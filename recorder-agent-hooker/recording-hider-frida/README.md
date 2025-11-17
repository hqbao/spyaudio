# SpringBoard Microphone Indicator Hook (Frida)

This project provides a library that utilizes Frida to inject into the SpringBoard process, allowing for the disabling of the system's microphone usage indicator.

The primary use case for this method is rapid debugging and tracing within a development environment.

Implementation involves performing a thorough analysis of SpringBoard's classes and methods to locate and hook the specific function responsible for controlling the microphone indicator's visibility.