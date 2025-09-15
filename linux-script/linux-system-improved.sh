#!/bin/bash
# linux-system-improved.sh
# 
# 🚀 改进版系统优化脚本 - 支持不同机器配置

echo "🚀 开始Linux UDP系统优化..."
echo "自动检测系统配置并应用优化"
echo ""

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 此脚本需要root权限执行"
    echo "请使用: sudo $0"
    exit 1
fi

# 系统信息检测
echo "📊 检测系统配置..."
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
KERNEL_VERSION=$(uname -r)
OS_VERSION=$(lsb_release -d 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")

echo "   - CPU核心数: $CPU_CORES"
echo "   - 总内存: $TOTAL_MEM"
echo "   - 内核版本: $KERNEL_VERSION"
echo "   - 操作系统: $OS_VERSION"

# 检测当前CPU频率
if command -v cpupower >/dev/null 2>&1; then
    CURRENT_GOV=$(cpupower frequency-info | grep "current policy" | head -1 | awk '{print $NF}')
    CURRENT_FREQ=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}')
    MAX_FREQ=$(cpupower frequency-info | grep "hardware limits" | head -1 | awk '{print $(NF-1)}')
    echo "   - 当前CPU调速器: $CURRENT_GOV"
    echo "   - 当前CPU频率: ${CURRENT_FREQ}MHz"
    echo "   - 最大CPU频率: ${MAX_FREQ}MHz"
else
    echo "   - CPU频率信息: 需要安装cpupower工具"
fi

# 检测主网络接口
MAIN_INTERFACE=$(ip route | grep default | head -1 | awk '{print $5}')
if [ -n "$MAIN_INTERFACE" ]; then
    echo "   - 主网络接口: $MAIN_INTERFACE"
else
    echo "   - 主网络接口: 自动检测失败"
fi

echo ""

# 1. CPU频率优化 (关键!)
echo "⚡ 1. CPU频率优化..."
if command -v cpupower >/dev/null 2>&1; then
    echo "   设置CPU为性能模式..."
    cpupower frequency-set -g performance
    
    # 等待设置生效
    sleep 2
    
    # 验证设置
    NEW_GOV=$(cpupower frequency-info | grep "current policy" | head -1 | awk '{print $NF}')
    NEW_FREQ=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}')
    
    echo "   ✅ CPU调速器: $CURRENT_GOV -> $NEW_GOV"
    echo "   ✅ CPU频率变化: ${CURRENT_FREQ}MHz -> ${NEW_FREQ}MHz"
    
    # 检查是否需要禁用CPU节能功能
    if [ -f "/sys/devices/system/cpu/intel_pstate/no_turbo" ]; then
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
        echo "   ✅ 启用Intel Turbo Boost"
    fi
    
    # 设置CPU最小频率等于最大频率（强制最高性能）
    if [ -n "$MAX_FREQ" ] && [ "$MAX_FREQ" != "asserted" ]; then
        cpupower frequency-set -d ${MAX_FREQ}MHz -u ${MAX_FREQ}MHz 2>/dev/null
        echo "   ✅ 强制CPU运行在最高频率: ${MAX_FREQ}MHz"
    fi
else
    echo "   ⚠️  cpupower未安装，跳过CPU频率优化"
    echo "   建议安装: apt install linux-tools-$(uname -r) linux-tools-generic"
fi

# 2. 透明大页优化
echo ""
echo "📄 2. 透明大页优化..."
if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then
    CURRENT_THP=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    NEW_THP=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
    echo "   ✅ 透明大页: $CURRENT_THP -> $NEW_THP"
    
    # 设置透明大页碎片整理
    if [ -f "/sys/kernel/mm/transparent_hugepage/defrag" ]; then
        echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag
        echo "   ✅ 透明大页碎片整理: defer+madvise"
    fi
else
    echo "   ⚠️  透明大页不可用"
fi

# 3. CPU调度器优化
echo ""
echo "🔄 3. CPU调度器优化..."
declare -A SCHED_PARAMS=(
    ["kernel.sched_migration_cost_ns"]="5000000"
    ["kernel.sched_min_granularity_ns"]="10000000"
    ["kernel.sched_wakeup_granularity_ns"]="15000000"
    ["kernel.sched_rt_period_us"]="1000000"
    ["kernel.sched_rt_runtime_us"]="950000"
)

for param in "${!SCHED_PARAMS[@]}"; do
    OLD_VAL=$(sysctl -n $param 2>/dev/null)
    sysctl -w $param=${SCHED_PARAMS[$param]} >/dev/null 2>&1
    NEW_VAL=$(sysctl -n $param 2>/dev/null)
    echo "   ✅ $param: $OLD_VAL -> $NEW_VAL"
