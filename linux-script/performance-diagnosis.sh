#!/bin/bash
# performance-diagnosis.sh
# 🔍 性能诊断脚本 - 对比不同配置的性能

echo "🔍 Aeron性能诊断脚本"
echo "=========================================="

# 检查系统信息
echo "📊 系统信息:"
echo "   CPU核心数: $(nproc)"
echo "   内存总量: $(free -h | awk '/^Mem:/ {print $2}')"
echo "   当前负载: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# 检查HugePage
echo "📋 HugePage配置:"
grep HugePages /proc/meminfo
echo ""

# 检查Java版本
echo "☕ Java版本:"
java -version
echo ""

# 检查是否有其他Java进程
echo "🔍 当前Java进程:"
ps aux | grep java | grep -v grep
echo ""

# 诊断测试1：标准MediaDriver + 标准应用
echo "🧪 测试1: 标准配置 (无优化)"
echo "===================="
echo "准备目录和权限..."

# 停止现有MediaDriver
pkill -f MediaDriver 2>/dev/null
sleep 2

# 清理并重新创建aeron目录
sudo rm -rf /dev/shm/aeron
mkdir -p /dev/shm/aeron
chmod 755 /dev/shm/aeron

echo "启动标准MediaDriver..."

# 启动标准MediaDriver
java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Daeron.dir=/dev/shm/aeron \
     -Daeron.term.buffer.sparse.file=false \
     -Daeron.pre.touch.mapped.memory=true \
     -Xms1g -Xmx1g \
     -cp aeron-all-1.48.6.jar \
     io.aeron.driver.MediaDriver &

MEDIADRIVER_PID=$!
echo "MediaDriver PID: $MEDIADRIVER_PID"
sleep 3

echo "开始标准性能测试..."
echo "请在另一个终端运行:"
echo "  ./binary-performance-subscriber.sh"
echo "然后在第三个终端运行:"  
echo "  ./binary-performance-publisher.sh -count 1000000"
echo ""
echo "按Enter键继续到优化测试..."
read

echo ""
echo "🚀 测试2: 优化配置"
echo "===================="
echo "准备优化目录和权限..."

# 停止标准MediaDriver
kill $MEDIADRIVER_PID 2>/dev/null
sleep 2

# 重新创建aeron目录并设置权限
sudo rm -rf /dev/shm/aeron
mkdir -p /dev/shm/aeron
chmod 755 /dev/shm/aeron

echo "启动优化MediaDriver..."

echo ""
echo "🚀 测试2: 优化配置"
echo "===================="
echo "启动优化MediaDriver..."

# 启动优化MediaDriver
taskset -c 0 nice -n -10 java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
     -Xms2g -Xmx2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=1 \
     -XX:+UnlockExperimentalVMOptions \
     -XX:+UseLargePages \
     -Daeron.dir=/dev/shm/aeron \
     -Daeron.threading.mode=DEDICATED \
     -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
     -Daeron.receiver.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
     -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \
     -cp aeron-all-1.48.6.jar \
     io.aeron.driver.MediaDriver &

OPTIMIZED_PID=$!
echo "优化MediaDriver PID: $OPTIMIZED_PID"
sleep 3

echo "开始优化性能测试..."
echo "请在另一个终端运行:"
echo "  taskset -c 2 java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED -Xms1g -Xmx1g -Daeron.dir=/dev/shm/aeron -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber"
echo "然后在第三个终端运行:"
echo "  taskset -c 1 java --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED -Xms1g -Xmx1g -Daeron.dir=/dev/shm/aeron -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher -count 1000000"
echo ""
echo "按Enter键停止所有测试..."
read

# 清理
kill $OPTIMIZED_PID 2>/dev/null
pkill -f MediaDriver 2>/dev/null

echo "诊断完成！"
