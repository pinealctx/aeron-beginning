#!/bin/bash
# machine-specific-config.sh
# 
# 🖥️ 机器特定配置 - 处理X1和X2机器的差异

# 检测机器类型的函数
detect_machine_type() {
    local hostname=$(hostname)
    local cpu_model=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(nproc)
    local max_freq=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}')
    
    echo "检测到的系统信息:"
    echo "  主机名: $hostname"
    echo "  CPU型号: $cpu_model"
    echo "  CPU核心: $cpu_cores"
    echo "  当前频率: ${max_freq}MHz"
    
    # 根据CPU特征判断机器类型
    if [[ "$cpu_model" == *"Intel"* ]]; then
        if [ "$cpu_cores" -ge 32 ]; then
            echo "X2"  # 高配置机器
        else
            echo "X1"  # 标准配置机器
        fi
    elif [[ "$cpu_model" == *"AMD"* ]]; then
        if [ "$cpu_cores" -ge 24 ]; then
            echo "X2"
        else
            echo "X1"
        fi
    else
        echo "UNKNOWN"
    fi
}

# X1机器配置（标准配置）
configure_x1_machine() {
    echo "🖥️ 配置X1机器（标准配置）..."
    
    # CPU频率目标较低，更注重稳定性
    export TARGET_CPU_FREQ="3000000"  # 3GHz
    export CPU_GOVERNOR="performance"
    
    # 内存配置
    export HUGEPAGES="512"  # 1GB大页内存
    export VM_SWAPPINESS="5"
    
    # 网络配置
    export NET_RX_RING="2048"
    export NET_TX_RING="2048"
    export NET_BUDGET_USECS="2000"
    
    # JVM配置建议
    export JVM_HEAP_SIZE="1g"
    export JVM_GC_STRATEGY="G1GC"
    
    echo "✅ X1机器配置完成"
}

# X2机器配置（高性能配置）
configure_x2_machine() {
    echo "🖥️ 配置X2机器（高性能配置）..."
    
    # CPU频率目标更高，追求极致性能
    export TARGET_CPU_FREQ="4300000"  # 4.3GHz
    export CPU_GOVERNOR="performance"
    
    # 内存配置
    export HUGEPAGES="2048"  # 4GB大页内存
    export VM_SWAPPINESS="1"
    
    # 网络配置
    export NET_RX_RING="4096"
    export NET_TX_RING="4096"
    export NET_BUDGET_USECS="1000"  # 更激进的网络预算
    
    # JVM配置建议
    export JVM_HEAP_SIZE="4g"
    export JVM_GC_STRATEGY="G1GC"
    
    echo "✅ X2机器配置完成"
}

# 应用机器特定的系统优化
apply_machine_specific_optimizations() {
    local machine_type=$1
    
    echo "🔧 应用${machine_type}机器特定优化..."
    
    # CPU频率设置
    if command -v cpupower >/dev/null 2>&1; then
        cpupower frequency-set -g $CPU_GOVERNOR
        if [ -n "$TARGET_CPU_FREQ" ]; then
            cpupower frequency-set -f ${TARGET_CPU_FREQ}kHz 2>/dev/null || true
        fi
        echo "  ✅ CPU频率优化完成"
    fi
    
    # 大页内存设置
    if [ -n "$HUGEPAGES" ]; then
        echo $HUGEPAGES > /proc/sys/vm/nr_hugepages
        echo "  ✅ 大页内存设置: ${HUGEPAGES}页"
    fi
    
    # 内存交换设置
    if [ -n "$VM_SWAPPINESS" ]; then
        sysctl -w vm.swappiness=$VM_SWAPPINESS >/dev/null
        echo "  ✅ 内存交换倾向: ${VM_SWAPPINESS}%"
    fi
    
    # 网络预算设置
    if [ -n "$NET_BUDGET_USECS" ]; then
        sysctl -w net.core.netdev_budget_usecs=$NET_BUDGET_USECS >/dev/null
        echo "  ✅ 网络设备预算: ${NET_BUDGET_USECS}μs"
    fi
    
    # 网络Ring Buffer设置
    local main_interface=$(ip route | grep default | head -1 | awk '{print $5}')
    if [ -n "$main_interface" ] && command -v ethtool >/dev/null 2>&1; then
        if [ -n "$NET_RX_RING" ] && [ -n "$NET_TX_RING" ]; then
            ethtool -G $main_interface rx $NET_RX_RING tx $NET_TX_RING 2>/dev/null && \
                echo "  ✅ 网络Ring Buffer: RX=${NET_RX_RING}, TX=${NET_TX_RING}" || \
                echo "  ⚠️ 网络Ring Buffer设置失败或不支持"
        fi
    fi
}

