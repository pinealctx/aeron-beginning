# 🚀 Aeron 测试流程指南

## 🎯 三种测试场景

### 1️⃣ **基础测试** - 简单稳定
适合：初次测试、验证功能
```bash
# 终端1: 启动基础MediaDriver
./start-mediadriver.sh

# 终端2: 启动订阅者
./binary-performance-subscriber.sh -count 1000000

# 终端3: 启动发布者
./binary-performance-publisher.sh -count 1000000
```

### 2️⃣ **中等优化测试** - 平衡性能（推荐）
适合：日常性能测试、生产环境评估
```bash
# 终端1: 启动中等优化MediaDriver
./moderate-start-mediadriver.sh

# 终端2: 启动中等优化订阅者
./moderate-binary-performance-subscriber.sh -count 10000000

# 终端3: 启动中等优化发布者
./moderate-binary-performance-publisher.sh -count 10000000
```

### 3️⃣ **极致优化测试** - 最高性能
适合：性能极限测试、高频交易评估
```bash
# 终端1: 启动极致优化MediaDriver (需要sudo)
sudo ./optimized-start-mediadriver.sh

# 终端2: 启动极致优化订阅者 (需要sudo)
sudo ./optimized-binary-performance-subscriber.sh -count 20000000

# 终端3: 启动极致优化发布者 (需要sudo)
sudo ./optimized-binary-performance-publisher.sh -count 20000000
```

## 🔄 测试步骤

### 第一次测试建议：
1. **从基础测试开始**
2. **验证功能正常**
3. **然后尝试中等优化**
4. **最后测试极致优化**

### 每次测试流程：
1. 启动对应的MediaDriver
2. 启动Subscriber等待
3. 启动Publisher开始测试
4. 观察性能数据
5. 测试完成后停止: `./stop-mediadriver.sh`

## 📊 预期性能

| 测试级别 | 延迟 | 吞吐量 | 权限要求 |
|----------|------|--------|----------|
| 基础测试 | ~50μs | 5M msg/s | 无 |
| 中等优化 | ~10μs | 10M msg/s | 无 |
| 极致优化 | ~2μs | 15M+ msg/s | sudo |

## 🛑 注意事项

1. **每次测试前确保停止之前的MediaDriver**
2. **不同优化级别不要混用**
3. **极致优化测试需要sudo权限**
4. **如果出现权限问题，使用对应级别的脚本重新启动**

## 🚀 开始测试

你现在可以选择从哪个级别开始测试？

- **推荐新手**: 从基础测试开始
- **推荐日常**: 使用中等优化测试  
- **推荐极限**: 使用极致优化测试
