#!/bin/bash
# start-mediadriver-cpu-affinity.sh
# 
# 🚀 CPU亲和性优化的MediaDriver - 32核心系统

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron MediaDriver (CPU亲和性优化版)..."
echo "CPU绑定: 核心0-1 (专用)"
echo "⚠️  需要sudo权限设置CPU亲和性和进程优先级"

# 检查权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 此脚本需要sudo权限执行"
    echo "请使用: sudo $0"
    exit 1
fi

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
    chown $SUDO_USER:$SUDO_USER "$AERON_DIR" 2>/dev/null || true
    chmod 755 "$AERON_DIR"
elif [ ! -w "$AERON_DIR" ]; then
    echo "🔧 修复Aeron目录权限..."
    chown $SUDO_USER:$SUDO_USER "$AERON_DIR" 2>/dev/null || true
    chmod 755 "$AERON_DIR" 2>/dev/null || true
fi

echo "⚡ MediaDriver CPU亲和性优化配置:"
echo "   - CPU绑定: 核心0-1"
echo "   - 进程优先级: -15"
echo "   - 线程模式: DEDICATED"
echo "   - 极限网络优化"
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

echo "🛠️  系统诊断信息:"
echo "   - Java路径: $JAVA_BIN"
echo "   - 当前用户: $(whoami)"
echo "   - 是否有root权限: $([ "$EUID" -eq 0 ] && echo "是" || echo "否")"
echo "   - 可用CPU核心: $(nproc)"
echo "   - taskset版本: $(taskset --version 2>/dev/null | head -1 || echo "未找到taskset")"

if [ ! -f "$JAVA_BIN" ]; then
    echo "❌ Java路径无效: $JAVA_BIN"
    exit 1
fi

if ! command -v taskset >/dev/null 2>&1; then
    echo "❌ taskset命令未找到，请安装util-linux包"
    exit 1
fi

echo ""
echo "🚀 启动MediaDriver..."

# CPU亲和性绑定到核心0-1，最高优先级，以原用户身份运行Java
# 第一种方式：直接设置亲和性和优先级
if [ -n "$SUDO_USER" ]; then
    echo "🔧 以用户$SUDO_USER身份启动，绑定到CPU核心0-1..."
    taskset -c 0-1 nice -n -15 sudo -u "$SUDO_USER" "$JAVA_BIN" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
        -Xms2G -Xmx2G \
        -XX:+UseG1GC \
        -XX:MaxGCPauseMillis=2 \
        -XX:+UnlockExperimentalVMOptions \
        -XX:+UseLargePages \
        -XX:+AlwaysPreTouch \
        -XX:+DisableExplicitGC \
        -XX:+UseTransparentHugePages \
        -Daeron.dir=/dev/shm/aeron \
        -Daeron.term.buffer.sparse.file=false \
        -Daeron.pre.touch.mapped.memory=true \
        -Daeron.threading.mode=DEDICATED \
        -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.receiver.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.socket.so_sndbuf=16777216 \
        -Daeron.socket.so_rcvbuf=16777216 \
        -Daeron.mtu.length=8192 \
        -Daeron.ipc.mtu.length=8192 \
        -Daeron.term.buffer.length=4194304 \
        -Daeron.rcv.initial.window.length=4194304 \
        -Daeron.network.publication.linger.timeout=0 \
        -Daeron.receiver.group.consideration.timeout=0 \
        -cp aeron-all-1.48.6.jar \
        io.aeron.driver.MediaDriver &
else
    echo "🔧 以root身份启动，绑定到CPU核心0-1..."
    taskset -c 0-1 nice -n -15 "$JAVA_BIN" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
        -Xms2G -Xmx2G \
        -XX:+UseG1GC \
        -XX:MaxGCPauseMillis=2 \
        -XX:+UnlockExperimentalVMOptions \
        -XX:+UseLargePages \
        -XX:+AlwaysPreTouch \
        -XX:+DisableExplicitGC \
        -XX:+UseTransparentHugePages \
        -Daeron.dir=/dev/shm/aeron \
        -Daeron.term.buffer.sparse.file=false \
        -Daeron.pre.touch.mapped.memory=true \
        -Daeron.threading.mode=DEDICATED \
        -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.receiver.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.socket.so_sndbuf=16777216 \
        -Daeron.socket.so_rcvbuf=16777216 \
        -Daeron.mtu.length=8192 \
        -Daeron.ipc.mtu.length=8192 \
        -Daeron.term.buffer.length=4194304 \
        -Daeron.rcv.initial.window.length=4194304 \
        -Daeron.network.publication.linger.timeout=0 \
        -Daeron.receiver.group.consideration.timeout=0 \
        -cp aeron-all-1.48.6.jar \
        io.aeron.driver.MediaDriver &
fi

MEDIADRIVER_PID=$!
echo "✅ MediaDriver CPU亲和性版已启动 (PID: $MEDIADRIVER_PID)"

# 等待进程启动
sleep 2

# 验证CPU亲和性和优先级
if [ -n "$MEDIADRIVER_PID" ] && kill -0 $MEDIADRIVER_PID 2>/dev/null; then
    echo "📊 进程信息:"
    if command -v taskset >/dev/null 2>&1; then
        AFFINITY=$(taskset -p $MEDIADRIVER_PID 2>/dev/null | cut -d: -f2 | tr -d ' ')
        echo "   - CPU亲和性: $AFFINITY"
        
        # 解析亲和性掩码
        if [[ "$AFFINITY" =~ ^0*3$ ]] || [[ "$AFFINITY" =~ ^3$ ]]; then
            echo "   ✅ CPU亲和性正确绑定到核心0-1"
        else
            echo "   ⚠️  CPU亲和性可能绑定失败"
        fi
    fi
    
    PRIORITY=$(ps -o pid,ni -p $MEDIADRIVER_PID --no-headers 2>/dev/null | awk '{print $2}')
    if [ -n "$PRIORITY" ]; then
        echo "   - 优先级: $PRIORITY"
        if [ "$PRIORITY" -eq -15 ]; then
            echo "   ✅ 高优先级设置成功"
        else
            echo "   ⚠️  优先级设置可能失败"
        fi
    fi
else
    echo "❌ 进程启动可能失败"
fi

echo ""
echo "🔍 监控命令:"
echo "   检查进程: ps aux | grep MediaDriver"
echo "   CPU使用率: htop -p $MEDIADRIVER_PID"
echo "   停止服务: ./stop-mediadriver.sh"
echo ""
echo "🚀 MediaDriver CPU亲和性版就绪 - 专用核心0-1!"
