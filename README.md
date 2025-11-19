## 🎙️ Covert Audio Recording Platform

### Overview and Analytics

This document outlines the technical approach for developing a platform capable of covertly recording and exfiltrating audio from a target device. The primary goals include persistent background operation, indicator suppression, and secure, optimized data transmission.

1.  **Background Persistence:** To ensure the audio recorder operates continuously in the background, the agent must be implemented as a **platform-level application** and deployed with **elevated privileges** (System-level permissions).
2.  **Indicator Suppression:** We must identify and hook the specific system applications, classes, and methods responsible for displaying recording indicators (e.g., the orange dot on iOS). **Frida** will be used for rapid tracing and identification of these components. The final implementation will involve a dedicated **hooker agent** deployed as a preloaded library within relevant system processes to dynamically disable the indicators.

3. **Encryption Layer & Man-in-the-Middle (MITM) Protection**
    * HTTPS/TLS is essential for establishing secure communication. During the TLS handshake, a master secret is generated, which is then used to derive the session keys for encrypting all application data exchanged between the client and the server.
    * Conclusion: Since TLS provides robust, end-to-end encryption for the data stream, we do not need to implement an extra, application-level encryption layer for the content itself. Relying on TLS is the standard and most efficient practice.
    * Standard TLS is vulnerable to sophisticated MITM attacks where an attacker can inject a malicious certificate issued by a compromised or rogue Certificate Authority (CA). The client's operating system or browser would typically trust this certificate, allowing the attacker to decrypt the traffic.
    * To mitigate this, SSL/TLS pinning should be implemented on the client (platform app).
    * Mechanism: The client app is configured to expect and trust a specific, known cryptographic identifier (the public key or the hash of the certificate) belonging to your server. Upon a TLS handshake, the client verifies the received certificate's identifier against the one it has pinned internally. If they don't match, the connection is immediately terminated, effectively defeating the MITM attack.

4.  **Data Transfer Optimization:** To minimize bandwidth usage and detection risk, data exfiltration will utilize standard **HTTP compressed file transfer**. We will leverage existing platform capabilities and avoid implementing a custom compression library.

### Core Components

1.  **Audio Recorder Agent (Platform Application)**
    * Function: Records audio covertly in the background with elevated privileges.
    * Execution: Runs as a platform-level process **without a user interface (UI)**.
    * Communication: Connects to the C&C server to receive commands (e.g., when/how long to record) and securely upload the recorded audio files.
2.  **Indicator Suppression Module (Hooker Agent)**
    * Function: The dedicated library responsible for intercepting and disabling the operating system's microphone usage indicators (e.g., making the orange dot transparent or suppressing its display entirely) to ensure user transparency.
3.  **Command and Control (C&C) Server**
    * Function: Provides the central infrastructure for issuing commands to deployed agents (timing, duration, target commands) and securely storing the encrypted audio recordings.

### Deployment Instructions

1.  **C&C Server:** Deploy the Command and Control server by following the instructions in the `README.MD` located in the `audio-server/` directory.
2.  **Recorder Agent:** Deploy the audio recording agent by following the instructions in the `README.MD` located in the `recorder-agent/` directory.
3.  **Indicator Suppression Module:** Deploy the recording hider/hooker by following the instructions in the `README.MD` located in the `recording-hider-theos/` directory.

### Quick Deployment
* Install & jailbreak device with Dopamine: https://ellekit.space/dopamine/
* Install openssh, enble ssh for root account
* Install Ellekit
* Run `./quick-start.sh` on your host machine

# Note
This works for jailbreaking with Dopamine. For Dopamine roothide, we to manually change iphoneos-arm64 to iphoneos-arm64e in recorder-agent-hooker/recording-hider-theos/control

Demo: https://youtu.be/4N50MfgVPkU

