#!/bin/bash
    set -e
    
    echo "[BUILD] Starting build process..."
    
    # Set JAVA_HOME for Java 11 (compatible with Maven)
    export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
    export PATH="$JAVA_HOME/bin:$PATH"
    
    echo "[BUILD] Java version: $(java -version 2>&1 | head -1)"
    echo "[BUILD] JAVA_HOME: $JAVA_HOME"
    
    # Clean previous builds
    echo "[BUILD] Cleaning previous builds..."
    if [ -d "target" ]; then
        chmod -R u+w target/ 2>/dev/null || true
        rm -rf target/
    fi
    
    # Set Maven options for Java 11
    export MAVEN_OPTS="-Xmx1024m -XX:MetaspaceSize=256m"
    
    # Build application
    echo "[BUILD] Building application..."
    mvn clean package \
        -DskipTests=false \
        -Dmaven.compiler.source=11 \
        -Dmaven.compiler.target=11 \
        -Dproject.build.sourceEncoding=UTF-8 \
        --batch-mode \
        --errors
    
    # Verify build
    if [ -f target/*.war ]; then
        echo "[BUILD] ✅ Build successful!"
        ls -la target/*.war
    else
        echo "[BUILD] ❌ Build failed - no WAR file found"
        exit 1
    fi
