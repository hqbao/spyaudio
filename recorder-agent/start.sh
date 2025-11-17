#!/bin/sh
JB_DIR=/var/jb
launchctl stop hq.bao.recagent
launchctl unload $JB_DIR/Library/LaunchDaemons/hq.bao.recagent.plist
launchctl load $JB_DIR/Library/LaunchDaemons/hq.bao.recagent.plist
launchctl start hq.bao.recagent
# tail -f $JB_DIR/var/log/recagent.log