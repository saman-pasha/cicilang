/* what <mutex.pl>'s C text calls (phase 2, 1.6.0): POSIX's threads, its mutex and its condition variable, which every C
   library has. A mutex is a pthread_mutex_t; a guard, a lock, a barrier and a latch are structs of one. */
#ifndef _CICILANG_CCLLIB_MUTEX_PL_H
#define _CICILANG_CCLLIB_MUTEX_PL_H
#include <pthread.h>
#include <string.h>
typedef pthread_mutex_t mutex_impl;
#endif
