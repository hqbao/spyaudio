#!/bin/sh
USERNAME=root
PASSWORD="alpine"
DEVICE_IP="192.168.1.38"
JB_DIR=/var/jb

sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "rm $JB_DIR/usr/bin/recagent"
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "rm $JB_DIR/Library/LaunchDaemons/hq.bao.recagent.plist"
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "rm $JB_DIR/start.sh"
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "rm $JB_DIR/stop.sh"
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "rm $JB_DIR/var/log/recagent.log"

sshpass -p $PASSWORD scp recagent $USERNAME@$DEVICE_IP:$JB_DIR/usr/bin/
sshpass -p $PASSWORD scp hq.bao.recagent.plist $USERNAME@$DEVICE_IP:$JB_DIR/Library/LaunchDaemons/
sshpass -p $PASSWORD scp start.sh $USERNAME@$DEVICE_IP:$JB_DIR/
sshpass -p $PASSWORD scp stop.sh $USERNAME@$DEVICE_IP:$JB_DIR/
