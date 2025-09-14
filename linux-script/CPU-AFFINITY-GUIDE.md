# 🚀 CPU亲和性极限优化测试指南

## ⚠️ **权限要求**

CPU亲和性优化需要sudo权限，因为：
1. `taskset`设置CPU亲和性需要特权
2. `nice -n -15`设置高优先级需要特权
3. 系统级网络优化需要特权

## 🎯 **测试流程**

### 第一步：应用系统级优化
```bash
chmod +x linux-udp-extreme-optimization.sh
sudo ./linux-udp-extreme-optimization.sh
```

### 第二步：CPU亲和性测试（需要sudo）
```bash
# 设置脚本权限
chmod +x start-mediadriver-cpu-affinity.sh
chmod +x binary-performance-*-cpu-affinity.sh

# 1. 启动CPU亲和性MediaDriver (核心0-1) - 需要sudo
sudo ./start-mediadriver-cpu-affinity.sh

# 2. 启动CPU亲和性Subscriber (核心4-5) - 需要sudo
sudo ./binary-performance-subscriber-cpu-affinity.sh -count 2000000

# 3. 启动CPU亲和性Publisher (核心2-3) - 需要sudo  
sudo ./binary-performance-publisher-cpu-affinity.sh -count 2000000
```

## 🔧 **权限说明**

### 为什么需要sudo？
1. **CPU亲和性绑定**: `taskset -c` 需要特权绑定进程到特定CPU核心
2. **进程优先级**: `nice -n -15` 需要特权设置高优先级（负值）
3. **文件权限**: 确保/dev/shm/aeron目录权限正确

### 安全考虑
- 使用 `sudo -u $SUDO_USER` 确保Java进程以原用户身份运行
- 只有taskset和nice命令使用sudo权限
- Java进程本身不以root权限运行

## 📊 **CPU核心分配**

| 组件 | CPU核心 | 优先级 | 作用 |
|------|---------|--------|------|
| **MediaDriver** | 0-1 | -15 | 网络I/O处理 |
| **Publisher** | 2-3 | -10 | 消息发送 |
| **Subscriber** | 4-5 | -10 | 消息接收 |
| **系统其他** | 6-31 | 默认 | 操作系统和其他进程 |

## 🚀 **预期效果**

通过CPU亲和性优化：
- **避免CPU缓存失效**: 进程绑定在固定核心
- **减少上下文切换**: 专用核心处理
- **降低延迟抖动**: 避免进程迁移
- **提高缓存命中率**: 数据局部性更好

**目标**: UDP延迟从73μs降低到5-15μs范围！

## 🔍 **验证方法**

测试完成后可以验证CPU绑定：
```bash
# 查看MediaDriver的CPU亲和性
ps aux | grep MediaDriver
taskset -p <MediaDriver_PID>

# 查看所有java进程的CPU使用情况
htop -p $(pgrep java | tr '\n' ',' | sed 's/,$//')
```

## 💡 **备选方案**

如果不想使用sudo，可以：
1. 使用非CPU亲和性的优化版本
2. 配置用户权限允许设置CPU亲和性
3. 使用cgroups进行资源限制

但CPU亲和性优化通常能带来最显著的延迟改善！
