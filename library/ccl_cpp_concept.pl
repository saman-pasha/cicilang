%% ccl_cpp_concept.pl -- C++20 concepts and the function's own name: satisfaction, requires-expressions, __func__ and
%% std::source_location. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there,
%% in their order.

%% ---- C++20 concepts: satisfaction ----------------------------------------------------------
%% a constraint holds when its concept's expression holds under the arguments: `&&', `||', `!',
%% a requires-expression whose requirements type-check under its parameters (an expression has a
%% type, a type resolves, a compound's type satisfies its concept, a nested one holds), else a
%% constant expression that is not 0; a trait of libc++'s has no body here and is refused
cpp_satisfied(bin('&&', A, B)) :- !, cpp_satisfied(A), cpp_satisfied(B).
cpp_satisfied(bin('||', A, B)) :- !, ( cpp_satisfied(A) -> true ; cpp_satisfied(B) ).
cpp_satisfied(not(E)) :- !, \+ cpp_satisfied(E).
cpp_satisfied(bool(true)) :- !.
cpp_satisfied(bool(false)) :- !, fail.
cpp_satisfied(tmpl(N, Args0)) :- cpp_variable_template(N), !, cpp_targ_values(Args0, Args), cpp_instantiate_variable(N, Args, E),   % a VARIABLE template in a requires-clause is its value: `requires (!is_same_v<...> && is_constructible_v<_Tp &, _Up>)' on optional<T &>, taken for a concept-id
    ( ccl_const_eval(E, V) -> V =\= 0 ; cpp_refuse(0, constraint_unknown(tmpl(N, Args))) ).
cpp_satisfied(tmpl(C, Args)) :- !, cpp_concept_holds(C, Args).
cpp_satisfied(id(C)) :- atom(C), '$cpp_concept'(C, _), !, cpp_concept_holds(C, []).
cpp_satisfied(requires_expr(Ps0, Reqs)) :- !,
    cpp_plain_params(Ps0, Ps), cpp_in_frame(( ccl_declare_params(Ps), catch(cpp_requirements_hold(Reqs), error(not_lowered(_), _), fail) )).   % a refusal inside a requirement is the requirement not met (SFINAE), never the program's error
cpp_satisfied(E) :- ( ccl_const_eval(E, V) -> V =\= 0 ; cpp_req_ctx(X), catch(cpp_expr(X, E, E1), _, fail), cpp_with_ce(cpp_const_bool(E1, V1)) -> V1 == true ; cpp_refuse(0, constraint_unknown(E)) ).   % a nested requirement `requires _IsSame<...>::value;' is a static's value, folded through the desugaring (0.44's `X<T>::value')
%% ... AND A CONSTEXPR CALL IN IT through the evaluator (0.200; [temp.constr.atomic]/3, an atomic constraint is a constant
%% expression, and its evaluation is manifestly constant-evaluated, [expr.const]/20): libc++ 18's chrono inserter of a
%% `sys_time<_Duration>' requires `_Duration{1} < days{1}', a call of duration's `operator<' over two temporaries, which
%% ccl_const_eval/2 alone does not fold, so the constraint was refused and no inserter took a time point of seconds
cpp_concept_known(N) :- atom(N), ( '$cpp_concept'(N, _) -> true ; cpp_hdr_join_concept(N) ).
cpp_hdr_join_concept(N) :- cpp_hdr_join(N), '$cpp_concept'(N, _), !.
cpp_concept_holds(C, Args) :-
    ( cpp_concept_known(C) -> true ; cpp_refuse(0, concept_without_body(C)) ),
    cpp_types(Args, Args1),
    (   ground(Args1), '$cpp_ccm'(C, A0, R0), A0 == Args1 -> R0 == yes                              % A CONCEPT'S SATISFACTION IS REMEMBERED (0.112), as C++ caches it ([temp.constr.atomic]: one answer per arguments, a second one ill-formed): libc++'s ranges asked 3463 concept-ids of 97 kinds in one build -- `same_as<I &, I &>' 552 times
    ;   once('$cpp_concept'(C, concept(TPs, E))), cpp_bind_targs(TPs, Args1, B), cpp_subst(E, B, E1),
        ( cpp_with_req_ctx(none, cpp_isolated(cpp_satisfied(E1))) -> R = yes ; cpp_trace(concept_unsatisfied(C, Args1)), R = no ),   % a concept's body is at namespace scope, never the asking class's -- nor the asking function's (0.182, above)
        ( ground(Args1) -> assertz('$cpp_ccm'(C, Args1, R)) ; true ),
        R == yes ).   % the concept that failed is named under the trace (0.109)
%% THE CONTEXT a requirement is walked in: none for a template's head, the CLASS for a member's trailing requires-clause
%% ([temp.inst]/11: a member function whose constraints are not satisfied is no candidate and is not instantiated) --
%% `bool empty() const requires requires { ranges::empty(*__range_); }' names a data member, `this->__range_'
cpp_req_ctx(X) :- ( nb_current('$cpp_req_ctx', X0) -> X = X0 ; X = none ).
%% ... and a MEMBER template's or constructor template's own constraints are in its class too ([temp.constr]; 0.110):
%% ref_view's `template <__different_from<ref_view> _Tp> requires ... && requires { __fun(declval<_Tp>()); }' names the
%% class's static `__fun', and walked with no class a free `__fun' of another header was found
cpp_with_req_ctx(C, Goal) :- cpp_req_ctx(X0), nb_setval('$cpp_req_ctx', C),
    ( catch(Goal, E, ( nb_setval('$cpp_req_ctx', X0), throw(E) )) -> nb_setval('$cpp_req_ctx', X0) ; nb_setval('$cpp_req_ctx', X0), fail ).
cpp_lazy_pick(C, Ms, Name, M) :- findall(M0, ( member(M0, Ms), cpp_member_mangled(C, M0, Name) ), Cs), Cs = [M1|_],
    ( Cs = [M] -> true ; member(M, Cs), catch(cpp_lazy_viable(C, M), _, true) -> true ; M = M1 ).
cpp_lazy_viable(C, ctor(_, Qs, Ps, _, _)) :- !, cpp_method_viable(C, Qs, Ps).
cpp_lazy_viable(C, method(_, Qs, _, _, Ps, _, _)) :- !, cpp_method_viable(C, Qs, Ps).
cpp_lazy_viable(_, _).
cpp_method_viable(C, Qs, Ps) :- ( memberchk(requires(R), Qs) -> cpp_member_req_holds(C, Qs, Ps, R) ; true ).
cpp_member_req_holds(C, Qs, Ps, R) :- cpp_this_type(C, Qs, ThisT), cpp_plain_params(Ps, Ps1), cpp_req_ctx(X0),
    nb_setval('$cpp_req_ctx', C),
    ( catch(cpp_isolated(cpp_in_class(C, ( ccl_scope_push, ccl_declare_params([param(ThisT, this)|Ps1]), cpp_satisfied(R), ccl_scope_pop ))), E, ( nb_setval('$cpp_req_ctx', X0), cpp_trace(member_req_error(C, E)), fail ))
    ->  nb_setval('$cpp_req_ctx', X0)
    ;   nb_setval('$cpp_req_ctx', X0), cpp_trace(member_req_unmet(C, R)), fail ).
cpp_requirements_hold([]).
cpp_requirements_hold([R|Rs]) :- ( cpp_requirement_holds(R) -> true ; cpp_trace(requirement_unmet(R)), fail ), cpp_requirements_hold(Rs).
cpp_requirement_holds(expr(E)) :- cpp_req_ctx(X), cpp_unevaluated(cpp_expr(X, E, E1)), ccl_type_of(E1, T), T \== unknown, \+ cpp_bare_template_type(T).
cpp_requirement_holds(type(T0)) :- cpp_type(T0, T), ccl_resolve_type(T, R), \+ R = base(_, [typedef(_)]).
cpp_requirement_holds(compound(E, C)) :- cpp_req_ctx(X), cpp_unevaluated(cpp_expr(X, E, E1)), ccl_type_of(E1, T0), T0 \== unknown, \+ cpp_bare_template_type(T0), ( C == none -> true ; cpp_decltype_paren(E1, T), cpp_concept_of(C, T) ).
cpp_requirement_holds(nested(E)) :- cpp_satisfied(E).
%% A COMPOUND REQUIREMENT'S TYPE IS decltype((e)) ([expr.prim.req.compound]; 0.109): an lvalue is `T &', a call its
%% declared reference -- `{ __lhs = std::forward<_Rhs>(__rhs) } -> same_as<_Lhs>' is assignable_from's, with _Lhs a
%% reference, and read as the plain type no iterator was weakly_incrementable, no vector a range
cpp_cond_glvalue(ref(_, X), ref(_, Y), ref([], Z)) :- cpp_cv_union(X, Y, Z).
cpp_cond_glvalue(rref(_, X), rref(_, Y), rref([], Z)) :- cpp_cv_union(X, Y, Z).
cpp_cv_union(base(QX, S), base(QY, S1), base(Q, S)) :- ( cpp_canon_specs(S, C), cpp_canon_specs(S1, C) -> true ; catch(cpp_same_type(base([], S), base([], S1)), _, fail) ), !,   % ONE TYPE UNDER TWO SPELLINGS is one type (0.112): libc++'s common_reference of `const unsigned &' and `uint32_t &' is __cond_res over the two, and compared by spelling it was a prvalue -- no reference, `__common_ref' unmet, no `const uint32_t *' indirectly_readable, and ranges::upper_bound over libc++'s grapheme table had no candidate
    findall(X, ( member(X, [const, volatile]), ( memberchk(X, QX) -> true ; memberchk(X, QY) ) ), Q).   % each qualifier ONCE: both arms const gave `const const'
cpp_cv_union(X, Y, X) :- X == Y.
cpp_fn_result(fn(R, _, _), R) :- !.
cpp_fn_result(ref(_, T), R) :- !, cpp_fn_result(T, R).
cpp_fn_result(rref(_, T), R) :- !, cpp_fn_result(T, R).
cpp_fn_result(ptr(_, T), R) :- cpp_fn_result(T, R).
cpp_decltype_paren(E, T) :- cpp_decltype_of(E, T0), ( T0 = ref(_, _) ; T0 = rref(_, _) ), !, T = T0.
cpp_decltype_paren(E, ref([], T)) :- ( E = id(N), atom(N), \+ ccl_enum_value(N, _) ; E = member(_, _) ; E = arrow(_, _) ; E = deref(_) ; E = index(_, _) ; E = assign(_, _, _) ; E = preinc(_) ; E = predec(_) ), ccl_type_of(E, T0), T0 \== unknown, !,
    ( ( E = member(_, _) ; E = arrow(_, _) ), \+ cpp_type_const(T0), cpp_obj_const(E, const) -> ccl_add_quals([const], T0, T) ; T = T0 ).   % A MEMBER OF A CONST OBJECT IS CONST ([expr.ref]/6.2; 0.206): `decltype((c.m))' was `int &'
