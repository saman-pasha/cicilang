%% ccl_cpp_deduce.pl -- deduction and substitution: SFINAE, the checks of a candidate, the ranking of conversions,
%% template parameters and their arguments, deduction from a call, the substitution, member templates instantiated at
%% a call. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there, in their order.

cpp_sfinae_result(base(_, [typedef(scoped(_, _))])) :- !.
cpp_sfinae_result(base(_, [decltype(_)])) :- !.   % a trailing `-> decltype(...)' (0.100)
cpp_sfinae_result(base(_, [typedef(X)])) :- cpp_template_id(X, _, _), !.   % A TEMPLATE-ID RESULT IS SUBSTITUTED IN THE IMMEDIATE CONTEXT TOO ([temp.deduct]/8): libc++'s conjunction is `__expand_to_true<__enable_if_t<_Pred::value>...> __and_helper(int)' beside `false_type __and_helper(...)', and unresolved at the check the first held for a false predicate -- every _And was true
cpp_sfinae_result(ptr(_, T)) :- cpp_sfinae_result(T).
cpp_sfinae_result(ref(_, T)) :- cpp_sfinae_result(T).
cpp_sfinae_result(rref(_, T)) :- cpp_sfinae_result(T).
cpp_note_refusal(W) :- nb_setval('$cpp_last_refusal', W), nb_getval('$cpp_first_refusal', W0), ( W0 == none -> nb_setval('$cpp_first_refusal', W) ; true ), fail.
%% an exact match beats one that converts (a derived object to a base's reference, a value to a class through a
%% constructor): the candidates with the fewest conversions, then the most specialized of those
cpp_fewest_conversions(Hs, Best) :- findall(C, member(h(_, _, _, _, C), Hs), [C0|Cs]), cpp_min_of(Cs, C0, Min), findall(H, ( member(H, Hs), H = h(_, _, _, _, Min) ), Best).
cpp_min_of([], M, M).
cpp_min_of([C|Cs], M0, M) :- ( C @< M0 -> cpp_min_of(Cs, C, M) ; cpp_min_of(Cs, M0, M) ).   % a pair: the conversions, then the reference-binding demerits
cpp_converted :- ( nb_current('$cpp_conversions', C) -> C1 is C + 1, nb_setval('$cpp_conversions', C1) ; true ).   % a count outside a candidate's check is no one's (0.201: a trait asks the acceptance with no check under way)
%% THE COUNTS OF A CHECK UNDER WAY SURVIVE THE CHECKS IT MAKES (0.117): every candidate starts its conversions at 0, and a candidate
%% whose signature makes a call of its own -- an `enable_if' that asks a trait, a constraint -- ran that call's candidates in the
%% middle of its count, each resetting it, and the outer candidate came out with what the LAST nested one counted: `out << "x"'
%% on an ofstream (`<fstream>' brings the filesystem path's friend inserter, whose signature asks a trait) held the path
%% inserter at ONE conversion and the `const char *' ones at three, and the path won. The counts are saved at a candidate's start and put
%% back at its end, on each road.
cpp_conv_enter(c(C, R)) :- ( nb_current('$cpp_conversions', C) -> true ; C = 0 ), ( nb_current('$cpp_refbind', R) -> true ; R = 0 ),nb_setval('$cpp_conversions', 0), nb_setval('$cpp_refbind', 0).
cpp_conv_leave(c(C, R)) :- nb_setval('$cpp_conversions', C), nb_setval('$cpp_refbind', R).
%% THE REFERENCE-BINDING RULES ARE A SECONDARY KEY, NEVER A CONVERSION ([over.ics.rank]/3.2.3 and /3.2.6 rank two
%% standard conversion sequences that are otherwise INDISTINGUISHABLE; 0.94): charged as a conversion (0.93's rule 53),
%% `const basic_string &' bound to a non-const lvalue string cost one, tied with the char inserters' user-defined
%% conversion, and the first declared won. A candidate's cost is `Conversions-Demerits', compared in standard order.
cpp_ref_demerit :- ( nb_current('$cpp_refbind', C) -> C1 is C + 1, nb_setval('$cpp_refbind', C1) ; true ).   % ... nor a demerit (0.201: `existence_error(variable, '$cpp_refbind')' at std::barrier's wait, an xvalue's demerit asked by a trait)
cpp_conversions(Cv-Rf) :- nb_getval('$cpp_conversions', Cv), nb_getval('$cpp_refbind', Rf).
%% a DECLARATION and a DEFINITION of one template are one entity: the definition is what an instance is made from,
%% and a declaration is a candidate only when nothing is defined (declval, whose type is all a decltype wants)
cpp_defined_first(Hs, Best) :- findall(H, ( member(H, Hs), H = h(_, _, function(_, _, _, _, _, _, Body), _, _), Body \== none ), Ds),
    ( Ds == [] -> Best = Hs ; Best = Ds ).
%% THE COMPARISON IS A TEST, ASKED ONCE (0.95): cpp_fn_more_special leaves choicepoints -- cpp_match's pointer and
%% array clauses have no cut and its catch-all last clause succeeds after any of them -- and with `\+ ( ..., more(Y, H),
%% \+ more(H, Y) )' every failure of the inner test RETRIED the outer one through every alternative deduction, one
%% choice per parameter: 4^k + 1 comparisons for k parameters, MEASURED at 1025 for a two-candidate `search' and 1029
%% for a four-candidate `__uninitialized_allocator_copy_impl' -- 125 of stdalgorithm2's first 135 s, and the whole of
%% the two-range family's cost (0.92's finding, read there as breadth: it was this)
cpp_most_special_fn([H|_], All, H) :- \+ ( member(Y, All), Y \== H, once(cpp_fn_more_special(Y, H)), \+ cpp_fn_more_special(H, Y) ), !.
cpp_most_special_fn([_|Hs], All, H) :- cpp_most_special_fn(Hs, All, H).
cpp_fn_more_special(h(_, TPsX, function(_, _, _, _, PsX, _, _), _, _), h(_, TPsY, function(_, _, _, _, PsY, _, _), _, _)) :-
    \+ ( cpp_has_pack_param(PsX), \+ cpp_has_pack_param(PsY) ),   % A FUNCTION PARAMETER PACK IS LESS SPECIALIZED than a parameter that is none ([temp.deduct.partial]/8; 0.99): `f(F &&, A0 &&)' beats `f(F &&, Args &&...)' for two arguments, where the pack's overload had won libc++'s `__invoke' for a pointer to data member
    once(( cpp_opaque_bindings(TPsX, BX), cpp_subst(PsX, BX, PsX1), cpp_param_types(PsX1, TsX0), cpp_opaque_types(TsX0, TsX), cpp_param_types(PsY, TsY) )),   % ONE way of spelling the opaque types: a comparison that FAILS is asked under `\+', which exhausts every alternative of what came before -- 127,000 deductions for one choice among four candidates (0.99, the sort probe: 484 s of a 570 s build)
    length(TsX, N), length(TsY, N), cpp_param_types(PsX, TsXr), cpp_partial_cv_ok(TsXr, TsY, TPsX), cpp_partial_ptr_ok(TsY, TsX),   % X's types as WRITTEN, the parameters still named
    once(catch(cpp_deduce_types(TsY, TsX, TPsY, [], B), error(not_lowered(_), _), fail)), cpp_all_bound(TPsY, TsY, B),
    cpp_params_consistent(TsY, TsX, TPsY).   % A PARAMETER THAT STANDS TWICE deduces ONE type ([temp.deduct.partial]/10; 0.122): `f(I1, I1, I2, I2)' is more special than `f(I1, I1, I2, P)' -- cpp_match took the second occurrence unseen, both directions deduced, and the first declared won (`std::mismatch(a, a + 3, b, b + 3)' called the predicate overload with an int *)
%% ... AND THE REFERENCE TIE-BREAK ([temp.deduct.partial]/9; 0.99): where two reference parameters deduce each other
%% (`T &' and `const T &': the types are identical once the reference and the top-level qualifiers are stripped, /5 and
%% /7), the LESS cv-qualified one is not at least as specialized -- `kind(const T &)' beats `kind(T &)' for a const lvalue,
%% where with (15)'s deduction both bound it and the tie fell to the first declared, which writes through it (constref.cpp,
%% which the gate found). Applied only where X's referent is a bare parameter, which is when both directions deduce.
cpp_partial_cv_ok([], [], _).
cpp_partial_cv_ok([PX|Xs], [PY|Ys], TPs) :-
    \+ ( PX = ref(_, base(QX, [typedef(P)])), atom(P), memberchk(tparam(type, P, _), TPs), \+ memberchk(const, QX),
          PY = ref(_, base(QY, _)), memberchk(const, QY) ),
    cpp_partial_cv_ok(Xs, Ys, TPs).
%% ... AND A POINTEE'S QUALIFIERS ARE NO PART OF WHAT A PARTIAL ORDERING DEDUCES AWAY ([temp.deduct.partial]: its deduction is [temp.deduct.type]'s,
%% with none of the adjustments [temp.deduct.call]/4 allows a call; 0.191): `const T *' does not deduce from `U *', so `f(const T *)' is more
%% specialized than `f(T *)'. The call's deduction took the qualification conversion, each deduced the other, and the first declared won:
%% `f(&ci)' of a `const int ci' called `f(T *)', and with the two declared the other way `f(&i)' called `f(const T *)' (qualrank.cpp).
cpp_partial_ptr_ok([], []).
cpp_partial_ptr_ok([P|Ps], [A|As]) :- cpp_partial_ptr_ok_(P, A), cpp_partial_ptr_ok(Ps, As).
cpp_partial_ptr_ok_(ptr(_, P), ptr(_, A)) :- !, cpp_pointee_quals(P, QP), cpp_pointee_quals(A, QA),
    \+ ( member(Q, [const, volatile]), memberchk(Q, QP), \+ memberchk(Q, QA) ), cpp_partial_ptr_ok_(P, A).
cpp_partial_ptr_ok_(_, _).
cpp_params_consistent(TsY, TsX, TPs) :- findall(P-T, ( nth1(I, TsY, PY), nth1(I, TsX, TX), cpp_bare_param(PY, TX, TPs, P, T) ), Bs), \+ ( member(P-T1, Bs), member(P-T2, Bs), \+ catch(cpp_same_type(T1, T2), _, fail) ).
cpp_bare_param(PY, TX, TPs, P, T) :- ( PY = ref(_, PY1), TX = ref(_, TX1) ; PY = rref(_, PY1), TX = rref(_, TX1) ; PY = ptr(_, PY1), TX = ptr(_, TX1) ), !, cpp_bare_param(PY1, TX1, TPs, P, T).
cpp_bare_param(base(QP, [typedef(P)]), TX, TPs, P, T) :- atom(P), memberchk(tparam(type, P, _), TPs),
    ( TX = base(QX, S) -> findall(Q, ( member(Q, QX), \+ memberchk(Q, QP) ), QT), T = base(QT, S) ; T = TX ).   % THE PATTERN'S OWN QUALIFIERS ARE NO PART OF WHAT IT DEDUCES (0.134): `const C *' against `const X *' is C = X, as the deduction strips them (cpp_pattern_quals); compared with the `const' kept, `pad(obi<C, T>, const C *, ..., C)' had C both `const X' and `X', was no more specialized than `pad(O, const C *, ..., C)', and libc++'s ostreambuf_iterator overload of `__pad_and_output' lost to the generic one again (since 0.125)
cpp_has_pack_param(Ps) :- member(P, Ps), ( P = param(pack(_), _) ; P = param(pack(_), _, _) ), !.
%% ... and a TEMPLATE-ID OVER OPAQUE NAMES among X's parameter types is an INCOMPLETE INSTANCE (0.58's: a name and
%% its arguments, recorded, no body), never instantiated: `ostreambuf_iterator<$opaque._CharT, $opaque._Traits>'
%% resolved as a class refused, so that overload of __pad_and_output was no more special than the generic one over
%% `_OutputIterator', the tie went to the first declared, and the generic one ran a stream through std::copy.
cpp_opaque_types([], []).
cpp_opaque_types([T0|Ts], [T|Us]) :- cpp_opaque_type(T0, T), cpp_opaque_types(Ts, Us).
cpp_opaque_type(base(Q, [typedef(X)]), base(Q, [typedef(Name)])) :- cpp_template_id(X, N, Args), cpp_has_opaque(Args),
    catch(( findall(K, ( member(A, Args), cpp_type_key(A, K) ), Ks), atomic_list_concat([N|Ks], '.', Name) ), _, fail), !,
    ( '$cpp_inst'(Name, _) -> true ; assertz('$cpp_inst'(Name, inst(N, Args))) ).
cpp_opaque_type(ptr(Q, T0), ptr(Q, T)) :- !, cpp_opaque_type(T0, T).
cpp_opaque_type(ref(Q, T0), ref(Q, T)) :- !, cpp_opaque_type(T0, T).
cpp_opaque_type(rref(Q, T0), rref(Q, T)) :- !, cpp_opaque_type(T0, T).
cpp_opaque_type(T, T).
cpp_has_opaque(T) :- atom(T), !, sub_atom(T, 0, 8, _, '$opaque.').
cpp_has_opaque(T) :- compound(T), T =.. [_|As], member(A, As), cpp_has_opaque(A), !.
cpp_opaque_bindings([], []).
cpp_opaque_bindings([tparam(K, P, _)|TPs], [P-A|B]) :- !, atom_concat('$opaque.', P, O),
    ( K == type -> A = base([], [typedef(O)]) ; K == template -> A = tname(O) ; cpp_pack_kind(K) -> A = pack([base([], [typedef(O)])]) ; A = id(O) ),
    cpp_opaque_bindings(TPs, B).
cpp_opaque_bindings([_|TPs], B) :- cpp_opaque_bindings(TPs, B).
cpp_param_types([], []).
cpp_param_types([param(T, _)|Ps], [T|Ts]) :- !, cpp_param_types(Ps, Ts).
cpp_param_types([param(T, _, _)|Ps], [T|Ts]) :- !, cpp_param_types(Ps, Ts).
cpp_param_types([_|Ps], Ts) :- cpp_param_types(Ps, Ts).
cpp_deduce_types([], [], _, B, B).
cpp_deduce_types([P|Ps], [A|As], TPs, B0, B) :- cpp_match(P, A, TPs, B0, B1), cpp_deduce_types(Ps, As, TPs, B1, B).
cpp_all_bound(TPs, Ts, B) :- \+ ( member(tparam(_, P, _), TPs), cpp_names_in(Ts, P), \+ memberchk(P-_, B) ).
cpp_path_dependent(Path, TPs) :- member(tparam(_, P, _), TPs), cpp_names_in(Path, P), !.
cpp_signature_holds(F, TPs, Ps, Explicit, As, B) :- cpp_signature_holds(F, TPs, Ps, false, Explicit, As, B).
cpp_signature_holds(F, TPs, Ps, Var, Explicit, As, B) :- cpp_where(sig(F), cpp_signature_holds_(F, TPs, Ps, Var, Explicit, As, B)).
cpp_signature_holds_(F, TPs, Ps, Var, Explicit, As, B) :-
    cpp_arity_holds(Ps, Var, As),
    ( cpp_bind_explicit(TPs, Explicit, B0) -> true ; cpp_trace(sig_failed(F, explicit)), fail ),          % each step names itself when it FAILS (a refusal says why; a failure said nothing, and looked like no candidate at all)
    cpp_explicit_skip(Ps, TPs, B0, PsD),   % A PARAMETER WHOSE TEMPLATE PARAMETERS ARE ALL GIVEN EXPLICITLY TAKES NO PART IN DEDUCTION ([temp.deduct.call]/4; 0.115): its argument converts, as libc++ 18's `__vformat_to_n<format_context>(..., make_format_args(...))' hands an arg store to `basic_format_args<_Context>'
    ( cpp_deduce_args_checked(PsD, As, TPs, B0, B1) -> true ; cpp_trace(sig_failed(F, deduce(B0))), fail ),
    ( cpp_bind_defaults(TPs, B1, B2) -> true ; cpp_trace(sig_failed(F, defaults(B1))), fail ), cpp_vbinds_typed(TPs, B2, B),   % a value parameter's argument of its type, whatever bound it: given, deduced, a default (0.199)
    ( cpp_all_bound(TPs, Ps, B) -> true ; cpp_trace(sig_failed(F, unbound(B))), fail ),   % A PARAMETER TYPE STILL NAMING A TEMPLATE PARAMETER after deduction and the defaults is no candidate ([temp.deduct]: deduction failed): an argument the deduction could not type left `reverse_iterator<_Up>' free, and the acceptance step instantiated it on the free name -- 147,000 flattens to the cap (the C++23 optional probe)
    ( cpp_constraints_hold(F, TPs, B) -> true ; cpp_trace(sig_failed(F, constraints(B))), fail ),
    ( cpp_params_accept(Ps, As, B) -> true ; cpp_trace(sig_failed(F, accept(B))), fail ).
%% the arguments must fit the parameters in number: a default fills, a pack takes any number
cpp_arity_holds(Ps, Var, As) :- length(As, NA), cpp_arity(Ps, Min, Max), NA >= Min, ( Var == true -> true ; Max == any -> true ; NA =< Max ), !.   % `...' takes any number
cpp_arity_holds(_, _, _) :- cpp_refuse(0, arity_mismatch).
cpp_arity([], 0, 0).
cpp_arity([param(pack(_), _)|_], 0, any) :- !.
cpp_arity([param(_, _, _)|Ps], Min, Max) :- !, cpp_arity(Ps, Min, Max0), ( Max0 == any -> Max = any ; Max is Max0 + 1 ).
cpp_arity([param(_, _)|Ps], Min, Max) :- !, cpp_arity(Ps, Min0, Max0), Min is Min0 + 1, ( Max0 == any -> Max = any ; Max is Max0 + 1 ).
cpp_arity([_|Ps], Min, Max) :- cpp_arity(Ps, Min, Max).
%% a class-typed parameter (under the bindings) takes an argument of that class, or of a class derived from it, or --
%% for an argument of no class -- a class with a one-argument constructor; a scalar parameter takes no class unless it
%% has a conversion operator; an argument the inference cannot type passes
cpp_params_accept([], _, _).
cpp_params_accept(Ps, [], B) :- !, cpp_params_resolve(Ps, B).
cpp_params_accept([param(pack(_), _)|_], _, _) :- !.
cpp_params_accept([P|Ps], [A|As], B) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), !,
    cpp_subst(PT0, B, PT0a), ( cpp_param_ref(PT0a, PT) -> true ; PT = PT0a ),   % RESOLVED IN ITS CLASS before it is judged (0.66's rule, in the road that never took it): `const deleter_type &' is unique_ptr's own typedef of `__destruct_n &', which the INFERENCE cannot resolve -- so the reference was never seen, the class test (which must not unref, 0.51) met one, and `(pointer, const deleter_type &)' was refused `argument_mismatch'
    ( cpp_param_accepts(PT, A) -> true ; cpp_refuse(0, argument_mismatch) ), cpp_params_accept(Ps, As, B).
cpp_params_accept([_|Ps], [_|As], B) :- cpp_params_accept(Ps, As, B).
%% THE PARAMETERS A CALL LEAVES OUT STILL HAVE TYPES, and those substitute with the rest ([temp.deduct]/7: the type of EVERY
%% function parameter, supplied or defaulted, is in the immediate context; 0.117): libc++ 18's `list::insert' writes its
%% SFINAE as a trailing parameter, `template <class _InpIter> iterator insert(const_iterator, _InpIter, _InpIter,
%% __enable_if_t<__has_input_iterator_category<_InpIter>::value> * = 0)', and the call `insert(__e, __n, __x)' never supplies it
%% -- the candidate held whatever the trait said, and was dropped only by ranking, behind a walk of 400,000 flattened names.
%% A refusal in a type is thrown, the candidate's rejection where the candidates are held.
cpp_params_resolve([], _).
cpp_params_resolve([param(pack(_), _)|_], _) :- !.
cpp_params_resolve([P|Ps], B) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), !, cpp_subst(PT0, B, PT), ( cpp_type(PT, _) -> true ; true ), cpp_params_resolve(Ps, B).
cpp_params_resolve([_|Ps], B) :- cpp_params_resolve(Ps, B).
cpp_param_accepts(PT, A) :- cpp_nullptr_param(PT), !, cpp_null_arg(A).   % `nullptr_t' TAKES A NULL POINTER CONSTANT AND NOTHING ELSE ([conv.ptr]), in the template road too (0.81 had it at the fit and the last resort): libc++ writes `unique_ptr(nullptr_t)' and `explicit unique_ptr(pointer)' as two constructor TEMPLATES with the same guard, so both held for `unique_ptr<int> p(new int(5))' and the first declared won -- p was constructed empty and `*p' read null
cpp_param_accepts(PT, A) :- cpp_null_to_pointer(PT, A), !, cpp_pointee_settles(PT).   % a literal 0 for a pointer parameter -- WHOSE POINTEE MUST STILL RESOLVE ([temp.deduct]/8): 0.92's rule accepted `nullptr' for `void_t<typename U::category> *' by the pointer's SHAPE alone, and the detection idiom's refusal (no such member type) was never raised, so the wrong overload held (detect2.cpp, RED since 0.92, whose gate did not run)
cpp_param_accepts(PT, A) :- cpp_fn_template_ref(A, F), !, cpp_fn_target(PT, FnT), cpp_target_deduces(F, FnT).   % a template's name: only a function-pointer parameter whose target deduces it
%% A BRACED LIST FOR AN ARRAY PARAMETER takes at most as many items as the array holds, each converted WITHOUT NARROWING ([over.ics.list]/6, [dcl.init.list]/7; 0.121):
%% `_Dest (&&)[1]' given `{declval<int>()}' holds for a `double' only if the conversion is no narrowing one -- and int to double is, for a value that is no constant.
%% That is how libc++ 18's std::variant keeps an alternative out of its converting constructor (`__check_for_narrowing', `variant<std::string, bool> v = "text"'
%% is the string); any other parameter takes a braced list as before.
cpp_param_accepts(PT, init(Items)) :- cpp_unref_all(PT, PT1), ccl_resolve_type(PT1, arr(B, ET)), catch(cpp_array_bound_n(arr(B, ET), N), _, fail), !,
    length(Items, K), K =< N, \+ ( member(item(_, V), Items), cpp_narrows(V, ET) ).
