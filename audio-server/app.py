import os
import json
from flask import Flask, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename
from datetime import datetime # Imported for generating timestamped filenames

# --- Configuration ---
# Folder where uploaded files will be stored, now named 'audio'
UPLOAD_FOLDER = 'audio'
# File to store the current command status for clients
COMMAND_FILE = 'command_status.json'
# Allowed file extensions for uploads
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'm4a'}

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# --- Utility Functions ---

def allowed_file(filename):
    """Check if the file extension is allowed."""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def initialize_app_environment():
    """Create the audio directory and initial command file if they don't exist."""
    # Create UPLOAD_FOLDER (which is now 'audio')
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)
        print(f"Created directory: {UPLOAD_FOLDER}")

    # Create initial command file
    if not os.path.exists(COMMAND_FILE):
        initial_command = {
            "id": 1,
            "command": "WAIT",
            "message": "Waiting for instruction from server operator."
        }
        with open(COMMAND_FILE, 'w') as f:
            json.dump(initial_command, f, indent=4)
        print(f"Created initial command file: {COMMAND_FILE}")

def update_command(cmd, msg, cmd_id=1):
    """Internal function to update the command status for the /get-command endpoint."""
    try:
        data = {
            "id": cmd_id,
            "command": cmd.upper(),
            "message": msg
        }
        with open(COMMAND_FILE, 'w') as f:
            json.dump(data, f, indent=4)
        print(f"Command updated to: {cmd.upper()}")
        return True
    except Exception as e:
        print(f"Error updating command file: {e}")
        return False

# --- Endpoints ---

@app.route('/upload', methods=['POST'])
def upload_file():
    """Endpoint 1: POST /upload - Receives and saves an audio file with a date-based name."""
    # Check if the POST request has the file part
    if 'audio' not in request.files:
        return jsonify({"message": "No 'audio' file part in the request"}), 400

    file = request.files['audio']

    # If the user does not select a file, the browser submits an empty part
    if file.filename == '':
        return jsonify({"message": "No selected file"}), 400

    if file and allowed_file(file.filename):
        # Get the original extension safely
        original_filename = secure_filename(file.filename)
        _, file_extension = os.path.splitext(original_filename)

        # Generate a new filename based on the current date and time
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        new_filename = f"{timestamp}{file_extension}"
        
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], new_filename)
        
        try:
            # Save the file
            file.save(filepath)

            # Optionally, update the command to WAIT after a successful upload
            update_command("WAIT", f"Successfully received {new_filename}.", request.form.get('command_id', 2))

            return jsonify({
                "message": "File successfully uploaded",
                "filename": new_filename, # Return the new, timestamped filename
                "filepath": filepath
            }), 201
        except Exception as e:
            # Handle file saving errors
            return jsonify({"message": f"Server error during file save: {e}"}), 500

    return jsonify({"message": "File type not allowed"}), 400


@app.route('/download', methods=['GET'])
def download_file():
    """Endpoint 2: GET /download - Sends a specific audio file for download."""
    
    # Get the filename from the query parameter
    filename = request.args.get('filename')
    
    if not filename:
        return jsonify({"message": "Missing 'filename' query parameter"}), 400
    
    # Check if the file exists in the audio directory
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(filename))
    
    if not os.path.exists(filepath):
        return jsonify({"message": f"File '{filename}' not found"}), 404
        
    try:
        # Use send_from_directory to safely serve files
        return send_from_directory(
            app.config['UPLOAD_FOLDER'], 
            secure_filename(filename), 
            as_attachment=True
        )
    except Exception as e:
        # Handle server errors during file transfer
        return jsonify({"message": f"Server error during file download: {e}"}), 500


@app.route('/list-audio', methods=['GET'])
def list_audio_files():
    """Endpoint 3: GET /list-audio - Returns a list of all uploaded audio filenames."""
    try:
        # Get all entries in the upload folder
        all_entries = os.listdir(app.config['UPLOAD_FOLDER'])
        
        # Filter for actual files and check for allowed extensions
        audio_files = []
        for entry in all_entries:
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], entry)
            # Ensure it's a file and has an allowed extension
            if os.path.isfile(filepath) and allowed_file(entry):
                audio_files.append(entry)
                
        # Sort the list, usually by name/timestamp (newest first)
        audio_files.sort(reverse=True)
        
        return jsonify({
            "message": f"Found {len(audio_files)} audio files.",
            "files": audio_files
        }), 200

    except FileNotFoundError:
        return jsonify({"message": f"Upload directory '{app.config['UPLOAD_FOLDER']}' not found."}), 500
    except Exception as e:
        return jsonify({"message": f"An unexpected error occurred: {e}"}), 500


@app.route('/get-command', methods=['GET'])
def get_command():
    """Endpoint 4: GET /get-command - Returns the current command for the client."""
    try:
        with open(COMMAND_FILE, 'r') as f:
            command_data = json.load(f)
        
        return jsonify(command_data), 200
        
    except FileNotFoundError:
        return jsonify({"message": "Command file not initialized"}), 500
    except json.JSONDecodeError:
        return jsonify({"message": "Error decoding command file"}), 500
    except Exception as e:
        return jsonify({"message": f"An unexpected error occurred: {e}"}), 500

# --- Server Startup ---

if __name__ == '__main__':
    # Initialize the necessary environment (folder, command file)
    initialize_app_environment()
    
    print("\n--- Audio Command Server Initialized ---")
    print(f"Uploads will be saved to the '{UPLOAD_FOLDER}' directory with a date/time stamp.")
    print("To test the server, run it and try these endpoints:")
    print("1. POST /upload (with a file named 'audio')")
    print("2. GET /download?filename=your_file.wav")
    print("3. GET /list-audio")
    print("4. GET /get-command")
    print("\n*** IMPORTANT: Server is running on all interfaces (0.0.0.0) ***")
    print("Use your DHCP/local network IP (e.g., 192.168.1.50:5000) to connect from other devices.")
    print("------------------------------------------\n")

    # Run the application, binding to 0.0.0.0 to be accessible on the local network
    app.run(debug=True, host='0.0.0.0', port=5000)