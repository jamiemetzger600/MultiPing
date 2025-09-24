# MultiPing v1.9

A macOS utility for monitoring multiple devices via ping with an elegant interface.

## Features

- **Multiple Interface Modes**:
  - Menu Bar Mode: Compact status indicators in the menu bar and the main Devices window for management.
  - Floating Window Mode: An always-visible status window. Hides the menu bar icons and main window to avoid redundancy.
  - CLI Mode: Command-line interface for scripting. Hides all UI elements.

- **Device Management**:
  - Add/remove devices with names and notes
  - Import devices from CSV or text files
  - Configurable ping interval (default: 5 seconds)
  - IP address validation to prevent invalid inputs
  - Duplicate IP detection
  - Visual indicators for device status

- **Window Management**:
  - Remembers window positions and sizes for both main and floating windows
  - Always-on-top option in floating mode
  - Adjustable opacity for floating window
  - Improved window position persistence between sessions
  - Seamless mode switching between menu bar and floating window modes

## Installation

### Option 1: Clickable Installer (Recommended)
1. Download the latest release from the releases page
2. Extract `MultiPing-Installer.app` from the release package
3. Double-click `MultiPing-Installer.app` to run the installation
4. Follow the prompts in the terminal window
5. MultiPing is ready to use!

### Option 2: Manual Installation
1. Download the latest release from the releases page
2. Move `MultiPing.app` to your Applications folder
3. When first launching, right-click and select "Open" to bypass Gatekeeper
4. Grant necessary permissions when prompted

## CSV Import Format

The CSV file should have the following format:
```csv
name,ip_address,note
Router,192.168.1.1,Main router
NAS,192.168.1.100,Storage device
Printer,192.168.1.200,Office printer
```

## Requirements

- macOS 12.0 or later
- Network access for ping functionality

## Version History

### v1.6
- **Major Menubar Fixes**: Fixed all menubar dropdown actions (Show Devices, Find Devices, Toggle Floating Window)
- **Direct Find Devices Access**: "Find Devices on Network" now opens directly without intermediate steps
- **Enhanced User Experience**: Removed unnecessary "Settings" menu item, added version number to menubar
- **Feature Request Integration**: Added "Feature Request" option that opens email client
- **Crash Prevention**: Fixed persistent crashes when opening/closing Find Devices window multiple times
- **Network Scanning**: Restored full network scanning functionality in Find Devices window
- **Clickable Installer**: Added MultiPing-Installer.app for easy double-click installation
- **Improved Window Management**: Better persistence and reliability across all window types
- **Streamlined Interface**: Cleaner menubar with working functionality and better user flow

### v1.5
- Added adjustable opacity control for floating window
- Improved menu bar interface with streamlined options
- Enhanced toggle functionality between menu bar and floating window modes
- Fixed window management issues when switching between modes
- Improved synchronization between UI controls and app state
- General performance and reliability improvements

### v1.4
- Added IP address validation to prevent invalid inputs
- Added duplicate IP detection when adding or editing devices
- Fixed menu bar access issues with Show Devices Window command
- Fixed window management to prevent the main window from becoming inaccessible
- Improved floating window position persistence
- Enhanced mode switching between menu bar and floating window modes
- Set default ping interval to 5 seconds
- General bug fixes and stability improvements

### v1.3
- Added floating window mode with persistent window position
- Improved window management and mode switching
- Fixed device deletion persistence
- Added parallel ping operations
- Enhanced menu bar display

### v1.2
- Initial release
- Basic ping functionality
- Menu bar integration
- Device management

## Support

For issues or feature requests, please open an issue on the GitHub repository.

## Future Plans

- Re-enable and debug Command Line Interface (CLI) mode.
- Display Packet Loss and Latency details within the GUI, potentially with color-coding for clarity.
- General UI/UX improvements and polish.

## License

MIT License - Feel free to use and modify as needed. 