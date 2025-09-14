#!/bin/bash
# simple-binary-performance-subscriber.sh
#
# 🚀 简化版二进制订阅者 - 无需sudo权限
# 适用于测试环境和权限受限的环境

echo "🚀 启动Aeron二进制高性能测试订阅者 (简化版)..."
echo "连接到MediaDriver: /dev/shm/aeron"
echo "准备接收二进制性能数据..."
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
echo "⚡ 使用标准配置启动订阅者..."
echo "   - 堆内存: 1GB"
echo "   - GC: G1GC"
echo "   - 参数: $@"
echo ""

"$JAVA_BIN" \
    -Xms1G -Xmx1G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=5 \
    -Daeron.dir=/dev/shm/aeron \
    -cp xsyphon-aeron-forex.jar \
    com.xsyphon.aeron.BinaryPerformanceSubscriber "$@"
