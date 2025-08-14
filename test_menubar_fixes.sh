#!/bin/bash

echo "Testing MultiPing Menubar Fixes"
echo "================================="

# Check if the app is running
if pgrep -f "MultiPing" > /dev/null; then
    echo "✓ MultiPing app is running"
else
    echo "✗ MultiPing app is not running"
    echo "Please start the app first"
    exit 1
fi

echo ""
echo "Testing Steps:"
echo "1. Click on the MultiPing menubar icon"
echo "2. Try 'Show Devices Window' - should show main devices window"
echo "3. Try 'Find Devices on Network' - should show find devices window"
echo "4. Try 'Toggle Floating Window' - should switch between modes"
echo "5. Try 'Settings...' - should show main window"
echo ""
echo "Check the Console app for debug output from MenuBarController"
echo "Look for messages like:"
echo "  - 'MenuBarController: showDevices action triggered'"
echo "  - 'MenuBarController: Successfully got AppDelegate'"
echo "  - 'MenuBarController: Mode switched, now showing main window'"
echo ""
echo "If you see errors, check that:"
echo "  - AppDelegate is properly accessible"
echo "  - WindowManager is working"
echo "  - Window titles are consistent"
echo ""
echo "Press any key to continue..."
read -n 1

echo ""
echo "Test completed. Check the app behavior and console output."
