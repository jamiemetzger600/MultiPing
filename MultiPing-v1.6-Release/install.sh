#!/bin/bash

# MultiPing v1.6 Installation Script
echo "🚀 MultiPing v1.6 Installation"
echo "================================"

# Check if the executable exists
if [ ! -f "MultiPing-v1.6-release" ]; then
    echo "❌ Error: MultiPing-v1.6-release not found in current directory"
    echo "Please make sure you're running this script from the same directory as the executable"
    exit 1
fi

# Make executable
echo "📝 Making MultiPing executable..."
chmod +x MultiPing-v1.6-release

# Check if it's now executable
if [ -x "MultiPing-v1.6-release" ]; then
    echo "✅ MultiPing is now executable!"
    echo ""
    echo "🎯 To run MultiPing:"
    echo "   ./MultiPing-v1.6-release"
    echo ""
    echo "📱 MultiPing will appear in your menubar (top-right of screen)"
    echo "   Click the menubar icon to access all features"
    echo ""
    echo "📖 For more information, see RELEASE_NOTES_v1.6.md"
    echo ""
    echo "🚀 Installation complete! You can now run MultiPing."
else
    echo "❌ Error: Failed to make MultiPing executable"
    exit 1
fi
