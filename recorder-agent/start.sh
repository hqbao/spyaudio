rm -rf /var/log/recagent.log

launchctl stop hq.bao.recagent
launchctl unload /Library/LaunchDaemons/hq.bao.recagent.plist
launchctl load /Library/LaunchDaemons/hq.bao.recagent.plist
launchctl start hq.bao.recagent

tail -f /var/log/recagent.log