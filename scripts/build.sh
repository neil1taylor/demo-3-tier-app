#!/bin/bash

# Build script for Three-Tier Java Application
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Starting build process..."

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    print_error "Maven is not installed or not in PATH"
    exit 1
fi

# Check if Java is installed
if ! command -v java &> /dev/null; then
    print_error "Java is not installed or not in PATH"
    exit 1
fi

# Display versions
print_status "Maven version: $(mvn -version | head -n 1)"
print_status "Java version: $(java -version 2>&1 | head -n 1)"

# Clean and compile
print_status "Cleaning previous builds..."
mvn clean

print_status "Compiling and packaging application..."
mvn package -DskipTests

# Verify WAR file was created
if [ -f "target/app.war" ]; then
    print_success "Build completed successfully!"
    print_success "WAR file created: target/app.war"
    print_status "WAR file size: $(ls -lh target/app.war | awk '{print $5}')"
else
    print_error "Build failed - WAR file not found"
    exit 1
fi

print_status "Build process completed"
