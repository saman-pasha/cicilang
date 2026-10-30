%% ccl_cpp_namespace.pl -- namespaces: the program's -- two of its namespaces declaring one name, a name of its
%% namespace that a library header declares too, an unnamed namespace, a definition by a name that begins with
%% namespaces, the usings, two namespaces' enums -- and the library's: a header's items loaded, indexed and keyed by
%% their namespace path, the bare uses inside a deeper namespace, the names across the headers' reads. A part of the
%% C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there, in their order.

%% TWO NAMESPACES OF THE PROGRAM'S OWN DECLARING ONE NAME (0.100; 0.88's rule was a header's): the outermost keeps
%% the bare name, a deeper namespace's item is renamed `<innermost named namespace>.<name>' (cpp_qualify_item), the
%% bare uses inside that namespace go to the key (cpp_qualify_body), and a use QUALIFIED by the namespace resolves
%% to it wherever a name is read (cpp_ns_key, through '$cpp_ns_own'). The units are rewritten before anything is
%% registered, and the symbol table is built again from them, since the first build held the two under one name --
%% `R::cpo(3)' and `cpo(3)' had both gone to whichever was noted last. A program's own raw header is part of the program.
cpp_ns_resolve(Units000, Units) :-
    cpp_anon_ns_units(Units000, Units00),      % an unnamed namespace is its unit's own, a using-directive after it (0.192, below)
    cpp_qual_members_in_ns(Units00, Units0),   % a definition by a namespace-qualified name is moved into its namespace first (0.166, below)
    cpp_reset('$cpp_ns_own'/1),
    findall(F, ( member(unit(Is), Units0), cpp_own_flat([], Is, F) ), Fs), append(Fs, Flat0), ccl_flat_quals(Flat0, Flat),   % a qualified declarator's namespace is the item's (ccl_flat_quals)
    findall(S, ( member(in(P0, _), Flat0), P0 \== c, member(S, P0), atom(S) ), NsL0), sort(NsL0, NsL), cpp_reset('$cpp_ns_names'/1), assertz('$cpp_ns_names'(NsL)),
    findall(N-NP, ( member(in(Path, I), Flat), ( catch(once(cpp_index_name(I, N)), _, fail) ; cpp_ns_enum_name(I, N) ), atom(N), cpp_ns_named_path(Path, NP) ), Pairs0),   % an ENUM's tag and an unscoped enum's enumerators are names of the namespace too (0.127)
    sort(Pairs0, Pairs), cpp_ns_quals_(Pairs, Qs0), cpp_anon_quals(Pairs, Qs0, Qs00), cpp_lib_quals(Units0, Pairs, Qs00, Qs),   % ... and a name a library header declares too (0.221, cpp_lib_quals/4)
    cpp_reset('$cpp_dbg_ns'/2), cpp_reset('$cpp_dbg_targs'/2),                                       % -g: the namespaces of the program's own names, a function template instance's arguments (0.130)
    cpp_reset('$cpp_own_ns'/2), forall(( member(N-NP, Pairs), NP \== [] ), assertz('$cpp_own_ns'(N, NP))),   % the namespace of each of the program's own names, where argument-dependent lookup looks (cpp_adl_fn, 0.134)
    cpp_reset('$cpp_own_ns_full'/2), forall(( member(in(FPath, FI), Flat), FPath \== c, memberchk(inline(_), FPath), ( catch(once(cpp_index_name(FI, FN)), _, fail) ; cpp_ns_enum_name(FI, FN) ), atom(FN), cpp_ns_plain(FPath, FP) ),
        ( '$cpp_own_ns_full'(FN, _) -> true ; assertz('$cpp_own_ns_full'(FN, FP)) )),   % ... and its whole path where an inline namespace is in it, which a local name spells (0.236: `ZN2ns2in2nfEvE1L')
    cpp_reset('$cpp_type_ns'/2), forall(( member(N-NP, Pairs), NP \== [], cpp_ns_final_name(N, NP, Qs, K) ), assertz('$cpp_type_ns'(K, NP))),   % ... and by the name it has once a collision is keyed (0.180), which the type information's names read (cpp_prog_scope/2)
    forall(( member(in(UP, declare(_, base(_, [union(UN, UMs)]))), Flat), atom(UN), UMs \== none, cpp_ns_named_path(UP, UNP), UNP \== [] ), assertz('$cpp_type_ns'(UN, UNP))),   % a plain union's too, which no index name names
    ( nb_current('$ccl_debug', file(_)) -> forall(( member(N-NP, Pairs), NP \== [], \+ '$cpp_dbg_ns'(N, _) ), assertz('$cpp_dbg_ns'(N, NP))) ; true ),
    (   Qs == []
    ->  Units = Units0
    ;   ( nb_current('$cpp_trace', yes) -> cpp_trace(ns_collisions(Qs)) ; true ),   % before cpp_register_units has set the trace global
        forall(( member(q(Ns, N, _), Qs), Ns \== bare ), ( atomic_list_concat([Ns, '.', N], K), assertz('$cpp_ns_own'(K)) )),
        cpp_ns_rewrite_units(Units0, Qs, Units),
        ccl_scope_init, forall(member(unit(Is1), Units), ccl_items_note_program(Is1)) ).
cpp_ns_final_name(N, NP, Qs, K) :- ( memberchk(q(Ns, N, NP), Qs), Ns \== bare -> atomic_list_concat([Ns, '.', N], K) ; K = N ).   % a deeper namespace's item of a collided name is `<suffix>.<name>'
%% A NAME OF THE PROGRAM'S NAMESPACE THAT A LIBRARY HEADER DECLARES TOO (0.221; [namespace.qual]/2, [basic.lookup.unqual]):
%% the library keeps the bare name, and each named namespace of the program's that declares it is keyed as a deeper namespace
%% of the program's own is (above), by the shortest suffix of its path that no other path declaring the name ends with, the
%% library's paths among them -- `ns.max', `ns.abs'. Flattened bare, the program's function joined the library's overloads of
%% the name (cpp_fn_ready/1): `std::max(1, 2)' called the program's `ns::max(int, int)' and printed 3 for clang's 2, and
%% `ns::abs(-4)' beside <cstdlib> was `undeclared('abs.int')'. The program's global names and its names in a namespace of the
%% library's (`namespace std { template <> struct hash<K> {...}; }') keep the bare name, as before; an operator's name is no
%% atom here, and operators stay one set, found by their arguments. The headers' ASTs are loaded first, in the include's
%% order, as the registration would (cpp_lib_names_load/1). An unqualified call finds a keyed function through its arguments'
%% classes (cpp_call_adl/4), and a bare use in a namespace nested in the keyed one goes to the key (cpp_lib_outer_body/4)
cpp_lib_quals(Units, Pairs, Qs0, Qs) :-
    cpp_reset('$cpp_ns_libkeyed'/1),
    findall(N, ( member(N-[S|_], Pairs), S \== std ), Ns0), sort(Ns0, Ns1),
    (   Ns1 == [] -> Qs = Qs0
    ;   cpp_lib_names_load(Units),
        findall(N, ( member(N, Ns1), cpp_lib_declares(N) ), Ns),
        (   Ns == [] -> Qs = Qs0
        ;   findall(Q, ( member(Q, Qs0), Q = q(_, QN, _), \+ memberchk(QN, Ns) ), Qs1),
            findall(Q, ( member(N, Ns), cpp_lib_name_quals(N, Pairs, Q) ), Qs2), append(Qs1, Qs2, Qs),
            forall(member(N, Ns), assertz('$cpp_ns_libkeyed'(N))) ) ).
%% each of the program's paths of the name: keyed, or bare where it is global, the library's namespace, or no suffix of it is unique
cpp_lib_name_quals(N, Pairs, Q) :- findall(P, member(N-P, Pairs), PPs), cpp_lib_paths(N, LPs), append(PPs, LPs, All0), sort(All0, All),
    member(P, PPs), ( P = [S|_], S \== std, cpp_ns_unique_suffix(P, All, K) -> Q = q(K, N, P) ; Q = q(bare, N, P) ).
cpp_lib_paths(N, LPs) :- findall(NP, ( catch('$cpp_hdr_ast_ns'(N, P), _, fail), ( P == c -> NP = [] ; cpp_ns_named_path(P, NP) ) ), L0),
    findall(NP, catch('$cpp_ns_libname'(N, NP), _, fail), L1), append(L0, L1, L2), sort(L2, LPs).
cpp_lib_declares(N) :- ( catch('$cpp_hdr_ast_ns'(N, _), _, fail) ; catch('$cpp_ns_libname'(N, _), _, fail) ), !.
%% the names the units' library headers declare: a served or a summarized header's AST loaded, a header flattened in the process
%% and not summarized read for its names ('$cpp_ns_libname')
cpp_lib_names_load(Units) :- cpp_reset('$cpp_ns_libname'/2), forall(member(unit(Is), Units), cpp_lib_names_items(Is)).
cpp_lib_names_items([]).
cpp_lib_names_items([I|Is]) :- cpp_lib_names_item(I), cpp_lib_names_items(Is).
cpp_lib_names_item(include(_, _, file(_, summary, summary(F)))) :- !, cpp_load_ast(F).
cpp_lib_names_item(include(_, _, file(P, preprocessed, unit(Js)))) :- !,
    (   cpp_read_now_summarized(P, F) -> cpp_load_ast(F)
    ;   cpp_own_flat([], Js, Fl), forall(( member(in(Path, I), Fl), catch(once(cpp_index_name(I, N)), _, fail), atom(N), cpp_ns_named_path(Path, NP) ), assertz('$cpp_ns_libname'(N, NP))) ).
