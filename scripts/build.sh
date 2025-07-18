#!/bin/bash
    set -e
    
    echo "[BUILD] Starting build process with Java 17..."
    
    # Set JAVA_HOME for Java 17
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
    export PATH="$JAVA_HOME/bin:$PATH"
    
    echo "[BUILD] Java version: $(java -version 2>&1 | head -1)"
    echo "[BUILD] JAVA_HOME: $JAVA_HOME"
    
    # Set Maven options for Java 17 (no MaxPermSize, use MetaspaceSize)
    export MAVEN_OPTS="-Xmx1024m -XX:MetaspaceSize=256m"
    
    # Build application with Java 17 settings
    echo "[BUILD] Building application..."
    mvn clean package \
        -DskipTests=false \
        -Dmaven.compiler.source=17 \
        -Dmaven.compiler.target=17 \
        -Dproject.build.sourceEncoding=UTF-8 \
        -Dmaven.compiler.release=17 \
        --batch-mode \
        --errors
    
    # Verify build
    # war file should be in /tmp/three-tier-java-app/target and named app.war
    if ls target/*.war 1> /dev/null 2>&1; then
        echo "[BUILD] ✅ Build successful!"
        ls -la target/*.war
    else
        echo "[BUILD] ❌ Build failed - no WAR file found"
        exit 1
    fi
