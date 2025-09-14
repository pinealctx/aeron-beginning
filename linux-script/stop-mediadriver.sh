#!/bin/bash
# stop-mediadriver.sh
#
# 🛑 停止Aeron MediaDriver

echo "🛑 停止Aeron MediaDriver..."

# 查找MediaDriver进程
PIDS=$(pgrep -f "io.aeron.driver.MediaDriver")

if [ -z "$PIDS" ]; then
    echo "ℹ️  没有发现运行中的MediaDriver进程"
    exit 0
fi

echo "📋 发现MediaDriver进程: $PIDS"

# 优雅停止
echo "⏳ 尝试优雅停止..."
kill $PIDS
sleep 3

# 检查是否已停止
REMAINING=$(pgrep -f "io.aeron.driver.MediaDriver")
if [ -n "$REMAINING" ]; then
    echo "⚠️  强制停止残留进程: $REMAINING"
    kill -9 $REMAINING
    sleep 1
fi

# 最终检查
FINAL_CHECK=$(pgrep -f "io.aeron.driver.MediaDriver")
if [ -z "$FINAL_CHECK" ]; then
    echo "✅ MediaDriver 已成功停止"
    
    # 清理目录 (处理权限问题)
    if [ -d "/dev/shm/aeron" ]; then
        echo "🧹 清理Aeron目录..."
        # 尝试普通用户删除
        if rm -rf /dev/shm/aeron/* 2>/dev/null; then
            echo "   ✅ 目录清理完成"
        else
            echo "   ⚠️  需要sudo权限清理，尝试sudo删除..."
            if sudo rm -rf /dev/shm/aeron/* 2>/dev/null; then
                echo "   ✅ sudo清理完成"
                # 重新创建目录并设置正确权限
                sudo mkdir -p /dev/shm/aeron
                sudo chown $USER:$USER /dev/shm/aeron
                sudo chmod 755 /dev/shm/aeron
                echo "   ✅ 权限已重置为当前用户"
            else
                echo "   ❌ 清理失败，请手动执行: sudo rm -rf /dev/shm/aeron/*"
            fi
        fi
    fi
else
    echo "❌ 停止失败，仍有进程: $FINAL_CHECK"
    exit 1
fi
