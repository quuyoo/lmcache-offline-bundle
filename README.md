# LMCache Offline Bundle

为离线环境（无法 Docker、无外网）构建的 LMCache + llama.cpp 分布式部署包。

## 架构

```
┌─────────────────────────────────────────────────┐
│                 RTX 3090 (24GB)                  │
│           llama-server (-ngl 41)                 │
│         --rpc 128GB-1:6500,128GB-2:6500         │
│            --ctx-size 262144 --np 4              │
└────────────────────┬────────────────────────────┘
                     │ RPC (KV cache offload)
         ┌───────────┴───────────┐
         │                       │
┌────────┴────────┐   ┌────────┴────────┐
│  128GB #1        │   │  128GB #2        │
│  lmcache-daemon  │   │  lmcache-daemon  │
│  Port 6500       │   │  Port 6500       │
│  存储 KV cache   │   │  存储 KV cache   │
└──────────────────┘   └──────────────────┘
```

## 解决的问题

- 3090 单机 24GB 显存跑 35B 模型 + 256K 上下文会 OOM
- KV cache（FP16 24GB / q8_0 12GB）超出 GPU 显存
- 分布式架构：计算在 GPU，KV cache 卸载到 2 台 128GB 机器内存

## 快速开始

### 1. 构建

GitHub Actions 自动构建，下载 `lmcache-bundle` artifact，解压得到 `lmcache-bundle.tar.gz`。

### 2. 部署

```bash
# 128GB #1 (134.200.18.7)
scp lmcache-bundle.tar.gz root@134.200.18.7:/opt/
scp scripts/deploy-128gb.sh root@134.200.18.7:/opt/
ssh root@134.200.18.7 "bash /opt/deploy-128gb.sh 128gb-1"

# 128GB #2 (134.200.18.8)
scp lmcache-bundle.tar.gz root@134.200.18.8:/opt/
scp scripts/deploy-128gb.sh root@134.200.18.8:/opt/
ssh root@134.200.18.8 "bash /opt/deploy-128gb.sh 128gb-2"

# 3090 (134.200.58.99)
scp lmcache-bundle.tar.gz root@134.200.58.99:/opt/
scp scripts/deploy-3090.sh root@134.200.58.99:/opt/
ssh root@134.200.58.99 "bash /opt/deploy-3090.sh"
```

### 3. 启动

```bash
# 先启动 128GB 机器的 lmcache-daemon
ssh root@134.200.18.7 "systemctl start lmcache-daemon"
ssh root@134.200.18.8 "systemctl start lmcache-daemon"

# 再启动 3090 的 llama-server
ssh root@134.200.58.99 "systemctl start llama-lmcache"
```

### 4. 验证

```bash
# 测试 API
curl http://134.200.58.99:8080/v1/models

# 测试上下文
curl -s http://134.200.58.99:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama",
    "messages": [{"role":"user","content":"Say hello"}],
    "max_tokens": 100
  }'
```

## 服务器信息

| 服务器 | IP | 内存 | GPU | 用途 |
|--------|------|------|-----|------|
| 3090 | 134.200.58.99 | 32GB | RTX 3090 24GB | llama-server (推理) |
| 128GB #1 | 134.200.18.7 | 48GB | 无 | lmcache-daemon (KV cache) |
| 128GB #2 | 134.200.18.8 | 46GB | 无 | lmcache-daemon (KV cache) |

## 依赖

构建环境：GitHub Actions (debian:bullseye, glibc 2.28)
目标环境：Ubuntu 20.04 / UOS 20 (glibc 2.28)
