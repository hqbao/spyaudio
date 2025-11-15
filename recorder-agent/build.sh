# Example cross-compilation command on a Mac
# This tells clang to compile for the ARM64 CPU (arch arm64) 
# using the iPhoneOS SDK, and link against the minimum version of iOS
rm -rf spysys
xcrun --sdk iphoneos clang -arch arm64 spysys.c -o spysys
ldid -Shq.bao.spysys.plist spysys

sshpass -p "000000" ssh root@192.168.1.38 'rm /usr/local/bin/spysys'
sshpass -p "000000" ssh root@192.168.1.38 'rm /Library/LaunchDaemons/hq.bao.spysys.plist'
sshpass -p "000000" ssh root@192.168.1.38 'rm /run.sh'
sshpass -p "000000" ssh root@192.168.1.38 'rm /stop.sh'

sshpass -p "000000" scp spysys root@192.168.1.38:/usr/local/bin/
sshpass -p "000000" scp hq.bao.spysys.plist root@192.168.1.38:/Library/LaunchDaemons/
sshpass -p "000000" scp run.sh root@192.168.1.38:/
sshpass -p "000000" scp stop.sh root@192.168.1.38:/