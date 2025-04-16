# MultiPing v1.1

A macOS utility for monitoring multiple devices via ping with an elegant interface.

## Features

- **Multiple Interface Modes**:
  - Menu Bar Mode: Compact status indicators in the menu bar and the main Devices window for management.
  - Floating Window Mode: An always-visible status window. Hides the menu bar icons and main window to avoid redundancy.
  - CLI Mode: Command-line interface for scripting. Hides all UI elements.

- **Device Management**:
  - Add/remove devices with names and notes
  - Import devices from CSV or text files
  - Automatic status updates every 5 seconds
  - Visual indicators for device status

- **Window Management**:
  - Remembers window positions and sizes
  - Always-on-top option in floating mode
  - Minimalist interface

## Installation

1. Download the latest release from the releases page
2. Move MultiPing.app to your Applications folder
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

### v1.1
- Added floating window mode with persistent window position
- Improved window management and mode switching
- Fixed device deletion persistence
- Added parallel ping operations
- Enhanced menu bar display

### v1.0
- Initial release
- Basic ping functionality
- Menu bar integration
- Device management

## Support

For issues or feature requests, please open an issue on the GitHub repository.

## License

MIT License - Feel free to use and modify as needed. 