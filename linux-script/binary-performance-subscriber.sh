#!/bin/bash
# Aeron二进制高性能测试 - 订阅者

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron二进制高性能测试订阅者..."
echo "连接到MediaDriver: $AERON_DIR"
echo "确保MediaDriver已在运行: ./start-mediadriver.sh"
echo "准备接收二进制性能数据..."
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms2g -Xmx2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=1 \
     -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber
