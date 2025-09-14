#!/bin/bash
# binary-performance-publisher-cpu-affinity.sh
# 
# 🚀 CPU亲和性优化的UDP发布者 - 绑定核心2-3

export AERON_DIR="/dev/shm/aeron"

echo "🚀 启动Aeron UDP发布者 (CPU亲和性优化版)..."
echo "CPU绑定: 核心2-3 (专用)"
echo "连接到MediaDriver: $AERON_DIR"
echo "传输方式: UDP (CPU亲和性极限优化)"
echo "⚠️  需要sudo权限设置CPU亲和性和进程优先级"
echo ""

# 检查权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 此脚本需要sudo权限执行"
    echo "请使用: sudo $0 [参数]"
    exit 1
fi

# 检测Java路径
JAVA_HOME=${JAVA_HOME:-"/home/kun/java/amazon-corretto-21.0.8.9.1-linux-x64"}
JAVA_BIN="$JAVA_HOME/bin/java"

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

# CPU亲和性绑定到核心2-3，以原用户身份运行Java
if [ -n "$SUDO_USER" ]; then
    echo "🔧 以用户$SUDO_USER身份启动，绑定到CPU核心2-3..."
    taskset -c 2-3 nice -n -10 sudo -u "$SUDO_USER" "$JAVA_BIN" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
        -Daeron.dir="$AERON_DIR" \
        -Xms2g -Xmx2g \
        -XX:+UseG1GC \
        -XX:MaxGCPauseMillis=2 \
        -XX:+UnlockExperimentalVMOptions \
        -XX:+UseLargePages \
        -XX:+AlwaysPreTouch \
        -XX:+DisableExplicitGC \
        -XX:+UseTransparentHugePages \
        -Daeron.socket.so_sndbuf=16777216 \
        -Daeron.socket.so_rcvbuf=16777216 \
        -Daeron.mtu.length=8192 \
        -Daeron.ipc.mtu.length=8192 \
        -Daeron.term.buffer.length=4194304 \
        -Daeron.rcv.initial.window.length=4194304 \
        -Daeron.threading.mode=DEDICATED \
        -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.network.publication.linger.timeout=0 \
        -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher -transport UDP "$@"
else
    echo "🔧 以root身份启动，绑定到CPU核心2-3..."
    taskset -c 2-3 nice -n -10 "$JAVA_BIN" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
        -Daeron.dir="$AERON_DIR" \
        -Xms2g -Xmx2g \
        -XX:+UseG1GC \
        -XX:MaxGCPauseMillis=2 \
        -XX:+UnlockExperimentalVMOptions \
        -XX:+UseLargePages \
        -XX:+AlwaysPreTouch \
        -XX:+DisableExplicitGC \
        -XX:+UseTransparentHugePages \
        -Daeron.socket.so_sndbuf=16777216 \
        -Daeron.socket.so_rcvbuf=16777216 \
        -Daeron.mtu.length=8192 \
        -Daeron.ipc.mtu.length=8192 \
        -Daeron.term.buffer.length=4194304 \
        -Daeron.rcv.initial.window.length=4194304 \
        -Daeron.threading.mode=DEDICATED \
        -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
        -Daeron.network.publication.linger.timeout=0 \
        -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher -transport UDP "$@"
fi
