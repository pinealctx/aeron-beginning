package com.xsyphon.timex;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Platform;
import com.sun.jna.Structure;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

/**
 * Unix纳秒时间戳获取工具类
 * 提供多种方法获取类似于 Go time.Now().UnixNano() 的Unix纳秒时间戳
 */
public class TimeX {

    // ========== 方法1: 标准 Java API - Instant ==========
    
    /**
     * 使用标准 Java Instant API 获取Unix纳秒时间戳
     * 精度最高，但性能开销较大
     */
    public static long instantUnixNano() {
        Instant now = Instant.now();
        return now.getEpochSecond() * 1_000_000_000L + now.getNano();
    }

    // ========== 方法2: System 时间方法混合 ==========
    
    // 在应用启动时初始化一次基准点
    private static final long SYSTEM_NANOTIME_OFFSET;
    static {
        long currentTimeMillis = System.currentTimeMillis();
        long nanoTime = System.nanoTime();
        SYSTEM_NANOTIME_OFFSET = currentTimeMillis * 1_000_000L - nanoTime;
    }

    /**
     * 使用 System.nanoTime() + 偏移量获取Unix纳秒时间戳
     * 性能较好，但精度取决于系统时钟同步
     */
    public static long systemMixedUnixNano() {
        return System.nanoTime() + SYSTEM_NANOTIME_OFFSET;
    }

    // ========== 方法3: JNI 直接调用系统 clock_gettime ==========
    
    // 加载本地库 - 简化版本
    static {
        try {
            // 尝试加载系统路径中的库
            System.loadLibrary("timex");
            System.out.println("✅ JNI库加载成功");
        } catch (UnsatisfiedLinkError e) {
            System.err.println("⚠️ 无法加载JNI库 timex: " + e.getMessage());
            System.err.println("💡 编译方法: cd native && ./build.sh");
        }
    }

    /**
     * JNI方法声明 - 调用系统的高精度时钟
     * Linux: clock_gettime(CLOCK_REALTIME)
     * macOS: clock_gettime_nsec_np(CLOCK_REALTIME)
     * Windows: GetSystemTimePreciseAsFileTime
     */
    public static native long jniUnixNano();

    /**
     * JNI获取Unix纳秒时间戳的安全包装方法
     */
    public static long safeJniUnixNano() {
        try {
            return jniUnixNano();
        } catch (UnsatisfiedLinkError e) {
            // 如果JNI不可用，降级到Instant方法
            return instantUnixNano();
        }
    }

    // ========== 方法4: JNA 调用 ==========
    
    // JNA接口定义
    public interface CLibrary extends Library {
        CLibrary INSTANCE = Native.load(Platform.isWindows() ? "kernel32" : "c", CLibrary.class);

        // Linux/macOS 结构体
        class TimeSpec extends Structure {
            public long tv_sec;  // 秒
            public long tv_nsec; // 纳秒

            @Override
            protected List<String> getFieldOrder() {
                return Arrays.asList("tv_sec", "tv_nsec");
            }
        }

        // Windows 结构体 (FILETIME)
        class FileTime extends Structure {
            public int dwLowDateTime;
            public int dwHighDateTime;

            @Override
            protected List<String> getFieldOrder() {
                return Arrays.asList("dwLowDateTime", "dwHighDateTime");
            }
        }

        // Linux/macOS: clock_gettime
        int clock_gettime(int clk_id, TimeSpec tp);

        // Windows: GetSystemTimePreciseAsFileTime
        void GetSystemTimePreciseAsFileTime(FileTime lpSystemTimeAsFileTime);
    }

    // 时钟类型常量
    private static final int CLOCK_REALTIME = 0;

    /**
     * 使用JNA调用系统API获取Unix纳秒时间戳
     */
    public static long jnaUnixNano() {
        if (Platform.isWindows()) {
            return jnaWindowsUnixNano();
        } else {
            return jnaUnixUnixNano();
        }
    }

