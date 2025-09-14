package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Publication;
import io.aeron.Subscription;
import io.aeron.logbuffer.FragmentHandler;
import io.aeron.logbuffer.Header;
import org.agrona.DirectBuffer;
import org.agrona.concurrent.UnsafeBuffer;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * 请求-响应模式的Aeron测试
 * 模拟RPC的同步调用模式，避免延迟累积
 * 支持UDP和IPC两种传输方式
 */
public class AeronRpcTest {
    // 传输方式枚举
    public enum TransportType {
        UDP("aeron:udp?endpoint=localhost:20121", "aeron:udp?endpoint=localhost:20122"),
        IPC("aeron:ipc?term-length=1048576", "aeron:ipc?term-length=1048576");
        
        private final String requestChannel;
        private final String responseChannel;
        
        TransportType(String requestChannel, String responseChannel) {
            this.requestChannel = requestChannel;
            this.responseChannel = responseChannel;
        }
        
        public String getRequestChannel() { return requestChannel; }
        public String getResponseChannel() { return responseChannel; }
    }
    
    private static final int REQUEST_STREAM_ID = 1001;
    private static final int RESPONSE_STREAM_ID = 1002;
    private static final int MESSAGE_SIZE = 64;
    private static final long DEFAULT_MESSAGE_COUNT = 100_000L;

