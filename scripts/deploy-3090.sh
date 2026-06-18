#!/bin/bash
# deploy-3090.sh - Update 3090 server config to use RPC workers
set -e

RPC_WORKERS="134.200.18.7:6500,134.200.18.8:6500"

echo "=== Updating 3090 llama-server with RPC workers ==="
echo "RPC workers: $RPC_WORKERS"

# Detect existing llama-server location
if command -v llama-server &> /dev/null; then
    BINARY=$(which llama-server)
elif [ -f "/home/cuaibox/zhuhui/llamacpp/llama.cpp/build/bin/llama-server" ]; then
    BINARY="/home/cuaibox/zhuhui/llamacpp/llama.cpp/build/bin/llama-server"
else
    echo "llama-server not found. Locate it first."
    exit 1
fi

echo "Found: $BINARY"

cat > /opt/start-server-rpc.sh << EOF
#!/bin/bash
# llama-server with RPC worker offloading
MODEL="/home/cuaibox/zhuhui/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"

# Fallback paths
for p in \\
    "/home/cuaibox/zhuhui/llamacpp/llama.cpp/models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf" \\
    "/opt/models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"; do
    if [ -f "\$p" ]; then
        MODEL="\$p"
        break
    fi
done

echo "Model: \$MODEL"
echo "RPC: $RPC_WORKERS"

$BINARY \\
    --model "\$MODEL" \\
    --host 0.0.0.0 \\
    --port 8080 \\
    --ctx-size 262144 \\
    --parallel 4 \\
    --n-gpu-layers 41 \\
    --cache-type-k q8_0 \\
    --cache-type-v q8_0 \\
    --rpc "$RPC_WORKERS"
EOF
chmod +x /opt/start-server-rpc.sh

echo "=== Created /opt/start-server-rpc.sh ==="
echo "Run it after starting RPC workers on 128GB machines"
echo ""
echo "Start order:"
echo "  1. 128GB-1: systemctl start llama-rpc-worker"
echo "  2. 128GB-2: systemctl start llama-rpc-worker"
echo "  3. 3090:    bash /opt/start-server-rpc.sh"
