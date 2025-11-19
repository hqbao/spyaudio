#!/bin/sh
JB_DIR=<jbdir>
AGENT_PLIST=$JB_DIR/Library/LaunchDaemons/hq.bao.recagent.plist
AGENT_LOG=$JB_DIR/var/log/recagent.log
AGENT_LABEL=hq.bao.recagent

echo "Attempting to start Audio Recorder Agent ($AGENT_LABEL)..."

# 1. Ensure the agent is stopped and unloaded cleanly before reloading
launchctl stop $AGENT_LABEL
launchctl unload $AGENT_PLIST 2>/dev/null 

# 2. Load the Launch Daemon configuration (must be run as root)
echo "Loading launch daemon file: $AGENT_PLIST"
launchctl load $AGENT_PLIST

# 3. Start the agent immediately
echo "Starting agent service: $AGENT_LABEL"
launchctl start $AGENT_LABEL

echo "Agent started. Check logs for status:"
echo "-------------------------------------"
# The original script had this line commented out. Uncomment to view logs directly.
# This requires the user to hit Ctrl+C to exit the log view.
# tail -f $AGENT_LOG