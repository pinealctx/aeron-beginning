package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Publication;
import io.aeron.Subscription;
import io.aeron.logbuffer.FragmentHandler;
import io.aeron.logbuffer.Header;
import org.agrona.DirectBuffer;
import org.agrona.concurrent.UnsafeBuffer;

import java.nio.ByteBuffer;

/**
 * 简单的Aeron响应服务器
 * 接收请求并立即发回响应
 * 支持UDP和IPC两种传输方式
 */
public class AeronRpcServer {
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

    public static void main(String[] args) {
        TransportType transport = TransportType.UDP; // 默认使用UDP
        
        // 解析命令行参数
        for (int i = 0; i < args.length; i++) {
            if ("-transport".equals(args[i]) && i + 1 < args.length) {
                String transportStr = args[i + 1].toUpperCase();
                try {
                    transport = TransportType.valueOf(transportStr);
                } catch (IllegalArgumentException e) {
                    System.err.println("错误: 无效的传输方式: " + args[i + 1]);
                    System.err.println("支持的传输方式: UDP, IPC");
                    System.exit(1);
                }
                i++; // 跳过参数值
            } else if ("-h".equals(args[i]) || "--help".equals(args[i])) {
                printUsage();
                System.exit(0);
            }
        }
        
        System.out.println("=== Aeron RPC服务器 ===");
        System.out.printf("传输方式: %s\n", transport.name());
        System.out.printf("监听请求: %s\n", transport.getRequestChannel());
        System.out.printf("响应通道: %s\n", transport.getResponseChannel());
        System.out.println("等待客户端连接...\n");

        try (Aeron aeron = Aeron.connect()) {
            // 创建订阅和发布
            Subscription requestSub = aeron.addSubscription(transport.getRequestChannel(), REQUEST_STREAM_ID);
            Publication responsePub = aeron.addPublication(transport.getResponseChannel(), RESPONSE_STREAM_ID);
            
            // 等待连接建立
            while (!requestSub.isConnected() || !responsePub.isConnected()) {
                Thread.sleep(1);
            }
            
            System.out.println("服务器已启动，准备处理请求...\n");
            
            // 创建请求处理器
            RequestProcessor processor = new RequestProcessor(responsePub);
            
            // 主循环 - 处理请求
            long requestCount = 0;
            while (true) {
                final int fragmentsRead = requestSub.poll(processor, 10);
                
                if (fragmentsRead > 0) {
                    requestCount += fragmentsRead;
                }
                
                // 如果没有消息，让出CPU
                if (fragmentsRead == 0) {
                    Thread.onSpinWait();
                }
            }
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    /**
     * 打印使用说明
     */
    private static void printUsage() {
        System.out.println("用法: java AeronRpcServer [选项]");
        System.out.println();
        System.out.println("选项:");
        System.out.println("  -transport <类型>   传输方式: UDP 或 IPC (默认: UDP)");
        System.out.println("  -h, --help         显示此帮助信息");
        System.out.println();
        System.out.println("传输方式说明:");
        System.out.println("  UDP: 使用UDP网络传输 (跨机器支持)");
        System.out.println("  IPC: 使用进程间通信 (本机内极低延迟)");
        System.out.println();
        System.out.println("示例:");
        System.out.println("  java AeronRpcServer                    # 使用UDP传输");
        System.out.println("  java AeronRpcServer -transport IPC     # 使用IPC传输");
    }

    private static class RequestProcessor implements FragmentHandler {
        private final Publication responsePub;
        private final UnsafeBuffer responseBuffer;

        public RequestProcessor(Publication responsePub) {
            this.responsePub = responsePub;
            this.responseBuffer = new UnsafeBuffer(ByteBuffer.allocateDirect(MESSAGE_SIZE));
        }

        @Override
        public void onFragment(DirectBuffer buffer, int offset, int length, Header header) {
            // 直接将请求数据复制到响应缓冲区（echo模式）
            responseBuffer.putBytes(0, buffer, offset, length);
            
            // 发送响应
            while (responsePub.offer(responseBuffer, 0, length) < 0) {
                Thread.onSpinWait();
            }
        }
    }
}
