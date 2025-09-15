package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Subscription;
import io.aeron.logbuffer.FragmentHandler;
import io.aeron.logbuffer.Header;
import org.agrona.DirectBuffer;
import org.HdrHistogram.Histogram;

/**
 * 高性能二进制消息订阅者
 * 解析二进制消息并计算延迟统计
 * 支持UDP和IPC两种传输方式
 * 接收2000万条消息后自动退出并打印统计
 */
public class BinaryPerformanceSubscriber {
    // 传输方式枚举
    public enum TransportType {
        UDP("aeron:udp?endpoint=localhost:20121"),
        IPC("aeron:ipc?term-length=1048576"),
        NETWORK_UDP("aeron:udp?endpoint=%s:20121"); // 支持自定义IP的UDP
        
        private final String channelTemplate;
        
        TransportType(String channelTemplate) {
            this.channelTemplate = channelTemplate;
        }
        
        public String getChannel() {
            return channelTemplate;
        }
        
        public String getChannel(String customEndpoint) {
            if (this == NETWORK_UDP && customEndpoint != null) {
                return String.format(channelTemplate, customEndpoint);
            }
            return channelTemplate;
        }
    }
    
    private static final int STREAM_ID = 1001;
    private static final long DEFAULT_TARGET_MESSAGE_COUNT = 20_000_000L;  // 默认2000万条消息
    private static TransportType transportType = TransportType.UDP;  // 默认UDP
    private static String customEndpoint = null; // 自定义端点IP地址 (Subscriber连接到Publisher的IP)
    
    private static String getEffectiveChannel() {
        if (transportType == TransportType.NETWORK_UDP && customEndpoint != null) {
            return transportType.getChannel(customEndpoint);
        } else if (transportType == TransportType.UDP && customEndpoint != null) {
            // UDP模式下指定IP时，连接到指定的Publisher地址
            return "aeron:udp?endpoint=" + customEndpoint + ":20121";
        }
        return transportType.getChannel();
    }
    
    // 统计信息 - 单线程处理，使用普通变量即可
    private static long messageCount = 0;
    private static long totalLatency = 0;
    private static long maxLatency = 0;
    private static long minLatency = Long.MAX_VALUE;
    private static long firstMessageTime = 0;
    private static long lastMessageTime = 0;
    private static int messageSize = 0;
    private static boolean testCompleted = false;
    private static long targetMessageCount = DEFAULT_TARGET_MESSAGE_COUNT;
    
    // HdrHistogram用于精确的延迟分布统计
    // 最高值1秒(1,000,000μs)，精度到1μs，3位有效数字
    private static final Histogram latencyHistogram = new Histogram(1_000_000L, 3);

    public static void main(String[] args) {
        // 解析命令行参数
        parseArguments(args);
        
        System.out.println("=== Aeron二进制高性能测试 - 订阅者 ===");
        System.out.println("传输方式: " + transportType.name());
        System.out.println("Channel: " + getEffectiveChannel());
        System.out.println("Stream ID: " + STREAM_ID);
        System.out.printf("目标消息数: %,d 条\n", targetMessageCount);
        System.out.println("等待消息...\n");

        try (Aeron aeron = Aeron.connect();
             Subscription subscription = aeron.addSubscription(getEffectiveChannel(), STREAM_ID)) {

            final BinaryMessageHandler messageHandler = new BinaryMessageHandler();
            
            System.out.println("开始监听消息...");
            
            // 主循环 - 接收消息直到达到目标数量
            while (!testCompleted) {
                final int fragmentsRead = subscription.poll(messageHandler, 10);
                
                if (fragmentsRead == 0) {
                    Thread.onSpinWait();
                }
            }
            
            // 打印最终统计信息
            printFinalStatistics();
            
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
            
            // 设置消息大小（第一次收到消息时）
            if (messageSize == 0) {
                messageSize = length;
                // System.out.println("🚀 开始接收测试消息 (消息大小: " + length + " bytes)");
            }
            
            // 验证消息格式
            if (length < 8) {
                System.err.println("错误: 消息长度不足8字节");
                return;
            }
            
            // 解析大端时间戳
            final long sendTime = buffer.getLong(offset, java.nio.ByteOrder.BIG_ENDIAN);
            final long latency = receiveTime - sendTime;
                        
            // 更新统计信息
            updateStatistics(receiveTime, latency);
        }
    }
    
