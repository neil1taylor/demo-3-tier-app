#!/bin/bash

# build.sh - Build Three Tier Java Application
# Fixed version addressing multiple issues

set -e  # Exit on any error

echo "[BUILD] Starting build process..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect and set JAVA_HOME
setup_java() {
    echo "[BUILD] Setting up Java environment..."
    
    if [ -n "$JAVA_HOME" ]; then
        echo "[BUILD] Using existing JAVA_HOME: $JAVA_HOME"
    elif [ -d "/usr/lib/jvm/java-17-openjdk" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
        echo "[BUILD] Set JAVA_HOME to: $JAVA_HOME"
    elif [ -d "/usr/lib/jvm/java-11-openjdk" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
        echo "[BUILD] Set JAVA_HOME to: $JAVA_HOME"
    elif [ -d "/usr/lib/jvm/java-8-openjdk" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-8-openjdk"
        echo "[BUILD] Set JAVA_HOME to: $JAVA_HOME"
    else
        echo "[ERROR] Java not found. Please install OpenJDK:"
        echo "        sudo dnf install -y java-11-openjdk java-11-openjdk-devel"
        exit 1
    fi
    
    # Add Java to PATH if not already there
    if [[ ":$PATH:" != *":$JAVA_HOME/bin:"* ]]; then
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
}

# Function to install dependencies
install_dependencies() {
    echo "[BUILD] Checking dependencies..."
    
    local missing_deps=()
    
    if ! command_exists java; then
        missing_deps+=("java-11-openjdk java-11-openjdk-devel")
    fi
    
    if ! command_exists mvn; then
        missing_deps+=("maven")
    fi
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "[BUILD] Installing missing dependencies: ${missing_deps[*]}"
        
        # Detect package manager and install
        if command_exists dnf; then
            sudo dnf install -y "${missing_deps[@]}"
        elif command_exists yum; then
            sudo yum install -y "${missing_deps[@]}"
        elif command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y openjdk-11-jdk maven git
        else
            echo "[ERROR] Cannot detect package manager. Please install manually:"
            echo "        ${missing_deps[*]}"
            exit 1
        fi
    else
        echo "[BUILD] All dependencies are available."
    fi
}

# Function to display version information
show_versions() {
    echo "[BUILD] Version information:"
    
    if command_exists mvn; then
        echo "[BUILD] Maven version: $(mvn --version | head -1)"
    fi
    
    if command_exists java; then
        echo "[BUILD] Java version: $(java -version 2>&1 | head -1)"
    fi
    
    if [ -n "$JAVA_HOME" ]; then
        echo "[BUILD] JAVA_HOME: $JAVA_HOME"
    fi
}

# Function to clean previous builds
clean_build() {
    echo "[BUILD] Cleaning previous builds..."
    
    # Use Maven clean but handle permission issues
    if [ -d "target" ]; then
        # Try Maven clean first
        if ! mvn clean -q 2>/dev/null; then
            echo "[BUILD] Maven clean failed, using manual cleanup..."
            # Manual cleanup with proper permissions
            chmod -R u+w target/ 2>/dev/null || true
            rm -rf target/
        fi
    fi
    
    echo "[BUILD] Clean completed."
}

# Function to compile and package
build_application() {
    echo "[BUILD] Compiling and packaging application..."
    
    # Set Maven options for better performance and error handling
    export MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=256m"
    
    # Build with appropriate options
    mvn package \
        -DskipTests=false \
        -Dmaven.compiler.source=11 \
        -Dmaven.compiler.target=11 \
        -Dproject.build.sourceEncoding=UTF-8 \
        --batch-mode \
        --errors \
        --fail-at-end \
        --show-version
    
    echo "[BUILD] Build completed successfully."
}

# Function to verify build artifacts
verify_build() {
    echo "[BUILD] Verifying build artifacts..."
    
    if [ ! -d "target" ]; then
        echo "[ERROR] Target directory not found!"
        exit 1
    fi
    
    # Find WAR files
    WAR_FILES=(target/*.war)
    
    if [ ! -e "${WAR_FILES[0]}" ]; then
        echo "[ERROR] No WAR file found in target directory!"
        echo "[ERROR] Contents of target directory:"
        ls -la target/ || echo "Target directory is empty"
        exit 1
    fi
    
    for war_file in "${WAR_FILES[@]}"; do
        if [ -f "$war_file" ]; then
            file_size=$(stat -f%z "$war_file" 2>/dev/null || stat -c%s "$war_file" 2>/dev/null || echo "unknown")
            echo "[BUILD] ✅ Found WAR file: $war_file (size: $file_size bytes)"
            
            # Verify WAR file is not corrupted
            if command_exists unzip; then
                if unzip -t "$war_file" >/dev/null 2>&1; then
                    echo "[BUILD] ✅ WAR file integrity verified"
                else
                    echo "[ERROR] WAR file appears to be corrupted!"
                    exit 1
                fi
            fi
        fi
    done
}

# Function to show build summary
show_summary() {
    echo "[BUILD] Build Summary:"
    echo "[BUILD] =================="
    
    if [ -d "target" ]; then
        echo "[BUILD] Artifacts created:"
        find target -name "*.war" -o -name "*.jar" | while read -r file; do
            file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown")
            echo "[BUILD]   - $(basename "$file") ($file_size bytes)"
        done
    fi
    
    echo "[BUILD] Next steps:"
    echo "[BUILD]   1. Deploy with: ./scripts/deploy.sh"
    echo "[BUILD]   2. Or manually copy WAR to Tomcat: sudo cp target/*.war /opt/apache-tomcat-*/webapps/"
}

# Main execution
main() {
    # Check if we're in the right directory
    if [ ! -f "pom.xml" ]; then
        echo "[ERROR] pom.xml not found. Are you in the project root directory?"
        echo "[ERROR] Please run this script from the directory containing pom.xml"
        exit 1
    fi
    
    # Install dependencies if needed
    install_dependencies
    
    # Setup Java environment
    setup_java
    
    # Show version information
    show_versions
    
    # Clean previous builds
    clean_build
    
    # Build the application
    build_application
    
    # Verify build artifacts
    verify_build
    
    # Show summary
    show_summary
    
    echo "[BUILD] Build process completed successfully!"
}

# Run main function
main "$@"
