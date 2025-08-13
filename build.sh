#!/bin/bash

# Simple build script for MultiPing
# This creates a standalone app bundle that you can run

echo "🔨 Building MultiPing..."

# Create build directory
mkdir -p build/MultiPing.app/Contents/MacOS
mkdir -p build/MultiPing.app/Contents/Resources

# Copy Info.plist
cp MultiPing/Info.plist build/MultiPing.app/Contents/

# Try to compile with swiftc directly
echo "📦 Compiling Swift files..."

/usr/bin/swift build --configuration release --product MultiPing 2>/dev/null || {
    echo "❌ Swift build failed. Trying alternative approach..."
    
    # Alternative: compile individual files
    cd MultiPing
    
    # Find all Swift files
    SWIFT_FILES=$(find . -name "*.swift" | tr '\n' ' ')
    
    echo "Found Swift files: $SWIFT_FILES"
    
    # Try to compile them together
    swiftc $SWIFT_FILES -o ../build/MultiPing.app/Contents/MacOS/MultiPing \
        -framework AppKit -framework SwiftUI -framework Foundation -framework Combine \
        -target x86_64-apple-macos13.0 2>/dev/null || {
        echo "❌ Direct compilation failed."
        echo "📱 Please try opening the project in a different way."
        exit 1
    }
    
    cd ..
}

# Make executable
chmod +x build/MultiPing.app/Contents/MacOS/MultiPing

echo "✅ Build complete! App created at: build/MultiPing.app"
echo "🚀 To run: open build/MultiPing.app"