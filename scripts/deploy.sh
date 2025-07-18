#!/bin/bash

# deploy.sh - Deploy Three Tier Java Application
# Fixed version addressing systemd service file corruption

set -e  # Exit on any error

echo "[DEPLOY] Starting deployment process..."

# Configuration variables
TOMCAT_VERSION="9.0.87"
TOMCAT_DIR="/opt/apache-tomcat-${TOMCAT_VERSION}"
TOMCAT_USER="rhel"
TOMCAT_GROUP="rhel"
WAR_FILE="/tmp/three-tier-java-app/target"
APP_NAME="app"

# Detect Java home automatically
if [ -n "$JAVA_HOME" ]; then
    echo "[DEPLOY] Using JAVA_HOME: $JAVA_HOME"
elif [ -d "/usr/lib/jvm/java-17-openjdk" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
    echo "[DEPLOY] Set JAVA_HOME to: $JAVA_HOME"
elif [ -d "/usr/lib/jvm/java-11-openjdk" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
    echo "[DEPLOY] Set JAVA_HOME to: $JAVA_HOME"
else
    echo "[ERROR] Java not found. Please install OpenJDK."
    exit 1
fi

# Function to install Tomcat
install_tomcat() {
    echo "[DEPLOY] Installing Apache Tomcat ${TOMCAT_VERSION}..."
    
    cd /opt
    
    # Download Tomcat
    echo "[DEPLOY] Downloading Tomcat..."
    sudo wget -q "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
    
    # Extract Tomcat
    echo "[DEPLOY] Extracting Tomcat..."
    sudo tar -xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz"
    
    # Set ownership
    sudo chown -R ${TOMCAT_USER}:${TOMCAT_GROUP} "${TOMCAT_DIR}"
    
    # Make scripts executable
    chmod +x "${TOMCAT_DIR}/bin/"*.sh
    
    echo "[DEPLOY] Tomcat installation completed."
}

# Function to create systemd service (FIXED - proper here-document handling)
create_tomcat_service() {
    echo "[DEPLOY] Creating Tomcat systemd service..."
    local service_file="/tmp/tomcat.service.$$"
    cat > "${service_file}" << 'EOF'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=rhel
Group=rhel
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk"
Environment="CATALINA_PID=/opt/apache-tomcat-9.0.87/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/apache-tomcat-9.0.87"
Environment="CATALINA_BASE=/opt/apache-tomcat-9.0.87"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseG1GC"
ExecStart=/opt/apache-tomcat-9.0.87/bin/startup.sh
ExecStop=/opt/apache-tomcat-9.0.87/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Copy to proper location and clean up
    sudo cp "${service_file}" /etc/systemd/system/tomcat.service
    rm -f "${service_file}"
    
    # Update Java home in service file if different
    if [ "$JAVA_HOME" != "/usr/lib/jvm/java-17-openjdk" ]; then
        sudo sed -i "s|/usr/lib/jvm/java-17-openjdk|${JAVA_HOME}|g" /etc/systemd/system/tomcat.service
    fi
    
    # Update Tomcat paths in service file
    sudo sed -i "s|/opt/apache-tomcat-9.0.87|${TOMCAT_DIR}|g" /etc/systemd/system/tomcat.service
    
    sudo systemctl daemon-reload
    echo "[DEPLOY] Tomcat service created."
}

# Function to configure firewall
configure_firewall() {
    echo "[DEPLOY] Configuring firewall..."
    
    # Check if firewalld is available and try to use it
    if systemctl list-unit-files | grep -q firewalld.service; then
        sudo systemctl enable firewalld 2>/dev/null || true
        sudo systemctl start firewalld 2>/dev/null || true
        sudo firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        echo "[DEPLOY] Firewall configured with firewalld"
    else
        echo "[DEPLOY] Firewalld not available, configuring iptables..."
        # Basic iptables rule to allow port 8080
        sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT 2>/dev/null || true
        echo "[DEPLOY] Firewall configured with iptables"
    fi
}

# Main deployment logic starts here

# Check if Tomcat is already installed
if [ ! -d "${TOMCAT_DIR}" ]; then
    install_tomcat
else
    echo "[DEPLOY] Tomcat already installed at: ${TOMCAT_DIR}"
fi

# Create systemd service if it doesn't exist
if [ ! -f "/etc/systemd/system/tomcat.service" ]; then
    create_tomcat_service
else
    echo "[DEPLOY] Tomcat service already exists."
fi

# Configure firewall
configure_firewall

# Stop Tomcat if running
echo "[DEPLOY] Stopping Tomcat if running..."
sudo systemctl stop tomcat 2>/dev/null || true

# Check for WAR file
if [ ! -f "$WAR_FILE" ]; then
    echo "[DEPLOY] $WAR_FILE file exists."
else
    echo "[DEPLOY] $WAR_FILE file does not exist."
    exit 1
fi

# Deploy new WAR file
echo "[DEPLOY] Deploying WAR file..."
sudo cp "$WAR_FILE" "${TOMCAT_DIR}/webapps/"

# Set correct ownership
sudo chown ${TOMCAT_USER}:${TOMCAT_GROUP} "${TOMCAT_DIR}/webapps/$(basename "$WAR_FILE")"

# Start Tomcat
echo "[DEPLOY] Starting Tomcat..."
sudo systemctl enable tomcat
sudo systemctl start tomcat

# Wait for deployment
echo "[DEPLOY] Waiting for application deployment..."
DEPLOYED=false
for i in {1..30}; do
    if [ -d "${TOMCAT_DIR}/webapps/${APP_NAME}" ]; then
        DEPLOYED=true
        break
    fi
    echo "[DEPLOY] Waiting for deployment... ($i/30)"
    sleep 2
done

if [ "$DEPLOYED" = true ]; then
    echo "[DEPLOY] Application deployed successfully!"
    echo "[DEPLOY] Application Name: $APP_NAME"
    echo "[DEPLOY] Tomcat Directory: $TOMCAT_DIR"
    echo "[DEPLOY] Access URL: http://localhost:8080/$APP_NAME"
    
    # Test deployment
    echo "[DEPLOY] Testing deployment..."
    sleep 5
    
    if curl -f -s "http://localhost:8080/$APP_NAME" > /dev/null 2>&1; then
        echo "[DEPLOY] ✅ Application is responding!"
    else
        echo "[DEPLOY] ⚠️  Application deployed but not responding yet. Check logs:"
        echo "         sudo journalctl -u tomcat -f"
        echo "         tail -f ${TOMCAT_DIR}/logs/catalina.out"
    fi
    
    # Show status
    echo "[DEPLOY] Service status:"
    sudo systemctl status tomcat --no-pager -l
    
else
    echo "[ERROR] Application deployment failed!"
    echo "[ERROR] Check Tomcat logs:"
    echo "        sudo journalctl -u tomcat -n 50"
    echo "        tail -f ${TOMCAT_DIR}/logs/catalina.out"
    exit 1
fi

echo "[DEPLOY] Deployment process completed."
