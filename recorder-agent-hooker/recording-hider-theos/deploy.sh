ROOT_PASS="000000"
DEVICE_IP="192.168.1.38"
TWEAK_DIR="/Library/MobileSubstrate/DynamicLibraries/"

# 1. Clean up old files
sshpass -p $ROOT_PASS ssh root@$DEVICE_IP "rm $TWEAK_DIR/RecordingHider.dylib $TWEAK_DIR/RecordingHider.plist"

# 2. Transfer new files
sshpass -p $ROOT_PASS scp RecordingHider.dylib root@$DEVICE_IP:$TWEAK_DIR
sshpass -p $ROOT_PASS scp RecordingHider.plist root@$DEVICE_IP:$TWEAK_DIR

# 3. Set permissions
sshpass -p $ROOT_PASS ssh root@$DEVICE_IP "chmod 0755 $TWEAK_DIR/RecordingHider.dylib"
sshpass -p $ROOT_PASS ssh root@$DEVICE_IP "chmod 0644 $TWEAK_DIR/RecordingHider.plist"

# 4. Activate tweak (Respring)
echo "Tweak deployed. Respringing device..."
sshpass -p $ROOT_PASS ssh root@$DEVICE_IP 'killall -9 SpringBoard'