cpp_lib_names_item(include(_, _, file(_, raw, unit(Js)))) :- !, cpp_lib_names_items(Js).
cpp_lib_names_item(namespace(_, _, Js)) :- is_list(Js), !, cpp_lib_names_items(Js).
cpp_lib_names_item(_).
%% THE UNIT'S TAG (0.192): a name that is one unit's own -- a closure's (`lambda.K'), a local class's (`N.local_K'), an unnamed
%% namespace's -- carries it, so that two units linked together never share one: a fold of the main file's absolute path, the
%% command line's macros, the configuration and the target, in base 36. The names were the same in every unit and emitted
%% linkonce_odr, so the link kept one unit's `lambda.1' for both, and one unit ran the other's body.
cpp_unit_tag(T) :- ( nb_current('$ccl_src_file', F), atom(F) -> true ; F = '' ),
    (   nb_current('$cpp_utag', tag(F0, T0)), F0 == F -> T = T0
    ;   F == '' -> T = ''
    ;   ( catch(absolute_file_name(F, A), _, fail) -> true ; A = F ), ccl_cmdline_key(CK), ccl_config_key(GK), ccl_target_key(TK),
        atomic_list_concat([A, CK, GK, TK], K), atom_codes(K, Cs), ccl_fold(Cs, 7, 131, S), cpp_tag_digits(S, Ds), atom_codes(T, Ds),
        nb_setval('$cpp_utag', tag(F, T)) ).
cpp_tag_digits(S, [C]) :- S < 36, !, cpp_tag_digit(S, C).
cpp_tag_digits(S, Cs) :- D is S mod 36, S1 is S // 36, cpp_tag_digits(S1, Cs0), cpp_tag_digit(D, C), append(Cs0, [C], Cs).
cpp_tag_digit(D, C) :- ( D < 10 -> C is 48 + D ; C is 87 + D ).
%% AN UNNAMED NAMESPACE IS ITS UNIT'S OWN ([namespace.unnamed]/1: `inline namespace unique {} using namespace unique; namespace
%% unique { body }'; 0.192): it is named `_GLOBAL__N_<tag>' (the unit's tag), a using-directive of it stands after its block, and
%% every name it declares is keyed by its path (cpp_anon_quals/3), so two units' names never meet at the link. It was flattened
%% into its enclosing namespace: two units that each define `namespace { int helper(); }' did not link, two strong definitions.
%% The mangler spells the segment as clang does, `12_GLOBAL__N_1', and such a type's information is internal (ir_rtti_link/2).
cpp_anon_ns_units(Us0, Us) :- \+ ( member(unit(Is), Us0), cpp_anon_ns_in(Is) ), !, Us = Us0.
cpp_anon_ns_units(Us0, Us) :- cpp_unit_tag(T), ( T == '' -> AN = '_GLOBAL__N_1' ; atom_concat('_GLOBAL__N_', T, AN) ),
    findall(unit(Is1), ( member(unit(Is), Us0), cpp_anon_ns_items(Is, AN, Is1) ), Us).
cpp_anon_ns_in(Is) :- member(I, Is), ( I = namespace(_, anon, _) -> true ; I = namespace(_, _, Js) -> cpp_anon_ns_in(Js) ; I = include(_, _, file(_, raw, unit(Js))) -> cpp_anon_ns_in(Js) ), !.
cpp_anon_ns_items([], _, []).
cpp_anon_ns_items([namespace(L, anon, Js)|Is], AN, [namespace(L, AN, Js1), using(L, namespace(AN))|Is1]) :- !, cpp_anon_ns_items(Js, AN, Js1), cpp_anon_ns_items(Is, AN, Is1).
cpp_anon_ns_items([namespace(L, N, Js)|Is], AN, [namespace(L, N, Js1)|Is1]) :- !, cpp_anon_ns_items(Js, AN, Js1), cpp_anon_ns_items(Is, AN, Is1).
cpp_anon_ns_items([include(L, S, file(F, raw, unit(Js)))|Is], AN, [include(L, S, file(F, raw, unit(Js1)))|Is1]) :- !, cpp_anon_ns_items(Js, AN, Js1), cpp_anon_ns_items(Is, AN, Is1).
cpp_anon_ns_items([I|Is], AN, [I|Is1]) :- cpp_anon_ns_items(Is, AN, Is1).
cpp_anon_quals(Pairs, Qs0, Qs) :-
    findall(Q, ( member(Q, Qs0), \+ ( Q = q(bare, _, P), cpp_anon_ns_path(P) ) ), Qs1),
    findall(q(Ns, N, P), ( member(N-P, Pairs), cpp_anon_ns_path(P), \+ ( member(q(X, N, P), Qs1), X \== bare ), atomic_list_concat(P, '.', Ns) ), Qs2),
    append(Qs1, Qs2, Qs).
cpp_anon_ns_path(P) :- member(S, P), cpp_anon_seg(S), !.
cpp_anon_seg(S) :- atom(S), sub_atom(S, 0, 11, _, '_GLOBAL__N_').
%% A DEFINITION BY A NAME THAT BEGINS WITH NAMESPACES (0.166; [namespace.memdef]/2, [class.mfct]/2): `int n::f() {...}',
%% `int n::g = 5;', `int n::C::m() const {...}', `n::C::C() : v(4) {}', `n::C::~C() {}', `int n::C::count = 3;' written
%% outside namespace n are members of n (and of its class C), their names looked up in n. Each such item is moved into a
%% block of its namespaces, the qualifier's namespace segments taken off (`namespace n { int C::m() const {...} }'), so
%% that the namespaces' paths, the index, the keys and the desugaring take it as the definition it is. The qualifier was
%% taken whole: a function or a variable reached the lowering as `member_of_class(scoped([n], f))', and a member's
%% definition was noted under its class's name at file scope beside n's class, the two collided, n's class was keyed
%% `n.C' and the definitions named a class nothing defined. A class's or a variable template's specialization keeps its
%% road (qualspec.cpp, ccl_flat_quals); a segment is a namespace where the program's units open one of that name.
cpp_qual_members_in_ns(Units0, Units) :-
    findall(S, ( member(unit(Is), Units0), cpp_own_flat([], Is, F), member(in(P, _), F), P \== c, member(S, P), ( atom(S) ; S = inline(_) ) ), Ns0), sort(Ns0, Ns),
    ( Ns == [] -> Units = Units0 ; findall(unit(Is1), ( member(unit(Is), Units0), cpp_qual_items(Is, Ns, Is1) ), Units) ).
cpp_qual_items([], _, []).
cpp_qual_items([namespace(L, N, Js)|Is], Ns, [namespace(L, N, Js1)|Is1]) :- !, cpp_qual_items(Js, Ns, Js1), cpp_qual_items(Is, Ns, Is1).
cpp_qual_items([include(L, S, file(F, raw, unit(Js)))|Is], Ns, [include(L, S, file(F, raw, unit(Js1)))|Is1]) :- !, cpp_qual_items(Js, Ns, Js1), cpp_qual_items(Is, Ns, Is1).
cpp_qual_items([I|Is], Ns, [I1|Is1]) :- ( cpp_qual_item(I, Ns, Pre, I0), Pre \== [], arg(1, I, L), integer(L) -> cpp_ns_wrap(Pre, L, I0, I1) ; I1 = I ), cpp_qual_items(Is, Ns, Is1).
cpp_qual_item(template(L, TPs, I), Ns, Pre, template(L, TPs, I1)) :- !, cpp_qual_item(I, Ns, Pre, I1), I1 \= declaration(_, _, _, _).
cpp_qual_item(function(L, Sto, Ret, scoped(Q, M), Ps, V, B), Ns, Pre, function(L, Sto, Ret, M1, Ps, V, B)) :- !, cpp_ns_split(Q, Ns, Pre, Rest), ( Rest == [] -> M1 = M ; M1 = scoped(Rest, M) ).
cpp_qual_item(declaration(L, Sto, T, [var(scoped(Q, N), VT, I)]), Ns, Pre, declaration(L, Sto, T, [var(N1, VT, I)])) :- !, atom(N), cpp_ns_split(Q, Ns, Pre, Rest), ( Rest == [] -> N1 = N ; N1 = scoped(Rest, N) ).
cpp_qual_item(ctor_def(L, scoped(Q, C), Qs, Ps, In, B), Ns, Pre, ctor_def(L, C1, Qs, Ps, In, B)) :- !, cpp_ns_split(Q, Ns, Pre, Rest), ( Rest == [] -> C1 = C ; C1 = scoped(Rest, C) ).
cpp_qual_item(dtor_def(L, scoped(Q, C), Qs, B), Ns, Pre, dtor_def(L, C1, Qs, B)) :- cpp_ns_split(Q, Ns, Pre, Rest), ( Rest == [] -> C1 = C ; C1 = scoped(Rest, C) ).
%% the leading segments that name the program's namespaces, each as its namespace was opened (`inline(N)' for an inline one)
cpp_ns_split([S|Ss], Ns, [G|Pre], Rest) :- atom(S), ( memberchk(S, Ns) -> G = S ; memberchk(inline(S), Ns) -> G = inline(S) ), !, cpp_ns_split(Ss, Ns, Pre, Rest).
cpp_ns_split(Rest, _, [], Rest).
cpp_ns_wrap([], _, I, I).
cpp_ns_wrap([G|Gs], L, I, namespace(L, G, [I1])) :- cpp_ns_wrap(Gs, L, I, I1).
cpp_own_flat(_, [], []).
cpp_own_flat(P, [include(_, _, file(_, raw, unit(Js)))|Is], Flat) :- !, cpp_own_flat(P, Js, F1), cpp_own_flat(P, Is, F2), append(F1, F2, Flat).
cpp_own_flat(P, [namespace(_, N, Js)|Is], Flat) :- !, cpp_ns_path(P, N, P1), cpp_own_flat(P1, Js, F1), cpp_own_flat(P, Is, F2), append(F1, F2, Flat).
cpp_own_flat(P, [extern_c(_, _)|Is], Flat) :- !, cpp_own_flat(P, Is, Flat).
cpp_own_flat(P, [I|Is], [in(P, I)|Flat]) :- cpp_own_flat(P, Is, Flat).
cpp_ns_path(P, N, P1) :- ( atom(N), N \== anon -> append(P, [N], P1) ; N = inline(_) -> append(P, [N], P1) ; P1 = P ).
cpp_ns_item_path(P, I, PI) :- ( '$cpp_ns_names'(Ns) -> ccl_item_ns_path(P, I, Ns, PI) ; PI = P ).
cpp_ns_rewrite_units([], _, []).
cpp_ns_rewrite_units([unit(Is)|Us], Qs, [unit(Is1)|Us1]) :- cpp_ns_rewrite_items(Is, [], Qs, Is1), cpp_ns_rewrite_units(Us, Qs, Us1).
cpp_ns_rewrite_items([], _, _, []).
cpp_ns_rewrite_items([namespace(L, N, Js)|Is], P, Qs, [namespace(L, N, Js1)|Is1]) :- !, cpp_ns_path(P, N, P1), cpp_ns_rewrite_items(Js, P1, Qs, Js1), cpp_ns_rewrite_items(Is, P, Qs, Is1).
cpp_ns_rewrite_items([include(L, S, file(F, raw, unit(Js)))|Is], P, Qs, [include(L, S, file(F, raw, unit(Js1)))|Is1]) :- !, cpp_ns_rewrite_items(Js, P, Qs, Js1), cpp_ns_rewrite_items(Is, P, Qs, Is1).
cpp_ns_rewrite_items([using(L, U)|Is], P, Qs, [using(L, U)|Is1]) :- cpp_ns_named_path(P, NP), cpp_using_map(U, NP, Qs, Map), Map \== [], !,
    cpp_rename_names(Is, Map, Is0), cpp_ns_rewrite_items(Is0, P, Qs, Is1).   % a using-declaration or -directive at file or namespace scope: the items after it (0.139)
