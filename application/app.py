from flask import Flask, jsonify, request
import os

app = Flask(__name__)

# --- Mock Data ---
# In a real application, this would come from a database or external system.
mock_user_devices = {
    "user123": [
        {"device_id": "laptop001", "type": "Laptop", "model": "ThinkPad X1"},
        {"device_id": "mobile002", "type": "Mobile", "model": "Pixel 8 Pro"}
    ],
    "user456": [
        {"device_id": "laptop003", "type": "Laptop", "model": "MacBook Pro 16"},
    ]
}

mock_device_status = {
    "laptop001": {"status": "compliant", "last_seen": "2025-05-17T10:00:00Z", "os_version": "Windows 11 Enterprise 23H2"},
    "mobile002": {"status": "non-compliant", "reason": "Pending OS Update", "last_seen": "2025-05-17T08:30:00Z", "os_version": "Android 14"},
    "laptop003": {"status": "compliant", "last_seen": "2025-05-16T15:00:00Z", "os_version": "macOS Sonoma 14.5"}
}

mock_software_requests = {}

# --- API Endpoints ---

@app.route('/')
def hello_world():
    """
    Root endpoint for basic application status.
    """
    version = os.environ.get('APP_VERSION', "1.0")
    return f'Hello, DevOps World! Version {version} - Deployed via Jenkins to EKS! Welcome to the End-User Device Integration API.'

@app.route('/api/v1/health', methods=['GET'])
def health_check():
    """
    Health check endpoint.
    """
    return jsonify({"status": "healthy", "message": "API is up and running"}), 200

@app.route('/api/v1/devices/<string:user_id>', methods=['GET'])
def get_user_devices(user_id):
    """
    Get a list of devices for a given user_id.
    """
    if user_id in mock_user_devices:
        return jsonify({"user_id": user_id, "devices": mock_user_devices[user_id]}), 200
    else:
        return jsonify({"error": "User not found"}), 404

@app.route('/api/v1/devices/<string:device_id>/status', methods=['GET'])
def get_device_status(device_id):
    """
    Get the status of a specific device.
    """
    if device_id in mock_device_status:
        return jsonify({"device_id": device_id, **mock_device_status[device_id]}), 200
    else:
        return jsonify({"error": "Device not found"}), 404

@app.route('/api/v1/devices/<string:device_id>/request_software', methods=['POST'])
def request_software(device_id):
    """
    Simulate a software request for a device.
    Expects a JSON payload like: {"software_name": "ExampleApp", "version": "2.1"}
    """
    if device_id not in mock_device_status: # Check if device exists in our system
        return jsonify({"error": "Device not found"}), 404

    data = request.get_json()
    if not data or 'software_name' not in data:
        return jsonify({"error": "Missing 'software_name' in request body"}), 400

    software_name = data.get('software_name')
    software_version = data.get('version', 'latest') # Optional version

    request_id = f"req_{len(mock_software_requests) + 1}" # Simple unique ID for the mock request
    mock_software_requests[request_id] = {
        "device_id": device_id,
        "software_name": software_name,
        "software_version": software_version,
        "status": "pending_approval" # Initial status
    }

    return jsonify({
        "message": "Software request submitted successfully.",
        "request_id": request_id,
        "details": mock_software_requests[request_id]
    }), 201 # 201 Created

if __name__ == '__main__':
    # It's good practice to get port from environment variable for containerized apps
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
