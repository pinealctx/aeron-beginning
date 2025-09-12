#!/bin/bash

# 简单的rsync同步脚本 - 同步JAR包和Linux脚本到服务器
# 使用方法: ./sync-to-linux.sh user@hostname:/path/to/destination

if [ $# -eq 0 ]; then
    echo "使用方法: $0 user@hostname:/remote/path"
    echo "示例: $0 root@192.168.1.100:/opt/aeron-test"
    exit 1
fi

REMOTE_TARGET=$1
LOCAL_JAR_DIR="../target"
LOCAL_SCRIPT_DIR="../linux-script"

echo "🚀 同步文件到Linux服务器..."
echo "JAR源目录: $LOCAL_JAR_DIR"
echo "脚本源目录: $LOCAL_SCRIPT_DIR"
echo "目标: $REMOTE_TARGET"

# 同步JAR文件
echo "📦 同步JAR文件..."
rsync -avz --progress \
    $LOCAL_JAR_DIR/*.jar \
    $REMOTE_TARGET/

# 同步Linux脚本
echo "📜 同步Linux脚本..."
rsync -avz --progress \
    $LOCAL_SCRIPT_DIR/ \
    $REMOTE_TARGET/

echo "✅ 同步完成！"
echo ""
echo "在Linux服务器上运行:"
echo "cd $REMOTE_TARGET"
echo "chmod +x *.sh"
echo "./run-subscriber.sh  # 或者运行其他脚本"

