#!/bin/bash
# universal-aeron-optimization.sh
# 
# 🚀 通用Aeron系统优化脚本 - 适用于任何Linux机器

echo "🚀 通用Aeron系统优化脚本"
echo "自动检测系统配置，智能应用优化"
echo ""

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 此脚本需要root权限执行"
    echo "请使用: sudo $0"
    exit 1
fi

# 系统信息检测
echo "📊 系统配置检测..."
CPU_CORES=$(nproc)
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
KERNEL_VERSION=$(uname -r)
MAIN_INTERFACE=$(ip route | grep default | head -1 | awk '{print $5}')

echo "   - CPU核心数: $CPU_CORES"
echo "   - 总内存: ${TOTAL_MEM_GB}GB"
echo "   - 内核版本: $KERNEL_VERSION"
echo "   - 主网络接口: ${MAIN_INTERFACE:-未检测到}"

# CPU频率检测
if command -v cpupower >/dev/null 2>&1; then
    CURRENT_GOV=$(cpupower frequency-info | grep "current policy" | head -1 | awk '{print $NF}')
    CURRENT_FREQ=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}')
    echo "   - 当前CPU调速器: $CURRENT_GOV"
    echo "   - 当前CPU频率: ${CURRENT_FREQ}MHz"
else
    echo "   - CPU频率工具: 需要安装cpupower"
fi

echo ""

# 1. CPU性能优化
echo "⚡ 1. CPU性能优化..."
if command -v cpupower >/dev/null 2>&1; then
    cpupower frequency-set -g performance >/dev/null 2>&1
    sleep 1
    NEW_GOV=$(cpupower frequency-info | grep "current policy" | head -1 | awk '{print $NF}')
    echo "   ✅ CPU调速器: $CURRENT_GOV -> $NEW_GOV"
    
    # 启用Turbo Boost（如果支持）
    if [ -f "/sys/devices/system/cpu/intel_pstate/no_turbo" ]; then
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
        echo "   ✅ 启用Intel Turbo Boost"
    fi
else
    echo "   ⚠️  cpupower未安装，建议安装: apt install linux-tools-$(uname -r)"
fi

# 2. 内存优化
echo ""
echo "💾 2. 内存优化..."

# 智能计算大页内存（总内存的8-15%）
if [ "$TOTAL_MEM_GB" -ge 32 ]; then
    HUGEPAGES=2048  # 32GB+机器使用4GB大页
elif [ "$TOTAL_MEM_GB" -ge 16 ]; then
    HUGEPAGES=1536  # 16-32GB机器使用3GB大页
elif [ "$TOTAL_MEM_GB" -ge 8 ]; then
    HUGEPAGES=1024  # 8-16GB机器使用2GB大页
else
    HUGEPAGES=512   # 8GB以下机器使用1GB大页
fi

echo "   智能配置大页内存: ${HUGEPAGES}页 ($(($HUGEPAGES * 2))MB)"

# 应用内存优化
sysctl -w vm.nr_hugepages=$HUGEPAGES >/dev/null 2>&1
sysctl -w vm.swappiness=1 >/dev/null 2>&1
sysctl -w vm.zone_reclaim_mode=0 >/dev/null 2>&1
sysctl -w vm.dirty_background_ratio=5 >/dev/null 2>&1
sysctl -w vm.dirty_ratio=10 >/dev/null 2>&1

# 透明大页
if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    echo "   ✅ 透明大页: 启用"
fi

echo "   ✅ 内存优化完成"

# 3. 网络优化
echo ""
echo "🌐 3. 网络优化..."

# 核心网络参数
sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1
sysctl -w net.core.netdev_budget_usecs=2000 >/dev/null 2>&1
sysctl -w net.ipv4.udp_early_demux=1 >/dev/null 2>&1
sysctl -w net.ipv4.ip_local_port_range="32768 65000" >/dev/null 2>&1

echo "   ✅ 网络栈参数优化完成"

