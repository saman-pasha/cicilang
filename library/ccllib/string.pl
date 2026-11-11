%% ccllib's <string.pl> (0.291; CCLLIB.md's phase 1a): std::string for cicilang's C, and for cicilang++ beside libc++'s.
%% Its header, string.pl.h, includes <basic_string.pl>, names the instance of char `string' and gives `npos'; this file
%% has what <string> gives that is no function of a string's: to_string, a macro, since its argument is a number.
:- ensure_loaded(library(ccllib/ccllib)).
%% to_string(x): the text of a number, as std::to_string writes it -- an integer's digits, a floating number as printf's
%% %f -- by the function of basic_string_char for x's type; an instance's own to_string where x is an instance's object
ccl_macro_to_string(X, Out) :- ccl_inst_call(to_string, X, [], Out), !.
ccl_macro_to_string(X, Out) :-
    (   catch(ccl_type_of(X, T), _, fail), T \== unknown, ccllib_to_string_call(T, Text) -> true
    ;   ccl_macro_error('to_string takes a number') ),
    ccl_c_expr(Text, [x = expr(X)], Out).
ccllib_to_string_call(T, "basic_string_char_to_string_ld(@x)") :-
    ccl_is_float(T), ccl_resolve_type(T, base(_, S)), memberchk(long, S), !.
ccllib_to_string_call(T, "basic_string_char_to_string_d(@x)") :- ccl_is_float(T), !.
ccllib_to_string_call(T, "basic_string_char_to_string_ull(@x)") :-
    ccl_is_integer(T), ccl_int_rank(T, R, true), R >= 3, !.
ccllib_to_string_call(T, "basic_string_char_to_string_ll(@x)") :- ccl_is_integer(T).
