#!/usr/bin/env python3
"""
MultiPing - A tool for simultaneously pinging multiple IP addresses and monitoring their status
"""

import argparse
import subprocess
import threading
import time
import os
import re
import socket
import signal
import sys
from datetime import datetime
from typing import List, Dict, Tuple, Optional
import stat
import curses
from curses import wrapper

# Try to import colorama for colored output, fallback to plain text if not available
try:
    from colorama import Fore, Style, init
    # Initialize colorama for cross-platform colored terminal output
    init()
    HAS_COLORAMA = True
except ImportError:
    # Fallback color constants if colorama is not available
    class Fore:
        RED = ''
        GREEN = ''
        YELLOW = ''
        BLUE = ''
        MAGENTA = ''
        CYAN = ''
        WHITE = ''
        RESET = ''
    
    class Style:
        BRIGHT = ''
        DIM = ''
        RESET_ALL = ''
    
    HAS_COLORAMA = False
    # Print a helpful message about colorama
    print("Note: For colored output, install colorama: pip install colorama")

# Global variables
hosts = []
host_names = {}  # Dictionary to store custom names for hosts
results = {}
running = True
refresh_rate = 1.0  # Default refresh rate in seconds
ping_timeout = 1.0  # Default ping timeout in seconds
show_timestamp = False
display_mode = "simple"  # Default display mode (simple, detailed, curses)
ping_count = 1  # Default ping count per cycle
devices_file = None  # Path to the devices file
last_file_mtime = 0  # Last modification time of devices file

# Curses-related globals
stdscr = None
curses_lock = threading.Lock()

