#!/usr/bin/env python3
import json
import subprocess
import sys

BRIDGE_URL = "http://localhost:9000"

def run_test(name, data):
    print(f"\nTest: {name}")
    try:
        subprocess.run([
            "curl", "-s", "-X", "POST", BRIDGE_URL,
            "-H", "Content-Type: application/json",
            "-d", json.dumps(data)
        ], check=True)
        print("Done. Check Discord for notification.")
    except subprocess.CalledProcessError as e:
        print(f"Error running test {name}: {e}")

def main():
    print("Starting Discord Bridge Verification Tests...")

    run_test("Overseerr Webhook (Email Mapping)", {
        "email": "caleb.john.larsen@gmail.com",
        "subject": "Overseerr Test",
        "message": "This is a simulated Overseerr notification."
    })

    run_test("Radarr Webhook (Label Mapping)", {
        "eventType": "Download",
        "instanceName": "Radarr",
        "movie": {"title": "The Matrix"},
        "tags": ["caleb"]
    })

    run_test("Sonarr Webhook (Label Mapping)", {
        "eventType": "Download",
        "instanceName": "Sonarr",
        "series": {"title": "The Boys"},
        "episode": {"seasonNumber": 1, "episodeNumber": 1},
        "tags": ["caleb"]
    })

    print("\nVerification Complete.")

if __name__ == "__main__":
    main()
