#!/bin/bash

echo "🔍 Verifying repository setup..."

# Check directory structure
echo "📁 Checking directory structure..."
directories=(
    "src/main/java/com/threetier/webapp"
    "src/main/webapp/WEB-INF"
    "src/main/resources"
    "scripts"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir"
    else
        echo "  ❌ $dir (missing)"
    fi
done

# Check required files
echo "📄 Checking required files..."
files=(
    "pom.xml"
    "README.md"
    "LICENSE"
    ".gitignore"
    "scripts/build.sh"
    "scripts/deploy.sh"
    "src/main/webapp/index.html"
    "src/main/webapp/WEB-INF/web.xml"
    "src/main/java/com/threetier/webapp/DatabaseConnection.java"
    "src/main/java/com/threetier/webapp/User.java"
    "src/main/java/com/threetier/webapp/UserServlet.java"
    "src/main/java/com/threetier/webapp/HealthServlet.java"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
    fi
done

# Check script permissions
echo "🔐 Checking script permissions..."
if [ -x "scripts/build.sh" ]; then
    echo "  ✅ scripts/build.sh is executable"
else
    echo "  ❌ scripts/build.sh is not executable"
fi

if [ -x "scripts/deploy.sh" ]; then
    echo "  ✅ scripts/deploy.sh is executable"
else
    echo "  ❌ scripts/deploy.sh is not executable"
fi

echo ""
echo "🎉 Repository setup verification completed!"
echo ""
echo "Next steps:"
echo "1. Initialize git repository: git init"
echo "2. Add files to git: git add ."
echo "3. Commit files: git commit -m 'Initial commit'"
echo "4. Add remote origin: git remote add origin https://github.com/YOUR_USERNAME/three-tier-java-app.git"
echo "5. Push to GitHub: git push -u origin main"
echo ""
echo "To test locally:"
echo "1. ./scripts/build.sh"
echo "2. ./scripts/deploy.sh"
