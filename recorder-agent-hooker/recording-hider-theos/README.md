## 🛑 Indicator Suppression Module (iOS)

This project contains the source code for an iOS hooking library designed to disable the system's microphone usage indicator. This module leverages the **ElleKit** injection platform to achieve persistent operation within key system processes.

### ⚙️ Technical Overview

* **Architecture:** The project is built using **Theos**, a cross-platform suite of tools for building software for iOS.
* **Deployment:** The compiled dynamic library (`.dylib`) is deployed to the standard injection path (`/Library/MobileSubstrate/DynamicLibraries/`).
* **Injection Platform:** **ElleKit** is responsible for loading the dynamic library at system application launch.
* **Target:** The library hooks into the `SpringBoard` process, which is responsible for managing the iOS home screen and system UI, including the microphone indicator.
* **Function:** The hook intercepts the relevant methods within `SpringBoard` to suppress the display or change the visual properties (e.g., transparency) of the microphone indicator (the orange dot).

### 🛠️ Development Setup

This project requires a standard Theos development environment setup.

**Prerequisites:**

* Theos installed (usually at `~/theos`)
* Access to a jailbroken iOS device with SSH enabled
* `ElleKit` installed on the target device

Add the following environment variables to your shell profile (e.g., `~/.zshrc` or `~/.bashrc`):

```bash
export THEOS=~/theos
export THEOS_DEVICE_IP=<Target Device IP>    # e.g., 192.168.1.38
export THEOS_DEVICE_PORT=22
```

Build and install
```bash
make clean
make package install
```

