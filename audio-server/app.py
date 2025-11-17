import os
import json
import socket
from flask import Flask, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename
from datetime import datetime

# --- Configuration ---
# Folder where uploaded files will be stored
UPLOAD_FOLDER = 'audio'
# Allowed file extensions for uploads
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'm4a'}

# Define Port for HTTPS Server Operation
PORT = 5000

# Global variable for command status (IN-MEMORY STATE)
command_status = {
    "device_id": "DEFAULT_DEVICE_ID", # Unique identifier for the target client device
    "command": "WAIT",
    "message": "Waiting for instruction from server operator."
}

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# --- Utility Functions ---

def create_response(message, status_code, **kwargs):
    """Creates a standardized JSON response."""
    data = {"message": message}
    data.update(kwargs)
    return jsonify(data), status_code

def allowed_file(filename):
    """Check if the file extension is allowed."""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def initialize_app_environment():
    """Create the audio directory if it doesn't exist."""
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)
        print(f"Created directory: {UPLOAD_FOLDER}")

def update_command(device_id, cmd, msg):
    """Internal function to update the GLOBAL command status, including device ID."""
    global command_status
    try:
        command_status["device_id"] = device_id
        command_status["command"] = cmd.upper()
        command_status["message"] = msg
        print(f"Command updated for device ID '{device_id}' to: {cmd.upper()}")
        return True
    except Exception as e:
        print(f"Error updating global command status: {e}")
        return False

# --- Endpoints ---

@app.route('/', methods=['GET'])
def home():
    """Endpoint 0: GET / - Simple health check endpoint."""
    return create_response("Audio command server is running (HTTPS Only).", 200, status="ok")

@app.route('/upload', methods=['POST'])
def upload_file():
    """Endpoint 1: POST /upload - Receives and saves an audio file with a date-based name, including device_id."""
    
    device_id = request.form.get('device_id', '').strip()
    
    if not device_id:
        return create_response("Missing or empty 'device_id' form field in the request", 400)
        
    if 'audio' not in request.files:
        return create_response("No 'audio' file part in the request", 400)

    file = request.files['audio']

    if file.filename == '':
        return create_response("No selected file", 400)

    if file and allowed_file(file.filename):
        original_filename = secure_filename(file.filename)
        _, file_extension = os.path.splitext(original_filename)

        # Generate a new filename based on the device ID and current date/time
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        new_filename = f"{secure_filename(device_id)}_{timestamp}{file_extension}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], new_filename)
        
        try:
            # Save the file
            file.save(filepath)

            # Update the command to WAIT after a successful upload
            update_command(command_status["device_id"], "WAIT", f"Successfully received {new_filename}.")

            return create_response("File successfully uploaded", 201, 
                                 filename=new_filename, 
                                 filepath=filepath)
        except Exception as e:
            return create_response(f"Server error during file save: {e}", 500)

    return create_response("File type not allowed", 400)


@app.route('/download', methods=['GET'])
def download_file():
    """Endpoint 2: GET /download - Sends a specific audio file for download."""
    
    filename = request.args.get('filename')
    
    if not filename:
        return create_response("Missing 'filename' query parameter", 400)
    
    secure_name = secure_filename(filename)
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], secure_name)
    
    if not os.path.exists(filepath):
        return create_response(f"File '{filename}' not found", 404)
        
    try:
        return send_from_directory(
            app.config['UPLOAD_FOLDER'], 
            secure_name, 
            as_attachment=True
        )
    except Exception as e:
        return create_response(f"Server error during file download: {e}", 500)


@app.route('/list-audio', methods=['GET'])
def list_audio_files():
    """Endpoint 3: GET /list-audio - Returns a list of all uploaded audio filenames."""
    try:
        all_entries = os.listdir(app.config['UPLOAD_FOLDER'])
        
        # Using a list comprehension for cleaner file filtering
        audio_files = [
            entry for entry in all_entries 
            if os.path.isfile(os.path.join(app.config['UPLOAD_FOLDER'], entry)) and allowed_file(entry)
        ]
        audio_files.sort(reverse=True)
        
        return create_response(f"Found {len(audio_files)} audio files.", 200, files=audio_files)

    except FileNotFoundError:
        return create_response(f"Upload directory '{app.config['UPLOAD_FOLDER']}' not found.", 500)
    except Exception as e:
        return create_response(f"An unexpected error occurred: {e}", 500)


@app.route('/set-command', methods=['POST'])
def set_command():
    """Endpoint 5: POST /set-command - Allows a client to set the current command (e.g., 'RECORD'). Requires device_id."""
    try:
        data = request.get_json()
    except Exception:
        return create_response("Invalid JSON format in request body", 400)

    device_id = data.get('device_id')
    command = data.get('command')
    message = data.get('message')

    if not all([device_id, command, message]):
        return create_response("Missing 'device_id', 'command', or 'message' fields in JSON body", 400)

    if update_command(device_id, command, message):
        return create_response(f"Command successfully updated for device: {device_id}", 200, 
                               new_command=command.upper(), 
                               new_message=message)
    else:
        return create_response("Failed to update global command status", 500)


@app.route('/get-command', methods=['GET'])
def get_command():
    """Endpoint 4: GET /get-command - Returns the command if the requested device_id matches the target ID, then resets the command to WAIT."""
    global command_status
    
    requested_device_id = request.args.get('device_id')
    
    if not requested_device_id:
        return create_response("Missing 'device_id' query parameter. Must provide ID to check for command.", 400,
                                device_id="INVALID_REQUEST", 
                                command="WAIT")

    try:
        target_device_id = command_status.get('device_id')
        
        if requested_device_id == target_device_id:
            response_data = command_status.copy()

            if response_data.get('command') != 'WAIT':
                print(f"Command '{response_data.get('command')}' consumed by device '{target_device_id}'. Resetting to WAIT.")
                update_command(target_device_id, "WAIT", f"Command {response_data.get('command')} received and reset.")
            
            # Return the original command data dictionary (using jsonify directly here is cleaner)
            return jsonify(response_data), 200
        else:
            print(f"Device '{requested_device_id}' requested command but did not match target '{target_device_id}'. Returning WAIT.")
            return create_response(f"Device ID does not match the current target ({target_device_id}). Command is WAIT.", 200, 
                                   device_id=requested_device_id, 
                                   command="WAIT")
        
    except Exception as e:
        return create_response(f"An unexpected error occurred while processing command: {e}", 500)

# --- Server Startup Function ---

def get_local_ip():
    """Dynamically determines the local IP address visible on the network."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Connect to a common external address (doesn't send data) to get the non-loopback IP
        s.connect(('10.255.255.255', 1)) 
        IP = s.getsockname()[0]
    except Exception:
        # Fallback to localhost if no network interface is found
        IP = '127.0.0.1' 
    finally:
        s.close()
    return IP


if __name__ == '__main__':
    # Initialize the necessary environment (folder)
    initialize_app_environment()
    
    # Get the local IP address for printing
    SERVER_IP = get_local_ip()
    
    print("\n--- Audio Command Server Initialized ---")
    print("HTTPS Only Mode Enabled.")
    print("------------------------------------------")
    # Endpoint print updated to include the new '/' route
    print(f"Health Check: https://{SERVER_IP}:{PORT}/")
    print(f"HTTPS URL: https://{SERVER_IP}:{PORT}/ (Requires certgen/certificate.crt and certgen/private.key)")
    print("------------------------------------------\n")

    # Run the application using the SSL certificate and key on the configured port
    app.run(debug=True, host='0.0.0.0', port=PORT, ssl_context=('certgen/certificate.crt', 'certgen/private.key'))
