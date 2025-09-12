package com.xsyphon.aeron;

import io.aeron.Aeron;
import io.aeron.Subscription;
import io.aeron.driver.MediaDriver;
import io.aeron.logbuffer.FragmentHandler;
import io.aeron.logbuffer.Header;
import org.agrona.DirectBuffer;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * 简单的Aeron订阅者示例
 * 用于外汇交易系统的基础消息接收测试
 */
public class SimpleForexSubscriber {
    private static final String CHANNEL = "aeron:udp?endpoint=localhost:20121";
    private static final int STREAM_ID = 1001;
    private static final int FRAGMENT_COUNT_LIMIT = 10;

    public static void main(String[] args) {
        System.out.println("Forex Subscriber - 订阅外汇报价数据: " + CHANNEL + " 流ID: " + STREAM_ID);
        
        final AtomicBoolean running = new AtomicBoolean(true);
        
        // 注册关闭钩子
        Runtime.getRuntime().addShutdownHook(new Thread(() -> running.set(false)));
        
        // 连接到外部MediaDriver
        try {
            final Aeron.Context ctx = new Aeron.Context();

            // 创建消息处理器
            final FragmentHandler fragmentHandler = new ForexQuoteHandler();

            // 连接到Aeron并创建订阅者
            try (Aeron aeron = Aeron.connect(ctx);
                 Subscription subscription = aeron.addSubscription(CHANNEL, STREAM_ID)) {

                System.out.println("正在等待外汇报价数据...");
                
                // 主循环：持续轮询消息
                while (running.get()) {
                    final int fragmentsRead = subscription.poll(fragmentHandler, FRAGMENT_COUNT_LIMIT);
                    
                    if (fragmentsRead == 0) {
                        // 如果没有新消息，短暂休眠避免空转
                        Thread.yield();
                    }
                }

                System.out.println("订阅者正在关闭...");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 外汇报价消息处理器
     */
    private static class ForexQuoteHandler implements FragmentHandler {
        private int messageCount = 0;

        @Override
        public void onFragment(DirectBuffer buffer, int offset, int length, Header header) {
            messageCount++;
            
            // 解析消息内容
            final byte[] data = new byte[length];
            buffer.getBytes(offset, data);
            final String message = new String(data);
            
            System.out.println("接收到外汇报价 #" + messageCount + ": " + message);
            
            // 解析外汇报价数据
            parseForexQuote(message);
        }
        
        private void parseForexQuote(String message) {
            try {
                if (message.startsWith("FX_QUOTE|")) {
                    String[] parts = message.split("\\|");
                    if (parts.length >= 5) {
                        String pair = parts[1];
                        double bid = Double.parseDouble(parts[2]);
                        double ask = Double.parseDouble(parts[3]);
                        long timestamp = Long.parseLong(parts[4]);
                        double spread = ask - bid;
                        
                        System.out.printf("  -> 货币对: %s, 买价: %.5f, 卖价: %.5f, 点差: %.5f, 时间戳: %d%n", 
                            pair, bid, ask, spread, timestamp);
                    }
                }
            } catch (Exception e) {
                System.err.println("解析外汇报价失败: " + e.getMessage());
            }
        }
    }
}
