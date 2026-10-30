%% ccl_cpp_mangle.pl -- the Itanium mangler: the names of what a library header only declares, the substitutions, the
%% nested names and the template instances, a function template's arguments by its parameters. A part of the C++
%% desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there, in their order.

%% ---- ITANIUM NAME MANGLING, for what a library header only DECLARES --------------------------
%% libc++ declares `std::__libcpp_verbose_abort(const char *, ...)' and ships its definition in
%% libc++.dylib as `_ZNSt3__122__libcpp_verbose_abortEPKcz'. This compiler emits every name it DEFINES
%% unmangled -- its own C-shaped symbols, and nothing else knows them -- but a name it only CALLS must be
%% the one the library exports. So a function that a library header declares and never defines, and that
%% is not `extern "C"', is called by its Itanium name: _ZN, the namespace path (St for std), the name
%% length-prefixed, E, then the parameters.
%% WHAT IS NOT MANGLED, and stays its plain name so the linker says so rather than a wrong symbol: a
%% class-typed parameter (this compiler's class names are its own mangling, not C++'s), a type no code
%% below encodes, and ANY signature whose substitutable components repeat -- Itanium writes the second
%% occurrence of a component as S_, S0_ ... and a straight re-encoding would be a different symbol.
cpp_mangled_name(F, Ps, Name) :-
    atom(F), \+ cpp_c_name(F), \+ cpp_header_c_name(F), '$cpp_fn'(F, _, Ps, no, decl(_, V)),   % ... NOR A NAME THE C LIBRARY DECLARES (0.117): the index lists a name's paths in the order the headers were read, `remove' as `[std, __1]' (the algorithm's template) before `c' (stdio.h's) when <fstream> comes before <cstdio>, and the plain declaration -- stdio's -- was called as `std::remove(const char *)', a symbol no library has
    cpp_hdr_ns(F, Path), Path = [_|_],
    ( cpp_ita_function(Path, [], F, [], Ps, V, Name) -> true
    ; once(catch(cpp_resolved_params(Ps, Ps1), _, fail)), cpp_ita_function(Path, [], F, [], Ps1, V, Name) ).   % A CLASS-TYPED PARAMETER spelled through its alias, resolved first (0.108): `std::stoi(const string &, size_t * = nullptr, int = 10)' is `_ZNSt3__14stoiERKNS_12basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEEEPmi', and unresolved the call kept the plain name the link could not find
%% ---- THE ITANIUM MANGLER, ITS SECOND HALF (0.73): substitutions, nested names, template instances ----------
%% What 0.61 spelled -- a free function's `_ZN' + namespace + name + `E' + builtin parameters, refusing any
%% repeat -- is spelled here with the ABI's SUBSTITUTION TABLE threaded through: every prefix, every nested name
%% and every non-builtin type is a candidate in the order it is met, and its second occurrence is `S_', `S0_',
%% `S1_' ... (base 36 past the first). A class is a NESTED NAME, `N <prefix> <len>name E' (`St' for std, never a
%% candidate itself; `St3__1' is one); a template instance a `<len>name I <args> E' whose template-name prefix and
%% whose template-id are candidates in turn; a member's own nested name is the class chain as a PREFIX, its levels
%% candidates, then the member. libc++'s own symbols are the test: `_ZNSt3__114__num_put_base18__identify_paddingE
%% PcS1_RKNS_8ios_baseE' (the second `Pc' is `S1_', the class-typed parameter `RKNS_8ios_baseE') and
%% `_ZNKSt3__15ctypeIcE9do_narrowEcc' (`K' for a const method, the specialization as a prefix). What this compiler
%% has no spelling for -- a function pointer, a non-type template argument, an operator, an array -- FAILS, and the
%% member keeps its own name for the linker to name.
cpp_ita_function([std], [], F, _, Ps, V, Name) :- !,                                       % a function directly in std is UNSCOPED: `_ZSt19uncaught_exceptionsv', no N...E
    cpp_ita_member_text(F, Ps, MText), cpp_ita_params(Ps, V, [], ParamText, _), atomic_list_concat(['_ZSt', MText, ParamText], Name).
cpp_ita_function(Path, Chain, F, Qs, Ps, V, Name) :-
    ( memberchk(const, Qs) -> CV = 'K' ; CV = '' ),
    cpp_ita_prefix(Path, Chain, [], PText, Subs1),
    cpp_ita_member_text(F, Ps, MText),
    cpp_ita_params(Ps, V, Subs1, ParamText, _),
    atomic_list_concat(['_ZN', CV, PText, MText, 'E', ParamText], Name).
%% ---- A FUNCTION TEMPLATE'S INSTANCE THE SHIPPED LIBRARY DEFINES (0.61's and 0.73's named not-done item) ----
%% libc++ declares `template <class _Comp, class _RandomAccessIterator> void __sort(_RandomAccessIterator,
%% _RandomAccessIterator, _Comp);' with NO BODY ANYWHERE and compiles the instances into libc++.dylib, listing
%% them `extern template ... __sort<__less<int>&, int*>' -- which is what every `std::sort' of an arithmetic type
%% calls. Such an instance is named by its Itanium symbol, and a function TEMPLATE's differs from a plain
%% function's in three places: the nested name carries the TEMPLATE-ID (`_ZN St3__1 6__sort I <args> E E', the
%% template-PREFIX a substitution candidate and the function's own template-args never one), the
%% bare-function-type that follows a template-id begins with the RETURN TYPE, and a parameter written as one of
%% the template's own parameters is `T_' for the first, `T0_' for the second (decimal, where a substitution is
%% base 36), each a candidate of its own: `_ZNSt3__16__sortIRNS_6__lessIiiEEPiEEvT0_S5_T_'.
cpp_ita_fn_instance(F, TPs, B, Ret, Ps, V, Name) :-
    atom(F), \+ cpp_c_name(F), cpp_hdr_ns(F, Path), Path = [_|_],
    cpp_ita_tparams(TPs, 0, Refs), cpp_ita_bound_args(TPs, B, Args),
    nb_setval('$cpp_ita_tps', Refs),
    (   cpp_ita_fn_inst_(Path, F, TPs, Args, Ret, Ps, V, Name0) -> nb_setval('$cpp_ita_tps', []), Name = Name0
    ;   nb_setval('$cpp_ita_tps', []), fail ).
cpp_ita_fn_inst_(Path, F, TPs, Args, Ret, Ps, V, Name) :-
    cpp_ita_ns(Path, '', '', [], C0, T0, Subs1),
    ccl_byte_length(F, L), atomic_list_concat([C0, L, F], C1),
    cpp_ita_level(C1, T0, L, F, Subs1, T1, Subs2),                                          % the template-prefix, a candidate
    cpp_ita_fn_targs(TPs, Args, Subs2, AText, Subs3),                                       % each argument by its parameter (0.221)
    cpp_ita_type(Ret, Subs3, _, RText, Subs4),                                              % the RETURN TYPE, which only a template's encoding carries
    cpp_ita_params(Ps, V, Subs4, PText, _),
    atomic_list_concat(['_ZN', T1, 'I', AText, 'EE', RText, PText], Name).
%% A FUNCTION TEMPLATE'S ARGUMENTS BY ITS PARAMETERS (0.221; Itanium 5.1.5.4 and its <template-param-decl>, as clang 18 and 21
%% spell them): a type is its type and a type pack `J ... E'; a value is `L', its parameter's type, the number, `E' (0.137's
%% cpp_ita_value/3) -- and where the parameter's type is a placeholder or another parameter, the parameter's declaration
%% comes first and the value takes its literal's own type: `TnDa' for `auto' (its top-level const dropped, [temp.param]/5),
%% `TnDc' for `decltype(auto)', `TnPDa' for `auto *', `Tn' and the parameter's code for `T V' (`TnT_', a substitution
%% candidate as a parameter's code always is), `TpTnDa' before an `auto...' pack's `J ... E'. They were types alone, and an
%% instance with a value argument took this compiler's name: `std::__1::e<5>()' of `template <auto N>' is
%% `_ZNSt3__11eITnDaLi5EEEiv', `a<int, 3>(int, int)' of `template <class T, T V>' `_ZNSt3__11aIiTnT_Li3EEEiS1_S1_'. A value
%% that is an address or an object (`X...E', `L_Z...E') is spelled by no clause, and the instance keeps this compiler's name
cpp_ita_fn_targs([], [], Subs, '', Subs).
cpp_ita_fn_targs([TP|TPs], As, Subs0, Text, Subs) :- \+ TP = tparam(_, _, _), !, cpp_ita_fn_targs(TPs, As, Subs0, Text, Subs).
cpp_ita_fn_targs([tparam(K, _, _)|TPs], [A|As], Subs0, Text, Subs) :- cpp_ita_fn_targ(K, A, Subs0, T1, Subs1), cpp_ita_fn_targs(TPs, As, Subs1, T2, Subs), atom_concat(T1, T2, Text).
cpp_ita_fn_targ(type, A, Subs0, T, Subs) :- !, cpp_ita_type(A, Subs0, _, T, Subs).
cpp_ita_fn_targ(pack, A, Subs0, T, Subs) :- !, ( A = pack(As) -> true ; is_list(A), As = A ), cpp_ita_targs(As, Subs0, _, T0, Subs), atomic_list_concat(['J', T0, 'E'], T).
cpp_ita_fn_targ(vpack(VT), A, Subs0, T, Subs) :- !, ( A = vpack(As) -> true ; A = pack(As) -> true ; is_list(A), As = A ),
    ( cpp_ita_pdecl(VT, Subs0, D, Subs) -> atom_concat('Tp', D, P), VT1 = none ; P = '', VT1 = VT, Subs = Subs0 ), cpp_ita_values(As, VT1, T0), atomic_list_concat([P, 'J', T0, 'E'], T).
cpp_ita_fn_targ(K, A, Subs0, T, Subs) :- cpp_ita_pdecl(K, Subs0, D, Subs), !, cpp_ita_value(A, none, V), atom_concat(D, V, T).
cpp_ita_fn_targ(K, A, Subs, T, Subs) :- K \== template, cpp_ita_value(A, K, T).
cpp_ita_values([], _, '').
cpp_ita_values([A|As], VT, T) :- cpp_ita_value(A, VT, T1), cpp_ita_values(As, VT, T2), atom_concat(T1, T2, T).
%% a value parameter's declaration where clang spells it: a placeholder's (`Da', `Dc', under `P', `R' and `O' each a candidate,
%% an inner const `K'), or a parameter's code where its type is another of the template's parameters
cpp_ita_pdecl(K, Subs0, D, Subs) :- cpp_has_auto(K), cpp_ita_auto_text(K, top, Subs0, X, Subs), !, atom_concat('Tn', X, D).
cpp_ita_pdecl(base(_, [typedef(N)]), Subs0, D, Subs) :- atom(N), cpp_ita_tparam(N, Code), !, cpp_ita_tp_use(Code, Subs0, T, Subs), atom_concat('Tn', T, D).
cpp_ita_auto_text(base(Q, [auto]), Lvl, Subs0, X, Subs) :- !,
    ( memberchk(decltype_auto, Q) -> X = 'Dc', Subs = Subs0 ; Lvl == inner, memberchk(const, Q) -> X = 'KDa', cpp_ita_note(X, Subs0, Subs) ; X = 'Da', Subs = Subs0 ).
cpp_ita_auto_text(ptr(_, T), _, Subs0, X, Subs) :- !, cpp_ita_auto_text(T, inner, Subs0, X0, Subs1), atom_concat('P', X0, X), cpp_ita_note(X, Subs1, Subs).
cpp_ita_auto_text(ref(_, T), _, Subs0, X, Subs) :- !, cpp_ita_auto_text(T, inner, Subs0, X0, Subs1), atom_concat('R', X0, X), cpp_ita_note(X, Subs1, Subs).
cpp_ita_auto_text(rref(_, T), _, Subs0, X, Subs) :- cpp_ita_auto_text(T, inner, Subs0, X0, Subs1), atom_concat('O', X0, X), cpp_ita_note(X, Subs1, Subs).
cpp_ita_tparams([], _, []).
cpp_ita_tparams([requires(_)|TPs], I, Rs) :- !, cpp_ita_tparams(TPs, I, Rs).
cpp_ita_tparams([ttp(_, _)|TPs], I, Rs) :- !, cpp_ita_tparams(TPs, I, Rs).
cpp_ita_tparams([tparam(_, P, _)|TPs], I, [P-Code|Rs]) :- cpp_ita_tp_code(I, Code), I1 is I + 1, cpp_ita_tparams(TPs, I1, Rs).
cpp_ita_tp_code(0, 'T_') :- !.
cpp_ita_tp_code(I, Code) :- I1 is I - 1, atomic_list_concat(['T', I1, '_'], Code).
cpp_ita_bound_args([], _, []).
cpp_ita_bound_args([requires(_)|TPs], B, As) :- !, cpp_ita_bound_args(TPs, B, As).
cpp_ita_bound_args([ttp(_, _)|TPs], B, As) :- !, cpp_ita_bound_args(TPs, B, As).
cpp_ita_bound_args([tparam(_, P, _)|TPs], B, [A|As]) :- memberchk(P-A, B), cpp_ita_bound_args(TPs, B, As).
cpp_ita_tparam(N, Code) :- ( nb_current('$cpp_ita_tps', Refs) -> true ; Refs = [] ), memberchk(N-Code, Refs).
cpp_ita_tp_use(Code, Subs0, Text, Subs) :- ( cpp_ita_sub(Code, Subs0, S) -> Text = S, Subs = Subs0 ; Text = Code, cpp_ita_note(Code, Subs0, Subs) ).
cpp_ita_member_text(operator(Op), [], Code) :- cpp_ita_unary(Op, Code), !.               % a member operator with no parameter is the unary one: `operator-()' is `ng'
cpp_ita_member_text(F, _, T) :- cpp_ita_member_name(F, T).
cpp_ita_member_name('$ctor', 'C1') :- !.
cpp_ita_member_name('$dtor', 'D1') :- !.
cpp_ita_member_name('$dtor_del', 'D0') :- !.                                    % the DELETING destructor (0.202)
cpp_ita_member_name(operator(Op), Code) :- !, cpp_ita_op(Op, Code).                      % an operator by the ABI's two-letter code: `operator>>' is `rs'
cpp_ita_member_name(F, T) :- atom(F), ccl_byte_length(F, L), atomic_list_concat([L, F], T).
cpp_ita_op('+', pl).    cpp_ita_op('-', mi).    cpp_ita_op('*', ml).    cpp_ita_op('/', dv).    cpp_ita_op('%', rm).    cpp_ita_op('&', an).    cpp_ita_op('|', or).    cpp_ita_op('^', eo).
cpp_ita_op('=', 'aS').  cpp_ita_op('+=', 'pL'). cpp_ita_op('-=', 'mI'). cpp_ita_op('*=', 'mL'). cpp_ita_op('/=', 'dV'). cpp_ita_op('%=', 'rM'). cpp_ita_op('&=', 'aN'). cpp_ita_op('|=', 'oR'). cpp_ita_op('^=', 'eO').
cpp_ita_op('<<', ls).   cpp_ita_op('>>', rs).   cpp_ita_op('<<=', 'lS'). cpp_ita_op('>>=', 'rS'). cpp_ita_op('==', eq). cpp_ita_op('!=', ne). cpp_ita_op('<', lt). cpp_ita_op('>', gt). cpp_ita_op('<=', le). cpp_ita_op('>=', ge). cpp_ita_op('<=>', ss).
cpp_ita_op('!', nt).    cpp_ita_op('&&', aa).   cpp_ita_op('||', oo).   cpp_ita_op('++', pp).   cpp_ita_op('--', mm).   cpp_ita_op(',', cm).    cpp_ita_op('->*', pm).  cpp_ita_op('->', pt).
cpp_ita_op(co_await, aw). cpp_ita_op('()', cl).   cpp_ita_op('[]', ix).   cpp_ita_op('~', co).    cpp_ita_op(new, nw).    cpp_ita_op(delete, dl).   cpp_ita_op('new[]', na).   cpp_ita_op('delete[]', da).   % the array forms are other functions (0.202)
cpp_ita_unary('-', ng). cpp_ita_unary('+', ps). cpp_ita_unary('*', de). cpp_ita_unary('&', ad).
%% the prefix: the namespace path, then the class chain (plain(Name) or inst(Name, Args) per level), each level a
%% candidate once complete; a level already in the table replaces everything spelled so far by its code
cpp_ita_prefix(Path, Chain, Subs0, Text, Subs) :-
    cpp_ita_ns(Path, '', '', Subs0, C0, T0, Subs1),
    cpp_ita_chain(Chain, C0, T0, Subs1, _, Text, Subs).
cpp_ita_ns([], C, T, Subs, C, T, Subs).
cpp_ita_ns([std|Ns], '', '', Subs0, C, T, Subs) :- !, cpp_ita_ns(Ns, 'St', 'St', Subs0, C, T, Subs).   % `St' abbreviates std, and is no candidate
cpp_ita_ns([N0|Ns], C0, T0, Subs0, C, T, Subs) :- atom(N0), ( cpp_anon_seg(N0) -> N = '_GLOBAL__N_1' ; N = N0 ), ccl_byte_length(N, L), atomic_list_concat([C0, L, N], C1), cpp_ita_level(C1, T0, L, N, Subs0, T1, Subs1), cpp_ita_ns(Ns, C1, T1, Subs1, C, T, Subs).   % an unnamed namespace as clang spells it (0.192)
%% one level of a prefix: its canonical text C1 is the key; known, its code stands for the whole prefix so far
cpp_ita_level(C1, T0, L, N, Subs0, T1, Subs1) :-
    (   cpp_ita_sub(C1, Subs0, Code) -> T1 = Code, Subs1 = Subs0
    ;   atomic_list_concat([T0, L, N], T1), cpp_ita_note(C1, Subs0, Subs1) ).
cpp_ita_chain([], C, T, Subs, C, T, Subs).
cpp_ita_chain([plain(N)|Ls], C0, T0, Subs0, C, T, Subs) :- ccl_byte_length(N, L), atomic_list_concat([C0, L, N], C1), cpp_ita_level(C1, T0, L, N, Subs0, T1, Subs1), cpp_ita_chain(Ls, C1, T1, Subs1, C, T, Subs).
cpp_ita_chain([plain(N, Ts)|Ls], C0, T0, Subs0, C, T, Subs) :- cpp_ita_src(N, Ts, Src), atom_concat(C0, Src, C1), cpp_ita_level(C1, T0, '', Src, Subs0, T1, Subs1), cpp_ita_chain(Ls, C1, T1, Subs1, C, T, Subs).   % a class's ABI tags with its name (0.236)
cpp_ita_chain([inst(N, Args)|Ls], C0, T0, Subs0, C, T, Subs) :- cpp_ita_chain([inst(N, Args, [])|Ls], C0, T0, Subs0, C, T, Subs).
cpp_ita_chain([inst(N, Args, Ts)|Ls], C0, T0, Subs0, C, T, Subs) :-
    cpp_ita_src(N, Ts, Src), atom_concat(C0, Src, C1), cpp_ita_level(C1, T0, '', Src, Subs0, T1, Subs1),   % the template-name prefix, a candidate
    cpp_ita_targs_t(N, Args, Subs1, ACanon, AText, Subs2),
    atomic_list_concat([C1, 'I', ACanon, 'E'], C2),
    (   cpp_ita_sub(C2, Subs2, Code) -> T2 = Code, Subs3 = Subs2
    ;   atomic_list_concat([T1, 'I', AText, 'E'], T2), cpp_ita_note(C2, Subs2, Subs3) ),                 % the template-id, a candidate
    cpp_ita_chain(Ls, C2, T2, Subs3, C, T, Subs).
%% A VALUE TEMPLATE ARGUMENT (0.137; Itanium 5.1.5.4): `L', the template parameter's type (else the literal's), the number
%% (`n' before a negative one), `E' -- `ratio<1, 1000000000>' is `5ratioILl1ELl1000000000EE', a bool `Lb1E'
cpp_ita_targs_t(N, Args, Subs0, Canon, Text, Subs) :- ( atom(N), catch('$cpp_tmpl'(N, TPs, _), _, fail) -> cpp_ita_vtypes(TPs, VTs) ; VTs = [] ), cpp_ita_targs_v(Args, VTs, Subs0, Canon, Text, Subs).
cpp_ita_vtypes([], []).
cpp_ita_vtypes([requires(_)|TPs], VTs) :- !, cpp_ita_vtypes(TPs, VTs).
cpp_ita_vtypes([ttp(_, _)|TPs], VTs) :- !, cpp_ita_vtypes(TPs, VTs).
cpp_ita_vtypes([tparam(K, _, _)|TPs], [VT|VTs]) :- ( memberchk(K, [type, pack, template]) -> VT = none ; K = vpack(_) -> VT = vpack ; cpp_has_auto(K) -> VT = none ; VT = K ), cpp_ita_vtypes(TPs, VTs).   % a placeholder's value by the literal's own type (0.199)
cpp_ita_targs_v([], _, Subs, '', '', Subs).
cpp_ita_targs_v([A|As], VTs, Subs0, Canon, Text, Subs) :- ( VTs = [VT|VTs1] -> true ; VT = none, VTs1 = [] ),
    ( cpp_ita_value(A, VT, C1) -> T1 = C1, Subs1 = Subs0 ; cpp_ita_type(A, Subs0, C1, T1, Subs1) ),
    ( VT == vpack -> VTs2 = VTs ; VTs2 = VTs1 ), cpp_ita_targs_v(As, VTs2, Subs1, C2, T2, Subs), atom_concat(C1, C2, Canon), atom_concat(T1, T2, Text).
cpp_ita_value(addr(id(G)), _, Text) :- atom(G), cpp_ita_extname(G, X), !, atomic_list_concat(['XadL_Z', X, 'EE'], Text).
cpp_ita_value(addr(scoped(P, G)), _, Text) :- is_list(P), atom(G), cpp_ita_scoped_name(P, G, X), !, atomic_list_concat(['XadL_Z', X, 'EE'], Text).   % ... a qualified one's, `XadL_ZN2ns1hEEE'
cpp_ita_value(nullptr, VT, Text) :- VT = ptr(_, _), catch(cpp_ita_type(VT, [], _, TT, _), _, fail), !, atomic_list_concat(['L', TT, '0E'], Text).   % a null pointer argument, its parameter's type: `LPi0E'   % AN ADDRESS (0.236; Itanium 5.1.5.4): `&g' is `XadL_Z1gEE', `&ns::h' `XadL_ZN2ns1hEEE', a function its encoding `XadL_Z2fnvEE'
cpp_ita_value(id(G), VT, Text) :- atom(G), catch(ccl_type_of(id(G), fn(_, _, _)), _, fail), VT \= ref(_, _), cpp_ita_extname(G, X), !, atomic_list_concat(['XadL_Z', X, 'EE'], Text).   % ... a function named bare, as its address
cpp_ita_value(id(G), ref(_, _), Text) :- atom(G), cpp_ita_extname(G, X), !, atomic_list_concat(['L_Z', X, 'E'], Text).   % ... an object a reference parameter names, `L_Z1gE'
cpp_ita_value(bool(B), _, Text) :- !, ( B == true -> Text = 'Lb1E' ; Text = 'Lb0E' ).
cpp_ita_value(cast(ET, X), VT, Text) :- ( VT == none ; VT == vpack ), cpp_ita_literal(X, _, V), integer(V), cpp_enum_type(ET), catch(cpp_ita_type(ET, [], _, TC, _), _, fail), !,   % an enumeration's value by its enum (0.203): `L5Color0E'
    ( V < 0 -> V1 is -V, atomic_list_concat(['L', TC, n, V1, 'E'], Text) ; atomic_list_concat(['L', TC, V, 'E'], Text) ).
cpp_ita_value(A, VT, Text) :- cpp_ita_literal(A, Kind, V), integer(V), !,
    ( VT \== none, VT \== vpack, catch(cpp_ita_type(VT, [], _, TC0, _), _, fail) -> TC = TC0 ; TC = Kind ),
    ( V < 0 -> V1 is -V, atomic_list_concat(['L', TC, n, V1, 'E'], Text) ; atomic_list_concat(['L', TC, V, 'E'], Text) ).
cpp_ita_literal(int(V), i, V).  cpp_ita_literal(uint(V), j, V).  cpp_ita_literal(long(V), l, V).  cpp_ita_literal(ulong(V), m, V).
cpp_ita_literal(V, i, V) :- integer(V).
cpp_ita_literal(chr(V), c, V).   % a typed value argument (0.199): a character's literal by its kind, a cast's by its type
cpp_ita_literal(wchr(V), w, V).
cpp_ita_literal(u16chr(V), 'Ds', V).
cpp_ita_literal(u32chr(V), 'Di', V).
cpp_ita_literal(cast(base(_, S), X), K, V) :- cpp_ita_literal(X, K0, V), ( cpp_canon_specs(S, Cs), cpp_ita_lit_code(Cs, K1) -> K = K1 ; K = K0 ).
cpp_ita_lit_code([long, long], x).
cpp_ita_lit_code([unsigned, long, long], y).
cpp_ita_lit_code([short], s).
cpp_ita_lit_code([unsigned, short], t).
cpp_ita_lit_code([signed, char], a).
cpp_ita_lit_code([unsigned, char], h).
cpp_ita_lit_code([char], c).
cpp_ita_lit_code([char8_t], 'Du').
cpp_ita_lit_code(['__int128'], n).
cpp_ita_lit_code([unsigned, '__int128'], o).
cpp_ita_lit_code([wchar_t], w).
cpp_ita_lit_code([char16_t], 'Ds').
cpp_ita_lit_code([char32_t], 'Di').
cpp_ita_targs([], Subs, '', '', Subs).
cpp_ita_targs([A|As], Subs0, Canon, Text, Subs) :- cpp_ita_type(A, Subs0, C1, T1, Subs1), cpp_ita_targs(As, Subs1, C2, T2, Subs), atom_concat(C1, C2, Canon), atom_concat(T1, T2, Text).
%% the parameters: `v' for none, `z' for the ellipsis
cpp_ita_params([], false, Subs, v, Subs) :- !.
cpp_ita_params(Ps, V, Subs0, Text, Subs) :- cpp_ita_ptypes(Ps, Subs0, T0, Subs), ( V == true -> atom_concat(T0, z, Text) ; Text = T0 ).
cpp_ita_ptypes([], Subs, '', Subs).
cpp_ita_ptypes([P|Ps], Subs0, Text, Subs) :- ( P = param(PT, _) ; P = param(PT, _, _) ), !, cpp_ita_type(PT, Subs0, _, T1, Subs1), cpp_ita_ptypes(Ps, Subs1, T2, Subs), atom_concat(T1, T2, Text).
cpp_ita_ptypes([_|Ps], Subs0, Text, Subs) :- cpp_ita_ptypes(Ps, Subs0, Text, Subs).
%% a type: its canonical spelling (the key) and its spelling with substitutions; a builtin is no candidate, and
%% each layer over one -- pointer, reference, const -- is a candidate of its own, the inner first
%% A C STRUCT IN A MANGLED NAME IS ITS UNSCOPED NAME (0.94; [basic.link]: a typedef of an unnamed struct gives it its
%% name for linkage purposes -- the FIRST typedef that names it): `basic_streambuf<char>::seekpos(fpos<mbstate_t>, openmode)'
%% is shipped as `..7seekposENS_4fposI11__mbstate_tEEj', and glibc's `mbstate_t' is a typedef of `__mbstate_t', a typedef of an
%% anonymous struct, which the resolution walked straight through to the struct and could not spell; asked BEFORE the
%% resolution, the chain is walked one typedef at a time to the one that names the struct, and a NAMED C struct is its tag.
cpp_ita_type(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_tparam(N, _), !, cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs).   % a template's own parameter, never a typedef of its name (0.236)
cpp_ita_type(base(Q, [decltype(E)]), Subs0, Canon, Text, Subs) :- cpp_ita_dependent, !, cpp_ita_expr(E, Subs0, C0, T0, Subs1), ( ( E = id(_) ; E = member(_, _) ; E = arrow(_, _) ) -> D = 'Dt' ; D = 'DT' ),   % IN A PATTERN'S WORDS (0.236): `decltype(e)' is `DT <expression> E', of a name or a member access `Dt'
    atomic_list_concat([D, C0, 'E'], C1), atomic_list_concat([D, T0, 'E'], T1),
    cpp_ita_whole(C1, T1, Subs1, T2, Subs2), ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C1, Canon), cpp_ita_wrap_cv(CV, Canon, T2, Subs2, Text, Subs) ; Canon = C1, Text = T2, Subs = Subs2 ).
cpp_ita_type(base(Q, [typedef(tmpl(N, Args))]), Subs0, Canon, Text, Subs) :- cpp_ita_dependent, atom(N), cpp_ita_dep_args(Args), !, cpp_ita_dep_tmpl(N, Args, Subs0, C1, T1, Subs1),   % ... a template-id over an expression, `1AIXplT_Li1EEE'
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C1, Canon), cpp_ita_wrap_cv(CV, Canon, T1, Subs1, Text, Subs) ; Canon = C1, Text = T1, Subs = Subs1 ).
cpp_ita_type(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_c_struct(N, Name), !, cpp_ita_global(Name, Q, Subs0, Canon, Text, Subs).
cpp_ita_type(T0, Subs0, Canon, Text, Subs) :- ccl_resolve_type(T0, T), cpp_ita_type_(T, Subs0, Canon, Text, Subs).
cpp_ita_c_struct(N, Name) :- \+ catch('$cpp_type_ns'(N, _), _, fail), \+ cpp_class_known(N), \+ catch('$cpp_inst'(N, _), _, fail), ccl_typedef_of(N, T), cpp_ita_c_struct_(N, T, Name).   % a type of the program in a namespace of its own is none (0.180)
cpp_ita_c_struct(N, N) :- \+ catch('$cpp_type_ns'(N, _), _, fail), \+ ccl_typedef_of(N, _), catch(ccl_tag(N, Ms), _, fail), Ms \== none, \+ ccl_is_enum_tag(Ms), cpp_ita_c_tag(N), \+ catch('$cpp_inst'(N, _), _, fail), !.   % A C STRUCT NAMED BY ITS TAG ALONE (0.134): <time.h>'s `struct tm', which no typedef names -- `time_put<char>::put(iter_type, ios_base &, char_type, const tm *, const char_type *, const char_type *)' is shipped as `..3putES4_RNS_8ios_baseEcPK2tmPKcSC_', the typedef road found no name for `tm', and the call kept this compiler's own: an undefined symbol at the link of every `std::put_time' and `std::get_time'
cpp_class_known(N) :- catch(cpp_class_l(N, _), _, fail).   % ... in a process WITHOUT the desugaring's registries too (the mangler's own check, test/cpp.pl's c34, spells its symbols with no class registered: an existence error there, 0.94's first gate)
cpp_ita_c_struct_(N, base(_, [struct(anon, _)]), N) :- !.
cpp_ita_c_struct_(N, base(_, [union(anon, _)]), N) :- !.
cpp_ita_c_struct_(_, base(_, [struct(S, _)]), S) :- atom(S), cpp_ita_c_tag(S), !.
cpp_ita_c_struct_(_, base(_, [union(S, _)]), S) :- atom(S), cpp_ita_c_tag(S), !.
cpp_ita_c_struct_(_, base(_, [typedef(N2)]), Name) :- atom(N2), cpp_ita_c_struct(N2, Name).
%% ... A TAG IS A C STRUCT'S where no class of that name is registered, or where the one registered stands in an
%% `extern "C"' scope (`c' in the header index; 0.115): glibc's `struct _IO_FILE' is a library class once a header
%% load registers it, and `__is_posix_terminal(FILE *)' kept its plain name -- an undefined symbol at the link of
%% every std::print (`_ZNSt3__119__is_posix_terminalEP8_IO_FILE').
cpp_ita_c_tag(S) :- \+ cpp_class_known(S), !.
cpp_ita_c_tag(S) :- catch(cpp_hdr_ns(S, c), _, fail).
cpp_ita_c_tag(S) :- catch(cpp_hdr_ns(S, []), _, fail).   % ... OR IN THE GLOBAL NAMESPACE (0.134): glibc's `struct tm' stands before <time.h>'s `extern "C"' and is a library class once a header load registers it; a class at global scope is its bare name, `2tm'
cpp_ita_global(Name, Q, Subs0, Canon, Text, Subs) :- cpp_abi_tags(Name, Ts), cpp_ita_src(Name, Ts, C0),   % its ABI tags too (0.236)
    ( cpp_ita_sub(C0, Subs0, Code) -> T0 = Code, Subs1 = Subs0 ; T0 = C0, cpp_ita_note(C0, Subs0, Subs1) ),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C0, Canon), cpp_ita_wrap_cv(CV, Canon, T0, Subs1, Text, Subs) ; Canon = C0, Text = T0, Subs = Subs1 ).
