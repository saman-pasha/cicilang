%% ccl_cpp_traits.pl -- the compiler's traits, decided here: __is_same and the other type traits, the trivial and
%% nothrow ones, offsetof. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there,
%% in their order.

%% ---- the compiler's traits, decided here ----------------------------------------------------
cpp_trait('__is_same', [A, B], bool(V)) :- !, cpp_trait_type(A, TA), cpp_trait_type(B, TB), ( cpp_same_type(TA, TB) -> V = true ; V = false ).
cpp_trait(N, _, bool(false)) :- memberchk(N, ['__reference_constructs_from_temporary', '__reference_converts_from_temporary', '__reference_binds_to_temporary']), !.   % no reference binds a temporary here that C++ would refuse (optional<T &>'s guards)
cpp_trait(N, _, bool(false)) :- memberchk(N, ['__builtin_lt_synthesizes_from_spaceship', '__builtin_le_synthesizes_from_spaceship', '__builtin_gt_synthesizes_from_spaceship', '__builtin_ge_synthesizes_from_spaceship']), !.   % no operator<=> synthesizes a comparison here (0.42: a class's is refused by name)
%% offsetof: the byte offset the layout already computes (libc++ finds a type's data size with it -- the offset of a
%% char member placed after it)
cpp_trait('__builtin_offsetof', [A, M], int(Off)) :- !, cpp_trait_type(A, T), cpp_offset_path(M, Path), cpp_offsetof(T, Path, 0, Off).
%% `__builtin_bit_cast(T, e)' ([bit.cast]; 0.117): the object representation of e read as a T -- a local of T filled by `memcpy' from a local copy of
%% e, the value of the statement expression. <bit>'s `std::bit_cast' is `return __builtin_bit_cast(_ToType, __from);'. It was `trait_unknown'.
cpp_trait('__builtin_bit_cast', [type(T0), X], stmt_expr(block([declaration(0, none, T, [var(R, T, none)]), declaration(0, none, ST, [var(S, ST, X)]),
        expr(0, call(id(memcpy), [addr(id(R)), addr(id(S)), sizeof_type(T)])), expr(0, id(R))]))) :- !,
    cpp_type(T0, T), cpp_arg_type(X, AT), ccl_unref(AT, AT1), cpp_strip_quals(AT1, _, ST),
    ccl_gensym('$bcr', R), ccl_gensym('$bcs', S), ccl_declare(R, T), ccl_declare(S, ST).
%% `__datasizeof(T)', clang's builtin (0.112): the Itanium ABI's dsize, the LAYOUT'S OWN data size since 0.135 (ccl_data_size/2) -- a
%% POD's whole size, else the byte where its last data member ends, its tail padding left out (an empty class that is no POD 0, as
%% clang has it). The test of a POD is the layout's (cpp_layout_pod/7), so what libc++ copies by it (`__libcpp_datasizeof<T>::value'
%% in `__constexpr_memmove') and what libc++ 21 pads a compressed pair with are the bytes the layout lends. `datasizeof.cpp'.
cpp_trait('__datasizeof', [A], int(N)) :- !, cpp_trait_type(A, T), ccl_resolve_type(T, R), ccl_data_size(R, N).
cpp_trait('__array_rank', [A], int(N)) :- !, cpp_trait_type(A, T), ccl_resolve_type(T, R), cpp_array_rank(R, N).   % [meta.unary.prop.query] (0.167): an array's rank, 0 for any other type -- libc++'s `rank_v' and `extent_v' are the builtins where clang has them, and a literal's type is an array now
cpp_trait('__array_extent', [A, D], int(N)) :- !, cpp_trait_type(A, T), ccl_resolve_type(T, R), ( cpp_trait_dim(D, I) -> true ; I = 0 ), cpp_array_extent(R, I, N).   % the extent of its I-th dimension, 0 past its rank or for an unbounded one
cpp_trait(N, [A], bool(V)) :- cpp_trait_type(A, T), ccl_resolve_type(T, R), cpp_trait_of(N, R, V), !.
cpp_trait(N, [A|As], bool(V)) :- cpp_trait_types([A|As], [T|Ts]), cpp_trait_n(N, T, Ts, V), !.
cpp_trait(N, _, _) :- cpp_refuse(0, trait_unknown(N)).
cpp_trait_dim(type(base(_, [typedef(X)])), I) :- !, atom(X), catch(cpp_const_value(id(X), I), _, fail).
cpp_trait_dim(type(_), _) :- !, fail.
cpp_trait_dim(E, I) :- catch(cpp_const_value(E, I), _, fail).
cpp_array_rank(arr(_, E), N) :- !, ccl_resolve_type(E, R), cpp_array_rank(R, N0), N is N0 + 1.
cpp_array_rank(_, 0).
cpp_array_extent(arr(K, _), 0, N) :- !, ( K \== none, catch(once(ccl_const_eval(K, N0)), _, fail), integer(N0) -> N = N0 ; N = 0 ).
cpp_array_extent(arr(_, E), I, N) :- I > 0, !, I1 is I - 1, ccl_resolve_type(E, R), cpp_array_extent(R, I1, N).
cpp_array_extent(_, _, 0).
cpp_offset_path(id(N), [N]) :- !.
cpp_offset_path(member(X, N), Path) :- !, cpp_offset_path(X, P0), append(P0, [N], Path).
cpp_offset_path(arrow(X, N), Path) :- !, cpp_offset_path(X, P0), append(P0, [N], Path).
cpp_offset_path(index(X, _), Path) :- !, cpp_offset_path(X, Path).
cpp_offset_path(X, _) :- cpp_refuse(0, offsetof_path(X)).
cpp_offsetof(_, [], Off, Off) :- !.
cpp_offsetof(T, [N|Ns], Acc, Off) :-
    ccl_members_of(T, Ms1), ( ccl_members_of_(T, Ms) -> true ; Ms = Ms1 ), ccl_members_layout(Ms, Lays, _, _), memberchk(lay(N, MT, MOff, _), Lays), !,   % the layout over the tag's own list, its markers in (0.199: an empty base's place)
    Acc1 is Acc + MOff, cpp_offsetof(MT, Ns, Acc1, Off).
cpp_offsetof(T, [N|_], _, _) :- cpp_refuse(0, no_member(N, T)).
cpp_trait_types([], []).
cpp_trait_types([A|As], [T|Ts]) :- cpp_trait_type(A, T), cpp_trait_types(As, Ts).
%% the traits over two or more types, decided over the registry: a scalar constructs from and converts to what
%% C++ converts, a class through its constructors, its conversion operators, its bases; the trivial ones ask for no
%% user-written special member, and the NOTHROW ones answer the declarations (0.193, below)
cpp_trait_n('__is_constructible', T, Args, V) :- !, ( cpp_constructible(T, Args) -> V = true ; V = false ).
cpp_trait_n('__is_nothrow_constructible', T, Args, V) :- !, ( cpp_constructible(T, Args), cpp_nothrow_q(cpp_nothrow_ctor(T, Args)) -> V = true ; V = false ).
cpp_trait_n('__is_trivially_constructible', T, Args, V) :- !, ( cpp_constructible(T, Args), cpp_trivial_type(T) -> V = true ; V = false ).
cpp_trait_n('__is_assignable', T, [F], V) :- !, ( cpp_assignable(T, F) -> V = true ; V = false ).
cpp_trait_n('__is_nothrow_assignable', T, [F], V) :- !, ( cpp_assignable(T, F), cpp_nothrow_q(cpp_nothrow_assign(T, F)) -> V = true ; V = false ).
cpp_trait_n('__is_trivially_assignable', T, [F], V) :- !, ( cpp_assignable(T, F), cpp_trivial_type(T) -> V = true ; V = false ).
cpp_trait_n(N, F, [T], V) :- memberchk(N, ['__is_convertible', '__is_convertible_to']), !, ( cpp_convertible(F, T) -> V = true ; V = false ).
cpp_trait_n('__is_nothrow_convertible', F, [T], V) :- !, ( cpp_convertible(F, T), cpp_nothrow_q(cpp_nothrow_ctor(T, [F])) -> V = true ; V = false ).
cpp_trait_n('__is_base_of', B, [D], V) :- !, ( cpp_base_of(B, D) -> V = true ; V = false ).
cpp_trait_n('__builtin_is_virtual_base_of', B, [D], V) :- !, ( cpp_class_of_type(B, CB), cpp_class_of_type(D, CD), cpp_vbases_of(CD, Vs), memberchk(CB, Vs) -> V = true ; V = false ).   % C++26's is_virtual_base_of, libc++ 21's over clang's builtin (0.194): B a virtual base of D, at any depth, cv-qualifiers aside
cpp_trait_n('__is_same_as', A, [B], V) :- !, ( cpp_same_type(A, B) -> V = true ; V = false ).
%% THE NOTHROW TRAITS ANSWER THE DECLARATIONS (0.193; [meta.unary.prop]: `T t(declval<Args>()...)' known not to throw;
%% [except.spec]/8, /10: an implicit or defaulted special member is noexcept where each sub-object's own is): a scalar's
%% construction and assignment never throw; a class's copy or move is its copy or move constructor's or assignment's
%% declared `noexcept' -- a move that the class does not declare beside a copy it declares is the copy ([class.copy.ctor]/8)
%% -- else the implicit one's, every data member's and base sub-object's (`$base', `$vb' ...) nothrow; its default
%% construction the declared default constructor's, else the implicit one's, the members' and their default member
%% initializers' (one that calls is taken as throwing); any other construction or assignment of the arity asked nothrow
%% where every candidate of that arity is declared `noexcept' (a constructor template among them). They were the plain
%% traits, which only libc++'s no-exceptions configuration could take: its exceptions configuration asks them in
%% `std::move_if_noexcept', and a vector grows by COPYING an element whose move constructor may throw where it has a copy.
cpp_nothrow_q(G) :- catch(once(G), error(not_lowered(_), _), true).   % a refusal met while asking: the plain trait's answer, as before
cpp_nothrow_ctor(T0, Args) :- ccl_unref(T0, T1), ( cpp_class_of_type(T1, C) -> cpp_nothrow_ctor_c(C, Args) ; true ).
cpp_nothrow_ctor_c(C, [F0]) :- ccl_unref(F0, F1), cpp_class_of_type(F1, C), !, ( F0 = ref(_, _) -> K = ref ; K = rref ), cpp_nothrow_copy(C, K).
cpp_nothrow_ctor_c(C, []) :- !, cpp_nothrow_default(C).
cpp_nothrow_ctor_c(C, Args) :- length(Args, N), cpp_class(C, cls(_, _, Ms, _, _, _)),
    findall(Qs-Ps, ( ( member(ctor(_, Qs, Ps, _, _), Ms) ; '$cpp_mt'(C, ctor, _, ctor(_, Qs, Ps, _, _)) ), cpp_arity(Ps, Min, Max), N >= Min, ( Max == any -> true ; N =< Max ) ), Qss),
    Qss \== [], forall(member(Qs-Ps, Qss), cpp_qs_nothrow(C, Qs, Ps)).   % a conditional noexcept by its condition (0.199)
cpp_nothrow_copy(C, K) :- cpp_class(C, cls(_, _, Ms, _, _, _)),
    (   member(ctor(_, Qs, [P], I, _), Ms), I \= memberwise(_, _), cpp_special_param(P, C, K) -> cpp_qs_nothrow(C, Qs, [P])
    ;   K == rref, \+ ( member(ctor(_, _, [P], _, _), Ms), cpp_special_param(P, C, rref) ), member(ctor(_, Qs, [P], I, _), Ms), I \= memberwise(_, _), cpp_special_param(P, C, ref) -> cpp_qs_nothrow(C, Qs, [P])
    ;   cpp_nothrow_parts(C, copy(K)) ).
cpp_nothrow_default(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)),
    (   member(ctor(_, Qs, Ps, I, _), Ms), I \= memberwise(_, _), cpp_params_no_args(Ps) -> cpp_qs_nothrow(C, Qs, Ps)
    ;   cpp_nothrow_parts(C, default), \+ ( cpp_class_l(C, cls(_, _, _, Ds, _)), cpp_term_mentions_functor(Ds, call) ) ).
cpp_nothrow_assign(T0, F0) :- ccl_unref(T0, T1),
    (   cpp_class_of_type(T1, C)
    ->  (   ccl_unref(F0, F1), cpp_class_of_type(F1, C) -> ( F0 = ref(_, _) -> K = ref ; K = rref ), cpp_nothrow_assign_c(C, K)
        ;   cpp_class(C, cls(_, _, Ms, _, _, _)), findall(Qs-[P], member(method(_, Qs, _, operator('='), [P], _, _), Ms), Qss), Qss \== [], forall(member(Qs-Ps, Qss), cpp_qs_nothrow(C, Qs, Ps)) )
    ;   true ).
cpp_nothrow_assign_c(C, K) :- cpp_class(C, cls(_, _, Ms, _, _, _)),
    (   member(method(_, Qs, _, operator('='), [P], _, _), Ms), cpp_special_param(P, C, K) -> cpp_qs_nothrow(C, Qs, [P])
    ;   K == rref, \+ ( member(method(_, _, _, operator('='), [P], _, _), Ms), cpp_special_param(P, C, rref) ), member(method(_, Qs, _, operator('='), [P], _, _), Ms), cpp_special_param(P, C, ref) -> cpp_qs_nothrow(C, Qs, [P])
    ;   cpp_nothrow_parts(C, assign(K)) ).
%% the implicit member's: each data member's and base sub-object's own (an array's element's; a scalar's and a reference's never throws)
cpp_nothrow_parts(C, Op) :- cpp_class_l(C, cls(_, Data, _, _, _)), forall(member(member(MT, _, _), Data), cpp_nothrow_part(MT, Op)).
cpp_nothrow_part(T0, Op) :- catch(ccl_resolve_type(T0, T), _, fail), !,
    (   T = arr(_, E) -> cpp_nothrow_part(E, Op)
    ;   ( T = ref(_, _) ; T = rref(_, _) ) -> true
    ;   cpp_class_of_type(T, D) -> ( Op == default -> cpp_nothrow_default(D) ; Op = copy(K) -> cpp_nothrow_copy(D, K) ; Op = assign(K) -> cpp_nothrow_assign_c(D, K) )
    ;   true ).
cpp_nothrow_part(_, _).
%% a parameter of a copy or a move -- `const C &' (K ref) or `C &&' (K rref), the class named as written or through its words
cpp_special_param(P, C, K) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), ( PT0 = ref(_, _) -> K0 = ref ; PT0 = rref(_, _) -> K0 = rref ), K0 == K,
    (   PT0 =.. [_, _, base(_, [typedef(C)])] -> true
    ;   catch(cpp_in_class(C, cpp_param_ref(PT0, PT1)), error(not_lowered(_), _), fail), ccl_unref(PT1, PT2), cpp_class_of_type(PT2, C) ), !.
%% A SPECIAL MEMBER'S PARAMETER THAT NAMES ITS CLASS OTHERWISE THAN BY ITS PLAIN NAME (0.198): by a template-id of its own
%% template ([temp.local]/1: within a class template its name with its own arguments is the class), `S(const S<T> &)',
%% `S(S<T> &&)', libc++'s `__bit_iterator(const __bit_iterator<_Cp, false> &)', or by an alias of the class, `A(const Self
%% &)'. The copy and the move constructor (cpp_copy_ctor/2, cpp_copy_or_move/2) and the ABI's non-triviality
%% (cpp_user_copy_ctor/1) asked the parameter to name the class by its own name: such a constructor was no copy, `S<int> b =
%% a;' copied a memberwise and the written constructor never ran, and the class was passed as its bytes where clang passes it
%% by reference. Asked only of a referent named by a compound specifier other than the class's plain name, which the class's
%% words resolve (cpp_special_param/3).
cpp_named_self(C, P, K) :- ( P = param(PT, _) ; P = param(PT, _, _) ), ( PT = ref(_, base(_, [S])) ; PT = rref(_, base(_, [S])) ), compound(S), S \= typedef(C), S \= struct(_, _),
    member(K, [ref, rref]), cpp_special_param(P, C, K), !.
cpp_base_of(B, D) :- cpp_class_of_type(B, CB), cpp_class_of_type(D, CD), cpp_derives(CD, CB), !.
cpp_base_of(B, D) :- \+ cpp_class_of_type(B, _), \+ cpp_class_of_type(D, _), ccl_resolve_type(B, base(_, [struct(S, _)])), atom(S), S \== anon, ccl_resolve_type(D, base(_, [struct(S, _)])).   % A PLAIN STRUCT IS ITS OWN BASE ([meta.rel]: `is_base_of<T, T>' holds for a class that is no union; 0.126): a struct of data members alone is no registered class and has no base, so only itself. Else libc++ 18's `__invoke' overloads for a pointer to a data member (`__enable_if_bullet4': `is_base_of<_ClassT, _DecayA0>') were all disabled for `std::invoke(&Pt::x, p)' and the generic callable one was chosen (invokedata.cpp)
%% A CLASS DERIVES FROM EVERY BASE IT NAMES, the first or a later one, empty or with storage (0.112; [class.derived]):
%% libc++'s `__range_adaptor_closure_t<F> : F, __range_adaptor_closure<__range_adaptor_closure_t<F>>' has its CRTP base
%% second, and with only the first followed `is_base_of' was false, `_RangeAdaptorClosure' unmet and `v | views::filter(p)'
%% had no operator| (no_operator). The traits ask this; the call roads keep the first-base walk, whose hops they emit.
cpp_derives(C, C) :- !.
cpp_derives(D, C) :- ( cpp_base_scope(D, B) ; catch('$cpp_base_slot'(D, B, _), _, fail) ; cpp_class_l(D, cls(B, _, _, _, _)), B \== none ), cpp_derives(B, C), !.   % ... the first base too, virtual or not (the dynamic_cast clause of 0.108, once a second definition of this name; one predicate since 0.112)
cpp_constructible(T, Args) :- Args = [_|_], ccl_std_at_least(20), cpp_agg_constructible(T, Args), !.   % AN AGGREGATE FROM VALUES, from C++20 on (0.197), below
cpp_constructible(T, []) :- !, ccl_unref(T, T1),
    ( cpp_class_of_type(T1, C) -> ( \+ cpp_has_ctors(C) -> true ; cpp_ctor_arity_fits(C, 0) -> true ; cpp_implicit_ctor_needed(C) -> true ; cpp_trivial_default(C) )   % `allocator() = default' is dropped as the implicit one: still default-constructible -- AND SO IS A CLASS WHOSE IMPLICIT DEFAULT CONSTRUCTOR IS MADE (cpp_implicit_ctor_needed): libc++ 18's `allocator<T> : private __non_trivial_if<...>' has `allocator() = default' over a base with a constructor, so the implicit one constructs that base and is no trivial default; answered 0, `is_default_constructible<allocator<...>>' rejected `__compressed_pair''s only default constructor (a template guarded by it), and the tree's `__pair1_' was left to an implicit constructor that did not exist
    ; \+ ccl_resolve_type(T1, base(_, [void])) ).
