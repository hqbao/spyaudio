launchctl stop hq.bao.spysys
launchctl unload /Library/LaunchDaemons/hq.bao.spysys.plist
launchctl load /Library/LaunchDaemons/hq.bao.spysys.plist
launchctl start hq.bao.spysys
# launchctl list
tail -f /var/log/spysys.log