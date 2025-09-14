# 🚀 Aeron 订阅者脚本使用指南

## 📋 脚本概览

现在所有订阅者脚本都支持 `-count` 参数来指定目标消息数量！

| 脚本 | 优化级别 | CPU亲和性 | 适用场景 |
|------|----------|-----------|----------|
| `simple-binary-performance-subscriber.sh` | 基础 | 无 | 测试环境，无sudo权限 |
| `moderate-binary-performance-subscriber.sh` | 中等 | 无 | 生产环境，平衡性能与稳定性 |
| `optimized-binary-performance-subscriber.sh` | 最高 | 核心2 | 极致性能，需要sudo权限 |
| `performance-subscriber.sh` | 标准 | 无 | 基础性能测试 |

## 🎯 参数说明

### 通用参数
```bash
-count <数量>     # 目标消息数量 (默认: 20,000,000)
--count <数量>    # 同上
-h, --help       # 显示帮助信息
```

## 📊 使用示例

### 1. 快速测试 (100万条消息)
```bash
# 简化版 - 适合快速验证
./simple-binary-performance-subscriber.sh -count 1000000

# 中等优化版 - 推荐
./moderate-binary-performance-subscriber.sh -count 1000000

# 极致优化版 - 最高性能
./optimized-binary-performance-subscriber.sh -count 1000000
```

### 2. 标准测试 (1000万条消息)
```bash
# 中等优化版
./moderate-binary-performance-subscriber.sh -count 10000000

# 极致优化版
./optimized-binary-performance-subscriber.sh -count 10000000
```

### 3. 压力测试 (5000万条消息)
```bash
# 极致优化版 - 推荐用于大量数据测试
./optimized-binary-performance-subscriber.sh -count 50000000
```

### 4. 默认测试 (2000万条消息)
```bash
# 直接运行，使用默认值
./moderate-binary-performance-subscriber.sh
```

## 🔄 完整测试流程

### 方案A：标准测试流程
```bash
# 1. 启动MediaDriver
./moderate-start-mediadriver.sh

# 2. 启动订阅者 (1000万条消息)
./moderate-binary-performance-subscriber.sh -count 10000000

# 3. 在另一个终端启动发布者
./moderate-binary-performance-publisher.sh -count 10000000
```

### 方案B：极致性能测试
```bash
# 1. 启动优化MediaDriver
./optimized-start-mediadriver.sh

# 2. 启动优化订阅者
./optimized-binary-performance-subscriber.sh -count 20000000

# 3. 启动优化发布者
./optimized-binary-performance-publisher.sh -count 20000000
```

### 方案C：快速验证
```bash
# 一键快速测试 (100万条消息)
./quick-latency-test.sh
```

## 📈 性能基准

| 消息数量 | 预期用时 | 推荐脚本 | 用途 |
|----------|----------|----------|------|
| 100万 | ~0.1秒 | `quick-latency-test.sh` | 快速验证 |
| 1000万 | ~1秒 | `moderate-*` | 标准基准 |
| 2000万 | ~2秒 | `moderate-*` | 默认测试 |
| 5000万 | ~5秒 | `optimized-*` | 压力测试 |
| 1亿 | ~10秒 | `optimized-*` | 极限测试 |

## 🎯 选择建议

### 开发测试
- 使用 `simple-*` 脚本，无需特殊权限
- 测试1-10万条消息即可

### 性能基准
- 使用 `moderate-*` 脚本，平衡性能与稳定性
- 测试1000-2000万条消息

### 生产评估
- 使用 `optimized-*` 脚本，获得最佳性能
- 测试2000万-1亿条消息

### 故障排查
- 先用 `quick-latency-test.sh` 快速验证连通性
- 再用具体脚本定位问题

## 🔍 输出解读

所有脚本的订阅者都会在完成后显示：

```
=== 📊 最终性能统计报告 ===
总接收消息数: 10,000,000 条
消息大小: 64 bytes
测试总时长: 1.234 秒

📈 吞吐量性能:
  消息吞吐量: 8,103,728 msg/sec
  数据吞吐量: 494.45 MB/sec

⚡ 端到端延迟统计 (receiveTime - sendTime):
  平均延迟: 12.34 μs
  最小延迟: 2.10 μs
  最大延迟: 156.78 μs

⚡ 延迟评估: 优秀 (< 5μs) - 适合高频交易!
🚀 吞吐量评估: 卓越 (> 1000万/秒)!
```

这样你就可以根据具体需求选择合适的测试方案了！🎉
