# 简化版 Makefile for TimeX JNI library
# 只编译当前平台版本

# 检测操作系统和架构
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Java 环境变量
JAVA_HOME ?= $(shell java -XshowSettings:properties -version 2>&1 | grep 'java.home' | sed 's/.*= *//')

# 编译器设置
CXX = g++
CXXFLAGS = -std=c++11 -fPIC -O3 -Wall

# 平台特定设置
ifeq ($(UNAME_S),Linux)
    # Linux
    LIB_EXT = so
    JAVA_INCLUDE = -I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/linux
    LDFLAGS = -shared -lrt
else ifeq ($(UNAME_S),Darwin)
    # macOS
    LIB_EXT = dylib
    JAVA_INCLUDE = -I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/darwin
    LDFLAGS = -shared -framework CoreFoundation
else
    $(error Unsupported platform: $(UNAME_S))
endif

# 目标文件
TARGET = libtimex.$(LIB_EXT)
SRC = TimeX.cpp
OBJ = TimeX.o

.PHONY: all clean info

all: $(TARGET)

$(TARGET): $(OBJ)
	@echo "🔗 链接 $(TARGET)..."
	$(CXX) $(LDFLAGS) -o $@ $^
	@echo "✅ 编译完成: $(TARGET)"

$(OBJ): $(SRC)
	@echo "🔨 编译 $(SRC)..."
	$(CXX) $(CXXFLAGS) $(JAVA_INCLUDE) -c $< -o $@

clean:
	@echo "🧹 清理文件..."
	rm -f $(OBJ) $(TARGET)

info:
	@echo "平台信息:"
	@echo "  操作系统: $(UNAME_S)"
	@echo "  架构: $(UNAME_M)"
	@echo "  Java Home: $(JAVA_HOME)"
	@echo "  目标文件: $(TARGET)"
	@echo "  编译器: $(CXX)"
	@echo "  编译选项: $(CXXFLAGS)"
	@echo "  包含路径: $(JAVA_INCLUDE)"
	@echo "  链接选项: $(LDFLAGS)"

# 测试编译的库
test: $(TARGET)
	@echo "🧪 测试 JNI 库..."
	@echo "请在Java中运行: TimeX.safeJniUnixNano()"
