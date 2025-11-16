# Audio Recorder (Spyware)

There are 3 components:

1. Audio recorder agent
- To record audio in background with elevated priveleges
- Run as a platform application without UI
- Communicate to server to know when/how long it should record audio and send the recording to server

2. Audio recorder agent hooker: To disable microphone indicator (orange dot), make it transparent to the users

3. C&C server: To give command to the agent and store the audio

