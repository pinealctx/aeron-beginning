# TimeX - Unix纳秒时间戳工具

类似于Go语言的`time.Now().UnixNano()`功能，提供多种获取Unix纳秒时间戳的方法。

## ✨ 特性

- 🚀 **多种实现方式**: Instant API、System混合、JNI、JNA、毫秒级等
- ⚡ **性能对比**: 每种方法执行100万次的性能测试
- 🌍 **跨平台支持**: Linux (x86_64/ARM64)、macOS (Intel/ARM64)、Windows
- 📊 **Go风格API**: 提供类似Go语言的时间处理接口

## 🚀 快速开始

### 编译和运行
```bash
# 编译项目
mvn clean compile

# 运行性能测试
java -cp target/classes com.xsyphon.timex.TimeX

# 编译JNI库 (可选, 需要C++编译环境)
cd src/main/java/com/xsyphon/timex
make clean && make
```

### 基本使用
```java
import com.xsyphon.timex.TimeX;

// 方法1: Instant API (最精确)
long timestamp1 = TimeX.instantUnixNano();

// 方法2: System混合方法 (平衡性能和精度)
long timestamp2 = TimeX.systemMixedUnixNano();

// 方法3: 毫秒精度 (最快)
long timestamp3 = TimeX.currentTimeMillisUnixNano();

// 方法4: Go风格API
long timestamp4 = TimeX.GoStyleTimeUtils.unixNanoTime();

// Go风格时间间隔测量
TimeX.GoStyleTimeUtils.GoTime start = TimeX.GoStyleTimeUtils.now();
// ... 执行操作 ...
TimeX.GoStyleTimeUtils.GoTime end = TimeX.GoStyleTimeUtils.now();
long elapsed = end.since(start); // 纳秒级间隔
```

## 📊 性能对比

典型性能表现 (macOS M1, Java 21):

| 方法 | 平均耗时 | 吞吐量 | 精度 | 说明 |
|------|----------|--------|------|------|
| currentTimeMillis | ~5 ns | 200M ops/sec | 毫秒 | 最快，适合高频场景 |
| System混合方法 | ~8 ns | 125M ops/sec | 纳秒 | 平衡选择 |
| Go风格工具 | ~10 ns | 100M ops/sec | 纳秒 | 易用性好 |
| JNA调用 | ~50 ns | 20M ops/sec | 纳秒 | 系统精度 |
| Instant.now() | ~80 ns | 12.5M ops/sec | 纳秒 | 最精确 |
| JNI调用 | ~15 ns | 66M ops/sec | 纳秒 | 需要编译 |

## 🔧 方法详解

### 1. Instant API
```java
long timestamp = TimeX.instantUnixNano();
```
- ✅ 最高精度，标准Java API
- ❌ 性能开销较大，约80ns/次

### 2. System混合方法
```java
long timestamp = TimeX.systemMixedUnixNano();
```
- ✅ 良好的性能和精度平衡
- ⚠️ 依赖系统时钟同步

### 3. JNI系统调用
```java
long timestamp = TimeX.safeJniUnixNano();
```
- ✅ 直接系统调用，精度高
- ❌ 需要编译本地库

### 4. JNA系统调用
```java
long timestamp = TimeX.jnaUnixNano();
```
- ✅ 无需编译，跨平台
- ❌ 性能开销较大

### 5. 毫秒精度
```java
long timestamp = TimeX.currentTimeMillisUnixNano();
```
- ✅ 性能最好，约5ns/次
- ❌ 只有毫秒精度

### 6. Go风格API
```java
// 简单获取时间戳
long timestamp = TimeX.GoStyleTimeUtils.unixNanoTime();

// 时间间隔测量
GoTime start = GoStyleTimeUtils.now();
// ... 操作 ...
GoTime end = GoStyleTimeUtils.now();
long elapsed = end.since(start);
```
- ✅ 接口友好，类似Go语言
- ✅ 支持时间间隔测量
- ⚡ 性能适中

## 🛠️ 编译JNI库

如果要使用JNI方法，需要编译本地库：

```bash
cd src/main/java/com/xsyphon/timex

# 查看编译信息
make info

# 编译库
make clean && make

# 安装到系统路径 (可选)
sudo make install
```

支持平台:
- Linux x86_64/ARM64
- macOS Intel/ARM64  
- Windows x86_64/ARM64

## ⚠️ 注意事项

1. **跨机器使用**: 只有真正的Unix时间戳方法才能跨机器比较
2. **时钟同步**: System混合方法依赖系统时钟同步(如chrony/NTP)
3. **性能选择**: 根据精度需求选择合适的方法
4. **JNI依赖**: JNI方法需要编译对应平台的本地库

## 🎯 推荐使用

- **高频交易**: 使用`systemMixedUnixNano()`或`currentTimeMillisUnixNano()`
- **精确计时**: 使用`instantUnixNano()`
- **跨平台**: 使用`GoStyleTimeUtils.unixNanoTime()`
- **Go开发者**: 使用`GoStyleTimeUtils.*`全套API
