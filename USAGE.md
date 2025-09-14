# Xsyphon Aeron Forex 测试工具使用说明

## 📦 JAR文件信息
- **文件名**: `xsyphon-aeron-forex.jar`
- **大小**: ~3.2MB
- **位置**: `aeron-beginning/target/xsyphon-aeron-forex.jar`

## 🚀 可执行类列表

### 1. 简单外汇测试 (字符串消息)
```bash
# 发布者 (默认主类)
java -jar xsyphon-aeron-forex.jar

# 订阅者
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.SimpleForexSubscriber
```

### 2. 字符串性能测试
```bash
# 发布者
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.AeronPerformancePublisher

# 订阅者
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.AeronPerformanceSubscriber
```

### 3. 二进制性能测试 (推荐用于高频交易)
```bash
# 发布者 - 基本使用
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher

# 发布者 - 自定义参数
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher \
  -size 128 -count 2000000 -warmup 200000

# 订阅者
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber
```

## ⚙️ 二进制性能测试参数说明

### BinaryPerformancePublisher 参数
- `-size <bytes>`: 消息大小，最小8字节 (默认: 64)
- `-count <num>`: 测试消息数量 (默认: 1,000,000)
- `-warmup <num>`: 预热消息数量 (默认: 100,000)
- `-help`: 显示帮助信息

### 消息格式
- **前8字节**: 大端序纳秒时间戳
- **后续字节**: 0-255循环填充模式

## 🏁 完整测试流程示例

### 场景1: 基本外汇功能测试
```bash
# 终端1: 启动订阅者
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.SimpleForexSubscriber

# 终端2: 启动发布者
java -jar xsyphon-aeron-forex.jar
```

### 场景2: 高性能二进制测试
```bash
# 终端1: 启动订阅者
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber

# 终端2: 启动发布者 (自定义大消息测试)
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher \
  -size 256 -count 5000000 -warmup 500000
```

## 📊 性能基准参考

### 预期性能指标 (基于之前测试)
- **吞吐量**: 1.25M+ msg/sec
- **延迟**: < 1μs 平均延迟
- **适用场景**: 超高频外汇交易

### 外汇交易适用性评估
- **< 1μs**: 🚀 超低延迟 - 完美适合超高频交易
- **< 10μs**: ⚡ 优秀 - 适合高频交易
- **< 50μs**: ✅ 良好 - 适合中频交易
- **> 50μs**: ⚠️ 需要优化配置

## 🔧 前置要求

### MediaDriver
确保MediaDriver正在运行:
```bash
# 检查MediaDriver状态
ps aux | grep MediaDriver

# 如果需要，启动独立MediaDriver
java -cp xsyphon-aeron-forex.jar io.aeron.driver.MediaDriver
```

### 系统优化 (Linux生产环境)
```bash
# 网络缓冲区优化
sudo sysctl -w net.core.rmem_max=2097152
sudo sysctl -w net.core.wmem_max=2097152

# 使用RAM磁盘
sudo mkdir -p /dev/shm/aeron
```

## 🎯 常见用法

### 快速验证连通性
```bash
java -jar xsyphon-aeron-forex.jar &
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.SimpleForexSubscriber
```

### 性能基准测试
```bash
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber &
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher -size 64 -count 1000000
```

### 大消息吞吐量测试
```bash
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformanceSubscriber &
java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher -size 1024 -count 500000
```

## ✅ 成功解决的问题

1. ✅ **统一JAR打包**: 只生成 `xsyphon-aeron-forex.jar`
2. ✅ **多主类支持**: 6个可执行类都可独立运行
3. ✅ **参数化配置**: 二进制测试支持消息大小和数量配置
4. ✅ **二进制格式优化**: 8字节时间戳 + 循环填充模式
5. ✅ **性能统计**: 详细的延迟和吞吐量报告