done

# 4. 网络栈优化
echo ""
echo "🌐 4. 网络栈优化..."
declare -A NET_PARAMS=(
    ["net.core.netdev_budget_usecs"]="2000"
    ["net.core.netdev_tstamp_prequeue"]="0"
    ["net.ipv4.udp_early_demux"]="1"
    ["net.ipv4.ip_local_port_range"]="32768 65000"
    ["net.core.rmem_default"]="262144"
    ["net.core.rmem_max"]="16777216"
    ["net.core.wmem_default"]="262144"
    ["net.core.wmem_max"]="16777216"
)

for param in "${!NET_PARAMS[@]}"; do
    OLD_VAL=$(sysctl -n $param 2>/dev/null)
    sysctl -w $param="${NET_PARAMS[$param]}" >/dev/null 2>&1
    NEW_VAL=$(sysctl -n $param 2>/dev/null)
    echo "   ✅ $param: $OLD_VAL -> $NEW_VAL"
done

# 尝试设置tcp_low_latency（某些内核版本不支持）
if sysctl net.ipv4.tcp_low_latency >/dev/null 2>&1; then
    sysctl -w net.ipv4.tcp_low_latency=1 >/dev/null 2>&1
    echo "   ✅ net.ipv4.tcp_low_latency: 1"
else
    echo "   ℹ️  tcp_low_latency参数不支持（内核版本较新）"
fi

# 5. 内存管理优化
echo ""
echo "💾 5. 内存管理优化..."

# 智能计算大页内存数量（基于总内存的10%，但不超过4GB）
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
SUGGESTED_HUGEPAGES=$((TOTAL_MEM_GB * 1024 / 10))  # 10%的内存作为大页
SUGGESTED_HUGEPAGES=$((SUGGESTED_HUGEPAGES > 2048 ? 2048 : SUGGESTED_HUGEPAGES))  # 最多2048页(4GB)
SUGGESTED_HUGEPAGES=$((SUGGESTED_HUGEPAGES < 512 ? 512 : SUGGESTED_HUGEPAGES))   # 最少512页(1GB)

echo "   检测到总内存: ${TOTAL_MEM_GB}GB"
echo "   建议大页内存: ${SUGGESTED_HUGEPAGES}页 ($(($SUGGESTED_HUGEPAGES * 2))MB)"

declare -A MEM_PARAMS=(
    ["vm.swappiness"]="1"
    ["vm.zone_reclaim_mode"]="0"
    ["vm.dirty_background_ratio"]="5"
    ["vm.dirty_ratio"]="10"
    ["vm.compaction_proactiveness"]="0"
    ["vm.nr_hugepages"]="$SUGGESTED_HUGEPAGES"
)

for param in "${!MEM_PARAMS[@]}"; do
    OLD_VAL=$(sysctl -n $param 2>/dev/null)
    sysctl -w $param=${MEM_PARAMS[$param]} >/dev/null 2>&1
    NEW_VAL=$(sysctl -n $param 2>/dev/null)
    echo "   ✅ $param: $OLD_VAL -> $NEW_VAL"
done

