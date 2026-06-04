import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

from app import main
from app.routers import explore, receipts


class ApiSmokeTests(unittest.TestCase):
    def test_health_payload_reports_expected_shape(self):
        storage_payload = {
            'writable': True,
            'paths': {'root': '/tmp/cartly-test'},
            'errors': [],
        }
        surface_payload = {
            'serviceName': 'Cartly API',
            'storageRootDisplay': '/tmp/cartly-test',
            'storageRootActual': '/tmp/cartly-test',
            'runtimeAssetsRootDisplay': '/tmp/cartly-assets',
            'runtimeAssetsRootActual': '/tmp/cartly-assets',
            'brandingAssetsDirDisplay': '/tmp/cartly-assets/branding',
            'brandingAssetsDirActual': '/tmp/cartly-assets/branding',
            'adsAssetsDirDisplay': '/tmp/cartly-assets/ads',
            'adsAssetsDirActual': '/tmp/cartly-assets/ads',
            'legacyPathCompatibilityActive': False,
        }

        with patch.object(main, 'storage_health_check', return_value=storage_payload), patch.object(
            main,
            'runtime_surface_labels',
            return_value=surface_payload,
        ):
            payload = main.health()

        self.assertTrue(payload['ok'])
        self.assertTrue(payload['storageWritable'])
        self.assertEqual(payload['service'], 'cartly-api')
        self.assertEqual(payload['storagePaths'], storage_payload['paths'])

    def test_receipt_auth_guard_rejects_missing_user(self):
        with self.assertRaises(HTTPException) as ctx:
            receipts._require_current_user(None)

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.detail['code'], 'UNAUTHORIZED')

    def test_receipt_auth_guard_passes_through_user(self):
        user = SimpleNamespace(id='user-1')
        self.assertIs(receipts._require_current_user(user), user)

    def test_explore_auth_guard_rejects_missing_user(self):
        with self.assertRaises(HTTPException) as ctx:
            explore._require_current_user(None)

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.detail['code'], 'UNAUTHORIZED')

    def test_explore_auth_guard_passes_through_user(self):
        user = SimpleNamespace(id='user-1')
        self.assertIs(explore._require_current_user(user), user)


if __name__ == '__main__':
    unittest.main()
