#!/bin/bash
# binary-performance-subscriber-ipc.sh
# Aeron二进制高性能测试 - 订阅者 (IPC模式)

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

echo "🚀 启动Aeron二进制高性能测试订阅者 (IPC模式)..."
echo "连接到MediaDriver: $AERON_DIR"
echo "传输方式: IPC (进程间通信)"
echo "确保MediaDriver已在运行: ./start-mediadriver.sh"

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

echo "准备接收二进制性能数据..."
echo ""

# 根据权限选择执行方式
if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    # 以sudo启动，但保持原用户身份执行Java程序
    sudo -u "$SUDO_USER" "$JAVA_CMD" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
         -Daeron.dir="$AERON_DIR" \
         -Xms2g -Xmx2g \
         -XX:+UseG1GC \
         -XX:MaxGCPauseMillis=1 \
         -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber \
         -transport IPC "$@"
else
    # 普通权限执行
    "$JAVA_CMD" --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
         -Daeron.dir="$AERON_DIR" \
         -Xms2g -Xmx2g \
         -XX:+UseG1GC \
         -XX:MaxGCPauseMillis=1 \
         -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber \
         -transport IPC "$@"
fi
