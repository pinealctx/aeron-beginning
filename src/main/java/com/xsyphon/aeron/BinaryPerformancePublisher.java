package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Publication;
import org.agrona.BufferUtil;
import org.agrona.concurrent.UnsafeBuffer;
import org.HdrHistogram.Histogram;

/**
 * 高性能二进制消息发布者
 * 支持参数配置的消息大小和消息数量
 * 支持UDP和IPC两种传输方式
 */
public class BinaryPerformancePublisher {
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
    
    // 默认参数
    private static final int DEFAULT_MESSAGE_SIZE = 64;
    private static final int DEFAULT_MESSAGE_COUNT = 1_000_000;
    private static final TransportType DEFAULT_TRANSPORT = TransportType.UDP;

    public static void main(String[] args) {
        // 解析命令行参数
        Config config = parseArgs(args);
        
        System.out.println("=== Aeron二进制高性能测试 - 发布者 ===");
        System.out.println("传输方式: " + config.transportType.name());
        System.out.println("Channel: " + config.getEffectiveChannel());
        System.out.println("Stream ID: " + STREAM_ID);
        System.out.println("消息大小: " + config.messageSize + " bytes");
        System.out.println("测试消息数: " + config.messageCount);
        System.out.println();

        try (Aeron aeron = Aeron.connect();
             Publication publication = aeron.addPublication(config.getEffectiveChannel(), STREAM_ID)) {

            // 创建消息缓冲区
            final UnsafeBuffer buffer = new UnsafeBuffer(BufferUtil.allocateDirectAligned(config.messageSize, 64));
            
            // 等待连接
            System.out.println("等待连接到订阅者...");
            while (!publication.isConnected()) {
                // 使用Thread.yield()进行微秒级等待，避免毫秒级的Thread.sleep()
                Thread.yield();
            }
            System.out.println("已连接到订阅者!");
            
            // 等待订阅者准备好
            Thread.sleep(1000);
            
            // 性能测试阶段
            System.out.println("\n⚡ 开始性能测试...");
            performanceTest(publication, buffer, config);
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    private static void performanceTest(Publication publication, UnsafeBuffer buffer, Config config) {
        final long startTime = System.nanoTime();
        int successCount = 0;
        int backPressureCount = 0;
        int retryCount = 0;
        
        // 发送延迟统计
        long minSendLatencyUs = Long.MAX_VALUE;
        long maxSendLatencyUs = 0;
        long totalSendLatencyUs = 0;
        
        // HdrHistogram用于统计发送延迟 (微秒级别)
        final Histogram sendLatencyHistogram = new Histogram(1_000_000L, 3); // 最高1秒，3位精度
        
        for (int i = 0; i < config.messageCount; i++) {
            final long messageStartTime = System.nanoTime();
            
            // 创建二进制消息 (使用消息开始时间作为时间戳)
            createBinaryMessage(buffer, 1, i, messageStartTime, config.messageSize);
            
            final long offerStartTime = System.nanoTime();
            long result;
            int messageRetries = 0;
            
            while ((result = publication.offer(buffer, 0, config.messageSize)) < 0) {
                messageRetries++;
                if (result == Publication.BACK_PRESSURED) {
                    backPressureCount++;
                    Thread.onSpinWait();
                } else if (result == Publication.NOT_CONNECTED) {
                    System.err.println("连接丢失!");
                    printSendStatistics(config, successCount, backPressureCount, retryCount, 
                                      System.nanoTime() - startTime, sendLatencyHistogram,
                                      minSendLatencyUs, maxSendLatencyUs, totalSendLatencyUs);
                    return;
                } else {
                    Thread.onSpinWait();
                }
            }
            
            final long offerEndTime = System.nanoTime();
            final long sendLatencyNs = offerEndTime - offerStartTime;
            final long sendLatencyUs = sendLatencyNs / 1000L;
            
            // 更新发送延迟统计
            totalSendLatencyUs += sendLatencyUs;
            if (sendLatencyUs < minSendLatencyUs) {
                minSendLatencyUs = sendLatencyUs;
            }
            if (sendLatencyUs > maxSendLatencyUs) {
                maxSendLatencyUs = sendLatencyUs;
            }
            
            // 记录发送延迟到histogram
            sendLatencyHistogram.recordValue(sendLatencyUs);
            
            successCount++;
            retryCount += messageRetries;
        }
        
        final long endTime = System.nanoTime();
        final long totalTimeNs = endTime - startTime;
        
        // 输出统计信息
        printSendStatistics(config, successCount, backPressureCount, retryCount, totalTimeNs, 
                           sendLatencyHistogram, minSendLatencyUs, maxSendLatencyUs, totalSendLatencyUs);
    }
    
    /**
     * 创建二进制消息
     * 格式: [0-7] 大端时间戳(long), [8-...] 循环填充0-255
     */
    private static void createBinaryMessage(UnsafeBuffer buffer, int messageType, int messageId, 
                                          long timestamp, int messageSize) {
        // 写入大端时间戳 (前8字节)
        buffer.putLong(0, timestamp, java.nio.ByteOrder.BIG_ENDIAN);
        
        // 后面用0-255循环填充
        for (int i = 8; i < messageSize; i++) {
            buffer.putByte(i, (byte) ((i - 8) % 256));
        }
    }
    
    private static void printSendStatistics(Config config, int successCount, int backPressureCount, 
                                           int retryCount, long totalTimeNs, Histogram sendLatencyHistogram,
                                           long minSendLatencyUs, long maxSendLatencyUs, long totalSendLatencyUs) {
        final double totalTimeMs = totalTimeNs / 1_000_000.0;
        final double totalTimeSec = totalTimeMs / 1000.0;
        final double messagesPerSecond = successCount / totalTimeSec;
        final double throughputMBps = (messagesPerSecond * config.messageSize) / (1024 * 1024);
        
        System.out.println("\n=== 📊 发布者性能统计报告 ===");
        System.out.printf("测试时长: %.3f 秒\n", totalTimeSec);
        System.out.printf("成功发送: %,d 条消息\n", successCount);
        System.out.printf("消息大小: %d bytes\n", config.messageSize);
        System.out.printf("背压次数: %,d 次\n", backPressureCount);
        System.out.printf("重试总数: %,d 次\n", retryCount);
        System.out.printf("平均重试: %.2f 次/消息\n", retryCount / (double) successCount);
        System.out.println();
        
        System.out.printf("📈 发送吞吐量性能:\n");
        System.out.printf("  消息吞吐量: %,.0f msg/sec\n", messagesPerSecond);
        System.out.printf("  数据吞吐量: %.2f MB/sec\n", throughputMBps);
        System.out.println();
        
        System.out.printf("⚡ 发送延迟统计 (offer调用耗时):\n");
        System.out.printf("  平均发送延迟: %.2f μs\n", (double) totalSendLatencyUs / successCount);
        System.out.printf("  最小发送延迟: %d μs\n", minSendLatencyUs);
        System.out.printf("  最大发送延迟: %d μs\n", maxSendLatencyUs);
        System.out.println();
        
        System.out.printf("📊 发送延迟分布 (百分位统计):\n");
        System.out.printf("  50th percentile (中位数): %d μs\n", sendLatencyHistogram.getValueAtPercentile(50.0));
        System.out.printf("  90th percentile: %d μs\n", sendLatencyHistogram.getValueAtPercentile(90.0));
        System.out.printf("  95th percentile: %d μs\n", sendLatencyHistogram.getValueAtPercentile(95.0));
        System.out.printf("  99th percentile: %d μs\n", sendLatencyHistogram.getValueAtPercentile(99.0));
        System.out.printf("  99.9th percentile: %d μs\n", sendLatencyHistogram.getValueAtPercentile(99.9));
        System.out.printf("  99.99th percentile: %d μs\n", sendLatencyHistogram.getValueAtPercentile(99.99));
        System.out.println();
        
        // 发送延迟分布区间统计
        System.out.printf("📈 发送延迟分布区间:\n");
        final long[] thresholds = {1, 5, 10, 20, 50, 100, 500, 1000}; // 微秒
        for (long threshold : thresholds) {
            double percentage = sendLatencyHistogram.getPercentileAtOrBelowValue(threshold);
            System.out.printf("  ≤ %d μs: %.2f%%\n", threshold, percentage);
        }
        System.out.println();
        
        // 性能评估
        final double p99SendLatency = sendLatencyHistogram.getValueAtPercentile(99.0);
        final double avgSendLatency = sendLatencyHistogram.getMean();
        
        System.out.printf("🎯 发送性能评估:\n");
        
        // 吞吐量分析
        if (messagesPerSecond > 5_000_000) {
            System.out.println("🚀 发送吞吐量: 超高性能 (> 500万/秒)!");
        } else if (messagesPerSecond > 1_000_000) {
            System.out.println("⚡ 发送吞吐量: 百万级性能!");
        } else if (messagesPerSecond > 500_000) {
            System.out.println("✅ 发送吞吐量: 50万+性能!");
        } else {
            System.out.println("⚠️ 发送吞吐量: 需要优化");
        }
        
        // 发送延迟分析
        if (p99SendLatency < 1) {
            System.out.println("🚀 发送延迟: 超低延迟 (P99 < 1μs) - 极致发送性能!");
        } else if (p99SendLatency < 5) {
            System.out.println("⚡ 发送延迟: 优秀 (P99 < 5μs) - 高效发送!");
        } else if (p99SendLatency < 20) {
            System.out.println("✅ 发送延迟: 良好 (P99 < 20μs) - 稳定发送!");
        } else if (p99SendLatency < 100) {
            System.out.println("⚠️ 发送延迟: 可接受 (P99 < 100μs) - 可优化!");
        } else {
            System.out.println("❌ 发送延迟: 较高 (P99 >= 100μs) - 需要优化!");
        }
        
        // 背压分析
        final double backPressureRate = backPressureCount / (double) successCount;
        if (backPressureRate < 0.01) {
            System.out.println("✅ 背压控制: 极少背压 (< 1%) - 发送流畅!");
        } else if (backPressureRate < 0.1) {
            System.out.println("⚠️ 背压控制: 中等背压 (< 10%) - 可接受!");
        } else {
            System.out.println("❌ 背压控制: 频繁背压 (>= 10%) - 需要优化!");
        }
        
        System.out.println();
        System.out.println("注意: 这是发送端统计，端到端延迟请查看订阅者统计结果");
        
        // 输出详细的HdrHistogram报告（可选）
        if (successCount > 10000) { // 只有大量数据时才输出
            System.out.println("\n📋 发送延迟 HdrHistogram 详细统计:");
            sendLatencyHistogram.outputPercentileDistribution(System.out, 1.0);
        }
    }
    
    private static Config parseArgs(String[] args) {
        Config config = new Config();
        
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "-size":
                    if (i + 1 < args.length) {
                        config.messageSize = Integer.parseInt(args[++i]);
                    }
                    break;
                case "-count":
                    if (i + 1 < args.length) {
                        config.messageCount = Integer.parseInt(args[++i]);
                    }
                    break;
                case "-transport":
                    if (i + 1 < args.length) {
                        try {
                            config.transportType = TransportType.valueOf(args[++i].toUpperCase());
                        } catch (IllegalArgumentException e) {
                            System.err.println("错误: 无效的传输方式: " + args[i]);
                            System.err.println("支持的传输方式: UDP, IPC, NETWORK_UDP");
                            printUsage();
                            System.exit(1);
                        }
                    }
                    break;
                case "-bind":
                case "-listen":
                case "-endpoint":
                case "-ip":
                    if (i + 1 < args.length) {
                        config.customEndpoint = args[++i];
                        System.out.println("Publisher将绑定到: " + config.customEndpoint + ":20121");
                    }
                    break;
                case "-help":
                    printUsage();
                    System.exit(0);
                    break;
                default:
                    System.err.println("错误: 未知参数: " + args[i]);
                    printUsage();
                    System.exit(1);
            }
        }
        
        // 验证参数
        if (config.messageSize < 8) {
            System.err.println("错误: 消息大小必须至少8字节(用于时间戳)");
            System.exit(1);
        }
        
        return config;
    }
    
