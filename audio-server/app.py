import os
import json
import socket # Added to determine the local IP address
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

@app.route('/upload', methods=['POST'])
def upload_file():
    """Endpoint 1: POST /upload - Receives and saves an audio file with a date-based name, including device_id."""
    
    # 1. Get device_id from form data (must be sent along with the file in multipart/form-data)
    # Using .strip() to safely remove any leading/trailing whitespace
    device_id = request.form.get('device_id', '').strip()
    
    # Check if device_id is None or an empty string after stripping
    if not device_id:
        return jsonify({"message": "Missing or empty 'device_id' form field in the request"}), 400
        
    if 'audio' not in request.files:
        return jsonify({"message": "No 'audio' file part in the request"}), 400

    file = request.files['audio']

    if file.filename == '':
        return jsonify({"message": "No selected file"}), 400

    if file and allowed_file(file.filename):
        original_filename = secure_filename(file.filename)
        _, file_extension = os.path.splitext(original_filename)

        # Generate a new filename based on the device ID and current date/time
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        # File name includes device_id
        new_filename = f"{secure_filename(device_id)}_{timestamp}{file_extension}"
        
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], new_filename)
        
        try:
            # Save the file
            file.save(filepath)

            # Update the command to WAIT after a successful upload, reusing the current device_id
            update_command(command_status["device_id"], "WAIT", f"Successfully received {new_filename}.")

            return jsonify({
                "message": "File successfully uploaded",
                "filename": new_filename,
                "filepath": filepath
            }), 201
        except Exception as e:
            return jsonify({"message": f"Server error during file save: {e}"}), 500

    return jsonify({"message": "File type not allowed"}), 400


@app.route('/download', methods=['GET'])
def download_file():
    """Endpoint 2: GET /download - Sends a specific audio file for download."""
    
    filename = request.args.get('filename')
    
    if not filename:
        return jsonify({"message": "Missing 'filename' query parameter"}), 400
    
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(filename))
    
    if not os.path.exists(filepath):
        return jsonify({"message": f"File '{filename}' not found"}), 404
        
    try:
        return send_from_directory(
            app.config['UPLOAD_FOLDER'], 
            secure_filename(filename), 
            as_attachment=True
        )
    except Exception as e:
        return jsonify({"message": f"Server error during file download: {e}"}), 500


@app.route('/list-audio', methods=['GET'])
def list_audio_files():
    """Endpoint 3: GET /list-audio - Returns a list of all uploaded audio filenames."""
    try:
        all_entries = os.listdir(app.config['UPLOAD_FOLDER'])
        
        audio_files = []
        for entry in all_entries:
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], entry)
            if os.path.isfile(filepath) and allowed_file(entry):
                audio_files.append(entry)
                
        audio_files.sort(reverse=True)
        
        return jsonify({
            "message": f"Found {len(audio_files)} audio files.",
            "files": audio_files
        }), 200

    except FileNotFoundError:
        return jsonify({"message": f"Upload directory '{app.config['UPLOAD_FOLDER']}' not found."}), 500
    except Exception as e:
        return jsonify({"message": f"An unexpected error occurred: {e}"}), 500


@app.route('/set-command', methods=['POST'])
def set_command():
    """Endpoint 5: POST /set-command - Allows a client to set the current command (e.g., 'RECORD'). Requires device_id."""
    try:
        data = request.get_json()
    except Exception:
        return jsonify({"message": "Invalid JSON format in request body"}), 400

    device_id = data.get('device_id')
    command = data.get('command')
    message = data.get('message')

    if not all([device_id, command, message]):
        return jsonify({"message": "Missing 'device_id', 'command', or 'message' fields in JSON body"}), 400

    if update_command(device_id, command, message):
        return jsonify({
            "message": f"Command successfully updated for device: {device_id}",
            "new_command": command.upper(),
            "new_message": message
        }), 200
    else:
        return jsonify({"message": "Failed to update global command status"}), 500


@app.route('/get-command', methods=['GET'])
def get_command():
    """Endpoint 4: GET /get-command - Returns the command if the requested device_id matches the target ID, then resets the command to WAIT."""
    global command_status
    
    # Get device_id from query parameter
    requested_device_id = request.args.get('device_id')
    
    # Check if the required parameter is missing
    if not requested_device_id:
        # If no ID is provided, treat it as an invalid request
        return jsonify({
            "device_id": "INVALID_REQUEST",
            "command": "WAIT",
            "message": "Missing 'device_id' query parameter. Must provide ID to check for command."
        }), 400

    try:
        # Get the global target device ID
        target_device_id = command_status.get('device_id')
        
        # Check if the IDs match
        if requested_device_id == target_device_id:
            # IDs match: Return the current command for the targeted device.
            
            # Store the current command to return to the client
            response_data = command_status.copy()

            # If the command is anything other than WAIT, reset it to WAIT
            if response_data.get('command') != 'WAIT':
                print(f"Command '{response_data.get('command')}' consumed by device '{target_device_id}'. Resetting to WAIT.")
                # The device ID is preserved as the target for the reset message.
                update_command(target_device_id, "WAIT", f"Command {response_data.get('command')} received and reset.")
            
            # Return the original command data to the matching client
            return jsonify(response_data), 200
        else:
            # IDs do not match: Return a fixed WAIT command response.
            print(f"Device '{requested_device_id}' requested command but did not match target '{target_device_id}'. Returning WAIT.")
            return jsonify({
                "device_id": requested_device_id,
                "command": "WAIT",
                "message": f"Device ID does not match the current target ({target_device_id}). Command is WAIT."
            }), 200
        
    except Exception as e:
        return jsonify({"message": f"An unexpected error occurred while processing command: {e}"}), 500

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
    # Updated print statement to show the actual IP address
    print(f"HTTPS URL: https://{SERVER_IP}:{PORT}/ (Requires certgen/certificate.crt and certgen/private.key)")
    print("------------------------------------------\n")

    # Run the application using the SSL certificate and key on the configured port
    app.run(debug=True, host='0.0.0.0', port=PORT, ssl_context=('certgen/certificate.crt', 'certgen/private.key'))
    # app.run(debug=True, host='0.0.0.0', port=5000)
