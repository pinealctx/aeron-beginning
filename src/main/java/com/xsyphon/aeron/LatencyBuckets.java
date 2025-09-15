package com.xsyphon.aeron;

/**
 * 简化的延迟统计桶 - 用于计算百分位数
 * 适合对内存和性能要求严格的场景
 */
public class LatencyBuckets {
    // 预定义的延迟桶 (微秒)
    private static final double[] BUCKET_BOUNDS = {
        0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000
    };
    
    private final long[] buckets;
    private long totalCount = 0;
    private long sumLatency = 0;
    private double minLatency = Double.MAX_VALUE;
    private double maxLatency = 0;
    
    public LatencyBuckets() {
        this.buckets = new long[BUCKET_BOUNDS.length + 1]; // +1 for overflow bucket
    }
    
    public void recordValue(double latencyUs) {
        // 更新基本统计
        totalCount++;
        sumLatency += latencyUs;
        if (latencyUs < minLatency) minLatency = latencyUs;
        if (latencyUs > maxLatency) maxLatency = latencyUs;
        
        // 找到对应的桶
        int bucketIndex = findBucketIndex(latencyUs);
        buckets[bucketIndex]++;
    }
    
    private int findBucketIndex(double latencyUs) {
        for (int i = 0; i < BUCKET_BOUNDS.length; i++) {
            if (latencyUs <= BUCKET_BOUNDS[i]) {
                return i;
            }
        }
        return BUCKET_BOUNDS.length; // overflow bucket
    }
    
    public double getPercentile(double percentile) {
        if (totalCount == 0) return 0;
        
        long targetCount = (long) (totalCount * percentile / 100.0);
        long cumulativeCount = 0;
        
        for (int i = 0; i < buckets.length; i++) {
            cumulativeCount += buckets[i];
            if (cumulativeCount >= targetCount) {
                if (i == buckets.length - 1) {
                    return maxLatency; // overflow bucket
                } else {
                    return BUCKET_BOUNDS[i];
                }
            }
        }
        return maxLatency;
    }
    
    public double getAverage() {
        return totalCount > 0 ? (double) sumLatency / totalCount : 0;
    }
    
    public double getMin() {
        return minLatency == Double.MAX_VALUE ? 0 : minLatency;
    }
    
    public double getMax() {
        return maxLatency;
    }
    
    public long getTotalCount() {
        return totalCount;
    }
    
    public void printDistribution() {
        System.out.println("📊 延迟分布统计:");
        
        long cumulativeCount = 0;
        for (int i = 0; i < buckets.length; i++) {
            cumulativeCount += buckets[i];
            double percentage = (double) cumulativeCount / totalCount * 100;
            
            if (buckets[i] > 0) {
                if (i == buckets.length - 1) {
                    System.out.printf("  > %.1f μs: %d 条 (%.2f%%)\n", 
                        BUCKET_BOUNDS[BUCKET_BOUNDS.length - 1], buckets[i], 
                        (double) buckets[i] / totalCount * 100);
                } else {
                    String range = i == 0 ? 
                        String.format("≤ %.1f μs", BUCKET_BOUNDS[i]) :
                        String.format("%.1f - %.1f μs", BUCKET_BOUNDS[i-1], BUCKET_BOUNDS[i]);
                    System.out.printf("  %s: %d 条 (%.2f%%, 累计: %.2f%%)\n", 
                        range, buckets[i], (double) buckets[i] / totalCount * 100, percentage);
                }
            }
        }
    }
}
