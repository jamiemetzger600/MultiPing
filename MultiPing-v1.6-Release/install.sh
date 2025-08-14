#!/bin/bash

# MultiPing v1.6 Installation Script
echo "🚀 MultiPing v1.6 Installation & Launch"
echo "========================================"

# Check if the executable exists
if [ ! -f "MultiPing-v1.6-executable" ]; then
    echo "❌ Error: MultiPing-v1.6-executable not found in current directory"
    echo "Please make sure you're running this script from the same directory as the executable"
    exit 1
fi

# Make executable
echo "📝 Making MultiPing executable..."
chmod +x MultiPing-v1.6-executable

# Check if it's now executable and launch it
if [ -x "MultiPing-v1.6-executable" ]; then
    echo "✅ MultiPing is now executable!"
    echo ""
    echo "🚀 Launching MultiPing (background process)..."
    
    # Launch MultiPing in background, detached from terminal
    nohup ./MultiPing-v1.6-executable > /dev/null 2>&1 &
    
    echo "📱 MultiPing is now running in your menubar (top-right of screen)"
    echo "   Click the menubar icon to access all features"
    echo ""
    echo "✅ Installation complete! You can close this terminal."
    echo ""
else
    echo "❌ Error: Failed to make MultiPing executable"
    exit 1
fi
