"""Official WhatsApp Cloud API integration. No personal-account or group scraping."""
from __future__ import annotations
import base64
import hashlib
import os
import secrets
from pathlib import Path

import httpx
from cryptography.fernet import Fernet
from fastapi import HTTPException

from .database import DATA

GRAPH_VERSION = os.getenv("META_API_VERSION", "v23.0")
GRAPH_URL = f"https://graph.facebook.com/{GRAPH_VERSION}"


def secret_key() -> bytes:
    configured = os.getenv("RELAY_SECRET_KEY")
    if configured:
        return hashlib.sha256(configured.encode()).digest()
    path = DATA / ".secret"
    if not path.exists():
        path.write_bytes(secrets.token_bytes(32))
        path.chmod(0o600)
    return path.read_bytes()


def cipher() -> Fernet:
    return Fernet(base64.urlsafe_b64encode(secret_key()))


def encrypt(value: str) -> str:
    return cipher().encrypt(value.encode()).decode()


def decrypt(value: str) -> str:
    return cipher().decrypt(value.encode()).decode()


async def graph(method: str, path: str, token: str, payload=None):
    try:
        async with httpx.AsyncClient(timeout=25) as client:
            response = await client.request(method, f"{GRAPH_URL}/{path}", headers={"Authorization": f"Bearer {token}"}, json=payload)
        data = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(502, "WhatsApp could not be reached. Please try again later.") from exc
    if response.status_code >= 400:
        message = data.get("error", {}).get("message", "WhatsApp rejected the request.")
        raise HTTPException(400, message)
    return data


async def verify_connection(phone_id: str, token: str):
    return await graph("GET", f"{phone_id}?fields=display_phone_number,verified_name", token)


async def list_templates(business_id: str, token: str):
    # Cursor pagination is used without following arbitrary URLs supplied by a remote response.
    result = []
    after = None
    for _ in range(50):
        path = f"{business_id}/message_templates?limit=100"
        if after:
            from urllib.parse import quote
            path += "&after=" + quote(after, safe="")
        page = await graph("GET", path, token)
        result.extend(page.get("data", []))
        if not page.get("paging", {}).get("next"):
            break
        after = page.get("paging", {}).get("cursors", {}).get("after")
        if not after:
            break
    return result


async def send_template(phone_id: str, token: str, phone: str, name: str, language: str, values: list[str]):
    payload = {
        "messaging_product": "whatsapp", "to": phone.lstrip("+"), "type": "template",
        "template": {"name": name, "language": {"code": language}},
    }
    if values:
        payload["template"]["components"] = [{"type": "body", "parameters": [{"type": "text", "text": v} for v in values]}]
    data = await graph("POST", f"{phone_id}/messages", token, payload)
    return data.get("messages", [{}])[0].get("id")