def ip_to_int(ip):
    """Convert IP address to integer for sorting"""
    try:
        # Only attempt conversion for strings that look like IP addresses
        if all(c.isdigit() or c == '.' for c in ip) and ip.count('.') == 3:
            parts = list(map(int, ip.split('.')))
            return (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + parts[3]
    except:
        pass
    # Return a large number for non-IP addresses so they appear at the end
    return float('inf')

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Ping multiple hosts simultaneously with live status updates')
    parser.add_argument('-f', '--file', help='File containing list of hosts (one per line or name:host)')
    parser.add_argument('-H', '--hosts', nargs='+', help='List of hosts to ping')
    parser.add_argument('-n', '--names', nargs='+', help='List of names corresponding to hosts (must match number of hosts)')
    parser.add_argument('-i', '--interval', type=float, default=1.0, help='Refresh interval in seconds (default: 1.0)')
    parser.add_argument('-t', '--timeout', type=float, default=1.0, help='Ping timeout in seconds (default: 1.0)')
    parser.add_argument('-m', '--mode', choices=['simple', 'detailed', 'compact', 'curses', 'live'], default='curses', help='Display mode (default: curses)')
    parser.add_argument('-T', '--timestamp', action='store_true', help='Show timestamp with each update')
    parser.add_argument('-c', '--count', type=int, default=1, help='Number of pings per cycle (default: 1)')
    
    args = parser.parse_args()
    
    if not args.hosts and not args.file:
        parser.error("You must specify hosts using -H/--hosts or provide a file with -f/--file")
    
    if args.hosts and args.names and len(args.hosts) != len(args.names):
        parser.error("The number of names must match the number of hosts")
    
    return args

def check_file_changes():
    """Check if the devices file has been modified and reload if necessary"""
    global hosts, host_names, last_file_mtime
    
    if not devices_file or not os.path.exists(devices_file):
        return
    
    try:
        # Get current modification time
        current_mtime = os.path.getmtime(devices_file)
        
        # If file has been modified, reload it
        if current_mtime > last_file_mtime:
            last_file_mtime = current_mtime
            new_hosts, new_host_names = read_hosts_from_file(devices_file)
            
            # Only update if the content has actually changed
            if new_hosts != hosts or new_host_names != host_names:
                hosts = new_hosts
                host_names = new_host_names
                
                # Clear old results for devices that no longer exist
                old_hosts = set(results.keys())
                new_hosts_set = set(hosts)
                removed_hosts = old_hosts - new_hosts_set
                
                for host in removed_hosts:
                    del results[host]
                
                # Print a subtle notification about the update (will be overwritten by next display)
                print(f"🔄 Updated: {len(hosts)} devices", end='')
                if removed_hosts:
                    print(f" (-{len(removed_hosts)})", end='')
                if added_hosts:
                    print(f" (+{len(added_hosts)})", end='')
                print()  # New line
                
    except (OSError, IOError):
        # File might be temporarily unavailable, ignore
        pass

def read_hosts_from_file(filename: str) -> Tuple[List[str], Dict[str, str]]:
    """Read hosts from file, one per line with optional name using format 'name:host'"""
    hosts = []
    host_names = {}
    
    try:
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                # Check if line has a name:host format
                if ':' in line:
                    parts = line.split(':', 1)
                    if len(parts) == 2:
                        name = parts[0].strip()
                        host = parts[1].strip()
                        hosts.append(host)
                        host_names[host] = name
                else:
                    hosts.append(line)
    except Exception as e:
        print(f"Error reading hosts file: {e}")
        sys.exit(1)
    
    if not hosts:
        print(f"No valid hosts found in {filename}")
        sys.exit(1)
    
    return hosts, host_names

def ping_host(host: str) -> Dict:
    """Ping a single host and return results"""
    # Initialize result dictionary
    result = {
        'host': host,
        'status': 'unknown',
        'latency': None,
        'timestamp': datetime.now(),
        'message': '',
        'packet_loss': 100.0
    }
    
    try:
        # Try to resolve the hostname first
        try:
            socket.gethostbyname(host)
        except socket.gaierror:
            result['status'] = 'error'
            result['message'] = 'Cannot resolve hostname'
            return result
        
        # Build the ping command
        if sys.platform == 'darwin':  # macOS
            cmd = ['/sbin/ping', '-c', str(ping_count), '-W', str(int(ping_timeout * 1000)), host]
        elif sys.platform == 'win32':  # Windows
            cmd = ['ping', '-n', str(ping_count), '-w', str(int(ping_timeout * 1000)), host]
        else:  # Linux/Unix
            cmd = ['ping', '-c', str(ping_count), '-W', str(int(ping_timeout)), host]
        
        # Execute the ping command
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        
        # Parse the ping output
        if process.returncode == 0:
            result['status'] = 'up'
            
            # Extract latency
            if 'time=' in stdout or 'time<' in stdout:
                latency_pattern = r'time[=<]([0-9.]+)'
                latency_matches = re.findall(latency_pattern, stdout)
                if latency_matches:
                    result['latency'] = float(latency_matches[-1])  # Use the last match
            
            # Extract packet loss
            packet_loss_pattern = r'(\d+(?:\.\d+)?)% packet loss'
            packet_loss_match = re.search(packet_loss_pattern, stdout)
            if packet_loss_match:
                result['packet_loss'] = float(packet_loss_match.group(1))
                
                # If packet loss is 100%, status should be down
                if result['packet_loss'] == 100.0:
                    result['status'] = 'down'
        else:
            result['status'] = 'down'
            
            if stderr:
                result['message'] = stderr.strip()
            else:
                result['message'] = 'Host is unreachable'
                
    except Exception as e:
        result['status'] = 'error'
        result['message'] = str(e)
    
    return result

def ping_worker(host_list: List[str]):
    """Worker function to ping hosts continuously"""
    global results, running, hosts
    
    while running:
        # Check for file changes first
        check_file_changes()
        
        # Use current hosts list (may have been updated by check_file_changes)
        current_hosts = hosts if hosts else host_list
        
        for host in current_hosts:
            if not running:
                break
            
            result = ping_host(host)
            results[host] = result
            
        # Small sleep to prevent CPU overuse in case of very fast cycles
        time.sleep(0.1)

def status_color(status: str) -> str:
    """Return color code based on status"""
    if status == 'up':
        return Fore.GREEN
    elif status == 'down':
        return Fore.RED
    elif status == 'error':
        return Fore.YELLOW
    else:
        return Fore.WHITE

def format_latency(latency: Optional[float]) -> str:
    """Format latency value for display"""
    if latency is None:
        return "N/A"
    
    if latency < 1:
        return f"<1 ms"
    else:
        return f"{latency:.1f} ms"

def display_results_simple():
    """Display results in simple format with minimal output"""
    # Only print a summary line instead of full table
    if results:
        up_count = sum(1 for r in results.values() if r['status'] == 'up')
        down_count = sum(1 for r in results.values() if r['status'] == 'down')
        error_count = sum(1 for r in results.values() if r['status'] == 'error')
        
        # Create a compact status line
        status_line = f"[{datetime.now().strftime('%H:%M:%S')}] "
        status_line += f"{Fore.GREEN}UP:{up_count}{Style.RESET_ALL} "
        status_line += f"{Fore.RED}DOWN:{down_count}{Style.RESET_ALL} "
        status_line += f"{Fore.YELLOW}ERROR:{error_count}{Style.RESET_ALL}"
        
        # Add device status indicators
        device_status = []
        sorted_hosts = sorted(hosts, key=ip_to_int)
        for host in sorted_hosts[:5]:  # Only show first 5 devices
            name = host_names.get(host, host)
            if host in results:
                status = results[host]['status']
                if status == 'up':
                    device_status.append(f"{name}:{Fore.GREEN}✓{Style.RESET_ALL}")
                elif status == 'down':
                    device_status.append(f"{name}:{Fore.RED}✗{Style.RESET_ALL}")
                else:
                    device_status.append(f"{name}:{Fore.YELLOW}?{Style.RESET_ALL}")
        
        if device_status:
            status_line += f" | {' '.join(device_status)}"
        
        print(status_line)
        sys.stdout.flush()

def display_results_detailed():
    """Display results in detailed format with compact output"""
    # Print detailed status for each host in compact format
    if results:
        up_count = sum(1 for r in results.values() if r['status'] == 'up')
        down_count = sum(1 for r in results.values() if r['status'] == 'down')
        error_count = sum(1 for r in results.values() if r['status'] == 'error')
        
        # Print summary first
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {Fore.GREEN}UP:{up_count}{Style.RESET_ALL} {Fore.RED}DOWN:{down_count}{Style.RESET_ALL} {Fore.YELLOW}ERROR:{error_count}{Style.RESET_ALL}")
        
        # Print device details in compact format
        sorted_hosts = sorted(hosts, key=ip_to_int)
        for host in sorted_hosts:
            name = host_names.get(host, host)
            
            if host in results:
                result = results[host]
                status = result['status']
                latency = result['latency']
                packet_loss = result['packet_loss']
                
                status_str = f"{status_color(status)}{status.upper()}{Style.RESET_ALL}"
                latency_str = format_latency(latency)
                packet_loss_str = f"{packet_loss}%" if packet_loss is not None else "N/A"
                
                print(f"  {name:<15} {host:<15} {status_str:<6} {latency_str:<8} {packet_loss_str}")
            else:
                print(f"  {name:<15} {host:<15} {'WAITING':<6} {'N/A':<8} {'N/A'}")
        
        print()  # Empty line for readability
        sys.stdout.flush()

def display_results_compact():
    """Display results in ultra-compact format to minimize scrolling"""
    if results:
        up_count = sum(1 for r in results.values() if r['status'] == 'up')
        down_count = sum(1 for r in results.values() if r['status'] == 'down')
        error_count = sum(1 for r in results.values() if r['status'] == 'error')
        
        # Ultra-compact single line with just counts and key devices
        line = f"[{datetime.now().strftime('%H:%M:%S')}] "
        line += f"{Fore.GREEN}{up_count}✓{Style.RESET_ALL} "
        line += f"{Fore.RED}{down_count}✗{Style.RESET_ALL} "
        line += f"{Fore.YELLOW}{error_count}?{Style.RESET_ALL}"
        
        # Add just the first few device statuses
        device_status = []
        sorted_hosts = sorted(hosts, key=ip_to_int)
        for host in sorted_hosts[:3]:  # Only first 3 devices
            name = host_names.get(host, host)[:8]  # Truncate long names
            if host in results:
                status = results[host]['status']
                if status == 'up':
                    device_status.append(f"{name}:{Fore.GREEN}✓{Style.RESET_ALL}")
                elif status == 'down':
                    device_status.append(f"{name}:{Fore.RED}✗{Style.RESET_ALL}")
                else:
                    device_status.append(f"{name}:{Fore.YELLOW}?{Style.RESET_ALL}")
        
        if device_status:
            line += f" {' '.join(device_status)}"
        
        print(line)
        sys.stdout.flush()

# Global variables for live display
_live_header_printed = False
_last_display_time = 0
_display_counter = 0
_device_lines = []

def display_results_live():
    """Display results in a truly live-updating format that updates in place"""
    global _live_header_printed, _last_display_time, _display_counter, _device_lines
    
    current_time = time.time()
    
    # Only print header once at the very beginning
    if not _live_header_printed:
        print("\n" + "="*80)
        print("MultiPing - Live Network Monitor")
        print("="*80)
        print(f"{'NAME':<15} {'HOST':<18} {'STATUS':<8} {'LATENCY':<10} {'PACKET LOSS':<12}")
        print("="*80)
        
        # Initialize device lines
        sorted_hosts = sorted(hosts, key=ip_to_int)
        _device_lines = []
        for i, host in enumerate(sorted_hosts):
            name = host_names.get(host, host)
            if len(name) > 14:
                name = name[:11] + "..."
            
            # Create initial line with waiting status
            line = f"{name:<15} {host:<18} {'WAITING':<8} {'N/A':<10} {'N/A':<12}"
            _device_lines.append(line)
            print(line)
        
        # Add summary line
        print("-" * 80)
        print("Last Update: Initializing...")
        
        _live_header_printed = True
        _last_display_time = current_time
        return
    
    # Only update every 0.5 seconds to reduce output
    if current_time - _last_display_time < 0.5:
        return
    
    _last_display_time = current_time
    _display_counter += 1
    
    # Update device lines in place using carriage return
    if results:
        sorted_hosts = sorted(hosts, key=ip_to_int)
        
        # Move cursor up to first device line
        lines_to_move_up = len(_device_lines) + 2  # +2 for separator and summary
        print(f"\033[{lines_to_move_up}A", end="")
        
        # Update each device line
        for i, host in enumerate(sorted_hosts):
            if i < len(_device_lines):
                name = host_names.get(host, host)
                if len(name) > 14:
                    name = name[:11] + "..."
                
                if host in results:
                    result = results[host]
                    status = result['status']
                    latency = result['latency']
                    packet_loss = result['packet_loss']
                    
                    # Format latency
                    if latency is not None and latency > 0:
                        if latency < 1:
                            latency_str = "<1 ms"
                        else:
                            latency_str = f"{latency:.1f} ms"
                    else:
                        latency_str = "N/A"
                    
                    # Format packet loss
                    packet_loss_str = f"{packet_loss}%" if packet_loss is not None else "N/A"
                    
                    # Color coding for status
                    if status == 'up':
                        status_color = Fore.GREEN
                        status_display = "UP"
                    elif status == 'down':
                        status_color = Fore.RED
                        status_display = "DOWN"
                    else:
                        status_color = Fore.YELLOW
                        status_display = "ERROR"
                    
                    # Create updated line
                    line = f"{name:<15} {host:<18} {status_color}{status_display:<8}{Style.RESET_ALL} {latency_str:<10} {packet_loss_str:<12}"
                else:
                    # No result yet
                    line = f"{name:<15} {host:<18} {'WAITING':<8} {'N/A':<10} {'N/A':<12}"
                
                # Clear the line and print new content
                print("\033[K", end="")  # Clear line
                print(line)
                _device_lines[i] = line
        
        # Update summary line
        up_count = sum(1 for r in results.values() if r['status'] == 'up')
        down_count = sum(1 for r in results.values() if r['status'] == 'down')
        error_count = sum(1 for r in results.values() if r['status'] == 'error')
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        summary = f"Last Update: {timestamp} | UP:{up_count} DOWN:{down_count} ERR:{error_count}"
        
        print("-" * 80)
        print("\033[K", end="")  # Clear line
        print(summary)
    
    sys.stdout.flush()

def display_results_dashboard():
    """Display results in a dashboard format that updates specific lines"""
    # This would require more complex terminal control that might not work in SwiftUI
    # For now, use the live format which is more compatible
    display_results_live()

def display_results_curses():
    """Display results using curses for live updating interface"""
    global stdscr
    
    if not stdscr:
        return
    
    with curses_lock:
        try:
            # Clear the screen
            stdscr.clear()
            
            # Get screen dimensions
            max_y, max_x = stdscr.getmaxyx()
            
            # Title
            title = "MultiPing - Live Network Monitor"
            stdscr.addstr(0, 0, title, curses.A_BOLD)
            
            # Header line with summary
            if results:
                up_count = sum(1 for r in results.values() if r['status'] == 'up')
                down_count = sum(1 for r in results.values() if r['status'] == 'down')
                error_count = sum(1 for r in results.values() if r['status'] == 'error')
                
                # Create colored summary
                summary = f"UP: {up_count}  DOWN: {down_count}  ERROR: {error_count}  |  Monitoring {len(hosts)} hosts"
                stdscr.addstr(1, 0, summary)
                
                # Timestamp
                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                time_str = f"Last Update: {current_time}"
                stdscr.addstr(1, max_x - len(time_str) - 1, time_str)
            else:
                stdscr.addstr(1, 0, "Initializing...")
            
            # Separator line
            stdscr.addstr(2, 0, "─" * max_x)
            
            # Table header
            header = f"{'NAME':<15} {'HOST':<18} {'STATUS':<8} {'LATENCY':<10} {'PACKET LOSS':<12}"
            stdscr.addstr(3, 0, header, curses.A_BOLD)
            stdscr.addstr(4, 0, "─" * max_x)
            
            # Device rows
            row = 5
            sorted_hosts = sorted(hosts, key=ip_to_int)
            
            for host in sorted_hosts:
                if row >= max_y - 2:  # Leave space for bottom info
                    break
                    
                name = host_names.get(host, host)
                if len(name) > 14:
                    name = name[:11] + "..."
                
                if host in results:
                    result = results[host]
                    status = result['status']
                    latency = result['latency']
                    packet_loss = result['packet_loss']
                    
                    # Format latency
                    if latency is not None and latency > 0:
                        if latency < 1:
                            latency_str = "<1 ms"
                        else:
                            latency_str = f"{latency:.1f} ms"
                    else:
                        latency_str = "N/A"
                    
                    # Format packet loss
                    packet_loss_str = f"{packet_loss}%" if packet_loss is not None else "N/A"
                    
                    # Color coding for status
                    if status == 'up':
                        status_color = curses.color_pair(1)  # Green
                        status_display = "UP"
                    elif status == 'down':
                        status_color = curses.color_pair(2)  # Red
                        status_display = "DOWN"
                    else:
                        status_color = curses.color_pair(3)  # Yellow
                        status_display = "ERROR"
                    
                    # Create row
                    row_text = f"{name:<15} {host:<18} {status_display:<8} {latency_str:<10} {packet_loss_str:<12}"
                    
                    # Truncate if too long for screen
                    if len(row_text) > max_x - 1:
                        row_text = row_text[:max_x - 4] + "..."
                    
                    stdscr.addstr(row, 0, row_text)
                    
                    # Color the status part
                    status_start = 34  # Position of status in the row
                    status_end = status_start + len(status_display)
                    if status_end <= max_x:
                        stdscr.addstr(row, status_start, status_display, status_color)
                    
                else:
                    # No result yet
                    row_text = f"{name:<15} {host:<18} {'WAITING':<8} {'N/A':<10} {'N/A':<12}"
                    if len(row_text) > max_x - 1:
                        row_text = row_text[:max_x - 4] + "..."
                    stdscr.addstr(row, 0, row_text)
                
                row += 1
            
            # Bottom info
            if row < max_y - 1:
                bottom_text = "Press 'q' to quit, 'r' to refresh, 's' to show stats"
                stdscr.addstr(max_y - 1, 0, bottom_text)
            
            # Refresh the screen
            stdscr.refresh()
            
        except curses.error:
            # Handle curses errors gracefully
            pass

def init_curses():
    """Initialize curses colors"""
    global stdscr
    
    if stdscr:
        # Define color pairs
        curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)    # Green for UP
        curses.init_pair(2, curses.COLOR_RED, curses.COLOR_BLACK)      # Red for DOWN
        curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)   # Yellow for ERROR
        curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)     # Cyan for headers

