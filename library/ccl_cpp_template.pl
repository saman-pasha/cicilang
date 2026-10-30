%% ccl_cpp_template.pl -- templates, instantiated on use: a header's templates joining the program's, the types and
%% typedefs a walk names, decltype, the emitted items, an instance asked again, a class template's member defined out
%% of its class, extern templates, specializations and partial ordering, variable templates, the candidate sets. A
%% part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there, in their order.

%% ---- templates, instantiated on use --------------------------------------------------
%% '$cpp_templates' = [Name-tmpl(TParams, Item) ...]; '$cpp_instances' = [InstanceName-Template ...];
%% '$cpp_instance_items' the items the instances made, newest first
cpp_template_name(function(_, _, _, N, _, _, _), N) :- atom(N).
cpp_template_name(function(_, _, _, operator(Op), Ps, _, _), N) :- cpp_free_operator(Op, Ps, N).   % a FREE OPERATOR TEMPLATE: named by its word and arity, as a written-out one is, so a header indexes and registers it
cpp_template_name(declare(_, base(_, [class(_, N, _, _)])), N) :- atom(N).
cpp_template_name(declare(_, base(_, [struct(N, _)])), N) :- atom(N).
cpp_template_name(declare(_, base(_, [class(N, none)])), N) :- atom(N).                     % a forward declaration (its defaults count)
cpp_template_name(declare(_, base(_, [union(N, _)])), N) :- atom(N).
cpp_template_name(declaration(_, _, _, [var(N, _, _)]), N) :- atom(N).      % a variable template
cpp_template_name(declaration(_, _, _, [var(operator(Op), fn(_, Ps, _), _)]), N) :- cpp_free_operator(Op, Ps, N).   % A FREE OPERATOR TEMPLATE'S DECLARATION (0.126), as its definition is: libc++ 21 declares `template <class _Tp, __enable_if_t<is_floating_point<_Tp>::value, int> = 0> complex<_Tp> operator*(const complex<_Tp> &, const complex<_Tp> &);' and defines it later WITHOUT the default, which only the declaration gives (cpp_fn_merge_defaults) -- unregistered, the definition's `$anon2' had none, `cannot_deduce($anon2)' dropped it, and `a * b' of two complex<double> had no operator (stdcomplex.cpp, enabledecl.cpp)
cpp_template_name(deduction_guide(_, N, _, _), G) :- atom(N), atom_concat('$guide.', N, G).   % a DEDUCTION GUIDE, by its class's name under `$guide.' (0.108): `pair(_T1, _T2) -> pair<_T1, _T2>'
cpp_template_name(concept(_, N, _), N) :- atom(N).                           % a CONCEPT (C++20): indexed by its name, registered on the first ask (cpp_hdr_join_concept)
cpp_template_name(typedef(_, [var(N, _, _)]), N) :- atom(N).                 % an alias template
cpp_template(N, TPs, Item) :- cpp_hdr_join(N), '$cpp_tmpl'(N, TPs, Item).
%% A HEADER'S TEMPLATES AND FUNCTIONS OF A NAME JOIN THE PROGRAM'S, one overload set: loaded on the first ask whether
%% or not the program has one already -- a friend `operator<<' of the program's class registered `op.shl.2' first,
%% the lookup found it and never loaded libc++'s inserters, and every string went to the `const void *' member
cpp_hdr_join(N) :- ( atom(N), cpp_hdr_item(N, _) -> ( cpp_hdr_load(N) -> true ; true ) ; true ).
%% a class template's primary: the definition when one was read after a forward declaration
cpp_class_template(N, TPs, Item) :- ( '$cpp_tmplh'(N, _, _, _) -> true ; cpp_hdr_load(N) ),   % the light record (cpp_tmpl_kind/2): no item copied but the one chosen (0.241)
    (   '$cpp_tmplh'(N, TPs0, class_def, _) -> K = class_def                    % a class's definition first (std::pmr::vector, an alias, shares the flattened name)
    ;   '$cpp_tmplh'(N, TPs0, defined, _) -> K = defined
    ;   '$cpp_tmplh'(N, TPs0, _, _) -> K = any ),
    cpp_tmpl_item(N, TPs0, K, Item),
    findall(N-tmpl(TPs2, x), '$cpp_tmplh'(N, TPs2, _, _), Ts), cpp_merge_defaults(N, TPs0, Ts, TPs).
%% the item of the first clause of the kind the light record chose: its parameters, bound, pass every other clause by without its item
cpp_tmpl_item(N, TPs, any, Item) :- !, '$cpp_tmpl'(N, TPs, Item), !.
cpp_tmpl_item(N, TPs, K, Item) :- '$cpp_tmpl'(N, TPs, Item), cpp_tmpl_kind(Item, K), !.
%% TWO CLASS TEMPLATES OF ONE FLATTENED NAME, from two headers' summaries (0.117): `<variant>' defines `template <class _Tp, size_t _Idx>
%% struct __overload' in `std::__variant_detail', and `<__algorithm/copy_move_common.h>' `template <class _F1, class _F2> struct __overload
%% : _F1, _F2' in `std' -- the namespace keys (cpp_ns_quals) tell two paths apart only inside ONE flattened unit, and `<iterator>' pulls
%% `<variant>' in without the algorithm, so the variant's took the bare name and `std::copy' of trivially copyable ints, reached from
%% `std::vector<int> v = {1, 2, 3}', found the wrong `__overload' (arity_mismatch). Where the name has class templates of DIFFERENT
%% parameter kinds, the first whose parameters bind the arguments is the one (C++ has the namespaces; the flattening lost them).
cpp_class_template(N, Args, TPs, Item) :-
    findall(K0, ( '$cpp_tmplh'(N, TPs0, class_def, _), cpp_tparam_kinds(TPs0, K0) ), Ks0), sort(Ks0, Ks), Ks = [_, _|_],   % the kinds from the light record (0.241)
    findall(K-(TPs1-Item1), ( '$cpp_tmpl'(N, TPs1, Item1), cpp_template_class_def(Item1), cpp_tparam_kinds(TPs1, K) ), Rows),
    member(_-(TPs-Item), Rows), cpp_kinds_fit(TPs, Args), catch(cpp_bind_targs(TPs, Args, _), error(not_lowered(_), _), fail), !.
cpp_class_template(N, _, TPs, Item) :- cpp_class_template(N, TPs, Item).
cpp_tparam_kinds([], []).
cpp_tparam_kinds([tparam(K, _, _)|Ps], [F/A|Ks]) :- !, functor(K, F, A), cpp_tparam_kinds(Ps, Ks).
cpp_tparam_kinds([_|Ps], Ks) :- cpp_tparam_kinds(Ps, Ks).
%% the arguments' KINDS against the parameters': a type for a type parameter, anything but a type for a value one, a pack takes the rest
cpp_kinds_fit([], []).
cpp_kinds_fit([requires(_)|Ps], As) :- !, cpp_kinds_fit(Ps, As).
cpp_kinds_fit([ttp(_, _)|Ps], As) :- !, cpp_kinds_fit(Ps, As).
cpp_kinds_fit([tparam(K, _, _)|_], _) :- ( K == pack ; K = vpack(_) ), !.
cpp_kinds_fit([tparam(K, _, _)|Ps], [A|As]) :- !, cpp_kind_fits(K, A), cpp_kinds_fit(Ps, As).
cpp_kinds_fit([tparam(_, _, D)|Ps], []) :- D \== none, cpp_kinds_fit(Ps, []).
cpp_kind_fits(type, A) :- !, cpp_is_type(A).
cpp_kind_fits(template, _) :- !.
cpp_kind_fits(_, A) :- \+ cpp_is_type(A).
%% a default the definition lacks comes from another declaration of the name (C++ merges them), its parameters renamed to these
cpp_merge_defaults(N, TPs0, Ts, TPs) :- findall(TPs2, ( member(N-tmpl(TPs2, _), Ts), TPs2 \== TPs0, length(TPs2, K), length(TPs0, K) ), Others), cpp_merge_defaults_(TPs0, 1, TPs0, Others, TPs).
cpp_merge_defaults_([], _, _, _, []).
cpp_merge_defaults_([tparam(K, P, none)|Ps], I, All, Others, [tparam(K, P, D)|Qs]) :-
    member(TPs2, Others), ccl_nth(I, TPs2, tparam(_, _, D2)), D2 \== none, !,
    cpp_rename_params(TPs2, All, B), cpp_subst(D2, B, D), I1 is I + 1, cpp_merge_defaults_(Ps, I1, All, Others, Qs).
cpp_merge_defaults_([P|Ps], I, All, Others, [P|Qs]) :- I1 is I + 1, cpp_merge_defaults_(Ps, I1, All, Others, Qs).
cpp_rename_params([], [], []).
cpp_rename_params([tparam(K, P2, _)|Ps2], [tparam(_, P, _)|Ps], B) :- ( P2 == P -> B = B1 ; ( K == type ; K == pack ; K == template ) -> B = [P2-base([], [typedef(P)])|B1] ; B = [P2-id(P)|B1] ), cpp_rename_params(Ps2, Ps, B1).
cpp_rename_params([requires(_)|Ps2], Ps, B) :- cpp_rename_params(Ps2, Ps, B).
cpp_rename_params([ttp(_, _)|Ps2], Ps, B) :- cpp_rename_params(Ps2, Ps, B).
cpp_rename_params(Ps2, [requires(_)|Ps], B) :- cpp_rename_params(Ps2, Ps, B).
cpp_rename_params(Ps2, [ttp(_, _)|Ps], B) :- cpp_rename_params(Ps2, Ps, B).
cpp_template_class_def(declare(_, base(_, [class(_, _, _, Ms)]))) :- Ms \== none.
cpp_template_class_def(declare(_, base(_, [struct(_, Ms)]))) :- Ms \== none.
cpp_template_class_def(declare(_, base(_, [union(_, Ms)]))) :- Ms \== none.
%% a template-id as a type: a class template's instance, or an alias template's type under the bindings
cpp_instantiate_type(N, Args, T) :- atom(N), cpp_nested_template(N, MN), !, cpp_instantiate_type(MN, Args, T).   % a MEMBER CLASS TEMPLATE named bare inside its class, whatever road asks (cpp_path_class walks `_CheckArrayPointerConversion<_Pp>::value' here)
cpp_instantiate_type(N, Args, T) :- atom(N), cpp_nested_alias(N, C, TPs, T0), !,                                          % a MEMBER ALIAS TEMPLATE named bare inside its class: optional's `_CheckOptionalArgsCtor<_Up>::template __enable_implicit<_Up>()' (0.47 resolved one only through `C::template _Select<A, B>')
    cpp_targ_values(Args, Args1), cpp_alias_args_fit(N, TPs, Args1), cpp_bind_targs(TPs, Args1, B), cpp_in_class(C, ( cpp_subst(T0, B, T1), cpp_type(T1, T) )).   % no more arguments than parameters (0.182; below)
cpp_instantiate_type(N, Args, T) :- cpp_instantiate_type_ns(N, Args, T).
cpp_instantiate_type_ns('__make_integer_seq', [A1, TA, NA], T) :- !,                          % CLANG'S BUILTIN TEMPLATE `__make_integer_seq<S, T, N>' IS `S<T, 0, 1, ..., N-1>': libc++'s index sequences, which the piecewise pair behind map::operator[] is built on
    ( A1 = tname(B) -> true ; A1 = base(_, [typedef(B)]), atom(B) ),
    ( cpp_targ_value(NA, NV) -> true ; NV = NA ), ( ccl_const_eval(NV, N) -> true ; cpp_refuse(0, integer_seq_size(NA)) ),
    findall(int(I), ( between(1, N, I0), I is I0 - 1 ), Is),
    cpp_type(base([], [typedef(tmpl(B, [TA|Is]))]), T).
cpp_instantiate_type_ns('__type_pack_element', [NA|Ts], T) :- !,                                % CLANG'S BUILTIN `__type_pack_element<I, Ts...>' IS THE I-TH OF Ts: libc++'s tuple_element, which tuple's get<I> is typed by
    ( cpp_targ_value(NA, NV) -> true ; NV = NA ), ( ccl_const_eval(NV, I) -> true ; cpp_refuse(0, type_pack_index(NA)) ),
    ( nth0(I, Ts, T0) -> true ; cpp_refuse(0, type_pack_index(NA)) ), cpp_type(T0, T).
cpp_instantiate_type_ns(N, Args, T) :-
    (   cpp_class_template(N, TPs, Item), Item = typedef(_, [var(_, T0, _)]) -> cpp_alias_args_fit(N, TPs, Args), cpp_bind_targs(TPs, Args, B), cpp_subst(T0, B, T1), cpp_type(T1, T)   % an alias template (the class definition wins the name)
    ;   cpp_instantiate_class(N, Args, Name), T = base([], [typedef(Name)]) ).
%% A TEMPLATE-ID QUALIFIED BY A SCOPE NAMES THAT SCOPE'S TEMPLATE, NEVER A MEMBER TEMPLATE OF THE CLASS BEING WALKED
%% ([basic.lookup.qual]/1; 0.182): the clauses of cpp_type/2 before the door take a class's own member templates through the
%% class, and what comes here qualified is a namespace's, which flattens. libc++ 22's vector declares `template <class _Up,
%% class _Alloc> using __split_buffer = std::__split_buffer<_Up, _Alloc, __split_buffer_pointer_layout>;', and the alias's
%% body, flattened, found the alias again in vector's class context, binding two of its three arguments, without end and
%% with no trace line: every std::vector over libc++ 22 ran past the memory cap.
cpp_instantiate_type_of(X, N, Args, T) :- ( X = scoped(_, _) -> cpp_instantiate_type_ns(N, Args, T) ; cpp_instantiate_type(N, Args, T) ).
%% AN ALIAS TEMPLATE TAKES NO MORE ARGUMENTS THAN IT HAS PARAMETERS ([temp.arg]/1; 0.181), a pack aside: more is no use of
%% it, refused by name. cpp_bind_targs/3 dropped the arguments past the parameters, and an alias whose body names its own
%% flattened name -- std::pmr::basic_string, `std::basic_string<_CharT, _Traits, polymorphic_allocator<_CharT>>', bare
%% beside a class template that <iosfwd> declares and nothing defines -- resolved itself without end: a call over
%% `const std::string &' with <string> unread ran to the memory cap with no trace line (exceptionptr.cpp, <stdexcept>'s
%% runtime_error). Such an alias is keyed apart since (cpp_qualify_item/4); this stops any other such loop by its name
cpp_alias_args_fit(N, TPs, Args) :-
    (   ( member(tparam(K, _, _), TPs), cpp_pack_kind(K) ; memberchk(pack(_), Args) ) -> true
    ;   findall(x, member(tparam(_, _, _), TPs), Ps), length(Ps, NP), length(Args, NA), NA =< NP -> true
    ;   cpp_refuse(0, too_many_template_arguments(N)) ).
cpp_nested_alias(N, C, TPs, T0) :- nb_getval('$cpp_class_ctx', C0), atom(C0), C0 \== none, cpp_nested_alias_of(C0, N, C, TPs, T0).
cpp_nested_alias_of(C, N, C, TPs, T0) :- '$cpp_mt'(C, N, TPs, typedef(_, [var(_, T0, _)|_])), !.
cpp_nested_alias_of(C, N, C1, TPs, T0) :- cpp_enclosing(C, EC), !, cpp_nested_alias_of(EC, N, C1, TPs, T0).
cpp_nested_alias_of(C, N, C1, TPs, T0) :- cpp_base_scope(C, B), cpp_nested_alias_of(B, N, C1, TPs, T0), !.
cpp_template_defined(declare(_, base(_, [class(_, _, _, Ms)]))) :- Ms \== none.
cpp_template_defined(declare(_, base(_, [struct(_, Ms)]))) :- Ms \== none.
cpp_template_defined(declare(_, base(_, [union(_, Ms)]))) :- Ms \== none.
cpp_template_defined(declaration(_, _, _, _)).
cpp_template_defined(typedef(_, _)).
%% template arguments as the bindings take them: a type resolved, an expression desugared and folded to its constant
cpp_targ_values([], []).
cpp_targ_values([A0|As], [A|Bs]) :- cpp_targ_value(A0, A), cpp_targ_values(As, Bs).
cpp_targ_value(type(T0), T) :- !, cpp_type(T0, T).
cpp_targ_value(A0, tname(mt(C, N))) :- ( A0 = base(_, [typedef(scoped(Path, N))]) ; A0 = scoped(Path, N) ), atom(N), Path \== [], catch(cpp_scope_class(Path, C0), _, fail), cpp_member_alias_of(C0, N, C, _, _), !.   % `Tester::template Apply' with no arguments: a member alias template's NAME, a template template argument (0.109)
cpp_targ_value(base([], [typedef(scoped(Path, N))]), A) :- atom(N), cpp_scope_class(Path, C), \+ cpp_class_typedef(C, N, _), !,   % a NAME: `X<T>::value'; a template-id last, `C::template ap<T>', is a member alias template and a TYPE, taken below (0.93)   % X<T>::value read as a type: the class has no such type, so a value
    ( cpp_static_const(C, N, _) -> true ; cpp_static_member(C, N, _) -> true ; cpp_refuse(0, no_member_type(C, N)) ),   % ... unless it has no such MEMBER either: `typename _Up::category' on a class without one, which is the SFINAE that rejects the candidate
    cpp_targ_value(scoped(Path, N), A).
cpp_targ_value(base([], [typedef(scoped(Path, N))]), A) :- cpp_enumerator(Path, N, V), !, cpp_enum_targ(Path, N, V, A).   % A SCOPED ENUMERATOR AS A TEMPLATE ARGUMENT IS ITS VALUE (0.93): `__base<_Trait::_TriviallyAvailable, _Types...>' in libc++'s variant, `holder<Trait::two, 5>' -- read as a type and keyed by its spelling, `scopedTraittwo', the static it fed never folded
cpp_targ_value(scoped(Path, N), A) :- cpp_enumerator(Path, N, V), !, cpp_enum_targ(Path, N, V, A).
%% A SCOPED NAME THAT IS A TYPE OF ITS CLASS IS A TYPE ARGUMENT (0.100): in an EXPRESSION, `is_same<iterator_traits<int *>::
%% iterator_category, random_access_iterator_tag>::value', the reader gives the argument as the value form `scoped(Path, N)'
%% (it cannot know the member is a type), and walked as an expression it became the static member's name
%% `id('iterator_traits.int_p.iterator_category')' -- keyed so, `is_same' compared two spellings and answered 0, which is how
%% libc++ 18's `move_iterator::iterator_category' (an `_If' over that trait) came out wrong for vector::insert
cpp_targ_value(scoped(Path, N), T) :- atom(N), cpp_scope_class(Path, C), cpp_class_typedef(C, N, _), !, cpp_type(base([], [typedef(scoped(Path, N))]), T).
cpp_targ_value(base(_, [typedef(X)]), bool(V)) :- cpp_template_id(X, N, Args0), cpp_concept_known(N), !,   % a CONCEPT-ID as a template argument is its truth: `conditional_t<__primary_template<iterator_traits<...>>, ...>' (C++20's iterator_traits)
    cpp_targ_values(Args0, Args), ( cpp_concept_holds(N, Args) -> V = true ; V = false ).
cpp_targ_value(base(_, [typedef(X)]), A) :- cpp_template_id(X, N, Args0), cpp_variable_template(N), !,   % `integral_constant<bool, __is_floating_point_impl<T>>': read as a type, it is a VARIABLE template's value
    cpp_targ_values(Args0, Args), cpp_instantiate_variable(N, Args, A).
%% `X::template f<U>()' in a template argument reads as a FUNCTION TYPE returning `X::f<U>' and taking nothing --
%% the reader cannot know that f is a member function template, where C++ knows it from the class. The class
%% does know: where it HAS such a member template, the argument is the CALL it means and its VALUE is asked
%% (libc++'s pair, `__enable_if_t<_CheckArgsDep::template __is_pair_constructible<_U1, _U2>(), int> = 0').
cpp_targ_value(fn(base([], [typedef(scoped(Path, tmpl(M, TArgs)))]), [], false), A) :- atom(M), cpp_scope_class(Path, C), '$cpp_mt'(C, M, _, _), !,
    cpp_targ_value(call(scoped(Path, tmpl(M, TArgs)), []), A).
cpp_targ_value(A0, A) :- ( A0 = id(N) -> true ; A0 = base(_, [typedef(N)]) ), atom(N), cpp_class_ctx(Cx), Cx \== none, \+ cpp_class_typedef(Cx, N, _, _), cpp_static_const(Cx, N, V), !, A = V.   % A STATIC CONST NAMED BARE AS A TEMPLATE ARGUMENT folds to its value, as it does in an expression (0.60): libc++'s find calls `std::__str_find<value_type, size_type, traits_type, npos>(...)', and read as a type the name keyed the instance and reached its body undeclared
%% A NAME CALLED WITH NO ARGUMENT, `rank()', READS AS A FUNCTION TYPE RETURNING `rank' in a template argument too: [temp.arg]/2
%% takes the type-id only where it IS one, and a name that a static member function of the class the argument is written in
%% hides -- its bases' and enclosing classes' -- or that a path names a static member function of, is none. The argument is the
%% CALL it means and its VALUE is asked (0.201): libc++'s mdspan writes `make_index_sequence<rank()>()' and `array<_OtherIndexType,
%% rank()>', and its layouts `array<index_type, extents_type::rank()>', where <type_traits>' class template `rank' made the
%% name a type and `__make_integer_seq' met a function type (`integer_seq_size').
cpp_targ_value(fn(base([], [typedef(N)]), [], false), A) :- atom(N), cpp_class_ctx(Cx), Cx \== none, \+ cpp_class_typedef(Cx, N, _), cpp_static_fn_called(Cx, N), !,
    cpp_targ_value(call(id(N), []), A).
cpp_targ_value(fn(base([], [typedef(scoped(Path, N))]), [], false), A) :- atom(N), catch(cpp_scope_class(Path, C), _, fail), \+ cpp_class_typedef(C, N, _), cpp_static_fn_owner(C, N, _), !,
    cpp_targ_value(call(scoped(Path, N), []), A).
cpp_targ_value(A0, A) :- cpp_is_type(A0), !, cpp_type(A0, A).
cpp_targ_value(pack(X), pack(X)) :- !.
cpp_targ_value(A0, A) :- ( cpp_class_ctx(Cx) -> true ; Cx = none ), cpp_expr(Cx, A0, A1),   % IN THE CLASS the argument is written in, as a decltype's expression is: libc++'s __value_func::swap declares `aligned_storage<sizeof(__buf_)>::type __tempbuf', and walked with no context `__buf_' was a name with no type and the bound did not fold
    ( A1 = bool(_) -> A = A1 ; cpp_const_value(A1, V) -> cpp_typed_value(A1, V, A) ; A = A1 ).
