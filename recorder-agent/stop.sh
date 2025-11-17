#!/bin/sh
JB_DIR=/var/jb
AGENT_PLIST=$JB_DIR/Library/LaunchDaemons/hq.bao.recagent.plist
AGENT_LABEL=hq.bao.recagent

echo "Attempting to stop Audio Recorder Agent ($AGENT_LABEL)..."

# 1. Stop the running service
launchctl stop $AGENT_LABEL

# 2. Unload the Launch Daemon from the system
launchctl unload $AGENT_PLIST 2>/dev/null

echo "Agent service ($AGENT_LABEL) successfully stopped and unloaded."