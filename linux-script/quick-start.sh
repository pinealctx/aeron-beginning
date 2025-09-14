#!/bin/bash

# 🚀 Aeron Linux 快速启动脚本
# 自动化部署和测试流程

set -e  # 遇到错误立即退出

echo "🚀 Aeron Linux 生产环境快速启动..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 步骤计数器
STEP=1

print_step() {
    echo -e "\n${BLUE}[步骤 $STEP]${NC} $1"
    ((STEP++))
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查必要文件
print_step "检查部署文件"
required_files=(
    "xsyphon-aeron-forex.jar"
    "aeron-all-1.48.6.jar"
    "optimized-start-mediadriver.sh"
    "optimized-binary-performance-publisher.sh"
    "optimized-binary-performance-subscriber.sh"
    "system-optimize.sh"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    print_error "缺少必要文件："
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    echo ""
    echo "请确保以下文件在当前目录："
    echo "  1. xsyphon-aeron-forex.jar (主应用)"
    echo "  2. aeron-all-1.48.6.jar (Aeron库)"
    echo "  3. 所有 .sh 脚本文件"
    exit 1
fi

print_success "所有必要文件检查完毕"

# 设置执行权限
print_step "设置脚本执行权限"
chmod +x *.sh
print_success "权限设置完成"

# 检查是否为root或有sudo权限
print_step "检查系统权限"
if [[ $EUID -eq 0 ]]; then
    print_success "以root用户运行"
    SUDO=""
elif sudo -n true 2>/dev/null; then
    print_success "检测到sudo权限"
    SUDO="sudo"
else
    print_warning "无sudo权限，将跳过系统优化"
    print_warning "建议运行: sudo ./quick-start.sh"
    SUDO=""
fi

# 系统优化
if [[ -n "$SUDO" ]]; then
    print_step "运行系统优化"
    if $SUDO ./system-optimize.sh; then
        print_success "系统优化完成"
    else
        print_warning "系统优化失败，继续运行（性能可能受影响）"
    fi
else
    print_warning "跳过系统优化"
fi

# 清理旧的MediaDriver
print_step "清理旧的MediaDriver进程"
if pgrep -f "io.aeron.driver.MediaDriver" > /dev/null; then
    print_warning "发现运行中的MediaDriver，正在停止..."
    pkill -f "io.aeron.driver.MediaDriver" || true
    sleep 2
fi

# 清理共享内存
if [[ -d "/dev/shm/aeron" ]]; then
    print_warning "清理旧的共享内存文件..."
    rm -rf /dev/shm/aeron* || true
fi

print_success "环境清理完成"

# 检查Java版本
print_step "检查Java环境"
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n1 | cut -d'"' -f2)
    print_success "Java版本: $JAVA_VERSION"
else
    print_error "未找到Java，请安装Java 11+"
    exit 1
fi

# 启动MediaDriver
print_step "启动优化版MediaDriver"
echo "启动MediaDriver..."
if [[ -n "$SUDO" ]]; then
    nohup $SUDO ./optimized-start-mediadriver.sh > mediadriver.log 2>&1 &
else
    nohup ./start-mediadriver.sh > mediadriver.log 2>&1 &
fi

MEDIADRIVER_PID=$!
echo "MediaDriver PID: $MEDIADRIVER_PID"

# 等待MediaDriver启动
print_step "等待MediaDriver准备就绪"
for i in {1..30}; do
    if [[ -d "/dev/shm/aeron" ]]; then
        print_success "MediaDriver已启动"
        break
    fi
    echo -n "."
    sleep 1
done

if [[ ! -d "/dev/shm/aeron" ]]; then
    print_error "MediaDriver启动失败"
    echo "请检查mediadriver.log文件"
    exit 1
fi

# 性能测试选项
echo ""
echo -e "${BLUE}选择测试模式：${NC}"
echo "1. 快速测试 (100万条消息)"
echo "2. 标准测试 (200万条消息)"  
echo "3. 压力测试 (500万条消息)"
echo "4. 自定义测试"
echo "5. 手动模式（启动订阅者和发布者）"

read -p "请选择 (1-5): " choice

case $choice in
    1)
        MESSAGE_COUNT=1000000
        TEST_NAME="快速测试"
        ;;
    2)
        MESSAGE_COUNT=2000000
        TEST_NAME="标准测试"
        ;;
    3)
        MESSAGE_COUNT=5000000
        TEST_NAME="压力测试"
        ;;
    4)
        read -p "请输入消息数量: " MESSAGE_COUNT
        TEST_NAME="自定义测试"
        ;;
    5)
        print_step "手动模式"
        echo ""
        echo -e "${GREEN}MediaDriver已启动，现在可以手动运行：${NC}"
        echo ""
        echo "订阅者（在新终端运行）："
        if [[ -n "$SUDO" ]]; then
            echo "  $SUDO ./optimized-binary-performance-subscriber.sh"
        else
            echo "  ./binary-performance-subscriber.sh"
        fi
        echo ""
        echo "发布者（在另一个新终端运行）："
        if [[ -n "$SUDO" ]]; then
            echo "  $SUDO ./optimized-binary-performance-publisher.sh -count 2000000"
        else
            echo "  ./binary-performance-publisher.sh -count 2000000"
        fi
        echo ""
        echo "停止MediaDriver："
        echo "  ./stop-mediadriver.sh"
        echo ""
        print_success "手动模式准备完成"
        exit 0
        ;;
    *)
        print_error "无效选择"
        exit 1
        ;;
