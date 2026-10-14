"""Relay API + Flutter web host. Run from project root: uvicorn backend.app:app."""
from __future__ import annotations
import asyncio
import csv
import hashlib
import hmac
import io
import json
import logging
import os
import re
import secrets
import sqlite3
import time
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Literal

from fastapi import BackgroundTasks, Depends, FastAPI, HTTPException, Request, Response, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from .database import activity, connect, hash_password, initialize, now, verify_password
from . import provider

log = logging.getLogger("relay")
ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web_release"
work_tasks: set[asyncio.Task] = set()
auth_attempts: dict[str, list[float]] = {}


def launch(campaign_id: int, uid: int):
    task = asyncio.create_task(process_campaign(campaign_id, uid))
    work_tasks.add(task)
    task.add_done_callback(work_tasks.discard)


@asynccontextmanager
async def lifespan(app):
    initialize()
    db = connect()
    # A request may have reached Meta before a previous process stopped. Do not blindly resend.
    db.execute("UPDATE messages SET status='failed', error='Delivery unknown after server restart; manual review required' WHERE status='processing'")
    for row in db.execute("SELECT id,user_id FROM campaigns WHERE status='Sending'").fetchall():
        launch(row["id"], row["user_id"])
    db.commit()
    db.close()
    scheduler = asyncio.create_task(schedule_worker())
    yield
    scheduler.cancel()
    for task in list(work_tasks):
        task.cancel()
    await asyncio.gather(scheduler, *work_tasks, return_exceptions=True)


app = FastAPI(title="Relay Marketing API", version="1.0.0", lifespan=lifespan)
origins = [x.strip() for x in os.getenv("RELAY_ALLOWED_ORIGINS", "").split(",") if x.strip()]
if origins:
    app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["GET", "POST", "PUT", "DELETE"], allow_headers=["Authorization", "Content-Type"])


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    if request.url.path.startswith("/api"):
        response.headers["Cache-Control"] = "no-store"
    return response


@app.exception_handler(sqlite3.IntegrityError)
async def conflict_handler(request, exc):
    return JSONResponse(status_code=409, content={"detail": "This record already exists, or a linked record is no longer available."})


def db_dep():
    db = connect()
    try:
        yield db
    finally:
        db.close()


def user_dep(request: Request, db=Depends(db_dep)):
    token = request.headers.get("Authorization", "").removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(401, "Please sign in to continue.")
    row = db.execute("SELECT u.* FROM users u JOIN sessions s ON s.user_id=u.id WHERE s.token_hash=? AND s.expires_at>?",
                     (hashlib.sha256(token.encode()).hexdigest(), now())).fetchone()
    if not row:
        raise HTTPException(401, "Your session has expired. Please sign in again.")
    return dict(row)


def own(db, table: str, rid: int, uid: int):
    row = db.execute(f"SELECT * FROM {table} WHERE id=? AND user_id=?", (rid, uid)).fetchone()
    if not row:
        raise HTTPException(404, "This record could not be found in your workspace.")
    return dict(row)


def public_user(row):
    return {"id": row["id"], "name": row["name"], "email": row["email"], "workspace": row["workspace"], "demo": bool(row["demo"]), "settings": json.loads(row["settings"])}