    /**
     * Windows平台JNA实现
     */
    private static long jnaWindowsUnixNano() {
        CLibrary.FileTime ft = new CLibrary.FileTime();
        CLibrary.INSTANCE.GetSystemTimePreciseAsFileTime(ft);
        
        // Windows FILETIME 是从1601年1月1日开始的100纳秒单位
        // 转换为Unix时间戳 (从1970年1月1日开始)
        long winTime = ((long) ft.dwHighDateTime << 32) | (ft.dwLowDateTime & 0xFFFFFFFFL);
        long unixTime = (winTime - 116444736000000000L) * 100L; // 转换为纳秒
        return unixTime;
    }

    /**
     * Linux/macOS平台JNA实现
     */
    private static long jnaUnixUnixNano() {
        CLibrary.TimeSpec ts = new CLibrary.TimeSpec();
        int result = CLibrary.INSTANCE.clock_gettime(CLOCK_REALTIME, ts);
        if (result != 0) {
            throw new RuntimeException("clock_gettime failed");
        }
        return ts.tv_sec * 1_000_000_000L + ts.tv_nsec;
    }

    // ========== 方法5: 优化的 System.currentTimeMillis() ==========
    
    /**
     * 使用 System.currentTimeMillis() 获取毫秒精度的Unix纳秒时间戳
     * 性能最好，但精度只有毫秒级
     */
    public static long currentTimeMillisUnixNano() {
        return System.currentTimeMillis() * 1_000_000L;
    }

    // ========== 方法6: 改进的Go风格时间工具 ==========
    
    /**
     * 改进的Go风格时间工具类
     * 提供高精度的Unix时间戳和时间间隔计算
     */
    public static class GoStyleTimeUtils {
        // 保存启动时间基准点 - 使用更精确的初始化
        private static final long WALL_TIME_BASE_NANOS;
        private static final long MONO_TIME_BASE_NANOS;
        
        static {
            // 使用Instant获取精确的启动时间基准点
            Instant startInstant = Instant.now();
            long startMono = System.nanoTime();
            
            WALL_TIME_BASE_NANOS = startInstant.getEpochSecond() * 1_000_000_000L + startInstant.getNano();
            MONO_TIME_BASE_NANOS = startMono;
        }
        
        /**
         * Go风格的时间结构
         */
        public static class GoTime {
            private final long wallNanos;  // 墙上时钟时间(Unix纳秒)
            private final long monoNanos;  // 单调时钟时间
            
            private GoTime(long wallNanos, long monoNanos) {
                this.wallNanos = wallNanos;
                this.monoNanos = monoNanos;
            }
            
            /**
             * 获取 Unix 纳秒时间戳
             */
            public long unixNano() {
                return wallNanos;
            }
            
            /**
             * 计算与另一个时间点之间的差值（使用单调时钟）
             * 类似于 Go 的 time.Since()
             */
            public long since(GoTime earlier) {
                return this.monoNanos - earlier.monoNanos;
            }
            
            /**
             * 添加纳秒偏移量
             */
            public GoTime add(long nanos) {
                return new GoTime(this.wallNanos + nanos, this.monoNanos + nanos);
            }
        }
        
        /**
         * 模拟 Go 的 time.Now()
         * 返回当前时间，包含墙上时钟和单调时钟
         */
        public static GoTime now() {
            long currentMono = System.nanoTime();
            // 使用单调时钟的偏移计算当前墙上时间，避免时钟调整的影响
            long currentWall = WALL_TIME_BASE_NANOS + (currentMono - MONO_TIME_BASE_NANOS);
            return new GoTime(currentWall, currentMono);
        }
        
        /**
         * 简化接口：直接获取 Unix 纳秒时间戳
         * 类似于 Go 的 time.Now().UnixNano()
         */
        public static long unixNanoTime() {
            return now().unixNano();
        }
        
