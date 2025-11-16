rm -rf /var/log/spysys.log

launchctl stop hq.bao.spysys
launchctl unload /Library/LaunchDaemons/hq.bao.spysys.plist
launchctl load /Library/LaunchDaemons/hq.bao.spysys.plist
launchctl start hq.bao.spysys

tail -f /var/log/spysys.log