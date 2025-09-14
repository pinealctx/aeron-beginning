# 🚀 Aeron 高性能消息系统

## 📋 目录结构

```
linux-script/
├── README.md                                    # 本说明文档
├── aeron-all-1.48.6.jar                       # Aeron核心库
│
├── 📁 MediaDriver启动脚本
│   ├── start-mediadriver.sh                   # 基础版MediaDriver
│   ├── moderate-start-mediadriver.sh          # 中等优化MediaDriver
│   └── optimized-start-mediadriver.sh         # 极致优化MediaDriver
│
├── 📁 Binary Performance测试 (3种优化级别)
│   ├── binary-performance-publisher.sh        # 基础版发布者
│   ├── binary-performance-subscriber.sh       # 基础版订阅者
│   ├── moderate-binary-performance-publisher.sh   # 中等优化发布者
│   ├── moderate-binary-performance-subscriber.sh  # 中等优化订阅者
│   ├── optimized-binary-performance-publisher.sh  # 极致优化发布者
│   └── optimized-binary-performance-subscriber.sh # 极致优化订阅者
│
└── 📁 工具脚本
    ├── download-aeron.sh                      # 下载Aeron库
    ├── stop-mediadriver.sh                   # 停止MediaDriver
    └── fix-aeron-permissions.sh              # 修复权限问题
```

## 🎯 三种优化级别

### 1️⃣ **基础版 (Basic)** - 无优化
```bash
./start-mediadriver.sh                    # 启动基础MediaDriver
./binary-performance-subscriber.sh        # 启动基础订阅者
./binary-performance-publisher.sh         # 启动基础发布者
```
**特点**：
- ✅ 无需特殊权限
- ✅ 兼容性最好
- ⚡ 性能：一般
- 🎯 **适用场景**：开发测试、兼容性验证

### 2️⃣ **中等优化 (Moderate)** - 平衡性能与稳定性
```bash
./moderate-start-mediadriver.sh           # 启动中等优化MediaDriver
./moderate-binary-performance-subscriber.sh # 启动中等优化订阅者
./moderate-binary-performance-publisher.sh  # 启动中等优化发布者
```
**特点**：
- ✅ 无需sudo权限
- ⚡ G1GC + 内存优化
- ⚡ 合理的JVM参数
- 🎯 **适用场景**：生产环境、日常性能测试（推荐）

### 3️⃣ **极致优化 (Optimized)** - 最高性能
```bash
./optimized-start-mediadriver.sh          # 启动极致优化MediaDriver
./optimized-binary-performance-subscriber.sh # 启动极致优化订阅者
./optimized-binary-performance-publisher.sh  # 启动极致优化发布者
```
**特点**：
- ⚠️ 需要sudo权限
- 🚀 CPU亲和性绑定
- 🚀 BusySpinIdleStrategy
- 🚀 最高进程优先级
- 🎯 **适用场景**：极致性能测试、高频交易评估

## 🚀 快速开始

### 方案A：推荐方案（中等优化）
```bash
# 1. 修复权限（如果需要）
./fix-aeron-permissions.sh

# 2. 启动MediaDriver
./moderate-start-mediadriver.sh

# 3. 启动订阅者（新终端）
./moderate-binary-performance-subscriber.sh -count 10000000

# 4. 启动发布者（新终端）
./moderate-binary-performance-publisher.sh -count 10000000
```

### 方案B：极致性能测试
```bash
# 1. 启动极致优化MediaDriver
sudo ./optimized-start-mediadriver.sh

# 2. 启动极致优化订阅者
sudo ./optimized-binary-performance-subscriber.sh -count 20000000

# 3. 启动极致优化发布者
sudo ./optimized-binary-performance-publisher.sh -count 20000000
```

## 📊 参数说明

所有 publisher 和 subscriber 脚本都支持以下参数：

```bash
-count <数量>     # 消息数量，默认20,000,000条
--help           # 显示帮助信息

# 示例
./moderate-binary-performance-subscriber.sh -count 5000000   # 500万条消息
./optimized-binary-performance-publisher.sh -count 50000000 # 5000万条消息
```

## 📈 性能对比

| 优化级别 | 延迟 | 吞吐量 | CPU使用 | 权限要求 | 适用场景 |
|----------|------|--------|---------|----------|----------|
| **基础版** | ~50μs | 5M msg/s | 低 | 无 | 开发测试 |
| **中等优化** | ~10μs | 10M msg/s | 中 | 无 | 生产环境 |
| **极致优化** | ~2μs | 15M+ msg/s | 高 | sudo | 性能评估 |

## 🔧 故障排除

### 常见问题

#### 1. 权限问题
```bash
# 错误：权限不够
./fix-aeron-permissions.sh

# 或使用基础版/中等优化版（无需sudo）
./moderate-start-mediadriver.sh
```

#### 2. Java路径问题
```bash
# 设置JAVA_HOME
export JAVA_HOME="/path/to/your/java"
export PATH="$JAVA_HOME/bin:$PATH"
```

#### 3. MediaDriver连接失败
```bash
# 停止现有MediaDriver
./stop-mediadriver.sh

# 清理并重启
./fix-aeron-permissions.sh
./moderate-start-mediadriver.sh
```

### 清理命令
```bash
# 杀死所有相关进程
pkill -f "aeron|MediaDriver"

# 清理Aeron目录
rm -rf /dev/shm/aeron/

# 重新创建目录
mkdir -p /dev/shm/aeron
```

## 📊 监控和管理

### 检查MediaDriver状态
```bash
# 检查进程
ps aux | grep MediaDriver

# 检查Aeron目录
ls -la /dev/shm/aeron/

# 检查内存使用
du -h /dev/shm/aeron/
```

### 性能监控
```bash
# 网络连接
netstat -an | grep 20121

# CPU使用率
top -p $(pgrep -f MediaDriver)

# 内存映射文件
lsof /dev/shm/aeron/*
```

## ⚡ 性能优化说明

### MediaDriver参数
- `-Daeron.term.buffer.sparse.file=false` - 预分配文件，避免运行时分配
- `-Daeron.pre.touch.mapped.memory=true` - 预加载内存页面
- `-Daeron.socket.so_sndbuf=2097152` - 发送缓冲区2MB
- `-Daeron.socket.so_rcvbuf=2097152` - 接收缓冲区2MB

### JVM参数
- `-Xms2g -Xmx2g` - 固定堆大小，避免GC重新分配
- `--add-opens=java.base/jdk.internal.misc=ALL-UNNAMED` - 允许访问Unsafe类

## 🎯 选择建议

### 🧪 开发阶段
- 使用 **基础版**，简单可靠
- 测试少量消息（1-10万条）

### 🔧 生产评估
- 使用 **中等优化版**，平衡性能与稳定性
- 测试中等规模（1000-2000万条）

### 🚀 性能极限测试
- 使用 **极致优化版**，获得最佳性能
- 测试大规模（2000万-1亿条）

## 🛑 关闭顺序

1. 先关闭Publisher和Subscriber (Ctrl+C)
2. 最后关闭MediaDriver (Ctrl+C)

## 📞 支持

如果遇到问题：
1. 检查 Java 环境和路径
2. 运行 `./fix-aeron-permissions.sh`
3. 尝试降级到更简单的版本
4. 查看MediaDriver日志：`ls -la /dev/shm/aeron/`

---

🎉 **现在开始你的高性能消息测试吧！**
