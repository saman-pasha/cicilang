%% ccllib's <functional.pl> (1.1.4; CCLLIB.md's phase 1b): C++'s function objects as the expressions a C program has,
%% and a hash of a value, for cicilang's C and for cicilang++ beside libc++'s.
%%
%%   #include <functional.pl>
%%   less(a, b)  greater(a, b)  less_equal(a, b)  greater_equal(a, b)  equal_to(a, b)  not_equal_to(a, b)
%%   plus(a, b)  minus(a, b)  multiplies(a, b)  divides(a, b)  modulus(a, b)  negate(a)
%%   logical_and(a, b)  logical_or(a, b)  logical_not(a)  bit_and(a, b)  bit_or(a, b)  bit_xor(a, b)  bit_not(a)
%%   identity(x)   hash(x)
%%
%% In C++ these name types whose call is an operator; C has no type whose call is an operator, so in ccllib each name is
%% a MACRO that expands to the operator's expression. The names in a call are ordinary expressions, so a name works
%% where C++ passes a type: `set<int, less>' orders a set by `<`, and `sort_by(v, a, b, greater(a, b))' hands its
%% comparison the expression. The macro is the module's own: a program that names a variable or a function `less' keeps
%% it -- `less' expands only where it is called with two arguments, and a bare `less' is a name as C reads it.
%%
%%   hash(x)         one FNV-1a step of x's bits, an unsigned long long: hash(0) is the 32-bit basis and hash(1) the
%%                   basis and 1 mixed by the 32-bit prime, in a 64-bit product. It takes an integer, an enum or a pointer, and refuses another type by
%%                   its name -- a floating number's bits, a struct's and a text's are a function of the program's,
%%                   where C++'s std::hash has a specialization for each.
%%
%% What differs from C++: less and the rest are macros, not types, so `auto f = less' and a function that takes a
%% `std::less' are not there; `hash' is a value's hash, not a type, and it takes the scalar types above. The arithmetic
%% is C's: `divides' of two integers truncates, as std::divides<int> does, and of two floating numbers is the
%% floating division.
:- ensure_loaded(library(ccllib/ccllib)).

%% the comparisons: the reader's binary forms, `bin(Op, A, B)'
ccl_macro_less(A, B, bin('<', A, B)).
ccl_macro_greater(A, B, bin('>', A, B)).
ccl_macro_less_equal(A, B, bin('<=', A, B)).
ccl_macro_greater_equal(A, B, bin('>=', A, B)).
ccl_macro_equal_to(A, B, bin('==', A, B)).
ccl_macro_not_equal_to(A, B, bin('!=', A, B)).

%% the arithmetic and the bit operators; negate, logical_not and bit_not are the reader's unary forms
ccl_macro_plus(A, B, bin('+', A, B)).
ccl_macro_minus(A, B, bin('-', A, B)).
ccl_macro_multiplies(A, B, bin('*', A, B)).
ccl_macro_divides(A, B, bin('/', A, B)).
ccl_macro_modulus(A, B, bin('%', A, B)).
ccl_macro_negate(A, neg(A)).
ccl_macro_bit_and(A, B, bin('&', A, B)).
ccl_macro_bit_or(A, B, bin('|', A, B)).
ccl_macro_bit_xor(A, B, bin('^', A, B)).
ccl_macro_bit_not(A, bitnot(A)).
ccl_macro_logical_and(A, B, bin('&&', A, B)).
ccl_macro_logical_or(A, B, bin('||', A, B)).
ccl_macro_logical_not(A, not(A)).
ccl_macro_identity(A, A).

%% hash(x): one FNV-1a step over x's bits as an unsigned long long. The cast is C's, so a pointer's address and an
%% enumerator's value hash alike; the two constants are FNV-1a's 32-bit basis and prime, carried in a 64-bit product. A type that is no scalar is
%% refused by name, with the word of its type
ccl_macro_hash(X, R) :-
    ccl_type_of(X, T), T \== unknown, ( ccl_is_integer(T) ; ccl_is_pointer(T) ), !,
    R = bin('*', bin('^', cast(base([], [unsigned, long, long]), X), int(2166136261)), int(16777619)).
ccl_macro_hash(X, _) :-
    ( catch(ccl_type_of(X, T0), _, fail) -> T = T0 ; T = unknown ),
    (   T \== unknown, catch(ccl_type_word(T, W), _, fail) -> Where = W ; Where = 'that type' ),
    atomic_list_concat(['a hash of the type ', Where, ' is not there: hash takes an integer, an enum or a pointer; ',
                        'a floating number, a struct and a text hash by a function of the program''s'], M),
    ccl_macro_error(M).
