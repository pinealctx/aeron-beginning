# Aeron Linux 脚本集合

本目录包含用于Aeron高性能消息传输测试的Linux脚本，支持本机IPC和跨机器UDP测试。

## 📁 脚本分类

### 🚀 MediaDriver 管理
| 脚本 | 功能 | 说明 |
|------|------|------|
| `start-mediadriver.sh` | 启动MediaDriver | 高性能配置，支持跨机器通信 |
| `stop-mediadriver.sh` | 停止MediaDriver | 清理资源和进程 |

### ⚡ 二进制性能测试
| 脚本 | 传输方式 | 优化级别 | 用途 |
|------|----------|----------|------|
| `binary-performance-publisher.sh` | UDP | 标准 | 跨机器发布者 |
| `binary-performance-subscriber.sh` | UDP | 标准 | 跨机器订阅者 |
| `binary-performance-publisher-ipc.sh` | IPC | 极致 | 本机发布者 |
| `binary-performance-subscriber-ipc.sh` | IPC | 极致 | 本机订阅者 |
| `*-udp-optimized.sh` | UDP | 高性能 | 优化版跨机器测试 |

### 🔧 RPC 服务测试
| 脚本 | 传输方式 | 功能 |
|------|----------|------|
| `aeron-rpc-server.sh` | UDP | RPC服务器 |
| `aeron-rpc-test.sh` | UDP | RPC客户端测试 |
| `aeron-rpc-server-ipc.sh` | IPC | 本机RPC服务器 |
| `aeron-rpc-test-ipc.sh` | IPC | 本机RPC测试 |

### 🛠️ 系统工具
| 脚本 | 功能 | 说明 |
|------|------|------|
| `linux-system.sh` | 系统优化 | CPU绑定、网络优化等 |
| `download-aeron.sh` | 依赖下载 | 获取Aeron JAR包 |

## 🚀 快速开始

### 1. 本机IPC测试 (极致性能)
```bash
# 启动MediaDriver
./start-mediadriver.sh

# 终端1: 启动IPC订阅者
./binary-performance-subscriber-ipc.sh

# 终端2: 启动IPC发布者
./binary-performance-publisher-ipc.sh
```

### 2. 跨机器UDP测试
```bash
# 机器A (192.168.0.106) - Publisher
./start-mediadriver.sh
./binary-performance-publisher.sh -transport NETWORK_UDP -bind 192.168.0.127

# 机器B (192.168.0.127) - Subscriber  
./start-mediadriver.sh
./binary-performance-subscriber.sh -transport NETWORK_UDP -connect 192.168.0.106
```

### 3. 系统性能优化
```bash
# 应用系统优化 (需要root权限)
sudo ./linux-system.sh

# 查看优化状态
./linux-system.sh status
```

## 📊 性能参数

### 支持的传输模式
- **IPC**: 本机进程间通信，延迟 < 1μs
- **UDP**: 跨机器网络传输，延迟通常 10-100μs  
- **NETWORK_UDP**: 跨机器优化UDP，支持自定义IP

### 常用测试参数
```bash
# 消息数量和大小
-count 1000000    # 发送100万条消息
-size 64          # 消息大小64字节

# 网络配置
-bind <IP>        # Publisher绑定IP
-connect <IP>     # Subscriber连接IP
```

## ⚠️ 注意事项

- **权限**: 确保脚本可执行 `chmod +x *.sh`
- **Java**: 需要Java 11+环境
- **网络**: 跨机器测试需要网络互通
- **时间同步**: 建议使用chrony进行时间同步
- **防火墙**: 确保端口20121开放

## 🔍 故障排除

### MediaDriver无法启动
```bash
# 检查进程
ps aux | grep MediaDriver
# 清理资源
./stop-mediadriver.sh
```

### 跨机器连接失败
```bash
# 检查网络连通性
ping <目标IP>
# 检查端口
telnet <目标IP> 20121
```

更多详细配置请参考上级目录的主README.md文档。
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