# 生成机器特定的JVM启动脚本
generate_jvm_script() {
    local machine_type=$1
    local script_name="aeron-optimized-${machine_type,,}.sh"
    
    cat > "$script_name" << EOF
#!/bin/bash
# Aeron优化启动脚本 - ${machine_type}机器专用
export AERON_DIR="/dev/shm/aeron"

# ${machine_type}机器JVM优化参数
JAVA_OPTS="-Xms${JVM_HEAP_SIZE} -Xmx${JVM_HEAP_SIZE}"
JAVA_OPTS="\$JAVA_OPTS -XX:+Use${JVM_GC_STRATEGY}"
JAVA_OPTS="\$JAVA_OPTS -XX:MaxGCPauseMillis=1"
JAVA_OPTS="\$JAVA_OPTS -XX:+UnlockExperimentalVMOptions"
JAVA_OPTS="\$JAVA_OPTS -XX:+UseLargePages"
JAVA_OPTS="\$JAVA_OPTS -XX:+AlwaysPreTouch"
JAVA_OPTS="\$JAVA_OPTS -XX:+DisableExplicitGC"

# Aeron特定优化
JAVA_OPTS="\$JAVA_OPTS -Daeron.dir=\$AERON_DIR"
JAVA_OPTS="\$JAVA_OPTS -Daeron.threading.mode=DEDICATED"
JAVA_OPTS="\$JAVA_OPTS -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy"
EOF

    if [ "$machine_type" = "X2" ]; then
        cat >> "$script_name" << EOF

# X2机器额外优化
JAVA_OPTS="\$JAVA_OPTS -Daeron.socket.so_sndbuf=4194304"
JAVA_OPTS="\$JAVA_OPTS -Daeron.socket.so_rcvbuf=4194304"
JAVA_OPTS="\$JAVA_OPTS -Daeron.mtu.length=8192"
JAVA_OPTS="\$JAVA_OPTS -Daeron.term.buffer.length=4194304"
EOF
    else
        cat >> "$script_name" << EOF

# X1机器稳定性优化
JAVA_OPTS="\$JAVA_OPTS -Daeron.socket.so_sndbuf=2097152"
JAVA_OPTS="\$JAVA_OPTS -Daeron.socket.so_rcvbuf=2097152"
JAVA_OPTS="\$JAVA_OPTS -Daeron.mtu.length=4096"
JAVA_OPTS="\$JAVA_OPTS -Daeron.term.buffer.length=2097152"
EOF
    fi
    
    cat >> "$script_name" << EOF

echo "🚀 启动${machine_type}机器优化的Aeron应用..."
echo "JVM参数: \$JAVA_OPTS"
echo ""

# 示例：启动Publisher
# java \$JAVA_OPTS -cp your-app.jar com.xsyphon.aeron.BinaryPerformancePublisher "\$@"

# 示例：启动Subscriber  
# java \$JAVA_OPTS -cp your-app.jar com.xsyphon.aeron.BinaryPerformanceSubscriber "\$@"
EOF
    
    chmod +x "$script_name"
    echo "✅ 生成${machine_type}机器专用脚本: $script_name"
}

# 主函数
main() {
    echo "🖥️ 机器特定配置检测和优化工具"
    echo ""
    
    # 检测机器类型
    local machine_type=$(detect_machine_type)
    echo ""
    echo "检测到机器类型: $machine_type"
    echo ""
    
    # 应用对应配置
    case $machine_type in
        "X1")
            configure_x1_machine
            ;;
        "X2")
            configure_x2_machine
            ;;
        "UNKNOWN")
            echo "⚠️ 无法确定机器类型，使用默认配置"
            configure_x1_machine  # 使用保守配置
            ;;
    esac
    
    # 如果有root权限，应用系统级优化
    if [ "$EUID" -eq 0 ]; then
        apply_machine_specific_optimizations $machine_type
    else
        echo "ℹ️ 非root权限，跳过系统级优化"
        echo "如需系统级优化，请使用: sudo $0"
    fi
    
    # 生成JVM启动脚本
    generate_jvm_script $machine_type
    
    echo ""
    echo "📋 ${machine_type}机器配置摘要:"
    echo "  目标CPU频率: $([ -n "$TARGET_CPU_FREQ" ] && echo "${TARGET_CPU_FREQ}kHz" || echo "默认")"
    echo "  大页内存: $([ -n "$HUGEPAGES" ] && echo "${HUGEPAGES}页" || echo "默认")"
    echo "  JVM堆大小: $JVM_HEAP_SIZE"
    echo "  网络Ring Buffer: RX=${NET_RX_RING}, TX=${NET_TX_RING}"
    echo ""
    echo "✅ 机器特定配置完成!"
}

# 运行主函数
main "$@"
