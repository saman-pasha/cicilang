%% ccl_cpp_init.pl -- the initialization of globals, static members and bases: a function's deduced result, an object
%% constructed at compile time or dynamically, the inline variables, the constructors' initializers, a
%% function-try-block, a union's and an array member's construction. A part of the C++ desugaring that ccl_cpp.pl
%% loads (0.223): its rules as they stood there, in their order.

%% A PLAIN FUNCTION'S DEDUCED RESULT, `auto f()', `auto &f()', `const auto &f()' (C++14, [dcl.spec.auto]; the lvalue reference forms 0.117): by value the first return's type
%% decayed, by reference that type itself under the reference -- `auto &gr() { return g; }' was `not lowered yet: auto' at its first call. `auto &&' (a forwarding reference) stays as it was
cpp_auto_result(base(_, [auto])).
cpp_auto_result(ref(_, base(_, [auto]))).
cpp_auto_result(rref(_, base(_, [auto]))).   % a FORWARDING REFERENCE result (0.121): `auto &&' is `T &' for an lvalue return, `T &&' for any other
%% A FREE FUNCTION'S TRAILING `decltype' OVER ITS PARAMETERS IS ITS RESULT (0.127; the reader keeps it, ccl_trailing_ret), resolved with the
%% parameters declared as a member's is (cpp_method_ret)
cpp_decltype_ret(Ret0, Ps, Ret) :- cpp_has_decltype(Ret0), cpp_with_params(Ps, [], cpp_type(Ret0, Ret)), !.
cpp_fn_auto_ret(base(Q, [auto]), Ps, Body, Ret) :- memberchk(decltype_auto, Q), !, cpp_decltype_auto_ret(none, Ps, Body, Ret).
cpp_fn_auto_ret(base(_, [auto]), Ps, Body, Ret) :- !, cpp_lambda_ret(Ps, Body, Ret).
cpp_fn_auto_ret(Ret0, Ps, Body, Ret) :- Ret0 =.. [K, Q, base(QA, [auto])], cpp_lambda_ret_mode(none, Ps, Body, keep, T0, Lv), ccl_unref(T0, T1), cpp_merge_quals(QA, T1, T), cpp_ref_auto_result(K, Q, T, Lv, Ret).
%% ... the reference a deduced result is: `auto &' always an lvalue reference, `auto &&' one for an lvalue return and an rvalue reference for the rest ([dcl.spec.auto]/[temp.deduct.call]/3)
cpp_ref_auto_result(ref, Q, T, _, ref(Q, T)).
cpp_ref_auto_result(rref, Q, T, Lv, R) :- ( Lv == yes -> R = ref(Q, T) ; R = rref(Q, T) ).
cpp_plain_members([], []).
cpp_plain_members([member(T, A, W)|Ms], [member(T1, A, W)|Ms1]) :- !, ( cpp_type(T, T2) -> cpp_fold_aligned(T2, T1) ; T1 = T ), cpp_plain_members(Ms, Ms1).
cpp_plain_members([M|Ms], [M|Ms1]) :- cpp_plain_members(Ms, Ms1).
%% A FILE-SCOPE OBJECT IS DECLARED UNDER ITS RESOLVED TYPE (0.112): the table holds the type as the reader wrote it,
%% `std::string_view' -- a scoped name the inference cannot resolve -- so `g.size()' on `constexpr std::string_view
%% g{"hello"}' found no class and stayed a raw member call; resolved here, the method road takes it
cpp_redeclare_globals([], []).
cpp_redeclare_globals([var(N, T0, _)|Vs], [var(_, T, _)|Ws]) :-
    ( atom(N), T \== T0, \+ T = fn(_, _, _), ccl_locals([]) -> ccl_gdeclare([N-T]), ccl_tables_changed ; true ),
    cpp_redeclare_globals(Vs, Ws).
%% A FILE-SCOPE `const' OBJECT INITIALIZED BY A CONSTEXPR CALL TAKES ITS VALUE ([expr.const]; 0.95): `constexpr int N =
%% twice(21);' reached the lowering as a call in a global's initializer (0.88's cpp_global_const folds such a name
%% where a CONSTANT is asked for, and the lowering never asks). Only where the fold answers: any other initializer
%% stays what it was.
cpp_fold_const_inits(base(Q, _), Sto, Rs, Vs, Ws) :- memberchk(const, Q), !, cpp_fold_const_inits_(Sto, Rs, Vs, Ws).
cpp_fold_const_inits(_, Sto, Rs, Vs, Ws) :- cpp_fold_ctor_inits_(Sto, Rs, Vs, Ws).
%% A GLOBAL OF A CLASS WITH A CONSTRUCTOR IS CONSTRUCTED AT COMPILE TIME ([basic.start.static]: constant initialization
%% where the constructor is constexpr and its arguments constant; 0.99): the constructor runs in the evaluator over a
%% cell holding the class's zero, and the cell's value is the global's initializer. This compiler runs no dynamic
%% initialization, so a constructor the evaluator cannot run is refused by name, where the lowering met `global_init(ctor(...))'.
cpp_fold_ctor_inits_(_, _, [], []).
cpp_fold_ctor_inits_(Sto, [R|Rs], [var(N, T, I)|Vs], [var(N, T, I1)|Ws]) :-
    ( cpp_global_object(Sto, N, T, I, C) -> cpp_global_ctor_init(Sto, R, N, T, C, I, I1) ; I1 = I ),
    cpp_fold_ctor_inits_(Sto, Rs, Vs, Ws).
%% a global of a class with constructors, given an initializer of another type -- or none, where its default
%% construction is no trivial one (0.112: `Tag g;' had been its zero bytes, the constructor never run)
cpp_global_object(Sto, N, T, I, C) :- atom(N), cpp_class_of_type(T, C), cpp_has_ctors(C),
    ( I \== none -> true ; Sto \== extern, \+ cpp_trivial_default(C) ), !.   % a value of the class itself too (0.112): `static Tag t = Tag(3)' constructs t, `T h = g' copies g
%% A STATIC DATA MEMBER OF A CLASS WITH CONSTRUCTORS, DEFINED OUT OF ITS CLASS, IS CONSTRUCTED AS A NAMESPACE-SCOPE OBJECT
%% IS (0.186; [class.static.data]/4): at compile time where the evaluator runs its constructor, else before main, in the
%% class's words and access. The road was a scalar's: `const O O::low(3);' and `const O O::low = O(3);' reached the
%% lowering raw (`global_init(ctor(...))'), and `const O O::low{3};' over `O(int x) : v(x * 2)' was the aggregate {3},
%% where clang++ gives 6 -- a silent wrong answer. A library class's such statics take its class's road (`'$cpp_sinit'',
%% cpp_static_constructed/4). `qualparam.cpp', `globalprvalue.cpp'.
cpp_static_object_init(Cx, Sto, N, T, Raw, I, I1) :-
    (   cpp_global_object(Sto, N, T, I, C) -> cpp_with_access_scope(Cx, cpp_global_ctor_init(Cx, Sto, var(N, T, Raw), N, T, C, I, I1))
    ;   I1 = I ).
cpp_fold_ctor_init(N, T, C, I, I1) :- ( cpp_fold_ctor_value(T, C, I, I0) -> I1 = I0 ; cpp_refuse(0, dynamic_initialization_of_global(N, C)) ).
%% the compile-time attempt with no trace left behind: its walk may register temporaries in the statement's register,
%% which a failed attempt must not leave there to be destroyed unconstructed
cpp_fold_quietly(T, C, I, IV) :- ccl_global('$cpp_temps', B, none),
    ( catch(cpp_fold_ctor_value(T, C, I, IV0), _, fail) -> nb_setval('$cpp_temps', B), IV = IV0 ; nb_setval('$cpp_temps', B), fail ).
cpp_fold_ctor_value(T, C, I, I1) :-
    (   I = init(_), cpp_agg_constant(C, I, I0) -> I1 = I0   % an aggregate: its braced list completed by the class's defaults (below)
    ;   cpp_ctor_args(none, I, C, Args), cpp_ctor(C, Args, CName), cpp_fill_defaults(CName, Args, Args0), cpp_ref_args_of(CName, Args0, Args1),
        catch(cpp_eval_construct(T, CName, Args1, AV), _, fail), cpp_eval_init_term(AV, I1) ).
%% A GLOBAL WHOSE CONSTRUCTOR THE EVALUATOR CANNOT RUN IS INITIALIZED DYNAMICALLY ([basic.start.dynamic]; 0.112; refused
%% as `dynamic_initialization_of_global' since 0.99): constant initialization where the evaluator constructs it, else
%% the global is zero bytes and the unit's one initialization function, `$cpp_ginit' -- run before main through
%% `llvm.global_ctors' -- constructs it where it stands (a placement new over its address, the RAW initializer walked
%% as any statement is) and registers its destructor with `atexit' (a wrapper `$cpp_gdtor.N'), in declaration order,
%% so the globals die in the reverse order. `std::string g = "x";' at file scope.
cpp_global_ctor_init(Sto, Raw, N, T, C, I, I1) :- cpp_global_ctor_init(none, Sto, Raw, N, T, C, I, I1).
cpp_global_ctor_init(Cx, Sto, var(_, T0, I00), N, T, C, I, I1) :-   % Cx: the class whose static data member N is, else none
    ( cpp_prvalue_init(T0, I00, IP) -> IF = IP, ID = IP ; IF = I, ID = I00 ),
    (   cpp_fold_ctor_value(T, C, IF, I0) -> I1 = I0, ( Sto \== extern, cpp_dtor(C, DName) -> cpp_gdtor_reg(N, DName, Reg), cpp_ginit_add(Sto, N, [Reg]) ; true )   % ... AND DESTROYED AT EXIT (0.192), below
    ;   Sto \== extern -> cpp_dynamic_init(Cx, Sto, N, T0, C, ID), I1 = none
    ;   cpp_refuse(0, dynamic_initialization_of_global(N, C)) ).
cpp_dynamic_init(Cx, Sto, N, T0, C, I0) :-
    ( I0 == none -> As = [] ; I0 = init(Items0), cpp_il_ctor_for(C, Items0, _) -> As = [I0] ; cpp_init_args(I0, As) ),   % a braced list for a class with an initializer_list constructor is ONE argument, the list (`std::vector<int> v = {1, 2, 3}')
    S0 = expr(0, new_at([addr(id(N))], new(T0, As))), ( Cx == none -> S1 = S0 ; S1 = '$in_class'(Cx, S0) ),   % a static member's in its class's words and access (0.186)
    ( cpp_dtor(C, DName) -> cpp_gdtor_reg(N, DName, Reg), Ss = [S1, Reg] ; Ss = [S1] ),
    cpp_ginit_add(Sto, N, Ss), cpp_trace(dynamic_init(N, C)).
%% AN OBJECT CONSTRUCTED AT COMPILE TIME IS DESTROYED AT EXIT TOO ([basic.start.term]/1, /3: one initialized statically is destroyed as
%% if it had been initialized dynamically, in its declaration's place; 0.192): its destructor is registered with `atexit' where the
%% unit's initialization function reaches the declaration, as a dynamically initialized one's is, a wrapper `$cpp_gdtor.N' that
%% destroys it. It registered nothing, and `~K' of a namespace-scope `K k(2);' over a constexpr constructor never ran.
cpp_gdtor_reg(N, DName, expr(0, call(id(atexit), [id(W)]))) :-
    atom_concat('$cpp_gdtor.', N, W), Void = base([], [void]), ccl_declare(W, fn(Void, [], false)),
    cpp_math_declared(atexit, base([], [int]), [param(ptr([], fn(Void, [], false)), f)]),
    nb_getval('$cpp_ginit_fns', Fs0), append(Fs0, [function(0, static, Void, W, [], false, block([expr(0, call(id(DName), [addr(id(N))]))]))], Fs1), nb_setval('$cpp_ginit_fns', Fs1).
cpp_ginit_add(Ss) :- nb_getval('$cpp_ginit', G0), append(G0, Ss, G1), nb_setval('$cpp_ginit', G1).
%% A VARIABLE THAT EVERY UNIT MAY DEFINE -- an inline one, a static data member initialized in its class -- IS INITIALIZED AND
%% REGISTERED ONCE (0.192): its statements stand under a guard of its own, `$gv.N', linkonce as the variable is, which the first
%% unit's initialization function tests and sets, and they run before the unit's ordered initializations, as clang runs them (the
%% partially-ordered and unordered initialization of [basic.start.dynamic]/1, each in a `llvm.global_ctors' entry of its own ahead
%% of the unit's). Two units that include one header's `inline Cnt gc(5);' each constructed the one object and registered it.
cpp_ginit_add(Sto, N, Ss) :- cpp_once_storage(Sto), !, atom_concat('$gv.', N, G), GT = base([], [char]), nb_getval('$cpp_ginit_fns', Fs0),
    (   memberchk(declaration(_, linkonce, _, [var(G, _, _)]), Fs0) -> true
    ;   ccl_gdeclare([G-GT]), ccl_tables_changed, append(Fs0, [declaration(0, linkonce, GT, [var(G, GT, none)])], Fs1), nb_setval('$cpp_ginit_fns', Fs1) ),
    nb_getval('$cpp_ginit_pre', P0), append(P0, [if(0, not(id(G)), block([expr(0, assign('=', id(G), int(1)))|Ss]), none)], P1), nb_setval('$cpp_ginit_pre', P1).
cpp_ginit_add(_, _, Ss) :- cpp_ginit_add(Ss).
cpp_once_storage(inline).
cpp_once_storage(linkonce).
%% ... and such a variable is DEFINED linkonce in every unit that has it ([basic.def.odr]/14), where `inline' was a strong `global' and
%% two units did not link, two definitions; a function's declaration keeps its word
cpp_inline_storage(inline, Vs, linkonce) :- \+ member(var(_, fn(_, _, _), _), Vs), !.
cpp_inline_storage(none, Vs, static) :- Vs \== [], forall(member(var(N, T, _), Vs), ( atom(N), \+ '$cpp_extern_var'(N), cpp_internal_const(T) )), !.
cpp_inline_storage(Sto, _, Sto).
%% ... AND A CONST ONE IS ITS UNIT'S OWN ([basic.link]/3.2: a variable of non-volatile const-qualified type that is not declared
%% `extern' or `inline', here or before, has internal linkage; 0.192): `const int k = 5;' in two units, and a header's
%% `constexpr int N = 8;' that two units include, were two strong definitions of one symbol, a link error. A name the
%% program declares `extern' anywhere keeps its external linkage (`'$cpp_extern_var'', cpp_note_extern_vars/1).
cpp_internal_const(T0) :- catch(ccl_resolve_type(T0, T), _, fail), cpp_internal_const_(T).
cpp_internal_const_(base(Q, _)) :- memberchk(const, Q), \+ memberchk(volatile, Q).
cpp_internal_const_(ptr(Q, _)) :- memberchk(const, Q), \+ memberchk(volatile, Q).
cpp_internal_const_(arr(_, E)) :- cpp_internal_const_(E).
%% A PRVALUE OF THE CLASS WRITTEN AS ITS CONSTRUCTOR'S CALL IS THE OBJECT ([dcl.init.general]/16.6.1, C++17's elision):
%% `Tag(3)' and `Tag{3}' (a list, the initializer_list constructor first) give the RAW initializer of the global, folded
%% and constructed from its own arguments (0.186). The fold took the WALKED initializer and walked it again, and the
%% temporary's declaration that the first walk made was default-constructed: `const O g = O(3);' and `P g = P{3};' at
%% namespace scope, and `const O O::low = O(3);', were `no_constructor('O', 0)' where the class has no default
%% constructor, and a copy of a temporary where it has one. `globalprvalue.cpp'.
cpp_prvalue_init(base(_, [typedef(X)]), call(id(X), As), ctor(As)).
cpp_prvalue_init(base(_, [typedef(X)]), ccast(functional, base(_, [typedef(X)]), A), ctor(As)) :- ( A == none -> As = [] ; As = [A] ).
cpp_prvalue_init(base(_, [typedef(X)]), braced_temp(call(id(X), Vs)), init(Items)) :- findall(item([], V), member(V, Vs), Items).
%% A FILE-SCOPE SCALAR WHOSE INITIALIZER NEEDS THE RUN TIME IS INITIALIZED DYNAMICALLY TOO ([basic.start.dynamic]; 0.117):
%% `int g = f() * 2;', `static int n = h + 4;', `int A::v = A::compute() * 2;' were refused by the lowering as
%% `global_init(...)', for the constant initialization of a global is all it spells. The global stays its zero, and the
%% RAW initializer is assigned in the unit's one initialization function (`$cpp_ginit', above), in declaration order, in
%% the class's words for a static member (`$in_class'). An initializer is run-time when it holds a call that did not fold, a
%% read of a variable, a dereference, a member, an index, an assignment, a `new' or the address of anything but a name
%% (cpp_runtime_init): all else stays what it was, a constant the lowering spells or refuses. Never for a `thread_local'
%% (it needs one initialization per thread), an `extern' declaration, a class, an array, a reference.
cpp_dynamic_scalars(_, _, _, _, [], [], []).
cpp_dynamic_scalars(L, Ctx, Sto, B, [R|Rs], [var(N, T, I)|Vs], [var(N, T, I1)|Ws]) :-
    (   cpp_dyn_scalar(Ctx, Sto, B, R, N, T, I, E) -> cpp_dynamic_assign(L, Ctx, Sto, N, E), I1 = none
    ;   I1 = I ),
    cpp_dynamic_scalars(L, Ctx, Sto, B, Rs, Vs, Ws).
cpp_dyn_scalar(Ctx, Sto, B, var(_, _, I0), N, T, I, E) :-
    atom(N), Sto \== extern, I \== none, \+ ( B = base(Q, _), memberchk(thread_local, Q) ),
    cpp_in_class_if(Ctx, cpp_dyn_scalar_type(T)),
    cpp_unbrace(I, IV), cpp_runtime_init(IV), cpp_unbrace(I0, E).
cpp_in_class_if(none, G) :- !, call(G).
cpp_in_class_if(C, G) :- cpp_in_class(C, G).
cpp_dyn_scalar_type(T) :- cpp_braced_scalar_type(T), ccl_resolve_type(T, R), \+ R = ref(_, _), \+ R = rref(_, _), \+ R = fn(_, _, _).
cpp_unbrace(init([item(_, X)]), X) :- !.
cpp_unbrace(ctor([X]), X) :- !.
cpp_unbrace(X, X).
cpp_dynamic_assign(L, Ctx, Sto, N, E) :-
    S0 = expr(L, assign('=', id(N), E)), ( Ctx == none -> S = S0 ; S = '$in_class'(Ctx, S0) ),
    cpp_ginit_add(Sto, N, [S]), cpp_trace(dynamic_scalar_init(N)).
%% the test: a node that reads or computes at run time. A name is a constant when it is a function, an enumerator or a
%% constant that folds; an address is a constant when it is a name's (`&g', `&f'); a `sizeof' is never walked into.
cpp_runtime_init(I) :- compound(I), cpp_rt_node(I), !.
cpp_rt_node(call(_, _)) :- !.
cpp_rt_node(id(X)) :- !, atom(X), ccl_declared(X, T), \+ ccl_resolve_type(T, fn(_, _, _)), \+ catch(ccl_const_eval(id(X), _), _, fail).
cpp_rt_node(addr(X)) :- !, X \= id(_).
cpp_rt_node(sizeof_type(_)) :- !, fail.
cpp_rt_node(sizeof(_)) :- !, fail.
cpp_rt_node(alignof_type(_)) :- !, fail.
cpp_rt_node(alignof_expr(_)) :- !, fail.
cpp_rt_node(noexcept_expr(_)) :- !, fail.
cpp_rt_node(str(_)) :- !, fail.
cpp_rt_node(u8str(_)) :- !, fail.
cpp_rt_node(deref(_)) :- !.
cpp_rt_node(arrow(_, _)) :- !.
cpp_rt_node(member(_, _)) :- !.
cpp_rt_node(index(_, _)) :- !.
cpp_rt_node(assign(_, _, _)) :- !.
cpp_rt_node(preinc(_)) :- !.
cpp_rt_node(predec(_)) :- !.
cpp_rt_node(postinc(_)) :- !.
cpp_rt_node(postdec(_)) :- !.
cpp_rt_node(new(_, _)) :- !.
cpp_rt_node(new_default(_)) :- !.
cpp_rt_node(new_array(_, _)) :- !.
cpp_rt_node(stmt_expr(_)) :- !.
cpp_rt_node(T) :- T =.. [_|As], member(A, As), compound(A), ( A = [_|_] -> member(X, A), cpp_runtime_init(X) ; cpp_runtime_init(A) ), !.
%% the unit's initialization function, at its end: its statements walked as a body's are (temporaries, copies)
cpp_ginit_items(Is0, Is) :- ( nb_current('$cpp_ginit', Ss1) -> true ; Ss1 = [] ),
    ( nb_current('$cpp_ginit_pre', Ss0) -> true ; Ss0 = [] ), append(Ss0, Ss1, Ss),   % the guarded ones first (0.192, cpp_ginit_add/3)
    (   Ss == [] -> Fn = []
    ;   Void = base([], [void]), ccl_declare('$cpp_ginit', fn(Void, [], false)),
        cpp_method_body(none, Void, [], block(Ss), Body1), Fn = [function(0, static, Void, '$cpp_ginit', [], false, Body1)] ),
    ( nb_current('$cpp_ginit_fns', Fs) -> true ; Fs = [] ),                       % the wrappers a static local array registers (0.117) stand without the unit's initialization function; read after its walk
    append(Is0, Fs, Is1), append(Is1, Fn, Is), cpp_ginit_reset.                  % ... and the lists emptied for the next unit (0.192)
%% A GLOBAL AGGREGATE'S BRACED LIST IS COMPLETED BY THE CLASS'S DEFAULT MEMBER INITIALIZERS ([dcl.init.aggr]/5.1;
%% 0.112): every data member gets its item -- the one written (by position, or by a designator `.f = v'), else its
%% default member initializer desugared in the class's words, else `init([])', its zero -- and a member of an aggregate
%% class is completed the same way, given or not. A global is a constant here (nothing runs dynamic initialization), so
%% only scalars, arrays of scalars and such aggregates take this road; a class with constructors stays the
%% constructor's (cpp_fold_ctor_init). Why: libc++ 18's `inline constexpr __fields __fields_integral{.__sign_ = true,
%% ...}' lost the members it does not name, and a `{true}' default read 0 (`aggconst.cpp').
cpp_agg_constant(C, init(Items0), init(Items)) :-
    cpp_aggregate_class(C), cpp_class_l(C, cls(none, Data, _, Defs, _)), length(Items0, NI), length(Data, ND), NI =< ND,   % more items than members is BRACE ELISION, the lowering's (ir_gelide)
    \+ ( member(member(_, N, _), Data), sub_atom(N, 0, 1, _, '$') ),
    cpp_agg_slots(Items0, Data, 0, [], Slots), cpp_agg_fill(Data, 0, Slots, C, Defs, Items).
