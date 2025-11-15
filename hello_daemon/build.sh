# Example cross-compilation command on a Mac
# This tells clang to compile for the ARM64 CPU (arch arm64) 
# using the iPhoneOS SDK, and link against the minimum version of iOS
rm -rf hello_daemon
xcrun --sdk iphoneos clang -arch arm64 hello_daemon.c -o hello_daemon
ldid -Shq.bao.hello_daemon.plist hello_daemon

sshpass -p "000000" ssh root@192.168.1.38 'rm /usr/local/bin/hello_daemon'
sshpass -p "000000" ssh root@192.168.1.38 'rm /Library/LaunchDaemons/hq.bao.hello_daemon.plist'
sshpass -p "000000" ssh root@192.168.1.38 'rm /run.sh'
sshpass -p "000000" ssh root@192.168.1.38 'rm /stop.sh'

sshpass -p "000000" scp hello_daemon root@192.168.1.38:/usr/local/bin/
sshpass -p "000000" scp hq.bao.hello_daemon.plist root@192.168.1.38:/Library/LaunchDaemons/
sshpass -p "000000" scp run.sh root@192.168.1.38:/
sshpass -p "000000" scp stop.sh root@192.168.1.38:/