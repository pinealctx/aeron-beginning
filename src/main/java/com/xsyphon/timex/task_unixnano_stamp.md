### Unix Nano Time Stamp

#### 在当前目录下`TimeX.java`文件中，帮我实现几种不同获取系统Unix纳秒时间戳的方法，类似于golang中的`time.Now().UnixNano()`，并且写一个主函数测试这些方法的性能，要求每种方法都执行一百万次，并打印出每种方法的平均执行时间（纳秒）。请确保代码简洁高效，并且包含必要的注释说明。

- 标准 Java API - Instant，类似下面代码。
  ```java
    Instant now = Instant.now();
    return now.getEpochSecond() * 1_000_000_000L + now.getNano();
  ```

- System 时间方法混合
    ```java
        // 需要在应用启动时初始化一次基准点
        private static final long SYSTEM_NANOTIME_OFFSET;
        static {
            long currentTimeMillis = System.currentTimeMillis();
            long nanoTime = System.nanoTime();
            SYSTEM_NANOTIME_OFFSET = currentTimeMillis * 1_000_000L - nanoTime;
        }

        ...

        // 获取当前Unix纳秒时间戳
          ...
          return System.nanoTime() + SYSTEM_NANOTIME_OFFSET;
    ```

- JNI 直接调用系统 clock_gettime，但这个clock_gettime是Linux的系统调用，你需要为我补上MacOS和Windows的实现，要求都能返回Unix纳秒时间戳。
  另外需要注意的是，不知道对于Amd64和ARM64架构的Linux，MacOS和Windows，JNI调用是否有区别，如果有区别请帮我处理好。

- JNA 调用，类似于JNI，不过用JNA来做。

- 优化的 System.currentTimeMillis() (仅毫秒精度)，即System.currentTimeMillis() * 1_000_000L;

- 你给了另外一种方法，但我看上去它好像精度有问题
  ```
  public class GoStyleTimeUtils {
    // 保存启动时间基准点
    private static final long WALL_TIME_OFFSET;
    private static final long MONO_TIME_OFFSET;
    
    static {
        // 初始化基准点
        WALL_TIME_OFFSET = System.currentTimeMillis() * 1_000_000L;
        MONO_TIME_OFFSET = System.nanoTime();
    }
    
    // 获取墙上时钟时间（纳秒）
    public static long wallTimeNano() {
        return System.currentTimeMillis() * 1_000_000L;
    }
    
    // 获取单调时钟时间（纳秒）
    public static long monotimeNano() {
        return System.nanoTime();
    }
    
    // Go风格的时间结构
    public static class GoTime {
        private final long wallNanos;
        private final long monoNanos;
        
        private GoTime(long wallNanos, long monoNanos) {
            this.wallNanos = wallNanos;
            this.monoNanos = monoNanos;
        }
        
        // 获取 Unix 纳秒时间戳
        public long unixNano() {
            return wallNanos;
        }
        
        // 计算与另一个时间点之间的差值（使用单调时钟）
        public long since(GoTime earlier) {
            return this.monoNanos - earlier.monoNanos;
        }
    }
    
    // 模拟 Go 的 time.Now()
    public static GoTime now() {
        long mono = System.nanoTime();
        // 使用单调时钟的偏移计算当前墙上时间，避免时钟调整的影响
        long wall = WALL_TIME_OFFSET + (mono - MONO_TIME_OFFSET);
        return new GoTime(wall, mono);
    }
    
    // 简化接口：直接获取 Unix 纳秒时间戳
    public static long unixNanoTime() {
        return now().unixNano();
    }
}

// 使用示例
public static void main(String[] args) {
    // 直接获取纳秒时间戳
    long timestamp = GoStyleTimeUtils.unixNanoTime();
    System.out.println("Unix Nano Time: " + timestamp);
    
    // Go 风格的时间测量
    GoStyleTimeUtils.GoTime start = GoStyleTimeUtils.now();
    // 执行一些操作...
    GoStyleTimeUtils.GoTime end = GoStyleTimeUtils.now();
    
    // 使用单调时钟计算持续时间（类似 Go 的 time.Since）
    long elapsed = end.since(start);
    System.out.println("Elapsed time: " + elapsed + " ns");
}
```
你帮我改进一下这个方法，确保它能正确返回Unix纳秒时间戳，并且能正确计算两个时间点之间的差值。