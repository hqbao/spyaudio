## 📱 Audio Recorder Agent (iOS)

This component is the core platform application responsible for covertly recording audio and securely communicating with the Command and Control (C&C) server. It is designed to run persistently in the background on the target iOS device.

### ⚙️ Technical Notes

* **Persistence:** The agent runs as a background service with elevated (System) privileges.
* **Logging:** All application logs are written to a dedicated file on the target device: `$JB_DIR/var/log/recagent.log`.

### 🚀 Build and Deployment

Deployment requires SSH access to a jailbroken iOS device. The build process uses local shell scripts (`build.sh`, `deploy.sh`) to compile the application and transfer the necessary files.

**Prerequisites:**

* A jailbroken iOS device with SSH access.

#### **1. Configuration**

Before deployment, you **must** update the `deploy.sh` script with the correct device credentials and network information:

* Change the **root password** (default is `"alpine"`).
* Update the **target device IP address**.
* Change the C&C server IP [here](https://github.com/hqbao/spyaudio/blob/main/recorder-agent/APIService.m#L5C43-L5C55)

#### **2. Building and Initial Deployment**

Execute the main build script to compile the application and deploy it, along with the helper scripts (`start.sh`, `stop.sh`), to the target device:

```bash
./build.sh