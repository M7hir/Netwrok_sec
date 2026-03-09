#!/usr/bin/env python3
"""
Install BGP learned routes into kernel routing table.
Works around Quagga's zebra-bgpd socket communication issue in Mininet namespaces.
"""

import subprocess
import re
import sys
import time

def get_node(name):
    """Get a node from mininet"""
    try:
        result = subprocess.run(
            ["sudo", "python3", "run.py", "--node", name, "--cmd", "ip route show"],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.returncode == 0
    except:
        return False

def get_bgp_routes(node):
    """Get routes learned by BGP on a node"""
    try:
        result = subprocess.run(
            ["sudo", "python3", "run.py", "--node", node, "--cmd", 
             "vtysh -c 'show ip bgp' 2>/dev/null"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        routes = []
        for line in result.stdout.split('\n'):
            # Match lines like:
            # *> 12.0.0.0/8      9.0.0.2                         0 2 i
            # *> 13.0.0.0/8      9.0.4.2                         0 4 i
            match = re.match(r'\s*\*?\s*>?\s+(\S+)\s+(\S+)\s+', line)
            if match:
                prefix = match.group(1)
                nexthop = match.group(2)
                if prefix not in ['Network', 'Next']:  # Skip headers
                    routes.append((prefix, nexthop))
        
        return routes
    except Exception as e:
        print(f"Error getting BGP routes from {node}: {e}", file=sys.stderr)
        return []

def install_route(node, prefix, nexthop):
    """Install a route in a node's kernel routing table"""
    try:
        subprocess.run(
            ["sudo", "python3", "run.py", "--node", node, "--cmd",
             f"ip route add {prefix} via {nexthop} 2>/dev/null || ip route replace {prefix} via {nexthop}"],
            capture_output=True,
            text=True,
            timeout=5
        )
        return True
    except:
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 install_bgp_routes.py <node> [prefix] [nexthop]")
        print("Examples:")
        print("  python3 install_bgp_routes.py S1          # Install all learned routes on S1")
        print("  python3 install_bgp_routes.py S1 13.0.1.0/24 9.0.4.2  # Install specific route")
        sys.exit(1)
    
    node = sys.argv[1]
    
    if not get_node(node):
        print(f"Error: Node {node} not found or not responding", file=sys.stderr)
        sys.exit(1)
    
    if len(sys.argv) == 4:
        # Install specific route
        prefix = sys.argv[2]
        nexthop = sys.argv[3]
        if install_route(node, prefix, nexthop):
            print(f"Installed route {prefix} via {nexthop} on {node}")
        else:
            print(f"Failed to install route on {node}", file=sys.stderr)
            sys.exit(1)
    else:
        # Install all learned routes
        routes = get_bgp_routes(node)
        
        if not routes:
            print(f"No BGP routes found on {node}", file=sys.stderr)
            sys.exit(1)
        
        print(f"Found {len(routes)} BGP routes on {node}")
        
        installed = 0
        for prefix, nexthop in routes:
            if install_route(node, prefix, nexthop):
                print(f"  ✓ {prefix} via {nexthop}")
                installed += 1
            else:
                print(f"  ✗ {prefix} via {nexthop} (failed)", file=sys.stderr)
        
        print(f"\nInstalled {installed}/{len(routes)} routes on {node}")
        
        if installed > 0:
            print(f"\nVerifying routes on {node}...")
            result = subprocess.run(
                ["sudo", "python3", "run.py", "--node", node, "--cmd", "ip route show"],
                capture_output=True,
                text=True,
                timeout=5
            )
            for line in result.stdout.split('\n'):
                if line.strip():
                    print(f"  {line}")

if __name__ == "__main__":
    main()
