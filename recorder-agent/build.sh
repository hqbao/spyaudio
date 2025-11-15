# Remove old bin
rm -rf spysys
rm -rf spysys-macos

# Example cross-compilation command on a Mac
# This tells clang to compile for the ARM64 CPU (arch arm64) 
# using the iPhoneOS SDK, and link against the minimum version of iOS
xcrun --sdk iphoneos clang \
    -arch arm64 \
    -framework Foundation \
    -framework AVFoundation \
    -o spysys \
    main.m APIService.m AudioRecorderManager.m

xcrun --sdk macosx clang \
    -arch x86_64 \
    -framework Foundation \
    -framework AVFoundation \
    -o spysys-macos \
    main.m APIService.m AudioRecorderManager.m

./spysys-macos

# Fake sign for jailkroken iOS
ldid -Shq.bao.spysys.plist spysys

# sshpass -p "000000" ssh root@192.168.1.38 'rm /usr/local/bin/spysys'
# sshpass -p "000000" ssh root@192.168.1.38 'rm /Library/LaunchDaemons/hq.bao.spysys.plist'
# sshpass -p "000000" ssh root@192.168.1.38 'rm /run.sh'
# sshpass -p "000000" ssh root@192.168.1.38 'rm /stop.sh'

# sshpass -p "000000" scp spysys root@192.168.1.38:/usr/local/bin/
# sshpass -p "000000" scp hq.bao.spysys.plist root@192.168.1.38:/Library/LaunchDaemons/
# sshpass -p "000000" scp run.sh root@192.168.1.38:/
# sshpass -p "000000" scp stop.sh root@192.168.1.38:/