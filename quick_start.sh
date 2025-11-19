#!/bin/bash

# Prompt for SSH details needed for step 2 output and step 3 check.
read -p "Enter Target Device IP (e.g., 192.168.1.38): " DEVICE_IP
read -p "Enter Target Host IP (e.g., 192.168.1.10): " HOST_IP
read -p "Enter Target Device Jailbreak Dir (\"/var/jb\" or empty): " JB_DIR
read -p "Enter Target Device SSH Username: " USERNAME
read -s -p "Enter Target Device SSH Password (will not be displayed): " PASSWORD
echo # Prints a newline after password input
# USERNAME=root
# PASSWORD=alpine
# DEVICE_IP=192.168.0.153
# HOST_IP=192.168.0.146
# JB_DIR="/var/jb"

echo "--- 1. Running Environment Check ---"

# Source the check script. This runs the environment tests, exports variables, 
# and returns an exit status (0 for success, 1 for failure) without terminating 
# the parent script.
source ./check_env.sh $USERNAME $PASSWORD $DEVICE_IP $JB_DIR

# Capture the exit status from the sourced script.
SETUP_EXIT_STATUS=$?

# Check the status and execute deployment or halt.
if [ $SETUP_EXIT_STATUS -eq 0 ]; then
	echo "--- 2. Environment Checks Passed (Status: 0) ---"
	# Proceed to the deployment script
	./deploy.sh $USERNAME $PASSWORD $DEVICE_IP $HOST_IP $JB_DIR
else
    echo "--- Setup Failed (Status: $SETUP_EXIT_STATUS) ---"
    echo "Environment requirements were not met. Deployment halted."
    exit 1
fi