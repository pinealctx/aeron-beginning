#!/bin/bash
# aeron-rpc-test.sh
# 
# 🚀 Aeron RPC测试 - UDP版本 (网络传输)

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron RPC客户端测试 (UDP模式)..."
echo "连接到MediaDriver: $AERON_DIR"
echo "传输方式: UDP (网络传输)"
echo "确保MediaDriver和RPC服务器都在运行"
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms2g -Xmx2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=1 \
     -cp xsyphon-aeron-forex.jar \
     com.xsyphon.aeron.AeronRpcTest \
     -transport UDP \
     "$@"