cpp_decltype_paren(E, T) :- ccl_type_of(E, T0), cpp_prvalue_type(T0, T).
%% A PRVALUE OF NON-CLASS TYPE HAS NO TOP-LEVEL CV-QUALIFIER ([expr.type]/2): `__j + __n' over a `const char *const' is a
%% `const char *', which random_access_iterator's `{ __j + __n } -> same_as<_Ip>' asks -- typed with the operand's own
%% const it was unmet, no `const char *' was a contiguous iterator, and std::format's replacement-field parser had no
%% candidate (0.112; test/cpp/run/prvaluecv.cpp)
cpp_prvalue_type(ptr(_, T), ptr([], T)) :- !.
cpp_prvalue_type(base(Q, S), base(Q1, S)) :- \+ cpp_class_of_type(base(Q, S), _), !, findall(X, ( member(X, Q), X \== const, X \== volatile ), Q1).
cpp_prvalue_type(T, T).
%% AN UNEVALUATED OPERAND ([expr.context]/1: decltype's, a requirement's) MAKES NO TEMPORARY (0.132): walked with the
%% statement's register of temporaries set aside, a class temporary is declared where it stands, as outside a statement
%% walk, and no destructor is scheduled -- `decltype(_Container(std::declval<_Range>()))' of libc++'s ranges::to left
%% four `vector' temporaries in the statement that called it, never built and destroyed at its end (a loop through
%% garbage)
%% A TEMPLATE'S BARE NAME AS AN EXPRESSION'S TYPE is a deduction that failed (0.132): `ranges::ref_view{std::forward<_Tp>(__t)}'
%% of a char deduces nothing (the guide takes an lvalue), and typed as the bare `ref_view' the requirement of libc++'s
%% `views::all' held for a char
cpp_bare_template_type(T) :- ccl_unref(T, base(_, [typedef(N)])), atom(N), cpp_bare_template_name(N).
cpp_unevaluated(G) :- ccl_global('$cpp_temps', Ts, none), nb_setval('$cpp_temps', none),
    ( nb_current('$cpp_uneval', U0) -> true ; U0 = no ), nb_setval('$cpp_uneval', yes),   % ... and the walk marked unevaluated (0.221, cpp_static_assert/4)
    ( catch(G, Err, ( nb_setval('$cpp_temps', Ts), nb_setval('$cpp_uneval', U0), throw(Err) )) -> nb_setval('$cpp_temps', Ts), nb_setval('$cpp_uneval', U0)
    ; nb_setval('$cpp_temps', Ts), nb_setval('$cpp_uneval', U0), fail ).
