package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Publication;
import org.agrona.BufferUtil;
import org.agrona.concurrent.UnsafeBuffer;

import java.util.concurrent.TimeUnit;

/**
 * Aeron性能基准测试 - 发布者
 * 测量吞吐量和延迟
 */
public class AeronPerformancePublisher {
    private static final String CHANNEL = "aeron:udp?endpoint=localhost:20121";
    private static final int STREAM_ID = 1001;
    private static final int WARMUP_MESSAGES = 10_000;
    private static final int TEST_MESSAGES = 100_000;
    private static final int MESSAGE_SIZE = 64; // 64字节消息

    public static void main(String[] args) throws InterruptedException {
        System.out.println("=== Aeron外汇交易系统性能基准测试 ===");
        System.out.println("Channel: " + CHANNEL);
        System.out.println("Stream ID: " + STREAM_ID);
        System.out.println("预热消息数: " + WARMUP_MESSAGES);
        System.out.println("测试消息数: " + TEST_MESSAGES);
        System.out.println("消息大小: " + MESSAGE_SIZE + " bytes");
        System.out.println();

        // 连接到外部MediaDriver
        final Aeron.Context ctx = new Aeron.Context();
        
        try (Aeron aeron = Aeron.connect(ctx);
             Publication publication = aeron.addPublication(CHANNEL, STREAM_ID)) {

            final UnsafeBuffer buffer = new UnsafeBuffer(BufferUtil.allocateDirectAligned(MESSAGE_SIZE, 64));
            
            // 等待连接
            System.out.println("等待连接到订阅者...");
            while (!publication.isConnected()) {
                Thread.sleep(1);
            }
            System.out.println("已连接到订阅者!");
            
            // 预热阶段
            System.out.println("\n🔥 预热阶段...");
            warmup(publication, buffer);
            
            // 等待订阅者准备好
            Thread.sleep(2000);
            
            // 性能测试阶段
            System.out.println("\n⚡ 性能测试阶段...");
            performanceTest(publication, buffer);
            
            // 发送完成信号
            System.out.println("\n发送测试完成信号...");
            String endMessage = "TEST_COMPLETE|" + System.nanoTime();
            buffer.putStringAscii(0, endMessage);
            while (publication.offer(buffer, 0, endMessage.length()) < 0) {
                Thread.yield();
            }
            
            System.out.println("性能测试完成!");
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    private static void warmup(Publication publication, UnsafeBuffer buffer) {
        System.out.println("发送预热消息...");
        for (int i = 0; i < WARMUP_MESSAGES; i++) {
            String message = String.format("WARMUP|%d|%d", i, System.nanoTime());
            buffer.putStringAscii(0, message);
            
            while (publication.offer(buffer, 0, message.length()) < 0) {
                Thread.yield();
            }
            
            if (i % 1000 == 0) {
                System.out.printf("预热进度: %d/%d\r", i, WARMUP_MESSAGES);
            }
        }
        System.out.println("预热完成!                    ");
    }
    
    private static void performanceTest(Publication publication, UnsafeBuffer buffer) {
        System.out.println("开始性能测试...");
        
        final long startTime = System.nanoTime();
        long totalLatency = 0;
        long maxLatency = 0;
        long minLatency = Long.MAX_VALUE;
        int successCount = 0;
        
        for (int i = 0; i < TEST_MESSAGES; i++) {
            final long sendTime = System.nanoTime();
            String message = String.format("PERF|%d|%d", i, sendTime);
            buffer.putStringAscii(0, message);
            
            long result;
            while ((result = publication.offer(buffer, 0, message.length())) < 0) {
                if (result == Publication.BACK_PRESSURED) {
                    // 背压，稍等片刻
                    Thread.yield();
                } else if (result == Publication.NOT_CONNECTED) {
                    System.err.println("连接丢失!");
                    return;
                } else {
                    Thread.yield();
                }
            }
            
            final long endTime = System.nanoTime();
            final long latency = endTime - sendTime;
            
            totalLatency += latency;
            maxLatency = Math.max(maxLatency, latency);
            minLatency = Math.min(minLatency, latency);
            successCount++;
            
            if (i % 10000 == 0) {
                System.out.printf("测试进度: %d/%d\r", i, TEST_MESSAGES);
            }
        }
        
        final long endTime = System.nanoTime();
        final long totalTimeNs = endTime - startTime;
        final double totalTimeMs = totalTimeNs / 1_000_000.0;
        final double totalTimeSec = totalTimeMs / 1000.0;
        
        // 计算性能指标
        final double messagesPerSecond = successCount / totalTimeSec;
        final double avgLatencyUs = (totalLatency / (double) successCount) / 1000.0;
        final double maxLatencyUs = maxLatency / 1000.0;
        final double minLatencyUs = minLatency / 1000.0;
        final double throughputMBps = (messagesPerSecond * MESSAGE_SIZE) / (1024 * 1024);
        
        // 输出结果
        System.out.println("\n=== 性能测试结果 ===");
        System.out.printf("测试时长: %.2f 秒\n", totalTimeSec);
        System.out.printf("成功发送: %d 条消息\n", successCount);
        System.out.printf("消息大小: %d bytes\n", MESSAGE_SIZE);
        System.out.println();
        System.out.printf("吞吐量: %.0f msg/sec\n", messagesPerSecond);
        System.out.printf("吞吐量: %.2f MB/sec\n", throughputMBps);
        System.out.println();
        System.out.printf("平均延迟: %.2f μs\n", avgLatencyUs);
        System.out.printf("最小延迟: %.2f μs\n", minLatencyUs);
        System.out.printf("最大延迟: %.2f μs\n", maxLatencyUs);
        System.out.println();
        System.out.println("=== 外汇交易系统适用性评估 ===");
        
        if (avgLatencyUs < 10) {
            System.out.println("✅ 优秀 - 适合高频交易 (延迟 < 10μs)");
        } else if (avgLatencyUs < 50) {
            System.out.println("✅ 良好 - 适合中频交易 (延迟 < 50μs)");
        } else if (avgLatencyUs < 100) {
            System.out.println("⚠️ 一般 - 适合低频交易 (延迟 < 100μs)");
        } else {
            System.out.println("❌ 较差 - 不适合实时交易 (延迟 > 100μs)");
        }
        
        if (messagesPerSecond > 100_000) {
            System.out.println("✅ 优秀 - 吞吐量满足高频交易需求");
        } else if (messagesPerSecond > 50_000) {
            System.out.println("✅ 良好 - 吞吐量满足中频交易需求");
        } else {
            System.out.println("⚠️ 一般 - 吞吐量有限");
        }
    }
}