cpp_agg_slots([], _, _, S, S).
cpp_agg_slots([item(Ds, V)|Is], Data, I0, S0, S) :-
    (   ( Ds == [] ; Ds == none ) -> I = I0, V1 = V
    ;   Ds = [field(F)], nth0(I, Data, member(_, F, _)) -> V1 = V
    ;   Ds = [field(F)], nth0(I, Data, member(UT, A, _)), cpp_anon_member(A), cpp_anon_field(UT, F, _) -> V1 = '$anon_item'(F, V) ), !,   % a nested designator `.a.b' is not this road
    I1 is I + 1, cpp_agg_slots(Is, Data, I1, [I-V1|S0], S).
%% A DESIGNATOR MAY NAME A MEMBER OF AN ANONYMOUS UNION ([class.union.anon]/1: its members are the class's for name
%% lookup; 0.112): the slot is the union's own (`$anonK', cpp_norm_members_) and its item `'$anon_item'(F, V)', which
%% cpp_agg_inits stores through the union. libc++'s `__parsed_specifications{.__std_ = __std{...}, ...}' (std::format)
%% had stored the whole `__std' into the union's bytes as a conversion LLVM refused.
cpp_anon_member(A) :- atom(A), atom_concat('$anon', _, A).
cpp_anon_field(UT, F, FT) :- ccl_members_of(UT, Ms), memberchk(member(FT, F, _), Ms).
cpp_agg_fill([], _, _, _, _, []).
cpp_agg_fill([member(MT, N, _)|Ds], I, Slots, C, Defs, [item([], V)|Is]) :-
    (   memberchk(I-V0, Slots) -> G = yes(V0)
    ;   memberchk(N-D, Defs) -> once(cpp_in_class(C, cpp_agg_default(C, D, D1))), G = yes(D1)
    ;   G = no ),
    cpp_agg_member(MT, G, V), I1 is I + 1, cpp_agg_fill(Ds, I1, Slots, C, Defs, Is).
cpp_agg_default(C, init(Items), init(Items1)) :- !, findall(item(Ds, V1), ( member(item(Ds, V0), Items), once(cpp_agg_default(C, V0, V1)) ), Items1).
cpp_agg_default(C, E0, E) :- cpp_expr(C, E0, E).
cpp_agg_member(MT, G, V) :- cpp_class_of_type(MT, MC), !,
    ( G = yes(init(Sub)) -> cpp_agg_constant(MC, init(Sub), V) ; G == no -> cpp_agg_constant(MC, init([]), V) ).
cpp_agg_member(MT, _, _) :- ccl_resolve_type(MT, arr(_, ET)), cpp_class_of_type(ET, _), !, fail.   % an array of objects: each element its own road
cpp_agg_member(MT, yes(init([item(_, X)])), X) :- \+ ccl_resolve_type(MT, arr(_, _)), cpp_scalar_member_type(MT), !.   % a braced scalar, `{true}': its one item (never an array's list: cpp_scalar_type answers yes for an array)
cpp_agg_member(_, yes(X), X) :- !.
cpp_agg_member(_, no, init([])).
cpp_eval_construct(T, CName, Args, V) :- cpp_eval_agg_kind(T, K), cpp_eval_agg_init(K, none, [], _, Z), cpp_ec_new(Z, Id), Env = ['$obj'-'$cell'(Id), '$t'('$obj')-T],
    cpp_eval_reduce(call(id(CName), [addr(id('$obj'))|Args]), Env, R), R \= call(_, _), cpp_ec_get(Id, V).
