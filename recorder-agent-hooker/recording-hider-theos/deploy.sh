ROOT_PASS="000000"

sshpass -p $ROOT_PASS ssh root@192.168.1.38 'rm /Library/MobileSubstrate/DynamicLibraries/RecordingHider.dylib'
sshpass -p $ROOT_PASS ssh root@192.168.1.38 'rm /Library/MobileSubstrate/DynamicLibraries/RecordingHider.plist'

sshpass -p $ROOT_PASS scp RecordingHider.dylib root@192.168.1.38:/Library/MobileSubstrate/DynamicLibraries/
sshpass -p $ROOT_PASS scp RecordingHider.plist root@192.168.1.38:/Library/MobileSubstrate/DynamicLibraries/
