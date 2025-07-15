#!/bin/bash
    set -e
    
    echo "[DEPLOY] Starting deployment process..."
    
    # Configuration
    TOMCAT_VERSION="9.0.87"
    TOMCAT_DIR="/opt/apache-tomcat-${TOMCAT_VERSION}"
    TOMCAT_USER="rhel"
    
    # Set JAVA_HOME
    export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
    echo "[DEPLOY] Using JAVA_HOME: $JAVA_HOME"
    
    # Install Tomcat if not present
    if [ ! -d "$TOMCAT_DIR" ]; then
        echo "[DEPLOY] Installing Tomcat..."
        cd /opt
        
        # Download Tomcat
        if ! sudo wget -q "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"; then
            echo "[ERROR] Failed to download Tomcat"
            exit 1
        fi
        
        # Extract and setup
        sudo tar -xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz"
        sudo chown -R ${TOMCAT_USER}:${TOMCAT_USER} "$TOMCAT_DIR"
        chmod +x "$TOMCAT_DIR/bin/"*.sh
        
        echo "[DEPLOY] Tomcat installed at: $TOMCAT_DIR"
    fi
    
    # Create systemd service
    sudo tee /etc/systemd/system/tomcat.service > /dev/null << EOF
    [Unit]
    Description=Apache Tomcat Web Application Container
    After=network.target
    
    [Service]
    Type=forking
    User=${TOMCAT_USER}
    Group=${TOMCAT_USER}
    Environment="JAVA_HOME=${JAVA_HOME}"
    Environment="CATALINA_PID=${TOMCAT_DIR}/temp/tomcat.pid"
    Environment="CATALINA_HOME=${TOMCAT_DIR}"
    Environment="CATALINA_BASE=${TOMCAT_DIR}"
    Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server"
    ExecStart=${TOMCAT_DIR}/bin/startup.sh
    ExecStop=${TOMCAT_DIR}/bin/shutdown.sh
    RestartSec=10
    Restart=always
    
    [Install]
    WantedBy=multi-user.target
    EOF
    
    # Configure firewall (handle missing firewalld gracefully)
    echo "[DEPLOY] Configuring firewall..."
    if systemctl list-unit-files | grep -q firewalld.service; then
        sudo systemctl enable firewalld
        sudo systemctl start firewalld
        sudo firewall-cmd --permanent --add-port=8080/tcp
        sudo firewall-cmd --reload
        echo "[DEPLOY] Firewall configured with firewalld"
    else
        echo "[DEPLOY] Firewalld not available, configuring iptables..."
        # Basic iptables rule to allow port 8080
        sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
        # Save iptables rules (method varies by distribution)
        sudo service iptables save 2>/dev/null || true
        echo "[DEPLOY] Firewall configured with iptables"
    fi
    
    # Find and deploy WAR file
    WAR_FILE=$(find . -name "*.war" -type f | head -1)
    if [ -z "$WAR_FILE" ]; then
        echo "[ERROR] No WAR file found"
        exit 1
    fi
    
    echo "[DEPLOY] Deploying WAR file: $WAR_FILE"
    
    # Stop Tomcat if running
    sudo systemctl stop tomcat 2>/dev/null || true
    
    # Remove old deployment
    APP_NAME=$(basename "$WAR_FILE" .war)
    sudo rm -rf "${TOMCAT_DIR}/webapps/${APP_NAME}"
    sudo rm -f "${TOMCAT_DIR}/webapps/${APP_NAME}.war"
    
    # Deploy new WAR
    sudo cp "$WAR_FILE" "${TOMCAT_DIR}/webapps/"
    sudo chown ${TOMCAT_USER}:${TOMCAT_USER} "${TOMCAT_DIR}/webapps/$(basename "$WAR_FILE")"
    
    # Start Tomcat
    sudo systemctl daemon-reload
    sudo systemctl enable tomcat
    sudo systemctl start tomcat
    
    # Wait for deployment
    echo "[DEPLOY] Waiting for application to deploy..."
    for i in {1..30}; do
        if [ -d "${TOMCAT_DIR}/webapps/${APP_NAME}" ]; then
            echo "[DEPLOY] ✅ Application deployed successfully!"
            break
        fi
        echo "[DEPLOY] Waiting... ($i/30)"
        sleep 2
    done
    
    # Test deployment
    sleep 10
    if curl -f -s "http://localhost:8080/$APP_NAME" > /dev/null; then
        echo "[DEPLOY] ✅ Application is responding!"
    else
        echo "[DEPLOY] ⚠️ Application deployed but not responding yet"
    fi
    
    echo "[DEPLOY] Deployment completed!"
