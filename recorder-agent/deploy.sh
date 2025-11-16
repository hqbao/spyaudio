ROOT_PASS="000000"

sshpass -p $ROOT_PASS ssh root@192.168.1.38 'rm /usr/local/bin/recagent'
sshpass -p $ROOT_PASS ssh root@192.168.1.38 'rm /Library/LaunchDaemons/hq.bao.recagent.plist'
sshpass -p $ROOT_PASS ssh root@192.168.1.38 'rm /start.sh'
sshpass -p $ROOT_PASS ssh root@192.168.1.38 'rm /stop.sh'

sshpass -p $ROOT_PASS scp recagent root@192.168.1.38:/usr/local/bin/
sshpass -p $ROOT_PASS scp hq.bao.recagent.plist root@192.168.1.38:/Library/LaunchDaemons/
sshpass -p $ROOT_PASS scp start.sh root@192.168.1.38:/
sshpass -p $ROOT_PASS scp stop.sh root@192.168.1.38:/