def issue_session(db, uid):
    token = secrets.token_urlsafe(48)
    db.execute("DELETE FROM sessions WHERE expires_at<?", (now(),))
    db.execute("INSERT INTO sessions VALUES(?,?,?)", (hashlib.sha256(token.encode()).hexdigest(), uid, (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()))
    db.commit()
    return {"token": token, "user": public_user(db.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone())}


def auth_limit(request: Request):
    key = request.client.host if request.client else "unknown"
    cutoff = time.time() - 60
    attempts = [t for t in auth_attempts.get(key, []) if t > cutoff]
    if len(attempts) >= 20:
        raise HTTPException(429, "Too many sign-in attempts. Please wait one minute.")
    attempts.append(time.time())
    auth_attempts[key] = attempts


class Login(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(max_length=200)


class Register(Login):
    name: str = Field(min_length=2, max_length=80)
    workspace: str = Field(min_length=2, max_length=100)


@app.post("/api/auth/demo")
def demo_login(request: Request, db=Depends(db_dep)):
    if os.getenv("RELAY_DEMO_ENABLED", "1") != "1":
        raise HTTPException(403, "Demo sign-in is disabled on this server.")
    auth_limit(request)
    row = db.execute("SELECT id FROM users WHERE email='alex@relay.demo'").fetchone()
    return issue_session(db, row[0])


@app.post("/api/auth/login")
def login(payload: Login, request: Request, db=Depends(db_dep)):
    auth_limit(request)
    user = db.execute("SELECT * FROM users WHERE email=?", (payload.email.strip().lower(),)).fetchone()
    if not user or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(401, "The email or password is incorrect.")
    if user["demo"] and os.getenv("RELAY_DEMO_ENABLED", "1") != "1":
        raise HTTPException(403, "Demo sign-in is disabled on this server.")
    return issue_session(db, user["id"])


@app.post("/api/auth/register", status_code=201)
def register(payload: Register, request: Request, db=Depends(db_dep)):
    auth_limit(request)
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", payload.email):
        raise HTTPException(422, "Enter a valid email address.")
    if len(payload.password) < 8 or not payload.password.strip():
        raise HTTPException(422, "Use a password with at least 8 characters.")
    if len(payload.name.strip()) < 2 or len(payload.workspace.strip()) < 2:
        raise HTTPException(422, "Your name and workspace need at least two non-whitespace characters.")
    uid = db.execute("INSERT INTO users(name,email,password_hash,workspace,created_at) VALUES(?,?,?,?,?)",
                     (payload.name.strip(), payload.email.lower().strip(), hash_password(payload.password), payload.workspace.strip(), now())).lastrowid
    activity(db, uid, "Welcome to Relay", "Your workspace is ready. Start by importing your contacts.", "workspace")
    db.commit()
    return issue_session(db, uid)


@app.get("/api/auth/me")
def me(user=Depends(user_dep)):
    return public_user(user)


@app.post("/api/auth/logout")
def logout(request: Request, user=Depends(user_dep), db=Depends(db_dep)):
    token = request.headers.get("Authorization", "").removeprefix("Bearer ").strip()
    db.execute("DELETE FROM sessions WHERE token_hash=?", (hashlib.sha256(token.encode()).hexdigest(),))
    db.commit()
    return {"ok": True}


@app.get("/api/health")
def health():
    return {"status": "ok", "app": "relay", "storage": "sqlite", "group_scraping": False}


class Profile(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    workspace: str = Field(min_length=2, max_length=100)
    email_notifications: bool = True
    delivery_notifications: bool = True
    timezone: str = "Africa/Lagos"


@app.put("/api/settings")
def settings(payload: Profile, user=Depends(user_dep), db=Depends(db_dep)):
    if len(payload.name.strip()) < 2 or len(payload.workspace.strip()) < 2:
        raise HTTPException(422, "Your name and workspace need at least two non-whitespace characters.")
    if payload.timezone not in ["Africa/Lagos", "UTC", "Europe/London", "America/New_York"]:
        raise HTTPException(422, "Select a supported timezone.")
    prefs = {k: v for k, v in payload.model_dump().items() if k not in ["name", "workspace"]}
    db.execute("UPDATE users SET name=?,workspace=?,settings=? WHERE id=?", (payload.name.strip(), payload.workspace.strip(), json.dumps(prefs), user["id"]))
    db.commit()
    return public_user(db.execute("SELECT * FROM users WHERE id=?", (user["id"],)).fetchone())


def contact_dict(db, row):
    item = dict(row)
    item["tags"] = json.loads(item["tags"])
    item["is_demo"] = bool(item["is_demo"])
    item["groups"] = [dict(g) for g in db.execute("SELECT g.id,g.name,g.color FROM contact_groups g JOIN group_members gm ON gm.group_id=g.id WHERE gm.contact_id=? ORDER BY g.name", (item["id"],)).fetchall()]
    return item


def normalize_phone(value: str) -> str:
    value = value.strip()
    if value.startswith("'+"):
        value = value[1:]  # Accept spreadsheet-safe phone values from our CSV exports.
    phone = re.sub(r"[\s().-]", "", value)
    if phone.startswith("00"):
        phone = "+" + phone[2:]
    if not re.fullmatch(r"\+[1-9]\d{6,14}", phone):
        raise HTTPException(422, "Use an international phone number, for example +234 803 123 4567.")
    return phone


class ContactData(BaseModel):
    is_demo: bool = False
    first_name: str = Field(min_length=1, max_length=80)
    last_name: str = Field(default="", max_length=80)
    phone: str = Field(max_length=40)
    email: str = Field(default="", max_length=254)
    company: str = Field(default="", max_length=100)
    tags: list[str] = Field(default_factory=list, max_length=10)
    consent_status: Literal["opted_in", "pending", "unsubscribed"] = "pending"
    consent_source: str = Field(default="", max_length=200)
    group_ids: list[int] = Field(default_factory=list, max_length=50)


def reserved_demo_phone(phone: str) -> bool:
    # North American 555-0100 through 555-0199 are reserved demonstration numbers.
    return re.fullmatch(r"\+1[2-9]\d{2}55501\d{2}", phone) is not None


def validate_contact(payload: ContactData):
    phone = normalize_phone(payload.phone)
    if not payload.first_name.strip():
        raise HTTPException(422, "A first name is required.")
    if payload.email and not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", payload.email):
        raise HTTPException(422, "Enter a valid email address.")
    if payload.consent_status == "opted_in" and not payload.consent_source.strip():
        raise HTTPException(422, "Record where this contact gave permission to receive messages.")
    if any(len(t) > 40 for t in payload.tags):
        raise HTTPException(422, "Contact tags must be 40 characters or fewer.")
    return phone


def check_groups(db, ids, uid):
    for gid in ids:
        own(db, "contact_groups", gid, uid)


@app.get("/api/contacts")
def list_contacts(q: str = "", ids: str = "", status: str = "", group_id: int | None = None, page: int = 1, limit: int = 12, user=Depends(user_dep), db=Depends(db_dep)):
    uid = user["id"]
    page = max(1, page)
    limit = max(1, min(limit, 5000))
    where = "c.user_id=?"
    args: list = [uid]
    if ids:
        try:
            selected = list(set(int(i) for i in ids.split(",")))
        except ValueError:
            raise HTTPException(422, "Invalid contact selection.")
        if len(selected) > 5000:
            raise HTTPException(422, "Select up to 5,000 contacts at a time.")
        where += " AND c.id IN (" + ",".join("?" for _ in selected) + ")"
        args.extend(selected)
    if q:
        where += " AND (c.first_name || ' ' || c.last_name LIKE ? OR c.phone LIKE ? OR c.email LIKE ?)"
        args.extend([f"%{q[:100]}%"] * 3)
    if status:
        if status not in ["opted_in", "pending", "unsubscribed"]:
            raise HTTPException(422, "Invalid contact status.")
        where += " AND c.consent_status=?"
        args.append(status)
    if group_id:
        own(db, "contact_groups", group_id, uid)
        where += " AND EXISTS(SELECT 1 FROM group_members gm WHERE gm.contact_id=c.id AND gm.group_id=?)"
        args.append(group_id)
    total = db.execute(f"SELECT COUNT(*) FROM contacts c WHERE {where}", args).fetchone()[0]
    rows = db.execute(f"SELECT c.* FROM contacts c WHERE {where} ORDER BY c.id ASC LIMIT ? OFFSET ?", args + [limit, (page-1)*limit]).fetchall()
    counts = {row["consent_status"]: row["n"] for row in db.execute("SELECT consent_status,COUNT(*) n FROM contacts WHERE user_id=? GROUP BY consent_status", (uid,))}
    return {"items": [contact_dict(db, row) for row in rows], "total": total, "page": page, "limit": limit, "counts": counts}


@app.post("/api/contacts", status_code=201)
def create_contact(payload: ContactData, user=Depends(user_dep), db=Depends(db_dep)):
    phone = validate_contact(payload)
    check_groups(db, payload.group_ids, user["id"])
    cid = db.execute("""INSERT INTO contacts(user_id,first_name,last_name,phone,email,company,tags,consent_status,
                       consent_source,consent_at,source,is_demo,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,'Manual',?,?,?)""",
                     (user["id"], payload.first_name.strip(), payload.last_name.strip(), phone, payload.email.strip(), payload.company.strip(),
                      json.dumps(payload.tags), payload.consent_status, payload.consent_source,
                      now() if payload.consent_status == "opted_in" else None, int(payload.is_demo or reserved_demo_phone(phone)), now(), now())).lastrowid
    for gid in set(payload.group_ids):
        db.execute("INSERT INTO group_members VALUES(?,?)", (gid, cid))
    activity(db, user["id"], "New contact added", f"{payload.first_name} {payload.last_name}".strip())
    db.commit()
    return contact_dict(db, db.execute("SELECT * FROM contacts WHERE id=?", (cid,)).fetchone())


@app.put("/api/contacts/{cid}")
def update_contact(cid: int, payload: ContactData, user=Depends(user_dep), db=Depends(db_dep)):
    previous = own(db, "contacts", cid, user["id"])
    phone = validate_contact(payload)
    check_groups(db, payload.group_ids, user["id"])
    # Synthetic contacts remain synthetic even if their phone/name changes.
    db.execute("""UPDATE contacts SET first_name=?,last_name=?,phone=?,email=?,company=?,tags=?,consent_status=?,
                  consent_source=?,consent_at=?,is_demo=?,updated_at=? WHERE id=? AND user_id=?""",
               (payload.first_name.strip(), payload.last_name.strip(), phone, payload.email.strip(), payload.company.strip(), json.dumps(payload.tags),
                payload.consent_status, payload.consent_source,
                (previous["consent_at"] or now()) if payload.consent_status == "opted_in" and previous["consent_status"] == "opted_in" else now() if payload.consent_status == "opted_in" else None, int(previous["is_demo"] or payload.is_demo or reserved_demo_phone(phone)), now(), cid, user["id"]))
    db.execute("DELETE FROM group_members WHERE contact_id=?", (cid,))
    for gid in set(payload.group_ids):
        db.execute("INSERT INTO group_members VALUES(?,?)", (gid, cid))
    activity(db, user["id"], "Contact updated", f"{payload.first_name} {payload.last_name}".strip())
    db.commit()
    return contact_dict(db, db.execute("SELECT * FROM contacts WHERE id=?", (cid,)).fetchone())


@app.delete("/api/contacts/{cid}")
def delete_contact(cid: int, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "contacts", cid, user["id"])
    db.execute("DELETE FROM contacts WHERE id=?", (cid,))
    activity(db, user["id"], "Contact removed", row["first_name"] + " " + row["last_name"])
    db.commit()
    return {"ok": True}


class BulkIds(BaseModel):
    ids: list[int] = Field(min_length=1, max_length=5000)


@app.post("/api/contacts/bulk-delete")
def bulk_delete(payload: BulkIds, user=Depends(user_dep), db=Depends(db_dep)):
    placeholders = ",".join("?" for _ in payload.ids)
    deleted = db.execute(f"DELETE FROM contacts WHERE user_id=? AND id IN ({placeholders})", [user["id"]] + payload.ids).rowcount
    activity(db, user["id"], "Contacts removed", f"{deleted} contacts deleted from the workspace")
    db.commit()
    return {"deleted": deleted}


@app.post("/api/contacts/import-preview")
async def import_preview(file: UploadFile = File(...), user=Depends(user_dep)):
    if not (file.filename or "").lower().endswith(".csv"):
        raise HTTPException(422, "Choose a CSV file. WhatsApp chat exports are not member or consent lists.")
    raw = await file.read(2_000_001)
    if len(raw) > 2_000_000:
        raise HTTPException(413, "The maximum CSV size is 2 MB.")
    try:
        reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig")))
        if not reader.fieldnames:
            raise ValueError()
        rows = []
        errors = []
        for i, original in enumerate(reader):
            if i >= 5000:
                raise HTTPException(422, "Import up to 5,000 contacts at a time.")
            if None in original or any(v is None for v in original.values()):
                errors.append({"row": i + 2, "reason": "The row has a different number of columns than the header."})
                continue
            row = {k.strip().lower().replace(" ", "_"): v.strip() for k, v in original.items()}
            full = row.get("name", "").split(" ", 1)
            first = row.get("first_name", full[0])
            last = row.get("last_name", full[1] if len(full) > 1 else "")
            try:
                phone = normalize_phone(row.get("phone", row.get("phone_number", row.get("number", ""))))
                if not first or len(first) > 80 or len(last) > 80:
                    raise ValueError("A first name of 1–80 characters is required.")
                email = row.get("email", "")
                if email and not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
                    raise ValueError("The email address is invalid.")
                rows.append({"first_name": first, "last_name": last, "phone": phone, "email": email, "is_demo": row.get("is_demo", "").lower() in ["1", "true", "yes"] or reserved_demo_phone(phone),
                             "consent_status": "opted_in" if row.get("consent_status", row.get("opted_in", "")).lower() in ["opted_in", "true", "yes", "1"] else "unsubscribed" if row.get("consent_status") == "unsubscribed" else "pending"})
            except (HTTPException, ValueError) as exc:
                errors.append({"row": i+2, "reason": exc.detail if isinstance(exc, HTTPException) else str(exc)})
        return {"contacts": rows, "valid": len(rows), "invalid": len(errors), "errors": errors[:50], "filename": file.filename}
    except (UnicodeDecodeError, csv.Error, ValueError):
        raise HTTPException(422, "This CSV could not be read. Use UTF-8 and columns: first_name, last_name, phone, email, consent_status.")


class ImportData(BaseModel):
    contacts: list[ContactData] = Field(min_length=1, max_length=5000)
    group_id: int | None = None
    has_consent: bool = False
    consent_source: str = Field(default="", max_length=200)


@app.post("/api/contacts/import")
def import_contacts(payload: ImportData, user=Depends(user_dep), db=Depends(db_dep)):
    uid = user["id"]
    if payload.group_id:
        own(db, "contact_groups", payload.group_id, uid)
    if payload.has_consent and not payload.consent_source.strip():
        raise HTTPException(422, "Please record the source of permission for this imported list.")
    imported, duplicates, invalid = 0, 0, 0
    for c in payload.contacts:
        try:
            phone = normalize_phone(c.phone)
            if not c.first_name.strip():
                invalid += 1
                continue
            existing = db.execute("SELECT id FROM contacts WHERE user_id=? AND phone=?", (uid, phone)).fetchone()
            if existing:
                duplicates += 1
                cid = existing[0]
            else:
                status = c.consent_status if payload.has_consent else "unsubscribed" if c.consent_status == "unsubscribed" else "pending"
                source = payload.consent_source if status == "opted_in" else ""
                cid = db.execute("""INSERT INTO contacts(user_id,first_name,last_name,phone,email,company,tags,consent_status,consent_source,
                               consent_at,source,is_demo,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?, 'CSV import',?,?,?)""",
                                 (uid, c.first_name.strip(), c.last_name.strip(), phone, c.email, c.company, json.dumps(c.tags),
                                  status, source, now() if status == "opted_in" else None, int(c.is_demo or reserved_demo_phone(phone)), now(), now())).lastrowid
                imported += 1
            if payload.group_id:
                db.execute("INSERT OR IGNORE INTO group_members VALUES(?,?)", (payload.group_id, cid))
        except HTTPException:
            invalid += 1
    activity(db, uid, "Contact list imported", f"{imported} added · {duplicates} duplicates skipped", "group" if payload.group_id else "contact")
    db.commit()
    return {"imported": imported, "duplicates": duplicates, "invalid": invalid}


@app.get("/api/contacts/export")
def export_contacts(format: str = "vcf", ids: str = "", group_id: int | None = None, user=Depends(user_dep), db=Depends(db_dep)):
    where = "c.user_id=?"
    args: list = [user["id"]]
    if ids:
        try:
            numbers = list(set(int(i) for i in ids.split(",")))
        except ValueError:
            raise HTTPException(422, "Invalid contact selection.")
        if len(numbers) > 5000:
            raise HTTPException(422, "Export up to 5,000 contacts at a time.")
        where += " AND c.id IN (" + ",".join("?" for _ in numbers) + ")"
        args.extend(numbers)
    if group_id:
        own(db, "contact_groups", group_id, user["id"])
        where += " AND EXISTS(SELECT 1 FROM group_members gm WHERE gm.group_id=? AND gm.contact_id=c.id)"
        args.append(group_id)
    rows = db.execute(f"SELECT c.* FROM contacts c WHERE {where} ORDER BY c.first_name LIMIT 5000", args).fetchall()
    if format == "csv":
        stream = io.StringIO()
        writer = csv.writer(stream)
        writer.writerow(["first_name", "last_name", "phone", "email", "consent_status", "consent_source", "source", "is_demo"])
        for row in rows:
            # Prevent spreadsheet formula injection in CSVs.
            def safe(v):
                text = str(v or "")
                return "'" + text if text.startswith(("=", "+", "-", "@", "\t", "\r")) else text
            writer.writerow([safe(row[key]) for key in ["first_name", "last_name", "phone", "email", "consent_status", "consent_source", "source", "is_demo"]])
        content, media, suffix = stream.getvalue(), "text/csv", "csv"
    elif format == "vcf":
        def escape(value):
            return (value or "").replace("\\", "\\\\").replace("\n", "\\n").replace("\r", "").replace(";", "\\;").replace(",", "\\,")
        cards = []
        for row in rows:
            card = ["BEGIN:VCARD", "VERSION:3.0", f"N:{escape(row['last_name'])};{escape(row['first_name'])};;;", f"FN:{escape(row['first_name'] + ' ' + row['last_name'])}", f"TEL;TYPE=CELL:{row['phone']}"]
            if row["email"]:
                card.append(f"EMAIL:{escape(row['email'])}")
            if row["company"]:
                card.append(f"ORG:{escape(row['company'])}")
            if row["is_demo"]:
                card.append("NOTE:Fictional Relay demonstration contact. Not for live messaging.")
            card.append("END:VCARD")
            cards.append("\r\n".join(card))
        content, media, suffix = "\r\n".join(cards) + "\r\n", "text/vcard", "vcf"
    else:
        raise HTTPException(422, "Choose vcf or csv.")
    return Response(content, media_type=media, headers={"Content-Disposition": f'attachment; filename="relay-contacts.{suffix}"', "X-Contact-Count": str(len(rows))})


class GroupData(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: str = Field(default="", max_length=400)
    color: str = "#C9DDB2"


def group_dict(db, row):
    item = dict(row)
    counts = db.execute("SELECT COUNT(*) total,COALESCE(SUM(c.consent_status='opted_in'),0) opted_in FROM group_members gm JOIN contacts c ON c.id=gm.contact_id WHERE gm.group_id=?", (row["id"],)).fetchone()
    item.update(dict(counts))
    item["preview"] = [dict(r) for r in db.execute("SELECT c.first_name,c.last_name FROM group_members gm JOIN contacts c ON c.id=gm.contact_id WHERE gm.group_id=? LIMIT 4", (row["id"],))]
    return item


@app.get("/api/groups")
def groups(q: str = "", user=Depends(user_dep), db=Depends(db_dep)):
    rows = db.execute("SELECT * FROM contact_groups WHERE user_id=? AND name LIKE ? ORDER BY id", (user["id"], f"%{q[:100]}%"))
    return {"items": [group_dict(db, row) for row in rows]}


def valid_group(payload):
    if not payload.name.strip():
        raise HTTPException(422, "Give this group a name.")
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", payload.color):
        raise HTTPException(422, "Choose a valid color.")


@app.post("/api/groups", status_code=201)
def create_group(payload: GroupData, user=Depends(user_dep), db=Depends(db_dep)):
    valid_group(payload)
    gid = db.execute("INSERT INTO contact_groups(user_id,name,description,color,created_at) VALUES(?,?,?,?,?)", (user["id"], payload.name.strip(), payload.description, payload.color, now())).lastrowid
    activity(db, user["id"], "New group created", payload.name, "group")
    db.commit()
    return group_dict(db, db.execute("SELECT * FROM contact_groups WHERE id=?", (gid,)).fetchone())


@app.put("/api/groups/{gid}")
def update_group(gid: int, payload: GroupData, user=Depends(user_dep), db=Depends(db_dep)):
    own(db, "contact_groups", gid, user["id"])
    valid_group(payload)
    db.execute("UPDATE contact_groups SET name=?,description=?,color=? WHERE id=?", (payload.name.strip(), payload.description, payload.color, gid))
    db.execute("UPDATE campaigns SET audience=? WHERE user_id=? AND group_id=?", (payload.name.strip(), user["id"], gid))
    db.commit()
    return group_dict(db, db.execute("SELECT * FROM contact_groups WHERE id=?", (gid,)).fetchone())


@app.delete("/api/groups/{gid}")
def delete_group(gid: int, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "contact_groups", gid, user["id"])
    if db.execute("SELECT 1 FROM campaigns WHERE group_id=? AND status IN ('Sending','Scheduled')", (gid,)).fetchone():
        raise HTTPException(409, "Cancel scheduled or sending campaigns for this group before deleting it.")
    # Avoid silently widening a draft's audience when its group is deleted.
    db.execute("DELETE FROM campaigns WHERE group_id=? AND status='Draft'", (gid,))
    db.execute("DELETE FROM contact_groups WHERE id=?", (gid,))
    activity(db, user["id"], "Group removed", row["name"] + " · contacts kept in your workspace", "group")
    db.commit()
    return {"ok": True}


class TemplateData(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    name: str = Field(min_length=1, max_length=100)
    body: str = Field(min_length=1, max_length=1024)
    category: Literal["MARKETING", "UTILITY"] = "MARKETING"
    language: str = Field(default="en", max_length=10)
    color: str = "#ECF2E4"


@app.get("/api/templates")
def templates(user=Depends(user_dep), db=Depends(db_dep)):
    return {"items": [dict(r) for r in db.execute("SELECT * FROM templates WHERE user_id=? ORDER BY id", (user["id"],))]}


def template_values(payload: TemplateData):
    if not re.fullmatch(r"[a-z][a-z0-9_]*", payload.name):
        raise HTTPException(422, "Template names use lowercase letters, numbers, and underscores.")
    if not payload.title.strip() or not payload.body.strip():
        raise HTTPException(422, "A template title and message are required.")
    vars = set(int(v) for v in re.findall(r"\{\{(\d+)\}\}", payload.body))
    if vars and vars != set(range(1, max(vars)+1)):
        raise HTTPException(422, "Use consecutive variables: {{1}}, {{2}}, and so on.")
    if len(vars) > 5:
        raise HTTPException(422, "This version supports up to five body variables.")
    return len(vars)


@app.post("/api/templates", status_code=201)
def create_template(payload: TemplateData, user=Depends(user_dep), db=Depends(db_dep)):
    count = template_values(payload)
    tid = db.execute("INSERT INTO templates(user_id,title,name,body,category,language,variable_count,color,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
                     (user["id"], payload.title.strip(), payload.name, payload.body, payload.category, payload.language, count, payload.color, now(), now())).lastrowid
    activity(db, user["id"], "New template created", payload.title, "template")
    db.commit()
    return dict(db.execute("SELECT * FROM templates WHERE id=?", (tid,)).fetchone())


@app.put("/api/templates/{tid}")
def update_template(tid: int, payload: TemplateData, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "templates", tid, user["id"])
    if row["meta_id"]:
        raise HTTPException(409, "Meta-managed templates are read-only here. Edit in WhatsApp Manager and sync again.")
    count = template_values(payload)
    db.execute("UPDATE templates SET title=?,name=?,body=?,category=?,language=?,variable_count=?,color=?,status='Draft',updated_at=? WHERE id=?",
               (payload.title.strip(), payload.name, payload.body, payload.category, payload.language, count, payload.color, now(), tid))
    db.commit()
    return dict(db.execute("SELECT * FROM templates WHERE id=?", (tid,)).fetchone())


@app.delete("/api/templates/{tid}")
def delete_template(tid: int, user=Depends(user_dep), db=Depends(db_dep)):
    own(db, "templates", tid, user["id"])
    if db.execute("SELECT 1 FROM campaigns WHERE template_id=? AND status IN ('Sending','Scheduled')", (tid,)).fetchone():
        raise HTTPException(409, "This template is used by an active campaign. Cancel that campaign first.")
    db.execute("DELETE FROM templates WHERE id=?", (tid,))
    db.commit()
    return {"ok": True}


def audience_rows(db, uid, group_id, mode="demo"):
    where = "c.user_id=? AND c.consent_status='opted_in' AND c.consent_source<>''"
    args = [uid]
    if group_id:
        where += " AND EXISTS(SELECT 1 FROM group_members gm WHERE gm.group_id=? AND gm.contact_id=c.id)"
        args.append(group_id)
    if mode == "live":
        where += " AND c.is_demo=0"
    return db.execute(f"SELECT c.* FROM contacts c WHERE {where} ORDER BY c.id", args).fetchall()


def campaign_dict(db, row):
    item = dict(row)
    item["variables"] = json.loads(item["variables"])
    counts = db.execute("""SELECT COUNT(*) total, COALESCE(SUM(status IN ('sent','delivered','read')),0) sent,
                      COALESCE(SUM(status IN ('delivered','read')),0) delivered, COALESCE(SUM(status='read'),0) read,
                      COALESCE(SUM(status='failed'),0) failed FROM messages WHERE campaign_id=?""", (item["id"],)).fetchone()
    item.update(dict(counts))
    item["audience_count"] = len(audience_rows(db, row["user_id"], row["group_id"], row["mode"]))
    template = db.execute("SELECT title,status,name FROM templates WHERE id=?", (row["template_id"],)).fetchone()
    item["template"] = dict(template) if template else None
    return item


@app.get("/api/campaigns")
def campaigns(q: str = "", status: str = "", user=Depends(user_dep), db=Depends(db_dep)):
    rows = db.execute("SELECT * FROM campaigns WHERE user_id=? AND name LIKE ? AND (?='' OR status=?) ORDER BY created_at DESC,id DESC",
                      (user["id"], f"%{q[:100]}%", status, status))
    return {"items": [campaign_dict(db, r) for r in rows]}


@app.get("/api/campaigns/{cid}")
def get_campaign(cid: int, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "campaigns", cid, user["id"])
    item = campaign_dict(db, row)
    item["messages"] = [dict(r) for r in db.execute("SELECT m.*,c.first_name,c.last_name FROM messages m LEFT JOIN contacts c ON c.id=m.contact_id WHERE campaign_id=? ORDER BY m.id DESC LIMIT 30", (cid,))]
    return item


class CampaignData(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    template_id: int | None = None
    group_id: int | None = None
    message: str = Field(default="", max_length=1024)
    variables: list[str] = Field(default_factory=list, max_length=4)
    mode: Literal["demo", "live"] = "demo"
    scheduled_at: str | None = None
    confirm_live_schedule: bool = False
    color: str = "#ECF2E4"


def check_campaign(payload, user, db):
    if not payload.name.strip():
        raise HTTPException(422, "Give this campaign a name.")
    if payload.template_id:
        template = own(db, "templates", payload.template_id, user["id"])
    else:
        template = None
    if payload.group_id:
        group = own(db, "contact_groups", payload.group_id, user["id"])
    else:
        group = None
    message = payload.message.strip() or (template["body"] if template else "")
    if not message:
        raise HTTPException(422, "Write a message or choose a template.")
    if payload.mode == "live":
        if user["demo"]:
            raise HTTPException(403, "Demo workspaces cannot send live messages. Create your own workspace first.")
        if not db.execute("SELECT 1 FROM integrations WHERE user_id=?", (user["id"],)).fetchone():
            raise HTTPException(422, "Connect WhatsApp Business before creating a live campaign.")
        if not template or template["status"] != "Approved" or not template["meta_id"]:
            raise HTTPException(422, "Live campaigns require a verified Meta-approved template. Sync your templates first.")
        if message != template["body"]:
            raise HTTPException(422, "The message must match the approved template exactly.")
        if len(payload.variables) != max(0, template["variable_count"] - 1):
            raise HTTPException(422, "Provide values for every additional template body variable.")
    if payload.scheduled_at:
        if payload.mode == "live" and not payload.confirm_live_schedule:
            raise HTTPException(422, "Explicit confirmation is required to schedule live messages.")
        try:
            date = datetime.fromisoformat(payload.scheduled_at.replace("Z", "+00:00"))
            if date.tzinfo is None:
                raise ValueError()
            if date <= datetime.now(timezone.utc):
                raise ValueError()
            payload.scheduled_at = date.astimezone(timezone.utc).isoformat(timespec="seconds")
        except ValueError:
            raise HTTPException(422, "Choose a future date and time, including its timezone.")
    return group, template, message


@app.post("/api/campaigns", status_code=201)
def create_campaign(payload: CampaignData, user=Depends(user_dep), db=Depends(db_dep)):
    group, template, message = check_campaign(payload, user, db)
    status = "Scheduled" if payload.scheduled_at else "Draft"
    cid = db.execute("""INSERT INTO campaigns(user_id,name,template_id,group_id,audience,message,variables,status,mode,scheduled_at,color,created_at,updated_at)
                      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                     (user["id"], payload.name.strip(), payload.template_id, payload.group_id, group["name"] if group else "All opted-in contacts", message,
                      json.dumps(payload.variables), status, payload.mode, payload.scheduled_at, payload.color, now(), now())).lastrowid
    activity(db, user["id"], "Campaign scheduled" if status == "Scheduled" else "Campaign draft created", payload.name, "schedule" if status == "Scheduled" else "campaign")
    db.commit()
    return campaign_dict(db, db.execute("SELECT * FROM campaigns WHERE id=?", (cid,)).fetchone())


@app.put("/api/campaigns/{cid}")
def update_campaign(cid: int, payload: CampaignData, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "campaigns", cid, user["id"])
    if row["status"] not in ["Draft", "Scheduled", "Failed"]:
        raise HTTPException(409, "Sent or sending campaigns cannot be edited. Duplicate it to start a new one.")
    group, template, message = check_campaign(payload, user, db)
    status = "Scheduled" if payload.scheduled_at else "Draft"
    db.execute("""UPDATE campaigns SET name=?,template_id=?,group_id=?,audience=?,message=?,variables=?,status=?,mode=?,scheduled_at=?,color=?,updated_at=? WHERE id=?""",
               (payload.name.strip(), payload.template_id, payload.group_id, group["name"] if group else "All opted-in contacts", message,
                json.dumps(payload.variables), status, payload.mode, payload.scheduled_at, payload.color, now(), cid))
    db.commit()
    return campaign_dict(db, db.execute("SELECT * FROM campaigns WHERE id=?", (cid,)).fetchone())


@app.post("/api/campaigns/{cid}/duplicate", status_code=201)
def duplicate_campaign(cid: int, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "campaigns", cid, user["id"])
    new = db.execute("""INSERT INTO campaigns(user_id,name,template_id,group_id,audience,message,variables,status,mode,color,created_at,updated_at)
                       VALUES(?,?,?,?,?,?,?,'Draft',?,?,?,?)""",
                      (user["id"], row["name"][:90]+" (copy)", row["template_id"], row["group_id"], row["audience"], row["message"], row["variables"], row["mode"], row["color"], now(), now())).lastrowid
    db.commit()
    return campaign_dict(db, db.execute("SELECT * FROM campaigns WHERE id=?", (new,)).fetchone())


class SendData(BaseModel):
    confirm_live: bool = False


def prepare_send(db, row, user, confirm_live=False):
    if row["status"] not in ["Draft", "Scheduled"]:
        raise HTTPException(409, "This campaign has already been sent or is being processed.")
    payload = CampaignData(name=row["name"], template_id=row["template_id"], group_id=row["group_id"], message=row["message"], variables=json.loads(row["variables"]), mode=row["mode"])
    check_campaign(payload, user, db)
    if row["mode"] == "live" and not confirm_live:
        raise HTTPException(422, "Explicit confirmation is required to send live messages.")
    recipients = audience_rows(db, user["id"], row["group_id"], row["mode"])
    if not recipients:
        raise HTTPException(422, "There are no eligible opted-in contacts in this audience. Demo contacts are never eligible for live delivery.")
    db.execute("UPDATE campaigns SET status='Sending',sent_at=?,last_error='',updated_at=? WHERE id=?", (now(), now(), row["id"]))
    db.executemany("INSERT OR IGNORE INTO messages(campaign_id,contact_id,phone,status,created_at,updated_at) VALUES(?,?,?,'queued',?,?)",
                   [(row["id"], r["id"], r["phone"], now(), now()) for r in recipients])
    activity(db, user["id"], "Campaign started" if row["mode"] == "live" else "Demo campaign started", f"{row['name']} · {len(recipients):,} opted-in contacts", "campaign")


@app.post("/api/campaigns/{cid}/send")
async def send_campaign(cid: int, payload: SendData, user=Depends(user_dep), db=Depends(db_dep)):
    db.execute("BEGIN IMMEDIATE")
    row = own(db, "campaigns", cid, user["id"])
    prepare_send(db, row, user, payload.confirm_live)
    db.commit()
    launch(cid, user["id"])
    return {"status": "Sending", "mode": row["mode"]}


@app.post("/api/campaigns/{cid}/cancel")
def cancel_campaign(cid: int, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "campaigns", cid, user["id"])
    if row["status"] not in ["Scheduled", "Sending"]:
        raise HTTPException(409, "Only scheduled or running campaigns can be canceled.")
    db.execute("UPDATE campaigns SET status='Canceled',scheduled_at=NULL,updated_at=? WHERE id=?", (now(), cid))
    db.execute("UPDATE messages SET status='canceled',updated_at=? WHERE campaign_id=? AND status='queued'", (now(), cid))
    activity(db, user["id"], "Campaign canceled", row["name"], "campaign")
    db.commit()
    return {"ok": True}


@app.delete("/api/campaigns/{cid}")
def delete_campaign(cid: int, user=Depends(user_dep), db=Depends(db_dep)):
    row = own(db, "campaigns", cid, user["id"])
    if row["status"] == "Sending":
        raise HTTPException(409, "Cancel this running campaign before deleting it.")
    db.execute("DELETE FROM campaigns WHERE id=?", (cid,))
    db.commit()
    return {"ok": True}


async def process_campaign(cid, uid):
    try:
        await asyncio.sleep(2)
        db = connect()
        row = db.execute("SELECT * FROM campaigns WHERE id=? AND user_id=?", (cid, uid)).fetchone()
        if not row or row["status"] != "Sending":
            db.close()
            return
        camp = dict(row)
        if camp["mode"] == "demo":
            pending = db.execute("SELECT id,contact_id FROM messages WHERE campaign_id=? AND status='queued' ORDER BY id", (cid,)).fetchall()
            updates = []
            for i, msg in enumerate(pending):
                c = db.execute("SELECT consent_status FROM contacts WHERE id=?", (msg["contact_id"],)).fetchone()
                status = "canceled" if not c or c[0] != "opted_in" else "failed" if i % 55 == 54 else "read" if i % 10 < 7 else "delivered"
                updates.append((status, "Simulated delivery failure" if status == "failed" else "", now(), msg["id"]))
            db.executemany("UPDATE messages SET status=?,error=?,updated_at=? WHERE id=?", updates)
            db.execute("UPDATE campaigns SET status='Completed',updated_at=? WHERE id=? AND status='Sending'", (now(), cid))
            activity(db, uid, "Demo campaign completed", f"{camp['name']} · all delivery data is simulated", "campaign")
            db.commit()
            db.close()
            return
        integration = db.execute("SELECT * FROM integrations WHERE user_id=?", (uid,)).fetchone()
        template = db.execute("SELECT * FROM templates WHERE id=?", (camp["template_id"],)).fetchone()
        if not integration or not template or template["status"] != "Approved":
            raise RuntimeError("A verified integration and approved template are required.")
        token = provider.decrypt(integration["access_token"])
        while True:
            state = db.execute("SELECT status FROM campaigns WHERE id=?", (cid,)).fetchone()
            if not state or state[0] != "Sending":
                break
            msg = db.execute("SELECT * FROM messages WHERE campaign_id=? AND status='queued' ORDER BY id LIMIT 1", (cid,)).fetchone()
            if not msg:
                db.execute("UPDATE campaigns SET status='Completed',updated_at=? WHERE id=? AND status='Sending'", (now(), cid))
                activity(db, uid, "Campaign submitted to WhatsApp", camp["name"] + " · delivery receipts will update analytics", "campaign")
                db.commit()
                break
            c = db.execute("SELECT * FROM contacts WHERE id=? AND user_id=?", (msg["contact_id"], uid)).fetchone()
            if not c or c["consent_status"] != "opted_in" or c["is_demo"] or not c["consent_source"]:
                db.execute("UPDATE messages SET status='canceled',error='Contact no longer eligible',updated_at=? WHERE id=?", (now(), msg["id"]))
                db.commit()
                continue
            db.execute("UPDATE messages SET status='processing',updated_at=? WHERE id=?", (now(), msg["id"]))
            db.commit()
            try:
                values = ([c["first_name"]] if template["variable_count"] else []) + json.loads(camp["variables"])
                mid = await provider.send_template(integration["phone_number_id"], token, c["phone"], template["name"], template["language"], values)
                db.execute("UPDATE messages SET status='sent',provider_id=?,updated_at=? WHERE id=?", (mid, now(), msg["id"]))
            except HTTPException as exc:
                db.execute("UPDATE messages SET status='failed',error=?,updated_at=? WHERE id=?", (str(exc.detail)[:500], now(), msg["id"]))
            db.commit()
            await asyncio.sleep(0.25)
        db.close()
    except asyncio.CancelledError:
        raise
    except Exception as exc:
        log.exception("Campaign worker failed")
        db = connect()
        db.execute("UPDATE campaigns SET status='Failed',last_error=?,updated_at=? WHERE id=? AND status='Sending'", (str(exc)[:500], now(), cid))
        db.commit()
        db.close()


async def schedule_worker():
    while True:
        await asyncio.sleep(5)
        db = connect()
        due = db.execute("SELECT * FROM campaigns WHERE status='Scheduled' AND scheduled_at<=?", (now(),)).fetchall()
        for row in due:
            try:
                db.execute("BEGIN IMMEDIATE")
                fresh = db.execute("SELECT * FROM campaigns WHERE id=? AND status='Scheduled'", (row["id"],)).fetchone()
                if not fresh:
                    db.rollback()
                    continue
                user = dict(db.execute("SELECT * FROM users WHERE id=?", (row["user_id"],)).fetchone())
                prepare_send(db, dict(fresh), user, confirm_live=True)
                db.commit()
                launch(row["id"], row["user_id"])
            except HTTPException as exc:
                db.rollback()
                db.execute("UPDATE campaigns SET status='Failed',last_error=? WHERE id=? AND status='Scheduled'", (str(exc.detail), row["id"]))
                db.commit()
        db.close()


@app.get("/api/activities")
def activities(user=Depends(user_dep), db=Depends(db_dep)):
    return {"items": [dict(r) for r in db.execute("SELECT * FROM activities WHERE user_id=? ORDER BY created_at DESC,id DESC LIMIT 30", (user["id"],))]}


@app.get("/api/dashboard")
def dashboard(days: int = 7, user=Depends(user_dep), db=Depends(db_dep)):
    uid = user["id"]
    days = days if days in [7, 14, 30] else 7
    current = datetime.now(timezone.utc)
    cutoff = (current - timedelta(days=days)).isoformat()
    stats = db.execute("""SELECT COUNT(*) total, COALESCE(SUM(m.status IN ('sent','delivered','read')),0) sent,
                       COALESCE(SUM(m.status IN ('delivered','read')),0) delivered, COALESCE(SUM(m.status='read'),0) read,
                       COALESCE(SUM(m.status='failed'),0) failed FROM messages m JOIN campaigns c ON c.id=m.campaign_id WHERE c.user_id=? AND m.created_at>=? AND m.status IN ('sent','delivered','read','failed')""", (uid, cutoff)).fetchone()
    count = db.execute("SELECT COUNT(*),COALESCE(SUM(consent_status='opted_in'),0),COALESCE(SUM(created_at>=?),0) FROM contacts WHERE user_id=?", (cutoff, uid)).fetchone()
    total_camps = db.execute("SELECT COUNT(*),COALESCE(SUM(status IN ('Scheduled','Sending')),0) FROM campaigns WHERE user_id=?", (uid,)).fetchone()
    points = []
    for offset in range(days-1, -1, -1):
        date = (current - timedelta(days=offset)).date().isoformat()
        r = db.execute("""SELECT COUNT(*) sent,COALESCE(SUM(m.status IN ('delivered','read')),0) delivered,
                        COALESCE(SUM(m.status='read'),0) read FROM messages m JOIN campaigns c ON c.id=m.campaign_id
                        WHERE c.user_id=? AND SUBSTR(m.created_at,1,10)=? AND m.status NOT IN ('queued','processing','canceled')""", (uid, date)).fetchone()
        points.append({"date": date, **dict(r)})
    segments = [dict(r) for r in db.execute("SELECT consent_status status,COUNT(*) count FROM contacts WHERE user_id=? GROUP BY consent_status", (uid,))]
    recent_sent = db.execute("SELECT * FROM campaigns WHERE user_id=? AND status IN ('Completed','Sending') ORDER BY sent_at DESC,id DESC LIMIT 3", (uid,)).fetchall()
    upcoming = db.execute("SELECT * FROM campaigns WHERE user_id=? AND status='Scheduled' ORDER BY scheduled_at ASC LIMIT 1", (uid,)).fetchall()
    drafts = db.execute("SELECT * FROM campaigns WHERE user_id=? AND status IN ('Draft','Failed','Canceled') ORDER BY created_at DESC,id DESC LIMIT 5", (uid,)).fetchall()
    recent = (recent_sent[:1] + upcoming + recent_sent[1:2] + drafts[:1] + recent_sent[2:] + drafts[1:])[:5]
    return {
        "total_contacts": count[0], "opted_in": count[1], "new_contacts": count[2], "messages_sent": stats["total"],
        "delivered": stats["delivered"], "read": stats["read"], "failed": stats["failed"],
        "delivery_rate": round(stats["delivered"]/stats["total"]*100, 1) if stats["total"] else 0,
        "read_rate": round(stats["read"]/stats["total"]*100, 1) if stats["total"] else 0,
        "total_campaigns": total_camps[0], "active_campaigns": total_camps[1], "days": days,
        "chart": points, "segments": segments,
        "recent_campaigns": [campaign_dict(db, r) for r in recent],
        "activities": [dict(r) for r in db.execute("SELECT * FROM activities WHERE user_id=? ORDER BY created_at DESC,id DESC LIMIT 4", (uid,))],
        "groups": [group_dict(db, r) for r in db.execute("SELECT * FROM contact_groups WHERE user_id=? ORDER BY id LIMIT 4", (uid,))],
    }


@app.get("/api/reports/export")
def report_export(user=Depends(user_dep), db=Depends(db_dep)):
    stream = io.StringIO()
    writer = csv.writer(stream)
    writer.writerow(["campaign", "audience", "status", "mode", "recipients", "delivered", "read", "failed", "created_at"])
    for row in db.execute("SELECT * FROM campaigns WHERE user_id=? ORDER BY id", (user["id"],)):
        item = campaign_dict(db, row)
        safe = lambda v: "'" + str(v) if str(v).startswith(("=", "+", "-", "@")) else v
        writer.writerow([safe(item[k]) for k in ["name", "audience", "status", "mode", "total", "delivered", "read", "failed", "created_at"]])
    return Response(stream.getvalue(), media_type="text/csv", headers={"Content-Disposition": 'attachment; filename="relay-campaign-report.csv"'})


@app.get("/api/search")
def search(q: str = "", user=Depends(user_dep), db=Depends(db_dep)):
    if len(q.strip()) < 2:
        return {"contacts": [], "campaigns": [], "groups": []}
    query = "%" + q[:80] + "%"
    return {
        "contacts": [dict(r) for r in db.execute("SELECT id,first_name,last_name,phone FROM contacts WHERE user_id=? AND (first_name||' '||last_name LIKE ? OR phone LIKE ?) LIMIT 5", (user["id"], query, query))],
        "campaigns": [dict(r) for r in db.execute("SELECT id,name,status FROM campaigns WHERE user_id=? AND name LIKE ? LIMIT 4", (user["id"], query))],
        "groups": [dict(r) for r in db.execute("SELECT id,name,color FROM contact_groups WHERE user_id=? AND name LIKE ? LIMIT 4", (user["id"], query))],
    }


@app.get("/api/integrations/whatsapp")
def integration_status(user=Depends(user_dep), db=Depends(db_dep)):
    row = db.execute("SELECT phone_number_id,business_account_id,connected_at FROM integrations WHERE user_id=?", (user["id"],)).fetchone()
    return {"connected": bool(row), "mode": "live" if row else "demo", "group_member_access": False, **(dict(row) if row else {})}


class IntegrationData(BaseModel):
    phone_number_id: str = Field(min_length=5, max_length=40)
    business_account_id: str = Field(min_length=5, max_length=40)
    access_token: str = Field(min_length=20, max_length=3000)


@app.post("/api/integrations/whatsapp")
async def connect_whatsapp(payload: IntegrationData, user=Depends(user_dep), db=Depends(db_dep)):
    if user["demo"]:
        raise HTTPException(403, "Create your own workspace to connect real WhatsApp Business credentials. The demo is intentionally isolated.")
    if not payload.phone_number_id.isdigit() or not payload.business_account_id.isdigit():
        raise HTTPException(422, "Meta IDs contain numbers only.")
    verified = await provider.verify_connection(payload.phone_number_id, payload.access_token)
    db.execute("INSERT INTO integrations VALUES(?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET phone_number_id=excluded.phone_number_id,business_account_id=excluded.business_account_id,access_token=excluded.access_token,connected_at=excluded.connected_at", (user["id"], payload.phone_number_id, payload.business_account_id, provider.encrypt(payload.access_token), now()))
    activity(db, user["id"], "WhatsApp Business connected", verified.get("display_phone_number", "Verified business phone"), "workspace")
    db.commit()
    return {"connected": True, "display_phone_number": verified.get("display_phone_number", ""), "verified_name": verified.get("verified_name", "")}


@app.delete("/api/integrations/whatsapp")
def disconnect_whatsapp(user=Depends(user_dep), db=Depends(db_dep)):
    if db.execute("SELECT 1 FROM campaigns WHERE user_id=? AND mode='live' AND status IN ('Sending','Scheduled')", (user["id"],)).fetchone():
        raise HTTPException(409, "Cancel active live campaigns before disconnecting WhatsApp.")
    db.execute("DELETE FROM integrations WHERE user_id=?", (user["id"],))
    db.commit()
    return {"connected": False}


@app.post("/api/templates/sync")
async def sync_templates(user=Depends(user_dep), db=Depends(db_dep)):
    integration = db.execute("SELECT * FROM integrations WHERE user_id=?", (user["id"],)).fetchone()
    if not integration:
        raise HTTPException(422, "Connect WhatsApp Business to sync approved templates.")
    data = await provider.list_templates(integration["business_account_id"], provider.decrypt(integration["access_token"]))
    synced = 0
    for t in data:
        components = t.get("components", [])
        body = next((c.get("text", "") for c in components if c.get("type") == "BODY"), "")
        # Sending implementation intentionally supports text-body-only templates.
        if not body or any(c.get("type") in ["HEADER", "BUTTONS", "CAROUSEL"] for c in components):
            continue
        count = len(set(re.findall(r"\{\{\d+\}\}", body)))
        if count > 5 or re.search(r"\{\{[^\d]", body):
            continue
        name = t.get("name", "")
        status = "Approved" if t.get("status") == "APPROVED" else "Pending" if t.get("status") == "PENDING" else "Rejected"
        existing = db.execute("SELECT id FROM templates WHERE user_id=? AND name=?", (user["id"], name)).fetchone()
        if existing:
            db.execute("UPDATE templates SET body=?,category=?,language=?,status=?,meta_id=?,variable_count=?,updated_at=? WHERE id=?",
                       (body, t.get("category", "MARKETING"), t.get("language", "en"), status, t.get("id"), count, now(), existing[0]))
        else:
            db.execute("INSERT INTO templates(user_id,title,name,body,category,language,status,meta_id,variable_count,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                       (user["id"], name.replace("_", " ").title(), name, body, t.get("category", "MARKETING"), t.get("language", "en"), status, t.get("id"), count, now(), now()))
        synced += 1
    db.commit()
    return {"synced": synced, "note": "Only text-body templates with numbered variables are supported."}


@app.get("/api/webhooks/whatsapp")
def verify_webhook(request: Request):
    token = os.getenv("WHATSAPP_VERIFY_TOKEN")
    if token and request.query_params.get("hub.mode") == "subscribe" and secrets.compare_digest(request.query_params.get("hub.verify_token", ""), token):
        return Response(request.query_params.get("hub.challenge", ""), media_type="text/plain")
    raise HTTPException(403, "Webhook verification failed.")


@app.post("/api/webhooks/whatsapp")
async def whatsapp_webhook(request: Request, db=Depends(db_dep)):
    secret = os.getenv("WHATSAPP_APP_SECRET")
    raw = await request.body()
    if len(raw) > 1_000_000:
        raise HTTPException(413, "Webhook body too large.")
    if not secret:
        raise HTTPException(503, "Configure WHATSAPP_APP_SECRET before accepting webhooks.")
    expected = "sha256=" + hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest()
    if not secrets.compare_digest(expected, request.headers.get("X-Hub-Signature-256", "")):
        raise HTTPException(403, "Invalid webhook signature.")
    try:
        payload = json.loads(raw)
        for entry in payload.get("entry", []):
            for change in entry.get("changes", []):
                value = change.get("value", {})
                phone_id = value.get("metadata", {}).get("phone_number_id")
                integration = db.execute("SELECT user_id FROM integrations WHERE phone_number_id=?", (phone_id,)).fetchone()
                if not integration:
                    continue
                for status in value.get("statuses", []):
                    state = status.get("status")
                    if state not in ["sent", "delivered", "read", "failed"]:
                        continue
                    row = db.execute("SELECT m.id,m.status FROM messages m JOIN campaigns c ON c.id=m.campaign_id WHERE m.provider_id=? AND c.user_id=?", (status.get("id"), integration[0])).fetchone()
                    if not row:
                        continue
                    ranks = {"queued": 0, "processing": 0, "sent": 1, "delivered": 2, "read": 3, "failed": 0}
                    if state != "failed" and ranks.get(state, 0) < ranks.get(row["status"], 0):
                        continue
                    if state == "failed" and row["status"] in ["delivered", "read"]:
                        continue
                    error = status.get("errors", [{}])[0].get("title", "") if state == "failed" else ""
                    db.execute("UPDATE messages SET status=?,error=?,updated_at=? WHERE id=?", (state, error, now(), row["id"]))
                for message in value.get("messages", []):
                    text = message.get("text", {}).get("body", "").strip().upper()
                    if text in ["STOP", "UNSUBSCRIBE", "CANCEL", "OPT OUT"]:
                        phone = "+" + message.get("from", "").lstrip("+")
                        db.execute("UPDATE contacts SET consent_status='unsubscribed',updated_at=? WHERE user_id=? AND phone=?", (now(), integration[0], phone))
        db.commit()
    except (ValueError, TypeError, KeyError):
        raise HTTPException(400, "Invalid webhook payload.")
    return {"ok": True}


# The same host serves API and app, including Arena's HTTPS preview host.
# No localhost URLs are embedded in browser-facing code.
if WEB.exists():
    app.mount("/assets", StaticFiles(directory=WEB / "assets"), name="assets")


@app.get("/{path:path}", include_in_schema=False)
def frontend(path: str):
    if path.startswith("api/"):
        raise HTTPException(404, "API endpoint not found.")
    target = (WEB / path).resolve()
    if target.is_relative_to(WEB.resolve()) and target.is_file():
        return FileResponse(target)
    index = WEB / "index.html"
    if index.exists():
        return FileResponse(index, headers={"Cache-Control": "no-cache"})
    return JSONResponse({"message": "Relay API is running. Build the Flutter app with scripts/build_web.sh to serve the interface.", "docs": "/docs"})
