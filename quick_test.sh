#!/bin/bash

echo "🚀 Testing MultiPing Version 1.6 with Menu Bar Fixes"
echo "======================================================"

cd MultiPing

echo "🔨 Compiling latest version..."
swiftc *.swift -framework AppKit -framework SwiftUI -framework Foundation -framework Combine -o MultiPing-latest

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo ""
    echo "🎯 Testing Instructions:"
    echo "1. The app will launch with a green menu bar icon"
    echo "2. Click the menu bar icon to see the dropdown"
    echo "3. Try these menu options:"
    echo "   • Show Devices Window (should open main window)"
    echo "   • Settings (should open main window)"
    echo "   • Toggle Floating Window (should switch modes)"
    echo "4. Press Ctrl+C in this terminal to quit"
    echo ""
    echo "🐛 Watch the console for debug output"
    echo "======================================================"
    echo ""
    
    ./MultiPing-latest
else
    echo "❌ Compilation failed"
fi