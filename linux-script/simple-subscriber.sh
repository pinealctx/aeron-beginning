#!/bin/bash
# Aeron外汇订阅者运行脚本 - 连接到独立MediaDriver

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动外汇订阅者..."
echo "连接到MediaDriver: $AERON_DIR"
echo "确保MediaDriver已在运行: ./start-mediadriver.sh"
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms1g -Xmx1g \
     -jar aeron-forex-subscriber.jar
