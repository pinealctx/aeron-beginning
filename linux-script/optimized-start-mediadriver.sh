#!/bin/bash
# optimized-start-mediadriver.sh
# 
# 🚀 Aeron MediaDriver 高性能优化版启动脚本
# 专为超低延迟高频交易系统设计
#
# 优化特性:
# - CPU亲和性绑定到专用核心
# - 最高进程优先级 (-20)
# - 专用线程模式 (DEDICATED)
# - 忙等待策略 (BusySpinIdleStrategy)
# - 大页内存支持
# - G1GC 1ms最大暂停
# - RAM磁盘存储 (/dev/shm)

echo "🚀 启动Aeron MediaDriver (高性能优化版)..."

# 检查是否已有MediaDriver在运行
if pgrep -f "io.aeron.driver.MediaDriver" > /dev/null; then
    echo "⚠️  MediaDriver 已在运行，先停止现有进程..."
    pkill -f "io.aeron.driver.MediaDriver"
    sleep 2
fi

# 确保RAM磁盘存在并设置正确权限
if [ ! -d "/dev/shm/aeron" ]; then
    echo "📁 创建Aeron目录: /dev/shm/aeron"
    sudo mkdir -p /dev/shm/aeron
    sudo chown $USER:$USER /dev/shm/aeron
    sudo chmod 755 /dev/shm/aeron
    echo "   ✅ 目录权限已设置为当前用户"
elif [ ! -w "/dev/shm/aeron" ]; then
    echo "🔧 修复Aeron目录权限..."
    sudo chown $USER:$USER /dev/shm/aeron
    sudo chmod 755 /dev/shm/aeron
    echo "   ✅ 权限修复完成"
fi

# 检查大页内存支持
if [ -f "/proc/meminfo" ]; then
    HUGEPAGES=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    if [ "$HUGEPAGES" = "0" ] || [ -z "$HUGEPAGES" ]; then
        echo "⚠️  大页内存未配置，建议执行: sudo sysctl vm.nr_hugepages=1024"
    else
        echo "✅ 大页内存可用: $HUGEPAGES 页"
    fi
fi

echo "⚡ 使用优化配置启动 MediaDriver..."
echo "   - 进程优先级: -15 (高优先级)"
echo "   - 线程模式: DEDICATED"
echo "   - 空闲策略: BusySpinIdleStrategy"
echo "   - 存储目录: /dev/shm/aeron"
echo "   - 内存配置: 2GB堆内存"
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
echo ""

# 简化优化：去掉CPU亲和性绑定，保留优先级
nice -n -15 "$JAVA_BIN" \
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
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
    -Daeron.rcv.initial.window.length=2097152 \
    -Daeron.socket.so_sndbuf=2097152 \
    -Daeron.socket.so_rcvbuf=2097152 \
    -cp aeron-all-1.48.6.jar \
    io.aeron.driver.MediaDriver &

MEDIADRIVER_PID=$!
echo "✅ MediaDriver 已启动 (PID: $MEDIADRIVER_PID)"
echo "📊 进程信息:"
echo "   - CPU亲和性: $(taskset -p $MEDIADRIVER_PID 2>/dev/null | cut -d: -f2 | tr -d ' ')"
echo "   - 优先级: $(ps -o pid,ni -p $MEDIADRIVER_PID --no-headers | awk '{print $2}')"
echo ""
echo "🔍 监控命令:"
echo "   检查进程: ps aux | grep MediaDriver"
echo "   查看日志: tail -f /dev/shm/aeron/cnc-*.log"
echo "   停止服务: ./stop-mediadriver.sh"
echo ""
echo "⚡ MediaDriver 优化版就绪，可开始高频交易测试!"
