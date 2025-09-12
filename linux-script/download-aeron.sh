#!/bin/bash
# 下载Aeron官方JAR用于MediaDriver

AERON_VERSION="1.48.6"
AERON_JAR="aeron-all-${AERON_VERSION}.jar"
MAVEN_REPO="https://repo.maven.apache.org/maven2/io/aeron/aeron-all/${AERON_VERSION}"

if [ ! -f "$AERON_JAR" ]; then
    echo "📥 下载Aeron官方JAR..."
    
    # 检查可用的下载工具
    if command -v curl >/dev/null 2>&1; then
        echo "使用curl下载..."
        curl -L "${MAVEN_REPO}/${AERON_JAR}" -o "$AERON_JAR"
    elif command -v wget >/dev/null 2>&1; then
        echo "使用wget下载..."
        wget "${MAVEN_REPO}/${AERON_JAR}" -O "$AERON_JAR"
    else
        echo "❌ 错误: 需要curl或wget来下载文件"
        echo "请安装其中一个:"
        echo "  Ubuntu/Debian: sudo apt install curl"
        echo "  CentOS/RHEL: sudo yum install curl"
        echo "  macOS: curl已预装"
        exit 1
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ 下载完成: $AERON_JAR"
    else
        echo "❌ 下载失败"
        exit 1
    fi
else
    echo "✅ 找到现有JAR: $AERON_JAR"
fi

echo "JAR文件大小: $(du -h $AERON_JAR | cut -f1)"