%% ... AND FROM VALUES ([dcl.init], [over.match.ctor]; 0.200): a reference binds as [dcl.init.ref] has it (cpp_ref_constructible/3); a
%% class from its own value, or a derived one's, takes its copy or its move where the one chosen is there and not deleted
%% (cpp_copy_there/2), else another constructor that takes the value; from other values a constructor that takes them
%% (cpp_ctor_takes/2), or the copy of what a class value's conversion function gives; a scalar what converts to it, by
%% direct-initialization through a class value's `explicit' conversion function too. Each was asked of the arity alone:
%% `is_constructible_v<std::string, int>' was 1, as were `<Two, int, int>' of `Two(int, const char *)' and `is_copy_constructible_v'
%% of a class whose copy constructor is deleted. A value the tables cannot type keeps the arity's answer.
cpp_constructible(T, Args) :- member(A, Args), cpp_untyped_arg(A), !, cpp_constructible_arity(T, Args).
cpp_constructible(T, [F]) :- cpp_ref_target(T, K, R), !, cpp_ref_constructible(K, R, F).
cpp_constructible(T, [F]) :- !, ccl_unref(T, T1), ( cpp_class_of_type(T1, C) -> cpp_class_constructible(C, T1, [F]) ; cpp_scalar_constructible(T1, F) ).
cpp_constructible(T, Args) :- ccl_unref(T, T1), cpp_class_of_type(T1, C), cpp_class_constructible(C, T1, Args).
cpp_constructible_arity(T, [F]) :- !, ccl_unref(T, T1), ccl_unref(F, F1),                       % the ARGUMENT unreffed too: `__is_constructible(T, T &&)' is T's copy or move
    ( cpp_class_of_type(T1, C) -> ( cpp_class_of_type(F1, C) -> true ; cpp_has_ctors(C) -> cpp_ctor_arity_fits(C, 1) ; cpp_convertible(F1, T1) )
    ; cpp_convertible(F1, T1) ).
