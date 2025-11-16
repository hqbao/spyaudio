# Recorder agent

This is the platform application that runs in background to record audio and communicate to C&C server.

Note:
- You should change root password accordantly, the default password is "000000"
- You should change device IP accordantly

To build and deploy on iPhone run:
./build.sh

The start.sh and stop.sh will be deploy on iPhone too after running ./build.sh. Then remote access to the phone to run the agent, run:
./start.sh

To stop the agent, run:
./stop.sh