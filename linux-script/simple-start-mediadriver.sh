#!/bin/bash
# simple-start-mediadriver.sh
# 
# 🚀 Aeron MediaDriver 简化版启动脚本
# 无需sudo权限，适用于测试环境

echo "🚀 启动Aeron MediaDriver (简化版)..."

# 检查是否已有MediaDriver在运行
if pgrep -f "io.aeron.driver.MediaDriver" > /dev/null; then
    echo "⚠️  MediaDriver 已在运行，先停止现有进程..."
    pkill -f "io.aeron.driver.MediaDriver"
    sleep 2
fi

# 确保RAM磁盘存在
if [ ! -d "/dev/shm/aeron" ]; then
    echo "📁 创建Aeron目录: /dev/shm/aeron"
    mkdir -p /dev/shm/aeron
fi

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
echo ""
echo "⚡ MediaDriver配置:"
echo "   - 线程模式: 标准模式"
echo "   - 存储目录: /dev/shm/aeron"
echo "   - 内存配置: 1GB堆内存"
echo ""

# 标准模式启动MediaDriver
"$JAVA_BIN" \
    -Xms1G -Xmx1G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=5 \
    -Daeron.dir=/dev/shm/aeron \
    -cp aeron-all-1.48.6.jar \
    io.aeron.driver.MediaDriver &

MEDIADRIVER_PID=$!
echo "✅ MediaDriver 已启动 (PID: $MEDIADRIVER_PID)"
echo ""
echo "🔍 监控命令:"
echo "   检查进程: ps aux | grep MediaDriver"
echo "   停止服务: pkill -f MediaDriver"
echo ""
echo "⚡ MediaDriver 就绪，可开始测试!"