    private static void printUsage() {
        System.out.println("用法: java -cp xsyphon-aeron-forex.jar com.xsyphon.aeron.BinaryPerformancePublisher [选项]");
        System.out.println();
        System.out.println("选项:");
        System.out.println("  -size <bytes>         消息大小 (默认: " + DEFAULT_MESSAGE_SIZE + ")");
        System.out.println("  -count <num>          测试消息数 (默认: " + DEFAULT_MESSAGE_COUNT + ")");
        System.out.println("  -transport <方式>     传输方式: UDP, IPC 或 NETWORK_UDP (默认: " + DEFAULT_TRANSPORT.name() + ")");
        System.out.println("  -bind <IP>            绑定到指定IP地址 (Publisher监听地址，默认localhost)");
        System.out.println("  -listen <IP>          绑定到指定IP地址 (同 -bind)");
        System.out.println("  -endpoint <IP>        绑定到指定IP地址 (同 -bind)");
        System.out.println("  -ip <IP>              绑定到指定IP地址 (同 -bind)");
        System.out.println("  -help                 显示帮助信息");
        System.out.println();
        System.out.println("传输方式:");
        System.out.println("  UDP        - 使用UDP网络传输 (默认localhost，可用-bind指定IP)");
        System.out.println("  IPC        - 使用进程间通信 (适合本机超低延迟测试)");
        System.out.println("  NETWORK_UDP - 使用UDP网络传输到指定IP (需要-bind参数)");
        System.out.println();
        System.out.println("示例:");
        System.out.println("  # 本机测试:");
        System.out.println("  java BinaryPerformancePublisher                                      # 使用默认设置(localhost)");
        System.out.println("  java BinaryPerformancePublisher -transport IPC                       # 使用IPC模式");
        System.out.println();
        System.out.println("  # 跨机器测试 - Publisher端 (192.168.0.106):");
        System.out.println("  java BinaryPerformancePublisher -bind 0.0.0.0                        # 监听所有网络接口");
        System.out.println("  java BinaryPerformancePublisher -bind 192.168.0.106                  # 监听指定IP");
        System.out.println("  java BinaryPerformancePublisher -bind 0.0.0.0 -count 10000000        # 高量测试");
        System.out.println();
        System.out.println("  注意: Publisher使用-bind指定监听地址，Subscriber使用-connect指定连接地址");
    }
    
    private static class Config {
        int messageSize = DEFAULT_MESSAGE_SIZE;
        int messageCount = DEFAULT_MESSAGE_COUNT;
        TransportType transportType = DEFAULT_TRANSPORT;
        String customEndpoint = null; // 自定义端点IP地址
        
        public String getEffectiveChannel() {
            if (transportType == TransportType.NETWORK_UDP && customEndpoint != null) {
                return transportType.getChannel(customEndpoint);
            } else if (transportType == TransportType.UDP && customEndpoint != null) {
                // UDP模式下指定IP时，使用自定义地址
                return "aeron:udp?endpoint=" + customEndpoint + ":20121";
            }
            return transportType.getChannel();
        }
    }
}
