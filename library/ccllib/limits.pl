%% ccllib's <limits.pl> (phase 1c): C++'s std::numeric_limits as a type macro, `numeric_limits<int> n;' and the
%% instance's functions: max(n), min(n), lowest(n), epsilon(n), infinity(n), quiet_NaN(n), digits(n), digits10(n),
%% is_signed(n), is_integer(n), is_iec559(n). C++ writes `std::numeric_limits<int>::max()'; C has no member call, so
%% the instance is named and its function is called, as every ccllib instance is. A bool's limits are C++'s, max 1, min
%% 0, digits 1 and no sign (1.6.4: they were a signed 8-bit type's, min true, digits 7 and is_signed 1).
:- ensure_loaded(library(ccllib/ccllib)).
type_numeric_limits([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(numeric_limits, [T], N),
    ccl_c_items("typedef struct @N { char unused; } @N;", ['N' = name(N)], Items).
fn_numeric_limits(Name, [T], Items) :- ccl_instance_name(numeric_limits, [T], N),
    ccllib_limits_fn(Name, T, Text, Hs),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)|Hs], Items).

%% an integer's value is a C macro of its width, so a 64-bit unsigned maximum needs no Prolog integer past 64 bits
ccllib_limits_fn(Name, T, Text, Hs) :- ccllib_limits_bool(T), !, ccllib_limits_bool_fn(Name, Text, Hs).
ccllib_limits_fn(max, T, "@T @{N}_max(const @N *n) { (void)n; return @X; }", ['X' = expr(E)]) :- ccllib_limits_value(max, T, E), !.
ccllib_limits_fn(min, T, "@T @{N}_min(const @N *n) { (void)n; return @X; }", ['X' = expr(E)]) :- ccllib_limits_value(min, T, E), !.
ccllib_limits_fn(lowest, T, "@T @{N}_lowest(const @N *n) { (void)n; return @X; }", ['X' = expr(E)]) :- ccllib_limits_value(lowest, T, E), !.
ccllib_limits_fn(epsilon, T, "@T @{N}_epsilon(const @N *n) { (void)n; return @X; }", ['X' = expr(E)]) :- ccllib_limits_value(epsilon, T, E), !.
ccllib_limits_fn(infinity, T, "@T @{N}_infinity(const @N *n) { (void)n; return @X; }", ['X' = expr(E)]) :- ccllib_limits_value(infinity, T, E), !.
ccllib_limits_fn(quiet_NaN, T, "@T @{N}_quiet_NaN(const @N *n) { (void)n; return @X; }", ['X' = expr(E)]) :- ccllib_limits_value(quiet_NaN, T, E), !.
ccllib_limits_fn(digits, T, "int @{N}_digits(const @N *n) { (void)n; return @K; }", ['K' = expr(K)]) :- ccllib_limits_digits(T, K).
ccllib_limits_fn(digits10, T, "int @{N}_digits10(const @N *n) { (void)n; return @K; }", ['K' = expr(K)]) :- ccllib_limits_digits10(T, K).
ccllib_limits_fn(is_signed, T, "int @{N}_is_signed(const @N *n) { (void)n; return @K; }", ['K' = name(K)]) :- ccllib_limits_signed(T, K).
ccllib_limits_fn(is_integer, T, "int @{N}_is_integer(const @N *n) { (void)n; return @K; }", ['K' = name(K)]) :-
    ( ccl_is_integer(T) -> K = '1' ; K = '0' ).
ccllib_limits_fn(is_iec559, T, "int @{N}_is_iec559(const @N *n) { (void)n; return @K; }", ['K' = name(K)]) :-
    ( ccl_is_float(T) -> K = '1' ; K = '0' ).

