#!/bin/bash

# Deploy script for Three-Tier Java Application
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
TOMCAT_HOME=${TOMCAT_HOME:-/opt/tomcat}
WAR_FILE="target/app.war"
APP_NAME="app"

print_status "Starting deployment process..."
print_status "Tomcat home: $TOMCAT_HOME"
print_status "WAR file: $WAR_FILE"

# Check if WAR file exists
if [ ! -f "$WAR_FILE" ]; then
    print_error "WAR file not found: $WAR_FILE"
    print_error "Please run './scripts/build.sh' first"
    exit 1
fi

# Check if Tomcat directory exists
if [ ! -d "$TOMCAT_HOME" ]; then
    print_error "Tomcat directory not found: $TOMCAT_HOME"
    print_error "Please install Tomcat or set TOMCAT_HOME environment variable"
    exit 1
fi

# Check if webapps directory exists
if [ ! -d "$TOMCAT_HOME/webapps" ]; then
    print_error "Tomcat webapps directory not found: $TOMCAT_HOME/webapps"
    exit 1
fi

# Stop Tomcat if running
print_status "Stopping Tomcat service..."
if systemctl is-active --quiet tomcat; then
    sudo systemctl stop tomcat
    print_status "Tomcat stopped"
else
    print_warning "Tomcat service not running"
fi

# Remove old deployment
print_status "Removing old deployment..."
sudo rm -rf "$TOMCAT_HOME/webapps/${APP_NAME}"*
print_status "Old deployment removed"

# Copy new WAR file
print_status "Deploying new WAR file..."
sudo cp "$WAR_FILE" "$TOMCAT_HOME/webapps/"
sudo chown tomcat:tomcat "$TOMCAT_HOME/webapps/$(basename $WAR_FILE)"
print_status "WAR file copied"

# Start Tomcat
print_status "Starting Tomcat service..."
sudo systemctl start tomcat
sudo systemctl enable tomcat

# Wait a moment for deployment
print_status "Waiting for application deployment..."
sleep 10

# Check if Tomcat is running
if systemctl is-active --quiet tomcat; then
    print_success "Tomcat is running"
    
    # Check if application deployed
    if [ -d "$TOMCAT_HOME/webapps/$APP_NAME" ]; then
        print_success "Application deployed successfully!"
        print_success "Access the application at: http://localhost:8080/$APP_NAME/"
        print_status "Health check: http://localhost:8080/$APP_NAME/health"
        print_status "API endpoint: http://localhost:8080/$APP_NAME/api/users/"
    else
        print_warning "Application directory not found - deployment may still be in progress"
        print_status "Check Tomcat logs: sudo journalctl -u tomcat -f"
    fi
else
    print_error "Failed to start Tomcat"
    print_error "Check Tomcat logs: sudo journalctl -u tomcat -f"
    exit 1
fi

print_status "Deployment process completed"
