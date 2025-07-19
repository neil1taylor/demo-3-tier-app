#!/bin/bash

echo "🔄 Rebuilding and redeploying the application with health check fixes..."

# Set working directory to the project root
cd "$(dirname "$0")/.." || exit 1

# Build the application
echo "🔨 Building the application..."
./scripts/build.sh

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please check the build logs."
    exit 1
fi

# Deploy the application
echo "🚀 Deploying the application..."
./scripts/deploy.sh

# Check if deployment was successful
if [ $? -ne 0 ]; then
    echo "❌ Deployment failed. Please check the deployment logs."
    exit 1
fi

echo "✅ Application rebuilt and redeployed successfully!"
echo "🔍 Testing the new health check endpoint..."

# Wait for the application to start
echo "⏳ Waiting for the application to start..."
sleep 10

# Test the new health check endpoint
curl -s http://localhost:8080/api/system-health | jq .

echo ""
echo "📝 Note: The frontend has been updated to use the new /api/system-health endpoint"
echo "   instead of /health to avoid OpenShift's health check interception."
echo ""
echo "🌐 You can access the application at: http://localhost:8080/"
echo "🔍 You can check the detailed health status at: http://localhost:8080/api/system-health"