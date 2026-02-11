
import os
import sys
import sqlite3
import hashlib
from datetime import datetime
from contextlib import closing
from flask import Flask, request, session, url_for, redirect, render_template, g, flash, jsonify
from flasgger import Swagger # openAPI Tool

################################################################################
# Configuration
################################################################################

DATABASE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'whoknows.db')
PER_PAGE = 30
DEBUG = False
SECRET_KEY = 'development key'

app = Flask(__name__)

app.secret_key = SECRET_KEY

# Initialize Flasgger for OpenAPI spec generation
swagger = Swagger(app)


################################################################################ 
# Database Functions
################################################################################

def connect_db(init_mode=False):
    """Returns a new connection to the database."""
    if not init_mode:
        check_db_exists()
    return sqlite3.connect(DATABASE_PATH)


def check_db_exists():
    """Checks if the database exists."""
    db_exists = os.path.exists(DATABASE_PATH)
    if not db_exists:
        print("Database not found")
        sys.exit(1)
    else:
        return db_exists


def init_db():
    """Creates the database tables."""
    with closing(connect_db(init_mode=True)) as db:
        with app.open_resource('../schema.sql') as f:
            db.cursor().executescript(f.read().decode('utf-8'))
        db.commit()
        print("Initialized the database: " + str(DATABASE_PATH))


def query_db(query, args=(), one=False):
    """Queries the database and returns a list of dictionaries."""
    cur = g.db.execute(query, args)
    rv = [dict((cur.description[idx][0], value)
               for idx, value in enumerate(row)) for row in cur.fetchall()]
    return (rv[0] if rv else None) if one else rv


def get_user_id(username):
    """Convenience method to look up the id for a username."""
    rv = g.db.execute("SELECT id FROM users WHERE username = '%s'" % username).fetchone()
    return rv[0] if rv else None


################################################################################
# Request Handlers
################################################################################

@app.before_request
def before_request():
    """Make sure we are connected to the database each request and look
    up the current user so that we know he's there.
    """
    g.db = connect_db()
    g.user = None
    if 'user_id' in session:
        g.user = query_db("SELECT * FROM users WHERE id = '%s'" % session['user_id'], one=True)


@app.after_request
def after_request(response):
    """Closes the database again at the end of the request."""
    g.db.close()
    return response


################################################################################
# Page Routes
################################################################################

@app.route('/')
def search():
    """Serve the root search page
    ---
    tags:
      - Pages
    parameters:
      - name: q
        in: query
        type: string
        required: false
        description: Search query (optional)
      - name: language
        in: query
        type: string
        required: false
        default: en
        description: Language code (e.g., 'en')
    responses:
      200:
        description: Returns HTML search page
        content:
          text/html:
            schema:
              type: string
    """
    q = request.args.get('q', None)
    language = request.args.get('language', "en")
    if not q:
        search_results = []
    else:
        search_results = query_db("SELECT * FROM pages WHERE language = '%s' AND content LIKE '%%%s%%'" % (language, q))

    return render_template('search.html', search_results=search_results, query=q)


@app.route('/about')
def about():
    """Serve the about page
    ---
    tags:
      - Pages
    responses:
      200:
        description: Returns HTML about page
        content:
          text/html:
            schema:
              type: string
    """
    return render_template('about.html')


@app.route('/login')
def login():
    """Serve the login page
    ---
    tags:
      - Pages
    responses:
      200:
        description: Returns HTML login page
        content:
          text/html:
            schema:
              type: string
      302:
        description: Redirects to search if already logged in
    """
    if g.user:
        return redirect(url_for('search'))
    return render_template('login.html')


@app.route('/register')
def register():
    """Serve the registration page
    ---
    tags:
      - Pages
    responses:
      200:
        description: Returns HTML registration page
        content:
          text/html:
            schema:
              type: string
      302:
        description: Redirects to search if already logged in
    """
    if g.user:
        return redirect(url_for('search'))
    return render_template('register.html')



