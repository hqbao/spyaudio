import os
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory, render_template
from werkzeug.utils import secure_filename

# --- Configuration ---
UPLOAD_FOLDER = 'uploaded_audio'
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'm4a'}

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
# Disable pretty printing by default for slightly smaller API responses
app.config['JSONIFY_PRETTYPRINT_REGULAR'] = False 

# Ensure the upload and templates folders exist
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
if not os.path.exists('templates'):
    os.makedirs('templates')

# --- In-Memory Command System (Global State) ---
__command = 'WAIT'
__command_message = 'System is waiting for a command.'

def allowed_file(filename):
    """Checks if a file has an allowed audio extension."""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def create_timestamped_filename(original_filename, device_id):
    """
    Creates a unique filename combining timestamp and device ID, excluding the original base name.
    Format: <YYYYMMDDHHmmss>_<DeviceId>.<Extension>
    """
    now = datetime.now()
    timestamp = now.strftime("%Y%m%d%H%M%S")
    
    # Secure and clean the input strings
    safe_name = secure_filename(original_filename)
    safe_device_id = secure_filename(device_id)
    
    # Extract only the extension (e.g., 'wav')
    name_parts = safe_name.rsplit('.', 1)
    ext = name_parts[1] if len(name_parts) == 2 else ''

    # Final concise filename
    return f"{timestamp}_{safe_device_id}.{ext}"


# ===============================================
#              API Endpoints
# ===============================================

@app.route('/upload', methods=['POST'])
def upload_file():
    """
    Uploads an audio file and saves it using a timestamp_deviceid.ext format.
    Requires 'audio' file part and 'device_id' in form data.
    """
    if 'audio' not in request.files:
        return jsonify({"error": "No 'audio' file part in the request."}), 400
    
    file = request.files['audio']
    
    if file.filename == '':
        return jsonify({"error": "No selected file."}), 400

    device_id = request.form.get('device_id')
    if not device_id:
        return jsonify({"error": "Missing required 'device_id' in form data."}), 400

    if file and allowed_file(file.filename):
        new_filename = create_timestamped_filename(file.filename, device_id)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], new_filename)
        
        try:
            file.save(filepath)
            app.logger.info(f"File uploaded by {device_id}: {new_filename}")
            return jsonify({
                "message": "File uploaded successfully.",
                "device_id": device_id,
                "filename": new_filename,
            }), 201
        except Exception as e:
            app.logger.error(f"Error saving file: {e}")
            return jsonify({"error": f"Failed to save file: {str(e)}"}), 500
            
    else:
        return jsonify({"error": "File type not allowed. Supported formats: WAV, MP3, OGG, FLAC, M4A."}), 400

@app.route('/download', methods=['GET'])
def download_file():
    """
    Downloads a specific audio file specified by the 'filename' query parameter.
    """
    filename = request.args.get('filename')
    
    if not filename:
        return jsonify({"error": "Missing 'filename' query parameter."}), 400
    
    safe_filename = secure_filename(filename)

    try:
        return send_from_directory(
            app.config['UPLOAD_FOLDER'], 
            safe_filename, 
            as_attachment=True
        )
    except FileNotFoundError:
        return jsonify({"error": f"File '{safe_filename}' not found."}), 404
    except Exception as e:
        app.logger.error(f"Error serving file: {e}")
        return jsonify({"error": f"An error occurred during file download: {str(e)}"}), 500

@app.route('/list-audio', methods=['GET'])
def list_audio_files():
    """
    Returns a sorted list of all uploaded audio files (latest first).
    """
    try:
        # List files, filter out directories, and sort in reverse alphabetical order (latest timestamp first)
        filenames = os.listdir(app.config['UPLOAD_FOLDER'])
        audio_files = [f for f in filenames if os.path.isfile(os.path.join(app.config['UPLOAD_FOLDER'], f))]
        audio_files.sort(reverse=True) 
        
        return jsonify({
            "count": len(audio_files),
            "files": audio_files
        })
    except Exception as e:
        app.logger.error(f"Error listing files: {e}")
        return jsonify({"error": f"Failed to list files: {str(e)}"}), 500

@app.route('/get-command', methods=['GET'])
def get_command():
    """
    Retrieves the current command. If the command is not 'WAIT', it is reset to 'WAIT' after being read.
    """
    global __command, __command_message

    app.logger.info(f"Device requesting command. Current state: {__command}")

    response = {
        "command": __command,
        "message": __command_message,
    }
    
    # Reset command state if it was an active command
    if __command != 'WAIT':
        app.logger.info(f"Command '{__command}' read. Resetting command state to 'WAIT'.")
        __command = 'WAIT'
        __command_message = 'System is waiting for a command.'

    return jsonify(response)

@app.route('/set-command', methods=['POST'])
def set_command():
    """
    Sets a new command and message via a JSON request body.
    """
    global __command, __command_message

    try:
        data = request.get_json()
    except Exception:
        # Handle case where request is not valid JSON
        return jsonify({"error": "Invalid JSON request body."}), 400

    if not data or 'command' not in data or 'message' not in data:
        return jsonify({
            "error": "JSON body must contain 'command' and 'message' fields."
        }), 400
        
    new_command = data['command'].upper().strip() 
    new_message = data['message'].strip()

    if not new_command:
        return jsonify({"error": "Command field cannot be empty."}), 400

    # Update the global command state
    __command = new_command
    __command_message = new_message
    
    app.logger.info(f"Command set: {__command} with message: {__command_message}")

    return jsonify({
        "message": "Command updated successfully.",
        "current_command": __command,
        "current_message": __command_message
    }), 200

# --- Default Route and Run ---
@app.route('/')
def home():
    """Serves the main HTML control panel application."""
    return render_template('index.html')

if __name__ == '__main__':
    # Run the application with host, port, debug mode, and custom SSL context 
    app.run(
        host='0.0.0.0', 
        port=5000, 
        debug=True, 
        ssl_context=('certgen/certificate.crt', 'certgen/private.key')
    )