cpp_ns_rewrite_items([I|Is], P, Qs, [I3|Is1]) :-
    (   catch(once(cpp_index_name(I, N)), _, fail), cpp_ns_item_path(P, I, PI), cpp_index_key(Qs, PI, N, K), K \== N, cpp_qualify_item(N, K, I, I1) -> true
    ;   cpp_ns_enum_name(I, _), cpp_ns_item_path(P, I, PI), cpp_qualify_enum(Qs, PI, I, I1) -> true
    ;   I1 = I ),
    cpp_qualify_body(Qs, P, I1, I20), cpp_lib_outer_body(Qs, P, I20, I2),
    ( cpp_ns_named_path(P, NP0) -> cpp_using_blocks(I2, NP0, Qs, I3) ; I3 = I2 ),   % ... and in a block, the statements after it (0.139)
    cpp_ns_rewrite_items(Is, P, Qs, Is1).
%% A BARE USE OF A KEYED NAME IN A NAMESPACE NESTED IN ONE THAT DECLARES IT (0.221; [basic.lookup.unqual]/4, cpp_lib_quals/4):
%% C++'s search goes from the use's namespace out, and the innermost enclosing namespace that declares the name is the one found
%% -- `max(a, b)' inside `ns::detail' is `ns::max', which was the library's bare one. Since 0.233 a name two of the program's
%% namespaces declare too: `helper(5)' inside `b::c' is `b::helper', which was the global one, keeping the bare name. A name
%% declared in the use's own namespace is cpp_qualify_body/4's
cpp_lib_outer_body(Qs, P, I, I1) :- cpp_ns_named_path(P, NP), NP \== [], findall(N-K, cpp_lib_outer_key(Qs, NP, N, K), Map0), sort(Map0, Map), Map \== [], !, cpp_rename_names(I, Map, I1).
cpp_lib_outer_body(_, _, I, I).
cpp_lib_outer_key(Qs, NP, N, K) :- member(q(_, N, _), Qs), \+ memberchk(q(_, N, NP), Qs),
    findall(L-Ns, ( member(q(Ns, N, P0), Qs), P0 \== NP, append(P0, _, NP), length(P0, L) ), LNs), LNs \== [],
    msort(LNs, S), last(S, _-Ns), Ns \== bare, atomic_list_concat([Ns, '.', N], K).
%% A USING-DECLARATION OR A USING-DIRECTIVE OVER COLLIDED NAMES (0.139; [namespace.udecl], [namespace.udir]): two namespaces of
%% the program declare one name, the outermost keeps it bare and the other's is keyed `<ns>.<name>' (above), so a bare use is the
%% bare one's. `using b::f;' and `using namespace b;' make b's names the ones a bare use finds in the rest of their scope: the
%% names they bring that were keyed are renamed to their keys in the items or statements that follow (cpp_using_map/4: the
%% declaration's or the directive's namespace found from the scope's own outwards, as a qualified name is, cpp_abs_ns_path).
%% `using b::f; ... f()' called a::f, and `using namespace b; S s; g(2)' was a's S and a's g, silent wrong answers.
cpp_using_map(name(scoped(Path, N)), NP, Qs, [N-K]) :- atom(N), cpp_abs_ns_path(Path, N, NP, Qs, Cand), memberchk(q(Ns, N, Cand), Qs), Ns \== bare, !, atomic_list_concat([Ns, '.', N], K).
cpp_using_map(namespace(Q), NP, Qs, Map) :- cpp_using_ns_segs(Q, Segs), Segs \== [],
    (   Segs = [global|Abs] -> Cand = Abs
    ;   length(NP, Len), between(0, Len, J), K0 is Len - J, length(Pre, K0), append(Pre, _, NP), append(Pre, Segs, Cand), memberchk(q(_, _, Cand), Qs) -> true ),
    findall(N-K, ( member(q(Ns, N, Cand), Qs), Ns \== bare, atomic_list_concat([Ns, '.', N], K) ), Map), !.
cpp_using_map(_, _, _, []).
cpp_using_ns_segs(Q, [Q]) :- atom(Q), !.
cpp_using_ns_segs(scoped(P, X), Segs) :- atom(X), is_list(P), forall(member(S, P), atom(S)), append(P, [X], Segs).
cpp_using_blocks(T, _, _, T) :- \+ compound(T), !.
cpp_using_blocks(block(Ss), NP, Qs, block(Ss1)) :- is_list(Ss), !, cpp_using_stmts(Ss, NP, Qs, Ss1).
cpp_using_blocks(T, NP, Qs, T1) :- T =.. [F|As], cpp_using_blocks_l(As, NP, Qs, As1), T1 =.. [F|As1].
cpp_using_blocks_l([], _, _, []).
cpp_using_blocks_l([A|As], NP, Qs, [A1|As1]) :- cpp_using_blocks(A, NP, Qs, A1), cpp_using_blocks_l(As, NP, Qs, As1).
cpp_using_stmts([], _, _, []).
cpp_using_stmts([S|Ss], NP, Qs, [S1|Ss1]) :-
    ( S = using(_, U), cpp_using_map(U, NP, Qs, Map), Map \== [] -> cpp_rename_names(Ss, Map, Ss0) ; Ss0 = Ss ),
    cpp_using_blocks(S, NP, Qs, S1), cpp_using_stmts(Ss0, NP, Qs, Ss1).
%% TWO NAMESPACES' ENUMS OF ONE NAME, OR OF ONE ENUMERATOR NAME (0.127): `namespace n1 { enum { x = 7 }; }' beside `namespace n2 { enum { x = 8 }; }'
%% read n1's 7 inside n2 and through `n2::x', and two enums `Mode' were one tag. The tag and an unscoped enum's enumerators are keyed and renamed as a
%% function's or a class's name is (the uses inside the namespace by cpp_qualify_body, a qualified one by cpp_ns_key)
cpp_ns_enum_name(declare(_, base(_, [E])), N) :- compound(E), ( E = enum(Tag, Es) ; E = enum_class(Tag, Es) ), is_list(Es),
    ( atom(Tag), Tag \== anon, N = Tag ; E = enum(_, _), member(enumerator(N, _), Es), atom(N) ).
cpp_qualify_enum(Qs, PI, declare(L, base(Q, [E0])), declare(L, base(Q, [E]))) :-
    E0 =.. [F, Tag0, Es0], ( atom(Tag0), Tag0 \== anon, cpp_index_key(Qs, PI, Tag0, Tag1) -> true ; Tag1 = Tag0 ),
    ( F == enum -> findall(X, ( member(X0, Es0), cpp_qualify_enumerator(Qs, PI, X0, X) ), Es) ; Es = Es0 ),
    E =.. [F, Tag1, Es], E \== E0.