cpp_constructible_arity(T, Args) :- length(Args, N), cpp_class_of_type(T, C), cpp_ctor_arity_fits(C, N).
%% ... AN AGGREGATE IS CONSTRUCTIBLE FROM ITS ELEMENTS' VALUES from C++20 on ([meta.unary.prop]: `T t(declval<Args>()...)' well-formed;
%% [dcl.init.general]/16.6.2.2, P0960; 0.197): as many values as it has elements at most -- its direct bases, then its data members,
%% a union its first member -- each convertible to its element in order. `is_constructible_v<P, int, int>' of `struct P { int x;
%% int y; }' was false, as it is at C++17; clang answers true at C++20, and false for three values. One value of the class itself is
%% the copy, which the clauses below answer.
cpp_agg_constructible(T, Args) :- ccl_unref(T, T1), cpp_agg_elements(T1, Es), length(Args, N), length(Es, NE), N =< NE,
    \+ ( Args = [F], ccl_unref(F, F1), ( cpp_same_type(F1, T1) ; cpp_same_unqualified(F1, T1) ; cpp_class_of_type(T1, C), cpp_class_of_type(F1, D), cpp_derives(D, C) ) ),
    cpp_agg_elems_take(Es, Args).
cpp_agg_elements(T, Es) :- cpp_class_of_type(T, C), !, cpp_aggregate_class(C), cpp_direct_bases(C, Bs), findall(base([], [typedef(B)]), member(B, Bs), BTs),
    cpp_class_l(C, cls(_, Data, _, _, _)), findall(MT, ( member(member(MT, M, _), Data), \+ sub_atom(M, 0, _, _, '$base'), M \== '$vptr' ), MTs), append(BTs, MTs, Es).
cpp_agg_elements(T, Es) :- once(ccl_resolve_type(T, base(_, [S]))), compound(S),
    (   S = struct(_, Ms), is_list(Ms) -> findall(MT, member(member(MT, _, _), Ms), Es)
    ;   S = union(_, Ms), is_list(Ms) -> ( member(member(MT, _, _), Ms) -> Es = [MT] ; Es = [] ) ).
cpp_agg_elems_take(_, []) :- !.
cpp_agg_elems_take([ET|Es], [A|As]) :- catch(cpp_convertible(A, ET), _, fail), cpp_agg_elems_take(Es, As).
cpp_ctor_arity_fits(C, N) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, Ps, _, _), Ms), cpp_arity(Ps, Min, Max), N >= Min, ( Max == any ; N =< Max ), !.
cpp_ctor_arity_fits(C, N) :- '$cpp_mt'(C, ctor, _, ctor(_, _, Ps, _, _)), cpp_arity(Ps, Min, Max), N >= Min, ( Max == any ; N =< Max ), !.   % a constructor TEMPLATE counts (libc++'s allocator has only that and a defaulted one)
%% a trait's value the tables cannot type: `unknown', a type that does not resolve, one that names a template's own parameter
cpp_untyped_arg(A) :- ( A == unknown -> true ; \+ catch(ccl_resolve_type(A, _), _, fail) -> true ; cpp_raw_type(A) ), !.
%% a value of the trait's type F: an lvalue where F is an lvalue reference, an rvalue else, X its type
cpp_value_cat(F, Cat, X) :- ( catch(ccl_resolve_type(F, RF), _, fail) -> true ; RF = F ),
    ( RF = ref(_, X) -> Cat = lvalue ; RF = rref(_, X) -> Cat = rvalue ; X = F, Cat = rvalue ).
%% a reference type: K `lvalue' for one to a non-const type, `clvalue' for one to a const type, `rvalue' for an rvalue reference
cpp_ref_target(T, K, R) :- \+ cpp_untyped_arg(T), catch(ccl_resolve_type(T, RT0), _, fail), cpp_ref_collapsed(RT0, RT),
    ( RT = ref(_, R) -> ( cpp_const_referent(R) -> K = clvalue ; K = lvalue ) ; RT = rref(_, R), K = rvalue ).
%% A REFERENCE TO A REFERENCE COLLAPSES ([dcl.ref]/7; 0.200): the substitution leaves `const _Tp &' of `_Tp = int &' as `int & &',
%% which is `int &', and the referent read as a reference was compatible with nothing
cpp_ref_collapsed(T, R) :- nonvar(T), ( T = ref(Q, U), K = ref ; T = rref(Q, U), K = rref ), nonvar(U), ( U = ref(_, _) ; U = rref(_, _) ), !,
    cpp_collapse_ref(K, Q, U, R1), cpp_ref_collapsed(R1, R).
cpp_ref_collapsed(T, T).
cpp_const_referent(R) :- catch(ccl_resolve_type(R, RR), _, fail), cpp_top_const(RR), !.
%% A REFERENCE FROM A VALUE ([dcl.init.ref]/5): one to a non-const type binds an lvalue of a type it is compatible with, or the
%% lvalue a class value's conversion function gives; one to a const type and an rvalue reference bind a compatible value, or a
%% temporary of what converts to the referent -- an rvalue reference no lvalue of a related type
cpp_ref_constructible(lvalue, R, F) :- !, ( cpp_value_cat(F, lvalue, X), cpp_ref_compatible(R, X) -> true ; cpp_value_cat(F, _, X), cpp_class_of_type(X, D), cpp_conv_lref(D, R) ).
cpp_ref_constructible(K, R, F) :- cpp_value_cat(F, Cat, X), \+ ( K == rvalue, Cat == lvalue, cpp_ref_related(R, X) ), ( cpp_ref_compatible(R, X) -> true ; cpp_convertible(X, R) ).
cpp_conv_lref(D, R) :- catch(ccl_resolve_type(R, RR), _, fail), cpp_conv_member_(_, implicit, D, RR, CT0, _), catch(cpp_in_class(D, cpp_type_or_self(CT0, CT)), _, fail),
    catch(ccl_resolve_type(CT, ref(_, Y)), _, fail), cpp_ref_compatible(R, Y), !.
%% a reference to R binds a value of type X directly ([dcl.init.ref]/4): X is R, or a class derived from it, R at least as
%% qualified as X; related, its qualifiers aside
cpp_ref_compatible(R, X) :- catch(( ccl_resolve_type(R, RR), ccl_resolve_type(X, RX) ), _, fail), cpp_strip_quals(RR, QR, BR), cpp_strip_quals(RX, QX, BX),
    forall(( member(Q, QX), memberchk(Q, [const, volatile]) ), memberchk(Q, QR)), cpp_ref_related_(BR, BX), !.
cpp_ref_related(R, X) :- catch(( ccl_resolve_type(R, RR), ccl_resolve_type(X, RX) ), _, fail), cpp_strip_quals(RR, _, BR), cpp_strip_quals(RX, _, BX), cpp_ref_related_(BR, BX), !.
cpp_ref_related_(BR, BX) :- cpp_same_type(BR, BX), !.
cpp_ref_related_(BR, BX) :- cpp_class_of_type(BR, CR), cpp_class_of_type(BX, CX), cpp_derives(CX, CR).
%% A CLASS FROM VALUES: from its own value, or a derived one's, its copy or its move where the one chosen is there and not
%% deleted, else another constructor that takes it; a class with no constructor from what converts to it; from other values
%% a constructor that takes them, or, from one class value, the move of what its conversion function gives
cpp_class_constructible(C, _, [F]) :- cpp_value_cat(F, _, X), cpp_class_of_type(X, D), cpp_class_fits(D, C), !, ( cpp_copy_there(C, F) -> true ; cpp_ctor_takes(C, [F]) ).
cpp_class_constructible(C, T1, [F]) :- \+ cpp_has_ctors(C), !, cpp_value_cat(F, _, X), cpp_convertible(X, T1).
cpp_class_constructible(C, _, Args) :- cpp_ctor_takes(C, Args), !.
cpp_class_constructible(C, T1, [F]) :- cpp_value_cat(F, _, X), cpp_class_of_type(X, D), cpp_conv_result(D, T1, _), cpp_special_there(C, move).
%% A CONSTRUCTOR TAKES THE VALUES ([over.match.ctor]; direct-initialization, so an `explicit' one too): a written one whose
%% parameters take them in order (cpp_value_binds/3, any implicit conversion), or a constructor template whose parameters deduce
%% from them, its defaults binding and its constraints and requires-clause holding, and whose substituted parameters take them
%% (a pack the rest, as before); and no constructor declared deleted takes them exactly
cpp_ctor_takes(C, Args) :- \+ cpp_deleted_takes(C, Args), length(Args, N),
    (   cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, Ps, I, _), Ms), \+ cpp_ctor_gone(C, I), cpp_arity(Ps, Min, Max), N >= Min, ( Max == any -> true ; N =< Max ), cpp_params_take(C, Ps, Args) -> true
    ;   '$cpp_mt'(C, ctor, TPs, ctor(_, Qs, Ps, _, _)), cpp_arity(Ps, Min, Max), N >= Min, ( Max == any -> true ; N =< Max ), cpp_tmpl_takes(user, C, TPs, Qs, Ps, Args) -> true ).
%% a defaulted copy or move that the class's parts delete is gone: the copy no candidate, the move none ([over.match.funcs]/8)
cpp_ctor_gone(C, memberwise(_, copy)) :- \+ cpp_special_there(C, copy).
cpp_ctor_gone(C, memberwise(_, move)) :- \+ cpp_move_kind(C, ok).
cpp_params_take(_, _, []) :- !.
cpp_params_take(_, [P|_], _) :- ( P = param(pack(_), _) ; P = param(pack(_), _, _) ), !.
cpp_params_take(C, [P|Ps], [A|As]) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), !,
    catch(cpp_in_class(C, cpp_param_ref(PT0, PT)), error(not_lowered(_), _), fail), cpp_value_binds(PT, A), cpp_params_take(C, Ps, As).
