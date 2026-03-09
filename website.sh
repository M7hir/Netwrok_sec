#!/bin/bash

node=${1:-h1-1}
target="13.0.1.1"

# Colors for better visibility
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)

echo "Monitoring connection to $target from $node..."

while true; do
    out=$(sudo python3 run.py --node $node --cmd "curl -s --max-time 2 --connect-timeout 2 $target")
    ts=$(date "+%H:%M:%S")
    
    if [[ -z "$out" ]]; then
        echo "$ts -- ${yellow}TIMEOUT/UNREACHABLE${normal}"
    elif [[ "$out" == *"Attacker"* ]]; then
        echo "$ts -- ${red}${bold}HIJACKED: $out${normal}"
    else
        echo "$ts -- ${green}LEGITIMATE: $out${normal}"
    fi
    sleep 1
done
