#!/bin/bash
# moderate-start-mediadriver.sh
# 
# 🔧 Aeron MediaDriver 中等优化版启动脚本
# 平衡性能和稳定性

echo "🚀 启动Aeron MediaDriver (中等优化版)..."

# 检查是否已有MediaDriver在运行
if pgrep -f "io.aeron.driver.MediaDriver" > /dev/null; then
    echo "⚠️  MediaDriver 已在运行，先停止现有进程..."
    pkill -f "io.aeron.driver.MediaDriver"
    sleep 2
fi

# 确保RAM磁盘存在并有正确权限
echo "📁 准备Aeron目录: /dev/shm/aeron"
sudo rm -rf /dev/shm/aeron
mkdir -p /dev/shm/aeron
chmod 755 /dev/shm/aeron

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
echo "⚡ MediaDriver中等优化配置:"
echo "   - 线程模式: SHARED (共享，更稳定)"
echo "   - 进程优先级: -10 (中等优先级)"
echo "   - 内存配置: 1GB堆内存"
echo "   - GC: G1GC 5ms最大暂停"
echo "   - 存储目录: /dev/shm/aeron"
echo ""

# 中等优化启动MediaDriver - 不使用taskset，避免权限问题
nice -n -10 "$JAVA_BIN" \
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
    -Xms1G -Xmx1G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=5 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UseLargePages \
    -Daeron.dir=/dev/shm/aeron \
    -Daeron.term.buffer.sparse.file=false \
    -Daeron.pre.touch.mapped.memory=true \
    -Daeron.threading.mode=SHARED \
    -Daeron.rcv.initial.window.length=2097152 \
    -Daeron.socket.so_sndbuf=2097152 \
    -Daeron.socket.so_rcvbuf=2097152 \
    -cp aeron-all-1.48.6.jar \
    io.aeron.driver.MediaDriver &

MEDIADRIVER_PID=$!
echo "✅ MediaDriver 已启动 (PID: $MEDIADRIVER_PID)"
echo "📊 进程信息:"
echo "   - 优先级: $(ps -o pid,ni -p $MEDIADRIVER_PID --no-headers | awk '{print $2}')"
echo ""
echo "🔍 监控命令:"
echo "   检查进程: ps aux | grep MediaDriver"
echo "   查看日志: ls -la /dev/shm/aeron/"
echo "   停止服务: pkill -f MediaDriver"
echo ""
echo "⚡ MediaDriver 中等优化版就绪，平衡性能与稳定性!"
