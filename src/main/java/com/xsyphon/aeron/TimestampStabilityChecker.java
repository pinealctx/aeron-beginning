package com.xsyphon.aeron;

import com.xsyphon.javaext.TimeX;
import java.util.Arrays;
import java.util.function.LongSupplier;

/**
 * 时间戳稳定性检查工具
 * 用于测试和比较不同时间源的稳定性和精度
 * 
 * @author Assistant
 * @version 1.0.0
 */
public class TimestampStabilityChecker {
    
    private static final int DEFAULT_SAMPLES = 1000;
    private static final int WARMUP_SAMPLES = 100;
    
    /**
     * 时间源枚举
     */
    public enum TimeSource {
        TIMEX_JNI("TimeX.unixNanoJNI", TimeX::unixNanoJNI),
        TIMEX_OPTIMIZED("TimeX.unixNanoOptimized", TimeX::unixNanoOptimized),
        TIMEX_INSTANT("TimeX.unixNanoInstant", TimeX::unixNanoInstant),
        SYSTEM_NANOTIME("System.nanoTime", System::nanoTime);
        
        private final String name;
        private final LongSupplier supplier;
        
        TimeSource(String name, LongSupplier supplier) {
            this.name = name;
            this.supplier = supplier;
        }
        
        public String getName() {
            return name;
        }
        
        public long getTimestamp() {
            return supplier.getAsLong();
        }
    }
    
    /**
     * 稳定性分析结果
     */
    public static class StabilityResult {
        private final String sourceName;
        private final int sampleCount;
        private final long minInterval;
        private final long maxInterval;
        private final double avgInterval;
        private final double stdDeviation;
        private final double jitterRatio;
        private final int negativeCount;
        private final int largeJumpCount;
        private final long[] intervals;
        
        public StabilityResult(String sourceName, long[] intervals) {
            this.sourceName = sourceName;
            this.sampleCount = intervals.length;
            this.intervals = Arrays.copyOf(intervals, intervals.length);
            
            // 计算统计信息
            long sum = 0;
            long min = Long.MAX_VALUE;
            long max = Long.MIN_VALUE;
            int negatives = 0;
            int largeJumps = 0;
            
            for (long interval : intervals) {
                sum += interval;
                if (interval < min) min = interval;
                if (interval > max) max = interval;
                if (interval < 0) negatives++;
                if (interval > 100_000_000L) largeJumps++; // >100ms
            }
            
            this.minInterval = min;
            this.maxInterval = max;
            this.avgInterval = sum / (double) intervals.length;
            this.negativeCount = negatives;
            this.largeJumpCount = largeJumps;
            this.jitterRatio = max / this.avgInterval;
            
            // 计算标准差
            double sumSquaredDiffs = 0;
            for (long interval : intervals) {
                double diff = interval - this.avgInterval;
                sumSquaredDiffs += diff * diff;
            }
            this.stdDeviation = Math.sqrt(sumSquaredDiffs / intervals.length);
        }
        
        public void printDetailedReport() {
            System.out.printf("=== %s 稳定性分析报告 ===\n", sourceName);
            System.out.printf("  样本数量: %d\n", sampleCount);
            System.out.printf("  平均间隔: %.2f ns\n", avgInterval);
            System.out.printf("  标准差: %.2f ns\n", stdDeviation);
            System.out.printf("  最小间隔: %d ns\n", minInterval);
            System.out.printf("  最大间隔: %d ns\n", maxInterval);
            System.out.printf("  抖动比例: %.1fx (最大/平均)\n", jitterRatio);
            System.out.printf("  变异系数: %.2f%% (标准差/平均)\n", (stdDeviation / avgInterval) * 100);
            System.out.printf("  负向跳跃: %d 次 (%.2f%%)\n", negativeCount, (negativeCount * 100.0) / sampleCount);
            System.out.printf("  大幅跳跃: %d 次 (>100ms)\n", largeJumpCount);
            
            // 百分位统计
            long[] sortedIntervals = Arrays.copyOf(intervals, intervals.length);
            Arrays.sort(sortedIntervals);
            System.out.println("  百分位统计:");
            System.out.printf("    P50 (中位数): %d ns\n", getPercentile(sortedIntervals, 50));
            System.out.printf("    P90: %d ns\n", getPercentile(sortedIntervals, 90));
            System.out.printf("    P95: %d ns\n", getPercentile(sortedIntervals, 95));
            System.out.printf("    P99: %d ns\n", getPercentile(sortedIntervals, 99));
            System.out.printf("    P99.9: %d ns\n", getPercentile(sortedIntervals, 99.9));
            
            // 稳定性评估
            evaluateStability();
            System.out.println();
        }
        
