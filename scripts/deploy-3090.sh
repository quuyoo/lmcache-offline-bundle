#!/bin/bash
# deploy-3090.sh - Deploy llama-server with LMCache to RTX 3090
set -e

DEPLOY_DIR="/opt/lmcache-bundle"
LMCACHE_HOST="134.200.18.7:6500,134.200.18.8:6500"

echo "=== Deploying llama-server to RTX 3090 ==="

# Check bundle
if [ ! -f "$DEPLOY_DIR/lmcache-bundle.tar.gz" ]; then
    echo "Bundle not found at $DEPLOY_DIR. Download from GitHub Actions first."
    exit 1
fi

# Extract if needed
if [ ! -d "$DEPLOY_DIR/llama-cpp-server" ]; then
    cd /
    tar xzf "$DEPLOY_DIR/lmcache-bundle.tar.gz"
fi

# Create start script with LMCache RPC
cat > $DEPLOY_DIR/start-server.sh << EOF
#!/bin/bash
# Start llama-server with LMCache distributed RPC
# Model path - adjust as needed
MODEL_PATH="/home/cuaibox/zhuhui/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"

# If model not found, try common locations
if [ ! -f "\$MODEL_PATH" ]; then
    for p in \\
        "/home/cuaibox/zhuhui/llamacpp/llama.cpp/models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf" \\
        "/opt/models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf" \\
        "./models/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"; do
        if [ -f "\$p" ]; then
            MODEL_PATH="\$p"
            break
        fi
    done
fi

echo "Using model: \$MODEL_PATH"
echo "LMCache RPC backends: $LMCACHE_HOST"

cd $DEPLOY_DIR/llama-cpp-server

# Start llama-server with LMCache RPC
./llama-server \\
    --model "\$MODEL_PATH" \\
    --host 0.0.0.0 \\
    --port 8080 \\
    --ctx-size 262144 \\
    --parallel 4 \\
    --n-gpu-layers 41 \\
    --cache-type-k q8_0 \\
    --cache-type-v q8_0 \\
    --rpc "$LMCACHE_HOST"
EOF
chmod +x $DEPLOY_DIR/start-server.sh

# Create systemd service
cat > /etc/systemd/system/llama-lmcache.service << EOF
[Unit]
Description=Llama Server with LMCache
After=network.target

[Service]
Type=simple
ExecStart=$DEPLOY_DIR/start-server.sh
Restart=always
RestartSec=10
User=root
WorkingDirectory=$DEPLOY_DIR/llama-cpp-server
Environment="LD_LIBRARY_PATH=$DEPLOY_DIR/llama-cpp-server:$LD_LIBRARY_PATH"
Environment="CUDA_VISIBLE_DEVICES=0"

[Install]
WantedBy=multi-user.target
EOF

# Create stop script
cat > $DEPLOY_DIR/stop-server.sh << 'EOF'
#!/bin/bash
echo "Stopping llama-lmcache service..."
systemctl stop llama-lmcache
echo "Service stopped."
EOF
chmod +x $DEPLOY_DIR/stop-server.sh

systemctl daemon-reload
systemctl enable llama-lmcache

echo "=== Deployment complete ==="
echo "Start server: systemctl start llama-lmcache"
echo "Or manually: $DEPLOY_DIR/start-server.sh"
