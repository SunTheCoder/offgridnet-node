from flask import Flask, request, jsonify, send_from_directory, redirect
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import os
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

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

# Kiwix proxy routes
@app.route('/kiwix')
@app.route('/kiwix/<path:path>')
def kiwix_proxy(path=''):
    kiwix_url = f'http://localhost:8080/{path}'
    try:
        app.logger.info(f"Proxying request to Kiwix: {kiwix_url}")
        response = requests.get(kiwix_url, timeout=10, allow_redirects=False)  # Don't follow redirects automatically
        
        # Log the response status and headers
        app.logger.info(f"Kiwix response status: {response.status_code}")
        app.logger.info(f"Kiwix response headers: {dict(response.headers)}")
        
        # If it's a redirect, modify it to stay within our network
        if response.status_code in (301, 302, 303, 307, 308):
            redirect_url = response.headers.get('Location', '')
            # Replace localhost:8080 with our local IP
            redirect_url = redirect_url.replace('http://localhost:8080', 'http://192.168.4.1/kiwix')
            app.logger.info(f"Modified Kiwix redirect to: {redirect_url}")
            return redirect(redirect_url)
        
        # Get content type
        content_type = response.headers.get('Content-Type', 'text/html')
        
        # Create response with proper headers
        headers = {
            'Content-Type': content_type,
            'Cache-Control': 'no-cache',
            'Access-Control-Allow-Origin': '*'
        }
        
        # Add any other headers from the original response
        for key, value in response.headers.items():
            if key.lower() not in ['content-length', 'content-encoding', 'transfer-encoding']:
                headers[key] = value
        
        return response.content, response.status_code, headers
    except requests.RequestException as e:
        app.logger.error(f"Kiwix proxy error: {str(e)}")
        return jsonify({
            'error': 'Kiwix service not available',
            'details': str(e)
        }), 503
    except Exception as e:
        app.logger.error(f"Unexpected error in Kiwix proxy: {str(e)}")
        return jsonify({
            'error': 'Internal server error',
            'details': str(e)
        }), 500

# Add specific routes for Kiwix content
@app.route('/content/<path:path>')
def kiwix_content(path):
    return kiwix_proxy(f'content/{path}')

@app.route('/viewer/<path:path>')
def kiwix_viewer(path):
    return kiwix_proxy(f'viewer/{path}')

@app.route('/search')
def kiwix_search():
    return kiwix_proxy('search')

@app.route('/suggest')
def kiwix_suggest():
    return kiwix_proxy('suggest')

@app.route('/catalog/<path:path>')
def kiwix_catalog(path):
    return kiwix_proxy(f'catalog/{path}')

@app.route('/raw/<path:path>')
def kiwix_raw(path):
    return kiwix_proxy(f'raw/{path}')

@app.route('/skin/<path:path>')
def kiwix_skin(path):
    return kiwix_proxy(f'skin/{path}')

# Routes
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

# Add frontend serving routes
@app.route('/')
@app.route('/journal')
@app.route('/files')
def serve_frontend():
    return send_from_directory('../frontend', 'index.html')

@app.route('/static/<path:path>')
def serve_static(path):
    return send_from_directory('../frontend/static', path)

# Error handlers
@app.errorhandler(404)
def not_found_error(error):
    return send_from_directory('../frontend', 'index.html'), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=int(os.getenv('FLASK_PORT', 5000))) 