# 6. 网络接口队列优化
echo ""
echo "📡 6. 网络接口队列优化..."
if [ -n "$MAIN_INTERFACE" ] && [ -d "/sys/class/net/$MAIN_INTERFACE" ]; then
    # 检查队列数量
    RX_QUEUES=$(find /sys/class/net/$MAIN_INTERFACE/queues/ -name "rx-*" 2>/dev/null | wc -l)
    TX_QUEUES=$(find /sys/class/net/$MAIN_INTERFACE/queues/ -name "tx-*" 2>/dev/null | wc -l)
    
    echo "   网络接口: $MAIN_INTERFACE"
    echo "   RX队列数: $RX_QUEUES"
    echo "   TX队列数: $TX_QUEUES"
    
    # 尝试优化网络接口参数
    if command -v ethtool >/dev/null 2>&1; then
        # 获取当前ring buffer大小
        RX_RING=$(ethtool -g $MAIN_INTERFACE 2>/dev/null | grep -A1 "^RX:" | tail -1 | awk '{print $2}')
        TX_RING=$(ethtool -g $MAIN_INTERFACE 2>/dev/null | grep -A1 "^TX:" | tail -1 | awk '{print $2}')
        
        if [ -n "$RX_RING" ] && [ "$RX_RING" -gt 0 ]; then
            echo "   当前RX Ring Buffer: $RX_RING"
            echo "   当前TX Ring Buffer: $TX_RING"
            
            # 智能设置Ring Buffer大小（基于当前值和队列数）
            OPTIMAL_RX=$((RX_QUEUES > 1 ? 4096 : 2048))
            OPTIMAL_TX=$((TX_QUEUES > 1 ? 4096 : 2048))
            
            # 只有当前值小于建议值时才调整
            if [ "$RX_RING" -lt "$OPTIMAL_RX" ] || [ "$TX_RING" -lt "$OPTIMAL_TX" ]; then
                ethtool -G $MAIN_INTERFACE rx $OPTIMAL_RX tx $OPTIMAL_TX 2>/dev/null && \
                    echo "   ✅ Ring Buffer优化: RX=$OPTIMAL_RX, TX=$OPTIMAL_TX" || \
                    echo "   ℹ️  Ring Buffer已是最优值或不支持调整"
            else
                echo "   ✅ Ring Buffer已是最优配置"
            fi
        fi
        
        # 禁用不必要的网络特性以降低延迟
        ethtool -K $MAIN_INTERFACE tso off gso off gro off lro off 2>/dev/null && \
            echo "   ✅ 禁用TCP分段卸载以降低延迟" || \
            echo "   ℹ️  网络卸载特性不支持调整"
    else
        echo "   ⚠️  ethtool未安装，无法优化网络接口"
    fi
else
    echo "   ⚠️  无法检测到有效的网络接口"
fi

# 7. 中断平衡优化
echo ""
echo "⚖️ 7. 中断平衡优化..."
if command -v irqbalance >/dev/null 2>&1; then
    # 停止irqbalance服务以手动控制中断
    systemctl stop irqbalance 2>/dev/null
    systemctl disable irqbalance 2>/dev/null
    echo "   ✅ 已停用自动中断平衡服务"
    echo "   ℹ️  建议手动将网络中断绑定到特定CPU"
else
    echo "   ℹ️  irqbalance服务未安装"
fi

# 8. 验证优化结果
echo ""
echo "🔍 8. 验证优化结果..."

# CPU信息
FINAL_GOV=$(cpupower frequency-info 2>/dev/null | grep "current policy" | head -1 | awk '{print $NF}' || echo "N/A")
FINAL_FREQ=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}' || echo "N/A")
echo "   CPU调速器: $FINAL_GOV"
echo "   CPU频率: ${FINAL_FREQ}MHz"

# 内存信息
THP_STATUS=$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo "N/A")
SWAPPINESS=$(sysctl -n vm.swappiness 2>/dev/null || echo "N/A")
echo "   透明大页: $THP_STATUS"
echo "   内存交换倾向: ${SWAPPINESS}%"

# 网络信息
NETDEV_BUDGET=$(sysctl -n net.core.netdev_budget_usecs 2>/dev/null || echo "N/A")
UDP_DEMUX=$(sysctl -n net.ipv4.udp_early_demux 2>/dev/null || echo "N/A")
echo "   网络设备预算: ${NETDEV_BUDGET}μs"
echo "   UDP早期解复用: $UDP_DEMUX"

echo ""
echo "✅ 通用系统优化完成!"
echo ""
echo "📋 优化摘要:"
echo "   🎯 CPU频率优化 - 设置为最大性能模式"
echo "   📄 透明大页优化 - 启用always模式"
echo "   🔄 CPU调度器优化 - 降低迁移成本，提高响应速度"
echo "   🌐 网络栈优化 - UDP专用优化，增大缓冲区"
echo "   💾 内存管理优化 - 智能大页内存配置，最小化swap"
echo "   📡 网络接口优化 - 智能Ring Buffer和卸载特性优化"
echo "   ⚖️ 中断平衡优化 - 禁用自动平衡，支持手动绑定"
echo ""
echo "🔧 建议的JVM参数（基于当前系统）:"
JVM_HEAP_SIZE=$((TOTAL_MEM_GB > 8 ? 4 : 2))
echo "   -Xms${JVM_HEAP_SIZE}g -Xmx${JVM_HEAP_SIZE}g"
echo "   -XX:+UseG1GC -XX:MaxGCPauseMillis=1"
echo "   -XX:+UseLargePages -XX:+AlwaysPreTouch"
echo "   -Daeron.threading.mode=DEDICATED"
echo ""
echo "⚠️  重要提醒:"
echo "   - 建议重启后运行此脚本以确保所有设置生效"
echo "   - 某些优化在不同硬件上效果可能不同"
echo "   - 建议在测试环境中验证性能提升"
echo ""