esac

# 自动化测试
print_step "启动 $TEST_NAME ($MESSAGE_COUNT 条消息)"

# 启动订阅者
echo "启动订阅者..."
if [[ -n "$SUDO" ]]; then
    nohup $SUDO ./optimized-binary-performance-subscriber.sh > subscriber.log 2>&1 &
else
    nohup ./binary-performance-subscriber.sh > subscriber.log 2>&1 &
fi

SUBSCRIBER_PID=$!
echo "订阅者 PID: $SUBSCRIBER_PID"

# 等待订阅者准备
sleep 3

# 启动发布者
echo "启动发布者..."
if [[ -n "$SUDO" ]]; then
    $SUDO ./optimized-binary-performance-publisher.sh -count $MESSAGE_COUNT
else
    ./binary-performance-publisher.sh -count $MESSAGE_COUNT
fi

# 等待测试完成
print_step "等待测试完成"
sleep 5

# 停止订阅者
echo "停止订阅者..."
kill $SUBSCRIBER_PID 2>/dev/null || true

# 显示结果
print_step "测试结果"
echo ""
echo -e "${GREEN}=== 发布者结果 ===${NC}"
tail -20 /dev/stdout 2>/dev/null || echo "请查看发布者终端输出"

echo ""
echo -e "${GREEN}=== 订阅者结果 ===${NC}"
tail -20 subscriber.log

# 性能分析
print_step "性能分析"
echo ""
if grep -q "平均延迟.*μs" subscriber.log; then
    AVG_LATENCY=$(grep "平均延迟" subscriber.log | tail -1 | grep -o '[0-9.]*' | head -1)
    if (( $(echo "$AVG_LATENCY < 10" | bc -l) )); then
        print_success "🚀 超低延迟 ($AVG_LATENCY μs) - 完美适合超高频交易!"
    elif (( $(echo "$AVG_LATENCY < 50" | bc -l) )); then
        print_success "⚡ 优秀延迟 ($AVG_LATENCY μs) - 适合高频交易!"
    elif (( $(echo "$AVG_LATENCY < 200" | bc -l) )); then
        print_warning "⚠️ 可接受延迟 ($AVG_LATENCY μs) - 需要进一步优化"
    else
        print_error "❌ 延迟过高 ($AVG_LATENCY μs) - 需要系统级优化"
    fi
fi

# 清理
print_step "清理环境"
echo "停止MediaDriver..."
./stop-mediadriver.sh

print_success "测试完成！"

echo ""
echo -e "${BLUE}下一步建议：${NC}"
echo "1. 查看完整日志: cat subscriber.log"
echo "2. 如需优化: 查看 PERFORMANCE_OPTIMIZATION.md"
echo "3. 生产部署: 查看 DEPLOYMENT_GUIDE.md"
echo "4. 重新测试: ./quick-start.sh"
