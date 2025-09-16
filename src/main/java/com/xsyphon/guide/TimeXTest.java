package com.xsyphon.guide;

import com.xsyphon.javaext.TimeX;

/**
 * Simple test class to verify TimeX JNI library functionality
 * Run with: java -cp xsyphon-aeron-forex.jar com.xsyphon.guide.TimeXTest
 */
public class TimeXTest {

    public static void main(String[] args) {
        System.out.println("=== TimeX JNI Library Test ===");
        
        // Test JNI method
        long jniTime = TimeX.unixNanoJNI();
        if (jniTime != -1) {
            System.out.println("✅ TimeX.unixNanoJNI() is working");
            System.out.println("Current Unix nanosecond timestamp: " + jniTime);
            
            // Convert to human readable time
            long millis = jniTime / 1_000_000;
            java.util.Date date = new java.util.Date(millis);
            System.out.println("Human readable time: " + date);
            
            // Show nano precision part
            long nanosPart = jniTime % 1_000_000;
            System.out.println("Nanosecond precision: " + nanosPart + " ns");
            
        } else {
            System.out.println("❌ TimeX.unixNanoJNI() failed - returned -1");
            System.exit(1);
        }
        
        // Test multiple calls to verify consistency
        System.out.println("\n=== Consistency Test (10 calls) ===");
        long lastTime = 0;
        for (int i = 0; i < 10; i++) {
            long currentTime = TimeX.unixNanoJNI();
            System.out.println("Call " + (i+1) + ": " + currentTime);
            
            if (lastTime > 0) {
                long diff = currentTime - lastTime;
                System.out.println("  Time diff: " + diff + " ns (" + String.format("%.3f", diff/1000000.0) + " ms)");
            }
            lastTime = currentTime;
            
            try {
                Thread.sleep(1); // 1ms sleep
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        
        // 添加预热测试
        System.out.println("\n=== Warmup Test (预热后再测试) ===");
        // 预热调用
        for (int i = 0; i < 1000; i++) {
            TimeX.unixNanoJNI();
        }
        
        System.out.println("After 1000 warmup calls:");
        lastTime = 0;
        for (int i = 0; i < 5; i++) {
            long currentTime = TimeX.unixNanoJNI();
            System.out.println("Warmed Call " + (i+1) + ": " + currentTime);
            
            if (lastTime > 0) {
                long diff = currentTime - lastTime;
                System.out.println("  Time diff: " + diff + " ns (" + String.format("%.3f", diff/1000000.0) + " ms)");
            }
            lastTime = currentTime;
            
            try {
                Thread.sleep(1); // 1ms sleep
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        
        System.out.println("\n✅ TimeX JNI library test completed successfully");
    }
}
