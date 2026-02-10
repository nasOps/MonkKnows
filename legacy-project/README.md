# ¿Who Knows? - Flask application

A search engine from 2009 built with the latest technology! Originally Python 2.7 and Flask 0.5, now upgraded to Python 3 and Flask 3.1.2.

**Note**: This application is intentionally full of problems and vulnerabilities. Do not run it in a production environment. 

## Installation

### 1. Create a virtual environment
```bash
# From project root
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install dependencies
```bash
pip install -r src/backend/requirements.txt
```

### 3. Initialize the database (optional)
```bash
# From the src/ directory
make init
```

Note: Windows does not natively support Make.

## Running the application

### Using Make (recommended)

Start a development server on port `8080`:
```bash
# From the src/ directory
make run
```

### Manual start
```bash
# Activate venv first
source venv/bin/activate

# Run the app
cd src/backend
python app.py
```

## Test the application

### Using Make
```bash
# From the src/ directory
make test
```

### Manual test
```bash
# Activate venv first
source venv/bin/activate

# Run tests
cd src/backend
python app_tests.py
```

## Python 2 → Python 3 Migration

This project was migrated from Python 2.7 to Python 3 using the `2to3` tool. Key changes:
- Updated all print statements to print() functions
- Upgraded Flask 0.5 → 3.1.2
- Upgraded Werkzeug 0.6.1 → 3.1.5
- Created virtual environment for dependency isolation

Original Python 2.7 requirements are backed up in `src/backend/requirements_backup_python2.7.txt`.