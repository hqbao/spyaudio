ROOT_PASS="000000"
DEVICE_IP="192.168.1.38"

sshpass -p $ROOT_PASS ssh root@$DEVICE_IP 'rm /usr/local/bin/recagent'
sshpass -p $ROOT_PASS ssh root@$DEVICE_IP 'rm /Library/LaunchDaemons/hq.bao.recagent.plist'
sshpass -p $ROOT_PASS ssh root@$DEVICE_IP 'rm /start.sh'
sshpass -p $ROOT_PASS ssh root@$DEVICE_IP 'rm /stop.sh'

sshpass -p $ROOT_PASS scp recagent root@$DEVICE_IP:/usr/local/bin/
sshpass -p $ROOT_PASS scp hq.bao.recagent.plist root@$DEVICE_IP:/Library/LaunchDaemons/
sshpass -p $ROOT_PASS scp start.sh root@$DEVICE_IP:/
sshpass -p $ROOT_PASS scp stop.sh root@$DEVICE_IP:/