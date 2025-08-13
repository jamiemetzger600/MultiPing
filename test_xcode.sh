#!/bin/bash

echo "🔍 Testing different ways to open the project..."

# Method 1: Try opening with specific Xcode version
echo "1️⃣ Trying to open with Xcode directly..."
open -a "Xcode" MultiPing.xcodeproj 2>/dev/null && {
    echo "✅ Opened with Xcode app"
    exit 0
}

# Method 2: Try opening workspace if it exists
if [ -f "MultiPing.xcworkspace" ]; then
    echo "2️⃣ Trying workspace..."
    open MultiPing.xcworkspace 2>/dev/null && {
        echo "✅ Opened workspace"
        exit 0
    }
fi

# Method 3: Try creating a new project with same files
echo "3️⃣ Creating simplified project structure..."
mkdir -p simple_build
cd simple_build

# Create a minimal Swift file that includes our main components
cat > main.swift << 'EOF'
import AppKit
import SwiftUI

// Import our source files by including them directly
EOF

# Copy source files
cp ../MultiPing/*.swift . 2>/dev/null

echo "📁 Files copied to simple_build/"
echo "💡 You can try compiling these directly with:"
echo "   cd simple_build"
echo "   swiftc *.swift -framework AppKit -framework SwiftUI -o MultiPing"

cd ..

echo "❌ Could not open project in Xcode. Try the alternatives above."