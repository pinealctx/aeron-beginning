#!/bin/bash
# aeron-rpc-server.sh
# 
# 🚀 Aeron RPC服务器 - UDP版本 (网络传输)

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron RPC服务器 (UDP模式)..."
echo "连接到MediaDriver: $AERON_DIR"
echo "传输方式: UDP (网络传输)"
echo "确保MediaDriver已在运行"
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms2g -Xmx2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=1 \
     -cp xsyphon-aeron-forex.jar \
     com.xsyphon.aeron.AeronRpcServer \
     -transport UDP \
     "$@"n-rpc-server.sh
# 
# 🚀 Aeron RPC服务器启动脚本

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron RPC服务器..."
echo "连接到MediaDriver: $AERON_DIR"
echo "确保MediaDriver已在运行: ./start-mediadriver.sh"
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms1g -Xmx1g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=5 \
     -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.AeronRpcServer
