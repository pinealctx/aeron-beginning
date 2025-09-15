#!/bin/bash

# TimeX JNI 本地编译脚本
# 在当前平台编译对应的JNI库

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 TimeX JNI 本地编译"
echo "===================="

# 检测平台
UNAME_S=$(uname -s)
UNAME_M=$(uname -m)

echo "平台: $UNAME_S"
echo "架构: $UNAME_M"

# 检查Java环境
if [[ -z "$JAVA_HOME" ]]; then
    JAVA_HOME=$(java -XshowSettings:properties -version 2>&1 | grep 'java.home' | sed 's/.*= *//')
fi

if [[ -z "$JAVA_HOME" ]]; then
    echo "❌ 无法找到JAVA_HOME"
    exit 1
fi

echo "Java Home: $JAVA_HOME"

# 编译设置
CXX="g++"
CXXFLAGS="-std=c++11 -fPIC -O3 -Wall"

if [[ "$UNAME_S" == "Darwin" ]]; then
    # macOS
    PLATFORM="macos"
    LIB_EXT="dylib"
    JAVA_INCLUDE="-I$JAVA_HOME/include -I$JAVA_HOME/include/darwin"
    LDFLAGS="-shared -framework CoreFoundation"
    
    if [[ "$UNAME_M" == "arm64" ]]; then
        ARCH="aarch64"
    else
        ARCH="x86_64"
    fi
    
elif [[ "$UNAME_S" == "Linux" ]]; then
    # Linux
    PLATFORM="linux"
    LIB_EXT="so"
    JAVA_INCLUDE="-I$JAVA_HOME/include -I$JAVA_HOME/include/linux"
    LDFLAGS="-shared -lrt"
    
    if [[ "$UNAME_M" == "aarch64" ]]; then
        ARCH="aarch64"
    else
        ARCH="x86_64"
    fi
else
    echo "❌ 不支持的平台: $UNAME_S"
    exit 1
fi

TARGET="libtimex.$LIB_EXT"

echo "目标: $TARGET ($PLATFORM-$ARCH)"
echo ""

# 编译
echo "🔨 编译中..."
$CXX $CXXFLAGS $JAVA_INCLUDE -c TimeX.cpp -o TimeX.o
$CXX $LDFLAGS -o $TARGET TimeX.o

if [[ -f "$TARGET" ]]; then
    echo "✅ 编译成功: $TARGET"
    
    # 显示文件信息
    if command -v file &> /dev/null; then
        echo "文件信息:"
        file "$TARGET" | sed 's/^/  /'
    fi
    
    # 显示文件大小
    if command -v ls &> /dev/null; then
        echo "文件大小:"
        ls -lh "$TARGET" | awk '{print "  " $5 " " $9}'
    fi
    
    echo ""
    echo "📋 使用方法:"
    echo "1. 将 $TARGET 复制到 Java library.path"
    echo "2. 或者使用 System.load() 加载绝对路径"
    echo "3. 在Java中调用: TimeX.jniUnixNano()"
    
else
    echo "❌ 编译失败"
    exit 1
fi

# 清理临时文件
rm -f TimeX.o

echo ""
echo "🎉 完成!"
