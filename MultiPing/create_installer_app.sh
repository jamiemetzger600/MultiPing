#!/bin/bash

# Script to create a clickable macOS installer app for MultiPing v1.6

echo "🔧 Creating clickable MultiPing installer app..."

# Create the app bundle structure
INSTALLER_APP="MultiPing-Installer.app"
CONTENTS_DIR="$INSTALLER_APP/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Create the main executable script
cat > "$MACOS_DIR/MultiPing-Installer" << 'EOF'
#!/bin/bash

# Get the directory where this app bundle is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKING_DIR="$(dirname "$BUNDLE_DIR")"

echo "🚀 MultiPing v1.6 Installer"
echo "=============================="
echo ""

# Change to the working directory
cd "$WORKING_DIR"

# Check if we're in the right place
if [ ! -f "MultiPing-v1.6-release" ]; then
    echo "❌ Error: MultiPing executable not found!"
    echo ""
    echo "Please make sure this installer is in the same folder as:"
    echo "  - MultiPing-v1.6-release"
    echo "  - install.sh"
    echo "  - RELEASE_NOTES_v1.6.md"
    echo ""
    echo "Press any key to close..."
    read -n 1
    exit 1
fi

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
    echo ""
    echo "Press any key to close..."
    read -n 1
else
    echo "❌ Error: Failed to make MultiPing executable"
    echo ""
    echo "Press any key to close..."
    read -n 1
    exit 1
fi
EOF

# Make the script executable
chmod +x "$MACOS_DIR/MultiPing-Installer"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MultiPing-Installer</string>
    <key>CFBundleIdentifier</key>
    <string>com.jamiemetzger.multiping.installer</string>
    <key>CFBundleName</key>
    <string>MultiPing Installer</string>
    <key>CFBundleDisplayName</key>
    <string>MultiPing Installer</string>
    <key>CFBundleVersion</key>
    <string>1.6</string>
    <key>CFBundleShortVersionString</key>
    <string>1.6</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <false/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "✅ Created $INSTALLER_APP"
echo ""
echo "🎯 Users can now double-click $INSTALLER_APP to install MultiPing!"
echo ""
echo "📁 The installer app should be placed in the same folder as:"
echo "   - MultiPing-v1.6-release"
echo "   - install.sh"
echo "   - RELEASE_NOTES_v1.6.md"
echo ""
echo "🚀 Installation process:"
echo "   1. Double-click MultiPing-Installer.app"
echo "   2. Follow the prompts in the terminal window"
echo "   3. MultiPing is ready to use!"