        /**
         * 获取墙上时钟时间（纳秒）- 基于currentTimeMillis
         */
        public static long wallTimeNano() {
            return System.currentTimeMillis() * 1_000_000L;
        }
        
        /**
         * 获取单调时钟时间（纳秒）
         */
        public static long monotimeNano() {
            return System.nanoTime();
        }
    }

    // ========== 性能测试主函数 ==========
    
    /**
     * 性能测试主函数
     * 测试各种方法获取Unix纳秒时间戳的性能
     */
    public static void main(String[] args) {
        System.out.println("=== Unix纳秒时间戳获取方法性能测试 ===");
        System.out.println("测试平台: " + System.getProperty("os.name") + " " + System.getProperty("os.arch"));
        System.out.println("Java版本: " + System.getProperty("java.version"));
        System.out.println();

        final int iterations = 1_000_000; // 一百万次测试
        
        // 预热JVM
        System.out.println("正在预热JVM...");
        for (int i = 0; i < 100_000; i++) {
            instantUnixNano();
            systemMixedUnixNano();
            currentTimeMillisUnixNano();
            GoStyleTimeUtils.unixNanoTime();
        }
        System.out.println("预热完成\n");

        // 测试各种方法
        testMethod("Instant.now()", iterations, TimeX::instantUnixNano);
        testMethod("System混合方法", iterations, TimeX::systemMixedUnixNano);
        testMethod("JNI调用", iterations, TimeX::safeJniUnixNano);
        testMethod("JNA调用", iterations, () -> {
            try {
                return jnaUnixNano();
            } catch (Exception e) {
                return instantUnixNano(); // 降级处理
            }
        });
        testMethod("currentTimeMillis", iterations, TimeX::currentTimeMillisUnixNano);
        testMethod("Go风格工具", iterations, GoStyleTimeUtils::unixNanoTime);

        // 精度对比测试
        System.out.println("\n=== 精度对比测试 ===");
        long instant = instantUnixNano();
        long system = systemMixedUnixNano();
        long millis = currentTimeMillisUnixNano();
        long goStyle = GoStyleTimeUtils.unixNanoTime();

        System.out.printf("Instant方法:      %d\n", instant);
        System.out.printf("System混合方法:   %d (差值: %d ns)\n", system, system - instant);
        System.out.printf("毫秒精度方法:     %d (差值: %d ns)\n", millis, millis - instant);
        System.out.printf("Go风格方法:       %d (差值: %d ns)\n", goStyle, goStyle - instant);

        // Go风格时间间隔测试
        System.out.println("\n=== Go风格时间间隔测试 ===");
        GoStyleTimeUtils.GoTime start = GoStyleTimeUtils.now();
        try {
            Thread.sleep(10); // 睡眠10毫秒
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        GoStyleTimeUtils.GoTime end = GoStyleTimeUtils.now();
        
        long elapsed = end.since(start);
        System.out.printf("测量的时间间隔: %d ns (%.2f ms)\n", elapsed, elapsed / 1_000_000.0);
        System.out.printf("Unix时间戳: 开始=%d, 结束=%d\n", start.unixNano(), end.unixNano());
    }

    /**
     * 测试方法性能的通用函数
     */
    private static void testMethod(String methodName, int iterations, TimeSupplier supplier) {
        System.gc(); // 建议进行垃圾回收
        
        long startTime = System.nanoTime();
        for (int i = 0; i < iterations; i++) {
            supplier.get();
        }
        long endTime = System.nanoTime();
        
        long totalTime = endTime - startTime;
        double avgTime = (double) totalTime / iterations;
        
        System.out.printf("%-15s: 总耗时=%6.2f ms, 平均耗时=%6.2f ns, 吞吐量=%8.0f ops/sec\n", 
                methodName, totalTime / 1_000_000.0, avgTime, 
                1_000_000_000.0 / avgTime);
    }

    /**
     * 函数式接口用于性能测试
     */
    @FunctionalInterface
    private interface TimeSupplier {
        long get();
    }
}
