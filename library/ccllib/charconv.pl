%% ccllib's <charconv.pl> (phase 2): C++'s std::to_chars and std::from_chars over C's snprintf and strtod.
%%
%%   #include <charconv.pl>
%%   char buf[64];
%%   to_chars_result r = to_chars(buf, buf + 64, 42);
%%   buf[r.pos] = 0;                   r.ec == 0 on success
%%   to_chars(buf, buf + 64, 255, 16); // an integer's base
%%   to_chars(buf, buf + 64, 3.5);     // general
%%   to_chars(buf, buf + 64, 3.5, chars_fixed);
%%   from_chars_result f = from_chars(buf, buf + 6, n);
%%   if (f.ec == 0) ...                f.pos is the first character not read
%%
%% The result structs and the format and error names are in charconv.pl.h: to_chars_result and from_chars_result,
%% chars_scientific, chars_fixed, chars_hex, chars_general, and ccllib_errc_value_too_large,
%% ccllib_errc_invalid_argument and ccllib_errc_result_out_of_range. An error is 0 on success; a program compares
%% `r.ec == 0` and `r.ec == ccllib_errc_invalid_argument`, where C++ compares `r.ec == std::errc()` and
%% `r.ec == std::errc::invalid_argument`.
%%
%% What differs from C++:
%%   to_chars of a floating number writes snprintf's general form with 17 significant digits, or its fixed or
%%     scientific form, and then trims the zeros that C++ trims; it is the shortest round-trip for a simple value, and
%%     not for every value (`0.1` writes more digits than std::to_chars does);
%%   to_chars of a floating number whose text is longer than 511 characters stops with value_too_large, even where the
%%     destination is larger;
%%   from_chars of a floating number reads strtod's syntax -- a decimal, inf, nan, or a hex float -- and at most 255
%%     characters; C++'s general format takes no hex float, and `chars_hex` takes nothing else;
%%   the result holds `pos', the offset of the first character not written or read, where C++ holds a pointer (`ptr');
%%   from_chars takes its value by name, `from_chars(first, last, n)', and refuses anything with no place to write.
:- ensure_loaded(library(ccllib/ccllib)).

%% to_chars(first, last, value): the general form of an integer or a floating number
ccl_macro_to_chars(F, L, X, R) :-
    ccl_type_of(X, T),
    (   ccl_is_integer(T) -> ccllib_charconv_to_int(F, L, X, T, 10, R)
    ;   ccl_is_float(T) -> ccllib_charconv_to_float(F, L, X, 0, R)
    ;   ccl_macro_error('to_chars takes an integer or a floating number') ).

%% to_chars(first, last, value, base or format)
ccl_macro_to_chars(F, L, X, A, R) :-
    ccl_type_of(X, T),
    (   ccl_is_integer(T) -> ccllib_charconv_base(A, B), ccllib_charconv_to_int(F, L, X, T, B, R)
    ;   ccl_is_float(T) -> ccllib_charconv_style(A, S), ccllib_charconv_to_float(F, L, X, S, R)
    ;   ccl_macro_error('to_chars takes an integer or a floating number') ).

%% from_chars(first, last, value): the general form
ccl_macro_from_chars(F, L, X, R) :-
    ccl_type_of(X, T), ccllib_charconv_lvalue(X),
    (   ccl_is_integer(T) -> ccllib_charconv_from_int(F, L, X, T, 10, R)
    ;   ccl_is_float(T) -> ccllib_charconv_from_float(F, L, X, R)
    ;   ccl_macro_error('from_chars takes an integer or a floating number') ).

%% from_chars(first, last, value, base or format)
ccl_macro_from_chars(F, L, X, A, R) :-
    ccl_type_of(X, T), ccllib_charconv_lvalue(X),
    (   ccl_is_integer(T) -> ccllib_charconv_base(A, B), ccllib_charconv_from_int(F, L, X, T, B, R)
    ;   ccl_is_float(T) -> ccllib_charconv_style(A, _), ccllib_charconv_from_float(F, L, X, R)
    ;   ccl_macro_error('from_chars takes an integer or a floating number') ).

ccllib_charconv_lvalue(X) :- ccl_iop_lvalue(X), !.
ccllib_charconv_lvalue(_) :- ccl_macro_error('from_chars takes a value with a place: name the value it reads into').

%% a base is a constant from 2 to 36; a base that is no constant is left to the call, as C++ leaves it
ccllib_charconv_base(A, B) :-
    (   catch(ccl_const_eval(A, B0), _, fail), integer(B0)
    ->  ( B0 >= 2, B0 =< 36 -> B = B0 ; ccl_macro_error('to_chars and from_chars take a base from 2 to 36') )
    ;   B = A ).

%% a floating number's format, as the header's enum names it
ccllib_charconv_style(chars_general, 0) :- !.
ccllib_charconv_style(chars_fixed, 1) :- !.
ccllib_charconv_style(chars_scientific, 2) :- !.
ccllib_charconv_style(chars_hex, 3) :- !.
ccllib_charconv_style(A, S) :-
    (   catch(ccl_const_eval(A, V), _, fail), integer(V)
    ->  ccllib_charconv_style_value(V, S)
    ;   ccl_macro_error('a floating to_chars or from_chars takes chars_general, chars_fixed, chars_scientific or chars_hex') ).
ccllib_charconv_style_value(0, 2) :- !.   % chars_scientific
ccllib_charconv_style_value(1, 1) :- !.   % chars_fixed
ccllib_charconv_style_value(2, 3) :- !.   % chars_hex
ccllib_charconv_style_value(3, 0) :- !.   % chars_general
ccllib_charconv_style_value(_, _) :- ccl_macro_error('a floating to_chars or from_chars takes chars_general, chars_fixed, chars_scientific or chars_hex').

ccllib_charconv_int_text(B, T) :-
    ( integer(B) -> number_codes(B, Cs), atom_codes(T, Cs)
    ; atomic_list_concat(['@B'], T) ).

%% -- the integers written: a signed one and an unsigned one call their own helper
ccllib_charconv_to_int(F, L, X, T, B, R) :-
    ( ccl_int_rank(T, _, true) -> Fn = ccllib_charconv_to_ull, Cast = '(unsigned long long)(@X)'
    ; Fn = ccllib_charconv_to_ll, Cast = '(long long)(@X)' ),
    ccllib_charconv_int_text(B, BT),
    atomic_list_concat([Fn, '((@F), (@L), ', Cast, ', (int)(', BT, '))'], Text),
    ccl_c_expr(Text, ['F' = expr(F), 'L' = expr(L), 'X' = expr(X), 'B' = expr(B)], R).

%% -- the floating numbers written
ccllib_charconv_to_float(F, L, X, S, R) :-
    ccllib_charconv_int_text(S, ST),
    atomic_list_concat(['ccllib_charconv_to_d((@F), (@L), (double)(@X), ', ST, ')'], Text),
    ccl_c_expr(Text, ['F' = expr(F), 'L' = expr(L), 'X' = expr(X), 'B' = expr(B)], R).

%% -- the integers read: a signed one and an unsigned one call their own helper
ccllib_charconv_from_int(F, L, X, T, B, R) :-
    ( ccl_int_rank(T, _, true) -> Fn = ccllib_charconv_from_unsigned ; Fn = ccllib_charconv_from_signed ),
    ccllib_charconv_int_text(B, BT),
    atomic_list_concat([Fn, '((@F), (@L), &(@X), (int)(', BT, '), (int)sizeof(@T))'], Text),
    ccl_c_expr(Text, ['F' = expr(F), 'L' = expr(L), 'X' = expr(X), 'T' = type(T), 'B' = expr(B)], R).

%% -- the floating numbers read
ccllib_charconv_from_float(F, L, X, R) :- ccl_type_of(X, T),
    ccl_c_expr("ccllib_charconv_from_double((@F), (@L), &(@X), (int)sizeof(@T))",
               ['F' = expr(F), 'L' = expr(L), 'X' = expr(X), 'T' = type(T)], R).
