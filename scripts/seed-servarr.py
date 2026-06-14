import sqlite3
import hashlib
import os
import base64
import uuid
import sys

config_root = "/config"
password = os.environ.get("ADMIN_PASSWORD")
if not password:
    print("ADMIN_PASSWORD not set. Skipping.")
    sys.exit(0)

# All modern Servarr apps (Sonarr v4, Radarr v5, Prowlarr) use HMAC-SHA512 @ 10k iterations
apps = ['sonarr', 'radarr', 'prowlarr']
iterations = 10000

for app in apps:
    db_path = f"{config_root}/{app}/{app}.db"
    if not os.path.exists(db_path):
        print(f"Database for {app} not found at {db_path}. Skipping.")
        continue

    print(f"Seeding admin user for {app}...")
    salt = os.urandom(16)
    key = hashlib.pbkdf2_hmac('sha512', password.encode(), salt, iterations, dklen=32)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    identifier = str(uuid.uuid4())

    try:
        cur.execute("SELECT Identifier FROM Users WHERE Username='admin'")
        row = cur.fetchone()
        if row:
            identifier = row[0]
            print(f"  Found existing user {identifier}. Updating password.")
        else:
            print(f"  No existing admin. Creating new user {identifier}.")

        cur.execute("INSERT OR REPLACE INTO Users (Id, Identifier, Username, Password, Salt, Iterations) VALUES (1, ?, 'admin', ?, ?, ?)",
                    (identifier, base64.b64encode(key).decode(), base64.b64encode(salt).decode(), iterations))
        conn.commit()
        print(f"  Successfully seeded {app}.")
    except sqlite3.OperationalError as e:
        print(f"  Failed to seed {app}: {e}")
    finally:
        conn.close()
