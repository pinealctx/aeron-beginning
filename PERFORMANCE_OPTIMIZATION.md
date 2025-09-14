# Aeron 高频交易性能优化方案

## 🔍 **当前性能分析**

### 实测结果
- **吞吐量**: 9M+ msg/sec ✅ (很好)
- **端到端延迟**: 1154μs ❌ (需要大幅优化)
- **最小延迟**: 1.65μs ⚠️ (有潜力，但不稳定)

### 与gRPC对比
你提到与gRPC/Go/Rust性能相近，这表明Aeron的优势没有体现出来。

## ⚡ **延迟优化策略**

### 1️⃣ **JVM优化**
```bash
# JVM参数优化
export JAVA_OPTS="
-XX:+UnlockExperimentalVMOptions
-XX:+UseG1GC
-XX:MaxGCPauseMillis=1
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:+UseLargePages
-XX:LargePageSizeInBytes=2M
-Xms4G -Xmx4G
-XX:+UseTransparentHugePages
"
```

### 2️⃣ **系统级优化**
```bash
# CPU亲和性
taskset -c 0,1 java ...

# 网络优化
sudo sysctl -w net.core.busy_read=50
sudo sysctl -w net.core.busy_poll=50
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728

# 禁用CPU频率缩放
sudo cpupower frequency-set -g performance
```

### 3️⃣ **Aeron配置优化**
```java
// 专用MediaDriver配置
MediaDriver.Context context = new MediaDriver.Context()
    .aeronDirectoryName("/dev/shm/aeron")
    .threadingMode(ThreadingMode.DEDICATED)
    .conductorIdleStrategy(new BusySpinIdleStrategy())
    .receiverIdleStrategy(new BusySpinIdleStrategy())
    .senderIdleStrategy(new BusySpinIdleStrategy());
```

### 4️⃣ **代码级优化**
```java
// 使用专用线程和CPU核心
Thread.currentThread().setPriority(Thread.MAX_PRIORITY);

// 消息批处理
final int batchSize = 256;
subscription.poll(messageHandler, batchSize);

// 预分配缓冲区
UnsafeBuffer buffer = new UnsafeBuffer(
    BufferUtil.allocateDirectAligned(messageSize, 64)
);
```

## 🔧 **具体优化实现**

### 优化版MediaDriver启动脚本
```bash
#!/bin/bash
# optimized-start-mediadriver.sh

# 设置CPU亲和性和优先级
sudo taskset -c 0 nice -n -20 java \\
    -Xms2G -Xmx2G \\
    -XX:+UseG1GC \\
    -XX:MaxGCPauseMillis=1 \\
    -XX:+UnlockExperimentalVMOptions \\
    -XX:+UseLargePages \\
    -Daeron.threading.mode=DEDICATED \\
    -Daeron.conductor.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \\
    -Daeron.receiver.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \\
    -Daeron.sender.idle.strategy=org.agrona.concurrent.BusySpinIdleStrategy \\
    -cp aeron-all-1.48.6.jar \\
    io.aeron.driver.MediaDriver
```

### 优化版应用启动
```bash
# 发布者绑定到CPU核心1
sudo taskset -c 1 nice -n -20 java \\
    -Xms1G -Xmx1G \\
    -XX:+UseG1GC \\
    -XX:MaxGCPauseMillis=1 \\
    -cp xsyphon-aeron-forex.jar \\
    com.xsyphon.aeron.BinaryPerformancePublisher

# 订阅者绑定到CPU核心2
sudo taskset -c 2 nice -n -20 java \\
    -Xms1G -Xmx1G \\
    -XX:+UseG1GC \\
    -XX:MaxGCPauseMillis=1 \\
    -cp xsyphon-aeron-forex.jar \\
    com.xsyphon.aeron.BinaryPerformanceSubscriber
```

## 🎯 **延迟目标**

### 现实期望
- **目标延迟**: < 10μs (99th percentile)
- **极限延迟**: < 1μs (专用硬件)
- **生产延迟**: < 50μs (可接受)

### 对比基准
- **原生UDP**: ~0.5μs
- **Aeron优化**: ~5-15μs
- **gRPC**: ~100-500μs
- **Kafka**: ~1-10ms

## 🔬 **诊断工具**

### 延迟分布分析
```java
// 添加延迟histogram
private static final long[] latencyHistogram = new long[1000];

// 记录延迟分布
int bucketIndex = (int) Math.min(latencyUs, 999);
latencyHistogram[bucketIndex]++;

// 输出P99, P99.9延迟
```

### 系统监控
```bash
# 监控网络延迟
sudo tcpdump -i lo -s 0 -w capture.pcap port 20121

# 监控CPU使用
top -p $(pgrep java)

# 监控内存分配
jstat -gc <java_pid> 1s
```

## 🚀 **预期优化效果**

实施这些优化后，预期能达到：
- **平均延迟**: 5-15μs
- **P99延迟**: < 50μs  
- **P99.9延迟**: < 100μs
- **吞吐量**: 保持或提升至15M+ msg/sec

这将使Aeron显著优于gRPC，体现其在高频交易中的真正价值。
