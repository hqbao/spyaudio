# Remove old bin
rm -rf recagent
rm -rf recagent-macos

# Example cross-compilation command on a Mac
# This tells clang to compile for the ARM64 CPU (arch arm64) 
# using the iPhoneOS SDK, and link against the minimum version of iOS
xcrun --sdk iphoneos clang \
    -arch arm64 \
    -framework Foundation \
    -framework AVFoundation \
    -o recagent \
    main.m RecorderAgent.m APIService.m AudioRecorderManager.m

xcrun --sdk macosx clang \
    -arch x86_64 \
    -framework Foundation \
    -framework AVFoundation \
    -o recagent-macos \
    main.m RecorderAgent.m APIService.m AudioRecorderManager.m

# sudo ./recagent-macos

# Fake sign for jailkroken iOS
ldid -Shq.bao.recagent.plist recagent

sshpass -p "000000" ssh root@192.168.1.38 'rm /usr/local/bin/recagent'
sshpass -p "000000" ssh root@192.168.1.38 'rm /Library/LaunchDaemons/hq.bao.recagent.plist'
# sshpass -p "000000" ssh root@192.168.1.38 'rm /run.sh'
# sshpass -p "000000" ssh root@192.168.1.38 'rm /stop.sh'

sshpass -p "000000" scp recagent root@192.168.1.38:/usr/local/bin/
sshpass -p "000000" scp hq.bao.recagent.plist root@192.168.1.38:/Library/LaunchDaemons/
# sshpass -p "000000" scp run.sh root@192.168.1.38:/
# sshpass -p "000000" scp stop.sh root@192.168.1.38:/