package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Subscription;
import io.aeron.logbuffer.FragmentHandler;
import io.aeron.logbuffer.Header;
import org.agrona.DirectBuffer;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Aeron性能基准测试 - 订阅者
 * 测量接收延迟和吞吐量
 */
public class AeronPerformanceSubscriber {
    private static final String CHANNEL = "aeron:udp?endpoint=localhost:20121";
    private static final int STREAM_ID = 1001;
    private static final int FRAGMENT_COUNT_LIMIT = 256;

    public static void main(String[] args) {
        System.out.println("=== Aeron外汇交易系统性能基准测试 - 订阅者 ===");
        System.out.println("Channel: " + CHANNEL);
        System.out.println("Stream ID: " + STREAM_ID);
        System.out.println("等待发布者开始测试...");
        System.out.println();

        final AtomicBoolean running = new AtomicBoolean(true);
        final PerformanceStats stats = new PerformanceStats();
        
        // 注册关闭钩子
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            running.set(false);
            stats.printFinalStats();
        }));

        // 连接到外部MediaDriver
        try (Aeron aeron = Aeron.connect();
             Subscription subscription = aeron.addSubscription(CHANNEL, STREAM_ID)) {

            final FragmentHandler fragmentHandler = new PerformanceFragmentHandler(stats);
            
            System.out.println("开始接收消息...");
            
            long lastMessageTime = System.currentTimeMillis();
            long idleCount = 0;
            
            while (running.get()) {
                final int fragmentsRead = subscription.poll(fragmentHandler, FRAGMENT_COUNT_LIMIT);
                
                if (fragmentsRead == 0) {
                    idleCount++;
                    // 如果测试已开始且连续5秒没有消息，认为测试完成
                    if (stats.messageCount.get() > 0) {
                        long currentTime = System.currentTimeMillis();
                        if (currentTime - lastMessageTime > 5000) {
                            System.out.println("\n检测到测试完成，打印最终统计...");
                            stats.printFinalStats();
                            break;
                        }
                    }
                    
                    // 每100次空轮询暂停1ms，避免CPU占用过高
                    if (idleCount % 100 == 0) {
                        Thread.sleep(1);
                    }
                } else {
                    lastMessageTime = System.currentTimeMillis();
                    idleCount = 0;
                }
            }
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    private static class PerformanceFragmentHandler implements FragmentHandler {
        private final PerformanceStats stats;
        private boolean warmupPhase = true;
        private long testStartTime = 0;
        
        public PerformanceFragmentHandler(PerformanceStats stats) {
            this.stats = stats;
        }
        
        @Override
        public void onFragment(DirectBuffer buffer, int offset, int length, Header header) {
            final long receiveTime = System.nanoTime();
            final String message = buffer.getStringAscii(offset, length);
            
            if (message.startsWith("WARMUP")) {
                if (warmupPhase) {
                    stats.warmupCount.incrementAndGet();
                    if (stats.warmupCount.get() % 1000 == 0) {
                        System.out.printf("预热接收: %d\r", stats.warmupCount.get());
                    }
                }
                return;
            }
            
            if (message.startsWith("TEST_COMPLETE")) {
                System.out.println("\n接收到测试完成信号，打印最终统计...");
                stats.printFinalStats();
                System.exit(0);
                return;
            }
            
            if (message.startsWith("PERF")) {
                if (warmupPhase) {
                    warmupPhase = false;
                    testStartTime = receiveTime;
                    System.out.println("\n开始性能测试接收...");
                }
                
                // 解析发送时间
                String[] parts = message.split("\\|");
                if (parts.length >= 3) {
                    try {
                        final int messageId = Integer.parseInt(parts[1]);
                        final long sendTime = Long.parseLong(parts[2]);
                        final long latency = receiveTime - sendTime;
                        
                        stats.recordMessage(messageId, latency, receiveTime);
                        
                        if (stats.messageCount.get() % 10000 == 0) {
                            System.out.printf("接收进度: %d, 当前延迟: %.2f μs\r", 
                                stats.messageCount.get(), latency / 1000.0);
                        }
                    } catch (NumberFormatException e) {
                        // 忽略解析错误
                    }
                }
            }
        }
    }
    
    private static class PerformanceStats {
        final AtomicLong warmupCount = new AtomicLong(0);
        final AtomicLong messageCount = new AtomicLong(0);
        final AtomicLong totalLatency = new AtomicLong(0);
        final AtomicLong maxLatency = new AtomicLong(0);
        final AtomicLong minLatency = new AtomicLong(Long.MAX_VALUE);
        final AtomicLong firstMessageTime = new AtomicLong(0);
        final AtomicLong lastMessageTime = new AtomicLong(0);
        
        void recordMessage(int messageId, long latency, long receiveTime) {
            messageCount.incrementAndGet();
            totalLatency.addAndGet(latency);
            
            // 更新最大最小延迟
            long currentMax = maxLatency.get();
            while (latency > currentMax && !maxLatency.compareAndSet(currentMax, latency)) {
                currentMax = maxLatency.get();
            }
            
            long currentMin = minLatency.get();
            while (latency < currentMin && !minLatency.compareAndSet(currentMin, latency)) {
                currentMin = minLatency.get();
            }
            
            // 记录时间范围
            if (firstMessageTime.get() == 0) {
                firstMessageTime.set(receiveTime);
            }
            lastMessageTime.set(receiveTime);
        }
        
        void printFinalStats() {
            final long count = messageCount.get();
            if (count == 0) {
                System.out.println("\n没有接收到性能测试消息");
                return;
            }
            
            final long totalTimeNs = lastMessageTime.get() - firstMessageTime.get();
            final double totalTimeSec = totalTimeNs / 1_000_000_000.0;
            final double messagesPerSecond = count / totalTimeSec;
            final double avgLatencyUs = (totalLatency.get() / (double) count) / 1000.0;
            final double maxLatencyUs = maxLatency.get() / 1000.0;
            final double minLatencyUs = minLatency.get() / 1000.0;
            
            System.out.println("\n=== 订阅者性能统计 ===");
            System.out.printf("接收消息数: %d\n", count);
            System.out.printf("测试时长: %.2f 秒\n", totalTimeSec);
            System.out.printf("接收速率: %.0f msg/sec\n", messagesPerSecond);
            System.out.println();
            System.out.printf("端到端延迟统计:\n");
            System.out.printf("  平均延迟: %.2f μs\n", avgLatencyUs);
            System.out.printf("  最小延迟: %.2f μs\n", minLatencyUs);
            System.out.printf("  最大延迟: %.2f μs\n", maxLatencyUs);
            System.out.println();
            
            // 延迟分析
            if (avgLatencyUs < 10) {
                System.out.println("🚀 超低延迟 - 完美适合高频交易!");
            } else if (avgLatencyUs < 50) {
                System.out.println("⚡ 低延迟 - 非常适合实时交易!");
            } else if (avgLatencyUs < 100) {
                System.out.println("✅ 中等延迟 - 适合一般交易需求");
            } else {
                System.out.println("⚠️ 高延迟 - 需要优化配置");
            }
        }
    }
}