        private long getPercentile(long[] sortedArray, double percentile) {
            int index = (int) Math.ceil((percentile / 100.0) * sortedArray.length) - 1;
            return sortedArray[Math.max(0, Math.min(index, sortedArray.length - 1))];
        }
        
        private void evaluateStability() {
            System.out.print("  稳定性评估: ");
            
            if (negativeCount > 0) {
                System.out.println("❌ 严重问题 - 检测到时钟倒退");
            } else if (largeJumpCount > 0) {
                System.out.println("⚠️ 警告 - 检测到大幅时间跳跃");
            } else if (jitterRatio > 50) {
                System.out.println("❌ 差 - 抖动过大 (>50x)");
            } else if (jitterRatio > 20) {
                System.out.println("⚠️ 一般 - 抖动较大 (>20x)");
            } else if (jitterRatio > 10) {
                System.out.println("📈 良好 - 轻微抖动 (>10x)");
            } else if (jitterRatio > 5) {
                System.out.println("✅ 优秀 - 抖动很小 (<10x)");
            } else {
                System.out.println("🚀 卓越 - 极低抖动 (<5x)");
            }
        }
        
        // Getter方法
        public String getSourceName() { return sourceName; }
        public double getAvgInterval() { return avgInterval; }
        public double getJitterRatio() { return jitterRatio; }
        public double getStdDeviation() { return stdDeviation; }
        public int getNegativeCount() { return negativeCount; }
        public int getLargeJumpCount() { return largeJumpCount; }
    }
    
    /**
     * 检查单个时间源的稳定性
     */
    public static StabilityResult checkStability(TimeSource timeSource, int samples) {
        System.out.printf("正在测试 %s (%d个样本)...\n", timeSource.getName(), samples);
        
        // 预热
        for (int i = 0; i < WARMUP_SAMPLES; i++) {
            timeSource.getTimestamp();
            Thread.onSpinWait();
        }
        
        // 收集时间戳样本
        long[] timestamps = new long[samples];
        for (int i = 0; i < samples; i++) {
            timestamps[i] = timeSource.getTimestamp();
            if (i > 0) {
                Thread.onSpinWait(); // 微小延迟
            }
        }
        
        // 计算时间间隔
        long[] intervals = new long[samples - 1];
        for (int i = 0; i < samples - 1; i++) {
            intervals[i] = timestamps[i + 1] - timestamps[i];
        }
        
        return new StabilityResult(timeSource.getName(), intervals);
    }
    
    /**
     * 检查所有时间源的稳定性
     */
    public static void checkAllTimeSources() {
        checkAllTimeSources(DEFAULT_SAMPLES);
    }
    
    /**
     * 检查所有时间源的稳定性（指定样本数）
     */
    public static void checkAllTimeSources(int samples) {
        System.out.println("🕒 开始时间戳稳定性全面检查");
        System.out.printf("样本数量: %d, 预热样本: %d\n", samples, WARMUP_SAMPLES);
        System.out.println("=".repeat(60));
        
        StabilityResult[] results = new StabilityResult[TimeSource.values().length];
        
        // 检查每个时间源
        for (int i = 0; i < TimeSource.values().length; i++) {
            TimeSource source = TimeSource.values()[i];
            try {
                results[i] = checkStability(source, samples);
                results[i].printDetailedReport();
            } catch (Exception e) {
                System.out.printf("❌ %s 检查失败: %s\n\n", source.getName(), e.getMessage());
            }
        }
        
        // 生成对比报告
        printComparisonReport(results);
    }
    
