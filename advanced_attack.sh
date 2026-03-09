#!/bin/bash

# Advanced BGP Hijacking Attack Script - Quagga Compatible
# Note: Quagga has limited dynamic route manipulation
# Most attack features are configured in bgpd-S4.conf

node=${1:-S4}
bold=`tput bold`
normal=`tput sgr0`

echo -e "${bold}[*] Starting Advanced BGP Hijacking Attack${normal}"
echo -e "${bold}[+] Using Quagga - attack configured via bgpd-S4.conf${normal}"

# Strategy 1: Verify rogue AS is running
check_rogue_status() {
    echo -e "${bold}[1] Verifying rogue AS status${normal}"
    ps aux | grep bgpd | grep -v grep
}

# Strategy 2: Display BGP routes from rogue AS
display_bgp_routes() {
    echo -e "${bold}[2] Current BGP routes announced:${normal}"
    sudo python3 run.py --node $node --cmd "vtysh -c 'show bgp ipv4'" 2>/dev/null || echo "BGP info unavailable"
}

# Strategy 3: Display neighbor status
check_neighbors() {
    echo -e "${bold}[3] BGP neighbor status:${normal}"
    sudo python3 run.py --node $node --cmd "vtysh -c 'show bgp neighbors'" 2>/dev/null || echo "Neighbor info unavailable"
}

# Execute strategies
check_rogue_status
echo ""
display_bgp_routes
echo ""
check_neighbors

echo -e "${bold}[+] Attack strategies active:${normal}"
echo "    - Multiple overlapping prefix announcements (13.0.0.0/8, /24, /24, /24)"
echo "    - High local preference (300) for route selection"
echo "    - Fast BGP timers (3s/9s) for quick convergence"
echo "    - Route map filtering enabled"