%% THE CV-QUALIFIERS OF A TYPE as the mangling spells them (0.117): `V' for volatile, then `K' for const -- the group is ONE substitution candidate with its type
%% (`PVKv' is `void const volatile *'). Dropped, libc++'s `__cxx_atomic_notify_one(void const volatile *)' was called by a symbol no library exports.
cpp_ita_cv(Q, CV) :- ( memberchk(volatile, Q) -> V = 'V' ; V = '' ), ( memberchk(const, Q) -> K = 'K' ; K = '' ), atom_concat(V, K, CV).
cpp_ita_wrap_cv(CV, Canon, Inner, Subs0, Text, Subs) :-
    (   cpp_ita_sub(Canon, Subs0, Code) -> Text = Code, Subs = Subs0
    ;   atom_concat(CV, Inner, Text), cpp_ita_note(Canon, Subs0, Subs) ).
%% A COMPLEX TYPE is `C' and its real type's code, a substitution candidate as a pointer is (0.136; clang's `nn(_Complex double,
%% _Complex double)' is `ECdS0_'); a bare `_Complex' is a double's
cpp_ita_type_(base(Q, S), Subs0, Canon, Text, Subs) :- memberchk('_Complex', S), !, ccl_delete_one(S, '_Complex', S0), ( S0 == [] -> S1 = [double] ; S1 = S0 ),
    cpp_ita_type(base([], S1), Subs0, C0, T0, Subs1), atom_concat('C', C0, C1), cpp_ita_wrap(C1, T0, Subs1, T1, Subs2),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C1, Canon), cpp_ita_wrap_cv(CV, Canon, T1, Subs2, Text, Subs) ; Canon = C1, Text = T1, Subs = Subs2 ).
%% A VECTOR TYPE is `Dv' its lanes `_' and its element's code, a substitution candidate (0.162; clang++'s `k(f2, f2)' is
%% `_Z1kDv2_fS_'), a `vector_size' one and an `ext_vector_type' one alike, a bool vector's element `b'
cpp_ita_type_(base(Q, [vec(_, N, E)]), Subs0, Canon, Text, Subs) :- !, cpp_ita_type(E, Subs0, C0, T0, Subs1), atomic_list_concat(['Dv', N, '_', C0], C1),
    ( cpp_ita_sub(C1, Subs1, Code) -> T1 = Code, Subs2 = Subs1 ; atomic_list_concat(['Dv', N, '_', T0], T1), cpp_ita_note(C1, Subs1, Subs2) ),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C1, Canon), cpp_ita_wrap_cv(CV, Canon, T1, Subs2, Text, Subs) ; Canon = C1, Text = T1, Subs = Subs2 ).
