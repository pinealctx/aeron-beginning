#!/bin/bash
# moderate-binary-performance-publisher.sh
#
# 🔧 中等优化二进制发布者 - 平衡性能与稳定性

echo "🚀 启动Aeron二进制高性能测试发布者 (中等优化版)..."
echo "连接到MediaDriver: /dev/shm/aeron"
echo ""

# 检测Java路径
JAVA_HOME=${JAVA_HOME:-"/home/kun/java/amazon-corretto-21.0.8.9.1-linux-x64"}
JAVA_BIN="$JAVA_HOME/bin/java"

# 如果JAVA_HOME路径不存在，尝试which java
if [ ! -f "$JAVA_BIN" ]; then
    JAVA_BIN=$(which java 2>/dev/null)
    if [ -z "$JAVA_BIN" ]; then
        echo "❌ 错误：找不到Java可执行文件"
        echo "请设置JAVA_HOME环境变量或确保java在PATH中"
        exit 1
    fi
fi

echo "📍 使用Java: $JAVA_BIN"
echo "⚡ 使用中等优化配置启动发布者..."
echo "   - 进程优先级: -5 (中等优先级)"
echo "   - 堆内存: 1GB"
echo "   - GC: G1GC 5ms最大暂停"
echo ""

nice -n -5 "$JAVA_BIN" \
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
    -Xms1G -Xmx1G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=5 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UseLargePages \
    -Daeron.dir=/dev/shm/aeron \
    -cp xsyphon-aeron-forex.jar \
    com.xsyphon.aeron.BinaryPerformancePublisher "$@"
