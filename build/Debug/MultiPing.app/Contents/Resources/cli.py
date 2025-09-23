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
from colorama import Fore, Style, init

# Initialize colorama for cross-platform colored terminal output
init()

# Global variables
hosts = []
host_names = {}  # Dictionary to store custom names for hosts
results = {}
running = True
refresh_rate = 1.0  # Default refresh rate in seconds
ping_timeout = 1.0  # Default ping timeout in seconds
show_timestamp = False
display_mode = "simple"  # Default display mode (simple, detailed)
ping_count = 1  # Default ping count per cycle

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
    parser.add_argument('-m', '--mode', choices=['simple', 'detailed'], default='simple', help='Display mode (default: simple)')
    parser.add_argument('-T', '--timestamp', action='store_true', help='Show timestamp with each update')
    parser.add_argument('-c', '--count', type=int, default=1, help='Number of pings per cycle (default: 1)')
    
    args = parser.parse_args()
    
    if not args.hosts and not args.file:
        parser.error("You must specify hosts using -H/--hosts or provide a file with -f/--file")
    
    if args.hosts and args.names and len(args.hosts) != len(args.names):
        parser.error("The number of names must match the number of hosts")
    
    return args

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
    global results, running
    
    while running:
        for host in host_list:
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
    """Display results in simple format"""
    # Clear screen
    os.system('cls' if sys.platform == 'win32' else 'clear')
    
    # Print header
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"MultiPing - Status Update" + (f" ({current_time})" if show_timestamp else ""))
    print(f"Monitoring {len(hosts)} hosts with refresh every {refresh_rate} seconds\n")
    
    # Print status table
    header = f"{'NAME':<20} {'HOST':<25} {'STATUS':<10} {'LATENCY':<15} {'PACKET LOSS':<15}"
    print(header)
    print("-" * len(header))
    
    # Sort hosts by IP address numeric value
    sorted_hosts = sorted(hosts, key=ip_to_int)
    
    for host in sorted_hosts:
        # Get the custom name for this host, or use the host itself if no name assigned
        name = host_names.get(host, "")
        
        if host in results:
            result = results[host]
            status = result['status']
            latency = result['latency']
            packet_loss = result['packet_loss']
            
            status_str = f"{status_color(status)}{status.upper()}{Style.RESET_ALL}"
            latency_str = format_latency(latency)
            packet_loss_str = f"{packet_loss}%" if packet_loss is not None else "N/A"
            
            print(f"{name:<20} {host:<25} {status_str:<10} {latency_str:<15} {packet_loss_str:<15}")
        else:
            print(f"{name:<20} {host:<25} {'WAITING':<10} {'N/A':<15} {'N/A':<15}")
    
    # Print summary
    if results:
        up_count = sum(1 for r in results.values() if r['status'] == 'up')
        down_count = sum(1 for r in results.values() if r['status'] == 'down')
        error_count = sum(1 for r in results.values() if r['status'] == 'error')
        
        print("\nSummary:")
        print(f"{Fore.GREEN}UP:{Style.RESET_ALL} {up_count}  {Fore.RED}DOWN:{Style.RESET_ALL} {down_count}  {Fore.YELLOW}ERROR:{Style.RESET_ALL} {error_count}")

def display_results_detailed():
    """Display results in detailed format"""
    # Clear screen
    os.system('cls' if sys.platform == 'win32' else 'clear')
    
    # Print header
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"MultiPing - Detailed Status" + (f" ({current_time})" if show_timestamp else ""))
    print(f"Monitoring {len(hosts)} hosts with refresh every {refresh_rate} seconds\n")
    
    # Sort hosts by IP address numeric value
    sorted_hosts = sorted(hosts, key=ip_to_int)
    
    # Print detailed status for each host
    for host in sorted_hosts:
        # Get the custom name for this host, or use the host itself if no name assigned
        name = host_names.get(host, "")
        
        if host in results:
            result = results[host]
            status = result['status']
            latency = result['latency']
            timestamp = result['timestamp']
            message = result['message']
            packet_loss = result['packet_loss']
            
            status_str = f"{status_color(status)}{status.upper()}{Style.RESET_ALL}"
            latency_str = format_latency(latency)
            timestamp_str = timestamp.strftime("%H:%M:%S")
            
            print(f"Name: {name}")
            print(f"Host: {host}")
            print(f"Status: {status_str}")
            print(f"Latency: {latency_str}")
            print(f"Packet Loss: {packet_loss}%")
            print(f"Last Check: {timestamp_str}")
            
            if message:
                print(f"Message: {message}")
            
            print("-" * 40)
        else:
            print(f"Name: {name}")
            print(f"Host: {host}")
            print("Status: WAITING")
            print("-" * 40)
    
    # Print summary
    if results:
        up_count = sum(1 for r in results.values() if r['status'] == 'up')
        down_count = sum(1 for r in results.values() if r['status'] == 'down')
        error_count = sum(1 for r in results.values() if r['status'] == 'error')
        
        print("\nSummary:")
        print(f"{Fore.GREEN}UP:{Style.RESET_ALL} {up_count}  {Fore.RED}DOWN:{Style.RESET_ALL} {down_count}  {Fore.YELLOW}ERROR:{Style.RESET_ALL} {error_count}")

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
    
    # Get list of hosts and their names
    if args.file:
        hosts, file_host_names = read_hosts_from_file(args.file)
        host_names.update(file_host_names)
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
            else:
                display_results_detailed()
            
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