cpp_qualify_enumerator(Qs, PI, enumerator(N, Ex), enumerator(K, Ex)) :- !, cpp_index_key(Qs, PI, N, K).
cpp_qualify_enumerator(_, _, X, X).
cpp_load_ast(F) :- ccl_ast_file(F, A), ( exists_file(A) -> ensure_loaded(A), cpp_ast_gen_next ; true ).
%% each load counted (0.219): the cross-read names' memos hold for the ASTs loaded when they were made (cpp_cross_table/1)
cpp_ast_gen_next :- ( nb_current('$cpp_ast_gen', G0), integer(G0) -> true ; G0 = 0 ), G is G0 + 1, nb_setval('$cpp_ast_gen', G).
cpp_hdr_item(N, I) :- '$cpp_hdr'(N, I).
cpp_hdr_item(N, I) :- '$cpp_hdr_ast'(N, I0), ccl_float_thaw(I0, I).   % a float kept exactly in the file (0.132; ccl_float_freeze/2)
%% '$cpp_hdr'(Name, Item): facts (found by name in microseconds; a global would copy the header at every read)
cpp_index_header(Js) :- ccl_flat_items([], Js, Flat), cpp_ns_quals(Flat, Qs), cpp_index_flat(Flat, Qs).
%% TWO NAMESPACES OF ONE FLATTENED NAME (0.32's open item, met at last): <functional> declares
%% `std::__maybe_derive_from_unary_function<_Tp, bool>' -- what __weak_result_type derives from, named
%% unqualified -- and `std::__function::__maybe_derive_from_unary_function<_Fp>' -- what std::function derives
%% from, written `__function::...' -- and flattened to one bare name the first won both, so function<int(int)>
%% took the two-parameter one, whose defaulted second argument asks a detection this compiler cannot answer.
%% THE OUTERMOST NAMESPACE KEEPS THE BARE NAME (an unqualified use from there is what C++ finds); every deeper
%% namespace's items are indexed under `<innermost namespace>.<name>', and a use QUALIFIED by that namespace
%% resolves to it (cpp_ns_key, in cpp_type). The decision is a function of the header's own items, so the index
%% and the AST beside the summary reach it alike without either telling the other. NOT DONE: an UNQUALIFIED use
%% from inside the deeper namespace still finds the outer name (libc++ qualifies every one of them).
cpp_ns_quals(Flat, Qs) :-
    findall(N-NP, ( member(in(Path, I), Flat), Path \== c, catch(once(cpp_index_name(I, N)), _, fail), atom(N), cpp_ns_named_path(Path, NP) ), Pairs0),   % by the NAMED path: `namespace std' and `namespace std { inline namespace __1' are one namespace (0.100), and libc++ declares `begin' in both
    sort(Pairs0, Pairs1),                                       % one entry per name and path, grouped by name, the outermost path first
    findall(q(rel_ops, N, NP), ( member(N-NP, Pairs1), cpp_relops_path(NP) ), RQs),   % std::rel_ops's names are ALWAYS keyed apart, `rel_ops.<name>' (0.136): found only through a using-directive, never bare
    findall(N-NP, ( member(N-NP, Pairs1), \+ cpp_relops_path(NP) ), Pairs),
    cpp_ns_quals_(Pairs, Qs0), append(RQs, Qs0, Qs1), cpp_ns_typedef_quals(Flat, Pairs1, Qs1, TQs), append(Qs1, TQs, Qs).
%% A NAMESPACE-SCOPE TYPEDEF THAT TWO NAMESPACES DECLARE IS KEYED APART TOO (0.201), the outermost keeping the bare name, as an
%% item's is -- only among such typedefs, for a name that no indexed item has, so no other item's key moves, and only where the two
%% name DIFFERENT types, each definition read in its own namespace (its colliding names gone to their keys, cpp_qualify_body/4): std's
%% `typedef basic_string<char> string;' and pmr's `using string = basic_string<char>;' were one name in the flat typedef table,
%% `basic_string' bare inside pmr was std's class template, and `std::pmr::string s("hello", &mr);' found no constructor of std::string.
%% The deeper one is indexed under its key (cpp_keyed_typedef_item/5), its bare uses in its namespace go to it, and `std::pmr::string'
%% resolves through cpp_ns_key/3 (cpp_hdr_keyed_typedef/2). An alias of the name itself, and two spellings of one builtin type, are
%% the same type and keep one name (cpp_typedefs_differ/2): libc++ 21's std writes `using size_t = decltype(sizeof(int));', the global
%% `size_t' is `unsigned long', and keyed apart, `std.size_t' was a name of its own in every body of std.
cpp_ns_typedef_quals(Flat, Pairs, Qs1, TQs) :-
    findall(N-NP-T, ( member(in(Path, typedef(_, Vs)), Flat), Path \== c, Vs = [var(N, T0, _)], atom(N), \+ memberchk(N-_, Pairs), cpp_ns_named_path(Path, NP),
                      ( catch(cpp_qualify_body(Qs1, Path, T0, TQ), _, fail) -> T = TQ ; T = T0 ) ), Ts),
    findall(N-NP, ( member(N-NP-_, Ts), cpp_typedefs_differ(N, Ts) ), Ks0), sort(Ks0, Ks), cpp_ns_quals_(Ks, TQs).
cpp_typedefs_differ(N, Ts) :- member(N-_-A, Ts), \+ cpp_names_itself(N, A), member(N-_-B, Ts), \+ cpp_names_itself(N, B), A \== B,
    cpp_typedef_type(A, TA), cpp_typedef_type(B, TB), TA \== TB, !.
cpp_names_itself(N, base(_, [typedef(X)])) :- ( X == N -> true ; X = scoped(_, Y), Y == N ).
%% TWO SPELLINGS OF ONE BUILTIN TYPE ARE ONE TYPEDEF (0.201): libc++ 21 writes `using size_t = decltype(sizeof(int));' and `using
%% ptrdiff_t = decltype(static_cast<int *>(nullptr) - static_cast<int *>(nullptr));' in std, where the global ones are `unsigned long'
%% and `long': keyed apart, std's bodies named `std.size_t', and `size_t(1)' in __next_hash_pow2 was undeclared (std::unordered_map
%% over libc++ 21). A decltype is its operand's type where that is a builtin one, and an integer type its one spelling.
cpp_typedef_type(base(Q, [decltype(E)]), base(Q, S)) :- catch(once(ccl_type_of(E, base([], S0))), _, fail), is_list(S0), S0 \== [],
    forall(member(W, S0), atom(W)), cpp_canon_specs(S0, S), !.
cpp_typedef_type(base(Q, S0), base(Q, S)) :- is_list(S0), S0 \== [], forall(member(W, S0), atom(W)), cpp_canon_specs(S0, S), !.
cpp_typedef_type(T, T).
%% STD::REL_OPS (0.136): its names are found only through a using-directive ([namespace.udir]) or a using-declaration of one
%% of them, so its items are indexed under `rel_ops.<name>' whatever else declares the name -- flattened bare, its `template
%% <class T> bool operator!=(const T &, const T &)' took every class (filter_view's iterator in a range-for), which is why
%% 0.112 left it out of the index
cpp_relops_path(NP) :- append(_, [rel_ops], NP), !.
cpp_ns_quals_([], []).
cpp_ns_quals_([N-P0|Ps], Qs) :- cpp_ns_run(Ps, N, Rest, Later),
    (   Later == [] -> Qs1 = []
    ;   findall(q(Ns, N, P), ( member(P, Later), cpp_ns_unique_suffix(P, [P0|Later], Ns) ), Qs0), Qs1 = [q(bare, N, P0)|Qs0] ),
    cpp_ns_quals_(Rest, Qs2), append(Qs1, Qs2, Qs).
%% A COLLIDED NAME IS KEYED BY THE SHORTEST SUFFIX OF ITS NAMESPACE PATH THAT NO OTHER PATH DECLARING IT ENDS WITH
%% (0.112; 0.88's key was the innermost namespace alone): libc++ has `ranges::__transform::__fn' (the algorithm) and
%% `ranges::views::__transform::__fn' (the view), both `__transform.__fn' -- `v | views::transform(f)' met the
%% algorithm's operator() (arity_mismatch) and `views::reverse' the algorithm's class (no_operator('|')); they are
%% `ranges.__transform.__fn' and `views.__transform.__fn' now. Where the innermost namespace is unique, as it mostly
%% is, the key is what it was. Every declaring path is listed, the outermost as `bare' (it keeps the bare name).
cpp_ns_unique_suffix(P, All, Ns) :- length(P, Len), between(1, Len, K), cpp_last_n(P, K, S), \+ ( member(P2, All), P2 \== P, cpp_last_n(P2, K, S) ), !, atomic_list_concat(S, '.', Ns).
cpp_last_n(L, K, S) :- length(L, Len), ( Len =< K -> S = L ; D is Len - K, length(Pre, D), append(Pre, S, L) ).
cpp_ns_run([N-P|Ps], N, Rest, [P|Later]) :- !, cpp_ns_run(Ps, N, Rest, Later).
cpp_ns_run(Ps, _, Ps, []).
cpp_index_flat([], _).
cpp_index_flat([in(Path, I)|Fs], Qs) :-
    (   cpp_index_name(I, N)
    ->  cpp_index_key(Qs, Path, N, Key0),
        (   Key0 == N -> Key = N, I0 = I
        ;   cpp_qualify_item(N, Key0, I, Iq) -> Key = Key0, I0 = Iq
        ;   Key = N, I0 = I ),                                  % an item whose name cannot be rewritten keeps the bare one
        cpp_qualify_body(Qs, Path, I0, I1),                     % 0.88's not-done: an UNQUALIFIED use inside the deeper namespace finds its own (0.100)
        assertz('$cpp_hdr'(Key, I1)), cpp_note_hdr_ns(Key, Path)
    ;   cpp_enum_ns_name(I, EN) -> cpp_note_hdr_ns(EN, Path)
    ;   cpp_keyed_typedef_item(Qs, Path, I, Key, I1) -> assertz('$cpp_hdr'(Key, I1)), cpp_note_hdr_ns(Key, Path)   % a keyed namespace-scope typedef (0.201, cpp_ns_typedef_quals/3)
    ;   cpp_fwd_class_item(I, FN) -> cpp_note_hdr_ns(FN, Path)   % a class DECLARED, its namespace path alone (0.201, cpp_fwd_class_item/2)
    ;   true ),
    cpp_index_flat(Fs, Qs).
%% A CLASS A HEADER DECLARES AND NEVER DEFINES KEEPS ITS NAMESPACE PATH (0.201), as an enum does: it is a type, never a template's free name
%% (cpp_raw_type/1, cpp_declared_class/1), and a shipped function over a pointer to it is mangled with its namespace. libc++'s <barrier>
%% holds `unique_ptr<__barrier_algorithm_base, void (*)(__barrier_algorithm_base *)>' over `class __barrier_algorithm_base;', which the
%% compiled library defines: taken for a free name, the pointer deduced nothing for the compressed pair's constructor template, and
%% `std::barrier' was refused `member_not_constructed'.
cpp_fwd_class_item(declare(_, base(_, [S])), N) :- ( S = class(N, none) ; S = struct(N, none) ; S = union(N, none) ), atom(N), N \== anon, !.
%% a namespace-scope typedef keyed apart (cpp_ns_typedef_quals/3): its declarator named by its key, its body's bare uses
%% of its namespace's colliding names gone to their keys -- pmr's `basic_string<char>' is pmr's alias template
cpp_keyed_typedef_item(Qs, Path, typedef(L, [var(N, T, E)]), Key, I1) :- atom(N), cpp_index_key(Qs, Path, N, Key), Key \== N, cpp_qualify_body(Qs, Path, typedef(L, [var(Key, T, E)]), I1).
%% A HEADER'S ENUM KEEPS ITS NAMESPACE PATH TOO, without being an item to load (0.112): a function the shipped library
%% defines is called by its Itanium name, and an enum among its parameters is a nested name there --
%% `to_chars(char *, char *, double, chars_format)' is `_ZNSt3__18to_charsEPcS0_dNS_12chars_formatE' -- where the
%% mangler took it for a program's global enum (`12chars_format', cpp_ita_type_) and the link named six to_chars
cpp_enum_ns_name(declare(_, base(_, [E])), N) :- ( E = enum(N, Es) ; E = enum_class(N, Es) ), atom(N), N \== anon, Es \== none, !.
cpp_index_key(Qs, Path, N, Key) :- cpp_ns_named_path(Path, NP), memberchk(q(Ns, N, NP), Qs), Ns \== bare, !, atomic_list_concat([Ns, '.', N], Key).   % by the item's WHOLE named path
cpp_index_key(_, _, N, N).
%% the NAMED segments of a path: an inline namespace (`inline(N)', the reader's mark) is skipped, so libc++'s
%% `std::ranges::__cpo::iter_move' keys as `ranges.iter_move' and `ranges::iter_move' finds it
cpp_ns_named_path(Path, NP) :- Path \== c, findall(S, ( member(S, Path), atom(S) ), NP).
%% THE BARE USES INSIDE A DEEPER NAMESPACE GO TO THE KEY: `id(N)', `typedef(N)', `tmpl(N, As)' of a colliding name in
%% that namespace's items -- unless the item declares a parameter, a local, a member or a capture of the name, which
%% shadows it there (then that item's `id's are left alone; its types are still rewritten). A CLASS DECLARES ITS MEMBERS'
%% NAMES, a function its parameters' and its locals' (0.182): the search for a class's own stops at each method,
%% function, constructor, destructor and lambda, which shadow only inside themselves. libc++ 22's
%% `__adjacent_transform::__fn' has an `operator()(_Range &&, _Fn &&__fn)', the search went through that member's
%% parameters (an operator's name is no atom, and the method rule takes an atom), and the class's base
%% `__range_adaptor_closure<__fn<_Np>>' kept the bare `__fn', another namespace's: `template_without_body('__fn')' for
%% every `views::adjacent_transform'. A method named by an atom counts its own parameters inside it now too.
cpp_qualify_body(Qs, Path, I, I2) :- Qs \== [], cpp_ns_named_path(Path, NP), !,
    findall(N-K, ( member(q(Ns, N, NP), Qs), Ns \== bare, atomic_list_concat([Ns, '.', N], K) ), Map),
    ( Map == [] -> I1 = I ; cpp_rename_names(I, Map, I1) ),
    cpp_qualify_paths(I1, NP, Qs, I2).
cpp_qualify_body(_, _, I, I).
%% ... AND A NAME QUALIFIED RELATIVE TO THE ITEM'S NAMESPACE IS MADE ABSOLUTE (0.112), where the item's own namespace
%% is known: `__transform::__fn{}' written inside `namespace views' is `std::ranges::views::__transform::__fn', found by
%% C++'s rule, the enclosing namespaces searched from the innermost out ([namespace.qual]) -- the first that declares
%% the name wins, the outermost (bare) one included. cpp_ns_key then finds the key by the path's suffixes, longest
%% first. Only a collided name is looked at; anything else keeps the qualifier as written.
cpp_qualify_paths(T, _, _, T) :- \+ compound(T), !.
cpp_qualify_paths(scoped(P, X), NP, Qs, scoped(P1, X1)) :- !, cpp_qualify_paths(X, NP, Qs, X1),
    ( cpp_scoped_last(X, N), cpp_abs_ns_path(P, N, NP, Qs, P2) -> P1 = P2 ; P1 = P ).
cpp_qualify_paths(T, NP, Qs, T2) :- T =.. [F|As], cpp_qualify_paths_l(As, NP, Qs, As1), T2 =.. [F|As1].
cpp_qualify_paths_l([], _, _, []).
cpp_qualify_paths_l([A|As], NP, Qs, [A1|As1]) :- cpp_qualify_paths(A, NP, Qs, A1), cpp_qualify_paths_l(As, NP, Qs, As1).
cpp_scoped_last(N, N) :- atom(N), !.
cpp_scoped_last(tmpl(N, _), N) :- atom(N).
cpp_abs_ns_path([global|P], N, _, Qs, Cand) :- !, forall(member(S, P), atom(S)), ( P \== [], memberchk(q(_, N, P), Qs) -> Cand = P ; cpp_anon_in(P, N, Qs, Cand) ).
cpp_abs_ns_path(P, N, NP, Qs, Cand) :- P \== [], forall(member(S, P), atom(S)), memberchk(q(_, N, _), Qs),
    length(NP, Len), between(0, Len, J), K is Len - J, length(Pre, K), append(Pre, _, NP), append(Pre, P, Cand0),
    ( memberchk(q(_, N, Cand0), Qs) -> Cand = Cand0 ; cpp_anon_in(Cand0, N, Qs, Cand) ), !.
%% ... and a namespace's UNNAMED namespace where the namespace itself declares no such name ([namespace.qual]/2: the members of
%% the namespaces its using-directives nominate, the unnamed one's implicit directive among them; 0.192): `n::deep()' and `::helper()'
cpp_anon_in(P, N, Qs, Cand) :- member(q(_, N, Cand), Qs), append(P, [S], Cand), cpp_anon_seg(S), !.
cpp_rename_names(T, _, T) :- \+ compound(T), !.
cpp_rename_names(scoped([S0|P], X), Map, scoped([S|P], X)) :- cpp_rename_qualifier(S0, Map, S), !.   % THE FIRST SEGMENT of a qualified name is looked up in the item's own scope ([basic.lookup.qual]/1): `__base::__visit_alt(...)' inside `namespace visitation' is visitation's class
cpp_rename_names(scoped(P, X), Map, scoped(P1, X1)) :- memberchk('$deep'-yes, Map), !, cpp_rename_path(P, Map, P1), cpp_rename_last(X, Map, X1).   % a LOCAL CLASS's name (0.121) is renamed in the template arguments of a qualified name too: `std::vector<P>' (cpp_stmts)
cpp_rename_names(scoped(P, X), _, scoped(P, X)) :- !.                                    % the rest of a qualified name is resolved where it is read (cpp_ns_key), never rewritten here
cpp_rename_names(id(N), Map, id(K)) :- atom(N), memberchk(N-K, Map), !.
cpp_rename_names(typedef(N), Map, typedef(K)) :- atom(N), memberchk(N-K, Map), !.
cpp_rename_names(tmpl(N, As), Map, tmpl(K, As1)) :- atom(N), memberchk(N-K, Map), !, cpp_rename_names(As, Map, As1).
cpp_rename_names(base(Acc, N), Map, base(Acc, K)) :- cpp_base_access(Acc), atom(N), memberchk(N-K, Map), !.            % a BASE CLAUSE naming the colliding name (0.101): `struct D : Base' inside the deeper namespace is that namespace's Base
cpp_rename_names(base(Acc, virtual(N)), Map, base(Acc, virtual(K))) :- cpp_base_access(Acc), atom(N), memberchk(N-K, Map), !.
cpp_rename_names(struct(N, none), Map, struct(K, none)) :- atom(N), memberchk('$deep'-yes, Map), memberchk(N-K, Map), !.   % a LOCAL struct or union named by its ELABORATED specifier, `struct P p' and `sizeof(union U)' (0.201)
cpp_rename_names(union(N, none), Map, union(K, none)) :- atom(N), memberchk('$deep'-yes, Map), memberchk(N-K, Map), !.
cpp_rename_names(T, Map, T2) :- functor(T, F, _), memberchk(F, [function, method, ctor, ctor_def, dtor_def, lambda, class, struct]), !,
    T =.. [F|As], cpp_declared_list(As, [], Ds), ( Ds == [] -> Map1 = Map ; findall(N-K, ( member(N-K, Map), \+ memberchk(N, Ds) ), Map1) ),
    ( Map1 == [] -> T2 = T ; cpp_rename_list(As, Map1, As1), T2 =.. [F|As1] ).
cpp_rename_names(T, Map, T2) :- T =.. [F|As], cpp_rename_list(As, Map, As1), T2 =.. [F|As1].
cpp_rename_qualifier(N, Map, K) :- atom(N), memberchk(N-K, Map).
cpp_rename_qualifier(tmpl(N, As), Map, tmpl(K, As1)) :- atom(N), memberchk(N-K, Map), cpp_rename_names(As, Map, As1).
cpp_rename_list([], _, []).
cpp_rename_list([A|As], Map, [A1|As1]) :- cpp_rename_names(A, Map, A1), cpp_rename_list(As, Map, As1).
cpp_rename_path([], _, []).
cpp_rename_path([S|Ss], Map, [S1|Ss1]) :- cpp_rename_last(S, Map, S1), cpp_rename_path(Ss, Map, Ss1).
cpp_rename_last(tmpl(N, As), Map, tmpl(N, As1)) :- !, cpp_rename_names(As, Map, As1).
cpp_rename_last(X, _, X).
cpp_declared_names(T, Ds, Ds) :- \+ compound(T), !.
cpp_declared_names(param(_, N), Ds, [N|Ds]) :- atom(N), !.
cpp_declared_names(param(_, N, _), Ds, [N|Ds]) :- atom(N), !.
cpp_declared_names(var(N, _, _), Ds, [N|Ds]) :- atom(N), !.
cpp_declared_names(member(_, N, _), Ds, [N|Ds]) :- atom(N), !.
cpp_declared_names(method(_, _, _, N, _, _, _), Ds, Ds1) :- !, ( atom(N) -> Ds1 = [N|Ds] ; Ds1 = Ds ).   % a class's own method of the name shadows the namespace's: vector's `begin()' beside std::begin
cpp_declared_names(function(_, _, _, N, _, _, _), Ds, Ds1) :- !, ( atom(N) -> Ds1 = [N|Ds] ; Ds1 = Ds ).
cpp_declared_names(T, Ds, Ds) :- functor(T, F, _), memberchk(F, [ctor, dtor, ctor_def, dtor_def, lambda]), !.   % (above) their names shadow inside them only
cpp_declared_names(typedef(_, Vs), Ds0, Ds) :- !, findall(N, member(var(N, _, _), Vs), Ns), append(Ns, Ds0, Ds).
cpp_declared_names(cap(_, N), Ds, [N|Ds]) :- atom(N), !.
cpp_declared_names(T, Ds0, Ds) :- T =.. [_|As], cpp_declared_list(As, Ds0, Ds).
cpp_declared_list([], Ds, Ds).
cpp_declared_list([A|As], Ds0, Ds) :- cpp_declared_names(A, Ds0, Ds1), cpp_declared_list(As, Ds1, Ds).
%% the name inside the item is rewritten with the key, so the class registers, specializes and instantiates under it
cpp_qualify_item(N, K, template(L, TPs, I0), template(L, TPs, I)) :- !, cpp_qualify_item(N, K, I0, I).
cpp_qualify_item(N, K, declare(L, base(Q, [class(Kd, C0, Bs, Ms)])), declare(L, base(Q, [class(Kd, C, Bs, Ms)]))) :- !, cpp_qualify_name(N, K, C0, C).
cpp_qualify_item(N, K, declare(L, base(Q, [struct(N, Ms)])), declare(L, base(Q, [struct(K, Ms)]))) :- !.
cpp_qualify_item(N, K, ctor_def(L, N, Ps, Is, V, B), ctor_def(L, K, Ps, Is, V, B)) :- !.
cpp_qualify_item(N, K, dtor_def(L, N, V, B), dtor_def(L, K, V, B)) :- !.
cpp_qualify_item(N, K, function(L, S, R, N, Ps, V, B), function(L, S, R, K, Ps, V, B)) :- B \== none, !.
cpp_qualify_item(N, K, function(L, S, R, operator(Op), Ps, V, B), function(L, S, R, K, Ps, V, B)) :- B \== none, atom_concat('rel_ops.', N, K), cpp_free_operator(Op, Ps, N), !.   % a REL_OPS operator under its key (0.136); any other collided operator keeps the bare name, where every operator expression looks   % a DEFINED function (0.100); a declared-only one is the shipped library's symbol and keeps its name
cpp_qualify_item(N, K, declaration(L, S, B, Vs), declaration(L, S, B, Vs1)) :- Vs = [var(N, _, _)|_], !, cpp_qualify_vars(N, K, Vs, Vs1).   % a namespace-scope object: libc++'s customization point objects, `ranges::iter_move'
cpp_qualify_item(N, K, typedef(L, Vs), typedef(L, Vs1)) :- Vs = [var(N, _, _)|_], !, cpp_qualify_vars(N, K, Vs, Vs1).   % AN ALIAS TEMPLATE (0.181): std::pmr::basic_string is `pmr.basic_string', apart from the class template std::basic_string (cpp_alias_args_fit/3)
cpp_qualify_vars(_, _, [], []).
cpp_qualify_vars(N, K, [var(N, T, I)|Vs], [var(K, T, I)|Vs1]) :- !, cpp_qualify_vars(N, K, Vs, Vs1).
cpp_qualify_vars(N, K, [V|Vs], [V|Vs1]) :- cpp_qualify_vars(N, K, Vs, Vs1).
cpp_qualify_name(N, K, N, K) :- !.
cpp_qualify_name(N, K, tmpl(N, As), tmpl(K, As)) :- !.
%% a name QUALIFIED by a namespace whose items were indexed apart (above): `__function::__value_func<...>'
cpp_ns_key(Path, N, K) :- Path \== c, findall(S, ( member(S, Path), atom(S), S \== global ), NP), length(NP, Len), between(0, Len, J), L1 is Len - J, L1 > 0, cpp_last_n(NP, L1, Sfx), atomic_list_concat(Sfx, '.', Ns),   % the path's SUFFIXES, longest first (0.112: a collided name's key may be longer than its innermost namespace)
    atomic_list_concat([Ns, '.', N], K), ( cpp_hdr_item(K, _) -> true ; catch('$cpp_ns_own'(K), _, fail) ), !.   % a header's key, or the program's own (cpp_ns_resolve)
%% A QUALIFIED CLASS NAME THAT TWO HEADERS' READS DECLARE IN TWO NAMESPACES (0.218): a read keys apart only the names that collide
%% in it (cpp_ns_quals/2), so `__traits' is bare in <string>'s read, std::__variant_detail's (<string> holds <variant>'s
%% implementation), and bare in <charconv>'s, std::__itoa's; the first header's item answered the bare name, and `#include
%% <string>' before `#include <charconv>' refused std::from_chars, `instance_refused(..., no_member_type('__traits.unsigned',
%% type))', where `__itoa::__traits<_Tp>' meant <charconv>'s. A qualified class name whose own key no read made (cpp_ns_key/3)
%% takes, where the bare name's items stand in two or more namespaces, the qualifier names one of them and the first item is
%% another's, that namespace's items under the key one read would have given them (cpp_ns_unique_suffix/3), renamed as such a
%% read renames them (cpp_qualify_item/4, cpp_rename_names/3). The AST beside a summary writes each item's namespace path after
%% it ('$cpp_hdr_ast_ns', ccl_ast_write), so the items and the paths pair one to one, or nothing is done; a header indexed in
%% the process ('$cpp_hdr') is left as it was. Classes and class templates only: a namespace's functions and objects overload
%% and are found by other roads (std::abs is std's and std::__math's). An UNQUALIFIED use inside a namespace is renamed where its
%% item registers (0.219, cpp_hdr_load_items/2). The first item's path is asked first, and a qualifier it ends with
%% (`std::vector', `std::basic_string', most names) stops there: the bare name is that namespace's already
cpp_cross_key(Path, N, K) :-
    findall(S, ( member(S, Path), atom(S), S \== global ), Q), Q \== [],
    once('$cpp_hdr_ast_ns'(N, P1)), cpp_ns_named_path(P1, First), \+ append(_, Q, First), \+ '$cpp_hdr'(N, _),
    findall(NP, ( '$cpp_hdr_ast_ns'(N, P), cpp_ns_named_path(P, NP) ), NPs), sort(NPs, Ds),
    findall(D, ( member(D, Ds), append(_, Q, D) ), [Dk]),
    cpp_cross_make(class, N, Dk, Ds, K).
%% A QUALIFIED CALL OF A FUNCTION THAT TWO HEADERS' READS DEFINE IN TWO NAMESPACES takes its namespace's functions (0.227;
%% [namespace.qual]/2: the lookup set of a qualified name is the namespace's own declarations): every item of a name is loaded
%% under the bare name, one overload set. libc++ 22's <algorithm> holds std's `__fill(first, last, value)', its second
%% parameter a deduced sentinel, and with <format> read before it `__formatter::__fill(out, n, c)' over a difference took it,
%% the closer match: its body compared two back_insert_iterators (`no_operator(!=)'), std::format's `__formattable_with'
%% answered false and `static assertion failed' (xreadupper.cpp, over 22 only: 21's std::__fill took a fourth argument, its
%% iterator tag). A qualifier that is not std, naming one of the name's namespaces where others have items too, takes that
%% namespace's functions under the key one read would have given them (cpp_cross_make/5); std's own set is its items and the
%% ones its using-declarations bring (std::abs is std::__math's), so std keeps the bare name
cpp_cross_fn_key(Path, N, K) :-
    findall(S, ( member(S, Path), atom(S), S \== global ), Q), Q \== [], Q \== [std], \+ '$cpp_hdr'(N, _),
    findall(NP, ( catch('$cpp_hdr_ast_ns'(N, P), _, fail), P \== c, cpp_ns_named_path(P, NP) ), NPs), sort(NPs, Ds), Ds = [_, _|_],
    findall(D, ( member(D, Ds), append(_, Q, D) ), [Dk]),
    cpp_cross_make(function, N, Dk, Ds, K).
%% THE KEY OF A NAMESPACE'S ITEMS OF A CROSS-READ NAME (0.218, 0.219): N's items whose path is Dk, kept under the key one read
%% would have given them, the shortest suffix of Dk that no other of N's paths Ds ends with (cpp_ns_unique_suffix/3), renamed as
%% such a read renames them, each with its path after it as the AST has it -- or the key a read made already. N's items and
%% paths pair one to one, and every item of Dk is of the Kind asked -- a class or a class template, or a defined function or
%% function template (0.227, above) -- or nothing is made, and the key is noted for that kind, so the next namespace that asks
%% for it does not copy N's items again ('$cpp_cross_none'). A key made already is taken, a read's or this road's, but one made
%% for the other kind ('$cpp_cross_made'): the class road's renames of a namespace's bare uses never go to a function key
cpp_cross_make(Kind, N, Dk, Ds, K) :-
    cpp_ns_unique_suffix(Dk, Ds, Ns), atomic_list_concat([Ns, '.', N], K),
    (   catch('$cpp_hdr_ast'(K, _), _, fail) -> \+ ( catch('$cpp_cross_made'(Other, K), _, fail), Other \== Kind )
    ;   catch('$cpp_cross_none'(Kind, K), _, fail) -> fail
    ;   cpp_cross_make_(Kind, N, Dk, K) -> assertz('$cpp_cross_made'(Kind, K))
    ;   assertz('$cpp_cross_none'(Kind, K)), fail ).
cpp_cross_make_(Kind, N, Dk, K) :-
    \+ '$cpp_hdr'(N, _), findall(I, '$cpp_hdr_ast'(N, I), Is), findall(P, '$cpp_hdr_ast_ns'(N, P), Ps), cpp_cross_zip(Is, Ps, IPs),
    findall(I-P, ( member(I-P, IPs), P \== c, cpp_ns_named_path(P, Dk) ), KIs), KIs \== [], forall(member(I-_, KIs), cpp_cross_kind_item(Kind, I)),
    forall(member(I0-P0, KIs), ( ( cpp_qualify_item(N, K, I0, I1) -> true ; cpp_cross_fwd_item(N, K, I0, I1) -> true ; I1 = I0 ), cpp_rename_names(I1, [N-K], I2), assertz('$cpp_hdr_ast'(K, I2)), assertz('$cpp_hdr_ast_ns'(K, P0)) )).
%% A CLASS DECLARED AND NOT DEFINED is renamed with the rest (0.219): libc++'s `template <class _Fp> class __base;', the
%% primary of std::__function's `__base<_Rp(_ArgTypes...)>', kept its bare name, and the key had a specialization and no
%% template (`template_without_body('__function.__base')' for <string> before <functional>)
cpp_cross_fwd_item(N, K, template(L, TPs, I0), template(L, TPs, I)) :- !, cpp_cross_fwd_item(N, K, I0, I).
cpp_cross_fwd_item(N, K, declare(L, base(Q, [S0])), declare(L, base(Q, [S]))) :- S0 =.. [F, N, none], memberchk(F, [class, struct, union]), S =.. [F, K, none].
cpp_cross_zip([], [], []).
cpp_cross_zip([I|Is], [P|Ps], [I-P|IPs]) :- cpp_cross_zip(Is, Ps, IPs).
cpp_cross_kind_item(Kind, template(_, _, I)) :- !, cpp_cross_kind_item(Kind, I).
cpp_cross_kind_item(class, declare(_, base(_, [S]))) :- functor(S, F, _), memberchk(F, [class, struct, union]).
cpp_cross_kind_item(function, function(_, _, _, _, _, _, B)) :- B \== none.   % a declared-only function is the shipped library's symbol, and keeps its name
%% a name the outer namespace also declares as a function (a plain overload or a function template): the fallback of a keyed qualified call
cpp_bare_fn(F) :- ( ccl_declared(F, fn(_, _, _)) ; catch('$cpp_fn'(F, _, _, _, _), _, fail) ; catch('$cpp_tmpl'(F, _, Item), _, fail), cpp_fn_item(Item, _) ), !.
%% the NAMESPACE PATH is kept beside each indexed name ('$cpp_hdr_ns'), since a function a header only
%% DECLARES must be called by the symbol the shipped library exports, which is its qualified name mangled
%% (cpp_mangled_name/3); `extern "C"' is the path `c', which never mangles
cpp_note_hdr_ns(N, Path) :- ( '$cpp_hdr_ns'(N, _) -> ( Path == c, \+ '$cpp_hdr_ns'(N, c) -> assertz('$cpp_hdr_ns'(N, c)) ; true ) ; assertz('$cpp_hdr_ns'(N, Path)) ).
%% ... the first path is the mangler's, and a C declaration's `c' is kept beside it (0.160), as the AST beside a summary keeps
%% every item's path: a header flattened in this process noted the first only, so `abs', which libc++ 21's <__math/abs.h>
%% declares in std::__math before <stdlib.h>'s, had no `c' for cpp_header_c_name/1, and a cold build of `std::abs(-4)' over
%% <chrono> called glibc's abs as `_ZNSt3__16__math3absEi', a symbol no library has; served from the summary, it was `abs'
cpp_header_c_name(N) :- ( '$cpp_hdr_ns'(N, c) ; '$cpp_hdr_ast_ns'(N, c) ), !.
cpp_hdr_ns(N, P) :- ( '$cpp_hdr_ns'(N, P0) -> true ; '$cpp_hdr_ast_ns'(N, P0) ), !, cpp_ns_plain(P0, P).   % the mangler's path: an inline namespace's mark unwrapped (`std::__1' is `St3__1')
cpp_ns_plain(c, c) :- !.
cpp_ns_plain([], []).
cpp_ns_plain([inline(N)|Ps], [N|Qs]) :- !, cpp_ns_plain(Ps, Qs).
cpp_ns_plain([N|Ps], [N|Qs]) :- cpp_ns_plain(Ps, Qs).
cpp_index_name(template(_, _, I), N) :- !, ( cpp_mdef_item(I, N, _, _) -> true ; cpp_spec_name(I, N, _) -> true ; cpp_template_name(I, N) ).
cpp_index_name(declare(_, base(_, [class(_, N0, _, Ms)])), N) :- Ms \== none, cpp_class_item_name(N0, N).   % a forward declaration declares nothing to register: the DEFINITION carries the name (the struct clause below always said so)
cpp_index_name(declare(_, base(_, [struct(N, Ms)])), N) :- atom(N), Ms \== none.
cpp_index_name(function(_, _, _, N, _, _, B), N) :- atom(N), B \== none.
cpp_index_name(function(_, _, _, operator(Op), Ps, _, B), N) :- ( Op = literal(_) ; B \== none, Op \= conv(_) ), cpp_free_operator(Op, Ps, N).   % A FREE OPERATOR FUNCTION a header DEFINES (0.117), by its free operator name -- <system_error>'s and <thread>'s `operator==' of a class, which no template names -- and a LITERAL OPERATOR it defines or declares: <chrono>'s `operator""ms', <string>'s `operator""s'
cpp_index_name(function(_, _, _, N, _, _, none), N) :- atom(N).                          % a DECLARATION: nothing to register, but its name, its parameters and its namespace are what a call must mangle
cpp_index_name(function(_, _, _, scoped(Path, _), _, _, B), C) :- B \== none, cpp_mdef_class(Path, C, _), atom(C).   % a member DEFINED OUT OF ITS CLASS, by the class's name: `inline ios_base::fmtflags ios_base::flags() const { ... }' -- its body is here, hidden from the ABI, and the class's own list holds only its declaration
cpp_index_name(declaration(_, _, _, [var(scoped([C], N), T, I)]), C) :- atom(C), atom(N), I \== none, \+ T = fn(_, _, _).   % a STATIC DATA MEMBER DEFINED OUT OF ITS CLASS, `inline constexpr strong_ordering strong_ordering::less(_OrdResult::__less);' (0.101): kept by the class's name, as its out-of-class member bodies are, and its own definition here
cpp_index_name(declaration(_, _, _, [var(N, fn(_, _, _), none)|_]), N) :- atom(N).
cpp_index_name(declaration(_, _, _, [var(N, fn(_, [], _), delete)|_]), N) :- atom(N).   % A POISON PILL, a function with NO parameter DELETED where it is declared, IS A DECLARATION OF ITS NAME (0.126; a deleted overload with parameters stays out: it is a candidate that must never be chosen, and `to_chars(char *, char *, bool, int = 10) = delete' would join the set of the real ones): libc++ 21 writes the poison pill of a customization point `void iter_move() = delete;' where libc++ 18 wrote `void iter_move();', and unindexed it made no namespace collision with the object `ranges::iter_move' -- the unqualified call in `__unqualified_iter_move' went to the OBJECT, whose operator() asks the same concept: an endless recursion (`std::reverse_iterator' at C++20, every `std::print', poison.cpp)
cpp_index_name(declaration(_, extern, _, [var(N, T, none)|_]), N) :- atom(N), \+ T = fn(_, _, _).   % an extern GLOBAL the shipped library defines: `extern ostream cout;'
cpp_index_name(declaration(_, Sto, _, [var(N, T, _)|_]), N) :- atom(N), Sto \== extern, \+ T = fn(_, _, _).   % an INLINE VARIABLE the header defines: `inline constexpr const char __base_2_lut[64] = { ... }', emitted by the program that names it -- and one with NO initializer, which C++ VALUE-INITIALIZES: `inline constexpr __ignore_type ignore;' is `std::ignore', and unindexed it was never registered and reached the lowering as an `external global' the link could not find
cpp_index_name(ctor_def(_, C, _, _, _, _), C) :- atom(C).
cpp_index_name(dtor_def(_, C, _, _), C) :- atom(C).
cpp_index_name(ctor_def(_, scoped(Path, _), _, _, _, _), C) :- cpp_mdef_class(Path, C, _), atom(C).   % a NESTED class's, by the enclosing class's name
cpp_index_name(dtor_def(_, scoped(Path, _), _, _), C) :- cpp_mdef_class(Path, C, _), atom(C).
cpp_index_name(extern_template(_, declare(_, base(_, [class(tmpl(N, _), none)]))), N) :- atom(N).   % AN EXTERN TEMPLATE, by the template's name: the instance the shipped library defines (cpp_note_extern)
cpp_index_name(extern_template(_, declaration(_, _, _, [var(scoped(Path, _), fn(_, _, _), none)])), N) :- ccl_last(Path, tmpl(N, _)), atom(N).   % ... and one member of an instance, declared alone (libc++'s string)
%% a name the registries do not have: the header's items of that name, registered now (a class as a lazy one)
cpp_hdr_load(N) :- atom(N), cpp_hdr_item(N, _), \+ ( nb_getval('$cpp_hdr_loaded', Ls), memberchk(N, Ls) ), !,
    cpp_spend(load(N)), nb_getval('$cpp_hdr_loaded', Ls0), nb_setval('$cpp_hdr_loaded', [N|Ls0]), assertz('$cpp_lib'(N)),
    \+ \+ ( cpp_hdr_load_items(N, Items), cpp_note_hdr_fns(Items), cpp_note_hdr_mdefs(Items),   % inside `\+ \+': the registrations are facts and globals, the items' copies are reclaimed
             cpp_where(load(N), cpp_as_lib(yes, cpp_isolated(cpp_register_lazy(Items)))) ).   % AT FILE SCOPE: a load met inside a function's body walk declared the header's functions into that function's open frame -- ccl_declare takes the innermost -- and they were gone with it: `__convert_to_integral.unsigned_long' declared in one walk, undeclared at the next call, its type unknown, and `_Size' undeducible
%% A HEADER'S ITEMS ARE REGISTERED IN THEIR OWN NAMESPACE'S WORDS (0.219): an UNQUALIFIED class name in an item, that two headers'
%% reads declare in two namespaces, names what C++'s lookup finds from the item's own namespace out ([basic.lookup.unqual]): the
%% innermost of its enclosing namespaces that declares the name. Where that is not the namespace of the bare name's first item,
%% the use goes to the key one read would have given that namespace's items (cpp_cross_make/4), as a read renames a deeper
%% namespace's bare uses (cpp_qualify_body/4). `#include <charconv>' before `#include <variant>' refused `std::variant<int>',
%% `base_not_registered('__copy_assignment.__traits.int.__traits.int.__copy_assignable_trait', '__impl.int')': <variant>'s
%% `__traits<_Types...>', named bare inside std::__variant_detail, took <charconv>'s `__itoa::__traits<_Tp>', the first item.
%% A header's items and their paths pair one to one in the AST ('$cpp_hdr_ast_ns' after each item), or the items go as they are
cpp_hdr_load_items(N, Items) :-
    findall(I, '$cpp_hdr'(N, I), Is1), findall(I0, '$cpp_hdr_ast'(N, I0), Is0),
    (   Is0 \== [], findall(P, '$cpp_hdr_ast_ns'(N, P), Ps), cpp_cross_zip(Is0, Ps, IPs), cpp_cross_table(T), T \== []
    ->  findall(I2, ( member(I0-P, IPs), ( P \== c, cpp_ns_named_path(P, NP), cpp_cross_map(NP, T, Map), Map \== [] -> cpp_rename_names(I0, Map, I2) ; I2 = I0 ) ), Is2)
    ;   Is2 = Is0 ),
    findall(I, ( member(I2, Is2), ccl_float_thaw(I2, I) ), Is3), append(Is1, Is3, Items).
%% the names whose AST items stand in two or more named namespaces, each N-Ds-First (its paths, its first item's), made once for
%% the ASTs loaded (cpp_ast_gen_next/0); a name a header indexed in the process has ('$cpp_hdr') is left out
cpp_cross_table(T) :- nb_getval('$cpp_ast_gen', G), ( nb_current('$cpp_cross_table', G-T0) -> T = T0 ; cpp_cross_table_(T), nb_setval('$cpp_cross_table', G-T) ).
cpp_cross_table_(T) :-
    findall(N-NP, ( '$cpp_hdr_ast_ns'(N, P), P \== c, cpp_ns_named_path(P, NP) ), L0), msort(L0, L1), cpp_cross_group(L1, G0),
    findall(N-Ds-First, ( member(N-Ds, G0), Ds = [_, _|_], \+ '$cpp_hdr'(N, _), once('$cpp_hdr_ast_ns'(N, P1)), cpp_ns_named_path(P1, First) ), T).
cpp_cross_group([], []).
cpp_cross_group([N-P|L], [N-Ds|Gs]) :- cpp_cross_run(L, N, [P], Ds0, Rest), sort(Ds0, Ds), cpp_cross_group(Rest, Gs).
cpp_cross_run([N-P|L], N, Acc, Ds, Rest) :- !, cpp_cross_run(L, N, [P|Acc], Ds, Rest).
cpp_cross_run(L, _, Ds, Ds, L).
%% the renames in a namespace's items, NP-memoized for the ASTs loaded: each cross-read name whose innermost declaring namespace,
%% from NP out, is not its first item's, to that namespace's key -- a class's or a class template's (cpp_cross_make/4 fails else).
%% ... AND THE FIRST ITEM'S OWN NAMESPACE TOO WHERE ANOTHER NAMESPACE'S ITEM OF THE NAME IS A FUNCTION OR AN OBJECT (0.221;
%% [basic.lookup.unqual]/1, [basic.lookup.argdep]/3: the class that ordinary lookup finds hides them, and no argument's
%% namespace is asked): every item of the name is loaded under the bare name, so the bare name held both kinds and a call took
%% the function's road. libc++ 21's `inline constexpr auto transform = __transform{};' in std::ranges, read in <algorithm>
%% before <sstream> brought std::__formatter's function template `__transform(first, last, out, op)', called it with no
%% argument, `arity_mismatch', and every `std::ranges::transform' was refused; read after it, the class was keyed already.
%% Over libc++ 21's summaries, `__transform' at C++20 to C++26 and `__upper_bound' (std's function, ranges' class) at C++23 and
%% C++26; none over libc++ 18's
cpp_cross_map(NP, T, Map) :- nb_getval('$cpp_ast_gen', G), ( catch('$cpp_cross_map'(NP, G, Map0), _, fail) -> Map = Map0 ; cpp_cross_map_(NP, T, Map), assertz('$cpp_cross_map'(NP, G, Map)) ).
cpp_cross_map_(NP, T, Map) :- findall(N-K, ( member(N-Ds-First, T), cpp_ns_innermost(NP, Ds, Q), ( Q \== First -> true ; cpp_cross_mixed(N, Q) ), cpp_cross_make(class, N, Q, Ds, K) ), Map).
cpp_cross_mixed(N, Q) :- findall(I, '$cpp_hdr_ast'(N, I), Is), findall(P, '$cpp_hdr_ast_ns'(N, P), Ps), cpp_cross_zip(Is, Ps, IPs), !,
    member(I-P, IPs), P \== c, cpp_ns_named_path(P, NP), NP \== Q, cpp_cross_value_item(I), !.
cpp_cross_value_item(template(_, _, I)) :- !, cpp_cross_value_item(I).
cpp_cross_value_item(function(_, _, _, _, _, _, _)).
cpp_cross_value_item(declaration(_, _, _, _)).
cpp_ns_innermost(NP, Ds, Q) :- findall(L-D, ( member(D, Ds), append(D, _, NP), length(D, L) ), LDs), LDs \== [], msort(LDs, S), last(S, _-Q).
