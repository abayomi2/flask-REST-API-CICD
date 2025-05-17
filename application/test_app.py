import unittest
import json
from app import app # Import the Flask app instance from your main app.py

class FlaskAppTests(unittest.TestCase):

    def setUp(self):
        """Set up a test client for each test."""
        self.app = app.test_client()
        self.app.testing = True 

    def tearDown(self):
        """Clean up after each test."""
        pass # Nothing to tear down in this case

    # --- Test Root and Health Endpoints ---
    def test_01_home_page_status_code(self):
        """Test the home page returns a 200 OK status."""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"DevOps Project Showcase", response.data) # Check for some content

    def test_02_health_check_status_code(self):
        """Test the health check endpoint returns a 200 OK status."""
        response = self.app.get('/api/v1/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.get_data(as_text=True))
        self.assertEqual(data['status'], 'healthy')

    # --- Test /api/v1/devices/<user_id> ---
    def test_03_get_user_devices_success(self):
        """Test getting devices for a known user."""
        response = self.app.get('/api/v1/devices/user123')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.get_data(as_text=True))
        self.assertEqual(data['user_id'], 'user123')
        self.assertIsInstance(data['devices'], list)
        self.assertTrue(len(data['devices']) > 0)

    def test_04_get_user_devices_not_found(self):
        """Test getting devices for an unknown user returns 404."""
        response = self.app.get('/api/v1/devices/unknownuser999')
        self.assertEqual(response.status_code, 404)
        data = json.loads(response.get_data(as_text=True))
        self.assertIn('error', data)
        self.assertEqual(data['error'], 'User not found')

    # --- Test /api/v1/devices/<device_id>/status ---
    def test_05_get_device_status_success(self):
        """Test getting status for a known device."""
        response = self.app.get('/api/v1/devices/laptop001/status')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.get_data(as_text=True))
        self.assertEqual(data['device_id'], 'laptop001')
        self.assertIn('status', data)

    def test_06_get_device_status_not_found(self):
        """Test getting status for an unknown device returns 404."""
        response = self.app.get('/api/v1/devices/unknown_device_xyz/status')
        self.assertEqual(response.status_code, 404)
        data = json.loads(response.get_data(as_text=True))
        self.assertIn('error', data)
        self.assertEqual(data['error'], 'Device not found')
        
    # --- Test /api/v1/devices/<device_id>/request_software ---
    def test_07_request_software_success(self):
        """Test successfully requesting software for a known device."""
        payload = {"software_name": "TestApp", "version": "1.0"}
        response = self.app.post('/api/v1/devices/laptop001/request_software',
                                  data=json.dumps(payload),
                                  content_type='application/json')
        self.assertEqual(response.status_code, 201) # 201 Created
        data = json.loads(response.get_data(as_text=True))
        self.assertIn('request_id', data)
        self.assertEqual(data['details']['software_name'], 'TestApp')
        self.assertEqual(data['details']['status'], 'pending_approval')

    def test_08_request_software_device_not_found(self):
        """Test requesting software for an unknown device returns 404."""
        payload = {"software_name": "TestApp"}
        response = self.app.post('/api/v1/devices/unknown_device_xyz/request_software',
                                  data=json.dumps(payload),
                                  content_type='application/json')
        self.assertEqual(response.status_code, 404)
        data = json.loads(response.get_data(as_text=True))
        self.assertEqual(data['error'], 'Device not found')

    def test_09_request_software_missing_payload_field(self):
        """Test requesting software with missing 'software_name' returns 400."""
        payload = {"version": "1.0"} # Missing software_name
        response = self.app.post('/api/v1/devices/laptop001/request_software',
                                  data=json.dumps(payload),
                                  content_type='application/json')
        self.assertEqual(response.status_code, 400) # Bad Request
        data = json.loads(response.get_data(as_text=True))
        self.assertEqual(data['error'], "Missing 'software_name' in request body")

    def test_10_request_software_empty_payload(self):
        """Test requesting software with an empty payload returns 400."""
        response = self.app.post('/api/v1/devices/laptop001/request_software',
                                  data=json.dumps({}),
                                  content_type='application/json')
        self.assertEqual(response.status_code, 400) # Bad Request
        data = json.loads(response.get_data(as_text=True))
        self.assertEqual(data['error'], "Missing 'software_name' in request body")

if __name__ == '__main__':
    unittest.main()
