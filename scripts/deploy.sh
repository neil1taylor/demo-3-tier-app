#!/bin/bash

# Three-tier Java Application Deployment Script
# This script sets up and deploys a Java web application with Tomcat

set -e  # Exit on any error

echo "[DEPLOY] Starting deployment process..."

# Set Java environment (CentOS Stream 9 specific path)
if [ -d "/usr/lib/jvm/java-17-openjdk" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
elif [ -d "/usr/lib/jvm/java-17-openjdk-17.0.0.35-2.el9_0.x86_64" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-17.0.0.35-2.el9_0.x86_64
else
    # Find the Java 17 installation dynamically
    export JAVA_HOME=$(find /usr/lib/jvm -name "java-17-openjdk*" -type d | head -1)
fi
echo "[DEPLOY] Set JAVA_HOME to: $JAVA_HOME"

# Define variables
TOMCAT_VERSION="9.0.87"
TOMCAT_DIR="/opt/tomcat"
TOMCAT_USER="tomcat"
APP_SOURCE_DIR="/tmp/three-tier-java-app"
WAR_FILE="three-tier-app.war"

# Install Java if not present
if ! command -v java &> /dev/null; then
    echo "[DEPLOY] Installing Java 17..."
    dnf update -y
    dnf install -y java-17-openjdk java-17-openjdk-devel wget curl
fi

# Create tomcat user
if ! id "$TOMCAT_USER" &>/dev/null; then
    echo "[DEPLOY] Creating tomcat user..."
    useradd -m -d $TOMCAT_DIR -U -s /bin/false $TOMCAT_USER
fi

# Download and install Tomcat
echo "[DEPLOY] Installing Apache Tomcat $TOMCAT_VERSION..."
echo "[DEPLOY] Downloading Tomcat..."

cd /tmp
if [ ! -f "apache-tomcat-$TOMCAT_VERSION.tar.gz" ]; then
    # Use multiple mirror attempts for better reliability
    if ! wget -q "https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"; then
        echo "[DEPLOY] Primary mirror failed, trying alternative..."
        wget -q "https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz" || {
            echo "[DEPLOY] ERROR: Failed to download Tomcat"
            exit 1
        }
    fi
fi

echo "[DEPLOY] Extracting Tomcat..."
tar -xzf apache-tomcat-$TOMCAT_VERSION.tar.gz

# Remove existing Tomcat directory if present
if [ -d "$TOMCAT_DIR" ]; then
    echo "[DEPLOY] Removing existing Tomcat installation..."
    rm -rf $TOMCAT_DIR
fi

# Move Tomcat to final location
mv apache-tomcat-$TOMCAT_VERSION $TOMCAT_DIR
chown -R $TOMCAT_USER:$TOMCAT_USER $TOMCAT_DIR
chmod +x $TOMCAT_DIR/bin/*.sh

echo "[DEPLOY] Tomcat installation completed."

# Create systemd service file for CentOS Stream 9
echo "[DEPLOY] Creating Tomcat systemd service..."
cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=$TOMCAT_USER
Group=$TOMCAT_USER

Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=$TOMCAT_DIR/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_DIR
Environment=CATALINA_BASE=$TOMCAT_DIR
Environment=CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC
Environment=JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom

ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh
SuccessExitStatus=143

RestartSec=10
Restart=always
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Ensure proper SELinux context for CentOS Stream 9
if command -v setsebool &> /dev/null; then
    echo "[DEPLOY] Configuring SELinux for Tomcat..."
    setsebool -P httpd_can_network_connect 1 2>/dev/null || true
    restorecon -R $TOMCAT_DIR 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable tomcat

echo "[DEPLOY] Tomcat service created."

# Configure firewall for CentOS Stream 9
echo "[DEPLOY] Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    # Ensure firewalld is installed
    if ! systemctl is-enabled firewalld &>/dev/null; then
        dnf install -y firewalld
    fi
    
    systemctl start firewalld
    systemctl enable firewalld
    
    # Wait for firewalld to be ready
    sleep 2
    
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
    echo "[DEPLOY] Firewall configured with firewalld"
else
    echo "[DEPLOY] Installing and configuring firewalld..."
    dnf install -y firewalld
    systemctl start firewalld
    systemctl enable firewalld
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
    echo "[DEPLOY] Firewall installed and configured"
fi

# Stop Tomcat if running
echo "[DEPLOY] Stopping Tomcat if running..."
systemctl stop tomcat 2>/dev/null || true

# Handle WAR file deployment
echo "[DEPLOY] Checking for application files..."

# Determine the correct source directory (could be current directory or /tmp)
if [ -d "/tmp/three-tier-java-app" ]; then
    APP_SOURCE_DIR="/tmp/three-tier-java-app"
elif [ -d "./target" ]; then
    APP_SOURCE_DIR="$(pwd)"
elif [ -d "../target" ]; then
    APP_SOURCE_DIR="$(cd .. && pwd)"
else
    echo "[DEPLOY] ERROR: Cannot find application source directory!"
    echo "[DEPLOY] Current directory: $(pwd)"
    echo "[DEPLOY] Contents:"
    ls -la
    exit 1
fi

echo "[DEPLOY] Using source directory: $APP_SOURCE_DIR"

if [ -d "$APP_SOURCE_DIR" ]; then
    echo "[DEPLOY] $APP_SOURCE_DIR directory exists."
    
    # Check if target directory exists and contains WAR file
    if [ -d "$APP_SOURCE_DIR/target" ]; then
        echo "[DEPLOY] Target directory found."
        echo "[DEPLOY] Target directory contents:"
        ls -la "$APP_SOURCE_DIR/target/"
        
        # Look for WAR file in target directory
        WAR_PATH=$(find "$APP_SOURCE_DIR/target" -name "*.war" -type f | head -1)
        
        if [ -n "$WAR_PATH" ] && [ -f "$WAR_PATH" ]; then
            echo "[DEPLOY] Found WAR file: $WAR_PATH"
            WAR_SIZE=$(stat -c%s "$WAR_PATH")
            echo "[DEPLOY] WAR file size: $WAR_SIZE bytes"
            
            if [ "$WAR_SIZE" -lt 1000 ]; then
                echo "[DEPLOY] WARNING: WAR file seems too small, this might indicate a build issue"
            fi
            
            echo "[DEPLOY] Deploying WAR file..."
            
            # Remove existing webapps
            rm -rf $TOMCAT_DIR/webapps/ROOT
            rm -rf $TOMCAT_DIR/webapps/ROOT.war
            
            # Copy WAR file
            cp "$WAR_PATH" "$TOMCAT_DIR/webapps/ROOT.war"
            chown $TOMCAT_USER:$TOMCAT_USER "$TOMCAT_DIR/webapps/ROOT.war"
            
            echo "[DEPLOY] WAR file deployed successfully."
            echo "[DEPLOY] Deployed WAR file size: $(stat -c%s "$TOMCAT_DIR/webapps/ROOT.war") bytes"
        else
            echo "[DEPLOY] ERROR: No WAR file found in target directory!"
            echo "[DEPLOY] Contents of target directory:"
            find "$APP_SOURCE_DIR/target" -type f -exec ls -la {} \; 2>/dev/null || echo "Cannot list target directory files"
            
            # Check if there are any JAR files that might be the issue
            JAR_FILES=$(find "$APP_SOURCE_DIR/target" -name "*.jar" -type f 2>/dev/null)
            if [ -n "$JAR_FILES" ]; then
                echo "[DEPLOY] Found JAR files instead of WAR:"
                echo "$JAR_FILES"
                echo "[DEPLOY] This suggests the project might be configured as a JAR project instead of WAR"
            fi
            exit 1
        fi
    else
        echo "[DEPLOY] ERROR: Target directory not found!"
        echo "[DEPLOY] Contents of application directory:"
        ls -la "$APP_SOURCE_DIR/" || echo "Cannot list application directory"
        
        # Check if Maven build was successful
        if [ -f "$APP_SOURCE_DIR/pom.xml" ]; then
            echo "[DEPLOY] Found pom.xml, checking Maven configuration..."
            grep -n "packaging" "$APP_SOURCE_DIR/pom.xml" || echo "No packaging configuration found"
        fi
        exit 1
    fi
else
    echo "[DEPLOY] ERROR: Application source directory $APP_SOURCE_DIR not found!"
    exit 1
fi

# Start Tomcat
echo "[DEPLOY] Starting Tomcat..."
systemctl start tomcat

# Wait for Tomcat to start
echo "[DEPLOY] Waiting for Tomcat to start..."
sleep 10

# Check if Tomcat is running
if systemctl is-active --quiet tomcat; then
    echo "[DEPLOY] Tomcat started successfully."
    
    # Check if application is accessible
    sleep 5
    if curl -f http://localhost:8080 > /dev/null 2>&1; then
        echo "[DEPLOY] Application is accessible on port 8080."
    else
        echo "[DEPLOY] WARNING: Application may not be fully started yet."
    fi
else
    echo "[DEPLOY] ERROR: Tomcat failed to start!"
    systemctl status tomcat
    exit 1
fi

echo "[DEPLOY] Deployment completed successfully!"
