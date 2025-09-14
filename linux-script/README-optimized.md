# 🚀 Aeron高频交易性能测试 - 优化版指南

## 📋 概述

本目录包含Aeron消息系统的高性能优化版本，专为高频交易系统设计，目标实现：
- **延迟**: < 10μs (99th percentile)  
- **吞吐量**: 10M+ msg/sec
- **稳定性**: 生产级可靠性

## 🔧 优化特性

### 系统级优化
- ✅ 网络缓冲区扩大至128MB
- ✅ CPU性能模式 + 禁用空闲状态
- ✅ 大页内存2GB配置
- ✅ 调度器优化减少上下文切换
- ✅ 内存管理优化减少交换

### Aeron优化
- ✅ 专用线程模式 (DEDICATED)
- ✅ 忙等待策略 (BusySpinIdleStrategy)
- ✅ CPU亲和性绑定
- ✅ 最高进程优先级 (-20)
- ✅ RAM磁盘存储 (/dev/shm)

### 应用优化
- ✅ 异步统计打印
- ✅ 原子操作计数器
- ✅ 优化JVM参数
- ✅ 二进制消息格式

## 🚀 快速开始

### 1. 一键完整测试 (推荐)
```bash
# 完整优化测试套件 (包含系统检查、启动、测试)
sudo ./optimized-test-suite.sh

# 自定义参数测试
sudo ./optimized-test-suite.sh -count 5000000 -size 128
```

### 2. 分步骤手动执行

#### 步骤1: 系统优化 (首次执行)
```bash
# 系统级优化 (需要root权限，只需执行一次)
sudo ./system-optimize.sh
```

#### 步骤2: 启动MediaDriver
```bash
# 启动优化版MediaDriver
sudo ./optimized-start-mediadriver.sh
```

#### 步骤3: 启动订阅者
```bash
# 新终端窗口
sudo ./optimized-binary-performance-subscriber.sh
```

#### 步骤4: 启动发布者
```bash
# 新终端窗口
sudo ./optimized-binary-performance-publisher.sh -count 2000000 -size 64
```

#### 步骤5: 停止服务
```bash
# 停止MediaDriver
./stop-mediadriver.sh
```

## 📊 脚本说明

### 核心脚本
- `optimized-test-suite.sh` - 一键完整测试套件
- `system-optimize.sh` - 系统级优化配置
- `optimized-start-mediadriver.sh` - 优化版MediaDriver启动
- `optimized-binary-performance-publisher.sh` - 优化版发布者
- `optimized-binary-performance-subscriber.sh` - 优化版订阅者
- `stop-mediadriver.sh` - MediaDriver停止脚本

### CPU核心分配
- **核心0**: MediaDriver (专用)
- **核心1**: 发布者 (专用)
- **核心2**: 订阅者 (专用)
- **其他核心**: 系统进程

### 内存配置
- **MediaDriver**: 2GB堆内存
- **发布者/订阅者**: 1GB堆内存
- **大页内存**: 2GB (1024页)
- **网络缓冲区**: 128MB

## 📈 性能预期

### 优化前 vs 优化后
| 指标 | 优化前 | 优化后 | 改善 |
|------|--------|--------|------|
| 平均延迟 | 1154μs | < 10μs | 100x+ |
| P99延迟 | > 5000μs | < 50μs | 100x+ |
| 吞吐量 | 8M msg/sec | 15M+ msg/sec | 2x+ |
| 稳定性 | 一般 | 生产级 | 显著提升 |

### 硬件要求
- **CPU**: 4核心+ @ 3.0GHz+
- **内存**: 8GB+ DDR4-3200+
- **网络**: 千兆网卡 (万兆推荐)
- **存储**: SSD (影响启动速度)

## 🔍 监控与诊断

### 检查MediaDriver状态
```bash
# 检查进程
ps aux | grep MediaDriver

# 检查CPU亲和性
taskset -p $(pgrep -f MediaDriver)

# 检查日志
tail -f /dev/shm/aeron/*.log
```

### 检查系统优化
```bash
# 网络缓冲区
sysctl net.core.rmem_max

# 大页内存
cat /proc/sys/vm/nr_hugepages

# CPU频率
cpupower frequency-info
```

### 性能分析
```bash
# 网络抓包
sudo tcpdump -i lo -s 0 port 20121

# CPU使用率
top -p $(pgrep java)

# 内存分配
jstat -gc $(pgrep java) 1s
```

## 🚨 故障排除

### 常见问题

#### 1. 权限不足
```bash
# 错误: Operation not permitted
# 解决: 使用sudo执行脚本
sudo ./optimized-start-mediadriver.sh
```

#### 2. MediaDriver启动失败
```bash
# 检查端口占用
sudo netstat -tulpn | grep 20121

# 清理进程
./stop-mediadriver.sh
```

#### 3. 延迟仍然很高
```bash
# 检查系统优化
sudo ./system-optimize.sh

# 检查CPU模式
cpupower frequency-info

# 检查网络配置
sysctl net.core.rmem_max
```

#### 4. 大页内存不足
```bash
# 检查当前配置
cat /proc/meminfo | grep Huge

# 增加大页内存
sudo sysctl vm.nr_hugepages=2048
```

## 📚 参考文档

- [PERFORMANCE_OPTIMIZATION.md](../PERFORMANCE_OPTIMIZATION.md) - 详细性能优化指南
- [USAGE.md](../USAGE.md) - 基础使用说明
- [Aeron官方文档](https://github.com/real-logic/aeron/wiki)

## 💡 最佳实践

1. **首次使用**: 执行系统优化脚本
2. **测试前**: 重启系统确保优化生效
3. **生产环境**: 使用专用硬件和实时内核
4. **监控**: 持续监控延迟和吞吐量指标
5. **调优**: 根据实际工作负载调整参数

## 🎯 目标延迟

| 应用场景 | 目标延迟 | 配置要求 |
|----------|----------|----------|
| 超高频交易 | < 1μs | 专用硬件 + 实时内核 |
| 高频交易 | < 10μs | 优化配置 + 专用CPU |
| 中频交易 | < 50μs | 标准配置 |
| 一般应用 | < 100μs | 默认配置 |

---

🚀 **开始您的高频交易之旅！**
