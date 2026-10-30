%% ccl_cpp_lambda.pl -- lambdas: a class of the captures, operator() the body, the captures, a generic lambda, the
%% result deduced from the first return. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as
%% they stood there, in their order.

%% ---- lambdas: a class of the captures, operator() the body ----------------------------------
%% A LAMBDA IS DESUGARED ONCE (0.99): an `auto' method's result is deduced from its first return DESUGARED, and the
%% body walk desugared the same lambda again -- two closure classes, and `return [*this]() { ... }' stored the second
%% into a slot of the first's type. The closure is remembered by its text, its context and the captured locals' types.
cpp_lambda(Ctx, Caps, Ps0, Ret0, Body, E) :- cpp_lambda_key(Ctx, Caps, Ps0, Ret0, Body, Key), nb_getval('$cpp_lambda_memo', M), member(K0-E0, M), K0 == Key, !, E = E0.
%% ONE CLASS FOR A LAMBDA MADE IN A CLOSURE'S BODY (0.197): the enclosing lambda's result is deduced from its first return in
%% the context the enclosing lambda is made in, its body emitted in its own closure's, and the lambda between them was two
%% classes -- `[](int p) { return [p](int q) { ... }; }' returned a `lambda.3' from a call operator declared to return a
%% `lambda.2', which LLVM refused. A lambda met again in a closure whose ROOT context -- the context the outermost
%% enclosing closure was made in ('$cpp_closure_made') -- holds its class ('$cpp_lambda_cls') takes that class, and its
%% capture values are made again where it stands: an enclosing capture is the closure's member there (cpp_capturable/3)
cpp_lambda(Ctx, Caps, Ps0, Ret0, Body, E) :- atom(Ctx), '$cpp_closure_made'(Ctx, _), cpp_lambda_key(Ctx, Caps, Ps0, Ret0, Body, Key),
    cpp_lambda_root_key(Ctx, Key, RKey), '$cpp_lambda_cls'(RK0, Name, T, Captures0, This), RK0 == RKey, !,
    cpp_lambda_sig(Caps, Ps0, Name, _, _, _, _, _, SelfPs), cpp_captures(Ctx, Caps, SelfPs, Body, Captures1),
    findall(N-How, ( member(N-How0, Captures0), ( memberchk(N-How1, Captures1) -> How = How1 ; How = How0 ) ), Captures),   % the class's captures, each made where it stands (an init-capture's value walked here)
    cpp_lambda_capvals(Ctx, Captures, This, Ms0, Items), cpp_closure_value(T, Name, Ms0, Items, E), cpp_trace(lambda_class_again(Name)),
    nb_getval('$cpp_lambda_memo', M), nb_setval('$cpp_lambda_memo', [Key-E|M]).
cpp_lambda(Ctx, Caps, Ps0, Ret0, Body, E) :- cpp_lambda_(Ctx, Caps, Ps0, Ret0, Body, E, Name, T, Captures, This),
    cpp_lambda_key(Ctx, Caps, Ps0, Ret0, Body, Key), nb_getval('$cpp_lambda_memo', M), nb_setval('$cpp_lambda_memo', [Key-E|M]),
    cpp_lambda_root_key(Ctx, Key, RKey), assertz('$cpp_lambda_cls'(RKey, Name, T, Captures, This)).
cpp_lambda_key(Ctx, Caps, Ps0, Ret0, Body, k(Ctx, Caps, Ps0, Ret0, Body, Ts, F)) :- ( cpp_lambda_names_fn(Caps-Body) -> cpp_fsig_now(F0), cpp_lctx(F0, F) ; cpp_lambda_instance(F) ),   % and THE FUNCTION IT IS MADE IN where its text spells that function's name (0.166, cpp_lambda_names_fn/1), or where it is an instance of the program's template (0.236)
    cpp_ids(Body, Ids0), sort(Ids0, Ids), findall(N-T, ( member(N, Ids), ( cpp_local(N) -> ccl_type_of(id(N), T) ; atom(Ctx), '$cpp_closure_made'(Ctx, _), cpp_capturable(Ctx, N, T) ) ), Ts).   % a name the lambda can capture: a local, or in a closure's body the closure's member (0.197)
cpp_lambda_root_key(Ctx, k(_, Caps, Ps0, Ret0, Body, Ts, F), k(R, Caps, Ps0, Ret0, Body, Ts, F)) :- cpp_lambda_root(Ctx, R).
cpp_lambda_root(Ctx, R) :- atom(Ctx), '$cpp_closure_made'(Ctx, C0), !, cpp_lambda_root(C0, R).
cpp_lambda_root(Ctx, Ctx).
%% A CLOSURE OF AN INSTANCE OF THE PROGRAM'S FUNCTION TEMPLATE IS THE INSTANCE'S OWN (0.236; [temp.inst], [expr.prim.lambda.closure]/1):
%% `tf<int>' and `tf<double>' each have their lambda's class, named in each (`Z2tfIiET_S0_EUlvE_'); keyed by the description of the
%% function the outermost closure is made in (cpp_fsig_root/2), so a lambda in a closure's body is the one the enclosing
%% function's walk made. The library's stay one per text (0.166: std::format's closures made per instance cost fmtcheck.cpp 10 s)
cpp_lambda_instance(F) :- \+ nb_current('$cpp_in_lib', yes), cpp_fsig_now(F0), cpp_fsig_root(F0, R), R = fsig(_, _, _, _, _, _, _, TA), TA \== none, !, F = inst(R).
cpp_lambda_instance(none).
%% A CLOSURE IS ONE PER ENCLOSING FUNCTION ONLY WHERE ITS TEXT SPELLS THAT FUNCTION'S NAME (0.166): a lambda whose body or
%% captures name `__func__', `__FUNCTION__', `__PRETTY_FUNCTION__', `source_location' or `__builtin_source_location', or
%% call a function of the program that takes a source location ('$cpp_srcloc_fn', noted with the unit's registries), is
%% `auto f(int)::(anonymous class)' in one function and `auto f(double)::(anonymous class)' in another; any other is one
%% class wherever its text, context and captured types are one (0.99's memo), as it was: keyed by the enclosing function
%% every time, the closures of std::format's library lambdas were made once per enclosing instance, and fmtcheck.cpp took
%% 72.6 s where it takes 62.9 s.
cpp_lambda_names_fn(T) :- atom(T), !, ( memberchk(T, ['__func__', '__FUNCTION__', '__PRETTY_FUNCTION__', '__builtin_source_location', '__builtin_FUNCTION', source_location]) -> true ; '$cpp_srcloc_fn'(T) ).
cpp_lambda_names_fn(T) :- compound(T), T \= str(_), T \= u8str(_), T =.. [_|As], member(A, As), cpp_lambda_names_fn(A), !.
cpp_note_srcloc_fns(Units) :- forall(( cpp_srcloc_fn_item(Units, N, Ps), cpp_srcloc_param(Ps) ), ( '$cpp_srcloc_fn'(N) -> true ; assertz('$cpp_srcloc_fn'(N)) )).
cpp_srcloc_fn_item(T, N, Ps) :- compound(T),
    (   T = function(_, _, _, N0, Ps, _, _) ; T = method(_, _, _, N0, Ps, _, _)
    ;   T = class(_, N0, _, Ms), is_list(Ms), member(ctor(_, _, Ps, _, _), Ms) ),   % a constructor's, by its class's name: `Lg a(1);'
    ( atom(N0) -> N = N0 ; N0 = scoped(_, N1), atom(N1) -> N = N1 ; N0 = tmpl(N1, _), atom(N1) -> N = N1 ).
cpp_srcloc_fn_item(T, N, Ps) :- compound(T), T \= str(_), T \= u8str(_), T =.. [_|As], member(A, As), cpp_srcloc_fn_item(A, N, Ps).
cpp_srcloc_param(T) :- atom(T), !, memberchk(T, [source_location, '__builtin_source_location', '__builtin_FUNCTION']).
cpp_srcloc_param(T) :- compound(T), T \= str(_), T \= u8str(_), T =.. [_|As], member(A, As), cpp_srcloc_param(A), !.
cpp_lambda_(Ctx, Caps, Ps0, Ret0, Body, E, Name, T, Captures, This) :-
    nb_getval('$cpp_lambdas', K0), K is K0 + 1, nb_setval('$cpp_lambdas', K), cpp_unit_tag(UT), ( UT == '' -> atomic_list_concat(['lambda.', K], Name) ; atomic_list_concat(['lambda.', K, '_', UT], Name) ),   % THE UNIT'S TAG in the name (0.192, cpp_unit_tag/1)
    T = base([], [typedef(Name)]),
    cpp_lambda_sig(Caps, Ps0, Name, Ps1, TPs, Ps, SN, Self, SelfPs),
    cpp_fsig_now(Encl), assertz('$cpp_pf_closure'(Name, Encl, Ps1)),                                   % the function it is made in, and its parameters as written: its call operator's own name (0.166)
    ( memberchk(tparams(ETPs), Caps) -> true ; ETPs = [] ), cpp_local_note(closure(Ps1, ETPs), Name, Encl),   % and its local name (0.236, cpp_local_note/3), before its body is walked
    ( ( memberchk(mutable, Caps) ; SN \== none ) -> OpQs = [closure] ; OpQs = [const, closure] ),   % A NON-MUTABLE LAMBDA'S CALL OPERATOR IS CONST ([expr.prim.lambda.closure]/5; 0.127): its by-value captures are const in the body, so a non-const member of one is no candidate and a non-const reference binds none
    OpSig = fsig(member, Name, operator('()'), none, Ps1, false, OpQs, none),                      % ITS BODY IS ITS CALL OPERATOR'S where its result is deduced too (0.236): a lambda or a local class made there is named in it, `ZZ3ilfvENKUlvE_clEvEUlvE_'
    cpp_lambda_caps(Ctx, Caps, SelfPs, Body, Captures, Ms0, Items, This),
    cpp_lambda_const_check(Caps, Captures, Body),
    ( ( This = yes(EC) ; This = star(EC) ) -> cpp_note_closure_this(Name, EC) ; true ),
    findall(param(PT, N), ( member(cap(_, N, _), Caps), memberchk(N-How, Captures), cpp_cap_member_type(How, PT) ), InitPs), append(SelfPs, InitPs, RetPs),   % an init-capture's name is in scope where the result is deduced
    (   Ret0 \== none, TPs == [], cpp_auto_result(Ret0) -> cpp_with_fsig(OpSig, cpp_lambda_auto_ret(Ctx, Ret0, RetPs, Body, Ret))   % A WRITTEN `-> auto &&' (`-> auto &', `-> auto') IS DEDUCED AS A FUNCTION'S IS (0.132, [dcl.spec.auto]): kept as written, a caller typed the call by its decayed first return -- join_view's `auto&& __inner = [this]() -> auto&& { ... return *__get_outer(); }();' made a bitwise COPY of the inner vector, bound the reference to it and destroyed it at the scope's end, freeing the vector's own buffer (views::join crashed)
    ;   Ret0 \== none, TPs \== [] -> Ret = base([], [auto]), Trail = [trailing(Ret0)]   % A GENERIC LAMBDA'S WRITTEN RESULT names its own parameters (0.201): its call operator template's trailing type, made at the instance with its bindings (cpp_trailing_rets) and part of its signature -- `[](auto x) -> decltype(x + 1)' was resolved over the invented `$A1', `decltype_unknown', and libc++ 18's parallel algorithms dispatch through `[](auto &&... __args) -> decltype(std::__pstl_sort<_Policy>(...))'
    ;   Ret0 \== none -> cpp_lambda_written_ret(Ret0, RetPs, Ret)
    ;   TPs \== [] -> Ret = base([], [auto])
    ;   cpp_with_fsig(OpSig, cpp_lambda_ret(Ctx, RetPs, Body, Ret)) ),   % IN THE ENCLOSING CONTEXT: a member named in the body is a call or an access of this, which has a type
    assertz('$cpp_closure_made'(Name, Ctx)),
    ( nb_getval('$cpp_in_lib', yes) -> assertz('$cpp_lib_closure'(Name)) ; true ),   % A CLOSURE MADE IN A LIBRARY'S WALK IS THE LIBRARY'S CLASS (0.201, cpp_lib_class/1)
    ( cpp_lambda_scope(Ctx, Enc) -> asserta('$cpp_encl'(Name, Enc)) ; true ),   % A CLOSURE IS ENCLOSED BY THE CLASS IT IS MADE IN, as a nested class is: its types, statics and enumerators are in scope in the body, this captured or not -- a default argument filled inside a string's lambda, `__reset_internal_buffer(__rep __new_rep = __short())', named the nested __short and found nothing
    cpp_lambda_nx(Caps, OpQs, OpQsN, FMark),   % ITS NOEXCEPT (0.205, below)
    cpp_lib_lambda_req(Caps, TPs, OpQsN, OpQs0), ( var(Trail) -> OpQs1 = OpQs0 ; append(OpQs0, Trail, OpQs1) ),
    append(Self, Ps, MPs), Op0 = method(0, OpQs1, Ret, operator('()'), MPs, false, Body),
    ( TPs == [] -> Op = Op0 ; Op = template(0, TPs, Op0) ),
    %% A CAPTURELESS LAMBDA CONVERTS TO A POINTER TO FUNCTION ([expr.prim.lambda.closure]/8; 0.112): its closure has a
    %% conversion operator to `R (*)(Ps)' answering the address of a STATIC INVOKER, `lambda.K.fn', which calls the
    %% operator() over a null `this' (nothing captured, nothing read through it) -- 0.100's thunk for a static method.
    %% libc++'s <format> writes its output buffer's flush as `__flush_([](_CharT *__p, size_t __n, void *__o) { ... })'
    %% into a member of function-pointer type; a generic lambda and one with an explicit object parameter have none here.
    (   Ms0 == [], TPs == [], SN == none, Ret \= base(_, [auto])
    ->  atom_concat(Name, '.fn', Invoker), FPT = ptr([], fn(Ret, Ps, FMark)), ccl_declare(Invoker, fn(Ret, Ps, false)),   % a pointer to a NOEXCEPT function where the call operator does not throw ([expr.prim.lambda.closure]/8; 0.205)
        Conv = [method(0, [const], FPT, operator(conv(FPT)), [], false, block([return(0, addr(id(Invoker)))]))]
    ;   Conv = [] ),
    append(Ms0, [Op|Conv], Ms),
    cpp_isolated(( cpp_register_class(0, Name, [], Ms), cpp_item(declare(0, base([], [class(struct, Name, [], Ms)])), Its) )),
    cpp_add_instance_items(Its),
    ( Conv \== [] -> cpp_closure_invoker(Name, Invoker, Ret, Ps, Its) ; true ),
    cpp_closure_value(T, Name, Ms0, Items, E).
%% A LAMBDA'S NOEXCEPT IS ITS CALL OPERATOR'S ([expr.prim.lambda.closure]/1, /8; 0.205): the reader's `lnx(yes)' and `lnx(cond(E))'
%% the qualifiers `noexcept' and `noexcept(E)' of its operator() -- a template's condition substituted at its instance, which
%% cpp_make_member/9 notes ('$cpp_nxdef') -- and the pointer a captureless one converts to is a pointer to a noexcept function
%% where its operator() cannot throw. The reader dropped it, and every closure's call was noexcept: `noexcept(a(1))' of `[](int
%% x) { return x + 1; }' and `std::is_nothrow_invocable_v<decltype(a), int>' were 1, where clang++ gives 0
cpp_lambda_nx(Caps, Qs, [noexcept|Qs], q(false, [noexcept])) :- memberchk(lnx(yes), Caps), !.
cpp_lambda_nx(Caps, Qs, [noexcept(E)|Qs], M) :- memberchk(lnx(cond(E)), Caps), !,
    ( catch(( cpp_unevaluated(cpp_expr(none, E, E1)), cpp_const_bool(E1, true) ), _, fail) -> M = q(false, [noexcept]) ; M = false ).
cpp_lambda_nx(_, Qs, Qs, false).
%% a lambda's parameters: its explicit object parameter apart, its template parameters and the ones its `auto's invent
cpp_lambda_sig(Caps, Ps0, Name, Ps1, TPs, Ps, SN, Self, SelfPs) :-
    ( Ps0 = [param(this(ST0), SN)|Ps1] -> true ; Ps1 = Ps0, SN = none ),                                         % C++23: an explicit object parameter: the closure itself, `this auto self'
    %% A GENERIC LAMBDA IS A CLOSURE WHOSE `operator()' IS A MEMBER TEMPLATE ([expr.prim.lambda.closure]/3), which
    %% is what an `auto' parameter means and what C++20's `[]<class T>(T)' writes out: the template's parameters are
    %% the lambda's own, then one INVENTED per `auto' (cpp_auto_params, 0.42's rule for an abbreviated function
    %% template), and the result type is deduced at the CALL, where the arguments are known. Refused by name since
    %% 0.42; libc++'s `__find_generic' is `[&]<class _ValT>(_ValT&& __val) -> bool { return __val == __value; }'.
    ( memberchk(tparams(TPs0), Caps) -> true ; TPs0 = [] ),
    cpp_auto_params(Ps1, 0, Ps1a, TPsA), append(TPs0, TPsA, TPs00), cpp_lambda_constraint(Caps, Ps1a, TPs00, TPs),
    cpp_lambda_params(Ps1a, TPs, Ps),
    ( SN == none -> Self = [], SelfPs = Ps ; cpp_self_type(ST0, Name, ST), Self = [param(this(ST), SN)], SelfPs = [param(ST, SN)|Ps] ).
%% a lambda's captures where it is made: the closure's members and the values that initialize them, `this' among them
cpp_lambda_caps(Ctx, Caps, SelfPs, Body, Captures, Ms0, Items, This) :-
    cpp_captures(Ctx, Caps, SelfPs, Body, Captures),
    (   cpp_captures_this(Ctx, Caps, Body, EC)                                                   % `[this]', and a default capture where the body names the enclosing class
    ->  ( memberchk(cap(star_this), Caps) -> This = star(EC) ; This = yes(EC) )
    ;   This = no ),
    cpp_lambda_capvals(Ctx, Captures, This, Ms0, Items).
cpp_lambda_capvals(Ctx, Captures, This, Ms0, Items) :-
    findall(member(MT, N, none), ( member(N-How, Captures), cpp_cap_member_type(How, MT) ), Ms1),
    findall(item([], V), ( member(N-How, Captures), cpp_cap_init(N, How, V0), cpp_expr(Ctx, V0, V) ), Items1),
    (   This = star(EC)                                                                          % `[*this]' ([expr.prim.lambda.capture]/10; 0.99): the OBJECT copied into the closure, reached through the same member
    ->  cpp_this_item(Ctx, EC, ThisV), Ms0 = [member(base([], [typedef(EC)]), '$this', none)|Ms1], Items = [item([], deref(ThisV))|Items1]
    ;   This = yes(EC)                                                                           % `this' where the lambda is made: the method's pointer, or -- inside a closure that captured it -- the object's address (0.117)
    ->  cpp_this_item(Ctx, EC, ThisV), Ms0 = [member(ref([], base([], [typedef(EC)])), '$this', none)|Ms1], Items = [item([], ThisV)|Items1]   % a REFERENCE to the object, as a `[&x]' capture is: the lowering reads a reference member through, and the check counts it as one
    ;   Ms0 = Ms1, Items = Items1 ).
%% A GENERIC LAMBDA'S PARAMETERS THAT NAME ITS OWN TEMPLATE PARAMETERS STAY AS WRITTEN WHERE THE TABLES KNOW THE NAME (0.126): the template parameter hides every outer
%% name ([temp.local]), and `cpp_type' resolves through the tables. A typedef in a block joins the unit's one table, and libc++ writes `using _Up = __libcpp_remove_reference_t<_Tp>;'
%% inside a function: the second parameter of `[]<class _Tp, class _Up>(const _Tp &__t, const _Up &__u)' -- libc++ 21's `__synth_three_way', the comparison a vector's `<=>' is
%% built on -- became `const _Tp &', `_Up' could not be deduced and `std::three_way_comparable<std::vector<int>>' was false. Only a parameter whose type names such a
%% template parameter is kept; the rest resolve as before. `lambdatparam.cpp'. WHATEVER THE TABLES KNOW (0.162): resolved, `std::index_sequence<_Is...>'
%% with the pack `_Is' free was `integer_sequence<size_t>', no argument took it (argument_mismatch), and the in-place call of `[=]<size_t...
%% _Is>(index_sequence<_Is...>) { ... }(make_index_sequence<N>{})' -- libc++ 21's `__load_vector' -- reached the lowering raw. `vector.cpp'.
cpp_lambda_params(Ps0, TPs, Ps) :-
    findall(H, ( member(tparam(_, H, _), TPs), atom(H) ), Hidden), Hidden \== [], !,
    cpp_params_hiding(Ps0, Hidden, Ps).
cpp_lambda_params(Ps0, _, Ps) :- cpp_plain_params(Ps0, Ps).
cpp_params_hiding([], _, []).
cpp_params_hiding([P|Ps], Hidden, [Q|Qs]) :-
    (   cpp_param_t(P, T), member(H, Hidden), cpp_names_in(T, H) -> arg(2, P, N), Q = param(T, N)
    ;   cpp_plain_params([P], [Q]) ),
    cpp_params_hiding(Ps, Hidden, Qs).
%% A LAMBDA'S REQUIRES-CLAUSE IS ITS OPERATOR TEMPLATE'S CONSTRAINT ([expr.prim.lambda.closure]/3; 0.112; dropped by
%% the reader since 0.84): the head's and the trailing one, conjoined into the ONE requires entry the template's
%% parameters end with (cpp_auto_params' own), a parameter named in a `decltype' replaced by its declared type -- the
%% invented `$A1' for an `auto' -- so the check after the binding reads it. Only the PROGRAM's lambdas here; a library's
%% (libc++'s __synth_three_way, whose clause names the parameters themselves) is the TRAILING clause of its call operator
%% (cpp_lib_lambda_req, 0.136), checked as a member template's is, with the parameters declared: it had stayed unchecked.
cpp_lambda_constraint(Caps, Ps, TPs0, TPs) :- TPs0 \== [], \+ nb_getval('$cpp_in_lib', yes),
    findall(R, member(lreq(R), Caps), Rs0), Rs0 \== [], !,
    findall(R1, ( member(R0, Rs0), cpp_lreq_subst(R0, Ps, R1) ), Rs), cpp_conj_reqs(Rs, R),
    ( append(TPsA, [requires(R00)], TPs0) -> append(TPsA, [requires(bin('&&', R00, R))], TPs) ; append(TPs0, [requires(R)], TPs) ).
cpp_lambda_constraint(_, _, TPs, TPs).
cpp_lib_lambda_req(Caps, TPs, Qs, Qs1) :- TPs \== [], nb_getval('$cpp_in_lib', yes), findall(R, member(lreq(R), Caps), Rs), Rs \== [], !, cpp_conj_reqs(Rs, R), append(Qs, [requires(R)], Qs1).
cpp_lib_lambda_req(_, _, Qs, Qs).
cpp_lreq_subst(base(Q, [decltype(id(N))]), Ps, T) :- atom(N), ( memberchk(param(T0, N), Ps) ; memberchk(param(T0, N, _), Ps) ), !, ( Q == [] -> T = T0 ; ccl_add_quals(Q, T0, T) ).
cpp_lreq_subst(X, Ps, Y) :- compound(X), !, X =.. [F|As], cpp_lreq_subst_l(As, Ps, Bs), Y =.. [F|Bs].
cpp_lreq_subst(X, _, X).
cpp_lreq_subst_l([], _, []).
cpp_lreq_subst_l([A|As], Ps, [B|Bs]) :- cpp_lreq_subst(A, Ps, B), cpp_lreq_subst_l(As, Ps, Bs).
cpp_closure_invoker(Name, Invoker, Ret, Ps, Its) :-
    atom_concat(Name, '.op.call', Pfx), member(function(_, _, _, OpName, _, _, _), Its), atom(OpName), sub_atom(OpName, 0, _, _, Pfx), !,
    cpp_thunk_params(Ps, 1, IPs, Args),
    ( ccl_resolve_type(Ret, base(_, [void])) -> IB = block([expr(0, call(id(OpName), [nullptr|Args]))]) ; IB = block([return(0, call(id(OpName), [nullptr|Args]))]) ),
    cpp_add_instance_items([function(0, none, Ret, Invoker, IPs, false, IB)]).
cpp_closure_invoker(Name, _, _, _, _) :- cpp_refuse(0, closure_invoker(Name)).
%% THE CLOSURE OBJECT: a compound literal of its captures' values -- unless a capture BY VALUE is of a class with
%% constructors (a `std::string', a class with a destructor, the object itself under `[*this]'), which C++ COPIES
%% through its copy constructor ([expr.prim.lambda.capture]/10) and the closure's destructor destroys: then the
%% closure is built member by member as an aggregate whose member constructs is (cpp_aggregate_inits, the temporary
%% road of 0.83), a reference member BOUND to its object, and the temporary is destroyed with the statement or elided
%% into the local it initializes. Bitwise, `[t]' of a class with a destructor held a copy no constructor made and
%% destroyed it once more than it was made (0.101).
cpp_closure_value(T, Name, Ms, Items, stmt_expr(block(Ss))) :-
    member(member(MT, _, _), Ms), MT \= ref(_, _), cpp_class_of_type(MT, MC), cpp_has_ctors(MC), !,
    cpp_class_l(Name, cls(_, Data, _, _, _)),
    findall(V, ( member(item(_, V0), Items), cpp_closure_bind_value(V0, V) ), Vs),
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), cpp_aggregate_inits(Data, Vs, id(Tmp), 0, Inits),
    (   cpp_dtor(Name, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts) -> nb_getval('$cpp_temps', Ts1), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts1]), Ss0 = Inits
    ;   Ss0 = [declaration(0, none, T, [var(Tmp, T, none)])|Inits] ),
    append(Ss0, [expr(0, id(Tmp))], Ss), cpp_trace(closure_value(Name, Ss)).
cpp_closure_value(T, Name, _, Items, compound_lit(T, init(Items))) :- cpp_trace(closure_bitwise(Name)).
cpp_closure_bind_value(addr(X), X) :- !.                                                 % a reference capture's item is the object's address; the bind takes the object
cpp_closure_bind_value(id(this), deref(id(this))) :- !.                                 % `[this]': the reference member bound to the object
cpp_closure_bind_value(V, V).
cpp_closure_class(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(M, Ms), cpp_closure_op(M), !.
cpp_closure_op(template(_, _, M)) :- !, cpp_closure_op(M).                                % a GENERIC lambda's operator() is a member template
cpp_closure_op(method(_, Qs, _, operator('()'), _, _, _)) :- memberchk(closure, Qs).   % a lambda's class: its operator() carries the mark
cpp_lambda_scope(self(C, _), C) :- !.
cpp_lambda_scope(Ctx, EC) :- atom(Ctx), Ctx \== none, ( cpp_closure_this(Ctx, EC) -> true ; cpp_closure_class(Ctx), cpp_enclosing(Ctx, EC) -> true ; cpp_class_l(Ctx, _), EC = Ctx ).   % the hop out is for a lambda made in a CLOSURE (0.132): made in a member of a NESTED class, the lambda went to the holder -- join_view's iterator writes `[this]() -> auto&& { if constexpr (__ref_is_glvalue) ... }', its own static was not folded, and the discarded branch was walked
%% A LAMBDA CAPTURES THIS where `[this]' says so, and under a DEFAULT capture where its body names anything of the
%% enclosing class -- a data member, a static or a method, or `this' itself. The closure keeps the enclosing object's
%% address in the member `'$this'', and inside its operator() a name of that class is reached through it, as C++'s
%% closure reaches it: the capture is by REFERENCE to the object (C++ captures the pointer, never the object).
%% ... A LAMBDA INSIDE A LAMBDA THAT CAPTURED THIS captures THE OBJECT, never the outer closure (0.117): `this' in the outer's body is
%% the enclosing object's address (cpp_closure_object), so `[this, k] { return s + k; }' made in `[this](int k) { ... }' reads
%% the member `s' of the class, as C++ has it. The outer closure itself stays what a default capture holds when the body
%% names the outer's own captures and none of the object's (the old road). `lambdathis.cpp'.
cpp_captures_this(Ctx, Caps, _, EC) :- atom(Ctx), ( memberchk(cap(this), Caps) ; memberchk(cap(star_this), Caps) ), !, ( cpp_closure_this(Ctx, EC0) -> EC = EC0 ; EC = Ctx ).
cpp_captures_this(Ctx, Caps, Body, EC) :- atom(Ctx), memberchk(cap(default, _), Caps),
    (   cpp_closure_this(Ctx, EC0), cpp_names_enclosing(EC0, Body) -> EC = EC0
    ;   cpp_names_enclosing(Ctx, Body), EC = Ctx ), !.
cpp_this_item(Ctx, EC, V) :- ( cpp_closure_this(Ctx, EC) -> cpp_closure_object([], V) ; V = id(this) ).
cpp_names_enclosing(C, Body) :- cpp_ids(Body, Ids), member(N, Ids), cpp_has_member(C, N), !.
cpp_names_enclosing(_, Body) :- cpp_mentions_this(Body), !.
cpp_mentions_this(this) :- !.
cpp_mentions_this(T) :- compound(T), T =.. [_|As], member(A, As), cpp_mentions_this(A), !.
cpp_has_member(C, N) :- cpp_data_member(C, N, _), !.
cpp_has_member(C, N) :- cpp_static_member(C, N, _), !.
cpp_has_member(C, N) :- '$cpp_mt'(C, N, _, _), !.                                        % a MEMBER TEMPLATE, which libc++'s vector names from a lambda inside emplace_back
cpp_has_member(C, N) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(M, Ms), cpp_member_named(M, N), !.
cpp_has_member(C, N) :- cpp_base_scope(C, B), cpp_has_member(B, N), !.
cpp_member_named(template(_, _, M), N) :- !, cpp_member_named(M, N).
cpp_member_named(method(_, _, _, N, _, _, _), N).
cpp_member_named(member(_, N, _), N).
cpp_note_closure_this(Name, C) :- nb_getval('$cpp_closure_this', L), nb_setval('$cpp_closure_this', [Name-C|L]).
cpp_closure_this(Ctx, C) :- atom(Ctx), nb_getval('$cpp_closure_this', L), memberchk(Ctx-C, L).
cpp_this_of_closure(arrow(id(this), '$this')).                                           % the enclosing OBJECT, an lvalue through the reference member (the closure's own this is a pointer)
cpp_closure_member(N, Hops, member(B, N)) :- cpp_this_of_closure(R), cpp_hops(R, Hops, B).
cpp_closure_object(Hops, addr(B)) :- cpp_this_of_closure(R), cpp_hops(R, Hops, B).       % its address, which a method takes as `this'
%% the closure's own type for `this auto self': by value, by reference (an rvalue reference read as one), or as named
cpp_self_type(base(Q, [auto]), Name, base(Q, [typedef(Name)])) :- !.
cpp_self_type(ref(Q, T0), Name, ref(Q, T)) :- !, cpp_self_type(T0, Name, T).
cpp_self_type(rref(Q, T0), Name, ref(Q, T)) :- !, cpp_self_type(T0, Name, T).
cpp_self_type(T, _, T).
%% the captures, Name-val(Type) | Name-ref(Type): the ones named, then, under a default, every enclosing local the body names
%% A CAPTURE BY REFERENCE REFERS TO THE ENTITY'S OWN TYPE ([expr.prim.lambda.capture]/12; 0.227): an array stays an array and a
%% `const' stays, where a capture by copy decays. Decayed, libc++ 22's `emplace_back' lambda captured its `const char (&)[6]'
%% argument as a reference to a `const char *', which no address of an array binds: the member was bound to a temporary holding the
%% address (ir_init_sub/4), and the string was made from the temporary's bytes
cpp_captures(Ctx, Caps, Ps, Body, Captures) :-
    findall(N-How, ( member(cap(K, N), Caps), ( K == val ; K == ref ), cpp_capturable(Ctx, N, CT), CT \== unknown, cpp_capture_how(K, CT, How) ), Explicit0),
    findall(N-How, ( member(cap(K, N, E), Caps), cpp_init_capture(Ctx, K, E, How) ), Inits),
    append(Explicit0, Inits, Explicit),
    (   memberchk(cap(default, D), Caps)
    ->  cpp_lambda_free(Ps, Body, Names), ( D == '=' -> DK = val ; DK = ref ),
        findall(N-How, ( member(N, Names), \+ memberchk(N-_, Explicit), cpp_capturable(Ctx, N, CT), CT \== unknown, cpp_capture_how(DK, CT, How) ), Implicit)
    ;   Implicit = [] ),
    append(Explicit, Implicit, Captures).
cpp_capture_how(val, CT, val(CT1)) :- cpp_decayed(CT, CT1).
cpp_capture_how(ref, CT, ref(CT1)) :- ccl_unref(CT, CT1).
%% A NAME A LAMBDA CAN CAPTURE is a local of the function it is made in or -- inside a closure's operator() -- a capture of that
%% closure ([expr.prim.lambda.capture]/9; 0.117): `[a] { return [a] { return a + 1; }(); }' and the default captures of
%% `[=] { return [=] { return a * b; }(); }' named the outer closure's members, which are no locals, so the inner lambda captured
%% nothing and its body met `undeclared(a)'. The member is read as the body reads it (`this->a'), its type unreferenced.
%% `lambdanest.cpp'.
cpp_capturable(_, N, CT) :- cpp_local(N), !, ccl_type_of(id(N), CT).
cpp_capturable(Ctx, N, CT) :- atom(Ctx), Ctx \== none, atom(N), \+ sub_atom(N, 0, 1, _, '$'), cpp_closure_class(Ctx), cpp_data_member(Ctx, N, Hops),
    cpp_access(id(this), N, Hops, E), ccl_type_of(E, CT0), ccl_unref(CT0, CT).
%% AN INIT-CAPTURE ([expr.prim.lambda.capture]/6), C++14's `[n = e]' and `[&r = e]': a member named by the capture,
%% of e's type decayed (`auto n = e') or a reference bound to e (`auto &r = e'), initialized by e in the ENCLOSING
%% scope. The reader has taken it since 0.91 (libc++'s radix sort, `[__map = std::move(__map)]') and nothing made the
%% member, so the body named nothing and the result type was refused (lambda_result_type; test/cpp/run/initcapture.cpp).
%% The initializer is walked ONCE, here, and passed on as walked (0.60's rule for an initializer).
cpp_init_capture(Ctx, K, E, How) :- cpp_expr(Ctx, E, E1), cpp_arg_type(E1, T0), T0 \== unknown, ccl_unref(T0, T1),
    ( K == init -> cpp_decayed(T1, CT), How = val(CT, '$cpp_walked'(E1)) ; How = ref(T1, '$cpp_walked'(E1)) ).
%% A NON-MUTABLE LAMBDA'S BY-VALUE CAPTURES ARE CONST ([expr.prim.lambda.capture]/11, [expr.prim.lambda.closure]/5, 0.117): its
%% operator() is a const member, so a write to a member copied into the closure is ill-formed. The closure's operator() here
%% is never const (a constness that no write check would read), so the rule is applied to the lambda's text: an assignment, an
%% increment or a decrement whose left side is a by-value capture, or a member of one (`c.x = 1', `++n'), is refused by name
%% unless the lambda is `mutable'. A name the body declares itself, a parameter, is not the capture (cpp_bound); a write
%% THROUGH a copied pointer (`*p = 1', `p[i] = 1', `p->x = 1') is the pointee's, which a const pointer leaves writable.
cpp_lambda_const_check(Caps, Captures, Body) :-
    (   memberchk(mutable, Caps) -> true
    ;   cpp_declared_names(Body, Bound),
        findall(N, ( member(N-How, Captures), compound(How), functor(How, val, _), \+ memberchk(N, Bound) ), Ns),
        (   Ns \== [], cpp_capture_written(Body, Ns, 0, W, L) -> cpp_refuse(L, assign_to_capture(W)) ; true ) ).
cpp_declared_names(param(_, N), [N]) :- atom(N), !.                            % a nested lambda's parameter hides a capture of its name
cpp_declared_names(param(_, N, _), [N]) :- atom(N), !.
cpp_declared_names(var(N, T, I), [N|Ns]) :- atom(N), !, cpp_declared_names(T, N1), cpp_declared_names(I, N2), append(N1, N2, Ns).
cpp_declared_names(T, Ns) :- compound(T), !, T =.. [_|As], cpp_declared_names_list(As, Ns).
cpp_declared_names(_, []).
cpp_declared_names_list([], []).
cpp_declared_names_list([A|As], Ns) :- cpp_declared_names(A, N1), cpp_declared_names_list(As, N2), append(N1, N2, Ns).
cpp_capture_written(T, Ns, L0, W, L) :- compound(T),
    (   T = assign(_, Lhs, _), cpp_capture_root(Lhs, N), memberchk(N, Ns) -> W = N, L = L0
    ;   ( T = preinc(X) ; T = postinc(X) ; T = predec(X) ; T = postdec(X) ), cpp_capture_root(X, N), memberchk(N, Ns) -> W = N, L = L0
    ;   T =.. [_, A1|_], integer(A1) -> cpp_capture_written_args(T, Ns, A1, W, L)       % a statement carries its line first
    ;   cpp_capture_written_args(T, Ns, L0, W, L) ).
cpp_capture_written_args(T, Ns, L0, W, L) :- T =.. [_|As], member(A, As), cpp_capture_written(A, Ns, L0, W, L), !.
cpp_capture_root(id(N), N) :- atom(N), !.
cpp_capture_root(member(X, _), N) :- cpp_capture_root(X, N).
cpp_cap_member_type(val(CT), CT).
cpp_cap_member_type(val(CT, _), CT).
cpp_cap_member_type(ref(CT), ref([], CT)).
cpp_cap_member_type(ref(CT, _), ref([], CT)).
cpp_cap_init(N, val(_), id(N)).
cpp_cap_init(_, val(_, E), E).
cpp_cap_init(N, ref(_), addr(id(N))).
cpp_cap_init(_, ref(_, '$cpp_walked'(E)), '$cpp_walked'(addr(E))).
cpp_lambda_free(Ps, Body, Names) :-
    cpp_ids(Body, Ids0), sort(Ids0, Ids), findall(N, member(param(_, N), Ps), PNs), cpp_bound(Body, Bs0), append(PNs, Bs0, Bound),
    findall(N, ( member(N, Ids), \+ memberchk(N, Bound) ), Names).
cpp_ids(id(N), [N]) :- atom(N), !.
cpp_ids(T, Ns) :- compound(T), !, T =.. [_|As], cpp_ids_list(As, Ns).
cpp_ids(_, []).
cpp_ids_list([], []).
cpp_ids_list([A|As], Ns) :- cpp_ids(A, N1), cpp_ids_list(As, N2), append(N1, N2, Ns).
cpp_bound(var(N, _, _), [N]) :- atom(N), !.
cpp_bound(T, Ns) :- compound(T), !, T =.. [_|As], cpp_bound_list(As, Ns).
cpp_bound(_, []).
cpp_bound_list([], []).
cpp_bound_list([A|As], Ns) :- cpp_bound(A, N1), cpp_bound_list(As, N2), append(N1, N2, Ns).
%% the result type when not written: the first return's, typed under the parameters
%% A WRITTEN RESULT TYPE IS RESOLVED UNDER THE LAMBDA'S PARAMETERS ([expr.prim.lambda]: the trailing return type is in
%% the parameters' scope; 0.93): libc++ 18's basic_string move constructor initializes `__r_' from an immediately
%% invoked `[](basic_string &__s) -> decltype(__s.__r_) && { ... return std::move(__s.__r_); }(__str)', and resolved
%% with no parameter in scope the decltype was untyped, the lambda's result unknown, and the member `not constructed'
cpp_lambda_written_ret(Ret0, Ps, Ret) :- cpp_in_frame(( ccl_declare_params(Ps), cpp_type(Ret0, Ret) )).
cpp_lambda_ret(Ps, Body, Ret) :- cpp_lambda_ret(none, Ps, Body, Ret).
cpp_lambda_auto_ret(Ctx, base(Q, [auto]), Ps, Body, Ret) :- memberchk(decltype_auto, Q), !, cpp_decltype_auto_ret(Ctx, Ps, Body, Ret0), ( Ret0 == none -> cpp_refuse(0, lambda_result_type) ; Ret = Ret0 ).
cpp_lambda_auto_ret(Ctx, base(_, [auto]), Ps, Body, Ret) :- !, cpp_lambda_ret(Ctx, Ps, Body, Ret).
cpp_lambda_auto_ret(Ctx, Ret0, Ps, Body, Ret) :- Ret0 =.. [K, Q, base(QA, [auto])], cpp_lambda_ret_mode(Ctx, Ps, Body, keep, T0, Lv), ccl_unref(T0, T1), cpp_merge_quals(QA, T1, T), cpp_ref_auto_result(K, Q, T, Lv, Ret).
%% A `decltype(auto)' RESULT IS THE FIRST RETURN'S decltype ([dcl.type.auto.deduct]/5; 0.132), the return desugared in the
%% context as an `auto' result's is: an unparenthesized name or member access its DECLARED type, any other expression its
%% type under the reference its value category says -- an lvalue `T &' (`*it', a call returning one, `a[i]'), an xvalue
%% `T &&' (`std::move(*it)', a call returning one), a prvalue `T' without its top-level cv when it is no class. No return:
%% `void'; an untyped one: `none', which the caller refuses by its own name. The reader does not keep parentheses, so
%% `return (x);' is taken as `return x;'.
cpp_decltype_auto_ret(Ctx, Ps, Body0, Ret) :- cpp_in_frame(cpp_decltype_auto_ret_(Ctx, Ps, Body0, Ret)).
cpp_decltype_auto_ret_(Ctx, Ps, Body0, Ret) :- ccl_declare_params(Ps), cpp_body_typedefs(Body0, Body),
    (   cpp_first_return_in(Ctx, Body, E00)
    ->  ( E00 = paren(E) -> Paren = yes ; E = E00, Paren = no ),
        ( catch(cpp_unevaluated(cpp_expr(Ctx, E, E1)), error(not_lowered(W), _), ( cpp_trace(lambda_ret_refused(W)), fail )) -> true ; E1 = E ),   % unevaluated, as the `auto' road's (0.206)
        ( Paren == yes, cpp_decltype_paren(E1, T) -> Ret = T ; cpp_decltype_auto_of(E1, T) -> Ret = T ; Ret = none )   % `return (x);' is decltype((x)), a reference to x (0.197)
    ;   Ret = base([], [void]) ).
cpp_decltype_auto_of(E, T) :- cpp_decltype_of(E, T0), T0 \== unknown, !,
    (   ( T0 = ref(_, _) ; T0 = rref(_, _) ) -> T = T0
    ;   ( E = id(_) ; E = member(_, _) ; E = arrow(_, _) ) -> T = T0                                   % an unparenthesized name or member access: its declared type
    ;   cpp_xvalue_object(E) -> ccl_unref(T0, T1), T = rref([], T1)
    ;   cpp_lvalue(E) -> ccl_unref(T0, T1), T = ref([], T1)
    ;   cpp_prvalue_type(T0, T) ).
%% the first return DESUGARED in the enclosing context and then typed, as a method's auto result already was
%% (cpp_method_ret): the body of a lambda in a member function names the class's members, which have a type only
%% once they are the calls and accesses the desugaring makes of them -- and here, where the lambda stands, the
%% enclosing locals and `this' are still in scope
cpp_lambda_ret(Ctx, Ps, Body0, Ret) :- cpp_lambda_ret_mode(Ctx, Ps, Body0, decay, Ret).
%% ... Mode `keep' leaves the type as the return's expression has it: `auto &f() { return g; }' deduces `T &' with T the OBJECT's type, qualifiers and all
cpp_lambda_ret_mode(Ctx, Ps, Body0, Mode, Ret) :- cpp_lambda_ret_mode(Ctx, Ps, Body0, Mode, Ret, _).
cpp_lambda_ret_mode(Ctx, Ps, Body0, Mode, Ret, Lv) :- cpp_in_frame(cpp_lambda_ret_mode_(Ctx, Ps, Body0, Mode, Ret, Lv)), ( Ret == none -> cpp_refuse(0, lambda_result_type) ; true ).
cpp_lambda_ret_mode_(Ctx, Ps, Body0, Mode, Ret, Lv) :- ccl_declare_params(Ps), cpp_body_typedefs(Body0, Body),
    (   cpp_first_return_in(Ctx, Body, E)
    ->  ( catch(cpp_unevaluated(cpp_expr(Ctx, E, E1)), error(not_lowered(W), _), ( cpp_trace(lambda_ret_refused(W)), fail )) -> true ; E1 = E ),   % traced: the refusal behind a `lambda_result_type' is otherwise silent. UNEVALUATED (0.206): a temporary the return's expression makes is no temporary of the statement the deduction runs in -- `c_api_make(std::out_ptr(up))' destroyed, at its end, an `out_ptr_t' slot that only the deduction of out_ptr's `auto' result had registered, never constructed: a segmentation fault
        ( cpp_lvalue(E1), \+ cpp_xvalue_object(E1) -> Lv = yes ; Lv = no ),   % a member of an xvalue is one (0.121)
        ( cpp_deduced_ret(E1, T), T \== unknown -> ( Mode == keep -> Ret = T ; cpp_decayed(T, Ret) ) ; Ret = none ),   % DECAYED, the top-level qualifiers dropped ([dcl.spec.auto]: `auto' deduces as a by-value parameter; 0.104): `return partial_ordering::equivalent', a static const, made `common_comparison_category_t' a `const partial_ordering' that `is_same_v' told from the plain one
        true
    ;   Ret = base([], [void]) ).
%% THE BLOCK TYPEDEFS BEFORE THE FIRST RETURN are substituted into it before its type is asked (0.60's rule at walk
%% time, beside 0.81's declarations before the return): libc++'s `transform' writes `using _Up = remove_cv_t<
%% invoke_result_t<_Func, _Tp &>>; ... return optional<_Up>(...)', and the first return typed raw instantiated
%% `optional<_Up>' on the free name (its bases refused `argument_mismatch' one by one). Only the body's top level:
%% a return inside an `if' sits in the statements substituted after the alias.
cpp_body_typedefs(block(Ss), block(Ss1)) :- !, cpp_body_typedefs_(Ss, Ss1).
cpp_body_typedefs(B, B).
cpp_body_typedefs_([], []).
cpp_body_typedefs_([typedef(L, Vs)|Ss], [typedef(L, Vs)|Ss2]) :- !,
    ( catch(( cpp_vars(none, Vs, Vs1), cpp_block_typedefs(Vs1, B) ), Err, ( cpp_trace(body_typedef_refused(Err)), fail )), B \== [] -> cpp_subst(Ss, B, Ss1) ; Ss1 = Ss ), cpp_body_typedefs_(Ss1, Ss2).
cpp_body_typedefs_([using(L, name(scoped(Path, N)))|Ss], [using(L, name(scoped(Path, N)))|Ss2]) :- atom(N), cpp_ns_key(Path, N, K), K \== N, cpp_key_names_type(K), !,   % a block's using-declaration of a class under its key (above), for the deduced result too
    cpp_subst(Ss, [N-base([], [typedef(K)])], Ss1), cpp_body_typedefs_(Ss1, Ss2).
cpp_body_typedefs_([S|Ss], [S|Ss1]) :- cpp_body_typedefs_(Ss, Ss1).
%% THE TYPE A DEDUCED RESULT HAS: a CONDITIONAL over two class arms is the one the other converts to ([expr.cond]/4,
%% the composite type), never the second arm taken alone -- `return x > 5 ? std::optional<int>(x - 5) : std::nullopt'
%% deduced `nullopt_t' and `optional<nullopt_t>' behind it; a cast to void is void; anything else is its own type.
cpp_deduced_ret(cond(_, A, B), T) :- ccl_type_of(A, TA), TA \== unknown, ccl_type_of(B, TB), TB \== unknown, TA \== TB,
    (   cpp_class_of_type(TA, CA), \+ cpp_class_of_type_of(B, CA), catch(cpp_converting_ctor(CA, B), error(not_lowered(_), _), fail) -> T = TA
    ;   cpp_class_of_type(TB, CB), \+ cpp_class_of_type_of(A, CB), catch(cpp_converting_ctor(CB, A), error(not_lowered(_), _), fail) -> T = TB ), !.
cpp_deduced_ret(E, T) :- ( E = member(_, _) ; E = arrow(_, _) ), ccl_type_of(E, T0), T0 \== unknown, \+ cpp_type_const(T0), cpp_obj_const(E, const), !, ccl_add_quals([const], T0, T).   % A MEMBER OF A CONST OBJECT IS CONST (0.121; [expr.ref]/6, [dcl.type.cv]): the type of `std::forward<const V &>(v).__head' under `auto &&' is `const T &' -- libc++'s variant `__get_alt' deduced `T &', the copy constructor of a variant forwarded a non-const alternative and moved the source's string out
cpp_deduced_ret(E, T) :- ccl_type_of(E, T).
cpp_first_return(return(_, E), E) :- !.
cpp_first_return(lambda(_, _, _, _), _) :- !, fail.                                              % A LAMBDA'S RETURN IS THE LAMBDA'S, never the enclosing function's (0.100): `auto make(int n) { int x = n; auto f = [&x](int k) { return x + k; }; return f; }' took `x + k' for make's first return, and with the lambda's `k' undeclared there refused lambda_result_type
cpp_first_return(declare(_, _), _) :- !, fail.                                                   % nor a local class's method's
cpp_first_return(T, E) :- compound(T), T =.. [_|As], member(A, As), cpp_first_return(A, E), !.
%% THE LOCALS DECLARED ON THE WAY TO THE FIRST RETURN are in scope when its expression is typed: libc++'s hash
%% table writes `pair<iterator, bool> __r = __node_insert_unique(__h.get()); if (...) ...; return __r;' in a
%% lambda, and with the parameters alone declared `__r' had no type (lambda_result_type). Every declaration before
%% the return -- in its block and the blocks around it, a for's own -- is desugared for its DECLARATIONS only
%% (cpp_stmt declares as it walks), the output dropped; a refusal there is nothing, the walk of the body says it.
%% AND A RETURN IN A DISCARDED `if constexpr' BRANCH DOES NOT DEDUCE ([stmt.if]/2; 0.104): the condition is decided
%% here, with those locals in scope, and only the kept branch is entered -- libc++'s `__get_comp_type' opens with
%% `if constexpr (__cat == _None) return void();', and the first return taken textually made every
%% `common_comparison_category_t' void; a condition that does not fold leaves both branches, as the walk does.
cpp_first_return_in(Ctx, block(Ss), E) :- !, cpp_first_return_in_(Ss, Ctx, E).
cpp_first_return_in(Ctx, if_constexpr(_, C, T, Else), E) :- catch(( cpp_expr(Ctx, C, C1), cpp_const_bool(C1, V) ), _, fail), !,
    ( V == true -> cpp_first_return_in(Ctx, T, E) ; cpp_first_return_in(Ctx, Else, E) ).
cpp_first_return_in(Ctx, if_constexpr(_, _, T, Else), E) :- !, ( cpp_first_return_in(Ctx, T, E) -> true ; cpp_first_return_in(Ctx, Else, E) ).
cpp_first_return_in(Ctx, if(_, _, T, Else), E) :- !, ( cpp_first_return_in(Ctx, T, E) -> true ; cpp_first_return_in(Ctx, Else, E) ).
cpp_first_return_in(Ctx, for(_, Init, _, _, S), E) :- !, ( Init = decl(B, Vs) -> cpp_declare_only(Ctx, declaration(0, none, B, Vs)) ; true ), cpp_first_return_in(Ctx, S, E).
cpp_first_return_in(Ctx, while(_, _, S), E) :- !, cpp_first_return_in(Ctx, S, E).
cpp_first_return_in(Ctx, do(_, S, _), E) :- !, cpp_first_return_in(Ctx, S, E).
cpp_first_return_in(Ctx, switch(_, _, S), E) :- !, cpp_first_return_in(Ctx, S, E).
cpp_first_return_in(Ctx, label(_, _, S), E) :- !, cpp_first_return_in(Ctx, S, E).
cpp_first_return_in(Ctx, case(_, _, S), E) :- !, cpp_first_return_in(Ctx, S, E).
cpp_first_return_in(Ctx, default(_, S), E) :- !, cpp_first_return_in(Ctx, S, E).
cpp_first_return_in(_, S, E) :- cpp_first_return(S, E).
cpp_first_return_in_([declare(L, base(_, [class(K, N, Bases, Ms)]))|Ss], Ctx, E) :- atom(N), N \== anon, !,   % A LOCAL CLASS (0.121) is registered on the way, the statements after it naming it by its own name (cpp_stmts)
    cpp_local_class(L, K, N, Bases, Ms, Name), cpp_tag_scoped_list(Ss, N, ['$deep'-yes, N-Name], Ss1), cpp_first_return_in_(Ss1, Ctx, E).
cpp_first_return_in_([declaration(L, Sto, B, Vs)|Ss], Ctx, E) :- B = base(_, [class(K, anon, Bases, Ms)]), !,
    cpp_local_class(L, K, anon, Bases, Ms, Name), cpp_subst_term(class(K, anon, Bases, Ms), typedef(Name), declaration(L, Sto, B, Vs), D1),
    cpp_declare_only(Ctx, D1), cpp_first_return_in_(Ss, Ctx, E).
cpp_first_return_in_([typedef(_, Vs)|Ss], Ctx, E) :- !,   % A BLOCK TYPEDEF OF A NESTED BLOCK (0.132), as the body's own (cpp_body_typedefs): libc++'s ranges::to deduces its container in `if constexpr (...) { using _Result = decltype(_Container(...)); return type_identity<_Result>{}; }', and the free `_Result' was the deduced type
    ( catch(( cpp_vars(none, Vs, Vs1), cpp_block_typedefs(Vs1, B) ), Err, ( cpp_trace(body_typedef_refused(Err)), fail )), B \== [] -> cpp_subst(Ss, B, Ss1) ; Ss1 = Ss ),
    cpp_first_return_in_(Ss1, Ctx, E).
cpp_first_return_in_([S|Ss], Ctx, E) :- S = bindings(_, _, Ns, _), memberchk(pack(_), Ns), !,   % A STRUCTURED BINDING PACK (0.198, cpp_binding_names): the statements after it name its elements, as cpp_stmts has them
    nb_setval('$cpp_bindpack', none), cpp_declare_only(Ctx, S), nb_getval('$cpp_bindpack', PB), nb_setval('$cpp_bindpack', none),
    ( PB == none -> Ss1 = Ss ; cpp_subst(Ss, PB, Ss1) ), cpp_first_return_in_(Ss1, Ctx, E).
cpp_first_return_in_([S|Ss], Ctx, E) :-
    (   ( S = declaration(_, _, _, _) ; S = bindings(_, _, _, _) ) -> cpp_declare_only(Ctx, S), cpp_first_return_in_(Ss, Ctx, E)
    ;   cpp_first_return_in(Ctx, S, E) -> true
    ;   cpp_first_return_in_(Ss, Ctx, E) ).
cpp_declare_only(Ctx, S) :- ( catch(cpp_stmt(Ctx, S, _), error(not_lowered(W), _), ( cpp_trace(declare_only_refused(W)), fail )) -> true ; cpp_trace(declare_only_failed), true ).
