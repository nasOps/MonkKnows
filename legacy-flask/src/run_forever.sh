#!/bin/bash

# Aktiver virtual environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
source venv/bin/activate

PYTHON_SCRIPT_PATH="$1"

# Validér at et argument blev givet
if [ -z "$PYTHON_SCRIPT_PATH" ]; then
    echo "Usage: $0 <path_to_python_script>" >&2
    exit 1
fi

while true
do
    python "$PYTHON_SCRIPT_PATH"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Script crashed with exit code $exit_code. Restarting..." >&2
        sleep 1
    fi
done