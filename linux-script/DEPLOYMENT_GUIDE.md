# 🚀 Aeron Linux 生产环境部署指南

## 📋 **部署清单**

确保你已经将以下文件复制到Linux服务器：
```
linux-script/
├── xsyphon-aeron-forex.jar          # 主应用JAR
├── aeron-all-1.48.6.jar            # Aeron核心库
├── optimized-start-mediadriver.sh   # 优化版MediaDriver启动
├── optimized-binary-performance-publisher.sh
├── optimized-binary-performance-subscriber.sh
├── system-optimize.sh               # 系统优化脚本
├── stop-mediadriver.sh             # 停止MediaDriver
└── optimized-test-suite.sh          # 完整测试套件
```

## 🔧 **第一步：系统优化**

### 1. 运行系统优化脚本
```bash
# 给脚本添加执行权限
chmod +x *.sh

# 运行系统优化（需要sudo权限）
sudo ./system-optimize.sh
```

### 2. 验证优化结果
```bash
# 检查HugePage配置（你的配置很好！）
cat /proc/meminfo | grep -i huge
# 应该看到：
# HugePages_Total:    1024  ✅ (2GB总量)
# HugePages_Free:     1024  ✅ (全部可用) 
# Hugepagesize:       2048 kB ✅ (2MB页大小)

# 检查CPU性能模式
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 检查网络缓冲区
sysctl net.core.rmem_max net.core.wmem_max
```

**你的HugePage配置评估**：
- ✅ **2GB HugePage内存** - 足够Aeron MediaDriver + 应用使用
- ✅ **全部页面可用** - 没有内存碎片化问题  
- ✅ **2MB页大小** - 标准配置，性能优秀
- 🚀 **建议**：这个配置对于高频交易来说是完美的！
# 检查网络参数
sysctl net.core.rmem_max net.core.wmem_max

# 检查CPU调度器
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 检查hugepages
cat /proc/meminfo | grep -i huge
```

## ⚡ **第二步：启动服务**

### 方案A：自动化测试（推荐新手）
```bash
# 一键运行完整优化测试
./optimized-test-suite.sh
```

### 方案B：手动启动（推荐生产环境）

#### 🚀 优化版（需要sudo权限）
```bash
# 终端1：启动优化版MediaDriver
./optimized-start-mediadriver.sh

# 终端2：启动订阅者
./optimized-binary-performance-subscriber.sh

# 终端3：启动发布者
./optimized-binary-performance-publisher.sh -count 2000000
```

#### 🔧 简化版（无需sudo权限，推荐测试）
```bash
# 终端1：启动简化版MediaDriver
./simple-start-mediadriver.sh

# 终端2：启动订阅者
./simple-binary-performance-subscriber.sh

# 终端3：启动发布者  
./simple-binary-performance-publisher.sh -count 2000000
```

## 📊 **第三步：性能监控**

### 实时监控
```bash
# 监控CPU使用（在另一个终端）
top -p $(pgrep -f MediaDriver)

# 监控网络流量
iftop -i lo

# 监控Java进程
jstat -gc $(pgrep -f BinaryPerformance) 1s
```

### 延迟分析
```bash
# 检查网络延迟
ping -c 10 localhost

# 系统延迟测试
cyclictest -m -Sp90 -q
```

## 🎯 **预期性能目标**

### 优化前 vs 优化后
| 指标 | 优化前 | 目标 | 说明 |
|------|--------|------|------|
| 平均延迟 | 2789μs | <15μs | 系统级优化 |
| P99延迟 | >15ms | <50μs | CPU亲和性+BusySpin |
| 最小延迟 | 1.72μs | <1μs | 专用线程模式 |
| 吞吐量 | 8M msg/s | 15M+ msg/s | 内存+网络优化 |

### 判断标准
- ✅ **优秀**: 平均延迟 < 10μs
- ⚡ **良好**: 平均延迟 < 50μs  
- ⚠️ **需优化**: 平均延迟 > 100μs

## 🔍 **故障排除**

### 常见问题

#### 1. Java路径问题 🔥
```bash
# 错误：nice: "java": 没有那个文件或目录
# 解决方案A：使用简化版脚本（推荐）
./simple-start-mediadriver.sh
./simple-binary-performance-subscriber.sh
./simple-binary-performance-publisher.sh -count 2000000

# 解决方案B：设置JAVA_HOME环境变量
export JAVA_HOME="/home/kun/java/amazon-corretto-21.0.8.9.1-linux-x64"
export PATH="$JAVA_HOME/bin:$PATH"
```

#### 2. 权限问题
```bash
# 错误：taskset: failed to set pid's affinity
sudo chmod +s /usr/bin/taskset
# 或者使用简化版脚本（无需sudo权限）
```

#### 2. 内存不足
```bash
# 错误：Cannot allocate memory
# 解决：减少JVM堆内存
-Xms1G -Xmx1G  # 替代 -Xms2G -Xmx2G
```

#### 3. 端口占用
```bash
# 检查端口
netstat -tulpn | grep 20121
# 杀死占用进程
sudo kill -9 $(lsof -t -i:20121)
```

#### 4. MediaDriver连接失败
```bash
# 检查共享内存
ls -la /dev/shm/aeron*
# 清理残留文件
rm -rf /dev/shm/aeron*
```

## 📈 **性能调优**

### 如果延迟仍然高（>100μs）

#### 1. 检查CPU负载
```bash
# CPU是否超载
uptime
# 如果load > CPU核心数，减少其他进程
```

#### 2. 增加CPU隔离
```bash
# 编辑GRUB配置
sudo vim /etc/default/grub
# 添加：GRUB_CMDLINE_LINUX="isolcpus=0,1,2"
sudo update-grub
sudo reboot
```

#### 3. 调整网络缓冲区
```bash
# 如果丢包率高
sudo sysctl -w net.core.rmem_max=268435456
sudo sysctl -w net.core.wmem_max=268435456
```

### 如果吞吐量低（<5M msg/s）

#### 1. 检查批处理大小
```java
// 在代码中增加批处理
subscription.poll(messageHandler, 1024); // 增加批大小
```

#### 2. 调整消息大小
```bash
# 测试不同消息大小
./optimized-binary-performance-publisher.sh -size 32
./optimized-binary-performance-publisher.sh -size 128
```

## 🔒 **生产环境建议**

### 1. 持久化配置
```bash
# 将系统优化写入配置文件
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
sysctl -p
```

### 2. 开机自启动
```bash
# 创建systemd服务
sudo vim /etc/systemd/system/aeron-mediadriver.service
```

### 3. 监控报警
```bash
# 设置延迟监控
# 如果平均延迟 > 50μs，发送报警
```

## 📞 **技术支持**

如果遇到问题：
1. 🔍 检查 `/dev/shm/aeron*` 文件权限
2. 📊 运行 `dmesg | tail` 查看系统日志
3. 🔧 尝试普通模式：`./binary-performance-publisher.sh`
4. 📈 对比优化前后的性能数据

祝你在Linux上获得超低延迟的Aeron性能！🚀