%% a parameter of type PT takes a value of the trait's type A ([over.best.ics], [dcl.init.ref]): a reference binds it, any other
%% parameter takes what converts to it
cpp_value_binds(PT, A) :- cpp_ref_target(PT, K, R), !, cpp_ref_constructible(K, R, A).
cpp_value_binds(PT, A) :- cpp_value_cat(A, _, X), ( cpp_ref_compatible(PT, X) -> true ; cpp_convertible(X, PT) ).
cpp_tmpl_takes(Mode, C, TPs, Qs, Ps, Args) :-
    catch(cpp_in_class(C, ( cpp_match_args(Ps, Args, TPs, [], B0), cpp_bind_defaults(TPs, B0, B), cpp_constraints_hold(ctor, TPs, B), cpp_member_tmpl_req(C, Qs, Ps, B) )),
          error(not_lowered(_), _), fail),
    cpp_tmpl_params_ok(Mode, C, Ps, Args, B), !.
cpp_match_args([P|_], As, TPs, B0, B) :- ( P = param(pack(T), _) ; P = param(pack(T), _, _) ), !, cpp_deduce_pack(T, As, TPs, B0, B).   % A PACK DEDUCES ITS ELEMENTS FROM THE REST (0.200), as the call road's (cpp_deduce_pack/5): undeduced, tuple's `tuple(_Up &&...)' took an `int' for a string
cpp_match_args(_, [], _, B, B) :- !.
cpp_match_args([P|Ps], [A|As], TPs, B0, B) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), !, cpp_match(PT0, A, TPs, B0, B1), cpp_match_args(Ps, As, TPs, B1, B).
cpp_tmpl_params_ok(_, _, _, [], _) :- !.
cpp_tmpl_params_ok(_, _, [P|_], _, _) :- ( P = param(pack(_), _) ; P = param(pack(_), _, _) ), !.
cpp_tmpl_params_ok(Mode, C, [P|Ps], [A|As], B) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), !, cpp_subst(PT0, B, PT1), cpp_tmpl_type_ok(Mode, C, PT1, A), cpp_tmpl_params_ok(Mode, C, Ps, As, B).
%% A CONSTRUCTOR DECLARED DELETED THAT TAKES THE VALUES EXACTLY, a copy or a move aside (cpp_copy_there/2), is the one overload
%% resolution chooses, and the construction is ill-formed ([dcl.fct.def.delete]/2): `basic_string(nullptr_t) = delete' (C++23)
cpp_deleted_takes(C, Args) :- '$cpp_dctor'(C, Ps), length(Args, N), length(Ps, N), \+ ( Ps = [P], ( cpp_sdecl_param(ctor, P, C, ref) ; cpp_sdecl_param(ctor, P, C, rref) ) ),
    cpp_params_exact(C, Ps, Args), !.
cpp_params_exact(_, [], []).
cpp_params_exact(C, [P|Ps], [A|As]) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), catch(cpp_in_class(C, cpp_param_ref(PT0, PT)), _, fail),
    cpp_unref_all(PT, R), cpp_value_cat(A, _, X), cpp_ref_related(R, X), cpp_params_exact(C, Ps, As).
%% THE COPY OR THE MOVE THAT CONSTRUCTS FROM THE CLASS'S OWN VALUE F ([over.match.ctor], [class.copy.ctor]): an rvalue takes the
%% move where there is one, an lvalue or a const value the copy; the one taken must be there and not deleted. The copy is
%% written, or implicit -- deleted where the class declares a move constructor or a move assignment, and a defaulted one where a
%% base or a data member has no copy; the move is written, or implicit where the class declares no copy constructor, copy or move
%% assignment and destructor, and a defaulted one that cannot move its parts is no candidate ([over.match.funcs]/8): the rvalue
%% then takes the copy
cpp_copy_there(C, F) :- cpp_value_cat(F, Cat, X), ( Cat == lvalue -> K = copy ; cpp_const_referent(X) -> K = copy ; K = move ), cpp_special_there(C, K).
cpp_special_there(C, move) :- !, cpp_move_kind(C, MK), ( MK == ok -> true ; MK == none -> cpp_special_there(C, copy) ).
cpp_special_there(C, copy) :-
    (   cpp_sdecl(C, copy_ctor, B) -> B \== delete, ( B == default -> cpp_parts_copyable(C, copy) ; true )
    ;   \+ cpp_sdecl(C, move_ctor, _), \+ cpp_sdecl(C, move_assign, _), cpp_parts_copyable(C, copy) ).
cpp_move_kind(C, K) :-
    (   cpp_sdecl(C, move_ctor, B) -> ( B == delete -> K = deleted ; B == default, \+ cpp_parts_copyable(C, move) -> K = none ; K = ok )
    ;   \+ cpp_sdecl(C, copy_ctor, _), \+ cpp_sdecl(C, copy_assign, _), \+ cpp_sdecl(C, move_assign, _), \+ cpp_sdecl(C, dtor, _) -> ( cpp_parts_copyable(C, move) -> K = ok ; K = none )
    ;   K = none ).
%% what the class declares of the special member K -- copy_ctor, move_ctor, copy_assign, move_assign or dtor -- and how
cpp_sdecl(C, dtor, B) :- !, '$cpp_sdecl'(C, dtor, none, B), !.
cpp_sdecl(C, K, B) :- cpp_sdecl_kind(K, What, Ref), '$cpp_sdecl'(C, What, P, B), cpp_sdecl_param(What, P, C, Ref), !.
cpp_sdecl_kind(copy_ctor, ctor, ref).
cpp_sdecl_kind(move_ctor, ctor, rref).
cpp_sdecl_kind(copy_assign, assign, ref).
cpp_sdecl_kind(move_assign, assign, rref).
cpp_sdecl_param(_, P, C, Ref) :- cpp_special_param(P, C, Ref), !.
cpp_sdecl_param(_, P, C, Ref) :- cpp_named_self(C, P, Ref), !.
cpp_sdecl_param(assign, P, C, ref) :- ( P = param(T0, _) ; P = param(T0, _, _) ), \+ T0 = ref(_, _), \+ T0 = rref(_, _),   % a copy assignment may take its class by value ([class.copy.assign]/1)
    catch(cpp_in_class(C, cpp_param_ref(T0, T)), error(not_lowered(_), _), fail), cpp_class_of_type(T, C), !.
%% every base of the class, an empty one among them, and every data member copies (K copy) or moves (K move): a scalar, a pointer
%% and a reference always, an array as its element, a class by its own copy or move; remembered once the class is registered
cpp_parts_copyable(C, K) :- '$cpp_cpok'(C, K, V), !, V == yes.
cpp_parts_copyable(C, K) :- cpp_class_l(C, cls(_, Data, _, _, _)), !, ( cpp_direct_bases(C, Bs) -> true ; Bs = [] ),
    (   forall(member(B, Bs), cpp_special_there(B, K)), forall(( member(member(MT, N, _), Data), \+ sub_atom(N, 0, 1, _, '$') ), cpp_part_copyable(MT, K)),
        \+ cpp_union_untrivial(C, Data)
    ->  V = yes ; V = no ), assertz('$cpp_cpok'(C, K, V)), V == yes.
cpp_parts_copyable(_, _).
cpp_part_copyable(T0, K) :- catch(ccl_resolve_type(T0, T), _, fail), !, ( T = arr(_, E) -> cpp_part_copyable(E, K) ; cpp_class_of_type(T, D) -> cpp_special_there(D, K) ; true ).
cpp_part_copyable(_, _).
%% A UNION'S VARIANT MEMBER OF A CLASS THAT IS NOT TRIVIAL deletes the union's implicit copy, move and copy and move assignment
%% ([class.copy.ctor]/10, [class.copy.assign]/7; 0.200): `union U { std::string s; int i; U() {} ~U() {} };' was copy-constructible
cpp_union_untrivial(C, Data) :- '$cpp_union'(C), member(member(MT, N, _), Data), \+ sub_atom(N, 0, 1, _, '$'), \+ cpp_part_trivial(MT), !.
cpp_part_trivial(T0) :- catch(ccl_resolve_type(T0, T), _, fail), !, ( T = arr(_, E) -> cpp_part_trivial(E) ; cpp_class_of_type(T, D) -> cpp_trivial_class(D) ; true ).
cpp_part_trivial(_).
%% A SCALAR FROM ONE VALUE ([dcl.init]/17.7, [over.match.conv]): what converts to it implicitly, and by direct-initialization a
%% class value's `explicit' conversion function too and a null pointer to `bool' ([conv.bool])
cpp_scalar_constructible(T1, F) :- cpp_value_cat(F, _, X),
    (   cpp_convertible(X, T1) -> true
    ;   cpp_class_of_type(X, D) -> catch(ccl_resolve_type(T1, RT), _, fail), cpp_conv_member_(exact, explicit, D, RT, _, _), !   % AN `explicit' ONE ONLY TO ITS OWN RESULT TYPE (0.200; [over.match.conv]/1.1: a qualification conversion at most): `explicit operator bool' made `is_constructible_v<int, std::optional<int>>' 1
    ;   ccl_nullptr_type(X) -> catch(ccl_resolve_type(T1, base(_, [bool])), _, fail) ).
%% THE TRAIT OF AN ASSIGNMENT ([meta.unary.prop]: `declval<T>() = declval<F>()' well-formed; 0.200): a class from its own value, or a
%% derived one's, through its copy or its move assignment where the one chosen is there and not deleted (cpp_assign_there/2), else
%% another assignment that takes it; from another value an `operator=' that takes it, written or a template, or the copy of what
%% converts to the class; a scalar only through a non-const lvalue reference ([expr.ass]/1), from what converts to it. Each was
%% asked of any one-parameter `operator=': `is_assignable_v<std::vector<int> &, int>' was 1, `<int, int>' and `<const int &, int>'
%% too. A value the tables cannot type keeps that answer.
cpp_assignable(T, F) :- cpp_untyped_arg(F), !, ccl_unref(T, T1), ccl_unref(F, F1),
    ( cpp_class_of_type(T1, C) -> ( cpp_class_of_type(F1, C) -> true ; cpp_assign_member(C) ) ; cpp_convertible(F1, T1) ).
