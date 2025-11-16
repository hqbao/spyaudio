USERNAME=root
ROOT_PASS="000000"
DEVICE_IP="192.168.1.38"

sshpass -p $ROOT_PASS ssh $USERNAME@$DEVICE_IP 'rm /usr/local/bin/recagent'
sshpass -p $ROOT_PASS ssh $USERNAME@$DEVICE_IP 'rm /Library/LaunchDaemons/hq.bao.recagent.plist'
sshpass -p $ROOT_PASS ssh $USERNAME@$DEVICE_IP 'rm /start.sh'
sshpass -p $ROOT_PASS ssh $USERNAME@$DEVICE_IP 'rm /stop.sh'

sshpass -p $ROOT_PASS scp recagent $USERNAME@$DEVICE_IP:/usr/local/bin/
sshpass -p $ROOT_PASS scp hq.bao.recagent.plist $USERNAME@$DEVICE_IP:/Library/LaunchDaemons/
sshpass -p $ROOT_PASS scp start.sh $USERNAME@$DEVICE_IP:/
sshpass -p $ROOT_PASS scp stop.sh $USERNAME@$DEVICE_IP:/