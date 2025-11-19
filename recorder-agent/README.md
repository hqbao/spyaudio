## 📱 Audio Recorder Agent (iOS)

This component is the core platform application responsible for covertly recording audio and securely communicating with the Command and Control (C&C) server. It is designed to run persistently in the background on the target jailbroken iOS device.

### ⚙️ Technical Notes

* **Persistence:** The agent runs as a background service with elevated (System) privileges via a Launch Daemon.
* **Target Directory:** All files are deployed to the jailbreak directory: `/var/jb`.
* **Logging:** All application logs are written to a dedicated file on the target device: `$JB_DIR/var/log/recagent.log`.

### 🚀 Build and Deployment

Deployment requires SSH access to the jailbroken iOS device and the `sshpass` utility installed on your host machine.

**Prerequisites:**

* A jailbroken iOS device with SSH access enabled (usually via `OpenSSH`).
* The `sshpass` utility installed on your deployment host.

#### **1. Configuration**

Before deployment, you **must** configure both the agent code and the deployment script:

* **Agent C&C IP:** Update the C&C server IP/URL inside the agent's source code (e.g., `APIService.m`) to point to your live server.
* **Deployment Credentials:** Update the `deploy.sh` script with the correct device credentials and network information.
    * `./deploy.sh root alpine 192.168.1.38 /var/jb`

> **Security Note:** Hardcoding the root password in `deploy.sh` is a significant security risk. For production use, or if sharing the script, move the password to an environment variable or use SSH keys for password-less authentication.

#### **2. Building and Initial Deployment**

Execute the main build script to compile the application (`recagent`) and deploy all necessary files to the target device:

```bash
# Build
./build.sh <host IP> <jailbreak path>
E.g. ./build.sh 192.168.1.10 /var/jb

# Deploy
./deploy.sh <username> <password> <device IP> <jailbreak path>
E.g. ./deploy.sh root alpine 192.168.1.38 /var/jb
```

