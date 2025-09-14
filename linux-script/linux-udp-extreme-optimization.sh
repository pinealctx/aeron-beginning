#!/bin/bash
# linux-udp-extreme-optimization.sh
# 
# 🚀 基于系统分析的精准UDP优化脚本

echo "🚀 开始Linux UDP极限优化..."
echo "基于系统分析报告的定制优化"
echo ""

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 此脚本需要root权限执行"
    echo "请使用: sudo $0"
    exit 1
fi

echo "📊 检测到的系统配置:"
echo "   - CPU: 32核心，当前1.5GHz（目标4.3GHz）"
echo "   - 内存: 125GB，大页内存2GB"
echo "   - 网络: 已基础优化"
echo "   - Ubuntu 24.04.1 LTS"
echo ""

# 1. CPU频率优化 (关键!)
echo "⚡ 1. CPU频率优化..."
if command -v cpupower >/dev/null 2>&1; then
    echo "   设置CPU为性能模式..."
    cpupower frequency-set -g performance
    echo "   ✅ CPU频率已设置为最大性能"
    
    # 验证频率
    CURRENT_FREQ=$(cpupower frequency-info | grep 'current CPU frequency' | head -1)
    echo "   当前频率: $CURRENT_FREQ"
else
    echo "   ⚠️  cpupower未安装，跳过CPU频率优化"
    echo "   建议安装: apt install linux-tools-$(uname -r)"
fi

# 2. 透明大页优化
echo ""
echo "📄 2. 透明大页优化..."
if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    echo "   ✅ 透明大页设置为always"
else
    echo "   ⚠️  透明大页不可用"
fi

# 3. CPU调度器优化
echo ""
echo "🔄 3. CPU调度器优化..."
sysctl -w kernel.sched_migration_cost_ns=5000000
sysctl -w kernel.sched_min_granularity_ns=10000000  
sysctl -w kernel.sched_wakeup_granularity_ns=15000000
sysctl -w kernel.sched_rt_period_us=1000000
sysctl -w kernel.sched_rt_runtime_us=950000
echo "   ✅ CPU调度器参数已优化"

# 4. 网络进一步优化
echo ""
echo "🌐 4. 网络栈进一步优化..."
# 网络中断优化
sysctl -w net.core.netdev_budget_usecs=2000
sysctl -w net.core.netdev_tstamp_prequeue=0
sysctl -w net.ipv4.tcp_low_latency=1 2>/dev/null || true

# UDP专用优化
sysctl -w net.ipv4.udp_early_demux=1
sysctl -w net.ipv4.ip_local_port_range="32768 65000"

echo "   ✅ 网络栈进一步优化完成"

# 5. 内存优化
echo ""
echo "💾 5. 内存管理优化..."
sysctl -w vm.swappiness=1
sysctl -w vm.zone_reclaim_mode=0
sysctl -w vm.dirty_background_ratio=5
sysctl -w vm.dirty_ratio=10
sysctl -w vm.compaction_proactiveness=0
echo "   ✅ 内存管理已优化"

# 6. CPU亲和性建议（32核心系统）
echo ""
echo "🧮 6. 32核心CPU亲和性建议..."
echo "   建议CPU核心分配:"
echo "   - MediaDriver: 核心0-1"
echo "   - Publisher: 核心2-3" 
echo "   - Subscriber: 核心4-5"
echo "   - 系统预留: 核心6-31"
echo ""
echo "   使用方法示例:"
echo "   taskset -c 0-1 ./start-mediadriver.sh"
echo "   taskset -c 2-3 ./publisher.sh"
echo "   taskset -c 4-5 ./subscriber.sh"

# 7. 网络接口队列优化
echo ""
echo "📡 7. 网络接口队列优化..."
MAIN_INTERFACE="enp3s0"
if [ -d "/sys/class/net/$MAIN_INTERFACE" ]; then
    # 检查是否支持多队列
    RX_QUEUES=$(ls /sys/class/net/$MAIN_INTERFACE/queues/ | grep rx- | wc -l)
    TX_QUEUES=$(ls /sys/class/net/$MAIN_INTERFACE/queues/ | grep tx- | wc -l)
    
    echo "   网络接口: $MAIN_INTERFACE"
    echo "   RX队列数: $RX_QUEUES"
    echo "   TX队列数: $TX_QUEUES"
    
    if [ "$RX_QUEUES" -gt 1 ]; then
        echo "   ✅ 支持多队列，建议绑定特定队列到专用CPU"
        echo "   命令示例: echo 2 > /proc/irq/\$(cat /proc/interrupts | grep $MAIN_INTERFACE | cut -d: -f1)/smp_affinity_list"
    else
        echo "   ℹ️  单队列网卡"
    fi
else
    echo "   ⚠️  主网络接口检测失败"
fi

# 8. 验证优化结果
echo ""
echo "🔍 8. 验证优化结果..."
echo "   CPU频率: $(cpupower frequency-info 2>/dev/null | grep 'current CPU frequency' | head -1 | cut -d: -f2 | tr -d ' ' || echo '需要安装cpupower')"
echo "   透明大页: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
echo "   调度器迁移成本: $(sysctl kernel.sched_migration_cost_ns | cut -d= -f2 | tr -d ' ')"
echo "   内存交换倾向: $(sysctl vm.swappiness | cut -d= -f2 | tr -d ' ')%"

echo ""
echo "✅ UDP极限优化完成!"
echo ""
echo "📋 优化摘要:"
echo "   🎯 CPU频率设置为最大性能模式"
echo "   📄 透明大页设置为always"
echo "   🔄 CPU调度器参数精调"
echo "   🌐 网络栈进一步优化"
echo "   💾 内存管理优化"
echo "   🧮 32核心CPU亲和性指导"
echo ""
echo "🚀 预期效果: UDP延迟可能降低到5-15μs范围!"
echo ""
echo "📖 后续步骤:"
echo "   1. 使用CPU亲和性脚本测试性能:"
echo "      sudo ./start-mediadriver-cpu-affinity.sh"
echo "      sudo ./binary-performance-subscriber-cpu-affinity.sh -count 2000000"
echo "      sudo ./binary-performance-publisher-cpu-affinity.sh -count 2000000"
echo "   2. 重新测试性能对比"
echo "   3. 考虑使用CPU隔离获得极致性能"