%% ... AND HOW A REFERENCE BINDS IS PART OF WHETHER IT BINDS ([over.ics.ref], [over.ics.rank]): the road
%% below unrefs BOTH sides, so `tuple<_Tp...> &', `const tuple<_Tp...> &' and `tuple<_Tp...> &&' -- the
%% overloads libc++ writes `std::get' as -- are one candidate to it, all hold, and the tie falls to the
%% first declared; `std::get<0>(std::forward<_Tuple0>(__t0))' then answered `int &' where C++ answers
%% `int &&'. THE TEST IS A WHITELIST AND NOT `\+ cpp_lvalue': that predicate is a partial list (id,
%% member, arrow, deref, index, a call returning `ref'), and every temporary this compiler builds is a
%% `stmt_expr' outside it -- read as rvalues they were refused from binding `T &' and three fixtures fell.
%% Only a call whose DECLARED result is an rvalue reference is certain, which is what `std::forward' and
%% `std::move' are and all the shape needs.
cpp_param_accepts(PT, A) :- ( cpp_xvalue_call(A) ; cpp_prvalue_call(A) ), cpp_ref_lvalue_only(PT), !, fail.   % an rvalue never binds a non-const `T &'
cpp_param_accepts(PT, A) :- cpp_ref_lvalue_only(PT), cpp_lvalue(A), cpp_deduce_type(A, AT), ccl_unref(AT, AT1), cpp_top_const(AT1), !, fail.   % ... NOR DOES A CONST LVALUE ([dcl.init.ref]/5; 0.91's other half, 0.99): `kind(T &)' declared before `kind(const T &)' took a `const int' and wrote through it
%% ... NOR DOES AN LVALUE OF ANOTHER ARITHMETIC TYPE bind a non-const `T &' of an arithmetic T ([dcl.init.ref]/5.1: the types must be reference-related; 0.117): libc++ 18's
%% `__mul_overflowed(unsigned char, _Tp, unsigned char &)' held for a `uint32_t' lvalue, and its `__r = ...' wrote ONE BYTE of the caller's variable --
%% `std::from_chars("12345", ...)' stored 0 (the unsigned and signed paths alike)
cpp_param_accepts(PT, A) :- cpp_ref_lvalue_only(PT), PT = ref(_, T), cpp_lvalue(A), cpp_deduce_type(A, AT), ccl_unref(AT, AT1),
    ccl_resolve_type(T, RT), ccl_resolve_type(AT1, RA), ccl_is_arith(RT), ccl_is_arith(RA), RT = base(_, S1), RA = base(_, S2),
    cpp_type_key(base([], S1), K1), cpp_type_key(base([], S2), K2), K1 \== K2, !, fail.
cpp_param_accepts(PT, A) :- PT = rref(_, T), T \= ref(_, _), \+ ( ccl_resolve_type(T, R), ( R = ref(_, _) ; R = rref(_, _) ) ), cpp_lvalue(A), !, fail.   % ... AND AN LVALUE NEVER BINDS `T &&' ([dcl.init.ref]/5; 0.93): the parameter is judged AFTER substitution, so a forwarding `_Tp &&' given an lvalue has collapsed to `S &' by now and only a true rvalue reference is left as `rref' -- `pick2(const box<T> &)' beside `pick2(box<T> &&)' given an lvalue box: with (53)'s charge on the const binding, the `&&' candidate, held by the old unref-both-sides road, won the tie it had only ever lost by declaration order (refrank.cpp)
cpp_param_accepts(PT, A) :- ( cpp_deduce_type(A, AT) -> cpp_ref_rank(PT, A), cpp_unref_all(PT, PT1), cpp_unref_all(AT, AT0), cpp_arg_decayed(PT, AT0, AT1), cpp_type_accepts(PT1, AT1), cpp_scalar_rank(PT1, AT1) ; true ).   % THE ARGUMENT TYPED AS THE DEDUCTION TYPES IT (cpp_deduce_type: through the desugaring where the inference cannot): a class's name called, `__optional_construct_from_invoke_tag{}', was unknown to the inference and passed every class parameter -- optional's `in_place_t' constructor took the invoke tag, level by level down its storage chain
%% AN ARRAY ARGUMENT FOR A PARAMETER THAT IS NO REFERENCE IS THE POINTER IT DECAYS TO ([conv.array]; 0.167): a C++ string
%% literal is typed `const char[N]' since 0.167, an array was no pointer to cpp_scalar_mismatch/2, and libc++'s
%% `println(FILE *, format_string<_Args...>, _Args &&...)' held for `std::println("{}", "ab")', the format string its stream
cpp_arg_decayed(PT, AT0, ptr([], E)) :- \+ ( PT = ref(_, _) ; PT = rref(_, _) ), ccl_resolve_type(AT0, arr(_, E)), !.
cpp_arg_decayed(_, AT, AT).
cpp_pointee_settles(PT) :- ccl_unref(PT, PT1), ( PT1 = ptr(_, T) -> cpp_type(T, _) ; true ).   % a refusal here is the candidate's rejection, caught where the candidates are held
%% a conversion that NARROWS ([dcl.init.list]/7): floating to integer; integer to floating or to an integer type that holds not all its values; floating to a narrower
%% floating type; a pointer to bool -- except from a constant expression whose value fits (an integer constant in the range of the target, a floating one in the
%% range of a narrower floating type)
cpp_narrows(V, ET) :- ccl_resolve_type(ET, RT), ccl_is_arith(RT), cpp_deduce_type(V, VT0), ccl_unref(VT0, VT1), ccl_resolve_type(VT1, RV), cpp_narrow_conv(RV, RT), \+ cpp_constant_fits(V, RV, RT).
cpp_narrow_conv(From, To) :- ccl_is_float(From), !, ( \+ ccl_is_float(To) -> true ; ccl_size_of(From, SF), ccl_size_of(To, ST), SF > ST ).
cpp_narrow_conv(From, To) :- ccl_is_integer(From), !, ( ccl_is_float(To) -> true ; ccl_is_integer(To), \+ cpp_int_subset(From, To) ).
cpp_narrow_conv(From, To) :- ccl_is_pointer(From), ccl_resolve_type(To, base(_, S)), ( memberchk(bool, S) ; memberchk('_Bool', S) ), !.
cpp_int_subset(From, _) :- ccl_resolve_type(From, base(_, S)), ( memberchk(bool, S) ; memberchk('_Bool', S) ), !.   % a bool's two values fit any integer type
cpp_int_subset(From, To) :- ccl_size_of(From, SF), ccl_size_of(To, ST), ( ir_signed(From) -> ir_signed(To), SF =< ST ; ir_signed(To) -> SF < ST ; SF =< ST ).
cpp_constant_fits(V, From, To) :- ccl_is_integer(From), ccl_const_eval(V, Val), integer(Val), !,
    (   ccl_is_float(To) -> Val =< 9007199254740992, Val >= -9007199254740992
    ;   ccl_resolve_type(To, base(_, S)), ( memberchk(bool, S) ; memberchk('_Bool', S) ) -> ( Val =:= 0 ; Val =:= 1 )
    ;   ccl_size_of(To, ST), ST =< 4, ( ir_signed(To) -> Hi is 2 ** (8 * ST - 1) - 1, Lo is - (2 ** (8 * ST - 1)) ; Hi is 2 ** (8 * ST) - 1, Lo = 0 ), Val >= Lo, Val =< Hi
    ;   ccl_size_of(To, 8) ).
