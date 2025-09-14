#!/bin/bash
# system-analysis.sh
# 
# 🔍 系统分析脚本 - 收集Linux优化所需信息

echo "🔍 Linux系统优化分析报告"
echo "=================================="
echo ""

echo "📊 1. 系统基本信息:"
echo "   内核版本: $(uname -r)"
echo "   发行版: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "   架构: $(uname -m)"
echo "   CPU核心数: $(nproc)"
echo ""

echo "🧠 2. CPU信息:"
lscpu | grep -E "(Model name|CPU MHz|Cache)"
echo ""

echo "💾 3. 内存信息:"
free -h
echo ""

echo "🌐 4. 当前网络参数:"
echo "   接收缓冲区最大值: $(sysctl net.core.rmem_max | cut -d= -f2 | tr -d ' ')"
echo "   发送缓冲区最大值: $(sysctl net.core.wmem_max | cut -d= -f2 | tr -d ' ')"
echo "   网络设备队列长度: $(sysctl net.core.netdev_max_backlog | cut -d= -f2 | tr -d ' ')"
echo "   繁忙轮询: $(sysctl net.core.busy_poll 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo '未设置')"
echo "   UDP内存: $(sysctl net.ipv4.udp_mem | cut -d= -f2 | tr -d ' ')"
echo ""

echo "🔧 5. 大页内存信息:"
if [ -f "/proc/meminfo" ]; then
    grep -E "HugePages|Hugepagesize" /proc/meminfo
else
    echo "   无法获取大页信息"
fi
echo ""

echo "⚖️ 6. 中断负载均衡:"
if systemctl is-active irqbalance >/dev/null 2>&1; then
    echo "   IRQ负载均衡: 启用 (可能影响延迟)"
else
    echo "   IRQ负载均衡: 禁用 (延迟友好)"
fi
echo ""

echo "🔄 7. CPU调度器参数:"
echo "   迁移成本: $(sysctl kernel.sched_migration_cost_ns 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo '默认')"
echo "   最小粒度: $(sysctl kernel.sched_min_granularity_ns 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo '默认')"
echo "   唤醒粒度: $(sysctl kernel.sched_wakeup_granularity_ns 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo '默认')"
echo ""

echo "🎯 8. CPU频率信息:"
if command -v cpupower >/dev/null 2>&1; then
    echo "   当前调速器: $(cpupower frequency-info | grep 'current policy' | cut -d: -f2 | tr -d ' ')"
    echo "   当前频率: $(cpupower frequency-info | grep 'current CPU frequency' | cut -d: -f2 | tr -d ' ')"
else
    echo "   cpupower未安装，无法获取频率信息"
fi
echo ""

echo "🌡️ 9. 当前系统负载:"
uptime
echo ""

echo "🔍 10. 网络接口信息:"
ip link show | grep -E "(^[0-9]+:|state UP)" | head -10
echo ""

echo "📈 11. 当前网络统计:"
if [ -f "/proc/net/snmp" ]; then
    echo "   UDP统计:"
    grep Udp: /proc/net/snmp | tail -1 | awk '{print "     接收包数: " $2 ", 发送包数: " $5 ", 错误数: " $4}'
fi
echo ""

echo "🎮 12. 透明大页状态:"
if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then
    echo "   透明大页: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
else
    echo "   透明大页: 不支持"
fi
echo ""

echo "⚡ 13. CPU空闲状态:"
if [ -d "/sys/devices/system/cpu/cpu0/cpuidle" ]; then
    echo "   CPU空闲状态数: $(find /sys/devices/system/cpu/cpu0/cpuidle -name "state*" | wc -l)"
    echo "   当前状态: $(find /sys/devices/system/cpu/cpu0/cpuidle/state*/disable -exec cat {} \; 2>/dev/null | head -5 | tr '\n' ' ')"
else
    echo "   CPU空闲状态: 不支持"
fi
echo ""

echo "🔍 分析完成！请将此报告提供给优化分析。"