cpp_ita_type_(base(Q, [auto]), Subs0, Canon, Text, Subs) :- !, ( memberchk(decltype_auto, Q) -> B = 'Dc' ; B = 'Da' ),   % A PLACEHOLDER (0.236): an instance's pattern's `auto' result `Da', `decltype(auto)' `Dc'
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, B, Canon), cpp_ita_wrap_cv(CV, Canon, B, Subs0, Text, Subs) ; Canon = B, Text = B, Subs = Subs0 ).
cpp_ita_type_(base(Q, S), Subs0, Canon, Text, Subs) :- cpp_mangle_basic(S, B), !,
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, B, Canon), cpp_ita_wrap_cv(CV, Canon, B, Subs0, Text, Subs) ; Canon = B, Text = B, Subs = Subs0 ).
cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_tparam(N, Code), !,   % a parameter WRITTEN as the template's own parameter is `T_', `T0_' ..., each a substitution candidate of its own
    cpp_ita_tp_use(Code, Subs0, T0, Subs1),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, Code, Canon), cpp_ita_wrap_cv(CV, Canon, T0, Subs1, Text, Subs) ; Canon = Code, Text = T0, Subs = Subs1 ).
cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs) :- atom(N), catch('$cpp_lname'(N, _, _), _, fail), once(cpp_local_name(N, [], C0, _)), !,   % A LOCAL TYPE (0.236): its local name, one candidate
    ( cpp_ita_sub(C0, Subs0, Code) -> T0 = Code, Subs1 = Subs0 ; once(cpp_local_name(N, Subs0, T0, Subs10)), cpp_ita_note(C0, Subs10, Subs1) ),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C0, Canon), cpp_ita_wrap_cv(CV, Canon, T0, Subs1, Text, Subs) ; Canon = C0, Text = T0, Subs = Subs1 ).
cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_class(N, Subs0, C0, T0, Subs1), !,
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C0, Canon), cpp_ita_wrap_cv(CV, Canon, T0, Subs1, Text, Subs) ; Canon = C0, Text = T0, Subs = Subs1 ).
cpp_ita_type_(base(Q, [struct(N, _)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs).
cpp_ita_type_(base(Q, [union(N, _)]), Subs0, Canon, Text, Subs) :- atom(N), N \== anon, cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs).   % ... and a plain union's, which resolves to a union since 0.201: in a namespace of the program `N2ns1VE', as a struct is (the global clause below took it, `1V')
cpp_ita_type_(base(Q, [class(_, N, _, _)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs).
cpp_ita_type_(base(Q, [S]), Subs0, Canon, Text, Subs) :- cpp_unnamed_spec(S), cpp_unnamed_member_name(S, Subs0, T0, Subs1), !, cpp_unnamed_member_name(S, [], C0, _),   % AN UNNAMED TYPE OF A CLASS (0.236): `N1UUt_E'
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C0, Canon), cpp_ita_wrap_cv(CV, Canon, T0, Subs1, Text, Subs) ; Canon = C0, Text = T0, Subs = Subs1 ).
cpp_ita_type_(base(Q, [E]), Subs0, Canon, Text, Subs) :- ( E = enum(N, _) ; E = enum_class(N, _) ), atom(N), \+ sub_atom(N, _, _, _, '.'), \+ catch(cpp_hdr_ns(N, _), _, fail), \+ catch('$cpp_type_ns'(N, _), _, fail), !, cpp_ita_global(N, Q, Subs0, Canon, Text, Subs).   % A GLOBAL ENUM OF THE PROGRAM is a global name, `1K' (0.110): taken to its name it resolved back to the enum and asked again without end -- libc++'s `__declval<K *&>' behind a std::array of an enum
cpp_ita_type_(base(Q, [enum(N, _)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs).   % A NESTED ENUM IS A NESTED NAME (0.94): `ios_base::seekdir' in `basic_streambuf<char>::seekoff', shipped as `NS_8ios_base7seekdirE'; the tag resolves to its enum spec, which no clause took, and the vtable named the slot by its plain name
cpp_ita_type_(base(Q, [enum_class(N, _)]), Subs0, Canon, Text, Subs) :- atom(N), cpp_ita_type_(base(Q, [typedef(N)]), Subs0, Canon, Text, Subs).
cpp_ita_type_(base(Q, [struct(N, _)]), Subs0, Canon, Text, Subs) :- atom(N), N \== anon, \+ cpp_class_known(N), \+ catch(cpp_hdr_ns(N, _), _, fail), !, cpp_ita_global(N, Q, Subs0, Canon, Text, Subs).   % a NAMED C struct reached through its tag: `struct tm' is `2tm'
cpp_ita_type_(base(Q, [union(N, _)]), Subs0, Canon, Text, Subs) :- atom(N), N \== anon, \+ cpp_class_known(N), \+ catch(cpp_hdr_ns(N, _), _, fail), !, cpp_ita_global(N, Q, Subs0, Canon, Text, Subs).
cpp_ita_type_(pack(T), Subs0, Canon, Text, Subs) :- !, cpp_ita_type(T, Subs0, C0, T0, Subs1), atom_concat('Dp', C0, Canon), atom_concat('Dp', T0, Text0), cpp_ita_whole(Canon, Text0, Subs1, Text, Subs).   % A PACK EXPANSION (0.236): `Dp <type>', `DpT_', a candidate
cpp_ita_type_(ptr(Q, T), Subs0, Canon, Text, Subs) :- cpp_ita_type(T, Subs0, C0, T0, Subs1), atom_concat('P', C0, C1), cpp_ita_wrap(C1, T0, Subs1, T1, Subs2),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C1, Canon), cpp_ita_wrap_cv(CV, Canon, T1, Subs2, Text, Subs) ; Canon = C1, Text = T1, Subs = Subs2 ).
cpp_ita_type_(ref(_, T), Subs0, Canon, Text, Subs) :- cpp_ita_type(T, Subs0, C0, T0, Subs1), atom_concat('R', C0, Canon), cpp_ita_wrap(Canon, T0, Subs1, Text, Subs).
cpp_ita_type_(rref(_, T), Subs0, Canon, Text, Subs) :- cpp_ita_type(T, Subs0, C0, T0, Subs1), atom_concat('O', C0, Canon), cpp_ita_wrap(Canon, T0, Subs1, Text, Subs).
%% A FUNCTION TYPE, AN ARRAY AND A POINTER TO MEMBER IN A MANGLED NAME (0.117): `F <result> <parameters> E' (`v' for none,
%% `z' for the ellipsis), `A <bound> _ <element>' and `M <class> <member type>' -- each a substitution candidate once
%% complete, as a pointer over it is. `std::set_terminate(void (*)())' is `_ZSt13set_terminatePFvvE', and without the
%% clause the type had no spelling, the name stayed this compiler's own and the link named `set_terminate'.
cpp_ita_type_(fn(Ret, Ps, V), Subs0, Canon, Text, Subs) :-
    cpp_ita_fn(Ret, Ps, V, Subs0, Canon, Text0, Subs2), cpp_ita_whole(Canon, Text0, Subs2, Text, Subs).
cpp_ita_type_(arr(NE, E), Subs0, Canon, Text, Subs) :-
    ( nonvar(NE), ccl_const_eval(NE, K) -> true ; K = '' ),
    cpp_ita_type(E, Subs0, EC, ET, Subs1),
    atomic_list_concat(['A', K, '_', EC], Canon), atomic_list_concat(['A', K, '_', ET], Text0), cpp_ita_whole(Canon, Text0, Subs1, Text, Subs).
cpp_ita_type_(memptr(C, _, T), Subs0, Canon, Text, Subs) :- atom(C),
    cpp_ita_type(base([], [typedef(C)]), Subs0, CC, CT, Subs1),
    (   ccl_resolve_type(T, fn(R, Ps, V))   % THE FUNCTION TYPE OF A POINTER TO MEMBER takes a place in the table and is never substituted (0.181), as clang's mangler has it: `_Z2k1PFiiEM1AFiiE', `_Z2k8M1AKFiiEM1BKFiiE' -- it was `M1AS_'
    ->  cpp_ita_fn(R, Ps, V, Subs1, TC, TT, Subs1b), atomic_list_concat(['M', CC, TC], Canon), cpp_ita_note('$mfn'(Canon), Subs1b, Subs2)   % ... a place of its own, keyed by the whole: the same pointer to member again is the whole's substitution, and takes none
    ;   cpp_ita_type(T, Subs1, TC, TT, Subs2), atomic_list_concat(['M', CC, TC], Canon) ),
    atomic_list_concat(['M', CT, TT], Text0), cpp_ita_whole(Canon, Text0, Subs2, Text, Subs).
%% A FUNCTION TYPE'S SPELLING: `[V][K] F <result> <parameters> [R|O] E', a member function type's qualifiers among it (0.181;
%% the reader's q(V, Qs)): `M1AKFiiE' for `int (A::*)(int) const', `M1AFiiOE' for `&&' -- the qualified type ONE candidate
cpp_ita_fn(Ret, Ps, V0, Subs0, Canon, Text, Subs) :- cpp_fn_q(V0, V, Qs),
    cpp_ita_type(Ret, Subs0, RC, RT, Subs1), cpp_ita_fparams(Ps, V, Subs1, PC, PT, Subs), cpp_ita_cv(Qs, CV), cpp_ita_refq(Qs, RQ),
    ( memberchk(noexcept, Qs) -> DO = 'Do' ; DO = '' ),   % a noexcept function type (0.198): `[V][K] Do F ... E', `PDoFvvE' for `void (*)() noexcept'
    atomic_list_concat([CV, DO, 'F', RC, PC, RQ, 'E'], Canon), atomic_list_concat([CV, DO, 'F', RT, PT, RQ, 'E'], Text).
cpp_ita_refq(Qs, R) :- ( memberchk('&&', Qs) -> R = 'O' ; memberchk('&', Qs) -> R = 'R' ; R = '' ).
%% a function type's parameters: each as the function's own would be -- an array or a function is the pointer it
%% decays to and a by-value parameter has no top-level const ([dcl.fct]/5) -- the canonical spelling beside the text
cpp_ita_fparams([], false, Subs, v, v, Subs) :- !.
cpp_ita_fparams(Ps, V, Subs0, Canon, Text, Subs) :- cpp_ita_fps(Ps, Subs0, C0, T0, Subs), ( V == true -> atom_concat(C0, z, Canon), atom_concat(T0, z, Text) ; Canon = C0, Text = T0 ).
cpp_ita_fps([], Subs, '', '', Subs).
cpp_ita_fps([P|Ps], Subs0, Canon, Text, Subs) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), !,
    cpp_ita_param_type(PT0, PT), cpp_ita_type(PT, Subs0, C1, T1, Subs1), cpp_ita_fps(Ps, Subs1, C2, T2, Subs), atom_concat(C1, C2, Canon), atom_concat(T1, T2, Text).
cpp_ita_fps([_|Ps], Subs0, Canon, Text, Subs) :- cpp_ita_fps(Ps, Subs0, Canon, Text, Subs).
cpp_ita_param_type(pack(T), pack(T)) :- !.   % a pack's expansion stays one (0.236): `DpT_'
cpp_ita_param_type(base(Q, [S]), base(Q1, [S])) :- cpp_ita_dependent, ( S = decltype(_) ; S = typedef(N), atom(N), cpp_ita_tparam(N, _) ; S = typedef(tmpl(_, As)), cpp_ita_dep_args(As) ), !, subtract(Q, [const, volatile], Q1).   % ... and the pattern's own words, unresolved
cpp_ita_param_type(T0, T) :- ccl_resolve_type(T0, T1),
    (   T1 = arr(_, E) -> T = ptr([], E)
    ;   T1 = fn(_, _, _) -> T = ptr([], T1)
    ;   T1 = base(Q, S), ( memberchk(const, Q) ; memberchk(volatile, Q) ) -> subtract(Q, [const, volatile], Q1), T = base(Q1, S)
    ;   T1 = ptr(Q, P), ( memberchk(const, Q) ; memberchk(volatile, Q) ) -> subtract(Q, [const, volatile], Q1), T = ptr(Q1, P)
    ;   T = T1 ).
cpp_ita_whole(Canon, Text0, Subs0, Text, Subs) :- ( cpp_ita_sub(Canon, Subs0, Code) -> Text = Code, Subs = Subs0 ; Text = Text0, cpp_ita_note(Canon, Subs0, Subs) ).
%% a layer's spelling: the whole known -> its code; else the layer's letter over the inner spelling, and noted
cpp_ita_wrap(Canon, Inner, Subs0, Text, Subs) :-
    (   cpp_ita_sub(Canon, Subs0, Code) -> Text = Code, Subs = Subs0
    ;   sub_atom(Canon, 0, 1, _, Letter), atom_concat(Letter, Inner, Text), cpp_ita_note(Canon, Subs0, Subs) ).
