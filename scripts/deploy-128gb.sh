#!/bin/bash
# deploy-128gb.sh - Deploy LMCache daemon to 128GB RAM server
# Usage: bash deploy-128gb.sh 128gb-1 (or 128gb-2)
set -e

ROLE=${1:-"128gb-1"}
DEPLOY_DIR="/opt/lmcache-bundle"
BUNDLE_URL="https://github.com/quuyoo/lmcache-offline-bundle/actions"
LMCACHE_PORT=6500

echo "=== Deploying LMCache daemon ($ROLE) ==="

# Check if bundle exists locally, if not try to download
if [ ! -f "$DEPLOY_DIR/lmcache-bundle.tar.gz" ]; then
    echo "Bundle not found at $DEPLOY_DIR. Please download from GitHub Actions:"
    echo "  1. Go to $BUNDLE_URL"
    echo "  2. Click latest successful build"
    echo "  3. Download lmcache-bundle artifact"
    echo "  4. Extract to $DEPLOY_DIR/"
    echo ""
    echo "Or copy the .tar.gz to $DEPLOY_DIR/ and re-run this script."
    exit 1
fi

# Extract if needed
if [ ! -d "$DEPLOY_DIR/lmcache" ]; then
    cd /
    tar xzf "$DEPLOY_DIR/lmcache-bundle.tar.gz"
fi

# Create LMCache config
mkdir -p /etc/lmcache
cat > /etc/lmcache/config.yaml << 'EOF'
# LMCache Distributed Config for 128GB RAM server
# This node stores KV cache in system memory

# Cluster config
cluster:
  role: worker
  manager_address: "134.200.18.7:5000"  # 128GB-1 as manager

# Storage config
storage:
  type: memory
  max_memory_gb: 96  # Leave 32GB for OS

# Server config  
server:
  host: "0.0.0.0"
  port: 6500
  num_threads: 4

# Cache config
cache:
  chunk_size: 256  # tokens per chunk
  max_cached_tensors: 10000
  eviction_policy: "lru"
EOF

# Create systemd service
cat > /etc/systemd/system/lmcache-daemon.service << EOF
[Unit]
Description=LMCache Distributed KV Cache Daemon
After=network.target

[Service]
Type=simple
ExecStart=$DEPLOY_DIR/lmcache/bin/lmcache-daemon --config /etc/lmcache/config.yaml
Restart=always
RestartSec=5
User=root
Environment="LD_LIBRARY_PATH=$DEPLOY_DIR/lib"

[Install]
WantedBy=multi-user.target
EOF

# Create start script
cat > $DEPLOY_DIR/start-daemon.sh << 'EOF'
#!/bin/bash
# Start LMCache daemon
export LD_LIBRARY_PATH=/opt/lmcache-bundle/lib:$LD_LIBRARY_PATH
cd /opt/lmcache-bundle/lmcache
./bin/lmcache-daemon --config /etc/lmcache/config.yaml
EOF
chmod +x $DEPLOY_DIR/start-daemon.sh

# Enable and start
systemctl daemon-reload
systemctl enable lmcache-daemon
systemctl start lmcache-daemon

echo "=== LMCache daemon started on port $LMCACHE_PORT ==="
echo "Check status: systemctl status lmcache-daemon"
echo "Check logs: journalctl -u lmcache-daemon -f"
