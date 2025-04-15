from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import os
import shutil
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Define paths
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
REPO_FRONTEND = os.path.join(REPO_ROOT, 'frontend')
WEB_ROOT = '/var/www/html'

def sync_frontend_files():
    """Copy frontend files from repo to web root"""
    try:
        # Create web root if it doesn't exist
        os.makedirs(WEB_ROOT, exist_ok=True)
        
        # Copy index.html
        shutil.copy2(
            os.path.join(REPO_FRONTEND, 'index.html'),
            os.path.join(WEB_ROOT, 'index.html')
        )
        
        # Copy static directory
        static_src = os.path.join(REPO_FRONTEND, 'static')
        static_dst = os.path.join(WEB_ROOT, 'static')
        if os.path.exists(static_dst):
            shutil.rmtree(static_dst)
        shutil.copytree(static_src, static_dst)
        
        print(f"Synced frontend files from {REPO_FRONTEND} to {WEB_ROOT}")
    except Exception as e:
        print(f"Error syncing frontend files: {e}")

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('FLASK_SECRET_KEY')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///offgridnet.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize extensions
db = SQLAlchemy(app)
CORS(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Models
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    journal_entries = db.relationship('JournalEntry', backref='author', lazy=True)

class JournalEntry(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    content = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Routes
@app.route('/')
def serve_frontend():
    return send_from_directory(WEB_ROOT, 'index.html')

@app.route('/static/<path:path>')
def serve_static(path):
    return send_from_directory(os.path.join(WEB_ROOT, 'static'), path)

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(username=data['username']).first()
    
    if user and check_password_hash(user.password_hash, data['password']):
        login_user(user)
        return jsonify({'message': 'Logged in successfully'})
    return jsonify({'message': 'Invalid credentials'}), 401

@app.route('/api/logout')
@login_required
def logout():
    logout_user()
    return jsonify({'message': 'Logged out successfully'})

@app.route('/api/journal', methods=['GET', 'POST'])
@login_required
def journal():
    if request.method == 'POST':
        data = request.get_json()
        entry = JournalEntry(content=data['content'], user_id=current_user.id)
        db.session.add(entry)
        db.session.commit()
        return jsonify({'message': 'Entry created successfully'})
    
    entries = JournalEntry.query.filter_by(user_id=current_user.id).order_by(JournalEntry.timestamp.desc()).all()
    return jsonify([{
        'id': entry.id,
        'content': entry.content,
        'timestamp': entry.timestamp.isoformat()
    } for entry in entries])

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        # Sync frontend files on startup
        sync_frontend_files()
    app.run(host='0.0.0.0', port=int(os.getenv('FLASK_PORT', 5000))) 