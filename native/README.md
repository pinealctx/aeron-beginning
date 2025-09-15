# TimeX JNI 本地库编译

这个目录包含TimeX JNI库的本地编译文件。

## 📁 文件说明

- `TimeX.h` - JNI头文件
- `TimeX.cpp` - 跨平台C++实现
- `Makefile` - Make编译脚本
- `build.sh` - Bash编译脚本
- `README.md` - 本说明文件

## 🚀 编译方法

### 方法1: 使用build.sh脚本 (推荐)
```bash
cd native
chmod +x build.sh
./build.sh
```

### 方法2: 使用Make
```bash
cd native
make info    # 查看编译环境信息
make clean   # 清理旧文件
make         # 编译
```

## 📋 编译要求

### macOS
- Xcode Command Line Tools
- Java 11+ (设置好JAVA_HOME)

### Linux
- gcc/g++ 编译器
- Java 11+ 开发包
- 运行时库 (librt)

## 🎯 输出文件

编译成功后会生成：
- **macOS**: `libtimex.dylib`
- **Linux**: `libtimex.so`

## 📦 使用方法

### 1. 系统路径安装
```bash
# macOS
sudo cp libtimex.dylib /usr/local/lib/

# Linux  
sudo cp libtimex.so /usr/lib/
sudo ldconfig
```

### 2. Java代码中使用
```java
// 方法1: 系统路径加载
System.loadLibrary("timex");

// 方法2: 绝对路径加载
System.load("/path/to/libtimex.dylib");

// 调用JNI方法
long timestamp = TimeX.jniUnixNano();
```

### 3. 安全调用 (推荐)
```java
// 使用TimeX中的安全包装方法
long timestamp = TimeX.safeJniUnixNano();
```

## ⚠️ 注意事项

1. **架构匹配**: 确保JNI库架构与Java运行时架构匹配
2. **JAVA_HOME**: 编译前确保JAVA_HOME环境变量正确设置  
3. **权限问题**: 系统路径安装可能需要sudo权限
4. **降级处理**: 如果JNI加载失败，会自动降级到Java标准API

## 🔍 故障排除

### 找不到JAVA_HOME
```bash
export JAVA_HOME=$(java -XshowSettings:properties -version 2>&1 | grep 'java.home' | sed 's/.*= *//')
```

### 编译错误
```bash
# 检查编译环境
make info

# 清理重新编译
make clean && make
```

### 运行时错误
```bash
# 检查库文件
file libtimex.dylib  # macOS
file libtimex.so     # Linux

# 检查依赖
otool -L libtimex.dylib  # macOS
ldd libtimex.so          # Linux
```
