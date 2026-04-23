import json
import os
import unittest
import urllib.request

BASE_URL = os.environ.get('CARTLY_LIVE_API_BASE_URL', 'http://127.0.0.1:8011')
ADMIN_TOKEN = os.environ.get('ADMIN_TOKEN', '').strip()
ENABLED = os.environ.get('CARTLY_LIVE_ADMIN_SMOKE') == '1' and bool(ADMIN_TOKEN)


@unittest.skipUnless(
    ENABLED,
    'set CARTLY_LIVE_ADMIN_SMOKE=1 and ADMIN_TOKEN to run live admin smoke tests',
)
class LiveAdminSmokeTests(unittest.TestCase):
    def _json(self, path: str):
        request = urllib.request.Request(f'{BASE_URL}{path}')
        request.add_header('Authorization', f'Bearer {ADMIN_TOKEN}')
        request.add_header('Accept', 'application/json')
        with urllib.request.urlopen(request, timeout=10) as response:
            self.assertGreaterEqual(response.status, 200)
            self.assertLess(response.status, 300)
            return json.loads(response.read().decode('utf-8'))

    def test_dashboard_summary_endpoint(self):
        payload = self._json('/admin/dashboard/summary')

        self.assertTrue(payload['ok'])
        self.assertIn('data', payload)
        self.assertIsInstance(payload['data'], dict)

    def test_dashboard_period_summary_endpoint(self):
        payload = self._json('/admin/dashboard/period-summary?period=month')

        self.assertTrue(payload['ok'])
        self.assertIn('data', payload)
        self.assertIsInstance(payload['data'], dict)


if __name__ == '__main__':
    unittest.main()
