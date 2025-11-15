launchctl stop hq.bao.hello_daemo
launchctl unload /Library/LaunchDaemons/hq.bao.hello_daemon.plist
launchctl load /Library/LaunchDaemons/hq.bao.hello_daemon.plist
launchctl start hq.bao.hello_daemo
# launchctl list
tail -f /var/log/hello_daemon.log