    /**
     * 打印对比报告
     */
    private static void printComparisonReport(StabilityResult[] results) {
        System.out.println("📊 时间源对比报告");
        System.out.println("=".repeat(60));
        
        // 找出最佳时间源
        StabilityResult bestOverall = null;
        StabilityResult mostStable = null;
        StabilityResult fastest = null;
        
        for (StabilityResult result : results) {
            if (result == null) continue;
            
            // 最快（最小平均间隔）
            if (fastest == null || result.getAvgInterval() < fastest.getAvgInterval()) {
                fastest = result;
            }
            
            // 最稳定（最小抖动比例）
            if (mostStable == null || result.getJitterRatio() < mostStable.getJitterRatio()) {
                mostStable = result;
            }
            
            // 综合最佳（无负数跳跃且抖动小）
            if (result.getNegativeCount() == 0 && result.getLargeJumpCount() == 0) {
                if (bestOverall == null || result.getJitterRatio() < bestOverall.getJitterRatio()) {
                    bestOverall = result;
                }
            }
        }
        
        // 打印推荐
        System.out.println("🏆 推荐时间源:");
        if (bestOverall != null) {
            System.out.printf("  综合最佳: %s (抖动: %.1fx)\n", bestOverall.getSourceName(), bestOverall.getJitterRatio());
        }
        if (mostStable != null) {
            System.out.printf("  最稳定: %s (抖动: %.1fx)\n", mostStable.getSourceName(), mostStable.getJitterRatio());
        }
        if (fastest != null) {
            System.out.printf("  最快: %s (平均: %.1f ns)\n", fastest.getSourceName(), fastest.getAvgInterval());
        }
        
        // 详细对比表
        System.out.println("\n📋 详细对比表:");
        System.out.printf("%-20s %10s %10s %10s %8s %8s\n", 
                         "时间源", "平均(ns)", "抖动比例", "标准差", "负跳跃", "大跳跃");
        System.out.println("-".repeat(80));
        
        for (StabilityResult result : results) {
            if (result == null) continue;
            System.out.printf("%-20s %10.1f %9.1fx %10.1f %8d %8d\n",
                             result.getSourceName(),
                             result.getAvgInterval(),
                             result.getJitterRatio(),
                             result.getStdDeviation(),
                             result.getNegativeCount(),
                             result.getLargeJumpCount());
        }
        
        System.out.println("\n💡 使用建议:");
        System.out.println("  - 跨机器测试: 推荐使用 TimeX.unixNanoJNI (绝对时间)");
        System.out.println("  - 本机测试: 可使用 System.nanoTime (相对时间，通常更稳定)");
        System.out.println("  - 生产环境: 选择抖动最小且无负跳跃的时间源");
        System.out.println("  - 如有负跳跃: 检查 chrony 同步状态和系统时钟");
    }
    
    /**
     * 主方法 - 用于独立运行测试
     */
    public static void main(String[] args) {
        int samples = DEFAULT_SAMPLES;
        
        // 解析命令行参数
        if (args.length > 0) {
            try {
                samples = Integer.parseInt(args[0]);
                if (samples < 10 || samples > 1000000) {
                    System.out.println("警告: 样本数应在 10-1000000 之间，使用默认值 " + DEFAULT_SAMPLES);
                    samples = DEFAULT_SAMPLES;
                }
            } catch (NumberFormatException e) {
                System.out.println("警告: 无效的样本数，使用默认值 " + DEFAULT_SAMPLES);
            }
        }
        
        System.out.println("时间戳稳定性检查工具 v1.0.0");
        System.out.println("用法: java TimestampStabilityChecker [样本数]");
        System.out.println();
        
        // 显示JVM和GC信息
        printJVMInfo();
        
        // 强制执行一次GC并等待
        System.out.println("🧹 执行GC清理...");
        System.gc();
        try {
            Thread.sleep(100); // 等待GC完成
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        checkAllTimeSources(samples);
    }
    
    /**
     * 打印JVM和GC相关信息
     */
    private static void printJVMInfo() {
        Runtime runtime = Runtime.getRuntime();
        long maxMemory = runtime.maxMemory();
        long totalMemory = runtime.totalMemory();
        long freeMemory = runtime.freeMemory();
        long usedMemory = totalMemory - freeMemory;
        
        System.out.println("💻 JVM环境信息:");
        System.out.printf("  Java版本: %s\n", System.getProperty("java.version"));
        System.out.printf("  JVM: %s\n", System.getProperty("java.vm.name"));
        System.out.printf("  最大内存: %.1f MB\n", maxMemory / 1024.0 / 1024.0);
        System.out.printf("  已分配内存: %.1f MB\n", totalMemory / 1024.0 / 1024.0);
        System.out.printf("  已使用内存: %.1f MB\n", usedMemory / 1024.0 / 1024.0);
        System.out.printf("  可用内存: %.1f MB\n", freeMemory / 1024.0 / 1024.0);
        
        // 检查GC参数
        java.lang.management.ManagementFactory.getGarbageCollectorMXBeans()
            .forEach(gcBean -> {
                System.out.printf("  GC: %s (收集次数: %d, 收集时间: %d ms)\n", 
                    gcBean.getName(), gcBean.getCollectionCount(), gcBean.getCollectionTime());
            });
        
        System.out.println();
        System.out.println("💡 GC优化建议:");
        System.out.println("  如果抖动过大，尝试以下JVM参数:");
        System.out.println("  -XX:+UseG1GC -XX:MaxGCPauseMillis=1 -XX:+UnlockExperimentalVMOptions");
        System.out.println("  -XX:+UseZGC (Java 11+) 或 -XX:+UseShenandoahGC");
        System.out.println("  -Xms4g -Xmx4g (固定堆大小避免动态扩展)");
        System.out.println();
    }
}
