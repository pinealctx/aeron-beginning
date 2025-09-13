#!/bin/bash
# Aeron性能基准测试 - 发布者

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron性能测试发布者..."
echo "连接到MediaDriver: $AERON_DIR"
echo "确保MediaDriver已在运行: ./start-mediadriver.sh"
echo "确保订阅者已在运行: ./performance-subscriber.sh"
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms2g -Xmx2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=1 \
     -jar aeron-performance-publisher.jar
