#!/bin/bash
# aeron-rpc-server-ipc.sh
# 
# 🚀 Aeron RPC服务器 - IPC版本 (进程间通信)

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron RPC服务器 (IPC模式)..."
echo "连接到MediaDriver: $AERON_DIR"
echo "传输方式: IPC (进程间通信 - 极低延迟)"
echo "确保MediaDriver已在运行"
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms2g -Xmx2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=1 \
     -cp xsyphon-aeron-forex.jar \
     com.xsyphon.aeron.AeronRpcServer \
     -transport IPC \
     "$@"
