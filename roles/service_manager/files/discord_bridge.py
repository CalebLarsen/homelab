import os
import json
import asyncio
import time
from aiohttp import web
import discord

BOT_TOKEN = os.environ.get("DISCORD_BOT_TOKEN")
USERS_JSON = os.environ.get("USERS_JSON", "[]")

# Simple in-memory cache for debouncing notifications (key: discord_id:title, value: timestamp)
last_notification_time = {}
DEBOUNCE_WINDOW = 60 # seconds

try:
    users = json.loads(USERS_JSON)
    # Map email -> discord_id
    email_to_discord = {u.get("email"): int(u.get("discord_id")) for u in users if u.get("email") and u.get("discord_id")}
    # Map label -> discord_id
    label_to_discord = {u.get("label"): int(u.get("discord_id")) for u in users if u.get("label") and u.get("discord_id")}
except Exception as e:
    print(f"Error parsing USERS_JSON: {e}")
    email_to_discord = {}
    label_to_discord = {}

print(f"Loaded email mappings: {list(email_to_discord.keys())}")
print(f"Loaded label mappings: {list(label_to_discord.keys())}")

intents = discord.Intents.default()
client = discord.Client(intents=intents)

async def send_dm(discord_id, subject, message, debounce_key=None):
    if debounce_key:
        now = time.time()
        key = f"{discord_id}:{debounce_key}"
        if key in last_notification_time and (now - last_notification_time[key]) < DEBOUNCE_WINDOW:
            print(f"Debouncing notification for {key}")
            return "debounced"
        last_notification_time[key] = now

    try:
        user = await client.fetch_user(discord_id)
        content = f"**{subject}**\n{message}"
        await user.send(content)
        print(f"Successfully sent DM to {discord_id}")
        return "sent"
    except Exception as e:
        print(f"Failed to send DM to {discord_id}: {e}")
        return "failed"

async def handle_webhook(request):
    try:
        data = await request.json()
        print(f"Received webhook: {data}")

        # 1. Try Overseerr (Email based)
        email = data.get("email")
        if email and email in email_to_discord:
            subject = data.get("subject", "Seerr Notification")
            message = data.get("message", "")
            result = await send_dm(email_to_discord[email], subject, message, debounce_key=subject)
            if result == "debounced":
                return web.Response(text="Debounced", status=200)
            elif result == "sent":
                return web.Response(text="OK")
            return web.Response(text="Failed to send DM", status=500)

        # 2. Try Radarr/Sonarr (Tag based)
        # These send a list of tags. We look for any tag that matches a user label.
        # Real webhooks nest tags inside 'movie' or 'series'
        tags = data.get("tags", [])
        if not tags and "movie" in data:
            tags = data["movie"].get("tags", [])
        if not tags and "series" in data:
            tags = data["series"].get("tags", [])

        event_type = data.get("eventType", "Unknown")

        # Radarr uses 'movie', Sonarr uses 'series'
        title = "Unknown Media"
        if "movie" in data:
            title = data["movie"].get("title", "Unknown Movie")
        elif "series" in data:
            title = data["series"].get("title", "Unknown Series")
            # Don't include episode info in title for debouncing purposes
            # title += f" - S{data['episode'].get('seasonNumber')}E{data['episode'].get('episodeNumber')}"

        if event_type == "Test":
            subject = "Test Notification"
            message = f"Connections look good from {data.get('instanceName', 'Servarr')}!"
        else:
            subject = f"Download Finished: {title}"
            message = f"{title} is now available on your Plex server."

        sent = False
        debounced = False
        for tag in tags:
            tag_lower = tag.lower()
            for label, discord_id in label_to_discord.items():
                if label.lower() in tag_lower:
                    result = await send_dm(discord_id, subject, message, debounce_key=title)
                    if result == "sent":
                        sent = True
                    elif result == "debounced":
                        debounced = True

        if sent:
            return web.Response(text="OK")
        if debounced:
            return web.Response(text="Debounced", status=200)

        print(f"No Discord mapping found for payload: {data}")
        return web.Response(text="No mapping found", status=404)

    except Exception as e:
        print(f"Error processing webhook: {e}")
        return web.Response(status=400, text="Bad Request")

async def handle_health(request):
    return web.Response(text="OK")

async def start_web_server():
    app = web.Application()
    app.router.add_post('/', handle_webhook)
    app.router.add_get('/health', handle_health)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 9000)
    await site.start()
    print("Discord Bridge web server started on port 9000")

@client.event
async def on_ready():
    print(f'Logged in as {client.user}')
    await start_web_server()

if __name__ == "__main__":
    if not BOT_TOKEN:
        print("No BOT_TOKEN configured. Exiting.")
        exit(1)
    client.run(BOT_TOKEN)
