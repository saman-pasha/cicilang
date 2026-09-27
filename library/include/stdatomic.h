/* cicili-lang's freestanding <stdatomic.h> (C11 7.17): written over the compiler's own `__c11_atomic_*'
   builtins, as clang's is; `_Atomic(T)' is the reader's, and every builtin is one LLVM instruction. */
#ifndef __CCL_STDATOMIC_H
#define __CCL_STDATOMIC_H
#include <stddef.h>
#define ATOMIC_BOOL_LOCK_FREE 2
#define ATOMIC_CHAR_LOCK_FREE 2
#define ATOMIC_CHAR16_T_LOCK_FREE 2
#define ATOMIC_CHAR32_T_LOCK_FREE 2
#define ATOMIC_WCHAR_T_LOCK_FREE 2
#define ATOMIC_SHORT_LOCK_FREE 2
#define ATOMIC_INT_LOCK_FREE 2
#define ATOMIC_LONG_LOCK_FREE 2
#define ATOMIC_LLONG_LOCK_FREE 2
#define ATOMIC_POINTER_LOCK_FREE 2
#define ATOMIC_FLAG_INIT { 0 }
#define ATOMIC_VAR_INIT(value) (value)
typedef enum memory_order {
    memory_order_relaxed = __ATOMIC_RELAXED, memory_order_consume = __ATOMIC_CONSUME, memory_order_acquire = __ATOMIC_ACQUIRE,
    memory_order_release = __ATOMIC_RELEASE, memory_order_acq_rel = __ATOMIC_ACQ_REL, memory_order_seq_cst = __ATOMIC_SEQ_CST
} memory_order;
#define kill_dependency(y) (y)
#define atomic_thread_fence(order) __c11_atomic_thread_fence(order)
#define atomic_signal_fence(order) __c11_atomic_signal_fence(order)
#define atomic_is_lock_free(obj) __c11_atomic_is_lock_free(sizeof(*(obj)))
typedef _Atomic(_Bool) atomic_bool;
typedef _Atomic(char) atomic_char;
typedef _Atomic(signed char) atomic_schar;
typedef _Atomic(unsigned char) atomic_uchar;
typedef _Atomic(short) atomic_short;
typedef _Atomic(unsigned short) atomic_ushort;
typedef _Atomic(int) atomic_int;
typedef _Atomic(unsigned int) atomic_uint;
typedef _Atomic(long) atomic_long;
typedef _Atomic(unsigned long) atomic_ulong;
typedef _Atomic(long long) atomic_llong;
typedef _Atomic(unsigned long long) atomic_ullong;
typedef _Atomic(__CHAR16_TYPE__) atomic_char16_t;
typedef _Atomic(__CHAR32_TYPE__) atomic_char32_t;
typedef _Atomic(__WCHAR_TYPE__) atomic_wchar_t;
typedef _Atomic(__INT_LEAST8_TYPE__) atomic_int_least8_t;
typedef _Atomic(__UINT_LEAST8_TYPE__) atomic_uint_least8_t;
typedef _Atomic(__INT_LEAST16_TYPE__) atomic_int_least16_t;
typedef _Atomic(__UINT_LEAST16_TYPE__) atomic_uint_least16_t;
typedef _Atomic(__INT_LEAST32_TYPE__) atomic_int_least32_t;
typedef _Atomic(__UINT_LEAST32_TYPE__) atomic_uint_least32_t;
typedef _Atomic(__INT_LEAST64_TYPE__) atomic_int_least64_t;
typedef _Atomic(__UINT_LEAST64_TYPE__) atomic_uint_least64_t;
typedef _Atomic(__INT_FAST8_TYPE__) atomic_int_fast8_t;
typedef _Atomic(__UINT_FAST8_TYPE__) atomic_uint_fast8_t;
typedef _Atomic(__INT_FAST16_TYPE__) atomic_int_fast16_t;
typedef _Atomic(__UINT_FAST16_TYPE__) atomic_uint_fast16_t;
typedef _Atomic(__INT_FAST32_TYPE__) atomic_int_fast32_t;
typedef _Atomic(__UINT_FAST32_TYPE__) atomic_uint_fast32_t;
typedef _Atomic(__INT_FAST64_TYPE__) atomic_int_fast64_t;
typedef _Atomic(__UINT_FAST64_TYPE__) atomic_uint_fast64_t;
typedef _Atomic(__INTPTR_TYPE__) atomic_intptr_t;
typedef _Atomic(__UINTPTR_TYPE__) atomic_uintptr_t;
typedef _Atomic(__SIZE_TYPE__) atomic_size_t;
typedef _Atomic(__PTRDIFF_TYPE__) atomic_ptrdiff_t;
typedef _Atomic(__INTMAX_TYPE__) atomic_intmax_t;
typedef _Atomic(__UINTMAX_TYPE__) atomic_uintmax_t;
#define atomic_init(obj, value) __c11_atomic_init(obj, value)
#define atomic_store(object, desired) __c11_atomic_store(object, desired, __ATOMIC_SEQ_CST)
#define atomic_store_explicit __c11_atomic_store
#define atomic_load(object) __c11_atomic_load(object, __ATOMIC_SEQ_CST)
#define atomic_load_explicit __c11_atomic_load
#define atomic_exchange(object, desired) __c11_atomic_exchange(object, desired, __ATOMIC_SEQ_CST)
#define atomic_exchange_explicit __c11_atomic_exchange
#define atomic_compare_exchange_strong(object, expected, desired) __c11_atomic_compare_exchange_strong(object, expected, desired, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)
#define atomic_compare_exchange_strong_explicit __c11_atomic_compare_exchange_strong
#define atomic_compare_exchange_weak(object, expected, desired) __c11_atomic_compare_exchange_weak(object, expected, desired, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)
#define atomic_compare_exchange_weak_explicit __c11_atomic_compare_exchange_weak
#define atomic_fetch_add(object, operand) __c11_atomic_fetch_add(object, operand, __ATOMIC_SEQ_CST)
#define atomic_fetch_add_explicit __c11_atomic_fetch_add
#define atomic_fetch_sub(object, operand) __c11_atomic_fetch_sub(object, operand, __ATOMIC_SEQ_CST)
#define atomic_fetch_sub_explicit __c11_atomic_fetch_sub
#define atomic_fetch_or(object, operand) __c11_atomic_fetch_or(object, operand, __ATOMIC_SEQ_CST)
#define atomic_fetch_or_explicit __c11_atomic_fetch_or
#define atomic_fetch_xor(object, operand) __c11_atomic_fetch_xor(object, operand, __ATOMIC_SEQ_CST)
#define atomic_fetch_xor_explicit __c11_atomic_fetch_xor
#define atomic_fetch_and(object, operand) __c11_atomic_fetch_and(object, operand, __ATOMIC_SEQ_CST)
#define atomic_fetch_and_explicit __c11_atomic_fetch_and
typedef struct atomic_flag { atomic_bool _Value; } atomic_flag;
#define atomic_flag_test_and_set(object) __c11_atomic_exchange(&(object)->_Value, 1, __ATOMIC_SEQ_CST)
#define atomic_flag_test_and_set_explicit(object, order) __c11_atomic_exchange(&(object)->_Value, 1, order)
#define atomic_flag_clear(object) __c11_atomic_store(&(object)->_Value, 0, __ATOMIC_SEQ_CST)
#define atomic_flag_clear_explicit(object, order) __c11_atomic_store(&(object)->_Value, 0, order)
#endif
