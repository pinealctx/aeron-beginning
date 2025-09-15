#include "TimeX.h"
#include <cstdint>

// 平台特定的头文件
#ifdef _WIN32
    #include <windows.h>
#elif __APPLE__
    #include <time.h>
    #include <mach/mach_time.h>
    #include <sys/time.h>
#else
    #include <time.h>
    #include <sys/time.h>
#endif

/*
 * 跨平台获取Unix纳秒时间戳的JNI实现
 * 支持Linux (x86_64/ARM64), macOS (Intel/ARM64), Windows (x86_64/ARM64)
 */
JNIEXPORT jlong JNICALL Java_com_xsyphon_timex_TimeX_jniUnixNano
  (JNIEnv *env, jclass clazz) {
    
#ifdef _WIN32
    // Windows 实现
    FILETIME ft;
    GetSystemTimePreciseAsFileTime(&ft);
    
    // 将 FILETIME 转换为 64 位整数
    uint64_t winTime = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    
    // Windows FILETIME 从 1601年1月1日 开始，以100纳秒为单位
    // Unix时间戳从 1970年1月1日 开始
    // 1601年到1970年的差值：116444736000000000 * 100ns
    uint64_t unixTime = (winTime - 116444736000000000ULL) * 100ULL;
    
    return (jlong)unixTime;
    
#elif __APPLE__
    // macOS 实现
    struct timespec ts;
    
    // macOS 10.12+ 支持 clock_gettime
    #ifdef CLOCK_REALTIME
        if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
            return (jlong)(ts.tv_sec * 1000000000LL + ts.tv_nsec);
        }
    #endif
    
    // 降级到 gettimeofday (微秒精度)
    struct timeval tv;
    if (gettimeofday(&tv, nullptr) == 0) {
        return (jlong)(tv.tv_sec * 1000000000LL + tv.tv_usec * 1000LL);
    }
    
    // 最后降级到 mach_absolute_time + 基准时间
    static uint64_t start_time = 0;
    static uint64_t start_abs = 0;
    static mach_timebase_info_data_t timebase_info = {0, 0};
    
    if (start_time == 0) {
        // 初始化基准时间
        struct timeval tv_init;
        gettimeofday(&tv_init, nullptr);
        start_time = tv_init.tv_sec * 1000000000ULL + tv_init.tv_usec * 1000ULL;
        start_abs = mach_absolute_time();
        mach_timebase_info(&timebase_info);
    }
    
    uint64_t abs_time = mach_absolute_time();
    uint64_t elapsed_abs = abs_time - start_abs;
    uint64_t elapsed_nanos = elapsed_abs * timebase_info.numer / timebase_info.denom;
    
    return (jlong)(start_time + elapsed_nanos);
    
#else
    // Linux 实现 (支持 x86_64 和 ARM64)
    struct timespec ts;
    
    // 使用 CLOCK_REALTIME 获取墙上时钟时间
    if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
        return (jlong)(ts.tv_sec * 1000000000LL + ts.tv_nsec);
    }
    
    // 降级到 gettimeofday
    struct timeval tv;
    if (gettimeofday(&tv, nullptr) == 0) {
        return (jlong)(tv.tv_sec * 1000000000LL + tv.tv_usec * 1000LL);
    }
    
    // 如果都失败了，返回错误
    return -1;
#endif
}
