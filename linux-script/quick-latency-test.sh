#!/bin/bash
# quick-latency-test.sh
# 快速延迟测试 - 100万条消息

echo "🚀 快速延迟测试 (100万条消息)"
echo "=================================="

# 检测Java路径
JAVA_HOME=${JAVA_HOME:-"/home/kun/java/amazon-corretto-21.0.8.9.1-linux-x64"}
JAVA_BIN="$JAVA_HOME/bin/java"

if [ ! -f "$JAVA_BIN" ]; then
    JAVA_BIN=$(which java 2>/dev/null)
    if [ -z "$JAVA_BIN" ]; then
        echo "❌ 错误：找不到Java可执行文件"
        exit 1
    fi
fi

echo "使用Java: $JAVA_BIN"
echo ""

# 在后台启动订阅者，接收100万条消息
echo "启动订阅者 (目标: 100万条消息)..."
"$JAVA_BIN" \
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
    -Xms512M -Xmx512M \
    -XX:+UseG1GC \
    -Daeron.dir=/dev/shm/aeron \
    -cp xsyphon-aeron-forex.jar \
    com.xsyphon.aeron.BinaryPerformanceSubscriber -count 1000000 &

SUBSCRIBER_PID=$!
echo "订阅者 PID: $SUBSCRIBER_PID"

# 等待2秒让订阅者启动
sleep 2

echo ""
echo "启动发布者 (发送100万条消息)..."
"$JAVA_BIN" \
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
    -Xms512M -Xmx512M \
    -XX:+UseG1GC \
    -Daeron.dir=/dev/shm/aeron \
    -cp xsyphon-aeron-forex.jar \
    com.xsyphon.aeron.BinaryPerformancePublisher -count 1000000

echo ""
echo "等待订阅者完成..."
wait $SUBSCRIBER_PID

echo "快速测试完成! 🎉"