# 网络接口优化
if [ -n "$MAIN_INTERFACE" ] && command -v ethtool >/dev/null 2>&1; then
    # 获取当前Ring Buffer
    RX_CURRENT=$(ethtool -g $MAIN_INTERFACE 2>/dev/null | grep -A1 "^RX:" | tail -1 | awk '{print $2}')
    TX_CURRENT=$(ethtool -g $MAIN_INTERFACE 2>/dev/null | grep -A1 "^TX:" | tail -1 | awk '{print $2}')
    
    if [ -n "$RX_CURRENT" ] && [ "$RX_CURRENT" -gt 0 ]; then
        # 智能设置Ring Buffer（优先2048，高端机器4096）
        TARGET_RING=$((TOTAL_MEM_GB >= 16 ? 4096 : 2048))
        
        if [ "$RX_CURRENT" -lt "$TARGET_RING" ]; then
            ethtool -G $MAIN_INTERFACE rx $TARGET_RING tx $TARGET_RING 2>/dev/null && \
                echo "   ✅ Ring Buffer优化: $TARGET_RING" || \
                echo "   ℹ️  Ring Buffer调整失败或已最优"
        else
            echo "   ✅ Ring Buffer已是最优: $RX_CURRENT"
        fi
        
        # 禁用网络卸载特性（降低延迟）
        ethtool -K $MAIN_INTERFACE tso off gso off gro off lro off 2>/dev/null && \
            echo "   ✅ 网络卸载特性已禁用" || \
            echo "   ℹ️  网络卸载特性不支持调整"
    fi
fi

# 4. CPU调度器优化
echo ""
echo "🔄 4. CPU调度器优化..."
sysctl -w kernel.sched_migration_cost_ns=5000000 >/dev/null 2>&1
sysctl -w kernel.sched_min_granularity_ns=10000000 >/dev/null 2>&1
sysctl -w kernel.sched_wakeup_granularity_ns=15000000 >/dev/null 2>&1
echo "   ✅ 调度器参数已优化"

# 5. 中断平衡
echo ""
echo "⚖️ 5. 中断平衡优化..."
if systemctl is-active --quiet irqbalance 2>/dev/null; then
    systemctl stop irqbalance 2>/dev/null
    systemctl disable irqbalance 2>/dev/null
    echo "   ✅ 自动中断平衡已禁用"
else
    echo "   ℹ️  中断平衡服务未运行"
fi

# 6. 验证结果
echo ""
echo "🔍 优化结果验证..."
FINAL_GOV=$(cpupower frequency-info 2>/dev/null | grep "current policy" | head -1 | awk '{print $NF}' || echo "N/A")
FINAL_FREQ=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}' || echo "N/A")
HUGEPAGES_SET=$(sysctl -n vm.nr_hugepages 2>/dev/null)
SWAPPINESS=$(sysctl -n vm.swappiness 2>/dev/null)

echo "   CPU调速器: $FINAL_GOV"
echo "   CPU频率: ${FINAL_FREQ}MHz"
echo "   大页内存: ${HUGEPAGES_SET}页 ($(($HUGEPAGES_SET * 2))MB)"
echo "   内存交换倾向: ${SWAPPINESS}%"

echo ""
echo "✅ 系统优化完成!"
echo ""
echo "📋 优化摘要:"
echo "   🎯 CPU调速器设置为performance模式"
echo "   💾 智能配置大页内存: $(($HUGEPAGES_SET * 2))MB"
echo "   🌐 网络栈UDP优化，Ring Buffer优化"
echo "   🔄 CPU调度器参数调优"
echo "   ⚖️ 禁用自动中断平衡"
echo ""
echo "🔧 推荐的Aeron JVM参数:"
# 智能推荐JVM堆大小
if [ "$TOTAL_MEM_GB" -ge 32 ]; then
    RECOMMENDED_HEAP="4g"
elif [ "$TOTAL_MEM_GB" -ge 16 ]; then
    RECOMMENDED_HEAP="3g"
elif [ "$TOTAL_MEM_GB" -ge 8 ]; then
    RECOMMENDED_HEAP="2g"
else
    RECOMMENDED_HEAP="1g"
fi

cat << EOF
   -Xms${RECOMMENDED_HEAP} -Xmx${RECOMMENDED_HEAP}
   -XX:+UseG1GC -XX:MaxGCPauseMillis=1
   -XX:+UseLargePages -XX:+AlwaysPreTouch
   -Daeron.threading.mode=DEDICATED
   -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy
   -Daeron.socket.so_sndbuf=2097152
   -Daeron.socket.so_rcvbuf=2097152

EOF

echo "⚠️  重要提醒:"
echo "   - 重启后建议重新运行此脚本"
echo "   - 适用于X1、X2或任何Linux机器"
echo "   - 根据实际硬件自动调整参数"
echo ""
