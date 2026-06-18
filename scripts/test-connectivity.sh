#!/bin/bash
# test-connectivity.sh - Verify network connectivity between all servers
set -e

echo "=== Testing network connectivity between servers ==="
echo ""

SERVERS=("134.200.58.99" "134.200.18.7" "134.200.18.8")
NAMES=("3090" "128GB-1" "128GB-2")

# Find which server we're on
MY_IP=$(hostname -I | awk '{print $1}')
echo "This server IP: $MY_IP"
echo ""

# Test SSH to all servers
for i in "${!SERVERS[@]}"; do
    ip="${SERVERS[$i]}"
    name="${NAMES[$i]}"
    
    if [ "$ip" = "$MY_IP" ]; then
        echo "[$name] $ip - THIS SERVER (skip)"
        continue
    fi
    
    echo -n "[$name] $ip - SSH: "
    if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes root@$ip "echo OK" 2>/dev/null; then
        echo "OK"
    else
        echo "FAILED (need SSH key setup)"
    fi
done

echo ""
echo "=== Port checks ==="

# Check if LMCache port is listening
echo "LMCache daemon (port 6500):"
if ss -tlnp | grep -q ":6500"; then
    echo "  Listening on port 6500"
else
    echo "  NOT listening on port 6500"
fi

# Check llama-server
echo "Llama server (port 8080):"
if ss -tlnp | grep -q ":8080"; then
    echo "  Listening on port 8080"
else
    echo "  NOT listening on port 8080"
fi

echo ""
echo "=== GPU status ==="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader
else
    echo "nvidia-smi not found (no GPU on this server)"
fi

echo ""
echo "=== Done ==="
