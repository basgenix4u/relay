"""SQLite persistence and deterministic, synthetic demo data for Relay."""
from __future__ import annotations
import hashlib
import json
import os
import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

DATA = Path(os.environ.get("RELAY_DATA_DIR", Path(__file__).parent / "data"))
DATA.mkdir(parents=True, exist_ok=True)
DB_PATH = DATA / "relay.sqlite3"


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def connect() -> sqlite3.Connection:
    db = sqlite3.connect(DB_PATH, timeout=20, check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA busy_timeout=20000")
    return db


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    value = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), 600000).hex()
    return f"pbkdf2_sha256$600000${salt}${value}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, count, salt, expected = stored.split("$")
        actual = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), int(count)).hex()
        return secrets.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def initialize() -> None:
    db = connect()
    db.executescript("""
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE COLLATE NOCASE,
      password_hash TEXT NOT NULL, workspace TEXT NOT NULL, demo INTEGER NOT NULL DEFAULT 0,
      settings TEXT NOT NULL DEFAULT '{}', created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions (
      token_hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS contact_groups (
      id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', color TEXT NOT NULL DEFAULT '#B7E88A',
      source TEXT NOT NULL DEFAULT 'Manual', created_at TEXT NOT NULL,
      UNIQUE(user_id, name)
    );
    CREATE TABLE IF NOT EXISTS contacts (
      id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      first_name TEXT NOT NULL, last_name TEXT NOT NULL DEFAULT '', phone TEXT NOT NULL,
      email TEXT NOT NULL DEFAULT '', company TEXT NOT NULL DEFAULT '', tags TEXT NOT NULL DEFAULT '[]',
      consent_status TEXT NOT NULL DEFAULT 'pending' CHECK(consent_status IN ('opted_in','pending','unsubscribed')),
      consent_source TEXT NOT NULL DEFAULT '', consent_at TEXT, source TEXT NOT NULL DEFAULT 'Manual',
      is_demo INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      UNIQUE(user_id, phone)
    );
    CREATE TABLE IF NOT EXISTS group_members (
      group_id INTEGER NOT NULL REFERENCES contact_groups(id) ON DELETE CASCADE,
      contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
      PRIMARY KEY(group_id, contact_id)
    );
    CREATE TABLE IF NOT EXISTS templates (
      id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL, name TEXT NOT NULL, body TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'MARKETING', language TEXT NOT NULL DEFAULT 'en',
      status TEXT NOT NULL DEFAULT 'Draft', meta_id TEXT, variable_count INTEGER NOT NULL DEFAULT 1,
      color TEXT NOT NULL DEFAULT '#EAF3E3', created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      UNIQUE(user_id, name)
    );
    CREATE TABLE IF NOT EXISTS campaigns (
      id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL, template_id INTEGER REFERENCES templates(id) ON DELETE SET NULL,
      group_id INTEGER REFERENCES contact_groups(id) ON DELETE SET NULL,
      audience TEXT NOT NULL DEFAULT 'All opted-in contacts', message TEXT NOT NULL DEFAULT '',
      variables TEXT NOT NULL DEFAULT '[]', status TEXT NOT NULL DEFAULT 'Draft',
      mode TEXT NOT NULL DEFAULT 'demo', scheduled_at TEXT, sent_at TEXT,
      color TEXT NOT NULL DEFAULT '#EAF3E3', created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      last_error TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY, campaign_id INTEGER NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
      contact_id INTEGER REFERENCES contacts(id) ON DELETE SET NULL,
      phone TEXT NOT NULL, status TEXT NOT NULL, provider_id TEXT, error TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      UNIQUE(campaign_id, contact_id)
    );
    CREATE TABLE IF NOT EXISTS activities (
      id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', kind TEXT NOT NULL DEFAULT 'contact',
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS integrations (
      user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      phone_number_id TEXT NOT NULL, business_account_id TEXT NOT NULL,
      access_token TEXT NOT NULL, connected_at TEXT NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_integration_phone ON integrations(phone_number_id);
    CREATE INDEX IF NOT EXISTS idx_contacts_owner ON contacts(user_id, consent_status, created_at);
    CREATE INDEX IF NOT EXISTS idx_campaigns_owner ON campaigns(user_id, status);
    CREATE INDEX IF NOT EXISTS idx_messages_campaign ON messages(campaign_id, status);
    CREATE INDEX IF NOT EXISTS idx_messages_provider ON messages(provider_id);
    CREATE INDEX IF NOT EXISTS idx_activities_owner ON activities(user_id, created_at);
    """)
    if not db.execute("SELECT 1 FROM users WHERE email='alex@relay.demo'").fetchone():
        uid = db.execute(
            "INSERT INTO users(name,email,password_hash,workspace,demo,settings,created_at) VALUES(?,?,?,?,1,?,?)",
            ("Alex Morgan", "alex@relay.demo", hash_password("Demo@1234"), "Acme Studio",
             json.dumps({"email_notifications": True, "delivery_notifications": True, "timezone": "Africa/Lagos"}), now()),
        ).lastrowid
        seed_demo(db, uid)
    db.commit()
    db.close()


