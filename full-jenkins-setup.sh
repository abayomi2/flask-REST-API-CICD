#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--------------------------------------------------------------------"
echo "Starting Comprehensive Jenkins Server Setup..."
echo "This script will install Jenkins, Java, Docker, AWS CLI, kubectl,"
echo "Python 3, pip, venv, Trivy, Git, and other utilities."
echo "--------------------------------------------------------------------"

# --- Helper Function for Section Headers ---
echo_step() {
    echo ""
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}

# --------------------------------------------------------------------
# 1. UPDATE SYSTEM AND INSTALL PREREQUISITES & GIT
# --------------------------------------------------------------------
echo_step "Updating package lists and installing prerequisites (including Git)..."
sudo apt update -y
sudo apt install -y wget curl gnupg software-properties-common apt-transport-https ca-certificates lsb-release unzip git

# --------------------------------------------------------------------
# 2. INSTALL JAVA (OpenJDK 17) & SET JAVA_HOME
# --------------------------------------------------------------------
echo_step "Installing OpenJDK 17..."
sudo apt install -y openjdk-17-jdk

echo_step "Setting JAVA_HOME environment variable..."
# Attempt to find the Java installation path robustly
JAVA_INSTALL_PATH_TEMP=$(readlink -f $(which java) || true) # Allow command to fail if java not found yet by `which`
if [ -z "$JAVA_INSTALL_PATH_TEMP" ] || [ ! -f "$JAVA_INSTALL_PATH_TEMP" ]; then
    # Fallback if `which java` doesn't work as expected before full path resolution
    # This often happens if java is installed but not yet in the immediate PATH for `which`
    # We'll rely on a common location for OpenJDK or a more direct find.
    # This part might need adjustment based on exact OS/JDK packaging.
    # For OpenJDK 17 on Ubuntu, it's usually in /usr/lib/jvm/java-17-openjdk-amd64
    POSSIBLE_JAVA_PATHS=(
        "/usr/lib/jvm/java-17-openjdk-amd64"
        "/usr/lib/jvm/java-17-openjdk"
        # Add other common paths if needed
    )
    for path_option in "${POSSIBLE_JAVA_PATHS[@]}"; do
        if [ -d "$path_option" ] && [ -f "$path_option/bin/java" ]; then
            JAVA_INSTALL_PATH="$path_option"
            break
        fi
    done
else
    JAVA_INSTALL_PATH=$(dirname $(dirname "$JAVA_INSTALL_PATH_TEMP"))
fi


if [ -z "$JAVA_INSTALL_PATH" ] || [ ! -d "$JAVA_INSTALL_PATH" ]; then
    echo "ERROR: Could not reliably determine Java installation path. Please set JAVA_HOME manually."
    # Attempting a common default for OpenJDK 17
    JAVA_INSTALL_PATH="/usr/lib/jvm/java-17-openjdk-amd64"
    echo "Attempting to use default: $JAVA_INSTALL_PATH"
    if [ ! -d "$JAVA_INSTALL_PATH" ]; then
        echo "ERROR: Default Java path $JAVA_INSTALL_PATH not found. Exiting."
        exit 1
    fi
fi

# Check if JAVA_HOME is already set in /etc/environment, if not, add it
if ! grep -q "JAVA_HOME=" /etc/environment; then
    echo "JAVA_HOME=\"$JAVA_INSTALL_PATH\"" | sudo tee -a /etc/environment > /dev/null
    echo "JAVA_HOME set to $JAVA_INSTALL_PATH in /etc/environment"
else
    echo "JAVA_HOME already seems to be set in /etc/environment."
fi
# Source /etc/environment for the current session (may not be necessary for services started later)
# For the current script execution and subsequent commands:
export JAVA_HOME="$JAVA_INSTALL_PATH"
export PATH="$JAVA_HOME/bin:$PATH"
echo "Verifying Java version..."
java -version
echo "JAVA_HOME currently set to: $JAVA_HOME"

# --------------------------------------------------------------------
# 3. INSTALL JENKINS
# --------------------------------------------------------------------
echo_step "Installing Jenkins..."
# Add Jenkins GPG key (using the current recommended method)
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
# Add Jenkins repository
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list again and install Jenkins
sudo apt update -y
sudo apt install -y jenkins

echo_step "Starting and enabling Jenkins service..."
sudo systemctl enable jenkins
sudo systemctl start jenkins
# Give Jenkins a moment to start up before proceeding (especially before adding jenkins user to docker group)
echo "Waiting for Jenkins to initialize (approx 30-60 seconds)..."
sleep 60 # Increased sleep time
sudo systemctl status jenkins --no-pager || echo "Jenkins status check failed, but continuing script."

# --------------------------------------------------------------------
# 4. INSTALL DOCKER ENGINE
# --------------------------------------------------------------------
echo_step "Installing Docker Engine..."
# Add Docker's official GPG key:
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.asc # Remove if exists to avoid issues
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo_step "Starting and enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker --no-pager

echo_step "Adding current user ($USER) and 'jenkins' user to the docker group..."
# Add current user to docker group
if ! groups $USER | grep -q '\bdocker\b'; then
    sudo usermod -aG docker $USER
    echo "Current user ($USER) added to docker group. You may need to log out and back in for this to take full effect for your interactive shell."
else
    echo "Current user ($USER) is already in the docker group."
fi

# Add jenkins user to docker group
if id "jenkins" &>/dev/null; then
    if ! groups jenkins | grep -q '\bdocker\b'; then
        sudo usermod -aG docker jenkins
        echo "User 'jenkins' added to docker group."
        echo "Restarting Jenkins for group membership to take effect for the Jenkins process..."
        sudo systemctl restart jenkins
    else
        echo "User 'jenkins' is already in the docker group."
    fi