cpp_assignable(T, F) :- ccl_unref(T, T1),
    (   cpp_class_of_type(T1, C) -> ( cpp_value_cat(F, _, X), cpp_class_of_type(X, D), cpp_class_fits(D, C) -> ( cpp_assign_there(C, F) -> true ; cpp_assign_takes(C, F) ) ; cpp_assign_takes(C, F) )
    ;   cpp_ref_target(T, lvalue, _) -> cpp_value_cat(F, _, X), cpp_convertible(X, T1), \+ cpp_plain_unassignable(T1) ).
cpp_assign_takes(C, F) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, _, _, operator('='), [P], _, _), Ms), ( P = param(PT0, _) ; P = param(PT0, _, _) ),
    catch(cpp_in_class(C, cpp_param_ref(PT0, PT)), error(not_lowered(_), _), fail), cpp_value_binds(PT, F), !.
cpp_assign_takes(C, F) :- '$cpp_mt'(C, _, TPs, method(_, Qs, _, operator('='), [P], _, _)), cpp_tmpl_takes(user, C, TPs, Qs, [P], [F]), !.
cpp_assign_takes(C, F) :- cpp_value_cat(F, _, X), \+ ( cpp_class_of_type(X, D), cpp_class_fits(D, C) ), cpp_class_l(C, _), cpp_convertible(X, base([], [typedef(C)])), cpp_assign_special(C, move).   % the implicit copy or move of the class made from it
%% THE COPY OR THE MOVE ASSIGNMENT FROM THE CLASS'S OWN VALUE ([class.copy.assign]/2, /4, /7), as cpp_copy_there/2 chooses a
%% constructor: the implicit copy assignment deleted where the class declares a move constructor or a move assignment, a defaulted
%% one where a data member is const or a reference or a part has no copy assignment; the implicit move assignment declared where the
%% class declares no copy constructor, copy assignment, move constructor and destructor
cpp_assign_there(C, F) :- cpp_value_cat(F, Cat, X), ( Cat == lvalue -> K = copy ; cpp_const_referent(X) -> K = copy ; K = move ), cpp_assign_special(C, K).
cpp_assign_special(C, move) :- !, cpp_move_assign_kind(C, MK), ( MK == ok -> true ; MK == none -> cpp_assign_special(C, copy) ).
cpp_assign_special(C, copy) :-
    (   cpp_sdecl(C, copy_assign, B) -> B \== delete, ( B == default -> cpp_parts_assignable(C, copy) ; true )
    ;   \+ cpp_sdecl(C, move_ctor, _), \+ cpp_sdecl(C, move_assign, _), cpp_parts_assignable(C, copy) ).
cpp_move_assign_kind(C, K) :-
    (   cpp_sdecl(C, move_assign, B) -> ( B == delete -> K = deleted ; B == default, \+ cpp_parts_assignable(C, move) -> K = none ; K = ok )
    ;   \+ cpp_sdecl(C, copy_ctor, _), \+ cpp_sdecl(C, copy_assign, _), \+ cpp_sdecl(C, move_ctor, _), \+ cpp_sdecl(C, dtor, _) -> ( cpp_parts_assignable(C, move) -> K = ok ; K = none )
    ;   K = none ).
cpp_parts_assignable(C, K) :- '$cpp_aspok'(C, K, V), !, V == yes.
cpp_parts_assignable(C, K) :- cpp_class_l(C, cls(_, Data, _, _, _)), !, ( cpp_direct_bases(C, Bs) -> true ; Bs = [] ),
    (   forall(member(B, Bs), cpp_assign_special(B, K)), forall(( member(member(MT, N, _), Data), \+ sub_atom(N, 0, 1, _, '$') ), cpp_part_assignable(MT, K)),
        \+ cpp_union_untrivial(C, Data)
    ->  V = yes ; V = no ), assertz('$cpp_aspok'(C, K, V)), V == yes.
cpp_parts_assignable(_, _).
cpp_part_assignable(T0, K) :- catch(ccl_resolve_type(T0, T), _, fail), !,
    (   ( T = ref(_, _) ; T = rref(_, _) ) -> fail
    ;   T = arr(_, E) -> cpp_part_assignable(E, K)
    ;   cpp_class_of_type(T, D) -> cpp_assign_special(D, K)
    ;   \+ cpp_top_const(T), \+ cpp_plain_unassignable(T) ).