%% a class as a TYPE: its nested name `N <prefix> <chain> E' (`St<len>name' for a name directly in std), the whole a
%% candidate; the class must be a library's, with a namespace path (cpp_class_scope)
cpp_ita_class(N, Subs0, Canon, Text, Subs) :-
    cpp_class_scope(N, Path, Chain),
    cpp_ita_ns(Path, '', '', Subs0, C0, T0, Subs1),
    (   Path == [std], Chain = [plain(Last)]
    ->  ccl_byte_length(Last, L), atomic_list_concat(['St', L, Last], Canon), ( cpp_ita_sub(Canon, Subs1, Code) -> Text = Code, Subs = Subs1 ; Text = Canon, cpp_ita_note(Canon, Subs1, Subs) )
    ;   Path == [], Chain = [L1]   % AN UNSCOPED NAME (0.180), a class of the program at file scope or its template's instance: `1A', `3BoxIiE', no `N ... E'
    ->  cpp_ita_last_level(L1, C0, T0, Subs1, Canon, T1, Subs2), ( cpp_ita_sub(Canon, Subs2, Code) -> Text = Code, Subs = Subs2 ; Text = T1, cpp_ita_note(Canon, Subs2, Subs) )
    ;   cpp_ita_chain_type(Chain, C0, T0, Subs1, C1, T1, Subs2),
        Canon = C1,                                                                                  % THE KEY IS THE CHAIN'S OWN, as a prefix level's is: the ABI counts `basic_istream<char>' the prefix and the type as ONE entity
        ( cpp_ita_sub(Canon, Subs2, Code) -> Text = Code, Subs = Subs2 ; atomic_list_concat(['N', T1, 'E'], Text), cpp_ita_note(Canon, Subs2, Subs) ) ).
%% ... a key with `N ... E' around it matched no prefix level, so `basic_istream<char>::sentry::sentry(basic_istream<char> &,
%% bool)' spelled its parameter afresh, `RNS0_IcS2_EE', where the library has `RS3_' -- the instance noted as the
%% constructor's own prefix; the sentry constructors were the two symbols the link named.
%% the chain of a TYPE: every level but the last is a prefix candidate; the last is the type's own (noted whole above)
cpp_ita_chain_type([L], C0, T0, Subs0, C, T, Subs) :- !, cpp_ita_last_level(L, C0, T0, Subs0, C, T, Subs).
cpp_ita_chain_type([L|Ls], C0, T0, Subs0, C, T, Subs) :- cpp_ita_chain([L], C0, T0, Subs0, C1, T1, Subs1), cpp_ita_chain_type(Ls, C1, T1, Subs1, C, T, Subs).
cpp_ita_last_level(plain(N), C0, T0, Subs, C, T, Subs) :- ccl_byte_length(N, L), atomic_list_concat([C0, L, N], C), atomic_list_concat([T0, L, N], T).
cpp_ita_last_level(plain(N, Ts), C0, T0, Subs, C, T, Subs) :- cpp_ita_src(N, Ts, Src), atom_concat(C0, Src, C), atom_concat(T0, Src, T).
cpp_ita_last_level(inst(N, Args), C0, T0, Subs0, C, T, Subs) :- cpp_ita_last_level(inst(N, Args, []), C0, T0, Subs0, C, T, Subs).
cpp_ita_last_level(inst(N, Args, Ts), C0, T0, Subs0, C, T, Subs) :-
    cpp_ita_src(N, Ts, Src), atom_concat(C0, Src, C1), cpp_ita_level(C1, T0, '', Src, Subs0, T1, Subs1),   % the template-name prefix IS a candidate
    cpp_ita_targs_t(N, Args, Subs1, ACanon, AText, Subs), atomic_list_concat([C1, 'I', ACanon, 'E'], C), atomic_list_concat([T1, 'I', AText, 'E'], T).
%% the substitution table: a key's code by its position, S_ then S0_ S1_ ... in base 36
cpp_ita_sub(Key, Subs, Code) :- cpp_ita_index(Subs, Key, 0, I), cpp_ita_code(I, Code).
cpp_ita_index([K|_], K, I, I) :- !.
cpp_ita_index([_|Ks], K, I0, I) :- I1 is I0 + 1, cpp_ita_index(Ks, K, I1, I).
cpp_ita_code(0, 'S_') :- !.
cpp_ita_code(I, Code) :- I1 is I - 1, cpp_base36(I1, D), atomic_list_concat(['S', D, '_'], Code).
cpp_base36(N, D) :- N < 36, !, cpp_digit36(N, D).
cpp_base36(N, D) :- Q is N // 36, R is N mod 36, cpp_base36(Q, D1), cpp_digit36(R, D2), atom_concat(D1, D2, D).
cpp_digit36(N, D) :- ( N < 10 -> C is 48 + N ; C is 55 + N ), atom_codes(D, [C]).
cpp_ita_note(Key, Subs0, Subs) :- ( memberchk(Key, Subs0) -> Subs = Subs0 ; append(Subs0, [Key], Subs) ).
%% WHERE A LIBRARY CLASS LIVES: its namespace path and its chain of classes from the outermost -- a plain class, a
%% nested one (through '$cpp_enclosing'), a template's instance or specialization by its template and arguments
cpp_class_scope(C, Path, Chain) :- atom(C), cpp_class_scope_(C, Path, Chain).
cpp_class_scope_(C, Path, Chain) :- cpp_enclosing(C, Enc), !, cpp_class_scope_(Enc, Path, Chain0), cpp_last_segment(C, Last), cpp_ita_plain(C, Last, Lv), append(Chain0, [Lv], Chain).
cpp_class_scope_(C, Path, Chain) :- ccl_tag(C, Ms), ccl_is_enum_tag(Ms), once('$cpp_ctype'(Enc, Last, base([], [typedef(C)]))), cpp_last_segment(C, Last), !,   % ... THE HOLDER'S TYPE OF THAT NAME (0.117): an alias is no holder -- `typedef _Tp value_type' of `__split_buffer<std::byte, ...>' made std::byte "__split_buffer<byte, ...>::value_type", and the mangler walked it for ever (`vector<std::byte>': 4 GB in ten seconds)   % a NESTED ENUM (0.94): recorded as a type of its holder (cpp_nested_names), never in '$cpp_enclosing'
    cpp_class_scope_(Enc, Path, Chain0), append(Chain0, [plain(Last)], Chain).
cpp_class_scope_(C, Path, [Lv]) :- '$cpp_inst'(C, inst(N, Args)), !, ( cpp_hdr_ns(N, P0) -> P0 = [_|_], Path = P0, L = N ; cpp_prog_scope(N, Path), cpp_last_segment(N, L) ),
    ( cpp_abi_tags(N, Ts), Ts \== [] -> Lv = inst(L, Args, Ts) ; Lv = inst(L, Args) ).   % its template's ABI tags (0.236)
cpp_class_scope_(C, Path, [Lv]) :- cpp_hdr_ns(C, Path), Path = [_|_], cpp_ita_plain(C, C, Lv).
cpp_class_scope_(C, Path, [Lv]) :- \+ catch(cpp_hdr_ns(C, _), _, fail), ( catch('$cpp_type_ns'(C, _), _, fail) -> true ; cpp_class_known(C), \+ cpp_lib_class(C) ), cpp_prog_scope(C, Path), cpp_last_segment(C, L), cpp_ita_plain(C, L, Lv).
%% A TYPE OF THE PROGRAM (0.180), for the type information's names, which clang spells: at file scope or in a namespace of
%% its own (`1A', `N2ns1AE', a plain struct's too, `N2ns1PE'), its template's instance (`3BoxIiE'), nested (above:
%% `N5Outer5InnerE'); a local class's or a closure's name, which has a dot, none; the program's functions keep this
%% compiler's names
cpp_prog_scope(N, Path) :- atom(N), catch('$cpp_type_ns'(N, P), _, fail), !, Path = P.
cpp_prog_scope(N, []) :- atom(N), \+ sub_atom(N, _, _, _, '.'), \+ catch('$cpp_lib'(N), _, fail).
cpp_last_segment(C, Last) :- atomic_list_concat(Segs, '.', C), ccl_last(Segs, Last).
cpp_mangle_ns([std|Rest], T) :- !, cpp_mangle_ns_(Rest, R), atom_concat('St', R, T).     % St is std's own abbreviation
cpp_mangle_ns(Path, T) :- cpp_mangle_ns_(Path, T).
cpp_mangle_ns_([], '').
cpp_mangle_ns_([N|Ns], T) :- atom(N), ccl_byte_length(N, L), cpp_mangle_ns_(Ns, R), atomic_list_concat([L, N, R], T).
%% the builtin types' codes (the Itanium mangler above spells a class, a pointer, a reference over them)
cpp_mangle_basic(S, v) :- memberchk(void, S), !.
cpp_mangle_basic(S, 'Dn') :- memberchk(nullptr_t, S), !.        % std::nullptr_t (0.206)
cpp_mangle_basic(S, 'DF16_') :- memberchk('_Float16', S), !.   % THE REST OF THE BUILTIN TYPES (0.136), clang's and gcc's codes: _Float16,
cpp_mangle_basic(S, 'Df') :- memberchk('_Decimal32', S), !.     % the decimal floating types (gcc's; clang has none),
cpp_mangle_basic(S, 'Dd') :- memberchk('_Decimal64', S), !.
cpp_mangle_basic(S, 'De') :- memberchk('_Decimal128', S), !.
cpp_mangle_basic(S, C) :- memberchk(bitint(E), S), !, ccl_bitint_width(E, W), ( memberchk(unsigned, S) -> P = 'DU' ; P = 'DB' ), atomic_list_concat([P, W, '_'], C).   % _BitInt(N): DB<N>_, unsigned DU<N>_
cpp_mangle_basic(S, b) :- ( memberchk(bool, S) ; memberchk('_Bool', S) ), !.
cpp_mangle_basic(S, w) :- memberchk(wchar_t, S), !.
cpp_mangle_basic(S, 'Ds') :- memberchk(char16_t, S), !.
cpp_mangle_basic(S, 'Di') :- memberchk(char32_t, S), !.
cpp_mangle_basic(S, 'Du') :- memberchk(char8_t, S), !.
cpp_mangle_basic(S, C) :- memberchk('__int128', S), !, ( memberchk(unsigned, S) -> C = o ; C = n ).   % GNU's 128-bit integer (0.117): `n' and `o'
cpp_mangle_basic(S, C) :- memberchk(char, S), !, ( memberchk(signed, S) -> C = a ; memberchk(unsigned, S) -> C = h ; C = c ).
cpp_mangle_basic(S, C) :- memberchk(short, S), !, ( memberchk(unsigned, S) -> C = t ; C = s ).
cpp_mangle_basic(S, C) :- ccl_count(long, S, 2), !, ( memberchk(unsigned, S) -> C = y ; C = x ).
cpp_mangle_basic(S, C) :- memberchk(long, S), !,
    ( memberchk(double, S) -> C = e ; memberchk(unsigned, S) -> C = m ; C = l ).
cpp_mangle_basic(S, f) :- memberchk(float, S), !.
cpp_mangle_basic(S, d) :- memberchk(double, S), !.
cpp_mangle_basic(S, C) :- ( memberchk(int, S) ; memberchk(signed, S) ; memberchk(unsigned, S) ), !,
    ( memberchk(unsigned, S) -> C = j ; C = i ).
cpp_fn_overloaded(F) :- atom(F), atomic_list_concat([op, _, K], '.', F), atom_number(K, _), !.   % A FREE OPERATOR SET'S NAME, `op.eq.2' exactly (an instance of one, `op.lt.2.c21.char...', is one function under its own name), IS ALWAYS AN OVERLOAD SET: every class's hidden friend `operator==' is `op.eq.2', and the first registered -- __tree_iterator's, alone at that moment -- was declared under the bare name, so once the others arrived the call's `op.eq.2.<keys>' named nothing and `__i == end()' stayed a comparison of two structs
cpp_fn_overloaded(F) :- '$cpp_fn'(F, K1, _, yes, _), '$cpp_fn'(F, K2, _, yes, _), K1 \== K2, !.
cpp_fn_overloaded(F) :- '$cpp_fn'(F, K1, Ps1, yes, _), '$cpp_fn'(F, K2, Ps2, no, _), K1 \== K2, cpp_params_surely_differ(Ps1, Ps2), !.   % ONE DEFINITION BESIDE A DECLARATION OF OTHER PARAMETERS (0.181, below)
%% ---- A CLASS'S ABI TAGS (0.236; the Itanium ABI's <abi-tags>, GCC's `abi_tag', as clang spells them) -----------------
%% `B <source-name>' after the class's name, each tag once and sorted (the reader's marker abi_tag(Tags)), the name with its
%% tags one level of the prefix: `1SB2v1', `N2ns1TB2t2E', libc++ 18's views `NSt3__16ranges11single_viewB10llvm18_nuaIiEE'.
%% They were dropped, and the type information named a tagged class as an untagged one
cpp_ita_src(N, Ts, Src) :- ccl_byte_length(N, L), findall(B, ( member(T, Ts), ccl_byte_length(T, TL), atomic_list_concat(['B', TL, T], B) ), Bs), atomic_list_concat([L, N|Bs], Src).
cpp_ita_plain(C, Last, Lv) :- ( cpp_abi_tags(C, Ts), Ts \== [] -> Lv = plain(Last, Ts) ; Lv = plain(Last) ).
cpp_abi_tags(C, Ts) :- atom(C), catch('$cpp_abi_tag'(C, Ts0), _, fail), !, Ts = Ts0.
cpp_abi_tags(C, Ts) :- atom(C), catch(ccl_tag(C, Ms), _, fail), is_list(Ms), memberchk(abi_tag(Ts0), Ms), !, Ts = Ts0.
cpp_abi_tags(N, Ts) :- atom(N), catch('$cpp_tmpl'(N, _, Item), _, fail), cpp_template_class_def(Item), Item = declare(_, base(_, [S])),
    ( S = class(_, _, _, Ms) ; S = struct(_, Ms) ; S = union(_, Ms) ), is_list(Ms), memberchk(abi_tag(Ts0), Ms), !, Ts = Ts0.   % a class template's, for its instances
cpp_abi_tags(_, []).
%% ---- LOCAL NAMES AND CLOSURES (0.236; Itanium 5.1.6 <local-name>, 5.1.8 <closure-type-name>, as clang 18 spells them) ----
%% A local class, a closure and an unnamed local class are named in their function: `Z <its encoding> E <entity>
%% [<discriminator>]' -- `Z4mainE1L', `ZN1K1fEvEUlvE_', `ZNK1C1mEiE1L', and a second local class of one name in one function
%% `Z3ilfvE1L_0'. The encoding is the function's own: its namespaces and class (`ZN2ns2in2nfEvE', a static one `ZL2sfvE', an
%% `extern "C"' one and `main' their names alone, `Z2cfE'), a constructor `C1', a destructor `D1', a closure's call operator
%% a local name of its own (`ZZ3ilfvENKUlvE_clEvE'), a function template's instance its arguments, its result and its
%% parameters as its pattern writes them (`Z2tfIiET_S0_E', a pack `DpT_', a decltype `DTplfp_Li1EE'). A closure where the
%% ABI asks one name in every unit -- an inline function, a member defined in its class, a template's instance, a closure's
%% call operator -- is `Ul <its parameters> E [n] _', numbered among the closures of those parameters there (`UliE_',
%% `UliE0_'); an unnamed local class there `Ut [n] _'. Elsewhere clang names either `$_N', numbered in its function in the
%% order the walk makes them, one at file scope by the count of all of them before its first name (`3$_3'). The names
%% were this compiler's (`14lambda3_hijdpb', `16L.local_1_hijdpb'), and three closures shared one.
%% The notes, made where the class is made: '$cpp_lname'(Name, Encl, Entity), Entity named(Src, D), ul(Ps, TPs, Sig, K),
%% anon(K), ut(K) or gnum (a closure at file scope, numbered at its first name)
cpp_local_note(_, Name, _) :- catch('$cpp_lname'(Name, _, _), _, fail), !.
cpp_local_note(_, _, _) :- nb_current('$cpp_in_lib', yes), !.   % the library's keep this compiler's names: they move no number of the program's
cpp_local_note(closure(Ps, TPs), Name, Encl) :- Encl \== none, cpp_lstable(Encl), catch(cpp_lsig(Ps, TPs, [], Sig, _), _, fail), !,
    cpp_lcount(Encl-ul(Sig), K), assertz('$cpp_lname'(Name, Encl, ul(Ps, TPs, Sig, K))).
cpp_local_note(closure(Ps, TPs), Name, none) :- nb_current('$cpp_gvar_now', gv(V, Sto)), cpp_sto_word(Sto, inline), catch(cpp_lsig(Ps, TPs, [], Sig, _), _, fail), !,   % an inline variable's: `N3lamMUliE_E'
    cpp_lcount(gv(V)-ul(Sig), K), assertz('$cpp_lname'(Name, var(V), ul(Ps, TPs, Sig, K))).
cpp_local_note(closure(_, _), Name, none) :- !, ( nb_current('$cpp_gvar_now', gv(V, _)) -> W = var(V) ; W = none ), assertz('$cpp_lname'(Name, none, gnum(W))).   % any other at file scope, in its variable's namespaces: `N2ns3$_4E'
cpp_local_note(closure(_, _), Name, Encl) :- !, cpp_lcount(Encl-anon, K), cpp_lcount(total, _), assertz('$cpp_lname'(Name, Encl, anon(K))).
cpp_local_note(named(Src), Name, Encl) :- !, cpp_lcount(Encl-named(Src), D), assertz('$cpp_lname'(Name, Encl, named(Src, D))).
cpp_local_note(anon, Name, Encl) :- Encl \== none, cpp_lstable(Encl), !, cpp_lcount(Encl-ut, K), assertz('$cpp_lname'(Name, Encl, ut(K))).
cpp_local_note(anon, Name, Encl) :- cpp_lcount(Encl-anon, K), cpp_lcount(total, _), assertz('$cpp_lname'(Name, Encl, anon(K))).
cpp_lcount(Key0, K) :- cpp_lcount_key(Key0, Key), ( retract('$cpp_lcount'(Key, K0)) -> K = K0 ; K = 0 ), K1 is K + 1, assertz('$cpp_lcount'(Key, K1)).
cpp_lcount_key(F-X, C-X) :- !, cpp_lctx(F, C).
cpp_lcount_key(K, K).
%% a closure's call operator is its closure's, whichever walk describes it: the walk that deduces its result, or its body's
cpp_lctx(fsig(member, C, operator('()'), _, _, _, _, _), cl(C)) :- atom(C), catch('$cpp_pf_closure'(C, _, _), _, fail), !.
cpp_lctx(F, F).
%% a function whose definition other units may hold, so its closures are named alike in each (Itanium 5.1.8)
cpp_lstable(fsig(free, _, _, _, _, _, Qs, TA)) :- !, ( TA \== none -> true ; memberchk(inline, Qs) ).
cpp_lstable(fsig(member, C, _, _, _, _, Qs, TA)) :- !,
    ( TA \== none -> true ; atom(C), catch('$cpp_pf_closure'(C, _, _), _, fail) -> true ; atom(C), catch('$cpp_lname'(C, _, _), _, fail) -> true ; atom(C), catch('$cpp_inst'(C, _), _, fail) -> true ; \+ memberchk(out_of_line, Qs) ).
cpp_lstable(fsig(K, _, _, _, _, _, Qs, _)) :- memberchk(K, [ctor, dtor]), \+ memberchk(out_of_line, Qs).
%% the name of a local type, for its type information and wherever the mangler meets it
cpp_local_type_name(C, N) :- atom(C), catch('$cpp_lname'(C, Encl, Ent), _, fail), once(cpp_local_name(C, [], N, _)),
    ( Ent = named(_, _), Encl \== none, Encl \= var(_), \+ cpp_lstable(Encl), \+ catch('$cpp_nolink'(N), _, fail) -> assertz('$cpp_nolink'(N)) ; true ).   % a local class of no linkage: its type information internal (ir_rtti_link/2)
cpp_local_name(C, Subs0, Text, Subs) :- '$cpp_lname'(C, Encl, Ent),
    (   Encl == none -> cpp_lent(C, Ent, Subs0, Text, Subs)
    ;   Encl = var(V) -> cpp_lvar_prefix(V, Subs0, PT, Subs1), cpp_lent(C, Ent, Subs1, NT, Subs), atomic_list_concat(['N', PT, NT, 'E'], Text)   % an inline variable's: its data member prefix, `3lamM'
    ;   cpp_lenc(Encl, Subs0, ET, Subs1), cpp_lent(C, Ent, Subs1, NT, Subs), atomic_list_concat(['Z', ET, 'E', NT], Text) ).
%% the entity: a name and its discriminator, a closure, an unnamed class
cpp_lent(_, named(Src, D), Subs, Text, Subs) :- !, ccl_byte_length(Src, L), cpp_ldisc(D, DT), atomic_list_concat([L, Src, DT], Text).
cpp_lent(_, ul(Ps, TPs, _, K), Subs0, Text, Subs) :- !, cpp_lsig(Ps, TPs, Subs0, Sig, Subs), cpp_lnum(K, KT), atomic_list_concat(['Ul', Sig, 'E', KT, '_'], Text).
cpp_lent(_, ut(K), Subs, Text, Subs) :- !, cpp_lnum(K, KT), atomic_list_concat(['Ut', KT, '_'], Text).
cpp_lent(_, anon(K), Subs, Text, Subs) :- !, cpp_lanon(K, Text).
cpp_lent(C, gnum(W), Subs0, Text, Subs) :- ( '$cpp_lgid'(C, K) -> true ; cpp_lcount(total, K), assertz('$cpp_lgid'(C, K)) ), cpp_lanon(K, T0),
    ( W = var(V), cpp_lenc_path(V, Path, _), Path \== [] -> cpp_ita_ns(Path, '', '', Subs0, _, P, Subs), atomic_list_concat(['N', P, T0, 'E'], Text) ; Text = T0, Subs = Subs0 ).
%% <data-member-prefix>: the variable's namespaces, its name, `M' -- one candidate
cpp_lvar_prefix(smem(C, N), Subs0, Text, Subs) :- !, cpp_class_scope(C, Path, Chain), cpp_ita_prefix(Path, Chain, Subs0, PT, Subs1),   % a static data member's: its class, its name, `1K2siM'
    ccl_byte_length(N, L), atomic_list_concat([L, N, 'M'], Src), atom_concat(PT, Src, Text), cpp_ita_note(Text, Subs1, Subs).
cpp_lvar_prefix(V, Subs0, Text, Subs) :- cpp_lenc_path(V, Path, S), ccl_byte_length(S, L), atomic_list_concat([L, S, 'M'], Src),
    cpp_ita_ns(Path, '', '', Subs0, C0, T0, Subs1), atom_concat(C0, Src, C1), cpp_ita_level(C1, T0, '', Src, Subs1, Text, Subs).
cpp_lanon(K, Text) :- atomic_list_concat(['$_', K], S), ccl_byte_length(S, L), atomic_list_concat([L, S], Text).
cpp_lnum(0, '') :- !.
cpp_lnum(K, T) :- K1 is K - 1, atom_number(T, K1).
cpp_ldisc(0, '') :- !.
cpp_ldisc(D, T) :- D1 is D - 1, ( D1 < 10 -> atomic_list_concat(['_', D1], T) ; atomic_list_concat(['__', D1, '_'], T) ).
%% a closure's <lambda-sig>: its explicit template parameters declared (`Ty', `Tn <type>', `Tp' before a pack), then its
%% parameters' types, an `auto' the template parameter it invents (`T_', the explicit ones first), `v' for none
cpp_lsig(Ps, TPs, Subs0, Text, Subs) :-
    cpp_lsig_decls(TPs, 0, N, Subs0, DT, Subs1, Refs),
    ( nb_current('$cpp_ita_tps', Old) -> true ; Old = [] ), nb_setval('$cpp_ita_tps', Refs),
    (   catch(cpp_lsig_params(Ps, N, Subs1, PT, Subs), E, ( nb_setval('$cpp_ita_tps', Old), throw(E) )) -> nb_setval('$cpp_ita_tps', Old)
    ;   nb_setval('$cpp_ita_tps', Old), fail ),
    atom_concat(DT, PT, Text).
cpp_lsig_decls([], N, N, Subs, '', Subs, []).
cpp_lsig_decls([tparam(K, P, _)|TPs], I, N, Subs0, Text, Subs, [P-Code|Rs]) :- !, cpp_ita_tp_code(I, Code), I1 is I + 1,
    cpp_lsig_decl(K, Subs0, D, Subs1), cpp_lsig_decls(TPs, I1, N, Subs1, T2, Subs, Rs), atom_concat(D, T2, Text).
cpp_lsig_decls([_|TPs], I, N, Subs0, Text, Subs, Rs) :- cpp_lsig_decls(TPs, I, N, Subs0, Text, Subs, Rs).
cpp_lsig_decl(type, Subs, 'Ty', Subs) :- !.
cpp_lsig_decl(pack, Subs, 'TpTy', Subs) :- !.
cpp_lsig_decl(vpack(VT), Subs0, D, Subs) :- !, cpp_ita_type(VT, Subs0, _, T, Subs), atom_concat('TpTn', T, D).
cpp_lsig_decl(VT, Subs0, D, Subs) :- VT \== template, cpp_ita_type(VT, Subs0, _, T, Subs), atom_concat('Tn', T, D).
cpp_lsig_params([], _, Subs, v, Subs) :- !.
cpp_lsig_params(Ps, N, Subs0, Text, Subs) :- cpp_lsig_ps(Ps, N, Subs0, Text, Subs).
cpp_lsig_ps([], _, Subs, '', Subs).
cpp_lsig_ps([P|Ps], I0, Subs0, Text, Subs) :- ( P = param(T, _) ; P = param(T, _, _) ), !,
    cpp_lsig_type(T, I0, I1, Subs0, _, T1, Subs1), cpp_lsig_ps(Ps, I1, Subs1, T2, Subs), atom_concat(T1, T2, Text).
cpp_lsig_ps([_|Ps], I, Subs0, Text, Subs) :- cpp_lsig_ps(Ps, I, Subs0, Text, Subs).
%% a parameter's type with its `auto's: each the next invented parameter, `T_' noted as a candidate where first met
cpp_lsig_type(base(Q, [auto]), I0, I, Subs0, Canon, Text, Subs) :- !, I is I0 + 1, cpp_ita_tp_code(I0, Code), cpp_ita_tp_use(Code, Subs0, T0, Subs1),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, Code, Canon), cpp_ita_wrap_cv(CV, Canon, T0, Subs1, Text, Subs) ; Canon = Code, Text = T0, Subs = Subs1 ).
cpp_lsig_type(pack(T), I0, I, Subs0, Canon, Text, Subs) :- !, cpp_lsig_type(T, I0, I, Subs0, C0, T0, Subs1), atom_concat('Dp', C0, Canon), atom_concat('Dp', T0, Text0), cpp_ita_whole(Canon, Text0, Subs1, Text, Subs).
cpp_lsig_type(ptr(Q, T), I0, I, Subs0, Canon, Text, Subs) :- cpp_has_auto(T), !, cpp_lsig_type(T, I0, I, Subs0, C0, T0, Subs1), atom_concat('P', C0, C1), cpp_ita_wrap(C1, T0, Subs1, T1, Subs2),
    ( cpp_ita_cv(Q, CV), CV \== '' -> atom_concat(CV, C1, Canon), cpp_ita_wrap_cv(CV, Canon, T1, Subs2, Text, Subs) ; Canon = C1, Text = T1, Subs = Subs2 ).
cpp_lsig_type(ref(_, T), I0, I, Subs0, Canon, Text, Subs) :- cpp_has_auto(T), !, cpp_lsig_type(T, I0, I, Subs0, C0, T0, Subs1), atom_concat('R', C0, Canon), cpp_ita_wrap(Canon, T0, Subs1, Text, Subs).
cpp_lsig_type(rref(_, T), I0, I, Subs0, Canon, Text, Subs) :- cpp_has_auto(T), !, cpp_lsig_type(T, I0, I, Subs0, C0, T0, Subs1), atom_concat('O', C0, Canon), cpp_ita_wrap(Canon, T0, Subs1, Text, Subs).
cpp_lsig_type(T0, I, I, Subs0, Canon, Text, Subs) :- cpp_ita_param_type(T0, T), cpp_ita_type(T, Subs0, Canon, Text, Subs).
%% THE ENCODING OF THE FUNCTION a local entity is named in
cpp_lenc(fsig(free, _, N, Ret, Ps, V, Qs, TA), Subs0, Text, Subs) :- !, cpp_lenc_free(N, Ret, Ps, V, Qs, TA, Subs0, Text, Subs).
cpp_lenc(fsig(member, C, _, _, Ps, V, Qs, none), Subs0, Text, Subs) :- atom(C), catch('$cpp_pf_closure'(C, _, WPs), _, fail), !,   % a closure's call operator: a member of the closure, its parameters as written
    ( memberchk(const, Qs) -> K = 'K' ; K = '' ), ( WPs == none -> Ps1 = Ps ; Ps1 = WPs ),
    cpp_lenc_member(C, K, text(cl), Ps1, V, Subs0, Text, Subs).
cpp_lenc(fsig(member, C, M, _, Ps, V, Qs, none), Subs0, Text, Subs) :- !,
    ( memberchk(const, Qs), \+ memberchk(static, Qs) -> K0 = 'K' ; K0 = '' ), ( memberchk(volatile, Qs) -> V0 = 'V' ; V0 = '' ), atom_concat(V0, K0, K),
    cpp_lenc_member(C, K, M, Ps, V, Subs0, Text, Subs).
cpp_lenc(fsig(member, C, M, Ret, Ps, V, Qs, ta(TPs, B)), Subs0, Text, Subs) :- atom(C), atom(M), \+ catch('$cpp_pf_closure'(C, _, _), _, fail), !,   % a member template's instance: `ZN1E2mtIdEEvT_E'
    ( memberchk(const, Qs), \+ memberchk(static, Qs) -> K = 'K' ; K = '' ), cpp_ita_tparams(TPs, 0, Refs), cpp_ita_bound_args(TPs, B, Args),
    cpp_lenc_with_pattern(Refs, Ps, cpp_lenc_minst(C, K, M, TPs, Args, Ret, Ps, V, Subs0, Text, Subs)).
cpp_lenc(fsig(ctor, C, _, _, Ps, V, _, _), Subs0, Text, Subs) :- !, cpp_lenc_member(C, '', text('C1'), Ps, V, Subs0, Text, Subs).
cpp_lenc(fsig(dtor, C, _, _, _, _, _, _), Subs0, Text, Subs) :- cpp_lenc_member(C, '', text('D1'), [], false, Subs0, Text, Subs).
%% a member: `N [K] <its class> <its name> E <parameters>', a member of a local class `Z <encoding> E N ... E' -- the
%% local class's own name inside the nested name
cpp_lenc_member(C, K, M, Ps, V, Subs0, Text, Subs) :- catch('$cpp_lname'(C, Encl, Ent), _, fail), !,
    ( Encl == none -> Pre = '', Subs1 = Subs0 ; cpp_lenc(Encl, Subs0, ET, Subs1), atomic_list_concat(['Z', ET, 'E'], Pre) ),
    cpp_lent(C, Ent, Subs1, CT, Subs2), cpp_ita_note(CT, Subs2, Subs3), cpp_lenc_mtext(M, Ps, Subs3, MT, Subs4),
    cpp_lenc_params(C, Ps, V, Subs4, PT, Subs), atomic_list_concat([Pre, 'N', K, CT, MT, 'E', PT], Text).
cpp_lenc_member(C, K, M, Ps, V, Subs0, Text, Subs) :- cpp_class_scope(C, Path, Chain), cpp_ita_prefix(Path, Chain, Subs0, PText, Subs1),
    cpp_lenc_mtext(M, Ps, Subs1, MT, Subs2), cpp_lenc_params(C, Ps, V, Subs2, PT, Subs), atomic_list_concat(['N', K, PText, MT, 'E', PT], Text).
%% a member's own name: an operator's code, a conversion function's `cv <type>', a constructor's `C1'
cpp_lenc_mtext(text(T), _, Subs, T, Subs) :- !.
cpp_lenc_mtext(operator(conv(T)), _, Subs0, Text, Subs) :- !, cpp_ita_type(T, Subs0, _, TT, Subs), atom_concat(cv, TT, Text).
cpp_lenc_mtext(M, Ps, Subs, Text, Subs) :- cpp_ita_member_text(M, Ps, Text).
cpp_lenc_params(C, Ps, V, Subs0, Text, Subs) :- ( atom(C), catch(cpp_in_class(C, cpp_plain_params(Ps, Ps1)), _, fail) -> true ; Ps1 = Ps ), cpp_ita_fparams(Ps1, V, Subs0, _, Text, Subs).
%% a free function: its C name alone where it has C's linkage (and `main'), else its namespaces, `L' for internal linkage,
%% its parameters; a template's instance its arguments, its result and its parameters in its pattern's words
cpp_lenc_free(N, _, _, _, Qs, none, Subs, Text, Subs) :- atom(N), ( memberchk(c_link, Qs) ; N == main ), !, cpp_last_segment(N, S), ccl_byte_length(S, L), atomic_list_concat([L, S], Text).
cpp_lenc_free(N, _, Ps, V, Qs, none, Subs0, Text, Subs) :- !, cpp_lenc_fname(N, Ps, Qs, Subs0, NT, Subs1),
    ( catch(cpp_resolved_params(Ps, Ps1), _, fail) -> true ; Ps1 = Ps ), cpp_ita_fparams(Ps1, V, Subs1, _, PT, Subs), atom_concat(NT, PT, Text).
cpp_lenc_free(N, Ret, Ps, V, _, ta(TPs, B), Subs0, Text, Subs) :- atom(N),
    cpp_ita_tparams(TPs, 0, Refs), cpp_ita_bound_args(TPs, B, Args),
    cpp_lenc_with_pattern(Refs, Ps, cpp_lenc_inst(N, TPs, Args, Ret, Ps, V, Subs0, Text, Subs)).   % the pattern's words: its parameters named `fp_' in an expression
cpp_lenc_minst(C, K, M, TPs, Args, Ret, Ps, V, Subs0, Text, Subs) :- cpp_class_scope(C, Path, Chain),
    cpp_ita_ns(Path, '', '', Subs0, C0, T0, Subs1), cpp_ita_chain(Chain, C0, T0, Subs1, C1, T1, Subs2),
    ccl_byte_length(M, L), atomic_list_concat([L, M], Src), atom_concat(C1, Src, C2), cpp_ita_level(C2, T1, '', Src, Subs2, T2, Subs3),   % the template-prefix, a candidate
    cpp_ita_fn_targs(TPs, Args, Subs3, AT, Subs4), cpp_ita_type(Ret, Subs4, _, RT, Subs5), cpp_ita_fparams(Ps, V, Subs5, _, PT, Subs),
    atomic_list_concat(['N', K, T2, 'I', AT, 'E', 'E', RT, PT], Text).
%% a goal in a pattern's words: its template parameters `T_' ..., its function parameters `fp_' ...
cpp_lenc_with_pattern(Refs, Ps, Goal) :- ( nb_current('$cpp_ita_tps', Old) -> true ; Old = [] ), nb_setval('$cpp_ita_tps', Refs), nb_setval('$cpp_ita_fps', fps(Ps)),
    (   catch(Goal, E, ( nb_setval('$cpp_ita_tps', Old), nb_setval('$cpp_ita_fps', none), throw(E) )) -> nb_setval('$cpp_ita_tps', Old), nb_setval('$cpp_ita_fps', none)
    ;   nb_setval('$cpp_ita_tps', Old), nb_setval('$cpp_ita_fps', none), fail ).
cpp_lenc_inst(N, TPs, Args, Ret, Ps, V, Subs0, Text, Subs) :-
    cpp_lenc_path(N, Path, S), ccl_byte_length(S, L), atomic_list_concat([L, S], Src),
    (   Path == [] -> cpp_ita_note(Src, Subs0, Subs1), T0 = Src                                   % an unscoped template name, a candidate
    ;   cpp_ita_ns(Path, '', '', Subs0, C0, T00, Subs00), atom_concat(C0, Src, C1), cpp_ita_level(C1, T00, '', Src, Subs00, T01, Subs1), atomic_list_concat(['N', T01], T0) ),
    cpp_ita_fn_targs(TPs, Args, Subs1, AT, Subs2),
    ( Path == [] -> atomic_list_concat([T0, 'I', AT, 'E'], NT) ; atomic_list_concat([T0, 'I', AT, 'EE'], NT) ),
    cpp_ita_type(Ret, Subs2, _, RT, Subs3), cpp_ita_fparams(Ps, V, Subs3, _, PT, Subs), atomic_list_concat([NT, RT, PT], Text).
cpp_lenc_fname(operator(Op), Ps, _, Subs, T, Subs) :- !, ( Ps = [_], cpp_ita_unary(Op, T0) -> T = T0 ; cpp_ita_op(Op, T) ).
cpp_lenc_fname(N, _, Qs, Subs0, T, Subs) :- cpp_lenc_path(N, Path, S), ccl_byte_length(S, L), ( memberchk(static, Qs) -> Lk = 'L' ; Lk = '' ), atomic_list_concat([Lk, L, S], Src),
    ( Path == [] -> T = Src, Subs = Subs0 ; cpp_ita_ns(Path, '', '', Subs0, _, T0, Subs), atomic_list_concat(['N', T0, Src, 'E'], T) ).
cpp_lenc_path(N, Path, S) :- atom(N), atomic_list_concat(Segs, '.', N), ccl_last(Segs, S), ( catch('$cpp_own_ns_full'(N, P0), _, fail) -> Path = P0 ; cpp_pf_ns_path(N, Segs, S, fn, Path) ).   % an inline namespace in it too
%% the marks of a free function's description for its local names: inline, static, C's linkage
cpp_fsig_marks(Sto, N, Ms) :- findall(W, ( member(W, [inline, static]), cpp_sto_word(Sto, W) ), Ms0), ( atom(N), cpp_c_name(N) -> Ms = [c_link|Ms0] ; Ms = Ms0 ).
cpp_sto_word(W, W) :- !.
cpp_sto_word(T, W) :- compound(T), T =.. [_|As], member(A, As), cpp_sto_word(A, W), !.
%% where the description of a closure's call operator leads: the function the outermost closure is made in
cpp_fsig_root(fsig(member, C, _, _, _, _, _, _), F) :- atom(C), catch('$cpp_pf_closure'(C, E, _), _, fail), E \== none, !, cpp_fsig_root(E, F).
cpp_fsig_root(F, F).
%% ---- AN EXPRESSION IN A PATTERN'S WORDS (0.236; Itanium 5.1.5.4 and 5.1.6 <expression>, as clang spells them) ---------
%% Where a function template's encoding names its pattern -- a local entity of its instance -- a `decltype(e)' result is `DT
%% <expression> E' and a template argument that is an expression `X <expression> E': an operator its code before its operands
%% (`plfp_Li1E'), the function's parameter `fp_', `fp0_' ..., a value template parameter `T_' (no candidate in an
%% expression), a literal `Li1E', a call `cl <callee> <arguments> E', `sizeof' `st <type>' or `sz <expression>', a name the
%% pattern leaves unresolved its source name. Any other form is spelled by no clause, and the local name keeps this
%% compiler's name.
cpp_ita_dependent :- nb_current('$cpp_ita_fps', fps(_)).
cpp_ita_dep_args(Args) :- member(A, Args), cpp_ita_dep_arg(A), !.
cpp_ita_dep_arg(A) :- \+ cpp_is_type(A), \+ ( cpp_ita_literal(A, _, V), integer(V) ), A \= bool(_), !.
cpp_ita_dep_arg(A) :- cpp_ita_names_tparam(A).
cpp_ita_names_tparam(typedef(N)) :- atom(N), cpp_ita_tparam(N, _), !.
cpp_ita_names_tparam(T) :- compound(T), T \= typedef(_), T =.. [_|As], member(A, As), cpp_ita_names_tparam(A), !.
%% a template-id over the pattern's words: its name a candidate, then the template-id; each argument a type, a literal, or `X
%% <expression> E'
cpp_ita_dep_tmpl(N, Args, Subs0, Canon, Text, Subs) :- cpp_prog_scope(N, Path), cpp_last_segment(N, L0), ccl_byte_length(L0, K), atomic_list_concat([K, L0], Src),
    (   Path == [] -> cpp_ita_note(Src, Subs0, Subs1), C1 = Src, T1 = Src
    ;   cpp_ita_ns(Path, '', '', Subs0, C0, T0, Subs00), atom_concat(C0, Src, C1), cpp_ita_level(C1, T0, '', Src, Subs00, T1, Subs1) ),
    cpp_ita_dep_targs(Args, Subs1, AC, AT, Subs2), atomic_list_concat([C1, 'I', AC, 'E'], C2), atomic_list_concat([T1, 'I', AT, 'E'], T2),
    ( Path == [] -> Canon = C2, Text0 = T2 ; atomic_list_concat(['N', C2, 'E'], Canon), atomic_list_concat(['N', T2, 'E'], Text0) ),
    cpp_ita_whole(Canon, Text0, Subs2, Text, Subs).
cpp_ita_dep_targs([], Subs, '', '', Subs).
cpp_ita_dep_targs([A|As], Subs0, Canon, Text, Subs) :-
    (   cpp_is_type(A) -> cpp_ita_type(A, Subs0, C1, T1, Subs1)
    ;   cpp_ita_value(A, none, V) -> C1 = V, T1 = V, Subs1 = Subs0
    ;   cpp_ita_expr(A, Subs0, C0, T0, Subs1), atomic_list_concat(['X', C0, 'E'], C1), atomic_list_concat(['X', T0, 'E'], T1) ),
    cpp_ita_dep_targs(As, Subs1, C2, T2, Subs), atom_concat(C1, C2, Canon), atom_concat(T1, T2, Text).
cpp_ita_expr(paren(E), Subs0, C, T, Subs) :- !, cpp_ita_expr(E, Subs0, C, T, Subs).
cpp_ita_expr(id(X), Subs, C, C, Subs) :- atom(X), nb_current('$cpp_ita_fps', fps(Ps)), cpp_ita_fp_index(Ps, X, 0, I), !, ( I == 0 -> C = 'fp_' ; I1 is I - 1, atomic_list_concat([fp, I1, '_'], C) ).
cpp_ita_expr(id(X), Subs, C, C, Subs) :- atom(X), cpp_ita_tparam(X, Code), !, C = Code.
cpp_ita_expr(id(X), Subs, C, C, Subs) :- atom(X), !, ccl_byte_length(X, L), atomic_list_concat([L, X], C).
cpp_ita_expr(A, Subs, C, C, Subs) :- cpp_ita_value(A, none, C), !.
cpp_ita_expr(bin(Op, A, B), Subs0, C, T, Subs) :- !, cpp_ita_op(Op, Code), cpp_ita_expr(A, Subs0, CA, TA, Subs1), cpp_ita_expr(B, Subs1, CB, TB, Subs),
    atomic_list_concat([Code, CA, CB], C), atomic_list_concat([Code, TA, TB], T).
cpp_ita_expr(E, Subs0, C, T, Subs) :- E =.. [F, A], cpp_ita_unop(F, Code), !, cpp_ita_expr(A, Subs0, CA, TA, Subs), atom_concat(Code, CA, C), atom_concat(Code, TA, T).
cpp_ita_expr(call(F, Args), Subs0, C, T, Subs) :- !, cpp_ita_expr(F, Subs0, CF, TF, Subs1), cpp_ita_exprs(Args, Subs1, CAs, TAs, Subs),
    atomic_list_concat([cl, CF, CAs, 'E'], C), atomic_list_concat([cl, TF, TAs, 'E'], T).
cpp_ita_expr(sizeof_type(Ty), Subs0, C, T, Subs) :- !, cpp_ita_type(Ty, Subs0, C0, T0, Subs), atom_concat(st, C0, C), atom_concat(st, T0, T).
cpp_ita_expr(sizeof(E), Subs0, C, T, Subs) :- cpp_ita_expr(E, Subs0, C0, T0, Subs), atom_concat(sz, C0, C), atom_concat(sz, T0, T).
cpp_ita_exprs([], Subs, '', '', Subs).
cpp_ita_exprs([A|As], Subs0, C, T, Subs) :- cpp_ita_expr(A, Subs0, C1, T1, Subs1), cpp_ita_exprs(As, Subs1, C2, T2, Subs), atom_concat(C1, C2, C), atom_concat(T1, T2, T).
cpp_ita_fp_index([P|_], X, I, I) :- ( P = param(_, N) ; P = param(_, N, _) ), N == X, !.
cpp_ita_fp_index([_|Ps], X, I0, I) :- I1 is I0 + 1, cpp_ita_fp_index(Ps, X, I1, I).
cpp_ita_unop(neg, ng).   cpp_ita_unop(pos, ps).   cpp_ita_unop(not, nt).   cpp_ita_unop(bitnot, co).   cpp_ita_unop(addr, ad).   cpp_ita_unop(deref, de).
%% the variable whose initializer the walk is in (0.236): its closures are named under it
cpp_gvar_walk(Sto, Vs, Goal) :- ( Vs = [var(N, _, _)|_], atom(N) -> G = gv(N, Sto) ; G = none ), cpp_with_gvar(G, Goal).
cpp_with_gvar(G, Goal) :- ( nb_current('$cpp_gvar_now', G0) -> true ; G0 = none ), nb_setval('$cpp_gvar_now', G),
    ( catch(Goal, E, ( nb_setval('$cpp_gvar_now', G0), throw(E) )) -> nb_setval('$cpp_gvar_now', G0) ; nb_setval('$cpp_gvar_now', G0), fail ).
%% AN UNNAMED CLASS OR ENUM OF A CLASS'S MEMBERS (0.236; Itanium 5.1.2 <unnamed-type-name>): `Ut [n] _' in its class, numbered
%% among the class's unnamed types in their order -- `N1UUt_E', `N1UUt0_E'; it was `4anon', every one of them
cpp_unnamed_spec(S) :- ( S = struct(anon, _) ; S = union(anon, _) ; S = enum(anon, _) ; S = enum_class(anon, _) ), !.
cpp_unnamed_member_name(Sp, Subs0, Text, Subs) :- cpp_unnamed_holder(Sp, C, K),
    ( cpp_class_scope(C, Path, Chain) -> true ; \+ sub_atom(C, _, _, _, '.'), Path = [], cpp_ita_plain(C, C, Lv), Chain = [Lv] ), !,   % a plain struct at file scope its own name
    cpp_ita_prefix(Path, Chain, Subs0, PT, Subs1), cpp_lnum(K, KT), atomic_list_concat(['N', PT, 'Ut', KT, '_E'], Text0), atomic_list_concat(['Ut', KT, '_'], Own),
    atom_concat(PT, Own, Key), cpp_ita_whole(Key, Text0, Subs1, Text, Subs).
%% the class that declares it: a class of the program's, else a plain struct of the tag table that no header declares
cpp_unnamed_holder(Sp, C, K) :- '$cpp_cls'(C, Cls), atom(C), \+ cpp_lib_class(C), arg(2, Cls, Data), is_list(Data), cpp_unnamed_types(Data, [], Us), nth0(K, Us, U), U == Sp, !.
cpp_unnamed_holder(Sp, C, K) :- ccl_tab_member('$ccl_tags', C, Ms), atom(C), C \== anon, is_list(Ms), \+ catch(cpp_hdr_ns(C, _), _, fail), cpp_unnamed_types(Ms, [], Us), nth0(K, Us, U), U == Sp, !.
cpp_unnamed_types([], Us0, Us) :- reverse(Us0, Us).
cpp_unnamed_types([member(base(_, [S]), _, _)|Ms], Us0, Us) :- cpp_unnamed_spec(S), \+ ( member(U, Us0), U == S ), !, cpp_unnamed_types(Ms, [S|Us0], Us).
cpp_unnamed_types([_|Ms], Us0, Us) :- cpp_unnamed_types(Ms, Us0, Us).
%% the external name an address or a reference argument names (0.236): a variable's namespaces and name, a function's encoding
cpp_ita_extname(G, X) :- catch(ccl_type_of(id(G), T), _, fail), T = fn(_, Ps, V), !, ( cpp_c_name(G) -> cpp_last_segment(G, S), ccl_byte_length(S, L), atomic_list_concat([L, S], X) ; cpp_lenc_free(G, none, Ps, V, [], none, [], X, _) ).
cpp_ita_extname(G, X) :- cpp_lenc_path(G, Path, S), ccl_byte_length(S, L), ( Path == [] -> atomic_list_concat([L, S], X) ; cpp_ita_ns(Path, '', '', [], _, T0, _), atomic_list_concat(['N', T0, L, S, 'E'], X) ).
cpp_ita_scoped_name(P, G, X) :- forall(member(S, P), atom(S)), ccl_byte_length(G, L), cpp_ita_ns(P, '', '', [], _, T0, _), atomic_list_concat(['N', T0, L, G, 'E'], X).
