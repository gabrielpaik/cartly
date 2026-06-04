import json
import os
import unittest
import urllib.error
import urllib.request

BASE_URL = os.environ.get('CARTLY_LIVE_API_BASE_URL', 'http://127.0.0.1:8011')
ENABLED = os.environ.get('CARTLY_LIVE_API_SMOKE') == '1'
USER_AGENT = os.environ.get('CARTLY_LIVE_SMOKE_USER_AGENT', 'curl/8.7.1').strip() or 'curl/8.7.1'


@unittest.skipUnless(ENABLED, 'set CARTLY_LIVE_API_SMOKE=1 to run live API smoke tests')
class LiveApiSmokeTests(unittest.TestCase):
    def _request(self, path: str):
        request = urllib.request.Request(f'{BASE_URL}{path}')
        request.add_header('Accept', 'application/json')
        request.add_header('User-Agent', USER_AGENT)
        return request

    def _json(self, path: str):
        with urllib.request.urlopen(self._request(path), timeout=10) as response:
            self.assertGreaterEqual(response.status, 200)
            self.assertLess(response.status, 300)
            return json.loads(response.read().decode('utf-8'))

    def test_health_endpoint(self):
        payload = self._json('/health')

        self.assertTrue(payload['ok'])
        self.assertTrue(payload['storageWritable'])
        self.assertEqual(payload['service'], 'cartly-api')

    def test_app_config_endpoint(self):
        payload = self._json('/v1/app-config')

        self.assertTrue(payload['ok'])
        self.assertIn('data', payload)
        self.assertIsInstance(payload['data'], dict)

    def test_receipt_endpoint_requires_auth(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(self._request('/v1/receipts/test-id'), timeout=10)

        self.assertEqual(ctx.exception.code, 401)
        payload = json.loads(ctx.exception.read().decode('utf-8'))
        self.assertEqual(payload['detail']['code'], 'UNAUTHORIZED')


if __name__ == '__main__':
    unittest.main()
