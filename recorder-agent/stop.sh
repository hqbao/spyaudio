#!/bin/sh
JB_DIR=/var/jb
launchctl stop hq.bao.recagent
launchctl unload $JB_DIR/Library/LaunchDaemons/hq.bao.recagent.plist