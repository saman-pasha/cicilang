%% ccllib's <chrono.pl> (phase 1c): a small clock and the durations over C's monotonic clock. `nanos_of(n)',
%% `millis_of(n)' and `seconds_of(n)' make a duration in nanoseconds, milliseconds or seconds; `count_of(d)' gives its
%% count; `duration_cast_millis(d)' and `duration_cast_seconds(d)' convert; `now_nanos()' and `now_millis()' read the
%% clock; `sleep_for_millis(n)' waits. The unit is a long long nanosecond count, so a duration is a plain value.
:- ensure_loaded(library(ccllib/ccllib)).
ccl_macro_nanos_of(N, E) :- ccl_c_expr("((long long)(@N))", ['N' = expr(N)], E).
ccl_macro_millis_of(N, E) :- ccl_c_expr("((long long)(@N) * 1000000LL)", ['N' = expr(N)], E).
ccl_macro_seconds_of(N, E) :- ccl_c_expr("((long long)(@N) * 1000000000LL)", ['N' = expr(N)], E).
ccl_macro_count_of(D, E) :- ccl_c_expr("((long long)(@D))", ['D' = expr(D)], E).
ccl_macro_duration_cast_millis(D, E) :- ccl_c_expr("((long long)(@D) / 1000000LL)", ['D' = expr(D)], E).
ccl_macro_duration_cast_seconds(D, E) :- ccl_c_expr("((long long)(@D) / 1000000000LL)", ['D' = expr(D)], E).
ccl_macro_now_nanos(E) :- ccl_c_expr("ccllib_chrono_now_nanos()", [], E).
ccl_macro_now_millis(E) :- ccl_c_expr("(ccllib_chrono_now_nanos() / 1000000LL)", [], E).
ccl_macro_sleep_for_millis(N, S) :- ccl_c_stmts("ccllib_chrono_sleep_millis(@N);", ['N' = expr(N)], S).
