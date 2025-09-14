#!/bin/bash
# fix-aeron-permissions.sh
# 🔧 修复Aeron目录权限问题

echo "🔧 修复Aeron权限和目录..."

# 停止所有MediaDriver进程
echo "停止现有MediaDriver进程..."
pkill -f MediaDriver 2>/dev/null
sleep 2

# 清理并重新创建aeron目录
echo "重新创建/dev/shm/aeron目录..."
sudo rm -rf /dev/shm/aeron
mkdir -p /dev/shm/aeron

# 设置正确的权限
echo "设置目录权限..."
chmod 755 /dev/shm/aeron
ls -la /dev/shm/ | grep aeron

echo "✅ 权限修复完成！"
echo ""
echo "现在可以运行:"
echo "  ./start-mediadriver.sh         # 标准版"
echo "  ./optimized-start-mediadriver.sh  # 优化版"
