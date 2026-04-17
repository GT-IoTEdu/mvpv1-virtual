#!/bin/bash

# Function to open a new terminal window with a command
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the parent directory
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to parent directory so all commands run from there
cd "$PARENT_DIR" || exit 1




# Copy environment file
cp backend/.env frontend/

# Stop existing containers
docker-compose down



echo "Opening terminal for uvicorn server..."

docker-compose build --no-cache
docker-compose up



