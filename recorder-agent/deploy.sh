USERNAME=mobile
PASSWORD="alpine"
DEVICE_IP="192.168.1.38"

sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP 'rm /usr/local/bin/recagent'
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP 'rm /Library/LaunchDaemons/hq.bao.recagent.plist'
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP 'rm /start.sh'
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP 'rm /stop.sh'

sshpass -p $PASSWORD scp recagent $USERNAME@$DEVICE_IP:/usr/local/bin/
sshpass -p $PASSWORD scp hq.bao.recagent.plist $USERNAME@$DEVICE_IP:/Library/LaunchDaemons/
sshpass -p $PASSWORD scp start.sh $USERNAME@$DEVICE_IP:/
sshpass -p $PASSWORD scp stop.sh $USERNAME@$DEVICE_IP:/