# Audio Command Server

A Flask-based web server for managing audio file uploads, downloads, and remote command execution with an in-memory command system.

## Features

* File Upload: Upload audio files with automatic timestamp-based naming
* File Download: Download previously uploaded audio files
* File Listing: View all available audio files in the system
* Command System: Remote command execution with automatic reset
* RESTful API: Simple HTTP endpoints for all operations

## API Endpoints

1. Upload Audio File
* Endpoint: POST /upload
* Description: Upload an audio file to the server
* Request: Form-data with 'audio' file part
* Supported Formats: WAV, MP3, OGG, FLAC, M4A
* Response: Returns uploaded filename and path

2. Download Audio File
* Endpoint: GET /download
* Description: Download a specific audio file
* Parameters: filename (query parameter)
*  Response: File download or error message

3. List Audio Files
* Endpoint: GET /list-audio
* Description: Get a list of all uploaded audio files
* Response: JSON with file count and sorted list of filenames

4. Get Command
* Endpoint: GET /get-command
* Description: Retrieve the current command (resets to "WAIT" after reading if not already "WAIT")
* Response: Current command and message

5. Set Command
* Endpoint: POST /set-command
* Description: Set a new command for the system
* Request: JSON body with command and message fields
* Response: Confirmation of updated command


## Installation & Setup
* pip install flask werkzeug
* python app.py

## Use postman to control
Import CC-client.json to your postman and play it
