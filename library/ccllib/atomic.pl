%% ccllib's <atomic.pl> (phase 2): C++'s std::atomic<T> and std::atomic_flag over clang's atomic builtins.
%%
%%   #include <atomic.pl>
%%   atomic<int> a;                     born zero; `atomic<int> a = {5};' makes one with a value
%%   store(a, 5);  n := load(a);  x := exchange(a, 7);
%%   n := fetch_add(a, 3);  n := fetch_sub(a, 1);
%%   n := fetch_and(a, 6);  n := fetch_or(a, 1);  n := fetch_xor(a, 2);
%%   int expected = 7;  ok := compare_exchange_strong(a, &expected, 9);
%%   if (is_lock_free(a)) ...;
%%   atomic_flag<> f;  test_and_set(f);  clear(f);
%%
%% The type is a struct of one T member, and each function is clang's atomic builtin of that name over it; every
%% operation is sequentially consistent, and `store(a, v)' is not the `a = v' that sequence points a C11 atomic's
%% value. What differs from C++:
%%   `atomic<T> a = 0;' is not read: the type is a struct of one member, so `atomic<T> a = {0};' is, and a bare
%%     `atomic<T> a;' is born zero;
%%   compare_exchange_strong takes the address of the expected value, `compare_exchange_strong(a, &e, d)', since C
%%     has no reference parameter; compare_exchange_weak is the same here (x86 has no spurious failure);
%%   every operation is seq_cst; there is no explicit-order form and no memory_order argument;
%%   `fetch_add' and the other fetch forms are for an integer T; a floating T has load, store and exchange;
%%   a T that holds a pointer is refused: an atomic of a struct with an owner is no atomic value.
:- ensure_loaded(library(ccllib/ccllib)).
%% C++23's <stdatomic.h> IS NO <stdatomic.h> FOR US (1.5.0): libc++ writes `#define _Atomic(T) std-atomic<T>' there, an
%% alias of std::atomic<T> -- a class of the library's with no C11 atomic in it -- so `_Atomic(int)' in this file's C text
%% became that class, and cicilang++ refused `no_member(a_, base([const], [typedef('atomic.int')]))' of every function.
%% The object is a struct of one `T' member instead, and every operation is clang's `__atomic_*' builtin over it
%% (`__atomic_load_n', `__atomic_exchange_n', `__atomic_fetch_add' and kin -- the compiler's own words, atomic over a
%% plain object, the order 5 `__ATOMIC_SEQ_CST'). What a C compiler's <stdatomic.h> calls an `_Atomic' object, this file
%% has as a plain one, its operations atomic still.
type_atomic([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(atomic, [T], N),
    ccllib_atomic_scalar('an atomic''s object', T),
    ccl_c_items("typedef struct @N { @T a_; } @N;", ['N' = name(N), 'T' = type(T)], Items).
fn_atomic(Name, [T], Items) :- ccl_instance_name(atomic, [T], N), ccllib_atomic_fn(Name, T, Text), ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).

%% the object is a scalar: an integer, a floating number, a pointer or an enum
ccllib_atomic_scalar(What, T) :- ccl_holds_pointer(T), !,
    ccl_arg_words([T], [W]), atomic_list_concat([What, ' is a scalar, and ', W, ' holds a pointer'], M), ccl_macro_error(M).
ccllib_atomic_scalar(What, T) :-
    ( ccl_is_integer(T) ; ccl_is_float(T) ; catch(ccl_resolve_type(T, base(_, [enum(_, _)])), _, false) ), !.
ccllib_atomic_scalar(What, _) :- atomic_list_concat([What, ' is an integer, a floating number or an enum'], M), ccl_macro_error(M).

ccllib_atomic_fn(load, T, "@T @{N}_load(const @N *a) { return __atomic_load_n(&a->a_, 5); }").
ccllib_atomic_fn(store, T, "void @{N}_store(@N *a, @T x) { __atomic_store_n(&a->a_, x, 5); }").
ccllib_atomic_fn(exchange, T, "@T @{N}_exchange(@N *a, @T x) { return __atomic_exchange_n(&a->a_, x, 5); }").
ccllib_atomic_fn(is_lock_free, T, "int @{N}_is_lock_free(const @N *a) { (void)a; return 1; }").
ccllib_atomic_fn(fetch_add, T, "@T @{N}_fetch_add(@N *a, @T x) { return __atomic_fetch_add(&a->a_, x, 5); }") :- ccl_is_integer(T).
ccllib_atomic_fn(fetch_sub, T, "@T @{N}_fetch_sub(@N *a, @T x) { return __atomic_fetch_sub(&a->a_, x, 5); }") :- ccl_is_integer(T).
ccllib_atomic_fn(fetch_and, T, "@T @{N}_fetch_and(@N *a, @T x) { return __atomic_fetch_and(&a->a_, x, 5); }") :- ccl_is_integer(T).
ccllib_atomic_fn(fetch_or, T, "@T @{N}_fetch_or(@N *a, @T x) { return __atomic_fetch_or(&a->a_, x, 5); }") :- ccl_is_integer(T).
ccllib_atomic_fn(fetch_xor, T, "@T @{N}_fetch_xor(@N *a, @T x) { return __atomic_fetch_xor(&a->a_, x, 5); }") :- ccl_is_integer(T).
ccllib_atomic_fn(compare_exchange_strong, T, "int @{N}_compare_exchange_strong(@N *a, @T *e, @T d) { return __atomic_compare_exchange(&a->a_, e, &d, 0, 5, 5); }").
ccllib_atomic_fn(compare_exchange_weak, T, "int @{N}_compare_exchange_weak(@N *a, @T *e, @T d) { return __atomic_compare_exchange(&a->a_, e, &d, 0, 5, 5); }").

%% -- atomic_flag: no type argument, tested and set as one byte
type_atomic_flag([], base([], [typedef(N)]), Items) :- ccl_instance_name(atomic_flag, [], N),
    ccl_c_items("typedef struct @N { _Bool a_; } @N;", ['N' = name(N)], Items).
fn_atomic_flag(test_and_set, [], Items) :- ccl_instance_name(atomic_flag, [], N),
    ccl_c_items("int @{N}_test_and_set(@N *f) { return __atomic_exchange_n(&f->a_, 1, 5); }", ['N' = name(N)], Items).
fn_atomic_flag(clear, [], Items) :- ccl_instance_name(atomic_flag, [], N),
    ccl_c_items("void @{N}_clear(@N *f) { __atomic_store_n(&f->a_, 0, 5); }", ['N' = name(N)], Items).