ccllib_limits_value(max, T, call(id(ccllib_limits_smax), [int(B)])) :- ccl_is_integer(T), ccllib_limits_int_width(T, B, true), !.
ccllib_limits_value(min, T, call(id(ccllib_limits_smin), [int(B)])) :- ccl_is_integer(T), ccllib_limits_int_width(T, B, true), !.
ccllib_limits_value(max, T, call(id(ccllib_limits_umax), [int(B)])) :- ccl_is_integer(T), ccllib_limits_int_width(T, B, false), !.
ccllib_limits_value(min, T, int(0)) :- ccl_is_integer(T), !.
ccllib_limits_value(lowest, T, E) :- ccllib_limits_value(min, T, E), !.
ccllib_limits_value(epsilon, T, int(0)) :- ccl_is_integer(T), !.
ccllib_limits_value(infinity, T, int(0)) :- ccl_is_integer(T), !.
ccllib_limits_value(quiet_NaN, T, int(0)) :- ccl_is_integer(T), !.
ccllib_limits_value(max, T, call(id(F), [])) :- ccl_is_float(T), ccllib_limits_float_fn(T, max, F), !.
ccllib_limits_value(min, T, call(id(F), [])) :- ccl_is_float(T), ccllib_limits_float_fn(T, min, F), !.
ccllib_limits_value(lowest, T, neg(call(id(F), []))) :- ccl_is_float(T), ccllib_limits_float_fn(T, max, F), !.
ccllib_limits_value(epsilon, T, call(id(F), [])) :- ccl_is_float(T), ccllib_limits_float_fn(T, epsilon, F), !.
ccllib_limits_value(infinity, T, call(id(F), [])) :- ccl_is_float(T), ccllib_limits_float_fn(T, infinity, F), !.
ccllib_limits_value(quiet_NaN, T, call(id(F), [])) :- ccl_is_float(T), ccllib_limits_float_fn(T, quiet_NaN, F), !.

%% a bool: max true, min and lowest false, one digit, no sign ([numeric.special]'s bool)
ccllib_limits_bool(T) :- catch(ccl_resolve_type(T, base(_, W)), _, fail), ( memberchk('_Bool', W) ; memberchk(bool, W) ), !.
ccllib_limits_bool_fn(max, "@T @{N}_max(const @N *n) { (void)n; return 1; }", []).
ccllib_limits_bool_fn(min, "@T @{N}_min(const @N *n) { (void)n; return 0; }", []).
ccllib_limits_bool_fn(lowest, "@T @{N}_lowest(const @N *n) { (void)n; return 0; }", []).
ccllib_limits_bool_fn(epsilon, "@T @{N}_epsilon(const @N *n) { (void)n; return 0; }", []).
ccllib_limits_bool_fn(infinity, "@T @{N}_infinity(const @N *n) { (void)n; return 0; }", []).
ccllib_limits_bool_fn(quiet_NaN, "@T @{N}_quiet_NaN(const @N *n) { (void)n; return 0; }", []).
ccllib_limits_bool_fn(digits, "int @{N}_digits(const @N *n) { (void)n; return 1; }", []).
ccllib_limits_bool_fn(digits10, "int @{N}_digits10(const @N *n) { (void)n; return 0; }", []).
ccllib_limits_bool_fn(is_signed, "int @{N}_is_signed(const @N *n) { (void)n; return 0; }", []).
ccllib_limits_bool_fn(is_integer, "int @{N}_is_integer(const @N *n) { (void)n; return 1; }", []).
ccllib_limits_bool_fn(is_iec559, "int @{N}_is_iec559(const @N *n) { (void)n; return 0; }", []).

ccllib_limits_int_width(T, B, S) :- ccl_size_of(T, Bytes), B is Bytes * 8, ( ccl_int_rank(T, _, true) -> S = false ; S = true ).
ccllib_limits_float_fn(T, K, F) :- ccl_resolve_type(T, base(_, S)),
    ( memberchk(float, S) -> P = f ; memberchk(long, S) -> P = ld ; P = d ),
    atomic_list_concat(['ccllib_limits_', K, '_', P], F).

ccllib_limits_digits(T, int(D)) :- ccl_is_integer(T), ccllib_limits_int_width(T, B, S), ( S == true -> D is B - 1 ; D = B ), !.
ccllib_limits_digits(T, call(id(F), [])) :- ccl_is_float(T), ccllib_limits_float_fn(T, digits, F).
ccllib_limits_digits10(T, int(D10)) :- ccl_is_integer(T), ccllib_limits_int_width(T, B, S), ( S == true -> D is B - 1 ; D = B ), D10 is (D * 30103) // 100000, !.
ccllib_limits_digits10(T, call(id(F), [])) :- ccl_is_float(T), ccllib_limits_float_fn(T, digits10, F).
ccllib_limits_signed(T, K) :- ccl_is_integer(T), ccllib_limits_int_width(T, _, S), ( S == true -> K = '1' ; K = '0' ), !.
ccllib_limits_signed(T, '1') :- ccl_is_float(T).
