#!/usr/bin/env bash
set -e

# SSH隧道配置
REMOTE_USER="tunneluser"        # 替换为您的云服务器用户名
REMOTE_HOST="your.cloud.host"   # 替换为您的云服务器地址
REMOTE_PORT=18000               # 云上将监听 127.0.0.1:18000
LOCAL_PORT=8000                 # 本地orchestrator端口
KEY_PATH="$HOME/.ssh/id_rsa"    # SSH私钥路径

# 可选：多服务端口映射
OCR_REMOTE_PORT=18010
OCR_LOCAL_PORT=7010
NMT_REMOTE_PORT=18020  
NMT_LOCAL_PORT=7020

echo "[Tunnel] Starting reverse SSH tunnel: cloud:${REMOTE_PORT} -> local:${LOCAL_PORT}"
echo "[Tunnel] Additional ports: OCR ${OCR_REMOTE_PORT}->${OCR_LOCAL_PORT}, NMT ${NMT_REMOTE_PORT}->${NMT_LOCAL_PORT}"

# 检查autossh是否可用
if command -v autossh &> /dev/null; then
    echo "[Tunnel] Using autossh for auto-reconnection..."
    autossh -M 0 -N -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
      -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} \
      -R ${OCR_REMOTE_PORT}:localhost:${OCR_LOCAL_PORT} \
      -R ${NMT_REMOTE_PORT}:localhost:${NMT_LOCAL_PORT} \
      ${REMOTE_USER}@${REMOTE_HOST} -i ${KEY_PATH}
else
    echo "[Tunnel] Using ssh (install autossh for auto-reconnection)..."
    ssh -N -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
      -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} \
      -R ${OCR_REMOTE_PORT}:localhost:${OCR_LOCAL_PORT} \
      -R ${NMT_REMOTE_PORT}:localhost:${NMT_LOCAL_PORT} \
      ${REMOTE_USER}@${REMOTE_HOST} -i ${KEY_PATH}
fi