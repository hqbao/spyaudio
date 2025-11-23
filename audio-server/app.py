import os
import time
from flask import Flask, request, jsonify, render_template, send_from_directory
from werkzeug.utils import secure_filename

# --- Configuration ---
UPLOAD_FOLDER = 'audio_files'
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'm4a'}

# Create the upload directory if it doesn't exist
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app = Flask(__name__, template_folder='templates')
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# --- Global Command State (In-Memory) ---
# NOTE: This state is simple and non-persistent for demonstration.
current_command = {
    'command': 'WAIT',
    'message': 'Waiting for command...',
    'timestamp': time.time()
}

# --- Utility Functions ---
def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# --- API Endpoints ---

@app.route('/')
def index():
    """Renders the main control panel (templates/index.html)."""
    # NOTE: The provided HTML file (templates/index.html) is expected to be in a 'templates' folder.
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    """Handles audio file uploads, now requiring a device_id in the form data."""
    if 'audio' not in request.files:
        return jsonify({'error': 'No audio file part in the request'}), 400
    
    file = request.files['audio']
    
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
        
    if file and allowed_file(file.filename):
        # 1. Get Device ID from form data
        # The client must now submit 'device_id' as a form field alongside 'audio'
        device_id = request.form.get('device_id')
        if not device_id:
            # Fallback for when the device ID is missing
            device_id = 'unknown' 
        
        # Ensure the device_id is safe for filenames
        safe_device_id = secure_filename(device_id)

        # Create a unique, timestamped filename
        extension = file.filename.rsplit('.', 1)[1].lower()
        timestamp = int(time.time() * 1000) # milliseconds
        
        # 2. Construct the new filename: <timestamp>_<device_id>.<ext>
        new_filename = f'{timestamp}_{safe_device_id}.{extension}' 
        
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], new_filename)
        file.save(filepath)
        
        return jsonify({
            'message': 'File uploaded successfully',
            'filename': new_filename,
            'path': filepath
        })
    
    return jsonify({'error': 'File type not allowed'}), 400

@app.route('/download', methods=['GET'])
def download_file():
    """Handles audio file downloads."""
    filename = request.args.get('filename')
    if not filename:
        return jsonify({'error': 'Filename parameter is missing'}), 400
    
    # Ensure filename is safe to prevent directory traversal
    safe_filename = secure_filename(filename)
    
    # Check if the file exists
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], safe_filename)
    if not os.path.exists(filepath):
         return jsonify({'error': 'File not found'}), 404

    # Send the file for download
    return send_from_directory(
        app.config['UPLOAD_FOLDER'], 
        safe_filename, 
        as_attachment=True,
        mimetype='audio/*'
    )


@app.route('/list-audio', methods=['GET'])
def list_audio():
    """
    Retrieves a list of uploaded audio files,
    filtering out system files like .DS_Store.
    """
    try:
        # Get all entries in the upload folder
        all_entries = os.listdir(app.config['UPLOAD_FOLDER'])
        
        # Filter: 
        # 1. Must not start with a dot (filters out .DS_Store)
        # 2. Must be an actual file, not a directory
        audio_files = sorted([
            f for f in all_entries 
            if not f.startswith('.') 
            and os.path.isfile(os.path.join(app.config['UPLOAD_FOLDER'], f))
        ])
        
        return jsonify({
            'count': len(audio_files),
            'files': audio_files
        })
    except Exception as e:
        # Log the error (optional)
        print(f"Error listing files: {e}")
        return jsonify({'error': 'Internal server error while listing files'}), 500


@app.route('/set-command', methods=['POST'])
def set_command():
    """Sets the new command and message."""
    global current_command
    data = request.get_json()
    
    if not data or 'command' not in data or 'message' not in data:
        return jsonify({'error': 'Missing command or message in request body'}), 400
        
    new_command = data['command'].upper()
    new_message = data['message']
    
    current_command.update({
        'command': new_command,
        'message': new_message,
        'timestamp': time.time()
    })
    
    return jsonify({
        'message': 'Command updated',
        'current_command': new_command,
        'current_message': new_message
    })

@app.route('/get-command', methods=['GET'])
def get_command():
    """
    Retrieves the current command. Resets to 'WAIT' if the command was read
    and was not already 'WAIT'.
    """
    global current_command
    
    # Check if a command is pending (i.e., not 'WAIT')
    if current_command['command'] != 'WAIT':
        response = current_command.copy()
        
        # Reset the command state immediately after reading
        current_command.update({
            'command': 'WAIT',
            'message': 'Waiting for command...',
            'timestamp': time.time()
        })
        
        return jsonify(response)
    else:
        # If already 'WAIT', return the current state without resetting
        return jsonify(current_command)


if __name__ == '__main__':
    # Run the application with host, port, debug mode, and custom SSL context 
    app.run(
        host='0.0.0.0', 
        port=8000, 
        debug=True, 
        ssl_context=('certgen/certificate.crt', 'certgen/private.key')
    )
