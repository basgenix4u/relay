"""Integration tests use a disposable SQLite workspace, never the preview database."""
import os
import json
import hashlib
import hmac
from datetime import datetime, timedelta, timezone
import tempfile
import time
import unittest
from pathlib import Path
from uuid import uuid4

_test_dir = tempfile.TemporaryDirectory(prefix='relay-test-', dir='/home/user/.cache' if Path('/home/user/.cache').exists() else None)
os.environ['RELAY_DATA_DIR'] = _test_dir.name
from fastapi.testclient import TestClient
from backend.app import app


class RelayApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.context = TestClient(app)
        cls.client = cls.context.__enter__()

    @classmethod
    def tearDownClass(cls):
        cls.context.__exit__(None, None, None)
        _test_dir.cleanup()

    def setUp(self):
        result = self.client.post('/api/auth/register', json={'name': 'Test Owner', 'email': f'{uuid4()}@test.example', 'password': 'Testing@123', 'workspace': 'Test Studio'})
        self.assertEqual(result.status_code, 201, result.text)
        self.headers = {'Authorization': 'Bearer ' + result.json()['token']}

    def contact(self, **changes):
        data = {'first_name': 'Amara', 'last_name': 'Okafor', 'phone': '+12025550123', 'consent_status': 'opted_in', 'consent_source': 'Explicit event sign-up'}
        data.update(changes)
        response = self.client.post('/api/contacts', json=data, headers=self.headers)
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()

    def test_auth_isolation_and_logout(self):
        self.assertEqual(self.client.get('/api/contacts').status_code, 401)
        contact = self.contact()
        other = self.client.post('/api/auth/register', json={'name': 'Other Owner', 'email': f'{uuid4()}@test.example', 'password': 'Testing@123', 'workspace': 'Other Studio'}).json()
        other_headers = {'Authorization': 'Bearer ' + other['token']}
        self.assertEqual(self.client.get('/api/contacts', headers=other_headers).json()['total'], 0)
        self.assertEqual(self.client.delete(f"/api/contacts/{contact['id']}", headers=other_headers).status_code, 404)
        self.client.post('/api/auth/logout', headers=self.headers)
        self.assertEqual(self.client.get('/api/auth/me', headers=self.headers).status_code, 401)

    def test_contacts_crud_and_consent_validation(self):
        bad = self.client.post('/api/contacts', json={'first_name': 'No consent', 'phone': '+12025550122', 'consent_status': 'opted_in'}, headers=self.headers)
        self.assertEqual(bad.status_code, 422)
        bad_phone = self.client.post('/api/contacts', json={'first_name': 'Local', 'phone': '08031234567'}, headers=self.headers)
        self.assertEqual(bad_phone.status_code, 422)
        c = self.contact()
        self.assertEqual(self.client.post('/api/contacts', json={'first_name': 'Duplicate', 'phone': c['phone']}, headers=self.headers).status_code, 409)
        update = self.client.put(f"/api/contacts/{c['id']}", json={'first_name': 'Updated', 'phone': c['phone'], 'consent_status': 'unsubscribed'}, headers=self.headers)
        self.assertEqual(update.json()['consent_status'], 'unsubscribed')
        self.assertEqual(self.client.get('/api/contacts', params={'q': 'Updated'}, headers=self.headers).json()['total'], 1)
        self.assertEqual(self.client.delete(f"/api/contacts/{c['id']}", headers=self.headers).status_code, 200)
        self.assertEqual(self.client.get('/api/contacts', headers=self.headers).json()['total'], 0)

    def test_csv_preview_import_duplicates_and_export(self):
        csv = b'first_name,last_name,phone,email,consent_status\nSarah,Johnson,+12025550110,sarah@demo.example,opted_in\nWrong,Number,080123,wrong@demo.example,pending\n'
        preview = self.client.post('/api/contacts/import-preview', files={'file': ('test.csv', csv, 'text/csv')}, headers=self.headers).json()
        self.assertEqual((preview['valid'], preview['invalid']), (1, 1))
        payload = {'contacts': preview['contacts'], 'has_consent': False}
        imported = self.client.post('/api/contacts/import', json=payload, headers=self.headers)
        self.assertEqual(imported.json()['imported'], 1)
        contacts = self.client.get('/api/contacts', headers=self.headers).json()['items']
        self.assertEqual(contacts[0]['consent_status'], 'pending')
        payload.update(has_consent=True, consent_source='A real permission record')
        result = self.client.post('/api/contacts/import', json=payload, headers=self.headers).json()
        self.assertEqual(result['duplicates'], 1)
        self.assertEqual(self.client.get('/api/contacts', headers=self.headers).json()['items'][0]['consent_status'], 'pending')
        vcf = self.client.get('/api/contacts/export', headers=self.headers)
        self.assertIn('BEGIN:VCARD', vcf.text)
        self.assertIn('TEL;TYPE=CELL:+12025550110', vcf.text)
        self.assertEqual(vcf.headers['x-contact-count'], '1')
        exported = self.client.get('/api/contacts/export?format=csv', headers=self.headers)
        self.assertEqual(exported.status_code, 200)
        roundtrip = self.client.post('/api/contacts/import-preview', files={'file': ('exported.csv', exported.content, 'text/csv')}, headers=self.headers)
        self.assertEqual(roundtrip.json()['valid'], 1)

    def test_group_crud_preserves_contacts_and_scopes_audience(self):
        group = self.client.post('/api/groups', json={'name': 'Abuja founders', 'description': 'Opt-in community'}, headers=self.headers).json()
        c = self.contact(group_ids=[group['id']])
        listed = self.client.get('/api/groups', headers=self.headers).json()['items'][0]
        self.assertEqual((listed['total'], listed['opted_in']), (1, 1))
        self.client.put(f"/api/groups/{group['id']}", json={'name': 'Renamed community'}, headers=self.headers)
        self.assertEqual(self.client.get('/api/groups', headers=self.headers).json()['items'][0]['name'], 'Renamed community')
        self.client.delete(f"/api/groups/{group['id']}", headers=self.headers)
        self.assertEqual(self.client.get('/api/contacts', headers=self.headers).json()['total'], 1)

    def test_campaigns_templates_simulated_delivery_and_live_guard(self):
        self.contact()
        self.contact(phone='+12025550124', first_name='Pending', consent_status='pending', consent_source='')
        template = self.client.post('/api/templates', json={'title': 'Hello community', 'name': 'hello_community', 'body': 'Hi {{1}}, welcome! Reply STOP to opt out.'}, headers=self.headers).json()
        self.assertEqual(template['status'], 'Draft')
        campaign = self.client.post('/api/campaigns', json={'name': 'Our first hello', 'template_id': template['id']}, headers=self.headers)
        self.assertEqual(campaign.status_code, 201, campaign.text)
        cid = campaign.json()['id']
        self.assertEqual(campaign.json()['audience_count'], 1)
        self.assertEqual(self.client.post(f'/api/campaigns/{cid}/send', json={}, headers=self.headers).status_code, 200)
        self.assertEqual(self.client.post(f'/api/campaigns/{cid}/send', json={}, headers=self.headers).status_code, 409)
        time.sleep(2.4)
        completed = self.client.get(f'/api/campaigns/{cid}', headers=self.headers).json()
        self.assertEqual((completed['status'], completed['total']), ('Completed', 1))
        self.assertEqual(self.client.put(f'/api/campaigns/{cid}', json={'name': 'Edit sent', 'message': 'No'}, headers=self.headers).status_code, 409)
        copy = self.client.post(f'/api/campaigns/{cid}/duplicate', headers=self.headers).json()
        self.assertEqual(copy['status'], 'Draft')
        self.assertEqual(self.client.delete(f"/api/campaigns/{copy['id']}", headers=self.headers).status_code, 200)
        self.assertEqual(self.client.get('/api/dashboard', headers=self.headers).json()['messages_sent'], 1)
        live = self.client.post('/api/campaigns', json={'name': 'Not connected', 'template_id': template['id'], 'mode': 'live'}, headers=self.headers)
        self.assertEqual(live.status_code, 422)
        self.client.put(f"/api/templates/{template['id']}", json={'title': 'Updated', 'name': 'updated_template', 'body': 'Hi {{1}}, thank you!'}, headers=self.headers)
        self.assertEqual(self.client.get('/api/templates', headers=self.headers).json()['items'][0]['title'], 'Updated')
        self.assertEqual(self.client.delete(f"/api/templates/{template['id']}", headers=self.headers).status_code, 200)
        self.assertEqual(self.client.get('/api/reports/export', headers=self.headers).status_code, 200)

    def test_demo_is_populated_and_cannot_send_live(self):
        token = self.client.post('/api/auth/demo').json()['token']
        h = {'Authorization': 'Bearer ' + token}
        d = self.client.get('/api/dashboard', headers=h).json()
        self.assertEqual(d['total_contacts'], 2486)
        self.assertGreater(d['messages_sent'], 7000)
        self.assertEqual(len(d['chart']), 7)
        self.assertTrue(self.client.get('/api/contacts', headers=h).json()['items'][0]['is_demo'])
        self.assertFalse(self.client.get('/api/integrations/whatsapp', headers=h).json()['group_member_access'])
        self.assertEqual(self.client.post('/api/campaigns', json={'name': 'No live', 'message': 'Hello', 'mode': 'live'}, headers=h).status_code, 403)


    def test_demo_markers_survive_csv_roundtrip(self):
        original = self.contact(phone='+2348009999999', is_demo=True)
        self.assertTrue(original['is_demo'])
        exported = self.client.get('/api/contacts/export?format=csv', headers=self.headers)
        preview = self.client.post('/api/contacts/import-preview', files={'file': ('demo.csv', exported.content, 'text/csv')}, headers=self.headers).json()
        self.assertTrue(preview['contacts'][0]['is_demo'])
        updated = self.client.put(f"/api/contacts/{original['id']}", json={'first_name': 'Still fictional', 'phone': original['phone'], 'is_demo': False}, headers=self.headers)
        self.assertTrue(updated.json()['is_demo'])

    def test_scheduling_cancel_and_live_confirmation(self):
        from backend.database import connect, now
        from backend.provider import encrypt
        contact = self.contact()
        group = self.client.post('/api/groups', json={'name': 'Scheduled group'}, headers=self.headers).json()
        template = self.client.post('/api/templates', json={'title': 'A scheduled hello', 'name': 'scheduled_hello', 'body': 'Hi {{1}}, hello! Reply STOP to opt out.'}, headers=self.headers).json()
        scheduled = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
        data = {'name': 'Future campaign', 'template_id': template['id'], 'group_id': group['id'], 'scheduled_at': scheduled}
        campaign = self.client.post('/api/campaigns', json=data, headers=self.headers).json()
        self.assertEqual(campaign['status'], 'Scheduled')
        self.assertEqual(self.client.delete(f"/api/groups/{group['id']}", headers=self.headers).status_code, 409)
        self.assertEqual(self.client.delete(f"/api/templates/{template['id']}", headers=self.headers).status_code, 409)
        self.assertEqual(self.client.post(f"/api/campaigns/{campaign['id']}/cancel", headers=self.headers).status_code, 200)
        # Mock a provider-verified integration and approval; no request goes to Meta.
        uid = self.client.get('/api/auth/me', headers=self.headers).json()['id']
        db = connect()
        db.execute("INSERT INTO integrations VALUES(?,?,?,?,?)", (uid, '1234567890', '9876543210', encrypt('fake-test-token-never-used'), now()))
        db.execute("UPDATE templates SET status='Approved',meta_id='fake-approved-id' WHERE id=?", (template['id'],))
        db.commit(); db.close()
        data.update(mode='live', name='Live scheduling needs confirmation')
        rejected = self.client.post('/api/campaigns', json=data, headers=self.headers)
        self.assertEqual(rejected.status_code, 422)
        self.assertIn('confirmation', rejected.json()['detail'])
        data['confirm_live_schedule'] = True
        accepted = self.client.post('/api/campaigns', json=data, headers=self.headers)
        self.assertEqual(accepted.status_code, 201, accepted.text)
        self.client.post(f"/api/campaigns/{accepted.json()['id']}/cancel", headers=self.headers)
        self.assertEqual(self.client.delete(f"/api/groups/{group['id']}", headers=self.headers).status_code, 200)

    def test_signed_webhook_opt_out_and_status_order(self):
        from backend.database import connect, now
        from backend.provider import encrypt
        contact = self.contact()
        uid = self.client.get('/api/auth/me', headers=self.headers).json()['id']
        db = connect()
        db.execute("INSERT INTO integrations VALUES(?,?,?,?,?)", (uid, '1112223334', '5556667778', encrypt('fake-webhook-test-token'), now()))
        cid = db.execute("INSERT INTO campaigns(user_id,name,message,status,mode,created_at,updated_at) VALUES(?, 'Webhook test', 'Hello','Completed','live',?,?)", (uid, now(), now())).lastrowid
        db.execute("INSERT INTO messages(campaign_id,contact_id,phone,status,provider_id,created_at,updated_at) VALUES(?,?,?,'read','wamid-test-123',?,?)", (cid, contact['id'], contact['phone'], now(), now()))
        db.commit()
        secret = 'test-webhook-secret-only'
        os.environ['WHATSAPP_APP_SECRET'] = secret
        os.environ['WHATSAPP_VERIFY_TOKEN'] = 'test-verify-token'
        try:
            self.assertEqual(self.client.get('/api/webhooks/whatsapp', params={'hub.mode': 'subscribe', 'hub.verify_token': 'test-verify-token', 'hub.challenge': '12345'}).text, '12345')
            payload = {'entry': [{'changes': [{'value': {'metadata': {'phone_number_id': '1112223334'}, 'statuses': [{'id': 'wamid-test-123', 'status': 'delivered'}], 'messages': [{'from': contact['phone'].lstrip('+'), 'text': {'body': 'STOP'}}]}}]}]}
            raw = json.dumps(payload).encode()
            self.assertEqual(self.client.post('/api/webhooks/whatsapp', content=raw).status_code, 403)
            signature = 'sha256=' + hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest()
            valid = self.client.post('/api/webhooks/whatsapp', content=raw, headers={'X-Hub-Signature-256': signature, 'Content-Type': 'application/json'})
            self.assertEqual(valid.status_code, 200)
            self.assertEqual(db.execute("SELECT status FROM messages WHERE provider_id='wamid-test-123'").fetchone()[0], 'read')
            self.assertEqual(self.client.get('/api/contacts', headers=self.headers).json()['items'][0]['consent_status'], 'unsubscribed')
        finally:
            db.close()
            os.environ.pop('WHATSAPP_APP_SECRET', None)
            os.environ.pop('WHATSAPP_VERIFY_TOKEN', None)


if __name__ == '__main__':
    unittest.main(verbosity=2)
