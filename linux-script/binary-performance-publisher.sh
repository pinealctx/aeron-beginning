#!/bin/bash
# Aeron二进制高性能测试 - 发布者

export AERON_DIR="/dev/shm/aeron"

# 默认参数
MESSAGE_SIZE=64
MESSAGE_COUNT=1000000
WARMUP_COUNT=100000

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -size)
            MESSAGE_SIZE="$2"
            shift 2
            ;;
        -count)
            MESSAGE_COUNT="$2"
            shift 2
            ;;
        -warmup)
            WARMUP_COUNT="$2"
            shift 2
            ;;
        -help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  -size <bytes>    消息大小 (默认: 64)"
            echo "  -count <num>     测试消息数 (默认: 1000000)"
            echo "  -warmup <num>    预热消息数 (默认: 100000)"
            echo "  -help            显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 -help 查看帮助"
            exit 1
            ;;
    esac
done

echo "🚀 启动Aeron二进制高性能测试发布者..."
echo "连接到MediaDriver: $AERON_DIR"
echo "消息大小: $MESSAGE_SIZE bytes"
echo "测试消息数: $MESSAGE_COUNT"
echo "预热消息数: $WARMUP_COUNT"
echo "确保MediaDriver已在运行: ./start-mediadriver.sh"
echo "确保订阅者已在运行: ./binary-performance-subscriber.sh"
echo ""

java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Xms2g -Xmx2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=1 \
     -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher \
     -size $MESSAGE_SIZE -count $MESSAGE_COUNT -warmup $WARMUP_COUNT