%% A VALUE ARGUMENT KEEPS ITS TYPE ([temp.arg.nontype]/1; 0.199): the folded constant is a literal of the argument's own
%% type -- `int', `unsigned', `long', `unsigned long', `char', `bool', and `long long' and `unsigned long long' as the casts
%% their literals are -- so that `template <auto N>' over `'a'' is a `char' in its instance and `X<'a'>' another class than
%% `X<97>'; a type no literal spells (an enumeration, `short', a character type but `char') and a value past 2^60 keep the
%% `int' they were. A parameter of a written type converts the argument to it where it is bound (cpp_vbinds_typed/3).
cpp_typed_value(A1, V, A) :- integer(V), catch(ccl_type_of(A1, T), _, fail), T \== unknown, ( cpp_value_lit(T, V, A0) -> true ; cpp_enum_value_lit(T, V, A0) ), !, A = A0.
cpp_typed_value(_, V, int(V)).
%% AN ENUMERATION'S VALUE AS A TEMPLATE ARGUMENT KEEPS ITS TYPE too (0.203; [temp.arg.nontype]/1): the cast of its value to the enum,
%% named by its tag, so that `X<Color::Red>' and `X<0>' of a placeholder are two classes, `decltype' of the value is the enumeration,
%% and the type information spells it (`1XIL5Color0EE'). It was its number, an int
cpp_enum_value_lit(T, V, cast(base([], [typedef(Tag)]), int(V))) :- catch(ccl_resolve_type(T, R), _, fail), R = base(_, [E]), compound(E), ( E = enum(Tag, _) ; E = enum_class(Tag, _) ), atom(Tag), Tag \== anon.
cpp_enum_targ(Path, N, V, A) :- integer(V), ( cpp_class_ctx(Cx) -> true ; Cx = none ), ( cpp_enum_path_tag(Cx, Path, Tag) -> true ; cpp_ns_enum_tag(Path, N, _, Tag) -> true ; cpp_hdr_enum_tag(Path, N, Tag) ), atom(Tag), !, A = cast(base([], [typedef(Tag)]), int(V)).
cpp_enum_targ(_, _, V, int(V)).
cpp_value_lit(T, V, A) :- catch(ccl_resolve_type(T, R), _, fail), R = base(_, Sp), \+ ( member(X, Sp), compound(X) ), cpp_canon_specs(Sp, Cs), cpp_value_lit_(Cs, V, A), !.
cpp_value_lit_(_, V, int(V)) :- \+ integer(V), !.
cpp_value_lit_([int], V, int(V)).
cpp_value_lit_([unsigned], V, uint(V)).
cpp_value_lit_([long], V, long(V)).
cpp_value_lit_([unsigned, long], V, ulong(V)).
cpp_value_lit_([long, long], V, cast(base([], [long, long]), long(V))).
cpp_value_lit_([unsigned, long, long], V, cast(base([], [unsigned, long, long]), ulong(V))).
cpp_value_lit_([char], V, chr(V)).
cpp_value_lit_([bool], V, bool(B)) :- ( V =:= 0 -> B = false ; B = true ).
cpp_value_lit_([wchar_t], V, wchr(V)).
cpp_value_lit_([char16_t], V, u16chr(V)).
cpp_value_lit_([char32_t], V, u32chr(V)).
cpp_value_lit_([char8_t], V, cast(base([], [char8_t]), chr(V))).
cpp_value_lit_(Cs, V, cast(base([], Cs), int(V))) :- memberchk(Cs, [[short], [unsigned, short], [signed, char], [unsigned, char], ['__int128'], [unsigned, '__int128']]).
cpp_enum_scope(Path) :- append(_, [E], Path), atom(E), ccl_tag(E, Ms), Ms \== none, ccl_is_enum_tag(Ms).   % the enum's name last (the namespaces before it flatten away); its enumerators are global names
cpp_variable_template(N) :- atom(N), catch(cpp_template(N, _, declaration(_, _, _, [var(_, _, _)|_])), _, fail),
    \+ ( cpp_template(N, _, I), cpp_template_class_def(I) ), !.
%% every type the walk meets goes through here: a template-id becomes its instance's name
cpp_type(T0, T) :- \+ compound(T0), !, T = T0.
%% A SCOPED NAME AN EXPRESSION WALK TURNED INTO `id(N)' IS THE TYPEDEF N (0.93): a builtin trait's `type(...)' argument goes
%% through the expression walk, which makes `typename add_const<int>::type' the name `add_const.int.type' wrapped in `id',
%% and the type-call road unwrapped that by hand (cpp_type_call's caller) where `__is_same' and `__is_constructible' did not
%% -- so libc++ 18's is_copy_constructible, `__is_constructible(_Tp, __add_lvalue_reference_t<typename add_const<_Tp>::type>)',
%% compared a name with a type and answered 0 for every pointer. One door for every road.
cpp_type(base(Q, [typedef(id(N))]), T) :- !, cpp_type(base(Q, [typedef(N)]), T).
cpp_type(base(Q, [typedef(tmpl(N, Args))]), T) :- atom(N), cpp_nested_template(N, MN), !, cpp_type(base(Q, [typedef(tmpl(MN, Args))]), T).   % a MEMBER CLASS TEMPLATE named bare in its class (cpp_nested_template_put)
cpp_type(base(Q, [typedef(scoped(Path, tmpl(N, Args)))]), T) :- atom(N), cpp_scope_class(Path, C), cpp_nested_template_of(C, N, MN), !, cpp_type(base(Q, [typedef(tmpl(MN, Args))]), T).   % ... or through its class
cpp_type(base(Q, [typedef(scoped(Path, tmpl(N, Args)))]), T) :-                            % C::template _Select<A, B>: the class's member ALIAS template, in the class's own words
    cpp_scope_class(Path, C0), cpp_member_alias_of(C0, N, C, TPs, T0), !,   % ... its own, or a BASE's (0.109): libc++'s `_ITER_CONCEPT' is `__iter_concept_cache<I>::type::template _Apply<I>', the tester's alias through two bases
    cpp_targ_values(Args, Args1), cpp_bind_targs(TPs, Args1, B), cpp_in_class(C, ( cpp_subst(T0, B, T1), cpp_type(T1, T2) )), cpp_merge_quals(Q, T2, T).
%% ... and a name QUALIFIED BY A NAMESPACE whose items were indexed apart (cpp_ns_quals), which is the only way
%% to tell `__function::__maybe_derive_from_unary_function<_Rp(_ArgTypes...)>' from the `std::' one of that name
cpp_type(base(Q, [typedef(scoped(Path, tmpl(N, Args)))]), T) :- atom(N), cpp_ns_key(Path, N, K), !, cpp_type(base(Q, [typedef(tmpl(K, Args))]), T).
cpp_type(base(Q, [typedef(scoped(Path, N))]), T) :- atom(N), cpp_ns_key(Path, N, K), !, cpp_type(base(Q, [typedef(K)]), T).
%% ... or, where two headers' reads declare the name in two namespaces and no read keyed it apart, by the qualifier's namespace's
%% items under a key of their own (0.218, cpp_cross_key/3): `__itoa::__traits<_Tp>' after <string>'s `__variant_detail::__traits'
cpp_type(base(Q, [typedef(scoped(Path, tmpl(N, Args)))]), T) :- atom(N), is_list(Path), cpp_cross_key(Path, N, K), !, cpp_type(base(Q, [typedef(tmpl(K, Args))]), T).
cpp_type(base(Q, [typedef(scoped(Path, N))]), T) :- atom(N), is_list(Path), cpp_cross_key(Path, N, K), !, cpp_type(base(Q, [typedef(K)]), T).
cpp_type(base(Q, [typedef(K)]), T) :- atom(K), cpp_hdr_keyed_typedef(K, T0), !, cpp_merge_quals(Q, T0, T1), cpp_type(T1, T).   % A HEADER'S KEYED TYPEDEF is its definition (0.201): `std::pmr::string', `pmr.string' (cpp_ns_typedef_quals/3)
cpp_type(base(Q, [typedef(tmpl(N, Args))]), T) :- atom(N), cpp_using_type_key(N, template, K), !, cpp_type(base(Q, [typedef(tmpl(K, Args))]), T).   % a header's keyed CLASS TEMPLATE named bare through a using of its namespace (0.161; below)
cpp_type(base(Q, [typedef(X)]), T) :- cpp_template_id(X, N, [C, A, B]), cpp_conditional_alias(N), catch(cpp_targ_value(C, CV), _, fail), cpp_truth(CV, Tr), !,   % THE ARM THE CONDITION TAKES, and only that one (0.136): `__writer_container<void>' in libc++'s `__writer_selector' is never completed
    ( Tr == true -> cpp_type(A, T0) ; cpp_type(B, T0) ), cpp_merge_quals(Q, T0, T).
cpp_type(base(Q, [typedef(X)]), T) :- cpp_template_id(X, N, Args), !,                       % the traces fire only under '$cpp_trace': a failure here is otherwise silent
    ( cpp_targ_values(Args, Args1) -> true ; cpp_trace(targ_values_failed(N)), fail ),
    ( cpp_instantiate_type_of(X, N, Args1, T0) -> true ; cpp_trace(instantiate_failed(N)), fail ),
    cpp_merge_quals(Q, T0, T).
cpp_type(base(Q, [typedef(scoped(Path, N))]), T) :- cpp_scope_class(Path, C), !,           % C::value_type, X<T>::type: the class's typedef (none: no type -- what SFINAE reads)
    ( atom(N), atom(C) -> ( cpp_class_ctx(Cx) -> true ; cpp_body_ctx(Cx) ), cpp_check_access(Cx, C, N) ; true ),   % A NESTED TYPE'S NAME has its access (0.127): `Outer::Secret' outside Outer, its members and its friends is refused
    ( cpp_class_typedef(C, N, T0, Def) -> cpp_ctype_resolve(Def, T0, T1), cpp_merge_quals(Q, T1, T), cpp_touch_nested(T1) ; cpp_refuse(0, no_member_type(C, N)) ).
cpp_type(base(Q, [decltype(call(id('__builtin_source_location'), []))]), T) :- !, cpp_srcloc_ptr_type(T0), cpp_merge_quals(Q, T0, T).   % its type alone, no place made (0.166): libc++'s `using __bsl_ty = decltype(__builtin_source_location());'
cpp_type(base(Q, [decltype(paren(E))]), T) :- !, ( cpp_class_ctx(Cx) -> true ; Cx = none ), cpp_unevaluated(cpp_expr(Cx, E, E1)),   % `decltype((x))' (0.197): by the operand's value category, an lvalue `T &' (cpp_decltype_paren/2)
    ( cpp_decltype_paren(E1, T0) -> cpp_storage_off(T0, T01), cpp_merge_quals(Q, T01, T) ; cpp_trace(decltype_untyped(E1)), cpp_refuse(0, decltype_unknown) ).
cpp_type(base(Q, [decltype(E)]), T) :- cpp_decltype_declared(E, T0), !, cpp_merge_quals(Q, T0, T).   % AN UNPARENTHESIZED NAME'S DECLARED TYPE, before the desugaring folds a constant (0.199; cpp_decltype_declared/2)
cpp_type(base(Q, [decltype(E)]), T) :- !, ( cpp_class_ctx(Cx) -> true ; Cx = none ), cpp_unevaluated(( cpp_std_move_call(E, X) -> cpp_expr(Cx, X, X1), E1 = move(X1) ; cpp_expr(Cx, E, E1) )),   % `decltype(std::move(x))' typed before the desugaring drops the move of a value without owners (0.112)   % IN THE CLASS whose member the decltype is, where C++ looks its names up: `using type = decltype(__find_base(static_cast<_Tp *>(nullptr)))' names a static member of that class, and walked with no context the call stayed as written and had no type
    ( cpp_decltype_of(E1, T0) -> cpp_storage_off(T0, T01), cpp_merge_quals(Q, T01, T) ; cpp_trace(decltype_untyped(E1)), cpp_refuse(0, decltype_unknown) ).   % an object's alignment or place is never its type's (0.206, cpp_storage_off/2)
cpp_type(base(Q, [builtin_type(N, Args)]), T) :- !, cpp_builtin_type(N, Args, T0), cpp_merge_quals(Q, T0, T).
cpp_type(base(_, [typedef(scoped(Path, N))]), _) :- memberchk(nonclass(A), Path), !, cpp_refuse(0, no_member_type(A, N)).   % a type has no member types (cpp_subst_path)
cpp_type(base(Q, [typedef(scoped(Path, N))]), base(Q, [typedef(N)])) :- atom(N), ccl_typedef_of(N, D), cpp_self_typedef(N, D), !.   % ... AND A NAME WHOSE FLATTENED FORM IS ITS OWN DEFINITION IS LEFT ALONE, without the hook and without the trace (0.64's self-typedef, from the flattened side): libc++'s type_info writes `typedef __type_info_implementations::__impl __impl' over a NAMESPACE, and the namespace flattening makes that `typedef __impl __impl' -- asked once per member of the class, it printed 139,393 flattens and took the machine's memory
cpp_type(base(Q, [typedef(scoped(Path, N))]), T) :- atom(N), !,
    ( nb_current('$cpp_where', W) -> true ; W = top ), cpp_trace(flatten(Path, N, in(W))),   % std::string: the namespace flattens (a class the resolver missed flattens too -- the trace tells)
    cpp_type(base(Q, [typedef(N)]), T).   % ... AND THE BARE NAME GOES THROUGH THE HOOK AGAIN: `std::string' is an alias of a template-id, and flattened and left there it reached the lowering as `basic_string<char>' itself
%% A NESTED TYPE NAMED AS A TYPE is registered on the first ask, whatever its kind: its tag must be in the table
%% before anything resolves a member of that type or lays its holder out, and a LAZY library instance never runs
%% the enclosing class's nested registrations. libc++'s `basic_string' names its own `__rep' as a template
%% argument, and that union's members name `__short' and `__long', two more of its nested types.
cpp_type(base(Q, [S]), base(Q, [S])) :- cpp_nested_tag(S, N), '$cpp_nested'(N, _, _, _, _), !, ( cpp_nested_ready(N) -> true ; true ).
%% ... AND A CLASS TYPEDEF THAT ASKS FOR ITSELF WHILE IT IS BEING RESOLVED IS LEFT AS WRITTEN, a guard per
%% (class, name) as `cpp_fold_static' has one: libc++'s type_info writes `typedef __type_info_implementations::__impl
%% __impl' over a NAMESPACE, and the namespace flattening makes that `typedef __impl __impl' -- which asked for
%% itself without end (139,393 flattens, the machine's memory). The SHAPE is no test: `allocator_traits' writes
%% `typedef typename __base::pointer pointer', the same spelling through a scope that DOES resolve, and refusing
%% it by shape left every `pointer' parameter of the allocator traits raw at the lowering.
%% A NAME THAT IS A NESTED CLASS'S OWN takes the nested type with NO guard, and the class is made ready AFTER: the
%% guard below is set while its resolution runs, and making the nested class ready walks its methods, whose body
%% names the class by its short name again -- inside `Gen::promise_type', `std::coroutine_handle<promise_type>' met
%% the guard, stayed `promise_type' and keyed the instance by that free name
cpp_type(base(Q, [typedef(N)]), T) :- atom(N), cpp_class_ctx(C), cpp_class_typedef(C, N, T0, _), T0 = base(_, [S]), cpp_nested_tag(S, X), X \== N,
    '$cpp_nested'(X, _, _, _, _), !, cpp_merge_quals(Q, T0, T), ( cpp_nested_ready(X) -> true ; true ).
cpp_type(base(Q, [typedef(N)]), T) :- atom(N), cpp_class_ctx(C), cpp_class_typedef(C, N, T0, Def), \+ cpp_self_typedef(N, T0),
    cpp_ctd_key(Def, N, K), \+ nb_current(K, yes), !, nb_setval(K, yes),
    (   catch(cpp_ctype_resolve(Def, T0, T1), E, ( nb_setval(K, no), throw(E) )) -> nb_setval(K, no)
    ;   nb_setval(K, no), fail ),
    cpp_merge_quals(Q, T1, T), cpp_touch_nested(T1).
%% A HEADER'S KEYED TYPE NAMED BARE WHERE A USING OF ITS NAMESPACE IS IN FORCE (0.161; [namespace.udir], [namespace.udecl]; cpp_using_key): `using
%% namespace std::ranges; less lt;' is ranges::less, which the flattening keyed `ranges.less' apart from std's class template `less' -- after
%% the class's own names, which no using hides, and only a key of the kind the name is used as: a class or an alias for a bare name, a
%% class or alias template for a template-id (cpp_using_type_key/3), so that `less<int>' stays std's
cpp_type(base(Q, [typedef(N)]), T) :- atom(N), cpp_using_type_key(N, class, K), !, cpp_type(base(Q, [typedef(K)]), T).
cpp_type(base(Q, [typedef(N)]), T) :- atom(N), ccl_typedef_of(N, base(_, [typedef(X)])), ( cpp_template_id(X, _, _) ; X = scoped(P, _), member(tmpl(_, _), P), \+ cpp_raw_type(base([], [typedef(X)])) ), !,   % `typedef integral_constant<bool, false> false_type', a LIBRARY header's alias -- or `typedef underlying_type<E>::type __memory_order_underlying_t' (0.117), a member type of an instance -- BUT NEVER A DEFINITION THAT NAMES A TEMPLATE PARAMETER (0.118; `cpp_raw_type'): the table holds block-local and class-scope typedefs too, `typedef typename iterator_traits<_Iter>::difference_type difference_type', and followed with its free name it instantiated `iterator_traits<_Iter>' for ever (rangesarray.cpp, 12 seconds at 0.116, 8.7 GB and no end at 0.117)
    ( catch(cpp_type(base([], [typedef(X)]), T1), error(not_lowered(W), _), ( cpp_trace(alias_refused(N, W)), fail )) -> cpp_merge_quals(Q, T1, T) ; T = base(Q, [typedef(N)]) ).   % of a template-id: the INSTANCE, not the name -- the passes rebuild the table from the summary, where the alias is raw, so a note behind the name does not survive to the lowering (the program's own typedef item is walked and does). Only an alias whose WHOLE definition is a template-id: a name like `type' is a class's, and the global table's entry for it is some other class's
%% ... AND AN ALIAS OF SUCH AN ALIAS (0.134): `typedef string __path_string;' in libc++'s <filesystem>, whose definition is the
%% bare name of a namespace-scope alias of a template-id (`typedef basic_string<char> string;'). The rule above takes only a
%% template-id as the definition -- a bare name like `type' is a class's, and the global table's entry for it some other
%% class's -- so `__path_string &' stayed a name, the lowering followed the table to the raw `basic_string<char>' and refused
%% every `std::filesystem::path' (`_PathCVT<char>::__append_range'). A chain of bare names is followed here only where it
%% ENDS in an alias of a template-id, and never through a name of the class being walked (the clause above asks first).
cpp_type(base(Q, [typedef(N)]), T) :- atom(N), ccl_typedef_of(N, base(Q0, [typedef(X)])), atom(X), X \== N, cpp_alias_chain(X, 4), !,
    cpp_merge_quals(Q0, base([], [typedef(X)]), T0), cpp_type(T0, T1), cpp_merge_quals(Q, T1, T).
%% AN ENUM'S UNDERLYING TYPE NAMED THROUGH A DEPENDENT TYPEDEF IS SETTLED WHERE THE ENUM IS FIRST NAMED (0.117): libc++ 18's
%% `enum class memory_order : __memory_order_underlying_t' over `typedef underlying_type<__legacy_memory_order>::type
%% __memory_order_underlying_t' -- the lowering reads the enum's base from the tag and cannot instantiate a class, so every
%% `-std=c++20' program that stored into a std::atomic met `typedef(scoped([tmpl(underlying_type, ...)], type))'. The base is resolved
%% here and the tag noted again. `stdatomic20.cpp'.
cpp_type(base(Q, [typedef(N)]), T) :- atom(N), cpp_enum_unsettled(N, Es, A, Tb1), !,
    ccl_note_tag(N, [enum_base(Tb1)|Es]), cpp_settle_typedef(A, Tb1),
    cpp_type(base(Q, [typedef(N)]), T).
cpp_type(base(Q, [vector(K, X0, E0)]), T) :- !, cpp_type(E0, E), cpp_array_bound(X0, X), ( ccl_resolve_base([vector(K, X, E)], Q, T1) -> T = T1 ; T = base(Q, [vector(K, X, E)]) ).   % A VECTOR TYPE (0.162): its element and count in the desugaring's words, then the inference's vec(K, N, E)
cpp_type(base(Q, S), base(Q, S)) :- !.
cpp_type(ptr(Q, T0), ptr(Q, T)) :- !, cpp_type(T0, T).
cpp_type(ref(Q, T0), T) :- !, cpp_type(T0, T1), cpp_collapse_ref(ref, Q, T1, T).
cpp_type(rref(Q, T0), T) :- !, cpp_type(T0, T1), cpp_collapse_ref(rref, Q, T1, T).
cpp_type(arr(N0, T0), arr(N, T)) :- !, cpp_type(T0, T), cpp_array_bound(N0, N).      % the BOUND is an expression too: `char pad[sizeof(T) - datasize<T>]' needs its template instantiated and folded
cpp_type(fn(R0, Ps0, V0), fn(R, Ps, V)) :- !, cpp_type(R0, R), cpp_plain_params(Ps0, Ps), cpp_fn_nx_cond(V0, V).
%% A POINTER TO MEMBER keeps its shape through the passes, the class and the pointee resolved ([dcl.mptr]): the
%% deduction and the specialization patterns libc++ writes over it (`_Rp (_Cp::*)(_A1)', thirty of them in
%% __weak_result_type) read it as it stands, and only the LOWERING turns it into what it is here -- the address of
%% the method this compiler emits, whose first parameter is the object (cpp_memptr_call). A pointer to a DATA member
%% is an offset and nothing here writes one; a pointer to a VIRTUAL member would have to carry a table index, and
%% both are refused by name where they are used.
cpp_type(memptr(C0, Q, T0), memptr(C, Q, T)) :- !,
    ( cpp_type(base([], [typedef(C0)]), base(_, [typedef(C1)])), atom(C1) -> C = C1 ; C = C0 ), cpp_type(T0, T).
cpp_type(T, T).
%% A FUNCTION TYPE'S CONDITIONAL NOEXCEPT (C++17, [except.spec]/2; 0.205): the reader's `nxif(E)' in its mark, evaluated where the
%% type is resolved -- an instance's, once its template's arguments are substituted -- the mark `noexcept' where it holds and
%% none where it does not, kept while it names a parameter not bound yet. It counted as noexcept whatever E was, so `template
%% <bool B> int callp(void (*f)() noexcept(B))' took no function that may throw for `callp<false>(tf)': no_matching_template
cpp_fn_nx_cond(V0, V) :- nonvar(V0), V0 = q(W, Qs0), select(nxif(E), Qs0, Qs1), !,
    (   ( cpp_class_ctx(Cx) -> true ; Cx = none ), catch(( cpp_unevaluated(cpp_expr(Cx, E, E1)), cpp_const_bool(E1, B) ), _, fail)
    ->  ( B == true, \+ memberchk(noexcept, Qs1) -> append(Qs1, [noexcept], Qs) ; Qs = Qs1 ), ( Qs == [] -> V = W ; V = q(W, Qs) )
    ;   V = V0 ).
cpp_fn_nx_cond(V, V).
%% A CLASS'S TYPEDEF IS RESOLVED IN THE CLASS THAT DEFINES IT, and its alignment FOLDED THERE (0.205; cpp_fold_aligned/2, as a
%% member's): `using AT [[__gnu__::__aligned__(req)]] = T;' over the class's static `req' -- libc++ 21's atomic_ref's
%% `_Aligned_Tp' -- kept `taligned(id(req))', which no fold outside the class reads, and `alignof(R<P>::AT)' was T's own
cpp_ctype_resolve(Def, T0, T) :- cpp_in_class(Def, ( cpp_type(T0, T1), cpp_fold_aligned(T1, T) )).
%% a keyed header typedef's definition (0.201): indexed under its key alone, so a name that is no key costs one failed lookup
cpp_hdr_keyed_typedef(K, T0) :- catch(cpp_hdr_item(K, typedef(_, Vs)), _, fail), memberchk(var(K, T0, _), Vs), !.
cpp_member_alias_of(C, N, C, TPs, T0) :- '$cpp_mt'(C, N, TPs, typedef(_, [var(_, T0, _)|_])), !.
cpp_member_alias_of(C, N, C1, TPs, T0) :- cpp_base_scope(C, B), cpp_member_alias_of(B, N, C1, TPs, T0), !.
%% decltype OF A CALL IS THE FUNCTION'S DECLARED RESULT, its reference kept ([dcl.type.decltype]): `std::declval<T>()'
%% is `T &&', and the inference DECAYS every reference (a reference is a pointer bound once), so declval gave the
%% closure BY VALUE and its operator() found no object to be called on
cpp_decltype_of(S, ref([], AT)) :- cpp_string_literal(S, AT), !.   % `decltype("ab")' is `const char (&)[3]' ([dcl.type.decltype]/1.5: a literal is an lvalue; 0.167)
cpp_decltype_of(call(id(F), _), T) :- atom(F), ccl_declared(F, fn(R, _, _)), ( R = ref(_, _) ; R = rref(_, _) ), !, T = R.
cpp_decltype_of(stmt_expr(block(Is)), R) :- append(_, [expr(_, call(Fc, _))], Is), cpp_called_fn(Fc, Is, fn(R, _, _)), ( R = ref(_, _) ; R = rref(_, _) ), !.   % ... AND A CALL THROUGH A POINTER TO MEMBER FUNCTION is the member's declared result (0.93), which cpp_memptr_call makes a STATEMENT EXPRESSION since 0.100 (the `{ ptr, adj }' pair, a virtual member through the table): its last call is through a cast to the function's type or through a local of it, and a clause on the bare call matched nothing, so `std::invoke(pm, s) += 2' over `int &(S::*)()' wrote into a copy (0.112; memptrdecl.cpp)
cpp_decltype_of(stmt_expr(block(Is)), R) :- append(_, [expr(_, call(id(F), _))], Is), atom(F), ccl_declared(F, fn(R, _, _)), ( R = ref(_, _) ; R = rref(_, _) ), !.   % ... AND A CALL MADE IN A STATEMENT EXPRESSION, a lambda called where it is made (0.132)
cpp_decltype_of(move(X), rref([], T)) :- ccl_type_of(X, T0), T0 \== unknown, !, ccl_unref(T0, T).
cpp_decltype_of(id(N), T) :- atom(N), ccl_declared(N, T0), ( T0 = ref(_, _) ; T0 = rref(_, _) ), catch(cpp_type(T0, T1), error(not_lowered(_), _), fail), ( T1 = ref(_, _) ; T1 = rref(_, _) ), !, T = T1.   % `decltype(x)' of an UNPARENTHESIZED NAME is its DECLARED type, the reference kept ([dcl.type.decltype]/1.3; 0.121): `std::forward<decltype(__rhs_alt)>(__rhs_alt)' in libc++'s variant copy took the alternative by value, forwarded it as an rvalue and moved the source's string out
cpp_decltype_of(E, ref([], T)) :- ( E = deref(_) ; E = index(_, _) ), ccl_type_of(E, T), T \== unknown, !.   % AN LVALUE EXPRESSION IS `T &' ([dcl.type.decltype]): `using __reference = decltype(*__first)' is `const string &' for a `const string *', and read as the plain `string' the range insert's `forward<__reference>' handed an RVALUE on -- the MOVE constructor took each element out of the caller's range
%% decltype OF A CONDITIONAL over two glvalues of one value category is a reference to their common type, the
%% qualifiers of both ([expr.cond]/4; 0.109), and decltype OF A CALL through a function reference or pointer is its
%% declared result: libc++'s common_reference is `decltype(false ? declval<X (&)()>()() : declval<Y (&)()>()())'
cpp_decltype_of(cond(_, A, B), T) :- cpp_decltype_of(A, TA), cpp_decltype_of(B, TB), cpp_cond_glvalue(TA, TB, T), !.
cpp_decltype_of(call(F, _), R) :- \+ F = id(_), ( cpp_decltype_of(F, FT) -> true ; ccl_type_of(F, FT) ), cpp_fn_result(FT, R), ( R = ref(_, _) ; R = rref(_, _) ), !.
cpp_decltype_of(id(N), T) :- atom(N), cpp_nx_fn_name(N), ccl_declared(N, T0), ccl_resolve_type(T0, fn(R, Ps, V)), !, cpp_fn_nx_on(V, V1), T = fn(R, Ps, V1).   % A NOEXCEPT FUNCTION'S TYPE IS `R(Ps) noexcept' (C++17, [except.spec]/2; 0.198): the name keeps the mark the reader takes off the declared type (ccl_own_fn_nx)
cpp_decltype_of(addr(id(N)), ptr([], T)) :- atom(N), cpp_nx_fn_name(N), cpp_decltype_of(id(N), T), T = fn(_, _, _), !.   % ... and its address a pointer to one
cpp_decltype_of(E, T) :- ccl_type_of(E, T), T \== unknown.
%% DECLTYPE OF AN UNPARENTHESIZED NAME IS THE DECLARED TYPE OF THE ENTITY IT NAMES ([dcl.type.decltype]/1.3; 0.199),
%% asked before the desugaring folds a constant to its value: `decltype(P::v)' of `static constexpr auto v = 5;' and
%% `decltype(g)' of a namespace-scope `constexpr auto g = 5;' are `const int', where the literal each folds to is an `int',
%% and `decltype(h)' of `const auto h = 'z';' is `const char'. A local or a parameter first, then a static member of the
%% class being walked (its bases' and its enclosing classes' included) or one named through its class, then a variable at
%% namespace scope that no member of the class hides. A function, `this', a name still `auto', a storage word (`static',
%% `extern', `thread_local') and an object's own alignment (`aligned(E)', the entity's, never the type's) are left out.
cpp_decltype_declared(id(N), T) :- atom(N), N \== this, nb_getval('$ccl_scope', Fs), ccl_in_frames(Fs, N, T0), !, cpp_decltype_entity(T0, T).
cpp_decltype_declared(id(N), T) :- atom(N), N \== this, cpp_decltype_class(C), catch(cpp_static_owner(C, N, O), _, fail), !, cpp_decltype_static(O, N, T).
cpp_decltype_declared(id(N), T) :- atom(N), N \== this, \+ ( cpp_decltype_class(C), catch(cpp_has_member(C, N), _, fail) ), ccl_gdeclared(N, T0), !, cpp_decltype_entity(T0, T).
cpp_decltype_declared(scoped(Path, N), T) :- atom(N), Path \== [], catch(cpp_scope_class(Path, C), _, fail), atom(C), catch(cpp_static_owner(C, N, O), _, fail), !, cpp_decltype_static(O, N, T).
cpp_decltype_declared(tmpl(N, Args0), T) :- atom(N), cpp_variable_template(N), catch(cpp_vt_declared(N, Args0, T), _, fail), !.   % A VARIABLE TEMPLATE'S ID: its specialization's declared type (0.199), `decltype(w<'b'>)' of `template <auto N> constexpr auto w = N;' `const char'
cpp_decltype_declared(scoped(Path, tmpl(N0, Args0)), T) :- atom(N0), \+ catch(cpp_scope_class(Path, _), _, fail), ( cpp_ns_key(Path, N0, K), cpp_variable_template(K) -> N = K ; cpp_variable_template(N0), N = N0 ), catch(cpp_vt_declared(N, Args0, T), _, fail), !.
cpp_decltype_declared(scoped(Path, N), T) :- atom(N), Path \== [], catch(cpp_scope_class(Path, C), _, fail), atom(C), cpp_member_declared(C, N, T0), !, cpp_storage_off(T0, T).   % A NON-STATIC DATA MEMBER NAMED THROUGH ITS CLASS, an unevaluated operand's ([expr.prim.id.general]/4; 0.206): `decltype(S::m)' was decltype_unknown
cpp_decltype_declared(member(E, N), T) :- atom(N), catch(cpp_class_of_type_of(E, C), _, fail), cpp_member_declared(C, N, T0), !, cpp_storage_off(T0, T).   % AN UNPARENTHESIZED CLASS MEMBER ACCESS ([dcl.type.decltype]/1.3; 0.206): the member's declared type, the object's constness and the member's alignment none of it
cpp_decltype_declared(arrow(E, N), T) :- atom(N), catch(ccl_type_of(E, PT), _, fail), PT \== unknown, catch(ccl_resolve_type(PT, ptr(_, P)), _, fail), cpp_class_of_type(P, C), cpp_member_declared(C, N, T0), !, cpp_storage_off(T0, T).
cpp_decltype_class(C) :- ( cpp_class_ctx(C0) -> true ; cpp_body_ctx(C0) ), atom(C0), C0 \== none, !, C = C0.
cpp_vt_declared(N, Args0, T) :- cpp_targ_values(Args0, Args), cpp_class_template(N, TPs, declaration(_, _, _, [var(_, VT, Init)])), cpp_bind_targs(TPs, Args, B), cpp_full_args(TPs, B, FullArgs),
    ( cpp_pick_spec(N, FullArgs, SB, declaration(_, _, _, [var(_, SVT, SInit)])) -> VT1 = SVT, I0 = SInit, VB = SB ; VT1 = VT, I0 = Init, VB = B ),
    cpp_subst(I0, VB, I1), cpp_unevaluated(cpp_expr(none, I1, I2)), cpp_vt_type(VT1, VB, I2, T), !.
cpp_decltype_entity(T0, T) :- \+ cpp_has_auto(T0), \+ catch(ccl_resolve_type(T0, fn(_, _, _)), _, fail), catch(cpp_type(T0, T1), error(not_lowered(_), _), fail), \+ cpp_has_auto(T1), cpp_storage_off(T1, T).
cpp_decltype_static(O, N, T) :- atomic_list_concat([O, '.', N], SN0), ( ccl_gdeclared(SN0, T0), \+ cpp_has_auto(T0) -> true ; cpp_static_member(O, N, SN), ccl_gdeclared(SN, T0), \+ cpp_has_auto(T0) -> true ; cpp_class_l(O, cls(_, _, Ss, _, _)), memberchk(N-T0, Ss), \+ cpp_has_auto(T0) ), !,
    catch(cpp_in_class(O, cpp_type(T0, T1)), error(not_lowered(_), _), fail), \+ cpp_has_auto(T1), cpp_storage_off(T1, T).
%% a data member's declared type, in its class's words: the class's own, then its bases' (0.206)
cpp_member_declared(C, N, T) :- cpp_class_l(C, cls(_, Data, _, _, _)), memberchk(member(T0, N, _), Data), !, \+ cpp_has_auto(T0), catch(cpp_in_class(C, cpp_type(T0, T)), error(not_lowered(_), _), fail).
cpp_member_declared(C, N, T) :- cpp_class_l(C, cls(B, _, _, _, _)), B \== none, cpp_member_declared(B, N, T), !.
cpp_member_declared(C, N, T) :- '$cpp_base_slot'(C, B, _), cpp_member_declared(B, N, T), !.
cpp_storage_off(base(Q0, S), base(Q, S)) :- !, cpp_storage_words_off(Q0, Q).
cpp_storage_off(ptr(Q0, T0), ptr(Q, T)) :- !, cpp_storage_words_off(Q0, Q), cpp_storage_off(T0, T).   % a pointer object's own alignment too (0.206)
cpp_storage_off(arr(N, T0), arr(N, T)) :- !, cpp_storage_off(T0, T).
cpp_storage_off(ref(Q, T0), ref(Q, T)) :- !, cpp_storage_off(T0, T).
cpp_storage_off(rref(Q, T0), rref(Q, T)) :- !, cpp_storage_off(T0, T).
cpp_storage_off(T, T).
cpp_storage_words_off([], []).
cpp_storage_words_off([W|Ws], Ws1) :- ( nonvar(W), ( memberchk(W, [static, extern, thread_local, register, inline, packed]) ; W = aligned(_) ; W = ualign(_) ) -> cpp_storage_words_off(Ws, Ws1) ; Ws1 = [W|Ws2], cpp_storage_words_off(Ws, Ws2) ).   % a member's GCC `packed' and its place below its alignment too (0.206)
cpp_nx_fn_name(N) :- ( ccl_nothrow(N) ; ccl_lib_nothrow(N) ), !.
%% A NOEXCEPT FUNCTION'S NAME OR ADDRESS DEDUCES A POINTER TO A NOEXCEPT FUNCTION (C++17, [except.spec]/2, [dcl.spec.auto]; 0.205):
%% `auto r = &nf;' and `auto s = nf;' as decltype(&nf) has it -- the table's type of the name keeps the plain mark (ccl_own_fn_nx),
%% and `noexcept(r())' was 0
cpp_nx_init_type(I0, IT0, IT) :- cpp_nx_named_fn(I0, N), cpp_nx_fn_name(N), catch(ccl_resolve_type(IT0, R), _, fail),
    ( R = ptr(Q, F0), catch(ccl_resolve_type(F0, fn(Rt, Ps, V)), _, fail) -> cpp_fn_nx_on(V, V1), IT = ptr(Q, fn(Rt, Ps, V1))
    ; R = fn(Rt, Ps, V) -> cpp_fn_nx_on(V, V1), IT = fn(Rt, Ps, V1) ), !.
cpp_nx_init_type(_, IT, IT).
cpp_nx_named_fn(addr(E), N) :- !, cpp_nx_named_fn(E, N).
cpp_nx_named_fn(id(N), N) :- atom(N), \+ cpp_local(N).
cpp_nx_named_fn(scoped(_, N), N) :- atom(N).
cpp_fn_nx_on(q(V, Qs), q(V, Qs1)) :- !, ( memberchk(noexcept, Qs) -> Qs1 = Qs ; append(Qs, [noexcept], Qs1) ).
cpp_fn_nx_on(V, q(V, [noexcept])).
cpp_fn_nx_off(V0, V) :- nonvar(V0), V0 = q(W, Qs), memberchk(noexcept, Qs), !, delete(Qs, noexcept, Qs1), ( Qs1 == [] -> V = W ; V = q(W, Qs1) ).
cpp_fn_nx_off(V, V).
cpp_called_fn(cast(ptr(_, F), _), _, F) :- F = fn(_, _, _), !.
cpp_called_fn(id(Fn), Is, F) :- member(declaration(_, _, _, Vs), Is), memberchk(var(Fn, ptr(_, F), _), Vs), F = fn(_, _, _), !.
cpp_std_move_call(call(scoped(P, move), [X]), X) :- ( P == [std] ; P == [std, inline('__1')] ; P == [global, std] ), !.   % `decltype(std::move(x))' is `T &&' ([dcl.type.decltype], an xvalue; 0.112): std::move is desugared to the move node, which the inference types as the value -- libc++'s `__move_t<_Iter>' came out by value, and `__iter_move' returned a COPY of every element std::move shifts
cpp_nested_tag(typedef(N), N) :- atom(N).
cpp_nested_tag(union(N, _), N) :- atom(N).
%% A TYPEDEF THAT IS ITS OWN DEFINITION IS LEFT ALONE, never followed: an instance keyed by a FREE name gives its
%% class `typedef value_type value_type' (libc++'s `initializer_list<_Ep>' with `_Ep' unresolved), and resolving
%% that name in that class asked for itself without end -- no refusal, no trace, just terms until the machine gave
%% out. cocolog reclaims nothing along the way, so a loop here is the whole memory (the finding below).
cpp_self_typedef(N, base(_, [typedef(N)])).
cpp_ctd_key(Def, N, K) :- ( atom(Def) -> D = Def ; D = '$c' ), atomic_list_concat(['$cpp_ctd:', D, '.', N], K).   % never a raw type_error out of atomic_list_concat, as cpp_mangle guards
%% A NESTED CLASS KNOWN BY ITS NAME ALONE -- forward-declared in its holder, defined out of it (`class locale::id')
%% -- is LOADED when its name resolves as a type, so its struct exists where the lowering meets the type; the
%% name road never asked for the class, and `locale::id' reached the lowering as a tag nothing had noted
cpp_touch_nested(base(_, [typedef(N)])) :- atom(N), '$cpp_nested'(N, _, _, _, _), \+ '$cpp_cls'(N, _), !, ( catch(cpp_class_l(N, _), _, fail) -> true ; true ).
cpp_touch_nested(_).   % value_type inside its class: class scope before namespace scope, as C++ looks names up; a base's typedef in the base's words
%% REFERENCE COLLAPSING: `T &' with T a reference is that reference's kind's lvalue form, `T &&' with T an lvalue
%% reference is an lvalue reference, `T &&' with T an rvalue reference an rvalue one -- what a forwarding reference
%% deduced as `X &' (above) means once substituted
cpp_collapse_ref(_, _, ref(Q2, U), ref(Q2, U)) :- !.
cpp_collapse_ref(ref, _, rref(Q2, U), ref(Q2, U)) :- !.
cpp_collapse_ref(rref, _, rref(Q2, U), rref(Q2, U)) :- !.
cpp_collapse_ref(K, Q, T, R) :- R =.. [K, Q, T].
cpp_array_bound(none, N) :- !, N = none.
cpp_array_bound(int(K), int(K)) :- !.
cpp_array_bound(E0, N) :- ( cpp_class_ctx(C) -> true ; C = none ),
    ( catch(cpp_expr(C, E0, E1), error(not_lowered(_), _), fail) -> true ; E1 = E0 ),
    ( cpp_const_value(E1, V), integer(V) -> N = int(V) ; N = E1 ).   % through the constexpr evaluator too (0.99): `int arr[sq(3)]' with sq the program's own constexpr function was a VLA
%% the chain of bare names an alias may be, ending in an alias of a template-id (above, 0.134)
cpp_alias_chain(X, D) :- D > 0, ccl_typedef_of(X, base(_, [typedef(Y)])), ( cpp_template_id(Y, _, _) -> true ; atom(Y), Y \== X, D1 is D - 1, cpp_alias_chain(Y, D1) ), !.
%% the tag is asked with its members UNBOUND: a bound pattern reaches memberchk on a miss, which then finds an OLDER, unsettled note of the same tag
cpp_enum_unsettled(N, Es, A, Tb1) :- ccl_tag(N, Ms), Ms = [enum_base(base(_, [typedef(A)]))|Es], atom(A),
    ccl_typedef_of(A, D), cpp_dependent_typedef(D),
    catch(cpp_type(D, Tb1), error(not_lowered(_), _), fail), Tb1 \= base(_, [typedef(scoped(_, _))]), \+ cpp_dependent_typedef(Tb1).
%% ... A MEMBER TYPE OF AN INSTANCE (libc++ 18's `underlying_type<E>::type') OR A TEMPLATE-ID OF AN ALIAS TEMPLATE (0.126; libc++ 21's `__underlying_type_t<__legacy_memory_order>',
%% itself `__underlying_type(_Tp)'): either one is a name the lowering cannot resolve to a type
cpp_dependent_typedef(base(_, [typedef(scoped([_|_], M))])) :- atom(M), !.
cpp_dependent_typedef(base(_, [typedef(X)])) :- cpp_template_id(X, _, _).
%% the passes build the table again from the output's items, so the settled typedef is OUTPUT too: the lowering reads the enum's base through it
cpp_settle_typedef(A, Tb1) :- Vs = [var(A, Tb1, none)], ccl_note_typedefs(Vs), assertz('$cpp_out'('', typedef(0, Vs))).
cpp_types([], []).
cpp_types([T0|Ts], [T|Us]) :- cpp_type(T0, T), cpp_types(Ts, Us).
%% A CALL'S EXPLICIT TEMPLATE ARGUMENTS ARE TEMPLATE ARGUMENTS, not types: libc++'s sort writes
%% `std::__introsort<_AlgPolicy, _Comp &, _Iter, __use_branchless_sort<_Comp, _Iter> >(...)', whose last
%% argument is a VARIABLE TEMPLATE's id -- typed as a class it refused `instance_without_body'. 0.63
%% evaluates an explicit argument where it BINDS (cpp_bind_explicit); this is the pre-pass that mangled it
%% first. Only the two shapes cpp_type gets wrong are diverted, so nothing that types today types differently.
cpp_call_targs([], []).
cpp_call_targs([A0|As], [A|Bs]) :- cpp_targ_id(A0, N), ( cpp_variable_template(N) ; cpp_concept_known(N) ), !,
    cpp_targ_value(A0, A), cpp_call_targs(As, Bs).
cpp_call_targs([A0|As], [A|Bs]) :- cpp_type(A0, A), cpp_call_targs(As, Bs).
cpp_targ_id(base(_, [typedef(X)]), N) :- cpp_template_id(X, N, _).
cpp_template_id(tmpl(N, Args), N, Args).
cpp_template_id(scoped(_, tmpl(N, Args)), N, Args).                      % a namespace flattens here too
%% the walk of an instance sees no local of the function that met it: the scopes are set aside
%% a breadcrumb for the trace: what the desugaring is working on, so a silent resolution says where it happened.
%% Scoped, so it names the innermost work and not merely the last thing entered.
%% ... AND THE BREADCRUMB IS A STACK, not one frame: `cpp_where' kept only the innermost, so a trace inside an
%% instantiation reported the ask naming ITSELF (0.65's lesson, which cost that step an afternoon and this one
%% another). The stack is bounded at six frames and is kept ONLY while `'$cpp_trace'' is on, so an ordinary build
%% pays nothing for it -- `nb_setval' copies what it stores and the breadcrumb is entered at every statement.
cpp_where(W, Goal) :- ( nb_current('$cpp_where', W0) -> true ; W0 = top ),
    cpp_wpush(W, St0), nb_setval('$cpp_where', W),
    ( catch(Goal, E, (cpp_wpop(W0, St0), throw(E))) -> cpp_wpop(W0, St0) ; cpp_wpop(W0, St0), fail ).
cpp_wpush(W, St0) :- ( nb_current('$cpp_trace', yes)
    ->  cpp_wstack(St0), cpp_wtake(8, [W|St0], St1), nb_setval('$cpp_wstack', St1) ; St0 = off ).
cpp_wpop(W0, St0) :- nb_setval('$cpp_where', W0), ( St0 == off -> true ; nb_setval('$cpp_wstack', St0) ).
cpp_wstack(St) :- ( nb_current('$cpp_wstack', St0) -> St = St0 ; St = [] ).
cpp_wtake(0, _, []) :- !.
cpp_wtake(_, [], []) :- !.
cpp_wtake(N, [X|Xs], [X|Ys]) :- N1 is N - 1, cpp_wtake(N1, Xs, Ys).
cpp_isolated(Goal) :- cpp_with_obj_const(none, cpp_with_obj_cat(none, cpp_with_obj_expr(none, cpp_line_kept(cpp_isolated_(Goal))))).   % NOR THE CALLER'S OBJECT (0.115), below; its expression too (0.117)
cpp_isolated_(Goal) :- nb_getval('$ccl_scope', S), nb_setval('$ccl_scope', []), ccl_global('$cpp_caller', Cl, none), nb_setval('$cpp_caller', none),
    ( catch(Goal, E, (nb_setval('$ccl_scope', S), nb_setval('$cpp_caller', Cl), throw(E))) -> nb_setval('$ccl_scope', S), nb_setval('$cpp_caller', Cl) ; nb_setval('$ccl_scope', S), nb_setval('$cpp_caller', Cl), fail ).   % ON A THROW TOO: SFINAE throws and catches by design, and a lost scope left the CALLER's own locals untyped
%% ... AND AN ISOLATED WALK HAS NO CALLER (0.112): an instance or a member emitted while an outer overload set is scored
%% (cpp_as_callee) kept that scoring's caller, so cpp_arg_type read the walk's own arguments in the outer caller's
%% words -- `m.push_back({})' over a vector of vectors made vector<int>'s default constructor, whose default member
%% initializer `__compressed_pair<pointer, allocator_type>(nullptr, __default_init_tag())' was typed in `main' and
%% instantiated `__compressed_pair_elem<pointer, 0>' on the free name
%% ... AND NOT THE CALLER'S OBJECT EITHER (0.115): the constness and the value category of the object a member call is
%% made on (`'$cpp_obj_const'', `'$cpp_obj_cat'') are set for that call's choice, and an emission made during the
%% choice walked its body under them -- a non-const member was no candidate on a const object (0.113), so inside
%% `__copy_loop<_AlgPolicy>::operator() const', emitted while its const temporary's call was chosen, `*__result =
%% *__first' found no `back_insert_iterator::operator=' and stored a char into the iterator (std::print, a
%% user formatter's format_to). `isolatedobj.cpp'.
%% ... AND THE CALLER'S LINE COMES BACK (0.164): `'$cpp_line'', the line a refusal is reported at (cpp_stmt/3 sets it), is
%% the caller's statement's again when an isolated walk ends, however it ends. An instance's body walked in the middle of
%% the caller's statement left its own last line there, a line of another file: `std::format("{} {}", 1)' was refused
%% at line 370, a line of libc++'s header, where clang++ names the program's line 6.
cpp_line_kept(Goal) :- ( nb_current('$cpp_line', L) -> true ; L = 0 ),
    ( catch(Goal, E, ( nb_setval('$cpp_line', L), throw(E) )) -> nb_setval('$cpp_line', L) ; nb_setval('$cpp_line', L), fail ).
%% A FRAME PUSHED FOR A WALK IS GONE WHEN THE WALK ENDS, HOWEVER IT ENDS (0.133): the scope is a global, which neither a
%% throw nor a failure restores, and a block, a statement expression or a deduction pushed its frame and popped it only
%% on success. A refusal inside one, caught by a candidate check or by `cpp_lvalue_deep' (SFINAE), left the frame
%% open: libc++ 21's `visit_format_arg' holds a block `{ ... __h{...}; return std::invoke(..., handle{__h}); }', the
%% typing of that return walked the desugared temporary again and refused `no_constructor(handle, 0)', and the frame of
%% its statement expression stayed -- so the instance `visit_format_arg<...>', declared a moment later, went into that
%% frame instead of the file scope and was gone when it closed: its call had no type, and the retargeted format
%% context's lambda refused `lambda_result_type' (every std::format of a range). The scope comes back as it was.
cpp_in_frame(Goal) :- nb_getval('$ccl_scope', S0), cpp_lconsts_now(LC0), ccl_scope_push,   % ... and its local constants leave with it (0.195, cpp_note_const)
    ( catch(Goal, E, ( cpp_frame_back(S0, LC0), throw(E) )) -> cpp_frame_back(S0, LC0) ; cpp_frame_back(S0, LC0), fail ).
cpp_frame_back(S0, LC0) :- nb_setval('$ccl_scope', S0), nb_setval('$cpp_lconsts', LC0).
cpp_lconsts_now(LC) :- ( nb_current('$cpp_lconsts', LC0) -> LC = LC0 ; LC = [] ).
cpp_add_instance_items(Items) :- cpp_linkonce(Items, Items1), forall(member(I, Items1), ( cpp_item_key(I, K), assertz('$cpp_out'(K, I)) )),
    ( nb_getval('$cpp_in_lib', yes) -> forall(member(function(_, _, _, Name, _, _, _), Items1), assertz('$cpp_libfn'(Name))) ; true ).
%% THE EMITTED ITEMS BY NAME (0.165): '$cpp_out'(Key, Item), a function under its name and any other item under '', so
%% that the evaluator finds a function by the first argument (cpp_eval_fn/3, cpp_const_fold/2) -- the table was found by
%% its item's functor alone, and each ask scanned every function the walk had emitted -- 14.5 % of a std::visit build's
%% run at 0.163, and since 0.164 the evaluator asks a name of every identifier it cannot place (cpp_eval_function/1). The
%% program's own desugared functions are keyed alike, '$cpp_ownfn'(Name, Function).
cpp_item_key(function(_, _, _, N, _, _, _), K) :- !, K = N.
cpp_item_key(_, '').
%% what a header or a template gives every unit alike links once: linkonce_odr
cpp_linkonce([], []).
cpp_linkonce([function(L, Sto, R, N, Ps, V, B)|Is], [function(L, linkonce, R, N, Ps, V, B)|Js]) :- ( Sto == none ; Sto == inline ), !, cpp_linkonce(Is, Js).   % an `inline' template's instance too (0.121): libc++'s `__invoke' instances were plain definitions, never dropped, and the one over std::variant's overload set called a function that is only declared
cpp_linkonce([I|Is], [I|Js]) :- cpp_linkonce(Is, Js).
%% a class template at its arguments: registered and desugared like a class written out, once
%% the budget: a program's instantiations and header loads are hundreds; libc++'s closure, pulled in whole, is
%% tens of thousands and took the machine's memory once -- past the budget the compile stops with a diagnostic
%% THE BUDGET IS 6000 (0.133; 3000 since 0.44): range formatting over libc++ 18 (`fmtrange.cpp') makes 3105 instances and
%% header loads and stopped at the old limit. An instance costs little memory since cocolog's collector (1.8.36) and the light
%% class records (0.120) -- 775 MB at 3105 -- and the memory and time caps stop a runaway too; the limit is a guard, twice the
%% largest need measured.
cpp_spend(What) :- nb_getval('$cpp_budget', K), K1 is K + 1, nb_setval('$cpp_budget', K1), ( K1 > 6000 -> cpp_refuse(0, instantiation_budget(K1, What)) ; true ),
    cpp_trace_mem(spend(K1, What)).
cpp_trace(T) :- cpp_trace_mem(T).
cpp_trace_mem(T) :- ( nb_getval('$cpp_trace', yes) -> cpp_mem(M), write(T-M), nl, flush_output ; true ).   % with the heap and the store in KB (cocolog 1.2.13's statistics/2, the honest instrument)
cpp_mem(kb(G, S)) :- ( catch(( statistics(globalused, G0), statistics(store_used, S0) ), _, fail) -> G is G0 // 1024, S is S0 // 1024 ; G = 0, S = 0 ).
cpp_deeper(What) :- nb_getval('$cpp_depth', D), D1 is D + 1, nb_setval('$cpp_depth', D1), ( D1 > 120 -> cpp_refuse(0, instantiation_depth(D1, What)) ; true ).
cpp_shallower :- nb_getval('$cpp_depth', D), D1 is D - 1, nb_setval('$cpp_depth', D1).
cpp_instantiate_class(N, Args, Name) :- cpp_where(class(N), cpp_instantiate_class__(N, Args, Name)).
cpp_instantiate_class__(N, Args, Name) :-
    cpp_deeper(N), ( catch(cpp_instantiate_class_(N, Args, Name), E, (cpp_shallower, throw(E))) -> cpp_shallower ; cpp_shallower, fail ).
%% AN INSTANCE ASKED FOR AGAIN ANSWERS ITS NAME AND NOTHING ELSE. A clause retrieval COPIES the term it answers
%% (the finding below, for globals; a fact's body is no different), and a template's item is its whole class --
%% hundreds of members for one of libc++'s containers. Every ask fetched that item to compute a name it had
%% computed before: `std::string s; s += "x";' asks for `allocator_traits<allocator<char>>' 267 times and for
%% `__allocator_traits_base' 283, and the desugaring took 2.9 GB where the read took 48 MB. Args are compared with
%% `==', never unified, so an unbound argument matches nothing.
cpp_instantiate_class_(N, Args, Name) :- '$cpp_iname'(N, A, Name0), A == Args, !, Name = Name0.
cpp_instantiate_class_(N, Args, Name) :-
    ( member(A, Args), cpp_free_arg(A) -> cpp_wstack(W), ( nb_current('$cpp_class_ctx', Cx) -> true ; Cx = none ), ( nb_current('$cpp_making', Mk) -> true ; Mk = none ), cpp_trace(free_name_instance(N, A, ctx(Cx), making(Mk), from(W))) ; true ),   % an instance asked on a name the tables do not know is TRACED with its breadcrumb (0.49's, 0.60's and 0.64's defect, from the other side); refusing it took an instance name still being registered for a free name (`__tree<__value_type<int, int>>'), 37 fixtures RED
    ( member(A, Args), cpp_free_reserved(A, FN) -> cpp_refuse(0, template_argument_free(FN)) ; true ),   % never over a library template's own parameter (below)
    ( member(A, Args), cpp_unexpanded_pack(A) -> cpp_refuse(0, pack_unexpanded_argument(N)) ; true ),   % nor over a pack expansion that no binding expanded (0.205, cpp_unexpanded_pack/1)
    ( cpp_class_template(N, Args, TPs, Item) -> true ; cpp_refuse(0, template_without_body(N)) ),
    ( cpp_bind_targs(TPs, Args, B) -> true ; cpp_trace(bind_failed(N)), fail ),
    cpp_constraints_hold(N, TPs, B),
    ( cpp_instance_name(N, TPs, B, Name) -> ( nb_current('$cpp_where', W1) -> true ; W1 = top ), cpp_trace(want(Name, in(W1))) ; cpp_trace(name_failed(N)), fail ),
    assertz('$cpp_iname'(N, Args, Name)),
    ( '$cpp_nested_tmpl'(EC, _, N) -> cpp_encloses(Name, EC) ; true ),   % an instance of a MEMBER class template is enclosed by the class that holds the template
    (   cpp_instance_done(Name) -> true
    ;   \+ \+ ( cpp_spend(instance(Name)), cpp_full_args(TPs, B, FullArgs), cpp_instance_note(Name, inst(N, FullArgs)),
                Self = N-base([], [typedef(Name)]),                                                                % the injected class name: inside its body, `vector' is this instance
                ( '$cpp_nested_tmpl'(_, Short, N), Short \== N -> Selves = [Self, Short-base([], [typedef(Name)])] ; Selves = [Self] ),   % ... and a MEMBER class template's SHORT name too (0.112): `friend bool operator==(const iterator_t<_Base> &, const __sentinel &)' inside take_while_view's `__sentinel<_Const>' named `V.S' to nobody, and the friend reached the lowering as typedef('__sentinel')
                (   cpp_pick_spec(N, FullArgs, SB, SItem), cpp_template_defined(SItem) -> append(Selves, SB, SB1), cpp_subst(SItem, SB1, Item1), cpp_instance_body(N, Name, FullArgs, Item1)   % a specialization only where it HAS a body: a forward-declared one is not the definition
                ;   cpp_template_defined(Item) -> append(Selves, B, B1), cpp_subst(Item, B1, Item1), cpp_instance_body(N, Name, FullArgs, Item1)
                ;   cpp_incomplete_instance(N, Name) ) ) ).
%% A FREE RESERVED NAME IS NO TEMPLATE ARGUMENT (0.136): `_Rep', `_Tp' -- an underscore and a capital, a name only the
%% implementation writes ([lex.name]/3) -- that no table holds is a library template's own parameter met outside its
%% template, never a type. Instantiated, `duration<_Rep, _Period>' (the chrono formatter's walk) made ratio's
%% `__static_gcd' over `_Period::num' and its unfolded remainders, an instance chain without end. Refused, the road that
%% asked takes the refusal as any substitution failure. A program's own name is never reserved.
cpp_free_reserved(A, N) :- cpp_free_arg(A), A = base(_, [typedef(N)]), atom(N), sub_atom(N, 0, 1, _, '_'), sub_atom(N, 1, 1, _, C), char_code(C, K), K >= 0'A, K =< 0'Z,
    \+ ( '$cpp_hdr'(N, _) ; '$cpp_hdr_ast'(N, _) ), !.   % ... AND NO HEADER INDEXES IT (0.137): `_FilesystemClock' is a class of <filesystem> not loaded yet
%% A PACK EXPANSION THAT NO BINDING EXPANDED IS NO TEMPLATE ARGUMENT (0.205): an argument list is substituted before an
%% instance is asked for, so a `pack(X)' or a waiting `pack_zip(Bound, X)' left in it names a pack of no instance --
%% `tuple<_Tp...>' met where a candidate's check typed a call outside the template that writes it. Made, the instance
%% emitted `std::forward' over `pack(_Tp)', which the lowering refused (a program's own `get' called as a tuple's
%% constructor argument over libc++ 21); refused, the candidate that asked is no candidate, as any substitution failure.
cpp_unexpanded_pack(pack(_)).
cpp_unexpanded_pack(pack_zip(_, _)).
%% A CLASS TEMPLATE DECLARED AND NEVER DEFINED is an INCOMPLETE TYPE, which C++ lets a template argument name:
%% libc++ dispatches its algorithms on `__specialized_algorithm<_Algorithm::__fill_n, __single_iterator<_It>>',
%% and `__single_iterator' is declared only -- a tag, never an object. The instance is its NAME and its arguments,
%% which is what a specialization's pattern matches on; asking it for a member finds no class and refuses there.
cpp_incomplete_instance(N, _) :- '$cpp_tmplh'(N, _, K, _), K \== other, !, cpp_refuse(0, template_without_body(N)).   % a body registered elsewhere and not taken: the old diagnostic
cpp_incomplete_instance(_, Name) :- cpp_trace(incomplete(Name)).
%% AN INSTANCE WHOSE BASE IS STILL BEING REGISTERED WAITS FOR IT (0.117): naming `__list_node<int, void *>' as the pointee of a typedef
%% instantiates it, and its base `__list_node_base<int, void *>' is the class whose registration asked for that typedef -- C++ asks no
%% definition of a pointee, and this refused base_not_registered. The registration is deferred ('$cpp_deferred') and runs when the class
%% is first looked up (cpp_class/2), by which time the base is registered. `std::list' (`__list_imp', `__list_node_base'). `stdlist.cpp'.
cpp_instance_body(N, Name, FullArgs, Item1) :-
    (   cpp_instance_class(Item1, _, _, Bases, _), cpp_base_in_progress(Bases) -> assertz('$cpp_deferred'(Name, N, FullArgs, Item1)), cpp_trace(deferred(Name))
    ;   cpp_sig_waits(N, FullArgs) -> assertz('$cpp_deferred'(Name, N, FullArgs, Item1)), cpp_trace(deferred_sig(Name))
    ;   cpp_with_sigdecl(none, cpp_instance_body_(N, Name, FullArgs, Item1)) ).   % a registration of its own: the signatures being declared outside it are not its
%% A SIGNATURE NAMES A CLASS AND DOES NOT COMPLETE IT (0.136; [temp.inst]/2: a class template specialization is instantiated
%% where a complete type is needed, and a function's declaration needs none of its parameter and result types). The
%% instances are made where they are named here, so while an instance declares its member functions ('$cpp_sigdecl', the
%% template whose instance is declaring, `none' inside any other registration) a further instance of THE SAME template
%% waits ('$cpp_deferred', run at its first lookup by cpp_class/2): libc++'s `__val_expr<_ValExpr>' declares
%% `__val_expr<__slice_expr<_ValExpr>> operator[](slice) const' and three more such, and each instance declared the next
%% until the depth cap refused `instantiation_depth(121, '__slice_expr')' -- every `std::valarray'. Only an instance that
%% GROWS waits, its first argument holding the declaring one's first argument as a proper part: transform_view's
%% `__iterator<false>' names `__iterator<true>' in its converting constructor, and that one made to wait was read by a
%% road that never looks it up (`not lowered yet: auto('$end_391')', a range-for over `filter | transform | take'). Another
%% template's instance is made as before, since what a registration asks is not known here.
cpp_sig_waits(N, [A|_]) :- nb_current('$cpp_sigdecl', s(T, [C|_])), T == N, cpp_proper_part(C, A), !.
cpp_proper_part(X, T) :- cpp_part_args(T, As), member(A, As), ( A == X -> true ; cpp_proper_part(X, A) ), !.
cpp_part_args(T, As) :- atom(T), '$cpp_iname'(_, As, T), !.   % an instance named by its name: its arguments
cpp_part_args(T, As) :- compound(T), T =.. [_|As].
cpp_with_sigdecl(C, Goal) :- ( atom(C), '$cpp_inst'(C, inst(T0x, CA)) -> T = s(T0x, CA) ; T = none ), ( nb_current('$cpp_sigdecl', T0) -> true ; T0 = none ),
    nb_setval('$cpp_sigdecl', T),
    ( catch(Goal, E, ( nb_setval('$cpp_sigdecl', T0), throw(E) )) -> nb_setval('$cpp_sigdecl', T0) ; nb_setval('$cpp_sigdecl', T0), fail ).
cpp_base_in_progress(Bases) :- member(B, Bases), cpp_base_name_of(B, X),
    (   atom(X), '$cpp_inst'(X, _), \+ '$cpp_cls'(X, _)
    ;   cpp_template_id(X, TN, TArgs), catch(cpp_targ_values(TArgs, As), _, fail), '$cpp_iname'(TN, A, Name0), A == As, '$cpp_inst'(Name0, _), \+ '$cpp_cls'(Name0, _) ), !.
cpp_run_deferred(C) :- retract('$cpp_deferred'(C, N, FullArgs, Item1)), !,
    (   cpp_instance_class(Item1, _, _, Bases, _), cpp_base_in_progress(Bases) -> assertz('$cpp_deferred'(C, N, FullArgs, Item1)), fail
    ;   cpp_trace(deferred_run(C)), \+ \+ cpp_instance_body_(N, C, FullArgs, Item1) ).
cpp_instance_body_(N, Name, FullArgs, Item1) :-
    ( cpp_instance_class(Item1, L, K, Bases, Ms0) -> true ; cpp_refuse(0, instance_without_body(N)) ), cpp_lib_origin(N, Lib),
    ( K == union -> ( '$cpp_union'(Name) -> true ; assertz('$cpp_union'(Name)) ) ; true ),                          % A UNION TEMPLATE'S INSTANCE is a union class: its members share storage (0.121)
    cpp_promote_plain_bases(Bases),                                                       % a plain struct bound to a base-clause parameter is a class from here (below)
    ( cpp_nonabi_bases(Bases) -> nb_setval('$cpp_nonabi', yes) ; nb_setval('$cpp_nonabi', no) ),   % the layout is not the ABI's (below): no member of it is the shipped library's
    cpp_member_defs(N, Name, FullArgs, Ms0, Ms),                                          % the members DEFINED out of the class: their bodies, substituted with this instance's arguments
    nb_setval('$cpp_nonabi', no),
    ( Lib == yes -> cpp_lazy_instance(yes, Name) ; cpp_lazy_instance(prog, Name) ),       % a LIBRARY template's instance is lazy, as a library class already is: its members come as they are used -- and the PROGRAM's (0.127), its members checked
    ( Lib \== yes, member(A, FullArgs), cpp_incomplete_arg(A) -> cpp_trace(crtp_lazy(Name)) ; true ),   % ... and so is one over a class STILL BEING REGISTERED (the CRTP, 0.110): its members name the derived class's, which exist once it is complete -- C++ instantiates a member function where it is used ([temp.inst]/4)
    (   cpp_as_lib(Lib, ( cpp_isolated(( cpp_register_class(K, L, Name, Bases, Ms),
                                        ( cpp_item(declare(L, base([], [class(K, Name, Bases, Ms)])), Items) -> true ; cpp_refuse(L, instance_not_emitted(Name)) ) )),
                          cpp_add_instance_items(Items), cpp_isolated(cpp_member_asserts(Name, Ms)) ))   % its static assertions once it is complete (0.221)
    ->  true ; cpp_refuse(0, instance_not_emitted(Name)) ).
%% ---- A CLASS TEMPLATE'S MEMBER DEFINED OUT OF ITS CLASS ---------------------------------------------
%% `template <class _Tp, class _Allocator> void __vector_layout<_Tp, _Allocator>::__set_bound_using_pointer(
%%  pointer __p) noexcept { ... }' is how libc++ writes half of a container's members: the class's own member
%% is a DECLARATION. Such an item was dropped at registration, so an instance took its body from nowhere --
%% a bodyless function, a `declare' in the IR, and the linker saying the symbol is undefined. Every one of them
%% is kept by its CLASS's name ('$cpp_mdef'(Class, MemberKey, TParams, Pattern, Member)), and an instance takes
%% the definition whose pattern matches its arguments and whose parameters key alike -- a MEMBER TEMPLATE among
%% them (`template <class _Tp> template <class... _Args> ... vector<_Tp>::emplace_back(_Args &&...)'), whose own
%% parameters shadow the class's and wait for the call.
cpp_mdef_item(function(L, Sto, Ret, scoped(Path, M), Ps, V, Body), C, Pat, method(L, Qs, Ret, M, Ps, V, Body)) :-
    Body \== none, cpp_mdef_class(Path, C, Pat), cpp_mdef_name(M), cpp_sto_quals(Sto, Qs).
cpp_mdef_item(template(L, TPs, I), C, Pat, template(L, TPs, M)) :- cpp_mdef_item(I, C, Pat, M).
%% A STATIC DATA MEMBER OF A CLASS TEMPLATE DEFINED OUT OF ITS CLASS (0.117): `template <class _V, ..., _D _BlockSize> const _D
%% __deque_iterator<_V, ..., _BlockSize>::__block_size = _BlockSize;' while the class declares `static const difference_type
%% __block_size;' -- kept by the class's name, and the instance takes the initializer as the member's own default (cpp_static_defs), so it
%% folds as one written in the class does. Unmerged, `deque<int>::begin()' read an undefined symbol.
cpp_mdef_item(declaration(_, _, _, [var(scoped(Path, N), T, Init)]), C, Pat, static_def(N, Init)) :-
    atom(N), Init \== none, \+ T = fn(_, _, _), cpp_mdef_class(Path, C, Pat), Pat \== none.
%% ... AND THE MEMBERS OF A NESTED CLASS DEFINED OUT OF ITS ENCLOSING CLASS TEMPLATE, `template <...> basic_ostream<
%% _CharT, _Traits>::sentry::sentry(basic_ostream &)': kept by the enclosing class's name under the key
%% nested_member(sentry, ...), bound by its template-id's pattern as any member's is, and merged into the nested
%% class's own members when the instance's are (cpp_nested_defs) -- so the nested class registers with its bodies.
cpp_mdef_item(function(L, Sto, Ret, scoped(Path, M), Ps, V, Body), C, Pat, in_nested(N, method(L, Qs, Ret, M, Ps, V, Body))) :-
    Body \== none, append(Front, [N], Path), atom(N), ccl_last(Front, tmpl(C, Pat)), cpp_mdef_name(M), cpp_sto_quals(Sto, Qs), !.
cpp_mdef_item(ctor_def(L, scoped(Path, N), Qs, Ps, Inits, Body), C, Pat, in_nested(N, ctor(L, Qs, Ps, Inits, Body))) :- atom(N), Body \== none, cpp_mdef_class(Path, C, Pat).
cpp_mdef_item(dtor_def(L, scoped(Path, N), Qs, Body), C, Pat, in_nested(N, dtor(L, Qs, Body))) :- atom(N), Body \== none, cpp_mdef_class(Path, C, Pat).
cpp_mdef_item(ctor_def(L, C, Qs0, Ps, Inits, Body), C, Pat, ctor(L, Qs, Ps, Inits, Body)) :- atom(C), Body \== none, cpp_take_pattern(Qs0, Pat, Qs).
cpp_mdef_item(dtor_def(L, C, Qs0, Body), C, Pat, dtor(L, Qs, Body)) :- atom(C), Body \== none, cpp_take_pattern(Qs0, Pat, Qs).
%% ... AND A NESTED CLASS DEFINED OUT OF ITS CLASS TEMPLATE: `template <class _CharT, class _Traits> class
%% basic_ostream<_CharT, _Traits>::sentry { ... }', the class declaring only `class sentry;' -- kept by the class's
%% name like a member's body, and merged into the instance's forward declaration (cpp_member_def), which the
%% nested-class machinery then registers as any nested class. Unindexed, the body never reached the instance, and
%% every `sentry __s(*this)' in the stream's members was initialized as a plain value.
cpp_mdef_item(declare(L, base(Q, [class(K, scoped(Path, Nested), Bases, Ms)])), C, Pat, nested(base(Q, [class(K, Nested, Bases, Ms)]))) :-
    atom(Nested), Ms \== none, cpp_mdef_class(Path, C, Pat), ( atom(L) -> true ; true ).
%% the reader keeps `const' after an out-of-class definition's parameters as `const(Sto)' in the storage slot
%% (0.79): the member it defines is the const overload, and its this is `const C *'
cpp_sto_quals(Sto, Qs) :- cpp_sto_quals(Sto, Qs0, S0), ( S0 == none -> Qs = Qs0 ; Qs = [S0|Qs0] ).
cpp_sto_quals(const(S), [const|Qs], S0) :- !, cpp_sto_quals(S, Qs, S0).
cpp_sto_quals(hidden(S), [hidden|Qs], S0) :- !, cpp_sto_quals(S, Qs, S0).   % `__visibility__("hidden")' on the definition (0.112): never the shipped library's
cpp_sto_quals(mreq(R, S), [requires(R)|Qs], S0) :- !, cpp_sto_quals(S, Qs, S0).   % its trailing requires-clause (0.205), the reader's mreq(R, Sto): the declaration it defines has the same (cpp_mdef_match/9)
cpp_sto_quals(S, [], S).
%% the class's template-id of an out-of-class constructor or destructor travels as the qualifier pattern(Args) (the reader, 0.117)
cpp_take_pattern(Qs0, Pat, Qs) :- ( memberchk(pattern(P), Qs0) -> Pat = P, ccl_delete_one(Qs0, pattern(P), Qs) ; Pat = none, Qs = Qs0 ).
cpp_mdef_class(Path, C, Pat) :- ccl_last(Path, S), ( S = tmpl(C, Pat) -> true ; atom(S), C = S, Pat = none ).
cpp_mdef_name(M) :- ( atom(M) -> true ; M = operator(_) ).
cpp_mdef_put(C, TPs, Pat, Member) :- cpp_member_shape(Member, K, _, _), assertz('$cpp_mdef'(C, K, TPs, Pat, Member)).
%% a member's key, its parameters and its body, the member template's own wrapper looked through
%% A MEMBER TEMPLATE DEFINED OUT OF CLASS MAY NAME ITS OWN PARAMETERS DIFFERENTLY from the declaration ([temp.mem]: the
%% names are the template's own; 0.99): libc++ 18 declares `template <class _Iterator> void __construct_at_end_with_size(
%% _Iterator, size_type)' and defines it over `_ForwardIterator', so the keys never met, the instance stayed a declaration
%% and the link named it -- the definition's parameters are renamed to the declaration's, position for position
cpp_align_tparams(template(_, TPsA, _), template(L, TPsB, M), template(L, TPsA1, M1)) :- length(TPsA, N), length(TPsB, N), cpp_tparam_renames(TPsB, TPsA, B), B \== [], !, cpp_subst(M, B, M1), cpp_rename_tparams(TPsB, TPsA, TPsA1).
cpp_align_tparams(_, Item, Item).
cpp_tparam_renames([], [], []).
cpp_tparam_renames([tparam(K, PB, _)|Bs], [tparam(K, PA, _)|As], Rs) :- atom(PB), atom(PA), PB \== PA, PA \== anon, !,   % an UNNAMED declaration parameter takes the definition's name (0.113): `template <bool> class It;' defined `template <bool Const> class C<F>::It', whose `!Const' was renamed to nobody's `anon'
    ( K == type -> R = PB-base([], [typedef(PA)]) ; R = PB-id(PA) ), Rs = [R|Rs1], cpp_tparam_renames(Bs, As, Rs1).
cpp_tparam_renames([_|Bs], [_|As], Rs) :- cpp_tparam_renames(Bs, As, Rs).
cpp_rename_tparams([], [], []).
cpp_rename_tparams([tparam(K, PB, D)|Bs], [tparam(_, PA, _)|As], [tparam(K, PA1, D)|Rs]) :- ( atom(PB), atom(PA), PA \== anon -> PA1 = PA ; PA1 = PB ), cpp_rename_tparams(Bs, As, Rs).
cpp_rename_tparams([X|Bs], [_|As], [X|Rs]) :- cpp_rename_tparams(Bs, As, Rs).
cpp_member_shape(template(_, _, M), K, Ps, B) :- !, cpp_member_shape(M, K, Ps, B).
cpp_member_shape(method(_, _, _, M, Ps, _, B), M, Ps, B).
cpp_member_shape(ctor(_, _, Ps, _, B), '$ctor', Ps, B).
cpp_member_shape(dtor(_, _, B), '$dtor', [], B).
cpp_member_shape(static_def(N, I), static_def(N), [], I).
cpp_member_shape(in_nested(N, M), nested_member(N, K), Ps, B) :- !, cpp_member_shape(M, K, Ps, B).   % a nested class's member defined out of the enclosing class
cpp_member_shape(nested(base(_, [class(_, N, _, Ms)])), nested(N), [], Ms).       % a nested class, defined ...
cpp_member_shape(nested(base(_, [class(N, none)])), nested(N), [], none).         % ... or only declared inside its holder
cpp_member_shape(nested(base(_, [struct(N, Ms)])), nested(N), [], Ms).
cpp_member_defs(N, _, _, Ms, Ms) :- \+ '$cpp_mdef'(N, _, _, _, _), !.
cpp_member_defs(N, Name, Args, Ms0, Ms) :- cpp_mdef_types(Ms0, [], Map), nb_setval('$cpp_mdef_types', Map), findall(M, ( member(M0, Ms0), cpp_member_def(N, Name, Args, M0, M) ), Ms1),
    cpp_static_defs(N, Name, Args, Ms1, Ms).
%% the initializers of the class's STATIC members defined out of it, as defaults of the members (the reader writes default_init(N, E) for one written in the class)
cpp_static_defs(N, Name, Args, Ms1, Ms) :-
    findall(default_init(SN, Init), ( '$cpp_mdef'(N, static_def(SN), TPs, Pat, Item), cpp_static_def_init(Item, SN, Init0), Init0 \== none,
                                       member(member(MT, SN, _), Ms1), cpp_static_type(MT, _), \+ memberchk(default_init(SN, _), Ms1),
                                       cpp_mdef_bind(Pat, Args, TPs, B), cpp_subst(Init0, [N-base([], [typedef(Name)])|B], Init) ), Ds),
    findall(SN, ( '$cpp_mdef'(N, static_def(SN), TPs, Pat, Item), cpp_static_def_init(Item, SN, none), cpp_mdef_bind(Pat, Args, TPs, _) ), Bare),
    cpp_static_noinit_defs(Bare, Ms1, Ms2), append(Ms2, Ds, Ms).
cpp_static_def_init(template(_, _, I), SN, Init) :- !, cpp_static_def_init(I, SN, Init).
cpp_static_def_init(static_def(SN, Init), SN, Init).
%% THE PROGRAM'S STATIC DATA MEMBER OF A CLASS TEMPLATE DEFINED OUT OF IT WITH NO INITIALIZER (0.218; [temp.inst]/3, [dcl.init]/7):
%% `template <class T> std::vector<T> R<T>::items;' -- kept by the class's name as static_def(N, none), and each instance
%% defines the member as an inline one with no initializer is defined, linkonce and default-initialized: the member's type
%% takes `inline' beside `static' (ccl_static_inline_qual/2), which the class's registration notes (cpp_static_inline_take/3).
%% It was kept nowhere, and `R<int>::items' was an undefined symbol at the link. A library header's (`template <...>
%% locale::id num_get<...>::id;') stays the class's declaration: libc++ instantiates its own (`extern template class')
cpp_static_noinit_item(declaration(_, _, _, [var(scoped(Path, N), T, none)]), C, Pat, static_def(N, none)) :-
    atom(N), \+ T = fn(_, _, _), cpp_mdef_class(Path, C, Pat), Pat \== none.
cpp_static_noinit_defs([], Ms, Ms) :- !.
cpp_static_noinit_defs(Bare, Ms0, Ms) :-
    findall(M, ( member(M0, Ms0), ( M0 = member(T0, SN, W), memberchk(SN, Bare), \+ memberchk(default_init(SN, _), Ms0), ccl_static_inline_qual(T0, T) -> M = member(T, SN, W) ; M = M0 ) ), Ms).
%% the class's own typedefs AS ITS MEMBER LIST HAS THEM, substituted with the instance's arguments: the merge runs before
%% the instance is registered, so the registry knows none of them yet, and the kinds are compared against these
cpp_mdef_types(Ms, Map0, Map) :- findall(A-T, ( member(typedef(_, Vs), Ms), member(var(A, T, _), Vs) ), Own), append(Own, Map0, Map).
cpp_member_def(N, Name, Args, M0, M) :- cpp_member_def_key(N, Name, Args, plain, M0, M1), cpp_nested_defs(N, Name, Args, M1, M).
cpp_member_def_key(N, Name, Args, Where, M0, M) :-
    (   cpp_mdef_match(agree, N, Name, Args, Where, M0, Ps, Ps1, M1) -> cpp_mdef_take(Name, M0, Ps, Ps1, M1, M)
    ;   cpp_mdef_match(any, N, Name, Args, Where, M0, Ps, Ps1, M1) -> cpp_mdef_take(Name, M0, Ps, Ps1, M1, M)
    ;   M = M0 ).
%% THE DEFINITION WHOSE TEMPLATE PARAMETERS AGREE WITH THE DECLARATION'S IS PREFERRED (0.100): two member templates of one
%% name and one parameter list, told apart by a SFINAE default alone -- libc++ 18's `__split_buffer::__construct_at_end'
%% over `__has_exactly_input_iterator_category' and over `__has_forward_iterator_category', both `(_It, _It)', and
%% `vector::insert(const_iterator, _It, _It)' twice -- key alike, and the first definition found served BOTH declarations:
%% the second's kinds then matched no default and refused cannot_deduce($anon2), so `vector::insert' had no
%% `__construct_at_end' at all. The kinds are compared IN THE CLASS'S WORDS (cpp_tparams_alike): libc++ writes the
%% declaration's guard over `value_type' and the definition's over `_Tp', one type under two spellings. A definition
%% that agrees with none still falls to the key alone, as before.
cpp_mdef_match(Mode, N, Name, Args, Where, M0, Ps, Ps1, M1) :-
    cpp_member_shape(M0, K, Ps, none), cpp_params_key(Ps, PK), cpp_mdef_key(Where, K, Key), cpp_mdef_lookup(N, K, Key, TPs, Pat, Item0),
    cpp_mdef_inner(Item0, Item1), cpp_align_tparams(M0, Item1, Item), cpp_mdef_bind(Pat, Args, TPs, B),
    cpp_subst(Item, [N-base([], [typedef(Name)])|B], M1a), cpp_member_shape(M1a, K1, Ps1, B1), cpp_same_member_key(Name, K, K1, M1a, M1), B1 \== none, cpp_params_key(Ps1, PK), cpp_member_const(M0, CK), cpp_member_const(M1, CK),   % ... of the same constness: `find(const _Key &)' and `find(const _Key &) const' are two members, each with its own body out of class
    cpp_member_req(M0, RQ), cpp_member_req(M1, RQ),                      % ... and the same trailing requires-clause (0.205, below)
    \+ cpp_extern_shipped(N, Args, Where, K, PK, Item),                  % ... unless the shipped library DEFINES it (below): the member stays declared, and is called by its symbol
    ( Mode == agree -> cpp_tparams_agree(Name, M0, M1) ; true ).
%% A DEFINITION OUT OF THE CLASS IS THE DECLARATION WHOSE TRAILING REQUIRES-CLAUSE IS ITS OWN (0.205; [class.mfct]/2, [temp.over.link]/7:
%% two declarations with requires-clauses that are not equivalent declare two functions): `int g() requires (sizeof(T) > 1); int g()
%% requires (sizeof(T) == 1);' key alike, and the first definition met served both declarations -- `kc.g()' of a `K<char>' ran the
%% other's body, a silent wrong answer. The reader keeps the definition's clause (mreq(R, Sto), cpp_sto_quals/3); the two are compared
%% substituted, a lambda's lines set aside, and a member with none matches one with none, as before
cpp_member_req(M, R) :- cpp_member_req_quals(M, Qs), memberchk(requires(R0), Qs), !, cpp_unlined(R0, R).
cpp_member_req(_, none).
cpp_member_req_quals(template(_, _, M), Qs) :- !, cpp_member_req_quals(M, Qs).
cpp_member_req_quals(in_nested(_, M), Qs) :- !, cpp_member_req_quals(M, Qs).
cpp_member_req_quals(method(_, Qs, _, _, _, _, _), Qs) :- is_list(Qs).
cpp_member_req_quals(ctor(_, Qs, _, _, _), Qs) :- is_list(Qs).
cpp_member_req_quals(dtor(_, Qs, _), Qs) :- is_list(Qs).
%% ONE MEMBER UNDER TWO SPELLINGS (0.136): a conversion function's name holds its type, and a definition out of the class may
%% spell a class typedef through the class (`valarray<__val_expr::__result_type>' for `valarray<__result_type>'): the two
%% are one member when they agree with the class's own qualifier dropped, under the DECLARATION's name; any other key is compared as it stands
cpp_same_member_key(_, K, K1, M, M) :- K = K1, !.
cpp_same_member_key(Name, operator(conv(T0)), operator(conv(T1)), M1a, M1) :- cpp_unqualify_own(Name, T1, T1u), T0 = T1u, !,   % the class is not registered yet where its definitions are merged: its own qualifier is dropped
    cpp_member_named(M1a, operator(conv(T0)), M1).
cpp_unqualify_own(Name, typedef(scoped([P], N)), typedef(N)) :- P == Name, atom(N), !.
cpp_unqualify_own(Name, T, U) :- compound(T), !, T =.. [F|As], cpp_unqualify_own_l(Name, As, Bs), U =.. [F|Bs].
cpp_unqualify_own(_, T, T).
cpp_unqualify_own_l(_, [], []).
cpp_unqualify_own_l(Name, [A|As], [B|Bs]) :- cpp_unqualify_own(Name, A, B), cpp_unqualify_own_l(Name, As, Bs).
cpp_member_named(template(L, TPs, M0), K, template(L, TPs, M)) :- !, cpp_member_named(M0, K, M).
cpp_member_named(method(L, Qs, R, _, Ps, V, B), K, method(L, Qs, R, K, Ps, V, B)).
cpp_mdef_take(Name, M0, Ps, Ps1, M1, M) :- cpp_keep_defaults(Ps, Ps1, Ps2), cpp_member_params(M1, Ps2, M2), cpp_keep_tdefaults(Name, M0, M2, M3), cpp_keep_explicit(M0, M3, M).   % the DEFINITION's body with the DECLARATION's default arguments
%% ... AND THE DECLARATION'S `explicit' (0.200; [dcl.fct.spec]/4: `explicit' stands on a constructor's or a conversion function's
%% declaration in its class, never on a definition out of it): the merged member had the definition's qualifiers alone, and
%% libc++ 18's `explicit vector(size_type)', defined out of its class, converted an `int' (`is_convertible_v<int, std::vector<int>>'
%% and `is_assignable_v<std::vector<int> &, int>' were 1)
cpp_keep_explicit(M0, M1, M) :- cpp_member_quals(M0, Q0), findall(X, ( member(X, Q0), cpp_explicit_word(X) ), Xs), Xs \== [], !, cpp_member_quals_add(M1, Xs, M).
cpp_keep_explicit(_, M, M).
cpp_explicit_word(X) :- X == explicit, !.
cpp_explicit_word(X) :- compound(X), X = explicit(_), !.
%% ... AND ITS `static', `virtual', `override' AND `final' (0.201; [class.static]/1, [class.virtual]/2: each stands on the
%% declaration in the class alone): merged without them, a static member function of a class template defined out of it
%% took a `this' -- <regex>'s regex_traits called itself through the wrong road until the stack ran out -- and a virtual
%% one defined out of its class template had no slot, a call through a base's reference reaching the base's function
cpp_explicit_word(X) :- memberchk(X, [static, virtual, override, final]).
%% ... AND ITS `noexcept' AND `noexcept(E)' (0.206; [except.spec]/5: the declarations of a function have one exception
%% specification): merged without them, the noexcept operator read the definition's qualifiers alone, and libc++'s
%% `basic_string::swap' and `vector::swap', declared `noexcept' in their class templates and defined out of them, could
%% throw -- `std::is_nothrow_swappable_v<std::string>' was 0
cpp_explicit_word(X) :- X == noexcept, !.
cpp_explicit_word(X) :- compound(X), X = noexcept(_), !.
cpp_member_quals(template(_, _, M), Q) :- !, cpp_member_quals(M, Q).
cpp_member_quals(ctor(_, Q, _, _, _), Q) :- !, is_list(Q).
cpp_member_quals(method(_, Q, _, _, _, _, _), Q) :- is_list(Q).
cpp_member_quals_add(template(L, TPs, M0), Xs, template(L, TPs, M)) :- !, cpp_member_quals_add(M0, Xs, M).
cpp_member_quals_add(ctor(L, Q, Ps, I, B), Xs, ctor(L, Q1, Ps, I, B)) :- is_list(Q), !, cpp_quals_with(Xs, Q, Q1).
cpp_member_quals_add(method(L, Q, R, N, Ps, V, B), Xs, method(L, Q1, R, N, Ps, V, B)) :- is_list(Q), !, cpp_quals_with(Xs, Q, Q1).
cpp_member_quals_add(M, _, M).
cpp_quals_with([], Q, Q).
cpp_quals_with([X|Xs], Q0, Q) :- ( memberchk(X, Q0) -> Q1 = Q0 ; Q1 = [X|Q0] ), cpp_quals_with(Xs, Q1, Q).
cpp_tparams_agree(Name, template(_, TPs0, _), template(_, TPs1, _)) :- !, cpp_tparams_alike(Name, TPs0, TPs1).
cpp_tparams_agree(_, M0, M1) :- M0 \= template(_, _, _), M1 \= template(_, _, _).
cpp_tparams_alike(_, TPs0, TPs1) :- cpp_same_tparams(TPs0, TPs1), !.
cpp_tparams_alike(Name, TPs0, TPs1) :- cpp_norm_tparams(Name, TPs0, A), cpp_norm_tparams(Name, TPs1, B), cpp_same_tparams(A, B).
cpp_norm_tparams(_, [], []).
cpp_norm_tparams(Name, [tparam(K, P, D)|Ps], [tparam(K1, P, D)|Qs]) :- !, cpp_norm_kind(Name, K, K1), cpp_norm_tparams(Name, Ps, Qs).
cpp_norm_tparams(Name, [P|Ps], [P|Qs]) :- cpp_norm_tparams(Name, Ps, Qs).
%% a kind's type expression with the class's own typedef names resolved in the class (`value_type' is `int' in vector<int>);
%% what does not resolve, or refuses, stays as written
cpp_norm_kind(Name, K, K1) :- ( catch(cpp_norm_term(Name, K, K2), _, fail) -> K1 = K2 ; K1 = K ).
cpp_norm_term(_, T, T) :- \+ compound(T), !.
cpp_norm_term(_, base(Q, [typedef(A)]), T) :- atom(A), nb_current('$cpp_mdef_types', Map), memberchk(A-T1, Map), !, cpp_merge_quals(Q, T1, T).   % the member list's own (cpp_mdef_types)
cpp_norm_term(Name, base(Q, [typedef(A)]), T) :- atom(A), cpp_class_typedef(Name, A, T0, Def), cpp_in_class(Def, cpp_type(T0, T1)), !, cpp_merge_quals(Q, T1, T).
cpp_norm_term(Name, T0, T) :- T0 =.. [F|As], cpp_norm_list(Name, As, Bs), T =.. [F|Bs].
cpp_norm_list(_, [], []).
cpp_norm_list(Name, [A|As], [B|Bs]) :- cpp_norm_term(Name, A, B), cpp_norm_list(Name, As, Bs).
%% ... AND THE DECLARATION'S TEMPLATE-PARAMETER DEFAULTS, for a member template (0.73's rule for a free template's
%% redeclaration, here): libc++ declares `template <class _ForwardIterator, __enable_if_t<..., int> = 0> void
%% __init(_ForwardIterator, _ForwardIterator);' in the class and defines it out of class without the `= 0', and taken
%% whole the definition refused cannot_deduce(anon) -- getline's append of a buffer's span goes through it. Lent where
%% the two lists are alike in the class's words, or of one SHAPE (kind for kind, 0.100): C++ has the definition's
%% list match the declaration's, and the defaults stand on the declaration alone
cpp_keep_tdefaults(Name, template(_, TPs0, _), template(L, TPs1, X), template(L, TPs2, X)) :- ( cpp_tparams_alike(Name, TPs0, TPs1) ; cpp_tparams_shape(TPs0, TPs1) ), !, cpp_merge_defaults(x, TPs1, [x-tmpl(TPs0, x)], TPs2).
cpp_keep_tdefaults(_, _, M, M).
cpp_tparams_shape([], []).
cpp_tparams_shape([tparam(K0, P, _)|Ps], [tparam(K1, P, _)|Qs]) :- functor(K0, F, A), functor(K1, F, A), cpp_tparams_shape(Ps, Qs).
cpp_tparams_shape([requires(_)|Ps], Qs) :- !, cpp_tparams_shape(Ps, Qs).
cpp_tparams_shape([ttp(_, _)|Ps], Qs) :- !, cpp_tparams_shape(Ps, Qs).
cpp_tparams_shape(Ps, [requires(_)|Qs]) :- !, cpp_tparams_shape(Ps, Qs).
cpp_tparams_shape(Ps, [ttp(_, _)|Qs]) :- !, cpp_tparams_shape(Ps, Qs).
cpp_member_const(template(_, _, M), K) :- !, cpp_member_const(M, K).
cpp_member_const(method(_, Qs, _, _, _, _, _), K) :- !, ( memberchk(const, Qs) -> K = const ; K = nonconst ).
cpp_member_const(_, nonconst).
%% AN EXTERN TEMPLATE'S INSTANCE IS SHIPPED: `extern template class basic_istream<char>;' in a library header says the
%% library's binary holds that instance -- every member of it that libc++ does not hide from its ABI -- and clang
%% calls those members rather than instantiating them (`cin >> n' is `_ZNSt3__113basic_istreamIcNS_11char_traitsIcEEE
%% rsERi' in clang's own object; the num_get machinery behind it is never compiled by a program). Here the same: the
%% instance's out-of-class definitions are NOT merged into its members (cpp_member_def_key), so they stay declared,
%% and a declared member of a library class is called by its Itanium name (cpp_shipped_member, 0.73). WHICH members:
%% libc++ marks the hidden ones `_LIBCPP_HIDE_FROM_ABI', which the preprocessor here spells as visibility hidden plus
%% always_inline -- and every such out-of-class definition of the stream classes is written `inline', every exported
%% one without it (measured on the flattened <iostream>: 41 + 29 + 16 definitions, not one exception) -- so the
%% `inline' the reader keeps (cpp_mdef_item's Qs) is the mark, no attribute needed. A member in the class body stays
%% compiled as before (libc++ writes those hidden without exception). The other spelling, `extern template void
%% basic_string<char>::__init(const value_type *, size_type);', names ONE member of an instance (libc++'s string
%% lists its exported members so), keyed by its name and its parameters as written.
cpp_note_extern(declare(_, base(_, [class(tmpl(N, Args), none)]))) :- atom(N), !, assertz('$cpp_extern'(N, Args, all)).
cpp_note_extern(declaration(_, _, _, [var(scoped(Path, M), fn(_, Ps, _), none)])) :- ccl_last(Path, tmpl(N, Args)), atom(N), cpp_mdef_name(M), !,
    cpp_params_key(Ps, K), assertz('$cpp_extern'(N, Args, member(M, K))).
cpp_note_extern(_).
cpp_extern_shipped(N, Args, Where, K, PK, Item) :-
    '$cpp_extern'(N, EArgs, Scope), cpp_extern_args(N, EArgs, Args), ( Scope == all -> true ; Where == plain, Scope == member(K, PK) ),
    cpp_mdef_function(Item), \+ cpp_mdef_inline(Item), \+ nb_current('$cpp_nonabi', yes), !.
%% ... BUT NOT A MEMBER OF A CLASS WHOSE LAYOUT IS NOT THE ABI'S (0.117). The shipped member reads the object's own data where
%% clang laid it, and a class derived from one with a virtual base is laid here with that base whole at its end -- libc++ 18's
%% `basic_ofstream<char>::open(const char *, openmode)' (exported, not hidden) wrote `__sb_' at offset 8, where the program's
%% `std::ofstream' keeps it at 160, and `is_open()' answered false before the next write crashed. Such a member is compiled from
%% its definition in the header, as an `inline' one is. The members of the class that HOLDS the virtual base (`basic_ostream')
%% and of a class with none stay shipped: their layout is the ABI's.
cpp_nonabi_bases(Bases) :-
    findall(BN, ( member(base(_, B0), Bases), catch(cpp_base_name(B0, BN), _, fail) ), BNs),
    member(BN, BNs), cpp_vbases_of(BN, [_|_]), \+ cpp_holder_bases(BNs), !.   % ... unless the class HOLDS the virtual base itself, a diamond's or a single path's (cpp_diamond_paths, cpp_path_holder; 0.163): its layout is the ABI's, and its members stay shipped
cpp_holder_bases(BNs) :- cpp_holder_paths(BNs, _, _).   % every base that holds virtual bases holds them through its `.nv' form (0.171: several)
%% ... a member FUNCTION, never a nested class's definition (the stream's sentry, merged as any nested class), and never a
%% MEMBER TEMPLATE (a second template wrapper: no explicit instantiation covers one)
cpp_mdef_function(template(_, _, M)) :- !, M \= template(_, _, _), cpp_mdef_function(M).
cpp_mdef_function(in_nested(_, M)) :- !, cpp_mdef_function(M).
cpp_mdef_function(method(_, _, _, _, _, _, _)).
cpp_mdef_function(ctor(_, _, _, _, _)).
cpp_mdef_function(dtor(_, _, _)).
%% THE EXTERN DECLARATION'S ARGUMENTS ARE THE INSTANCE'S WHOLE LIST, its template's defaults filling the rest ([temp.explicit]/2; 0.201):
%% `extern template class basic_string<char>;' is `basic_string<char, char_traits<char>, allocator<char>>', and compared by its first
%% argument alone it covered `std::pmr::string', whose `__init' and `append' were called by symbols no library defines (a link error).
%% The full list is made once per declaration ('$cpp_extern_full'/3); one the template cannot make keeps the first arguments' test.
cpp_extern_args(N, EArgs, Args) :- length(EArgs, LE), length(Args, LA), LE < LA, !,
    ( '$cpp_extern_full'(N, EArgs, Full) -> true ; catch(cpp_extern_full(N, EArgs, Full0), _, fail) -> Full = Full0, assertz('$cpp_extern_full'(N, EArgs, Full)) ; Full = EArgs ),
    cpp_extern_args(Full, Args).
cpp_extern_args(_, EArgs, Args) :- cpp_extern_args(EArgs, Args).
cpp_extern_full(N, EArgs, Full) :- cpp_class_template(N, TPs, _), cpp_targ_values(EArgs, EArgs1), cpp_bind_targs(TPs, EArgs1, B), cpp_full_args(TPs, B, Full), !.
cpp_extern_args([], _).                                                          % the arguments compared in order, each by its key
cpp_extern_args([E|Es], [A|As]) :- cpp_type_key(E, EK), cpp_type_key(A, AK), EK == AK, cpp_extern_args(Es, As).
cpp_mdef_inline(template(_, _, M)) :- !, cpp_mdef_inline(M).
cpp_mdef_inline(in_nested(_, M)) :- !, cpp_mdef_inline(M).
cpp_mdef_inline(method(_, Qs, _, _, _, _, _)) :- ( memberchk(inline, Qs) -> true ; memberchk(hidden, Qs) ).   % `inline' (libc++ 21's mark) or hidden visibility (libc++ 18's, 0.112)
cpp_mdef_inline(ctor(_, Qs, _, _, _)) :- ( memberchk(inline, Qs) -> true ; memberchk(hidden, Qs) ).   % ... a constructor or destructor too since the reader keeps the prefix of one defined out of its class (reader 112, 0.117): libc++ 18's `inline basic_ofstream<...>::basic_ofstream(const char *, ios_base::openmode)'
cpp_mdef_inline(dtor(_, Qs, _)) :- ( memberchk(inline, Qs) -> true ; memberchk(hidden, Qs) ).
%% a conversion function's key holds its type, which the declaration has SUBSTITUTED (cpp_subst_mname) and the definition, kept by its
%% template, has not: every definition of a conversion function is a candidate, and the substituted names must agree
cpp_mdef_lookup(N, operator(conv(_)), operator(conv(_)), TPs, Pat, Item) :- !, '$cpp_mdef'(N, operator(conv(_)), TPs, Pat, Item).
cpp_mdef_lookup(N, _, Key, TPs, Pat, Item) :- ( '$cpp_mdef'(N, Key, TPs, Pat, Item), cpp_special_pattern(Pat) ; '$cpp_mdef'(N, Key, TPs, Pat, Item), \+ cpp_special_pattern(Pat) ).
%% A SPECIALIZATION'S DEFINITION OF A MEMBER COMES BEFORE THE PRIMARY'S (0.117): `template <size_t _Size> __bitset<1, _Size>::flip()' and the
%% primary's `__bitset<_N_words, _Size>::flip()' both match `__bitset<1, 16>', and the first registered, the primary's, served the
%% specialization -- whose `__first_' is one word, not an array. A pattern with anything but distinct parameters in it is a specialization's.
cpp_special_pattern(Pat) :- is_list(Pat), Pat \== [], \+ cpp_identity_pattern(Pat, []).
cpp_identity_pattern([], _).
cpp_identity_pattern([A|As], Seen) :- ( A = base([], [typedef(P)]) ; A = id(P) ; A = pack(base([], [typedef(P)])) ; A = pack(id(P)) ), atom(P), \+ memberchk(P, Seen), cpp_identity_pattern(As, [P|Seen]).
cpp_mdef_key(plain, K, K).
cpp_mdef_key(nested(Nested), K, nested_member(Nested, K)).
cpp_mdef_inner(in_nested(_, Item), Item) :- !.
cpp_mdef_inner(template(L, TPs, in_nested(_, Item)), template(L, TPs, Item)) :- !.
cpp_mdef_inner(Item, Item).
%% a nested class's members, once the class itself is whole: each bodyless one takes its definition from the
%% enclosing class's records, keyed nested_member(Nested, K)
cpp_nested_defs(N, Name, Args, nested(base(Q, [class(K, Nested, Bases, NMs0)])), nested(base(Q, [class(K, Nested, Bases, NMs)]))) :-
    is_list(NMs0), atom(Nested), '$cpp_mdef'(N, nested_member(Nested, _), _, _, _), !,
    ( nb_current('$cpp_mdef_types', Map0) -> true ; Map0 = [] ), cpp_mdef_types(NMs0, Map0, Map), nb_setval('$cpp_mdef_types', Map),
    findall(M, ( member(M0, NMs0), cpp_member_def_key(N, Name, Args, nested(Nested), M0, M) ), NMs), nb_setval('$cpp_mdef_types', Map0).
cpp_nested_defs(_, _, _, M, M).
%% A DEFAULT ARGUMENT BELONGS TO THE DECLARATION, and C++ forbids repeating it on an out-of-class definition -- so
%% taking the definition whole threw the defaults away, and libc++'s `__grow_by_without_replace(a, b, c, d, 0)',
%% five arguments to six parameters, found no member of that arity at all.
cpp_keep_defaults([], Ps, Ps) :- !.
cpp_keep_defaults(_, [], []) :- !.
cpp_keep_defaults([param(_, _, D)|Ps0], [param(T, N)|Ps1], [param(T, N, D)|Ps2]) :- !, cpp_keep_defaults(Ps0, Ps1, Ps2).
cpp_keep_defaults([_|Ps0], [P|Ps1], [P|Ps2]) :- cpp_keep_defaults(Ps0, Ps1, Ps2).
cpp_member_params(template(L, TPs, M0), Ps, template(L, TPs, M)) :- !, cpp_member_params(M0, Ps, M).
cpp_member_params(method(L, Q, R, M, _, V, B), Ps, method(L, Q, R, M, Ps, V, B)) :- !.
cpp_member_params(ctor(L, Q, _, I, B), Ps, ctor(L, Q, Ps, I, B)) :- !.
cpp_member_params(M, _, M).
cpp_mdef_bind(none, Args, TPs, B) :- !, cpp_bind_targs(TPs, Args, B).       % a constructor's and a destructor's: the reader gives the class's bare name, so the parameters bind in order
cpp_mdef_bind(Pat, Args, TPs, B) :- cpp_match_pattern(Pat, Args, TPs, [], B).
cpp_instance_class(declare(L, base(_, [class(K, _, Bases, Ms)])), L, K, Bases, Ms) :- Ms \== none.
cpp_instance_class(declare(L, base(_, [struct(_, Ms)])), L, struct, [], Ms) :- Ms \== none.
cpp_instance_class(declare(L, base(_, [union(_, Ms)])), L, union, [], Ms) :- Ms \== none.
%% the arguments in the parameters' order, a pack's spliced: what a specialization's pattern is matched against
cpp_full_args([], _, []).
cpp_full_args([requires(_)|TPs], B, As) :- !, cpp_full_args(TPs, B, As).
cpp_full_args([ttp(_, _)|TPs], B, As) :- !, cpp_full_args(TPs, B, As).
cpp_full_args([tparam(_, P, _)|TPs], B, As) :- memberchk(P-A, B), ( cpp_pack_list(A, L) -> append(L, As1, As) ; As = [A|As1] ), cpp_full_args(TPs, B, As1).
%% the specialization whose pattern matches, the most specialized of those that do (X is more specialized than Y when
%% X's pattern, taken as arguments, matches Y's)
cpp_pick_spec(N, Args, SB, Item) :-
    findall(m(TPs, Pat1, It), ( '$cpp_spec'(N, TPs, Pat, It), cpp_spec_pattern(N, Pat, Args, Pat1) ), Cands), Cands \== [],
    findall(m(TPs, Pat, It, B), ( member(m(TPs, Pat, It), Cands), cpp_match_pattern(Pat, Args, TPs, [], B),
                                  catch(cpp_constraints_hold(N, TPs, B), error(not_lowered(_), _), fail) ), Ms00), Ms00 \== [],   % A CONSTRAINED PARTIAL SPECIALIZATION is a candidate only where its constraints hold ([temp.spec.partial.match]; 0.109): libc++'s `indirectly_readable_traits<_Ip> requires is_array_v<_Ip>' took every iterator, its value_type the iterator itself
    cpp_by_constraints(Ms00, Ms0),   % ... and of two with one pattern the MORE CONSTRAINED is tried first ([temp.constr.order], by the count of its conjuncts)
    %% A DEFINITION BEFORE A FORWARD DECLARATION of the same specialization: libc++ declares `struct char_traits<char>;'
    %% early and defines it later, both matching `[char]' and equally specialized, so the empty one won and every
    %% `traits_type::copy' was a call to nothing. A declared-only specialization still stands where none is defined
    %% (an incomplete type a template argument may name).
    ( findall(M, ( member(M, Ms0), M = m(_, _, I2, _), cpp_template_class_def(I2) ), [D|Ds]) -> Ms = [D|Ds] ; Ms = Ms0 ),
    cpp_most_special(Ms, Ms, m(TPs1, _, Item, SB0)),
    cpp_vbinds_typed(TPs1, SB0, SB).   % ITS VALUE PARAMETERS OF THEIR TYPES (0.205; [temp.arg.nontype]/1, as the primary's are since 0.199): `S<T[N]>' over `int[7]' with `size_t N' binds `7ul', where the bound was an `int' and `decltype(S<int[7]>::n)' of `static constexpr auto n = N;' no `const size_t'
%% A PARTIAL SPECIALIZATION'S ARGUMENT LIST IS FILLED FROM THE PRIMARY'S DEFAULTS ([temp.spec.partial]): libc++
%% writes `template <class _Tp, class _Up, class = void> inline const bool __is_trivially_equality_comparable_impl
%% = false;' and specializes it `<_Tp, _Tp>' -- TWO arguments where the primary takes three -- so the pattern's
%% length never matched and `__is_trivially_equality_comparable_v<int, int>' was FALSE for everything, which sent
%% `std::find' to the overload guarded by its negation, whose body calls __find again: a stack overflow on
%% `std::find(v.begin(), v.end(), 5)'.
cpp_spec_pattern(N, Pat, Args, Pat1) :-
    length(Pat, LP), length(Args, LA),
    (   LP >= LA -> Pat1 = Pat
    ;   K is LA - LP,
        cpp_template(N, TPs0, _), cpp_plain_tparams(TPs0, TPs), length(TPs, LT), LT >= LA,
        cpp_nth_tail(LP, TPs, Rest), cpp_default_args(K, Rest, Extra)
    ->  append(Pat, Extra, Pat1)
    ;   Pat1 = Pat ).
cpp_plain_tparams([], []).
cpp_plain_tparams([requires(_)|Ts], Us) :- !, cpp_plain_tparams(Ts, Us).
cpp_plain_tparams([ttp(_, _)|Ts], Us) :- !, cpp_plain_tparams(Ts, Us).
cpp_plain_tparams([T|Ts], [T|Us]) :- cpp_plain_tparams(Ts, Us).
cpp_nth_tail(0, L, L) :- !.
cpp_nth_tail(K, [_|L], R) :- K > 0, K1 is K - 1, cpp_nth_tail(K1, L, R).
cpp_default_args(0, _, []) :- !.
cpp_default_args(K, [tparam(_, _, D)|Ts], [D|Ds]) :- D \== none, K1 is K - 1, cpp_default_args(K1, Ts, Ds).
cpp_by_constraints(Ms, Sorted) :- findall(K-I, ( nth1(I, Ms, M), M = m(TPs, _, _, _), cpp_constraint_count(TPs, C), K is -C ), KIs), msort(KIs, S0), findall(M, ( member(_-I, S0), nth1(I, Ms, M) ), Sorted).   % stable: equals keep their declaration order
cpp_constraint_count(TPs, C) :- findall(A, ( member(requires(R), TPs), cpp_conjunct(R, A) ), As), length(As, C).
cpp_conjunct(bin('&&', A, B), X) :- !, ( cpp_conjunct(A, X) ; cpp_conjunct(B, X) ).
cpp_conjunct(X, X).
cpp_most_special([M|_], All, M) :- \+ ( member(Y, All), Y \== M, cpp_spec_better(Y, M) ), !.   % `once': the comparison is a TEST (the shape 0.95 found exponential in the function ordering below)
cpp_most_special([_|Ms], All, M) :- cpp_most_special(Ms, All, M).
%% Y IS MORE SPECIALIZED THAN M where M's pattern deduces from Y's and not the other way; ON A TIE THE ONE WITH NO TRAILING PACK
%% EXPANSION WHERE THE OTHER ENDS IN ONE (0.201; [temp.deduct.type]/9: partial ordering ignores the pack expansion the shorter
%% list has no argument for, so both deduce; CWG 1432's tie-breaker, as clang and gcc order them): libc++'s
%% `__scoped_allocator_storage<_OuterAlloc>' over `<_OuterAlloc, _InnerAllocs...>' -- the first declared stood, and
%% `scoped_allocator_adaptor<allocator<string>>' was built on a storage with an inner adaptor of no allocator
cpp_spec_better(Y, M) :- once(cpp_more_special(Y, M)), ( \+ cpp_more_special(M, Y) -> true ; cpp_pack_tie(Y, M) ).
cpp_pack_tie(m(_, PY, _, _), m(_, PM, _, _)) :- last(PM, LM), LM = pack(_), \+ ( last(PY, LY), LY = pack(_) ).
cpp_more_special(m(TPsX, PatX, _, _), m(TPsY, PatY, _, _)) :- cpp_pattern_as_args(PatX, TPsX, ArgsX), cpp_match_pattern(PatY, ArgsX, TPsY, [], _).
cpp_pattern_as_args([], _, []).
cpp_pattern_as_args([pack(_)|Ps], TPs, As) :- !, cpp_pattern_as_args(Ps, TPs, As).
cpp_pattern_as_args([P|Ps], TPs, [P|As]) :- cpp_pattern_as_args(Ps, TPs, As).
%% two passes, as the standard deduces: the deducible elements bind the parameters, then every NON-DEDUCED element
%% -- an alias template's template-id, a name qualified by a parameter (`typename T::x'), a decltype -- is
%% substituted, resolved and compared with its argument; a refusal in that resolution is no match, which is the
%% SFINAE of the detection idiom: `__detector<_Default, __void_t<_Op<_Args...>>, _Op, _Args...>' is chosen only
%% where `_Op<_Args...>' has a type
cpp_match_pattern(Ps, As, TPs, B0, B) :- cpp_match_deducible(Ps, As, TPs, B0, B1, Later), cpp_match_later(Later, TPs, B1), B = B1.
cpp_match_deducible([], [], _, B, B, []).
cpp_match_deducible([pack(base(_, [typedef(P)]))], Args, TPs, B0, [P-pack(Args)|B0], []) :- memberchk(tparam(pack, P, _), TPs), !.
cpp_match_deducible([pack(id(P))], Args, TPs, B0, [P-pack(Args)|B0], []) :- memberchk(tparam(vpack(_), P, _), TPs), !.
cpp_match_deducible([P|Ps], [A|As], TPs, B0, B, Later) :-
    (   cpp_alias_through(P, TPs, P2) -> cpp_match_one(P2, A, TPs, B0, B1), Later = Later1   % AN ALIAS OF A CLASS TEMPLATE-ID IS TRANSPARENT ([temp.alias]/2): `__tuple_impl<__index_sequence<_Indx...>, _Tp...>' deduces _Indx through __integer_sequence<size_t, _Indx...> -- held non-deduced, the pattern never bound it and the tuple's base stayed the declared-only primary, an incomplete type
    ;   cpp_non_deduced(P, TPs) -> B1 = B0, Later = [P-A|Later1]
    ;   cpp_match_one(P, A, TPs, B0, B1), Later = Later1 ),
    cpp_match_deducible(Ps, As, TPs, B1, B, Later1).
cpp_alias_through(base(Q, [typedef(X)]), TPs, base(Q, [typedef(X2)])) :-
    cpp_template_id(X, N, UArgs), atom(N), \+ memberchk(tparam(template, N, _), TPs), cpp_alias_template(N),
    cpp_alias_pattern(N, UArgs, X2), cpp_template_id(X2, N2, _), atom(N2), \+ cpp_alias_template(N2), !.   % ... to a CLASS template's id; an alias of an alias (`__index_sequence_for') stays non-deduced
%% A VECTOR ALIAS TEMPLATE IS TRANSPARENT TOO (0.162): libc++ 21's `template <class _Tp, size_t _Np> using __simd_vector
%% __attribute__((__ext_vector_type__(_Np))) = _Tp;' deduces its element and its lane count from a vector (cpp_match_one/5)
cpp_alias_through(base(Q, [typedef(X)]), TPs, base(Q, [vector(K, X2, E2)])) :-
    cpp_template_id(X, N, UArgs), atom(N), \+ memberchk(tparam(template, N, _), TPs), cpp_alias_template(N), cpp_vector_alias(N, UArgs, K, X2, E2), !.
cpp_non_deduced(base(_, [typedef(tmpl(N, _))]), TPs) :- atom(N), \+ memberchk(tparam(template, N, _), TPs), cpp_alias_template(N), !.
cpp_non_deduced(base(_, [typedef(scoped(_, tmpl(N, _)))]), TPs) :- atom(N), \+ memberchk(tparam(template, N, _), TPs), cpp_alias_template(N), !.
cpp_non_deduced(base(_, [typedef(scoped(Path, _))]), TPs) :- cpp_path_dependent(Path, TPs), !.   % a qualified name whose nested-name-specifier names a parameter ANYWHERE, inside a template-id segment included ([temp.deduct.type]/5.1): libc++ 18's `basic_format_context<typename __retarget_buffer<_CharT>::__iterator, _CharT>' was resolved in the first pass with _CharT free, and the buffer's constraint refused every format context (test/cpp/run/ndpath.cpp)
cpp_non_deduced(base(_, [decltype(_)]), _).
cpp_non_deduced(P, TPs) :- \+ cpp_is_type(P), P \= id(_), P \= pack(_), member(tparam(_, Q, _), TPs), atom(Q), cpp_names_in(P, Q), !.   % A VALUE PATTERN NAMING A PARAMETER is evaluated once the others bind it, as C++ has it ([temp.deduct.type]/5): `sizeof(__default_three_way_comparator<_LHS, _RHS>) >= 0' compared raw folded to true for every pair of types
cpp_match_later([], _, _).
cpp_match_later([P-A|Ls], TPs, B) :- cpp_subst(P, B, P1),
    ( \+ ( member(tparam(_, Q, _), TPs), cpp_names_in(P1, Q) ) -> true ; cpp_trace(later_free(P1)), fail ),   % a parameter still free in it: no match
    (   cpp_is_type(P1)
    ->  ( catch(cpp_type(P1, T), error(not_lowered(W), _), ( cpp_trace(later_refused(W)), fail )) -> true ; cpp_trace(later_failed(P1)), fail ),
        ( cpp_same_type(T, A) -> true ; cpp_trace(later_differs(T, A)), fail )
    ;   ( catch(cpp_targ_value(P1, V), error(not_lowered(W), _), ( cpp_trace(later_refused(W)), fail )) -> true ; cpp_trace(later_failed(P1)), fail ),   % a value: evaluated under the bindings, a refusal in it no match (SFINAE)
        ( cpp_same_value(V, A) -> true ; cpp_trace(later_differs(V, A)), fail ) ),
    cpp_match_later(Ls, TPs, B).
cpp_match_one(base(Q, [typedef(P)]), A, TPs, B0, B) :- memberchk(tparam(type, P, _), TPs), !,
    cpp_pattern_quals(Q, A, A1),                                                     % `numeric_limits<const _Tp>' matches only a CONST argument, and binds _Tp to it WITHOUT the const -- the qualifiers were ignored, so it matched everything and the class derived from itself
    ( memberchk(P-A0, B0) -> cpp_same_type(A0, A1), B = B0 ; B = [P-A1|B0] ).
cpp_match_one(base(_, [typedef(P)]), tname(X), TPs, B0, B) :- memberchk(tparam(template, P, _), TPs), !, ( memberchk(P-A0, B0) -> A0 == tname(X), B = B0 ; B = [P-tname(X)|B0] ).
cpp_match_one(base(_, [typedef(X)]), tname(X), _, B, B) :- !.
cpp_match_one(id(P), A, TPs, B0, B) :- memberchk(tparam(K, P, _), TPs), \+ memberchk(K, [type, pack, template]), !, ( memberchk(P-A0, B0) -> cpp_same_value(A0, A), B = B0 ; B = [P-A|B0] ).
cpp_match_one(base(_, [typedef(tmpl(N, Sub))]), A, TPs, B0, B) :- !, cpp_match_tmpl(N, Sub, A, TPs, B0, B).
cpp_match_one(base(_, [typedef(scoped(_, tmpl(N, Sub)))]), A, TPs, B0, B) :- !, cpp_match_tmpl(N, Sub, A, TPs, B0, B).
cpp_match_one(ptr(_, X), A, TPs, B0, B) :- !, ccl_resolve_type(A, A1), A1 = ptr(_, Y), cpp_match_one(X, Y, TPs, B0, B).
cpp_match_one(ref(_, X), A, TPs, B0, B) :- !, A = ref(_, Y), cpp_match_one(X, Y, TPs, B0, B).
cpp_match_one(rref(_, X), A, TPs, B0, B) :- !, A = rref(_, Y), cpp_match_one(X, Y, TPs, B0, B).
cpp_match_one(arr(K, X), A, TPs, B0, B) :- !, ccl_resolve_type(A, A1), A1 = arr(KA, Y), cpp_match_bound_one(K, KA, TPs, B0, B1), cpp_match_one(X, Y, TPs, B1, B).   % ... AND ITS BOUND (0.167): `formatter<_CharT[_Size], _CharT>' over `char[2]' binds `_Size = 2', which libc++'s character-array formatter reads; `T[]' takes no bounded array, `T[N]' no unbounded one
cpp_match_one(memptr(CP, _, X), A, TPs, B0, B) :- !, ccl_resolve_type(A, memptr(CA, _, Y)),   % `_Rp (_Cp::*)(_A1)': __weak_result_type specializes over every member-function shape
    cpp_match_one(base([], [typedef(CP)]), base([], [typedef(CA)]), TPs, B0, B1), cpp_match_one(X, Y, TPs, B1, B).
%% A FUNCTION TYPE as a pattern, `_Rp(_ArgTypes...)' ([temp.deduct.type]/8: the return type and the parameter
%% types are deduced elements of their own) -- which is the whole of how <functional> is written: std::function,
%% __value_func, __policy_func, __func and __alloc_func are each a primary template declared and never defined
%% beside one partial specialization over a function type, and without this clause every one of them fell to the
%% primary and the instance was an incomplete type. A trailing parameter pack takes every parameter type left.
cpp_match_one(fn(R, Ps, V), A, TPs, B0, B) :- !, ccl_resolve_type(A, A1), A1 = fn(RA, PsA, VA), cpp_match_fn_mark(V, VA, TPs, B0, B00),
    cpp_match_one(R, RA, TPs, B00, B1), cpp_match_fparams(Ps, PsA, TPs, B1, B).
cpp_match_one(base(_, [typedef(scoped(Path, N))]), A, _, B, B) :- atom(N), \+ cpp_is_type(A), catch(cpp_enumerator(Path, N, V), _, fail), !, cpp_same_value(int(V), A).   % A SCOPED ENUMERATOR READ AS A TYPE (0.133): the reader takes `range_format::map' for a type, its last name a known template (std::map), and libc++ 21's `__range_default_formatter<range_format::map, _Rp, _CharT>' never matched `format_kind<map<...>>', 1 -- std::format of a map met the primary, declared and not defined
cpp_match_one(base(_, [vector(K, X, E)]), A, TPs, B0, B) :- !, ccl_resolve_type(A, base(_, [vec(K, N, AE)])), cpp_vector_count(K, N, AE, V),   % a vector's element and lane count (0.162)
    cpp_match_one(X, int(V), TPs, B0, B1), cpp_match_one(E, AE, TPs, B1, B).
cpp_match_one(P, A, _, B, B) :- cpp_is_type(P), !, cpp_same_type(P, A).
cpp_match_one(P, A, _, B, B) :- cpp_same_value(P, A).
%% a function type's mark matches the argument's, AND ITS `noexcept(i)' DEDUCES i ([temp.deduct.type]/8, P0012; 0.205): true
%% where the argument's type is noexcept, false where it is not, the rest of the marks alike -- `template <bool B> int
%% callp(void (*)() noexcept(B))' called with a function's name was no_matching_template, B deduced from nothing
cpp_match_fn_mark(V, VA, _, B, B) :- V = VA, !.
cpp_match_fn_mark(V, VA, TPs, B0, B) :- nonvar(V), V = q(W, Qs), select(nxif(id(P)), Qs, Qs1), atom(P),
    memberchk(tparam(K, P, _), TPs), \+ memberchk(K, [type, pack, template]), !,
    ( nonvar(VA), VA = q(WA, QsA0) -> true ; WA = VA, QsA0 = [] ),
    ( select(noexcept, QsA0, QsA) -> A = bool(true) ; QsA = QsA0, A = bool(false) ), W = WA, Qs1 = QsA,
    ( memberchk(P-A0, B0) -> cpp_same_value(A0, A), B = B0 ; B = [P-A|B0] ).
%% an array pattern's bound against the argument's (0.167): an unbounded pattern takes only an unbounded array, a value
%% parameter binds the folded bound, any other bound compares as a value
cpp_match_bound_one(none, KA, _, B, B) :- !, KA == none.
cpp_match_bound_one(_, none, _, _, _) :- !, fail.
cpp_match_bound_one(id(P), KA, TPs, B0, B) :- memberchk(tparam(K, P, _), TPs), \+ memberchk(K, [type, pack, template]), !,
    ( catch(once(ccl_const_eval(KA, V)), _, fail), integer(V) -> A = int(V) ; A = KA ), ( memberchk(P-A0, B0) -> cpp_same_value(A0, A), B = B0 ; B = [P-A|B0] ).
cpp_match_bound_one(K, KA, _, B, B) :- ( catch(once(ccl_const_eval(K, V1)), _, fail), catch(once(ccl_const_eval(KA, V2)), _, fail) -> V1 =:= V2 ; true ).
cpp_pattern_quals([], A, A) :- !.
cpp_pattern_quals(Q, base(Q0, S), base(Q1, S)) :- forall(member(X, Q), memberchk(X, Q0)), findall(Y, ( member(Y, Q0), \+ memberchk(Y, Q) ), Q1).
cpp_match_tmpl(N, Sub, A, TPs, B0, B) :- memberchk(tparam(template, N, _), TPs), !,               % `_Sp<_Tp, _Args...>': the template deduced too (tname)
    cpp_instance_of(A, N1, SubArgs), ( memberchk(N-tname(N0), B0) -> N0 == N1, B1 = B0 ; B1 = [N-tname(N1)|B0] ), cpp_match_pattern(Sub, SubArgs, TPs, B1, B).
cpp_match_tmpl(N, Sub, A, TPs, B0, B) :- cpp_instance_of(A, N, SubArgs), cpp_fill_pattern(N, Sub, SubArgs, Sub1), cpp_match_pattern(Sub1, SubArgs, TPs, B0, B).
%% A TEMPLATE-ID IN A PATTERN NAMES THE SPECIALIZATION WITH ITS DEFAULTS ([temp.arg]/2): `basic_string<_CharT>' is
%% `basic_string<_CharT, char_traits<_CharT>, allocator<_CharT>>', so the pattern is filled from the primary's
%% defaults, substituted with the pattern's own elements, before it meets an instance's full argument list --
%% libc++'s `__format::__enable_insertable<basic_string<_CharT>>' matched no string, a back_insert_iterator over
%% one was no container's and std::format wrote into a `__writer_container<void>' (test/cpp/run/tmpldefaults.cpp)
cpp_fill_pattern(N, Sub, Args, Sub1) :- length(Sub, LS), length(Args, LA), LS < LA, \+ memberchk(pack(_), Sub),
    catch(cpp_template(N, TPs0, _), _, fail), cpp_plain_tparams(TPs0, TPs), length(TPs, LT), LT >= LA,
    cpp_fill_pattern_(TPs, Sub, LA, [], Sub1), !.
cpp_fill_pattern(_, Sub, _, Sub).
cpp_fill_pattern_(_, _, 0, _, []) :- !.
cpp_fill_pattern_([tparam(_, P, _)|Ts], [E|Es], K, B, [E|Fs]) :- !, K1 is K - 1, cpp_fill_pattern_(Ts, Es, K1, [P-E|B], Fs).
cpp_fill_pattern_([tparam(_, P, D)|Ts], [], K, B, [E|Fs]) :- D \== none, cpp_subst(D, B, E), K1 is K - 1, cpp_fill_pattern_(Ts, [], K1, [P-E|B], Fs).
cpp_match_fparams([], [], _, B, B).
cpp_match_fparams([param(pack(base(_, [typedef(P)])), _)], As, TPs, B0, [P-pack(Ts)|B0]) :-
    memberchk(tparam(pack, P, _), TPs), !, cpp_param_types(As, Ts).
cpp_match_fparams([param(P, _)|Ps], [param(A, _)|As], TPs, B0, B) :- cpp_match_one(P, A, TPs, B0, B1), cpp_match_fparams(Ps, As, TPs, B1, B).
%% an argument that is an instance of N: its arguments as they were bound
cpp_instance_of(base(_, [S]), N, Args) :- cpp_tag_name(S, Name), atom(Name), '$cpp_inst'(Name, inst(N, Args)), !.   % AN INSTANCE RESOLVED TO ITS STRUCT SPEC IS THE INSTANCE STILL (0.93): libc++ 18's `__make_tuple_types' asks `__make_tuple_types_flat<__remove_cv_t<__libcpp_remove_reference_t<_Tp>>, ...>', and the builtin hands the tuple's instance back as `struct('tuple.int_r', Ms)' -- against which the pattern `_Tuple<_Types...>' matched nothing, so the instance was incomplete and `__apply_quals' a template without a body
cpp_instance_of(base(_, [typedef(Name)]), N, Args) :- atom(Name), '$cpp_inst'(Name, inst(N, Args)), !.
cpp_instance_of(base(_, [typedef(X)]), N, Args) :- cpp_template_id(X, N, Args0), cpp_targ_values(Args0, Args).
cpp_same_type(A, B) :- cpp_type(A, A1), cpp_type(B, B1), ccl_resolve_type(A1, A2), ccl_resolve_type(B1, B2), ( cpp_class_of_type(A2, C1), cpp_class_of_type(B2, C2) -> C1 == C2, cpp_same_quals(A2, B2) ; A2 == B2 -> true ; cpp_type_key(A2, K), cpp_type_key(B2, K2), K == K2 -> true ; cpp_same_compound(A2, B2) ).   % ... and two other types by the KEY an instance is named by (0.109): `is_same_v<common_reference_t<int &, const int &>, const int &>' was false where `same<...>' took one instance   % two class types are the same by CLASS: a struct spec resolved by one road carries its members one way and by another another, and `is_same<__remove_const_ref_t<const piecewise_construct_t &>, piecewise_construct_t>' was false
%% ... and a reference, a pointer or an array is the same as one of its shape whose referent is the same type
%% (0.112): the resolution does not reach under a reference, so `const uint32_t &' and `const unsigned &' keyed apart and
%% `is_same_v<common_reference_t<const unsigned &, uint32_t &>, const unsigned &>' was false
cpp_same_compound(ref(Q1, X), ref(Q2, Y)) :- !, msort(Q1, S), msort(Q2, S), cpp_same_type(X, Y).
cpp_same_compound(rref(Q1, X), rref(Q2, Y)) :- !, msort(Q1, S), msort(Q2, S), cpp_same_type(X, Y).
cpp_same_compound(ptr(Q1, X), ptr(Q2, Y)) :- !, msort(Q1, S), msort(Q2, S), cpp_same_type(X, Y).
cpp_same_compound(arr(N1, X), arr(N2, Y)) :- ( N1 == N2 -> true ; ccl_const_eval(N1, V), ccl_const_eval(N2, V) ), cpp_same_type(X, Y).
cpp_same_quals(base(Q1, _), base(Q2, _)) :- !, sort(Q1, S1), sort(Q2, S2), S1 == S2.
cpp_same_quals(_, _).
cpp_same_value(A, B) :- cpp_value_of(A, VA), cpp_value_of(B, VB),
    ( VA == VB -> true ; number(VA), number(VB) -> VA =:= VB ; catch(ccl_w_cmp(VA, VB, =), _, fail) ).   % a value past 2^60 is big(Atom) -- decimal when computed, hex when written so -- and no number to compare: `span<_Tp, dynamic_extent>' is `span<_Tp, 18446744073709551615>' (0.117)
%% ... the value of a pattern element or an argument: the one evaluator's, else the template argument's own road (cpp_targ_value) -- `dynamic_extent' is `inline constexpr size_t
%% dynamic_extent = numeric_limits<size_t>::max()', a name whose value only a constexpr call gives
cpp_value_of(E, V) :- ( ccl_const_eval(E, V0) -> V = V0 ; E = bool(X) -> ( X == true -> V = 1 ; V = 0 )
    ; nonvar(E), E = cast(ET, X), cpp_enum_type(ET) -> cpp_value_of(X, V)   % an enumeration's typed value (0.203): its number
    ; catch(cpp_targ_value(E, A), error(not_lowered(_), _), fail), ( A = int(V0) -> V = V0 ; A = bool(X) -> ( X == true -> V = 1 ; V = 0 ) ; A = cast(ET, X), cpp_enum_type(ET) -> cpp_value_of(X, V) ) ).   % a scoped enumerator's value is its enum's typed value (0.203)
%% a variable template's instance: the initializer under the bindings, a constant where it folds
cpp_instantiate_variable(N, Args, E) :- ground(Args), '$cpp_vtm'(N, A0, E0), A0 == Args, !, E = E0.   % A VARIABLE TEMPLATE'S VALUE IS REMEMBERED (0.112): one instance per arguments -- `is_convertible_v' was evaluated 1031 times over libc++'s ranges, 35 instances in all
cpp_instantiate_variable(N, Args, E) :- cpp_instantiate_variable_(N, Args, E), ( ground(Args) -> assertz('$cpp_vtm'(N, Args, E)) ; true ).
cpp_instantiate_variable_(N, Args, E) :-
    ( cpp_class_template(N, TPs, declaration(_, _, _, [var(_, VT, Init)])) -> true ; cpp_refuse(0, template_without_body(N)) ),
    cpp_bind_targs(TPs, Args, B), cpp_full_args(TPs, B, FullArgs),
    ( cpp_pick_spec(N, FullArgs, SB, declaration(_, _, _, [var(_, SVT, SInit)])) -> cpp_subst(SInit, SB, I1), VB = SB, VT1 = SVT ; cpp_subst(Init, B, I1), VB = B, VT1 = VT ),
    cpp_expr(none, I1, I2), cpp_trace(vartmpl(N, Args, I2)), ( I2 = bool(_) -> E = I2 ; ccl_const_eval(I2, V) -> cpp_vt_typed_value(VT1, VB, I2, V, E) ; cpp_eval_constant(I2, V) -> cpp_vt_typed_value(VT1, VB, I2, V, E) ; cpp_object_value(I2) -> E = I2 ; cpp_braced_object(I2, VT1, VB, E0) -> E = E0 ; cpp_vt_floating(VT1, VB, I2, E0) -> E = E0 ; cpp_trace(vartmpl_not_constant(I2)), cpp_refuse(0, variable_template_not_constant(N)) ).
%% A VARIABLE TEMPLATE'S VALUE OF ITS DECLARED TYPE (0.199): `template <auto N> constexpr auto w = N;' over 'b' a char,
%% `tuple_size_v<T>' a size_t; the value was an int whatever the variable's type
cpp_vt_typed_value(VT0, B, I2, V, E) :- integer(V), catch(( cpp_vt_type(VT0, B, I2, T), ( cpp_value_lit(T, V, E0) -> true ; cpp_enum_value_lit(T, V, E0) ) ), _, fail), !, E = E0.
cpp_vt_typed_value(_, _, _, V, int(V)).
%% the declared type substituted, a placeholder the initializer's type (its top-level qualifiers off) under the declaration's own
cpp_vt_type(VT0, B, I2, T) :- cpp_subst(VT0, B, VT1), cpp_storage_off(VT1, VT2),
    (   VT2 = base(Q0, [auto]) -> ( memberchk(decltype_auto, Q0) -> Q = [] ; Q = Q0 ), ccl_type_of(I2, IT), IT \== unknown, ccl_resolve_type(IT, R),
        ( R = base(_, Sp) -> R1 = base([], Sp) ; R = ptr(_, PE) -> R1 = ptr([], PE) ; R1 = R ), ccl_add_quals(Q, R1, T)
    ;   \+ cpp_has_auto(VT2), cpp_type(VT2, T) ).
%% A FLOATING VALUE (0.201): <numbers>' `template <floating_point _Tp> inline constexpr _Tp pi_v<_Tp> = 3.141592653589793238462643383279502884L;'
%% -- the evaluator holds no floating value, so the instance is its initializer converted to the variable's type, a constant the lowering folds
%% (ir_fp_value/2, as a floating static's, cpp_static_floating/4); `std::numbers::pi' was refused `variable_template_not_constant(pi_v)'
cpp_vt_floating(VT0, B, I2, cast(T, I2)) :- catch(( cpp_vt_type(VT0, B, I2, T), ir_fp_global(T, _), ir_fp_value(cast(T, I2), _) ), _, fail), !.
%% A VALUE THAT IS A LAMBDA CALLED IN PLACE (0.133): libc++ 21 writes `template <class _Rp> constexpr range_format
%% format_kind = [] { ... }();' and its specialization for an input range the same way, a lambda whose body chooses by
%% `if constexpr' -- the constraint of the range formatter, so `std::format("{}", v)' of a vector met the primary
%% `formatter', which has no `parse'. Desugared, the value is a statement expression: the closure, a temporary, then
%% the call of its `operator()' over the temporary's address -- which the evaluator runs, as it runs a constexpr
%% function's body (`cpp_eval_reduce' on `stmt_expr'), with a budget of its own when it is the outermost fold.
cpp_eval_constant(E, V) :- E = stmt_expr(_), cpp_fold_depth(D), ( D == 0 -> nb_setval('$cpp_eval_steps', 0) ; true ),
    catch(( cpp_eval_reduce(E, [], R), cpp_eval_value(R, V0) ), error(not_lowered(_), _), fail), cpp_eval_scalar(V0), !, V = V0.
%% ... AND A BRACED INITIALIZER OF THE DECLARED CLASS TYPE (0.121): libc++ 18's `template <size_t _Idx> inline constexpr in_place_index_t<_Idx>
%% in_place_index{};' is the object of an empty class written as `T v{}', the initializer a bare `init([])' whose type is the declaration's:
%% the class's object, a compound literal of the declared type (an empty or trivially constructible class; any other class is run-time).
cpp_braced_object(init([]), VT0, B, compound_lit(T, init([]))) :-
    cpp_subst(VT0, B, VT1), catch(cpp_type(VT1, T), error(not_lowered(_), _), fail), cpp_class_of_type(T, C), cpp_trivial_default(C).
%% A VARIABLE TEMPLATE WHOSE VALUE IS AN OBJECT OF CLASS TYPE answers that value (0.113; [temp.pre]/1, a variable
%% template's specialization is a variable): libc++ 18 writes `template <size_t _Np> inline constexpr auto elements =
%% __elements::__fn<_Np>{};' and `inline constexpr auto keys = elements<0>;', the customization point objects of
%% views::keys and views::values, and an object that is no constant was refused. The value is a COPY of the
%% initializer, a compound literal of the class with no temporaries in it: the same object wherever its address is
%% not asked for, which a constexpr object of an empty class never has. `vtobject.cpp'.
cpp_object_value(compound_lit(T, init(_))) :- cpp_class_of_type(T, _).
%% a function template at a call: its type arguments explicit, then deduced from the arguments' types, then defaulted.
%% The candidates are every DEFINITION of the name, in declaration order (a prototype is a declaration item, not a
%% function); one whose signature does not hold -- the arity, a deduction, a default, a value parameter's type, a
%% class-typed parameter's argument, the constraints -- is no candidate (SFINAE), and of those that hold the MOST
%% SPECIALIZED wins: X is more specialized than Y when Y's parameter types deduce from X's, taken as arguments with X's
%% own parameters opaque (`swap(vector<T, A> &, ...)' over `swap(T &, T &)'); the first declared among equals.
cpp_instantiate_function(F, Explicit, As, Name) :- cpp_where(fn(F), cpp_instantiate_function__(F, Explicit, As, Name)).
cpp_instantiate_function__(F, Explicit, As, Name) :-
    ( nb_getval('$cpp_trace', yes) -> findall(A-T, ( member(A, As), ( ccl_type_of(A, T0), T0 \== unknown -> T = T0 ; T = unknown ) ), ATs), cpp_trace(call_types(F, ATs)) ; true ),
    cpp_fn_candidates(F, Cands00), cpp_libq_cands(F, Cands00, Cands01), cpp_lib_unq_cands(F, As, Cands01, Cands),     % assertz: declaration order; the merged set kept per name (0.97); the program's own hidden as cpp_fn_hidden/3 hides them (0.233)
    length(Cands, NC), ( nb_current('$cpp_first_refusal', Outer) -> true ; Outer = none ), nb_setval('$cpp_first_refusal', none),
    (   catch(cpp_holding_set(F, Explicit, As, Cands, NC, Hs), E, ( nb_setval('$cpp_first_refusal', Outer), throw(E) ))
    ->  nb_getval('$cpp_first_refusal', FirstW), nb_setval('$cpp_first_refusal', Outer)   % THE ENCLOSING CALL'S FIRST REFUSAL BACK (0.112): a candidate check makes calls of its own, each resetting the one global, and the reason reported for `std::invoke' was a nested `__sfinae_test_impl''s
    ;   nb_setval('$cpp_first_refusal', Outer), fail ),
    (   Hs == [] -> ( FirstW == none -> cpp_refuse(0, no_matching_template(F)) ; cpp_refuse(0, FirstW) )   % none fit: the first one's reason
    ;   cpp_fewest_conversions(Hs, Hs1), cpp_defined_first(Hs1, Hs2), cpp_most_special_fn(Hs2, Hs2, h(K, TPs, function(L, Sto, Ret, _, Ps, V, Body), B, _)),
        ( NC =:= 1 -> FN = F ; atomic_list_concat([F, '.c', K], FN) ),
        (   Body == none, cpp_ita_fn_instance(F, TPs, B, Ret, Ps, V, Name0) -> Name = Name0   % declared here, DEFINED in the shipped library: its own C++ symbol
        ;   cpp_instance_name(FN, TPs, B, Name) ),
        catch(cpp_instantiate_function_(F, TPs, B, L, Sto, Ret, Ps, V, Body, Name), error(not_lowered(W), H),
              ( W = instance_refused(_, _) -> throw(error(not_lowered(W), H)) ; throw(error(not_lowered(instance_refused(Name, W)), H)) )) ).   % A CANDIDATE HELD, and its body refused: the refusal is THAT, named
%% ... and not a chance for the plain overloads of the name (cpp_call's template road, cpp_free_operator_call): the
%% getline<char, ...> that held and whose body refused `auto &' fell through to C's getline(char **, size_t *, FILE *),
%% three arguments alike, and the stream and the string went to it as pointers
%% A FUNCTION TEMPLATE'S REDECLARATION TAKES THE DEFAULTS OF ITS FIRST DECLARATION: C++ lets a default template
%% argument stand on the first declaration only, so libc++ writes `template <class _Tp, __enable_if_t<..., int> =
%% 0>' on the prototype and `template <class _Tp, __enable_if_t<..., int>>' on the definition below it -- and the
%% definition refused cannot_deduce(anon) while the prototype held and was emitted as a declare: `__to_chars_integral',
%% the last symbol between `std::cout << "hello"' and a binary. The other declarations of the name with the same
%% parameter list lend theirs, as a class template's declarations do (cpp_merge_defaults, 0.44).
%% THE CANDIDATE SET OF A NAME IS MADE ONCE (0.97): `std::get' has 96 definitions in libc++ 18's <tuple>, <utility> and
%% their closure, and every one of `stdtuple''s 188 calls of it rebuilt the merged set -- each candidate's parameter key
%% computed against every other's, 9216 key resolutions a call, 0.36 s before the first candidate was even tried. The
%% set is kept per name and remade only where the count of the name's templates has moved (a header loaded since).
cpp_fn_candidates(F, Cands) :- cpp_hdr_join(F), aggregate_all(count, '$cpp_tmplh'(F, _, _, _), N), atom_concat('$cpp_fncands:', F, K),
    (   nb_current(K, cands(N, Cands0)) -> Cands = Cands0
    ;   findall(TPs-Fn, ( '$cpp_tmpl'(F, TPs, Item), cpp_fn_item(Item, Fn) ), Cands0), cpp_dedupe_candidates(Cands0, Cands1), cpp_fn_merge_defaults(F, Cands1, Cands), nb_setval(K, cands(N, Cands)) ).
%% ONE FUNCTION TEMPLATE DECLARED TWICE IS ONE CANDIDATE (0.126): a header's items come from every summary that flattened it, and `<format>' and `<string>' each hold libc++
%% 21's `back_inserter', so a program that read both had it TWICE under one name. Two copies are alike in everything but the line numbers of their statements, and the
%% second is tried after the first: when the first candidate's check refuses and leaves its instance half made (`back_insert_iterator<void>', whose
%% `operator=(const typename _Container::value_type &)' cannot be declared), the second is answered the instance's name, holds, and emits a constructor of a class that
%% was never made -- `not lowered yet: typedef(back_insert_iterator.void)'. Alike means: the same template head, storage, result, name, parameters and variadic mark
%% and the same body once the line of each statement is set aside (`cpp_unlined/2', over the statement forms that carry one); a declaration is alike to a declaration
%% only (it lends its defaults to the definition, below). A form the list lacks compares unequal and keeps both. `formatton.cpp' (libc++ 21).
cpp_dedupe_candidates([], []).
cpp_dedupe_candidates([C|Cs], [C|Rs]) :- cpp_drop_copies(Cs, C, Cs1), cpp_dedupe_candidates(Cs1, Rs).
cpp_drop_copies([], _, []).
cpp_drop_copies([D|Ds], C, Rs) :- ( cpp_same_candidate(C, D) -> Rs = Rs1 ; Rs = [D|Rs1] ), cpp_drop_copies(Ds, C, Rs1).
cpp_same_candidate(TPs-function(_, S, R, N, Ps, V, B1), TPs2-function(_, S2, R2, N2, Ps2, V2, B2)) :- TPs == TPs2, S == S2, R == R2, N == N2, Ps == Ps2, V == V2, cpp_same_body(B1, B2).
cpp_same_body(B, B) :- B == none, !.
cpp_same_body(B1, B2) :- B1 \== none, B2 \== none, cpp_unlined(B1, U1), cpp_unlined(B2, U2), U1 == U2.
cpp_unlined(T, T) :- \+ compound(T), !.
cpp_unlined(T, U) :- T =.. [F, L|As], integer(L), cpp_line_functor(F), !, cpp_unlined_list(As, Us), U =.. [F, 0|Us].
cpp_unlined(T, U) :- T =.. [F|As], cpp_unlined_list(As, Us), U =.. [F|Us].
cpp_unlined_list([], []).
cpp_unlined_list([A|As], [U|Us]) :- cpp_unlined(A, U), cpp_unlined_list(As, Us).
cpp_line_functor(F) :- memberchk(F, [assume, break, case, continue, declaration, declare, default, defer, do, expr, for, for_each, goto, if, ifce, label, return, static_assert, switch, try, typedef, using, while, if_constexpr, if_consteval, co_return, bindings, function, method, ctor, dtor, template, include, directive, extern_c, namespace]).
cpp_fn_merge_defaults(F, Cands, Merged) :-
    findall(k(K, TPs, Fn), ( member(TPs-Fn, Cands), Fn = function(_, _, _, _, Ps, _, _), cpp_params_key(Ps, K) ), Keyed),   % each key once
    findall(TPs1-Fn, ( member(k(K, TPs0, Fn), Keyed), cpp_fn_lend_defaults(F, K, TPs0, Keyed, TPs1) ), Merged).
cpp_fn_lend_defaults(F, K, TPs0, Keyed, TPs) :-
    findall(F-tmpl(TPs2, x), ( member(k(K, TPs2, _), Keyed), TPs2 \== TPs0, cpp_same_tparams(TPs0, TPs2) ), Ts),
    ( Ts == [] -> TPs = TPs0 ; cpp_merge_defaults(F, TPs0, Ts, TPs) ).
%% ... a REDECLARATION only: the same template parameters, kind for kind and name for name (another overload over
%% the same value parameters lends nothing -- its defaults mean something else)
cpp_same_tparams([], []).
cpp_same_tparams([tparam(K, P, _)|Ps], [tparam(K, P, _)|Qs]) :- cpp_same_tparams(Ps, Qs).
cpp_same_tparams([requires(_)|Ps], Qs) :- !, cpp_same_tparams(Ps, Qs).
cpp_same_tparams([ttp(_, _)|Ps], Qs) :- !, cpp_same_tparams(Ps, Qs).
cpp_same_tparams(Ps, [requires(_)|Qs]) :- !, cpp_same_tparams(Ps, Qs).
cpp_same_tparams(Ps, [ttp(_, _)|Qs]) :- !, cpp_same_tparams(Ps, Qs).
%% a function template's item: its definition, or a DECLARATION with no body -- `template <class T> T &&declval();'
%% is never called, and a decltype wants only its return type
cpp_fn_item(function(L, Sto, Ret, N, Ps, V, Body), function(L, Sto, Ret, N, Ps, V, Body)).
cpp_fn_item(declaration(L, Sto, _, [var(N, fn(Ret, Ps, V), none)]), function(L, Sto, Ret, N, Ps, V, none)) :- atom(N).
cpp_fn_item(declaration(L, Sto, _, [var(operator(Op), fn(Ret, Ps, V), none)]), function(L, Sto, Ret, operator(Op), Ps, V, none)).   % ... an operator's too (0.126)
%% A FUNCTION TEMPLATE'S NAME AS AN ARGUMENT has no type of its own: C++ deduces its template arguments from the
%% TARGET, the function type a function-pointer parameter names ([temp.deduct.funcaddr]) -- `cout << std::endl' hands
%% `endl' to `operator<<(basic_ostream &(*)(basic_ostream &))', and the instance is endl<char, char_traits<char>>.
%% Typed by the inference as the template's RAW signature (a function template is declared under it, 0.49), the
%% argument's `basic_ostream<_CharT, _Traits>' was instantiated on the free names -- and `_Traits' met a stray block
%% typedef of another template's body -- 412 s to the memory cap. The name is `tmplfn(F)' to cpp_arg_type; a candidate's
%% function-pointer parameter DEDUCES it (cpp_target_deduces: the template's parameter types against the target's,
%% reference for reference, then its result, the defaults and the constraints; the first candidate of the name that
%% holds) and scores it exact; any other parameter takes it not at all; and where the candidate is chosen
%% (cpp_ref_args_) the argument becomes the instance's name, emitted as any instance is (cpp_deduce_target).
cpp_fn_template_ref(id(F), F) :- atom(F), \+ cpp_local(F), cpp_fn_template(F), !.
cpp_fn_template_ref(scoped(Path, F), F) :- atom(F), \+ cpp_scope_class(Path, _), cpp_fn_template(F), !.
cpp_fn_template(F) :- \+ \+ ( cpp_template(F, _, Item), cpp_fn_item(Item, _) ).
cpp_fn_target(PT0, FnT) :- cpp_type_or_self(PT0, PT), ccl_resolve_type(PT, R), ( R = ptr(_, T) ; R = ref(_, T) ; R = rref(_, T) ; R = fn(_, _, _), T = R ), ccl_resolve_type(T, FnT), FnT = fn(_, _, _), !.
cpp_target_deduces(F, FnT) :- \+ \+ cpp_target_bindings(F, FnT, _, _, _, _).
cpp_deduce_target(F, FnT, Name) :- cpp_where(fn(F), cpp_deduce_target_(F, FnT, Name)).
cpp_deduce_target_(F, FnT, Name) :-
    cpp_target_bindings(F, FnT, NC, K, TPs, h(function(L, Sto, Ret, _, Ps0, V0, Body), B)),
    ( NC =:= 1 -> FN = F ; atomic_list_concat([F, '.c', K], FN) ),
    (   Body == none, cpp_ita_fn_instance(F, TPs, B, Ret, Ps0, V0, Name0) -> Name = Name0   % the shipped library's symbol, as at the call road: an instance with no body ANYWHERE defines nothing under a name of ours
    ;   cpp_instance_name(FN, TPs, B, Name) ),
    cpp_instantiate_function_(F, TPs, B, L, Sto, Ret, Ps0, V0, Body, Name).
%% THE INSTANCE AN EXPLICIT TEMPLATE-ID NAMES (0.117): the candidates in declaration order, the first whose explicit arguments bind,
%% whose defaults fill the rest, whose parameters are ALL bound and whose constraints hold -- no arguments, no target type
cpp_fn_template_id(tmpl(F0, TArgs), F, TArgs) :- atom(F0), \+ cpp_local(F0), cpp_using_key(F0, F), cpp_fn_template(F), !.   % a header's keyed function template, named through a using of its namespace (0.161): `&abs<long long, ratio<1>>' under `using namespace std::chrono;'
cpp_fn_template_id(tmpl(F, TArgs), F, TArgs) :- atom(F), cpp_fn_template(F), !.
cpp_fn_template_id(scoped(Path, tmpl(F0, TArgs)), F, TArgs) :- atom(F0), \+ cpp_scope_class(Path, _), ( cpp_ns_key(Path, F0, K) -> F = K ; F = F0 ), cpp_fn_template(F), !.
cpp_explicit_instance(F, Explicit, Name) :- cpp_where(fn(F), cpp_explicit_instance_(F, Explicit, Name)).
cpp_explicit_instance_(F, Explicit, Name) :-
    cpp_fn_candidates(F, Cands), length(Cands, NC),
    (   cpp_explicit_candidate(Cands, 1, F, Explicit, K, TPs, h(function(L, Sto, Ret, _, Ps, V, Body), B)) -> true
    ;   cpp_refuse(0, no_matching_template(F)) ),
    ( NC =:= 1 -> FN = F ; atomic_list_concat([F, '.c', K], FN) ),
    (   Body == none, cpp_ita_fn_instance(F, TPs, B, Ret, Ps, V, Name0) -> Name = Name0
    ;   cpp_instance_name(FN, TPs, B, Name) ),
    cpp_instantiate_function_(F, TPs, B, L, Sto, Ret, Ps, V, Body, Name).
cpp_explicit_candidate([TPs-Fn|Cs], K, F, Explicit, K1, TPs1, H) :-
    (   catch(( cpp_bind_explicit(TPs, Explicit, B0), cpp_bind_defaults(TPs, B0, B),
                \+ ( member(tparam(_, P, _), TPs), \+ memberchk(P-_, B) ), cpp_constraints_hold(F, TPs, B) ),
              error(not_lowered(_), _), fail)
    ->  K1 = K, TPs1 = TPs, H = h(Fn, B)
    ;   K2 is K + 1, cpp_explicit_candidate(Cs, K2, F, Explicit, K1, TPs1, H) ).
cpp_target_bindings(F, fn(R, Ps, V), NC, K, TPs, H) :-
    cpp_fn_candidates(F, Cands),
    length(Cands, NC), cpp_target_candidate(Cands, 1, F, R, Ps, V, K, TPs, H).
cpp_target_candidate([TPs-Fn|Cs], K, F, R, Ps, V, K1, TPs1, H) :-
    Fn = function(_, _, Ret, _, Ps0, V0, _),
    (   V0 == V, length(Ps0, N), length(Ps, N),
        catch(( cpp_match_target_params(Ps0, Ps, TPs, [], B0), cpp_match_target(Ret, R, TPs, B0, B1), cpp_bind_defaults(TPs, B1, B), cpp_constraints_hold(F, TPs, B) ),
              error(not_lowered(_), _), fail)
    ->  K1 = K, TPs1 = TPs, H = h(Fn, B)
    ;   K2 is K + 1, cpp_target_candidate(Cs, K2, F, R, Ps, V, K1, TPs1, H) ).
cpp_match_target_params([], [], _, B, B).
cpp_match_target_params([P|Ps], [Q|Qs], TPs, B0, B) :- cpp_param_type_of(P, PT), cpp_param_type_of(Q, QT), cpp_match_target(PT, QT, TPs, B0, B1), cpp_match_target_params(Ps, Qs, TPs, B1, B).
cpp_match_target(ref(_, X), QT, TPs, B0, B) :- !, ( QT = ref(_, Y) -> true ; ccl_resolve_type(QT, ref(_, Y)) ), cpp_match(X, Y, TPs, B0, B).      % reference for reference: a target is matched exactly
cpp_match_target(rref(_, X), QT, TPs, B0, B) :- !, ( QT = rref(_, Y) -> true ; ccl_resolve_type(QT, rref(_, Y)) ), cpp_match(X, Y, TPs, B0, B).
cpp_match_target(PT, QT, TPs, B0, B) :- \+ QT = ref(_, _), \+ QT = rref(_, _), cpp_match(PT, QT, TPs, B0, B).
%% THE HOLDING SET IS REMEMBERED PER CALL SHAPE (0.97): the same call of a function template -- the name, its explicit
%% arguments, each argument's expression and TYPE (its value category with it), the class context, and the count of
%% the name's templates, since a header loaded since may add a candidate -- has the same holding candidates, their
%% bindings and their conversions, and `stdtuple' asks `get' 188 times in 33 shapes. An argument the inference cannot
%% type is not a key (the desugaring would type it, differently per place), and that call is checked as before.
cpp_holding_set(F, Explicit, As, Cands, NC, Hs) :-
    (   cpp_call_shape(F, Explicit, As, NC, Key)
    ->  (   nb_current(Key, hs(Hs0, W)) -> Hs = Hs0, nb_setval('$cpp_first_refusal', W), cpp_trace(candidates_remembered(F))
        ;   cpp_holding_candidates(Cands, 1, F, Explicit, As, Hs), nb_getval('$cpp_first_refusal', W), nb_setval(Key, hs(Hs, W)) )
    ;   cpp_holding_candidates(Cands, 1, F, Explicit, As, Hs) ).
cpp_call_shape(F, Explicit, As, NC, Key) :-
    findall(V, ( member(E, Explicit), ( catch(cpp_targ_value(E, V0), _, fail) -> V = V0 ; V = E ) ), EVs), cpp_targs_settled(EVs),   % BY VALUE: `get<__indx>' names a const local whose value is another in every instantiation (stdbind's placeholders)
    findall(A-T, ( member(A, As), ccl_type_of(A, T), T \== unknown ), ATs), length(As, NA), length(ATs, NA),
    ( nb_current('$cpp_class_ctx', Ctx) -> true ; Ctx = none ),
    term_to_atom(k(F, EVs, ATs, NC, Ctx), KA), atom_concat('$cpp_hs:', KA, Key).
cpp_holding_candidates([], _, _, _, _, []).
cpp_holding_candidates([TPs-Fn|Cs], K, F, Explicit, As, Hs) :-
    Fn = function(_, _, Ret, _, Ps, Var, _), nb_setval('$cpp_last_refusal', failed), cpp_conv_enter(Saved),
    (   cpp_candidate_check(( cpp_signature_holds(F, TPs, Ps, Var, Explicit, As, B), cpp_result_holds(Ret, TPs, B, Ps) ), error(not_lowered(W), _), cpp_note_refusal(W), B, ground(As-Explicit))   % SFINAE: a signature that does not hold is no candidate
    ->  cpp_conversions(Conv), cpp_conv_leave(Saved), cpp_trace(candidate(F, K, holds(Conv))), Hs = [h(K, TPs, Fn, B, Conv)|Hs1]
    ;   cpp_conv_leave(Saved), nb_getval('$cpp_last_refusal', W1), cpp_trace(candidate(F, K, refused(W1))), Hs = Hs1 ),
    K1 is K + 1, cpp_holding_candidates(Cs, K1, F, Explicit, As, Hs1).
%% A CANDIDATE'S CHECK RUNS INSIDE `\+ \+' where the call's arguments are ground (0.109): what it makes that lasts --
%% the instances, the facts, the globals -- survives the scope, and its intermediates, the deductions and the
%% substitutions of every candidate tried, are reclaimed (cocolog reclaims on backtracking and by nothing else, the
%% finding). Only the bindings come out, through a global. Measured on libc++'s ranges, where the checks after a
%% remembered candidate set were most of a 7.5 GB heap.
cpp_candidate_check(Goal, Ball, Recovery, B, Ground) :- call(Ground), !,
    \+ \+ ( ( catch(Goal, Ball, Recovery) -> nb_setval('$cpp_cand_out', ok(B)) ; nb_setval('$cpp_cand_out', no) ) ),
    nb_getval('$cpp_cand_out', R), nb_setval('$cpp_cand_out', no), R = ok(B).
cpp_candidate_check(Goal, Ball, Recovery, _, _) :- catch(Goal, Ball, Recovery).
%% THE RESULT TYPE IS PART OF THE SIGNATURE, C++'s immediate context: `typename __sfinae_underlying_type<_Tp>::__promoted_type
%% __convert_to_integral(_Tp)' is NO CANDIDATE for a _Tp that is no enum, since the trait's specialization for a non-enum has
%% no such member -- and libc++ writes the overload that way on purpose. Only a DEPENDENT QUALIFIED NAME is resolved here
%% (`typename X<T>::y'), the one shape written to fail: an auto or a decltype result is deduced later, from the body, and a
%% plain type or a template-id costs an instantiation a refused candidate need not make.
cpp_result_holds(Ret, TPs, B, Ps) :- ( catch(cpp_param_packs(Ps, B, B1), _, fail) -> true ; B1 = B ), cpp_subst(Ret, B1, Ret1), ( cpp_sfinae_result(Ret1), cpp_all_bound(TPs, [Ret1], B) -> cpp_with_params(Ps, B, cpp_type(Ret1, _)) ; true ).   % ... the result substituted under the PARAMETER PACKS' bindings as the parameters are (0.127): `-> decltype((ts + ...))' folded over the pack's elements
%% A TRAILING RETURN TYPE NAMES THE PARAMETERS ([dcl.fct]/2: `auto f(T a) -> decltype(a + 1)'), so they are declared,
%% substituted, while it is resolved -- in the immediate context (the candidate check) and where the member is emitted
%% (cpp_method_ret); a decltype result is part of the SFINAE, as a template-id result is (0.100)
cpp_with_params(Ps, B, Goal) :-
    cpp_param_packs(Ps, B, B1), cpp_subst(Ps, B1, Ps1), ( catch(cpp_plain_params(Ps1, Ps2), _, fail) -> true ; Ps2 = [] ),
    cpp_in_frame(( ( catch(ccl_declare_params(Ps2), _, true) -> true ; true ),
                   ( cpp_class_ctx(C), C \== none, \+ memberchk(param(_, this), Ps2) -> ccl_declare(this, ptr([], base([], [typedef(C)]))) ; true ),   % and `this' in a member's: `decltype(Op()(std::get<Idx>(bound_)...))' names a data member
                   Goal )).   % ... and only where every name in it is BOUND ([temp.deduct]/2: the deduced arguments are substituted): `__invoke_result_t<_Args...>', the result of libc++'s C++23 `std::__invoke', resolved with the pack still free instantiated `__invoke_result_impl<void, _Fn>' on that name, whose `type' no specialization gives
