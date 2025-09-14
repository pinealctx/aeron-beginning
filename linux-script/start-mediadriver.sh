#!/bin/bash
# 独立MediaDriver启动脚本 - 生产环境推荐

export AERON_DIR="/dev/shm/aeron"

# 确保目录存在且权限正确
if [ ! -d "$AERON_DIR" ]; then
    mkdir -p "$AERON_DIR"
elif [ ! -w "$AERON_DIR" ]; then
    echo "⚠️  Aeron目录权限不足，尝试修复..."
    if sudo chown $USER:$USER "$AERON_DIR" 2>/dev/null; then
        echo "✅ 权限修复成功"
    else
        echo "❌ 权限修复失败，请手动执行:"
        echo "   sudo chown $USER:$USER $AERON_DIR"
        echo "   sudo chmod 755 $AERON_DIR"
        exit 1
    fi
fi

# 检查JAR文件
AERON_JAR="aeron-all-1.48.6.jar"
if [ ! -f "$AERON_JAR" ]; then
    echo "❌ 找不到 $AERON_JAR"
    echo "请运行: ./download-aeron.sh"
    exit 1
fi

echo "🚀 启动独立MediaDriver..."
echo "Aeron目录: $AERON_DIR"
echo "使用JAR: $AERON_JAR"
echo "使用RAM磁盘以获得最佳性能"
echo ""

# 启动独立MediaDriver
java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir="$AERON_DIR" \
     -Daeron.term.buffer.sparse.file=false \
     -Daeron.pre.touch.mapped.memory=true \
     -Daeron.socket.so_sndbuf=2097152 \
     -Daeron.socket.so_rcvbuf=2097152 \
     -Daeron.rcv.initial.window.length=2097152 \
     -Xms2g -Xmx2g \
     -cp "$AERON_JAR" \
     io.aeron.driver.MediaDriver

echo "MediaDriver已停止"
