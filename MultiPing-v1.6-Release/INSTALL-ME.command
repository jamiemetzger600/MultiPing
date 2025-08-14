#!/bin/bash

echo "🚀 MultiPing v1.6 - One-Click Installer"
echo "========================================="
echo ""

# Make MultiPing executable
chmod +x MultiPing-v1.6-executable

echo "✅ MultiPing is ready!"
echo ""
echo "🚨 You may see a security warning - click 'Open' to continue"
echo ""
echo "🚀 Launching MultiPing (background process)..."

# Launch MultiPing in background, detached from terminal
nohup ./MultiPing-v1.6-executable > /dev/null 2>&1 &

echo "📱 MultiPing is now running in your menubar (top-right of screen)"
echo "✅ Installation complete! You can close this terminal."
echo ""
