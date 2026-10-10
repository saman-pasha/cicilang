%% cicilang -- library(ccl_infer): what a macro can ask, as the parser
%% stands at the call. The parser (library(ccl_syntax)) keeps the scope of
%% declared names, the typedef definitions and the struct tags as it reads;
%% a macro predicate from an included .pl runs at that point and may ask:
%%
%%   ccl_type_of(+Expr, -Type)        the type of an expression AST, or unknown
%%   ccl_resolve_type(+T, -T1)        typedef names unwrapped, a tag's members filled
%%   ccl_declared(+Name, -Type)       a name in scope, innermost first
%%   ccl_typedef_of(+Name, -Type)     a typedef's definition
%%   ccl_tag(+Tag, -Members)          a struct/union's members, an enum's enumerators
%%   ccl_members_of(+Type, -Members)  the members of a struct or union type
%%   ccl_member_type(+Type, +Name, -T)
%%   ccl_is_integer(+T) ccl_is_float(+T) ccl_is_arith(+T) ccl_is_pointer(+T)
%%   ccl_size_of(+T, -Bytes)          LP64: char 1 short 2 int 4 long 8 float 4 double 8 pointer 8
%%   ccl_enum_value(+Name, -Int)      an enumerator's value
%%   ccl_const_eval(+Expr, -Int)      an integer constant expression, folded as C folds it
%%   ccl_scope(-Frames)               every frame, innermost first
%%   ccl_gensym(+Prefix, -Atom)       a fresh identifier for a macro's temporary
%%   ccl_here(-File, -Line)           where the parser is
%%   ccl_macro_error(+Message)        stop the read with a message and the place
%%
%% Types are the AST's: base(Quals, Specs), ptr(Quals, T), arr(Size, T),
%% fn(Ret, Params, Variadic), block(Quals, T); and unknown.

%% no catch on a read of a global here: the keys are set once per process
%% (ccl_ensure_globals/0, library(ccl_include)), and a catch costs in
%% proportion to the terms bound inside it (a cocolog finding, in CLAUDE.md)
ccl_scope(Fs) :- nb_getval('$ccl_scope', Ls), ccl_tab_list('$ccl_gscope', G), append(Ls, [G], Fs).   % every frame, the file scope's last
ccl_locals(Ls) :- nb_getval('$ccl_scope', Ls).                                                   % the open frames alone, innermost first
ccl_declared(N, T) :- nb_getval('$ccl_scope', Ls), ( ccl_in_frames(Ls, N, T0) -> T = T0 ; ccl_gdeclared(N, T) ).
ccl_gdeclared(N, T) :- ccl_cached_named('$ccl_g:', N, T, ccl_tab_find('$ccl_gscope', N, T)).
%% a small answer cache in a global -- the Key-Value pairs found so far; a
%% copy of a dozen pairs is microseconds where the table's is a millisecond.
%% For keys that are terms (a type, a member list) whose values are small.
ccl_cached(Cache, Key, Value, Goal) :-
    nb_getval(Cache, C),
    (   memberchk(Key-V0, C) -> Value = V0
    ;   call(Goal), nb_setval(Cache, [Key-Value|C]) ).
%% the same for a NAME whose value may be large -- a tag's members, a
%% typedef's resolution, a function's type: a global per name, so a lookup
%% copies that one value and not every value found so far (nb_getval/2
%% copies what it answers); the names found are an index of atoms
ccl_cached_named(Prefix, Name, Value, Goal) :-
    atom_concat(Prefix, names, IK), nb_getval(IK, Names),
    (   memberchk(Name, Names), atom_concat(Prefix, Name, K), nb_getval(K, V0), V0 \== '$ccl_recheck' -> V0 \== '$ccl_miss', Value = V0
    ;   atom(Name), var(Value), ccl_caches_misses(Prefix)
    ->  atom_concat(Prefix, Name, K), ( memberchk(Name, Names) -> Names1 = Names ; Names1 = [Name|Names] ),
        ( call(Goal) -> nb_setval(K, Value), nb_setval(IK, Names1) ; nb_setval(K, '$ccl_miss'), nb_setval(IK, Names1), fail )
    ;   call(Goal), atom_concat(Prefix, Name, K), nb_setval(K, Value), ( memberchk(Name, Names) -> true ; nb_setval(IK, [Name|Names]) ) ).
%% A MISS IS REMEMBERED TOO (0.112), where the table is written only through ccl_tables_changed, which forgets it with
%% the answers: a name that is no tag copied the whole tags table at every ask -- `cpp_path_class(std, _)' asks
%% `ccl_tag(std, _)' at every `std::' call, 3 ms each over libc++'s ranges, 17,000 times in a 150 s build. Only for a
%% caller that asks with the value unbound, since a bound one fails for its value and not for the name.
ccl_caches_misses('$ccl_tag:').
ccl_caches_misses('$ccl_td:').
ccl_caches_misses('$ccl_ts:').
ccl_caches_misses('$ccl_g:').     % ... and the file scope's, whose writer marks a remembered miss of each name it declares for a new look (ccl_gdeclare)
ccl_named_caches(['$ccl_td:', '$ccl_tag:', '$ccl_r:', '$ccl_g:', '$ck_oa:', '$ccl_ts:']).
ccl_in_frames([F|Fs], N, T) :- ( memberchk(N-T0, F) -> T = T0 ; ccl_in_frames(Fs, N, T) ).
%% nb_getval/2 COPIES the term it answers, 0.05 ms for the typedef table and
%% 0.15 ms for the tags, and the lowering of 170 lines asks 2000 typedefs
%% and 1100 tags; the names a file uses are a dozen, so each answer is kept
%% in a small cache (a copy of a dozen pairs is microseconds), emptied by
%% ccl_tables_changed/0 wherever a table is written
ccl_typedef_of(N, T) :- atom(N), ccl_builtin_typedef(N, T0), !, T = T0.
ccl_builtin_typedef('__int128_t', base([], ['__int128'])).                   % the compiler's own 128-bit typedefs, which clang predefines (0.117)
ccl_builtin_typedef('__uint128_t', base([], [unsigned, '__int128'])).
ccl_typedef_of(N, T) :- ccl_cached_named('$ccl_td:', N, T, ccl_tab_find('$ccl_typedefs', N, T)).
ccl_tag(Tag, Ms) :- ccl_cached_named('$ccl_tag:', Tag, Ms, ccl_tab_find('$ccl_tags', Tag, Ms)).

