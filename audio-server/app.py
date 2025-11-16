import os
import json
from flask import Flask, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename
from datetime import datetime

# --- Configuration ---
# Folder where uploaded files will be stored
UPLOAD_FOLDER = 'audio'
# Allowed file extensions for uploads
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'm4a'}

# Global variable for command status (IN-MEMORY STATE)
command_status = {
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
    # Create UPLOAD_FOLDER (which is now 'audio')
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)
        print(f"Created directory: {UPLOAD_FOLDER}")

# Removed initialize_app_environment logic for COMMAND_FILE

def update_command(cmd, msg):
    """Internal function to update the GLOBAL command status."""
    global command_status
    try:
        command_status["command"] = cmd.upper()
        command_status["message"] = msg
        print(f"Command updated to: {cmd.upper()} with message: {msg}")
        return True
    except Exception as e:
        # Note: Since this is an in-memory update, errors here are usually due to logic bugs, not I/O.
        print(f"Error updating global command status: {e}")
        return False

# --- Endpoints ---

@app.route('/upload', methods=['POST'])
def upload_file():
    """Endpoint 1: POST /upload - Receives and saves an audio file with a date-based name."""
    if 'audio' not in request.files:
        return jsonify({"message": "No 'audio' file part in the request"}), 400

    file = request.files['audio']

    if file.filename == '':
        return jsonify({"message": "No selected file"}), 400

    if file and allowed_file(file.filename):
        original_filename = secure_filename(file.filename)
        _, file_extension = os.path.splitext(original_filename)

        # Generate a new filename based on the current date and time
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        new_filename = f"{timestamp}{file_extension}"
        
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], new_filename)
        
        try:
            # Save the file
            file.save(filepath)

            # Update the command to WAIT after a successful upload
            update_command("WAIT", f"Successfully received {new_filename}.")

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
    """Endpoint 5: POST /set-command - Allows a client to set the current command (e.g., 'RECORD')."""
    try:
        data = request.get_json()
    except Exception:
        return jsonify({"message": "Invalid JSON format in request body"}), 400

    command = data.get('command')
    message = data.get('message')

    if not command or not message:
        return jsonify({"message": "Missing 'command' or 'message' fields in JSON body"}), 400

    if update_command(command, message):
        return jsonify({
            "message": "Command successfully updated",
            "new_command": command.upper(),
            "new_message": message
        }), 200
    else:
        return jsonify({"message": "Failed to update global command status"}), 500


@app.route('/get-command', methods=['GET'])
def get_command():
    """Endpoint 4: GET /get-command - Returns the current command for the client, then resets it to WAIT."""
    global command_status
    
    try:
        # Store the current command to return to the client
        response_data = command_status.copy()

        # IMPORTANT: If the command is anything other than WAIT, reset it to WAIT
        # to ensure the command is only executed once.
        if response_data.get('command') != 'WAIT':
            # Update the global variable
            update_command("WAIT", "Command received and reset to WAIT.")
        
        # Return the original command data to the client
        return jsonify(response_data), 200
        
    except Exception as e:
        return jsonify({"message": f"An unexpected error occurred while processing command: {e}"}), 500

# --- Server Startup ---

if __name__ == '__main__':
    # Initialize the necessary environment (folder)
    initialize_app_environment()
    
    print("\n--- Audio Command Server Initialized ---")
    print(f"Uploads will be saved to the '{UPLOAD_FOLDER}' directory with a date/time stamp.")
    print("Command status is now managed using a fast, in-memory global variable (non-persistent across server restarts).")
    print("To test the server, run it and try these endpoints:")
    print("1. POST /upload (with a file named 'audio')")
    print("2. GET /download?filename=your_file.wav")
    print("3. GET /list-audio")
    print("4. GET /get-command (Now resets command to WAIT after reading)")
    print("5. POST /set-command (Requires JSON body: {\"command\": \"RECORD\", \"message\": \"Start recording now.\"}")
    print("\n*** IMPORTANT: Server is running on all interfaces (0.0.0.0) ***")
    print("Use your DHCP/local network IP (e.g., 192.168.1.50:5000) to connect from other devices.")
    print("------------------------------------------\n")

    # Run the application, binding to 0.0.0.0 to be accessible on the local network
    # Note: In a production environment, you would use gunicorn as specified in requirements.txt
    app.run(debug=True, host='0.0.0.0', port=5000)
