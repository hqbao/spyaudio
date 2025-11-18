#!/bin/bash

# Initialize exit status: 0 for success, 1 for failure.
EXIT_STATUS=0

# --- Configuration Variables ---

SSH_USERNAME=$1
SSH_PASSWORD=$2
DEVICE_IP=$3

THEOS_PATH="$HOME/theos"
THEOS_PORT=22
ELLEKIT_PATH="/var/jb/Library/MobileSubstrate/DynamicLibraries"

echo "--- Starting Environment Check ---"
echo ""

# 1. Check if Python 3 is installed
check_python3() {
    echo "1. Checking for Python 3..."
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        echo "   ✅ Python 3 is installed (version $PYTHON_VERSION)."
    else
        echo "   ❌ Python 3 is NOT found. Cannot proceed."
        EXIT_STATUS=1
        return 1
    fi
    echo "----------------------------------------------------"
}

# 2. Check for Theos directory and automatically set environment variables
check_theos() {
    echo "2. Checking for Theos installation and environment variables..."
    if [ -d "$THEOS_PATH" ]; then
        echo "   ✅ Theos directory found at: $THEOS_PATH"
        
        # --- Auto-Export Section (Requires 'source' to persist) ---
        export THEOS="$THEOS_PATH"
        export THEOS_DEVICE_IP="$DEVICE_IP"
        export THEOS_DEVICE_PORT="$THEOS_PORT"
        
        echo "   ✅ Theos variables have been exported."
        echo "      THEOS=$THEOS"
        echo "      THEOS_DEVICE_IP=$THEOS_DEVICE_IP"
        # --- End Auto-Export Section ---
        
    else
        echo "   ❌ Theos directory not found at: $THEOS_PATH. Cannot proceed."
        EXIT_STATUS=1
    fi
    echo "----------------------------------------------------"
}

# 3. Check SSH connection using sshpass
check_ssh() {
    echo "3. Attempting SSH connection test to $SSH_USERNAME@$DEVICE_IP using sshpass..."

    # Check if sshpass is installed
    if ! command -v sshpass &> /dev/null; then
        echo "   ⚠️ Warning: 'sshpass' is required for this automatic check but is not installed."
        echo "   Skipping SSH connection test. This will not cause the script to fail, but manual verification is needed."
        echo "----------------------------------------------------"
        return 0
    fi

    # Suppress output from the ssh attempt and limit the connection time
    if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USERNAME@$DEVICE_IP" exit 2>/dev/null; then
        echo "   ✅ SSH connection successful to $SSH_USERNAME@$DEVICE_IP:$THEOS_PORT."
    else
        echo "   ❌ SSH connection failed. Cannot proceed."
        EXIT_STATUS=1
    fi
    echo "----------------------------------------------------"
}

# 4. Check for ElleKit/Substrate path on the remote device
check_ellekit() {
    echo "4. Checking for required ElleKit/Substrate directory on target device..."
    
    # We must ensure SSH is working before this, but we'll try the check anyway.
    if ! command -v sshpass &> /dev/null; then
         echo "   (Skipping remote ElleKit check as sshpass is missing.)"
         echo "----------------------------------------------------"
         return 0
    fi

    # Use sshpass to check if the directory exists on the remote device
    # The 'test -d' command returns 0 if the directory exists, 1 otherwise.
    if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USERNAME@$DEVICE_IP" "test -d $ELLEKIT_PATH" 2>/dev/null; then
        echo "   ✅ ElleKit/Substrate directory found at: $ELLEKIT_PATH"
    else
        echo "   ❌ Required directory not found on device: $ELLEKIT_PATH"
        echo "   Please install ElleKit or a compatible substrate from: https://ellekit.space/"
        EXIT_STATUS=1
    fi
    echo "----------------------------------------------------"
}


# --- Main Execution ---
check_python3
check_theos
check_ssh
check_ellekit

echo "--- Environment Check Complete (Final Exit Code: $EXIT_STATUS) ---"

# Cleanup sensitive variable
unset SSH_PASSWORD

# FIX: Use 'return' instead of 'exit' when the script is sourced, 
# to allow the parent script to continue.
return $EXIT_STATUS