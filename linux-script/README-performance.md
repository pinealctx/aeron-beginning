# Aeron外汇交易系统 - 生产环境部署指南

## 部署准备

### 1. 下载Aeron官方JAR
```bash
./download-aeron.sh
```

### 2. 设置执行权限
```bash
chmod +x *.sh
```

## 基础功能测试

### 1. 启动独立MediaDriver (必须第一个启动)
```bash
# 终端1: 启动MediaDriver
./start-mediadriver.sh
```

### 2. 启动应用程序 (任意顺序)
```bash
# 终端2: 启动订阅者
./simple-subscriber.sh

# 终端3: 启动发布者  
./simple-pulisher.sh
```

## 性能基准测试

### 测试场景
- **预热阶段**: 10,000条消息
- **测试阶段**: 100,000条消息  
- **消息大小**: 64字节
- **测试指标**: 延迟、吞吐量、稳定性

### 执行步骤
```bash
# 终端1: 启动MediaDriver
./start-mediadriver.sh

# 终端2: 启动性能测试订阅者
./performance-subscriber.sh

# 终端3: 启动性能测试发布者  
./performance-publisher.sh
```

### 性能指标说明
- **延迟 < 10μs**: 优秀，适合高频交易
- **延迟 < 50μs**: 良好，适合中频交易  
- **延迟 < 100μs**: 一般，适合低频交易
- **吞吐量 > 100,000 msg/sec**: 满足高频交易需求

## 监控和管理

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

## 性能优化参数说明

### MediaDriver参数
- `-Daeron.term.buffer.sparse.file=false` - 预分配文件，避免运行时分配
- `-Daeron.pre.touch.mapped.memory=true` - 预加载内存页面
- `-Daeron.socket.so_sndbuf=2097152` - 发送缓冲区2MB
- `-Daeron.socket.so_rcvbuf=2097152` - 接收缓冲区2MB
- `-Daeron.rcv.initial.window.length=2097152` - 初始接收窗口2MB

### JVM参数
- `-Xms2g -Xmx2g` - 固定堆大小，避免GC触发的内存重新分配
- `-XX:+UseG1GC` - 使用G1垃圾收集器，低延迟
- `-XX:MaxGCPauseMillis=1` - 最大GC暂停时间1ms
- `--add-opens=java.base/jdk.internal.misc=ALL-UNNAMED` - 允许访问Unsafe类

## 关闭顺序

1. 先关闭Publisher和Subscriber (Ctrl+C)
2. 最后关闭MediaDriver (Ctrl+C)

## 故障排除

### 常见错误
- `ActiveDriverException` - 多个MediaDriver冲突，检查是否有遗留进程
- `RegistrationException` - 端口被占用，检查网络连接
- `NoSuchFileException` - Aeron目录不存在，检查/dev/shm权限

### 清理命令
```bash
# 杀死所有相关进程
pkill -f "aeron|MediaDriver"

# 清理Aeron目录
rm -rf /dev/shm/aeron/

# 重新创建目录
mkdir -p /dev/shm/aeron
```
