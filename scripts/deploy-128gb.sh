#!/bin/bash
# deploy-128gb.sh - Deploy llama-server as RPC worker on 128GB RAM server
# Usage: bash deploy-128gb.sh
set -e

DEPLOY_DIR="/opt/llama-rpc"

echo "=== Deploying llama.cpp RPC worker ==="

ARCHIVE="llama-rpc-worker.tar.gz"
if [ ! -f "$ARCHIVE" ]; then
    echo "ERROR: $ARCHIVE not found in current directory."
    echo "Download from: https://github.com/quuyoo/lmcache-offline-bundle/actions"
    exit 1
fi

# Extract
mkdir -p $DEPLOY_DIR
tar xzf $ARCHIVE -C $DEPLOY_DIR
chmod +x $DEPLOY_DIR/llama-cpp-server/*

# Create start script
cat > $DEPLOY_DIR/start-rpc-worker.sh << 'EOF'
#!/bin/bash
# Start llama-server as RPC worker
# KV cache stored in system RAM (up to 128GB)
export LD_LIBRARY_PATH=/opt/llama-rpc/llama-cpp-server:$LD_LIBRARY_PATH

cd /opt/llama-rpc/llama-cpp-server

echo "Starting llama.cpp RPC worker on port 6500..."
echo "System memory:"
free -h

./llama-server \
    --host 0.0.0.0 \
    --port 6500 \
    --rpc
EOF
chmod +x $DEPLOY_DIR/start-rpc-worker.sh

# Create systemd service
cat > /etc/systemd/system/llama-rpc-worker.service << EOF
[Unit]
Description=Llama.cpp RPC Worker
After=network.target

[Service]
Type=simple
ExecStart=$DEPLOY_DIR/start-rpc-worker.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable llama-rpc-worker

echo "=== Done ==="
echo "Start: systemctl start llama-rpc-worker"
echo "Logs: journalctl -u llama-rpc-worker -f"