    public static void main(String[] args) {
        long messageCount = DEFAULT_MESSAGE_COUNT;
        TransportType transport = TransportType.UDP; // 默认使用UDP
        
        // 调试信息：打印所有参数
        if (args.length > 0) {
            System.out.println("🔍 调试信息 - 接收到的参数:");
            for (int i = 0; i < args.length; i++) {
                System.out.printf("  args[%d] = '%s'\n", i, args[i]);
            }
            System.out.println();
        }
        
        // 解析命令行参数
        for (int i = 0; i < args.length; i++) {
            if ("-count".equals(args[i]) && i + 1 < args.length) {
                try {
                    messageCount = Long.parseLong(args[i + 1]);
                    i++; // 跳过参数值
                } catch (NumberFormatException e) {
                    System.err.printf("错误: 无效的消息数量 '%s': %s\n", args[i + 1], e.getMessage());
                    printUsage();
                    System.exit(1);
                }
            } else if ("-transport".equals(args[i]) && i + 1 < args.length) {
                String transportStr = args[i + 1].toUpperCase();
                try {
                    transport = TransportType.valueOf(transportStr);
                } catch (IllegalArgumentException e) {
                    System.err.println("错误: 无效的传输方式: " + args[i + 1]);
                    System.err.println("支持的传输方式: UDP, IPC");
                    printUsage();
                    System.exit(1);
                }
                i++; // 跳过参数值
            } else if ("-h".equals(args[i]) || "--help".equals(args[i])) {
                printUsage();
                System.exit(0);
            } else {
                System.err.printf("警告: 忽略未知参数: '%s'\n", args[i]);
            }
        }

        System.out.println("=== Aeron RPC模式延迟测试 ===");
        System.out.printf("传输方式: %s\n", transport.name());
        System.out.printf("请求通道: %s\n", transport.getRequestChannel());
        System.out.printf("响应通道: %s\n", transport.getResponseChannel());
        System.out.printf("请求-响应测试，消息数量: %,d 条\n", messageCount);
        System.out.println("避免延迟累积，每个请求等待响应\n");

        try (Aeron aeron = Aeron.connect()) {
            // 创建发布和订阅
            Publication requestPub = aeron.addPublication(transport.getRequestChannel(), REQUEST_STREAM_ID);
            Subscription responseSub = aeron.addSubscription(transport.getResponseChannel(), RESPONSE_STREAM_ID);
            
            // 等待连接建立 (更充分的检查)
            System.out.println("等待连接建立...");
            while (!requestPub.isConnected() || !responseSub.isConnected()) {
                Thread.sleep(10);
            }
            
            // 额外等待确保服务器准备好
            Thread.sleep(100);
            System.out.println("✅ 连接已建立");
            
            // 发送一条测试消息确保通信正常
            System.out.println("📡 测试连接通信...");
            
            System.out.println("连接已建立，开始RPC模式测试...\n");
            
            // 执行测试
            RpcTester tester = new RpcTester(requestPub, responseSub);
            tester.runTest(messageCount);
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static class RpcTester {
        private final Publication requestPub;
        private final Subscription responseSub;
        private final UnsafeBuffer requestBuffer;
        private final List<Long> latencies;
        private volatile boolean responseReceived;
        private volatile long responseTime;

        public RpcTester(Publication requestPub, Subscription responseSub) {
            this.requestPub = requestPub;
            this.responseSub = responseSub;
            this.requestBuffer = new UnsafeBuffer(ByteBuffer.allocateDirect(MESSAGE_SIZE));
            this.latencies = new ArrayList<>();
        }

        public void runTest(long messageCount) {
            final ResponseHandler responseHandler = new ResponseHandler();
            final long startTime = System.nanoTime();
            
            for (long i = 0; i < messageCount; i++) {
                // 发送请求并等待响应
                long latency = sendRequestAndWaitResponse(i, responseHandler);
                latencies.add(latency);
            }
            
            final long totalTime = System.nanoTime() - startTime;
            // print total rpc requests and total time and average request time
            System.out.println("\n");
            System.out.printf("总请求数: %,d 条\n", messageCount);
            System.out.printf("测试总时长: %.3f 秒\n", totalTime / 1_000_000_000.0);
            System.out.printf("平均每次请求时长: %.2f μs\n", (totalTime / (double)messageCount) / 1000.0);
            
            // 打印统计结果
            printStatistics(messageCount, totalTime);
        }

        private long sendRequestAndWaitResponse(long requestId, ResponseHandler handler) {
            // 创建请求消息 (8字节时间戳 + 8字节请求ID + 填充)
            final long sendTime = System.nanoTime();
            requestBuffer.putLong(0, sendTime, java.nio.ByteOrder.BIG_ENDIAN);
            requestBuffer.putLong(8, requestId, java.nio.ByteOrder.BIG_ENDIAN);
            
            // 重置响应状态
            responseReceived = false;
            
            // 发送请求
            while (requestPub.offer(requestBuffer, 0, MESSAGE_SIZE) < 0) {
                Thread.onSpinWait();
            }
            
            // 等待响应 (超时100ms)
            final long deadline = System.nanoTime() + 100_000_000L; // 100ms超时
            while (!responseReceived && System.nanoTime() < deadline) {
                responseSub.poll(handler, 1);
                if (!responseReceived) {
                    Thread.onSpinWait();
                }
            }
            
            if (!responseReceived) {
                throw new RuntimeException("响应超时: " + requestId);
            }
            
            return responseTime - sendTime;
        }

        private class ResponseHandler implements FragmentHandler {
            @Override
            public void onFragment(DirectBuffer buffer, int offset, int length, Header header) {
                // 解析响应 (8字节原始时间戳 + 8字节请求ID)
                final long originalSendTime = buffer.getLong(offset, java.nio.ByteOrder.BIG_ENDIAN);
                final long requestId = buffer.getLong(offset + 8, java.nio.ByteOrder.BIG_ENDIAN);
                
                responseTime = System.nanoTime();
                responseReceived = true;
            }
        }

        private void printStatistics(long messageCount, long totalTimeNs) {
            if (latencies.isEmpty()) {
                System.out.println("没有收集到延迟数据");
                return;
            }

            // 排序以计算百分位数
            latencies.sort(Long::compareTo);
            
            final double totalTimeSec = totalTimeNs / 1_000_000_000.0;
            final double qps = messageCount / totalTimeSec;
            
            final long minLatency = latencies.get(0);
            final long maxLatency = latencies.get(latencies.size() - 1);
            final long p50Latency = latencies.get((int)(latencies.size() * 0.5));
            final long p90Latency = latencies.get((int)(latencies.size() * 0.9));
            final long p99Latency = latencies.get((int)(latencies.size() * 0.99));
            final long p999Latency = latencies.get((int)(latencies.size() * 0.999));
            
            final double avgLatency = latencies.stream().mapToLong(Long::longValue).average().orElse(0.0);

            System.out.println("=== 📊 RPC模式性能统计报告 ===");
            System.out.printf("总请求数: %,d 条\n", messageCount);
            System.out.printf("测试总时长: %.3f 秒\n", totalTimeSec);
            System.out.printf("请求速率 (QPS): %,.0f req/sec\n", qps);
            System.out.println();
            
            System.out.println("⚡ RTT延迟统计 (往返时间):");
            System.out.printf("  最小延迟: %.2f μs\n", minLatency / 1000.0);
            System.out.printf("  最大延迟: %.2f μs\n", maxLatency / 1000.0);
            System.out.printf("  平均延迟: %.2f μs\n", avgLatency / 1000.0);
            System.out.printf("  P50延迟:  %.2f μs\n", p50Latency / 1000.0);
            System.out.printf("  P90延迟:  %.2f μs\n", p90Latency / 1000.0);
            System.out.printf("  P99延迟:  %.2f μs\n", p99Latency / 1000.0);
            System.out.printf("  P99.9延迟: %.2f μs\n", p999Latency / 1000.0);
            System.out.println();
            
            // 延迟抖动分析
            final double stdDev = calculateStdDev(latencies, avgLatency);
            System.out.printf("📊 延迟抖动分析:\n");
            System.out.printf("  标准差: %.2f μs\n", stdDev / 1000.0);
            System.out.printf("  抖动系数: %.2f%% (标准差/平均值)\n", (stdDev / avgLatency) * 100);
            
            // 性能评估
            if (avgLatency < 5000) {
                System.out.println("🚀 延迟评估: 优秀 (< 5μs)!");
            } else if (avgLatency < 20000) {
                System.out.println("✅ 延迟评估: 良好 (< 20μs)!");
            } else if (avgLatency < 100000) {
                System.out.println("⚠️ 延迟评估: 可接受 (< 100μs)!");
            } else {
                System.out.println("❌ 延迟评估: 需要优化!");
            }
            
            System.out.println("\n测试完成! 🎉");
        }
        
        private double calculateStdDev(List<Long> values, double mean) {
            double sum = 0.0;
            for (long value : values) {
                sum += Math.pow(value - mean, 2);
            }
            return Math.sqrt(sum / values.size());
        }
    }
    
    /**
     * 打印使用说明
     */
    private static void printUsage() {
        System.out.println("用法: java AeronRpcTest [选项]");
        System.out.println();
        System.out.println("选项:");
        System.out.printf("  -count <数量>       目标消息数量 (默认: %,d)\n", DEFAULT_MESSAGE_COUNT);
        System.out.println("  -transport <类型>   传输方式: UDP 或 IPC (默认: UDP)");
        System.out.println("  -h, --help         显示此帮助信息");
        System.out.println();
        System.out.println("传输方式说明:");
        System.out.println("  UDP: 使用UDP网络传输 (跨机器支持)");
        System.out.println("  IPC: 使用进程间通信 (本机内极低延迟)");
        System.out.println();
        System.out.println("示例:");
        System.out.println("  java AeronRpcTest                              # 使用UDP，默认10万请求");
        System.out.println("  java AeronRpcTest -transport IPC               # 使用IPC，默认10万请求");
        System.out.println("  java AeronRpcTest -count 50000 -transport UDP  # 使用UDP，5万请求");
        System.out.println("  java AeronRpcTest -count 200000 -transport IPC # 使用IPC，20万请求");
    }
}
