/* what <mutex.pl>'s C text calls (phase 2, 1.6.0): POSIX's threads, its mutex and its condition variable, which every C
   library has. A mutex holds a pthread_mutex_t; a barrier and a latch hold a mutex and a condition in words of their
   size, and a guard and a lock hold a mutex's address as a uintptr_t (1.6.5). */
#ifndef _CICILANG_CCLLIB_MUTEX_PL_H
#define _CICILANG_CCLLIB_MUTEX_PL_H
#include <pthread.h>
#include <stdint.h>
#include <string.h>
typedef pthread_mutex_t mutex_impl;
#endif