def curses_main(screen):
    """Main function wrapped by curses"""
    global stdscr, hosts, host_names, results, running, refresh_rate, ping_timeout, show_timestamp, display_mode, ping_count, devices_file, last_file_mtime
    
    stdscr = screen
    stdscr.nodelay(True)  # Make getch() non-blocking
    curses.curs_set(0)    # Hide cursor
    init_curses()         # Initialize colors
    
    # Parse command line arguments
    args = parse_arguments()
    
    # Set global variables from arguments
    refresh_rate = args.interval
    ping_timeout = args.timeout
    show_timestamp = args.timestamp
    display_mode = args.mode
    ping_count = args.count
    
    # Get list of hosts and their names
    if args.file:
        devices_file = args.file  # Store the file path for live updates
        hosts, file_host_names = read_hosts_from_file(args.file)
        host_names.update(file_host_names)
        
        # Initialize file modification time
        try:
            last_file_mtime = os.path.getmtime(devices_file)
        except OSError:
            last_file_mtime = 0
    elif args.hosts:
        hosts = args.hosts
        
        # If names are provided, associate them with hosts
        if args.names:
            for i, host in enumerate(hosts):
                if i < len(args.names):
                    host_names[host] = args.names[i]
    
    # Remove duplicates while preserving order
    hosts = list(dict.fromkeys(hosts))
    
    if not hosts:
        stdscr.addstr(0, 0, "Error: No hosts to monitor")
        stdscr.refresh()
        stdscr.getch()
        return
    
    # Register signal handler for Ctrl+C
    signal.signal(signal.SIGINT, sigint_handler)
    
    # Start worker thread
    worker = threading.Thread(target=ping_worker, args=(hosts,), daemon=True)
    worker.start()
    
    try:
        while running:
            # Handle keyboard input
            try:
                key = stdscr.getch()
                if key == ord('q') or key == ord('Q'):
                    break
                elif key == ord('r') or key == ord('R'):
                    # Force refresh
                    display_results_curses()
                elif key == ord('s') or key == ord('S'):
                    # Show stats (could be implemented later)
                    pass
                elif key == curses.KEY_RESIZE:
                    # Handle window resize
                    display_results_curses()
            except curses.error:
                pass  # No input available
            
            # Display results
            display_results_curses()
            
            # Wait for refresh interval
            time.sleep(refresh_rate)
    except KeyboardInterrupt:
        # Handle Ctrl+C
        running = False
    
    # Cleanup
    stdscr.clear()
    stdscr.addstr(0, 0, "Stopping MultiPing...")
    stdscr.refresh()
    
    # Wait for worker thread to terminate
    worker.join(timeout=1.0)

