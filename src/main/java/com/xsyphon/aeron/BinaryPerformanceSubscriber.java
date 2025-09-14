package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Subscription;
import io.aeron.logbuffer.FragmentHandler;
import io.aeron.logbuffer.Header;
import org.agrona.DirectBuffer;

import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 高性能二进制消息订阅者
 * 解析二进制消息并计算延迟统计
 */
public class BinaryPerformanceSubscriber {
    private static final String CHANNEL = "aeron:udp?endpoint=localhost:20121";
    private static final int STREAM_ID = 1001;
    
    // 统计信息 - 全部使用原子操作确保线程安全
    private static final AtomicLong messageCount = new AtomicLong(0);
    private static final AtomicLong totalLatency = new AtomicLong(0);
    private static final AtomicLong maxLatency = new AtomicLong(0);
    private static final AtomicLong minLatency = new AtomicLong(Long.MAX_VALUE);
    private static volatile long firstMessageTime = 0;
    private static volatile long lastMessageTime = 0;
    private static volatile int messageSize = 0;
    private static volatile boolean testCompleted = false;
    
    // 异步打印队列
    private static final BlockingQueue<StatSnapshot> printQueue = new ArrayBlockingQueue<>(1000);
    private static Thread printThread;

    public static void main(String[] args) {
        System.out.println("=== Aeron二进制高性能测试 - 订阅者 ===");
        System.out.println("Channel: " + CHANNEL);
        System.out.println("Stream ID: " + STREAM_ID);
        System.out.println("等待消息...\n");

        // 启动异步打印线程
        startPrintThread();

        try (Aeron aeron = Aeron.connect();
             Subscription subscription = aeron.addSubscription(CHANNEL, STREAM_ID)) {

            final BinaryMessageHandler messageHandler = new BinaryMessageHandler();
            
            System.out.println("开始监听消息...");
            
            // 主循环
            while (!testCompleted) {
                final int fragmentsRead = subscription.poll(messageHandler, 10);
                
                if (fragmentsRead == 0) {
                    Thread.onSpinWait();
                }
            }
            
            // 打印最终统计信息
            printFinalStatistics();
            
            // 停止打印线程
            stopPrintThread();
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 二进制消息处理器
     */
    private static class BinaryMessageHandler implements FragmentHandler {
        @Override
        public void onFragment(DirectBuffer buffer, int offset, int length, Header header) {
            final long receiveTime = System.nanoTime();
            
            // 验证消息格式
            if (length < 8) {
                System.err.println("错误: 消息长度不足8字节");
                return;
            }
            
            // 解析大端时间戳
            final long sendTime = buffer.getLong(offset, java.nio.ByteOrder.BIG_ENDIAN);
            final long latency = receiveTime - sendTime;
                        
            // 更新统计信息
            updateStatistics(latency, receiveTime);
        }
    }
    
    private static void updateStatistics(long latency, long receiveTime) {
        if (firstMessageTime == 0) {
            firstMessageTime = receiveTime;
        }
        lastMessageTime = receiveTime;
        
        final long currentCount = messageCount.incrementAndGet();
        totalLatency.addAndGet(latency);  // 原子操作
        
        // 原子更新最大/最小延迟
        updateMaxLatency(latency);
        updateMinLatency(latency);
        
        // 每100万条消息异步打印统计 - 不阻塞主线程
        if (currentCount % 1_000_000 == 0) {
            scheduleAsyncPrint(currentCount);
        }
        
        // 如果达到2000万条消息，自动完成测试
        if (currentCount >= 20_000_000) {
            testCompleted = true;
        }
    }
    
    private static void updateMaxLatency(long latency) {
        long currentMax = maxLatency.get();
        while (latency > currentMax) {
            if (maxLatency.compareAndSet(currentMax, latency)) {
                break;
            }
            currentMax = maxLatency.get();
        }
    }
    
    private static void updateMinLatency(long latency) {
        long currentMin = minLatency.get();
        while (latency < currentMin) {
            if (minLatency.compareAndSet(currentMin, latency)) {
                break;
            }
            currentMin = minLatency.get();
        }
    }
    
    /**
     * 统计快照类 - 用于异步打印
     */
    private static class StatSnapshot {
        final long messageCount;
        final long timeSpanNs;
        final long totalLatency;
        final long minLatency;
        final long maxLatency;
        final int messageSize;
        
        StatSnapshot(long messageCount, long timeSpanNs, long totalLatency, 
                    long minLatency, long maxLatency, int messageSize) {
            this.messageCount = messageCount;
            this.timeSpanNs = timeSpanNs;
            this.totalLatency = totalLatency;
            this.minLatency = minLatency;
            this.maxLatency = maxLatency;
            this.messageSize = messageSize;
        }
    }
    
    /**
     * 启动异步打印线程
     */
    private static void startPrintThread() {
        printThread = new Thread(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    StatSnapshot snapshot = printQueue.take();
                    printStatisticsFromSnapshot(snapshot);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }, "AsyncPrintThread");
        printThread.setDaemon(true);
        printThread.start();
    }
    
    /**
     * 停止异步打印线程
     */
    private static void stopPrintThread() {
        if (printThread != null) {
            printThread.interrupt();
            try {
                printThread.join(1000); // 等待最多1秒
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }
    
    /**
     * 异步调度打印任务 - 极轻量级，不阻塞主线程
     */
    private static void scheduleAsyncPrint(long currentCount) {
        final long timeSpan = lastMessageTime - firstMessageTime;
        final StatSnapshot snapshot = new StatSnapshot(
            currentCount, timeSpan, totalLatency.get(), minLatency.get(), maxLatency.get(), messageSize
        );
        
        // 非阻塞式提交，如果队列满了就丢弃（避免影响性能）
        printQueue.offer(snapshot);
    }
    
    /**
     * 从快照打印统计信息
     */
    private static void printStatisticsFromSnapshot(StatSnapshot snapshot) {
        final double timeSpanSec = snapshot.timeSpanNs / 1_000_000_000.0;
        final double messagesPerSecond = snapshot.messageCount / timeSpanSec;
        final double avgLatencyUs = (snapshot.totalLatency / (double) snapshot.messageCount) / 1000.0;
        final double maxLatencyUs = snapshot.maxLatency / 1000.0;
        final double minLatencyUs = snapshot.minLatency / 1000.0;
        final double throughputMBps = (messagesPerSecond * snapshot.messageSize) / (1024 * 1024);
        
        System.out.println("\n=== 订阅者阶段性统计 ===");
        System.out.printf("接收消息数: %d\n", snapshot.messageCount);
        System.out.printf("测试时长: %.2f 秒\n", timeSpanSec);
        System.out.printf("吞吐量: %.0f msg/sec\n", messagesPerSecond);
        System.out.printf("吞吐量: %.2f MB/sec\n", throughputMBps);
        System.out.printf("端到端延迟:\n");
        System.out.printf("  平均: %.2f μs\n", avgLatencyUs);
        System.out.printf("  最小: %.2f μs\n", minLatencyUs);
        System.out.printf("  最大: %.2f μs\n", maxLatencyUs);
        System.out.println("继续监听...\n");
    }
    
    private static void validateBinaryContent(DirectBuffer buffer, int offset, int length) {
        // 验证循环填充模式(8字节之后应该是0-255循环)
        for (int i = 8; i < Math.min(length, 24); i++) { // 只验证前16字节的填充
            byte expected = (byte) ((i - 8) % 256);
            byte actual = buffer.getByte(offset + i);
            
            if (actual != expected) {
                System.err.printf("警告: 字节%d应为%d但为%d\n", i, expected & 0xFF, actual & 0xFF);
                break;
            }
        }
    }
    
    private static void printFinalStatistics() {
        final long finalCount = messageCount.get();
        final long timeSpanNs = lastMessageTime - firstMessageTime;
        final double timeSpanSec = timeSpanNs / 1_000_000_000.0;
        final double messagesPerSecond = finalCount / timeSpanSec;
        final double avgLatencyUs = (totalLatency.get() / (double) finalCount) / 1000.0;
        final double maxLatencyUs = maxLatency.get() / 1000.0;
        final double minLatencyUs = minLatency.get() / 1000.0;
        final double throughputMBps = (messagesPerSecond * messageSize) / (1024 * 1024);
        
        System.out.println("\n\n=== 订阅者最终性能统计 ===");
        System.out.printf("总接收消息数: %d\n", finalCount);
        System.out.printf("消息大小: %d bytes\n", messageSize);
        System.out.printf("测试总时长: %.2f 秒\n", timeSpanSec);
        System.out.println();
        System.out.printf("接收吞吐量: %.0f msg/sec\n", messagesPerSecond);
        System.out.printf("接收吞吐量: %.2f MB/sec\n", throughputMBps);
        System.out.println();
        System.out.printf("端到端延迟统计:\n");
        System.out.printf("  平均延迟: %.2f μs\n", avgLatencyUs);
        System.out.printf("  最小延迟: %.2f μs\n", minLatencyUs);
        System.out.printf("  最大延迟: %.2f μs\n", maxLatencyUs);
        System.out.println();
        
        // 延迟分析
        if (avgLatencyUs < 1) {
            System.out.println("🚀 端到端延迟: 超低延迟 - 完美适合超高频交易!");
        } else if (avgLatencyUs < 5) {
            System.out.println("⚡ 端到端延迟: 优秀 - 适合高频交易!");
        } else if (avgLatencyUs < 20) {
            System.out.println("✅ 端到端延迟: 良好 - 适合中频交易!");
        } else {
            System.out.println("⚠️ 端到端延迟: 需要优化");
        }
        
        // 吞吐量分析
        if (messagesPerSecond > 1_000_000) {
            System.out.println("🚀 吞吐量: 百万级消息处理能力!");
        } else if (messagesPerSecond > 500_000) {
            System.out.println("⚡ 吞吐量: 50万+消息处理能力!");
        } else if (messagesPerSecond > 100_000) {
            System.out.println("✅ 吞吐量: 10万+消息处理能力!");
        } else {
            System.out.println("⚠️ 吞吐量: 需要优化配置");
        }
    }
}