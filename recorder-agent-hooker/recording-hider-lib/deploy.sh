USERNAME=root
PASSWORD="alpine"
DEVICE_IP="192.168.1.38"
TWEAK_DIR="/var/jb/Library/MobileSubstrate/DynamicLibraries"

# 1. Clean up old files
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "rm $TWEAK_DIR/RecordingHider.dylib $TWEAK_DIR/RecordingHider.plist"

# 2. Transfer new files
sshpass -p $PASSWORD scp RecordingHider.dylib $USERNAME@$DEVICE_IP:$TWEAK_DIR
sshpass -p $PASSWORD scp RecordingHider.plist $USERNAME@$DEVICE_IP:$TWEAK_DIR

# 3. Set permissions
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "chmod 0755 $TWEAK_DIR/RecordingHider.dylib"
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP "chmod 0644 $TWEAK_DIR/RecordingHider.plist"

# 4. Activate tweak (Respring)
echo "Tweak deployed. Respringing device..."
sshpass -p $PASSWORD ssh $USERNAME@$DEVICE_IP 'killall -9 SpringBoard'