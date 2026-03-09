#!/usr/bin/env python3

"""
BGP Hijacking Attack Performance Analyzer
Measures attack effectiveness and route convergence time
"""

import subprocess
import time
import sys
import json
from datetime import datetime

class AttackAnalyzer:
    def __init__(self, target_prefix="13.0.1.1", test_node="h1-1"):
        self.target_prefix = target_prefix
        self.test_node = test_node
        self.results = []
        
    def run_command(self, node, cmd):
        """Execute command on mininet node"""
        cmd_str = f"sudo python3 run.py --node {node} --cmd \"{cmd}\""
        try:
            result = subprocess.run(cmd_str, shell=True, capture_output=True, timeout=5)
            return result.stdout.decode().strip()
        except subprocess.TimeoutExpired:
            return None
    
    def check_route_reachability(self):
        """Check if traffic is being hijacked"""
        output = self.run_command(self.test_node, f"curl -s --max-time 2 {self.target_prefix}")
        return output
    
    def get_routing_table(self, node="S1"):
        """Get BGP routing table from router"""
        cmd = f"vtysh -c 'show bgp ipv4'"
        output = self.run_command(node, cmd)
        return output
    
    def measure_hijacking_time(self, timeout=60):
        """Measure time until route is hijacked"""
        start_time = time.time()
        hijacked = False
        
        while time.time() - start_time < timeout:
            try:
                result = self.run_command(self.test_node, f"curl -s --max-time 1 {self.target_prefix}")
                if result and "Attacker" in result:
                    hijacked = True
                    break
            except:
                pass
            time.sleep(0.5)
        
        elapsed = time.time() - start_time
        return hijacked, elapsed
    
    def run_analysis(self, duration=120):
        """Run continuous attack analysis"""
        print(f"[*] Starting attack analysis for {duration}s")
        print(f"[*] Target: {self.target_prefix}, Test node: {self.test_node}")
        print("-" * 80)
        
        start_time = time.time()
        successful_hijacks = 0
        total_attempts = 0
        response_times = []
        
        while time.time() - start_time < duration:
            attempt_start = time.time()
            total_attempts += 1
            
            try:
                result = self.run_command(self.test_node, f"curl -s --max-time 2 --connect-timeout 1 {self.target_prefix}")
                elapsed = time.time() - attempt_start
                response_times.append(elapsed)
                
                if result:
                    if "Attacker" in result:
                        successful_hijacks += 1
                        status = "✓ HIJACKED"
                    else:
                        status = "✗ LEGITIMATE"
                else:
                    status = "✗ TIMEOUT"
                
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Attempt {total_attempts}: {status} ({elapsed:.2f}s)")
            except Exception as e:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Error: {e}")
            
            time.sleep(1)
        
        # Calculate statistics
        hijack_rate = (successful_hijacks / total_attempts * 100) if total_attempts > 0 else 0
        avg_response_time = sum(response_times) / len(response_times) if response_times else 0
        
        print("-" * 80)
        print(f"\n[+] Analysis Complete:")
        print(f"    Total Attempts: {total_attempts}")
        print(f"    Successful Hijacks: {successful_hijacks}")
        print(f"    Hijack Success Rate: {hijack_rate:.1f}%")
        print(f"    Avg Response Time: {avg_response_time:.2f}s")
        
        return {
            "total_attempts": total_attempts,
            "successful_hijacks": successful_hijacks,
            "hijack_rate": hijack_rate,
            "avg_response_time": avg_response_time
        }

if __name__ == "__main__":
    analyzer = AttackAnalyzer()
    duration = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    results = analyzer.run_analysis(duration)
    
    # Save results to file
    with open("attack_results.json", "w") as f:
        json.dump(results, f, indent=2)
