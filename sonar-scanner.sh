#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# SonarScanner CLI version and download details
SCANNER_VERSION="7.1.0.4889"
# Adjusted SCANNER_FILENAME to match the typical extracted directory name
SCANNER_EXTRACTED_DIR_NAME="sonar-scanner-${SCANNER_VERSION}-linux-x64" 
SCANNER_ZIP_FILENAME="sonar-scanner-cli-${SCANNER_VERSION}-linux-x64" # Name of the zip file itself
DOWNLOAD_URL="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${SCANNER_ZIP_FILENAME}.zip"
INSTALL_DIR="/opt" # Common directory for optional software
SYMLINK_PATH="/usr/local/bin/sonar-scanner"

echo "--------------------------------------------------------------------"
echo "Starting SonarScanner CLI ${SCANNER_VERSION} Installation..."
echo "--------------------------------------------------------------------"

# --- Helper Function for Section Headers ---
echo_step() {
    echo ""
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}

# --------------------------------------------------------------------
# 1. CHECK FOR PREREQUISITES (wget, unzip)
# --------------------------------------------------------------------
echo_step "Checking for prerequisites (wget, unzip)..."
if ! command -v wget &> /dev/null; then
    echo "wget could not be found. Please install wget."
    echo "Attempting to install wget..."
    sudo apt update && sudo apt install -y wget || (echo "Failed to install wget. Exiting." && exit 1)
fi

if ! command -v unzip &> /dev/null; then
    echo "unzip could not be found. Please install unzip."
    echo "Attempting to install unzip..."
    sudo apt update && sudo apt install -y unzip || (echo "Failed to install unzip. Exiting." && exit 1)
fi
echo "Prerequisites are met."

# --------------------------------------------------------------------
# 2. DOWNLOAD SONARSCANNER CLI
# --------------------------------------------------------------------
echo_step "Downloading SonarScanner CLI from ${DOWNLOAD_URL}..."
# Navigate to a temporary directory for download
cd /tmp
# Remove existing file if it's there from a previous failed attempt
rm -f "${SCANNER_ZIP_FILENAME}.zip"

wget -q "${DOWNLOAD_URL}" -O "${SCANNER_ZIP_FILENAME}.zip"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download SonarScanner CLI. Please check the URL and your internet connection."
    exit 1
fi
echo "Download complete."

# --------------------------------------------------------------------
# 3. UNZIP SONARSCANNER CLI
# --------------------------------------------------------------------
echo_step "Unzipping SonarScanner CLI to ${INSTALL_DIR}..."
# Remove existing installation directory if it matches the expected extracted name
if [ -d "${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}" ]; then
    echo "Found existing installation at ${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}. Removing it..."
    sudo rm -rf "${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}"
fi

sudo unzip -q "${SCANNER_ZIP_FILENAME}.zip" -d "${INSTALL_DIR}"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to unzip SonarScanner CLI."
    rm -f "${SCANNER_ZIP_FILENAME}.zip" # Clean up downloaded file
    exit 1
fi
# Verify that the expected directory was created by unzip
if [ ! -d "${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}" ]; then
    echo "ERROR: Expected directory ${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME} was not found after unzip."
    echo "Please check the contents of ${INSTALL_DIR} to see what was actually extracted."
    ls -l ${INSTALL_DIR}
    rm -f "${SCANNER_ZIP_FILENAME}.zip" # Clean up downloaded file
    exit 1
fi
echo "Unzip complete. SonarScanner extracted to ${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}"

# --------------------------------------------------------------------
# 4. CREATE SYMBOLIC LINK (Optional but Recommended)
# --------------------------------------------------------------------
echo_step "Creating symbolic link for sonar-scanner at ${SYMLINK_PATH}..."
# Remove existing symlink if it points to an old version or is broken
if [ -L "${SYMLINK_PATH}" ]; then
    echo "Removing existing symlink at ${SYMLINK_PATH}..."
    sudo rm -f "${SYMLINK_PATH}"
fi

# Use the SCANNER_EXTRACTED_DIR_NAME for the source of the symlink
sudo ln -s "${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}/bin/sonar-scanner" "${SYMLINK_PATH}"
echo "Symbolic link created."

# --------------------------------------------------------------------
# 5. CLEAN UP DOWNLOADED FILE
# --------------------------------------------------------------------
echo_step "Cleaning up downloaded zip file..."
rm -f "${SCANNER_ZIP_FILENAME}.zip"
echo "Cleanup complete."

# --------------------------------------------------------------------
# 6. VERIFY INSTALLATION
# --------------------------------------------------------------------
echo_step "Verifying SonarScanner CLI installation..."
# Attempt to re-source profile or use hash -r to clear command hash, then verify
hash -r 
if command -v sonar-scanner &> /dev/null; then
    sonar-scanner -v
    echo "SonarScanner CLI installed successfully!"
else
    echo "ERROR: sonar-scanner command not found in PATH even after creating symlink and rehashing."
    echo "Please check your PATH or the symlink at ${SYMLINK_PATH}."
    echo "Expected symlink target: ${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}/bin/sonar-scanner"
    ls -l ${SYMLINK_PATH}
    ls -l "${INSTALL_DIR}/${SCANNER_EXTRACTED_DIR_NAME}/bin/sonar-scanner"
    exit 1
fi

echo "--------------------------------------------------------------------"
echo "SonarScanner CLI Installation Finished."
echo "--------------------------------------------------------------------"

exit 0