cpp_constant_fits(V, From, To) :- ccl_is_float(From), ccl_is_float(To), V = float(F), number(F), abs(F) =< 3.0e38.
cpp_xvalue_call(call(id(F), _)) :- atom(F), ccl_declared(F, fn(rref(_, _), _, _)).   % `std::forward<T>(x)', `std::move(x)': a call whose DECLARED result is an rvalue reference is an xvalue ([basic.lval])
%% AN ARITHMETIC ARGUMENT OF ANOTHER ARITHMETIC TYPE IS A CONVERSION, an exact match is not ([over.ics.rank]/3; 0.121): it costs one demerit, the
%% reference-binding kind, so that of two templates that tie on the class conversions the one that takes the arguments as they are wins.
%% libc++'s std::variant picks its alternative so (`__overload<int, 0>' and `__overload<double, 1>' called with an int), and the program's
%% `template <class T> int f(T x, int y)' against `template <class T, class U> int f(T &&, U &&)' for (2.5, 3.5) is the second.
cpp_scalar_rank(PT, AT) :-
    (   ccl_resolve_type(PT, RP), ccl_resolve_type(AT, RA), ccl_is_arith(RP), ccl_is_arith(RA), RP = base(_, S1), RA = base(_, S2),
        cpp_type_key(base([], S1), K1), cpp_type_key(base([], S2), K2), K1 \== K2
    ->  cpp_ref_demerit, ( cpp_promotes_to(AT, PT) -> true ; cpp_ref_demerit )   % ... ONE for a promotion, TWO for a conversion (0.127, [over.ics.rank]/4.2): `std::cout << e' of an `enum : unsigned char' is the free `unsigned char' inserter, a promotion, never the `char' one
    ;   cpp_qualification_conv(PT, AT, K) -> forall(between(1, K, _), cpp_ref_demerit)
    ;   true ).
%% ... AND A POINTER WHOSE POINTEE A QUALIFICATION CONVERSION ADDS `const' OR `volatile' TO IS WORSE THAN THE IDENTITY ([over.ics.rank]/3.2.5;
%% 0.191), one demerit for each qualifier it adds, so the less qualified target is the better one (`f(const T *)' over `f(const volatile T *)'
%% for an `int *'): libc++'s `any_cast<T>(const any *)' calls `std::any_cast<T>(const_cast<any *>(__any))', which is `any_cast(any *)'; the
%% two tied, the first declared stood, and the call was itself -- every `std::any_cast' of a value ran until the stack overflowed
cpp_qualification_conv(PT, AT, K) :- ccl_resolve_type(PT, ptr(_, P)), ccl_resolve_type(AT, ptr(_, A)), cpp_pointee_quals(P, QP), cpp_pointee_quals(A, QA),
    findall(X, ( member(X, [const, volatile]), memberchk(X, QP), \+ memberchk(X, QA) ), Xs), length(Xs, K), K > 0, !.
cpp_pointee_quals(base(Q, _), Q) :- !.
cpp_pointee_quals(ptr(Q, _), Q) :- !.
cpp_pointee_quals(_, []).
cpp_ref_lvalue_only(ref(Q, T)) :- \+ memberchk(const, Q), \+ cpp_top_const(T).   % ... the referent's own top-level const counts, a CONST POINTER's too (`int (*const &)(int)', what a forwarding `_Tp &&' collapses to for a const function-pointer lvalue; 0.99: read as non-const, the const-lvalue rule refused forward_as_tuple's argument inside std::function)
%% ... and among the ones that do bind, an rvalue prefers `T &&' to `const T &' ([over.ics.rank]/3.2.3),
%% which this road already has a place to say: the candidate with the FEWEST conversions wins (0.45), so
%% the worse binding costs one. The `const' of `const T &' sits on the REFERENT's qualifiers, not the
%% reference's own, which is why the first writing of this charged nothing and the tie stood.
cpp_ref_rank(ref(Q, T), A) :- ( memberchk(const, Q) -> true ; T = base(Q2, _), memberchk(const, Q2) ), ( cpp_xvalue_object(A) ; cpp_prvalue_shape(A) ), !, cpp_ref_demerit.   % an XVALUE of any shape, `std::move(a)' too, and a cast to a class or a temporary the desugaring made (0.201): uncharged, std::tuple's `tuple(const _Tp &...)' tied with `tuple(_Up &&...)' and, declared first, COPIED a moved value
%% ... AND A CALL RETURNING A CLASS BY VALUE IS A PRVALUE, an rvalue as an xvalue is ([basic.lval]; 0.93) -- the second
%% certain shape, a temporary this compiler builds around such a call included (a statement expression ending in it):
%% libc++ 18's `tuple_cat' returns `__tuple_cat<...>()(...)', a tuple of references BY VALUE, into a tuple of values,
%% and with the prvalue uncharged `tuple(const tuple<_Up...> &)' tied with `tuple(tuple<_Up...> &&)' and stood first;
%% its `_Tuple' was then `const tuple<...> &', whose `__tuple_like_ext<const _Tp>' specialization derives from the
%% unqualified instance -- ONE NAME with it here, the keys carrying no qualifiers (named below) -- so the converting
%% constructor template was rejected and the bytes of three references were copied as an int, a double and a char
cpp_ref_rank(ref(Q, T), A) :- ( memberchk(const, Q) -> true ; T = base(Q2, _), memberchk(const, Q2) ), cpp_lvalue(A), cpp_deduce_type(A, AT), ccl_unref(AT, AT1), \+ cpp_top_const(AT1), !, cpp_ref_demerit.   % ... AND A NON-CONST LVALUE PREFERS THE BINDING WITHOUT THE `const' ([over.ics.rank]/3.2.6): a forwarding `V &&' deduced as `S &' beats `const V &' for an lvalue `S', which C++ ranks as the identity against a qualification adjustment; uncharged, `W(const V &)' stood first (0.93, commafold.cpp)
cpp_ref_rank(_, _).
cpp_top_const(base(Q, _)) :- memberchk(const, Q).
cpp_top_const(ptr(Q, _)) :- memberchk(const, Q).
cpp_prvalue_call(call(id(F), _)) :- atom(F), ccl_declared(F, fn(R, _, _)), R \= ref(_, _), R \= rref(_, _), cpp_class_of_type(R, _).
cpp_prvalue_call(stmt_expr(block(Ss))) :- append(_, [expr(_, E)], Ss), cpp_prvalue_call(E).
cpp_prvalue_shape(A) :- cpp_prvalue_call(A), !.
cpp_prvalue_shape(stmt_expr(block(Ss))) :- append(_, [expr(_, id(N))], Ss), atom(N), ( sub_atom(N, 0, _, _, '$tmp') ; sub_atom(N, 0, _, _, '$copy') ), !.   % a temporary the desugaring made (0.201)
cpp_prvalue_shape(A) :- ( A = ccast(K, T, _), K \== dynamic ; A = cast(T, _) ), T \= ref(_, _), T \= rref(_, _), catch(cpp_deduce_type(A, AT), _, fail), AT \= ref(_, _), AT \= rref(_, _), cpp_class_of_type(AT, _), !.   % a cast to a class: `static_cast<R>(x)', `R(x)' (0.201)
cpp_unref_all(T, T1) :-                                                  % EVERY reference layer, INCLUDING one behind a typedef or a bound parameter:
    (   ccl_unref(T, T0), T0 \== T -> cpp_unref_all(T0, T1)              % `const deleter_type &' with `deleter_type = __destruct_n &' unreffed ONCE to the
    ;   ccl_resolve_type(T, R), ( R = ref(_, _) ; R = rref(_, _) )       % typedef and stopped there, so a REFERENCE reached the class test, which must not
    ->  cpp_unref_all(R, T1)                                             % unref (0.51), and unique_ptr's `(pointer, const deleter_type &)' was refused
    ;   T1 = T ).   % EVERY reference layer: a forwarding `_Tp &&' bound to an lvalue is `T & &&' before it collapses, and one layer off it was a reference to a class and no class -- libc++'s piecewise key extraction refused argument_mismatch on its piecewise_construct_t
cpp_type_accepts(PT, AT) :- cpp_type(PT, PT2), cpp_class_of_type(PT2, C), !, ( cpp_class_of_type(AT, D) -> ( D == C -> true ; cpp_class_fits(D, C) -> cpp_converted, cpp_base_steps_demerit(D, C) ; cpp_conv_result(D, PT2, _) -> cpp_converted ; cpp_class_converts(C, D) -> cpp_converted ; cpp_converting_tmpl(C, AT), cpp_converted ) ; cpp_converting(C, AT), cpp_converted ).
cpp_type_accepts(PT, AT) :- ccl_resolve_type(PT, RP), cpp_scalar_mismatch(RP, AT), !, fail.   % NO STANDARD CONVERSION: a pointer to an arithmetic parameter (a bool takes one), an arithmetic value to a pointer parameter -- `cout << "hello"' took the CHAR inserter, `operator<<(basic_ostream<_CharT, _Traits> &, _CharT)', and passed the literal's address truncated to a byte
cpp_type_accepts(PT, AT) :- ( cpp_class_of_type(AT, D) -> ( cpp_type(PT, PT2), ccl_resolve_type(PT2, RP) -> cpp_conv_result(D, RP, _) ; cpp_has_conversion(D) ), cpp_converted ; true ).   % A CLASS ARGUMENT FOR A SCALAR PARAMETER CONVERTS ONLY THROUGH A CONVERSION OPERATOR WHOSE RESULT FITS IT ([over.ics.user]; 0.94): basic_string's `operator basic_string_view()' let the CHAR inserter, `operator<<(basic_ostream<_CharT, _Traits> &, _CharT)', take a string -- any conversion operator counted -- and on libc++ 18, where the char inserters are declared before the string one, it won the tie and the struct was sign-extended to a byte
%% A DERIVED CLASS TAKEN AS A NEARER BASE IS THE BETTER CONVERSION ([over.ics.rank]/4.4.4; 0.206): it costs a demerit for
%% each step of its shortest path to the base, so that of two candidates that tie on their conversions the nearer base wins --
%% libc++'s `__sample' over a vector's iterators takes the `forward_iterator_tag' overload for a `random_access_iterator_tag',
%% where the `input_iterator_tag' one, declared first, stood and asked `operator[]' of a back_insert_iterator
cpp_base_steps_demerit(D, C) :- ( cpp_base_steps(D, C, 0, K) -> forall(between(1, K, _), cpp_ref_demerit) ; true ).
cpp_base_steps(C, C, K, K) :- !.
cpp_base_steps(D, C, K0, K) :- K0 < 32, K1 is K0 + 1, catch(cpp_direct_bases(D, Bs), _, fail), findall(K2, ( member(B, Bs), cpp_base_steps(B, C, K1, K2) ), Ks), Ks \== [], min_list(Ks, K).
%% ... or the parameter's class has a constructor that takes the argument's class ([over.ics.user]): libc++'s tree
%% copies itself through `unique_ptr<__node, __tree_deleter>(node, __node_alloc_)', the deleter made of the allocator
cpp_class_converts(C, D) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, Qs, Ps, _, _), Ms), \+ cpp_is_explicit(C, Qs), cpp_arity_fits(Ps, 1), Ps = [P|_],
    ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_in_class(C, cpp_param_ref(PT0, PT1)), ccl_unref(PT1, PT2), cpp_class_of_type(PT2, E), cpp_class_fits(D, E), !.
%% ... or a CONSTRUCTOR TEMPLATE whose one parameter is a template-id the argument's class is an instance of, deduced
%% as a call would deduce it ([over.match.copy], [over.ics.user]): libc++'s vformat takes `format_args', which
%% make_format_args's `__format_arg_store<format_context, int, int>' converts to only through `template <class... _Args>
%% basic_format_args(const __format_arg_store<_Context, _Args...> &)' -- refused, std::format had no vformat to call
%% (test/cpp/run/ctortconv.cpp). Only that shape: a forwarding `T &&' would take anything its guards would refuse.
cpp_class_converts(C, D) :- cpp_class_l(C, _), '$cpp_mt'(C, ctor, TPs, ctor(_, Qs, Ps, _, _)), \+ memberchk(explicit, Qs), cpp_arity_fits(Ps, 1), Ps = [P|_],
    ( P = param(PT0, _) ; P = param(PT0, _, _) ), ccl_unref(PT0, PT1), PT1 = base(_, [typedef(X)]), cpp_template_id(X, N, _), atom(N),
    \+ memberchk(tparam(template, N, _), TPs),
    catch(cpp_in_class(C, ( cpp_match(PT1, base([], [typedef(D)]), TPs, [], B0), cpp_subst(PT1, B0, PT2), cpp_type(PT2, T2) )), error(not_lowered(_), _), fail),
    cpp_class_of_type(T2, D2), D2 == D,
    catch(cpp_in_class(C, ( cpp_bind_defaults(TPs, B0, B), cpp_constraints_hold(ctor, TPs, B), cpp_member_tmpl_req(C, Qs, [P], B) )), error(not_lowered(_), _), fail),   % ITS DEFAULTS AND CONSTRAINTS HOLD (0.200): `shared_ptr(unique_ptr<_Yp, _Dp> &&)' under `__compatible_with<_Yp, _Tp>' converted a `unique_ptr<double>' to a `shared_ptr<int>'
    \+ cpp_explicit_under(C, Qs, B), !.   % THE DEDUCED PARAMETER IS THE ARGUMENT'S CLASS (0.115): the match binds the constructor's own parameters and lets every other element pass, so `basic_format_args<wformat_context>' took make_format_args's `__format_arg_store<format_context, ...>' and std::vformat chose the WIDE overload (`ctorctx.cpp')
cpp_scalar_mismatch(RP, AT) :- ccl_is_arith(RP), \+ RP = base(_, [bool|_]), cpp_pointerish(AT), !.
cpp_scalar_mismatch(RP, AT) :- ( RP = ptr(_, _) ; RP = arr(_, _) ), ccl_resolve_type(AT, RA), ccl_is_arith(RA), !.
cpp_scalar_mismatch(RP, AT) :- RP = ptr(_, PE), \+ ccl_resolve_type(PE, fn(_, _, _)), ccl_resolve_type(AT, RA), ( RA = fn(_, _, _) ; RA = ptr(_, AE), ccl_resolve_type(AE, fn(_, _, _)) ), !.   % a function for a pointer to an object: no conversion (the `const _CharT *' inserter took a manipulator)
cpp_scalar_mismatch(RP, AT) :- RP = ptr(_, PE), ccl_resolve_type(PE, fn(_, _, _)), ccl_resolve_type(AT, RA), RA = ptr(_, AE), \+ ccl_resolve_type(AE, fn(_, _, _)), !.
cpp_scalar_mismatch(RP, AT) :- RP = ptr(_, PE), \+ ccl_resolve_type(PE, base(_, [void])), ccl_resolve_type(AT, RA), RA = ptr(_, AE), \+ cpp_pointees_agree(PE, AE), !.   % nor an object pointer for a function pointer
cpp_class_fits(C, C) :- !.
cpp_class_fits(D, C) :- cpp_class_l(D, cls(B, _, _, _, _)), B \== none, cpp_class_fits(B, C).
cpp_class_fits(D, C) :- '$cpp_base_slot'(D, B, _), cpp_class_fits(B, C).   % A LATER BASE WITH STORAGE TOO (0.117): `ss << "x"' on a basic_stringstream reaches basic_ostream, the SECOND base of basic_iostream, and took the member `operator<<(const void *)' for want of the free inserter
cpp_class_fits(D, C) :- '$cpp_extra'(D, Bs), member(B, Bs), \+ '$cpp_base_slot'(D, B, _), cpp_class_fits(B, C).   % ... AND A LATER EMPTY BASE (0.126): no sub-object, no slot, the object's own address is its address -- the CRTP base of libc++ 21's `__pipeable<_Fn> : _Fn, __range_adaptor_closure<__pipeable<_Fn>>' converts a `__pipeable *' to `__range_adaptor_closure<...> *' (`_RangeAdaptorClosure' asks it through a call)
%% ... AND A NON-CLASS ARGUMENT CONVERTS ONLY THROUGH A CONSTRUCTOR WHOSE PARAMETER TAKES ITS KIND: any one-argument
%% constructor let `const pair *' pass for a map's `const_iterator' (a class built from a tree iterator), so
%% `insert(__il.begin(), __il.end())' in the map's initializer-list constructor took `insert(const_iterator, _Pp &&)'
%% over the range template, and a node was constructed from a pointer to a pair
cpp_converting(C, AT) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, Qs, [P|Rest], _, _), Ms), \+ cpp_is_explicit(C, Qs), cpp_arity_fits([P|Rest], 1),
    ( P = param(PT0, _) ; P = param(PT0, _, _) ), catch(cpp_in_class(C, cpp_param_ref(PT0, PT)), _, fail), ccl_unref(PT, PT1),
    \+ cpp_class_of_type(PT1, _), \+ ( ccl_resolve_type(PT1, RP), ( cpp_scalar_mismatch(RP, AT) ; cpp_arith_pointee_differs(RP, AT) ) ),
    \+ ( cpp_nullptr_param(PT1), \+ cpp_nullptr_arg(AT) ),   % A `nullptr_t' PARAMETER TAKES A `nullptr_t' ALONE (0.200; [conv.ptr]/1): `unique_ptr(nullptr_t)' converted an `int *'
    \+ cpp_class_of_type(AT, _), !.   % A CLASS ARGUMENT NEVER: its conversion function and this constructor are two user-defined conversions, of which an implicit conversion has one ([class.conv]/4; 0.200) -- it went through its own conversion function from 0.137, and before that through any (`is_convertible<const locale &, string_view>' held through string_view's `const char *' constructor)
cpp_converting(C, AT) :- '$cpp_mt'(C, ctor, TPs, ctor(_, Qs, Ps, _, _)), \+ memberchk(explicit, Qs), cpp_arity_fits(Ps, 1), cpp_ctor_tmpl_takes(C, TPs, Qs, Ps, AT), !.   % a constructor template takes what deduces
%% ... AND A CLASS ARGUMENT THROUGH A CONSTRUCTOR TEMPLATE whose one parameter deduces from it (0.137; [over.match.copy]),
%% its defaults and constraints checked as for a non-class argument (cpp_ctor_tmpl_takes), a pack never: `const
%% optional<locale> &' took no `locale', `optional(_Up &&)' being no template-id's constructor (cpp_class_converts) -- libc++'s
%% `__format_context_create(..., optional<locale> &&)' had no candidate, and std::format of hh_mm_ss stopped there
cpp_converting_tmpl(C, AT) :- '$cpp_mt'(C, ctor, TPs, ctor(_, Qs, Ps, _, _)), \+ memberchk(explicit, Qs), cpp_arity_fits(Ps, 1),
    Ps = [P|_], ( P = param(PT0, _) ; P = param(PT0, _, _) ), ccl_unref(PT0, base(_, [typedef(TP)])), atom(TP), memberchk(tparam(type, TP, _), TPs),   % ONLY A BARE TEMPLATE PARAMETER (`_Up &&', `const _Up &'): a template-id's is cpp_class_converts's, which checks the deduced class (`ctorctx.cpp')
    cpp_ctor_tmpl_takes(C, TPs, Qs, Ps, AT), !.
cpp_converting(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, Qs, [_], _, _), Ms), \+ cpp_is_explicit(C, Qs), !.   % the type-only question (a trait's `is_convertible' with no argument in hand): any one-argument constructor that is not `explicit' -- the implicit conversion [meta.rel] asks for, which an explicit one never makes (0.112: it counted them, so `is_convertible<int, E>' was true for `explicit E(int)')
cpp_has_conversion(D) :- cpp_class(D, cls(_, _, Ms, _, _, _)), member(method(_, _, _, operator(conv(_)), _, _, _), Ms), !.
%% ... AND A POINTER TO AN ARITHMETIC TYPE TAKES ONLY THAT TYPE, its qualifiers aside (0.115; [conv.ptr], [conv.qual]):
%% the pointer fit lets any two arithmetic pointees agree (cpp_pointees_agree), and so `basic_string_view<char>(const
%% char *)' converted a `const wchar_t *' -- std::format(L"...") held the narrow overload (`wideformat.cpp').
cpp_arith_pointee_differs(ptr(_, PE), AT) :- ccl_resolve_type(AT, RA), ( RA = ptr(_, AE) ; RA = arr(_, AE) ), !,
    ccl_resolve_type(PE, base(_, S1)), ccl_resolve_type(AE, base(_, S2)), ccl_is_arith(base([], S1)), ccl_is_arith(base([], S2)),
    cpp_canon_specs(S1, C1), cpp_canon_specs(S2, C2), C1 \== C2.
%% ... A CONSTRUCTOR TEMPLATE CONVERTS WHAT ITS PARAMETER DEDUCES FROM AND ITS CONSTRAINTS TAKE (0.115;
%% [over.match.copy], [temp.deduct.call]): the parameter matched against the argument's type, the defaults bound (an
%% `enable_if' default refuses there), the head's and the trailing requires-clause checked in the class. Any constructor
%% template converted before, so `basic_format_string<char, int, int>', whose constructor is `template <class _Tp>
%% requires convertible_to<const _Tp &, basic_string_view<_CharT>>', took a `const wchar_t *', and std::format over a
%% wide string chose the narrow overload (`wideformat.cpp'). A parameter pack keeps the old answer.
cpp_ctor_tmpl_takes(C, TPs, Qs, [P|_], AT) :- ( P = param(pack(T), _) ; P = param(pack(T), _, _) ), !,   % A PACK DEDUCES ITS ONE ELEMENT FROM THE VALUE (0.200), its defaults, constraints and explicit-specifier checked as one parameter's are: a pack took any value since 0.115, and `tuple(_Up &&...)' converted an `int' to a `tuple<string>'
    catch(cpp_in_class(C, ( cpp_deduce_pack(T, [AT], TPs, [], B0), cpp_bind_defaults(TPs, B0, B), cpp_constraints_hold(ctor, TPs, B), cpp_member_tmpl_req(C, Qs, [P], B) )),
          error(not_lowered(_), _), fail),
    \+ cpp_explicit_under(C, Qs, B).
cpp_ctor_tmpl_takes(C, TPs, Qs, [P|_], AT) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), !,
    catch(cpp_in_class(C, ( cpp_match(PT0, AT, TPs, [], B0), cpp_bind_defaults(TPs, B0, B), cpp_constraints_hold(ctor, TPs, B), cpp_member_tmpl_req(C, Qs, [P], B) )),
          error(not_lowered(_), _), fail),
    cpp_subst(PT0, B, PT1), cpp_tmpl_type_ok(std, C, PT1, AT),   % ITS PARAMETER TAKES THE VALUE (0.200): libc++'s `template <__enable_if_t<__is_allocator<_Allocator>::value, int> = 0> basic_string(const _CharT *)' deduces nothing from its parameter, and took an `int': `is_convertible_v<int, std::string>' was 1
    \+ cpp_explicit_under(C, Qs, B).   % its explicit-specifier false under the bindings (0.197): `explicit(!is_convertible_v<U, T>)'
%% A TEMPLATE'S SUBSTITUTED PARAMETER TAKES THE VALUE, its references aside (0.200): what the deduction left may be a reference of
%% another category than the value's, so only the conversion is asked -- a standard conversion by Mode `std', the parameter of
%% the one user-defined conversion of a copy-initialization ([over.best.ics]/4), any implicit one by `user'; a type the tables cannot
%% settle passes, as before
cpp_tmpl_type_ok(Mode, C, PT1, A) :-
    (   cpp_unref_all(PT1, R0), cpp_nullptr_param(R0), \+ cpp_untyped_arg(A) -> cpp_value_cat(A, _, X0), cpp_nullptr_arg(X0)   % A `nullptr_t' PARAMETER TAKES A `nullptr_t' ALONE (0.200; [conv.ptr]/1): it resolves to `void *', and libc++'s `template <bool _Dummy = true, ...> unique_ptr(nullptr_t)' converted an `int *'
    ;   catch(cpp_in_class(C, cpp_param_ref(PT1, PT)), _, fail), \+ cpp_untyped_arg(PT), \+ cpp_untyped_arg(A)
    ->  cpp_value_cat(A, Cat, X),
        (   cpp_ref_target(PT, lvalue, R0) -> Cat == lvalue, cpp_ref_compatible(R0, X)   % A NON-CONST LVALUE REFERENCE BINDS AN LVALUE ALONE (0.200; [dcl.init.ref]/5): `const _Tp &' of `_Tp = int &' is `int &', and tuple's `tuple(const _Tp &...)' took an rvalue `int' for a `tuple<int &>'
        ;   cpp_unref_all(PT, R), ( cpp_ref_compatible(R, X) -> true ; cpp_converts(Mode, X, R) ) )
    ;   true ).
%% A FUNCTION TEMPLATE'S INSTANCE IS NOTED WHEN IT IS EMITTED, NOT BEFORE -- 0.69's rule, which the member template
%% and the lazy member got and this road kept the old way: the note was taken first, an emission abandoned by a
%% candidate's check (SFINAE throws and catches by design) left it behind, and the next ask found the instance
%% "done" with no body anywhere -- `__to_chars_integral' declared and never defined, the last symbol between
%% `std::cout << "hello"' and a binary. In progress while it emits (its own recursive call finds it declared).
cpp_instantiate_function_(F, TPs, B, L, Sto, Ret, Ps, V, Body, Name) :-
    (   cpp_instance_done(Name) -> true
    ;   cpp_making(Name) -> true
    ;   nb_getval('$cpp_making', M0), nb_setval('$cpp_making', [Name|M0]),
        (   catch(\+ \+ cpp_instantiate_function_emit(F, TPs, B, L, Sto, Ret, Ps, V, Body, Name), E, ( nb_setval('$cpp_making', M0), throw(E) ))   % inside `\+ \+': the instance's items go to the facts, its walk is reclaimed
        ->  nb_setval('$cpp_making', M0), cpp_instance_note(Name, F), cpp_dbg_note_targs(Name, TPs, B)
        ;   nb_setval('$cpp_making', M0), cpp_refuse(0, function_not_emitted(Name)) ) ).
cpp_instantiate_function_emit(F, TPs, B, L0, Sto00, Ret, Ps, V0, Body, Name) :-
    cpp_lib_origin(F, Lib), cpp_nx_sto(Sto00, StoP, Cond0),
    cpp_where(subst(F), cpp_subst(fn(Ret, Ps, nxb(Cond0, Body)), B, fn(Ret10, Ps10, nxb(Cond10, Body10)))),   % ITS NOEXCEPT CONDITION TOO (0.199), under the instance's bindings, the parameter packs' among them
    (   Cond10 \== none -> Sto0 = nxif(Cond10, StoP)   % the program's plain noexcept among them, its pattern's own `bool(true)' since 0.232 (ccl_nx_sto/3), where the name's set answered for every overload of the name
    ;   Sto0 = StoP ),
    (   cpp_fspec_for(F, TPs, B, Ret10, Ps10, function(L, Sto, Ret1, _, Ps1, V, Body1)) -> cpp_trace(explicit_specialization(F, Name)), ISig = fsig(free, none, F, Ret1, Ps1, V, [], none)   % the instance IS the explicit specialization (0.129)
    ;   L = L0, Sto = Sto0, Ret1 = Ret10, Ps1 = Ps10, V = V0, Body1 = Body10, ISig = fsig(free, none, F, Ret, Ps, V0, [], ta(TPs, B)) ),   % what its own name says (0.166): the pattern, with its arguments
    cpp_as_lib(Lib, ( cpp_with_fsig(inst(Name, ISig), cpp_isolated(( cpp_plain_params(Ps1, Ps2), ( Ret1 = base(_, [auto]) -> cpp_lambda_ret(Ps2, Body1, Ret2) ; cpp_decltype_ret(Ret1, Ps1, Ret2) -> true ; cpp_type(Ret1, Ret2) ),
                                     ccl_declare(Name, fn(Ret2, Ps2, V)), cpp_note_defaults(Name, Ps1),
                                     ( Body1 == none -> cpp_nx_sto(Sto, StoD, CondD), ( CondD == none -> true ; assertz('$cpp_nxdef'(Name, none, CondD, Ps2)) ),
                                                        Items = [declaration(L, StoD, Ret2, [var(Name, fn(Ret2, Ps2, V), none)])]   % declared, not defined: a declaration, never a bodyless function
                                     ; cpp_item(function(L, Sto, Ret2, Name, Ps1, V, Body1), Items) ) ))),
                      cpp_add_instance_items(Items) )).
cpp_bind_targs(TPs, Args, B) :- cpp_bind_targs_(TPs, Args, [], B0), ( memberchk(ttp(_, _), TPs) -> cpp_ttp_binds(TPs, B0, B1) ; B1 = B0 ), cpp_vbinds_typed(TPs, B1, B).   % a template template parameter's own list (0.185): bound after the rest, past a pack, which ends the walk; a value parameter's argument of its type (0.199, cpp_vbinds_typed/3)
cpp_bind_targs_([], _, B, B).
cpp_bind_targs_([requires(_)|TPs], Args, Acc, B) :- !, cpp_bind_targs_(TPs, Args, Acc, B).
cpp_bind_targs_([ttp(_, _)|TPs], Args, Acc, B) :- !, cpp_bind_targs_(TPs, Args, Acc, B).
cpp_bind_targs_([tparam(K, P, _)|_], Args, Acc, [P-pack(Args)|Acc]) :- cpp_pack_kind(K), !.     % a pack takes what is left
cpp_bind_targs_([tparam(template, P, D)|TPs], Args, Acc, B) :- !,                                % a template template parameter: bound to a template's NAME
    ( Args = [A0|Rest] -> cpp_tname_arg(A0, Acc, A) ; D \== none -> cpp_tname_arg(D, Acc, A), Rest = [] ; cpp_refuse(0, template_argument_missing(P)) ),
    cpp_bind_targs_(TPs, Rest, [P-A|Acc], B).
%% AN EXPLICIT TEMPLATE ARGUMENT IS EVALUATED WHERE IT IS BOUND, whatever road brought it: the class path ran it
%% through cpp_targ_value first and the MEMBER TEMPLATE path handed it over raw, so `__align_it<__boundary>(n)' --
%% libc++'s alignment step, over a `const' local -- keyed its instance by the NAME and left it in the body.
cpp_bind_targs_([tparam(K, P, D)|TPs], Args, Acc, B) :-
    ( Args = [A0|Rest] -> ( cpp_targ_value(A0, A1) -> true ; cpp_trace(targ_raw(P, A0)), A1 = A0 ) ; D \== none -> cpp_subst(D, Acc, D1), cpp_type_or_value(D1, A1), Rest = [] ; cpp_refuse(0, template_argument_missing(P)) ),
    ( K \== type, cpp_class_nttp(K, Acc, A1, A2) -> A = A2 ; A = A1 ),   % a parameter of class type names its template parameter object (0.197), below
    ( K \== type, A = id(N), atom(N), cpp_local(N) -> cpp_refuse(0, template_argument_not_constant(P, A)) ; true ),   % A VALUE ARGUMENT THAT IS A PLAIN LOCAL'S NAME can never fold: refused by name (0.98), where `Box<x>' keyed the instance by its spelling; an unfolded CALL or a class's static stays keyed as it is, since libc++'s `get' by type keys `tuple_element' by `__find_exactly_one_t<...>::value' and folds it later, inside the instance
    cpp_bind_targs_(TPs, Rest, [P-A|Acc], B).
%% A TEMPLATE PARAMETER OF CLASS TYPE NAMES A TEMPLATE PARAMETER OBJECT ([temp.param]/8, [temp.arg.nontype]/1; C++20, P1907;
%% 0.197): a static object of type `const T', T the parameter's type -- DEDUCED by class template argument deduction where the type
%% is a class template's name, a placeholder (`template <Str S>' over `template <size_t N> struct Str') -- its value the argument
%% converted to T at compile time (the evaluator runs the constructor; an aggregate's list is completed by its defaults). The
%% parameter is the object's name in the instance, `$tpo_<fold>', one linkonce constant per type and value; a member read folds
%% through it (`'$cpp_gagg:'') and its address is static. `name<"hello">()' over `template <Str S> const char *name() { return
%% S.s; }' bound S to the literal itself and was refused `no_member(s, const char *)'. An argument that is already such an object
%% (a parameter handed on) is that object; one the evaluator cannot convert keeps the argument as it is.
cpp_class_nttp(K0, Acc, A, id(N)) :- K0 = base(_, [typedef(_)]), \+ cpp_tpo_name(A),
    cpp_subst(K0, Acc, K), K = base(Q, [typedef(TN)]),
    (   atom(TN), \+ catch(cpp_class_l(TN, _), _, fail), \+ catch(ccl_typedef_of(TN, _), _, fail), catch(cpp_ctad_args(TN, [A], TArgs), error(not_lowered(_), _), fail)
    ->  T0 = base(Q, [typedef(tmpl(TN, TArgs))])
    ;   T0 = K ),
    catch(cpp_type(T0, T), error(not_lowered(_), _), fail), cpp_class_of_type(T, C), !,
    ( A = compound_lit(_, init(Items)) -> I = init(Items) ; I = '$cpp_walked'(A) ),
    catch(cpp_fold_ctor_value(T, C, I, Init), _, fail),
    ( T = base(TQ, TS), \+ memberchk(const, TQ) -> CT = base([const|TQ], TS) ; CT = T ),
    term_to_atom(CT-Init, At), atom_codes(At, Cs), ccl_fold(Cs, 7, 31, F1), ccl_fold(Cs, 11, 37, F2), atomic_list_concat(['$tpo_', F1, '_', F2], N),
    (   cpp_instance_done(N) -> true
    ;   cpp_instance_note(N, tpo), ccl_gdeclare([N-CT]), ccl_tables_changed, atom_concat('$cpp_gagg:', N, GK), nb_setval(GK, agg(CT, Init, global)),
        cpp_as_lib(yes, cpp_add_instance_items([declaration(0, linkonce, CT, [var(N, CT, Init)])])) ).
cpp_tpo_name(id(N)) :- atom(N), sub_atom(N, 0, _, _, '$tpo_').
cpp_pack_kind(pack).
cpp_pack_kind(vpack(_)).
%% ... AND A VALUE PARAMETER OF A WRITTEN TYPE CONVERTS ITS ARGUMENT TO THAT TYPE ([temp.arg.nontype]/1: a converted
%% constant expression of the parameter's type; 0.199), wrapped to it: `template <unsigned N>' over `5' is `5u' in its
%% instance, `size_t _Size' over `3' a `3ul', a `bool' over `1' `true', `T V' with T bound the bound type's -- whatever road
%% bound it (the arguments written, a default, a deduction, an array's bound), so that one instance has one name. A
%% placeholder (`auto', `decltype(auto)') keeps the argument's own type (cpp_typed_value/3); an enumeration, a pointer, a
%% class, a type that does not resolve and an argument that is no literal (a call not folded yet) keep the argument.
cpp_vbinds_typed(TPs, B0, B) :- findall(P-K, ( member(tparam(K, P, _), TPs), atom(P), compound(K) ), PKs), ( PKs == [] -> B = B0 ; cpp_vbinds_map(B0, PKs, B0, B) ).
cpp_vbinds_map([], _, _, []).
cpp_vbinds_map([X|Bs], PKs, B0, [Y|Bs1]) :- ( X = P-A0, atom(P), memberchk(P-K, PKs), cpp_nttp_as(K, B0, A0, A1) -> Y = P-A1 ; Y = X ), cpp_vbinds_map(Bs, PKs, B0, Bs1).
cpp_nttp_as(vpack(T), B0, pack(L0), pack(L)) :- !, is_list(L0), cpp_nttp_as_list(L0, T, B0, L).
cpp_nttp_as(K0, B0, A0, A) :- K0 \= vpack(_), cpp_nttp_value(A0, V), integer(V), cpp_subst(K0, B0, K1), \+ cpp_has_auto(K1),
    catch(cpp_type(K1, K2), _, fail), catch(ccl_w_cast(K2, V, V1), _, fail), ( cpp_value_lit(K2, V1, A) -> true ; cpp_enum_value_lit(K2, V1, A) ), !.   % an enumeration's too (0.203): one value, one instance
%% A FUNCTION GIVEN TO A VALUE PARAMETER OF A PLACEHOLDER OR A POINTER TYPE IS ITS ADDRESS ([temp.param]/10: the parameter's type
%% is the decayed one; [temp.arg.nontype]/1; 0.206): bound to the function's name, `decltype(F)' was the function type in the
%% instance, where libc++ 21's `std::not_fn<f>()' asks `is_pointer_v<decltype(_Fn)>'. `X<f>' and `X<&f>' name one instance
%% (cpp_type_key/2).
cpp_nttp_as(K0, B0, id(F), addr(id(F))) :- atom(F), K0 \= vpack(_), cpp_nttp_fn_name(F), cpp_subst(K0, B0, K1),
    ( cpp_has_auto(K1) -> true ; catch(cpp_type(K1, K2), _, fail), catch(ccl_resolve_type(K2, ptr(_, _)), _, fail) ), !.
cpp_nttp_as_list([], _, _, []).
cpp_nttp_as_list([X0|Xs0], T, B0, [X|Xs]) :- ( cpp_nttp_as(T, B0, X0, X1) -> X = X1 ; X = X0 ), cpp_nttp_as_list(Xs0, T, B0, Xs).
cpp_nttp_value(bool(true), 1) :- !.
cpp_nttp_value(bool(false), 0) :- !.
cpp_nttp_value(cast(base(_, _), X), V) :- !, cpp_nttp_value(X, V).
cpp_nttp_value(A, V) :- compound(A), functor(A, F, 1), memberchk(F, [int, uint, long, ulong, chr, wchr, u16chr, u32chr]), arg(1, A, V), integer(V).
%% a template template parameter's argument is a template's name -- an atom (the reader gives a bare name as a
%% type, `Cell<int, Twice>'), a namespace's flattened away, or another such parameter's binding passed on
%% (`__split_buffer<_Tp, _Allocator, _Layout>') -- kept as tname(N): a type it is not, and no instance is made of it
cpp_tname_arg(tname(N), _, tname(N)) :- !.
cpp_tname_arg(mt(C, N), _, tname(mt(C, N))) :- !.   % a member alias template passed on (0.109)
cpp_tname_arg(base(_, [typedef(X)]), B, A) :- !, cpp_tname_arg(X, B, A).
cpp_tname_arg(scoped(Path, X), _, tname(mt(C, X))) :- atom(X), Path \== [], catch(cpp_scope_class(Path, C0), _, fail), cpp_member_alias_of(C0, X, C, _, _), !.   % (the declaring class: a base's alias is found through the derived one) A MEMBER ALIAS TEMPLATE as a template template argument keeps its class ([temp.arg.template]; 0.109): libc++'s `_IsValidExpansion<_Tester::template _Apply, _Iter>', three testers each with an `_Apply'
cpp_tname_arg(scoped(_, X), B, A) :- !, cpp_tname_arg(X, B, A).
%% A CLASS INSTANCE GIVEN TO A TEMPLATE TEMPLATE PARAMETER IS THE INJECTED CLASS NAME, which there names the class template
%% itself ([temp.local]/1; 0.182): no type is a template template argument, and inside an instance's body its template's name
%% is the instance (`Self' of cpp_instantiate_class_/3). libc++ 22's `__split_buffer_pointer_layout' names itself so, in
%% `__split_buffer<value_type, allocator_type, __split_buffer_pointer_layout>' within its own body; the instance's name was
%% taken for a template's, `__split_buffer' was made over it, and every `std::vector' over libc++ 22 ran past the cap.
cpp_tname_arg(X, _, tname(N)) :- atom(X), '$cpp_inst'(X, inst(N, _)), !.
cpp_tname_arg(X, B, tname(N)) :- atom(X), !, ( memberchk(X-tname(N0), B) -> N = N0 ; cpp_type_name_only(X) -> cpp_refuse(0, not_a_template_name(X)) ; N = X ).   % a TYPE'S name is no template (0.132): `ranges::to<std::string>(r)' is no candidate of the template template overload
cpp_tname_arg(X, _, _) :- cpp_refuse(0, not_a_template_name(X)).
%% A NAME THAT IS ONLY A TEMPLATE (the reader's set of templates, and no typedef or class of the name), and a name that
%% is only a type (a typedef or a class, and no template): what an explicit template argument's kind is checked by
cpp_bare_template_name(N) :- atom(N), ccl_known_template(N), \+ catch(ccl_typedef_of(N, _), _, fail), \+ catch(cpp_class_l(N, _), error(not_lowered(_), _), fail), !.
cpp_type_name_only(N) :- atom(N), \+ ccl_known_template(N), ( catch(ccl_typedef_of(N, _), _, fail) -> true ; catch(cpp_class_l(N, _), error(not_lowered(_), _), fail) ), !.
%% C++20: the head's requires-clause, under the bindings, must hold
%% ... AND IT SEES NO CALLER'S LOCAL (0.182; [temp.constr]: its names are looked up where the template is), as a member's
%% trailing clause has not since 0.110 (cpp_member_req_holds/4): libc++ 22's `views::zip_transform' names its parameter
%% `__fun' and asks, in its trailing return type, `views::all' of each range, and ref_view's constructor requires
%% `requires { __fun(std::declval<_Tp>()); }' of its own static `__fun' -- with the caller's frames open, the call went
%% to the caller's lambda, the requirement was unmet, and no `operator()' was left.
cpp_constraints_hold(N, TPs, B) :- ( memberchk(requires(_), TPs) -> cpp_isolated(cpp_constraints_hold_(TPs, N, B)) ; true ).   % EVERY requires entry (a written clause, and one per constrained auto parameter)
cpp_constraints_hold_([], _, _).
cpp_constraints_hold_([requires(R)|TPs], N, B) :- !, cpp_subst(R, B, R1), ( cpp_satisfied(R1) -> true ; cpp_refuse(0, constraint_not_satisfied(N)) ), cpp_constraints_hold_(TPs, N, B).
cpp_constraints_hold_([_|TPs], N, B) :- cpp_constraints_hold_(TPs, N, B).
cpp_bind_explicit([], _, []) :- !.
cpp_bind_explicit(_, [], []) :- !.
cpp_bind_explicit([requires(_)|TPs], As, B) :- !, cpp_bind_explicit(TPs, As, B).
cpp_bind_explicit([ttp(_, _)|TPs], As, B) :- !, cpp_bind_explicit(TPs, As, B).
cpp_bind_explicit([tparam(K, P, _)|_], As, [P-pack(As)]) :- cpp_pack_kind(K), !.
cpp_bind_explicit([tparam(template, P, _)|TPs], [A0|As], [P-A|B]) :- !, cpp_tname_arg(A0, [], A), cpp_bind_explicit(TPs, As, B).
cpp_bind_explicit([tparam(K, P, _)|TPs], [A0|As], [P-A|B]) :- ( cpp_targ_value(A0, A1) -> true ; cpp_trace(targ_raw(P, A0)), A1 = A0 ),   % EVALUATED where it binds, as the class path's arguments are
    ( K == type -> ( cpp_is_type(A1), \+ ( A1 = base(_, [typedef(TN)]), cpp_bare_template_name(TN) ) -> true ; cpp_refuse(0, kind_mismatch(P)) )   % ... and A TEMPLATE'S BARE NAME IS NO TYPE (0.132): `ranges::to<std::vector>(r)' bound `vector' to the overload whose `_Container' is a type, and the result was the bare name, no class   % A TYPE PARAMETER TAKES A TYPE and a value parameter a value ([temp.arg]): `get<0>(tup)' is no candidate of the by-TYPE get, whose `_T1' bound to 0 instantiated __find_exactly_one_t<0, ...> without end
    ; cpp_is_type(K) -> ( cpp_is_type(A1) -> cpp_refuse(0, kind_mismatch(P)) ; true )
    ; true ),
    ( K \== type, cpp_class_nttp(K, [], A1, A2) -> A = A2 ; A = A1 ),   % a parameter of class type names its template parameter object (0.197; cpp_class_nttp/4)
    cpp_bind_explicit(TPs, As, B).
%% what deduction left unbound: a pack is empty, a default stands (under the bindings so far), and a value
%% parameter's TYPE must resolve -- `enable_if<c, int>::type = 0' has no type when c is false (SFINAE)
cpp_bind_defaults([], B, B).
cpp_bind_defaults([requires(_)|TPs], B0, B) :- !, cpp_bind_defaults(TPs, B0, B).
cpp_bind_defaults([ttp(P, I)|TPs], B0, B) :- !, cpp_ttp_bind(P, I, B0, B1), cpp_bind_defaults(TPs, B1, B).             % its own list, for cpp_ttp_fill/4 (0.185)
cpp_bind_defaults([tparam(template, P, D)|TPs], B0, B) :- !,
    ( memberchk(P-_, B0) -> B1 = B0 ; D \== none -> cpp_tname_arg(D, B0, A), B1 = [P-A|B0] ; cpp_refuse(0, cannot_deduce(P)) ),
    cpp_bind_defaults(TPs, B1, B).
cpp_bind_defaults([tparam(K, P, D)|TPs], B0, B) :-
    (   atom(P), memberchk(P-_, B0) -> B1 = B0                                            % ... and it binds nothing either, for the same reason
    ;   cpp_pack_kind(K) -> ( atom(P) -> B1 = [P-pack([])|B0] ; B1 = B0 )
    ;   D \== none -> cpp_subst(D, B0, D1), cpp_type_or_value(D1, A), ( atom(P) -> B1 = [P-A|B0] ; B1 = B0 )   % the default is still RESOLVED: that resolution is the SFINAE
    ;   atom(P) -> cpp_refuse(0, cannot_deduce(P))
    ;   B1 = B0 ),
    ( cpp_value_param_type(K, T0) -> cpp_subst(T0, B1, T1), cpp_type(T1, T2), cpp_type_resolved(T2) ; true ),
    cpp_bind_defaults(TPs, B1, B).
cpp_value_param_type(K, K) :- compound(K), K \= vpack(_), cpp_is_type(K).
cpp_type_resolved(T) :- \+ cpp_has_scoped(T).
cpp_has_scoped(T) :- compound(T), ( T = typedef(scoped(_, _)) -> true ; T =.. [_|As], member(A, As), cpp_has_scoped(A) ).
cpp_deduce_args([param(pack(T), _)], As, TPs, B0, B) :- !,                                       % a trailing pack: one element deduced per argument left
    findall(AT, ( member(A, As),
                  (   T = rref(_, base(_, [typedef(_)])), cpp_string_literal(A, AT1) -> AT = ref([], AT1)   % a string literal, an lvalue of `const char[N]' (0.167): `const char (&)[N]', as `count("a", "bcd")' deduces it
                  ;   T = rref(_, base(_, [typedef(_)])), cpp_lvalue_deep(A), cpp_deduce_type(A, AT0) -> ccl_unref(AT0, AT1), AT = ref([], AT1)   % a forwarding pack, an lvalue: as a reference (judged on the desugared argument too, cpp_lvalue_deep)
                  ;   cpp_deduce_type(A, AT0) -> ( T = ref(_, _) -> ccl_unref(AT0, AT) ; cpp_decayed(AT0, AT) )   % a REFERENCE pattern takes the argument undecayed ([temp.deduct.call]/2; 0.167)
                  ;   AT = unknown ) ), ATs),
    cpp_deduce_pack(T, ATs, TPs, B0, B).
cpp_deduce_args([], _, _, B, B) :- !.
cpp_deduce_args(_, [], _, B, B) :- !.
cpp_deduce_args([P|Ps], [A|As], TPs, B0, B) :- ( P = param(PT, _) ; P = param(PT, _, _) ), !, cpp_deduce_one(PT, A, TPs, B0, B1), cpp_deduce_args(Ps, As, TPs, B1, B).
cpp_deduce_args([_|Ps], [_|As], TPs, B0, B) :- cpp_deduce_args(Ps, As, TPs, B0, B).
cpp_deduce_pack(T, ATs, TPs, B0, [P-pack(Es)|B0]) :-
    cpp_pack_param_in(T, TPs, P), !,
    findall(E, ( member(AT, ATs), ( AT == unknown -> E = unknown ; cpp_pack_elem(T, AT, P, E) ) ), Es).
cpp_deduce_pack(_, _, _, B, B).
%% one element of a pack: `T &...' and `const T &...' given an ARRAY take the array, the pattern's own qualifiers off its
%% element (0.167): libc++'s `make_format_args(_Args &... __args)' over a string literal's `const char (&)[2]' deduced the
%% pointer it decays to, and `std::format("{} {}", "a", "b")' formatted a reference to a pointer that was never made
cpp_pack_elem(ref(_, base(Q, [typedef(P)])), AT, P, arr(K, E)) :- ccl_resolve_type(AT, arr(K, E0)), !,
    cpp_strip_quals(E0, EQ, E1), subtract(EQ, Q, EQ1), cpp_with_quals(EQ1, E1, E).
cpp_pack_elem(T, AT, P, E) :- cpp_match(T, AT, [tparam(type, P, none)], [], Bk), memberchk(P-E, Bk).
cpp_pack_param_in(T, TPs, P) :- member(tparam(pack, P, _), TPs), cpp_names_in(T, P), !.
cpp_explicit_skip([], _, _, []).
cpp_explicit_skip([P|Ps], TPs, B0, [Q|Qs]) :-
    ( ( P = param(PT, _) ; P = param(PT, _, _) ), PT \= pack(_), cpp_tparam_names(TPs, Ns),
      once(( member(N1, Ns), cpp_term_mentions(PT, N1) )), \+ ( member(N2, Ns), \+ memberchk(N2-_, B0), cpp_term_mentions(PT, N2) )
    ->  Q = skip ; Q = P ),
    cpp_explicit_skip(Ps, TPs, B0, Qs).
%% ... A PARAMETER NAMING A GIVEN AND A DEDUCED ONE TAKES PART (0.208): the two tests shared one variable, so the name the first
%% found stood for the second, and `T (&&)[N]' with T given was skipped -- `std::to_array<std::string>({"x", "yy"})' could not
%% deduce N
cpp_deduce_one(_, A, _, B, B) :- cpp_fn_template_ref(A, _), !.                                  % a template's name is a NON-DEDUCED CONTEXT ([temp.deduct.call]/6)
cpp_deduce_one(PT, init(Items), TPs, B0, B) :- Items \== [], cpp_il_param(PT, EPT), !, cpp_deduce_items(Items, EPT, TPs, B0, B).   % A BRACED LIST AGAINST `initializer_list<P>' DEDUCES P FROM EACH ITEM ([temp.deduct.call]/1; 0.132): zip_view's `size()' is `ranges::min({_CT(__sizes)...})', and `_Tp' of `operator()(initializer_list<_Tp>, ...)' was never deduced, `cannot_deduce(_Tp)'
cpp_deduce_one(PT, init(Items), TPs, B0, B) :- Items \== [], ccl_unref(PT, PT1), PT1 = arr(K, EPT), !, ( cpp_deduce_items(Items, EPT, TPs, B0, B1) -> true ; \+ ( member(tparam(_, P, _), TPs), atom(P), \+ memberchk(P-_, B0), cpp_mentions(EPT, typedef(P)) ) -> B1 = B0 ), length(Items, N), cpp_match_bound(K, int(N), TPs, B1, B).   % (an element type the explicit arguments give whole deduces nothing from the items, 0.208: `std::to_array<std::string>({"x", "yy"})') ... AND AGAINST `P (&)[N]' AND `P (&&)[N]' DEDUCES P FROM EACH ITEM AND N FROM THE LIST'S LENGTH ([temp.deduct.call]/1; 0.206): `std::to_array({7, 8, 9})' was `cannot_deduce(_Tp)'
cpp_deduce_one(rref(_, base(_, [typedef(P)])), A, TPs, B0, [P-ref([], AT)|B0]) :-                   % ... a STRING LITERAL is such an lvalue (0.167): `const char (&)[N]', as libc++'s `_Args &&...' take it
    memberchk(tparam(type, P, _), TPs), \+ memberchk(P-_, B0), cpp_string_literal(A, AT), !.
cpp_deduce_one(rref(_, base(_, [typedef(P)])), A, TPs, B0, [P-ref([], AT1)|B0]) :-                 % A FORWARDING REFERENCE, `T &&' with T a parameter, given an LVALUE: T is the argument's type AS A REFERENCE ([temp.deduct.call]/3)
    memberchk(tparam(type, P, _), TPs), \+ memberchk(P-_, B0), cpp_lvalue_deep(A), cpp_deduce_type(A, AT), !, ccl_unref(AT, AT1).
%% ... so `std::forward<T>' hands the lvalue back as one (T& && collapses to T&, cpp_collapse_ref), and the
%% rvalue-stream inserter's `is_base_of<ios_base, _Stream>' is FALSE for `basic_ostream &' -- deduced as the plain
%% class it was viable for an lvalue stream, and with `<iomanip>''s hidden friend unknown it called itself until
%% the stack ran out. Every `_Args &&...' pack the containers forward through takes the same rule (cpp_deduce_args).
cpp_deduce_one(ref(_, base(_, [typedef(P)])), A, TPs, B0, [P-AT1|B0]) :-                        % `T &' AND `const T &' GIVEN A FUNCTION DEDUCE THE FUNCTION TYPE ([temp.deduct.call]/2: no function-to-pointer conversion for a reference P; 0.126): libc++ 21's `std::thread' hands `std::addressof(__thread_proxy<_Gp>)' to `__libcpp_thread_create', and `_Tp := pointer to function' made it a pointer to a pointer -- the call stayed raw, its definition never emitted (addressfn.cpp)
    memberchk(tparam(type, P, _), TPs), \+ memberchk(P-_, B0), cpp_deduce_type(A, AT), ccl_unref(AT, AT1), ccl_resolve_type(AT1, fn(_, _, _)), !.
cpp_deduce_one(ref(_, base(Q, [typedef(P)])), A, TPs, B0, [P-AT1|B0]) :-                       % `T &' GIVEN A CONST LVALUE DEDUCES T WITH ITS CONST ([temp.deduct.call]/2: the top-level qualifiers decay only for a by-value P; 0.99): `std::addressof(_Tp &)' over a `const int &' is `addressof<const int>', where `_Tp := int' made a `T &' that no const lvalue binds
    memberchk(tparam(type, P, _), TPs), \+ memberchk(P-_, B0), \+ memberchk(const, Q), cpp_deduce_type(A, AT), ccl_unref(AT, AT1), ( cpp_top_const(AT1) ; AT1 = arr(_, _) ), !.   % ... and AN ARRAY STAYS AN ARRAY (0.112, [temp.deduct.call]/2: no array-to-pointer conversion for a reference P): ranges::begin's `_Tp &' over libc++'s `__entries[1496]' deduced a pointer, `is_array_v<_Tp>' was false and ranges::upper_bound had no candidate
cpp_deduce_one(PT, A, TPs, B0, B) :- ( cpp_deduce_type(A, AT0) -> cpp_ptr_decay(PT, AT0, AT), cpp_match(PT, AT, TPs, B0, B) ; B = B0 ).
%% A FUNCTION OR AN ARRAY GIVEN TO A PARAMETER OF POINTER TYPE IS THE POINTER IT DECAYS TO ([temp.deduct.call]/2: P is no reference;
%% 0.201): `template <class R, class... A> int arity(R (*)(A...))' called with a function's name, and libc++'s guide `function(_Rp
%% (*)(_Ap...)) -> function<_Rp(_Ap...)>' of `std::function f{twice};', deduced nothing from the function type, `cannot_deduce(R)'
cpp_ptr_decay(ptr(_, _), AT0, AT) :- catch(ccl_resolve_type(AT0, R), _, fail), ( R = fn(_, _, _) -> AT = ptr([], R) ; R = arr(_, E) -> AT = ptr([], E) ), !.
cpp_ptr_decay(_, AT, AT).
%% ... judged on the DESUGARED argument where the raw one cannot tell: `std::forward<_That>(__opt).__get()' is a
%% member call whose instance returns `const value_type &' -- read raw it was no lvalue, `_Args' deduced the plain
%% string, and `optional''s copy MOVED the source's string out (its size read 0 after the copy)
cpp_lvalue_deep(A) :- cpp_lvalue(A), !.
cpp_lvalue_deep(A) :- cpp_deep_form(A, A1), cpp_lvalue(A1), !.
cpp_deep_form(A, A1) :- A \= move(_), A \= call(scoped(_, move), _), cpp_caller_ctx(Ctx, Class), ccl_global('$cpp_temps', Ts, none),
    ( catch(cpp_in_class(Class, cpp_expr(Ctx, A, A1)), E, ( cpp_trace(lvalue_deep_refused(E)), fail )) -> true ; A1 = A ), ( Ts == none -> true ; nb_setval('$cpp_temps', Ts) ),
    A1 \== A.
%% AN ARGUMENT IS AN LVALUE ([basic.lval]; 0.121) judged on its DESUGARED form where the raw one cannot tell, an xvalue never: a member initializer's `std::forward<_Args>(__args)'
%% is raw when the constructor is chosen, and read as no lvalue it took the MOVE constructor for every argument -- libc++'s `__alt(in_place_t, _Args &&... __args) :
%% __value(std::forward<_Args>(__args)...)' moved the string out of a variant being COPIED
cpp_arg_lvalue(A) :- ( cpp_lvalue(A) -> A1 = A ; cpp_deep_form(A, A1), cpp_lvalue(A1) ), \+ cpp_xvalue_object(A1), !.
cpp_il_param(PT, EPT) :- ccl_unref(PT, base(_, [typedef(Q)])), cpp_il_template(Q, EPT).
cpp_il_template(tmpl(initializer_list, [EPT]), EPT).
cpp_il_template(scoped(_, tmpl(initializer_list, [EPT])), EPT).
cpp_deduce_items([], _, _, B, B).
cpp_deduce_items([It|Is], EPT, TPs, B0, B) :- ( It = item(_, V) -> true ; V = It ), cpp_deduce_one(EPT, V, TPs, B0, B1), cpp_deduce_items(Is, EPT, TPs, B1, B).
%% THE TYPE AN ARGUMENT HAS, FOR DEDUCTION: the inference's, else the DESUGARED form's (cpp_arg_type, 0.68's one
%% door), the temporaries that walk registers dropped again -- `__index_sequence_for<_Args1...>()' is a call of an
%% alias template's instance, which only the desugaring can type, and typed unknown its pack `_I1' stayed EMPTY
%% beside a bound `_Args1', so pair's piecewise delegation substituted two packs of different lengths and failed
%% without a word. A template's name has no type to deduce from (a non-deduced context, the first clause above).
cpp_deduce_type(A, AT) :- cpp_string_literal(A, AT), !.
cpp_deduce_type(id(N), AT) :- atom(N), cpp_nx_fn_name(N), \+ cpp_local(N), cpp_decltype_of(id(N), AT), AT = fn(_, _, _), !.   % A NOEXCEPT FUNCTION'S NAME deduces its type with the mark (0.199; [except.spec]/2): `inv(pn)' deduces `void (&)() noexcept', which the instance's own condition reads
cpp_deduce_type(addr(id(N)), AT) :- atom(N), cpp_nx_fn_name(N), \+ cpp_local(N), cpp_decltype_of(addr(id(N)), AT), !.   % A STRING LITERAL IS AN LVALUE OF `const char[N]' ([lex.string]/10, [expr.prim.literal]/1; 0.167): a by-value parameter takes the pointer it decays to (`T' is `const char *'), a reference the array (`T &' is `const char (&)[N]')
cpp_deduce_type(A, AT) :- \+ cpp_fn_template_ref(A, _), ccl_global('$cpp_temps', Ts, none),
    (   catch(cpp_arg_type(A, AT0), _, fail) -> nb_setval('$cpp_temps', Ts), AT0 \== unknown, AT = AT0
    ;   nb_setval('$cpp_temps', Ts), fail ).
%% a string literal's own type, the array of its code units and the NUL: `const char[N]', `const wchar_t[N]' ...
cpp_string_literal(str(Cs), arr(int(N), base([const], [char]))) :- !, length(Cs, K), N is K + 1.
cpp_string_literal(u8str(Cs), arr(int(N), base([const], [char8_t]))) :- !, length(Cs, K), N is K + 1.   % C++20's u8"..." (0.196)
cpp_string_literal(wstr(Cs), arr(int(N), base([const], [wchar_t]))) :- !, ccl_utf8_count(Cs, K), N is K + 1.
cpp_string_literal(u32str(Cs), arr(int(N), base([const], [char32_t]))) :- !, ccl_utf8_count(Cs, K), N is K + 1.
cpp_string_literal(u16str(Cs), arr(int(N), base([const], [char16_t]))) :- ccl_utf16_count(Cs, K), N is K + 1.
cpp_match(base(_, [typedef(P)]), AT, TPs, B0, B) :- memberchk(tparam(type, P, _), TPs), !, ( memberchk(P-Bound, B0) -> cpp_deduced_agree(P, Bound, AT, B0), B = B0 ; cpp_decayed(AT, AT1), B = [P-AT1|B0] ).
cpp_match(base(_, [typedef(scoped(Path, _))]), _, TPs, B, B) :- cpp_path_dependent(Path, TPs), !.   % A NAME QUALIFIED BY A PARAMETER IS A NON-DEDUCED CONTEXT, whatever it names: `typename _IterOps<_AlgPolicy>::template __difference_type<_InIter> __n' binds nothing here and resolves once the others bind it (C++'s nested-name-specifier rule; 0.46 had it for a pattern); its last segment taken for a class template refused deduction_failed
cpp_match(base(_, [typedef(X)]), AT, TPs, B0, B) :- cpp_template_id(X, N, UArgs), \+ memberchk(tparam(template, N, _), TPs), cpp_alias_template(N), !,
    (   cpp_alias_pattern(N, UArgs, X2) -> cpp_match(base([], [typedef(X2)]), AT, TPs, B0, B)   % THROUGH THE ALIAS: `__index_sequence<_I1...>' is `__integer_sequence<size_t, _I1...>', which deduces -- C++ substitutes an alias before deducing; an alias that is no template-id stays a non-deduced context
    ;   cpp_vector_alias(N, UArgs, K, X2, E2) -> cpp_match_vector(K, X2, E2, AT, TPs, B0, B)   % a vector alias (0.162): `__all_of(__simd_vector<_Tp, _Np>)'
    ;   B = B0 ).
cpp_match(base(_, [typedef(X)]), _, TPs, B, B) :- cpp_template_id(X, N, _), \+ memberchk(tparam(template, N, _), TPs), cpp_nested_alias(N, _, _, _), !.   % A MEMBER ALIAS TEMPLATE'S TEMPLATE-ID IS A NON-DEDUCED CONTEXT too (0.93): libc++ 18 writes `unique_ptr(pointer, _LValRefType<_Dummy>)' with `_LValRefType' the class's own alias template over the constructor's defaulted `_Dummy' -- read as a class template-id it refused deduction_failed, and no two-argument constructor was left
%% A PARAMETER WHOSE TEMPLATE PARAMETERS ALL STAND IN NON-DEDUCED CONTEXTS takes no part in deduction
%% ([temp.deduct.call]/1, [temp.deduct.type]/5; 0.108): libc++'s `format(format_string<_Args...>, _Args &&...)' is
%% `basic_format_string<char, type_identity_t<_Args>...>' against a string literal -- `_Args' comes from the pack,
%% and the literal converts through the class's constructor once it is bound
cpp_match(base(_, [typedef(X)]), AT, TPs, B, B) :- cpp_template_id(X, N, Sub), \+ memberchk(tparam(template, N, _), TPs), Sub \== [],
    \+ cpp_instance_or_base(AT, N, _, _), cpp_tparam_names(TPs, Ns), forall(member(E, Sub), cpp_elem_nondeduced(E, TPs, Ns)), !.
cpp_match(base(_, [typedef(X)]), AT, TPs, B0, B) :- cpp_template_id(X, N, Sub), !,                  % f(H<T>), f(vector<T>): the argument an instance of N, or of what H is bound to
    ( memberchk(tparam(template, N, _), TPs) -> Want = any ; catch(cpp_nested_template(N, MN), _, fail) -> Want = MN ; Want = N ),   % a MEMBER CLASS TEMPLATE named short in its class is its registered name (0.115): `__get_current(const __iterator<_AnyConst> &)', a static member template of elements_view's sentinel
    (   cpp_instance_or_base(AT, Want, N1, SubArgs)
    ->  ( Want == any -> ( memberchk(N-tname(N0), B0) -> N0 == N1, B1 = B0 ; B1 = [N-tname(N1)|B0] ) ; B1 = B0 ),
        cpp_match_targs(Sub, SubArgs, TPs, B1, B)
    ;   cpp_refuse(0, deduction_failed(N)) ).                                                         % not an instance: no candidate
cpp_match(fn(R, Ps, V), AT, TPs, B0, B) :- !, cpp_match_fnconv(fn(R, Ps, V), AT, TPs, B0, B).   % a FUNCTION TYPE as a parameter or a template argument is matched exactly, never decayed ([temp.deduct.type]): `operator==(const function<_Rp(_ArgTypes...)> &, nullptr_t)' deduces both from function<int(int)>
cpp_match(memptr(CP, _, X), AT, TPs, B0, B) :- !, ccl_resolve_type(AT, memptr(CA, _, Y)),   % `R T::*pm', which is how std::mem_fn takes its argument
    cpp_match_one(base([], [typedef(CP)]), base([], [typedef(CA)]), TPs, B0, B1), cpp_match_fnconv(X, Y, TPs, B1, B).
cpp_match(ptr(_, X), AT, TPs, B0, B) :- ccl_resolve_type(AT, AT1), ( AT1 = ptr(_, Y) ; AT1 = arr(_, Y) ), !, cpp_match_pointee(X, Y, TPs, B0, B).
%% AN ARRAY BOUND DEDUCES ([temp.deduct.type]/9: `T (&a)[N]' binds N from the argument's own bound), which a
%% REFERENCE parameter brings undecayed -- libc++ writes `__find_idx(size_t __i, const bool (&__matches)[_Nx])',
%% which is how `get<T>' finds a type's place in a tuple, and with no clause for an array pattern the bound was
%% matched by nothing and every get-by-type refused cannot_deduce(_Nx).
cpp_match(arr(K, X), AT, TPs, B0, B) :- ccl_resolve_type(AT, arr(K1, Y)), !, cpp_match_bound(K, K1, TPs, B0, B1), cpp_match_pointee(X, Y, TPs, B1, B).   % AN ELEMENT KEEPS ITS QUALIFIERS as a pointee does (0.112): `_Tp (&)[_Np]' against `const uint32_t[5]' is _Tp = const uint32_t, where the decaying match gave uint32_t
cpp_match(ref(_, X), AT, TPs, B0, B) :- !, cpp_match(X, AT, TPs, B0, B).
cpp_match(rref(_, X), AT, TPs, B0, B) :- !, cpp_match(X, AT, TPs, B0, B).
cpp_match(_, _, _, B, B).
%% A CALL'S ARGUMENT MAY TAKE THE FUNCTION POINTER CONVERSION ([temp.deduct.call]/4, [conv.fctptr]; 0.205): a pattern of a function
%% type with no `noexcept' deduces from a noexcept function's, the mark dropped, at the call's own level -- a pointer, a
%% reference, a pointer to member -- never inside a template-id, where the types must be the same. Since 0.199 a noexcept
%% function's name deduces its type with the mark, and `template <class R> int g(R (*)());' took no `int k() noexcept': no_matching_template
cpp_match_fnconv(X, Y, TPs, B0, B) :- cpp_match_one(X, Y, TPs, B0, B), !.
cpp_match_fnconv(X, Y, TPs, B0, B) :- X = fn(_, _, _), ccl_resolve_type(Y, fn(RA, PsA, VA)), nonvar(VA), VA = q(W, Qs), select(noexcept, Qs, Qs1),
    ( Qs1 == [] -> VA1 = W ; VA1 = q(W, Qs1) ), cpp_match_one(X, fn(RA, PsA, VA1), TPs, B0, B).
cpp_alias_pattern(N, UArgs, X) :- cpp_class_template(N, TPs, typedef(_, [var(_, base(_, [typedef(X0)]), _)])), cpp_alias_binds(TPs, UArgs, B),
    (   cpp_template_id(X0, _, _) -> cpp_subst(base([], [typedef(X0)]), B, base(_, [typedef(X2)]))
    ;   atom(X0), memberchk(tparam(type, X0, _), TPs), memberchk(X0-base(_, [typedef(X2)]), B) ),   % A TRANSPARENT ALIAS, `template <class _Type, class> using __enable_hash_helper_imp = _Type;': its argument (0.99)
    (   cpp_template_id(X2, N2, Args2), atom(N2), \+ memberchk(tparam(template, N2, _), TPs), cpp_transparent_alias(N2, Args2, X3) -> X = X3 ; X = X2 ).   % ... and through one: libc++'s `hash<__enable_hash_helper<optional<_Tp>, ...>>' is `hash<optional<_Tp>>' to the matcher, as C++ has it
cpp_transparent_alias(N, Args, X) :- cpp_class_template(N, TPs, typedef(_, [var(_, base(_, [typedef(P)]), _)])), atom(P), memberchk(tparam(type, P, _), TPs), cpp_alias_binds(TPs, Args, B), memberchk(P-base(_, [typedef(X)]), B), !.
%% an alias template whose definition is a vector type, its element and lane count in the pattern's words (0.162)
cpp_vector_alias(N, UArgs, K, X, E) :- cpp_class_template(N, ATPs, typedef(_, [var(_, base(_, [vector(K, X0, E0)]), _)])), cpp_alias_binds(ATPs, UArgs, B), cpp_subst(X0, B, X), cpp_subst(E0, B, E), !.
%% a type's name that names a vector type, the vector (0.162)
cpp_vector_named(F, T) :- cpp_braced_spec(F, Spec), \+ cpp_raw_type(base([], [Spec])), catch(cpp_type(base([], [Spec]), T0), error(not_lowered(_), _), fail), ccl_resolve_type(T0, T), T = base(_, [vec(_, _, _)]), !.   % a name, a template-id, a qualified name, as a braced class's (cpp_braced_class/3)
cpp_vector_named(base(Q, S), T) :- catch(cpp_type(base(Q, S), T0), error(not_lowered(_), _), fail), ccl_resolve_type(T0, T), T = base(_, [vec(_, _, _)]), !.
%% the count a vector's type spells: an ext_vector_type its lanes, a vector_size its bytes
cpp_vector_count(K, N, AE, V) :- ( K == ext -> V = N ; ccl_size_of(AE, ES), V is N * ES ).
cpp_match_vector(K, X, E, AT, TPs, B0, B) :-
    (   ccl_resolve_type(AT, base(_, [vec(K, N, AE)])) -> cpp_vector_count(K, N, AE, V), cpp_match_bound(X, int(V), TPs, B0, B1), cpp_match(E, AE, TPs, B1, B)
    ;   cpp_refuse(0, deduction_failed(vector(K))) ).
cpp_alias_binds([], _, []).
cpp_alias_binds([requires(_)|TPs], As, B) :- !, cpp_alias_binds(TPs, As, B).
cpp_alias_binds([ttp(_, _)|TPs], As, B) :- !, cpp_alias_binds(TPs, As, B).
cpp_alias_binds([tparam(K, P, _)|_], As, [P-pack(As)]) :- cpp_pack_kind(K), !.                 % a pack takes the rest as written: an expansion `_I1...' stays one element
cpp_alias_binds([tparam(_, P, _)|TPs], [A|As], [P-A|B]) :- cpp_alias_binds(TPs, As, B).
cpp_tparam_names(TPs, Ns) :- findall(P, member(tparam(_, P, _), TPs), Ns).
cpp_elem_nondeduced(pack(E), TPs, Ns) :- !, cpp_elem_nondeduced(E, TPs, Ns).
cpp_elem_nondeduced(E, _, Ns) :- \+ ( member(P, Ns), cpp_term_mentions(E, P) ), !.
cpp_elem_nondeduced(base(_, [typedef(X)]), _, _) :- cpp_template_id(X, N2, _), cpp_alias_template(N2), !.
cpp_elem_nondeduced(base(_, [typedef(scoped(Path, _))]), TPs, _) :- cpp_path_dependent(Path, TPs).
cpp_term_mentions(T, P) :- T == P, !.
cpp_term_mentions(T, P) :- compound(T), T =.. [_|As], member(A, As), cpp_term_mentions(A, P), !.
%% `conditional_t<B, T, F>' and libc++'s `__conditional_t<B, T, F>', the aliases of `typename conditional<B, T, F>::type' (0.136):
%% C++ completes no class that a template argument only names ([temp.inst]/2), so of the two arms only the one the condition
%% takes is resolved -- this compiler makes every class a template argument names, and libc++'s `__writer_selector' names
%% `__writer_container<void>', whose body cannot be made (`no_member_type(void, value_type)'), in the arm a `void' container
%% does not take: every std::format_to over an ostreambuf_iterator stopped there (chrono formatting writes through one)
cpp_conditional_alias(N) :- memberchk(N, [conditional_t, '__conditional_t']), catch(cpp_class_template(N, _, typedef(_, _)), _, fail), !.
cpp_truth(bool(V), V) :- !, ( V == true ; V == false ).
cpp_truth(V0, Tr) :- catch(ccl_const_eval(V0, V), _, fail), integer(V), ( V =:= 0 -> Tr = false ; Tr = true ).
cpp_alias_template(N) :- atom(N), catch(cpp_class_template(N, _, typedef(_, _)), _, fail), \+ ( cpp_class_template(N, _, I), cpp_template_class_def(I) ), !.   % an alias only: std::pmr::vector shares std::vector's flattened name, and the class wins
%% the argument's type as an instance of the template wanted (any, for a template template parameter): itself, or a base
%% of its class -- a derived object binds a base's reference
cpp_instance_or_base(AT, Want, N, Args) :-
    ( cpp_instance_of(AT, N0, Args0) ; ccl_resolve_type(AT, AT1), AT1 \== AT, cpp_instance_of(AT1, N0, Args0) ), cpp_wanted(Want, N0), !, N = N0, Args = Args0.
cpp_instance_or_base(AT, Want, N, Args) :- cpp_class_of_type(AT, C), cpp_class_base_instance(C, Want, N, Args), cpp_converted.
cpp_class_base_instance(C, Want, N, Args) :- cpp_class_l(C, cls(B, _, _, _, _)), B \== none,
    ( '$cpp_inst'(B, inst(N0, Args0)), cpp_wanted(Want, N0) -> N = N0, Args = Args0 ; cpp_class_base_instance(B, Want, N, Args) ).
cpp_class_base_instance(C, Want, N, Args) :- '$cpp_base_slot'(C, B, _),   % a LATER base with storage too (0.117): `operator<<(basic_ostream<_CharT, _Traits> &, const char *)' deduced from a basic_stringstream, whose basic_ostream is the SECOND base of its basic_iostream
    ( '$cpp_inst'(B, inst(N0, Args0)), cpp_wanted(Want, N0) -> N = N0, Args = Args0 ; cpp_class_base_instance(B, Want, N, Args) ).
cpp_class_base_instance(C, Want, N, Args) :- '$cpp_extra'(C, Bs), member(B, Bs),   % ... AND A LATER BASE WITH NO STORAGE (0.126): the EMPTY base has no sub-object and no slot, but a class derives from it all the same ([temp.deduct.call]/4.3). libc++ 21's `_RangeAdaptorClosure' asks `ranges::__derived_from_range_adaptor_closure((T *) nullptr)' for `__pipeable<_Fn> : _Fn, __range_adaptor_closure<__pipeable<_Fn>>', the CRTP base second and empty: `deduction_failed(__range_adaptor_closure)', `no_operator(|)' for every `v | views::drop(5)'
    ( '$cpp_inst'(B, inst(N0, Args0)), cpp_wanted(Want, N0) -> N = N0, Args = Args0 ; cpp_class_base_instance(B, Want, N, Args) ).
cpp_wanted(any, _) :- !.
cpp_wanted(N, N).
%% A POINTEE KEEPS ITS QUALIFIERS ([temp.deduct.call]/4; 0.108): only a by-value parameter's own top level decays,
%% so `T *' against `const int *' is T = const int, and `const T *' against it T = int -- deduced through the
%% decaying clause, libc++'s `__to_address(_Tp *)' gave `int *' for a `const int *' and ranges' __unwrap_range built
%% a pair<int *, int *> from two `const int *'
cpp_match_pointee(base(Q, [typedef(P)]), Y, TPs, B0, B) :- memberchk(tparam(type, P, _), TPs), !,
    ( memberchk(P-Bound, B0) -> cpp_deduced_agree(P, Bound, Y, B0), B = B0 ; cpp_less_quals(Q, Y, Y1), B = [P-Y1|B0] ).
cpp_match_pointee(X, Y, TPs, B0, B) :- cpp_match(X, Y, TPs, B0, B).
cpp_less_quals(Q, base(QY, S), base(QY1, S)) :- !, cpp_cv_minus(QY, Q, QY1).
cpp_less_quals(Q, ptr(QY, E), ptr(QY1, E)) :- !, cpp_cv_minus(QY, Q, QY1).
cpp_less_quals(_, Y, Y).
cpp_cv_minus(QY, Q, QY1) :- findall(X, ( member(X, QY), \+ ( ( X == const ; X == volatile ), memberchk(X, Q) ) ), QY1).
cpp_match_bound(id(P), K1, TPs, B0, B) :- cpp_value_param(P, TPs), \+ memberchk(P-_, B0), ccl_const_eval(K1, V), !, B = [P-int(V)|B0].
cpp_match_bound(_, _, _, B, B).
cpp_value_param(P, TPs) :- atom(P), memberchk(tparam(K, P, _), TPs), cpp_value_param_type(K, _).
cpp_match_targs([], _, _, B, B) :- !.
cpp_match_targs([pack(base(_, [typedef(P)]))], As, TPs, B0, B) :- memberchk(tparam(K, P, _), TPs), cpp_pack_kind(K), !, ( memberchk(P-_, B0) -> B = B0 ; B = [P-pack(As)|B0] ).   % a PACK as the last argument of a template-id takes every argument left: `tuple<_Args1...>' against tuple<int &&>, which pair's piecewise constructor deduces from
cpp_match_targs([pack(id(P))], As, TPs, B0, B) :- memberchk(tparam(vpack(_), P, _), TPs), !, ( memberchk(P-_, B0) -> B = B0 ; B = [P-pack(As)|B0] ).
cpp_match_targs(_, [], _, B, B) :- !.
cpp_match_targs([P|Ps], [A|As], TPs, B0, B) :-
    (   P = base(Q, [typedef(N)]), memberchk(tparam(type, N, _), TPs)        % A TEMPLATE ARGUMENT BINDS THE TYPE AS IT IS ([temp.deduct.type]/1; 0.95): the decay is [temp.deduct.call]'s, a by-value FUNCTION parameter's, and through cpp_match `pair<_T1, _T2> &' against a map's `pair<const string, int>' bound _T1 to `string' -- invisible while the keys carried no qualifiers, refused `argument_mismatch' once they did
    ->  ( memberchk(N-Bound, B0) -> cpp_deduced_agree(N, Bound, A, B0), B1 = B0 ; cpp_pattern_quals(Q, A, A1) -> B1 = [N-A1|B0] ; B1 = B0 )
    ;   cpp_is_type(P) -> \+ cpp_targ_fixed_differs(P, A, TPs), cpp_match(P, A, TPs, B0, B1)
    ;   P = id(V), memberchk(tparam(K, V, _), TPs), \+ memberchk(K, [type, pack, template]), \+ memberchk(V-_, B0) -> B1 = [V-A|B0]
    ;   B1 = B0 ),
    cpp_match_targs(Ps, As, TPs, B1, B).
%% A TEMPLATE ARGUMENT THAT NAMES NO PARAMETER OF THE TEMPLATE IS MATCHED EXACTLY ([temp.deduct.type]/1 and /8; 0.221): the `char' of
%% `basic_ostream<char, _Traits> &' against a `basic_ostream<wchar_t, char_traits<wchar_t>>' fails the deduction. The match took any
%% type there, so libc++ 18's deleted `operator<<(basic_ostream<char, _Traits> &, const wchar_t *)' deduced `_Traits :=
%% char_traits<wchar_t>' from a wide stream and made `basic_ostream<char, char_traits<wchar_t>>', whose basic_ios's static assertion
%% fails. A type that does not resolve on either side is no difference.
cpp_targ_fixed_differs(P, A, TPs) :- A \== unknown, cpp_tparam_names(TPs, Ns), \+ ( member(N, Ns), cpp_term_mentions(P, N) ),
    catch(( cpp_type(P, P1), cpp_type(A, A1) ), _, fail), \+ catch(cpp_same_type(P1, A1), _, true), !.
%% A TEMPLATE PARAMETER DEDUCED FROM TWO PARAMETERS DEDUCES ONE TYPE ([temp.deduct.type]; 0.126): the first binding stood for the
%% second silently, so `operator/(const _Tp &, const complex<_Tp> &)' held for two `complex<double>' with `_Tp := complex<double>'
%% and won over the candidate that deduces `_Tp := double' from both, and libc++ 21's `complex<double> / complex<double>' built a
%% `complex<complex<double>>'. Only a name that THIS call's deduction bound (cpp_deduce_args_checked marks the explicit ones), and
%% only where a CLASS is on either side and the two are not the same type -- scalars convert and the later acceptance judges them,
%% and a type the inference could not settle agrees (stdcomplex.cpp)
cpp_deduce_args_checked(Ps, As, TPs, B0, B) :-
    findall(N, member(N-_, B0), Ex),
    cpp_deduce_args(Ps, As, TPs, ['$explicit'-Ex|B0], B1),
    selectchk('$explicit'-_, B1, B).
cpp_deduced_agree(P, Bound, AT, B0) :-
    (   memberchk('$explicit'-Ex, B0), \+ memberchk(P, Ex), cpp_deduced_differ(Bound, AT) -> cpp_trace(deduce_conflict(P, Bound, AT)), fail
    ;   true ).
cpp_deduced_differ(Bound, AT) :-
    catch(( cpp_deduced_form(Bound, B1), cpp_deduced_form(AT, A1), B1 \== A1,
            ( cpp_class_of_type(B1, _) ; cpp_class_of_type(A1, _) ),
            \+ cpp_same_type(B1, A1) ), _, fail), !.
cpp_deduced_form(T, T2) :- T \== unknown, ccl_unref(T, T1), cpp_decayed(T1, T2), \+ cpp_raw_type(T2).
%% ... AND A FUNCTION TYPE DECAYS TO A POINTER TO FUNCTION ([conv.func], as an array does to a pointer to its
%% element): `std::function<int(int)> f = twice' hands `twice' to `function(_Fp)', whose _Fp is `int (*)(int)' --
%% deduced as the FUNCTION type, `__decay_t<_Fp>' kept it, and __func<int(int), int(int)> held its callable in a
%% member of function type, whose address was then called instead of its value.
cpp_decayed(T, T1) :- ccl_resolve_type(T, arr(_, E)), !, T1 = ptr([], E).
cpp_decayed(T, T1) :- ccl_resolve_type(T, fn(R, Ps, V)), !, T1 = ptr([], fn(R, Ps, V)).
cpp_decayed(base(_, S), base([], S)) :- !.
cpp_decayed(ptr(_, E), ptr([], E)) :- !.   % A POINTER'S OWN QUALIFIERS GO TOO ([temp.deduct.call]/2, [dcl.spec.auto]): `const char *const' is `const char *' by value (0.121). A member of a const object is const now (cpp_arg_type), so libc++'s `__formatter::__copy(__result.__exponent, __result.__last, ...)' over a `const __float_result &' deduced `_Iterator' as `const char *const', which is no `incrementable' -- and every std::format failed
cpp_decayed(T, T).
%% the instance's name: the template's, then a key per argument
cpp_instance_name(N0, TPs, B, Name) :- cpp_instance_base(N0, N),
    findall(K, ( member(tparam(_, P, _), TPs), atom(P), memberchk(P-A0, B), cpp_targ_canon(A0, A), cpp_type_key(A, K) ), Ks), atomic_list_concat([N|Ks], '.', Name).
%% A SCALAR TYPEDEF ARGUMENT NAMES THE INSTANCE BY THE TYPE IT NAMES (0.221; [dcl.typedef]/1: a typedef-name is a synonym): libc++
%% 21's pstl declares `optional<__iter_diff_t<_ForwardIterator>>', an instance named `optional.ptrdiff_t', and returns the
%% `optional<_Tp>' that `__transform_reduce' deduces from `_DiffT()', a long -- two instances of one type, and the IR stored the
%% one into the other (`execpol.cpp'). Each spelling keeps its own '$cpp_iname' entry, and both find the one instance. A class's
%% name, an instance's, an enum and a template's parameter stay as they are
cpp_targ_canon(base(Q, [typedef(X)]), R) :- atom(X), \+ cpp_class_l(X, _), \+ catch('$cpp_inst'(X, _), _, fail),
    catch(ccl_resolve_type(base(Q, [typedef(X)]), R0), _, fail), R0 = base(_, S), S \== [typedef(X)], S \== [], forall(member(E, S), atom(E)), !, R = R0.
cpp_targ_canon(A, A).
%% AN UNNAMED TEMPLATE PARAMETER HAS NO NAME TO LOOK UP -- libc++ writes its SFINAE guard as one
%% (`template <class _Up, class... _Args, __enable_if_t<...> = 0>') -- and `memberchk(P-A, B)' with P unbound takes
%% whatever is FIRST in the bindings, so the instance was named one way where it was emitted and another where it
%% was called, and the call named nothing. It contributes no key, in both places alike.
cpp_instance_base(operator(Op), N) :- !, cpp_op_word(Op, W), atom_concat('op.', W, N).   % an OPERATOR member template: `__less<>::operator()' is a template of its own
cpp_instance_base(N, N).
cpp_type_key(pack([]), e) :- !.
cpp_type_key(pack(L), K) :- !, findall(K1, ( member(A, L), cpp_type_key(A, K1) ), Ks), atomic_list_concat(Ks, '_', K).
cpp_type_key(vpack(L), K) :- !, cpp_type_key(pack(L), K).
%% A TYPE'S QUALIFIERS ARE PART OF ITS KEY (0.95; 0.93's item 55): `is_const<const int>' and `is_const<int>' were ONE
%% instance here, the first made answering for both, and libc++ 18's `__tuple_like_ext<const _Tp> : __tuple_like_ext<_Tp>'
%% resolved its base to itself. `const' and `volatile' key -- `const_int', `int_pc' for `int *const' -- and nothing
%% else in a qualifier list does (own, tie, fresh, the markers).
cpp_type_key(base(Q, S0), K) :- !, ( cpp_int_spelling(S0, S) -> true ; S = S0 ), findall(W, ( member(X, S), cpp_spec_key(X, W) ), Ws), cpp_cv_key(Q, CV), append(CV, Ws, Ws1), atomic_list_concat(Ws1, '_', K).
cpp_type_key(ptr(Q, T), K) :- !, cpp_type_key(T, K0), findall(C, ( member(X-C, [const-c, volatile-v]), memberchk(X, Q) ), Cs), atomic_list_concat([K0, '_p'|Cs], K).
cpp_type_key(ref(_, T), K) :- !, cpp_type_key(T, K0), atom_concat(K0, '_r', K).
cpp_type_key(rref(_, T), K) :- !, cpp_type_key(T, K0), atom_concat(K0, '_rr', K).
cpp_type_key(arr(B, T), K) :- !, cpp_type_key(T, K0), ( catch(once(ccl_const_eval(B, V)), _, fail), integer(V) -> atomic_list_concat([K0, '_a', V], K) ; atom_concat(K0, '_a', K) ).   % ITS BOUND IS PART OF IT (0.167): `T &' over an `int[3]' and an `int[5]' named one instance, and the second read the first's sizeof
cpp_type_key(memptr(C, _, T), K) :- !, cpp_type_key(T, TK), atomic_list_concat([C, '_mp_', TK], K).
cpp_type_key(tname(mt(C, N)), K) :- !, atomic_list_concat([C, '.', N], K).   % a member alias template (0.109)
cpp_type_key(tname(X), X) :- !.
cpp_type_key(fn(R, Ps, V0), K) :- !, cpp_fn_q(V0, V, Qs), cpp_type_key(R, RK), findall(PK, ( member(P, Ps), cpp_param_type_of(P, PT), cpp_type_key(PT, PK) ), PKs),   % a FUNCTION TYPE keys by its result and its parameters' types, never their names: `(*pf)(basic_ostream &)' declared and `(*__pf)(basic_ostream &__os)' defined are one
    ( V == true -> Vs = [z] ; Vs = [] ), cpp_ita_cv(Qs, CV), cpp_ita_refq(Qs, RQ), ( memberchk(noexcept, Qs) -> NX = nx ; NX = '' ), atomic_list_concat([CV, NX, fn, RQ], FW), append([FW, RK|PKs], Vs, Ks), atomic_list_concat(Ks, '_', K).   % ... and a member function type's qualifiers (0.181): `Kfn_int_int', `fnO_int_int'; a noexcept one's `nxfn' (0.198)
cpp_type_key(int(big(A)), A) :- !.                                                       % a literal past 2^60 (0.94)
cpp_type_key(uint(big(A)), K) :- !, atom_concat(A, u, K).
cpp_type_key(long(big(A)), K) :- !, atom_concat(A, l, K).
cpp_type_key(ulong(big(A)), K) :- !, atom_concat(A, ul, K).
cpp_type_key(int(N), N) :- !.
cpp_type_key(uint(N), K) :- !, atom_concat(N, u, K).
cpp_type_key(long(N), K) :- !, atom_concat(N, l, K).
cpp_type_key(ulong(N), K) :- !, atom_concat(N, ul, K).
cpp_type_key(wb(N), K) :- !, atom_concat(N, wb, K).
cpp_type_key(uwb(N), K) :- !, atom_concat(N, uwb, K).
cpp_type_key(neg(int(N)), K) :- !, atom_concat(m, N, K).
cpp_type_key(chr(C), K) :- !, atom_concat(c, C, K).
cpp_type_key(wchr(C), K) :- !, atom_concat(wc, C, K).   % a wide character's value argument (0.199), its sign kept
cpp_type_key(u16chr(C), K) :- !, atom_concat(u16c, C, K).
cpp_type_key(u32chr(C), K) :- !, atom_concat(u32c, C, K).
cpp_type_key(cast(base(_, S), X), K) :- cpp_settled_value(X), \+ maplist(atomic, S), !, cpp_type_key(X, K0), cpp_type_key(base([], S), SK), atomic_list_concat([K0, SK], '_', K).   % an enumeration's value (0.203), its tag's key: `0_Color'
cpp_type_key(cast(base(_, S), X), K) :- cpp_settled_value(X), !, cpp_type_key(X, K0), cpp_canon_specs(S, Cs), atomic_list_concat(Cs, '_', SK), atomic_list_concat([K0, SK], '_', K).   % A TYPED VALUE'S CAST (0.199): its value's key and its type, `-5l_long_long'; spelled by its letters the sign went, and `Val<-X>' and `Val<X>' over a long long parameter were one instance
cpp_type_key(bool(true), '1') :- !.      % a bool argument keys as its NUMBER, so `true' and `1' name one instance and not two
cpp_type_key(bool(false), '0') :- !.
cpp_type_key(addr(id(X)), X) :- atom(X), cpp_nttp_fn_name(X), !.   % a function's address keys as its name (0.206; cpp_nttp_as/4)
cpp_type_key(id(X), X) :- !.
cpp_type_key(X, K) :- term_to_atom(X, A), atom_codes(A, Cs), findall(C, ( member(C, Cs), ( C >= 0'a, C =< 0'z ; C >= 0'A, C =< 0'Z ; C >= 0'0, C =< 0'9 ) ), Ds), atom_codes(K, Ds).
%% A FUNCTION TYPE'S THIRD FIELD: the ellipsis mark, and a member function type's qualifiers where the reader kept them,
%% q(V, Qs) (0.181; `const', `volatile', `&', `&&', in that order)
cpp_fn_q(q(V, Qs), V, Qs) :- !.
cpp_fn_q(V, V, []).
cpp_spec_key(typedef(X), X) :- atom(X), !.
cpp_spec_key(typedef(scoped(_, X)), K) :- !, cpp_spec_key(typedef(X), K).                                  % a namespace path keys nothing (the names flatten)
cpp_spec_key(typedef(tmpl(N, Args)), K) :- atom(N), !, findall(AK, ( member(A, Args), cpp_type_key(A, AK) ), AKs), atomic_list_concat([N|AKs], '.', K).   % `initializer_list<std::string>' is `initializer_list.string', where the term spelled letter by letter was `typedefscopedstdtmpl...'
cpp_spec_key(struct(T, _), T) :- !.
cpp_spec_key(union(T, _), T) :- !.              % a nested union names its instance by its tag, as a struct does
cpp_spec_key(class(_, T, _, _), T) :- !.
cpp_spec_key(enum(T, _), T) :- !.
cpp_spec_key(enum_class(T, _), T) :- !.
cpp_spec_key(vec(K, N, E), Key) :- !, cpp_type_key(E, EK), ( K == ext -> C = e ; C = s ), atomic_list_concat([vec, N, C, '_', EK], Key).   % a vector (0.162): `vec4e_int' for an ext_vector_type(4) of int, `vec4s_int' for vector_size(16)
cpp_spec_key(X, X) :- atom(X), !.
cpp_spec_key(X, K) :- cpp_type_key(X, K).
%% the parameters substituted through the item: a type parameter's typedef becomes the
%% argument (its qualifiers kept), a non-type parameter's name the value
cpp_subst(T, _, T) :- \+ compound(T), !.
%% C++26's PACK INDEXING ([temp.variadic]/6): `Ts...[I]' is the I-th type of the pack, `args...[I]' the I-th argument,
%% once the pack is bound; I is a constant expression, folded after its own substitution
cpp_subst(base(Q, [pack_index(P, I)]), B, T) :- memberchk(P-Pk, B), cpp_pack_list(Pk, L), !, cpp_pack_at(P, I, B, L, E), cpp_merge_quals(Q, E, T).
cpp_subst(pack_index(X, I), B, E) :- cpp_pack_names(X, B, [P|_]), !, cpp_expand_pack(X, B, Es), cpp_pack_at(P, I, B, Es, E).
cpp_subst([], _, []) :- !.
cpp_subst([X|Xs], B, Ys) :- !, cpp_subst_elems([X|Xs], B, Ys).
cpp_subst(sizeof_pack(P), B, int(N)) :- memberchk(P-Pk, B), cpp_pack_list(Pk, L), !, length(L, N).                  % a pack not bound yet (a member template's) stays
cpp_subst(fold(Op, dots, E), B, fold_zip(Op, left, Bp, E1)) :- cpp_zip_later(E, B, Bp, E1), !.   % A FOLD OVER AN ENCLOSING PACK AND A MEMBER TEMPLATE'S OR A GENERIC LAMBDA'S OWN WAITS for its instantiation, as an expansion does (pack_zip; 0.201): libc++'s <mdspan> folds `((__res = static_cast<index_type>(__idx) + __extents_.extent(_Pos) * __res), ...)' over the call operator's `__idx...' in a lambda over its own `_Pos...', and expanded over `__idx' alone the lambda's instance met `_Pos' bare
cpp_subst(fold(Op, E, dots), B, fold_zip(Op, right, Bp, E1)) :- cpp_zip_later(E, B, Bp, E1), !.
cpp_subst(fold(Op, A, dots, Z), B, fold_zip(Op, right(Z1), Bp, A1)) :- cpp_pack_names(A, B, [_|_]), cpp_zip_later(A, B, Bp, A1), !, cpp_subst(Z, B, Z1).   % ... and a binary fold, `(E op ... op I)'
cpp_subst(fold(Op, A, dots, Z), B, fold_zip(Op, left(A1), Bp, Z1)) :- cpp_pack_names(Z, B, [_|_]), cpp_zip_later(Z, B, Bp, Z1), !, cpp_subst(A, B, A1).   % ... `(I op ... op E)'
cpp_subst(fold_zip(Op, Dir, Bp, E), B, R) :- !, append(Bp, B, B2),
    (   cpp_later_names(E, B2, []) -> cpp_expand_pack(E, B2, Es), cpp_fold_zip_dir(Dir, Op, Es, B, R)
    ;   cpp_zip_later(E, B2, Bp2, E2) -> cpp_fold_dir_subst(Dir, B, Dir1), R = fold_zip(Op, Dir1, Bp2, E2)
    ;   R = fold_zip(Op, Dir, Bp, E) ).
cpp_subst(fold(Op, dots, E), B, R) :- cpp_pack_names(E, B, [_|_]), !, cpp_expand_pack(E, B, Es), cpp_fold_left(Op, Es, R).      % (... op E)
cpp_subst(fold(Op, E, dots), B, R) :- cpp_pack_names(E, B, [_|_]), !, cpp_expand_pack(E, B, Es), cpp_fold_right(Op, Es, R).     % (E op ...)
cpp_subst(fold(Op, A, dots, Z), B, R) :- cpp_pack_names(fold(A, Z), B, [_|_]), !,                                              % (E op ... op I), (I op ... op E)
    (   cpp_pack_names(A, B, [_|_]) -> cpp_expand_pack(A, B, Es), cpp_subst(Z, B, Z1), append(Es, [Z1], All), cpp_fold_right(Op, All, R)
    ;   cpp_expand_pack(Z, B, Es), cpp_subst(A, B, A1), cpp_fold_left(Op, [A1|Es], R) ).
cpp_subst(function(L, S, R, N, Ps, V, Body), B, function(L, S1, R1, N1, Ps1, V, Body1)) :- !,
    cpp_param_packs(Ps, B, B1), cpp_subst(R, B1, R1), cpp_subst(N, B1, N1), cpp_subst(Ps, B1, Ps1), cpp_subst(Body, B1, Body1), cpp_subst_nxsto(S, B1, S1).   % a noexcept condition in the storage slot too (0.199)
cpp_subst(method(L, Qs, R, M, Ps, V, Body), B, method(L, Qs1, R1, M1, Ps1, V, Body1)) :- !,
    cpp_param_packs(Ps, B, B1), cpp_subst(R, B1, R1), cpp_subst_mname(M, B1, M1), cpp_subst(Ps, B1, Ps1), cpp_subst(Body, B1, Body1),
    cpp_subst_quals(Qs, B1, Qs1).   % THE QUALIFIERS TOO (0.100): a trailing return type, `-> decltype(Op()(std::get<Idx>(bound_)...))', sits among them, and passed through unchanged it kept the class's pack `Idx' unsubstituted (libc++'s __perfect_forward_impl, std::bind_front)
cpp_subst(ctor(L, Qs, Ps, Inits, Body), B, ctor(L, Qs1, Ps1, Inits1, Body1)) :- !,
    cpp_param_packs(Ps, B, B1), cpp_subst(Ps, B1, Ps1), cpp_subst(Inits, B1, Inits1), cpp_subst(Body, B1, Body1),
    cpp_subst_quals(Qs, B1, Qs1).   % A CONSTRUCTOR'S QUALIFIERS TOO (0.112), as a method's since 0.100: `filter_view() requires default_initializable<_View> = default' was checked over the free `_View'
cpp_subst(lambda(Caps, Ps, Ret, Body), B0, lambda(Caps1, Ps1, Ret1, Body1)) :- !, ( memberchk(tparams(TPs), Caps) -> cpp_shadow(TPs, B0, B) ; B = B0 ),   % A GENERIC LAMBDA'S OWN TEMPLATE PARAMETERS SHADOW, its own pack marked to wait (0.201: an expansion or a fold over an enclosing pack and the lambda's own, pack_zip and fold_zip); A LAMBDA'S OWN PARAMETER PACK expands with the enclosing template's bindings, as a function's does: libc++'s __tree writes `[this](_Args&&... __args2) { ... std::forward<_Args>(__args2)... }' inside __emplace_unique, and unexpanded the body named `__args2', a name with no type
    cpp_param_packs(Ps, B, B1), cpp_cap_packs(Caps, B1, B2), cpp_subst_caps(Caps, B1, Caps1), cpp_subst(Ps, B2, Ps1), cpp_subst(Ret, B2, Ret1), cpp_subst(Body, B2, Body1).
cpp_subst(requires_expr(Ps, Rs), B, requires_expr(Ps1, Rs1)) :- !, cpp_param_packs(Ps, B, B1), cpp_subst(Ps, B1, Ps1), cpp_subst(Rs, B1, Rs1).   % A REQUIRES-EXPRESSION'S OWN PARAMETER PACK expands with the bindings as a function's does (0.126): `requires(_Fn &&__fn, _Args &&...__args) { std::invoke(std::forward<_Fn>(__fn), std::forward<_Args>(__args)...); }' is the concept `invocable', its parameters became `__args$1', `__args$2' and its body kept `__args' -- found nowhere, so an enclosing function's variable of that name was found: libc++ 21's `__try_constant_folding(..., basic_format_args __args)' made `std::ranges::find_first_of(__fmt, array{'{', '}'})' fail `indirectly_comparable', and every std::format and std::print with it (stdformat.cpp, stdprint.cpp, reqpack.cpp)
cpp_subst(fn(R, Ps, X), B, fn(R1, Ps1, X1)) :- !, cpp_param_packs(Ps, B, B1), cpp_subst(R, B1, R1), cpp_subst(Ps, B1, Ps1), cpp_subst(X, B1, X1).
cpp_subst(memptr(C0, Q, T0), B, memptr(C, Q, T)) :- !,                                          % the CLASS of a pointer to member is a bare name in the term, so the binding is read by hand: `_Rp _Tp::*'
    ( atom(C0), memberchk(C0-A, B), cpp_class_of_type(A, C1) -> C = C1 ; C = C0 ), cpp_subst(T0, B, T).
cpp_subst(template(L, TPs, M), B, template(L, TPs1, M1)) :- !, cpp_shadow(TPs, B, B1), cpp_subst_tparams(TPs, B1, TPs1), cpp_subst(M, B1, M1).   % a member template's own parameters shadow; its defaults and value types take the class's bindings (`class _Ap = _Alloc')
%% A BASE CLAUSE NAMING A BOUND TYPE PARAMETER takes the class the parameter is bound to (0.93): libc++ 18 builds its
%% containers on `__compressed_pair_elem<_Tp, _Idx, true> : private _Tp' (and its tuple on `__tuple_leaf<_Ip, _Hp, true> :
%% private _Hp'), and a base clause is `base(Access, Name)' with the name a BARE ATOM, which the walk below left as it was
%% -- the instance then refused base_not_registered('_Tp', ...). The overloaded functor is told apart by its first argument:
%% a type is `base(Qualifiers, Specifiers)', a base clause `base(none | public | private | protected, Name)'.
cpp_subst(base(Acc, virtual(P)), B, base(Acc, virtual(X))) :- cpp_base_access(Acc), atom(P), memberchk(P-A, B), cpp_bound_base(A, X), !.
cpp_subst(base(Acc, P), B, base(Acc, X)) :- cpp_base_access(Acc), atom(P), memberchk(P-A, B), cpp_bound_base(A, X), !.
%% ... AND A CONSTRUCTOR INITIALIZER NAMING THAT PARAMETER names the class it is bound to (0.100): libc++'s
%% `template <class _Tp, class _Base = __cxx_atomic_base_impl<_Tp>> struct __cxx_atomic_impl : public _Base' writes
%% `__cxx_atomic_impl(_Tp __value) : _Base(__value) {}', and left as the atom `_Base' the initializer matched neither
%% the base nor a member and was DROPPED -- every std::atomic was constructed empty, its value garbage
cpp_subst(init(P, As), B, init(X, As1)) :- atom(P), memberchk(P-A, B), cpp_bound_base(A, X), !, cpp_subst(As, B, As1).
cpp_subst(base(Q, [typedef(P)]), B, base(Q, [typedef(X)])) :- atom(P), memberchk(P-tname(X), B), !.      % a template template parameter passed on by name
cpp_subst(base(Q, [typedef(tmpl(P, Args0))]), B, base(Q, [typedef(scoped([C], tmpl(N, Args)))])) :- atom(P), memberchk(P-tname(mt(C, N)), B), !, cpp_subst(Args0, B, Args).   % bound to a MEMBER alias template, `_Tester::template _Apply' (0.109): `C::template N<Args>'
cpp_subst(tmpl(P, Args0), B, scoped([C], tmpl(N, Args))) :- atom(P), memberchk(P-tname(mt(C, N)), B), !, cpp_subst(Args0, B, Args).
cpp_subst(tmpl(P, Args0), B, tmpl(X, Args)) :- atom(P), memberchk(P-tname(X), B), !, cpp_subst(Args0, B, Args1), cpp_ttp_fill(P, B, Args1, Args).   % L<A, B>: the template it is bound to
cpp_subst(base(Q, [typedef(P)]), B, T) :- memberchk(P-A, B), !, ( A == '$later' -> T = base(Q, [typedef(P)]) ; cpp_pack_list(A, _) -> cpp_refuse(0, pack_unexpanded(P)) ; A = pack(_) -> T = A ; cpp_merge_quals(Q, A, T) ).   % an expansion handed through stays one; a member template's own pack stays its name
cpp_subst(sizeof(id(P)), B, sizeof_type(A)) :- memberchk(P-A, B), cpp_is_type(A), !.          % sizeof(T), read as an expression while T was a name
%% A BOUND TYPE PARAMETER CALLED: the ARGUMENTS ARE SUBSTITUTED FIRST and the arity read off the result, since a
%% PACK EXPANSION is one element until it expands -- `_TupleDst(std::get<_Indices>(std::forward<_TupleSrc>(__src))
%% ...)', which is how libc++'s tuple_cat builds its answer, was taken for the one-argument functional cast and
%% its pattern substituted whole, refusing pack_unexpanded. One predicate for the three shapes (the owner's rule),
%% where three clauses each matched an arity of the RAW list.
cpp_subst(braced_temp(call(id(P), Args0)), B, compound_lit(T, init(Items))) :- memberchk(P-A, B), cpp_is_type(A), ccl_resolve_type(A, T), T = base(_, [vec(_, _, _)]), !,   % `_VecT{__iter[_Indices]...}' over a vector (0.162): its lanes
    cpp_subst_elems(Args0, B, Args), findall(item([], V), member(V, Args), Items).
cpp_subst(call(id(P), Args0), B, E) :- memberchk(P-A, B), cpp_is_type(A), cpp_subst_elems(Args0, B, Args), cpp_type_called(A, Args, E), !.
cpp_subst(id(P), B, V) :- memberchk(P-V0, B), !, ( V0 == '$later' -> V = id(P) ; cpp_pack_list(V0, _) -> cpp_refuse(0, pack_unexpanded(P)) ; V = V0 ).
cpp_subst(scoped(Path, N0), B, scoped(Path1, N)) :- !, cpp_subst_path(Path, B, Path1), ( atom(N0) -> N = N0 ; cpp_subst(N0, B, N) ).   % C::value_type with C a parameter: the class it is bound to; std::vector<T> under T
cpp_subst(str(S), _, str(S)) :- !.
cpp_subst(u8str(S), _, u8str(S)) :- !.
cpp_subst(T0, B, T) :- T0 =.. [F|As], cpp_subst_list(As, B, Bs), T =.. [F|Bs].
cpp_subst_nxsto(nxif(E, S), B, nxif(E1, S)) :- !, cpp_subst(E, B, E1).
cpp_subst_nxsto(S, _, S).
%% a free function's storage and its noexcept condition apart (0.199; the reader's `nxif(E, Sto)'), `none' for no condition
cpp_nx_sto(nxif(E, S), S, E) :- !.
cpp_nx_sto(S, S, none).
%% A TEMPLATE TEMPLATE PARAMETER'S OWN DEFAULTS ([temp.param]/14; 0.185): in the parameter's scope `TT<U>' takes
%% the arguments its own list defaults (the reader's ttp(N, List), bound beside the parameter as '$ttdef'(N) by
%% cpp_ttp_bind/4, LAST, so that no reader of the first binding meets it), read under the arguments given and the
%% template's own bindings, an unnamed one named by its place; the bound template's own defaults take what the list
%% leaves. They were skipped with the list, and `TT<U>' took the bound template's own, a silent difference where the
%% two differ (ttpown.cpp).
cpp_ttp_bind(P, I, B0, B) :- ( memberchk(P-tname(_), B0), \+ memberchk('$ttdef'(P)-_, B0) -> append(B0, ['$ttdef'(P)-ttdef(I)], B) ; B = B0 ).
cpp_ttp_binds([], B, B).
cpp_ttp_binds([ttp(P, I)|TPs], B0, B) :- !, cpp_ttp_bind(P, I, B0, B1), cpp_ttp_binds(TPs, B1, B).
cpp_ttp_binds([_|TPs], B0, B) :- cpp_ttp_binds(TPs, B0, B).
cpp_ttp_fill(P, B, Args0, Args) :-
    (   memberchk('$ttdef'(P)-ttdef(I0), B), cpp_name_anon(I0, I), cpp_ttp_short(I, Args0),
        catch(cpp_bind_targs_(I, Args0, B, IB), error(not_lowered(_), _), fail), cpp_full_args(I, IB, Args1) -> Args = Args1
    ;   Args = Args0 ).
cpp_ttp_short(I, Args) :- \+ ( member(tparam(K, _, _), I), cpp_pack_kind(K) ), findall(x, member(tparam(_, _, _), I), Ps), length(Ps, NP), length(Args, NA), NA < NP.
cpp_pack_at(P, I, B, L, E) :-
    cpp_subst(I, B, I1), ( ccl_const_eval(I1, K) -> true ; cpp_refuse(0, pack_index_not_constant(P)) ),
    length(L, N), ( K >= 0, K < N -> true ; cpp_refuse(0, pack_index_out_of_range(P, K)) ), nth0(K, L, E).
%% A CONVERSION FUNCTION'S NAME holds its type (0.117): `operator T()' of S<long> is `operator long()', and was left as `operator T()' -- no
%% target matched it exactly, so `long t = s;' took the first arithmetic conversion function declared
cpp_subst_mname(operator(conv(T)), B, operator(conv(T1))) :- !, cpp_subst(T, B, T1).
cpp_subst_mname(M, _, M).
%% AN INIT-CAPTURE PACK (C++20, [expr.prim.lambda.capture]/17, P0780; 0.198): `[...xs = std::move(ts)]' is one init-capture an element of the
%% pack its initializer expands over, `xs$1' ... `xs$k' (cpp_subst_caps), and the body names xs as the pack of them, a parameter pack's way
cpp_cap_packs([], B, B).
cpp_cap_packs([C|Cs], B0, B) :- ( C = cap(init_pack, N, E) ; C = cap(init_ref_pack, N, E) ), cpp_pack_names(E, B0, [_|_]), !,
    cpp_expand_pack(E, B0, Es), length(Es, K), findall(id(Nk), ( between(1, K, I), atomic_list_concat([N, '$', I], Nk) ), Ids),
    cpp_cap_packs(Cs, [N-vpack(Ids)|B0], B).
cpp_cap_packs([_|Cs], B0, B) :- cpp_cap_packs(Cs, B0, B).
cpp_subst_caps([], _, []).
cpp_subst_caps([cap(pack, N)|Cs], B, Out) :- ( memberchk(N-vpack(Xs), B) ; memberchk(N-pack(Xs), B) ), !,   % `[xs...]' over a bound pack: one capture by value per element (0.99)
    findall(cap(val, X), member(id(X), Xs), Cs1), cpp_subst_caps(Cs, B, Rest), append(Cs1, Rest, Out).
cpp_subst_caps([C|Cs], B, Out) :- ( C = cap(init_pack, N, E), W = init ; C = cap(init_ref_pack, N, E), W = init_ref ), cpp_pack_names(E, B, [_|_]), !,   % an init-capture pack (0.198, above): one init-capture an element
    cpp_expand_pack(E, B, Es), findall(cap(W, Nk, Ek), ( nth1(I, Es, Ek), atomic_list_concat([N, '$', I], Nk) ), Cs1), cpp_subst_caps(Cs, B, Rest), append(Cs1, Rest, Out).
cpp_subst_caps([C|Cs], B, [C1|Cs1]) :- cpp_subst(C, B, C1), cpp_subst_caps(Cs, B, Cs1).
cpp_subst_quals([], _, []).
cpp_subst_quals([trailing(T)|Qs], B, [trailing(T1)|Qs1]) :- !, cpp_subst(T, B, T1), cpp_subst_quals(Qs, B, Qs1).
cpp_subst_quals([explicit_this(N, T)|Qs], B, [explicit_this(N, T1)|Qs1]) :- !, cpp_subst(T, B, T1), cpp_subst_quals(Qs, B, Qs1).   % the object parameter's type takes the deduced object type (0.117)
cpp_subst_quals([noexcept(E)|Qs], B, [noexcept(E1)|Qs1]) :- !, cpp_subst(E, B, E1), cpp_subst_quals(Qs, B, Qs1).
cpp_subst_quals([requires(E)|Qs], B, [requires(E1)|Qs1]) :- !, cpp_subst(E, B, E1), cpp_subst_quals(Qs, B, Qs1).
cpp_subst_quals([explicit(E)|Qs], B, [explicit(E1)|Qs1]) :- !, cpp_subst(E, B, E1), cpp_subst_quals(Qs, B, Qs1).   % ... and its explicit-specifier (0.197): `explicit(!is_convertible_v<U, T>)' of a class template's constructor template asked over the free T   % a member's TRAILING requires-clause takes the class's arguments too (0.110): ref_view's `size() const requires sized_range<_Range>' was checked over the free `_Range'
cpp_subst_quals([Q|Qs], B, [Q|Qs1]) :- cpp_subst_quals(Qs, B, Qs1).
cpp_subst_tparams([], _, []).
cpp_subst_tparams([tparam(K, P, D)|TPs], B, [tparam(K1, P, D1)|Qs]) :- !, ( cpp_is_type(K) -> cpp_subst(K, B, K1) ; K1 = K ), ( D == none -> D1 = none ; cpp_subst(D, B, D1) ), cpp_subst_tparams(TPs, B, Qs).
cpp_subst_tparams([requires(R)|TPs], B, [requires(R1)|Qs]) :- !, cpp_subst(R, B, R1), cpp_subst_tparams(TPs, B, Qs).
cpp_subst_tparams([ttp(N, I)|TPs], B, [ttp(N, I1)|Qs]) :- !, cpp_shadow(I, B, B1), cpp_subst_tparams(I, B1, I1), cpp_subst_tparams(TPs, B, Qs).   % a template template parameter's own list (0.185): its defaults take the class's bindings too
cpp_subst_tparams([X|TPs], B, [X|Qs]) :- cpp_subst_tparams(TPs, B, Qs).
cpp_base_access(virtual(A)) :- !, cpp_base_access(A).   % ... a VIRTUAL base's (0.235): the reader writes `base(virtual(Access), Name)', and its name was neither renamed in its namespace nor substituted for a template parameter -- `b::D : virtual B' took `a::B', the first class of that name
cpp_base_access(A) :- memberchk(A, [none, public, private, protected]).
cpp_bound_base(tname(X), X) :- !.
cpp_bound_base(base(_, [typedef(X)]), X) :- !.
cpp_bound_base(base(_, [S]), X) :- cpp_tag_name(S, X), !.
cpp_type_called(A, [X], ccast(functional, A, X)) :- \+ ( X = pack(_), A = base(_, [typedef(N)]), atom(N) ), !.   % T(x); a pack expansion over a CLASS is no one argument until it expands (0.162): `V{it[Is]...}' in a lambda's body, its pack `Is' the lambda's own, was the cast `ccast(functional, V, pack(...))' and refused pack_unexpanded
cpp_type_called(T, [], ccast(functional, T, Z)) :- \+ T = base(_, [typedef(_)]), !, cpp_zero_of(T, Z).            % T() with T a BUILTIN or a pointer: value-initialization, the type's zero -- `*__s = _CharT()' ends the char extractor's string
cpp_type_called(base(_, [typedef(N)]), Args, call(id(N), Args)) :- atom(N).   % T() and T(a, b, ...): the bound class's name called over the arguments, its temporary -- `using _Pair = pair<...>; return _Pair(__end, __end->__left_);' in libc++'s __tree, a block alias substituted into the statements after it (0.60), and how a constructor template writes its allocator's default argument, `const _Allocator & __a = _Allocator()'
cpp_subst_path([], _, []).
cpp_subst_path([P|Ps], B, [P1|Qs]) :-
    (   atom(P), memberchk(P-A, B), ( A = base(_, [typedef(X)]) ; A = base(_, [S0]), cpp_tag_name(S0, X) ) -> ( cpp_typedef_scalar(A) -> P1 = nonclass(A) ; P1 = X )   % (a CLASS bound as its tag, a plain struct's form, names its class too -- 0.121: `using alt_type = remove_cvref_t<decltype(__alt)>; ... typename alt_type::__value_type')   % A TYPEDEF NAMING A SCALAR (`size_t', `ptrdiff_t', `uint32_t') has no member types either (0.117): it kept its name in the path, which flattened as a namespace, and libc++'s `__has_iterator_typedefs<size_t>' found `iterator_category' in some other class -- `std::list::assign(3, 4)', whose `insert(__e, __n, __x)' asks `iterator_traits<size_t>', recursed through 400,000 flattened names and never finished
    ;   atom(P), memberchk(P-tname(X), B) -> P1 = X
    ;   atom(P), memberchk(P-A, B), cpp_scalar_type(A) -> P1 = nonclass(A)   % `typename _Tp::pointer' with _Tp a POINTER, a scalar, a reference, a function: NO MEMBER TYPES AT ALL. The segment carries the type and RESOLVING the name refuses (cpp_type, cpp_expr) -- the SFINAE libc++'s detection idiom needs (`__pointer_member' on a deleter that is a function pointer); the parameter's name stayed in the path before, and flattened as a namespace into a free name
    ;   cpp_subst(P, B, P1) ),
    cpp_subst_path(Ps, B, Qs).
cpp_typedef_scalar(A) :- catch(ccl_resolve_type(A, RA), error(not_lowered(_), _), fail), RA \== A, cpp_scalar_type(RA),
    \+ ( RA = base(_, [X|_]), compound(X), ( X = enum(_, _) ; X = enum_class(_, _) ) ), !.   % an ENUMERATION's name still finds its enumerators (`E::Green' with E bound to Color, [dcl.enum]/11): only a scalar that is no enumeration has nothing to find
cpp_scalar_type(ptr(_, _)).  cpp_scalar_type(ref(_, _)).  cpp_scalar_type(rref(_, _)).  cpp_scalar_type(arr(_, _)).  cpp_scalar_type(fn(_, _, _)).
cpp_scalar_type(base(_, [K|_])) :- atom(K), ccl_basic_type(K).
cpp_scalar_type(base(_, [nullptr_t])).   % `std::nullptr_t' (0.206)
cpp_scalar_type(base(_, [X|_])) :- compound(X), ( X = enum(_, _) ; X = enum_class(_, _) ), !.   % AN ENUMERATION IS A SCALAR TYPE ([basic.types.general]/9; 0.112): `__alignment __alignment_ : 3 {__alignment::__default}' is its one item, and `typename E::x' finds no member types
cpp_subst_list([], _, []).
cpp_subst_list([X|Xs], B, [Y|Ys]) :- cpp_subst(X, B, Y), cpp_subst_list(Xs, B, Ys).
%% the elements of a list: a pack expansion `X...' becomes one X per element of the packs it names,
%% wherever the reader left pack/1 -- an argument, a template argument, a base, a parameter, an item, an initializer
cpp_subst_elems([], _, []).
%% AN EXPANSION OVER A CLASS'S PACK AND A MEMBER TEMPLATE'S OWN WAITS FOR THE MEMBER'S INSTANTIATION ([temp.variadic]:
%% every pack in one pattern expands together, to one length): libc++'s __tuple_impl<__index_sequence<_Indx...>, _Tp...>
%% constructs `__tuple_leaf<_Indx, _Tp>(std::forward<_Args>(__args))...' with `_Args' the constructor's own. Expanded
%% over the class's packs alone the `...' was gone, and the constructor's instantiation met `_Args' bare and refused
%% pack_unexpanded. The class's packs travel with the pattern, `pack_zip(Bound, X)', the rest substituted now.
cpp_subst_elems([pack(X)|Xs], B, [pack_zip(Bp, X1)|Ys]) :- cpp_pack_names(X, B, [_|_]), cpp_later_names(X, B, [_|_]), !,
    findall(P-Pk, ( member(P-Pk, B), cpp_pack_list(Pk, _), cpp_names_in(X, P) ), Bp),
    findall(Y, ( member(Y, B), \+ memberchk(Y, Bp) ), Bn), cpp_subst(X, Bn, X1), cpp_subst_elems(Xs, B, Ys).
cpp_subst_elems([pack_zip(Bp, X)|Xs], B, Ys) :- !, append(Bp, B, B2),
    (   cpp_later_names(X, B2, []) -> cpp_expand_pack(X, B2, Es), cpp_subst_elems(Xs, B, Ys1), append(Es, Ys1, Ys)
    ;   cpp_subst_elems([pack(X)], B2, [Z]), cpp_subst_elems(Xs, B, Ys1), Ys = [Z|Ys1] ).   % still waiting: deferred again, with more of its packs bound
cpp_subst_elems([pack(X)|Xs], B, Ys) :- cpp_pack_names(X, B, [_|_]), !, cpp_expand_pack(X, B, Es), cpp_subst_elems(Xs, B, Ys1), append(Es, Ys1, Ys).
cpp_subst_elems([base(A, pack(Q0))|Xs], B, Ys) :- atom(Q0), memberchk(Q0-Pk, B), cpp_pack_list(Pk, L), !,   % A BASE CLAUSE THAT IS A BARE PACK, `struct overloaded : Ts... {' (0.121): the reader writes the pack's name as an atom, the pattern below is a template-id or a path, and the atom named no pack to it -- every base of the expansion is the class its element is bound to (cpp_bound_base), as a single parameter's base is
    findall(base(A, X), ( member(E, L), cpp_bound_base(E, X) ), Bs), cpp_subst_elems(Xs, B, Ys1), append(Bs, Ys1, Ys).
cpp_subst_elems([base(A, pack(Q))|Xs], B, Ys) :- cpp_pack_names(Q, B, [_|_]), !, cpp_expand_pack(Q, B, Qs), findall(base(A, Q1), member(Q1, Qs), Bs), cpp_subst_elems(Xs, B, Ys1), append(Bs, Ys1, Ys).
cpp_subst_elems([friend_class(pack(Q0))|Xs], B, Ys) :- atom(Q0), memberchk(Q0-Pk, B), cpp_pack_list(Pk, L), !,   % a variadic friend (C++26, 0.198): one friend class per element of the pack, the class each is bound to
    findall(friend_class(X), ( member(E, L), cpp_bound_base(E, X) ), Fs), cpp_subst_elems(Xs, B, Ys1), append(Fs, Ys1, Ys).
cpp_subst_elems([using(L, pack(Q))|Xs], B, Ys) :- cpp_pack_names(Q, B, [_|_]), !, cpp_expand_pack(Q, B, Qs),   % `using Bs::operator()...;' (0.121): one using-declaration per element of the pack it names, each naming its base
    findall(using(L, name(Q1)), member(Q1, Qs), Us), cpp_subst_elems(Xs, B, Ys1), append(Us, Ys1, Ys).
cpp_subst_elems([item(D, pack(V))|Xs], B, Ys) :- cpp_pack_names(V, B, [_|_]), !, cpp_expand_pack(V, B, Vs), findall(item(D, V1), member(V1, Vs), Is), cpp_subst_elems(Xs, B, Ys1), append(Is, Ys1, Ys).
cpp_subst_elems([type(pack(T))|Xs], B, Ys) :- cpp_pack_names(T, B, [_|_]), !, cpp_expand_pack(T, B, Ts), findall(type(T1), member(T1, Ts), Ss), cpp_subst_elems(Xs, B, Ys1), append(Ss, Ys1, Ys).   % a builtin trait's argument: `__is_constructible(_Tp, _Args...)', which is how libc++ writes is_constructible
cpp_subst_elems([param(pack(T), N)|Xs], B, Ys) :- cpp_pack_names(T, B, [_|_]), !, cpp_expand_pack(T, B, Ts), cpp_number_params(Ts, N, 1, Ps), cpp_subst_elems(Xs, B, Ys1), append(Ps, Ys1, Ys).
cpp_subst_elems([X|Xs], B, [Y|Ys]) :- cpp_subst(X, B, Y), cpp_subst_elems(Xs, B, Ys).
cpp_later_names(X, B, Ns) :- findall(P, ( member(P-'$later', B), cpp_names_in(X, P) ), Ns).
%% a pattern over a bound pack and a pack that waits ('$later'): the bound packs' bindings kept for its expansion, the
%% rest substituted now (the expansion's pack_zip and the fold's fold_zip, 0.201)
cpp_zip_later(X, B, Bp, X1) :- cpp_pack_names(X, B, [_|_]), cpp_later_names(X, B, [_|_]),
    findall(P-Pk, ( member(P-Pk, B), cpp_pack_list(Pk, _), cpp_names_in(X, P) ), Bp),
    findall(Y, ( member(Y, B), \+ memberchk(Y, Bp) ), Bn), cpp_subst(X, Bn, X1).
%% a deferred fold expanded: a unary one left or right, a binary one with its initial operand, substituted with the bindings
cpp_fold_zip_dir(left, Op, Es, _, R) :- !, cpp_fold_left(Op, Es, R).
cpp_fold_zip_dir(right, Op, Es, _, R) :- !, cpp_fold_right(Op, Es, R).
cpp_fold_zip_dir(right(I), Op, Es, B, R) :- !, cpp_subst(I, B, I1), append(Es, [I1], All), cpp_fold_right(Op, All, R).
cpp_fold_zip_dir(left(I), Op, Es, B, R) :- cpp_subst(I, B, I1), cpp_fold_left(Op, [I1|Es], R).
cpp_fold_dir_subst(right(I), B, right(I1)) :- !, cpp_subst(I, B, I1).
cpp_fold_dir_subst(left(I), B, left(I1)) :- !, cpp_subst(I, B, I1).
cpp_fold_dir_subst(D, _, D).
cpp_number_params([], _, _, []).
cpp_number_params([T|Ts], N, K, [param(T, Nk)|Ps]) :- atomic_list_concat([N, '$', K], Nk), K1 is K + 1, cpp_number_params(Ts, N, K1, Ps).
%% a parameter pack `Ts... args' under the bindings: the names args$1 .. args$k, a pack of values, for the body
cpp_param_packs([], B, B).
cpp_param_packs([param(pack(T), N)|Ps], B0, B) :- atom(N), cpp_pack_names(T, B0, [P|_]), !, memberchk(P-Pk, B0), cpp_pack_list(Pk, L), length(L, K),
    findall(id(Nk), ( between(1, K, I), atomic_list_concat([N, '$', I], Nk) ), Ids), cpp_param_packs(Ps, [N-vpack(Ids)|B0], B).
cpp_param_packs([_|Ps], B0, B) :- cpp_param_packs(Ps, B0, B).
cpp_pack_list(pack(L), L) :- is_list(L).   % a BINDING holds a list; `pack(id(_I1))', an EXPANSION of an outer pack handed through an alias's own, is an element, not a pack (cpp_alias_binds)
cpp_pack_list(vpack(L), L) :- is_list(L).
%% the packs a term names, among the bindings
cpp_pack_names(X, B, Ns) :- findall(P, ( member(P-Pk, B), cpp_pack_list(Pk, _), cpp_names_outside(X, P) ), Ns0), cpp_dedupe(Ns0, Ns).
%% THE PACKS AN EXPANSION ZIPS ARE THE ONES NAMED OUTSIDE ITS NESTED EXPANSIONS ([temp.variadic]/5: a pack expansion's
%% pattern expands over the packs it names UNEXPANDED; a `Ts...' inside it is an expansion of its own, expanded whole
%% in every element, and `sizeof...(Ts)' names no expansion at all). libc++'s `__make_tuple_types_flat' writes
%% `__tuple_types<__apply_cv_t<_Tp, __type_pack_element<_Idx, _Types...>>...>', and zipped over BOTH packs it refused
%% `pack_lengths_differ' where `_Idx' was empty and `_Types' was not -- `__make_tuple_types<tuple, 0>', which every tuple
%% constructor over an empty pack asks for; with the lengths equal the answer was right by coincidence (0.93).
cpp_names_outside(id(P), P) :- !.
cpp_names_outside(typedef(P), P) :- !.
cpp_names_outside(scoped(Path, Last), P) :- ( member(S, Path), S == P ; cpp_names_outside(Last, P) ), !.   % ... and inside the last segment's template arguments (0.99): `std::get<_Idx>(__bound_args_)...' names the class's pack _Idx, and unseen the expansion stayed folded (libc++'s __perfect_forward, behind bind_front and not_fn)
cpp_names_outside(pack(_), _) :- !, fail.
cpp_names_outside(sizeof_pack(_), _) :- !, fail.
cpp_names_outside(T, P) :- compound(T), T =.. [_|As], member(A, As), cpp_names_outside(A, P), !.
cpp_names_in(id(P), P) :- !.
cpp_names_in(typedef(P), P) :- !.
cpp_names_in(scoped(Path, Last), P) :- ( member(S, Path), S == P ; cpp_names_in(Last, P) ), !.   % a parameter as a PATH SEGMENT, or inside the last segment's template arguments (0.99): `__enable_if_t<_Pred::value>...' names the pack _Pred, and unseen the expansion stayed folded -- libc++'s _And held for every predicate
cpp_names_in(sizeof_pack(P), P) :- !.
cpp_names_in(T, P) :- compound(T), T =.. [_|As], member(A, As), cpp_names_in(A, P), !.
cpp_dedupe([], []).
cpp_dedupe([X|Xs], [X|Ys]) :- \+ memberchk(X, Xs), !, cpp_dedupe(Xs, Ys).
cpp_dedupe([_|Xs], Ys) :- cpp_dedupe(Xs, Ys).
cpp_expand_pack(X0, B, Xs) :-
    cpp_pack_names(X0, B, Ns), ( Ns == [] -> cpp_refuse(0, pack_expansion_without_pack) ; true ),
    Ns = [N1|_], memberchk(N1-Pk1, B), cpp_pack_list(Pk1, L1), length(L1, K),
    ( forall(member(N, Ns), ( memberchk(N-Pk, B), cpp_pack_list(Pk, L), length(L, K) )) -> true ; cpp_refuse(0, pack_lengths_differ(Ns)) ),   % ill-formed C++, and a silent failure here cost an afternoon (pair's piecewise delegation with `_I1' deduced empty beside `_Args1')
    cpp_whole_packs(X0, Ns, B, X, Bw),
    findall(Xk, ( between(1, K, I), cpp_pack_select(B, Ns, I, Bk0), append(Bw, Bk0, Bk), cpp_subst(X, Bk, Xk) ), Xs).
%% A NESTED EXPANSION OF THE PACK BEING EXPANDED SEES THE WHOLE PACK ([temp.variadic]/5: a pack named inside a nested
%% expansion belongs to that expansion, never to the outer one) (0.133): each element's substitution binds the pack to
%% ONE element, so in the pattern of libc++ 21's __concat_indirectly_readable, `(__concat_indirectly_readable_impl<
%% __concat_reference_t<_Rs...>, __concat_rvalue_reference_t<_Rs...>, iterator_t<_Rs>> && ...)', the nested `_Rs...'
%% saw one range, and `views::join_with' refused its class's constraints. The pack's name inside every nested expansion
%% -- `pack(Y)', `sizeof...(P)', a nested fold -- is renamed `P$all', bound to the whole pack beside the element.
cpp_whole_packs(X0, Ns, B, X, Bw) :-
    findall(N-Nw, ( member(N, Ns), atom(N), atom_concat(N, '$all', Nw) ), M),
    cpp_rename_nested(X0, M, X, no, Ch),
    (   Ch == yes -> findall(Nw-Pk, ( member(N-Nw, M), memberchk(N-Pk, B) ), Bw)
    ;   Bw = [] ).
cpp_rename_nested(X, _, X, C, C) :- \+ compound(X), !.
cpp_rename_nested(pack_zip(Bp, Y), _, pack_zip(Bp, Y), C, C) :- !.          % a deferred expansion keeps its own bindings
cpp_rename_nested(fold_zip(Op, D, Bp, Y), _, fold_zip(Op, D, Bp, Y), C, C) :- !.   % ... and a deferred fold (0.201)
cpp_rename_nested(T, M, T1, _, yes) :- cpp_nested_expansion(T), cpp_mentions_any(T, M), !, cpp_rename_atoms(T, M, T1).
cpp_rename_nested(T, M, T1, C0, C) :- T =.. [F|As], cpp_rename_nested_list(As, M, As1, C0, C), T1 =.. [F|As1].
cpp_rename_nested_list([], _, [], C, C).
cpp_rename_nested_list([A|As], M, [A1|As1], C0, C) :- cpp_rename_nested(A, M, A1, C0, C1), cpp_rename_nested_list(As, M, As1, C1, C).
cpp_nested_expansion(pack(_)).
cpp_nested_expansion(sizeof_pack(_)).
cpp_nested_expansion(fold(_, _, _)).
cpp_nested_expansion(fold(_, _, _, _)).
cpp_mentions_any(T, M) :- member(N-_, M), cpp_names_in(T, N), !.
cpp_rename_atoms(A, M, A1) :- atom(A), !, ( memberchk(A-A1, M) -> true ; A1 = A ).
cpp_rename_atoms(T, M, T1) :- compound(T), !, T =.. [F|As], cpp_rename_atoms_list(As, M, As1), T1 =.. [F|As1].
cpp_rename_atoms(T, _, T).
cpp_rename_atoms_list([], _, []).
cpp_rename_atoms_list([A|As], M, [A1|As1]) :- cpp_rename_atoms(A, M, A1), cpp_rename_atoms_list(As, M, As1).
cpp_pack_select([], _, _, []).
cpp_pack_select([P-Pk|B], Ns, I, [P-E|B1]) :- memberchk(P, Ns), cpp_pack_list(Pk, L), !, nth1(I, L, E), cpp_pack_select(B, Ns, I, B1).
cpp_pack_select([X|B], Ns, I, [X|B1]) :- cpp_pack_select(B, Ns, I, B1).
cpp_shadow([], B, B).
cpp_shadow([tparam(K, P, _)|TPs], B0, B) :- !, findall(X, ( member(X, B0), X \= P-_ ), B1),
    ( cpp_pack_kind(K), atom(P) -> B2 = [P-'$later'|B1] ; B2 = B1 ), cpp_shadow(TPs, B2, B).   % its own PACK is marked: an expansion naming it waits (pack_zip, cpp_subst_elems)
cpp_shadow([_|TPs], B0, B) :- cpp_shadow(TPs, B0, B).
%% a fold: right, E1 op (E2 op (... op En)); left, ((E1 op E2) op ...) op En; empty: what the standard gives && || and ,
cpp_fold_right(Op, [], R) :- !, cpp_fold_empty(Op, R).
cpp_fold_right(_, [E], E) :- !.
cpp_fold_right(Op, [E|Es], R) :- cpp_fold_right(Op, Es, R1), cpp_fold_op(Op, E, R1, R).
cpp_fold_left(Op, [], R) :- !, cpp_fold_empty(Op, R).
cpp_fold_left(Op, [E|Es], R) :- cpp_fold_left_(Op, Es, E, R).
cpp_fold_left_(_, [], R, R).
cpp_fold_left_(Op, [E|Es], Acc, R) :- cpp_fold_op(Op, Acc, E, Acc1), cpp_fold_left_(Op, Es, Acc1, R).
cpp_fold_op(',', A, B, comma(A, B)) :- !.
cpp_fold_op(Op, A, B, assign(Op, A, B)) :- memberchk(Op, ['=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=']), !.
cpp_fold_op(Op, A, B, bin(Op, A, B)).
cpp_fold_empty('&&', bool(true)) :- !.
cpp_fold_empty('||', bool(false)) :- !.
cpp_fold_empty(',', int(0)) :- !.
cpp_fold_empty(Op, _) :- cpp_refuse(0, empty_fold(Op)).
%% ---- member templates, instantiated at a call --------------------------------------------------
cpp_member_template_call(C, M, Explicit, As, Name) :- cpp_where(member(C, M), cpp_member_template_call_(C, M, Explicit, As, Name)).
cpp_member_template_call_(C, M, Explicit, As, Name) :-
    findall(TPs-Mem, '$cpp_mt'(C, M, TPs, Mem), Cands0), Cands0 \== [],
    findall(X, ( member(X, Cands0), \+ cpp_variadic_member(X) ), Plain),      % an ELLIPSIS is C++'s worst match: `test(...)' only where nothing else fits
    findall(X, ( member(X, Cands0), cpp_variadic_member(X) ), Var), append(Plain, Var, Cands0b),
    cpp_prefer_const(Cands0b, Cands),   % THE OBJECT'S CONSTNESS ORDERS THE MEMBER TEMPLATES too (0.79's rule for the plain overloads): libc++ writes `template <class _Key> iterator find(const _Key &)' beside its const twin, and `find' inside `unordered_map::find(...) const' took the non-const one first
    cpp_try_member(Cands, C, Explicit, As, Name).
%% THE INSTANCE AN EXPLICIT MEMBER TEMPLATE-ID NAMES, with no call to deduce from: the first candidate whose explicit arguments bind, whose
%% defaults fill the rest, whose parameters are all bound and whose constraints hold (cpp_explicit_candidate's rule, for a member template).
cpp_member_template_id(Path, M, C) :- atom(M), cpp_scope_class(Path, C), '$cpp_mt'(C, M, _, _), cpp_static_member_template(C, M), !.
cpp_member_explicit_instance(C, M, Explicit, Name) :- cpp_where(member(C, M), cpp_member_explicit_instance_(C, M, Explicit, Name)).
cpp_member_explicit_instance_(C, M, Explicit, Name) :-
    findall(TPs-Mem, '$cpp_mt'(C, M, TPs, Mem), Cands), Cands \== [],
    (   cpp_member_explicit_candidate(Cands, C, M, Explicit, TPs, method(L, Qs, Ret, M, Ps, V, Body), B) -> true
    ;   cpp_refuse(0, no_matching_template(M)) ),
    cpp_instance_name(M, TPs, B, MName), cpp_subst(method(L, Qs, Ret, M, Ps, V, Body), B, method(_, Qs1, Ret1, _, Ps1, _, Body1)),
    cpp_mangle_q(C, MName, Qs1, Ps1, Name),
    (   cpp_instance_done(Name) -> true
    ;   cpp_making(Name) -> true
    ;   cpp_with_fsig(inst(MName, fsig(member, C, M, Ret, Ps, V, Qs1, ta(TPs, B))), cpp_make_member(Name, C, L, Qs1, Ret1, MName, Ps1, V, Body1)) ).
cpp_member_explicit_candidate([TPs-Mem|Cs], C, M, Explicit, TPs1, Mem1, B) :-
    (   cpp_candidate_check(cpp_as_callee(C, cpp_with_req_ctx(C, ( cpp_bind_explicit(TPs, Explicit, B0), cpp_bind_defaults(TPs, B0, B),
                \+ ( member(tparam(_, P, _), TPs), \+ memberchk(P-_, B) ), cpp_constraints_hold(M, TPs, B) ))),
              error(not_lowered(_), _), fail, B, ground(Explicit))
    ->  TPs1 = TPs, Mem1 = Mem
    ;   cpp_member_explicit_candidate(Cs, C, M, Explicit, TPs1, Mem1, B) ).
%% a member template's instance named as a value is the THUNK over its own parameters, the null `this' dropped
cpp_instance_thunk(C, Name, Thunk) :-
    atom_concat(Name, '.fn', Thunk),
    (   cpp_instance_done(Thunk) -> true
    ;   ccl_declared(Name, fn(R, [_|Ps1], false)), cpp_thunk_params(Ps1, 1, Ps, Args),
        ( ccl_resolve_type(R, base(_, [void])) -> Body = block([expr(0, call(id(Name), [nullptr|Args]))]) ; Body = block([return(0, call(id(Name), [nullptr|Args]))]) ),
        cpp_instance_note(Thunk, thunk), ccl_gdeclare([Thunk-fn(R, Ps, false)]),   % AT FILE SCOPE: the deduction that asks for it pops its frame (0.117's rule for a mangled prototype)
        ( cpp_lib_class(C) -> Lib = yes ; Lib = no ), cpp_as_lib(Lib, cpp_add_instance_items([function(0, none, R, Thunk, Ps, false, Body)])) ).
cpp_prefer_const(Cands, Sorted) :- cpp_obj_const_now(K), K \== none, !,
    findall(X, ( member(X, Cands), cpp_cand_const(X, K) ), First), findall(X, ( member(X, Cands), \+ cpp_cand_const(X, K) ), Rest), append(First, Rest, Sorted).
cpp_prefer_const(Cands, Cands).
cpp_cand_const(_-method(_, Qs, _, _, _, _, _), K) :- ( memberchk(const, Qs) -> K == const ; K == nonconst ), \+ ( cpp_obj_cat_now(Cat), Cat \== none, memberchk(refq(R), Qs), R \== Cat ).   % and never a ref-qualifier against the object's value category
%% A NAME NOTED DONE BEFORE ITS EMISSION SURVIVES THAT EMISSION'S ABANDONMENT. A member template's instance is
%% made wherever its call is met, and that can be INSIDE another candidate's signature check, whose catch swallows
%% the refusal and rejects the candidate (SFINAE, by design) -- and the note was left behind, so every later ask
%% answered with a definition that had never been emitted: `std::vector<std::string>' called
%% `allocator<string>::construct' and the linker's own complaint arrived as `undeclared'. The name is IN PROGRESS
%% while the emission runs, which is all a recursive ask needs, and NOTED only once it is done; a throw clears it,
%% as cpp_isolated and cpp_in_class already restore what they set aside.
cpp_making(Name) :- nb_getval('$cpp_making', L), memberchk(Name, L).
cpp_make_member(Name, C, L, Qs, Ret1, MName, Ps1, V, Body1) :-
    nb_getval('$cpp_making', M0), nb_setval('$cpp_making', [Name|M0]),
    ( memberchk(noexcept(NE), Qs), \+ '$cpp_nxdef'(Name, _, _, _) -> assertz('$cpp_nxdef'(Name, C, NE, Ps1)) ; true ),   % A MEMBER TEMPLATE'S INSTANCE'S CONDITIONAL NOEXCEPT, substituted (0.205): the noexcept operator asks it of the instance a call resolves to (cpp_nx_named_value/2), a generic lambda's `noexcept(sizeof(x) > 4)' among them
    M = method(L, Qs, Ret1, MName, Ps1, V, Body1),
    (   catch(\+ \+ ( cpp_class_l(C, cls(Base, _, _, Defaults, _)), ( cpp_lib_class(C) -> Lib = yes ; Lib = no ),
                cpp_as_lib(Lib, ( cpp_isolated(cpp_in_class(C, ( cpp_declare_members([M], C), cpp_member_fns([M], C, Base, Defaults, Fns) ))),
                                  cpp_add_instance_items(Fns) )) ),
              E, ( nb_setval('$cpp_making', M0), throw(E) ))
    ->  nb_setval('$cpp_making', M0), cpp_instance_note(Name, C)
    ;   nb_setval('$cpp_making', M0), cpp_refuse(L, member_instance_not_emitted(Name)) ).
cpp_variadic_member(_-method(_, _, _, _, _, true, _)).
cpp_try_member(Cands, C, Explicit, As, Name) :-
    cpp_member_holding(Cands, C, Explicit, As, Hs), Hs \== [],
    cpp_fewest_conversions(Hs, [h(_, TPs, method(L, Qs, Ret, M, Ps, V, Body), B, _)|_]),           % the fewest conversions, the first declared among equals (the object's constness ordered the list)
    cpp_instance_name(M, TPs, B, MName), cpp_subst(method(L, Qs, Ret, M, Ps, V, Body), B, method(_, Qs1, Ret1, _, Ps1, _, Body1)),
    cpp_mangle_q(C, MName, Qs1, Ps1, Name), cpp_trace(member_holds(C, Name)),   % the member template's instance chosen, with its deduced keys, NAMED BY ITS SUBSTITUTED QUALIFIERS (0.114): the `.rq<fold>' of a constrained member (0.112) folded the raw clause here and the substituted one where the instance is declared, so the call named nothing (ranges::begin over an array, `rangesarray.cpp')
    (   cpp_instance_done(Name) -> true
    ;   cpp_making(Name) -> true                                    % in progress: the NAME is all a recursive ask needs
    ;   cpp_with_fsig(inst(MName, fsig(member, C, M, Ret, Ps, V, Qs1, ta(TPs, B))), cpp_make_member(Name, C, L, Qs1, Ret1, MName, Ps1, V, Body1)) ).   % ITS QUALIFIERS SUBSTITUTED TOO (0.112): handed over raw, ranges::begin's `requires(sizeof(_Tp) >= 0)' was checked with _Tp free at the emission, the member was skipped and its name noted made -- `undeclared' at the call
cpp_member_holding([], _, _, _, []).
cpp_member_holding([TPs-method(L, Qs, Ret, M, Ps0, V, Body)|Cs], C, Explicit, As0, Hs) :- cpp_conv_enter(Saved),
    (   memberchk(explicit_this(EN, ET), Qs) -> ( cpp_obj_expr_now(EO) -> Ps = [param(ET, EN)|Ps0], As = [EO|As0], Usable = yes ; Ps = Ps0, As = As0, Usable = no ) ; Ps = Ps0, As = As0, Usable = yes ),   % C++23's EXPLICIT OBJECT PARAMETER (0.117): the object is the first argument, the candidate's first parameter its declared type; a call that names no object has no such candidate
    (   Usable == yes, cpp_candidate_check(cpp_as_callee(C, cpp_with_req_ctx(C, ( cpp_signature_holds(M, TPs, Ps, V, Explicit, As, B), cpp_result_holds(Ret, TPs, B, Ps), cpp_member_tmpl_req(C, Qs, Ps, B) ))), error(not_lowered(W), _), ( cpp_trace(member_refused(C, M, W)), fail ), B, ground(As-Explicit))   % IN ITS OWN CLASS: a parameter written `const allocator_type &' is in the traits class's words, not the caller's; AND THE RESULT TYPE IS PART OF THE SIGNATURE on the member road too (0.55's rule for a free template, 0.93): `__do_test(...) -> __all<__enable_if_t<_Trait<_LArgs, _RArgs>::value, bool>{true}...>' is REJECTED where a trait is false, which is how the variadic `__do_test(...) -> false_type' beside it is ever chosen
    ->  cpp_conversions(Conv), cpp_conv_leave(Saved), Hs = [h(0, TPs, method(L, Qs, Ret, M, Ps0, V, Body), B, Conv)|Hs1]
    ;   cpp_conv_leave(Saved), Hs = Hs1 ),
    cpp_member_holding(Cs, C, Explicit, As0, Hs1).
%% A MEMBER TEMPLATE'S REQUIRES-CLAUSE KEPT AMONG ITS QUALIFIERS is part of the candidate (0.112, [temp.constr]): checked
%% under the deduced bindings, an unmet one is no candidate -- chosen and then skipped at its emission, its name was
%% noted made and the call named nothing
cpp_member_tmpl_req(C, Qs, Ps, B) :-
    (   memberchk(requires(_), Qs)
    ->  cpp_subst(method(0, Qs, base([], [void]), '$req', Ps, false, none), B, method(_, Qs1, _, _, Ps1, _, _)), cpp_method_viable(C, Qs1, Ps1)
    ;   true ).
cpp_member_template_ctor(C, As, Name) :-
    findall(TPs-Mem, '$cpp_mt'(C, ctor, TPs, Mem), Cands), Cands \== [],
    cpp_try_ctor(Cands, C, As, Name).
cpp_try_ctor(Cands, C, As, Name) :-
    cpp_ctor_holding(Cands, C, As, Hs), Hs \== [],
    cpp_fewest_conversions(Hs, [h(_, _, ctor(L, Qs, Ps, Inits, Body), B, _)|_]),                    % the fewest conversions, the first declared among equals
    cpp_subst(ctor(L, Qs, Ps, Inits, Body), B, ctor(_, _, Ps1, Inits1, Body1)), cpp_mangle(C, C, Ps1, Name), cpp_trace(ctor_holds(Name)),
        (   cpp_instance_done(Name) -> true
        ;   cpp_making(Name) -> true                                    % in progress: the NAME is all a recursive ask needs
        ;   nb_getval('$cpp_making', M0), nb_setval('$cpp_making', [Name|M0]),   % IN PROGRESS while it emits, NOTED after (0.69's rule, here too): a failed emission left a note behind and no definition
            (   catch(\+ \+ ( cpp_class_l(C, cls(Base, _, _, Defaults, _)), ( cpp_lib_class(C) -> Lib = yes ; Lib = no ),
                        cpp_as_lib(Lib, ( cpp_isolated(cpp_in_class(C, ( cpp_declare_members([ctor(L, Qs, Ps1, Inits1, Body1)], C), cpp_member_fns([ctor(L, Qs, Ps1, Inits1, Body1)], C, Base, Defaults, Fns) ))),
                                          cpp_add_instance_items(Fns) )) ), E2, ( nb_setval('$cpp_making', M0), throw(E2) ))
            ->  nb_setval('$cpp_making', M0), cpp_instance_note(Name, C)
            ;   nb_setval('$cpp_making', M0), cpp_refuse(0, member_instance_not_emitted(Name)) ) ).   % never a silent failure: it looked like no constructor at all
%% EVERY CONSTRUCTOR TEMPLATE WHOSE SIGNATURE HOLDS, with the conversions it takes ([over.match.best]: the fewest win,
%% the first declared among equals, as the free-function road has had it since 0.45). The FIRST that held won before,
%% and libc++'s pair declares `pair(const _T1 &, const _T2 &)' before `pair(_U1 &&, _U2 &&)': given a `char *' the
%% first held through the string's converting constructor, where the second is exact, and `emplace("one", 1)' on a
%% map of strings built its node from the pointer's bytes.
cpp_ctor_holding([], _, _, []).
cpp_ctor_holding([TPs-ctor(L, Qs, Ps, Inits, Body)|Cs], C, As, Hs) :-
    length(Ps, NP), cpp_trace(ctor_candidate(C, NP, As)), cpp_conv_enter(Saved),
    (   cpp_candidate_check(cpp_as_callee(C, cpp_with_req_ctx(C, cpp_signature_holds(C, TPs, Ps, [], As, B))), E, ( ( E = error(not_lowered(W), _) -> cpp_trace(member_refused(C, ctor, W)) ; cpp_trace(member_error(C, ctor, E)) ), fail ), B, ground(As))   % IN ITS OWN CLASS, as a member template's is (0.51)
    ->  cpp_conversions(Conv), cpp_conv_leave(Saved), Hs = [h(0, TPs, ctor(L, Qs, Ps, Inits, Body), B, Conv)|Hs1]
    ;   cpp_conv_leave(Saved), cpp_trace(ctor_no(C, NP)), Hs = Hs1 ),
    cpp_ctor_holding(Cs, C, As, Hs1).
