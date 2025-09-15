#!/bin/bash

# 跨平台编译脚本
# 在macOS上编译Linux和ARM64版本的JNI库

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 TimeX JNI 跨平台编译脚本"
echo "=============================="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    exit 1
fi

# 创建输出目录
mkdir -p native-libs/{linux-x86_64,linux-aarch64,macos-x86_64,macos-aarch64,windows-x86_64}

echo "📦 编译Linux x86_64版本..."
docker build -t timex-builder-linux .
docker run --rm -v "$PWD:/workspace" -w /workspace timex-builder-linux \
    bash -c "make clean && make && cp libtimex.so native-libs/linux-x86_64/"

echo "📦 编译Linux ARM64版本..."
docker run --rm -v "$PWD:/workspace" -w /workspace \
    --platform linux/aarch64 timex-builder-linux \
    bash -c "make clean && make && cp libtimex.so native-libs/linux-aarch64/"

echo "📦 编译macOS版本..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # 本地编译macOS版本
    make clean
    make
    
    # 检测当前架构
    if [[ $(uname -m) == "arm64" ]]; then
        cp libtimex.dylib native-libs/macos-aarch64/
        echo "  ✅ 已编译 macOS ARM64 版本"
    else
        cp libtimex.dylib native-libs/macos-x86_64/
        echo "  ✅ 已编译 macOS x86_64 版本"
    fi
    
    # 尝试交叉编译另一个架构
    if command -v clang &> /dev/null; then
        if [[ $(uname -m) == "arm64" ]]; then
            # 在ARM64 Mac上编译x86_64版本
            echo "  🔄 交叉编译 macOS x86_64 版本..."
            clang++ -target x86_64-apple-macos10.15 -std=c++11 -fPIC -O3 -Wall \
                -I$JAVA_HOME/include -I$JAVA_HOME/include/darwin \
                -shared -framework CoreFoundation \
                -o native-libs/macos-x86_64/libtimex.dylib TimeX.cpp || echo "  ⚠️ 无法交叉编译x86_64版本"
        else
            # 在x86_64 Mac上编译ARM64版本
            echo "  🔄 交叉编译 macOS ARM64 版本..."
            clang++ -target arm64-apple-macos11.0 -std=c++11 -fPIC -O3 -Wall \
                -I$JAVA_HOME/include -I$JAVA_HOME/include/darwin \
                -shared -framework CoreFoundation \
                -o native-libs/macos-aarch64/libtimex.dylib TimeX.cpp || echo "  ⚠️ 无法交叉编译ARM64版本"
        fi
    fi
else
    echo "  ⚠️ 非macOS系统，跳过macOS编译"
fi

echo "📦 编译Windows版本 (使用MinGW)..."
if command -v x86_64-w64-mingw32-g++ &> /dev/null; then
    x86_64-w64-mingw32-g++ -std=c++11 -O3 -Wall \
        -I$JAVA_HOME/include -I$JAVA_HOME/include/win32 \
        -shared -lkernel32 \
        -o native-libs/windows-x86_64/timex.dll TimeX.cpp
    echo "  ✅ 已编译 Windows x86_64 版本"
else
    echo "  ⚠️ MinGW-w64未安装，跳过Windows编译"
    echo "  💡 安装方法: brew install mingw-w64"
fi

echo ""
echo "🎉 编译完成！生成的库文件："
echo "================================"
find native-libs -name "*.so" -o -name "*.dylib" -o -name "*.dll" | while read -r file; do
    echo "  📄 $file"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        file "$file" | sed 's/^/     /'
    fi
done

echo ""
echo "📋 使用说明："
echo "1. 将对应平台的库文件复制到Java library.path"
echo "2. 或者将库文件打包到JAR的resources/native/目录"
echo "3. 在Java代码中通过System.loadLibrary()加载"

# 创建自动加载的Java工具类
cat > NativeLibraryLoader.java << 'EOF'
package com.xsyphon.timex;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * 自动加载本地库的工具类
 * 支持从JAR资源中提取并加载对应平台的本地库
 */
public class NativeLibraryLoader {
    
    private static final String LIBRARY_NAME = "timex";
    private static boolean loaded = false;
    
    /**
     * 加载本地库
     */
    public static synchronized void loadLibrary() {
        if (loaded) {
            return;
        }
        
        try {
            // 首先尝试系统路径
            System.loadLibrary(LIBRARY_NAME);
            loaded = true;
            return;
        } catch (UnsatisfiedLinkError e) {
            // 系统路径加载失败，尝试从资源加载
        }
        
        try {
            loadLibraryFromResource();
            loaded = true;
        } catch (Exception e) {
            throw new RuntimeException("无法加载本地库: " + LIBRARY_NAME, e);
        }
    }
    
    /**
     * 从JAR资源中加载本地库
     */
    private static void loadLibraryFromResource() throws IOException {
        String osName = System.getProperty("os.name").toLowerCase();
        String osArch = System.getProperty("os.arch").toLowerCase();
        
        String platform;
        String extension;
        
        if (osName.contains("win")) {
            platform = "windows-x86_64";
            extension = ".dll";
        } else if (osName.contains("mac")) {
            if (osArch.contains("aarch64") || osArch.contains("arm")) {
                platform = "macos-aarch64";
            } else {
                platform = "macos-x86_64";
            }
            extension = ".dylib";
        } else if (osName.contains("linux")) {
            if (osArch.contains("aarch64") || osArch.contains("arm")) {
                platform = "linux-aarch64";
            } else {
                platform = "linux-x86_64";
            }
            extension = ".so";
        } else {
            throw new UnsupportedOperationException("不支持的平台: " + osName + " " + osArch);
        }
        
        String resourcePath = "/native/" + platform + "/lib" + LIBRARY_NAME + extension;
        if (osName.contains("win")) {
            resourcePath = "/native/" + platform + "/" + LIBRARY_NAME + extension;
        }
        
        InputStream is = NativeLibraryLoader.class.getResourceAsStream(resourcePath);
        if (is == null) {
            throw new IOException("找不到本地库资源: " + resourcePath);
        }
        
        // 创建临时文件
        File tempFile = File.createTempFile("lib" + LIBRARY_NAME, extension);
        tempFile.deleteOnExit();
        
        // 复制到临时文件
        try (FileOutputStream fos = new FileOutputStream(tempFile)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = is.read(buffer)) != -1) {
                fos.write(buffer, 0, bytesRead);
            }
        }
        
        // 加载临时文件
        System.load(tempFile.getAbsolutePath());
    }
    
    /**
     * 检查本地库是否已加载
     */
    public static boolean isLoaded() {
        return loaded;
    }
}
EOF

echo ""
echo "📝 已生成 NativeLibraryLoader.java 自动加载工具类"
echo "   可以自动检测平台并从JAR资源中加载对应的本地库"