cpp_fold_const_inits_(_, _, [], []).
cpp_fold_const_inits_(Sto, [R|Rs], [var(N, T, I)|Vs], [var(N, T, I1)|Ws]) :-
    (   cpp_global_object(Sto, N, T, I, C) -> cpp_global_ctor_init(Sto, R, N, T, C, I, I1)   % `constexpr V g(3, 4);' (0.99); else at run time, before main (0.112)
    ;   I = call(_, _), catch(cpp_eval_agg_kind(T, _), _, fail), catch(cpp_eval_init(T, I, [], _, AV), _, fail), cpp_eval_init_term(AV, I2) -> I1 = I2   % `constexpr P origin = make(7);': the aggregate the call answers, as its initializer (0.98)
    ;   I = call(_, _), \+ ccl_resolve_type(T, arr(_, _)), once(( between(1, 2, _), catch(cpp_with_ce(cpp_const_value(I, K)), _, fail) )) -> ( K = bool(_) -> I1 = K ; integer(K) -> I1 = int(K) ; K = big(_) -> I1 = int(K) ; I1 = I ) ; I1 = I ),   % TWICE: the first attempt EMITS the library instances the call runs through (`numeric_limits<size_t>::max()'), and only the second sees them -- `inline constexpr size_t dynamic_extent' was a run-time initialization, no constant for a pattern (0.117)
    ( atom(N), I1 \== none, catch(cpp_eval_agg_kind(T, _), _, fail) -> atom_concat('$cpp_gagg:', N, GK), nb_setval(GK, agg(T, I1, global)) ; true ),   % a constant aggregate: a value for the constexpr evaluator (0.97)
    cpp_fold_const_inits_(Sto, Rs, Vs, Ws).
%% auto parameters become invented type parameters, in order: `$A1', `$A2' ...
cpp_auto_params(Ps, K, Ps1, TPs) :-
    cpp_auto_params_(Ps, K, Ps1, TPs0, Rs),
    ( Rs == [] -> TPs = TPs0 ; cpp_conj_reqs(Rs, R), append(TPs0, [requires(R)], TPs) ).   % the constraints as ONE requires entry, LAST, as the reader gathers a written head's (ccl_gather_requires)
cpp_auto_params_([], _, [], [], []).
cpp_auto_params_([P|Ps], K, [P1|Ps1], TPs, Rs) :-
    ( P = param(T0, N) -> D = none ; P = param(T0, N, D) ),
    (   cpp_auto_in(T0, K, T1, K1)
    ->  atom_concat('$A', K1, A), ( D == none -> P1 = param(T1, N) ; P1 = param(T1, N, D) ),
        ( T0 = pack(_) -> Kind = pack ; Kind = type ), TPs = [tparam(Kind, A, none)|TPs1],   % `auto... xs' invents a template parameter PACK ([dcl.fct]/22; 0.132): it invented nothing, and `[](auto... s) { return 1L; }' failed the desugaring without a word -- zip_view's `size()' is `std::apply([](auto... __sizes) {...}, ...)'
        (   cpp_auto_constraint(T0, C, As), '$cpp_concept'(C, _)
        ->  R = tmpl(C, [base([], [typedef(A)])|As]), ( Kind == pack -> Rs = [fold('&&', R, dots)|Rs1] ; Rs = [R|Rs1] )   % `Number auto x' ([dcl.fct]/22): the invented parameter is constrained by it -- a concept the program declared; a library's is left to the library; `Number auto... xs' each element, a fold
        ;   Rs = Rs1 )
    ;   P1 = P, K1 = K, TPs = TPs1, Rs = Rs1 ),
    cpp_auto_params_(Ps, K1, Ps1, TPs1, Rs1).
cpp_conj_reqs([R], R) :- !.
cpp_conj_reqs([R|Rs], bin('&&', R, R1)) :- cpp_conj_reqs(Rs, R1).
cpp_auto_constraint(base(Q, [auto]), C, As) :- memberchk(constrained(C, As), Q), !.
cpp_auto_constraint(ptr(_, T), C, As) :- !, cpp_auto_constraint(T, C, As).
cpp_auto_constraint(pack(T), C, As) :- !, cpp_auto_constraint(T, C, As).
cpp_auto_constraint(ref(_, T), C, As) :- !, cpp_auto_constraint(T, C, As).
cpp_auto_constraint(rref(_, T), C, As) :- !, cpp_auto_constraint(T, C, As).
cpp_auto_in(base(Q0, [auto]), K, base(Q, [typedef(A)]), K1) :- !, K1 is K + 1, atom_concat('$A', K1, A), delete(Q0, constrained(_, _), Q).
cpp_auto_in(ptr(Q, T0), K, ptr(Q, T), K1) :- !, cpp_auto_in(T0, K, T, K1).
cpp_auto_in(pack(T0), K, pack(T), K1) :- !, cpp_auto_in(T0, K, T, K1).
cpp_auto_in(ref(Q, T0), K, ref(Q, T), K1) :- !, cpp_auto_in(T0, K, T, K1).
cpp_auto_in(rref(Q, T0), K, rref(Q, T), K1) :- !, cpp_auto_in(T0, K, T, K1).
%% AN ENUMERATOR THE READER COULD NOT FOLD IS THE DESUGARING'S (0.160; [dcl.enum]/5: its initializer is a converted constant
%% expression): `enum { A = f(), B };' over `constexpr int f() { return 7; }' took the value after the one before it, silently
%% -- A 0 and B 1 where clang++ has 7 and 8 -- since the reader runs no constexpr call. An initializer the one evaluator does not
%% fold is desugared and folded through the constexpr evaluator (cpp_const_value/2), the enumerators before it put in as their
%% values; the item goes on with that value as a literal, the table is told every value of the enum at once (newest first), and
%% one of the program's own that folds nowhere is refused by name, `enumerator_not_constant(N)'
cpp_enum_unfolded([enumerator(M, X0)|Es], K, Seen) :- !,
    (   X0 == none -> V = K
    ;   cpp_replace_ids(X0, Seen, X1), catch(ccl_const_eval(X1, V0), _, fail) -> V = V0
    ;   true ),
    ( var(V) -> true ; ccl_w_add(V, 1, K1), cpp_enum_unfolded(Es, K1, [M-int(V)|Seen]) ).
cpp_enum_unfolded([_|Es], K, Seen) :- cpp_enum_unfolded(Es, K, Seen).
cpp_fold_enumerators(_, [], _, _, []).
cpp_fold_enumerators(L, [enumerator(M, X0)|Es0], K, Seen, [enumerator(M, X)|Es]) :- !,
    (   X0 == none -> V = K, X = none
    ;   cpp_replace_ids(X0, Seen, X1), catch(ccl_const_eval(X1, V0), _, fail) -> V = V0, X = X0
    ;   cpp_replace_ids(X0, Seen, X1), catch(( cpp_expr(none, X1, X2), cpp_const_value(X2, V0) ), _, fail), ( integer(V0) ; V0 = big(_) ) -> V = V0, X = int(V)
    ;   nb_getval('$cpp_in_lib', yes) -> V = K, X = X0
    ;   cpp_refuse(L, enumerator_not_constant(M)) ),
    nb_getval('$ccl_enums', T0), nb_setval('$ccl_enums', [M-V|T0]),
    ccl_w_add(V, 1, K1), cpp_fold_enumerators(L, Es0, K1, [M-int(V)|Seen], Es).
cpp_fold_enumerators(L, [E|Es0], K, Seen, [E|Es]) :- cpp_fold_enumerators(L, Es0, K, Seen, Es).
%% A FREE FUNCTION IS DECLARED UNDER ITS RESOLVED RESULT TYPE (0.132), as an `auto' one has been since 0.100: the table
%% held the reader's `std::string &', a scoped name the inference resolved to the bare C struct, so `get(s).size()' over
%% `std::string &get(std::string &)' found no member, and `std::string t = take(s);' over `std::string &&take(...)' typed
%% the argument as nothing and took the `const char *' constructor
cpp_declare_resolved(Name, Ret0, Ret, Ps1, V) :- ( Ret \== Ret0, atom(Name) -> ccl_declare(Name, fn(Ret, Ps1, V)) ; true ).
cpp_vars(_, [], []).
cpp_vars(Ctx, [var(N, fn(R0, Ps, V), I)|Vs], [var(N, fn(R, Ps1, V), I)|Ws]) :- !, cpp_type(R0, R), cpp_plain_params(Ps, Ps1), cpp_vars(Ctx, Vs, Ws).
cpp_vars(Ctx, [var(N, T0, I)|Vs], [var(N, T, I1)|Ws]) :- cpp_type(T0, T1), cpp_expr(Ctx, I, I10), cpp_init_convs(T1, I10, I11), cpp_set_value(I11, T1, I1),   % an aggregate's class items converted to its scalar members (cpp_init_convs, 0.168); an overload set chosen by the type (cpp_set_value/3, 0.181)
    ( cpp_has_auto(T1), I1 \== none -> ( ccl_type_of(I1, IT), IT \== unknown -> cpp_auto_deduce(T1, IT, T) ; cpp_refuse(0, auto(N)) ), ( atom(N), ccl_locals([]) -> ccl_gdeclare([N-T]), ccl_tables_changed ; true ) ; T = T1 ),   % a namespace-scope `auto' object, `inline constexpr auto twice = fn{};' ([dcl.spec.auto]: deduced from its initializer), where the lowering met `auto'
    cpp_vars(Ctx, Vs, Ws).
%% AN OVERLOAD SET NAMED BY A NAMESPACE-SCOPE OBJECT'S INITIALIZER IS CHOSEN BY THE OBJECT'S TYPE ([over.over]; 0.181), as
%% a local's is (cpp_conv_to/3): `int (*pm)(int) = m;' beside a defined `int m(long)' was refused, `global_init(id(m))',
%% and beside a DECLARED one (cpp_fn_overloaded/1's third clause) it named the declaration
cpp_set_value(E0, T, E) :- ( E0 = id(F) ; E0 = addr(id(F)) ), atom(F), cpp_fn_overloaded(F), !, cpp_conv_to(E0, T, E).
cpp_set_value(E, _, E).
%% the static members: declared with the class, defined out of it (Counter::made, above) -- except one initialized in
%% the class (`static constexpr bool value = __v;', integral_constant's), which is its own definition, linkonce as the
%% class's functions are, since every unit that has the class has it
cpp_static_decls(_, _, [], []).
cpp_static_decls(L, C, [N-T0|Ss], [D|Ds]) :- cpp_static_name(C, N, Name), cpp_resolved_type(T0, T1), cpp_static_auto(C, N, T1, T),
    (   cpp_static_const(C, N, V) -> D = declaration(L, linkonce, T, [var(Name, T, V)])
    ;   \+ cpp_ctor_class_type(T), cpp_static_aggregate(C, N, I) -> D = declaration(L, linkonce, T, [var(Name, T, I)])   % never a class with constructors (0.112): `static constexpr basic_string_view<_CharT> __true{"true"}' is the constructor's, and as an aggregate its pointer took the literal and its size 0 -- std::format printed `true' as nothing
    ;   \+ cpp_ctor_class_type(T), cpp_static_agg_call(C, N, T, I) -> D = declaration(L, linkonce, T, [var(Name, T, I)])   % an aggregate from a call of its class's own constexpr function (0.201, below)
    ;   cpp_static_constructed(C, N, T, I) -> D = declaration(L, linkonce, T, [var(Name, T, I)]), cpp_static_dtor_reg(Name, T)
    ;   cpp_sinit(C, N, _), cpp_class_of_type(T, TC), cpp_empty_class(TC) -> D = declaration(L, linkonce, T, [var(Name, T, init([]))])   % a static of an EMPTY class initialized in its class -- a customization point object copied, `static constexpr auto __iter_move = ranges::iter_move;' -- is its zero bytes, as a header's inline global of one is (0.82)   % a static of CLASS type constructed at compile time by its constexpr constructor (0.99's rule for a global; 0.101 for a member): `strong_ordering::less(_OrdResult::__less)'
    ;   cpp_static_floating(C, N, T, I) -> D = declaration(L, linkonce, T, [var(Name, T, I)])
    ;   cpp_static_floating_late(C, N, T, E) -> D = declaration(L, linkonce, T, [var(Name, T, none)]), cpp_dynamic_assign(L, C, linkonce, Name, E)
    ;   cpp_static_scalar_late(C, N, T, E) -> D = declaration(L, linkonce, T, [var(Name, T, none)]), cpp_dynamic_assign(L, C, linkonce, Name, E)
    ;   cpp_static_dynamic(C, N, T, E, TC) -> D = declaration(L, linkonce, T, [var(Name, T, none)]), cpp_dynamic_init(C, linkonce, Name, T, TC, E)
    ;   \+ cpp_sinit(C, N, _), catch('$cpp_sinline'(C, N), _, fail) -> D = declaration(L, linkonce, T, [var(Name, T, none)]), cpp_static_default_init(C, Name, T)   % an inline one with no initializer (0.218, below)
    ;   D = declaration(L, extern, T, [var(Name, T, none)]) ),
    cpp_static_decls(L, C, Ss, Ds).