################################################################################
# API Routes
################################################################################

@app.route('/api/search')
def api_search():
    """API endpoint for search
    ---
    tags:
        - API
    parameters:
      - name: q
        in: query
        type: string
        required: true
        description: Search query
      - name: language
        in: query
        type: string
        required: false
        description: Language code (e.g., 'en')
    responses:
      200:
        description: Search results
        schema:
          type: object
          properties:
            search_results:
              type: array
              items:
                type: object
    """
    q = request.args.get('q', None)
    language = request.args.get('language', "en")
    if not q:
        search_results = []
    else:
        search_results = query_db("SELECT * FROM pages WHERE language = '%s' AND content LIKE '%%%s%%'" % (language, q))

    return jsonify(search_results=search_results)


@app.route('/api/login', methods=['POST'])
def api_login():
    """Logs the user in
    ---
    tags:
      - API
    consumes:
      - application/x-www-form-urlencoded
    parameters:
      - name: username
        in: formData
        type: string
        required: true
        description: Username
      - name: password
        in: formData
        type: string
        required: true
        description: Password
    responses:
      200:
        description: Login successful, redirects to search page
      401:
        description: Invalid credentials
    """
    error = None
    user = query_db("SELECT * FROM users WHERE username = '%s'" % request.form['username'], one=True)
    if user is None:
        error = 'Invalid username'
    elif not verify_password(user['password'], request.form['password']):
        error = 'Invalid password'
    else:
        flash('You were logged in')
        session['user_id'] = user['id']
        return redirect(url_for('search'))
    return render_template('login.html', error=error)


@app.route('/api/register', methods=['POST'])
def api_register():
    """Registers a new user
    ---
    tags:
      - API
    consumes:
      - application/x-www-form-urlencoded
    parameters:
      - name: username
        in: formData
        type: string
        required: true
        description: Username
      - name: email
        in: formData
        type: string
        required: true
        description: Email address
      - name: password
        in: formData
        type: string
        required: true
        description: Password
      - name: password2
        in: formData
        type: string
        required: true
        description: Password confirmation
    responses:
      200:
        description: Registration successful, redirects to login
      400:
        description: Validation error
    """
    if g.user:
        return redirect(url_for('search'))
    error = None
    if not request.form['username']:
        error = 'You have to enter a username'
    elif not request.form['email'] or '@' not in request.form['email']:
        error = 'You have to enter a valid email address'
    elif not request.form['password']:
        error = 'You have to enter a password'
    elif request.form['password'] != request.form['password2']:
        error = 'The two passwords do not match'
    elif get_user_id(request.form['username']) is not None:
        error = 'The username is already taken'
    else:
        g.db.execute("INSERT INTO users (username, email, password) values ('%s', '%s', '%s')" % 
                     (request.form['username'], request.form['email'], hash_password(request.form['password'])))
        g.db.commit()
        flash('You were successfully registered and can login now')
        return redirect(url_for('login'))
    return render_template('register.html', error=error)

@app.route('/api/logout')
def logout():
    """Logs the user out
    ---
    tags:
      - API
    responses:
      200:
        description: Logout successful, redirects to search page
    """
    flash('You were logged out')
    session.pop('user_id', None)
    return redirect(url_for('search'))

################################################################################
# Security Functions
################################################################################

def hash_password(password):
    """Hash a password using md5 encryption."""
    password_bytes = password.encode('utf-8')
    hash_object = hashlib.md5(password_bytes)
    password_hash = hash_object.hexdigest()
    return password_hash

def verify_password(stored_hash, password):
    """Verify a stored password against one provided by user. Returns a boolean."""
    password_hash = hash_password(password)
    return stored_hash == password_hash


################################################################################
# Main
################################################################################
if __name__ == '__main__':
    # Try to connect to the database first
    connect_db()
    # Run the server
    # debug=True enables automatic reloading and better messaging, only for development
    app.run(host="0.0.0.0", port=8080, debug=DEBUG)
