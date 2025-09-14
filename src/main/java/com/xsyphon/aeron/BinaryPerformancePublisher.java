package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Publication;
import org.agrona.BufferUtil;
import org.agrona.concurrent.UnsafeBuffer;

/**
 * 高性能二进制消息发布者
 * 支持参数配置的消息大小和消息数量
 * 支持UDP和IPC两种传输方式
 */
public class BinaryPerformancePublisher {
    // 传输方式枚举
    public enum TransportType {
        UDP("aeron:udp?endpoint=localhost:20121"),
        IPC("aeron:ipc?term-length=1048576");
        
        private final String channel;
        
        TransportType(String channel) {
            this.channel = channel;
        }
        
        public String getChannel() {
            return channel;
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
        System.out.println("Channel: " + config.transportType.getChannel());
        System.out.println("Stream ID: " + STREAM_ID);
        System.out.println("消息大小: " + config.messageSize + " bytes");
        System.out.println("测试消息数: " + config.messageCount);
        System.out.println();

        try (Aeron aeron = Aeron.connect();
             Publication publication = aeron.addPublication(config.transportType.getChannel(), STREAM_ID)) {

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
        
        for (int i = 0; i < config.messageCount; i++) {
            final long sendTime = System.nanoTime();
            
            // 创建二进制消息
            createBinaryMessage(buffer, 1, i, sendTime, config.messageSize);
            
            long result;
            while ((result = publication.offer(buffer, 0, config.messageSize)) < 0) {
                if (result == Publication.BACK_PRESSURED) {
                    Thread.onSpinWait();
                } else if (result == Publication.NOT_CONNECTED) {
                    System.err.println("连接丢失!");
                    return;
                } else {
                    Thread.onSpinWait();
                }
            }
            successCount++;
        }
        
        final long endTime = System.nanoTime();
        final long totalTimeNs = endTime - startTime;
        
        // 输出统计信息
        printStatistics(config, successCount, totalTimeNs);
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
    
    private static void printStatistics(Config config, int successCount, long totalTimeNs) {
        final double totalTimeMs = totalTimeNs / 1_000_000.0;
        final double totalTimeSec = totalTimeMs / 1000.0;
        final double messagesPerSecond = successCount / totalTimeSec;
        final double throughputMBps = (messagesPerSecond * config.messageSize) / (1024 * 1024);
        
        System.out.println("\n=== 发布者性能统计 ===");
        System.out.printf("测试时长: %.2f 秒\n", totalTimeSec);
        System.out.printf("成功发送: %d 条消息\n", successCount);
        System.out.printf("消息大小: %d bytes\n", config.messageSize);
        System.out.println();
        System.out.printf("发送吞吐量: %.0f msg/sec\n", messagesPerSecond);
        System.out.printf("发送吞吐量: %.2f MB/sec\n", throughputMBps);
        System.out.println();
        System.out.println("注意: 端到端延迟请查看订阅者统计结果");
        
        // 吞吐量分析
        if (messagesPerSecond > 5_000_000) {
            System.out.println("🚀 发送性能: 超高吞吐量!");
        } else if (messagesPerSecond > 1_000_000) {
            System.out.println("⚡ 发送性能: 百万级吞吐量!");
        } else if (messagesPerSecond > 500_000) {
            System.out.println("✅ 发送性能: 50万+吞吐量!");
        } else {
            System.out.println("⚠️ 发送性能: 需要优化");
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
                            System.err.println("支持的传输方式: UDP, IPC");
                            printUsage();
                            System.exit(1);
                        }
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
        System.out.println("  -transport <方式>     传输方式: UDP 或 IPC (默认: " + DEFAULT_TRANSPORT.name() + ")");
        System.out.println("  -help                 显示帮助信息");
        System.out.println();
        System.out.println("传输方式:");
        System.out.println("  UDP    - 使用UDP网络传输 (适合跨网络测试)");
        System.out.println("  IPC    - 使用进程间通信 (适合本机超低延迟测试)");
        System.out.println();
        System.out.println("示例:");
        System.out.println("  java BinaryPerformancePublisher                                      # 使用默认设置");
        System.out.println("  java BinaryPerformancePublisher -transport IPC                       # 使用IPC模式");
        System.out.println("  java BinaryPerformancePublisher -count 10000000                      # 发送1000万条消息");
        System.out.println("  java BinaryPerformancePublisher -transport IPC -count 50000000       # IPC模式，5000万条消息");
        System.out.println("  java BinaryPerformancePublisher -size 128 -count 1000000             # 128字节消息，100万条");
    }
    
    private static class Config {
        int messageSize = DEFAULT_MESSAGE_SIZE;
        int messageCount = DEFAULT_MESSAGE_COUNT;
        TransportType transportType = DEFAULT_TRANSPORT;
    }
}