%% A STATIC DATA MEMBER OF CLASS TYPE INITIALIZED IN ITS CLASS (an inline variable, every unit's) IS DESTROYED AT EXIT, once (0.192):
%% one the evaluator constructs registers its destructor under its guard (cpp_ginit_add/3), and one it cannot construct is constructed
%% before main in its class's words and registered, under the guard too -- `static inline Loud l{3};' was declared `extern', defined
%% nowhere, and its first use failed at the link. Never an AGGREGATE, whose braced items are no constructor's arguments: libc++'s
%% `static constexpr array<__compile_time_handle<_CharT>, sizeof...(_Args)> __handles_{...}', which only the consteval check of a
%% format string names, stays declared and not defined, as 0.112 left it (`no_constructor('array.__compile_time_handle.char.2', 2)')
cpp_static_dtor_reg(Name, T) :- ( cpp_class_of_type(T, TC), cpp_dtor(TC, DName) -> cpp_gdtor_reg(Name, DName, Reg), cpp_ginit_add(linkonce, Name, [Reg]) ; true ).
cpp_static_dynamic(C, N, T, ID, TC) :- cpp_sinit(C, N, E), cpp_class_of_type(T, TC), cpp_has_ctors(TC), \+ cpp_aggregate_class(TC), ( cpp_prvalue_init(T, E, IP) -> ID = IP ; ID = E ).
%% AN INLINE STATIC DATA MEMBER WITH NO INITIALIZER IS ITS CLASS'S DEFINITION (0.218; [class.static.data]/4, [dcl.init]/7), every
%% unit's, linkonce, DEFAULT-INITIALIZED: a class with a constructor that is no trivial default one constructed before main in
%% its class's words under the variable's guard, its destructor registered (cpp_dynamic_init/6, no initializer: the default
%% constructor), as a namespace-scope one is (cpp_global_object/5); any other type its zero bytes, a destructor registered
%% all the same. `struct K { static inline std::vector<int> all; };' was declared `extern' and its first use failed at the link
cpp_static_default_init(C, Name, T) :- cpp_class_of_type(T, TC), cpp_has_ctors(TC), \+ cpp_trivial_default(TC), !, cpp_dynamic_init(C, linkonce, Name, T, TC, none).
cpp_static_default_init(_, Name, T) :- cpp_static_dtor_reg(Name, T).
%% A STATIC MEMBER DECLARED `auto' TAKES THE TYPE OF ITS INITIALIZER ([dcl.spec.auto]), desugared in its class's words:
%% libc++'s `_IterOps<_RangeAlgPolicy>' writes `static constexpr auto __iter_move = ranges::iter_move;', a customization
%% point object, and every ranges algorithm calls through it.
cpp_static_auto(C, N, T0, T) :- cpp_has_auto(T0), cpp_sinit(C, N, E), !,
    (   once(catch(cpp_in_class(C, ( cpp_init_expr(E, E1), ccl_type_of(E1, IT), IT \== unknown, cpp_auto_deduce(T0, IT, T) )), error(not_lowered(_), _), fail)) -> cpp_static_name(C, N, Name), ccl_gdeclare([Name-T]), ccl_tables_changed
    ;   cpp_refuse(0, auto_static(C, N)) ).
cpp_static_auto(_, _, T, T).
%% ... AND A STATIC MEMBER WHOSE INITIALIZER IS AN AGGREGATE IS ITS OWN DEFINITION TOO, its items desugared in the
%% class's own words as a scalar's are (cpp_fold_static): libc++ writes `static constexpr bool
%% __matches[sizeof...(_Args)] = {is_same<_T1, _Args>::value...}', which is the array `get<T>' searches for a
%% type's place in a tuple, and only a FOLDING SCALAR was defined here -- the array was emitted `extern' and the
%% link named it.
cpp_static_constructed(C, N, T, I) :- cpp_sinit(C, N, E), cpp_class_of_type(T, TC), cpp_has_ctors(TC),
    once(catch(cpp_in_class(C, ( cpp_fold_ctor_init(N, T, TC, E, I0), cpp_eval_init_term_ok(I0) )), error(not_lowered(_), _), fail)), I = I0.
cpp_eval_init_term_ok(I) :- I \== none.
cpp_ctor_class_type(T) :- cpp_class_of_type(T, TC), cpp_has_ctors(TC), !.
%% A FLOATING STATIC MEMBER INITIALIZED IN ITS CLASS IS ITS OWN DEFINITION (0.143), linkonce as an integral one is, where
%% its initializer, desugared in the class's words, is a floating constant the lowering folds (ir_fp_global/2,
%% ir_fp_value/2: a literal, an integer constant, a cast, a sign, the four operations). `static constexpr double half =
%% 0.5;', `static inline double c = 3.5;' and `static constexpr T v = T(0.25);' were declared `extern' and defined
%% nowhere, so every use named them at the link; an initializer the lowering cannot fold keeps that road
cpp_static_floating(C, N, T, I) :- catch(ir_fp_global(T, _), _, fail), cpp_sinit(C, N, E), E \= init(_),
    once(catch(cpp_in_class(C, cpp_init_expr(E, I)), error(not_lowered(_), _), fail)),
    catch(ir_fp_value(I, _), _, fail), !.
%% ... and one whose initializer does not fold -- another floating static (`static constexpr double tau = 2 * pi;'), a
%% call of a constexpr function -- is its zero, assigned before main by the unit's `$cpp_ginit' in the class's words, as
%% a namespace-scope scalar is (0.117): the constexpr evaluator holds no floating value
cpp_static_floating_late(C, N, T, E) :- catch(ir_fp_global(T, _), _, fail), cpp_sinit(C, N, E), E \= init(_), !.
%% ... AND AN INTEGRAL, ENUMERATION OR POINTER STATIC WHOSE INITIALIZER THIS COMPILER DOES NOT FOLD (0.160) -- one over a template
%% value argument kept as written (`targ_raw': `S<half(4.0)>' with `constexpr int half(double)', which the evaluator does not run,
%% since it holds no floating value) -- is its zero, assigned before main in the class's words, as a floating one is: it was
%% declared `extern', defined nowhere, and its first use failed at the link. An aggregate's initializer keeps the old road.
cpp_static_scalar_late(C, N, T, E) :- cpp_sinit(C, N, E), E \= init(_), catch(ccl_resolve_type(T, RT), _, fail),
    ( RT = base(_, [K|_]), atom(K), ccl_basic_type(K) ; RT = base(_, [X|_]), compound(X), ( X = enum(_, _) ; X = enum_class(_, _) ) ; RT = ptr(_, _) ), !.
cpp_static_aggregate(C, N, I) :- cpp_sinit(C, N, E), E = init(_),
    once(catch(cpp_in_class(C, ( cpp_init_expr(E, I0), cpp_fold_items(I0, I) )), error(not_lowered(_), _), fail)),
    \+ cpp_has_call(I).   % an item that does not fold is no constant: the static is DECLARED (cpp_static_decls' last road) -- libc++ 18's
                          % `__handles_', immediately invoked lambdas, serves only the consteval check this compiler drops (0.110)
%% A STATIC AGGREGATE MEMBER INITIALIZED BY A CALL, `T x{f()}' or `T x = f()', IS THE VALUE THE CALL ANSWERS (0.201): libc++'s
%% <mdspan> writes `static constexpr array<_Tp, sizeof...(_Values)> __result{__static_partial_sums_impl()};' over a static
%% constexpr function of its own class that fills an array through its `operator[]', and the static was declared and not
%% defined -- the link named it. The call is desugared in the class and run by the evaluator, TWICE: the first attempt emits
%% the instances the call runs through, and only the second sees them (as a file-scope constant's, cpp_fold_const_inits_/4).
cpp_static_agg_call(C, N, T, I) :- cpp_sinit(C, N, E), ( E = init([item(_, E0)]) -> true ; E0 = E ), E0 = call(_, _), catch(cpp_eval_agg_kind(T, _), _, fail),
    once(( between(1, 2, _), catch(cpp_in_class(C, ( cpp_expr(C, E0, E1), cpp_eval_init(T, E1, [], _, AV) )), _, fail) )),
    cpp_eval_init_term(AV, I), !.
cpp_has_call(call(_, _)) :- !.
cpp_has_call(stmt_expr(_)) :- !.
cpp_has_call(T) :- compound(T), T =.. [_|As], member(A, As), cpp_has_call(A), !.
%% A CONSTANT'S ITEMS ARE FOLDED, a constexpr call through the evaluator (0.112): libc++ 18's `basic_format_string' holds
%% `static constexpr array<__arg_t, sizeof...(_Args)> __types_{__determine_arg_t<_Context, ...>()...}', and a call is no
%% constant to the lowering (`staticpack.cpp')
cpp_fold_items(init(Items), init(Items1)) :- !, findall(item(D, V1), ( member(item(D, V0), Items), once(cpp_fold_items(V0, V1)) ), Items1).
cpp_fold_items(V, F) :- V = call(_, _), catch(cpp_const_value(V, K), _, fail), !, ( integer(K) -> F = int(K) ; K = bool(_) -> F = K ; F = V ).
cpp_fold_items(V, V).
%% a type resolved where it can be, left as it stands where it cannot: a member's, a static's -- written in the
%% class's own words (`type', `pointer'), which nothing outside the class resolves, the global table's entry of
%% that name being some other class's
cpp_resolved_type(T0, T) :- ( catch(cpp_type(T0, T1), error(not_lowered(_), _), fail) -> T = T1 ; T = T0 ).
%% the members that are functions
cpp_member_fns([], _, _, _, []).
cpp_member_fns([method(_, Qs, _, _, Ps, _, _)|Ms], C, B, Ds, Fs) :- memberchk(requires(_), Qs), \+ cpp_method_viable(C, Qs, Ps), !, cpp_member_fns(Ms, C, B, Ds, Fs).   % its constraints unmet: not instantiated
cpp_member_fns([method(L, Qs, Ret0, M, Ps, V, Body)|Ms], C, B, Ds, [F|Fs]) :- memberchk(explicit_this(N, T0), Qs), !,     % C++23: the object parameter as declared; the body has no implicit this
    cpp_mangle_q(C, M, Qs, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_self_param(L, C, N, T0, Self), Params = [Self|Ps1],
    cpp_fsig_own(M, fsig(member, C, M, Ret0, Ps, V, Qs, none), Sig), cpp_with_fsig(Sig, cpp_method_ret(C, Ret0, Params, Body, Ret)),
    ( memberchk(closure, Qs) -> Ctx = self(C, N) ; Ctx = none ),                                                           % a lambda's captures are reached through it
    (   Body == none -> F = declaration(L, none, Ret, [var(Name, fn(Ret, Params, V), none)])
    ;   cpp_with_fsig(Sig, cpp_method_body(Ctx, Ret, Params, Body, Body1)), F = function(L, none, Ret, Name, Params, V, Body1) ),
    cpp_member_fns(Ms, C, B, Ds, Fs).
cpp_member_fns([method(L, Qs, Ret0, M, Ps, V, Body)|Ms], C, B, Ds, [F|Fs]) :- !,
    cpp_mangle_q(C, M, Qs, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_this_type(C, Qs, ThisT), Params = [param(ThisT, this)|Ps1],
    cpp_fsig_own(M, fsig(member, C, M, Ret0, Ps, V, Qs, none), Sig),                                   % what its own name says (0.166): a member template's instance, its pattern's
    ( cpp_with_fsig(Sig, cpp_method_ret(C, Ret0, Params, Body, Ret)) -> true ; cpp_trace(method_ret_failed(C, M)), fail ),
    (   Body == none -> F = declaration(L, none, Ret, [var(Name, fn(Ret, Params, V), none)])
    ;   ( cpp_qs_guarded(C, Qs, Params, Body) -> cpp_nx_wrap(L, Body, BodyG) ; BodyG = Body ), cpp_with_fsig(Sig, cpp_method_body(C, Ret, Params, BodyG, Body1)) -> F = function(L, none, Ret, Name, Params, V, Body1)
    ;   cpp_trace(method_body_failed(C, M)), fail ),
    cpp_note_consteval(C, Qs, Name), cpp_nx_note_member(C, Qs, Ps, [F]),
    cpp_member_fns(Ms, C, B, Ds, Fs).
cpp_member_fns([ctor(_, Qs, Ps, _, _)|Ms], C, B, Ds, Fs) :- memberchk(requires(_), Qs), \+ cpp_method_viable(C, Qs, Ps), !, cpp_member_fns(Ms, C, B, Ds, Fs).   % a constructor whose constraints are unmet is not instantiated ([temp.inst]/11; 0.112)
cpp_member_fns([ctor(L, Qs, Ps, _, none)|Ms], C, B, Ds, [F|Fs]) :- !,                     % DECLARED, not defined: libc++'s bad_alloc() lives in the shipped binary -- a declaration, as a method and a destructor already were
    cpp_mangle(C, C, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_this_type(C, [], [fresh], ThisT), Params = [param(ThisT, this)|Ps1],
    F = declaration(L, none, base([], [void]), [var(Name, fn(base([], [void]), Params, false), none)]), cpp_nx_note_member(C, Qs, Ps, [F]),
    cpp_member_fns(Ms, C, B, Ds, Fs).
cpp_member_fns([ctor(L, Qs, Ps, Inits, Body0)|Ms], C, B, Ds, Fs) :- memberchk(consteval, Qs), Body0 \== block([]), cpp_lib_class(C), !,   % A LIBRARY CLASS'S CONSTEVAL CONSTRUCTOR: its body is a compile-time CHECK (basic_format_string parses the format string against the arguments' kinds) -- the run-time constructor initializes the members, and the whole body is kept as the CHECK TWIN the evaluator runs where the object is made (cpp_ce_twin, cpp_ce_check; 0.164)
    cpp_ce_twin(L, C, B, Ds, Ps, Inits, Body0), cpp_member_fns([ctor(L, Qs, Ps, Inits, block([]))|Ms], C, B, Ds, Fs).
cpp_member_fns([ctor(L, Qs, Ps, Inits, Body)|Ms], C, B, Ds, Out) :- !,
    cpp_ctor_fn(L, C, B, Ds, Ps, Inits, Body, F), cpp_nv_twin(C, F, cpp_ctor_fn(L, C, B, Ds, Ps, Inits, Body, F2), F2, Out, Fs),
    ( F = function(_, _, _, CName, _, _, _) -> cpp_note_consteval(C, Qs, CName) ; true ), cpp_nx_note_member(C, Qs, Ps, [F]),
    cpp_member_fns(Ms, C, B, Ds, Fs).
cpp_member_fns([dtor(L, _, Body)|Ms], C, B, Ds, Fs) :- !,
    cpp_dtor_fn(L, C, Body, F), cpp_nv_twin(C, F, cpp_dtor_fn(L, C, Body, F2), F2, Fs, Fs1), cpp_nx_note_dtor(C, [F]),
    cpp_member_fns(Ms, C, B, Ds, Fs1).
cpp_member_fns([_|Ms], C, B, Ds, Fs) :- cpp_member_fns(Ms, C, B, Ds, Fs).
%% THE PROGRAM'S CONSTEVAL MEMBER FUNCTION AND CONSTRUCTOR ARE IMMEDIATE ([dcl.constexpr]/13; 0.112), as its free one has
%% been since 0.99: a call of one folds (cpp_consteval_fold, cpp_decl_pieces' consteval constructor) or refuses
%% `consteval_call_not_constant'. A library class's constructor is checked through its twin since 0.164 (below,
%% cpp_ce_twin/7 and cpp_ce_check/3: basic_format_string's format parse); its other consteval members run at run time.
cpp_note_consteval(C, Qs, Name) :- ( memberchk(consteval, Qs), \+ cpp_lib_class(C), \+ '$cpp_consteval'(Name) -> assertz('$cpp_consteval'(Name)) ; true ).
%% THE CHECK TWIN (0.164): the library's consteval constructor desugared WHOLE -- its member initializers and its body --
%% under the name `<CName>.ce', a function the evaluator finds ('$cpp_ownfn') and the lowering never sees, recorded as
%% `'$cpp_cecheck'(CName, Twin, C)'. A twin the desugaring refuses leaves the constructor unchecked, as it was until 0.163.
cpp_ce_twin(L, C, B, Ds, Ps, Inits, Body) :-
    (   catch(cpp_ctor_fn(L, C, B, Ds, Ps, Inits, Body, F), E, ( cpp_trace(consteval_ctor_twin_refused(C, E)), fail )),
        F = function(L1, S1, R1, CName, P1, V1, B1)
    ->  atom_concat(CName, '.ce', Twin), assertz('$cpp_ownfn'(Twin, function(L1, S1, R1, Twin, P1, V1, B1))),
        ( '$cpp_cecheck'(CName, _, _) -> true ; assertz('$cpp_cecheck'(CName, Twin, C)) )
    ;   cpp_trace(consteval_ctor_unchecked(C)) ).
cpp_ctor_fn(L, C, B, Ds, Ps, Inits, Body, F) :- cpp_with_fsig(fsig(ctor, C, C, none, Ps, false, [], none), cpp_ctor_fn_(L, C, B, Ds, Ps, Inits, Body, F)).   % its member initializers are its own (0.166)
cpp_ctor_fn_(L, C, B, Ds, Ps, Inits, Body, F) :-
    cpp_mangle(C, C, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_this_type(C, [], [fresh], ThisT), cpp_vtt_params(C, [param(ThisT, this)|Ps1], Params),
    ccl_scope_push, ccl_declare_params(Params),                                     % the parameters are in scope while the MEMBER INITIALIZERS are built: `a_(a)' has to type `a' to pick the member's constructor
    ( catch(cpp_ctor_body(L, C, B, Ds, Inits, Body, Body0), E0, (ccl_scope_pop, throw(E0))) -> ccl_scope_pop ; ccl_scope_pop, cpp_trace(ctor_body_failed(C)), fail ),
    ( cpp_method_body(C, Params, Body0, Body1) -> true ; cpp_trace(ctor_walk_failed(C, Body0)), fail ),
    F = function(L, none, base([], [void]), Name, Params, false, Body1).
%% THE BASE-VARIANT CONSTRUCTOR AND DESTRUCTOR of a class with a table-reached virtual base (the Itanium ABI's C2 and
%% D2, 0.110): the same body without the virtual base's construction or destruction -- a diamond's path is built by it,
%% the complete object having built the shared base once -- and its tables those of the VTT it is handed (`$vtt', after
%% `this'; cpp_vtt_stores, 0.172). `C.C.k.nv', `C.dtor.0.nv', made beside the complete forms.
cpp_nv_twin(C, F, Goal, F2, [F, F3|Fs], Fs) :- cpp_has_nv_form(C), F = function(_, _, _, _, _, _, _), !,
    nb_setval('$cpp_nv', C), ( catch(Goal, E, (nb_setval('$cpp_nv', none), throw(E))) -> nb_setval('$cpp_nv', none) ; nb_setval('$cpp_nv', none), fail ),
    F2 = function(L2, S2, R2, N2, P2, V2, B2), atom_concat(N2, '.nv', N3), F3 = function(L2, S2, R2, N3, P2, V2, B2),
    ccl_declare(N3, fn(R2, P2, V2)).
cpp_nv_twin(_, F, _, _, [F|Fs], Fs).
cpp_nv_body(C) :- nb_current('$cpp_nv', X), X == C.
cpp_dtor_fn(L, C, Body, F) :-
    cpp_dtor_name(C, Body, Name), cpp_this_type(C, [], [dying], ThisT), cpp_vtt_params(C, [param(ThisT, this)], Params),
    (   Body == none -> F = declaration(L, none, base([], [void]), [var(Name, fn(base([], [void]), Params, false), none)])
    ;   cpp_with_fsig(fsig(dtor, C, C, none, [], false, [], none), ( cpp_dtor_body(L, C, Body, Body0), cpp_method_body(C, Params, Body0, Body1) )), F = function(L, none, base([], [void]), Name, Params, false, Body1) ).
%% a constructor's body: the base's constructor, then every member from its
%% initializer, else its default, in the members' order; then the body
%% A FUNCTION-TRY-BLOCK ([except.pre]/1, [except.handle]/15; 0.201): `C() try : m(x) { ... } catch (...) { ... }' -- the
%% bases, the member initializers and the body under one try, what was built destroyed before a handler is entered (its
%% cleanups inside the try, cpp_member_cleanup/4), and the exception RETHROWN where a handler's end is reached
cpp_ctor_body(L, C, B, Defaults, Inits, fntry(Block, Cs), block([try(L, block(Pre), Cs1)])) :- !,
    cpp_ctor_body(L, C, B, Defaults, Inits, Block, block(Pre)), cpp_fntry_handlers(L, Cs, Cs1).
cpp_ctor_body(L, C, B, Defaults, memberwise(S, Kind), block([]), Out) :- !,                  % the memberwise copy or move (cpp_norm_members_): the initializers written out, then the usual road
    (   '$cpp_union'(C) -> Out = block([expr(L, call(id(memcpy), [id(this), addr(id(S)), sizeof_type(base([], [typedef(C)]))]))])   % A UNION'S IS ITS BYTES, copied as bytes (0.83's rule for an anonymous union member): as an assignment the two sides were typed by two roads -- basic_string's `__rep' loaded its source as `[0 x i8]' where the slot was `{ i64, [16 x i8] }', which LLVM refused
    ;   cpp_class_l(C, cls(_, Data, _, _, _)),
        findall(init(N, [Src]), ( member(member(_, N, _), Data), N \== '$base', N \== '$vptr', cpp_memberwise_src(Kind, member(id(S), N), Src) ), MInits),
        findall(init(Slot, [ESrc]), ( '$cpp_base_slot'(C, E, Slot), \+ '$cpp_lvb'(C, E, _), cpp_memberwise_base_src(C, E, Kind, S, member(id(S), Slot), ESrc) ), EInits),   % a later VIRTUAL base with the held ones, below (0.172)
        ( B \== none -> cpp_base_src(B, S, BPl), cpp_memberwise_base_src(C, B, Kind, S, BPl, BSrc), Inits0 = [init(B, [BSrc])|MInits] ; Inits0 = MInits ),
        findall(init(V, [VSrc]), ( '$cpp_vb_holder'(C, V), cpp_memberwise_base_src(C, V, Kind, S, _, VSrc0), cpp_vbase_src(V, Kind, S, VSrc0, VSrc) ), VInits),   % each of several (0.171) -- A DIAMOND'S SHARED BASE is copied from the source's (0.135), never default-built -- reached through the source's table (0.163): the source may be a sub-object of a larger class, whose virtual base lies where that class put it (`D d2 = e;')
        append(Inits0, EInits, Inits1), append(VInits, Inits1, Inits),
        cpp_ctor_body(L, C, B, Defaults, Inits, block([]), Out) ).
cpp_ctor_body(L, C, _, _, Inits0, block(Body), block([expr(L, call(id(DName), [id(this)|DArgs1]))|Body1])) :-
    cpp_norm_inits(Inits0, Inits), member(init(N, DArgs), Inits), atom(N), cpp_own_name(C, N), !,   % A DELEGATING CONSTRUCTOR (C++11): the other constructor over this, and nothing else initialized -- pair's piecewise constructor delegates to its private one with the index sequences
    ( cpp_ctor(C, DArgs, DName) -> true ; length(DArgs, K), cpp_refuse(L, no_constructor(C, K)) ), cpp_fill_defaults(DName, DArgs, DArgs0), cpp_ref_args_of(DName, DArgs0, DArgs1),
    ( cpp_dtor(C, Dt) -> Body1 = [eh_cleanup(L, block([expr(L, call(id(Dt), [id(this)]))]))|Body] ; Body1 = Body ).   % ... ITS BODY THAT THROWS DESTROYS THE OBJECT its target completed ([except.ctor]/4; 0.201): the class's destructor, by a cleanup only the unwinding runs
cpp_ctor_body(L, C, B, Defaults, Inits0, block(Body), block(Pre)) :-
    cpp_norm_inits(Inits0, Inits), cpp_inits_known(L, C, B, Inits),
    (   '$cpp_vb_holder'(C, _), \+ cpp_nv_body(C)                                          % A DIAMOND'S HOLDER builds the shared base first, where it lies, then stores its tables, so every path's base-variant constructor reaches it -- its own base variant builds none (0.163)
    ->  cpp_vb_build_all(C, B, Vs), cpp_vb_calls_all(Vs, L, C, B, Inits, VCall),   % every held base, in the order the standard builds them (0.171, 0.173) -- the virtual first base in its place among them (0.175), where it was built first (0.172)
        cpp_vptr_store(L, C, VStore), append(VCall, VStore, VPre), append(VPre, Pre00, Pre)
    ;   Pre = Pre00 ),
    (   B \== none, \+ ( cpp_nv_body(C), '$cpp_vbase'(C) ), \+ ( '$cpp_vbase'(C), '$cpp_vb_holder'(C, _) )   % the base variant builds no virtual base, nor does the complete object here that built it first (above)
    ->  cpp_first_base_call(L, C, B, Inits, FirstCall0), cpp_first_base_cleanup(L, C, B, FCl), append(FirstCall0, FCl, FirstCall)   % ... and the base destroyed if what follows throws (0.201)
    ;   FirstCall = [] ),
    cpp_extra_init_groups(L, C, Inits, ExGs0), cpp_extra_group_cleanups(L, C, ExGs0, ExGs),
    cpp_bases_in_order(C, FirstCall, ExGs, BaseCalls), append(BaseCalls, Pre1, Pre00),   % each base WITH storage of its own, in declaration order
    ( cpp_nv_body(C) -> cpp_vtt_stores(L, C, Store) ; cpp_vptr_store(L, C, Store) ), append(Store, Pre2, Pre1),   % the base variant stores the tables of the VTT it was handed, its bases built (0.172)
    cpp_class_l(C, cls(_, Data0, _, _, _)),
    (   '$cpp_union'(C) -> cpp_union_inits(Data0, Inits, Defaults, Data), cpp_member_inits(Data, Inits, Defaults, L, Pre2, Body)
    ;   cpp_member_inits_cl(Data0, Inits, Defaults, L, Pre2, Body) ).   % each member destroyed if what follows throws (0.201); a union's members are no object's to destroy
%% A CONSTRUCTOR THAT THROWS DESTROYS WHAT IT HAS BUILT ([except.ctor]/3; 0.201): each base and each member with a destructor, once
%% built, is followed by a cleanup that only an exception's unwinding runs, `eh_cleanup(L, Body)' (the lowering's eh_only defer,
%% ir_stmt_(eh_cleanup)), so a throw from a later member's initializer or from the body destroys the built ones in the reverse of
%% their construction, then propagates -- they were left, their destructors never run (`T() : a(1), b(boom(2))' leaked a's string).
%% The destructor called is the one the class's own destructor calls for that sub-object (cpp_dtor_body/4); a virtual base the
%% complete object built alike (cpp_vb_cleanup/4), and a delegating constructor's completed object by the class's destructor.
cpp_member_inits_cl([], _, _, _, Body, Body).
cpp_member_inits_cl([M|Ds], Inits, Defaults, L, Pre, Body) :- cpp_member_inits([M], Inits, Defaults, L, Pre, Pre1), cpp_member_cleanup(M, L, Pre1, Pre2),
    cpp_member_inits_cl(Ds, Inits, Defaults, L, Pre2, Body).
cpp_member_cleanup(member(MT, N, _), L, [eh_cleanup(L, block(Ss))|Rest], Rest) :- atom(N), N \== '$vptr', cpp_member_dtor(MT, arrow(this, N), L, Ss), Ss \== [], !.
cpp_member_cleanup(_, _, Rest, Rest).
cpp_first_base_cleanup(L, C, B, [eh_cleanup(L, block([expr(L, call(id(BName), BArgs))]))]) :- \+ ( cpp_nv_body(C), '$cpp_vbase'(C) ), cpp_dtor(B, BName0), cpp_nv_dtor(C, B, BName0, BName), BName \== '$no_dtor', !,   % a virtual first base too where this constructor built it, a complete object's (0.201)
    cpp_class_base_place(C, B, BPlace), cpp_vtt_pass(C, B, BName, [BPlace], BArgs).
cpp_first_base_cleanup(_, _, _, []).
cpp_extra_group_cleanups(L, C, Gs0, Gs) :- findall(E-Slot, '$cpp_base_slot'(C, E, Slot), ESs), cpp_extra_group_cleanups_(ESs, Gs0, L, C, Gs).
cpp_extra_group_cleanups_([E-Slot|ESs], [G0|Gs0], L, C, [G|Gs]) :- !,
    findall(expr(L, call(id(EName), EArgs)), ( \+ '$cpp_lvb'(C, E, _), cpp_dtor(E, EName0), cpp_nv_dtor(C, E, EName0, EName), EName \== '$no_dtor', cpp_vtt_pass(C, E, EName, [addr(arrow(this, Slot))], EArgs) ), Ds),
    ( Ds == [] -> G = G0 ; append(G0, [eh_cleanup(L, block(Ds))], G) ), cpp_extra_group_cleanups_(ESs, Gs0, L, C, Gs).
cpp_extra_group_cleanups_(_, Gs, _, _, Gs).
%% the handlers of a constructor's or a destructor's function-try-block: the exception rethrown at each one's end ([except.handle]/15)
cpp_fntry_handlers(_, [], []).
cpp_fntry_handlers(L, [catch(P, block(Bs))|Cs], [catch(P, block(Bs1))|Cs1]) :- !, append(Bs, [expr(L, throw(none))], Bs1), cpp_fntry_handlers(L, Cs, Cs1).
cpp_fntry_handlers(L, [C|Cs], [C|Cs1]) :- cpp_fntry_handlers(L, Cs, Cs1).
%% the first base's constructor over its place, from its initializer in the class, else by its default constructor
cpp_first_base_call(L, C, B, Inits, FirstCall) :-
    ( memberchk(init(B, BArgs), Inits) -> true ; cpp_alias_base_init(C, B, Inits, BArgs) -> true ; BArgs = [] ),   % the base named through an ALIAS: `using __base = __optional_iterator_base<_Tp>; ... : __base(in_place, ...)' -- dropped, the base was default-constructed and the optional never engaged
    ( cpp_base_ctor(B, BArgs, BName0) -> ( '$cpp_nv_base'(C, B) -> atom_concat(BName0, '.nv', BName) ; BName = BName0 ), cpp_fill_defaults(BName0, BArgs, BArgs1), cpp_class_base_place(C, B, BPlace), cpp_vtt_pass(C, B, BName, [BPlace|BArgs1], CArgs), FirstCall = [expr(L, call(id(BName), CArgs))]
    ; BArgs == [], \+ cpp_no_default_ctor(B) -> FirstCall = []
    ; cpp_refuse(L, base_constructor(B)) ).
%% THE VIRTUAL BASES IN THE ORDER THE STANDARD BUILDS THEM, the class's virtual first base among them (0.175): a nearly empty primary
%% written after another virtual base -- `XJ2 : virtual K, virtual I' -- is built after K and destroyed before it, though it lies first
cpp_vb_build_all(C, B, Vs) :- findall(V, '$cpp_vb_holder'(C, V), Hs0), ( '$cpp_vbase'(C), B \== none -> Hs = [B|Hs0] ; Hs = Hs0 ),
    cpp_vb_post(C, P), findall(V, ( member(V, P), memberchk(V, Hs) ), Vs1), findall(V, ( member(V, Hs), \+ memberchk(V, Vs1) ), Rest), append(Vs1, Rest, Vs).
cpp_vb_calls_all([], _, _, _, _, []).
cpp_vb_calls_all([V|Vs], L, C, B, Inits, Calls) :- ( V == B, '$cpp_vbase'(C) -> cpp_first_base_call(L, C, B, Inits, Call) ; cpp_vb_calls([V], L, C, Inits, Call) ),
    cpp_vb_cleanup(V, L, C, B, Cl), append(Call, Cl, Call1),   % ... each DESTROYED IF WHAT FOLLOWS THROWS ([except.ctor]/3; 0.201), as a base and a member are (cpp_member_cleanup/4)
    cpp_vb_calls_all(Vs, L, C, B, Inits, Calls0), append(Call1, Calls0, Calls).
cpp_vb_cleanup(V, L, C, B, Cl) :-
    (   V == B, '$cpp_vbase'(C) -> cpp_first_base_cleanup(L, C, B, Cl)   % the virtual first base where the destructor destroys it (cpp_dtor_body/4's FirstDtor)
    ;   findall(expr(L, call(id(VName), VArgs)), ( cpp_dtor(V, VName0), cpp_vb_place(C, V, VPl), cpp_vb_dtor_name(V, VName0, VName), VName \== '$no_dtor', cpp_vtt_pass(C, V, VName, [VPl], VArgs) ), D),
        ( D == [] -> Cl = [] ; Cl = [eh_cleanup(L, block(D))] ) ).
cpp_vb_dtors([], _, _, _, _, []).
cpp_vb_dtors([V|Vs], L, C, B, FirstDtor, Out) :-
    (   V == B, '$cpp_vbase'(C) -> D = FirstDtor
    ;   findall(expr(L, call(id(VName), VArgs)), ( cpp_dtor(V, VName0), cpp_vb_place(C, V, VPl), cpp_vb_dtor_name(V, VName0, VName), VName \== '$no_dtor', cpp_vtt_pass(C, V, VName, [VPl], VArgs) ), D) ),
    cpp_vb_dtors(Vs, L, C, B, FirstDtor, Out0), append(D, Out0, Out).
%% the held virtual bases built where they lie, each from its initializer in the class, else by its default constructor
cpp_vb_calls([], _, _, _, []).
cpp_vb_calls([V|Vs], L, C, Inits, Calls) :- cpp_vb_place(C, V, VPl),
    ( memberchk(init(V, VArgs), Inits) -> true ; VArgs = [] ),
    (   cpp_base_ctor(V, VArgs, VName0) -> cpp_fill_defaults(VName0, VArgs, VArgs1),
        ( cpp_vb_nv(V) -> atom_concat(VName0, '.nv', VName), cpp_vtt_pass(C, V, VName, [VPl|VArgs1], CArgs) ; VName = VName0, CArgs = [VPl|VArgs1] ),   % one with virtual bases of its own by its base variant and its part of the VTT (0.173)
        Call = [expr(L, call(id(VName), CArgs))]
    ;   VArgs == [], \+ cpp_no_default_ctor(V) -> Call = []
    ;   cpp_refuse(L, base_constructor(V)) ),
    cpp_vb_calls(Vs, L, C, Inits, Calls0), append(Call, Calls0, Calls).
%% where a held virtual base lies in the complete object: its member, an empty one the object's own address (0.172) -- by a cast
%% through `void *', which takes no base route: the base is built before any table is stored (0.173)
cpp_vb_place(C, V, P) :- ( ( cpp_empty_class(V) ; cpp_vb_at_self(C, V) ) -> P = cast(ptr([], base([], [typedef(V)])), cast(ptr([], base([], [void])), id(this))) ; '$cpp_vb_claim'(C, V, H) -> cpp_poly_access(H, Acc), P = cast(ptr([], base([], [typedef(V)])), cast(ptr([], base([], [void])), addr(Acc))) ; cpp_vb_name(C, V, VN), P = addr(arrow(this, VN)) ).   % ... a claimed one at its claimant's address (0.174), one at the class's own address there (0.178)
cpp_memberwise_src(copy, E, E).
cpp_memberwise_src(move, E, move(E)).
%% THE SOURCE OF A BASE in a memberwise copy or move: its slot, or -- for a diamond's path, whose slot is the base-variant struct
%% `B.nv' -- the source itself cast to the base (0.135; the base's copy constructor takes a B, which `B.nv' is not:
%% `base_constructor(B)' refused the implicit copy of every diamond)
cpp_memberwise_base_src(C, B, Kind, S, _, Src) :- '$cpp_nv_base'(C, B), !,
    ( Kind == copy -> Src = ccast(static, ref([const], base([], [typedef(B)])), id(S)) ; Src = move(ccast(static, ref([], base([], [typedef(B)])), id(S))) ).
cpp_memberwise_base_src(_, _, Kind, _, Pl, Src) :- cpp_memberwise_src(Kind, Pl, Src).
cpp_vbase_src(V, Kind, S, _, Src) :- ( Kind == copy -> Src = ccast(static, ref([const], base([], [typedef(V)])), id(S)) ; Src = move(ccast(static, ref([], base([], [typedef(V)])), id(S))) ).   % the source as its virtual base, a conversion the lowering takes through its table
cpp_extra_inits(L, C, Inits, Ss) :- findall(B-Slot, '$cpp_base_slot'(C, B, Slot), BSs), cpp_extra_inits_(BSs, L, C, Inits, Ss).
cpp_extra_init_groups(L, C, Inits, Gs) :- findall(B-Slot, '$cpp_base_slot'(C, B, Slot), BSs), cpp_extra_groups_(BSs, L, C, Inits, Gs).
cpp_extra_groups_([], _, _, _, []).
cpp_extra_groups_([BS|BSs], L, C, Inits, [G|Gs]) :- cpp_extra_inits_([BS], L, C, Inits, G), cpp_extra_groups_(BSs, L, C, Inits, Gs).
%% ... each named directly, by its slot, or THROUGH AN ALIAS as the first base may be (cpp_alias_base_init), and
%% never silently: libc++ 18's `__compressed_pair() : _Base1(__value_init_tag()), _Base2(__value_init_tag())' names
%% both bases through `using _Base2 = __compressed_pair_elem<_T2, 1>', and a findall that merely FAILED on the second
%% left it unconstructed -- a base with constructors and no default one given no initializer is refused now
%% (base_constructor), as the first base has been
cpp_extra_inits_([], _, _, _, []).
cpp_extra_inits_([B-_|BSs], L, C, Inits, Ss) :- '$cpp_lvb'(C, B, _), !, cpp_extra_inits_(BSs, L, C, Inits, Ss).   % a later VIRTUAL base: built by the complete object, first (cpp_vb_calls; 0.172)
cpp_extra_inits_([B-Slot|BSs], L, C, Inits, Ss) :-
    ( memberchk(init(B, BArgs), Inits) -> true ; memberchk(init(Slot, BArgs), Inits) -> true ; cpp_alias_base_init(C, B, Inits, BArgs) -> true ; BArgs = [] ),
    ( '$cpp_nv_base'(C, B), \+ cpp_nv_body(C) -> cpp_sec_store(L, C, Slot, St) ; St = [] ),   % a diamond's later path: this class's table for it first, so its base-variant constructor reaches the shared base -- in the base variant the complete object's, stored already (0.163)
    (   cpp_base_ctor(B, BArgs, BName0) -> ( '$cpp_nv_base'(C, B) -> atom_concat(BName0, '.nv', BName) ; BName = BName0 ), cpp_fill_defaults(BName0, BArgs, BArgs1), cpp_vtt_pass(C, B, BName, [addr(arrow(this, Slot))|BArgs1], CArgs), append(St, [expr(L, call(id(BName), CArgs))|Ss1], Ss)
    ;   BArgs == [], \+ cpp_no_default_ctor(B) -> append(St, Ss1, Ss)
    ;   cpp_refuse(L, base_constructor(B)) ),
    cpp_extra_inits_(BSs, L, C, Inits, Ss1).
%% A BASE WITH CONSTRUCTORS AND NO DEFAULT ONE MUST BE NAMED BY AN INITIALIZER ([class.base.init]/9: a base no
%% initializer names is default-initialized, and a class with a user-declared constructor, none of which takes no
%% argument, cannot be): refused by name (0.112), where the base was left unconstructed and the comment above said
%% refused. A base with no constructor at all is left alone, as C++ leaves it; a constructor whose parameters all
%% have defaults, a pack, a constructor template that may take nothing and `C() = default' are default constructors.
cpp_no_default_ctor(B) :- cpp_class(B, cls(_, _, Ms, _, _, _)),
    ( memberchk(ctor(_, _, _, _, _), Ms) -> true ; '$cpp_mt'(B, ctor, _, _) ), !,
    \+ '$cpp_default_ctor'(B),
    \+ ( member(ctor(_, _, Ps, _, _), Ms), cpp_arity_fits(Ps, 0) ),
    \+ ( '$cpp_mt'(B, ctor, _, ctor(_, _, Ps2, _, _)), cpp_arity_fits(Ps2, 0) ).
%% AN INITIALIZER THAT NAMES NOTHING THE CLASS HAS IS REFUSED, never dropped (0.100): the base (by its name, its alias
%% or its slot), a data member (an anonymous union's through its hop), a class named as a base; anything else is
%% `unknown_initializer', where a silent drop left the object unconstructed and the defect surfaced as garbage at run time
cpp_inits_known(_, _, _, []).
cpp_inits_known(L, C, B, [init(N, _)|Is]) :- atom(N), !, ( cpp_init_known(C, B, N) -> true ; cpp_refuse(L, unknown_initializer(C, N)) ), cpp_inits_known(L, C, B, Is).
cpp_inits_known(L, C, B, [_|Is]) :- cpp_inits_known(L, C, B, Is).
cpp_init_known(_, B, N) :- N == B, !.
cpp_init_known(C, _, N) :- catch(cpp_data_member(C, N, _), _, fail), !.
cpp_init_known(C, _, N) :- ( '$cpp_base_slot'(C, N, _) ; '$cpp_base_slot'(C, _, N) ), !.
cpp_init_known(C, _, N) :- catch(cpp_class_typedef(C, N, _, _), _, fail), !.
cpp_init_known(C, _, N) :- '$cpp_vb_holder'(C, N), !.                                      % the most derived class names the virtual base it builds
cpp_init_known(_, _, N) :- catch(cpp_class_l(N, _), _, fail), !.
cpp_init_known(C, B, N) :- cpp_ns_typedef_class(N, K), ( K == B ; '$cpp_base_slot'(C, _, K) ; '$cpp_base_slot'(C, K, _) ; '$cpp_vb_holder'(C, K) ), !.   % a base named through a NAMESPACE's typedef (0.201, cpp_alias_base_init/4)
cpp_alias_base_init(C, B, Inits, Args) :- member(init(N, Args), Inits), atom(N), \+ cpp_data_member(C, N, _),
    catch(cpp_class_typedef(C, N, T0, Def), _, fail), catch(cpp_in_class(Def, cpp_type(T0, T)), _, fail), cpp_class_of_type(T, B), !.
%% ... AND THROUGH A NAMESPACE'S TYPEDEF ([class.base.init]/2: a mem-initializer-id names a base by any name of its type;
%% 0.201): libc++'s `class strstream : public iostream' writes `strstream() : iostream(&__sb_) {}' over `typedef
%% basic_iostream<char> iostream;', and the constructor was refused `unknown_initializer(strstream, iostream)'
cpp_alias_base_init(C, B, Inits, Args) :- member(init(N, Args), Inits), atom(N), \+ cpp_data_member(C, N, _),
    \+ catch(cpp_class_typedef(C, N, _, _), _, fail), cpp_ns_typedef_class(N, B), !.
cpp_ns_typedef_class(N, K) :- atom(N), catch(ccl_typedef_of(N, T0), _, fail), catch(cpp_type(T0, T), error(not_lowered(_), _), fail), cpp_class_of_type(T, K).
%% A UNION'S CONSTRUCTOR initializes AT MOST ONE member and leaves every other alone: they share the storage, and
%% default-constructing the rest would both overwrite it and demand a constructor none of them need. libc++'s
%% `__rep(__short __r) : __s(__r) {}' names one of two.
cpp_union_inits(Ds, Inits, Defaults, Ds1) :-
    findall(member(T, N, I), ( member(member(T, N, I), Ds), ( memberchk(init(N, _), Inits) ; memberchk(N-_, Defaults) ) ), Ds1).
%% an initializer naming a base by its template-id names the instance
cpp_norm_inits([], []).
cpp_norm_inits([init(N0, As)|Is], [init(N, As)|Js]) :- ( atom(N0) -> N = N0 ; cpp_base_name(N0, N) ), cpp_norm_inits(Is, Js).
cpp_norm_inits([I|Is], [I|Js]) :- cpp_norm_inits(Is, Js).
%% the class an initializer's argument has, on the RAW expression a constructor's initializer list carries (it is
%% desugared later, with the body): through a `std::move', which is how a guard takes its rollback
%% THE TYPE AN ARGUMENT HAS, wherever the raw form cannot say it: through a `move' in either spelling, and else
%% through the DESUGARED form. A member initializer and a call's arguments are both raw when they are scored, and
%% libc++ writes `__rep_(std::move(__str.__rep_))' -- whose type the inference cannot tell, so every candidate
%% scored the 1 that an unknown type earns and the FIRST constructor won, `__rep(__short)' for a `__rep'.
cpp_arg_type(move(X), T) :- !, cpp_arg_type(X, T).                       % THE MOVE FORMS FIRST: <utility> comes in with
cpp_arg_type(call(scoped(_, move), [X]), T) :- !, cpp_arg_type(X, T).   % every container, so `std::move' is a declared template whose RAW result type would otherwise win
cpp_arg_type(A, tmplfn(F)) :- cpp_fn_template_ref(A, F), !.               % A FUNCTION TEMPLATE'S NAME has no type of its own: a target type gives it one (cpp_deduce_target)
cpp_arg_type(A, T) :- ( A = member(_, _) ; A = arrow(_, _) ), ccl_type_of(A, T0), T0 \== unknown, \+ cpp_raw_type(T0), \+ cpp_type_const(T0), cpp_obj_const(A, const), !, ccl_add_quals([const], T0, T).   % A MEMBER OF A CONST OBJECT IS CONST (0.121): `std::forward<const V &>(v).__data' deduces `const _Vp' for the next call, where the inference's type lost the const -- libc++'s variant reached a const alternative through a non-const union
cpp_arg_type(A, T) :- \+ cpp_object_callee(A), \+ cpp_arity_clash(A), ccl_type_of(A, T0), T0 \== unknown, \+ cpp_raw_type(T0), \+ cpp_callee_param_type(A, T0), !, T = T0.   % ... but never a type that names a template's own parameter: a call of a FUNCTION TEMPLATE is typed by the inference from the raw signature the summary declares it under (0.49), `std::exchange(__other.__alloc_, nullopt)' as `_T1', and optional's `optional(_Up &&)' then deduced `_Up' as that free name (an allocator built from a `_T1' in the node handle's move constructor); the desugaring below instantiates the call and types it
cpp_arg_type(A, T) :- cpp_caller_ctx(Ctx, Class), catch(cpp_in_class(Class, cpp_expr(Ctx, A, A1)), _, fail), A1 \== A, ccl_type_of(A1, T0), T0 \== unknown, T = T0.   % in the CALLER's words (cpp_as_callee)
%% A CALL OF A NAMESPACE-SCOPE OBJECT, a customization point (`std::ranges::begin(r)'), is typed by the call the desugaring makes
%% of it, never by the inference (0.132): the table holds the flattened name's FUNCTIONS, libc++'s poison pill `void begin(auto &)
%% = delete;' among them, and the argument was `void' -- subrange's `subrange(ranges::begin(__r), ranges::end(__r))' chose no
%% constructor (lazy_split_view)
cpp_object_callee(call(scoped(Path, F), _)) :- atom(F), Path \== [], \+ catch(cpp_scope_class(Path, _), _, fail), ( catch(cpp_ns_key(Path, F, K), _, fail) -> true ; K = F ), catch(cpp_callable_global(K, _, _), _, fail), !.
%% THE TABLE'S ONE TYPE OF A NAME MAY BE ANOTHER OVERLOAD'S (0.201): a call with more arguments than a function of no ellipsis has
%% parameters is no call of it, and the call the desugaring makes is typed instead -- libc++'s poison pill `void make_error_code() =
%% delete;' (std::__adl_only) answered `std::make_error_code(e)' with void, and `std::error_code ec = std::make_error_code(
%% errc::invalid_argument)' chose no constructor
cpp_arity_clash(call(F, As)) :- ( F = id(N) ; F = scoped(_, N) ), atom(N), is_list(As), ccl_declared(N, fn(_, Ps, V)), is_list(Ps), V \== true, V \= q(true, _),
    length(As, NA), length(Ps, NP), NA > NP, !.
cpp_raw_type(base(_, [typedef(N)])) :- atom(N), \+ ccl_typedef_of(N, _), \+ ccl_tag(N, _), \+ cpp_class_l(N, _), \+ cpp_template(N, _, _), \+ cpp_declared_class(N), !.
cpp_raw_type(base(_, [typedef(X)])) :- cpp_template_id(X, _, Args), member(A, Args), cpp_free_arg(A), !.   % ... AND A TEMPLATE-ID OVER ONE IS RAW TOO, which only a bare name was
cpp_raw_type(base(_, [typedef(scoped(Path, _))])) :- member(S, Path), cpp_template_id(S, _, Args), member(A, Args), cpp_free_arg(A), !.   % ... and the template-id may sit in the PATH: `invoke_result_t<_Fn, _Args...>' is `typename invoke_result<_Fn, _Args...>::type', whose last name is `type' and whose scope carries the free one. A plain namespace segment is an atom and no template-id, so `std::x' is untouched
cpp_raw_type(ref(_, T)) :- cpp_raw_type(T).
cpp_raw_type(rref(_, T)) :- cpp_raw_type(T).
cpp_raw_type(ptr(_, T)) :- cpp_raw_type(T).
%% a template ARGUMENT that is a free name: a plain type naming no typedef, tag, class or template (a template parameter of
%% an enclosing template, unbound), through pointers and references; a value or a template-id is no such thing
cpp_free_arg(base(_, [typedef(N)])) :- atom(N), \+ ccl_typedef_of(N, _), \+ ccl_tag(N, _), \+ cpp_class_l(N, _), \+ cpp_template(N, _, _), \+ cpp_declared_class(N), !.
cpp_free_arg(ptr(_, T)) :- !, cpp_free_arg(T).
cpp_free_arg(ref(_, T)) :- !, cpp_free_arg(T).
cpp_free_arg(rref(_, T)) :- !, cpp_free_arg(T).
cpp_free_arg(pack(T)) :- !, cpp_free_arg(T).                                             % ... and through a PACK EXPANSION (0.93): `forward_as_tuple' is declared `tuple<_Tp &&...>', and typed by that raw result the compressed pair's piecewise constructor bound its `_Args1' to `_Tp &&' -- libc++ 18's `__alloc_func' is built so
%% a class DECLARED and never defined is a type, never a template's free name (0.201): the program's (`'$cpp_fwd'', cpp_note_fwd_classes/1)
%% and a header's, which keeps its namespace path (cpp_fwd_class_item/2)
cpp_declared_class(N) :- catch('$cpp_fwd'(N), _, fail), !.
cpp_declared_class(N) :- cpp_hdr_ns(N, _), !.
%% THE TYPE OF A CALL OF A FUNCTION TEMPLATE THAT NAMES THE TEMPLATE'S OWN PARAMETER IS RAW WHATEVER THE TABLES KNOW OF THAT NAME (0.126): `cpp_raw_type' calls a
%% name raw when no table holds it, and the tables hold `_Tp': libc++'s `__format_char' opens with `using _Tp = decltype(__value);', a typedef in a block joins the
%% unit's one table, and every instance the walk meets adds its own (`_Tp' as `int'). So `std::addressof(__max_output_size_)', typed by the signature the summary
%% declares, `_Tp *', became an `int *', fitted no `__max_output_size *' parameter, and libc++ 21's `__formatted_size_buffer', whose base is built from it, was refused
%% `base_constructor(__output_buffer.char)' -- only when `formatted_size' had walked a `_Tp' before. Inside the callee's own signature the name is its parameter
%% ([temp.local]), so the callee's parameter names decide, not the tables. `stdvformat.cpp' (libc++ 21), `rawparam.cpp'.
cpp_callee_param_type(call(F, _), T) :- ccl_call_name(F, N), ccl_fn_template(N), cpp_template(N, TPs, _),
    member(tparam(_, P, _), TPs), atom(P), cpp_mentions(T, typedef(P)), !.
cpp_init_arg_class(E, C) :- cpp_arg_type(E, T), ccl_unref(T, T1), cpp_class_of_type(T1, C), !.
cpp_init_arg_class(E, C) :- ( cpp_class_ctx(Cx) -> true ; Cx = none ), catch(cpp_expr(Cx, E, E1), _, fail), E1 \== E, cpp_class_of_type_of(E1, C).   % a type that is KNOWN but names no class -- a library template's raw result -- still leaves the DESUGARED form to ask. IN THE CLASS being built (0.117): a NESTED class's short name, `p_(param_type(a, b))' with `param_type' the class's own member type, is only a name there; with no context the call stayed as written and had no class, so `uniform_int_distribution::param_type __p_' was `member_not_constructed'
%% ... and where the RAW form cannot tell, the desugared one can: libc++'s copy constructor writes
%% `__alloc_(__alloc_traits::select_on_container_copy_construction(__str.__alloc_))', a static member call whose
%% result is the member's own class, and unasked it read as a member with no constructor to take it. Only the
%% CLASS is wanted here; the initializer itself is walked with the body, once, as it always was.
cpp_member_inits([], _, _, _, Body, Body).
cpp_member_inits([member(_, '$vptr', _)|Ds], Inits, Defaults, L, Pre, Body) :- !, cpp_member_inits(Ds, Inits, Defaults, L, Pre, Body).
%% AN ANONYMOUS UNION'S MEMBER INITIALIZED BY NAME: optional's storage writes `union { char __null_state_; value_type
%% __val_; }; ... : __val_(std::forward<_Args>(__args)...), __engaged_(true)', and `__val_' named no member of the
%% class itself, so the initializer was dropped and the value read back was garbage. The place is reached through
%% the member the union became (cpp_data_member's hop); a class constructs, a scalar is assigned, `m()' zeroes.
cpp_member_inits([member(MT, A, _)|Ds], Inits, Defaults, L, [expr(L, call(id(memcpy), [addr(arrow(this, A)), addr(Src), sizeof_type(MT)]))|Pre], Body) :-
    MT = base(_, [union(anon, _)]), memberchk(init(A, [Src]), Inits), !,   % the memberwise copy of an ANONYMOUS UNION is its bytes (the union of optional's storage, copied by the implicit copy constructor): as an assignment the lowering converted the union's bytes as a pointer
    cpp_member_inits(Ds, Inits, Defaults, L, Pre, Body).
cpp_member_inits([member(base(_, [union(anon, Ns)]), A, _)|Ds], Inits, Defaults, L, Pre, Body) :-
    member(member(MT, N, _), Ns), memberchk(init(N, Args), Inits), !,
    cpp_union_member_init(L, member(arrow(this, A), N), MT, Args, Pre, Pre1), cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
%% A REFERENCE MEMBER IS BOUND, never constructed and never assigned: its slot takes the object's ADDRESS, and
%% every later use reads through it (ir_ref_member). libc++'s `__destroy_vector' holds a `vector &' and binds it
%% in its constructor -- taken as a member of a class with constructors, that became `operator=' into an
%% uninitialized reference, which ran and crashed. With no initializer the member is left alone, as a closure's
%% captures are (an aggregate fills them item by item).
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :- ( MT = ref(_, _) ; MT = rref(_, _) ), !,
    (   memberchk(init(N, [E]), Inits) -> Pre = [expr(L, bind_ref(arrow(this, N), E))|Pre1]
    ;   memberchk(N-E, Defaults) -> Pre = [expr(L, bind_ref(arrow(this, N), E))|Pre1]
    ;   cpp_trace(reference_member_unbound(N)), Pre = Pre1 ),
    cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :- \+ memberchk(init(N, _), Inits), memberchk(N-init(Items), Defaults), cpp_class_of_type(MT, _), !,   % A BRACED DEFAULT MEMBER INITIALIZER OF A CLASS MEMBER IS LIST-INITIALIZATION (0.112): an aggregate from its items, its own default member initializers for the rest; a class with constructors through them. Handed over as ONE argument, the braced list itself, libc++'s `__code_point<_CharT> __fill_{}' left std::format's spec parser unregistered (member_not_constructed)
    cpp_member_from(MT, arrow(this, N), init(Items), L, Pre, Pre1), cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :- memberchk(init(N, [init(Items)]), Inits), cpp_designated_items(Items), !,   % A DESIGNATED BRACED LIST, `: m{.a = x, .b = y}' (C++20; the reader's one argument, ccl_designated_list//1, 0.201): the aggregate road, each designator naming its member's place (cpp_agg_values/3)
    cpp_member_from(MT, arrow(this, N), init(Items), L, Pre, Pre1), cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :- memberchk(init(N, Args), Inits), Args = [_|_], ccl_std_at_least(20), cpp_class_of_type(MT, _), cpp_paren_aggregate(MT, Args), !,   % AN AGGREGATE CLASS MEMBER FROM PARENTHESES (C++20; cpp_paren_aggregate/2, 0.197): `: q(3, P(4, 5))', and `: p(6)' of a struct a base clause promoted, which was ASSIGNED its one value (`sext i32 6 to %struct.P')
    findall(item([], A), member(A, Args), Items), cpp_member_from(MT, arrow(this, N), init(Items), L, Pre, Pre1), cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :- cpp_class_of_type(MT, MC), cpp_has_ctors(MC), !,   % a member of a class with constructors: constructed
    ( memberchk(init(N, Args0), Inits) -> true ; memberchk(N-E, Defaults) -> Args0 = [E] ; Args0 = [] ),
    ( Args0 = [call(id(TN), TArgs)], atom(TN), cpp_class_of_type(base([], [typedef(TN)]), MC) -> Args = TArgs ; Args = Args0 ),   % A PRVALUE OF THE MEMBER'S OWN CLASS INITIALIZES THE MEMBER IN PLACE ([class.copy.elision]/1; 0.122): `H() : m_(S(5))' is `m_(5)', the S constructed once in the member -- no move constructor runs, and a class that holds its own address stays whole
    length(Args, NA),
    (   cpp_ctor(MC, Args, CName) -> cpp_fill_defaults(CName, Args, Args1),
        ( Args == [], memberchk(init(N, []), Inits), cpp_value_zeroes(MC) -> cpp_zero_fill(MT, arrow(this, N), L, Pre, Pre0) ; Pre = Pre0 ),   % `m()' of a class whose default constructor is not user-provided: zeroed, then constructed (0.127)
        Pre0 = [expr(L, call(id(CName), [addr(arrow(this, N))|Args1]))|Pre1]
    ;   Args == [], cpp_trivial_default(MC)                                                        % nothing to construct: libc++'s allocator, `allocator() = default' and a converting template
    ->  ( memberchk(init(N, []), Inits) -> cpp_zero_fill(MT, arrow(this, N), L, Pre, Pre1) ; Pre = Pre1 )   % ... but `m()' WRITTEN OUT is VALUE-initialization, which ZEROES a class whose default constructor is not user-provided: basic_string's `: __rep_()', and left as garbage the union's `__is_long_' bit read long, `clear()' wrote through a null pointer
    ;   Args = [E], cpp_init_arg_class(E, MC)                                                      % the implicit copy or move: bitwise, as a struct copies; a class with a destructor keeps the rule
    ->  ( cpp_dtor(MC, _) -> cpp_refuse(L, copy_of_a_class_with_destructor(MC)) ; cpp_empty_class(MC) -> Pre = Pre1 ; Pre = [expr(L, assign('=', arrow(this, N), E))|Pre1] )   % ... and a member with NO BYTES copies none (cpp_zero_fill's rule, from the other side)
    ;   ( Args \== Args0 ; ccl_std_at_least(20) ), cpp_paren_aggregate(MT, Args)                % AN AGGREGATE MEMBER FROM PARENTHESES (C++20; cpp_paren_aggregate/2, 0.197), or from a prvalue of its class handed on above
    ->  findall(item([], A), member(A, Args), Items), cpp_member_from(MT, arrow(this, N), init(Items), L, Pre, Pre1)
    ;   cpp_refuse(L, member_not_constructed(N, MC, NA)) ),
    cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
%% AN ARRAY MEMBER (0.41's "array member of objects"): `: cells()' zeroes it (it was `cells = 0', an int into an
%% array), a memberwise copy or move takes the source's element by element where the element constructs (a
%% `std::string names[2]') and as its bytes otherwise, a nested braced list fills it, a default initializer likewise,
%% and with nothing said an array of objects default-constructs each element
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :- ccl_resolve_type(MT, arr(_, ET)), !,
    (   memberchk(init(N, [E]), Inits) -> cpp_array_item(E, E1), cpp_member_from(MT, arrow(this, N), E1, L, Pre, Pre1)
    ;   memberchk(init(N, Es), Inits), Es = [_, _|_] -> cpp_array_items(Es, Is), cpp_member_from(MT, arrow(this, N), init(Is), L, Pre, Pre1)   % `n_{5, 6}': several items, the elements in order (0.117)
    ;   memberchk(init(N, []), Inits) -> cpp_zero_fill(MT, arrow(this, N), L, Pre, Pre1)
    ;   memberchk(N-D, Defaults) -> cpp_member_from(MT, arrow(this, N), D, L, Pre, Pre1)
    ;   cpp_elem_class(ET, EC), cpp_has_ctors(EC) -> cpp_value_init(MT, arrow(this, N), L, Pre, Pre1)
    ;   Pre = Pre1 ),
    cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :- memberchk(init(N, Args), Inits), Args = [_|_], cpp_plain_aggregate(MT), cpp_aggregate_args(Args, MT), !,   % A PLAIN STRUCT OR UNION MEMBER INITIALIZED BY PARENTHESES from values that are not its own type is aggregate initialization ([dcl.init.general]/16.6.2.2, C++20): the first member from the first value, a union's the first member alone. libc++ 21's `basic_string() : __rep_(__short())' sets the union `__rep' to a short string; assigned, the value reached the lowering as `sext %struct.__short to %struct.__rep'. `unionparen.cpp'
    findall(item([], A), member(A, Args), Items), cpp_member_from(MT, arrow(this, N), init(Items), L, Pre, Pre1),
    cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
cpp_member_inits([member(MT, N, _)|Ds], Inits, Defaults, L, Pre, Body) :-
    (   memberchk(init(N, [E]), Inits) -> Pre = [expr(L, assign('=', arrow(this, N), E))|Pre1]
    ;   memberchk(init(N, []), Inits)                                                        % `second()' -- an EMPTY initializer VALUE-INITIALIZES ([dcl.init]/8): a scalar's zero, a class without constructors zero-filled (libc++'s __map_value_compare writes `: __comp_()' over an empty less<int>); left alone it was the member's garbage (7 32759 for pair<int, int>(piecewise_construct, forward_as_tuple(7), forward_as_tuple()))
    ->  ( cpp_scalar_member_type(MT) -> cpp_zero_of(MT, Z), Pre = [expr(L, assign('=', arrow(this, N), Z))|Pre1]
        ; cpp_zero_fill(MT, arrow(this, N), L, Pre, Pre1) )
    ;   memberchk(N-init([]), Defaults)                                                     % `T cur{};' -- a braced EMPTY default member initializer value-initializes as `m()' does (0.108)
    ->  ( cpp_scalar_member_type(MT) -> cpp_zero_of(MT, Z), Pre = [expr(L, assign('=', arrow(this, N), Z))|Pre1]
        ; cpp_zero_fill(MT, arrow(this, N), L, Pre, Pre1) )
    ;   memberchk(N-init([item([], E)]), Defaults), cpp_scalar_member_type(MT) -> Pre = [expr(L, assign('=', arrow(this, N), E))|Pre1]   % `int n{3};' on a scalar: its one item
    ;   memberchk(N-init(Items), Defaults), ( cpp_plain_aggregate(MT) ; cpp_vector_member(MT) ) -> cpp_member_from(MT, arrow(this, N), init(Items), L, Pre, Pre1)   % a plain struct or union from its braced list (0.117), a vector from its lanes (0.162): a compound literal of its type
    ;   memberchk(N-E, Defaults) -> Pre = [expr(L, assign('=', arrow(this, N), E))|Pre1]
    ;   Pre = Pre1 ),
    cpp_member_inits(Ds, Inits, Defaults, L, Pre1, Body).
cpp_designated_items(Items) :- member(item(Ds, _), Items), Ds \== [], Ds \== none, !.   % a braced list with a designator (0.201)
cpp_union_member_init(L, Place, MT, Args, Pre, Pre1) :- ( ccl_std_at_least(20) -> true ; Args = [_, _|_] ), cpp_paren_aggregate(MT, Args), !,   % AN AGGREGATE FROM VALUES (cpp_paren_aggregate/2, 0.197): `std::optional<P> o(std::in_place, 1, 2)' builds `__val_(std::forward<_Args>(__args)...)' over a plain struct
    findall(item([], A), member(A, Args), Items), cpp_member_from(MT, Place, init(Items), L, Pre, Pre1).
cpp_union_member_init(L, Place, MT, Args, [S|Pre], Pre) :-
    (   cpp_class_of_type(MT, MC), cpp_has_ctors(MC)
    ->  length(Args, NA), ( cpp_ctor(MC, Args, CName) -> cpp_fill_defaults(CName, Args, Args1), S = expr(L, call(id(CName), [addr(Place)|Args1])) ; cpp_refuse(L, member_not_constructed(MC, NA)) )
    ;   Args = [E] -> S = expr(L, assign('=', Place, E))
    ;   Args == [] -> S = expr(L, call(id(memset), [addr(Place), int(0), sizeof_type(MT)]))
    ;   cpp_refuse(L, member_init_arity(Args)) ).
%% `: __first_{0}' IS AN ARRAY MEMBER'S BRACED LIST (0.117), read as the one-item `init(__first_, [0])' that `__first_(0)' reads as: a SCALAR
%% item for an array member is the first element of a braced list (an array has no other initializer here), the rest zero --
%% libc++'s `__bitset' zeroes its words so, and it was `lvalue(int(0))' (a program's own) or an uninitialized array
cpp_array_item(E, init([item([], E)])) :- ( E = int(_) ; E = uint(_) ; E = long(_) ; E = ulong(_) ; E = bool(_) ; E = chr(_) ; E = float(_) ), !.
cpp_array_item(E, init([item([], E)])) :- catch(( ccl_type_of(E, T), T \== unknown, ccl_resolve_type(T, R), \+ R = arr(_, _), \+ cpp_class_of_type(R, _) ), _, fail), !.
cpp_array_item(E, E).
cpp_array_items([], []).
cpp_array_items([E|Es], [item([], E)|Is]) :- cpp_array_items(Es, Is).
%% a class default-initialized with nothing to do: no constructor of its own written out (a `= default' one is dropped
%% as the implicit one; a constructor TEMPLATE counts the class as constructible but takes arguments), and no implicit
%% constructor needed -- no defaults, no base or member that constructs, no vtable
cpp_trivial_default(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), \+ memberchk(ctor(_, _, _, _, _), Ms), \+ '$cpp_mt'(C, ctor, _, _), \+ cpp_implicit_ctor_needed(C).   % a constructor TEMPLATE is a user-declared constructor: with one and no `= default', default-initialization goes through the template road or is refused, never left uninitialized
cpp_trivial_default(C) :- '$cpp_default_ctor'(C), \+ cpp_implicit_ctor_needed(C).     % `C() = default' beside other constructors: the implicit one, with nothing to do
%% VALUE-INITIALIZATION ZEROES THE OBJECT FIRST where the default constructor is not USER-PROVIDED ([dcl.init]/8; 0.127): the
%% implicit one, or `C() = default' in the class (dropped as the implicit one, '$cpp_default_ctor'). `R()', `new R()', `new (p)
%% R()' and a member's `r()' of `struct R { int a; Q q; }' ran R's implicit constructor alone, which builds q and leaves a: a
%% garbage a where clang++ gives 0. A constructor the class writes, or a constructor template that takes no argument, is
%% user-provided, and value-initialization is that constructor alone. A class with no bytes of its own is zeroed by nothing.
cpp_value_zeroes(C) :- \+ cpp_empty_class(C), \+ cpp_user_default_ctor(C).
cpp_user_default_ctor(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(M, Ms), M = ctor(_, _, Ps, _, _), cpp_user_ctor(M), cpp_params_no_args(Ps), !.
cpp_user_default_ctor(C) :- '$cpp_mt'(C, ctor, _, M), ( M = ctor(_, _, Ps, _, _) -> cpp_params_no_args(Ps) ; true ), !.
cpp_params_no_args([]).
cpp_params_no_args([P|Ps]) :- ( P = param(_, _, _) -> true ; P = param(pack(_), _) ), cpp_params_no_args(Ps).
%% C++20'S PARENTHESIZED AGGREGATE INITIALIZATION ([dcl.init.general]/16.5, /16.6.2.2; P0960; 0.197): where no constructor is
%% viable and the destination is an AGGREGATE -- a class no constructor of which is written (cpp_aggregate_class), a plain struct or
%% union, an array -- a parenthesized expression-list initializes it as a braced list of its values does: each element
%% copy-initialized from its value in order, the rest from their default member initializers or value-initialized, an array of
%% unknown bound as many elements as values. An aggregate's only constructors are the implicit copy and move, viable for ONE value
%% of its own class or of a class derived from it (cpp_aggregate_args, cpp_derived_value): that value is a copy, as before. Before,
%% `P p(1, 2);' reached the lowering as `ctor([1, 2])', `Q q(3, P(4, 5));' over an aggregate class (a default member initializer
%% makes one) was refused `no_constructor(Q, 2)', `new Q(1)' and the placement new of `v.emplace_back(14)' alike (`new Q{1}' too:
%% braces and parentheses are one node after `new'), `int a[](9, 10, 11);' a VLA initialized, and `is_constructible_v<P, int, int>'
%% false. A value that cannot be typed is no aggregate's (a copy is meant, or nothing is known).
cpp_paren_aggregate(T, As) :- As = [_|_], once(ccl_resolve_type(T, R)), \+ R = ref(_, _), \+ R = rref(_, _),
    (   cpp_class_of_type(T, C) -> cpp_aggregate_class(C), cpp_aggregate_args(As, T), \+ cpp_derived_value(As, C)
    ;   R = arr(_, _) -> true
    ;   cpp_plain_aggregate(T), cpp_aggregate_args(As, T) ), !.
cpp_paren_agg_vars([], []).
cpp_paren_agg_vars([var(N, T0, ctor(As))|Vs], [var(N, T0, init(Items))|Ws]) :- As = [_|_], catch(cpp_type(T0, T), error(not_lowered(_), _), fail), cpp_paren_aggregate(T, As), !,
    findall(item([], A), member(A, As), Items), cpp_paren_agg_vars(Vs, Ws).
cpp_paren_agg_vars([V|Vs], [V|Ws]) :- cpp_paren_agg_vars(Vs, Ws).
cpp_derived_value([E], C) :- catch(( cpp_aggregate_arg_type(E, AT0), ccl_unref(AT0, AT1), cpp_class_of_type(AT1, D) ), _, fail), cpp_derives(D, C), !.
cpp_aggregate_args([_, _|_], _).                                                          % several values: the list of an aggregate
cpp_aggregate_args([E], MT) :- catch(( cpp_aggregate_arg_type(E, AT0), ccl_unref(AT0, AT1), cpp_strip_quals(AT1, _, AT), \+ cpp_same_type(AT, MT) ), _, fail).   % ... one value of ANOTHER type, known (a value of the member's own type is its copy)
cpp_aggregate_arg_type(E, T) :- cpp_arg_type(E, T), T \== unknown, !.
cpp_aggregate_arg_type(E, T) :- ( cpp_class_ctx(Cx) -> true ; Cx = none ), cpp_expr(Cx, E, E1), E1 \== E, ccl_type_of(E1, T), T \== unknown.   % IN THE CLASS BEING BUILT, as cpp_init_arg_class asks: `__rep_(__short())' names a type nested in the class, which the raw form cannot tell
%% a SCALAR member, its type resolved first (0.112): libc++'s basic_format_args writes `size_t __size_{0};', and the type
%% as written, `typedef(size_t)', is no spelled base type -- the braced list reached the lowering as the value assigned
cpp_scalar_member_type(MT) :- ( cpp_scalar_type(MT) -> true ; catch(( cpp_type(MT, T), ccl_resolve_type(T, RT) ), _, fail), cpp_scalar_type(RT) ).
%% a class with no constructor of its own but defaults to set, or a base to construct: C.C.0
cpp_implicit_ctor(L, C, B, Defaults, Fs) :- cpp_implicit_ctor_(L, C, B, Defaults, F), cpp_nv_twin(C, F, cpp_implicit_ctor_(L, C, B, Defaults, F2), F2, Fs, []).
cpp_implicit_ctor_(L, C, B, Defaults, function(L, none, base([], [void]), Name, Params, false, Body1)) :-
    cpp_mangle(C, C, [], Name), cpp_this_type(C, [], [fresh], ThisT), cpp_vtt_params(C, [param(ThisT, this)], Params),
    ( cpp_nv_body(C) -> true ; ccl_declare(Name, fn(base([], [void]), Params, false)) ),   % the base variant is declared under its own name (cpp_nv_twin)
    ccl_scope_push, ccl_declare_params(Params),   % `this' is in scope while the DEFAULT MEMBER INITIALIZERS are built, as a written constructor's parameters are (0.115): libc++ 18's `__output_buffer<_CharT> __output_{__storage_.__begin(), __storage_.__buffer_size, this};' deduces its constructor template's `_Tp' from `this' (std::formatted_size)
    ( catch(cpp_ctor_body(L, C, B, Defaults, [], block([]), Body0), E0, (ccl_scope_pop, throw(E0))) -> ccl_scope_pop ; ccl_scope_pop, fail ),
    cpp_method_body(C, Params, Body0, Body1).
%% a body under its parameters, the class's members in reach
cpp_method_body(Ctx, Params, Body, Body1) :- cpp_method_body(Ctx, none, Params, Body, Body1).
cpp_body_ctx(C) :- ( nb_current('$cpp_body_ctx', C0) -> C = C0 ; C = none ).
cpp_method_body(Ctx, Ret, Params, Body, Body1) :- cpp_where(body(Ctx), cpp_method_body_(Ctx, Ret, Params, Body, Body1)).
cpp_method_body_(Ctx, Ret, Params, Body, Body1) :-
    ( nb_current('$cpp_ret', R0) -> true ; R0 = none ), nb_setval('$cpp_ret', Ret),
    cpp_body_ctx(BC0), nb_setval('$cpp_body_ctx', Ctx),   % the context of the body being walked, for what asks it without a Ctx of its own (an operator's access, 0.127)
    (   catch(( ccl_scope_push, ccl_declare_params(Params), cpp_coro_skeleton(Ret, Params, Body, BodyK0), cpp_nrvo(Ret, BodyK0, BodyK), cpp_stmt(Ctx, BodyK, Body0), ccl_scope_pop ),
              Err, ( nb_setval('$cpp_ret', R0), nb_setval('$cpp_body_ctx', BC0), throw(Err) ))
    ->  nb_setval('$cpp_ret', R0), nb_setval('$cpp_body_ctx', BC0)
    ;   nb_setval('$cpp_ret', R0), nb_setval('$cpp_body_ctx', BC0), fail ),   % THE RESULT TYPE IS RESTORED ON EVERY EXIT (0.115): a body whose walk threw (a refusal inside an instance that a candidate check catches) left its own result type behind, and `return 0;' in main converted through `vector(size_type)' after `v | views::reverse'
    Body1 = Body0, cpp_param_classes(Params).   % A BY-VALUE PARAMETER IS THE CALLER'S TO DESTROY (0.207; the Itanium C++ ABI's 3.1.2.3, as clang and gcc have it, at the end of the caller's full-expression, cpp_copies_/3): the callee destroyed it at every exit, so a call from clang's code destroyed it twice and a call into clang's code never
%% EACH PARAMETER'S CLASS IS ASKED, so the unit knows it (0.207): the lowering lays a by-value parameter's class out, and a header's
%% class is loaded when it is first asked (cpp_class/2) -- the callee's destructor defers asked it of every parameter, and with them
%% gone `void operator delete(D *, std::destroying_delete_t)' was `class(destroying_delete_t)', the tag's class never loaded
cpp_param_classes(Ps) :- forall(( member(P, Ps), ( P = param(T, N) ; P = param(T, N, _) ), N \== this ), ( cpp_class_of_type(T, _) -> true ; true )).
%% UNDER -g A DESTRUCTOR RUN AT A SCOPE'S END HAS THE LINE OF THE SCOPE'S CLOSING BRACE, on every exit (0.139), as clang's
%% has: the reader recorded it against the declaration's line and name (ccl_note_scope_end/2); without the record (no -g,
%% or a library's code) the declaration's own line, as before
cpp_scope_end(L, N, LE) :- ( nb_current('$ccl_scope_ends', Es), Es \== [], memberchk(v(L, N, E), Es) -> LE = E ; LE = L ).
%% the unnamed parameters take a name by position, `$argK' (0.134), in the function's own list, every function of the unit's
%% output, in a namespace or an `extern "C"' block too
cpp_name_anon_items([], []).
cpp_name_anon_items([I|Is], [J|Js]) :- cpp_name_anon_item(I, J), cpp_name_anon_items(Is, Js).
cpp_name_anon_item(function(L, Sto, R, N, Ps, V, B), function(L, Sto, R, N, Ps1, V, B)) :- B \== none, memberchk(param(_, anon), Ps), !, cpp_name_anon_ps(Ps, 1, B, Ps1).
cpp_name_anon_item(namespace(L, N, Is), namespace(L, N, Js)) :- !, cpp_name_anon_items(Is, Js).
cpp_name_anon_item(extern_c(L, Is), extern_c(L, Js)) :- !, cpp_name_anon_items(Is, Js).
cpp_name_anon_item(I, I).
cpp_name_anon_ps([], _, _, []).
cpp_name_anon_ps([param(T, anon)|Ps], K, B, [param(T, N)|Qs]) :- atom_concat('$arg', K, N), cpp_mentions(B, id(N)), !, K1 is K + 1, cpp_name_anon_ps(Ps, K1, B, Qs).
cpp_name_anon_ps([P|Ps], K, B, [P|Qs]) :- K1 is K + 1, cpp_name_anon_ps(Ps, K1, B, Qs).