cpp_part_assignable(_, _).
%% A PLAIN STRUCT OR UNION, no registered class, whose data member is a reference or a const object, through its arrays and the
%% plain records it holds, has a deleted copy and move assignment ([class.copy.assign]/7; 0.200): `struct H { int &r; };' was
%% copy-assignable to the traits
cpp_plain_unassignable(T) :- cpp_plain_aggregate(T), ccl_members_of(T, Ms), member(member(MT, _, _), Ms), cpp_plain_part_fixed(MT), !.
cpp_plain_part_fixed(T0) :- catch(ccl_resolve_type(T0, T), _, fail),
    (   ( T = ref(_, _) ; T = rref(_, _) ) -> true
    ;   T = arr(_, E) -> cpp_plain_part_fixed(E)
    ;   cpp_top_const(T) -> true
    ;   cpp_plain_unassignable(T) ).
cpp_assign_member(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, _, _, operator('='), [_], _, _), Ms), !.
cpp_assign_member(C) :- '$cpp_mt'(C, _, _, method(_, _, _, operator('='), [_], _, _)).   % an assignment TEMPLATE counts, as a constructor template does (cpp_ctor_arity_fits): `std::ignore' is a class whose only `operator=' is `template <class _Tp> const __ignore_type &operator=(const _Tp &) const', and read as not assignable it rejected tuple's CONVERTING assignment -- the copy assignment then took a `tuple<int, int>' for a `tuple<int &, __ignore_type &>' and read an int as an address
%% THE TRAIT OF A CONVERSION ([conv]: `To t = declval<From>();', a copy-initialization; 0.200): a reference binds as a construction
%% does, a class from its own value, or a derived one's, through its copy or its move where the one chosen is there and not
%% deleted, else a converting constructor; anything else by cpp_converts/3, which a standard conversion alone serves in mode `std'
cpp_convertible(F, T) :- \+ cpp_untyped_arg(F), cpp_ref_target(T, K, R), !, cpp_ref_constructible(K, R, F).
cpp_convertible(F, T) :- \+ cpp_untyped_arg(F), ccl_unref(T, T1), cpp_class_of_type(T1, C), cpp_value_cat(F, _, X), cpp_class_of_type(X, D), cpp_class_fits(D, C), !,
    ( cpp_copy_there(C, F) -> true ; cpp_converting(C, X) ).
cpp_convertible(F, T) :- cpp_converts(user, F, T).
cpp_converts(Mode, F, T) :- ccl_unref(F, F1), ccl_unref(T, T1), ccl_resolve_type(F1, RF), ccl_resolve_type(T1, RT),
    (   cpp_same_type(F1, T1) -> true
    ;   cpp_nullptr_written(T1), \+ cpp_untyped_arg(F1) -> cpp_nullptr_arg(F1)                       % `std::nullptr_t' FROM A `nullptr_t' ALONE (0.200): it resolved to `void *' until 0.206, which any object pointer converted to
    ;   cpp_same_unqualified(RF, RT) -> true                                                         % A VALUE'S TOP-LEVEL QUALIFIERS ARE NO BAR to initializing from it ([dcl.init]): `is_constructible<S, const S &>' of a plain struct, `__is_constructible(int *, int *const &)' -- both answered 0 where clang answers 1, since neither side is a registered class and `const S' is not the spelling `S' (0.93, libc++ 18's is_copy_constructible)
    ;   ccl_is_arith(RF), ccl_is_arith(RT) -> \+ cpp_enum_type(RT), \+ cpp_scoped_enum_value(RF)   % ... AN ARITHMETIC VALUE, BUT TO AN ENUMERATION AND FROM A SCOPED ONE ([conv.integral], [dcl.enum]/10; 0.200): `is_convertible_v<int, E>' and `<Scoped, int>' were 1
    ;   ( RF = ptr(_, PF) ; RF = arr(_, PF) ), RT = ptr(_, PT), ( ccl_resolve_type(PT, base(_, [void])) -> true ; cpp_same_type(PF, PT) -> true ; cpp_quals_added(PF, PT) -> true ; cpp_fnptr_conv(PF, PT) -> true ; cpp_pointer_to_base(PF, PT) ) -> true   % ... AND THE QUALIFICATION CONVERSION ([conv.qual]): `char *' converts to `const char *' (0.93). libc++ 18's `__unwrap_range' builds `std::make_pair(__unwrap_iter(__first), __unwrap_iter(__last))' over a string's characters, and `is_constructible<const char *, char *const>' answered 0, which rejected every two-argument constructor of the pair
    ;   RF = fn(_, _, _), RT = ptr(_, PT), ( cpp_same_type(RF, PT) -> true ; cpp_fnptr_conv(RF, PT) ) -> true                                % A FUNCTION CONVERTS TO A POINTER TO ITSELF ([conv.func]), which is what `is_constructible<_Fd, _Gp>' asks of std::bind's `int (&)(int, int, int)' against its decayed `int (*)(int, int, int)'
    ;   RF = base(_, [nullptr_t]), ( RT = ptr(_, _) ; RT = memptr(_, _, _) ) -> true                   % A `std::nullptr_t' TO ANY POINTER AND POINTER TO MEMBER ([conv.ptr]/1, [conv.mem]/1; 0.206) -- `void *' to another pointer is no implicit conversion ([conv.ptr]/2; 0.200)
    ;   cpp_pointerish(RF), RT = base(_, [bool]) -> true                                               % A POINTER TO `bool' ([conv.bool]; 0.200); a `std::nullptr_t' by direct-initialization alone (cpp_scalar_constructible/2)
    ;   cpp_class_of_type(RF, CF), cpp_class_of_type(RT, CT) -> ( cpp_class_fits(CF, CT) -> true ; Mode == user, ( cpp_converting(CT, RF) -> true ; cpp_class_converts(CT, CF) -> true ; cpp_conv_result(CF, RT, _) ) )   % A CLASS TO ANOTHER CLASS (0.121): a derived one, a converting constructor of the target that takes the source, or a conversion function of the source that gives the target ([conv], [class.conv]); only the first was asked -- libc++'s `strong_ordering' converts to `partial_ordering' by `operator partial_ordering()', and `convertible_to' of the two, the compound requirement of `three_way_comparable', was false
    ;   cpp_class_of_type(RT, CT) -> Mode == user, ( RF == unknown -> cpp_converting(CT) ; cpp_converting(CT, RF) )   % BY THE SOURCE'S TYPE (0.115): a constructor whose parameter takes its kind, as an argument converts -- `basic_string_view<char>(const char *)' made `is_convertible<const wchar_t *, string_view>' true
    ;   cpp_class_of_type(RF, CF) -> Mode == user, cpp_conv_scalar(implicit, CF, RT)                      % A CLASS VALUE TO A SCALAR THROUGH A CONVERSION FUNCTION WHOSE RESULT CONVERTS TO IT (0.200): any conversion function counted, and `is_convertible_v<std::string, int>' was 1 by `operator basic_string_view()'
    ;   fail ).
%% a class's conversion function to the scalar type RT: its result converts to RT by a standard conversion ([over.match.conv]), an
%% `explicit' one by direct-initialization alone (How `explicit')
cpp_conv_scalar(How, CF, RT) :- cpp_conv_member_(_, How, CF, RT, _, RCT), cpp_converts(std, RCT, RT), !.
%% a scoped enumeration's value, which converts to no arithmetic type ([dcl.enum]/10)
cpp_scoped_enum_value(R) :- R = base(_, [E]), compound(E), ( E = enum(Tag, _) ; E = enum_class(Tag, _) ), ccl_scoped_enum(Tag), !.
%% `std::nullptr_t' as the tables hold it, a typedef of `decltype(nullptr)', and resolved, the builtin `base([], [nullptr_t])' (0.206)
cpp_nullptr_written(T) :- cpp_nullptr_param(T), !.
cpp_nullptr_written(base(_, [decltype(nullptr)])).
%% ... and a value's type as a conversion has it: a `std::nullptr_t' alone, where a `void *' value passed until 0.206
cpp_nullptr_arg(T) :- cpp_nullptr_written(T), !.
cpp_nullptr_arg(T) :- ccl_nullptr_type(T).
%% THE FUNCTION POINTER CONVERSION ([conv.fctptr], C++17; 0.198): a pointer to a noexcept function converts to a pointer to the same
%% function type without it, never the other way: `is_convertible_v<void (*)() noexcept, void (*)()>' is 1 and the reverse 0
cpp_fnptr_conv(F0, T0) :- ccl_resolve_type(F0, F), F = fn(R, Ps, VF), cpp_fn_type_nx(F), ccl_resolve_type(T0, T), T = fn(_, _, _), \+ cpp_fn_type_nx(T),
    cpp_fn_nx_off(VF, V), cpp_same_type(fn(R, Ps, V), T), !.
%% A POINTER TO A DERIVED CLASS CONVERTS TO A POINTER TO ITS BASE ([conv.ptr]/3), the pointee gaining qualifiers and
%% losing none (0.100): `is_convertible<Node *, const enable_shared_from_this<Node> *>' is how libc++'s shared_ptr
%% chooses `__enable_weak_this' over its `(...)' fallback, and answered 0 here the object's weak pointer was never set
%% and `shared_from_this()' aborted on bad_weak_ptr.
cpp_pointer_to_base(base(QF, SF), base(QT, ST)) :- forall(member(Q, QF), memberchk(Q, QT)),
    cpp_class_of_type(base([], SF), CF), cpp_class_of_type(base([], ST), CT), CF \== CT, cpp_derives(CF, CT), !.   % any base, as the traits have it (0.112)
cpp_same_unqualified(base(_, S1), base(_, S2)) :- !, cpp_canon_specs(S1, C1), cpp_canon_specs(S2, C2), ( C1 == C2 -> true ; cpp_same_type(base([], S1), base([], S2)) ).
cpp_same_unqualified(ptr(_, A), ptr(_, B)) :- !, cpp_same_type(A, B).
cpp_same_unqualified(A, B) :- cpp_same_type(A, B).
%% the pointee gains qualifiers and loses none: `char' to `const char', `int *' to `int *const' one level down
cpp_quals_added(base(QF, S1), base(QT, S2)) :- !, forall(member(Q, QF), memberchk(Q, QT)),
    cpp_canon_specs(S1, C1), cpp_canon_specs(S2, C2), ( C1 == C2 -> true ; cpp_same_type(base([], S1), base([], S2)) ).   % the spellings differ, the types may not: a program's alias of a class and the class's resolved struct (0.138)
cpp_quals_added(ptr(QF, A), ptr(QT, B)) :- !, forall(member(Q, QF), memberchk(Q, QT)), cpp_quals_added(A, B).
cpp_quals_added(arr(N1, A), arr(N2, B)) :- !, N1 == N2, cpp_quals_added(A, B).   % an array's element carries the array's qualifiers ([basic.type.qualifier]/3): `int (*)[]' converts to `const int (*)[]' -- libc++ 18's `__span_array_convertible', which `span<const int>(span<int>)' asks (0.117)
cpp_quals_added(A, B) :- cpp_same_type(A, B).
cpp_trivial_type(T) :- ccl_unref(T, T1), ( cpp_class_of_type(T1, C) -> cpp_trivial_class(C) ; true ).
cpp_trivial_class(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), \+ ( member(M, Ms), M = ctor(_, _, _, _, _), cpp_user_ctor(M) ), \+ member(dtor(_, _, _), Ms), \+ member(method(_, _, _, operator('='), _, _, _), Ms), \+ cpp_implicit_dtor_needed(C).
cpp_has_dtor(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), ( memberchk(dtor(_, _, _), Ms) -> true ; cpp_implicit_dtor_needed(C) ).
cpp_trait_type(type(T0), T) :- !, cpp_type(T0, T).
cpp_trait_type(id(N), T) :- cpp_type(base([], [typedef(N)]), T), !.
cpp_trait_type(T0, T) :- cpp_type(T0, T).
cpp_trait_of('__is_integral', R, V) :- ( R = base(_, S), cpp_arith(R), \+ memberchk(float, S), \+ memberchk(double, S) -> V = true ; V = false ).
cpp_trait_of('__is_floating_point', R, V) :- ( R = base(_, S), ( memberchk(float, S) ; memberchk(double, S) ) -> V = true ; V = false ).
cpp_trait_of('__is_arithmetic', R, V) :- ( cpp_arith(R) -> V = true ; V = false ).
cpp_trait_of('__is_pointer', R, V) :- ( R = ptr(_, _) -> V = true ; V = false ).
cpp_trait_of('__is_reference', R, V) :- ( ( R = ref(_, _) ; R = rref(_, _) ) -> V = true ; V = false ).
cpp_trait_of('__is_lvalue_reference', R, V) :- ( R = ref(_, _) -> V = true ; V = false ).
cpp_trait_of('__is_rvalue_reference', R, V) :- ( R = rref(_, _) -> V = true ; V = false ).
cpp_trait_of('__is_const', R, V) :- ( cpp_strip_quals(R, Q, _), memberchk(const, Q) -> V = true ; V = false ).   % the top-level qualifiers: a pointer's own, an array's element's (0.167: `is_const<const char[4]>' was false, and `is_const<int *const>')
cpp_trait_of('__is_volatile', R, V) :- ( ( R = base(Q, _) ; R = ptr(Q, _) ), memberchk(volatile, Q) -> V = true ; V = false ).   % libc++ 18's `__is_trivially_equality_comparable' road asks it (0.93); the top-level qualifiers, a pointer's own included
cpp_trait_of('__is_abstract', R, V) :- ( cpp_class_of_type(R, C), cpp_abstract_class(C) -> V = true ; V = false ).   % the one test (cpp_abstract_class)
cpp_trait_of('__is_void', R, V) :- ( R = base(_, [void]) -> V = true ; V = false ).
cpp_trait_of('__is_array', R, V) :- ( R = arr(_, _) -> V = true ; V = false ).
cpp_trait_of('__is_class', R, V) :- ( ( R = base(_, [struct(_, _)]) ; R = base(_, [class(_, _, _, _)]) ; R = base(_, [union(_, _)]) ; R = base(_, [typedef(N)]), atom(N), ( '$cpp_inst'(N, _) ; '$cpp_iname'(_, _, N) ; cpp_class_in_progress(N) ; cpp_nested_class_named(N) ) ) -> V = true ; V = false ).   % ... AND A NESTED CLASS KNOWN BY NAME (0.132), registered or not: lazy_split_view's iterator holds `struct value_type : view_interface<value_type>', whose base asks is_class_v of it while it registers -- refused, the iterator's registration stopped before its friends, and `it != end' had no operator
cpp_trait_of('__is_enum', R, V) :- ( ( R = base(_, [enum(_, _)]) ; R = base(_, [enum_class(_, _)]) ) -> V = true ; V = false ).
%% SIGNED AND UNSIGNED BY THE INFERENCE'S OWN TEST (0.221; [basic.fundamental]/9, [meta.unary.prop]: T(-1) < T(0); ccl_int_rank/3):
%% char8_t, char16_t and char32_t are unsigned, plain char and wchar_t unsigned on Linux aarch64, a floating type signed, bool
%% unsigned. The specifiers alone answered: `is_unsigned_v<char8_t>' was false, and libc++ 21's `__constexpr_memcmp', which every
%% `std::u8string' comparison calls, failed its static assertion
cpp_trait_of('__is_signed', R, V) :- ( cpp_arith(R), R = base(_, S), \+ memberchk(bool, S), ( ccl_is_float(R) -> true ; catch(ccl_int_rank(R, _, U), _, fail), U == false ) -> V = true ; V = false ).
cpp_trait_of('__is_unsigned', R, V) :- ( cpp_arith(R), R = base(_, S), ( memberchk(bool, S) -> true ; \+ ccl_is_float(R), catch(ccl_int_rank(R, _, U), _, fail), U == true ) -> V = true ; V = false ).
cpp_trait_of('__is_union', R, V) :- ( R = base(_, [union(_, _)]) -> V = true ; V = false ).
cpp_trait_of('__is_function', R, V) :- ( R = fn(_, _, _) -> V = true ; V = false ).
cpp_trait_of('__is_scalar', R, V) :- ( ( ccl_is_arith(R) ; R = ptr(_, _) ; R = memptr(_, _, _) ; R = base(_, [enum(_, _)]) ; R = base(_, [enum_class(_, _)]) ; R = base(_, [nullptr_t]) ) -> V = true ; V = false ).   % a pointer to member and `std::nullptr_t' too ([basic.types.general]/9; 0.206)
cpp_trait_of('__is_fundamental', R, V) :- ( ( cpp_arith(R) ; R = base(_, [void]) ; R = base(_, [nullptr_t]) ) -> V = true ; V = false ).
cpp_trait_of('__is_compound', R, V) :- ( ( ccl_is_arith(R) ; R = base(_, [void]) ; R = base(_, [nullptr_t]) ) -> V = false ; V = true ).
cpp_trait_of('__is_object', R, V) :- ( ( R = fn(_, _, _) ; R = ref(_, _) ; R = rref(_, _) ; R = base(_, [void]) ) -> V = false ; V = true ).
cpp_trait_of('__is_referenceable', R, V) :- ( R = base(_, [void]) -> V = false ; V = true ).
cpp_trait_of('__is_bounded_array', R, V) :- ( R = arr(N, _), N \== none -> V = true ; V = false ).
cpp_trait_of('__is_unbounded_array', R, V) :- ( R = arr(none, _) -> V = true ; V = false ).
%% THE MEMBER-POINTER TRAITS ARE ANSWERED (0.93), a pointer to member being a type of its own since 0.86 (memptr/3): a
%% function's or an object's by what it points to. libc++ 18 writes std::invoke's dispatch as six overloads guarded by
%% `is_member_function_pointer<__decay_t<_Fp>>::value && is_base_of<...>', and answered 0 every one of them was refused
%% and the generic `__f(__args...)' held for a pointer to member function, whose body refused decltype_unknown
cpp_trait_of('__is_member_pointer', R, V) :- !, ( R = memptr(_, _, _) -> V = true ; V = false ).
cpp_trait_of('__is_member_function_pointer', R, V) :- !, ( R = memptr(_, _, T), ccl_resolve_type(T, fn(_, _, _)) -> V = true ; V = false ).
cpp_trait_of('__is_member_object_pointer', R, V) :- !, ( R = memptr(_, _, T), \+ ccl_resolve_type(T, fn(_, _, _)) -> V = true ; V = false ).
cpp_trait_of('__is_final', R, V) :- ( cpp_class_of_type(R, C), '$cpp_final'(C) -> V = true ; V = false ).   % a class declared `final' (0.206; [meta.unary.prop]): it was false for every class
cpp_trait_of(N, R, V) :- memberchk(N, ['__is_null_pointer', '__is_nullptr']), ( R = base(_, [nullptr_t]) -> V = true ; V = false ).   % `std::nullptr_t', a type of its own (0.206): it was false
cpp_trait_of(N, R, V) :- memberchk(N, ['__is_trivially_copyable', '__is_trivial', '__is_pod', '__is_standard_layout', '__is_literal_type', '__is_trivially_copy_constructible', '__is_trivially_move_constructible']), ( cpp_trivial_type(R) -> V = true ; V = false ).
cpp_trait_of(N, R, V) :- memberchk(N, ['__is_trivially_destructible', '__has_trivial_destructor']), ( ( cpp_class_of_type(R, C) -> \+ cpp_has_dtor(C) ; true ) -> V = true ; V = false ).
cpp_trait_of(N, _, true) :- memberchk(N, ['__is_destructible', '__is_nothrow_destructible']).
cpp_trait_of('__has_virtual_destructor', R, V) :- ( cpp_class_of_type(R, C), cpp_class_l(C, cls(_, _, _, _, Slots)), memberchk(slot('$dtor', _, _, _, _), Slots) -> V = true ; V = false ).
cpp_trait_of('__is_polymorphic', R, V) :- ( cpp_class_of_type(R, C), cpp_polymorphic(C) -> V = true ; V = false ).
cpp_trait_of('__is_empty', R, V) :- ( cpp_class_of_type(R, C), cpp_class_l(C, cls(B, Data, _, _, _)) -> ( cpp_empty_data(Data), ( B == none ; cpp_trait_of('__is_empty', base([], [typedef(B)]), true) ) -> V = true ; V = false )   % its data members, if any, empty data members (0.198, cpp_empty_data/1)
    ;   catch(ccl_resolve_type(R, base(_, [struct(_, Ms)])), _, fail), Ms \== none, ccl_no_data_members(Ms) -> V = true   % ... and a plain struct, no registered class, by the layout's test (0.198)
    ;   V = false ).
cpp_trait_of('__is_trivially_equality_comparable', R, V) :- ( ( ccl_is_arith(R), R = base(_, S), \+ memberchk(float, S), \+ memberchk(double, S), \+ cpp_enum_type(R) ; R = ptr(_, _) ) -> V = true ; V = false ).   % `a == b' is `memcmp(&a, &b, sizeof(T))': the integral types and pointers, never a FLOAT (0.0 == -0.0 with different bits) and never an ENUM, for which a program may write its own `==' (0.112: std::find over an enum used memcmp and missed the program's operator==; test/cpp/run/enumeq.cpp)
cpp_trait_of('__is_aggregate', R, V) :- ( ( R = arr(_, _) ; cpp_class_of_type(R, C), cpp_aggregate_class(C) ; \+ cpp_class_of_type(R, _), ( R = base(_, [struct(_, _)]) ; R = base(_, [union(_, _)]) ) ) -> V = true ; V = false ).   % a plain struct or union too (0.206): `std::is_aggregate_v<P>' of `struct P { int x; double y; };' was 0
cpp_trait_of('__has_unique_object_representations', R, V) :- ( cpp_unique_repr(R) -> V = true ; V = false ).   % (0.206, cpp_unique_repr/1)
cpp_trait_of('__is_scoped_enum', R, V) :- ( cpp_scoped_enum_value(R) -> V = true ; V = false ).   % C++23's `is_scoped_enum', which libc++ 21 asks the compiler (0.206): it was trait_unknown
cpp_trait_of(N, R, V) :- memberchk(N, ['__builtin_is_implicit_lifetime', '__is_implicit_lifetime']), ( cpp_implicit_lifetime(R) -> V = true ; V = false ).   % (0.206, cpp_implicit_lifetime/1)
%% A TYPE WHOSE VALUE IS ITS BYTES ([meta.unary.prop]: `has_unique_object_representations', C++17; 0.206), as clang 21 answers it:
%% an integral or enumeration type whose bits fill its bytes (a `_BitInt' with padding bits is none), a pointer and a pointer to
%% member; an array of one; a trivially copyable class with no table whose data members and bases each are one and whose bits,
%% bit-fields' widths included, fill its size; a union whose members are and each fill it -- never a floating type, `std::nullptr_t'
%% or an empty class. It was trait_unknown, and libc++ 18 and 21 ask the compiler.
cpp_unique_repr(arr(_, E)) :- !, catch(ccl_resolve_type(E, RE), _, fail), cpp_unique_repr(RE).
cpp_unique_repr(R) :- ( ccl_is_float(R) ; ccl_is_decimal(R) ; ccl_is_complex(R) ), !, fail.
cpp_unique_repr(R) :- R = base(_, S), memberchk(bitint(E), S), !, ccl_bitint_width(E, W), catch(ccl_size_of(R, N), _, fail), W =:= N * 8.
cpp_unique_repr(R) :- ( ccl_is_integer(R) ; R = ptr(_, _) ; R = memptr(_, _, _) ), !.
cpp_unique_repr(R) :- \+ R = ref(_, _), \+ R = rref(_, _), cpp_trivial_type(R), \+ ( cpp_class_of_type(R, C), cpp_polymorphic(C) ),
    ( cpp_class_of_type(R, C), catch(ccl_tag(C, TMs), _, fail), is_list(TMs) -> Ms0 = TMs ; cpp_class_of_type(R, C), cpp_class_l(C, cls(_, Data, _, _, _)) -> Ms0 = Data ; catch(ccl_members_of_(R, Ms0), _, fail) ),   % a class's tag, its base sub-objects among its members
    ccl_data_members(Ms0, Ms), Ms \== [], \+ memberchk(member(_, '$vptr', _), Ms),
    forall(member(member(MT, _, _), Ms), ( catch(ccl_resolve_type(MT, RM), _, fail), cpp_unique_repr(RM) )),
    catch(ccl_size_of(R, Size), _, fail), Bits is Size * 8,
    (   catch(ccl_resolve_type(R, base(_, [union(_, _)])), _, fail)
    ->  forall(member(M, Ms), ( cpp_member_bits(M, MB), MB =:= Bits ))
    ;   cpp_members_bits(Ms, 0, Bits) ).
cpp_members_bits([], B, B).
cpp_members_bits([M|Ms], B0, B) :- cpp_member_bits(M, MB), B1 is B0 + MB, cpp_members_bits(Ms, B1, B).
cpp_member_bits(member(T, _, W), B) :- ( ccl_plain_width(W) -> catch(ccl_size_of(T, N), _, fail), B is N * 8 ; integer(W) -> B = W ; catch(ccl_const_eval(W, B), _, fail) ).   % a bit-field by its width
%% AN IMPLICIT-LIFETIME TYPE ([basic.types.general]/9, [class.prop]/9; C++23's `is_implicit_lifetime', which libc++ 21 asks the
%% compiler; 0.206): a scalar, an array of any type, an aggregate class whose destructor is not user-provided, a class trivial in
%% its constructors and its destructor. It was trait_unknown.
cpp_implicit_lifetime(arr(_, _)) :- !.
cpp_implicit_lifetime(R) :- cpp_trait_of('__is_scalar', R, true), !.
cpp_implicit_lifetime(R) :- cpp_class_of_type(R, C), !, ( cpp_aggregate_class(C), \+ ( cpp_sdecl(C, dtor, B), B \== default ) -> true ; cpp_trivial_class(C) ).
cpp_implicit_lifetime(R) :- ( R = base(_, [struct(_, _)]) ; R = base(_, [union(_, _)]) ), !.   % a plain struct or union
%% AN ENUMERATION IS NO ARITHMETIC TYPE ([basic.fundamental]; an enum is a SCALAR, [basic.types.general]/9): the inference
%% counts an enum as an integer, which C wants, and `is_integral<E>' and `is_arithmetic<E>' were true -- libc++'s std::find
%% took the integral road for an enum (0.112; test/cpp/run/enumeq.cpp)
cpp_arith(R) :- ccl_is_arith(R), \+ cpp_enum_type(R).
cpp_nested_class_named(N) :- '$cpp_nested'(N, _, _, _, nested(base(_, [S]))), ( S = class(K, _, _, _), K \== union ; S = struct(_, _) ), !.   % AN INSTANCE STILL BEING REGISTERED IS A CLASS (0.110): the CRTP -- `ref_view<R> : view_interface<ref_view<R>>', whose constraint asks is_class_v of the class not yet complete
%% A HEADER'S CLASS BEING LOADED IS A CLASS (0.126), as an instance being registered is: a plain class of a header is registered when its name is
%% first asked (cpp_hdr_load marks it '$cpp_lib' first), and its bases are instantiated BEFORE its record exists. libc++ 21's `struct __fn :
%% __range_adaptor_closure<__fn>' asks `requires is_class_v<_Tp> && same_as<_Tp, remove_cv_t<_Tp>>' of its CRTP base while `__fn' is registering:
%% the constraint failed and every `v | views::drop(5)' was `no_operator(|)'. A class definition the index holds, loaded, with no record yet.
cpp_class_in_progress(N) :- atom(N), '$cpp_lib'(N), \+ '$cpp_cls'(N, _), cpp_hdr_item(N, declare(_, base(_, [S]))),
    ( S = class(K, _, _, Ms), K \== union, Ms \== none ; S = struct(_, Ms), Ms \== none ), !.
cpp_enum_type(R) :- ccl_resolve_type(R, base(_, S)), member(X, S), ( X = enum(_, _) ; X = enum_class(_, _) ), !.
%% the traits that name a type
%% THE TOP-LEVEL QUALIFIERS OF A TYPE are a specifier list's or a POINTER's (`char * const'); a reference, an array
%% and a function carry none. The three strippers took only a specifier list and FAILED on a pointer -- and libc++'s
%% is_void is `_BoolConstant<__is_same(__remove_cv(_Tp), void)>', which every pointer_traits asks.
cpp_builtin_type('__remove_cv', [A], T1) :- !, cpp_trait_type(A, T), ccl_resolve_type(T, R), cpp_strip_quals(R, _, T1).
cpp_builtin_type('__remove_const', [A], T1) :- !, cpp_trait_type(A, T), ( T = base(Q, [typedef(N)]), atom(N) -> ccl_delete_one(Q, const, Q1), T1 = base(Q1, [typedef(N)]) ; ccl_resolve_type(T, R), cpp_strip_quals(R, Q, T0), ccl_delete_one(Q, const, Q1), cpp_with_quals(Q1, T0, T1) ).   % a NAMED type keeps its name (a class's, resolved, is its struct spec, which nothing compares well)
cpp_builtin_type('__remove_reference_t', [A], T1) :- !, cpp_trait_type(A, T), ccl_unref(T, T1).
cpp_builtin_type('__remove_cvref', [A], T1) :- !, cpp_trait_type(A, T), ccl_unref(T, T0), ( T0 = base(_, [typedef(N)]), atom(N) -> T1 = base([], [typedef(N)]) ; ccl_resolve_type(T0, R), cpp_strip_quals(R, _, T1) ).
cpp_builtin_type('__remove_extent', [A], T1) :- !, cpp_trait_type(A, T), ( ccl_resolve_type(T, arr(_, E)) -> T1 = E ; T1 = T ).   % an array's element, the array itself one dimension shorter ([meta.trans.arr]): shared_ptr's element_type is `__remove_extent_t<_Tp>'
cpp_builtin_type('__remove_all_extents', [A], T1) :- !, cpp_trait_type(A, T), ( ccl_resolve_type(T, arr(_, E)) -> cpp_builtin_type('__remove_all_extents', [type(E)], T1) ; T1 = T ).
cpp_builtin_type('__add_pointer', [A], ptr([], T)) :- !, cpp_trait_type(A, T0), ccl_unref(T0, T).
cpp_builtin_type('__add_lvalue_reference', [A], T1) :- !, cpp_trait_type(A, T),   % [meta.trans.ref], REFERENCE COLLAPSING: `T &&' takes an lvalue reference and stays one
    ( T = ref(_, _) -> T1 = T ; T = rref(Q, U) -> T1 = ref(Q, U) ; T1 = ref([], T) ).
cpp_builtin_type('__add_rvalue_reference', [A], T1) :- !, cpp_trait_type(A, T),   % ... and an lvalue reference takes an rvalue one and stays an lvalue reference
    ( ( T = ref(_, _) ; T = rref(_, _) ) -> T1 = T ; T1 = rref([], T) ).
cpp_builtin_type('__decay', [A], T1) :- !, cpp_trait_type(A, T), ccl_unref(T, T0), cpp_decayed(T0, T1).
cpp_builtin_type('__add_pointer', [A], ptr([], T1)) :- !, cpp_trait_type(A, T), ccl_unref(T, T1).
cpp_builtin_type('__remove_pointer', [A], T1) :- !, cpp_trait_type(A, T), ( ccl_resolve_type(T, ptr(_, T1)) -> true ; T1 = T ).
%% the signed and unsigned counterparts, which libc++ takes a type's DIGITS from
%% (`__builtin_popcountg(~__make_unsigned_t<type>(0))'): the qualifiers kept, an enum through its underlying type
cpp_builtin_type('__make_unsigned', [A], T1) :- !, cpp_trait_type(A, T), cpp_signedness(unsigned, T, T1).
cpp_builtin_type('__make_signed', [A], T1) :- !, cpp_trait_type(A, T), cpp_signedness(signed, T, T1).
%% `__underlying_type(E)' (0.117): a fixed enum's own type (a scoped enum without one has `int', which the reader wrote down), else clang's
%% choice for an enum with none -- `unsigned int', or `int' where an enumerator is negative. libc++ 18's `memory_order' is `enum class
%% memory_order : __memory_order_underlying_t' over `typedef underlying_type<__legacy_memory_order>::type', so every `-std=c++20' program
%% that called `atomic<int>::store' met the unknown trait. `stdatomic20.cpp'.
cpp_builtin_type('__underlying_type', [A], U) :- !, cpp_trait_type(A, T), cpp_underlying_of(T, U).
cpp_builtin_type(N, _, _) :- cpp_refuse(0, trait_unknown(N)).
cpp_strip_quals(base(Q, S), Q, base([], S)) :- !.
cpp_strip_quals(ptr(Q, T), Q, ptr([], T)) :- !.
cpp_strip_quals(arr(K, E0), Q, arr(K, E)) :- !, cpp_strip_quals(E0, Q, E).   % AN ARRAY'S cv-QUALIFIERS ARE ITS ELEMENT'S ([basic.type.qualifier]/3; 0.167): `remove_const_t<const char[4]>' is `char[4]', which libc++'s format takes as a string
cpp_strip_quals(T, [], T).
cpp_with_quals(Q, base(_, S), base(Q, S)) :- !.
cpp_with_quals(Q, ptr(_, T), ptr(Q, T)) :- !.
cpp_with_quals(Q, arr(K, E0), arr(K, E)) :- !, cpp_with_quals(Q, E0, E).
cpp_with_quals(_, T, T).
cpp_underlying_of(T, U) :- ccl_resolve_type(T, base(_, [enum(_, Ms)])), !,
    (   Ms = [enum_base(B)|_], \+ ( B = base(BQ, [int]), memberchk(packed_enum, BQ) ) -> ccl_enum_base_plain(B, U)   % GCC's `aligned' on an enum written with no base keeps the values' type (0.205)
    ;   member(enumerator(EN, _), Ms), ccl_enum_value(EN, X), number(X), X < 0 -> U = base([], [int])
    ;   U = base([], [unsigned]) ).
cpp_underlying_of(_, _) :- cpp_refuse(0, underlying_type_of_a_non_enum).
cpp_signedness(W, T0, base(Q, S1)) :- ccl_resolve_type(T0, base(Q, S0)), cpp_int_spec(S0, S), !, cpp_sign_spec(W, S, S1).
cpp_signedness(_, T, T).
%% the integer a specifier list names, its own signedness dropped: [unsigned, long] and [long] are both long
cpp_int_spec(S0, S) :- findall(X, ( member(X, S0), X \== signed, X \== unsigned ), S), S \== [], cpp_integer_spec(S).
cpp_integer_spec(S) :- ( memberchk(char, S) ; memberchk(short, S) ; memberchk(int, S) ; memberchk(long, S) ; memberchk('__int128', S) ; memberchk('_Bool', S) ).
cpp_sign_spec(unsigned, S, [unsigned|S]).
cpp_sign_spec(signed, S, [signed|S]).
cpp_is_type(T) :- ( T = base(_, _) ; T = ptr(_, _) ; T = ref(_, _) ; T = rref(_, _) ; T = arr(_, _) ; T = fn(_, _, _) ; T = memptr(_, _, _) ), !.
cpp_merge_quals(Q, base(Q2, S), base(Q3, S)) :- !, append(Q, Q2, Q3).
cpp_merge_quals(Q, ptr(Q2, P), ptr(Q3, P)) :- !, append(Q, Q2, Q3).        % `const T' with T a POINTER is a const pointer ([dcl.type.cv]: the qualifier applies to the type named), where the qualifiers were dropped -- `add_const<int *>::type' was `int *', and libc++ 18's is_copy_constructible asks `__add_lvalue_reference_t<typename add_const<_Tp>::type>' of every iterator (0.93)
cpp_merge_quals(Q, arr(N, E0), arr(N, E)) :- !, cpp_merge_quals(Q, E0, E).  % ... and with T an array, its elements' ([basic.type.qualifier])
cpp_merge_quals(_, A, A).                                                   % a reference takes no qualifier of its own ([dcl.ref]), a function none