def activity(db: sqlite3.Connection, uid: int, title: str, description: str, kind: str = "contact") -> None:
    db.execute("INSERT INTO activities(user_id,title,description,kind,created_at) VALUES(?,?,?,?,?)",
               (uid, title, description, kind, now()))


def seed_demo(db: sqlite3.Connection, uid: int) -> None:
    """Never live-message these illustrative contacts. is_demo is enforced server-side."""
    current = datetime.now(timezone.utc)
    groups = [
        ("Lagos customers", "Your Lagos community. Customer offers, new arrivals, and useful updates.", "#C9DDB2", 684, "CSV import"),
        ("Abuja founders", "Entrepreneurs who opted in at the Abuja Founders Meetup.", "#C6D4ED", 412, "Group opt-in"),
        ("VIP community", "Our most loyal customers. A little extra care goes a long way.", "#E7C6EA", 286, "CSV import"),
        ("New subscribers", "Fresh faces who joined through our store's opt-in form.", "#F1D8B3", 512, "Opt-in form"),
        ("Event attendees", "Keep the conversation going after your last community event.", "#B8DEDA", 398, "Group opt-in"),
        ("Store enquiries", "People who asked to hear more about our products.", "#D7D1EE", 194, "Manual"),
    ]
    gids = []
    for name, desc, color, count, source in groups:
        gid = db.execute("INSERT INTO contact_groups(user_id,name,description,color,source,created_at) VALUES(?,?,?,?,?,?)",
                         (uid, name, desc, color, source, (current - timedelta(days=35)).isoformat())).lastrowid
        gids.append(gid)
    first_names = ["Amara", "Adebayo", "Sarah", "David", "Fatima", "Chinedu", "Grace", "Tunde", "Zainab", "Michael", "Ada", "Daniel", "Ifeoma", "James", "Aisha", "Emeka", "Ella", "Oluwaseun", "Ngozi", "Samuel", "Sophia", "Ibrahim", "Chiamaka", "Benjamin", "Nneka", "Joseph", "Mariam", "Peter", "Chloe", "Femi", "Victoria", "Hassan", "Olivia", "Kunle", "Bukola", "Noah", "Lola", "Ahmed", "Maya", "Chika", "Uche", "Nathan", "Esther", "Seyi", "Joy", "Abubakar", "Ruth", "Anthony", "Yemi", "Blessing", "Damilola", "Joshua", "Hannah", "Usman", "Chisom", "Caleb", "Tosin", "Leo", "Precious", "Segun", "Stella", "Isaac", "Elizabeth", "Olumide"]
    last_names = ["Okafor", "Adeyemi", "Johnson", "Chen", "Ibrahim", "Eze", "Williams", "Olawale", "Bello", "Adebayo", "Nwosu", "Smith", "Obi", "Wilson", "Yusuf", "Okechukwu", "Brown", "Adesina", "Okeke", "Mensah", "Taylor", "Hassan", "Chukwu", "Akinola", "Davis", "Balogun", "Ahmed", "Lewis", "Afolabi", "Nelson", "Ojo", "Mohammed", "White", "Ajayi", "Lawal", "Walker", "Ogunleye", "Roberts", "Campbell", "Abiola", "Nnamdi", "Oni", "Cole", "Osinachi", "Ekwueme", "Clark", "James", "Adamu", "Umar", "Okoro", "Akande", "Ezekiel"]
    contacts = []
    g_index = 0
    next_boundary = groups[0][3]
    for i in range(2486):
        if i >= next_boundary:
            g_index += 1
            next_boundary += groups[g_index][3]
        first = first_names[i % len(first_names)]
        last = last_names[(i // len(first_names) + i % len(first_names)) % len(last_names)]
        status = "unsubscribed" if i % 41 == 40 else "pending" if i % 17 == 16 else "opted_in"
        created = (current - timedelta(days=(i % 58), hours=i % 20)).isoformat()
        cid = db.execute("""INSERT INTO contacts(user_id,first_name,last_name,phone,email,company,tags,
                       consent_status,consent_source,consent_at,source,is_demo,created_at,updated_at)
                       VALUES(?,?,?,?,?,?,?,?,?,?,?,1,?,?)""",
                         (uid, first, last, f"+{2348000000000+i}", f"{first.lower()}.{last.lower()}{i}@demo.example",
                          "" if i % 4 else "Studio " + last, json.dumps(["VIP"] if g_index == 2 else ["Customer"]),
                          status, "Synthetic demo opt-in record" if status == "opted_in" else "",
                          created if status == "opted_in" else None, groups[g_index][4], created, created)).lastrowid
        db.execute("INSERT INTO group_members(group_id,contact_id) VALUES(?,?)", (gids[g_index], cid))
        contacts.append((cid, f"+{2348000000000+i}", status))
    template_defs = [
        ("Weekend flash sale", "weekend_flash_sale", "Hi {{1}} 👋\n\nA little something for your weekend: enjoy 20% off our entire collection with code WEEKEND20.\n\nYour next favorite is waiting. Offer ends Sunday.\n\nReply STOP to opt out.", "MARKETING", "#ECF2E4"),
        ("Welcome to the community", "community_welcome", "Hi {{1}}, welcome to our little corner of the world! 🌿\n\nWe're so glad you're here. Expect thoughtful updates, first looks, and the occasional treat.\n\nReply STOP to opt out.", "MARKETING", "#EDE8F6"),
        ("Your order is on its way", "order_update", "Hello {{1}}, good news! Your order is on its way. 📦\n\nWe'll share tracking details soon. Thank you for supporting our business.", "UTILITY", "#E2EFF3"),
        ("Let's meet at the pop-up", "community_event", "Hey {{1}}, you're invited! 🎉\n\nJoin us at the community pop-up this Saturday, 11 am – 5 pm. Good people, great finds, and a few surprises.\n\nReply STOP to opt out.", "MARKETING", "#F6ECDD"),
        ("A little thank-you", "customer_thank_you", "Hi {{1}}, this one's for you. 💚\n\nThank you for being part of our story. Here's 15% off your next order, just because. Use THANKYOU15.\n\nReply STOP to opt out.", "MARKETING", "#E5F2E9"),
        ("Meet your new favorites", "new_product_drop", "Hello {{1}} ✨\n\nFresh arrivals are here, and we think you'll love them. Explore the new collection and find something that feels like you.\n\nReply STOP to opt out.", "MARKETING", "#F4E6EA"),
    ]
    tids = []
    for title, name, body, category, color in template_defs:
        tid = db.execute("INSERT INTO templates(user_id,title,name,body,category,status,color,created_at,updated_at) VALUES(?,?,?,?,?,'Demo approved',?,?,?)",
                         (uid, title, name, body, category, color, (current - timedelta(days=21)).isoformat(), now())).lastrowid
        tids.append(tid)
    sent_defs = [("Weekend flash sale", 0, 1450, 1), ("October new arrivals", 5, 1215, 2),
                 ("A thank-you to our VIPs", 4, 286, 3), ("Community pop-up invite", 3, 1867, 4),
                 ("September favorites", 5, 1820, 5), ("Hello, new subscribers", 1, 920, 6)]
    eligible = [c for c in contacts if c[2] == "opted_in"]
    for k, (title, t, count, days) in enumerate(sent_defs):
        at = (current - timedelta(days=days, hours=2)).isoformat()
        camp = db.execute("""INSERT INTO campaigns(user_id,name,template_id,audience,message,status,mode,sent_at,color,created_at,updated_at)
                             VALUES(?,?,?,?,?,'Completed','demo',?,?,?,?)""",
                          (uid, title, tids[t], "All opted-in contacts" if k != 2 else "VIP community",
                           template_defs[t][2], at, template_defs[t][4], at, at)).lastrowid
        batch = []
        for j in range(count):
            cid, phone, _ = eligible[(j + k * 53) % len(eligible)]
            status = "failed" if j % 55 == 54 else "read" if j % 10 < 7 else "delivered"
            batch.append((camp, cid, phone, status, "Simulated delivery failure" if status == "failed" else "", at, at))
        db.executemany("INSERT INTO messages(campaign_id,contact_id,phone,status,error,created_at,updated_at) VALUES(?,?,?,?,?,?,?)", batch)
    draft_defs = [("VIP early access", 5, gids[2], "Scheduled", 1), ("Midweek little treat", 4, gids[0], "Scheduled", 2),
                  ("New subscriber welcome", 1, gids[3], "Draft", 0), ("Holiday collection preview", 5, None, "Draft", 0)]
    for title, t, gid, status, day in draft_defs:
        audience = next((g[0] for g, gi in zip(groups, gids) if gi == gid), "All opted-in contacts")
        db.execute("""INSERT INTO campaigns(user_id,name,template_id,group_id,audience,message,status,mode,scheduled_at,color,created_at,updated_at)
                     VALUES(?,?,?,?,?,?,?,'demo',?,?,?,?)""",
                   (uid, title, tids[t], gid, audience, template_defs[t][2], status,
                    (current + timedelta(days=day)).isoformat() if day else None, template_defs[t][4], now(), now()))
    activity_defs = [
        ("Weekend flash sale completed", "1,424 messages delivered to your community", "campaign", 12),
        ("New contacts added", "42 subscribers joined Lagos customers", "contact", 38),
        ("VIP early access scheduled", "Ready for tomorrow. Your VIPs are in for a treat.", "schedule", 84),
        ("Contact list imported", "Abuja founders · consented member list", "group", 125),
        ("New template created", "Meet your new favorites · Demo approved", "template", 240),
    ]
    for title, desc, kind, minutes in activity_defs:
        db.execute("INSERT INTO activities(user_id,title,description,kind,created_at) VALUES(?,?,?,?,?)",
                   (uid, title, desc, kind, (current - timedelta(minutes=minutes)).isoformat()))
