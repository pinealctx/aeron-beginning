package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Publication;
import io.aeron.driver.MediaDriver;
import org.agrona.BufferUtil;
import org.agrona.concurrent.UnsafeBuffer;

import java.util.concurrent.TimeUnit;

/**
 * 简单的Aeron发布者示例
 * 用于外汇交易系统的基础消息传输测试
 */
public class SimpleForexPublisher {
    private static final String CHANNEL = "aeron:udp?endpoint=localhost:20121";
    private static final int STREAM_ID = 1001;
    private static final int NUMBER_OF_MESSAGES = 10;

    public static void main(String[] args) throws InterruptedException {
        System.out.println("Forex Publisher - 发布外汇报价数据到: " + CHANNEL + " 流ID: " + STREAM_ID);

        // 连接到外部MediaDriver (不启动嵌入式)
        final Aeron.Context ctx = new Aeron.Context();
        
        // 连接到Aeron并创建发布者
        try (Aeron aeron = Aeron.connect(ctx);
             Publication publication = aeron.addPublication(CHANNEL, STREAM_ID)) {

                final UnsafeBuffer buffer = new UnsafeBuffer(BufferUtil.allocateDirectAligned(256, 64));

                // 模拟外汇报价数据
                String[] forexPairs = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD"};
                
                for (int i = 0; i < NUMBER_OF_MESSAGES; i++) {
                    String forexPair = forexPairs[i % forexPairs.length];
                    double bid = 1.0500 + (Math.random() * 0.1);
                    double ask = bid + 0.0010;
                    long timestamp = System.currentTimeMillis();
                    
                    String message = String.format("FX_QUOTE|%s|%.5f|%.5f|%d", 
                        forexPair, bid, ask, timestamp);

                    System.out.print("发送外汇报价 " + (i + 1) + "/" + NUMBER_OF_MESSAGES + ": " + message + " - ");

                    final int length = buffer.putStringWithoutLengthAscii(0, message);
                    final long position = publication.offer(buffer, 0, length);

                    if (position > 0) {
                        System.out.println("成功!");
                    } else if (position == Publication.BACK_PRESSURED) {
                        System.out.println("失败 - 背压");
                    } else if (position == Publication.NOT_CONNECTED) {
                        System.out.println("失败 - 未连接到订阅者");
                    } else if (position == Publication.ADMIN_ACTION) {
                        System.out.println("失败 - 管理操作");
                    } else if (position == Publication.CLOSED) {
                        System.out.println("失败 - 发布者已关闭");
                        break;
                    } else {
                        System.out.println("失败 - 未知原因: " + position);
                    }

                    if (!publication.isConnected()) {
                        System.out.println("警告: 没有检测到活跃订阅者");
                    }

                    Thread.sleep(TimeUnit.SECONDS.toMillis(1));
                }

                System.out.println("外汇报价发送完成!");
                System.out.println("等待5秒以便订阅者处理...");
                Thread.sleep(5000);
        }
    }
}
