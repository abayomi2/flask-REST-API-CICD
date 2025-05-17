from flask import Flask, jsonify, request, Markup
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

# --- Project Details ---
YOUR_NAME = "Abayomi Oguntiloye" # Your name
PROJECT_TOOLS = [
    "Python (Flask) for the Web Application",
    "Docker for Containerization",
    "Kubernetes (AWS EKS) for Orchestration",
    "Terraform for Infrastructure as Code (AWS EKS Setup)",
    "Jenkins for CI/CD Automation",
    "Git for Version Control",
    "GitHub for Source Code Management & Webhooks",
    "Docker Hub for Docker Image Registry",
    "AWS (EC2 for Jenkins, EKS, Load Balancer, IAM)",
    "AWS CLI for AWS interaction",
    "kubectl for Kubernetes interaction",
    "Bash/Shell for scripting"
]

# --- API Endpoints ---

@app.route('/')
def hello_world():
    """
    Root endpoint - Serves an HTML page detailing the project.
    """
    version = os.environ.get('APP_VERSION', "1.0")

    # HTML content with inline CSS for styling
    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>DevOps Project Showcase</title>
        <style>
            body {{
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                margin: 0;
                padding: 0;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: #ffffff;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                text-align: center;
                padding: 20px;
                box-sizing: border-box;
            }}
            .container {{
                background-color: rgba(0, 0, 0, 0.6);
                padding: 30px 40px;
                border-radius: 15px;
                box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
                max-width: 800px;
                width: 100%;
            }}
            h1 {{
                color: #f0f0f0;
                margin-bottom: 10px;
                font-size: 2.5em;
            }}
            h2 {{
                color: #cfcfcf;
                margin-top: 30px;
                margin-bottom: 15px;
                border-bottom: 2px solid #764ba2;
                padding-bottom: 5px;
                font-size: 1.8em;
            }}
            p {{
                font-size: 1.1em;
                line-height: 1.6;
                margin-bottom: 20px;
            }}
            ul {{
                list-style-type: none;
                padding: 0;
                text-align: left;
                display: inline-block; /* Center the list items */
            }}
            li {{
                background-color: rgba(255, 255, 255, 0.1);
                margin-bottom: 10px;
                padding: 12px 18px;
                border-radius: 8px;
                transition: transform 0.2s ease-in-out, background-color 0.2s ease-in-out;
            }}
            li:hover {{
                transform: translateX(5px);
                background-color: rgba(255, 255, 255, 0.2);
            }}
            .footer {{
                margin-top: 30px;
                font-size: 0.9em;
                color: #cccccc;
            }}
            a {{
                color: #87CEFA; /* Light Sky Blue for links */
                text-decoration: none;
            }}
            a:hover {{
                text-decoration: underline;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>DevOps Project Showcase</h1>
            <p>Implemented by: <strong>{YOUR_NAME}</strong></p>
            <p>Application Version: {version}</p>
            <p>Welcome to this demonstration of an end-to-end CI/CD pipeline deploying a Flask application to AWS EKS!</p>
            
            <h2>Tools & Technologies Used:</h2>
            <ul>
    """
    for tool in PROJECT_TOOLS:
        html_content += f"            <li>{tool}</li>\n"
    
    html_content += """
            </ul>
            <div class="footer">
                <p>This page provides a brief overview. The core functionality includes REST APIs for device integration tasks.</p>
                <p>Explore the API endpoints: 
                    <a href="/api/v1/health">/api/v1/health</a> | 
                    <a href="/api/v1/devices/user123">/api/v1/devices/user123</a>
                </p>
            </div>
        </div>
    </body>
    </html>
    """
    return Markup(html_content) # Use Markup to render HTML

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
