import json
import os
import unittest
import urllib.request
import uuid
from typing import Optional

BASE_URL = os.environ.get('CARTLY_LIVE_API_BASE_URL', 'http://127.0.0.1:8011')
ENABLED = os.environ.get('CARTLY_LIVE_CARTS_SMOKE') == '1'


@unittest.skipUnless(ENABLED, 'set CARTLY_LIVE_CARTS_SMOKE=1 to run live carts smoke tests')
class LiveCartsSmokeTests(unittest.TestCase):
    def _request(self, method: str, path: str, *, token: Optional[str] = None, body: Optional[dict] = None):
        data = json.dumps(body).encode('utf-8') if body is not None else None
        request = urllib.request.Request(f'{BASE_URL}{path}', data=data, method=method)
        request.add_header('Accept', 'application/json')
        if body is not None:
            request.add_header('Content-Type', 'application/json')
        if token:
            request.add_header('Authorization', f'Bearer {token}')
        with urllib.request.urlopen(request, timeout=10) as response:
            self.assertGreaterEqual(response.status, 200)
            self.assertLess(response.status, 300)
            return json.loads(response.read().decode('utf-8'))

    def _guest_session(self):
        return self._request(
            'POST',
            '/v1/auth/guest',
            body={
                'deviceId': f'live-smoke-{uuid.uuid4().hex}',
                'platform': 'ios',
                'appVersion': 'live-smoke',
            },
        )

    def test_guest_cart_crud_flow(self):
        login = self._guest_session()
        token = login['data']['session']['token']
        created_cart_id = None

        try:
            list_before = self._request('GET', '/v1/carts', token=token)
            self.assertTrue(list_before['ok'])
            self.assertIsInstance(list_before['data']['carts'], list)

            created = self._request(
                'POST',
                '/v1/carts',
                token=token,
                body={
                    'title': 'Live smoke temp cart',
                    'items': [
                        {'name': 'Smoke Apple', 'price': 1500, 'quantity': 2},
                    ],
                },
            )
            self.assertTrue(created['ok'])
            created_cart = created['data']['cart']
            created_cart_id = created_cart['id']
            self.assertEqual(created_cart['title'], 'Live smoke temp cart')

            fetched = self._request('GET', f'/v1/carts/{created_cart_id}', token=token)
            self.assertTrue(fetched['ok'])
            self.assertEqual(fetched['data']['cart']['id'], created_cart_id)

            updated = self._request(
                'PATCH',
                f'/v1/carts/{created_cart_id}',
                token=token,
                body={
                    'title': 'Live smoke updated cart',
                    'items': [
                        {'name': 'Smoke Banana', 'price': 2200, 'quantity': 1},
                    ],
                },
            )
            self.assertTrue(updated['ok'])
            self.assertEqual(updated['data']['cart']['title'], 'Live smoke updated cart')

        finally:
            if created_cart_id:
                deleted = self._request('DELETE', f'/v1/carts/{created_cart_id}', token=token)
                self.assertTrue(deleted['ok'])
                self.assertEqual(deleted['data']['cartId'], created_cart_id)


if __name__ == '__main__':
    unittest.main()