def sigint_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    global running
    print("\nStopping MultiPing...")
    running = False
    sys.exit(0)

def main():
    global hosts, host_names, results, running, refresh_rate, ping_timeout, show_timestamp, display_mode, ping_count
    
    # Parse command line arguments
    args = parse_arguments()
    
    # Set global variables from arguments
    refresh_rate = args.interval
    ping_timeout = args.timeout
    show_timestamp = args.timestamp
    display_mode = args.mode
    ping_count = args.count
    
    # If curses mode is selected, try curses wrapper with fallback
    if display_mode == 'curses':
        # Set up terminal environment for curses
        if 'TERM' not in os.environ:
            os.environ['TERM'] = 'xterm-256color'
        
        try:
            wrapper(curses_main)
        except (curses.error, OSError) as e:
            print(f"Error: Curses mode failed ({e}). Falling back to live mode.")
            print("This usually happens when running in a non-terminal environment.")
            display_mode = 'live'  # Fallback to live mode
        except KeyboardInterrupt:
            running = False
            return
    
    # Get list of hosts and their names
    if args.file:
        devices_file = args.file  # Store the file path for live updates
        hosts, file_host_names = read_hosts_from_file(args.file)
        host_names.update(file_host_names)
        
        # Initialize file modification time
        try:
            last_file_mtime = os.path.getmtime(devices_file)
        except OSError:
            last_file_mtime = 0
    elif args.hosts:
        hosts = args.hosts
        
        # If names are provided, associate them with hosts
        if args.names:
            for i, host in enumerate(hosts):
                if i < len(args.names):
                    host_names[host] = args.names[i]
    
    # Remove duplicates while preserving order
    hosts = list(dict.fromkeys(hosts))
    
    # Register signal handler for Ctrl+C
    signal.signal(signal.SIGINT, sigint_handler)
    
    # Start worker thread
    worker = threading.Thread(target=ping_worker, args=(hosts,), daemon=True)
    worker.start()
    
    try:
        while running:
            # Display results based on selected mode
            if display_mode == 'simple':
                display_results_simple()
            elif display_mode == 'detailed':
                display_results_detailed()
            elif display_mode == 'compact':
                display_results_compact()
            elif display_mode == 'live':
                display_results_live()
            
            # Wait for refresh interval
            time.sleep(refresh_rate)
    except KeyboardInterrupt:
        # Handle Ctrl+C
        running = False
        print("\nStopping MultiPing...")
    
    # Wait for worker thread to terminate
    worker.join(timeout=1.0)
    
if __name__ == "__main__":
    main()
