#!/bin/bash
# binary-performance-publisher-udp-extreme.sh
# 
# 🚀 UDP传输极限优化版 - 系统级优化

export AERON_DIR="/dev/shm/aeron"

# 检测Java路径 - 支持sudo环境
if [ -n "$JAVA_HOME" ]; then
    JAVA_CMD="$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
    JAVA_CMD="java"
elif [ -n "$SUDO_USER" ] && sudo -u "$SUDO_USER" bash -c 'command -v java' >/dev/null 2>&1; then
    # 在sudo环境下尝试获取原用户的Java路径
    JAVA_CMD=$(sudo -u "$SUDO_USER" bash -c 'command -v java')
elif [ -n "$SUDO_USER" ] && sudo -u "$SUDO_USER" bash -c '[ -n "$JAVA_HOME" ]' >/dev/null 2>&1; then
    # 尝试获取原用户的JAVA_HOME
    JAVA_CMD=$(sudo -u "$SUDO_USER" bash -c 'echo $JAVA_HOME/bin/java')
elif [ -f "/home/kun/java/amazon-corretto-21.0.8.9.1-linux-x64/bin/java" ]; then
    # 回退到已知的Java路径
    JAVA_CMD="/home/kun/java/amazon-corretto-21.0.8.9.1-linux-x64/bin/java"
else
    echo "❌ 错误: 找不到Java安装"
    echo "请设置JAVA_HOME环境变量或确保java在PATH中"
    echo "当前检查的路径:"
    echo "  JAVA_HOME: $JAVA_HOME"
    echo "  which java: $(which java 2>/dev/null || echo '未找到')"
    echo "  SUDO_USER: $SUDO_USER"
    exit 1
fi

echo "🚀 启动Aeron UDP极限优化测试发布者..."
echo "连接到MediaDriver: $AERON_DIR"
echo "传输方式: UDP (系统级极限优化)"

# 检查是否需要sudo权限
if [ "$EUID" -eq 0 ]; then
    echo "🔐 以root权限运行，保持用户身份..."
    USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
    echo "目标用户: $USER_NAME"
    echo "Java路径: $JAVA_CMD"
else
    echo "👤 以普通用户身份运行"
    USER_NAME="$(whoami)"
    echo "当前用户: $USER_NAME"
    echo "Java路径: $JAVA_CMD"
fi

echo ""
echo "⚡ 启动极限优化发布者..."
echo "   - 专用线程模式"
echo "   - 忙等待策略"
echo "   - 最大缓冲区"
echo ""

# 根据权限选择执行方式
if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    # 以sudo启动，但保持原用户身份执行Java程序
    sudo -u "$SUDO_USER" nice -n -10 "$JAVA_CMD" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
         -Daeron.dir="$AERON_DIR" \
         -Xms2g -Xmx2g \
         -XX:+UseG1GC \
         -XX:MaxGCPauseMillis=5 \
         -XX:+UnlockExperimentalVMOptions \
         -XX:+UseLargePages \
         -XX:+AlwaysPreTouch \
         -XX:+DisableExplicitGC \
         -XX:+UseTransparentHugePages \
         -Daeron.socket.so_sndbuf=16777216 \
         -Daeron.socket.so_rcvbuf=16777216 \
         -Daeron.mtu.length=8192 \
         -Daeron.term.buffer.length=4194304 \
         -Daeron.rcv.initial.window.length=4194304 \
         -Daeron.threading.mode=DEDICATED \
         -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
         -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
         -Daeron.network.publication.linger.timeout=0 \
         -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher -transport UDP "$@"
else
    # 普通权限执行
    nice -n -10 "$JAVA_CMD" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
         -Daeron.dir="$AERON_DIR" \
         -Xms2g -Xmx2g \
         -XX:+UseG1GC \
         -XX:MaxGCPauseMillis=5 \
         -XX:+UnlockExperimentalVMOptions \
         -XX:+UseLargePages \
         -XX:+AlwaysPreTouch \
         -XX:+DisableExplicitGC \
         -XX:+UseTransparentHugePages \
         -Daeron.socket.so_sndbuf=16777216 \
         -Daeron.socket.so_rcvbuf=16777216 \
         -Daeron.mtu.length=8192 \
         -Daeron.term.buffer.length=4194304 \
         -Daeron.rcv.initial.window.length=4194304 \
         -Daeron.threading.mode=DEDICATED \
         -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
         -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
         -Daeron.network.publication.linger.timeout=0 \
         -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher -transport UDP "$@"
fi