%% ---- constants ---------------------------------------------------------------------
ccl_enum_value(N, V) :- nb_getval('$ccl_enums', L), memberchk(N-V, L).
%% AN ENUMERATOR'S TYPE IS ITS ENUM IN C++ ([dcl.enum]/5; 0.127), and the enum's name is a type. The table that keeps
%% the values ('$ccl_enums', Name-Value) keeps the enum too, as an entry of its own, `'$t'(Name)-Tag', beside the value;
%% and a SCOPED enum's tag as `'$s'(Tag)-1' (C++ asks it: a scoped enum converts to nothing implicitly). An entry of
%% that shape never answers a lookup of a value by name -- the key is a compound, a name is an atom -- so every writer,
%% save and restore of the table carries the two kinds of entry without a word, and a summary's `enum/2' lines too
ccl_enumerator_tag(N, L, Tag) :- atom(N), memberchk('$t'(N)-Tag0, L), !, Tag = Tag0.
ccl_scoped_enum(Tag) :- atom(Tag), nb_getval('$ccl_enums', L), memberchk('$s'(Tag)-_, L), !.
%% an integer constant expression, as C folds it
ccl_const_eval(int(big(A)), big(A)) :- !.     % A LITERAL PAST 2^60 (big(Atom), the lexers' term; 0.94) IS ITS OWN VALUE: the 64-bit arithmetic below takes it
ccl_const_eval(uint(big(A)), big(A)) :- !.
ccl_const_eval(long(big(A)), big(A)) :- !.
ccl_const_eval(ulong(big(A)), big(A)) :- !.
ccl_const_eval(wb(big(_)), _) :- !, fail.       % a _BitInt literal past 2^60 folds nowhere (its width is read off the value)
ccl_const_eval(uwb(big(_)), _) :- !, fail.
ccl_const_eval(int(N), N) :- !.
ccl_const_eval(uint(N), N) :- !.
ccl_const_eval(long(N), N) :- !.
ccl_const_eval(ulong(N), N) :- !.
ccl_const_eval(wchr(N), N) :- !.
ccl_const_eval(u16chr(N), N) :- !.
ccl_const_eval(u32chr(N), N) :- !.
ccl_const_eval(wb(N), N) :- !.
ccl_const_eval(uwb(N), N) :- !.
ccl_const_eval(bool(true), 1) :- !.                                            % C++
ccl_const_eval(comma(A, B), V) :- !, ( ccl_const_eval(A, _) -> true ; A = cast(base(_, [void]), _) ), ccl_const_eval(B, V).   % THE COMMA OPERATOR IS A CONSTANT EXPRESSION (C++11, [expr.const]): the right operand's value, the left one a constant or a `(void)' cast of anything. libc++ writes its conjunction as `_IsSame<__all_dummy<_Preds...>, __all_dummy<((void)_Preds, true)...>>', and unfolded the second instance was keyed by the term's spelling, so `__all<true, true, true>' was FALSE and every tuple constructed from another tuple lost its converting constructor (0.93)
ccl_const_eval(bool(false), 0) :- !.
ccl_const_eval(chr(C), C) :- !.
ccl_const_eval(id(N), V) :- !, \+ ccl_shadowed_constant(N), ccl_enum_value(N, V).   % a name is a constant only where no PLAIN local shadows the enumerator (0.94)
%% ... a `const' local with a constant initializer IS the constant (0.63's rule 11, `cpp_note_const'): libc++'s `__mu' writes
%% `const size_t __indx = is_placeholder<_Ti>::value - 1;' and indexes a tuple by it, and refused as a shadow it never folded
ccl_shadowed_constant(N) :- ccl_locals(Ls), ccl_in_frames(Ls, N, T), \+ ( ccl_resolve_type(T, base(Q, _)), memberchk(const, Q) ).
%% ---- 64-BIT CONSTANT ARITHMETIC (0.94) ------------------------------------------------------------------
%% cocolog's integers are 61-bit (the finding): `_Tp(1) << 63' folded to 0 and `type(type(~0) ^ __min)' -- how libc++
%% computes every numeric_limits<...>::max() -- to -1, so a string read, bounded by numeric_limits<streamsize>::max(),
%% never looped. A folded value is a cocolog integer where it fits in 61 bits and `big(Atom)' beyond (the lexers'
%% term for a literal past 2^60: its decimal digits, `-' first when negative); an operation whose result could pass
%% 61 bits computes on base-2^30 limbs (ccl_w_* over ccl_mag_*), and a CAST TO AN INTEGER TYPE WRAPS to its width
%% and signedness ([conv.integral]), which is where a 64-bit two's complement pattern is made: `(long long) (1ULL <<
%% 63)' is -2^63. The bitwise operators are the mathematical two's complement (`~0' is -1, as cocolog and C have it),
%% which with the casts gives C's answer; `/' and `%' truncate toward zero as C does, `>>' of a negative is arithmetic.
ccl_const_eval(neg(E), V) :- !, ccl_const_eval(E, V0), ccl_w_neg(V0, V1), ccl_cv_unary(E, V1, V).
ccl_const_eval(pos(E), V) :- !, ccl_const_eval(E, V).
ccl_const_eval(bitnot(E), V) :- !, ccl_const_eval(E, V0), ccl_w_sub(-1, V0, V1), ccl_cv_unary(E, V1, V).
ccl_const_eval(not(E), V) :- !, ccl_const_eval(E, V0), ( V0 == 0 -> V = 1 ; V = 0 ).
%% A FLOATING CONSTANT THAT IS THE OPERAND OF A CAST TO AN INTEGER TYPE is part of an integer constant expression (C 6.6/6,
%% [expr.const]; 0.129): `(int) 2.5', `(__int128) 1e30' and `(long) -3.75' fold, truncated toward zero and wrapped; a
%% floating literal alone still folds nowhere (a folded floating static would become an integer)
ccl_const_eval(cast(T, F), V) :- ccl_float_operand(F, X), ccl_resolve_type(T, RT), ccl_cast_shape(RT, _, _), !, ccl_w_cast(T, X, V).
ccl_const_eval(ccast(_, T, F), V) :- ccl_float_operand(F, X), ccl_resolve_type(T, RT), ccl_cast_shape(RT, _, _), !, ccl_w_cast(T, X, V).
ccl_const_eval(cast(T, E), V) :- !, ccl_const_eval(E, V0), ccl_w_cast(T, V0, V).
ccl_const_eval(ccast(_, T, E), V) :- !, ccl_const_eval(E, V0), ccl_w_cast(T, V0, V).      % C++'s own casts, a functional one among them: `type(~0)' folds as `(type) ~0' does
ccl_const_eval(sizeof_type(T), V) :- !, once(ccl_size_of(T, V)).   % A SIZE IS ONE ANSWER (0.117): the resolver leaves alternatives, and a test that backtracked into the fold (a static assertion) met a 0 after the right 16
ccl_const_eval(noexcept_expr(_), 1) :- !.   % no library function throws here (0.109; the desugaring folds a throwing operand to false first)
ccl_const_eval(offsetof(T, D), V) :- !, ccl_offsetof(T, D, V).
ccl_const_eval(alignof_type(T), V) :- !, once(( ccl_resolve_type(T, T1), ccl_size_align(T1, _, V) )).   % `alignof(T)' ([expr.alignof]): the alignment the layout already computes
ccl_const_eval(sizeof(E), V) :- !, ( ccl_literal_bytes(E, V) -> true ; once(( ccl_type_of(E, T), ccl_size_of(T, V) )) ).   % a string literal's bytes (0.103)
ccl_const_eval(cond(C, A, B), V) :- !, ccl_const_eval(C, CV), ( CV \== 0 -> ccl_const_eval(A, V) ; ccl_const_eval(B, V) ).
%% A LEFT SHIFT WRAPS IN THE PROMOTED TYPE OF ITS LEFT OPERAND ([expr.shift]/1, [expr.const]; 0.117): `intmax_t(1) << 63' is -2^63, which clang folds so,
%% and libc++'s `-((intmax_t(1) << (sizeof(intmax_t) * CHAR_BIT - 1)) + 1)' is INTMAX_MAX -- it was +2^63 here, the sum 2^63 + 1, the negation
%% -2^63 - 1, and every `__no_overflow<...>::value' of <chrono> false, so no duration converted to another. An operand with no type
%% (a name the tables lack) keeps the mathematical shift.
ccl_const_eval(bin('<<', A, B), V) :- !, ccl_const_eval(A, X), ccl_const_eval(B, Y), ccl_const_op('<<', X, Y, V0), ccl_shl_wrap(A, V0, V).
ccl_const_eval(bin(Op, A, B), V) :- ccl_const_eval(A, X), ccl_const_eval(B, Y), ccl_const_op(Op, X, Y, V0), ccl_cv_binary(Op, A, B, X, Y, V0, V).
%% UNSIGNED ARITHMETIC WRAPS, AND A NEGATIVE OPERAND OF AN UNSIGNED OPERATION IS CONVERTED FIRST (0.128; C 6.3.1.8, 6.2.5/9,
%% [expr.arith.conv], [basic.fundamental]/2): `~0u / 3' folded to 0 -- `~0u' was -1 and -1 / 3 is 0 -- where it is 0x55555555, `0u - 1' was
%% -1, `-1 < 0u' held, and `_Static_assert(~0UL / 3 == 0x5555555555555555UL)' failed. The values themselves stay untyped mathematical
%% integers; an operation whose operands and result are all small and not negative is the same in every type and is answered at once,
%% and only the rest asks the operands' types: where their common type is unsigned, the operands are converted to it, the operation is
%% done, and the result wraps to it (a comparison answers 0 or 1). In `#if' every unsigned type is uintmax_t ('$ccl_cv_pp', C 6.10.1/4):
%% `#if ~0u == 0xFFFFFFFFFFFFFFFF' holds, which it did not.
ccl_cv_unary(E, V1, V) :-
    (   ccl_cv_small(V1) -> V = V1
    ;   catch(( ccl_type_of(E, T0), T0 \== unknown, ccl_promoted_or_unknown(T0, T1), T1 \== unknown, ccl_cv_unsigned(T1) ), _, fail) -> ccl_cv_width(T1, T), ccl_w_cast(T, V1, V)
    ;   V = V1 ).
ccl_cv_binary(Op, A, B, X, Y, V0, V) :-
    (   ccl_cv_small(X), ccl_cv_small(Y), ccl_cv_small(V0) -> V = V0
    ;   ccl_cv_typed_op(Op, Rel),
        catch(( ccl_type_of(A, TA), ccl_type_of(B, TB), TA \== unknown, TB \== unknown, ccl_is_integer(TA), ccl_is_integer(TB), ccl_usual(TA, TB, T0), ccl_cv_unsigned(T0) ), _, fail)
    ->  ccl_cv_width(T0, T), ccl_w_cast(T, X, X1), ccl_w_cast(T, Y, Y1), ccl_const_op(Op, X1, Y1, V1), ( Rel == yes -> V = V1 ; ccl_w_cast(T, V1, V) )
    ;   Op == '>>', \+ ccl_cv_small(X), catch(( ccl_type_of(A, TA0), TA0 \== unknown, ccl_promoted_or_unknown(TA0, TL0), TL0 \== unknown, ccl_cv_unsigned(TL0) ), _, fail)
    ->  ccl_cv_width(TL0, TL), ccl_w_cast(TL, X, X1), ccl_const_op('>>', X1, Y, V)
    ;   V = V0 ).
ccl_cv_small(X) :- integer(X), X >= 0, X < 2147483648.
ccl_cv_pp :- catch(nb_getval('$ccl_cv_pp', yes), _, fail).
ccl_cv_width(T0, T) :- ( ccl_cv_pp -> T = base([], [unsigned, long]) ; T = T0 ).   % `#if' computes in uintmax_t (C 6.10.1/4): an unsigned operation is 64 bits wide there
ccl_cv_unsigned(T) :- ccl_is_integer(T), \+ ccl_is_bool_type(T), ccl_int_rank(T, _, true), !.
ccl_is_bool_type(T) :- ccl_resolve_type(T, base(_, S)), ( memberchk(bool, S) ; memberchk('_Bool', S) ), !.
ccl_cv_typed_op('+', no). ccl_cv_typed_op('-', no). ccl_cv_typed_op('*', no). ccl_cv_typed_op('/', no). ccl_cv_typed_op('%', no).
ccl_cv_typed_op('&', no). ccl_cv_typed_op('|', no). ccl_cv_typed_op('^', no).
ccl_cv_typed_op('<', yes). ccl_cv_typed_op('>', yes). ccl_cv_typed_op('<=', yes). ccl_cv_typed_op('>=', yes). ccl_cv_typed_op('==', yes). ccl_cv_typed_op('!=', yes).
ccl_shl_wrap(A, V0, V) :- ( catch(( ccl_type_of(A, AT), AT \== unknown, ccl_promoted_or_unknown(AT, T), T \== unknown ), _, fail) -> ccl_w_cast(T, V0, V) ; V = V0 ).
ccl_const_op('+', X, Y, V) :- ccl_w_add(X, Y, V).
ccl_const_op('-', X, Y, V) :- ccl_w_sub(X, Y, V).
ccl_const_op('*', X, Y, V) :- ccl_w_mul(X, Y, V).
ccl_const_op('/', X, Y, V) :- Y \== 0, ccl_w_div(X, Y, V).
ccl_const_op('%', X, Y, V) :- Y \== 0, ccl_w_mod(X, Y, V).
ccl_const_op('<<', X, Y, V) :- integer(Y), Y >= 0, ccl_w_shl(X, Y, V).
ccl_const_op('>>', X, Y, V) :- integer(Y), Y >= 0, ccl_w_shr(X, Y, V).
ccl_const_op('&', X, Y, V) :- ccl_w_bit(and, X, Y, V).
ccl_const_op('|', X, Y, V) :- ccl_w_bit(or, X, Y, V).
ccl_const_op('^', X, Y, V) :- ccl_w_bit(xor, X, Y, V).
ccl_const_op('<', X, Y, V) :- ( ccl_w_cmp(X, Y, <) -> V = 1 ; V = 0 ).
ccl_const_op('>', X, Y, V) :- ( ccl_w_cmp(X, Y, >) -> V = 1 ; V = 0 ).
ccl_const_op('<=', X, Y, V) :- ( ccl_w_cmp(X, Y, >) -> V = 0 ; V = 1 ).
ccl_const_op('>=', X, Y, V) :- ( ccl_w_cmp(X, Y, <) -> V = 0 ; V = 1 ).
ccl_const_op('==', X, Y, V) :- ( ccl_w_cmp(X, Y, =) -> V = 1 ; V = 0 ).
ccl_const_op('!=', X, Y, V) :- ( ccl_w_cmp(X, Y, =) -> V = 0 ; V = 1 ).
ccl_const_op('&&', X, Y, V) :- ( X \== 0, Y \== 0 -> V = 1 ; V = 0 ).
ccl_const_op('||', X, Y, V) :- ( ( X \== 0 ; Y \== 0 ) -> V = 1 ; V = 0 ).
%% the operations: a fast path in the engine's own arithmetic where the result cannot pass 61 bits, else the limbs
ccl_w_fits(X) :- integer(X), X < 576460752303423488, X > -576460752303423488.          % |X| < 2^59
ccl_w_neg(X, V) :- integer(X), !, V is -X.
ccl_w_neg(X, V) :- ccl_wide(X, w(S, M)), S1 is -S, ccl_narrow(w(S1, M), V).
ccl_w_add(X, Y, V) :- ccl_w_fits(X), ccl_w_fits(Y), !, V is X + Y.
ccl_w_add(X, Y, V) :- ccl_wide(X, A), ccl_wide(Y, B), ccl_w_add_(A, B, C), ccl_narrow(C, V).
ccl_w_sub(X, Y, V) :- ccl_w_fits(X), ccl_w_fits(Y), !, V is X - Y.
ccl_w_sub(X, Y, V) :- ccl_wide(X, A), ccl_wide(Y, w(S, M)), S1 is -S, ccl_w_add_(A, w(S1, M), C), ccl_narrow(C, V).
ccl_w_mul(X, Y, V) :- integer(X), integer(Y), X < 1073741824, X > -1073741824, Y < 1073741824, Y > -1073741824, !, V is X * Y.
ccl_w_mul(X, Y, V) :- ccl_wide(X, w(SA, MA)), ccl_wide(Y, w(SB, MB)), S is SA * SB, ccl_mag_mul(MA, MB, M), ccl_narrow(w(S, M), V).
ccl_w_div(X, Y, V) :- integer(X), integer(Y), !, V is X // Y.                            % `//' truncates, as C does
ccl_w_div(X, Y, V) :- ccl_wide(X, w(SA, MA)), ccl_wide(Y, w(SB, MB)), ccl_mag_divmod(MA, MB, Q, _), S is SA * SB, ccl_narrow(w(S, Q), V).
ccl_w_mod(X, Y, V) :- integer(X), integer(Y), !, V is X - (X // Y) * Y.                 % the remainder takes the dividend's sign, as C has it
ccl_w_mod(X, Y, V) :- ccl_wide(X, w(SA, MA)), ccl_wide(Y, w(_, MB)), ccl_mag_divmod(MA, MB, _, R), ccl_narrow(w(SA, R), V).
ccl_w_shl(X, N, V) :- integer(X), N < 30, X < 1073741824, X > -1073741824, !, V is X << N.
ccl_w_shl(X, N, V) :- ccl_wide(X, w(S, M)), ccl_mag_shl(M, N, M1), ccl_narrow(w(S, M1), V).
ccl_w_shr(X, N, V) :- integer(X), !, V is X >> N.                                        % arithmetic: the floor, as every compiler here has it
ccl_w_shr(X, N, V) :- ccl_wide(X, w(S, M)), ccl_mag_shr(M, N, M1, Rem), ( S < 0, Rem == nonzero -> ccl_mag_add(M1, [1], M2) ; M2 = M1 ), ccl_narrow(w(S, M2), V).
ccl_w_bit(Op, X, Y, V) :- integer(X), integer(Y), !, ccl_w_bit_int(Op, X, Y, V).
ccl_w_bit(Op, X, Y, V) :- ccl_wide(X, A), ccl_wide(Y, B), ccl_w_tc(A, TA), ccl_w_tc(B, TB), ccl_mag_bit(Op, TA, TB, TC), ccl_w_untc(TC, C), ccl_narrow(C, V).
ccl_w_bit_int(and, X, Y, V) :- V is X /\ Y.
ccl_w_bit_int(or, X, Y, V) :- V is X \/ Y.
ccl_w_bit_int(xor, X, Y, V) :- V is xor(X, Y).
ccl_w_cmp(X, Y, O) :- integer(X), integer(Y), !, compare(O, X, Y).
ccl_w_cmp(X, Y, O) :- ccl_wide(X, w(SA, MA)), ccl_wide(Y, w(SB, MB)),
    ( SA < SB -> O = (<) ; SA > SB -> O = (>) ; ccl_mag_cmp(MA, MB, O0), ( SA < 0 -> ccl_w_flip(O0, O) ; O = O0 ) ).
ccl_w_flip(<, >). ccl_w_flip(>, <). ccl_w_flip(=, =).
%% a cast to an integer type wraps to its width, then to its signedness; to bool it is the test; to anything else the value
ccl_w_cast(T, X, V) :- float(X), ccl_resolve_type(T, RT), ccl_cast_shape(RT, Bits, Signed), !, ( Signed == bool -> ( X =:= 0.0 -> V = 0 ; V = 1 ) ; ccl_float_int(X, X1), ccl_w_wrap(X1, Bits, Signed, V) ).   % a floating value to an integer type truncates toward zero (6.3.1.4), then wraps (0.108)
ccl_w_cast(T, X, V) :- ccl_resolve_type(T, RT), ccl_cast_shape(RT, Bits, Signed), !, ccl_w_wrap(X, Bits, Signed, V).
ccl_w_cast(T, X, V) :- integer(X), ccl_is_float(T), !, V is X * 1.0.   % an integer to a floating type is a floating value
ccl_w_cast(T, X, V) :- X = big(_), ccl_is_float(T), !, ccl_w_float(X, V).   % ... a wide one too (0.129)
ccl_w_cast(_, X, X).
%% FLOATING VALUES AND WIDE INTEGERS (0.129): `truncate/1' and `* 1.0' have the engine's 61 bits, so `(__int128) 1e30' did not
%% fold (a global's initializer refused, global_init) and `(double) ((__int128) 1 << 100)' kept the integer as a double's value.
%% A double past 2^59 is an integer m * 2^e with m below 2^53 -- halving it is exact -- and the wide value is m shifted; a wide
%% integer is a double rounded to nearest, ties to even, from its top 53 bits, the next one and whether any lower bit is set.
%% An infinity or a NaN converts to no integer, and does not fold.
ccl_float_operand(float(X), X) :- float(X).
ccl_float_operand(neg(float(X)), Y) :- float(X), Y is -X.
ccl_float_operand(pos(float(X)), X) :- float(X).
ccl_float_int(X, V) :- A is abs(X), A =< 1.7976931348623157e308,
    (   A < 576460752303423488.0 -> V is truncate(X)
    ;   ccl_float_halve(A, 0, M, E), ccl_w_shl(M, E, V0), ( X < 0.0 -> ccl_w_neg(V0, V) ; V = V0 ) ).
ccl_float_halve(A, E0, M, E) :- ( A < 9007199254740992.0 -> M is truncate(A), E = E0 ; A1 is A / 2.0, E1 is E0 + 1, ccl_float_halve(A1, E1, M, E) ).
ccl_w_float(X, F) :- ccl_wide(X, w(S, M)), ccl_mag_bits_be(M, Bits), length(Bits, N),
    (   N =< 53 -> ccl_bits_int(Bits, 0, I), F0 is I * 1.0
    ;   length(Hi, 53), append(Hi, [R|Lo], Bits), ccl_bits_int(Hi, 0, H0),
        ( R =:= 1, ( memberchk(1, Lo) ; H0 /\ 1 =:= 1 ) -> H is H0 + 1 ; H = H0 ),
        E is N - 53, F1 is H * 1.0, ccl_float_scale2(E, F1, F0) ),
    ( S < 0 -> F is -F0 ; F = F0 ).
ccl_bits_int([], I, I).
ccl_bits_int([B|Bs], I0, I) :- I1 is I0 * 2 + B, ccl_bits_int(Bs, I1, I).
ccl_float_scale2(0, F, F) :- !.
ccl_float_scale2(E, F0, F) :- F1 is F0 * 2.0, E1 is E - 1, ccl_float_scale2(E1, F1, F).
ccl_cast_shape(base(_, S), 1, bool) :- ( memberchk(bool, S) ; memberchk('_Bool', S) ), !.
ccl_cast_shape(RT, Bits, Signed) :- ccl_is_integer(RT), ccl_size_of(RT, Bytes), Bits is Bytes * 8, ( ccl_int_rank(RT, _, true) -> Signed = false ; Signed = true ).
ccl_w_wrap(X, 1, bool, V) :- !, ( X == 0 -> V = 0 ; V = 1 ).
ccl_w_wrap(X, Bits, Signed, V) :- integer(X), Bits =< 32, !, P is 1 << Bits, M0 is X mod P, ( M0 < 0 -> M is M0 + P ; M = M0 ), H is P // 2, ( Signed == true, M >= H -> V is M - P ; V = M ).
ccl_w_wrap(X, Bits, Signed, V) :- integer(X), Bits >= 61, ( X >= 0 ; Signed == true ), !, V = X.   % a value that fits in 61 bits is unchanged by a 64-bit wrap, unless it is negative and the type is unsigned
ccl_w_wrap(X, Bits, Signed, V) :- ccl_wide(X, w(S, M)), ccl_pow2_mag(Bits, P), ccl_mag_lowbits(M, Bits, L0),
    ( S < 0, L0 \== [] -> ccl_mag_sub(P, L0, L) ; L = L0 ),
    B1 is Bits - 1, ( Signed == true, ccl_mag_bit_set(L, B1) -> ccl_mag_sub(P, L, M1), ccl_narrow(w(-1, M1), V) ; ccl_narrow(w(1, L), V) ).
%% a value between the engine's integers and the limbs: w(Sign, Limbs), little-endian base 2^30, no trailing zero limb
ccl_wide(V, W) :- integer(V), !, ( V < 0 -> M is -V, S = -1 ; M = V, S = 1 ), ccl_limbs_of_int(M, Ls), ccl_w_norm(S, Ls, W).
ccl_wide(big(A), W) :- atom_codes(A, Cs), ( Cs = [0'-|Ds] -> S = -1 ; Ds = Cs, S = 1 ),
    ( Ds = [0'0, X|Hs], ( X == 0'x ; X == 0'X ) -> ccl_limbs_of_hex(Hs, [], Ls) ; ccl_limbs_of_dec(Ds, [], Ls) ), ccl_w_norm(S, Ls, W).   % a HEX, octal or binary literal past 2^60 is `big('0x...')' (0.94): read as decimal digits, `0xF000000000000000ull >> 60' folded to 0 and an array of that bound had no bytes (test/c/run/bighex.c)
ccl_w_norm(S, Ls0, w(S1, Ls)) :- ccl_mag_norm(Ls0, Ls), ( Ls == [] -> S1 = 1 ; S1 = S ).
ccl_narrow(w(S, M), V) :-
    (   M == [] -> V = 0
    ;   M = [L0] -> V is S * L0
    ;   M = [L0, L1] -> V is S * (L0 + L1 * 1073741824)
    ;   ccl_mag_dec(M, Ds), ( S < 0 -> atom_codes(A, [0'-|Ds]) ; atom_codes(A, Ds) ), V = big(A) ).
ccl_w_add_(w(SA, MA), w(SB, MB), C) :-
    (   SA =:= SB -> ccl_mag_add(MA, MB, M), ccl_w_norm(SA, M, C)
    ;   ccl_mag_cmp(MA, MB, O), ( O == (<) -> ccl_mag_sub(MB, MA, M), ccl_w_norm(SB, M, C) ; ccl_mag_sub(MA, MB, M), ccl_w_norm(SA, M, C) ) ).
ccl_w_tc(w(S, M), T) :- ( S >= 0 -> T = M ; ccl_pow2_mag(128, P), ccl_mag_sub(P, M, T) ).                    % two's complement at 128 bits
ccl_w_untc(T, C) :- ( ccl_mag_bit_set(T, 127) -> ccl_pow2_mag(128, P), ccl_mag_sub(P, T, M), C = w(-1, M) ; C = w(1, T) ).
%% the magnitudes
ccl_limbs_of_int(0, []) :- !.
ccl_limbs_of_int(M, [L|Ls]) :- L is M mod 1073741824, M1 is M // 1073741824, ccl_limbs_of_int(M1, Ls).
ccl_limbs_of_dec([], Ls, Ls).
ccl_limbs_of_dec([D|Ds], Acc0, Ls) :- V is D - 0'0, ccl_mag_mul_small(Acc0, 10, V, Acc1), ccl_limbs_of_dec(Ds, Acc1, Ls).
ccl_limbs_of_hex([], Ls, Ls).
ccl_limbs_of_hex([D|Ds], Acc0, Ls) :- ( D >= 0'a -> V is D - 0'a + 10 ; D >= 0'A -> V is D - 0'A + 10 ; V is D - 0'0 ), ccl_mag_mul_small(Acc0, 16, V, Acc1), ccl_limbs_of_hex(Ds, Acc1, Ls).
ccl_mag_norm(Ls, N) :- reverse(Ls, R0), ccl_drop_zeros(R0, R), reverse(R, N).
ccl_drop_zeros([0|Xs], R) :- !, ccl_drop_zeros(Xs, R).
ccl_drop_zeros(Xs, Xs).
ccl_mag_add(A, B, C) :- ccl_mag_add_(A, B, 0, C0), ccl_mag_norm(C0, C).
ccl_mag_add_([], [], 0, []) :- !.
ccl_mag_add_([], [], Cy, [Cy]) :- !.
ccl_mag_add_([], Bs, Cy, C) :- !, ccl_mag_add_([0], Bs, Cy, C).
ccl_mag_add_(As, [], Cy, C) :- !, ccl_mag_add_(As, [0], Cy, C).
ccl_mag_add_([A|As], [B|Bs], Cy, [D|Ds]) :- T is A + B + Cy, D is T mod 1073741824, Cy1 is T // 1073741824, ccl_mag_add_(As, Bs, Cy1, Ds).
ccl_mag_sub(A, B, C) :- ccl_mag_sub_(A, B, 0, C0), ccl_mag_norm(C0, C).                  % A >= B
ccl_mag_sub_([], [], 0, []) :- !.
ccl_mag_sub_(As, [], Bw, C) :- !, ccl_mag_sub_(As, [0], Bw, C).
ccl_mag_sub_([A|As], [B|Bs], Bw, [D|Ds]) :- T is A - B - Bw, ( T < 0 -> D is T + 1073741824, Bw1 = 1 ; D = T, Bw1 = 0 ), ccl_mag_sub_(As, Bs, Bw1, Ds).
ccl_mag_cmp(A, B, O) :- length(A, LA), length(B, LB), ( LA < LB -> O = (<) ; LA > LB -> O = (>) ; reverse(A, RA), reverse(B, RB), compare(O, RA, RB) ).
ccl_mag_mul_small([], _, Cy, Ls) :- ( Cy =:= 0 -> Ls = [] ; Ls = [Cy] ).               % K and the carry below 2^30
ccl_mag_mul_small([L|Ls], K, Cy, [R|Rs]) :- T is L * K + Cy, R is T mod 1073741824, Cy1 is T // 1073741824, ccl_mag_mul_small(Ls, K, Cy1, Rs).
ccl_mag_mul([], _, []) :- !.
ccl_mag_mul([A|As], B, C) :- ccl_mag_mul_small(B, A, 0, P), ccl_mag_mul(As, B, C1), ( C1 == [] -> ccl_mag_norm(P, C) ; ccl_mag_add(P, [0|C1], C) ).
ccl_mag_divmod(A, [K], Q, R) :- !, ccl_mag_divmod_small(A, K, Q, R0), ( R0 =:= 0 -> R = [] ; R = [R0] ).
ccl_mag_divmod(A, B, Q, R) :- ccl_mag_bits_be(A, Bits), ccl_mag_ldiv(Bits, B, [], QBits, R), ccl_mag_of_bits_be(QBits, Q).
ccl_mag_divmod_small(A, K, Q, R) :- reverse(A, BE), ccl_mag_dms_(BE, K, 0, QBE, R), reverse(QBE, Q0), ccl_mag_norm(Q0, Q).
ccl_mag_dms_([], _, R, [], R).
ccl_mag_dms_([L|Ls], K, R0, [Q|Qs], R) :- T is R0 * 1073741824 + L, Q is T // K, R1 is T mod K, ccl_mag_dms_(Ls, K, R1, Qs, R).
ccl_mag_bits_be(M, Bits) :- reverse(M, BE), ccl_limbs_bits_be(BE, Bits0), ccl_drop_zeros(Bits0, Bits).
ccl_limbs_bits_be([], []).
ccl_limbs_bits_be([L|Ls], Bits) :- ccl_limb_bits(29, L, B0), ccl_limbs_bits_be(Ls, B1), append(B0, B1, Bits).
ccl_limb_bits(-1, _, []) :- !.
ccl_limb_bits(I, L, [B|Bs]) :- B is (L >> I) /\ 1, I1 is I - 1, ccl_limb_bits(I1, L, Bs).
ccl_mag_ldiv([], _, R, [], R).
ccl_mag_ldiv([Bit|Bits], B, R0, [QB|QBs], R) :-
    ccl_mag_shl(R0, 1, R1a), ( Bit =:= 1 -> ccl_mag_add(R1a, [1], R1) ; R1 = R1a ),
    ( ccl_mag_cmp(R1, B, O), O \== (<) -> ccl_mag_sub(R1, B, R2), QB = 1 ; R2 = R1, QB = 0 ), ccl_mag_ldiv(Bits, B, R2, QBs, R).
ccl_mag_of_bits_be(Bits, M) :- ccl_mag_of_bits_(Bits, [], M0), ccl_mag_norm(M0, M).
ccl_mag_of_bits_([], M, M).
ccl_mag_of_bits_([B|Bs], Acc, M) :- ccl_mag_shl(Acc, 1, A1), ( B =:= 1 -> ccl_mag_add(A1, [1], A2) ; A2 = A1 ), ccl_mag_of_bits_(Bs, A2, M).
ccl_mag_shl(M, N, R) :- Q is N // 30, Rm is N mod 30, K is 1 << Rm, ccl_mag_mul_small(M, K, 0, M1), ( M1 == [] -> R = [] ; length(Z, Q), ccl_fill_zeros(Z), append(Z, M1, R0), ccl_mag_norm(R0, R) ).
ccl_fill_zeros([]).
ccl_fill_zeros([0|Z]) :- ccl_fill_zeros(Z).
ccl_mag_shr(M, N, R, Rem) :- Q is N // 30, Rm is N mod 30, ccl_mag_drop(Q, M, M1, Rem0), K is 1 << Rm, ccl_mag_divmod_small(M1, K, R, Rm2), ( ( Rem0 == nonzero ; Rm2 =\= 0 ) -> Rem = nonzero ; Rem = zero ).
ccl_mag_drop(0, M, M, zero) :- !.
ccl_mag_drop(_, [], [], zero) :- !.
ccl_mag_drop(Q, [L|Ls], M, Rem) :- Q1 is Q - 1, ccl_mag_drop(Q1, Ls, M, Rem1), ( ( L =\= 0 ; Rem1 == nonzero ) -> Rem = nonzero ; Rem = zero ).
ccl_mag_lowbits(M, Bits, L) :- Q is Bits // 30, Rb is Bits mod 30, ccl_mag_take(Q, M, Full, Rest), ( Rb > 0, Rest = [X|_] -> Mask is (1 << Rb) - 1, Y is X /\ Mask, append(Full, [Y], L0) ; L0 = Full ), ccl_mag_norm(L0, L).
ccl_mag_take(0, M, [], M) :- !.
ccl_mag_take(_, [], [], []) :- !.
ccl_mag_take(Q, [X|Xs], [X|Ys], Rest) :- Q1 is Q - 1, ccl_mag_take(Q1, Xs, Ys, Rest).
ccl_mag_bit_set(M, I) :- Q is I // 30, Rb is I mod 30, nth0(Q, M, L), (L >> Rb) /\ 1 =:= 1.
ccl_pow2_mag(Bits, P) :- ccl_mag_shl([1], Bits, P).
ccl_mag_bit(Op, A, B, C) :- length(A, LA), length(B, LB), Lm is max(LA, LB), ccl_mag_pad(A, Lm, A1), ccl_mag_pad(B, Lm, B1), ccl_mag_bit_(Op, A1, B1, C0), ccl_mag_norm(C0, C).
ccl_mag_pad(M, N, P) :- length(M, L), ( L >= N -> P = M ; K is N - L, length(Z, K), ccl_fill_zeros(Z), append(M, Z, P) ).
ccl_mag_bit_(_, [], [], []).
ccl_mag_bit_(Op, [A|As], [B|Bs], [C|Cs]) :- ccl_w_bit_int(Op, A, B, C), ccl_mag_bit_(Op, As, Bs, Cs).
ccl_mag_dec([], [0'0]) :- !.
ccl_mag_dec(M, Ds) :- ccl_mag_dec_(M, [], Ds).
ccl_mag_dec_([], Acc, Acc) :- !.
ccl_mag_dec_(M, Acc, Ds) :- ccl_mag_divmod_small(M, 10, Q, R), D is 0'0 + R, ccl_mag_dec_(Q, [D|Acc], Ds).

ccl_here(File, Line) :- ccl_ensure_globals, nb_getval('$ccl_file', File), nb_getval('$ccl_far', Line).
ccl_gensym(Prefix, Atom) :-
    ccl_ensure_globals, nb_getval('$ccl_gensym', N0), N is N0 + 1, nb_setval('$ccl_gensym', N),
    atomic_list_concat([Prefix, '_', N], Atom).
ccl_macro_error(Msg) :- ccl_here(F, L), throw(error(macro_error(Msg, here(F, L)), _)).

%% ---- resolving ------------------------------------------------------------------
%% a typedef resolves to its end in one step: the chain (size_t -> __darwin_size_t
%% -> unsigned long) is walked once per name and kept (the lowering of 170 lines
%% asked 16,600 resolutions, most of them links of a chain)
%% (asked 12,000 times in the lowering of 170 lines, most for a pointer or a
%% plain base type: the functor decides the clause, one try)
ccl_resolve_type(base(Q, [S|Ss]), base(Q, [S|Ss])) :- atom(S), !.               % a plain specifier list, the commonest: one call
ccl_resolve_type(base(Q, S), T) :- !, ccl_resolve_base(S, Q, T).
ccl_resolve_type(T, T).
ccl_resolve_base([S|Ss], Q, base(Q, [S|Ss])) :- atom(S), !.                      % a plain specifier list, the common case: one try
%% THE VARIABLE ARGUMENT LIST, `__builtin_va_list' (0.108): the platform ABI's own type -- on x86-64 SysV a
%% `struct __va_list_tag[1]' of 24 bytes (two 4-byte offsets and two pointers), on AAPCS64 Linux a 32-byte struct,
%% on Apple's arm64 a `char *' -- kept here as an array of words of that size, since nothing reads its fields but
%% LLVM's own `va_arg' instruction: a local is the object, a parameter the pointer it decays to, as C has it
ccl_resolve_base([typedef('__builtin_va_list')], Q, T) :- !, ccl_va_list_type(Q, T).
ccl_resolve_base([typedef(N)], Q, T) :- atom(N), ccl_cached_named('$ccl_r:', N, T1, ccl_resolve_typedef(N, T1)), !, ccl_add_quals(Q, T1, T).
ccl_resolve_base([typedef(N)], Q, T) :- atom(N), ccl_lang(cpp), ccl_tag(N, Ms), !, ccl_tag_type(N, Ms, Q, T).   % C++: a tag's name is a type name; a template-id (a compound) stays as it is
%% typeof(x): the TYPE when a type was written (GNU's, and C23's own), else the expression's -- nothing
%% resolved it before, so a `typeof' reached the lowering as a specifier it could not take
ccl_resolve_base([typeof(unqual(X))], Q, T) :- !, ccl_resolve_base([typeof(X)], [], T0), ccl_strip_quals(T0, T1), ccl_add_quals(Q, T1, T).   % C23's typeof_unqual: the top-level qualifiers off
ccl_resolve_base([typeof(X)], Q, T) :- ccl_type_term(X), !, ccl_resolve_type(X, T0), ccl_add_quals(Q, T0, T).
ccl_resolve_base([typeof(X)], Q, T) :- ccl_type_of(X, T0), T0 \== unknown, !, ccl_resolve_type(T0, T1), ccl_add_quals(Q, T1, T).
ccl_type_term(T) :- compound(T), functor(T, F, _), memberchk(F, [base, ptr, arr, fn, ref, rref]).
ccl_resolve_base([decltype(E)], Q, base(Q, [unsigned, long])) :- ccl_lang(cpp), ccl_sizeof_expr(E), !.   % C++: libc++ spells size_t `decltype(sizeof(int))', and the type of a sizeof is size_t: the concrete type here, or the chain turns
ccl_resolve_base([decltype(E)], Q, T) :- ccl_lang(cpp), ccl_type_of(E, T0), T0 \== unknown, !, ccl_add_quals(Q, T0, T).
ccl_resolve_base([struct(Tag, none)], Q, base(Q, [struct(Tag, Ms)])) :- ccl_tag(Tag, Ms), !.
ccl_resolve_base([union(Tag, none)], Q, base(Q, [union(Tag, Ms)])) :- ccl_tag(Tag, Ms), !.
ccl_resolve_base(S, Q, base(Q, S)).
%% what a C++ tag's name stands for, told by its members' shape: enumerators,
%% plain members (a struct), or a class's (a constructor, a method, a label)
ccl_tag_type(N, Ms0, Q, base(Q, [union(N, Ms)])) :- ccl_is_union_tag(Ms0), !, ccl_tag(N, Ms).   % a UNION with constructors: a class whose members share storage
ccl_tag_type(N, Ms0, Q, base(Q, [enum(N, Ms)])) :- ccl_is_enum_tag(Ms0), !, ccl_tag(N, Ms).
ccl_tag_type(N, Ms, Q, base(Q, [struct(N, Ms2)])) :- ccl_class_shape(Ms), ccl_tag_struct(N, Ms2), !.   % the class desugared: its struct, noted beside the raw class
ccl_tag_type(N, Ms, Q, base(Q, [class(class, N, [], Ms)])) :- ccl_class_shape(Ms), !.
ccl_tag_type(N, Ms, Q, base(Q, [struct(N, Ms)])).
%% A TAG'S MEMBERS TELL AN ENUM FROM A STRUCT: its enumerators, or the underlying type kept before them
%% (ccl_enum_members//3 in the reader) -- which is the only thing that tells `enum class C : size_t { }',
%% libc++'s strong typedef for a count, from an empty struct. Asked wherever a tag's name is resolved,
%% cast to, or taken as a scope.
%% ... and a marker before them tells a UNION-CLASS from a struct, the same way: libc++'s `basic_string::__rep'
%% is a union with four constructors -- a class whose members share storage, so its LAYOUT is a union's while its
%% constructors and methods are a class's
ccl_is_union_tag([union_tag|_]).
ccl_is_enum_tag([enumerator(_, _)|_]).
ccl_is_enum_tag([enum_base(_)|_]).
ccl_tag_struct(N, Ms) :- ccl_cached_named('$ccl_ts:', N, Ms, ( ccl_tab_member('$ccl_tags', N, Ms), \+ ccl_class_shape(Ms) )).
%% a member list that is a CLASS's and not a plain struct's: something in it is no data member. The
%% `align_as' a class states is LAYOUT and not a member, so it counts for neither shape -- read as one,
%% an `alignas' struct answered its raw class where its desugared struct was meant and `sizeof' had
%% nothing to lay out.
ccl_class_shape(Ms) :- member(M, Ms), \+ ccl_layout_marker(M), M \= member(_, _, _), !.
ccl_layout_marker(align_as(_)).
ccl_layout_marker(virtual_base).                                   % a class whose FIRST base is VIRTUAL (0.110): its `$base' is reached through the vtable's vbase offset
ccl_layout_marker(virtual_base_of(_)).                             % ... and its base-subobject form `C.nv', the shared base not laid out (a diamond's later path)
%% which kind of virtual-base struct a type is: `complete' (the base laid LAST, at a place only the complete object knows)
%% or `nv(T)' (the base elsewhere in the complete object); either is reached through the vtable, never statically
ccl_vbase_kind(T, K) :- ccl_members_of_(T, Ms), ( memberchk(virtual_base, Ms) -> K = complete ; memberchk(virtual_base_of(VT), Ms) -> K = nv(VT) ).
ccl_resolve_typedef(N, T) :- ccl_typedef_of(N, T0), ccl_resolve_type(T0, T).
ccl_add_quals([], T, T) :- !.
ccl_add_quals(Q, base(Q0, S), base(Q1, S)) :- !, append(Q, Q0, Q1).
ccl_add_quals(Q, ptr(Q0, T), ptr(Q1, T)) :- !, append(Q, Q0, Q1).
ccl_add_quals(_, T, T).
%% the one door for a struct's members, so the LAYOUT MARKERS a tag carries beside them (`align_as')
%% are taken out here: the check's field walks and the lowering's member roads read this, and a marker
%% where a member/3 is expected fails a walk without a word (`phase(check)')
ccl_members_of(T, Ms) :- ccl_members_of_(T, Ms0), ccl_data_members(Ms0, Ms).
ccl_data_members([], []) :- !.
ccl_data_members([M|Ms], Out) :- ( ( ccl_layout_marker(M) ; M == union_tag ) -> Out = Out1 ; Out = [M|Out1] ), ccl_data_members(Ms, Out1).   % ... and a UNION CLASS's tag mark (0.121): `U u = {5}' initializes the first MEMBER, which the mark stood in front of
ccl_members_of_(memptr(_, _, F), [member(ptr([], base([], [void])), ptr, none), member(base([], [long]), adj, none)]) :- ccl_resolve_type(F, fn(_, _, _)), !.   % the two fields of a pointer to member function (0.100), read as `pm.ptr' by the call the desugaring makes
ccl_members_of_(base(_, [struct(_, Ms)]), Ms) :- Ms \== none, !.                 % resolved already: no resolution
ccl_members_of_(base(_, [union(_, Ms)]), Ms) :- Ms \== none, !.
ccl_members_of_(T, Ms) :- ccl_resolve_type(T, T1), ( T1 = base(_, [struct(_, Ms)]) ; T1 = base(_, [union(_, Ms)]) ), Ms \== none, !.
ccl_members_of_(T, Ms) :- ccl_resolve_type(T, base(_, [class(_, _, _, Ms0)])), !, findall(member(MT, N, I), ( member(member(MT, N, I), Ms0), \+ ( MT = base(Q, _), memberchk(static, Q) ) ), Ms).   % C++: a class's data members, the statics apart
%% C 6.7.9: A DESIGNATED INITIALIZER LIST MADE POSITIONAL (0.108), for a global's constant, which is written
%% member by member and element by element: `.f = v' and `[k] = v' move the cursor, a later designation of the
%% same slot replaces it, `.a.b = v' and `[1].x = v' gather under their slot as a sub-list (itself normalized where
%% it is emitted), a member of an anonymous struct or union goes through the member that holds it, a hole is
%% `init([])', the type's zero; a union keeps the one member given last. A list with no designator is as written.
ccl_init_norm(_, Items, Out) :- \+ ( member(item(Ds, _), Items), Ds \== [] ), !, Out = Items.
ccl_init_norm(T, Items, Out) :- ccl_resolve_type(T, T1), ccl_init_place(Items, T1, 0, [], Slots),
    (   T1 = base(_, [union(_, Ms)]) -> ( last(Items, _), Slots = [_|_] -> ccl_init_last(Slots, I-V), ccl_nth0_member(Ms, I, N), Out = [item([field(N)], V)] ; Out = [] )
    ;   findall(I, member(I-_, Slots), Is), max_list(Is, Max), ccl_init_fill(0, Max, Slots, Out) ).
ccl_init_last(Slots, S) :- last(Slots, S).
ccl_nth0_member(Ms, I, N) :- I1 is I + 1, ccl_nth(I1, Ms, member(_, N, _)).
ccl_init_fill(I, Max, _, []) :- I > Max, !.
ccl_init_fill(I, Max, Slots, [item([], V)|Out]) :- ( memberchk(I-V0, Slots) -> V = V0 ; V = init([]) ), I1 is I + 1, ccl_init_fill(I1, Max, Slots, Out).
ccl_init_place([], _, _, S, S).
ccl_init_place([item(Ds0, V)|Is], T, Cur, S0, S) :-
    ccl_init_route(T, Ds0, Ds),
    (   Ds = [] -> I = Cur, Rest = []
    ;   Ds = [at(K)|Rest] -> ccl_const_eval(K, I)
    ;   Ds = [field(F)|Rest] -> ccl_members_of(T, Ms), ccl_member_pos(Ms, F, 0, I) ),
    (   Rest == [] -> ccl_init_set(S0, I, V, S1)
    ;   ( select(I-init(L), S0, S2) -> append(L, [item(Rest, V)], L1) ; S2 = S0, L1 = [item(Rest, V)] ), S1 = [I-init(L1)|S2] ),
    Cur1 is I + 1, ccl_init_place(Is, T, Cur1, S1, S).
ccl_init_set(S0, I, V, [I-V|S1]) :- ( select(I-_, S0, S1) -> true ; S1 = S0 ).
ccl_member_pos([member(_, N, _)|_], N, I, I) :- !.
ccl_member_pos([_|Ms], N, I0, I) :- I1 is I0 + 1, ccl_member_pos(Ms, N, I1, I).
%% `.u' of a member of an anonymous struct or union is `.$anonK.u'
ccl_init_route(T, [field(F)|Rest], Ds) :- ccl_members_of(T, Ms), \+ memberchk(member(_, F, _), Ms), ccl_anon_route(T, F, A, _), !, Ds = [field(A), field(F)|Rest].
ccl_init_route(_, Ds, Ds).
%% C99's `__func__' (6.4.2.2), and GNU's `__FUNCTION__' and `__PRETTY_FUNCTION__' beside it: the enclosing function's name (0.108)
ccl_func_name(N) :- memberchk(N, ['__func__', '__FUNCTION__', '__PRETTY_FUNCTION__']), \+ ccl_declared(N, _), !.
ccl_member_type(T, '$base!', MT) :- !, ccl_member_type(T, '$base', MT).   % the virtual base AT ITS PLACE in the complete object: a constructor's and a destructor's name for it
ccl_member_type(T, '$base', MT) :- ccl_vbase_kind(T, nv(MT0)), !, MT = MT0.
ccl_member_type(T, N, MT) :- ccl_members_of(T, Ms), ( memberchk(member(MT, N, _), Ms) -> true ; ccl_anon_route(T, N, A, AT), A \== N, ccl_member_type(AT, N, MT) ).
%% the anonymous member of a C struct or union that holds a member N, directly or through another anonymous one
ccl_anon_route(T, N, A, AT) :- ccl_members_of(T, Ms), member(member(AT, A, _), Ms), atom(A), sub_atom(A, 0, _, _, '$anon'), ccl_anon_has(AT, N), !.
ccl_anon_has(T, N) :- ccl_members_of(T, Ms), ( memberchk(member(_, N, _), Ms) -> true ; member(member(AT, A, _), Ms), atom(A), sub_atom(A, 0, _, _, '$anon'), ccl_anon_has(AT, N) ), !.

%% ---- classes ----------------------------------------------------------------------
%% the literal zero, a null pointer constant ([conv.ptr]/1)
ccl_null_constant(int(0)). ccl_null_constant(uint(0)). ccl_null_constant(long(0)). ccl_null_constant(ulong(0)).
ccl_is_pointer(T) :- ccl_resolve_type(T, T1), ( T1 = ptr(_, _) ; T1 = arr(_, _) ; T1 = block(_, _) ), !.
ccl_is_float(T) :- ccl_resolve_type(T, base(_, S)), \+ memberchk('_Complex', S), ( memberchk(double, S) ; memberchk(float, S) ; memberchk('_Float16', S) ), !.   % a complex type is no real floating type
%% C's COMPLEX TYPES (C11 6.2.5, Annex G; 0.100): `_Complex double' and `_Complex float', two components of the real type;
%% the usual arithmetic conversions make a complex of the common real type where either operand is complex
ccl_is_complex(T) :- ccl_resolve_type(T, base(_, S)), memberchk('_Complex', S), !.
%% -- and `_Complex int', GNU's integer complex (0.103): the real type is whatever specifiers stand beside `_Complex'
%% (`_Complex' alone is a complex double), and the usual arithmetic conversions over two complex integers are the
%% integers' own, so `3i + 2' is a `_Complex int' and `7u + 3i' a `_Complex unsigned', as clang has them
ccl_complex_real(T, R) :- ccl_resolve_type(T, base(_, S)), ccl_specs_without(S, '_Complex', S1), ( S1 == [] -> R = base([], [double]) ; R = base([], S1) ).
ccl_complex_of(R, base([], ['_Complex'|S1])) :- ccl_resolve_type(R, base(_, S)), ccl_specs_without(S, '_Complex', S1).
ccl_complex_usual(A, B, T) :- ccl_real_of(A, RA), ccl_real_of(B, RB), ccl_usual(RA, RB, R0), ( R0 == unknown -> R = base([], [double]) ; R = R0 ), ccl_complex_of(R, T).
ccl_specs_without([], _, []).
ccl_specs_without([X|Xs], X, Ys) :- !, ccl_specs_without(Xs, X, Ys).
ccl_specs_without([Y|Xs], X, [Y|Ys]) :- ccl_specs_without(Xs, X, Ys).
ccl_real_of(T, R) :- ( ccl_is_complex(T) -> ccl_complex_real(T, R) ; R = T ).
ccl_is_integer(T) :- ccl_resolve_type(T, base(_, S)), \+ memberchk(double, S), \+ memberchk(float, S), \+ memberchk(void, S), \+ memberchk('_Complex', S),   % a complex integer is no integer (0.103)
    ( memberchk(int, S) ; memberchk(char, S) ; memberchk(short, S) ; memberchk(long, S) ; memberchk('__int128', S) ; memberchk(signed, S)
    ; memberchk(unsigned, S) ; memberchk('_Bool', S) ; memberchk(bool, S) ; memberchk(char8_t, S) ; memberchk(wchar_t, S) ; memberchk(char16_t, S) ; memberchk(char32_t, S) ; S = [enum(_, _)] ; S = [enum_class(_, _)] ; memberchk(bitint(_), S) ), !.   % C23's _BitInt(N) is an integer
ccl_is_arith(T) :- ( ccl_is_integer(T) ; ccl_is_float(T) ; ccl_is_decimal(T) ), !.
%% C23'S DECIMAL FLOATING TYPES (6.2.5/11; 0.129): `_Decimal32', `_Decimal64' and `_Decimal128', real floating types of their own,
%% kept apart from the standard ones (ccl_is_float/1 is false for them): their arithmetic is libgcc's BID routines (the lowering)
ccl_is_decimal(T) :- ccl_resolve_type(T, base(_, S)), ccl_decimal_spec(S, _), !.
ccl_decimal_kind(T, K) :- ccl_resolve_type(T, base(_, S)), ccl_decimal_spec(S, K), !.
ccl_decimal_spec(S, K) :- ( memberchk('_Decimal32', S) -> K = 32 ; memberchk('_Decimal64', S) -> K = 64 ; memberchk('_Decimal128', S) -> K = 128 ).
ccl_decimal_type(32, base([], ['_Decimal32'])).  ccl_decimal_type(64, base([], ['_Decimal64'])).  ccl_decimal_type(128, base([], ['_Decimal128'])).

%% integer rank and signedness, for the usual arithmetic conversions
ccl_int_rank(T, Rank, Unsigned) :- ccl_resolve_type(T, base(_, [E])), compound(E), ccl_enum_spec_members(E, Ms), !, ccl_enum_underlying(Ms, U), ccl_int_rank(U, Rank, Unsigned).   % AN ENUM RANKS AS ITS UNDERLYING TYPE (0.127): an int unless one is written
ccl_int_rank(T, Rank, Unsigned) :-
    ccl_resolve_type(T, base(_, S)),
    ( memberchk(unsigned, S) -> Unsigned = true ; memberchk(char16_t, S) -> Unsigned = true ; memberchk(char32_t, S) -> Unsigned = true ; memberchk(char8_t, S) -> Unsigned = true ; ccl_plain_char_unsigned(S) -> Unsigned = true ; Unsigned = false ),   % C++'s char16_t, char32_t and char8_t are UNSIGNED; wchar_t is signed on this ABI
    (   memberchk(bitint(E), S) -> ccl_bitint_width(E, W), ccl_bitint_rank(W, Rank)           % C23: below the standard type of its width, above every narrower one (6.3.1.1)
    ; memberchk('__int128', S) -> Rank = 6                                                                      % GNU's __int128 (0.117): above long long
    ; ccl_count(long, S, 2) -> Rank = 5 ; memberchk(long, S) -> Rank = 4 ; memberchk(short, S) -> Rank = 2 ; memberchk(char16_t, S) -> Rank = 2
    ; memberchk(char, S) -> Rank = 1 ; memberchk(char8_t, S) -> Rank = 1 ; memberchk('_Bool', S) -> Rank = 0 ; memberchk(bool, S) -> Rank = 0 ; Rank = 3 ).
ccl_bitint_width(E, W) :- ( ccl_const_eval(E, W0) -> W = W0 ; W = 32 ).
ccl_bitint_rank(W, R) :- ( W =< 8 -> R = 0.5 ; W =< 16 -> R = 1.5 ; W =< 32 -> R = 2.5 ; W =< 64 -> R = 3.5 ; R = 5.5 ).
ccl_is_bitint(T) :- ccl_resolve_type(T, base(_, S)), memberchk(bitint(_), S), !.
ccl_count(_, [], 0).
ccl_count(X, [Y|T], N) :- ccl_count(X, T, N0), ( X == Y -> N is N0 + 1 ; N = N0 ).
ccl_promote(T, P) :- ( ccl_resolve_type(T, base(_, S)), memberchk(char32_t, S) -> P = base([], [unsigned, int])   % C++'s char32_t and wchar_t PROMOTE TO THEIR UNDERLYING TYPES ([conv.prom]/8; 0.112): `false ? c32 : u' is an unsigned int, which libc++'s common_reference of `const char32_t &' and `const unsigned &' asks (ranges::less over the grapheme table)
                     ; ccl_resolve_type(T, base(_, S)), memberchk(wchar_t, S) -> P = base([], [int])
                     ; ccl_resolve_type(T, base(_, [E])), compound(E), ccl_enum_spec_members(E, Ms) -> ccl_enum_underlying(Ms, U), ccl_promote(U, P)   % AN ENUM PROMOTES TO ITS UNDERLYING TYPE, promoted ([conv.prom]/3-4, C23 6.3.1.1; 0.127): it stayed itself, so `c + 1' of a Color was a Color
                     ; \+ ccl_is_bitint(T), ccl_int_rank(T, R, _), R < 3 -> P = base([], [int]) ; P = T ).   % a _BitInt is never promoted (C23 6.3.1.1/2)
ccl_enum_spec_members(enum(_, Ms), Ms).
ccl_enum_spec_members(enum_class(_, Ms), Ms).
ccl_enum_underlying(Ms, U) :- ( is_list(Ms), memberchk(enum_base(B), Ms) -> U = B ; U = base([], [int]) ).
ccl_float_rank(T, R) :- ccl_resolve_type(T, base(_, S)), ( memberchk(double, S) -> ( memberchk(long, S) -> R = 3 ; R = 2 ) ; memberchk(float, S) -> R = 1 ; R = 0 ).
ccl_usual(A, B, T) :- ccl_usual_(A, B, T0), ( T0 = base(_, S) -> T = base([], S) ; T = T0 ).   % THE RESULT IS AN UNQUALIFIED VALUE (0.112): an operand's const stayed on it, and `false ? declval<const char32_t &>() : declval<const unsigned &>()' typed `const const char32_t'
ccl_usual_(A, B, T) :-
    (   ( ccl_is_decimal(A) ; ccl_is_decimal(B) ) -> ccl_decimal_usual(A, B, T)   % a DECIMAL operand decides (C23 6.3.1.8/1): the wider decimal type, an integer converted to it (0.129)
    ;   ccl_is_float(A), ccl_is_float(B) -> ( ccl_float_rank(A, FA), ccl_float_rank(B, FB), FA >= FB -> T = A ; T = B )   % the wider of the two (6.3.1.8): long double, double, float, _Float16 (0.108: a double took a long double's place)
    ;   ccl_is_float(A) -> T = A
    ;   ccl_is_float(B) -> T = B
    ;   ccl_is_integer(A), ccl_is_integer(B) ->
            ccl_promote(A, PA), ccl_promote(B, PB), ccl_int_rank(PA, RA, UA), ccl_int_rank(PB, RB, UB),
            ( RA > RB -> T = PA ; RB > RA -> T = PB ; UA == true -> T = PA ; UB == true -> T = PB ; T = PA )
    ;   T = unknown ).
%% `__builtin_add_overflow(a, b, &r)' and kin, the lowering's exact arithmetic with a bool for `did not fit'
ccl_decimal_usual(A, B, T) :- ( ccl_decimal_kind(A, KA) -> true ; KA = 0 ), ( ccl_decimal_kind(B, KB) -> true ; KB = 0 ), K is max(KA, KB), ccl_decimal_type(K, T).
ccl_overflow_builtin('__builtin_add_overflow', add).  ccl_overflow_builtin('__builtin_sub_overflow', sub).  ccl_overflow_builtin('__builtin_mul_overflow', mul).
%% the bit builtins and the LLVM intrinsic each one is (the lowering's ir_bit_builtin/2 reads this table): every one answers an int
ccl_bit_builtin('__builtin_clzg', ctlz).  ccl_bit_builtin('__builtin_clz', ctlz).  ccl_bit_builtin('__builtin_clzl', ctlz).  ccl_bit_builtin('__builtin_clzll', ctlz).
ccl_bit_builtin('__builtin_ctzg', cttz).  ccl_bit_builtin('__builtin_ctz', cttz).  ccl_bit_builtin('__builtin_ctzl', cttz).  ccl_bit_builtin('__builtin_ctzll', cttz).
ccl_bit_builtin('__builtin_popcountg', ctpop).  ccl_bit_builtin('__builtin_popcount', ctpop).  ccl_bit_builtin('__builtin_popcountl', ctpop).  ccl_bit_builtin('__builtin_popcountll', ctpop).
ccl_size_type(T) :- ( ccl_typedef_of(size_t, _) -> T = base([], [typedef(size_t)]) ; T = base([], [unsigned, long]) ).
ccl_sizeof_expr(sizeof(_)).
ccl_sizeof_expr(sizeof_type(_)).

%% ---- the type of an expression ----------------------------------------------------
ccl_type_of(int(big(A)), T) :- !, ccl_big_type(A, T).                                  % a literal past 2^60 (0.94): the first of long and unsigned long that holds it
ccl_type_of(uint(big(_)), base([], [unsigned, long])) :- !.
ccl_type_of(int(_), base([], [int])) :- !.
ccl_type_of(uint(_), base([], [unsigned])) :- !.
ccl_type_of(long(_), base([], [long])) :- !.
%% ... and a value past 64 bits, which only a fold makes (a 128-bit type's constant: libc++'s numeric_limits<__int128>), the
%% first of __int128 and unsigned __int128 that holds it (0.129: it was an unsigned long, lowered as an i64 and cut to its low
%% half); a negative value is a long where it fits one (it was an unsigned long)
ccl_big_type(A, T) :-
    (   ccl_big_fits(A, '-9223372036854775808', '9223372036854775807') -> T = base([], [long])
    ;   ccl_big_fits(A, 0, '18446744073709551615') -> T = base([], [unsigned, long])
    ;   ccl_big_fits(A, '-170141183460469231731687303715884105728', '170141183460469231731687303715884105727') -> T = base([], ['__int128'])
    ;   T = base([], [unsigned, '__int128']) ).
ccl_big_fits(A, Lo, Hi) :- ccl_big_bound(Lo, L), ccl_big_bound(Hi, H), ccl_w_cmp(big(A), L, O1), O1 \== (<), ccl_w_cmp(big(A), H, O2), O2 \== (>).
ccl_big_bound(B, V) :- ( integer(B) -> V = B ; V = big(B) ).
ccl_type_of(ulong(_), base([], [unsigned, long])) :- !.
ccl_type_of(wb(N), base([], [bitint(int(W))])) :- !, ccl_wb_width(N, W0), W is W0 + 1.   % C23's 9wb: a _BitInt of the width the value needs, plus the sign
ccl_type_of(uwb(N), base([], [unsigned, bitint(int(W))])) :- !, ccl_wb_width(N, W).
ccl_wb_width(N, W) :- ( N =:= 0 -> W = 1 ; W is msb(N) + 1 ).
ccl_type_of(bool(_), base([], [bool])) :- !.                          % C++
ccl_type_of(nullptr, ptr([], base([], [void]))) :- !.
ccl_type_of(float(_), base([], [double])) :- !.
ccl_type_of(imag(_), base([], ['_Complex', double])) :- !.
ccl_float_builtin_type('__builtin_inf', base([], [double])).      ccl_float_builtin_type('__builtin_huge_val', base([], [double])).
ccl_float_builtin_type('__builtin_inff', base([], [float])).      ccl_float_builtin_type('__builtin_huge_valf', base([], [float])).
ccl_float_builtin_type('__builtin_nan', base([], [double])).      ccl_float_builtin_type('__builtin_nanf', base([], [float])).    % the imaginary literal (0.101)
ccl_type_of(imagf(_), base([], ['_Complex', float])) :- !.
ccl_type_of(dec32(_), base([], ['_Decimal32'])) :- !.     % C23's decimal floating literals (0.129)
ccl_type_of(dec64(_), base([], ['_Decimal64'])) :- !.
ccl_type_of(dec128(_), base([], ['_Decimal128'])) :- !.
ccl_type_of(imagl(_), base([], ['_Complex', long, double])) :- !.
ccl_type_of(imagi(Sp, _), base([], ['_Complex'|Sp])) :- !.   % `3i', `2ui', `3li', `4uli' (0.104): the specifiers its suffix and its value give
ccl_type_of(chr(_), base([], [char])) :- ccl_lang(cpp), !.   % C++: a character literal is a char (C's is an int): `cout << ' '' takes the char inserter, not operator<<(int)
ccl_type_of(chr(_), base([], [int])) :- !.
%% a string literal is an ARRAY whose bytes `sizeof' counts (6.5.3.4, [expr.sizeof]; 0.103): the narrow one its codes
%% and the NUL, a wide one a code point per element (the body is UTF-8 bytes, ccl_utf8_count), `wchar_t' and
%% `char32_t' four bytes each, `char16_t' two -- the type stays the pointer it decays to everywhere else
ccl_literal_bytes(str(S), N) :- length(S, L), N is L + 1.
ccl_literal_bytes(wstr(S), N) :- ccl_utf8_count(S, K), N is (K + 1) * 4.
ccl_literal_bytes(u32str(S), N) :- ccl_utf8_count(S, K), N is (K + 1) * 4.
ccl_literal_bytes(u16str(S), N) :- ccl_utf16_count(S, K), N is (K + 1) * 2.   % UTF-16 units, a code point past U+FFFF two (0.112)
ccl_type_of(str(_), ptr([], base([], [char]))) :- !.
ccl_type_of(wstr(_), ptr([], base([], [wchar_t]))) :- !.                          % L"...": wchar_t's, u"..." char16_t's, U"..." char32_t's
ccl_type_of(u16str(_), ptr([], base([], [char16_t]))) :- !.
ccl_type_of(u32str(_), ptr([], base([], [char32_t]))) :- !.
ccl_type_of(wchr(_), base([], [wchar_t])) :- !.
ccl_type_of(u16chr(_), base([], [char16_t])) :- !.
ccl_type_of(u32chr(_), base([], [char32_t])) :- !.
ccl_type_of(id(N), T) :- !, ( ccl_declared(N, T0) -> ccl_unref(T0, T) ; atom(N), nb_getval('$ccl_enums', L), memberchk(N-_, L) -> ccl_enumerator_type(N, L, T) ; ccl_func_name(N) -> T = ptr([], base([const], [char])) ; T = unknown ).   % AN ENUMERATOR is an int in C, its ENUM in C++ (0.127; ccl_enumerator_type): the parser declares one in scope, the bulk noter keeps its value and its enum in the table of values, so after the passes' rebuild it is found there (0.100: it was `unknown' when the table held only the value -- libc++'s __to_failure_order)
ccl_type_of(call(id(B), _), base([], [bool])) :- ccl_overflow_builtin(B, _), !.
ccl_type_of(call(id(B), _), base([], [int])) :- ccl_bit_builtin(B, _), !.   % the bit counts answer an int (0.129): `c ? 64 + __builtin_clzll(x) : __builtin_clzll(y)' had no type, in C as in C++ (libc++'s `__libcpp_clz(__uint128_t)')
ccl_type_of(call(id(B), _), T) :- ccl_float_builtin_type(B, T), !.
ccl_type_of(call(id(B), [_]), base([], [int])) :- memberchk(B, ['__builtin_isnan', '__builtin_isinf', '__builtin_isinf_sign', '__builtin_isfinite', '__builtin_signbit', '__builtin_isnormal']), !.   % glibc's classification macros (0.101)                                   % INFINITY, NAN, HUGE_VAL (0.101)
ccl_type_of(call(id('__builtin_complex'), [A, _]), T) :- ccl_type_of(A, AT), AT \== unknown, !, ccl_complex_of(AT, T).   % C11's CMPLX and I, in the compiler's <complex.h> (0.100)   % C23's <stdckdint.h> is written on them
ccl_type_of(call(id(B), _), T) :- ccl_coro_builtin_type(B, T), !.   % C++20's coroutine builtins, libc++'s coroutine_handle (0.108)
ccl_type_of(braced_temp(E), T) :- !, ccl_type_of(E, T).   % `T{a, b}' (reader version 113): the call it was before
ccl_type_of(call(F, _), T) :- !,
    (   F = id(N), ccl_declared(N, fn(R, _, _)) -> ccl_unref(R, T)
    ;   ccl_type_of(F, FT), ccl_resolve_type(FT, FT1),
        ( FT1 = fn(R, _, _) -> ccl_unref(R, T) ; FT1 = ptr(_, fn(R, _, _)) -> ccl_unref(R, T) ; FT1 = block(_, fn(R, _, _)) -> ccl_unref(R, T) ; T = unknown ) ).
ccl_type_of(member(E, N), T) :- !, ccl_type_of(E, ET), ( ccl_member_type(ET, N, T0) -> ccl_unref(T0, T) ; T = unknown ).
ccl_type_of(arrow(E, N), T) :- !, ccl_type_of(E, ET), ccl_resolve_type(ET, ET1),
    ( ( ET1 = ptr(_, ST) ; ET1 = arr(_, ST) ), ccl_member_type(ST, N, T0) -> ccl_unref(T0, T) ; T = unknown ).
ccl_type_of(index(A, _), T) :- !, ccl_type_of(A, AT), ccl_resolve_type(AT, AT1), ( ( AT1 = ptr(_, T0) ; AT1 = arr(_, T0) ) -> ccl_unref(T0, T) ; T = unknown ).
ccl_type_of(deref(E), T) :- !, ccl_type_of(E, ET), ccl_resolve_type(ET, ET1), ( ( ET1 = ptr(_, T0) ; ET1 = arr(_, T0) ) -> ccl_unref(T0, T) ; T = unknown ).
%% C++ (M6): a reference is the thing it refers to wherever a value is asked;
%% a qualified name is its bare name (a namespace flattens); the casts, new
ccl_type_of(scoped(_, N), T) :- !, ccl_type_of(id(N), T).
ccl_type_of(ccast(_, T0, _), T) :- !, ccl_unref(T0, T).   % a C++ cast to a REFERENCE type names the object, as every other lvalue does: `const_cast<value_type &>(*p)' has the value's type here (deduction took the reference as the argument's type and addressof's `_Tp &' became a reference to a reference)
ccl_type_of(new(T, _), ptr([], T)) :- !.
ccl_type_of(new_default(T), ptr([], T)) :- !.
ccl_type_of(new_at(_, N), T) :- !, ccl_type_of(N, T).                              % placement new: the type the plain one has
ccl_type_of(new_array(T, _), ptr([], T)) :- !.
ccl_type_of(delete(_), base([], [void])) :- !.
ccl_type_of(delete_array(_), base([], [void])) :- !.
ccl_type_of(addr(E), T) :- !, ccl_type_of(E, ET), ( ET == unknown -> T = unknown ; T = ptr([], ET) ).
ccl_type_of(neg(E), T) :- ccl_type_of(E, ET), ccl_is_complex(ET), !, T = ET.
ccl_type_of(real_part(E), T) :- !, ccl_type_of(E, ET), ( ccl_is_complex(ET) -> ccl_complex_real(ET, T) ; ccl_is_arith(ET) -> T = ET ; T = unknown ).   % GNU's `__real__ z', `__imag__ z' (0.100)
ccl_type_of(imag_part(E), T) :- !, ccl_type_of(E, ET), ( ccl_is_complex(ET) -> ccl_complex_real(ET, T) ; ccl_is_arith(ET) -> T = ET ; T = unknown ).
ccl_type_of(neg(E), T) :- !, ccl_type_of(E, ET), ccl_promoted_or_unknown(ET, T).
ccl_type_of(pos(E), T) :- !, ccl_type_of(E, ET), ccl_promoted_or_unknown(ET, T).
ccl_type_of(bitnot(E), T) :- !, ccl_type_of(E, ET), ccl_promoted_or_unknown(ET, T).
ccl_type_of(not(_), T) :- !, ccl_truth_type(T).
ccl_type_of(preinc(E), T) :- !, ccl_type_of(E, T).
ccl_type_of(predec(E), T) :- !, ccl_type_of(E, T).
ccl_type_of(postinc(E), T) :- !, ccl_type_of(E, T).
ccl_type_of(postdec(E), T) :- !, ccl_type_of(E, T).
ccl_type_of(sizeof(_), T) :- !, ccl_size_type(T).
ccl_type_of(sizeof_type(_), T) :- !, ccl_size_type(T).
ccl_type_of(offsetof(_, _), T) :- !, ccl_size_type(T).
ccl_type_of(noexcept_expr(_), base([], [bool])) :- !.
ccl_type_of(rtti(_), base([const], [typedef(type_info)])) :- !.          % a type_info object (0.108)
ccl_type_of(rtti_dyn(_), base([const], [typedef(type_info)])) :- !.
ccl_type_of(dyncast(_, _, _, T), T) :- !.
ccl_type_of(eh_alloc(_), ptr([], base([], [void]))) :- !.
ccl_coro_builtin_type('__builtin_coro_frame', ptr([], base([], [void]))).
ccl_coro_builtin_type('__builtin_coro_noop', ptr([], base([], [void]))).
ccl_coro_builtin_type('__builtin_coro_promise', ptr([], base([], [void]))).
ccl_coro_builtin_type('__builtin_coro_resume', base([], [void])).
ccl_coro_builtin_type('__builtin_coro_destroy', base([], [void])).
ccl_coro_builtin_type('__builtin_coro_done', base([], [bool])).
ccl_type_of(eh_throw(_, _, _), base([], [void])) :- !.
ccl_type_of(eh_rethrow, base([], [void])) :- !.
ccl_type_of(eh_terminate, base([], [void])) :- !.
ccl_type_of(throw(_), base([], [void])) :- !.
ccl_type_of(dyncast_ref(_, _, _, T), T) :- !.
ccl_type_of(va_arg(_, T0), T) :- !, T = T0.
ccl_type_of(alignof_type(_), T) :- !, ccl_size_type(T).
ccl_type_of(cast(T, _), T) :- !.
ccl_type_of(move(E), T) :- !, ccl_type_of(E, T).
ccl_type_of(compound_lit(T, _), T) :- !.
ccl_type_of(assign(_, L, _), T) :- !, ccl_type_of(L, T).
ccl_type_of(comma(_, B), T) :- !, ccl_type_of(B, T).
ccl_type_of(cond(_, A, B), T) :- !, ccl_type_of(A, AT), ccl_type_of(B, BT),
    (   ccl_is_arith(AT), ccl_is_arith(BT) -> ccl_cond_arith(AT, BT, T)
    ;   A == nullptr -> T = BT          % a null pointer constant takes the OTHER arm's type ([expr.cond]), unknown included: typed `void *' by its
    ;   B == nullptr -> T = AT          % nullptr while the other arm was still unknown, `__nbc > 0 ? allocate(...) : nullptr' chose unique_ptr's `reset(nullptr_t)' and dropped the buckets
    ;   ccl_null_constant(A), ccl_is_pointer(BT) -> T = BT      % `c ? 0 : p': the literal zero is a null pointer constant and takes the pointer's type ([expr.cond]/7), where the arm `0' made it an int (0.117): libc++'s `deque::begin()' passes `__map_.empty() ? 0 : *__mp + __start_ % __block_size' to an iterator taking a pointer, and no constructor fit
    ;   ccl_null_constant(B), ccl_is_pointer(AT) -> T = AT
    ;   AT \== unknown -> T = AT ; T = BT ).
ccl_type_of(stmt_expr(block(Is)), T) :- !,            % its declarations are in scope for its last expression
    ccl_scope_push, ccl_note_items(Is),
    ( append(_, [expr(_, E)], Is) -> ccl_type_of(E, T) ; T = base([], [void]) ),
    ccl_scope_pop.
ccl_type_of(bin(Op, A, B), T) :- !,
    ccl_type_of(A, AT), ccl_type_of(B, BT),
    (   memberchk(Op, ['&&', '||']) -> ccl_truth_type(T)
    ;   memberchk(Op, ['<', '>', '<=', '>=', '==', '!=']) -> ( ccl_lang(cpp), ( ccl_class_operand(AT) ; ccl_class_operand(BT) ) -> T = unknown ; ccl_truth_type(T) )   % a CLASS operand: the operator the desugaring chooses decides (its declared result), never the built-in's
    ;   memberchk(Op, ['<<', '>>']) -> ccl_promoted_or_unknown(AT, T)
    ;   memberchk(Op, ['+', '-']), ccl_is_pointer(AT), ccl_is_pointer(BT) -> T = base([], [long])
    ;   memberchk(Op, ['+', '-']), ccl_is_pointer(AT) -> ccl_decay(AT, T)
    ;   Op == '+', ccl_is_pointer(BT) -> ccl_decay(BT, T)
    ;   memberchk(Op, ['+', '-', '*', '/']), ( ccl_is_complex(AT) ; ccl_is_complex(BT) ) -> ccl_complex_usual(AT, BT, T)   % complex arithmetic (0.100)
    ;   ccl_is_arith(AT), ccl_is_arith(BT) -> ccl_usual(AT, BT, T)
    ;   T = unknown ).
ccl_type_of(_, unknown).
ccl_unref(ref(_, T), T) :- !.
ccl_unref(rref(_, T), T) :- !.
ccl_unref(T, T).
%% THE TYPE OF A COMPARISON, `!', `&&' AND `||': an int in C (6.5.8/6, 6.5.9/3, 6.5.13/3, 6.5.3.3/5), a BOOL in C++
%% ([expr.rel]/1, [expr.eq]/1, [expr.log.and]/1, [expr.unary.op]/9; 0.127). It was an int in both: `decltype(x < y)',
%% `auto b = x < y' (sizeof 4), `std::cout << std::boolalpha << (x < y)' (`1') and `f(x < y)' beside `f(int)' and
%% `f(bool)' (the int overload) all said so. The lowering makes the value the type says (ir_truth/4).
ccl_truth_type(T) :- ( ccl_lang(cpp) -> T = base([], [bool]) ; T = base([], [int]) ).
ccl_class_operand(T) :- T \== unknown, ccl_resolve_type(T, base(_, [S])), compound(S), ( S = struct(_, _) ; S = class(_, _, _, _) ; S = union(_, _) ), !.
%% an enumerator's type: its enum in C++ where the table names a named enum still in the tag table, else an int
%% (C's, and an unnamed enum's)
ccl_enumerator_type(N, L, T) :- ccl_lang(cpp), ccl_enumerator_tag(N, L, Tag), ccl_tag(Tag, Ms), Ms \== none, !, T = base([], [typedef(Tag)]).
ccl_enumerator_type(_, _, base([], [int])).
%% THE CONDITIONAL OVER TWO ARMS OF ONE ARITHMETIC TYPE HAS THAT TYPE in C++ ([expr.cond]/7.1: the usual arithmetic
%% conversions only bring two DIFFERENT types to one; 0.127), where C converts them always (6.5.15/5): `std::cout <<
%% (c ? 'Y' : 'N')' printed 89, the char inserter passed over for the int one, and `c ? Red : Green' was no Color
ccl_cond_arith(AT, BT, T) :- ccl_lang(cpp), ccl_resolve_type(AT, base(_, SA)), ccl_resolve_type(BT, base(_, SB)),
    ccl_type_canon(base([], SA), K), ccl_type_canon(base([], SB), K), !, ( AT = base(_, S0) -> T = base([], S0) ; T = base([], SA) ).
ccl_cond_arith(AT, BT, T) :- ccl_usual(AT, BT, T).
%% a range-for over an array as the for it is: `for (T x : xs) S' is
%% `for (int i = 0; i < N; i++) { T x = xs[i]; S }', an `auto &' binding a
%% reference to the element; the check and the lowering both walk the for
ccl_for_each_as_for(for_each(L, var(N, T, none), Range, S),
                    for(L, decl(base([], [int]), [var(I, base([], [int]), int(0))]), bin('<', id(I), NE), postinc(id(I)),
                        block([declaration(L, none, ET, [var(N, T1, index(Range, id(I)))]), S]))) :-
    ccl_type_of(Range, RT), ccl_resolve_type(RT, arr(NE, ET)),
    ccl_gensym('$i', I), ccl_range_var_type(T, ET, T1).
ccl_range_var_type(base(_, [auto]), ET, ET) :- !.
ccl_range_var_type(ref(Q, base(_, [auto])), ET, ref(Q, ET)) :- !.
ccl_range_var_type(rref(Q, base(_, [auto])), ET, ref(Q, ET)) :- !.
ccl_range_var_type(ptr(Q, base(_, [auto])), ET, T) :- !, ( ccl_resolve_type(ET, ptr(_, _)) -> T = ET ; T = ptr(Q, ET) ).
ccl_range_var_type(T, _, T).
ccl_promoted_or_unknown(ET, T) :- ( ccl_is_integer(ET) -> ccl_promote(ET, T) ; ccl_is_float(ET) -> T = ET ; ccl_is_decimal(ET) -> T = ET ; T = unknown ).
%% an array decays to a pointer to its element, a function to a pointer to
%% itself; anything else keeps its name (a typedef stays a typedef)
%% the canonical form of a resolved type, for `_Generic' (the reader) -- every typedef resolved through the pointers,
%% arrays and functions, the specifiers sorted with `signed' dropped (but on a char), `int' dropped beside short or
%% long and supplied for a bare `unsigned', so `unsigned' and `unsigned int' are one type as C has them
ccl_type_canon(T, K) :- ccl_resolve_type(T, T1), ccl_type_canon_(T1, K).
ccl_type_canon_(base(Q, S), base(Q1, K)) :- !, msort(Q, Q1), msort(S, S1), ( memberchk(char, S1) -> S2 = S1 ; delete(S1, signed, S2) ),
    ( ( memberchk(short, S2) ; memberchk(long, S2) ) -> delete(S2, int, S3) ; S2 == [unsigned] -> S3 = [int, unsigned] ; S3 = S2 ), ccl_canon_specs(S3, K).
ccl_type_canon_(ptr(_, T), ptr(K)) :- !, ccl_type_canon(T, K).
ccl_type_canon_(arr(N, T), arr(V, K)) :- !, ( ccl_const_eval(N, V) -> true ; V = N ), ccl_type_canon(T, K).
ccl_type_canon_(fn(R, Ps, V), fn(RK, PKs, V)) :- !, ccl_type_canon(R, RK), findall(PK, ( member(param(PT, _), Ps), ccl_type_canon(PT, PK) ), PKs).
ccl_type_canon_(T, T).
ccl_canon_specs([], []).
ccl_canon_specs([S|Ss], [K|Ks]) :- ( S = struct(Tag, _) -> K = struct(Tag) ; S = union(Tag, _) -> K = union(Tag) ; S = enum(Tag, _) -> K = enum(Tag) ; K = S ), ccl_canon_specs(Ss, Ks).
ccl_decay(T, D) :- ccl_resolve_type(T, T1), ( T1 = arr(_, E) -> D = ptr([], E) ; T1 = fn(_, _, _) -> D = ptr([], T1) ; D = T ).

%% ---- sizes, LP64 ---------------------------------------------------------------------
ccl_size_of(T, N) :- ccl_resolve_type(T, T1), ccl_size_align(T1, N, _).
ccl_size_align(ptr(_, _), 8, 8) :- !.
ccl_size_align(block(_, _), 8, 8) :- !.
ccl_size_align(fn(_, _, _), 8, 8) :- !.
ccl_size_align(memptr(_, _, F), 16, 8) :- ccl_resolve_type(F, fn(_, _, _)), !.   % A POINTER TO MEMBER FUNCTION IS THE ITANIUM ABI'S `{ ptr, adj }' (0.100): the function's address, or 1 + the slot's byte offset in the table for a virtual one, and the this adjustment (0 here: a base's address is made by the conversion at the call)
ccl_size_align(memptr(_, _, _), 8, 8) :- !.                                    % a pointer to member: a function's is the address of the one function emitted for it, a data member's its byte offset (0.99)                          % a pointer to member function: the address of the one function emitted for it
ccl_size_align(arr(NE, E), N, A) :- !, ( ccl_size_align(E, EN0, A0) -> EN = EN0, A = A0 ; ccl_resolve_type(E, E1), ccl_size_align(E1, EN, A) ), ( ccl_const_eval(NE, K) -> N is K * EN ; N = 0 ).   % a flexible member, `T a[]' or `own T *a[n]': no bytes of its own; the ELEMENT resolved (the resolver leaves an array as it is, and `std::string s[2]' had no size)
ccl_size_align(base(Q, S), N, A) :- memberchk(aligned(E), Q), ccl_const_eval(E, A0), !, ccl_size_align(base([], S), N, A1), A is max(A0, A1).   % `_Alignas(E)' on a member or an object ([dcl.align]; 0.99): never below the natural alignment -- and THE SIZE UNCHANGED (0.112): an alignment specifier moves where an object or a member lies, never how big it is; rounded, `_Alignas(16) int x' had `sizeof x' 16, the member after it lay 16 bytes on, and on an array, whose element carries the qualifier, every element counted at the alignment: `alignas(S) unsigned char buf[sizeof(S)]' was 192 bytes to sizeof for 24, and a loop over it wrote past the stack slot
ccl_size_align(base(_, S), N, A) :- memberchk(bitint(E), S), !, ccl_bitint_width(E, W),     % _BitInt(N): the smallest integer type that holds it up to 64 bits; past that, whole eightbytes aligned 8 (the psABI)
    ( W =< 8 -> N = 1 ; W =< 16 -> N = 2 ; W =< 32 -> N = 4 ; N is ((W + 63) // 64) * 8 ), ( N > 8 -> A = 8 ; A = N ).
ccl_size_align(base(_, S), N, A) :- memberchk('_Complex', S), !, ccl_complex_real(base([], S), R), ccl_size_align(R, A, _), N is 2 * A.   % a complex: two components, aligned as one (0.100; an integer's too, 0.103)
ccl_size_align(base(_, S), N, A) :- ccl_basic_size(S, N), !, A = N.
ccl_size_align(base(_, [struct(_, Ms)]), N, A) :- Ms \== none, memberchk(virtual_base_of(_), Ms), !, ccl_members_layout(Ms, Lays, _, A),   % A BASE-SUBOBJECT FORM takes its DATA size (the Itanium ABI's dsize, 0.110): what follows it in the complete object may lie in its tail padding, as clang lays `int d' of `struct D : B, C' at 28, inside C's 16 bytes
    findall(E, ( member(lay(_, T, Off, _), Lays), ccl_resolve_type(T, T1), ccl_size_align(T1, S, _), E is Off + S ), Es), ( Es == [] -> N = 0 ; max_list(Es, N) ).
ccl_size_align(base(_, [struct(_, Ms)]), N, A) :- Ms \== none, !, ccl_struct_layout(Ms, 0, 1, N0, A0), ccl_tag_size(Ms, N0, A0, N, A).
ccl_size_align(base(_, [union(_, Ms)]), N, A) :- Ms \== none, !, ccl_union_layout(Ms, 0, 1, N0, A0), ccl_tag_size(Ms, N0, A0, N, A).
%% a tag's size and alignment: the members' own, the empty class's byte, and `alignas' where the class
%% states one ([dcl.align]: never smaller than the natural alignment, and the size rounds up to it)
ccl_tag_size(Ms, N0, A0, N, A) :- ccl_class_size(Ms, N0, N1), ccl_align_as(Ms, A0, A), ccl_round_up(N1, A, N).
ccl_align_as(Ms, A0, A) :- findall(V, ( member(align_as(E), Ms), ccl_const_eval(E, V) ), Vs), ccl_max_align(Vs, A0, A).
ccl_max_align([], A, A).
ccl_max_align([V|Vs], A0, A) :- ( V > A0 -> A1 = V ; A1 = A0 ), ccl_max_align(Vs, A1, A).
%% AN EMPTY CLASS HAS SIZE ONE ([class]/4): two objects of it must have two addresses, an array of
%% them n, and `new' must hand back something. In C an empty struct is a GNU extension of no bytes
%% and stays so. The rule cannot be written without the one beside it -- an empty BASE takes no
%% bytes (cpp_base_layout, the empty base optimization) -- or every class deriving from an empty one
%% would grow by a byte where C++ gives it none, and libc++'s allocators, comparators and tuple
%% leaves are empty bases everywhere.
ccl_class_size(Ms, 0, N) :- ccl_lang(cpp), ccl_no_data_members(Ms), !, N = 1.   % NO DATA MEMBERS AT ALL is what [class]/4 asks: a class whose one member is a zero-length array (libc++'s compressed-pair padding, `char __padding_[sizeof(T) - __datasizeof_v<T>]') HAS a member and keeps the no bytes the GNU extension gives it
ccl_class_size(_, N, N).
ccl_size_align(base(_, [enum(_, [enum_base(T)|_])]), N, A) :- !, ( ccl_size_align(T, N, A) -> true ; ccl_resolve_type(T, T1), ccl_size_align(T1, N, A) ).   % `enum E : size_t' is eight bytes; a typedef'd underlying type is RESOLVED first (0.112): `enum class __alignment : uint8_t' had no size, so libc++ 18's format-spec parser lost its bitfields from the layout
ccl_size_align(base(_, [enum(_, _)]), 4, 4) :- !.
ccl_size_align(base(_, [enum_class(_, _)]), 4, 4) :- !.
ccl_size_align(ref(_, _), 8, 8) :- !.                                            % C++: a reference is a pointer in memory
ccl_size_align(rref(_, _), 8, 8) :- !.
%% LONG DOUBLE (0.108): x87's 80 bits in sixteen bytes aligned sixteen on x86-64, as the SysV ABI has it; a double on
%% arm64 as Apple has it (Linux on arm64 has an IEEE quad, which no gate here runs on)
ccl_va_list_type(Q, T) :- ( once(catch(pp_arch(A), _, fail)) -> true ; A = x86_64 ),     % the target's (0.131)
    ( A == arm64, once(catch(pp_os(darwin), _, fail)) -> T = ptr(Q, base([], [char]))
    ; A == arm64 -> T = arr(int(4), base(Q, [unsigned, long]))
    ; T = arr(int(3), base(Q, [unsigned, long])) ).
%% offsetof(T, designator) (C 7.19/3, `__builtin_offsetof'): the byte offset the layout computes, a member name,
%% `.m' and `[i]' along the path; an index is a constant expression times the element's size
ccl_offsetof(T, D, Off) :- ccl_offset_steps(D, Steps), ccl_offset_walk(Steps, T, 0, Off).
ccl_offset_steps(id(N), [m(N)]) :- !.
ccl_offset_steps(member(X, N), S) :- !, ccl_offset_steps(X, S0), append(S0, [m(N)], S).
ccl_offset_steps(index(X, I), S) :- !, ccl_offset_steps(X, S0), append(S0, [i(I)], S).
ccl_offset_walk([], _, Off, Off).
ccl_offset_walk([m(N)|Ss], T, Acc, Off) :- ccl_resolve_type(T, R), ccl_offset_member_of(R, N, MT, MO), !, Acc1 is Acc + MO, ccl_offset_walk(Ss, MT, Acc1, Off).
ccl_offset_walk([i(I)|Ss], T, Acc, Off) :- ccl_resolve_type(T, arr(_, E)), ccl_const_eval(I, V), ccl_size_of(E, Sz), !, Acc1 is Acc + V * Sz, ccl_offset_walk(Ss, E, Acc1, Off).
%% a member of an anonymous struct or union is the holder's own, at the anonymous member's offset plus its own
ccl_offset_member_of(R, N, MT, MO) :- ccl_members_of(R, Ms), ( R = base(_, [union(_, _)]) -> findall(lay(M, T, 0, none), member(member(T, M, _), Ms), Lays) ; ccl_members_layout(Ms, Lays, _, _) ),
    ( memberchk(lay(N, MT, MO, _), Lays) -> true
    ; member(lay(A, AT, AO, _), Lays), ccl_anon_member(A), ccl_resolve_type(AT, AR), ccl_offset_member_of(AR, N, MT, O2), MO is AO + O2 ), !.
ccl_anon_member(A) :- atom(A), sub_atom(A, 0, _, _, '$anon'), !.
ccl_long_double(K) :- catch(nb_getval('$ccl_ldbl', K0), _, fail), !, K = K0.
ccl_long_double(K) :- ( once(catch(pp_arch(A), _, fail)) -> true ; A = x86_64 ),   % the target's (0.131): an IEEE quad on Linux aarch64, a double on Apple's arm64, x87's on x86-64
    ( A == arm64, once(catch(pp_os(linux), _, fail)) -> K0 = quad ; A == arm64 -> K0 = double ; K0 = x87 ), nb_setval('$ccl_ldbl', K0), K = K0.
%% PLAIN CHAR AND wchar_t ARE UNSIGNED ON LINUX AARCH64 (AAPCS64; 0.131), as clang has them (`__CHAR_UNSIGNED__', `__WCHAR_UNSIGNED__')
ccl_char_unsigned :- once(catch(pp_arch(arm64), _, fail)), once(catch(pp_os(linux), _, fail)).
ccl_plain_char_unsigned(S) :- ( memberchk(char, S) ; memberchk(wchar_t, S) ), \+ memberchk(signed, S), ccl_char_unsigned.
ccl_basic_size(S, N) :- ( memberchk(double, S) -> ( memberchk(long, S), ( ccl_long_double(x87) ; ccl_long_double(quad) ) -> N = 16 ; N = 8 ) ; memberchk(float, S) -> N = 4 ; memberchk('_Float16', S) -> N = 2 ; memberchk('_Decimal32', S) -> N = 4 ; memberchk('_Decimal64', S) -> N = 8 ; memberchk('_Decimal128', S) -> N = 16 ; ccl_count(long, S, 2) -> N = 8
    ; memberchk('__int128', S) -> N = 16
    ; memberchk(long, S) -> N = 8 ; memberchk(short, S) -> N = 2 ; memberchk(char, S) -> N = 1 ; memberchk('_Bool', S) -> N = 1 ; memberchk(bool, S) -> N = 1 ; memberchk(char8_t, S) -> N = 1 ; memberchk(char16_t, S) -> N = 2 ; memberchk(wchar_t, S) -> N = 4 ; memberchk(char32_t, S) -> N = 4
    ; memberchk(int, S) -> N = 4 ; memberchk(unsigned, S) -> N = 4 ; memberchk(signed, S) -> N = 4 ; memberchk(void, S) -> N = 1 ; fail ).
ccl_struct_layout(Ms, _, _, N, Al) :- ccl_members_layout(Ms, _, N, Al).
%% ccl_members_layout(+Members, -Lays, -Size, -Align): where every member lies --
%% lay(Name, T, ByteOff, none) for a plain member, lay(Name, T, UnitByteOff,
%% bits(BitOffInUnit, Width, UnitBytes)) for a bitfield. The packing is the
%% SysV one (clang's): a bitfield lands at the next bit unless it would cross
%% a boundary of its declared type's alignment, then at that boundary; a zero
%% width closes the unit; a plain member is aligned as usual; the struct's
%% alignment counts every member's, a bitfield's declared type included.
%% a struct's layout is asked at every member access: kept per member list
ccl_members_layout(Ms, Lays, Size, Align) :- ccl_cached('$ccl_laycache', Ms, lay(Lays, Size, Align), ccl_members_layout_nocache(Ms, Lays, Size, Align)).
ccl_members_layout_nocache(Ms, Lays, Size, Align) :- ccl_members_layout_(Ms, 0, 1, acc([], 0), Lays, Bits, Align, EE), Bytes0 is (Bits + 7) // 8, Bytes is max(Bytes0, EE), ccl_round_up(Bytes, Align, Size).
%% THE EMPTY SUBOBJECTS PLACED SO FAR travel with the walk (acc(Seen, EmptyEnd): the empty subobjects' tags and offsets,
%% and the byte past the last of them), since an EMPTY `[[no_unique_address]]' MEMBER IS PLACED BY THE ABI'S RULE
%% (Itanium 2.4 II.3, measured against clang++, 0.96): at offset ZERO, whatever lies there, unless an empty subobject of
%% ITS OWN TYPE is there already -- then at the current data size, rounded to its alignment, and on by its alignment
%% while such a subobject is in the way. It takes no bytes of the data, and the class's size still covers its byte.
%% `struct { int x; [[no_unique_address]] E a, b; }' is `a' at 0, `b' at 4, eight bytes; `struct { [[no_unique_address]]
%% E a; char c; }' one byte, `c' at 0. Before, such a member lay one past the members before it (0.89's not-done).
ccl_members_layout_([], Bits, Al, acc(_, EE), [], Bits, Al, EE).
ccl_members_layout_([member(T, N, W0)|Ms], Bit0, Al0, acc(Seen, EE0), Lays, Bits, Al, EE) :-
    ccl_resolve_type(T, T1), ccl_size_align(T1, S, A), ABits is A * 8,
    (   W0 == no_unique_address, ccl_empty_layout(T1)
    ->  ccl_empty_tag(T1, Tag), ccl_empty_offset(Tag, A, Bit0, Seen, Off), Bit1 = Bit0, Al1 is max(Al0, A),   % no bytes, its ALIGNMENT kept -- libc++ marks every container's allocator and comparator with it
        EE1 is max(EE0, Off + S), Seen1 = [Tag-Off|Seen],
        Lays = [lay(N, T, Off, empty)|Lays1]
    ;   ccl_plain_width(W0)
    ->  ccl_round_up(Bit0, ABits, B1), Off is B1 // 8, Bit1 is B1 + S * 8, Al1 is max(Al0, A), EE1 = EE0,
        ( ccl_empty_layout(T1), ccl_empty_tag(T1, Tag) -> Seen1 = [Tag-Off|Seen] ; Seen1 = Seen ),   % a plain member of an empty class is an empty subobject too, and its byte is in the way of a marked one of its type
        Lays = [lay(N, T, Off, none)|Lays1]
    ;   ccl_bit_width(W0, W), Seen1 = Seen, EE1 = EE0,
        (   W =:= 0 -> ccl_round_up(Bit0, ABits, Bit1), Al1 = Al0, Lays = Lays1
        ;   ( (Bit0 mod ABits) + W > ABits -> ccl_round_up(Bit0, ABits, Start) ; Start = Bit0 ),
            UnitStart is (Start // ABits) * ABits, Off is UnitStart // 8, BOff is Start - UnitStart,
            Bit1 is Start + W, Al1 is max(Al0, A),
            Lays = [lay(N, T, Off, bits(BOff, W, S))|Lays1] ) ),
    ccl_members_layout_(Ms, Bit1, Al1, acc(Seen1, EE1), Lays1, Bits, Al, EE).
%% A LAYOUT IS OVER DATA MEMBERS: a C++ class's tag carries its constructors, methods and typedefs beside them, and
%% a nested one reaches the layout as the reader gave it -- libc++'s `union __rep' has three constructors.
ccl_members_layout_([_|Ms], Bit0, Al0, Acc, Lays, Bits, Al, EE) :- ccl_members_layout_(Ms, Bit0, Al0, Acc, Lays, Bits, Al, EE).
ccl_empty_tag(base(_, [struct(Tag, _)]), Tag) :- !.
ccl_empty_tag(base(_, [union(Tag, _)]), Tag) :- !.
ccl_empty_tag(T, T).
ccl_empty_offset(Tag, A, Bit0, Seen, Off) :-
    (   \+ memberchk(Tag-0, Seen) -> Off = 0
    ;   Bytes is (Bit0 + 7) // 8, ccl_round_up(Bytes, A, C0), ccl_empty_step(Tag, A, Seen, C0, Off) ).
ccl_empty_step(Tag, A, Seen, C, Off) :- ( memberchk(Tag-C, Seen) -> C1 is C + A, ccl_empty_step(Tag, A, Seen, C1, Off) ; Off = C ).
ccl_plain_width(none).
ccl_plain_width(no_unique_address).                                              % the mark is no bitfield width: a member carrying it over a type with bytes lies where it always did
%% AN EMPTY CLASS IS ONE WITH NO DATA MEMBERS AT ALL ([class]/4) -- the same test `ccl_class_size' asks, and
%% written once. NOT "lays out to zero": `ccl_members_layout_' SKIPS a member whose type it cannot size yet (its
%% last clause takes anything), so a class whose members are not resolvable at the moment of asking lays out to
%% zero and would read as empty. libc++'s compressed pair marks `__rep_' ITSELF with `[[no_unique_address]]', and
%% by the weaker test basic_string's 24-byte union became a member of no bytes -- the struct came out
%% `{ {}, padding, {}, {} }' with no `__rep_' in it, every string was its own first byte, and `a + ", "' was empty.
ccl_empty_layout(T) :- ( T = base(_, [struct(_, Ms)]) ; T = base(_, [union(_, Ms)]) ), Ms \== none, ccl_no_data_members(Ms).
ccl_no_data_members(Ms) :- \+ member(member(_, _, _), Ms).
ccl_bit_width(int(W), W) :- !.
ccl_bit_width(W, W) :- integer(W), !.
ccl_bit_width(E, W) :- ccl_const_eval(E, W).
ccl_union_layout([], S, Al, N, Al) :- ccl_round_up(S, Al, N).
ccl_union_layout([member(T, _, _)|Ms], S0, Al0, N, Al) :-
    ccl_resolve_type(T, T1), ccl_size_align(T1, S, A), S1 is max(S0, S), Al1 is max(Al0, A), ccl_union_layout(Ms, S1, Al1, N, Al).
ccl_union_layout([_|Ms], S0, Al0, N, Al) :- ccl_union_layout(Ms, S0, Al0, N, Al).      % the data members alone, as above
ccl_round_up(X, A, Y) :- Y is ((X + A - 1) // A) * A.

%% ---- the tie, `x tie y' -------------------------------------------------------
%% `x tie y' declares x to live within y. The reader keeps it as the qualifier
%% tie(Y) in the OUTERMOST qualifier list of x's type -- through an array to
%% its element, through a function to its result, which is how a result is
%% tied to a parameter. The check reads it (library(ccl_check)); the lowering
%% and the layout never look at a qualifier, so it costs them nothing.
ccl_add_tie(Y, base(Q, S), base([tie(Y)|Q], S)) :- !.
ccl_add_tie(Y, ptr(Q, T), ptr([tie(Y)|Q], T)) :- !.
ccl_add_tie(Y, block(Q, T), block([tie(Y)|Q], T)) :- !.
ccl_add_tie(Y, arr(N, T0), arr(N, T)) :- !, ccl_add_tie(Y, T0, T).
ccl_add_tie(Y, fn(R0, Ps, V), fn(R, Ps, V)) :- !, ccl_add_tie(Y, R0, R).
ccl_add_tie(_, T, T).
ccl_tie_of(base(Q, _), Y) :- memberchk(tie(Y), Q), !.
ccl_tie_of(ptr(Q, _), Y) :- memberchk(tie(Y), Q), !.
ccl_tie_of(block(Q, _), Y) :- memberchk(tie(Y), Q), !.
ccl_tie_of(arr(_, T), Y) :- !, ccl_tie_of(T, Y).
ccl_tie_of(fn(R, _, _), Y) :- !, ccl_tie_of(R, Y).
%% a struct (or union) with an own member, at any depth held by value: its copy
%% would own the same memory twice, so clone refuses it
ccl_has_own_member(T) :- ccl_members_of(T, Ms), member(member(MT, _, _), Ms), ( ccl_own_quals(MT) -> true ; ccl_has_own_member(MT) ), !.
ccl_own_quals(ptr(Q, B)) :- ( memberchk(own, Q) ; B = base(Q2, _), memberchk(own, Q2) ), !.
ccl_own_quals(base(Q, _)) :- memberchk(own, Q), !.
ccl_own_quals(arr(_, T)) :- ccl_own_quals(T), !.