cpp_concept_of(id(C), T) :- cpp_concept_holds(C, [T]).
cpp_concept_of(tmpl(C, Args), T) :- cpp_concept_holds(C, [T|Args]).
cpp_concept_of(scoped(_, X), T) :- cpp_concept_of(X, T).   % a QUALIFIED type-constraint, `-> std::same_as<I>': the namespaces flatten (0.112)

%% a constant condition: a constant expression, or a constraint
cpp_const_bool(E, V) :- ccl_const_eval(E, N), !, ( N =\= 0 -> V = true ; V = false ).
cpp_const_bool(bool(B), B) :- !.
cpp_const_bool(tmpl(C, Args), V) :- atom(C), '$cpp_concept'(C, _), !, ( cpp_concept_holds(C, Args) -> V = true ; V = false ).
cpp_const_bool(E, V) :- compound(E), cpp_has_call(E), catch(cpp_const_value(E, K), _, fail), !, ( K = bool(V0) -> V = V0 ; integer(K), K =\= 0 -> V = true ; K = big(_) -> V = true ; V = false ).   % A CONSTEXPR CALL decides it too, through the evaluator (0.112): libc++ 18's `if constexpr (__format::__use_packed_format_arg_store(sizeof...(_Args)))' kept both branches, and the other one named a member the store does not have
%% ... AND ONE INSIDE THE CONDITION (0.197): cpp_const_value/2 folds each call where it sits; libc++ 21's pair writes `explicit(!_CheckArgs::template __is_implicit<_U1 const &, _U2 const &>())', and `!f()' was no constant, so the converting constructor was never explicit
%% a plain struct or union (no registered class) value that an lvalue names: the type of `std::move(x)'s cast, `S &&'
cpp_plain_xvalue(X, rref([], T)) :- cpp_lvalue(X), ccl_type_of(X, T0), T0 \== unknown, ccl_unref(T0, T), ccl_resolve_type(T, R), R = base(RQ, [Tag]), \+ memberchk(const, RQ), T = base(TQ, _), \+ memberchk(const, TQ), ( Tag = struct(_, _) ; Tag = union(_, _) ), \+ cpp_class_of_type(T, _), \+ cpp_holds_owners(T).
cpp_scalar_xvalue(X, rref([], T)) :- cpp_lvalue(X), ccl_type_of(X, T0), T0 \== unknown, ccl_unref(T0, T), catch(ccl_resolve_type(T, R), _, fail), ( R = ptr(_, _) ; ccl_is_arith(R) ), !.   % an lvalue of arithmetic, enumeration or pointer type (0.201)
%% -g'S NAMES AND SCOPES (0.130): what the lowering's debug information says of a C++ function, class or global, as the
%% source spells it; this compiler's own names (`Counter.bump.int') stay the symbols. A class is its namespaces and its chain
%% of classes (cpp_dbg_class_path/3: `ns::Outer::Inner', a template's instance `Buf<int, 4>'; the program's own namespaces from
%% '$cpp_dbg_ns', noted by cpp_ns_resolve under -g, a header's from cpp_hdr_ns/2). A method is `member(Class, Name)' -- a
%% constructor the class's own name, the destructor `~' and it, an operator `operator+' --, a free function or a function
%% template's instance `free(NsPath, Name)', a free operator `free([], operator<<)', a static data member `member(Class,
%% Name)' and a namespace-scope global `free(NsPath, Name)'. A name that no rule spells keeps its own (a thunk, an
%% invoker, `$cpp_ginit'), and so does a table or a type's information (`C.vtable'), which no rule answers.
cpp_dbg_fn(Name, Src) :- atom(Name), cpp_dbg_fn_(Name, Src), !.
cpp_dbg_fn_(Name, free([], Op)) :- atomic_list_concat([op, W|_], '.', Name), !, cpp_dbg_op_spell(W, Op).
cpp_dbg_fn_(Name, free(P, F2)) :- catch('$cpp_inst'(Name, F), _, fail), atom(F), \+ memberchk(F, [mangled, hdr, cdecl, thunk, inline_var]), \+ catch('$cpp_clsl'(F, _), _, fail), !,
    cpp_dbg_ns_of(F, P, F1),                                                                       % a function template's instance, with its arguments
    ( catch('$cpp_dbg_targs'(Name, As), _, fail), As \== [] -> cpp_dbg_args(As, AS), ( sub_atom(AS, _, 1, 0, '>') -> Sp = ' >' ; Sp = '>' ), atomic_list_concat([F1, '<', AS, Sp], F2) ; F2 = F1 ).
cpp_dbg_fn_(Name, member(C, M)) :- atomic_list_concat(Segs, '.', Name), cpp_dbg_class_prefix(Segs, C, Rest), !, cpp_dbg_member(C, Rest, M).
cpp_dbg_fn_(Name, free(P, F1)) :- atomic_list_concat([F|_], '.', Name), catch('$cpp_fn'(F, _, _, _, _), _, fail), !, cpp_dbg_ns_of(F, P, F1).   % a free function, an overload `F.<keys>'
cpp_dbg_global(N, member(C, M)) :- atom(N), atomic_list_concat(Segs, '.', N), Segs = [_, _|_], cpp_dbg_class_prefix(Segs, C, [M]),
    cpp_class_l(C, cls(_, _, Ss, _, _)), memberchk(M-_, Ss), !.                                 % a static data member: no table, no type's information
cpp_dbg_global(N, free(P, N1)) :- atom(N), \+ sub_atom(N, _, _, _, '.'), !, cpp_dbg_ns_of(N, P, N1).
cpp_dbg_note_targs(Name, TPs, B) :-
    (   nb_current('$ccl_debug', file(_)), \+ catch('$cpp_dbg_targs'(Name, _), _, fail)
    ->  findall(A, ( member(TP, TPs), TP = tparam(_, P, _), memberchk(P-A, B) ), As), assertz('$cpp_dbg_targs'(Name, As))
    ;   true ).
%% a name's namespaces: the program's own, else a header's; a key of a deeper namespace's name (`inner.f') is that name
cpp_dbg_ns_of(F, P, F) :- catch('$cpp_dbg_ns'(F, P), _, fail), !.
cpp_dbg_ns_of(F, P, F) :- catch(cpp_hdr_ns(F, P0), _, fail), is_list(P0), !, findall(X, ( member(X, P0), atom(X) ), P).
cpp_dbg_ns_of(F, [], F).
%% the longest leading segments that name a registered class, and the rest
cpp_dbg_class_prefix(Segs, C, Rest) :- length(Segs, N), K is N - 1, K >= 1, cpp_dbg_split(Segs, K, C, Rest).
cpp_dbg_split(Segs, K, C, Rest) :- length(Pre, K), append(Pre, Rest, Segs), atomic_list_concat(Pre, '.', C), catch('$cpp_clsl'(C, _), _, fail), !.
cpp_dbg_split(Segs, K, C, Rest) :- K > 1, K1 is K - 1, cpp_dbg_split(Segs, K1, C, Rest).
cpp_dbg_member(C, [dtor|_], M) :- !, cpp_dbg_last(C, L), atom_concat('~', L, M).
cpp_dbg_member(_, [op, W|_], M) :- !, cpp_dbg_op_spell(W, M).
cpp_dbg_member(C, Rest, M) :- atomic_list_concat(CSegs, '.', C), append(CSegs, _, Rest), !, cpp_dbg_last(C, M).   % the constructor, `C.C.<keys>'
cpp_dbg_member(_, [M|_], M).
cpp_dbg_last(C, L) :- ( catch('$cpp_inst'(C, inst(N, _)), _, fail), atom(N) -> true ; N = C ), atomic_list_concat(Ss, '.', N), ccl_last(Ss, L).
%% a class's namespaces and its chain of classes, the outermost first: `Outer.Inner' is [Outer, Inner], an instance's own
%% name spelled with its arguments
cpp_dbg_class_path(C, P, Chain) :- atom(C), cpp_dbg_class_path_(C, P, Chain), !.
cpp_dbg_class_path_(C, P, Chain) :- catch('$cpp_inst'(C, inst(N, Args)), _, fail), atom(N), is_list(Args), !,
    cpp_dbg_args(Args, AS), ( sub_atom(AS, _, 1, 0, '>') -> Sp = ' >' ; Sp = '>' ),
    (   cpp_dbg_holder(N, E, Last) -> cpp_dbg_class_path(E, P, ChainE), atomic_list_concat([Last, '<', AS, Sp], Own), append(ChainE, [Own], Chain)
    ;   cpp_dbg_ns_of(N, P, N1), atomic_list_concat([N1, '<', AS, Sp], Own), Chain = [Own] ).
cpp_dbg_class_path_(C, P, Chain) :- cpp_dbg_holder(C, E, Last), !, cpp_dbg_class_path(E, P, ChainE), append(ChainE, [Last], Chain).
cpp_dbg_class_path_(C, P, [C1]) :- cpp_dbg_ns_of(C, P, C1).
cpp_dbg_holder(C, E, Last) :- atomic_list_concat(Segs, '.', C), Segs = [_, _|_], cpp_dbg_class_prefix(Segs, E, Rest), atomic_list_concat(Rest, '.', Last).
cpp_dbg_holder_tag(C, E) :- catch('$cpp_inst'(C, inst(N, _)), _, fail), atom(N), cpp_dbg_holder(N, E, _), !.
cpp_dbg_holder_tag(C, E) :- cpp_dbg_holder(C, E, _).
cpp_dbg_args(Args, AS) :- findall(S, ( member(A, Args), ( catch(cpp_dbg_spell(A, S0), _, fail) -> S = S0 ; S = '?' ) ), Ss), atomic_list_concat(Ss, ', ', AS).
cpp_dbg_spell(A, A) :- integer(A), !.
cpp_dbg_spell(cast(ET, X), S) :- cpp_enum_type(ET), cpp_pf_int_of(X, I), catch(ccl_resolve_type(ET, base(_, [E])), _, fail), compound(E), arg(1, E, Tag), atom(Tag), cpp_dbg_class_spelled(Tag, EN), !, atomic_list_concat(['(', EN, ')', I], S).   % an enumeration's value, `X<(Color)1>' as clang names a debug entry (0.203)
cpp_dbg_spell(V, S) :- cpp_pf_int_of(V, I), cpp_pf_lit_type(V, LT), !, cpp_pf_value(LT, I, yes, S).   % a value by its own type, shown, as clang names a debug entry (0.199: `g<4U>', `h<5LL>', `s<(short)9>', `k<'x'>')
cpp_dbg_spell(bool(B), B) :- !.
cpp_dbg_spell(pack(L), S) :- !, is_list(L), cpp_dbg_args(L, S).
cpp_dbg_spell(tname(X), S) :- !, atom(X), cpp_dbg_class_spelled(X, S).
cpp_dbg_spell(ptr(Q, E), S) :- !, cpp_dbg_spell(E, ES), ( memberchk(const, Q) -> atom_concat(ES, ' *const', S) ; atom_concat(ES, ' *', S) ).
cpp_dbg_spell(ref(_, E), S) :- !, cpp_dbg_spell(E, ES), atom_concat(ES, ' &', S).
cpp_dbg_spell(rref(_, E), S) :- !, cpp_dbg_spell(E, ES), atom_concat(ES, ' &&', S).
cpp_dbg_spell(base(Q, Sp), S) :- !, cpp_dbg_specs(Sp, S0), ( memberchk(const, Q) -> atom_concat('const ', S0, S1) ; S1 = S0 ), ( memberchk(volatile, Q) -> atom_concat('volatile ', S1, S) ; S = S1 ).
cpp_dbg_specs([typedef(N)], S) :- !, atom(N), ( catch('$cpp_clsl'(N, _), _, fail) -> cpp_dbg_class_spelled(N, S) ; S = N ).
cpp_dbg_specs([X], S) :- compound(X), functor(X, F, _), memberchk(F, [struct, union, enum, enum_class]), arg(1, X, N), atom(N), !, cpp_dbg_class_spelled(N, S).
cpp_dbg_specs(Sp, S) :- forall(member(X, Sp), atom(X)), atomic_list_concat(Sp, ' ', S).
cpp_dbg_class_spelled(C, S) :- cpp_dbg_class_path(C, P0, Chain), cpp_pf_anon(P0, P), append(P, Chain, All), atomic_list_concat(All, '::', S).
cpp_dbg_op_spell(W, S) :- atom_concat(conv_, K, W), !, atom_concat('operator ', K, S).
cpp_dbg_op_spell(W, S) :- member(Op, ['+', '-', '*', '/', '%', '==', '!=', '<', '>', '<=', '>=', '+=', '-=', '*=', '/=', '%=', '[]', '()', '<<', '>>', '!', '&&', '||', '&', '|', '^', '~', '++', '--', '=', '->', '<<=', '>>=', '&=', '|=', '^=', '<=>', ',', '->*']),
    catch(cpp_op_word(Op, W0), _, fail), W0 == W, !, atom_concat(operator, Op, S).
cpp_dbg_op_spell(W, S) :- atom_concat('operator_', W, S).
%% ---- THE FUNCTION'S OWN NAME (0.166) --------------------------------------------------------------------------------
%% `__func__' and `__FUNCTION__' are the function's own name and `__PRETTY_FUNCTION__' its signature, as clang spells them
%% ([dcl.fct.def.general]/8; clang's PredefinedExpr): `m', `K', `~K', `operator+=', `operator()'; `int main()', `static
%% long K::s(char)', `virtual void D::v()', `int K::c() const', `T tf(T) [T = int]', `void S<int, 4>::f() [T = int, N =
%% 4]', `auto f(int)::(anonymous class)::operator()() const'. They were the name this compiler gives the function, `K.m.0',
%% and `__PRETTY_FUNCTION__' the same. `__builtin_source_location()', which libc++'s std::source_location::current() reads
%% through its default argument, is the address of a constant `source_location::__impl': the file, that signature, the
%% line and the column of the call whose default argument it is ([support.srcloc.cons]/2); nothing answered it, and every
%% `std::source_location' was refused. The desugaring keeps what the names need in `'$cpp_fsig'', the function whose body
%% is walked -- `fsig(Kind, Class, Name, Result, Params, Variadic, Qualifiers, TemplateArgs)', its result and parameters as
%% written, a template instance's its pattern's -- set around each body's walk (cpp_with_fsig/2) and spelled only where a
%% name is used. A type is spelled as written; a template's bound argument as clang prints a canonical type, through its
%% namespaces (an inline one left out) and with its class template's defaulted arguments left out.
cpp_with_fsig(S, Goal) :- ( nb_current('$cpp_fsig', S0) -> true ; S0 = none ), ( nb_current('$cpp_dflt_site', D0) -> true ; D0 = none ),
    cpp_lconsts_now(LC0),
    nb_setval('$cpp_fsig', S), nb_setval('$cpp_dflt_site', none),                   % a body's own calls are their own places
    ( catch(Goal, E, ( cpp_fsig_back(S0, D0, LC0), throw(E) )) -> cpp_fsig_back(S0, D0, LC0)
    ; cpp_fsig_back(S0, D0, LC0), fail ).
%% ... and its local constants are its own (0.195, cpp_lconst_push/1)
cpp_fsig_back(S0, D0, LC0) :- nb_setval('$cpp_fsig', S0), nb_setval('$cpp_dflt_site', D0), nb_setval('$cpp_lconsts', LC0).
%% an instance's road names the description its body is walked under, `inst(Name, Sig)': its pattern's, with its arguments
cpp_fsig_own(Name, Default, Sig) :- ( nb_current('$cpp_fsig', inst(N0, S)), N0 == Name -> Sig = S ; Sig = Default ).
cpp_fsig_now(S) :- ( nb_current('$cpp_fsig', S0) -> cpp_fsig_unwrap(S0, S) ; S = none ).
cpp_fsig_unwrap(inst(_, S), S) :- !.
cpp_fsig_unwrap(S, S).
%% a member defined out of its class: `static' and `virtual' are its declaration's
cpp_pf_decl_quals(C, M, Ps, Qs, FQs) :- ( catch('$cpp_decl'(C, method(M), DQs, DPs), _, fail), length(DPs, A), length(Ps, A) -> append(Qs, DQs, FQs) ; FQs = Qs ).
%% `__func__' (func) or `__PRETTY_FUNCTION__' (pretty) in the function walked, a string literal; empty outside one
cpp_fsig_literal(N, str(Cs)) :- ( N == '__PRETTY_FUNCTION__' -> K = pretty ; K = func ), cpp_fsig_text(K, T), ccl_atom_bytes(T, Cs).   % its bytes, a name past ASCII's UTF-8 (0.196)
cpp_fsig_text(K, T) :- cpp_fsig_now(S), ( S \== none, catch(cpp_pf(K, S, T0), _, fail), atom(T0) -> T = T0 ; T = '' ).
cpp_pf(func, fsig(Kind, C, Src, _, _, _, _, _), T) :- !, ( Kind == ctor -> cpp_pf_class_short(C, T) ; Kind == dtor -> cpp_pf_class_short(C, S), atom_concat('~', S, T) ; cpp_pf_short(Src, T) ).
cpp_pf(pretty, fsig(free, _, Src, Ret, Ps, V, _, TA), T) :- !,
    cpp_pf_free_name(Src, Q), cpp_pf_params(Ps, V, [], PT), cpp_pf_brackets(none, Ps, TA, Br), cpp_pf_ret(Ret, RT),
    atom_concat(Q, PT, D), cpp_pf_with_ret(RT, D, T0), atom_concat(T0, Br, T).
cpp_pf(pretty, fsig(member, C, _, _, _, V, Qs, TA), T) :- '$cpp_pf_closure'(C, Encl, WPs), !,   % a lambda: `auto', its context, its parameters as written
    cpp_pf_ctx(Encl, X), cpp_pf_params(WPs, V, [], PT), cpp_pf_mquals(Qs, MQ), cpp_pf_brackets(C, WPs, TA, Br),
    atomic_list_concat(['auto ', X, '::(anonymous class)::operator()', PT, MQ, Br], T).
cpp_pf(pretty, fsig(member, C, Src, Ret0, Ps0, V, Qs, TA), T) :- !,
    cpp_pf_pattern(C, Src, Qs, Ret0, Ps0, Ret1, Ps), ( memberchk(trailing(TT), Qs) -> Ret = TT ; Ret = Ret1 ),
    cpp_pf_class(C, CS), cpp_pf_short(Src, MN), cpp_pf_params(Ps, V, [], PT), cpp_pf_mquals(Qs, MQ), cpp_pf_brackets(C, Ps, TA, Br),
    ( Src = operator(conv(CT)) -> cpp_pf_type(w([]), CT, RT) ; cpp_pf_ret(Ret, RT) ),   % a conversion function's result is its type, which clang prints
    cpp_pf_mprefix(C, Src, Qs, Ps, Pre), atomic_list_concat([CS, '::', MN, PT, MQ], D), cpp_pf_with_ret(RT, D, T0), atomic_list_concat([Pre, T0, Br], T).
cpp_pf(pretty, fsig(ctor, C, _, _, Ps0, V, _, _), T) :- !,
    cpp_pf_pattern(C, '$ctor', [], none, Ps0, _, Ps), cpp_pf_class(C, CS), cpp_pf_class_short(C, S),
    cpp_pf_params(Ps, V, [], PT), cpp_pf_brackets(C, Ps, none, Br), atomic_list_concat([CS, '::', S, PT, Br], T).
cpp_pf(pretty, fsig(dtor, C, _, _, _, _, _, _), T) :-
    cpp_pf_class(C, CS), cpp_pf_class_short(C, S), cpp_pf_brackets(C, [], none, Br),
    ( catch(cpp_class_l(C, cls(_, _, _, _, Sl)), _, fail), memberchk(slot('$dtor', _, _, _, _), Sl) -> Pre = 'virtual ' ; Pre = '' ),
    atomic_list_concat([Pre, CS, '::~', S, '()', Br], T).
%% a function as the context of its lambda or local class: its qualified name and its parameters, an instance's substituted
cpp_pf_ctx(none, '') :- !.
cpp_pf_ctx(fsig(free, _, Src, _, Ps, V, _, TA), S) :- !, cpp_pf_free_name(Src, Q), cpp_pf_binds(TA, B), cpp_pf_params(Ps, V, B, PT), atom_concat(Q, PT, S).
cpp_pf_ctx(fsig(member, C, _, _, _, V, _, TA), S) :- '$cpp_pf_closure'(C, Encl, WPs), !, cpp_pf_ctx(Encl, X), cpp_pf_binds(TA, B), cpp_pf_params(WPs, V, B, PT),
    atomic_list_concat([X, '::(anonymous class)::operator()', PT], S).
cpp_pf_ctx(fsig(member, C, Src, _, Ps, V, _, TA), S) :- !, cpp_pf_class(C, CS), cpp_pf_short(Src, MN), cpp_pf_binds(TA, B), cpp_pf_params(Ps, V, B, PT), atomic_list_concat([CS, '::', MN, PT], S).
cpp_pf_ctx(fsig(ctor, C, _, _, Ps, V, _, _), S) :- !, cpp_pf_class(C, CS), cpp_pf_class_short(C, N), cpp_pf_params(Ps, V, [], PT), atomic_list_concat([CS, '::', N, PT], S).
cpp_pf_ctx(fsig(dtor, C, _, _, _, _, _, _), S) :- cpp_pf_class(C, CS), cpp_pf_class_short(C, N), atomic_list_concat([CS, '::~', N, '()'], S).
cpp_pf_binds(ta(_, B), B) :- !.
cpp_pf_binds(_, []).
%% the result before the name: `T *tp(T *)', `int f()'
cpp_pf_with_ret('', D, D) :- !.
cpp_pf_with_ret(RT, D, T) :- ( ( sub_atom(RT, _, 1, 0, '*') ; sub_atom(RT, _, 1, 0, '&') ) -> atom_concat(RT, D, T) ; atomic_list_concat([RT, ' ', D], T) ).
cpp_pf_ret(none, '') :- !.
cpp_pf_ret(base(Q, [auto]), S) :- !, ( memberchk(decltype_auto, Q) -> S = 'decltype(auto)' ; S = auto ).
cpp_pf_ret(T, S) :- cpp_pf_type(w([]), T, S).
cpp_pf_mquals(Qs, S) :- findall(W, ( member(Q, [const, volatile]), memberchk(Q, Qs), atom_concat(' ', Q, W) ), Ws0),
    ( memberchk(refq(lvalue), Qs) -> append(Ws0, [' &'], Ws) ; memberchk(refq(rvalue), Qs) -> append(Ws0, [' &&'], Ws) ; Ws = Ws0 ), atomic_list_concat(Ws, S).
%% `virtual ' (by the word, or as the class's table holds the member: an override), `static '
cpp_pf_mprefix(C, Src, Qs, Ps, Pre) :-
    (   ( memberchk(virtual, Qs) ; memberchk(override, Qs) ; memberchk(pure, Qs) ) -> V = 'virtual '
    ;   atom(C), catch(cpp_class_l(C, cls(_, _, _, _, Sl)), _, fail), length(Ps, A), cpp_slots_of(Sl, Src, A, Same), Same \== [] -> V = 'virtual '
    ;   V = '' ),
    ( memberchk(static, Qs) -> St = 'static ' ; St = '' ), atom_concat(V, St, Pre).
%% `[T = int, N = 4]': the arguments of each class template instance the function is a member of, the outermost first,
%% then its own (a function template's, a member template's) -- none of an explicit specialization
cpp_pf_brackets(C, Ps, TA, Br) :-
    ( C == none -> P0 = [] ; cpp_pf_class_pairs(C, P0) ),
    ( TA = ta(TPs, B) -> cpp_pf_fn_pairs(TPs, B, Ps, P1) ; P1 = [] ),
    append(P0, P1, Prs), ( Prs == [] -> Br = '' ; atomic_list_concat(Prs, ', ', In), atomic_list_concat([' [', In, ']'], Br) ).
cpp_pf_class_pairs(C, Prs) :-
    (   '$cpp_pf_closure'(C, Encl, _) -> ( cpp_pf_sig_class(Encl, EC) -> cpp_pf_class_pairs(EC, Prs) ; Prs = [] )
    ;   '$cpp_pf_local'(C, _, Encl) -> ( cpp_pf_sig_class(Encl, EC) -> cpp_pf_class_pairs(EC, Prs) ; Prs = [] )
    ;   ( cpp_pf_holder(C, E) -> cpp_pf_class_pairs(E, P0) ; P0 = [] ), ( cpp_pf_own_pairs(C, P1) -> true ; P1 = [] ), append(P0, P1, Prs) ).
cpp_pf_sig_class(fsig(K, C, _, _, _, _, _, _), C) :- K \== free, atom(C).
cpp_pf_holder(C, E) :- '$cpp_inst'(C, inst(N, _)), atom(N), '$cpp_nested_tmpl'(E, _, N), !.
cpp_pf_holder(C, E) :- atom(C), cpp_dbg_holder(C, E, _), !.
cpp_pf_own_pairs(C, Prs) :- atom(C), '$cpp_inst'(C, inst(N, Args)), atom(N), is_list(Args),
    \+ ( catch(cpp_pick_spec(N, Args, SB, SI), _, fail), cpp_template_defined(SI), SB == [] ),     % an explicit specialization prints none
    catch(cpp_class_template(N, Args, TPs, _), _, fail), catch(cpp_bind_targs(TPs, Args, B), _, fail),
    findall(P, ( member(tparam(K, X, _), TPs), \+ sub_atom(X, 0, 1, _, '$'), memberchk(X-A, B), cpp_pf_arg(K, A, no, AS), atomic_list_concat([X, ' = ', AS], P) ), Prs).
cpp_pf_fn_pairs(TPs, B, Ps, Prs) :-
    findall(P, ( member(tparam(K, X, _), TPs), memberchk(X-A, B), cpp_pf_tparam_name(X, Ps, XN), cpp_pf_arg(K, A, yes, AS), atomic_list_concat([XN, ' = ', AS], P) ), Prs).
%% an `auto' parameter's invented template parameter `$A<k>' is named by the parameter, `x:auto', as clang names it
cpp_pf_tparam_name(X, Ps, XN) :- atom_concat('$A', KA, X), atom_number(KA, K), !,
    findall(N, ( member(P, Ps), arg(1, P, T), cpp_pf_has_auto(T), arg(2, P, N) ), Ns),
    ( nth1(K, Ns, N), atom(N), N \== anon -> atom_concat(N, ':auto', XN) ; atomic_list_concat(['auto:', K], XN) ).
cpp_pf_tparam_name(X, _, XN) :- \+ sub_atom(X, 0, 1, _, '$'), XN = X.
cpp_pf_has_auto(base(_, [auto])) :- !.
cpp_pf_has_auto(T) :- compound(T), T =.. [_|As], member(A, As), cpp_pf_has_auto(A), !.
%% a template argument: a type canonical, a pack `<int, double>', a value -- in a function template's with its type's
%% suffix (`4U', `-3L'), a character as itself (`'c''), a bool as `true'
cpp_pf_arg(K, pack(L), IT, S) :- !, is_list(L), ( compound(K), K = vpack(EK) -> true ; EK = any ), findall(E, ( member(A, L), cpp_pf_arg(EK, A, IT, E) ), Es), atomic_list_concat(Es, ', ', In), atomic_list_concat(['<', In, '>'], S).
cpp_pf_arg(_, tname(X), _, S) :- !, ( atom(X) -> cpp_pf_ns_name(X, tmpl, S) ; X = mt(C, N), cpp_pf_class(C, CS), atomic_list_concat([CS, '::', N], S) ).
cpp_pf_arg(_, bool(B), _, B) :- !.
cpp_pf_arg(K, A, IT, S) :- cpp_pf_int_of(A, I), !,
    (   compound(K), cpp_has_auto(K), cpp_pf_lit_type(A, LT) -> cpp_pf_value(LT, I, yes, S)       % a placeholder's value by its own type, the type shown (0.199: `S<5U>', `[N = (short)9]')
    ;   \+ cpp_pf_plain_kind(K), cpp_pf_lit_type(A, LT) -> cpp_pf_value(LT, I, IT, S)             % a parameter of a dependent type (`T V') by the argument's own
    ;   cpp_pf_value(K, I, IT, S) ).
cpp_pf_arg(_, A, _, S) :- cpp_is_type(A), !, cpp_pf_type(c, A, S).
cpp_pf_arg(_, A, _, S) :- term_to_atom(A, S).
cpp_pf_int_of(I, I) :- integer(I), !.
cpp_pf_int_of(cast(base(_, _), X), I) :- !, cpp_pf_int_of(X, I).   % a typed value argument's cast (0.199: `long long', `short', `char8_t')
cpp_pf_int_of(V, I) :- compound(V), functor(V, F, 1), memberchk(F, [int, uint, long, ulong, chr, wchr, u16chr, u32chr]), arg(1, V, I), integer(I).
%% a parameter whose type is a plain arithmetic one, resolved
cpp_pf_plain_kind(K) :- compound(K), catch(ccl_resolve_type(K, R), _, fail), R = base(_, Sp), \+ ( member(X, Sp), compound(X) ).
%% a value literal's own type
cpp_pf_lit_type(cast(T, _), T) :- !.
cpp_pf_lit_type(I, base([], [int])) :- integer(I), !.
cpp_pf_lit_type(A, base([], Sp)) :- compound(A), functor(A, F, 1), cpp_pf_lit_specs(F, Sp).
cpp_pf_lit_specs(int, [int]).
cpp_pf_lit_specs(uint, [unsigned]).
cpp_pf_lit_specs(long, [long]).
cpp_pf_lit_specs(ulong, [unsigned, long]).
cpp_pf_lit_specs(chr, [char]).
cpp_pf_lit_specs(wchr, [wchar_t]).
cpp_pf_lit_specs(u16chr, [char16_t]).
cpp_pf_lit_specs(u32chr, [char32_t]).
%% A VALUE ARGUMENT AS CLANG PRINTS IT (clang's printIntegral; 0.199): a bool `true'; a character type as a character
%% literal, its prefix (`L', `u8', `u', `U') and C's escapes (`'\n'', `'\x00'', `'\''), a signed or an unsigned char
%% cast where the type is shown (`(unsigned char)'B''); where the type is shown -- a function template's arguments, a
%% placeholder's -- `5U', `5L', `5UL', `5LL', `5ULL', an int as its number and another type cast (`(short)9'); else the
%% number. An enumeration's value is the enumerator of that value, qualified as the source names it (`Color::Green', `P1',
%% `ns::K::b'), else its number cast to the enum, `(Color)7' (0.203; it was the number).
cpp_pf_value(K, I, _, S) :- compound(K), cpp_enum_type(K), catch(ccl_resolve_type(K, base(_, [E])), _, fail), compound(E), arg(1, E, Tag), atom(Tag), Tag \== anon, cpp_pf_class(Tag, EN), !,
    ( ccl_tag(Tag, Es), is_list(Es), member(enumerator(N, _), Es), atom(N), cpp_enum_value(Tag, N, V), V =:= I -> cpp_pf_enumerator(Tag, EN, N, S) ; atomic_list_concat(['(', EN, ')', I], S) ).
cpp_pf_value(K, I, IT, S) :- ( compound(K), catch(ccl_resolve_type(K, R), _, fail), R = base(_, Sp), \+ ( member(X, Sp), compound(X) ) -> cpp_canon_specs(Sp, Cs) ; Cs = none ),
    cpp_pf_value_(Cs, I, IT, S), !.
cpp_pf_value_([bool], I, _, S) :- !, ( I =:= 0 -> S = false ; S = true ).
cpp_pf_value_(Cs, I, IT, S) :- cpp_pf_char_kind(Cs, Pfx, Cast), !, cpp_pf_char_lit(Cs, I, L), ( IT == yes -> atomic_list_concat([Cast, Pfx, L], S) ; atom_concat(Pfx, L, S) ).
cpp_pf_value_(Cs, I, yes, S) :- cpp_pf_int_suffix(Cs, Sfx), !, atomic_list_concat([I, Sfx], S).
cpp_pf_value_([int], I, _, S) :- !, atomic_list_concat([I], S).
cpp_pf_value_(Cs, I, yes, S) :- Cs \== none, forall(member(W, Cs), atom(W)), !, atomic_list_concat(Cs, ' ', TS), atomic_list_concat(['(', TS, ')', I], S).
cpp_pf_value_(_, I, _, S) :- atomic_list_concat([I], S).
cpp_pf_enumerator(Tag, EN, N, S) :- ( ccl_scoped_enum(Tag) -> atomic_list_concat([EN, '::', N], S) ; atomic_list_concat(Ps, '::', EN), append(Pre, [_], Ps), Pre \== [] -> append(Pre, [N], Ps1), atomic_list_concat(Ps1, '::', S) ; S = N ).
cpp_pf_int_suffix([unsigned], 'U').
cpp_pf_int_suffix([long], 'L').
cpp_pf_int_suffix([unsigned, long], 'UL').
cpp_pf_int_suffix([long, long], 'LL').
cpp_pf_int_suffix([unsigned, long, long], 'ULL').
cpp_pf_char_kind([char], '', '').
cpp_pf_char_kind([signed, char], '', '(signed char)').
cpp_pf_char_kind([unsigned, char], '', '(unsigned char)').
cpp_pf_char_kind([wchar_t], 'L', '').
cpp_pf_char_kind([char8_t], u8, '').
cpp_pf_char_kind([char16_t], u, '').
cpp_pf_char_kind([char32_t], 'U', '').
%% clang's CharacterLiteral::print: a narrow character's value taken as its byte, C's single escapes, a printable ASCII
%% character as itself, else `\xNN', `\uNNNN' or `\UNNNNNNNN' in lowercase hex
cpp_pf_char_lit(Cs, I0, L) :- ( memberchk(Cs, [[char], [signed, char], [unsigned, char]]) -> I is I0 /\ 255 ; I0 < 0 -> I is I0 + 4294967296 ; I = I0 ),
    (   cpp_pf_char_esc(I, E) -> true
    ;   I >= 32, I =< 126 -> char_code(E, I)
    ;   I < 256 -> cpp_pf_hex(I, 2, H), atom_concat('\\x', H, E)
    ;   I =< 65535 -> cpp_pf_hex(I, 4, H), atom_concat('\\u', H, E)
    ;   cpp_pf_hex(I, 8, H), atom_concat('\\U', H, E) ),
    atomic_list_concat(['\'', E, '\''], L).
cpp_pf_char_esc(92, '\\\\').
cpp_pf_char_esc(39, '\\\'').
cpp_pf_char_esc(7, '\\a').
cpp_pf_char_esc(8, '\\b').
cpp_pf_char_esc(12, '\\f').
cpp_pf_char_esc(10, '\\n').
cpp_pf_char_esc(13, '\\r').
cpp_pf_char_esc(9, '\\t').
cpp_pf_char_esc(11, '\\v').
%% I's lowercase hex digits, zeros before them up to W
cpp_pf_hex(I, W, H) :- cpp_pf_hexds(I, Ds), length(Ds, N), cpp_pf_hex_pad(N, W, Ds, Cs), atom_codes(H, Cs).
cpp_pf_hexds(I, [D]) :- I < 16, !, cpp_pf_hexd(I, D).
cpp_pf_hexds(I, Ds) :- Q is I >> 4, R is I /\ 15, cpp_pf_hexds(Q, Ds0), cpp_pf_hexd(R, D), append(Ds0, [D], Ds).
cpp_pf_hexd(V, D) :- ( V < 10 -> D is 0'0 + V ; D is 0'a + V - 10 ).
cpp_pf_hex_pad(N, W, Ds, Ds) :- N >= W, !.
cpp_pf_hex_pad(N, W, Ds, [0'0|Cs]) :- N1 is N + 1, cpp_pf_hex_pad(N1, W, Ds, Cs).
%% a class template instance's member is printed with its PATTERN's result and parameters, as clang prints them: the
%% class's member of that name, arity and constness in the specialization or the primary the instance was made from
cpp_pf_pattern(C, Src, Qs, _, Ps0, Ret, Ps) :- atom(C), '$cpp_inst'(C, inst(N, Args)), atom(N), is_list(Args),
    ( catch(cpp_pick_spec(N, Args, _, SI), _, fail), cpp_template_defined(SI) -> I = SI ; catch(cpp_class_template(N, Args, _, I), _, fail) ),
    cpp_instance_class(I, _, _, _, Ms), length(Ps0, A), ( memberchk(const, Qs) -> K = yes ; K = no ), cpp_pf_member_of(Ms, Src, A, K, Ret, Ps), !.
cpp_pf_pattern(_, _, _, Ret, Ps, Ret, Ps).
cpp_pf_member_of(Ms, '$ctor', A, _, none, Ps) :- !, member(ctor(_, _, Ps, _, _), Ms), length(Ps, A), !.
cpp_pf_member_of(Ms, M, A, K, Ret, Ps) :- member(X, Ms), ( X = method(_, MQs, Ret, M, Ps, _, _) ; X = template(_, _, method(_, MQs, Ret, M, Ps, _, _)) ), length(Ps, A),
    ( memberchk(const, MQs) -> K = yes ; K = no ), !.
%% the parameters, `(int, const char *, ...)': an array or a function as the pointer it decays to
cpp_pf_params(Ps, V0, B, PT) :- cpp_fn_q(V0, V, Qs), cpp_pf_param_list(Ps, B, Ss), ( V == true -> append(Ss, ['...'], Ss1) ; Ss1 = Ss ), atomic_list_concat(Ss1, ', ', In),
    findall(W, ( member(Q, Qs), atom_concat(' ', Q, W) ), Ws), atomic_list_concat(['(', In, ')'|Ws], PT).   % a member function type's qualifiers after its parameters (0.181), clang's `int (A::*)(int) const &'
cpp_pf_param_list([], _, []).
cpp_pf_param_list([P|Ps], B, [S|Ss]) :- ( compound(P), arg(1, P, T0), cpp_pf_param_type(T0, T), catch(cpp_pf_type(w(B), T, S0), _, fail) -> S = S0 ; S = '?' ), cpp_pf_param_list(Ps, B, Ss).
cpp_pf_param_type(this(T), T) :- !.
cpp_pf_param_type(arr(_, E), ptr([], E)) :- !.
cpp_pf_param_type(fn(R, Ps, V), ptr([], fn(R, Ps, V))) :- !.
cpp_pf_param_type(T, T).
%% A TYPE, as a declarator around nothing: `int *', `const char *const', `int (*)(int)', `int (&)[3]', `void (K::*)(int)';
%% written (w(Bindings): the names as written, a bound template parameter its argument) or canonical (c)
cpp_pf_type(M, T, S) :- cpp_pf_decl(M, T, '', S).
cpp_pf_decl(M, ptr(Q, T), In, S) :- !, cpp_pf_cv(Q, QS), cpp_pf_join_q('*', QS, In, I1), cpp_pf_paren(T, I1, I2), cpp_pf_decl(M, T, I2, S).
cpp_pf_decl(M, ref(_, T), In, S) :- !, atom_concat('&', In, I1), cpp_pf_paren(T, I1, I2), cpp_pf_decl(M, T, I2, S).
cpp_pf_decl(M, rref(_, T), In, S) :- !, atom_concat('&&', In, I1), cpp_pf_paren(T, I1, I2), cpp_pf_decl(M, T, I2, S).
cpp_pf_decl(M, memptr(C, Q, T), In, S) :- !, cpp_pf_tname(M, C, CS), cpp_pf_cv(Q, QS), atom_concat(CS, '::*', P0), cpp_pf_join_q(P0, QS, In, I1), cpp_pf_paren(T, I1, I2), cpp_pf_decl(M, T, I2, S).
cpp_pf_decl(M, arr(N, T), In, S) :- !, ( integer(N) -> NS = N ; catch(ccl_const_eval(N, NV), _, fail), integer(NV) -> NS = NV ; NS = '' ), atomic_list_concat([In, '[', NS, ']'], I1), cpp_pf_decl(M, T, I1, S).
cpp_pf_decl(M, fn(R, Ps, V), In, S) :- !, ( M = w(B) -> true ; B = [] ), cpp_pf_params(Ps, V, B, PT), atom_concat(In, PT, I1), cpp_pf_decl(M, R, I1, S).
cpp_pf_decl(M, pack(T), In, S) :- !, cpp_pf_decl(M, T, In, S0), atom_concat(S0, '...', S).
cpp_pf_decl(M, base(Q, Sp), In, S) :- !, cpp_pf_base(M, Q, Sp, B0), ( In == '' -> S = B0 ; atomic_list_concat([B0, ' ', In], S) ).
cpp_pf_decl(_, T, In, S) :- atom(T), ( In == '' -> S = T ; atomic_list_concat([T, ' ', In], S) ).
cpp_pf_join_q(P, QS, In, I) :- ( QS \== '', In \== '' -> atomic_list_concat([P, QS, ' ', In], I) ; atomic_list_concat([P, QS, In], I) ).
cpp_pf_paren(T, I, I2) :- ( compound(T), ( functor(T, fn, 3) ; functor(T, arr, 2) ) -> atomic_list_concat(['(', I, ')'], I2) ; I2 = I ).
cpp_pf_cv(Q, S) :- findall(W, ( member(W, [const, volatile]), memberchk(W, Q) ), Ws), atomic_list_concat(Ws, ' ', S).
cpp_pf_base(M, Q, Sp, S) :- cpp_pf_cv(Q, QS), cpp_pf_specs(M, Q, Sp, SS), ( QS == '' -> S = SS ; atomic_list_concat([QS, ' ', SS], S) ).
cpp_pf_specs(_, Q, [auto], S) :- !, ( memberchk(decltype_auto, Q) -> S = 'decltype(auto)' ; memberchk(constrained(C, _), Q), atom(C) -> atom_concat(C, ' auto', S) ; S = auto ).
cpp_pf_specs(M, _, [typedef(X)], S) :- !, cpp_pf_tname(M, X, S).
cpp_pf_specs(M, _, [X], S) :- compound(X), functor(X, F, _), memberchk(F, [struct, union, class, enum, enum_class]), cpp_pf_tag_name(X, N), !,
    ( M == c -> cpp_pf_class(N, S) ; ccl_lang(cpp), catch(cpp_class_l(N, _), _, fail) -> cpp_pf_class(N, S) ; cpp_pf_tag_kw(F, Kw), atomic_list_concat([Kw, ' ', N], S) ).
cpp_pf_specs(_, _, [bitint(N0)], S) :- ( cpp_pf_int_of(N0, N) -> true ; N = N0 ), !, atomic_list_concat(['_BitInt(', N, ')'], S).
cpp_pf_specs(_, _, [unsigned, bitint(N0)], S) :- ( cpp_pf_int_of(N0, N) -> true ; N = N0 ), !, atomic_list_concat(['unsigned _BitInt(', N, ')'], S).
cpp_pf_specs(_, _, Sp, S) :- forall(member(W, Sp), atom(W)), !, ( cpp_int_spelling(Sp, Cs) -> ( Cs == [unsigned] -> S = 'unsigned int' ; atomic_list_concat(Cs, ' ', S) ) ; cpp_pf_words(Sp, S) ).
cpp_pf_specs(_, Q, Sp, S) :- catch(cpp_type(base(Q, Sp), R), _, fail), R = base(_, Sp1), Sp1 \== Sp, !, cpp_pf_specs(c, [], Sp1, S).
cpp_pf_specs(_, _, _, '?').
cpp_pf_tag_name(X, N) :- ( X = class(_, N, _, _) -> true ; arg(1, X, N) ), atom(N).
cpp_pf_tag_kw(struct, struct).
cpp_pf_tag_kw(class, struct).
cpp_pf_tag_kw(union, union).
cpp_pf_tag_kw(enum, enum).
cpp_pf_tag_kw(enum_class, enum).
%% the other builtin types, as clang names them
cpp_pf_words(Sp, S) :- msort(Sp, Ss), ( cpp_pf_words_(Ss, S0) -> S = S0 ; atomic_list_concat(Sp, ' ', S) ).
cpp_pf_words_([double, long], 'long double').
cpp_pf_words_(['_Complex', double], '_Complex double').
cpp_pf_words_(['_Complex', float], '_Complex float').
cpp_pf_words_(['_Complex', double, long], '_Complex long double').
cpp_pf_words_(['__int128', unsigned], 'unsigned __int128').
cpp_pf_words_(['__int128', signed], '__int128').
cpp_pf_words_(['_Bool'], '_Bool').
%% a name as written (`std::string', `K', `vector<int>'), a bound template parameter its argument, a class this compiler
%% made (an instance, a key `inner.f') as its source spells it
cpp_pf_tname(w(B), X, S) :- atom(X), memberchk(X-A, B), !, cpp_pf_arg(type, A, no, S).
cpp_pf_tname(_, X, S) :- atom(X), cpp_pf_made(X), !, cpp_pf_class(X, S).
cpp_pf_tname(c, X, S) :- atom(X), ccl_lang(cpp), catch(cpp_class_l(X, _), _, fail), !, cpp_pf_class(X, S).
cpp_pf_tname(_, X, S) :- atom(X), !, atomic_list_concat(Ss, '.', X), ccl_last(Ss, S).
cpp_pf_tname(M, scoped(Path, Last), S) :- !, findall(PS, ( member(P, Path), cpp_pf_seg(M, P, PS) ), PSs), cpp_pf_tname(M, Last, LS), append(PSs, [LS], All), atomic_list_concat(All, '::', S).
cpp_pf_tname(M, tmpl(N, As), S) :- !, cpp_pf_tname(M, N, NS), findall(AS, ( member(A, As), cpp_pf_targ(M, A, AS) ), ASs), atomic_list_concat(ASs, ', ', In), atomic_list_concat([NS, '<', In, '>'], S).
cpp_pf_tname(_, X, S) :- term_to_atom(X, S).
cpp_pf_seg(_, global, '') :- !.
cpp_pf_seg(M, P, S) :- cpp_pf_tname(M, P, S).
%% a class this compiler named: an instance, a closure, a local class (C has none)
cpp_pf_made(X) :- ccl_lang(cpp), ( catch('$cpp_inst'(X, inst(_, _)), _, fail) -> true ; catch('$cpp_pf_closure'(X, _, _), _, fail) -> true ; catch('$cpp_pf_local'(X, _, _), _, fail) ).
cpp_pf_targ(M, A, S) :- cpp_is_type(A), !, cpp_pf_type(M, A, S).
cpp_pf_targ(_, A, S) :- cpp_pf_int_of(A, I), !, atomic_list_concat([I], S).
cpp_pf_targ(_, bool(B), B) :- !.
cpp_pf_targ(M, pack(X), S) :- !, cpp_pf_targ(M, X, S0), atom_concat(S0, '...', S).
cpp_pf_targ(M, id(X), S) :- !, cpp_pf_tname(M, X, S).
cpp_pf_targ(_, A, S) :- term_to_atom(A, S).
%% a class: its namespaces or its holder, its own name, an instance's arguments up to the defaulted ones (`U<int>' of
%% `template <class T, unsigned N = 3>'); a lambda's and a local class's through the function that holds it
cpp_pf_class(C, S) :- '$cpp_pf_closure'(C, Encl, _), !, cpp_pf_ctx(Encl, X), atom_concat(X, '::(anonymous class)', S).
cpp_pf_class(C, S) :- '$cpp_pf_local'(C, Src, Encl), !, cpp_pf_ctx(Encl, X), atomic_list_concat([X, '::', Src], S).
cpp_pf_class(C, S) :- atom(C), '$cpp_inst'(C, inst(N, Args)), atom(N), is_list(Args), !, cpp_pf_targs_shown(N, Args, AS),
    ( '$cpp_nested_tmpl'(EC, Short, N) -> cpp_pf_class(EC, ES), atomic_list_concat([ES, '::', Short, '<', AS, '>'], S) ; cpp_pf_ns_name(N, tmpl, NN), atomic_list_concat([NN, '<', AS, '>'], S) ).
cpp_pf_class(C, S) :- atom(C), cpp_dbg_holder(C, E, Last), !, cpp_pf_class(E, ES), atomic_list_concat([ES, '::', Last], S).
cpp_pf_class(C, S) :- atom(C), !, cpp_pf_ns_name(C, cls, S).
cpp_pf_class(C, S) :- term_to_atom(C, S).
cpp_pf_class_short(C, S) :- '$cpp_pf_local'(C, S0, _), !, S = S0.
cpp_pf_class_short(C, S) :- atom(C), '$cpp_inst'(C, inst(N, _)), atom(N), !, ( '$cpp_nested_tmpl'(_, Short, N) -> S = Short ; atomic_list_concat(Ss, '.', N), ccl_last(Ss, S) ).
cpp_pf_class_short(C, S) :- atom(C), atomic_list_concat(Ss, '.', C), ccl_last(Ss, S).
cpp_pf_targs_shown(N, Args, AS) :-
    ( catch(cpp_class_template(N, Args, TPs, _), _, fail) -> true ; TPs = [] ),
    findall(TP, ( member(TP, TPs), TP = tparam(_, _, _) ), TPs1), cpp_pf_drop_defaults(TPs1, Args, Shown),
    findall(S, ( nth1(I, Shown, A), ( nth1(I, TPs1, tparam(K, _, _)) -> true ; K = any ), cpp_pf_arg(K, A, no, S) ), Ss), atomic_list_concat(Ss, ', ', AS).   % each value by its parameter's type: `X<'c', true, 5>'
%% the trailing arguments equal to their parameters' defaults, under the arguments before them, are left out
cpp_pf_drop_defaults(TPs, Args, Shown) :- length(TPs, NT), length(Args, NA),
    (   NT =:= NA, append(_, [tparam(_, _, D)], TPs), D \== none, last(Args, A),
        K is NT - 1, length(TPs0, K), append(TPs0, [_], TPs), length(As0, K), append(As0, [_], Args),
        catch(cpp_bind_targs(TPs0, As0, B0), _, fail), catch(( cpp_subst(D, B0, D1), cpp_type_or_value(D1, DV) ), _, fail), cpp_pf_same_arg(DV, A)
    ->  cpp_pf_drop_defaults(TPs0, As0, Shown)
    ;   Shown = Args ).
cpp_pf_same_arg(X, Y) :- X == Y, !.
cpp_pf_same_arg(X, Y) :- cpp_pf_int_of(X, I), cpp_pf_int_of(Y, J), !, I =:= J.
cpp_pf_same_arg(X, Y) :- cpp_is_type(X), cpp_is_type(Y), catch(cpp_same_type(X, Y), _, fail).
%% a namespace's name and the name in it: the program's own (`'$cpp_own_ns''), a header's (an inline namespace left out);
%% a key `inner.f' is the `f' of the namespace that ends in `inner'
cpp_pf_ns_name(N, K, S) :- atomic_list_concat(Segs, '.', N), ccl_last(Segs, Short), cpp_pf_ns_path(N, Segs, Short, K, P0), cpp_pf_anon(P0, P), append(P, [Short], All), atomic_list_concat(All, '::', S).
%% an unnamed namespace's segment spelled as clang spells it in a function's description, `(anonymous namespace)' (0.192)
cpp_pf_anon([], []).
cpp_pf_anon([S0|Ss0], [S|Ss]) :- ( cpp_anon_seg(S0) -> S = '(anonymous namespace)' ; S = S0 ), cpp_pf_anon(Ss0, Ss).
cpp_pf_ns_path(N, _, _, _, P) :- catch('$cpp_own_ns'(N, P), _, fail), !.
cpp_pf_ns_path(_, Segs, Short, _, P) :- Segs = [_, _|_], append(Pre, [Short], Segs), catch('$cpp_own_ns'(Short, P), _, fail), append(_, Pre, P), !.
cpp_pf_ns_path(N, _, _, K, P) :- cpp_pf_lib(K, N), ( catch('$cpp_hdr_ns'(N, P0), _, fail) -> true ; catch('$cpp_hdr_ast_ns'(N, P0), _, fail) ), is_list(P0), !, findall(X, ( member(X, P0), atom(X) ), P).
cpp_pf_ns_path(_, _, _, _, []).
%% a header's namespaces are a LIBRARY name's: the program's own `log' or `pair' at file scope is no std one
cpp_pf_lib(fn, _) :- nb_current('$cpp_in_lib', yes), !.
cpp_pf_lib(cls, C) :- catch(cpp_lib_class(C), _, fail), !.
cpp_pf_lib(tmpl, N) :- catch('$cpp_lib'(N), _, fail), !.
cpp_pf_free_name(operator(Op), S) :- !, cpp_pf_op(Op, S).
cpp_pf_free_name(Src, S) :- atom(Src), cpp_pf_ns_name(Src, fn, S).
cpp_pf_short(operator(Op), S) :- !, cpp_pf_op(Op, S).
cpp_pf_short(Src, S) :- atom(Src), atomic_list_concat(Ss, '.', Src), ccl_last(Ss, S).
cpp_pf_op(conv(T), S) :- !, cpp_pf_type(w([]), T, TS), atom_concat('operator ', TS, S).
cpp_pf_op(literal(Sfx), S) :- !, atom_concat('operator""', Sfx, S).
cpp_pf_op(Op, S) :- memberchk(Op, [new, delete, co_await]), !, atom_concat('operator ', Op, S).
cpp_pf_op(Op, S) :- atom_concat(operator, Op, S).
%% A SOURCE LOCATION ([support.srcloc.cons]): `__builtin_source_location()' is the address of a constant of libc++'s
%% `source_location::__impl' -- the file named as the compiler was given it, the function's signature, the line and the
%% column -- one per place (`'$cpp_srcloc''). The place is the call whose default argument the builtin is, the OUTERMOST
%% one ('$cpp_dflt_site', set where cpp_fill_defaults fills a default and none is being filled): `log("x")' over `void
%% log(const char *, std::source_location = std::source_location::current())' is the place of `log', as clang has it.
%% The column is found in the line's text: the first whole-word callee, back over its qualifier (`std::') or its object
%% (`a.', `p->'), else the line's first character that is no blank; a statement that goes on past its line is followed
%% to the line where the callee is.
cpp_srcloc(addr(id(G))) :-
    cpp_srcloc_type(IT), cpp_fsig_text(pretty, Fn), cpp_srcloc_here(none, File, Line, Col),
    Key = loc(File, Line, Col, Fn),
    (   '$cpp_srcloc'(K0, G0), K0 == Key -> G = G0
    ;   ccl_gensym('$srcloc', G), assertz('$cpp_srcloc'(Key, G)), atom_codes(File, FCs), atom_codes(Fn, NCs),
        T = base([const], IT), ccl_gdeclare([G-T]),
        cpp_add_instance_items([declaration(0, static, T, [var(G, T, init([item([], str(FCs)), item([], str(NCs)), item([], uint(Line)), item([], uint(Col))]))])]) ).
%% the place: in a default argument the outermost call's, its callee's spelling found on its line; else the statement's
%% line and Own, a token to find there (none: the line's first character that is no blank)
cpp_srcloc_here(Own, File, Line, Col) :-
    ( nb_current('$cpp_dflt_site', site(L0, SN)) -> cpp_srcloc_token(SN, Tok) ; ( nb_current('$cpp_line', L0) -> true ; L0 = 0 ), Tok = Own ),
    ( nb_current('$ccl_src_file', File), atom(File) -> true ; File = '' ),
    cpp_srcloc_place(File, L0, Tok, Line, Col).
%% CLANG'S SOURCE-LOCATION BUILTINS (0.201): `__builtin_FILE()', `__builtin_FILE_NAME()' (its base name), `__builtin_LINE()',
%% `__builtin_COLUMN()' and `__builtin_FUNCTION()' (the function's name, `__func__''s) answer the place a source location has --
%% in a default argument the outermost call's, else their own, the builtin's name found in its line's text -- a file and a
%% function as a `const char *' prvalue, a line and a column as an `unsigned int', as clang types them. glibc's `<assert.h>'
%% writes `assert' on the first two in C++, where `__has_builtin(__builtin_FILE)' (`__ASSERT_FILE', `__ASSERT_LINE'), and every
%% `assert' of a C++ program was refused, `undeclared('__builtin_FILE')'. In C the lowering answers them (ir_call/4).
%% `srcbuiltins.cpp', `cwrap.cpp'.
cpp_srcloc_builtin('__builtin_FILE', file).
cpp_srcloc_builtin('__builtin_FILE_NAME', file_name).
cpp_srcloc_builtin('__builtin_LINE', line).
cpp_srcloc_builtin('__builtin_COLUMN', column).
cpp_srcloc_builtin('__builtin_FUNCTION', function).
cpp_srcloc_value(K, B, E) :- cpp_srcloc_here(tok(B, call), File, Line, Col), cpp_srcloc_answer(K, File, Line, Col, E).
cpp_srcloc_answer(file, File, _, _, E) :- !, cpp_cstr_value(File, E).
cpp_srcloc_answer(file_name, File, _, _, E) :- !, atomic_list_concat(Parts, '/', File), last(Parts, Base), cpp_cstr_value(Base, E).
cpp_srcloc_answer(line, _, Line, _, uint(Line)) :- !.
cpp_srcloc_answer(column, _, _, Col, uint(Col)) :- !.
cpp_srcloc_answer(function, _, _, _, E) :- cpp_fsig_text(func, F), cpp_cstr_value(F, E).
cpp_cstr_value(A, cast(ptr([], base([const], [char])), str(Cs))) :- ccl_atom_bytes(A, Cs).   % a `const char *' prvalue of a text's bytes
%% the type the builtin answers, `const std::source_location::__impl *', for a decltype too
cpp_srcloc_ptr_type(ptr([], base([const], IT))) :- cpp_srcloc_type(IT).
cpp_srcloc_type(Sp) :- catch(cpp_type(base([], [typedef(scoped([source_location], '__impl'))]), base(_, Sp)), _, fail), !.
cpp_srcloc_type([typedef('source_location.__impl')]).
%% the callee a default is filled for, by its name: the token its call is spelled by, and whether it constructs
cpp_srcloc_token(Name, tok(T, K)) :- catch(cpp_dbg_fn(Name, Src), _, fail), cpp_srcloc_src(Src, T0, K), atom(T0), !,
    ( sub_atom(T0, B, _, _, '<') -> sub_atom(T0, 0, B, _, T) ; T = T0 ).
cpp_srcloc_token(Name, tok(T, call)) :- atom(Name), atomic_list_concat([T|_], '.', Name), T \== '', !.
cpp_srcloc_token(_, none).
cpp_srcloc_src(member(C, M), M, K) :- !, ( catch(cpp_pf_class_short(C, M), _, fail) -> K = ctor ; K = call ).
cpp_srcloc_src(free(_, F), F, call).
cpp_srcloc_place(File, L0, tok(T, K), Line, Col) :- File \== '', integer(L0), L0 > 0, atom(T), cpp_srcloc_find(File, L0, T, K, 0, Line, Col), !.
cpp_srcloc_place(File, L0, _, L0, Col) :- ( File \== '', integer(L0), cpp_src_line(File, L0, Text), atom_codes(Text, Cs), cpp_srcloc_nonblank(Cs, 0, P) -> Col is P + 1 ; Col = 1 ).
cpp_srcloc_find(File, L, T, K, N, Line, Col) :- N =< 20, cpp_src_line(File, L, Text), atom_codes(Text, Cs),
    (   atom_codes(T, TCs), cpp_srcloc_word(Cs, TCs, 0, P) -> cpp_srcloc_at(K, Cs, P, TCs, P1), Line = L, Col is P1 + 1
    ;   \+ memberchk(59, Cs), L1 is L + 1, N1 is N + 1, cpp_srcloc_find(File, L1, T, K, N1, Line, Col) ).
%% a constructor's place in a declaration is its declarator's, `a' of `Lg a(1);', as clang has it; any other call's
%% begins where its callee's spelling does
cpp_srcloc_at(ctor, Cs, P, TCs, P1) :- length(TCs, TL), Q is P + TL, length(Pre, Q), append(Pre, After, Cs), cpp_srcloc_blanks(After, A1),
    A1 = [C|_], cpp_srcloc_idc(C), \+ ( C >= 0'0, C =< 0'9 ), cpp_srcloc_ident(A1, A2), cpp_srcloc_blanks(A2, [D|_]), memberchk(D, [0'(, 0'{, 59]), !,
    length(A1, LA1), length(Cs, LC), P1 is LC - LA1.
cpp_srcloc_at(_, Cs, P, _, P1) :- cpp_srcloc_left(Cs, P, P1).
%% the first place of the word Tok in a line's codes, bounded by no identifier character on either side
cpp_srcloc_word(Cs, TCs, P0, P) :- append(Pre, Rest, Cs), append(TCs, After, Rest), length(Pre, P1), P1 >= P0,
    ( Pre == [] -> true ; last(Pre, B), \+ cpp_srcloc_idc(B) ), ( After = [A|_] -> \+ cpp_srcloc_idc(A) ; true ), !, P = P1.
cpp_srcloc_idc(C) :- ( C >= 0'a, C =< 0'z ; C >= 0'A, C =< 0'Z ; C >= 0'0, C =< 0'9 ; C =:= 0'_ ), !.
cpp_srcloc_nonblank([C|Cs], P0, P) :- ( C =:= 0'  ; C =:= 9 ) -> P1 is P0 + 1, cpp_srcloc_nonblank(Cs, P1, P) ; P = P0.
%% back over what spells the callee before its name: `std::source_location::' and a template-id's `<...>', `::' alone,
%% an object `a.' or `p->' and what it is made of (names, calls, subscripts, `(*p)')
cpp_srcloc_left(Cs, P, S) :- length(Pre, P), append(Pre, _, Cs), reverse(Pre, R), cpp_srcloc_back(R, R1), length(R1, S).
cpp_srcloc_back(R, R1) :- cpp_srcloc_blanks(R, Ra),
    (   Ra = [0':, 0':|Rb] -> cpp_srcloc_blanks(Rb, Rc), ( cpp_srcloc_operand(Rc, Rd) -> cpp_srcloc_back(Rd, R1) ; R1 = Rb )
    ;   Ra = [0'.|Rb] -> cpp_srcloc_blanks(Rb, Rc), ( cpp_srcloc_operand(Rc, Rd) -> cpp_srcloc_back(Rd, R1) ; R1 = R )
    ;   Ra = [0'>, 0'-|Rb] -> cpp_srcloc_blanks(Rb, Rc), ( cpp_srcloc_operand(Rc, Rd) -> cpp_srcloc_back(Rd, R1) ; R1 = R )
    ;   R1 = R ).
cpp_srcloc_blanks([C|Cs], R) :- ( C =:= 0'  ; C =:= 9 ), !, cpp_srcloc_blanks(Cs, R).
cpp_srcloc_blanks(R, R).
%% one operand, read backward: a name (a template-id's `<...>' before it), a balanced `(...)' or `[...]' and what precedes it
cpp_srcloc_operand([C|Cs], R) :- ( C =:= 0') ; C =:= 0'] ; C =:= 0'> ), !, ( C =:= 0') -> O = 0'( ; C =:= 0'] -> O = 0'[ ; O = 0'< ), cpp_srcloc_close(Cs, C, O, 1, R0),
    ( cpp_srcloc_blanks(R0, R1), cpp_srcloc_operand(R1, R2) -> R = R2 ; R = R0 ).
cpp_srcloc_operand([C|Cs], R) :- cpp_srcloc_idc(C), cpp_srcloc_ident(Cs, R).
cpp_srcloc_ident([C|Cs], R) :- cpp_srcloc_idc(C), !, cpp_srcloc_ident(Cs, R).
cpp_srcloc_ident(R, R).
cpp_srcloc_close([], _, _, _, []).
cpp_srcloc_close([C|Cs], Cl, O, D, R) :- ( C =:= O -> D1 is D - 1, ( D1 =:= 0 -> R = Cs ; cpp_srcloc_close(Cs, Cl, O, D1, R) ) ; C =:= Cl -> D1 is D + 1, cpp_srcloc_close(Cs, Cl, O, D1, R) ; cpp_srcloc_close(Cs, Cl, O, D, R) ).
%% a line of the file the compiler was given, read once
cpp_src_line(File, L, Text) :- ( nb_current('$cpp_srcf', File) -> true ; cpp_src_load(File) ), atom_concat('$cpp_srcl:', L, K), nb_current(K, Text).
cpp_src_load(File) :- nb_setval('$cpp_srcf', File),
    ( catch(read_file_to_codes(File, Cs), _, fail) -> atom_codes(A, Cs), atomic_list_concat(Ls, '\n', A), cpp_src_note(Ls, 1) ; true ).
cpp_src_note([], _).
cpp_src_note([T|Ts], N) :- atom_concat('$cpp_srcl:', N, K), nb_setval(K, T), N1 is N + 1, cpp_src_note(Ts, N1).
