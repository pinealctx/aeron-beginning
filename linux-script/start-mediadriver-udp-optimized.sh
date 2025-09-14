#!/bin/bash
# start-mediadriver-udp-optimized.sh
# 
# 🚀 UDP优化版MediaDriver - 匹配客户端优化配置

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron MediaDriver (UDP优化版)..."

# 检查是否已有MediaDriver在运行
if pgrep -f "io.aeron.driver.MediaDriver" > /dev/null; then
    echo "⚠️  MediaDriver 已在运行，先停止现有进程..."
    pkill -f "io.aeron.driver.MediaDriver"
    sleep 2
fi

# 确保RAM磁盘存在并有正确权限
echo "📁 准备Aeron目录: /dev/shm/aeron"
if [ ! -d "$AERON_DIR" ]; then
    mkdir -p "$AERON_DIR"
elif [ ! -w "$AERON_DIR" ]; then
    echo "🔧 修复Aeron目录权限..."
    sudo chown $USER:$USER "$AERON_DIR" 2>/dev/null || true
    sudo chmod 755 "$AERON_DIR" 2>/dev/null || true
fi

echo "⚡ MediaDriver UDP优化配置:"
echo "   - 线程模式: DEDICATED (专用线程)"
echo "   - 进程优先级: -10 (高优先级)"
echo "   - 内存配置: 2GB堆内存"
echo "   - Socket缓冲区: 2MB"
echo "   - Term缓冲区: 2MB"
echo "   - MTU: 8KB"
echo ""

# UDP优化版MediaDriver - 匹配客户端配置
nice -n -10 java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
    -Xms2G -Xmx2G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=5 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+UseLargePages \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -Daeron.dir=/dev/shm/aeron \
    -Daeron.term.buffer.sparse.file=false \
    -Daeron.pre.touch.mapped.memory=true \
    -Daeron.threading.mode=DEDICATED \
    -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
    -Daeron.receiver.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
    -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
    -Daeron.socket.so_sndbuf=2097152 \
    -Daeron.socket.so_rcvbuf=2097152 \
    -Daeron.mtu.length=8192 \
    -Daeron.ipc.mtu.length=8192 \
    -Daeron.term.buffer.length=2097152 \
    -Daeron.rcv.initial.window.length=2097152 \
    -cp aeron-all-1.48.6.jar \
    io.aeron.driver.MediaDriver &

MEDIADRIVER_PID=$!
echo "✅ MediaDriver UDP优化版已启动 (PID: $MEDIADRIVER_PID)"
echo "📊 进程信息:"
echo "   - 优先级: $(ps -o pid,ni -p $MEDIADRIVER_PID --no-headers | awk '{print $2}')"
echo ""
echo "🔍 监控命令:"
echo "   检查进程: ps aux | grep MediaDriver"
echo "   查看日志: ls -la /dev/shm/aeron/"
echo "   停止服务: ./stop-mediadriver.sh"
echo ""
echo "⚡ MediaDriver UDP优化版就绪!"
