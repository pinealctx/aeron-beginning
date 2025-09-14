#!/bin/bash
# optimized-test-suite.sh
#
# 🚀 Aeron高频交易完整测试套件 - 优化版
# 自动执行系统优化、MediaDriver启动、性能测试

echo "🚀 Aeron高频交易完整测试套件 - 优化版"
echo "========================================"
echo ""

# 默认测试参数
MESSAGE_COUNT=2000000
MESSAGE_SIZE=64
WARMUP_TIME=5

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -count)
            MESSAGE_COUNT="$2"
            shift 2
            ;;
        -size)
            MESSAGE_SIZE="$2"
            shift 2
            ;;
        -warmup)
            WARMUP_TIME="$2"
            shift 2
            ;;
        -help|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -count <数量>    测试消息数量 (默认: 2000000)"
            echo "  -size <大小>     消息大小 (默认: 64)"
            echo "  -warmup <秒>     系统预热时间 (默认: 5)"
            echo "  -help           显示此帮助"
            echo ""
            echo "示例:"
            echo "  $0 -count 5000000 -size 128"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 -help 查看帮助"
            exit 1
            ;;
    esac
done

echo "📋 测试配置:"
echo "   消息数量: $MESSAGE_COUNT"
echo "   消息大小: $MESSAGE_SIZE bytes"
echo "   预热时间: $WARMUP_TIME 秒"
echo ""

# 1. 检查系统优化
echo "🔧 1. 检查系统优化状态..."
if [ -f "/etc/sysctl.d/99-aeron-trading.conf" ]; then
    echo "   ✅ 系统优化配置已存在"
    
    # 检查当前网络配置
    CURRENT_RMEM=$(sysctl -n net.core.rmem_max)
    if [ "$CURRENT_RMEM" -ge "134217728" ]; then
        echo "   ✅ 网络缓冲区已优化: ${CURRENT_RMEM} bytes"
    else
        echo "   ⚠️  网络缓冲区需要优化，建议运行: sudo ./system-optimize.sh"
    fi
    
    # 检查大页内存
    HUGEPAGES=$(cat /proc/sys/vm/nr_hugepages 2>/dev/null || echo "0")
    if [ "$HUGEPAGES" -ge "1024" ]; then
        echo "   ✅ 大页内存已配置: $HUGEPAGES 页"
    else
        echo "   ⚠️  大页内存需要配置，建议运行: sudo ./system-optimize.sh"
    fi
else
    echo "   ⚠️  系统优化配置不存在"
    echo "   建议首次运行: sudo ./system-optimize.sh"
fi

echo ""

# 2. 停止现有进程
echo "🛑 2. 清理现有进程..."
./stop-mediadriver.sh
sleep 2

# 3. 启动优化版MediaDriver
echo "🚀 3. 启动优化版MediaDriver..."
./optimized-start-mediadriver.sh
sleep $WARMUP_TIME
echo "   ⏱️  预热完成 ($WARMUP_TIME 秒)"

# 4. 检查MediaDriver状态
echo ""
echo "🔍 4. 检查MediaDriver状态..."
MEDIADRIVER_PID=$(pgrep -f "io.aeron.driver.MediaDriver")
if [ -n "$MEDIADRIVER_PID" ]; then
    echo "   ✅ MediaDriver 运行中 (PID: $MEDIADRIVER_PID)"
    
    # 检查CPU亲和性
    AFFINITY=$(taskset -p $MEDIADRIVER_PID 2>/dev/null | cut -d: -f2 | tr -d ' ')
    echo "   📍 CPU亲和性: $AFFINITY"
    
    # 检查优先级
    PRIORITY=$(ps -o pid,ni -p $MEDIADRIVER_PID --no-headers | awk '{print $2}')
    echo "   🎯 进程优先级: $PRIORITY"
else
    echo "   ❌ MediaDriver 启动失败!"
    exit 1
fi

# 5. 启动订阅者
echo ""
echo "🔽 5. 启动优化版订阅者..."
./optimized-binary-performance-subscriber.sh &
SUBSCRIBER_PID=$!
sleep 3

# 6. 启动发布者并执行测试
echo ""
echo "🔼 6. 启动优化版发布者并执行测试..."
echo "⚡ 开始高频交易性能测试..."
echo ""

./optimized-binary-performance-publisher.sh -count $MESSAGE_COUNT -size $MESSAGE_SIZE

# 7. 等待测试完成并收集结果
echo ""
echo "⏳ 等待测试完成..."
sleep 5

# 8. 停止订阅者
echo ""
echo "🛑 8. 停止订阅者..."
if [ -n "$SUBSCRIBER_PID" ]; then
    kill $SUBSCRIBER_PID 2>/dev/null
fi

# 9. 生成测试报告
echo ""
echo "📊 9. 生成测试报告..."
echo "========================================"
echo "🎯 Aeron高频交易性能测试完成!"
echo ""
echo "📋 测试摘要:"
echo "   消息数量: $MESSAGE_COUNT"
echo "   消息大小: $MESSAGE_SIZE bytes"
echo "   总数据量: $(echo "scale=2; $MESSAGE_COUNT * $MESSAGE_SIZE / 1024 / 1024" | bc) MB"
echo ""
echo "🔧 系统优化状态:"
echo "   MediaDriver: 专用线程模式 + BusySpinIdleStrategy"
echo "   发布者: CPU核心1, 优先级-20"
echo "   订阅者: CPU核心2, 优先级-20"
echo "   网络缓冲区: 128MB"
echo "   大页内存: ${HUGEPAGES}页"
echo ""
echo "💡 如果延迟仍高于10μs，请检查:"
echo "   1. 网络硬件 (万兆网卡推荐)"
echo "   2. CPU性能 (高频率处理器推荐)" 
echo "   3. 内存延迟 (DDR4-3200+推荐)"
echo "   4. 操作系统配置 (实时内核推荐)"
echo ""
echo "🚀 测试完成! 结果详见上方统计数据。"