else
    echo "WARNING: User 'jenkins' does not exist yet or Jenkins service hasn't fully created it. This might happen if Jenkins installation had issues."
    echo "If 'jenkins' user exists later, manually run: sudo usermod -aG docker jenkins && sudo systemctl restart jenkins"
fi

# --------------------------------------------------------------------
# 5. INSTALL AWS CLI V2
# --------------------------------------------------------------------
echo_step "Installing AWS CLI v2..."
if command -v aws &> /dev/null; then
    echo "AWS CLI already seems to be installed. Verifying version..."
    aws --version
else
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip # -o to overwrite if exists
    sudo ./aws/install --update
    rm -rf awscliv2.zip aws # Clean up
    echo "AWS CLI v2 installed. Verifying version..."
    aws --version
fi

# --------------------------------------------------------------------
# 6. INSTALL KUBECTL
# --------------------------------------------------------------------
echo_step "Installing kubectl..."
KUBECTL_VERSION="v1.29.5" # Match your EKS version or use a compatible one
if command -v kubectl &> /dev/null && kubectl version --client --output=yaml | grep -q "gitVersion: ${KUBECTL_VERSION}"; then
    echo "kubectl version ${KUBECTL_VERSION} already seems to be installed."
    kubectl version --client
else
    echo "Downloading kubectl version ${KUBECTL_VERSION}..."
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    # Optional: Validate checksum
    # curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
    # echo "$(cat kubectl.sha256) kubectl" | sha256sum --check || (echo "kubectl checksum failed!" && exit 1)
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl* # Clean up
    echo "kubectl installed. Verifying version..."
    kubectl version --client
fi

# --------------------------------------------------------------------
# 7. INSTALL PYTHON 3, PIP, AND VENV
# --------------------------------------------------------------------
echo_step "Installing Python 3, pip, and venv..."
sudo apt install -y python3 python3-pip python3-full # python3-full often includes venv and other common modules
# Determine Python3 minor version for venv package (e.g., python3.12-venv)
PYTHON_VERSION_MINOR=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "Detected Python version: $PYTHON_VERSION_MINOR"
if [ -n "$PYTHON_VERSION_MINOR" ]; then
    sudo apt install -y "python${PYTHON_VERSION_MINOR}-venv"
else
    echo "Could not determine Python minor version, attempting generic python3-venv."
    sudo apt install -y python3-venv # Fallback
fi
echo "Verifying Python and pip versions..."
python3 --version
pip3 --version

# --------------------------------------------------------------------
# 8. INSTALL TRIVY
# --------------------------------------------------------------------
echo_step "Installing Trivy..."
if command -v trivy &> /dev/null; then
    echo "Trivy already seems to be installed. Verifying version..."
    trivy --version
else
    # Add Trivy repository GPG key and repository
    sudo wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list

    sudo apt-get update -y
    sudo apt-get install trivy -y
    echo "Trivy installed. Verifying version..."
    trivy --version
fi

# --------------------------------------------------------------------
# 9. ENABLE PASSWORD AUTHENTICATION FOR SSH (As per earlier request)
# --------------------------------------------------------------------
echo_step "Enabling PasswordAuthentication for SSH (if not already set)..."
# Ensure the lines are uncommented and set to yes
if sudo grep -q "^#\?PasswordAuthentication" /etc/ssh/sshd_config; then
    sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
    echo "PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi

# Check if a restart is needed
if sudo diff /etc/ssh/sshd_config /etc/ssh/sshd_config.bak >/dev/null ; then
    echo "No changes to sshd_config, or no backup to compare. Assuming restart might be needed if changes were made manually."
    # sudo systemctl restart sshd # Be cautious with automated restarts of sshd
else
    echo "sshd_config modified. Restarting SSH service..."
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak # Create a backup before restart
    sudo systemctl restart sshd
fi
echo "PasswordAuthentication for SSH should now be enabled."
echo "WARNING: Enabling password authentication is generally less secure than key-based authentication. Ensure strong passwords are used."


# --------------------------------------------------------------------
# 10. FINAL INSTRUCTIONS
# --------------------------------------------------------------------
echo_step "Comprehensive Setup Complete!"
echo "--------------------------------------------------------------------"
echo "MANUAL STEPS & INFORMATION:"
echo ""
echo "1. Jenkins Initial Admin Password:"
echo "   You can retrieve it by running this command on the server:"
echo "   sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "   Or it might be printed in the Jenkins service log: sudo journalctl -u jenkins -n 100 --no-pager"
echo ""
echo "2. Access Jenkins:"
echo "   Open your web browser and navigate to: http://<your_server_ip>:8080"
echo ""
echo "3. Docker Group Membership:"
echo "   For your current user ($USER), you may need to log out and log back in for Docker group membership to apply without needing 'sudo' for docker commands."
echo "   The Jenkins service has been restarted, so it should have the new group permissions."
echo ""
echo "4. Firewall:"
echo "   If you have a firewall like UFW enabled, ensure ports 8080 (for Jenkins) and 22 (for SSH) are allowed."
echo "   Example for UFW: sudo ufw allow 8080/tcp; sudo ufw allow ssh; sudo ufw enable" # 'allow ssh' is safer than 'allow 22/tcp' if sshd port changes
echo ""
echo "5. AWS CLI Configuration (if not using IAM Role for EC2):"
echo "   If Jenkins is NOT running on an EC2 instance with an IAM role granting EKS access,"
echo "   you will need to configure AWS credentials for the 'jenkins' user:"
echo "   sudo su -s /bin/bash jenkins"
echo "   aws configure"
echo "   It is STRONGLY recommended to use an IAM Role attached to the Jenkins EC2 instance."
echo ""
echo "--------------------------------------------------------------------"

exit 0
