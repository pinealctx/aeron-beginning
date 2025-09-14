# 🚀 Linux 快速启动指南

你已经把JAR文件和脚本复制到Linux了，现在按照以下步骤开始：

## 📋 **第0步：检查文件**

确保你有这些文件：
```bash
ls -la
# 应该看到：
# xsyphon-aeron-forex.jar
# aeron-all-1.48.6.jar  
# *.sh (各种脚本)
```

## 🔧 **第1步：给脚本添加执行权限**

```bash
chmod +x *.sh
```

## 🎯 **第2步：验证你的HugePage配置**

你的配置很好！验证一下：
```bash
cat /proc/meminfo | grep -i huge
```

**你的配置评估**：
- ✅ **HugePages_Total: 1024** (2GB) - 完美！
- ✅ **HugePages_Free: 1024** - 全部可用，没有碎片
- ✅ **Hugepagesize: 2048 kB** - 标准2MB页，性能最佳
- 🚀 **结论**：你的HugePage配置对高频交易来说是理想的！

## ⚡ **第3步：选择启动方式**

### 🎯 **方式1：一键测试（推荐）**
```bash
# 运行完整的优化测试套件
./optimized-test-suite.sh
```

### 🔧 **方式2：手动启动（专业模式）**

**终端1 - 启动优化版MediaDriver：**
```bash
./optimized-start-mediadriver.sh
```

**终端2 - 启动订阅者：**
```bash
./optimized-binary-performance-subscriber.sh
```

**终端3 - 启动发布者测试：**
```bash
./optimized-binary-performance-publisher.sh -count 2000000
```

## 📊 **第4步：期待的性能结果**

使用优化配置，你应该看到：

### 🎯 **目标性能**
- **延迟**: < 50μs (平均)，< 10μs (最小)
- **吞吐量**: 10M+ msg/sec
- **稳定性**: 延迟方差小

### 🔍 **性能分析**
```bash
# 之前的结果分析：
# 发布者: 0.11μs (send调用延迟) ✅
# 订阅者: 2789μs (端到端延迟) ❌ 

# 优化后期待：
# 发布者: 0.1μs (send调用延迟) ✅  
# 订阅者: 5-50μs (端到端延迟) 🚀
```

## 🛠 **故障排除**

### 如果延迟仍然很高 (>100μs)：

1. **检查CPU绑定**：
```bash
ps aux | grep java  # 应该看到taskset绑定
```

2. **检查网络优化**：
```bash
sysctl net.core.busy_read net.core.busy_poll
```

3. **检查MediaDriver状态**：
```bash
ps aux | grep MediaDriver
ls -la /dev/shm/aeron/
```

4. **检查系统负载**：
```bash
top
iotop  # 检查I/O压力
```

## 🔄 **停止服务**

```bash
# 停止MediaDriver
./stop-mediadriver.sh

# 或手动停止
pkill -f MediaDriver
```

## 📈 **优化效果预期**

基于你良好的HugePage配置，预期优化效果：

| 指标 | 优化前 | 优化后 | 改善 |
|------|--------|--------|------|
| 平均延迟 | 2789μs | 5-50μs | **98%+** |
| 最小延迟 | 1.72μs | 0.5-2μs | **稳定** |
| 最大延迟 | 15968μs | <200μs | **95%+** |
| 吞吐量 | 8M msg/s | 10-15M msg/s | **25%+** |

## 🚀 **成功标志**

如果你看到以下结果，说明优化成功：
- ✅ 平均延迟 < 50μs
- ✅ P99延迟 < 100μs  
- ✅ 吞吐量 > 10M msg/sec
- ✅ 延迟分布稳定（没有大的跳跃）

---

**现在开始你的第一次测试！** 🎯
