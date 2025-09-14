#!/bin/bash
# optimized-binary-performance-pub# 检测Java路径
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
echo ""

sudo taskset -c 1 nice -n -20 "$JAVA_BIN" \
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
    -Xms1G -Xmx1G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=1 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UseLargePages \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -Daeron.dir=/dev/shm/aeron \
    -cp xsyphon-aeron-forex.jar \
    com.xsyphon.aeron.BinaryPerformancePublisher "$@"
# 🚀 高性能二进制发布者 - 优化版
# 专用CPU核心 + 最高优先级 + 优化JVM参数

echo "🚀 启动Aeron二进制高性能测试发布者 (优化版)..."

# 默认参数
MESSAGE_COUNT=1000000
MESSAGE_SIZE=64

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -count)
            MESSAGE_COUNT="$2"
            shift 2
            ;;
        -size)
            MESSAGE_SIZE="$2"
            shift 2
            ;;
        *)
            echo "用法: $0 [-count 消息数量] [-size 消息大小]"
            echo "示例: $0 -count 2000000 -size 64"
            exit 1
            ;;
    esac
done

echo "连接到MediaDriver: /dev/shm/aeron"
echo "消息大小: $MESSAGE_SIZE bytes"
echo "测试消息数: $MESSAGE_COUNT"
echo "确保MediaDriver已在运行: ./optimized-start-mediadriver.sh"
echo "确保订阅者已在运行: ./optimized-binary-performance-subscriber.sh"
echo ""

# CPU核心1 + 最高优先级 + 优化JVM参数
echo "⚡ 使用优化配置启动发布者..."
echo "   - CPU亲和性: 核心1"
echo "   - 进程优先级: -20 (最高)"
echo "   - 堆内存: 1GB"
echo "   - GC: G1GC 1ms最大暂停"
echo ""

sudo taskset -c 1 nice -n -20 java \
    -Xms1G -Xmx1G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=1 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UseLargePages \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -Daeron.dir=/dev/shm/aeron \
    -cp xsyphon-aeron-forex.jar \
    com.xsyphon.aeron.BinaryPerformancePublisher \
    -count $MESSAGE_COUNT \
    -size $MESSAGE_SIZE
