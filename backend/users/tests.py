import uuid

from rest_framework.test import APITestCase


class AuthEndpointsTest(APITestCase):
    def _register_payload(self):
        unique = uuid.uuid4().hex[:8]
        return {
            "email": f"test_{unique}@example.com",
            "username": f"testuser_{unique}",
            "password": "Str0ngPassw0rd!",
            "type": "CUSTOMER",
        }

    def test_register_endpoint_auth_path(self):
        resp = self.client.post("/api/auth/register/", self._register_payload(), format="json")
        self.assertEqual(resp.status_code, 201, resp.data)

    def test_register_endpoint_legacy_path(self):
        resp = self.client.post("/api/register/", self._register_payload(), format="json")
        self.assertEqual(resp.status_code, 201, resp.data)

    def test_login_endpoint_auth_and_legacy_paths(self):
        payload = self._register_payload()
        self.client.post("/api/auth/register/", payload, format="json")

        login_payload = {"email": payload["email"], "password": payload["password"]}
        resp_auth = self.client.post("/api/auth/login/", login_payload, format="json")
        self.assertEqual(resp_auth.status_code, 200, resp_auth.data)
        self.assertIn("access", resp_auth.data)
        self.assertIn("refresh", resp_auth.data)

        resp_legacy = self.client.post("/api/login/", login_payload, format="json")
        self.assertEqual(resp_legacy.status_code, 200, resp_legacy.data)
        self.assertIn("access", resp_legacy.data)
        self.assertIn("refresh", resp_legacy.data)