    private static void updateStatistics(long receiveTime, long latency) {
        if (firstMessageTime == 0) {
            firstMessageTime = receiveTime;
        }
        lastMessageTime = receiveTime;
        
        messageCount++;
        
        // 更新统计
        totalLatency += latency;
        if (latency > maxLatency) {
            maxLatency = latency;
        }
        if (latency < minLatency) {
            minLatency = latency;
        }
        
        // 记录到HdrHistogram (转换为微秒)
        final long latencyUs = latency / 1000L;
        latencyHistogram.recordValue(latencyUs);
        
        // 检查是否达到目标消息数量
        if (messageCount >= targetMessageCount) {
            testCompleted = true;
        }
    }
    
    /**
     * 解析命令行参数
     */
    private static void parseArguments(String[] args) {
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "-count":
                case "--count":
                    if (i + 1 < args.length) {
                        try {
                            targetMessageCount = Long.parseLong(args[i + 1]);
                            if (targetMessageCount <= 0) {
                                System.err.println("错误: 消息数量必须大于0");
                                printUsage();
                                System.exit(1);
                            }
                            i++; // 跳过参数值
                        } catch (NumberFormatException e) {
                            System.err.println("错误: 无效的消息数量: " + args[i + 1]);
                            printUsage();
                            System.exit(1);
                        }
                    } else {
                        System.err.println("错误: -count 参数需要指定数量");
                        printUsage();
                        System.exit(1);
                    }
                    break;
                case "-transport":
                case "--transport":
                    if (i + 1 < args.length) {
                        try {
                            transportType = TransportType.valueOf(args[i + 1].toUpperCase());
                            i++; // 跳过参数值
                        } catch (IllegalArgumentException e) {
                            System.err.println("错误: 无效的传输方式: " + args[i + 1]);
                            System.err.println("支持的传输方式: UDP, IPC, NETWORK_UDP");
                            printUsage();
                            System.exit(1);
                        }
                    } else {
                        System.err.println("错误: -transport 参数需要指定传输方式");
                        printUsage();
                        System.exit(1);
                    }
                    break;
                case "-connect":
                case "--connect":
                case "-endpoint":
                case "--endpoint":
                case "-ip":
                case "--ip":
                    if (i + 1 < args.length) {
                        customEndpoint = args[i + 1];
                        System.out.println("Subscriber将连接到: " + customEndpoint + ":20121");
                        i++; // 跳过参数值
                    } else {
                        System.err.println("错误: " + args[i] + " 参数需要指定Publisher的IP地址");
                        printUsage();
                        System.exit(1);
                    }
                    break;
                case "-h":
                case "--help":
                    printUsage();
                    System.exit(0);
                    break;
                default:
                    System.err.println("错误: 未知参数: " + args[i]);
                    printUsage();
                    System.exit(1);
            }
        }
    }
    
    /**
     * 打印使用说明
     */
    private static void printUsage() {
        System.out.println("用法: java BinaryPerformanceSubscriber [选项]");
        System.out.println();
        System.out.println("选项:");
        System.out.println("  -count, --count <数量>      目标消息数量 (默认: " + String.format("%,d", DEFAULT_TARGET_MESSAGE_COUNT) + ")");
        System.out.println("  -transport <方式>           传输方式: UDP, IPC 或 NETWORK_UDP (默认: UDP)");
        System.out.println("  -connect <IP>               连接到Publisher的IP地址 (跨机器测试时必需)");
        System.out.println("  -endpoint <IP>              连接到Publisher的IP地址 (同 -connect)");
        System.out.println("  -ip <IP>                    连接到Publisher的IP地址 (同 -connect)");
        System.out.println("  -h, --help                  显示此帮助信息");
        System.out.println();
        System.out.println("传输方式:");
        System.out.println("  UDP        - 使用UDP网络传输 (默认连接localhost，可用-connect指定Publisher IP)");
        System.out.println("  IPC        - 使用进程间通信 (适合本机超低延迟测试)");
        System.out.println("  NETWORK_UDP - 使用UDP网络传输连接指定IP (需要-connect参数)");
        System.out.println();
        System.out.println("示例:");
        System.out.println("  java BinaryPerformanceSubscriber                              # 使用默认UDP模式");
        System.out.println("  java BinaryPerformanceSubscriber -transport IPC               # 使用IPC模式");
        System.out.println("  java BinaryPerformanceSubscriber -count 10000000              # UDP模式，1000万条消息");
        System.out.println("  java BinaryPerformanceSubscriber -transport IPC -count 50000000 # IPC模式，5000万条消息");
    }
    
    private static void printFinalStatistics() {
        final long finalCount = messageCount;
        final long timeSpanNs = lastMessageTime - firstMessageTime;
        final double timeSpanSec = timeSpanNs / 1_000_000_000.0;
        final double messagesPerSecond = finalCount / timeSpanSec;
        final double avgLatencyUs = (totalLatency / (double) finalCount) / 1000.0;
        final double maxLatencyUs = maxLatency / 1000.0;
        final double minLatencyUs = minLatency / 1000.0;
        final double throughputMBps = (messagesPerSecond * messageSize) / (1024 * 1024);
        
        System.out.println("\n\n=== 📊 最终性能统计报告 ===");
        System.out.printf("总接收消息数: %,d 条\n", finalCount);
        System.out.printf("消息大小: %d bytes\n", messageSize);
        System.out.printf("测试总时长: %.3f 秒\n", timeSpanSec);
        System.out.println();
        System.out.printf("📈 吞吐量性能:\n");
        System.out.printf("  消息吞吐量: %,.0f msg/sec\n", messagesPerSecond);
        System.out.printf("  数据吞吐量: %.2f MB/sec\n", throughputMBps);
        System.out.println();
        System.out.printf("⚡ 端到端延迟统计 (receiveTime - sendTime):\n");
        System.out.printf("  平均延迟: %.2f μs\n", avgLatencyUs);
        System.out.printf("  最小延迟: %.2f μs\n", minLatencyUs);
        System.out.printf("  最大延迟: %.2f μs\n", maxLatencyUs);
        System.out.println();
        
        // 添加百分位延迟统计
        System.out.printf("📊 延迟分布 (百分位统计):\n");
        System.out.printf("  50th percentile (中位数): %d μs\n", latencyHistogram.getValueAtPercentile(50.0));
        System.out.printf("  90th percentile: %d μs\n", latencyHistogram.getValueAtPercentile(90.0));
        System.out.printf("  95th percentile: %d μs\n", latencyHistogram.getValueAtPercentile(95.0));
        System.out.printf("  99th percentile: %d μs\n", latencyHistogram.getValueAtPercentile(99.0));
        System.out.printf("  99.9th percentile: %d μs\n", latencyHistogram.getValueAtPercentile(99.9));
        System.out.printf("  99.99th percentile: %d μs\n", latencyHistogram.getValueAtPercentile(99.99));
        System.out.println();
        
        // 延迟分布区间统计
        System.out.printf("📈 延迟分布区间:\n");
        final long[] thresholds = {1, 5, 10, 20, 50, 100, 500, 1000}; // 微秒
        for (long threshold : thresholds) {
            double percentage = latencyHistogram.getPercentileAtOrBelowValue(threshold);
            System.out.printf("  ≤ %d μs: %.2f%%\n", threshold, percentage);
        }
        System.out.println();
        
        // 性能评估
        final double p99 = latencyHistogram.getValueAtPercentile(99.0);
        final double p90 = latencyHistogram.getValueAtPercentile(90.0);
        
        if (p99 < 1) {
            System.out.println("🚀 延迟评估: 超低延迟 (P99 < 1μs) - 完美适合超高频交易!");
        } else if (p99 < 5) {
            System.out.println("⚡ 延迟评估: 优秀 (P99 < 5μs) - 适合高频交易!");
        } else if (p99 < 20) {
            System.out.println("✅ 延迟评估: 良好 (P99 < 20μs) - 适合中频交易!");
        } else if (p99 < 100) {
            System.out.println("⚠️ 延迟评估: 可接受 (P99 < 100μs) - 需要优化!");
        } else {
            System.out.println("❌ 延迟评估: 较高 (P99 >= 100μs) - 急需优化!");
        }
        
        if (messagesPerSecond > 10_000_000) {
            System.out.println("🚀 吞吐量评估: 卓越 (> 1000万/秒)!");
        } else if (messagesPerSecond > 5_000_000) {
            System.out.println("⚡ 吞吐量评估: 优秀 (> 500万/秒)!");
        } else if (messagesPerSecond > 1_000_000) {
            System.out.println("✅ 吞吐量评估: 良好 (> 100万/秒)!");
        } else {
            System.out.println("⚠️ 吞吐量评估: 需要优化!");
        }
        
        // 输出详细的HdrHistogram报告（可选）
        if (finalCount > 10000) { // 只有大量数据时才输出
            System.out.println("\n📋 HdrHistogram 详细统计:");
            latencyHistogram.outputPercentileDistribution(System.out, 1.0);
        }
        
        System.out.println("\n测试完成! 🎉");
    }
}