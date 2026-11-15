/* the clock of <chrono.pl> (phase 1c): POSIX's monotonic clock through clock_gettime */
#ifndef _CICILANG_CCLLIB_CHRONO_PL_H
#define _CICILANG_CCLLIB_CHRONO_PL_H
#include <time.h>
static inline long long ccllib_chrono_now_nanos(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (long long)t.tv_sec * 1000000000LL + (long long)t.tv_nsec;
}
static inline void ccllib_chrono_sleep_millis(long long n) {
    struct timespec t;
    if (n < 0) n = 0;
    t.tv_sec = (time_t)(n / 1000);
    t.tv_nsec = (long)((n % 1000) * 1000000LL);
    nanosleep(&t, 0);
}
#endif
