#!/bin/sh

# =================================================================
# WARNING: SECURITY RISK!
# It is highly recommended to use SSH keys instead of 'sshpass'.
# If you must use 'sshpass', load the PASSWORD from an environment
# variable or prompt for it, rather than hardcoding it here.
# =================================================================

# --- Configuration (MUST BE UPDATED) ---
USERNAME=root
PASSWORD="alpine" # <<< CHANGE THIS!
DEVICE_IP="192.168.1.38" # <<< CHANGE THIS!
JB_DIR=/var/jb

# Files to be deployed
AGENT_EXEC="recagent"
LAUNCH_PLIST="hq.bao.recagent.plist"
START_SCRIPT="start.sh"
STOP_SCRIPT="stop.sh"

echo "--- Starting Deployment to $DEVICE_IP ---"

# 1. Check for required local files
if [ ! -f "$AGENT_EXEC" ] || [ ! -f "$LAUNCH_PLIST" ]; then
    echo "ERROR: Missing required local files ($AGENT_EXEC or $LAUNCH_PLIST)." >&2
    echo "Please run './build.sh' first." >&2
    exit 1
fi

# 2. Cleanup (Remove old versions and log file in one remote command)
echo "1. Cleaning up old agent files on target device..."
CLEANUP_CMD="rm -f $JB_DIR/usr/bin/$AGENT_EXEC; \
             rm -f $JB_DIR/Library/LaunchDaemons/$LAUNCH_PLIST; \
             rm -f $JB_DIR/$START_SCRIPT; \
             rm -f $JB_DIR/$STOP_SCRIPT; \
             rm -f $JB_DIR/var/log/recagent.log"

sshpass -p "$PASSWORD" ssh "$USERNAME"@"$DEVICE_IP" "$CLEANUP_CMD"
if [ $? -ne 0 ]; then
    echo "WARNING: Cleanup failed or connection issue. Continuing with deployment."
fi

# 3. Transfer new files
echo "2. Transferring new files..."

# Executable
sshpass -p "$PASSWORD" scp "$AGENT_EXEC" "$USERNAME"@"$DEVICE_IP":"$JB_DIR"/usr/bin/
# Launch Daemon
sshpass -p "$PASSWORD" scp "$LAUNCH_PLIST" "$USERNAME"@"$DEVICE_IP":"$JB_DIR"/Library/LaunchDaemons/
# Helper Scripts
sshpass -p "$PASSWORD" scp "$START_SCRIPT" "$USERNAME"@"$DEVICE_IP":"$JB_DIR"/
sshpass -p "$PASSWORD" scp "$STOP_SCRIPT" "$USERNAME"@"$DEVICE_IP":"$JB_DIR"/

if [ $? -eq 0 ]; then
    echo "--- Deployment Complete ---"
    echo "Run '$JB_DIR/$START_SCRIPT' on the device or via SSH to start the agent."
else
    echo "!!! Deployment FAILED during file transfer. Check credentials and IP. !!!" >&2
    exit 1
fi