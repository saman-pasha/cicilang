%% ccl_cpp_stmt.pl -- statements, the scopes kept: temporaries and their full expressions, coroutines, exceptions,
%% the range-for and the structured bindings, conversion functions, local classes and usings, the named return value,
%% local statics and arrays, aggregates' items and braced arguments. A part of the C++ desugaring that ccl_cpp.pl
%% loads (0.223): its rules as they stood there, in their order.

%% ---- statements, the scopes kept -------------------------------------------------
%% A TEMPORARY DIES AT THE END OF ITS FULL EXPRESSION (C++'s rule), and the full expression here is the STATEMENT.
%% A temporary of a class with a DESTRUCTOR is declared in a block wrapped around the statement and destroyed by a
%% call after it -- `v.push_back(Tag(1))' constructed the temporary and left it alive for good, and a class holding
%% an owner leaked one buffer per call.
cpp_stmt(Ctx, S, Out) :-
    ( compound(S), arg(1, S, SL), integer(SL), SL > 0 -> nb_setval('$cpp_line', SL) ; true ),   % the line a refusal made inside the statement's expressions is reported at (0.117; the access control)
    ccl_global('$cpp_temps', Outer, none), nb_setval('$cpp_temps', []),
    (   catch(cpp_stmt_(Ctx, S, S1), E, (nb_setval('$cpp_temps', Outer), throw(E)))
    ->  nb_getval('$cpp_temps', Ts), nb_setval('$cpp_temps', Outer)
    ;   nb_setval('$cpp_temps', Outer), fail ),
    ( Ts == [] -> Out = S1 ; cpp_cond_flags(Ts, S1, S2, Ts1), cpp_temps_built_order(Ts1, S2, Ts2), cpp_temp_scope(S, Ts2, S2, Out) ),   % EVERY TEMPORARY FLAGGED WHERE IT IS BUILT (0.207), as a conditional operand's (cpp_cond_branch/4): its destruction asks the flag, on unwinding too, and comes in the reverse of the order they were built
    ( ccl_global('$cpp_in_lib', no, no) -> cpp_trace(stmt_out(Out)) ; true ).   % under the trace, the program's own statements as they come out
%% AN EXPRESSION OR A DECLARATION ends where its full expression ends, and the destructors are plain calls after
%% it: C++'s point of destruction, exactly. ANY OTHER statement holds statements of its own, past which an early
%% exit would walk, so its temporaries are destroyed by a DEFER at the end of a block wrapped around it -- which a
%% `return' needs in any case, the defers running after its value is computed. The temporaries are newest first:
%% declared in construction order, destroyed in the reverse, as C++ has it.
cpp_temp_scope(S0, Ts, S, '$splice'(Js)) :- ( S0 = expr(_, _) ; S0 = declaration(_, _, _, _) ), !,
    reverse(Ts, Order), cpp_temp_decls(Order, Ds), findall(C, (member(X, Ts), cpp_temp_end(X, C)), Cs),
    findall(eh_cleanup(0, block([C])), ( member(X, Order), cpp_temp_flagged(X), cpp_temp_dtor(X, C) ), Es),
    findall(eh_drop(0, block([C])), ( member(X, Ts), cpp_temp_flagged(X), cpp_temp_dtor(X, C) ), Xs),
    ( S = '$splice'(Is) -> true ; Is = [S] ), append([Ds, Es, Is, Cs, Xs], Js).
cpp_temp_scope(_, Ts, S, block(Js)) :- reverse(Ts, Order), cpp_temp_decls(Order, Ds),
    findall(defer(0, [], block([C])), (member(X, Order), cpp_temp_dtor(X, C)), Fs), append(Ds, Fs, Pre), append(Pre, [S], Js).
%% ... A FLAGGED TEMPORARY OF AN EXPRESSION OR A DECLARATION IS DESTROYED ON UNWINDING TOO, where it was built (0.207): an
%% unwinding-only cleanup that asks its flag (the lowering's eh_only) runs while the statement does, dropped at its end
%% (`eh_drop'), and the statement's own end clears the flag before the destructor runs, so a destructor that throws is not run
%% again by the cleanup. The callee destroyed a by-value parameter on unwinding before (cpp_byval_arg/3); a temporary bound to a
%% reference parameter was never destroyed by an exception.
cpp_temp_flagged(tmp(_, _, D)) :- nonvar(D), D = flag(_, _).
%% THE TEMPORARIES IN THE ORDER THEIR CONSTRUCTIONS END (0.207): each placed where the walked statement sets its flag, right after
%% its construction, in the evaluation's order -- the register is the order they were made in the desugaring, and a by-value
%% argument's copy is registered by the argument pass after the temporaries its later arguments made: `both(x, T(3), 4)' destroyed
%% the copy of x first, where clang destroys `T(3)' first. An unflagged one is placed where it is first named. Newest first.
cpp_temps_built_order(Ts, S, Ts1) :- cpp_ids_preorder(S, Ns, []),
    findall(K-T, ( member(T, Ts), T = tmp(N, _, D), ( nonvar(D), D = flag(F, _) -> M = F ; M = N ), ( nth0(K0, Ns, M) -> K = K0 ; K = -1 ) ), KTs0),
    keysort(KTs0, KTs), findall(T, member(_-T, KTs), Built), reverse(Built, Ts1).
cpp_ids_preorder(id(N), [N|R], R) :- atom(N), !.
cpp_ids_preorder(T, R0, R) :- compound(T), !, T =.. [_|As], cpp_ids_preorder_list(As, R0, R).
cpp_ids_preorder(_, R, R).
cpp_ids_preorder_list([], R, R).
cpp_ids_preorder_list([A|As], R0, R) :- cpp_ids_preorder(A, R0, R1), cpp_ids_preorder_list(As, R1, R).
cpp_temp_end(tmp(N, T, flag(F, D)), if(0, id(F), block([expr(0, assign('=', id(F), int(0)))|Ss]), none)) :- !, cpp_temp_dtor(tmp(N, T, D), S), ( S = block(Ss) -> true ; Ss = [S] ).
cpp_temp_end(X, C) :- cpp_temp_dtor(X, C).
cpp_temp_decls(Ts, Ds) :- findall(D, ( member(tmp(N, T, Dt), Ts), ( D = declaration(0, none, T, [var(N, T, none)]) ; nonvar(Dt), Dt = flag(F, _), D = declaration(0, none, base([], [int]), [var(F, base([], [int]), int(0))]) ) ), Ds).   % a flagged temporary's flag declared 0 beside it (cpp_cond_branch, 0.201)
%% A TEMPORARY WHOSE VALUE INITIALIZES ANOTHER OBJECT of its own class is ELIDED, as C++17 guarantees: the object
%% it builds IS the by-value parameter or the result, and whoever holds it destroys it. Its declaration goes back
%% inside its own block and the statement lets it be -- destroyed at both ends, `v.push(Name("gamma"))' freed one
%% buffer twice and `return Counter(n)' counted a destruction that never happened.
cpp_temp_elide(E0, E) :- E0 = stmt_expr(block(Is0)), append(_, [expr(_, id(N))], Is0),
    nb_getval('$cpp_temps', Ts), cpp_temp_take(N, Ts, T, Fl, Ts1), !,
    nb_setval('$cpp_temps', Ts1), cpp_unflag(Fl, Is0, Is), E = stmt_expr(block([declaration(0, none, T, [var(N, T, none)])|Is])).
cpp_temp_elide(cond(C, A0, B0), cond(C, A, B)) :- cpp_elidable_arm(A0), cpp_elidable_arm(B0), !, cpp_temp_elide(A0, A), cpp_temp_elide(B0, B).   % A CONDITIONAL OF TWO PRVALUES IS ELIDED ARM BY ARM ([class.copy.elision]/1, [expr.cond]/7; 0.201): `T x = c ? T(1) : T(2);' -- the object built in place by the arm taken (the lowering's ir_init/3 of a conditional), where it was copied bitwise and both arms' temporaries destroyed, one never built
cpp_temp_elide(E, E).
cpp_elidable_arm(stmt_expr(block(Is))) :- append(_, [expr(_, id(N))], Is), atom(N), nb_current('$cpp_temps', Ts), is_list(Ts), memberchk(tmp(N, _, _), Ts), !.
cpp_elidable_arm(call(_, _)) :- !.
cpp_elidable_arm(cond(_, A, B)) :- cpp_elidable_arm(A), cpp_elidable_arm(B).
cpp_temp_take(N, Ts, T, Ts1) :- cpp_temp_take(N, Ts, T, _, Ts1).
cpp_temp_take(N, [tmp(N, T, D)|Ts], T, Fl, Ts) :- !, ( nonvar(D), D = flag(F, _) -> Fl = F ; Fl = none ).   % ... and its cleanup flag, `none' where it has none (0.201)
cpp_temp_take(N, [X|Ts], T, Fl, [X|Rs]) :- cpp_temp_take(N, Ts, T, Fl, Rs).
%% a temporary taken out of the statement's register takes its flag's setting out of its block: the flag is declared
%% with the register's entries, and the setting left behind named nothing
cpp_unflag(none, Is, Is) :- !.
cpp_unflag(F, Is0, Is) :- cpp_del_flag(Is0, F, Is).
cpp_del_flag([], _, []).
cpp_del_flag([I|Is], F, Js) :- I = expr(_, assign('=', Id, int(1))), Id == id(F), !, cpp_del_flag(Is, F, Js).
cpp_del_flag([I|Is], F, [I|Js]) :- cpp_del_flag(Is, F, Js).
%% A TEMPORARY BUILT BY cpp_temporary, CONSTRUCTED AT A PLACE INSTEAD (0.121): its statement expression ends in the temporary's name, and the constructor call before it works on `addr(id(Tmp))'. The call over the place's
%% address is the same construction in its final home -- the temporary's own declaration and its entry in the statement's register of destructions (the place's owner destroys the object) are dropped. It fails for any
%% other form (a call returning the class), and where the temporary's name is used otherwise than by that address.
cpp_prvalue_in_place(stmt_expr(block(Is)), Place, block(Is2)) :-
    append(Pre, [expr(_, id(Tmp))], Is), atom(Tmp), sub_atom(Tmp, 0, _, _, '$tmp'),
    cpp_without_decl(Pre, Tmp, Pre1), \+ ( member(declaration(_, _, _, Vs), Pre1), memberchk(var(Tmp, _, _), Vs) ),
    cpp_subst_term(id(Tmp), Place, Pre1, Is1),   % its constructor's object, and an AGGREGATE's temporary built member by member over `$tmp' too (0.206): `Leaf{3, {}}' with a list member
    (   ccl_global('$cpp_temps', Ts, none), is_list(Ts), cpp_temp_take(Tmp, Ts, _, Fl, Ts1) -> nb_setval('$cpp_temps', Ts1), cpp_unflag(Fl, Is1, Is2) ; Is2 = Is1 ).
cpp_without_decl([], _, []).
cpp_without_decl([declaration(_, _, _, [var(N, _, none)])|Is], N, Js) :- !, cpp_without_decl(Is, N, Js).
cpp_without_decl([I|Is], N, [I|Js]) :- cpp_without_decl(Is, N, Js).
cpp_mentions(T, S) :- T == S, !.
cpp_mentions(T, S) :- compound(T), T =.. [_|As], member(A, As), cpp_mentions(A, S), !.
cpp_temp_dtor(tmp(N, T, flag(F, D)), if(0, id(F), S, none)) :- !, cpp_temp_dtor(tmp(N, T, D), S).   % a flagged one where its flag is set (cpp_cond_branch, 0.201)
cpp_temp_dtor(tmp(_, _, stmts(Ds)), block(Ds)) :- !.   % an initializer_list's array of objects, element by element (cpp_init_list/4, 0.206)
cpp_temp_dtor(tmp(N, _, D), expr(0, call(id(D), [addr(id(N))]))).
%% A LOOP'S CONDITION AND STEP ARE EVALUATED AT EVERY ITERATION, and so are their temporaries ([class.temporary]/4:
%% each dies at the end of its full expression; 0.112, refused as `temporary_in_a_loop_condition' since 0.62): an
%% expression whose walk registered temporaries becomes a statement expression of its own -- the temporaries declared,
%% the value kept in `$cv' (a condition's, after its contextual conversion to bool), the destructors run, the value
%% last -- so each evaluation builds and destroys its own. `while (std::string(p) != "end")'.
cpp_opt_expr_once(_, _, none, none) :- !.
cpp_opt_expr_once(Ctx, L, E, E1) :- cpp_expr_once(Ctx, L, E, E1).
cpp_opt_cond_once(_, _, none, none) :- !.
cpp_opt_cond_once(Ctx, L, E, E1) :- cpp_cond_once(Ctx, L, E, E1).
cpp_expr_once(Ctx, L, E, E1) :- cpp_expr_temps(Ctx, E, E0, Ts), ( Ts == [] -> E1 = E0 ; cpp_temps_around(L, Ts, E0, none, E1) ).
cpp_cond_once(Ctx, L, E, E1) :- cpp_expr_temps(Ctx, E, E0, Ts), cpp_to_bool(E0, Eb), ( Ts == [] -> E1 = Eb ; cpp_temps_around(L, Ts, Eb, value, E1) ).
cpp_expr_temps(Ctx, E, E0, Ts) :- nb_getval('$cpp_temps', B), nb_setval('$cpp_temps', []),
    (   catch(cpp_expr(Ctx, E, E0), X, (nb_setval('$cpp_temps', B), throw(X)))
    ->  nb_getval('$cpp_temps', Ts), nb_setval('$cpp_temps', B)
    ;   nb_setval('$cpp_temps', B), fail ).
cpp_temps_around(L, Ts, E0, How, stmt_expr(block(Ss))) :-
    reverse(Ts, Order), cpp_temp_decls(Order, Ds), findall(C, (member(X, Ts), cpp_temp_dtor(X, C)), Cs),
    (   How == value
    ->  ( ccl_type_of(E0, VT), VT \== unknown -> true ; cpp_refuse(L, temporary_in_a_loop_condition) ), ccl_gensym('$cv', V), ccl_declare(V, VT),
        append(Ds, [declaration(L, none, VT, [var(V, VT, E0)])|Cs], S0), append(S0, [expr(L, id(V))], Ss)
    ;   append(Ds, [expr(L, E0)|Cs], Ss) ).
%% THE CONDITION OF AN `if' IS A FULL-EXPRESSION ([intro.execution]/5, [stmt.pre]; 0.201): its temporaries die when its
%% evaluation ends, before a branch runs, as a loop's condition's do (cpp_cond_once); they were the whole statement's,
%% destroyed after the branch. A value the inference cannot type leaves them the statement's, as before.
cpp_if_cond(Ctx, L, C, C2) :- cpp_expr_temps(Ctx, C, C0, Ts), cpp_to_bool(C0, Cb),
    (   Ts == [] -> C2 = Cb
    ;   catch(ccl_type_of(Cb, VT), _, fail), VT \== unknown -> cpp_temps_around(L, Ts, Cb, value, C2)
    ;   cpp_temps_back(Ts), C2 = Cb ).
cpp_temps_back(Ts) :- nb_getval('$cpp_temps', R), ( is_list(R) -> append(Ts, R, R1), nb_setval('$cpp_temps', R1) ; true ).
%% A TEMPORARY BUILT IN A CONDITIONALLY EVALUATED OPERAND -- the right operand of `&&' and `||', an arm of `?:' -- IS
%% DESTROYED ONLY WHERE IT WAS BUILT ([class.temporary]/4: only a constructed object is destroyed; 0.201): it is the
%% statement's, as any temporary, with a cleanup flag of its own, `$tf_K', declared 0 beside it (cpp_temp_decls/2), set
%% to 1 right after its construction in the operand's walked form (cpp_flag_set/4), its destructor called only where the
%% flag is set (cpp_temp_dtor/2) -- clang's cleanup flag. It was destroyed at the statement's end on every path, over the
%% stack's garbage: libc++'s `__assoc_sub_state::__has_value()' is `(__state_ & __constructed) || (__exception_ !=
%% nullptr)', whose right operand builds an `exception_ptr(nullptr)', and a `std::future' that a thread set crashed in
%% `__cxa_decrement_exception_refcount'. A temporary flagged already, in a nested operand, keeps its flag, which only its
%% own construction sets; one whose construction is not found in the walked form keeps the old road (trace).
cpp_cond_branch(Ctx, X, X0, Tn) :- ccl_global('$cpp_temps', R, none),
    (   is_list(R)
    ->  nb_setval('$cpp_temps', []),
        (   catch(cpp_expr(Ctx, X, X0), E, ( nb_setval('$cpp_temps', R), throw(E) ))
        ->  nb_getval('$cpp_temps', Tn), nb_setval('$cpp_temps', R)
        ;   nb_setval('$cpp_temps', R), fail )
    ;   cpp_expr(Ctx, X, X0), Tn = [] ).
cpp_cond_flag([], X, X) :- !.
cpp_cond_flag(Tn, X0, X) :- cpp_cond_flags(Tn, X0, X, Fl), nb_getval('$cpp_temps', R), ( is_list(R) -> append(Fl, R, R1), nb_setval('$cpp_temps', R1) ; true ).
cpp_cond_flags([], X, X, []).
cpp_cond_flags([tmp(N, T, D)|Ts], X0, X, [tmp(N, T, D1)|Fs]) :-
    (   nonvar(D), D = flag(_, _) -> D1 = D, X1 = X0
    ;   ccl_gensym('$tf', F), ccl_declare(F, base([], [int])),
        (   cpp_flag_set(N, F, X0, X2) -> D1 = flag(F, D), X1 = X2
        ;   cpp_trace(cleanup_flag_unplaced(N)), D1 = D, X1 = X0 ) ),
    cpp_cond_flags(Ts, X1, X, Fs).
cpp_flag_set(N, F, T0, T) :- compound(T0), T0 = stmt_expr(block(Is)), is_list(Is), cpp_flag_in(Is, N, F, Is1), !, T = stmt_expr(block(Is1)).
cpp_flag_set(N, F, T0, T) :- compound(T0), T0 =.. [Fn|As], cpp_flag_set_args(As, N, F, Bs), T =.. [Fn|Bs].
cpp_flag_set_args([A|As], N, F, [B|As]) :- cpp_flag_set(N, F, A, B), !.
cpp_flag_set_args([A|As], N, F, [A|Bs]) :- cpp_flag_set_args(As, N, F, Bs).
cpp_flag_in(Is, N, F, Is1) :- append(Pre, [expr(L, Last)], Is), Last == id(N), !, append(Pre, [expr(0, assign('=', id(F), int(1))), expr(L, id(N))], Is1).   % cpp_temporary's block and the `$tmp = A' one end in the temporary's name
cpp_flag_in(Is, N, F, Is1) :- append(Pre, [S|Post], Is), S = expr(_, assign('=', Id, _)), Id == id(N), !, append(Pre, [S, expr(0, assign('=', id(F), int(1)))|Post], Is1).   % a call's object, `$tmp = f()', then its operator() (cpp_temp_call/3)
%% AN LVALUE ARM BESIDE A PRVALUE ARM OF ONE CLASS IS COPIED into a temporary ([expr.cond]/7: the conditional is a prvalue;
%% 0.201): `c ? x : T(2)' -- each arm then builds the result, and a class with a destructor or a written copy constructor
%% is never copied bitwise
cpp_cond_copy_arm(X, Other, Tx, X1, Tx1) :- nb_current('$cpp_temps', R), is_list(R), cpp_class_glvalue(X), \+ cpp_class_glvalue(Other),
    cpp_class_of_type_of(X, C), cpp_class_of_type_of(Other, C), ( cpp_dtor(C, _) -> true ; cpp_written_copy_ctor(C) ), !,
    nb_setval('$cpp_temps', []),
    (   catch(cpp_temporary(base([], [typedef(C)]), C, [X], X0), E, ( nb_setval('$cpp_temps', R), throw(E) ))
    ->  nb_getval('$cpp_temps', Tn), nb_setval('$cpp_temps', R), X1 = X0, append(Tn, Tx, Tx1)
    ;   nb_setval('$cpp_temps', R), X1 = X, Tx1 = Tx ).
cpp_cond_copy_arm(X, _, Tx, X, Tx).
cpp_class_glvalue(X) :- ( cpp_lvalue(X) -> true ; cpp_xvalue_object(X) ).
cpp_stmt_(_, '$in_class'(C, B), B1) :- !, cpp_in_class(C, cpp_stmt(C, B, B1)).   % a friend template's body in its class (0.115; cpp_friend_tmpl_words)
cpp_stmt_(Ctx, block(Is), block(Js)) :- !, cpp_in_frame(cpp_stmts(Ctx, Is, Js)).
cpp_stmt_(Ctx, '$splice'(Is), '$splice'(Js)) :- !, cpp_stmts(Ctx, Is, Js).
cpp_stmt_(Ctx, declaration(L, Sto, B, Vs), S) :- !, cpp_decl_stmt(Ctx, L, Sto, B, Vs, S).
%% A STRUCTURED BINDING THE READER DEFERRED (bindings/4): the initializer desugared and typed, a temporary of that
%% type (a reference to it for `auto &'), then one `auto' declaration per name from the class's data members by
%% position -- a pair's first and second, a struct's members; a tuple's get<I> is not done
cpp_stmt_(Ctx, bindings(L, Ref, Ns0, E0), S) :- !,
    cpp_expr(Ctx, E0, E), ( cpp_arg_type(E, T0) -> true ; cpp_refuse(L, bindings_untyped(Ns0)) ), ccl_unref(T0, T1), cpp_type(T1, T),
    cpp_binding_names(L, T, Ns0, Ns),   % a binding pack's elements named (0.198, below)
    length(Ns, K),
    ccl_gensym('$bind', Tmp),
    ( Ref == yes, cpp_lvalue(E) -> TT = ref([], T) ; TT = T ),
    ( Ref == yes -> VT = ref([], base([], [auto])) ; VT = base([], [auto]) ),
    (   cpp_tuple_size(T, K0)                                                    % THE TUPLE PROTOCOL, below
    ->  ( K0 =:= K -> true ; cpp_refuse(L, bindings_count(K)) ),
        cpp_binding_get(T, G),
        findall(declaration(L, none, base([], [auto]), [var(N, ref([], base([], [auto])), call(tmpl(G, [int(I0)]), [id(Tmp)]))]),
                ( nth1(I, Ns, N), N \== '_', I0 is I - 1 ), Decls)
    ;   (   cpp_class_of_type(T, C) -> cpp_class_l(C, cls(_, Data, _, _, _)), findall(M-MT, ( member(member(MT, M, _), Data), M \== '$base', M \== '$vptr' ), Ms)
        ;   ccl_resolve_type(T, base(_, [struct(_, SMs)])) -> findall(M-MT, member(member(MT, M, _), SMs), Ms)
        ;   cpp_refuse(L, bindings_of(T)) ),
        ( length(Ms, K) -> true ; cpp_refuse(L, bindings_count(K)) ),
        findall(declaration(L, none, base([], [auto]), [var(N, VTn, member(id(Tmp), M))]), ( nth1(I, Ns, N), nth1(I, Ms, M-MT), N \== '_', cpp_binding_vt(MT, VT, VTn) ), Decls) ),   % A BINDING TO A REFERENCE MEMBER IS A REFERENCE ([dcl.struct.bind]: its type is the tuple element's, `B &'): libc++'s __find_equal answers `pair<__end_node_pointer, __node_base_pointer &>', and `auto [__parent, __child]' then STORES THE NEW NODE THROUGH __child -- copied, the pointer went nowhere and the tree balanced a null root
    cpp_stmts(Ctx, [declaration(L, none, TT, [var(Tmp, TT, '$cpp_walked'(E))])|Decls], Ss), S = '$splice'(Ss).   % THE INITIALIZER WALKED ONCE (0.132): handed on desugared and walked again, its temporary's declaration was default-constructed before its constructor ran, and `const auto [b, e] = ranges::subrange{sv};' asked subrange for a constructor from the whole statement expression
cpp_stmt_(Ctx, expr(L, E), expr(L, E1)) :- !, cpp_expr(Ctx, E, E1).
cpp_stmt_(Ctx, gnu_asm(L, ext(Qs, T, Os, Is, Cs, Ls)), gnu_asm(L, ext(Qs, T, Os1, Is1, Cs, Ls))) :- !, cpp_asm_ops(Ctx, Os, Os1), cpp_asm_ops(Ctx, Is, Is1).   % GNU's asm statement (0.215): its operands desugared
cpp_stmt_(Ctx, assume(L, E), assume(L, E1)) :- !, cpp_expr(Ctx, E, E1).                       % C++23's [[assume(e)]]
cpp_stmt_(_, using(_, enum(_)), empty) :- !.                                                    % C++20: the enumerators are in scope already (a namespace flattens)
cpp_stmt_(Ctx, defer(L, Vs, Body), defer(L, Vs, Body1)) :- !, cpp_stmt(Ctx, Body, Body1).
cpp_stmt_(Ctx, eh_cleanup(L, Body), eh_cleanup(L, Body1)) :- !, cpp_stmt(Ctx, Body, Body1).   % a constructor's cleanup of a base or a member it built (cpp_member_cleanup/4, 0.201)
cpp_stmt_(Ctx, if_constexpr(L, C, T, E), Out) :- !,                                          % C++17: decided here when the condition is a constant, else a plain if
    cpp_expr(Ctx, C, C1),
    (   cpp_const_bool(C1, V) -> ( V == true -> cpp_stmt(Ctx, T, Out) ; E == none -> Out = empty ; cpp_stmt(Ctx, E, Out) )
    ;   cpp_stmt(Ctx, T, T1), ( E == none -> E1 = none ; cpp_stmt(Ctx, E, E1) ), Out = if(L, C1, T1, E1) ).
%% C++23's `if consteval': BOTH branches are kept, `ifce(L, CompileTime, RunTime)' -- the lowering and the check take
%% the run-time one, the constexpr evaluator the compile-time one (0.108: the evaluator had only the run-time
%% branch, so a consteval function's fold took the wrong road). THE COMPILE-TIME BRANCH IS AN IMMEDIATE FUNCTION CONTEXT
%% (0.234; C++23 [expr.const]/16): a consteval function's call there that does not fold stands, for the evaluator to take
%% where it takes the branch (cpp_immediate_context/0) -- libc++ 22's `std::is_within_lifetime(&b)' inside a constexpr
%% member's `if consteval' was refused `consteval_call_not_constant'
cpp_stmt_(Ctx, if_consteval(L, Neg, T, E), ifce(L, CT1, RT1)) :- !,
    ( Neg == yes -> RT = T, CT = E ; RT = E, CT = T ),
    ( CT == none -> CT1 = empty ; ( nb_current('$cpp_in_ifce', I0) -> true ; I0 = no ), nb_setval('$cpp_in_ifce', yes),
      ( catch(cpp_stmt(Ctx, CT, CT1), X, ( nb_setval('$cpp_in_ifce', I0), throw(X) )) -> nb_setval('$cpp_in_ifce', I0) ; nb_setval('$cpp_in_ifce', I0), fail ) ),
    ( RT == none -> RT1 = empty ; cpp_stmt(Ctx, RT, RT1) ).
%% ---- C++20 COROUTINES (0.108; refused by name since 0.42) ---------------------------------------------------
%% A function whose body holds co_await, co_yield or co_return is made the skeleton the lowering takes
%% (`cpp_coro_skeleton', before the walk): the promise `$promise' of `R::promise_type' declared, `coro_begin',
%% `coro_ret' (get_return_object(), converted as a return is), the initial suspend's await, `coro_body' (the body,
%% then a fall-off `return_void()' where the promise has one), the final suspend's await, `coro_done'. co_return is
%% the promise's return_value or return_void and `coro_return'; co_yield e is co_await of `yield_value(e)'; co_await
%% e -- through the promise's await_transform where it has one -- is a statement expression over the awaiter:
%% `await_ready()', else `coro_suspend' over `await_suspend(coroutine_handle<P>::from_address(frame))', then
%% `await_resume()'. The lowering is LLVM's switch-resumed coroutine.
cpp_stmt_(Ctx, co_return(L, none), S) :- !, cpp_stmt(Ctx, block([expr(L, call(member(id('$promise'), return_void), [])), coro_return(L)]), S).
cpp_stmt_(Ctx, co_return(L, E), S) :- !, cpp_stmt(Ctx, block([expr(L, call(member(id('$promise'), return_value), [E])), coro_return(L)]), S).
cpp_stmt_(Ctx, coro_promise(L, PT, Init), D) :- !, cpp_stmt(Ctx, declaration(L, none, PT, [var('$promise', PT, Init)]), S),   % THE PROMISE IS CONSTRUCTED ONCE THE STATE IS ALLOCATED ([dcl.fct.def.coroutine]/5, /10; 0.205): its storage declared here, where the lowering's `llvm.coro.id' takes it, and its constructor and its destructor's defer after the allocation (below)
    ( S = '$splice'([D|Rest]), D = declaration(_, _, _, _) -> true ; D = S, Rest = [] ), nb_setval('$cpp_coro_pinit', Rest).
cpp_stmt_(Ctx, coro_begin(L, P, As), '$splice'([coro_begin(L, P, A, F)|Rest])) :- !, cpp_coro_alloc(Ctx, L, As, A, F),   % the coroutine state's allocation (0.202), then the promise's construction: where `get_return_object_on_allocation_failure()' answers a null state, no promise was built and none is destroyed -- it was built first and destroyed on that return
    ( nb_current('$cpp_coro_pinit', Rest0) -> Rest = Rest0 ; Rest = [] ), nb_setval('$cpp_coro_pinit', []).
cpp_stmt_(_, coro_return(L), coro_return(L)) :- !.
cpp_stmt_(_, coro_done(L), coro_done(L, D)) :- !, cpp_coro_dealloc(D).
cpp_stmt_(Ctx, coro_body(L, S0), coro_body(L, S)) :- !, cpp_stmt(Ctx, S0, S).
cpp_stmt_(Ctx, coro_ret(L, E0), S) :- !, cpp_stmt(Ctx, return(L, E0), S0), ( cpp_coro_ret(S0, S) -> true ; cpp_refuse(L, coroutine_return_object) ).
cpp_stmt_(Ctx, coro_falloff(L), S) :- !, ( cpp_promise_class(C), cpp_has_member(C, return_void) -> cpp_stmt(Ctx, expr(L, call(member(id('$promise'), return_void), [])), S) ; S = block([]) ).
cpp_stmt_(Ctx, coro_suspend(L, K, E0), coro_suspend(L, K, E, SK)) :- !, cpp_expr(Ctx, E0, E),
    ( ccl_type_of(E, T0), T0 \== unknown -> true ; cpp_refuse(L, await_suspend_type) ),
    ( ccl_resolve_type(T0, base(_, [void])) -> SK = void ; cpp_class_of_type(T0, _) -> SK = handle ; SK = bool ).
%% ---- EXCEPTIONS (0.108; refused by name since M6's first step) ----------------------------------------------------
%% The PROGRAM's throw and try, over the Itanium C++ ABI's runtime in libc++abi (linked with -lc++), while libc++
%% keeps its own no-exceptions configuration (0.50): `throw e' is __cxa_allocate_exception, the object made in place
%% by the placement new's road, and __cxa_throw with the type's type_info and its destructor; a try's handlers are
%% matched by that type_info in the lowering's landing pads, which also run the destructors and defers of every scope
%% the exception leaves (ir_landing_pad). A handler binds its parameter to the caught object: by reference as C++
%% says, and a class caught BY VALUE is bound to the object itself rather than a copy (named, not done).
cpp_stmt_(Ctx, try(L, Body, Catches), try(L, Body1, Catches1)) :- !, ( Catches = [catch(terminate, _)] -> true ; cpp_eh_needed(try_requires_exceptions) ), nb_setval('$cpp_eh_used', yes),
    cpp_stmt(Ctx, Body, Body1), cpp_catches(Ctx, Catches, Catches1).
cpp_stmt_(Ctx, if(L, C, T, E), if(L, C2, T1, E1)) :- !, cpp_if_cond(Ctx, L, C, C2), cpp_stmt(Ctx, T, T1), ( E == none -> E1 = none ; cpp_stmt(Ctx, E, E1) ).
cpp_stmt_(Ctx, while(L, C, S), while(L, C2, S1)) :- !, cpp_cond_once(Ctx, L, C, C2), cpp_stmt(Ctx, S, S1).
cpp_stmt_(Ctx, do(L, S, C), do(L, S1, C2)) :- !, cpp_stmt(Ctx, S, S1), cpp_cond_once(Ctx, L, C, C2).
cpp_stmt_(Ctx, for(L, decl(B, Vs), C, Step, S), Out) :- !,                                  % A FOR'S DECLARATION IS A DECLARATION IN THE FOR'S OWN SCOPE ([stmt.for]/1: `{ init; for (; c; step) s }'), so it takes the declaration road -- `auto' deduced, a class local constructed and its destructor deferred -- where cpp_vars left `auto it2 = m.begin()' undeduced for the lowering to refuse
    cpp_stmt_(Ctx, block([declaration(L, none, B, Vs), for(L, none, C, Step, S)]), Out).
cpp_stmt_(Ctx, for(L, Init, C, Step, S), for(L, Init1, C1, Step1, S1)) :- !,
    cpp_in_frame(( ( Init = decl(B, Vs) -> cpp_vars(Ctx, Vs, Vs1), ccl_declare_vars(Vs1), Init1 = decl(B, Vs1) ; cpp_opt_expr(Ctx, Init, Init1) ),
                   cpp_opt_cond_once(Ctx, L, C, C1), cpp_opt_expr_once(Ctx, L, Step, Step1), cpp_stmt(Ctx, S, S1) )).
%% A RANGE-FOR OVER AN OBJECT WITH begin() AND end() IS C++'s: `auto __b = r.begin(), __e = r.end(); for (; __b != __e;
%% ++__b) { decl = *__b; body }' -- the iterator's `!=', `++' and `*' the class's own (a map's are hidden friends). It
%% comes BEFORE the size()/[] rewrite of 0.38, which is this compiler's shortcut for a container indexed by position:
%% a map has both, and indexed by position it would have inserted the keys 0, 1, 2. A prvalue range is bound to a
%% reference first (`auto &&'), an lvalue used as it is; a structured binding as the declaration becomes bindings/4.
cpp_stmt_(Ctx, for_each(L, Decl, R, S), Out) :-
    cpp_expr(Ctx, R, R0), cpp_range_class(R0, C), cpp_range_ends(C, How),
    ( Decl = var(_, _, _) ; Decl = bindings(_, _) ), !,
    (   cpp_lvalue(R0) -> R1 = R0, Range = R1, Pre = []
    ;   cpp_temp_elide(R0, R1),                                                           % THE PRVALUE RANGE IS THE `auto &&' OBJECT (0.117): its temporary was registered with THIS statement, and the declaration below is a statement of its own whose elision looks in its own register -- the vector of `for (auto x : std::vector<int>(3, 7))' was destroyed by both
        ccl_gensym('$range', Rn), Pre = [declaration(L, none, base([], [auto]), [var(Rn, rref([], base([], [auto])), '$cpp_walked'(R1))])], Range = id(Rn) ),
    ccl_gensym('$it', B), ccl_gensym('$end', E),
    cpp_range_call(How, begin, Range, BCall), cpp_range_call(How, end, Range, ECall),
    Decls = [declaration(L, none, base([], [auto]), [var(B, base([], [auto]), BCall)]),
             declaration(L, none, base([], [auto]), [var(E, base([], [auto]), ECall)])],
    (   Decl = var(N, T0, _) -> Body0 = declaration(L, none, T0, [var(N, T0, deref(id(B)))])
    ;   Decl = bindings(Ref, Ns), Body0 = bindings(L, Ref, Ns, deref(id(B))) ),
    For = for(L, none, bin('!=', id(B), id(E)), preinc(id(B)), block([Body0, S])),
    append(Pre, Decls, Ds), append(Ds, [For], Items),
    cpp_stmt(Ctx, block(Items), Out).
cpp_stmt_(Ctx, for_each(L, var(N, T0, I), R, S), Out) :- !,
    cpp_type(T0, T), cpp_expr(Ctx, R, R1),
    (   cpp_class_of_type_of(R1, C), cpp_method(C, size, [], _, _), cpp_method(C, operator('[]'), [int(0)], IxName, _)   % a range-for over an object: by size() and []
    ->  ( cpp_lvalue(R1) -> true ; cpp_refuse(L, range_for_over_a_value(C)) ),
        ccl_declared(IxName, fn(ERet, _, _)), ccl_unref(ERet, ET), cpp_range_type(T, ET, T1), ccl_gensym('$i', Ix),
        For = for(L, decl(base([], [int]), [var(Ix, base([], [int]), int(0))]), bin('<', id(Ix), call(member(R1, size), [])), postinc(id(Ix)),
                  block([declaration(L, none, ET, [var(N, T1, index(R1, id(Ix)))]), S])),
        cpp_stmt(Ctx, For, Out)
    ;   Out = for_each(L, var(N, T, I), R1, S1), cpp_in_frame(( ccl_declare(N, T), cpp_stmt(Ctx, S, S1) )) ).
%% `return { a, b }': the RESULT TYPE's object, built from the items -- through its constructor where it has one
%% (libc++'s __copy returns `{ __last, __result }', a pair), else the aggregate literal -- and the result it is, elided
cpp_stmt_(Ctx, return(L, init(Items)), return(L, E2)) :- nb_getval('$cpp_ret', Ret), Ret \== none, cpp_designated(Items), !,   % `return {.a = 1}': a designated list names the result aggregate's members (0.112), where they were taken in order with their designators dropped
    (   cpp_class_of_type(Ret, C), cpp_class_l(C, cls(_, Data, _, _, _)), cpp_agg_slots(Items, Data, 0, [], _)
    ->  cpp_agg_values(Data, Items, Vs0), cpp_exprs(Ctx, Vs0, Vs), cpp_type(Ret, T), cpp_agg_temp(T, C, Data, Vs, E0)
    ;   cpp_expr(Ctx, init(Items), I1), E0 = compound_lit(Ret, I1) ),
    cpp_temp_elide(E0, E2).
cpp_stmt_(Ctx, return(L, init(Items)), return(L, E2)) :- nb_getval('$cpp_ret', Ret), Ret \== none, cpp_class_of_type(Ret, C0), cpp_has_ctors(C0), cpp_il_braced(C0, Items, ET0), !,   % `return {"a", "b"}' of a vector<string>: the initializer_list constructor FIRST ([over.match.list]; 0.117), the list one argument
    cpp_init_list(Ctx, ET0, Items, IL0), cpp_temporary(Ret, C0, [IL0], E0), cpp_temp_elide(E0, E2).
cpp_stmt_(Ctx, return(L, init(Items)), return(L, E2)) :- nb_getval('$cpp_ret', Ret), Ret \== none, !,
    findall(V, member(item(_, V), Items), Vs0), cpp_exprs(Ctx, Vs0, Vs),
    (   cpp_class_of_type(Ret, C), cpp_has_ctors(C) -> cpp_temporary(Ret, C, Vs, E0)
    ;   cpp_class_of_type(Ret, C), cpp_class_l(C, cls(_, Data, _, _, _)), member(member(MT, _, _), Data), cpp_class_of_type(MT, MC), cpp_has_ctors(MC)   % AN AGGREGATE WHOSE MEMBER CONSTRUCTS is built member by member (cpp_aggregate_inits, 0.41's road for a local): the tree's `return _InsertReturnType{end(), false, _NodeHandle()}' put a `__tree_iterator' into a `__tree_const_iterator' member bitwise, where its converting constructor was meant
    ->  cpp_type(Ret, T), ccl_gensym('$ret', Tmp), ccl_declare(Tmp, T), cpp_aggregate_inits(Data, Vs, id(Tmp), L, Inits),
        append([declaration(L, none, T, [var(Tmp, T, none)])|Inits], [expr(L, id(Tmp))], Ss), E0 = stmt_expr(block(Ss))
    ;   findall(item([], V), member(V, Vs), Items1), cpp_init_convs(Ret, init(Items1), I2), E0 = compound_lit(Ret, I2) ),   % an aggregate's class items converted to its scalar members (cpp_init_convs, 0.168)
    cpp_temp_elide(E0, E2).
cpp_stmt_(Ctx, return(L, cond(C, A, B)), Out) :- nb_getval('$cpp_ret', Ret), Ret \== none, cpp_class_of_type(Ret, _), !,   % A RETURN OF A CONDITIONAL OVER CLASS ARMS returns each arm on its own ([expr.cond], [class.copy.elision]: the chosen arm's prvalue IS the result object): optional's `value_or' is `return has_value() ? __get() : static_cast<value_type>(...)', and as one value the lvalue arm was copied BITWISE and the temporary arm destroyed under the caller
    cpp_stmt_(Ctx, if(L, C, return(L, A), return(L, B)), Out).
cpp_stmt_(Ctx, return(L, paren(E)), Out) :- !, cpp_stmt_(Ctx, return(L, E), Out).
cpp_stmt_(_, return(L, nrvo(N)), block([expr(L, assign('=', id(F), int(1))), return(L, id(N))])) :- !, cpp_nrvo_flag(N, F).   % THE NAMED RETURN VALUE (0.199, cpp_nrvo/3): it is the result already   % `return (x);': the parentheses spoke to the deduction of a decltype(auto) result alone (0.197)
cpp_stmt_(Ctx, return(L, E), return(L, E2)) :- !, cpp_expr(Ctx, E, E0), cpp_temp_elide(E0, E1),
    (   nb_getval('$cpp_ret', Ret), Ret \== none, cpp_class_of_type(Ret, C), ccl_type_of(E1, AT), AT \== unknown, \+ cpp_class_of_type_of(E1, C), cpp_converting_ctor(C, E1),
        ( cpp_implicitly_movable(E), cpp_class_of_type_of(E1, _) -> E1a = move(E1) ; E1a = E1 )   % ... an implicitly movable name as an rvalue (C++20's P1825: `return m;' into `Box(M x)' moves m into x)   % A VALUE OF ANOTHER TYPE RETURNED converts through the result class's converting constructor, as a call's argument does (0.66): libc++'s `map::find' returns `__tree_.find(__k)', a __tree_iterator where its iterator is a __map_iterator holding one
    ->  cpp_temporary(base([], [typedef(C)]), C, [E1a], E2a), cpp_temp_elide(E2a, E2)
    ;   nb_getval('$cpp_ret', Ret), Ret \== none, cpp_class_of_type(Ret, C), cpp_class_of_type_of(E1, C1), C1 \== C, \+ cpp_class_fits(C1, C), cpp_conv_to(E1, Ret, E2a)   % (never a DERIVED object's, which the result's copy or move constructor slices, below; 0.197) ... or through the VALUE's conversion operator ([class.conv.fct]; 0.108): a coroutine's `return h;' of a coroutine_handle<P> where coroutine_handle<> is the result
    ->  E2 = E2a
    ;   nb_getval('$cpp_ret', Ret), Ret \== none, \+ cpp_class_of_type(Ret, _), cpp_class_of_type_of(E1, _), cpp_conv_to(E1, Ret, E2a), E2a \== E1   % ... AND A SCALAR RESULT takes the value's conversion function too ([stmt.return]/2, [class.conv.fct]; 0.117): libc++'s `bitset::test' is `bool test(size_t) const { return (*this)[__pos]; }', a __bit_const_reference converting to bool, which was compared with zero as a struct
    ->  E2 = E2a
    ;   nb_getval('$cpp_ret', Ret), Ret \== none, cpp_class_of_type(Ret, C), cpp_ret_constructs(C),
        ( E1 = move(EL0), cpp_lvalue(EL0) -> How = move ; cpp_lvalue(E1), EL0 = E1, ( cpp_implicitly_movable(E) -> How = move ; How = copy ) ),   % by value: `return std::move(x)' and an implicitly movable name move, any other lvalue is copied (0.197)
        ( cpp_class_of_type_of(EL0, C1), C1 \== C, cpp_class_fits(C1, C) -> EL = deref(cast(ptr([], base([], [typedef(C)])), addr(EL0))) ; EL = EL0 )   % a DERIVED object's base sub-object, which the move constructor takes as its own class's (0.197: `M(const M &)' was chosen, the tie the first declared)
    ->  (   ( How == move, cpp_copy_ctor(C, rref) -> Arg = move(EL) ; cpp_copy_ctor(C, ref) -> Arg = EL )   % C++'s implicit move out of a local, else its copy
        ->  T = base([], [typedef(C)]), cpp_ctor(C, [Arg], CName), ccl_gensym('$ret', Tmp),
            E2 = stmt_expr(block([declaration(L, none, T, [var(Tmp, T, none)]), expr(L, call(id(CName), [addr(id(Tmp)), EL])), expr(L, id(Tmp))]))
        ;   cpp_refuse(L, return_of_a_class_with_destructor(C)) )
    ;   nb_getval('$cpp_ret', Ret), Ret \== none, cpp_class_of_type(Ret, C), cpp_class_of_type_of(E1, C1), C1 \== C, cpp_class_fits(C1, C)   % A DERIVED OBJECT RETURNED AS ITS BASE is its base sub-object, sliced as an assignment slices it (0.197): `M h() { D d; return d; }' stored the D as an M, which LLVM refused
    ->  E2 = deref(cast(ptr([], base([], [typedef(C)])), addr(E1)))
    ;   E2 = E1 ).
cpp_stmt_(Ctx, label(L, N, S), label(L, N, S1)) :- !, cpp_stmt(Ctx, S, S1).
cpp_stmt_(Ctx, switch(L, E, S), switch(L, E1, S1)) :- !, cpp_expr(Ctx, E, E1), cpp_stmt(Ctx, S, S1).
cpp_stmt_(Ctx, case(L, E, S), case(L, E2, S1)) :- !, cpp_expr(Ctx, E, E1),   % A CASE LABEL IS A CONSTANT EXPRESSION, desugared and folded as any (0.112): libc++ 18's `case __format_spec::__type::__default:' reached the lowering raw
    ( catch(cpp_const_value(E1, K), _, fail), integer(K) -> E2 = int(K) ; E2 = E1 ), cpp_stmt(Ctx, S, S1).
cpp_stmt_(Ctx, default(L, S), default(L, S1)) :- !, cpp_stmt(Ctx, S, S1).
cpp_stmt_(Ctx, static_assert(L, E, M), static_assert(L, E, M)) :- !, cpp_static_assert(Ctx, L, E, M).
cpp_stmt_(_, S, S).
cpp_asm_ops(_, [], []).
cpp_asm_ops(Ctx, [op(N, C, E)|Os], [op(N, C, E1)|Os1]) :- cpp_expr(Ctx, E, E1), cpp_asm_ops(Ctx, Os, Os1).
%% A C++ STATIC ASSERTION IS CHECKED (0.198; [dcl.pre]/10): the program's own, where its condition folds -- at file scope, in a block and in
%% an instance's body, which a discarded `if constexpr' branch never is (P2593: `static_assert(false)' there is no error). It was read
%% and never asked: `static_assert(sizeof(int) == 8);' compiled. ... AND A LIBRARY HEADER'S TOO (0.221; [temp.inst]/3, /11: an
%% instance's static assertions are asked where it is made), where its condition folds to false, the header's line no line of the
%% program's file: `std::get<5>' of a `std::array<int, 3>' read past the array's end where clang++ says "Index out of bounds in
%% std::get<> (std::array)", and `std::optional<int &>', `std::variant<int, void>' and libc++ 21's `std::vector<const int>' compiled.
%% They were trusted, never asked. An instance made in an unevaluated walk (cpp_unevaluated/1: a decltype, a noexcept operand)
%% asks none of the library's ([temp.inst]/5: a function's definition is instantiated where it is odr-used, and an unevaluated
%% operand odr-uses nothing), as its body is made there: `std::declval<_Tp>()' of `decltype(...)' met its guard, "std::declval
%% can only be used in an unevaluated context", and refused `std::vector<const int>' over libc++ 18, which clang++ takes
cpp_static_assert(Ctx, L, E, M) :- ( nb_getval('$cpp_in_lib', no) -> true ; \+ nb_current('$cpp_uneval', yes) ),
    catch(( cpp_expr(Ctx, E, E1), cpp_const_bool(E1, V) ), _, fail), V == false, !,
    ( ( M == none ; M = str(_) ) -> ccl_assert_text(M, Text) ; Text = '' ),
    ( nb_getval('$cpp_in_lib', no) -> L1 = L, ( '$cpp_assert_failed'(_, _) -> true ; assertz('$cpp_assert_failed'(Text, L1)) ) ; L1 = 0 ),
    throw(error(static_assert_failed(Text), here(none, L1))).
cpp_static_assert(_, _, _, _).
%% A STRUCTURED BINDING PACK (C++26, [dcl.struct.bind]/1, P1061; 0.198): `auto [a, ...xs, z] = e' -- the pack is the elements the other
%% names leave, each a binding of its own, `xs$1' ... `xs$k'; the statements after the declaration name xs as the pack of them, a
%% parameter pack's way (cpp_stmts, over '$cpp_bindpack': a fold, `sizeof...(xs)', an expansion `f(xs...)', `xs...[I]')
cpp_binding_names(L, T, Ns0, Ns) :- append(Pre, [pack(X)|Post], Ns0), !,
    ( cpp_binding_count(T, K0) -> true ; cpp_refuse(L, bindings_of(T)) ),
    length(Pre, K1), length(Post, K2), KP is K0 - K1 - K2, ( KP >= 0 -> true ; cpp_refuse(L, bindings_count(K0)) ),
    findall(XN, ( between(1, KP, I), atomic_list_concat([X, '$', I], XN) ), XNs), findall(id(XN), member(XN, XNs), Ids),
    append([Pre, XNs, Post], Ns), nb_setval('$cpp_bindpack', [X-vpack(Ids)]).
cpp_binding_names(_, _, Ns, Ns).
cpp_binding_count(T, K) :- cpp_tuple_size(T, K), !.
cpp_binding_count(T, K) :- cpp_class_of_type(T, C), !, cpp_class_l(C, cls(_, Data, _, _, _)), findall(M, ( member(member(_, M, _), Data), M \== '$base', M \== '$vptr' ), Ms), length(Ms, K).
cpp_binding_count(T, K) :- ccl_resolve_type(T, base(_, [struct(_, SMs)])), findall(M, member(member(_, M, _), SMs), Ms), length(Ms, K).
%% THE TUPLE PROTOCOL ([dcl.struct.bind]/4): where `std::tuple_size<E>::value' is a constant, THAT many bindings
%% are asked for and each is `get<i>(e)', a reference to what the get answers -- a tuple keeps its elements in its
%% BASES (one `__tuple_leaf' per element) and has no data member of its own, so the member road found none and
%% refused bindings_count. An E that is no tuple simply has no such constant, and the member road stands.
cpp_tuple_size(T, K) :- cpp_class_of_type(T, _), once(catch(cpp_tuple_size_(T, K), _, fail)).
%% ... AND ITS `get' IS FOUND BY ARGUMENT-DEPENDENT LOOKUP ([dcl.struct.bind]/4; 0.132), in the namespace of E's class,
%% which the flattening keys apart where it collides: `subrange''s `get' is libc++'s `ranges.get', and `auto [__begin,
%% __end] = ranges::search(...)' in split_view's `__find_next' found only std's 44 overloads (deduction_failed(tuple))
cpp_binding_get(T, G) :- cpp_class_of_type(T, C), !, cpp_adl_fn(C, get, G).
cpp_binding_get(_, get).
cpp_tuple_size_(T, K) :- cpp_template(tuple_size, _, _), cpp_instantiate_class(tuple_size, [T], C), cpp_static_const(C, value, V), ccl_const_eval(V, K).
cpp_binding_vt(MT, _, ref([], base([], [auto]))) :- ( MT = ref(_, _) ; MT = rref(_, _) ), !.
cpp_binding_vt(_, VT, VT).
cpp_coro_ret(return(L, E), coro_ret(L, E)) :- !.
cpp_coro_ret(block(Ss0), block(Ss)) :- append(Front, [Last0], Ss0), cpp_coro_ret(Last0, Last), !, append(Front, [Last], Ss).
cpp_promise_class(C) :- ccl_declared('$promise', T), cpp_class_of_type(T, C).
%% the body is a coroutine's when it holds one of the three forms outside a lambda
cpp_has_coro(T) :- compound(T), \+ T = lambda(_, _, _, _), ( ( T = co_return(_, _) ; T = co_await(_) ; T = co_yield(_) ) -> true ; T =.. [_|As], member(A, As), cpp_has_coro(A) ), !.
cpp_coro_skeleton(_, _, Body, Body) :- \+ cpp_has_coro(Body), !.
cpp_coro_skeleton(Ret, Params, block(Ss), block(Sk)) :- ( cpp_promise_type(Ret, Params, PT) -> true ; cpp_refuse(0, coroutine_result(Ret)) ),
    ( Ss = [S1|_], arg(1, S1, L), integer(L) -> true ; L = 0 ), P = id('$promise'), append(Ss, [coro_falloff(L)], Ss2),
    cpp_promise_init(PT, Params, Init), cpp_coro_guard(L, P, block(Ss2), Guarded),
    findall(A, ( member(Pm, Params), cpp_coro_param_arg(Pm, A) ), AllocArgs),
    Sk = [coro_promise(L, PT, Init), coro_begin(L, '$promise', AllocArgs),
          coro_ret(L, call(member(P, get_return_object), [])),
          expr(L, co_await_raw(call(member(P, initial_suspend), []), initial)),
          coro_body(L, Guarded),
          expr(L, co_await_raw(call(member(P, final_suspend), []), final)),
          coro_done(L)].
%% THE PROMISE TYPE ([dcl.fct.def.coroutine]/4; 0.110): `std::coroutine_traits<R, P1, ..., Pn>::promise_type', the
%% implicit object parameter first for a method, as an lvalue reference -- asked through the traits where the program
%% specializes them (their primary is `R::promise_type' anyway, so a program that does not is served the short way)
cpp_promise_type(Ret, Params, base([], [typedef(scoped([std, tmpl(coroutine_traits, [Ret|Ts])], promise_type))])) :-
    '$cpp_spec'(coroutine_traits, _, _, _), !, findall(T, ( member(P, Params), cpp_coro_param_type(P, T) ), Ts).
cpp_promise_type(Ret, _, PT) :- cpp_promise_type(Ret, PT).
cpp_promise_type(base(_, [typedef(scoped(Path, N))]), base([], [typedef(scoped(Path1, promise_type))])) :- !, append(Path, [N], Path1).
cpp_promise_type(base(_, [typedef(X)]), base([], [typedef(scoped([X], promise_type))])).
cpp_coro_param_type(param(ptr(Q, T), this), ref(Q1, T)) :- !, ( T = base(Q0, _), memberchk(const, Q0) -> Q1 = Q ; Q1 = Q ).
cpp_coro_param_type(param(T, _), T).
cpp_coro_param_type(param(T, _, _), T).
%% THE PROMISE IS CONSTRUCTED FROM THE PARAMETERS where it has a constructor taking them all ([dcl.fct.def.coroutine]/5)
cpp_promise_init(PT, Params, ctor(Args)) :- Params \== [], catch(cpp_type(PT, T), _, fail), cpp_class_of_type(T, C),
    length(Params, N), cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, CPs, _, _), Ms), length(CPs, N), !,
    findall(A, ( member(P, Params), cpp_coro_param_arg(P, A) ), Args).
cpp_promise_init(_, _, none).
cpp_coro_param_arg(param(_, this), deref(this)) :- !.
cpp_coro_param_arg(P, id(N)) :- arg(2, P, N).
%% AN EXCEPTION OUT OF THE BODY IS THE PROMISE'S ([dcl.fct.def.coroutine]/5: `try { body } catch (...) {
%% promise.unhandled_exception(); }'), where the program throws at all (0.110; its own throws are the only ones)
cpp_coro_guard(L, P, B, block([try(L, B, [catch(any, block([expr(L, call(member(P, unhandled_exception), []))]))])])) :-
    nb_current('$cpp_throws', yes), !.
cpp_coro_guard(_, _, B, B).
%% THE COROUTINE STATE'S ALLOCATION ([dcl.fct.def.coroutine]/9, /10; 0.202; `_Znwm' alone before): the promise type's `operator new', its own or a
%% base's, over the frame's size (`coro_size') and the coroutine's parameters as lvalues, else over the size alone; else the global one, the
%% nothrow form where the promise has `get_return_object_on_allocation_failure' -- whose call the ramp returns where the allocation answers null
cpp_coro_alloc(Ctx, L, As, A, F) :- ( cpp_promise_class(PC) -> true ; PC = none ),
    ( PC \== none, cpp_has_member(PC, get_return_object_on_allocation_failure) -> NT = yes ; NT = no ),
    (   PC \== none, cpp_alloc_owner(PC, new, _), member(Args, [[coro_size|As], [coro_size]]), catch(cpp_call(none, scoped([PC], operator(new)), Args, A0), _, fail), A0 = call(id(Name), _), cpp_alloc_method(PC, new, Name, _, _) -> cpp_copies(A0, A)
    ;   NT == yes, catch(cpp_expr(none, scoped([std], nothrow), NTE), _, fail) -> A = call(id('_ZnwmRKSt9nothrow_t'), [coro_size, NTE])
    ;   A = call(id('_Znwm'), [coro_size]) ), !,
    ( NT == yes -> cpp_stmt(Ctx, return(L, call(scoped([PC], get_return_object_on_allocation_failure), [])), F) ; F = none ).
%% ... AND ITS DEALLOCATION ([dcl.fct.def.coroutine]/12): the promise type's usual `operator delete', the one that takes the size where it has both,
%% else the global one, sized (`_ZdlPv' before)
cpp_coro_dealloc(D) :- cpp_promise_class(PC), cpp_alloc_owner(PC, delete, O), cpp_class(O, cls(_, _, Ms, _, _, _)),
    findall(Sh-(Qs-Ps), ( member(method(_, Qs, _, operator(delete), Ps, _, _), Ms), cpp_alloc_shape(Ps, Sh), memberchk(Sh, [[ptr], [ptr, size]]) ), Us), Us \== [],
    ( memberchk([ptr, size]-(Qs-Ps), Us) -> Rest = [coro_size] ; memberchk([ptr]-(Qs-Ps), Us), Rest = [] ), !,
    cpp_mangle_q(O, operator(delete), Qs, Ps, Name), D = call(id(Name), [nullptr, coro_mem|Rest]).
cpp_coro_dealloc(call(id('_ZdlPvm'), [coro_mem, coro_size])).
%% an awaiter named by an lvalue is awaited where it is; a prvalue is kept for the suspension
cpp_coro_lvalue(E) :- ( E = id(_) ; E = member(_, _) ; E = arrow(_, _) ; E = deref(_) ; E = index(_, _) ), !.
cpp_coro_operand(E, call(member(id('$promise'), await_transform), [E])) :- cpp_promise_class(C), cpp_has_member(C, await_transform), !.
cpp_coro_operand(E, E).
cpp_catches(_, [], []).
cpp_catches(Ctx, [catch(K, B)|Cs], [catch(K, B1)|Cs1]) :- ( K == any ; K == terminate ), !, cpp_stmt(Ctx, B, B1), cpp_catches(Ctx, Cs, Cs1).
%% A CLASS CAUGHT BY VALUE IS A COPY ([except.handle]/15; 0.110): the handler's parameter is copy-initialized from the
%% exception object -- a hidden reference binds the object, the named parameter is a local copied from it at the
%% handler's head and destroyed at its end, before __cxa_end_catch destroys the object itself
cpp_catches(Ctx, [catch(P, B)|Cs], Out) :- ( P = param(T0, N) ; P = param(T0, N, _) ), N \== anon, T0 \= ref(_, _), T0 \= rref(_, _),
    catch(cpp_type(T0, T), _, fail), cpp_class_of_type(T, C), cpp_has_ctors(C), !,
    ccl_gensym('$exref', X), ( B = block([S1|_]), arg(1, S1, L), integer(L) -> true ; L = 0 ),
    cpp_catches(Ctx, [catch(param(ref([], T0), X), block([declaration(L, none, T0, [var(N, T0, id(X))]), B]))|Cs], Out).
cpp_catches(Ctx, [catch(P, B)|Cs], [catch(R, T, N, B1)|Cs1]) :-
    ( P = param(T0, N) -> true ; P = param(T0, N, _) ), cpp_type(T0, T), cpp_rtti_of_type(T, R),
    cpp_in_frame(( ( N == anon -> true ; ccl_declare(N, T) ), cpp_stmt(Ctx, B, B1) )), cpp_catches(Ctx, Cs, Cs1).
%% A CLASS VALUE WHERE A BOOL IS WANTED -- an if, a loop's test, `!x', the operands of && and || -- converts through its
%% `operator bool' (explicit or not: these are the contextual conversions C++ allows it), which is how a stream's
%% sentry says whether the stream is good: `if (__s)'. Compared with zero as a struct, LLVM refused the icmp.
cpp_to_bool(E, call(id(Name), [Obj])) :- cpp_class_of_type_of(E, C), cpp_method(C, operator(conv(base(_, [bool]))), [], Name, Hops), !, cpp_hops(E, Hops, B), cpp_object_arg(Name, addr(B), Obj).
cpp_to_bool(E, E).
%% A CLASS VALUE WHERE A SCALAR IS WANTED converts through its CONVERSION OPERATOR -- fpos's `operator streamoff()',
%% which is what `streamoff off = cin.tellg()' and `cout << cout.tellp()' are; an explicit one converts only where
%% the context does (cpp_to_bool). In a declaration, an argument (cpp_ref_args_), a cast; scored as exact after
%% the conversion (2) where the operator's result is the parameter's type, else 1 (cpp_arg_fit_), so
%% `operator<<(long)' takes a streamoff over `operator<<(bool)'.
cpp_conv_to(E, T, E1) :- cpp_conv_to(implicit, E, T, E1).
cpp_conv_to(How, E, T0, E1) :- cpp_conv_target(T0, T), ( cpp_class_of_type(T, TC) -> cpp_class_of_type_of(E, C), C \== TC ; cpp_class_of_type_of(E, C) ), cpp_conv_op(How, C, T, Name, Hops), !, cpp_conv_object(E, E2, Pre), cpp_hops(E2, Hops, B), cpp_object_arg(Name, addr(B), Obj), cpp_conv_wrap(Pre, call(id(Name), [Obj]), E1).   % a scalar wanted, or ANOTHER class (0.79): the operator's result is the value
%% ... AND A REFERENCE TARGET IS LOOKED THROUGH, ITS TOP-LEVEL QUALIFIERS WITH IT ([dcl.init.ref]/5,
%% [over.ics.user]: the operator makes a PRVALUE and the reference binds to it, so neither the reference
%% nor the `const' on it is the conversion's business). THE SCORER AND THE EMITTER DISAGREED: `cpp_arg_fit_'
%% unrefs the parameter before it asks (`ccl_unref') and so looks through `const Yards &' -- and then
%% `cpp_ref_args_' handed `cpp_conv_to' the type AS WRITTEN, where `ccl_resolve_type' passes a `ref'
%% through unchanged and the type-level class test must not unref (0.51's rule, whose place is
%% `cpp_class_of_type_of'), so `cpp_conv_fits' had neither an arithmetic pair nor two pointers nor two
%% REGISTERED classes to compare -- a plain struct is no registered class -- and fell to `RT == RCT',
%% which the reference, and then the `const' under it, each defeat on their own. The overload chosen was
%% right and the argument went raw: `by_ref(f)' read Feet's bytes as Yards, and `std::string_view v = s;'
%% took string_view's COPY constructor over the string's own. Stripping HERE, at the emitter's one door,
%% leaves every SCORE where it was and only makes the emission agree with the choice.
cpp_conv_to(_, id(F), T0, id(Name)) :- atom(F), \+ cpp_local(F), cpp_using_key(F, KF), cpp_fn_ready(KF), cpp_fn_overloaded(KF), cpp_fn_target(T0, fn(_, Ps1, _)),   % ... A KEYED SET THROUGH A USING OF ITS NAMESPACE (0.161): the key's overloads first, then the bare name's (below), the set C++ joins
    cpp_params_key(Ps1, K), '$cpp_fn'(KF, K, Ps, yes, _), !, cpp_fn_name(KF, Ps, yes, Name), cpp_use_fn(KF, Ps, Name).
cpp_conv_to(_, id(F), T0, id(Name)) :- atom(F), \+ cpp_local(F), cpp_fn_overloaded(F), cpp_fn_target(T0, fn(_, Ps1, _)),   % AN OVERLOAD SET NAMED AS A VALUE IS CHOSEN BY ITS TARGET ([over.over]; 0.99): `int (*pi)(int) = twice' beside `double twice(double)'
    cpp_params_key(Ps1, K), '$cpp_fn'(F, K, Ps, yes, _), !, cpp_fn_name(F, Ps, yes, Name), cpp_use_fn(F, Ps, Name).
cpp_conv_to(How, addr(id(F)), T0, addr(E)) :- atom(F), \+ cpp_local(F), cpp_fn_overloaded(F), cpp_conv_to(How, id(F), T0, E), E \== id(F), !.   % ... AND ITS ADDRESS, `&m' ([over.over]/1; 0.181): it was `undeclared(m)', the set's own name no function's
cpp_conv_to(_, '$memaddr'(C, N), T0, E) :- cpp_type_or_self(T0, T1), ccl_resolve_type(T1, memptr(_, _, F0)), ccl_resolve_type(F0, fn(_, Ps1, V1)), cpp_params_key(Ps1, K), cpp_fn_q(V1, _, TQs),   % AN OVERLOADED MEMBER'S ADDRESS IS CHOSEN BY ITS TARGET ([over.over]; 0.112): the overload whose parameters are the pointer's
    (   cpp_class_method(C, N, Qs, R0, Ps0, V0), cpp_method_mfq(Qs, MQs), cpp_mfq_fits(MQs, TQs), cpp_in_class(C, cpp_plain_params(Ps0, PsP)), cpp_params_key(PsP, K) -> true   % ... and whose qualifiers are the target's (0.181): `int (A::*pc)() const = &A::get' is the const `get'
    ;   cpp_class_method(C, N, Qs, R0, Ps0, V0), cpp_in_class(C, cpp_plain_params(Ps0, PsP)), cpp_params_key(PsP, K) ), !, cpp_method_address(C, N, m(Qs, R0, Ps0, V0), E).
cpp_conv_to(_, '$staticfn'(C, N), T0, id(Thunk)) :- cpp_fn_target(T0, fn(_, Ps1, _)), cpp_params_key(Ps1, K),   % SEVERAL STATIC FUNCTIONS OF ONE NAME NAMED AS A VALUE: the target's parameters choose ([over.over]; 0.126, cpp_static_fn_value)
    cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, Qs, _, N, Ps0, _, _), Ms), memberchk(static, Qs), cpp_in_class(C, cpp_plain_params(Ps0, PsP)), cpp_params_key(PsP, K), !,
    cpp_mangle_q(C, N, Qs, Ps0, Name), cpp_static_thunk(C, N, Name, Thunk).
cpp_conv_to(_, E, T0, addr(id(Inv))) :- cpp_class_of_type_of(E, C), cpp_generic_closure(C), cpp_fn_target(T0, fn(R, Ps1, V)), !, cpp_generic_invoker(C, R, Ps1, V, Inv).
cpp_conv_to(_, E, _, E).
%% A CLASS PRVALUE CONVERTED THROUGH ITS CONVERSION FUNCTION IS A TEMPORARY OF THE STATEMENT ([class.temporary]/2 and /4; 0.206):
%% the function is called on it, and it is destroyed at the end of the full-expression. `c_api_make(std::out_ptr(up))' called
%% `operator int **' on a copy of the `out_ptr_t' the call returned and destroyed none, so the pointer the C function wrote into
%% it never reached `up'. Outside a statement walk (no register of temporaries) the prvalue is converted as it was.
cpp_conv_object(E, id(Tmp), [expr(0, assign('=', id(Tmp), E))]) :- cpp_dtor_prvalue(E, T, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts), !,
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts]).
cpp_conv_object(E, E, []).
cpp_conv_wrap([], X, X) :- !.
cpp_conv_wrap(Pre, X, stmt_expr(block(Ss))) :- append(Pre, [expr(0, X)], Ss).
%% A CAPTURELESS GENERIC LAMBDA CONVERTS TO A POINTER TO FUNCTION too ([expr.prim.lambda.closure]/9: its closure has a
%% conversion function TEMPLATE whose arguments the target deduces; 0.112, where only a non-generic one had the
%% conversion and the closure's struct was handed on as the pointer): an invoker per closure and target,
%% `lambda.K.fn.<keys>', calls the closure's operator() over the target's parameters, so the member template is
%% instantiated by that call as any is, and the invoker's address is the value
cpp_generic_closure(C) :- cpp_closure_class(C), cpp_class(C, cls(_, [], Ms, _, _, _)), member(template(_, _, method(_, Qs, _, operator('()'), Ps, _, _)), Ms), memberchk(closure, Qs), \+ member(param(this(_), _), Ps), !.
cpp_generic_invoker(C, R, Ps1, V, Inv) :-
    cpp_params_key(Ps1, K), atomic_list_concat([C, '.fn.', K], Inv), nb_getval('$cpp_gen_invs', Done),
    (   memberchk(Inv, Done) -> true
    ;   nb_setval('$cpp_gen_invs', [Inv|Done]), cpp_thunk_params(Ps1, 1, IPs, Args),
        Call = call(compound_lit(base([], [typedef(C)]), init([])), Args),
        ( ccl_resolve_type(R, base(_, [void])) -> B0 = block([expr(0, Call)]) ; B0 = block([return(0, Call)]) ),
        cpp_isolated(( ccl_declare(Inv, fn(R, IPs, V)), cpp_method_body(none, R, IPs, B0, B1) )),
        cpp_add_instance_items([function(0, static, R, Inv, IPs, V, B1)]) ).
cpp_conv_target(T0, T) :- cpp_unref_all(T0, T1), cpp_strip_quals(T1, _, T).
%% a CAST is direct-initialization: an explicit conversion operator applies, and a cast to bool is the contextual one
%% (`(bool) cin' is basic_ios's `explicit operator bool()')
cpp_cast_to(E, T, E1) :- ccl_resolve_type(T, base(_, [bool])), cpp_class_of_type_of(E, _), !, cpp_to_bool(E, E1).
cpp_cast_to(E, T, E1) :- cpp_class_of_type(T, C), \+ cpp_class_of_type_of(E, C), ccl_type_of(E, AT), AT \== unknown, cpp_converting_ctor(C, E), !, cpp_temporary(T, C, [E], E1).   % A CAST TO A CLASS IS ITS CONVERTING CONSTRUCTOR ([expr.static.cast]/4, direct-initialization): optional's `value_or' returns `static_cast<value_type>(std::forward<_Up>(__v))', a string from a `const char *', which the lowering met as a pointer cast to a struct
%% A CAST OF A GLVALUE TO ITS OWN CLASS, OR TO A BASE, IS A TEMPORARY DIRECT-INITIALIZED FROM IT ([expr.static.cast]/4; 0.201): `static_cast<R>(
%% std::forward<A>(a))', `static_cast<R>(std::move(s))', `(R) r' -- the move constructor for an xvalue, the copy one for an lvalue --, where
%% the cast was the value itself: libc++'s _LIBCPP_AUTO_CAST over an argument pack copied a move-only value, and `R t = static_cast<R>(
%% std::move(s));' was refused `move of a non-owner'. A prvalue of the class stays itself, the result object initialized from it.
cpp_cast_to(E, T, E1) :- cpp_class_of_type(T, C), cpp_ret_constructs(C), cpp_class_of_type_of(E, D), ( D == C -> true ; cpp_derives(D, C) ), cpp_glvalue_arg(E), !, cpp_temporary(T, C, [E], E1).
cpp_cast_to(E, T, E1) :- cpp_conv_to(explicit, E, T, E1).
cpp_glvalue_arg(move(_)) :- !.
cpp_glvalue_arg(E) :- cpp_xvalue_object(E), !.
cpp_glvalue_arg(E) :- cpp_arg_lvalue(E).
cpp_cast_made(T, X1, X2) :- X2 \== X1, X2 = stmt_expr(_), cpp_class_of_type(T, _).   % a cast to a class that MADE its prvalue is that prvalue, which the elisions see (0.201)
cpp_conv_op(How, C, T, Name, Hops) :- ccl_resolve_type(T, RT), cpp_conv_member(How, C, RT, CT0, _), cpp_method(C, operator(conv(CT0)), [], Name, Hops), !.
cpp_conv_result(C, T, RCT) :- ccl_resolve_type(T, RT), cpp_conv_member(implicit, C, RT, _, RCT), !.
%% THE CONVERSION FUNCTION WHOSE RESULT IS THE TARGET ITSELF comes first ([over.match.conv], [over.ics.rank]/3.3: the identity beats a
%% standard conversion of the result): a class with `operator int()' and `operator long()' (`operator T()' of S<long>) converts to a
%% `long' through the second, where the first declared served every arithmetic target (0.117: S<long>'s `long t = s;' gave `operator
%% int')
cpp_conv_member(How, C, RT, CT0, RCT) :- cpp_conv_member_(exact, How, C, RT, CT0, RCT), !.
cpp_conv_member(How, C, RT, CT0, RCT) :- cpp_conv_member_(fits, How, C, RT, CT0, RCT), !.
cpp_conv_member_(Mode, How, C, RT, CT0, RCT) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, Qs, _, operator(conv(CT0)), [], _, _), Ms), ( How == explicit -> true ; \+ cpp_is_explicit(C, Qs) ),
    cpp_in_class(C, cpp_type_or_self(CT0, CT)), ccl_resolve_type(CT, RCT0), cpp_conv_result_type(RCT0, RCT), cpp_conv_mode(Mode, RT, RCT).
cpp_conv_member_(Mode, How, C, RT, CT0, RCT) :- cpp_base_scope(C, B), cpp_conv_member_(Mode, How, B, RT, CT0, RCT).
%% A CONVERSION FUNCTION THAT YIELDS A REFERENCE is a candidate for the referent's type ([over.match.ref]/1.1, [over.match.conv]):
%% libc++'s `reference_wrapper<T>::operator T &()' where a `T &', a T or a base of T is wanted. The result's reference was
%% kept, and neither `cpp_bare_type' nor `cpp_conv_fits' looks through one, so `bump(std::ref(c), 3)' over `void bump(Counter &, int)'
%% passed the WRAPPER's address as the Counter (0.117; std::thread's `std::ref' argument ran the callee on the tuple's bytes)
cpp_conv_result_type(T0, T) :- ( ( T0 = ref(_, X) ; T0 = rref(_, X) ) -> ccl_resolve_type(X, T) ; T = T0 ).
cpp_conv_mode(exact, RT, RCT) :- catch(( cpp_bare_type(RT, B1), cpp_bare_type(RCT, B2) ), _, fail), B1 == B2.
cpp_conv_mode(fits, RT, RCT) :- cpp_conv_fits(RT, RCT).
cpp_conv_fits(RT, RCT) :- ( ccl_is_arith(RT), ccl_is_arith(RCT) -> true ; RCT = ptr(_, fn(_, _, _)) -> RT = ptr(_, FT1), FT1 = fn(_, _, _), RCT = ptr(_, FT2), cpp_fn_types_agree(FT1, FT2) ; RT = ptr(_, _), RCT = ptr(_, _) -> true ; cpp_class_of_type(RT, C1), cpp_class_of_type(RCT, C2) -> C1 == C2 ; RT == RCT ).   % ... or a CLASS: basic_string's `operator basic_string_view()' where a string_view is wanted (`compare(__self_view(__str))'); a POINTER TO FUNCTION converts to that function type and no other (a captureless closure's, 0.112)
%% THE BEGIN AND END OF A RANGE ([stmt.ranged]/1.3): the class's members where it declares both, else the free `begin(range)'
%% and `end(range)' that ARGUMENT-DEPENDENT LOOKUP finds in the namespace of the range's class (0.134; cpp_adl_fn) -- libc++'s
%% `std::filesystem::begin(directory_iterator)' and `end(directory_iterator)', the only begin and end a directory iterator
%% has; `for (const auto &e : fs::directory_iterator(d))' fell to the raw range-for, which the safe part refused (`not_checked')
cpp_range_class(R, C) :- catch(cpp_class_of_type_of(R, C), _, fail), !.
cpp_range_class(R, C) :- catch(cpp_arg_type(R, T), _, fail), ccl_unref(T, T1), ccl_resolve_type(T1, base(_, [struct(C, _)])), atom(C), C \== anon.   % a PLAIN struct is a range too, by the free functions of its namespace
cpp_range_ends(C, member) :- catch(( cpp_method(C, begin, [], _, _), cpp_method(C, end, [], _, _) ), _, fail), !.
cpp_range_ends(C, free(BF, EF)) :- \+ catch(( cpp_has_member(C, begin), cpp_has_member(C, end) ), _, fail),
    cpp_adl_fn(C, begin, BF), cpp_adl_fn(C, end, EF), cpp_free_callable(BF), cpp_free_callable(EF).
cpp_range_call(member, F, Range, call(member(Range, F), [])).
cpp_range_call(free(BF, _), begin, Range, call(id(BF), [Range])).
cpp_range_call(free(_, EF), end, Range, call(id(EF), [Range])).
cpp_free_callable(F) :- ( catch(cpp_fn_ready(F), _, fail) -> true ; catch(cpp_template(F, _, _), _, fail) ), !.
%% A FREE FUNCTION FOUND BY ARGUMENT-DEPENDENT LOOKUP ([basic.lookup.argdep]): F in the namespace of the class C (of its template,
%% for an instance), which the flattening keys apart where the name collides (cpp_ns_key: `filesystem.begin', `ranges.get'),
%% else the bare name
cpp_adl_fn(C, F, G) :- ( '$cpp_inst'(C, inst(N, _)) -> true ; N = C ), atom(N), ( catch(cpp_hdr_ns(N, P), _, fail) ; catch('$cpp_own_ns'(N, P), _, fail) ), is_list(P), catch(cpp_ns_key(P, F, G0), _, fail), !, G = G0.   % a header's namespace, or the program's own (cpp_ns_resolve)
cpp_adl_fn(_, F, F).
cpp_range_type(base(_, [auto]), ET, ET) :- !.
cpp_range_type(ref(Q, base(_, [auto])), ET, ref(Q, ET)) :- !.
cpp_range_type(rref(Q, base(_, [auto])), ET, ref(Q, ET)) :- !.
cpp_range_type(T, _, T).
cpp_lvalue(id(_)).
cpp_lvalue(call(id(F), _)) :- atom(F), ccl_declared(F, fn(R, _, _)), R = ref(_, _).   % a call returning an lvalue REFERENCE is an lvalue: `cout << a << b' hands the first insertion's result on as one
cpp_lvalue(member(_, _)).
cpp_lvalue(ccast(_, ref(_, _), _)).                                       % a cast to an lvalue reference is an lvalue (`const_cast<T &>(x)'); to `T &&' an xvalue, which forwards as a temporary does
cpp_lvalue(arrow(_, _)).
cpp_lvalue(deref(_)).
cpp_lvalue(index(_, _)).
cpp_lvalue(stmt_expr(block(Ss))) :- append(_, [expr(_, E)], Ss), E = call(_, _), cpp_lvalue(E).   % A CALL MADE IN A STATEMENT EXPRESSION is the call's value category (0.132): a lambda called where it is made is its closure's temporary, then the call; never the block's last NAME, which is a temporary the block built (a prvalue)
cpp_lvalue(cond(_, A, B)) :- cpp_lvalue(A), cpp_lvalue(B).   % A CONDITIONAL OF TWO LVALUES IS AN LVALUE ([expr.cond]/4; 0.201): `const T &r = c ? a : b;' and a copy constructor over it take the arm's object, never a temporary of it (the lowering's address phi, ir_lval/4 of a conditional)
cpp_xvalue_object(move(_)).
cpp_xvalue_object(call(scoped(_, move), _)).
cpp_xvalue_object(ccast(_, rref(_, _), _)).
cpp_xvalue_object(X) :- cpp_xvalue_call(X).
cpp_xvalue_object(member(X, _)) :- cpp_xvalue_object(X).
cpp_stmts(_, [], []).
%% A TYPEDEF IN A BLOCK IS SUBSTITUTED INTO THE STATEMENTS THAT FOLLOW IT, as a template's parameter already is.
%% libc++ writes `using _ValueType = typename iterator_traits<_ContiguousIterator>::value_type;' inside
%% __uninitialized_allocator_relocate and names _ValueType in the lines below -- and the typedef TABLE is one per
%% unit, so half a dozen functions each declaring their own `_ValueType' leave one entry, another function's, whose
%% own parameter is free: `__libcpp_is_trivially_relocatable<_ValueType>' was then keyed by the unresolved NAME.
%% Substituted away, the name is gone and every later use is the concrete type this instance resolved it to.
cpp_stmts(Ctx, [typedef(L, Vs)|Ss], Ts) :- !,
    cpp_where(stmt(typedef, L), cpp_vars(none, Vs, Vs1)),
    cpp_block_typedefs(Vs1, B), ( B == [] -> Ss1 = Ss ; cpp_subst(Ss, B, Ss1) ),
    cpp_scoped_typedefs(Vs1, cpp_stmts(Ctx, Ss1, Ts)).
%% A USING-DECLARATION IN A BLOCK that names a class of a namespace whose items were indexed apart (cpp_ns_key) is that class under the short name for the
%% statements that follow (0.121), as a block typedef is: libc++ 18's std::visit opens with `using __variant_detail::__visitation::__variant;' and calls
%% `__variant::__visit_value(...)', where the bare name is `__access::__variant', another class.
cpp_stmts(Ctx, [using(L, U)|Ss], Ts) :- cpp_cplxlit_using(U, Sx), \+ cpp_cplxlit_covered(Sx), !, cpp_with_cplxlit(Sx, cpp_stmts(Ctx, [using(L, U)|Ss], Ts)).   % ... and in a BLOCK, to its end (0.179)
cpp_stmts(Ctx, [using(_, U)|Ss], Ts) :- cpp_relops_using(U, Ops), !, cpp_with_relops(Ops, cpp_stmts(Ctx, Ss, Ts)).   % std::rel_ops in a BLOCK (0.136): in force to the block's end
cpp_stmts(Ctx, [using(_, U)|Ss], Ts) :- cpp_hdr_using(U, Us), !, cpp_with_usings(Us, cpp_stmts(Ctx, Ss, Ts)).   % a header namespace's names in a BLOCK (0.160): in force to the block's end
cpp_stmts(Ctx, [using(_, name(scoped(Path, N)))|Ss], Ts) :- atom(N), cpp_ns_key(Path, N, K), K \== N, cpp_key_names_type(K), !,   % ... a CLASS's (0.201): a function's keyed name, libc++'s `using __adl_only::make_error_condition;' before the call that ADL answers, was made a type, and the call of it `typedef(...)'; such a using reaches the check and the lowering, which take it as nothing
    cpp_subst(Ss, [N-base([], [typedef(K)])], Ss1), cpp_stmts(Ctx, Ss1, Ts).
%% A LOCAL CLASS (0.121; [class.local]) -- one defined in a function body, named or not, with member functions or bases (a plain struct of data stays C's) -- is a
%% class of the unit under a name of its own, registered and emitted where the walk meets it as a closure's class is (cpp_lambda_), and the statements after it
%% name it by that name. Its name is unique (`Loc.local_7'), so two functions' `Loc' are two classes. libc++ 18's `variant' assigns an alternative through
%% `struct { void operator()(true_type) const {...} void operator()(false_type) const {...}; __assignment *__this; _Arg &&__arg; } __impl{this, std::forward<_Arg>(__arg)};'.
cpp_stmts(Ctx, [declare(L, base(_, [class(K, N, Bases, Ms)]))|Ss], Ts) :- atom(N), N \== anon, !,
    cpp_local_class(L, K, N, Bases, Ms, Name), cpp_tag_scoped_list(Ss, N, ['$deep'-yes, N-Name], Ss1), cpp_stmts(Ctx, Ss1, Ts).
%% A PLAIN LOCAL STRUCT OR UNION (0.201; [class.local]) is the unit's under a name of its own too: the table holds one tag a name, and two
%% functions' -- or two instances of one function template's -- `struct X { T a; char b; }' had one layout, the first met (`f<double>()'
%% read f<int>'s `sizeof(X)', a silent wrong answer; libc++ 18's std::expected asks `__fits_in_tail_padding<_First, _Second>', a lambda's
%% local struct, of each instance: `variable_template_not_constant'). It stays C's, its members' types resolved, named once per text as
%% the instance has it (`X.local_7_<tag>'); one that a member of class type promotes, a `std::string' among them, takes the local class
%% road, as a file-scope one is promoted (cpp_struct_promotes). The statements after it name it by its new name.
cpp_stmts(Ctx, [declare(L, base(Q, [S0]))|Ss], Ts) :- cpp_plain_local(S0, K, N, Ms0), \+ '$cpp_localst'(_, N), !,
    (   K == struct, cpp_struct_promotes(N, Ms0)
    ->  cpp_stmts(Ctx, [declare(L, base(Q, [class(struct, N, [], Ms0)]))|Ss], Ts)
    ;   cpp_plain_local_name(L, K, N, Ms0, Name, Ms), S =.. [K, Name, Ms], ccl_note_spec(S), cpp_tag_scoped_list(Ss, N, ['$deep'-yes, N-Name], Ss1),
        cpp_stmts(Ctx, [declare(L, base(Q, [S]))|Ss1], Ts) ).
%% AN UNNAMED PLAIN LOCAL STRUCT OR UNION OF THE PROGRAM'S (0.236; [class.local]) is a class of its own too: `struct { int z; } v;' in a
%% function is named where it is met, its variables' type that name, its type information its local name, `Z2nlvE3$_0' -- it was
%% `4anon', and two such structs of one text one type
cpp_stmts(Ctx, [declaration(L, Sto, base(Q, [S0]), Vs)|Ss], Ts) :- Vs \== [], cpp_unnamed_local(S0, K, Ms0), \+ nb_current('$cpp_in_lib', yes), !,
    cpp_unnamed_local_name(L, K, Ms0, Name, Ms), S =.. [K, Name, Ms], ccl_note_spec(S),
    cpp_subst_term(S0, S, declaration(L, Sto, base(Q, [S0]), Vs), D1), cpp_stmts(Ctx, [declare(L, base([], [S])), D1|Ss], Ts).
cpp_stmts(Ctx, [declaration(L, Sto, B, Vs)|Ss], Ts) :- B = base(_, [class(K, anon, Bases, Ms)]), !,
    cpp_local_class(L, K, anon, Bases, Ms, Name), cpp_subst_term(class(K, anon, Bases, Ms), typedef(Name), declaration(L, Sto, B, Vs), D1), cpp_stmts(Ctx, [D1|Ss], Ts).   % an UNNAMED class is the type of the declaration, its variables' types the same term
cpp_stmts(Ctx, [S|Ss], [S1|Ts]) :- S = bindings(L, _, Ns, _), memberchk(pack(_), Ns), !,   % a structured binding pack (0.198, cpp_binding_names): the statements after it name its elements
    nb_setval('$cpp_bindpack', none), cpp_where(stmt(bindings, L), cpp_stmt(Ctx, S, S1)), nb_getval('$cpp_bindpack', PB), nb_setval('$cpp_bindpack', none),
    ( PB == none -> Ss1 = Ss ; cpp_subst(Ss, PB, Ss1) ), cpp_stmts(Ctx, Ss1, Ts).
cpp_stmts(Ctx, [S|Ss], [S1|Ts]) :- ( S =.. [F, L|_], integer(L) -> W = stmt(F, L) ; W = stmt ), cpp_where(W, cpp_stmt(Ctx, S, S1)), cpp_stmts(Ctx, Ss, Ts).
cpp_block_typedefs([], []).
cpp_block_typedefs([var(N, T, _)|Vs], [N-T|B]) :- atom(N), !, cpp_block_typedefs(Vs, B).
cpp_block_typedefs([_|Vs], B) :- cpp_block_typedefs(Vs, B).
%% ... NOTED FOR THE STATEMENTS OF ITS BLOCK AND TAKEN BACK AT ITS END (0.127): the note was the unit's for the rest of the walk, and
%% every later function met `_Tp' as a known type
cpp_scoped_typedefs(Vs, Goal) :- ccl_note_typedefs(Vs), findall(N, ( member(var(N, _, _), Vs), atom(N) ), Ns),
    ( catch(Goal, E, ( cpp_unnote_typedefs(Ns), throw(E) )) -> cpp_unnote_typedefs(Ns) ; cpp_unnote_typedefs(Ns), fail ).
cpp_unnote_typedefs(Ns) :- forall(member(N, Ns), ccl_tab_del('$ccl_typedefs', N)), ccl_tables_changed.
%% std::rel_ops (0.136): `using namespace std::rel_ops;' (or `rel_ops' after `using namespace std;') puts all four operators in
%% force, `using std::rel_ops::operator>;' the one it names. The global '$cpp_relops' is `none', `all' or a list of operators.
cpp_relops_using(namespace(Q), all) :- cpp_relops_ns(Q), !.
cpp_relops_using(name(scoped(P, operator(Op))), [Op]) :- is_list(P), append(_, [rel_ops], P), memberchk(Op, ['!=', '>', '<=', '>=']), !.
cpp_relops_ns(rel_ops) :- !.
cpp_relops_ns(scoped(P, rel_ops)) :- is_list(P).
%% A USING OF A HEADER'S NAMESPACE DEEPER THAN std, OR OF ONE OF ITS FUNCTIONS OR OBJECTS (0.160; [namespace.udir], [namespace.udecl]):
%% namespaces flatten, and where two of them declare one name the deeper one's is keyed `<ns>.<name>' (cpp_ns_key), so a bare call
%% found the outer one alone -- `using namespace std::chrono; floor<seconds>(d)' met <cmath>'s floor, and `abs(d)' of a duration the
%% C library's. In force at namespace scope for the rest of the unit and in a block to its end ('$cpp_usings': `ns(Path)' for a
%% directive, `name(Path, N)' for a declaration), a bare call of a name keyed there takes the key first and the bare name's own road
%% if the key's candidates refuse, as a keyed qualified call does (cpp_call). `using namespace std;' brings nothing: std's names are
%% the outermost, the bare ones; a declaration of a CLASS keeps the block rule above.
cpp_hdr_using(namespace(Q), [ns(Segs)]) :- \+ cpp_relops_ns(Q), cpp_using_ns_segs(Q, Segs0), Segs0 \== [], ( Segs0 = [global|Segs] -> true ; Segs = Segs0 ), Segs \== [], Segs \== [std], !.
cpp_hdr_using(name(scoped(Path, N)), [name(Path, N)]) :- atom(N), is_list(Path), Path \== [], Path \== [std], cpp_ns_key(Path, N, K), K \== N,
    once(( cpp_hdr_item(K, I), ( cpp_fn_item(I, _) ; I = template(_, _, I2), cpp_fn_item(I2, _) ; I = declaration(_, _, _, [var(_, T, _)]), T \= fn(_, _, _) ) )), !.
cpp_with_usings(Us, Goal) :- ( nb_current('$cpp_usings', U0) -> true ; U0 = [] ), append(Us, U0, U1), nb_setval('$cpp_usings', U1),
    ( catch(Goal, E, ( nb_setval('$cpp_usings', U0), throw(E) )) -> nb_setval('$cpp_usings', U0) ; nb_setval('$cpp_usings', U0), fail ).
cpp_using_key(F, K) :- nb_current('$cpp_usings', Us), Us \== [], \+ nb_current('$cpp_in_lib', yes), \+ ( nb_current('$cpp_using_skip', Sk), memberchk(F, Sk) ),   % never inside a library's code, whose names the program's usings do not reach
    member(U, Us), ( U = ns(Path) ; U = name(Path, F) ), cpp_ns_key(Path, F, K), K \== F, \+ catch('$cpp_ns_own'(K), _, fail), !.   % a HEADER's key: the program's own namespaces are 0.139's renaming before the walk (cpp_using_map/4), and its usings must never redirect a name here (`nsusing.cpp': `a::f()' called b's f)
%% ... a header's keyed TYPE (0.161): `class' a class or an alias, `template' a class or alias template; `using std::ranges::less;' at namespace scope
cpp_hdr_type_using(name(scoped(Path, N)), [name(Path, N)]) :- atom(N), is_list(Path), Path \== [], Path \== [std], cpp_ns_key(Path, N, K), K \== N,
    once(( cpp_hdr_item(K, I), cpp_key_type_item(I, _) )), !.
cpp_using_type_key(N, Kind, K) :- cpp_using_key(N, K), once(( cpp_hdr_item(K, I), cpp_key_type_item(I, Kind) )).
cpp_key_type_item(declare(_, base(_, [S])), class) :- ( S = class(_, _, _, Ms) ; S = struct(_, Ms) ; S = union(_, Ms) ), Ms \== none, !.
cpp_key_type_item(typedef(_, _), class) :- !.
cpp_key_type_item(template(_, _, I), template) :- cpp_key_type_item(I, class).
cpp_key_names_type(K) :- ( once(( cpp_hdr_item(K, I), cpp_key_type_item(I, _) )) ; catch(cpp_class_l(K, _), _, fail) ; ccl_tag(K, _) ; ccl_typedef_of(K, _) ), !.
%% ... and its OBJECT or its one FUNCTION named as a value (0.161): `auto b = begin;' under `using namespace std::ranges;' is ranges::begin
cpp_using_value(K, id(G)) :- cpp_global_var(K, G), !.
cpp_using_value(K, id(Name)) :- cpp_lazy_fn_value(K, Name), !.
%% the bare name's own road, the key's having refused: the name is no more redirected while it is walked
cpp_without_using(F, Goal) :- ( nb_current('$cpp_using_skip', S0) -> true ; S0 = [] ), nb_setval('$cpp_using_skip', [F|S0]),
    ( catch(Goal, E, ( nb_setval('$cpp_using_skip', S0), throw(E) )) -> nb_setval('$cpp_using_skip', S0) ; nb_setval('$cpp_using_skip', S0), fail ).
cpp_relops_join(none, Ops, Ops) :- !.
cpp_relops_join(all, _, all) :- !.
cpp_relops_join(_, all, all) :- !.
cpp_relops_join(R0, Ops, R) :- append(R0, Ops, R1), sort(R1, R).
cpp_with_relops(Ops, Goal) :- nb_getval('$cpp_relops', R0), cpp_relops_join(R0, Ops, R), nb_setval('$cpp_relops', R),
    ( catch(Goal, E, ( nb_setval('$cpp_relops', R0), throw(E) )) -> nb_setval('$cpp_relops', R0) ; nb_setval('$cpp_relops', R0), fail ).
%% ... AND THE OPERATOR ROAD TAKES THEM (0.136): `a > b' of a class, a struct or a union with no operator of its own, while one
%% is in force and only in the program's own code (a library function's lookup finds its namespace's operators first and stops
%% there), through its template under its key: `rel_ops.op.gt.2', whose body is `__y < __x'. After the free operators, since
%% a library's own (`operator!=(const basic_string &, const basic_string &)') is more specialized than rel_ops's for any type it
%% takes, and before the rewritten candidates, which C++17 does not have.
cpp_relops_call(Op, A, [B], E) :- memberchk(Op, ['!=', '>', '<=', '>=']), nb_current('$cpp_relops', R), R \== none, ( R == all -> true ; memberchk(Op, R) ),
    nb_getval('$cpp_in_lib', no), ( cpp_op_operand(A) ; cpp_op_operand(B) ), cpp_op_word(Op, W), atomic_list_concat(['rel_ops.op.', W, '.2'], Name),
    catch(cpp_call(none, id(Name), [A, B], E), error(not_lowered(_), _), fail), E = call(id(F), _), atom(F), ccl_declared(F, fn(_, _, _)), !.
%% <complex>'S LITERAL OPERATORS MADE VISIBLE (0.179; [lex.ext]/1, [namespace.udir]): `3i', `2.0i', `1.5if' and `3il' call a literal
%% operator where unqualified lookup finds one, else they are GNU's imaginary literals, as clang reads them (cpp_udl_imag/3). libc++
%% declares `operator""i', `if' and `il' in std::literals::complex_literals, inline namespaces of std, so `using namespace std;', a
%% using-directive of `std::literals', `std::complex_literals' or `std::literals::complex_literals', or a using-declaration of the one
%% operator, makes them visible -- at namespace scope for the rest of the unit or of the namespace's block it stands in, in a block to
%% its end, as rel_ops's are ('$cpp_cplxlit':
%% `none', `all' or a list of suffixes). With `using namespace std::complex_literals;' the lexers' `2.0i' was a `_Complex double', and
%% `std::complex<double> z = 1.0 + 2.0i;' was refused (`no_member(real, ...)'); without one, a `_Complex' value stays the program's.
cpp_cplxlit_using(namespace(Q), all) :- cpp_using_ns_segs(Q, Segs0), ( Segs0 = [global|Segs] -> true ; Segs = Segs0 ), cpp_cplxlit_ns(Segs), !.
cpp_cplxlit_using(name(scoped(P, operator(literal(S)))), [S]) :- memberchk(S, [i, if, il]), is_list(P), last(P, N), memberchk(N, [std, literals, complex_literals]), !.
cpp_cplxlit_ns([std]).            cpp_cplxlit_ns([std, literals]).    cpp_cplxlit_ns([std, complex_literals]).
cpp_cplxlit_ns([std, literals, complex_literals]).                    cpp_cplxlit_ns([literals]).
cpp_cplxlit_ns([complex_literals]).                                    cpp_cplxlit_ns([literals, complex_literals]).
cpp_cplxlit_covered(Sx) :- nb_current('$cpp_cplxlit', C), ( C == all -> true ; Sx \== all, is_list(C), forall(member(S, Sx), memberchk(S, C)) ).
cpp_with_cplxlit(Sx, Goal) :- nb_getval('$cpp_cplxlit', C0), cpp_relops_join(C0, Sx, C), nb_setval('$cpp_cplxlit', C),
    ( catch(Goal, E, ( nb_setval('$cpp_cplxlit', C0), throw(E) )) -> nb_setval('$cpp_cplxlit', C0) ; nb_setval('$cpp_cplxlit', C0), fail ).
cpp_cplxlit_visible(S) :- nb_current('$cpp_cplxlit', C), ( C == all -> true ; is_list(C), memberchk(S, C) ), !.
%% ... ELSE GNU'S IMAGINARY LITERAL, as the lexers made it before C++14's <complex> took the suffixes: `3i' a `_Complex int' (a long
%% where the value needs it), `3il' a `_Complex long', `2.0i' a `_Complex double', `1.5if' a `_Complex float', `1.0il' a `_Complex long
%% double', its text kept; `3if' a `_Complex int', the `f' dropped, as clang reads it
cpp_udl_imag(i, int(N), imagi(Sp, N)) :- !, ccl_imag_specs(imagi, N, Sp).
cpp_udl_imag(if, int(N), imagi(Sp, N)) :- !, ccl_imag_specs(imagi, N, Sp).
cpp_udl_imag(il, int(N), imagi(Sp, N)) :- !, ccl_imag_specs(imagli, N, Sp).
cpp_udl_imag(i, ldbl(A), imag(F)) :- !, cpp_text_double(A, F).
cpp_udl_imag(if, ldbl(A), imagf(F)) :- !, cpp_text_double(A, F).
cpp_udl_imag(il, ldbl(A), imagl(A)) :- !.
cpp_udl_imag(S, L, _) :- cpp_refuse(0, literal_operator_not_visible(S, L)).
cpp_text_double(A, F) :- atom_codes(A, Cs), once(phrase(ccl_number(0, tok(float, F, _)), Cs)).   % the double nearest the text, as the lexers read a decimal or a hex one
cpp_local_class(L, K, N, Bases0, Ms0, Name) :- cpp_local_key(L, LK), '$cpp_localcls'(LK-class(K, N, Bases0, Ms0), Name), !.   % ONCE per text, as a lambda is: the result of a function is deduced from a walk of its first return, and the walk that emits meets the class again -- and per place and function in the program's code (0.236, cpp_local_key/2)
cpp_local_class(L, K, N, Bases0, Ms0, Name) :-
    ccl_gensym(local, G0), cpp_unit_tag(UT), ( UT == '' -> G = G0 ; atomic_list_concat([G0, '_', UT], G) ), ( N == anon -> Name = G ; atomic_list_concat([N, '.', G], Name) ),   % the unit's tag in the name (0.192)
    ( N == anon -> Bases = Bases0, Ms = Ms0 ; cpp_rename_names(Bases0, ['$deep'-yes, N-Name], Bases), cpp_rename_names(Ms0, ['$deep'-yes, N-Name], Ms) ),   % its own name inside it is the new one
    cpp_fsig_now(Encl), ( N == anon -> cpp_local_note(anon, Name, Encl) ; assertz('$cpp_pf_local'(Name, N, Encl)), cpp_local_note(named(N), Name, Encl) ),   % the function it is written in: its members' own names (0.166), its local name (0.236)
    cpp_isolated(( cpp_register_class(L, Name, Bases, Ms), cpp_item(declare(L, base([], [class(K, Name, Bases, Ms)])), Its) )),
    cpp_add_instance_items(Its), cpp_local_key(L, LK), assertz('$cpp_localcls'(LK-class(K, N, Bases0, Ms0), Name)), cpp_trace(local_class(Name)).
%% A LOCAL CLASS IS ITS PLACE'S AND ITS FUNCTION'S (0.236; [class.local], [temp.inst]): two local classes of one text in two blocks or two
%% functions, or in two instances of one function template, are two classes -- `{ struct L {}; } { struct L {}; }' was one, their type
%% information one. Keyed by the line and the description of the function the outermost closure is made in (cpp_fsig_root/2), as a
%% lambda in a closure's body is; the library's stay one per text
cpp_local_key(_, lib) :- nb_current('$cpp_in_lib', yes), !.
cpp_local_key(L, at(L, R)) :- cpp_fsig_now(F0), cpp_fsig_root(F0, R).
cpp_plain_local(struct(N, Ms), struct, N, Ms) :- atom(N), N \== anon, is_list(Ms).   % a plain local struct or union's definition (0.201; cpp_stmts)
cpp_plain_local(union(N, Ms), union, N, Ms) :- atom(N), N \== anon, is_list(Ms).
cpp_plain_local_name(L, K, N, Ms0, Name, Ms) :- cpp_local_key(L, LK), '$cpp_localst'(LK-K-N-Ms1, Name), Ms1 == Ms0, !, cpp_plain_local_ms(N, Name, Ms0, Ms).   % ONCE per text, place and function, as a local class is
cpp_plain_local_name(L, K, N, Ms0, Name, Ms) :-
    ccl_gensym(local, G0), cpp_unit_tag(UT), ( UT == '' -> G = G0 ; atomic_list_concat([G0, '_', UT], G) ), atomic_list_concat([N, '.', G], Name),
    cpp_local_key(L, LK), assertz('$cpp_localst'(LK-K-N-Ms0, Name)), cpp_fsig_now(Encl), cpp_local_note(named(N), Name, Encl), cpp_plain_local_ms(N, Name, Ms0, Ms).
cpp_plain_local_ms(N, Name, Ms0, Ms) :- cpp_rename_names(Ms0, ['$deep'-yes, N-Name], Ms1), cpp_plain_members(Ms1, Ms).   % its own name inside it the new one, its members' types resolved
cpp_unnamed_local(struct(anon, Ms), struct, Ms) :- is_list(Ms).
cpp_unnamed_local(union(anon, Ms), union, Ms) :- is_list(Ms).
cpp_unnamed_local_name(L, K, Ms0, Name, Ms) :- cpp_local_key(L, LK), '$cpp_localst'(LK-K-anon-Ms1, Name), Ms1 == Ms0, !, cpp_plain_members(Ms0, Ms).   % once per text, place and function
cpp_unnamed_local_name(L, K, Ms0, Name, Ms) :-
    ccl_gensym(local, G0), cpp_unit_tag(UT), ( UT == '' -> Name = G0 ; atomic_list_concat([G0, '_', UT], Name) ),
    cpp_local_key(L, LK), assertz('$cpp_localst'(LK-K-anon-Ms0, Name)), cpp_fsig_now(Encl), cpp_local_note(anon, Name, Encl), cpp_plain_members(Ms0, Ms).
cpp_subst_term(Old, New, X, Y) :- ( X == Old -> Y = New ; compound(X) -> X =.. [F|As], cpp_subst_term_l(As, Old, New, Bs), Y =.. [F|Bs] ; Y = X ).
cpp_subst_term_l([], _, _, []).
cpp_subst_term_l([A|As], Old, New, [B|Bs]) :- cpp_subst_term(Old, New, A, B), cpp_subst_term_l(As, Old, New, Bs).
%% A LOCAL TAG'S NAME IS RENAMED IN ITS SCOPE (0.201; [basic.scope.block]): the statements after its definition, but from a
%% nested block's own definition of the name on, which names its own type there (its own clause renames it when the walk
%% gets there): `{ struct S { short x, y; } t; struct S *p = &t; ... p->y }' inside a block of another `struct S' read the
%% outer S, `no_member(y, ...)'. A statement that holds no such definition is renamed whole (cpp_rename_names/3).
cpp_tag_scoped_list([], _, _, []).
cpp_tag_scoped_list([S0|Ss0], N, Map, Ss) :- ( cpp_tag_redef(S0, N) -> Ss = [S0|Ss0] ; cpp_tag_scoped(S0, N, Map, S), Ss = [S|Ss1], cpp_tag_scoped_list(Ss0, N, Map, Ss1) ).
cpp_tag_scoped(S0, N, Map, S) :- \+ cpp_tag_redef_in(S0, N), !, cpp_rename_names(S0, Map, S).
cpp_tag_scoped(block(Is0), N, Map, block(Is)) :- is_list(Is0), !, cpp_tag_scoped_list(Is0, N, Map, Is).
cpp_tag_scoped(S0, N, Map, S) :- S0 =.. [F|As0], cpp_tag_scoped_args(As0, N, Map, As), S =.. [F|As].
cpp_tag_scoped_args([], _, _, []).
cpp_tag_scoped_args([A0|As0], N, Map, [A|As]) :- cpp_tag_scoped(A0, N, Map, A), cpp_tag_scoped_args(As0, N, Map, As).
cpp_tag_redef_in(T, N) :- compound(T), ( cpp_tag_redef(T, N) -> true ; T =.. [_|As], member(A, As), cpp_tag_redef_in(A, N) ), !.
cpp_tag_redef(declare(_, base(_, [S])), N) :- cpp_tag_def_spec(S, N).
cpp_tag_redef(declaration(_, _, base(_, [S]), _), N) :- cpp_tag_def_spec(S, N).
cpp_tag_def_spec(S, N) :- compound(S), ( S = class(_, N1, _, Ms) -> true ; S =.. [K, N1, Ms], memberchk(K, [struct, union]) ), N1 == N, is_list(Ms).
cpp_opt_expr(_, none, none) :- !.
cpp_opt_expr(Ctx, E, E1) :- cpp_expr(Ctx, E, E1).
%% a declaration: a local of a class type with a constructor is declared, then
%% constructed (from its arguments, or copied from a value of the class),
%% then -- when the class has a destructor -- deferred; several declarators
%% go one by one
cpp_decl_stmt(Ctx, L, Sto, B, Vs, S) :-
    cpp_decl_pieces(Ctx, L, Sto, B, Vs, Pieces0),
    ( Sto == nrvo, Vs = [var(N, _, _)] -> cpp_nrvo_pieces(L, N, Pieces0, Pieces) ; Pieces = Pieces0 ),   % the named return value (0.199, cpp_nrvo/3)
    ( Sto == static, ccl_locals([_|_]) -> forall(( member(var(N, _, _), Vs), atom(N) ), ccl_declare('$sl'(N), static)) ; true ),   % a static local marked in its frame (0.197): no implicitly movable entity
    ( Pieces = [One] -> S = One ; S = '$splice'(Pieces) ).
%% NRVO, THE NAMED RETURN VALUE ([class.copy.elision]/1.1; 0.199): a named local of the result's class, of automatic storage, that
%% every return in its scope returns -- none there returns another expression, and the name is declared once -- is the result
%% object itself, as clang builds it at every level of optimization: its storage the caller's (`nrvo' in its storage slot, which
%% the lowering binds to the hidden result pointer, ir_locals/2), its returns handing it over as it is (`return(L, nrvo(N))'),
%% and its destructor run only where its scope ends otherwise -- a jump, an exception -- (a flag `$nrvo.N' the return sets,
%% which its defer asks). It was moved into the result (the implicit move of 0.197), a move constructor where clang runs none:
%% `S make() { S s(3); s.v = 4; return s; }' printed `move 4' and a second destructor. A class with no copy or move constructor
%% written and no destructor is returned in registers, its copy no one's to see; a coroutine's body has no return
cpp_nrvo(Ret, block(Is), block(Os)) :- Ret \== none, \+ cpp_term_mentions_functor(Is, co_return),
    catch(( cpp_class_of_type(Ret, C), cpp_ret_constructs(C) ), _, fail), !, cpp_nrvo_stmts(C, Is, Os).
cpp_nrvo(_, B, B).
cpp_nrvo_stmts(_, [], []) :- !.
cpp_nrvo_stmts(C, [declaration(L, Sto, B, [var(N, T, I)])|Is], [declaration(L, nrvo, B, [var(N, T, I)])|Os]) :- ( Sto == none ; Sto == auto ), atom(N),
    \+ ( T = base(Q, _), memberchk(volatile, Q) ), catch(( cpp_class_of_type(T, C1), C1 == C ), _, fail), cpp_nrvo_candidate(N, Is), !,
    cpp_nrvo_returns(N, Is, Is1), cpp_nrvo_stmts(C, Is1, Os).
cpp_nrvo_stmts(C, [S|Is], [S1|Os]) :- cpp_nrvo_nested(C, S, S1), cpp_nrvo_stmts(C, Is, Os).
cpp_nrvo_nested(C, block(Is), block(Os)) :- !, cpp_nrvo_stmts(C, Is, Os).
cpp_nrvo_nested(_, S, S) :- ( \+ compound(S) ; cpp_nrvo_opaque(S) ; S = expr(_, _) ; S = return(_, _) ; S = declaration(_, _, _, _) ), !.
cpp_nrvo_nested(C, S, S1) :- S =.. [F|As], cpp_nrvo_nested_list(C, As, Bs), S1 =.. [F|Bs].
cpp_nrvo_nested_list(_, [], []).
cpp_nrvo_nested_list(C, [A|As], [B|Bs]) :- cpp_nrvo_nested(C, A, B), cpp_nrvo_nested_list(C, As, Bs).
%% every return of the statements after the declaration names it, at least one does, and no other declaration there names it
cpp_nrvo_candidate(N, Is) :- \+ cpp_nrvo_redeclared(N, Is), findall(E, cpp_nrvo_ret(Is, E), Es), Es \== [], \+ ( member(E, Es), \+ cpp_nrvo_named(E, N) ).
cpp_nrvo_named(id(N0), N) :- N0 == N.
cpp_nrvo_named(paren(id(N0)), N) :- N0 == N.
cpp_nrvo_ret(T, E) :- compound(T), ( T = return(_, E0) -> E = E0 ; \+ cpp_nrvo_opaque(T), T =.. [_|As], member(A, As), cpp_nrvo_ret(A, E) ).
cpp_nrvo_redeclared(N, T) :- compound(T), \+ cpp_nrvo_opaque(T), ( T = var(N0, _, _), N0 == N -> true ; T =.. [_|As], member(A, As), cpp_nrvo_redeclared(N, A) ), !.
cpp_nrvo_opaque(lambda(_, _, _, _)).   % a lambda's returns are its own, a local class's members' too
cpp_nrvo_opaque(declare(_, _)).
cpp_nrvo_returns(_, T, T) :- \+ compound(T), !.
cpp_nrvo_returns(N, return(L, E), return(L, nrvo(N))) :- cpp_nrvo_named(E, N), !.
cpp_nrvo_returns(_, T, T) :- cpp_nrvo_opaque(T), !.
cpp_nrvo_returns(N, T, T1) :- T =.. [F|As], cpp_nrvo_returns_list(N, As, Bs), T1 =.. [F|Bs].
cpp_nrvo_returns_list(_, [], []).
cpp_nrvo_returns_list(N, [A|As], [B|Bs]) :- cpp_nrvo_returns(N, A, B), cpp_nrvo_returns_list(N, As, Bs).
cpp_nrvo_flag(N, F) :- atom_concat('$nrvo.', N, F).
%% the flag declared before the object, its destructor run where the flag is clear
cpp_nrvo_pieces(L, N, Ps0, [declaration(L, none, base([], [int]), [var(F, base([], [int]), int(0))])|Ps]) :- cpp_nrvo_flag(N, F), ccl_declare(F, base([], [int])), cpp_nrvo_defers(N, F, Ps0, Ps).
cpp_nrvo_defers(_, _, [], []).
cpp_nrvo_defers(N, F, [defer(DL, Vs, block([expr(LE, call(id(D), [addr(id(N0))]))]))|Ps], [defer(DL, Vs, block([if(LE, not(id(F)), block([expr(LE, call(id(D), [addr(id(N0))]))]), none)]))|Qs]) :- N0 == N, !,
    cpp_nrvo_defers(N, F, Ps, Qs).
cpp_nrvo_defers(N, F, [P|Ps], [P|Qs]) :- cpp_nrvo_defers(N, F, Ps, Qs).
%% A NAME IMPLICITLY MOVABLE IN A RETURN ([class.copy.elision]/3, C++20's P1825; 0.197): a local or a parameter of automatic
%% storage of the function being walked -- the innermost open frame that holds it holds no `'$sl'(N)', a static local's mark
%% -- of object type or an rvalue reference, never a member, a global, a static or an lvalue reference: `return s;' of a
%% member was moved out of it, and a later call read an empty string
cpp_implicitly_movable(id(N)) :- atom(N), ccl_locals(Fs), member(F, Fs), memberchk(N-T, F), !, \+ memberchk('$sl'(N)-_, F), \+ ccl_resolve_type(T, ref(_, _)).
%% A RETURNED VALUE OF THE RESULT'S CLASS IS CONSTRUCTED through its copy or move constructor where its class has a destructor,
%% or a copy or a move constructor with a body of its own (0.197: such a class without a destructor was copied as its bytes,
%% and the constructor's effects were lost); a defaulted one is memberwise, which the bytes are where nothing is destroyed
cpp_ret_constructs(C) :- cpp_dtor(C, _), !.
cpp_ret_constructs(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, [P], I, _), Ms), I \= memberwise(_, _), ( cpp_special_param(P, C, ref) ; cpp_special_param(P, C, rref) ), !.
cpp_decl_pieces(_, _, _, _, [], []).
%% `auto x = {a, b}' DEDUCES `std::initializer_list<E>' ([dcl.type.auto.deduct]/4; 0.206), E the first item's type decayed, a list of one
%% item too: the reader reads the direct form of one item, `auto x{a}', as `auto x = a' (ccl_var_init_fn//2), and `auto x{a, b}' is
%% ill-formed. It was refused `auto(x)'
cpp_decl_pieces(Ctx, L, Sto, B, [var(N, base(_, [auto]), init(Items))|Vs], Pieces) :- Items = [item(_, E0)|_],
    catch(( cpp_unevaluated(cpp_expr(Ctx, E0, E1)), ccl_type_of(E1, IT0), IT0 \== unknown ), _, fail), ccl_unref(IT0, IT1), cpp_decayed(IT1, ET), !,
    cpp_instantiate_type(initializer_list, [ET], ILT),
    cpp_decl_pieces(Ctx, L, Sto, B, [var(N, ILT, init(Items))|Vs], Pieces).
%% A LOCAL `std::initializer_list<E>' FROM A BRACED LIST ([dcl.init.list]/6: the backing array lives as long as the list; 0.206): the
%% array a local of its own, `$ila', built by the roads above (an array of objects in place, destroyed at the scope's end), and the
%% list over it by the class's two-argument constructor, as cpp_init_list/4 makes it -- `std::initializer_list<int> il{1, 2, 3};' was
%% `no_constructor(initializer_list.int, 3)'
cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T0, init(Items))|Vs], Pieces) :- Items \== [], Sto \== static, Sto \== extern, atom(N),
    cpp_il_written(T0), cpp_type(T0, T), cpp_class_of_type(T, C), '$cpp_inst'(C, inst(initializer_list, [ET])), !,   % the WRITTEN type asked first: a type caught here was every braced declaration's, and a refusal of its instance (a static assertion's) was swallowed, the class then unknown
    length(Items, K), ccl_gensym('$ila', Arr), AT = arr(int(K), ET),
    cpp_decl_pieces(Ctx, L, Sto, ET, [var(Arr, AT, init(Items))], P0),
    cpp_temporary(T, C, [id(Arr), int(K)], ILE), ccl_declare(N, T),
    append(P0, [declaration(L, Sto, B, [var(N, T, ILE)])|P1], Pieces), cpp_decl_pieces(Ctx, L, Sto, B, Vs, P1).
cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T0, I0)|Vs], Pieces) :- cpp_has_auto(T0), !,      % auto the reader could not infer: a lambda, a call of a method or a template
    cpp_where(auto(N), cpp_expr(Ctx, I0, I)), ( ccl_type_of(I, IT0), IT0 \== unknown -> cpp_nx_init_type(I0, IT0, IT), cpp_trace(auto_type(N, I, IT)), cpp_auto_deduce(T0, IT, T2), cpp_fwd_auto(T0, I, T2, T) ; cpp_trace(auto_untyped(N, I)), cpp_refuse(L, auto(N)) ),   % ANY deduced type, not only a plain one: `auto p = q - n' is a pointer, and required a base before; a noexcept function's name or address a pointer to a noexcept function (0.205, cpp_nx_init_type/3)
    ( cpp_has_auto(T) -> cpp_refuse(L, auto(N)) ; true ),                                  % an initializer whose type is still `auto' -- a call of a function whose result was never deduced -- is refused, where it was asked again without end (0.100)
    cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T, '$cpp_walked'(I))|Vs], Pieces).
%% CLASS TEMPLATE ARGUMENT DEDUCTION IN A DECLARATION ([dcl.type.class.deduct]): `R s(x, 5ul)', `std::pair p(a, b)'
%% -- the template's name as the type, its arguments deduced from the initializer by the implicit guides (cpp_ctad_args,
%% the expression road's since this step). The base spec is rewritten with it, so the lowering sees the instance.
cpp_decl_pieces(Ctx, L, Sto, B0, [var(N, base(Q, [typedef(TN0)]), I)|Vs], Pieces) :- cpp_ctad_name(TN0, TN), \+ cpp_class_l(TN, _), \+ ccl_typedef_of(TN, _),
    cpp_init_args(I, As), ( As \== [] ; I == init([]) ), cpp_ctad_init(TN, I, As, Args), !,   % `std::less l{};' too, the template's defaults (0.201)
    T1 = base(Q, [typedef(tmpl(TN, Args))]), ( B0 = base(Q0, [typedef(TN0)]) -> B1 = base(Q0, [typedef(tmpl(TN, Args))]) ; B1 = B0 ),
    cpp_decl_pieces(Ctx, L, Sto, B1, [var(N, T1, I)|Vs], Pieces).
%% C++20'S PARENTHESIZED AGGREGATE INITIALIZATION OF A LOCAL (0.197; cpp_paren_aggregate/2): `P p(1, 2);', `Q q(3, P(4, 5));',
%% `int a[](9, 10, 11);' -- the braced list of its values, which the aggregate roads below take
cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T0, ctor(As))|Vs], Pieces) :- As = [_|_], ccl_std_at_least(20),
    cpp_type(T0, T), cpp_paren_aggregate(T, As), !,
    findall(item([], A), member(A, As), Items),
    cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T0, init(Items))|Vs], Pieces).
cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T0, init(Items))|Vs], Pieces) :-
    cpp_type(T0, T), Sto \== static, Sto \== extern, cpp_class_of_type(T, C), cpp_implicit_ctor_needed(C), cpp_aggregate_class(C), !,   % an aggregate of members that construct: each from its item -- AN AGGREGATE, a class with no constructor WRITTEN ([dcl.init.list]/3; 0.100): `std::atomic<int> a{12}' has `atomic() = default' beside `atomic(_Tp)', which made the implicit default constructor needed and took this clause, the item 12 given to no data member (atomic has only its base) and DROPPED -- the object was never constructed
    ccl_declare(N, T), cpp_class_l(C, cls(_, Data, _, _, _)),
    cpp_agg_values(Data, Items, Es), cpp_exprs(Ctx, Es, Es1), cpp_aggregate_inits(Data, Es1, id(N), L, Inits),
    Pieces = [declaration(L, Sto, B, [var(N, T, none)])|P1], append(Inits, P2, P1),
    ( cpp_dtor(C, DName) -> cpp_check_access(Ctx, C, '$dtor'), cpp_scope_end(L, N, LE), P2 = [defer(L, [], block([expr(LE, call(id(DName), [addr(id(N))]))]))|P3] ; P2 = P3 ),
    cpp_decl_pieces(Ctx, L, Sto, B, Vs, P3).
%% A FUNCTION-LOCAL STATIC OBJECT IS INITIALIZED THE FIRST TIME CONTROL PASSES ITS DECLARATION ([stmt.dcl]/3; 0.112):
%% at compile time where the evaluator constructs it, else under the Itanium ABI's guard -- `__cxa_guard_acquire'
%% answers non-zero once, the constructor runs over the static's address, its destructor is registered with
%% `__cxa_atexit' (the destructor itself the callback, the object its argument), and `__cxa_guard_release' marks it
%% done. Before, the static took the plain road and the lowering met an initializer that is no constant.
cpp_decl_pieces(Ctx, L, static, B, [var(N, T0, I)|Vs], Pieces) :-
    atom(N), cpp_type(T0, T), cpp_class_of_type(T, C), cpp_has_ctors(C), ( I \== none ; \+ cpp_trivial_default(C) ), !,
    ccl_declare(N, T),
    (   cpp_fold_quietly(T, C, I, IV)
    ->  (   cpp_dtor(C, DName)   % ... AND ONE CONSTRUCTED AT COMPILE TIME REGISTERS ITS DESTRUCTOR the first time control passes it, under the guard (0.192): it registered none
        ->  cpp_static_guard(L, N, G, GT, Acq, Rel), cpp_cxa_atexit(L, N, DName, Reg),
            Pieces = [declaration(L, static, B, [var(N, T, IV)]), declaration(L, static, GT, [var(G, GT, none)]), if(L, Acq, block([Reg, Rel]), none)|P1]
        ;   Pieces = [declaration(L, static, B, [var(N, T, IV)])|P1] )
    ;   ( I = '$cpp_walked'(E1) -> W = I ; I \== none, I \= ctor(_), I \= init(_) -> cpp_expr(Ctx, I, E1), W = '$cpp_walked'(E1) ; W = I ),   % the initializer walked ONCE
        (   nonvar(E1), cpp_class_of_type_of(E1, C), \+ cpp_lvalue(E1), \+ E1 = move(_)
        ->  cpp_temp_elide(E1, E2), InitS = expr(L, assign('=', id(N), E2))   % a prvalue of the class IS the object (C++17)
        ;   I = init(Items), cpp_aggregate_class(C), \+ cpp_il_ctor_for(C, Items, _)   % AN AGGREGATE CLASS FROM ITS BRACED LIST, or C++20's parentheses (0.197): member by member, as a local's (`static Q q{8, P(9, 10)};' was refused `no_constructor(Q, 2)' where its value does not fold)
        ->  cpp_class_l(C, cls(_, Data, _, _, _)), cpp_agg_values(Data, Items, Es), cpp_exprs(Ctx, Es, Es1), cpp_aggregate_inits(Data, Es1, id(N), L, InitSs), InitS = block(InitSs)
        ;   cpp_ctor_args(Ctx, W, C, Args), length(Args, NA), ( cpp_ctor(C, Args, CName) -> true ; cpp_refuse(L, no_constructor(C, NA)) ),
            cpp_fill_defaults(CName, Args, Args0), cpp_ref_args_of(CName, Args0, Args1), cpp_copies(call(id(CName), [addr(id(N))|Args1]), Call), InitS = expr(L, Call) ),
        cpp_static_guard(L, N, G, GT, Acq, Rel), cpp_guard_abort(L, G, GT, Abort),
        ( cpp_dtor(C, DName) -> cpp_cxa_atexit(L, N, DName, R1), Reg = [R1] ; Reg = [] ),
        append([Abort, InitS|Reg], [Rel], Once),
        Pieces = [declaration(L, static, B, [var(N, T, none)]), declaration(L, static, GT, [var(G, GT, none)]), if(L, Acq, block(Once), none)|P1] ),
    cpp_decl_pieces(Ctx, L, static, B, Vs, P1).
%% A FUNCTION-LOCAL STATIC ARRAY OF OBJECTS (0.117) is initialized the first time control passes its declaration, as
%% a static object is: under the guard, each element made in order (the local array's road, cpp_elems_from), then the
%% array's destruction registered with `__cxa_atexit' -- a wrapper that takes the array's address (`$cpp_sdtor.N.K',
%% emitted with the unit's other wrappers: the static is a name of this function alone) and destroys the elements in
%% reverse. `static T once[2];' was neither constructed nor destroyed.
cpp_decl_pieces(Ctx, L, static, B, [var(N, T0, I0)|Vs], Pieces) :-
    atom(N), cpp_type(T0, T1), cpp_size_by_init(T1, I0, T), ccl_resolve_type(T, arr(Bd, ET)),
    cpp_elem_class(ET, EC), ( cpp_has_ctors(EC) ; cpp_dtor(EC, _) ), I0 \= '$cpp_walked'(_), !,
    ccl_declare(N, T), cpp_array_bound_n(arr(Bd, ET), K), K1 is K - 1,
    (   I0 = init(Items) -> findall(V, member(item(_, V), Items), Vs0), cpp_exprs(Ctx, Vs0, Es)
    ;   I0 == none -> Es = []
    ;   cpp_refuse(L, array_of_objects_initialized(N)) ),
    ( cpp_dtor(EC, _) -> cpp_elems_unwind(0, K1, ET, id(N), Es, L, Inits0, []) ; cpp_elems_from(0, K1, ET, id(N), Es, L, Inits0, []) ),
    atom_concat('$guard.', N, G), GT = base([], [long]), ccl_declare(G, GT),
    cpp_math_declared('__cxa_guard_acquire', base([], [int]), [param(ptr([], GT), g)]),
    cpp_math_declared('__cxa_guard_release', base([], [void]), [param(ptr([], GT), g)]),
    cpp_guard_abort(L, G, GT, Abort), Inits = [Abort|Inits0],   % ... AN ELEMENT THAT THROWS (0.201; [stmt.dcl]/4): the elements built destroyed and the guard aborted, so the next pass tries again

    (   cpp_dtor(EC, _)
    ->  VP = ptr([], base([], [void])), FT = ptr([], fn(base([], [void]), [param(VP, p)], false)), Void = base([], [void]),
        cpp_math_declared('__cxa_atexit', base([], [int]), [param(FT, f), param(VP, p), param(VP, d)]),
        ccl_gensym('$cpp_sdtor.', W), cpp_member_dtor(T, deref(cast(ptr([], T), id('$p'))), L, DSs),
        nb_getval('$cpp_ginit_fns', Fs0), append(Fs0, [function(L, static, Void, W, [param(VP, '$p')], false, block(DSs))], Fs1), nb_setval('$cpp_ginit_fns', Fs1),
        ccl_declare(W, fn(Void, [param(VP, '$p')], false)),
        Reg = [expr(L, call(id('__cxa_atexit'), [cast(FT, id(W)), cast(VP, addr(id(N))), nullptr]))]
    ;   Reg = [] ),
    append(Inits, Reg, Once0), append(Once0, [expr(L, call(id('__cxa_guard_release'), [addr(id(G))]))], Once),
    Pieces = [declaration(L, static, B, [var(N, T, none)]), declaration(L, static, GT, [var(G, GT, none)]),
              if(L, call(id('__cxa_guard_acquire'), [addr(id(G))]), block(Once), none)|P1],
    cpp_decl_pieces(Ctx, L, static, B, Vs, P1).
%% A LOCAL ARRAY OF OBJECTS ([dcl.init]/7, [dcl.init.aggr]/5; 0.112): each element constructed in order -- from its
%% item, a prvalue of the class BEING the element (C++17's elision, `Tag us[3] = {Tag(10), Tag(20)}'), else
%% value-initialized through the default constructor -- and the array destroyed in reverse at the scope's end, as a
%% member array has been since 0.84 (`cpp_member_from', `cpp_value_init', `cpp_member_dtor'). Before, a local array
%% was neither constructed nor destroyed, and `std::string names[3] = {"ann", "bob"}' stored the literals' pointers
%% into the strings' bytes. An array of arrays of objects stays the plain road (named).
cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T0, I0)|Vs], Pieces) :-
    Sto \== static, Sto \== extern, atom(N), cpp_type(T0, T1), cpp_size_by_init(T1, I0, T), ccl_resolve_type(T, arr(Bd, ET)),
    cpp_elem_class(ET, EC), ( cpp_has_ctors(EC) ; cpp_dtor(EC, _) ), !,                        % AN ARRAY OF ARRAYS OF OBJECTS TOO (0.117): each outer element is an array the member road builds (cpp_member_from, cpp_value_init) and the destruction walks (cpp_member_dtor)
    ccl_declare(N, T), cpp_array_bound_n(arr(Bd, ET), K), K1 is K - 1,
    (   I0 = init(Items) -> findall(V, member(item(_, V), Items), Vs0), cpp_exprs(Ctx, Vs0, Es)
    ;   I0 == none -> Es = []
    ;   cpp_refuse(L, array_of_objects_initialized(N)) ),
    ( cpp_dtor(EC, _) -> cpp_elems_unwind(0, K1, ET, id(N), Es, L, Inits0, []), Inits = [block(Inits0)] ; cpp_elems_from(0, K1, ET, id(N), Es, L, Inits, []) ),
    Pieces = [declaration(L, Sto, B, [var(N, T, none)])|P1], append(Inits, P2, P1),
    ( cpp_dtor(EC, _) -> cpp_member_dtor(T, id(N), L, Ds), P2 = [defer(L, [], block(Ds))|P3] ; P2 = P3 ),
    cpp_decl_pieces(Ctx, L, Sto, B, Vs, P3).
cpp_decl_pieces(Ctx, L, Sto, B, [var(N, T0, I)|Vs], Pieces) :-
    cpp_type(T0, T1), cpp_size_by_init(T1, I, T),
    (   Sto \== static, Sto \== extern, cpp_class_of_type(T, C), cpp_has_ctors(C), cpp_ctor_args(Ctx, I, C, Args)
    ->  cpp_check_access(Ctx, C, '$ctor'), length(Args, NA), ccl_declare(N, T),
        %% C++17: A PRVALUE OF THE CLASS IS THE OBJECT, elided -- no constructor runs and none is looked for.
        %% `auto __guard = std::__make_scope_guard(f);' hands a `__scope_guard' to the only constructor
        %% `__scope_guard(_Func)' has, which takes the closure, and LLVM refused the store; the temporary that
        %% built it is the object too, so the statement must not destroy it (cpp_temp_elide, as a by-value
        %% parameter and a return already do).
        (   Args = [E0], cpp_class_of_type_of(E0, C), \+ cpp_lvalue(E0), \+ ( E0 = move(X0), cpp_lvalue(X0) ), \+ cpp_xvalue_object(E0)   % ... and a CALL RETURNING `T &&' names an object too (0.132: `std::string t = take(s);' over `std::string &&take(std::string &)' made t the bytes of s; the move constructor takes it) ... but `std::move(q)' NAMES AN OBJECT and is no temporary to elide ([basic.lval]: an xvalue, not a prvalue): elided, `auto r = std::move(q)' made r the bytes of q, both unique_ptrs held the pointer and both freed it
        ->  cpp_temp_elide(E0, E1), Pieces = [declaration(L, Sto, B, [var(N, T, E1)])|P1]
        ;   cpp_ctor(C, Args, CName), '$cpp_consteval'(CName)   % A CONSTEVAL CONSTRUCTOR runs at compile time (0.112): the object's value is the local's initializer
        ->  cpp_fill_defaults(CName, Args, Args0), cpp_ref_args_of(CName, Args0, Args1),
            ( catch(cpp_eval_construct(T, CName, Args1, AV), _, fail), cpp_eval_init_term(AV, IV) -> Pieces = [declaration(L, Sto, B, [var(N, T, IV)])|P1] ; cpp_refuse(L, consteval_call_not_constant(CName)) )
        ;   cpp_ctor(C, Args, CName)
        ->  cpp_fill_defaults(CName, Args, Args0), cpp_ref_args_of(CName, Args0, Args1),
            cpp_copies(call(id(CName), [addr(id(N))|Args1]), Call),   % THE COPY PASS ON A LOCAL'S CONSTRUCTOR CALL (0.112), as a temporary's has had it since 0.83: `H h(v, pred)' over `H(V x, P q)' with V a ref_view handed the vector itself to the ref_view parameter, where its converting constructor template is meant -- LLVM refused the store
            (   I == init([]), cpp_value_zeroes(C)   % `T t{}' VALUE-INITIALIZES ([dcl.init.list]/3.5; 0.127): zeroed before a constructor that is not user-provided
            ->  Pieces = [declaration(L, Sto, B, [var(N, T, none)])|Zs], cpp_zero_stmts(L, T, id(N), Zs, [expr(L, Call)|P1])
            ;   Pieces = [declaration(L, Sto, B, [var(N, T, none)]), expr(L, Call)|P1] )
        ;   Args == [], cpp_trivial_default(C) -> Pieces = [declaration(L, Sto, B, [var(N, T, none)])|P1]        % nothing to construct
        ;   Args = [E], cpp_class_of_type_of(E, C), \+ cpp_dtor(C, _) -> Pieces = [declaration(L, Sto, B, [var(N, T, E)])|P1]   % the implicit copy, bitwise
        ;   cpp_refuse(L, no_constructor(C, NA)) )
    ;   cpp_trace(plain_init(N, T, I)), cpp_plain_init(I, T, I0), cpp_expr(Ctx, I0, I0w), cpp_init_convs(T, I0w, I00), cpp_conv_to(I00, T, I10), ccl_declare(N, T), cpp_note_const(N, T, I10, I1),   % a scalar from a class value: its conversion operator
        ( cpp_binds_const_lvalue(T, I1) -> cpp_refuse(L, binds_const(N)) ; true ),
        ( cpp_class_of_type(T, C0), cpp_dtor(C0, _), cpp_lvalue(I1) -> cpp_refuse(L, copy_of_a_class_with_destructor(C0)) ; true ),   % two owners of one buffer
        (   Sto \== static, Sto \== extern, cpp_ext_temp(T, I1, X, XT, XD)   % A TEMPORARY BOUND TO A NAMED REFERENCE LIVES AS LONG AS THE REFERENCE ([class.temporary]/6; 0.112): it is a hidden local `$ext_K', the prvalue elided into it, destroyed by a defer at the scope's end where the statement's end had destroyed it (`const Tag &a = Tag(1)' dangled) or nothing had (`Tag &&b = make(2)')
        ->  cpp_temp_elide(I1, I2), ccl_declare(X, XT),
            Pieces = [declaration(L, none, XT, [var(X, XT, I2)])|P0],
            ( XD \== none -> cpp_scope_end(L, N, LX), P0 = [defer(L, [], block([expr(LX, call(id(XD), [addr(id(X))]))])), declaration(L, Sto, B, [var(N, T, id(X))])|P1] ; P0 = [declaration(L, Sto, B, [var(N, T, id(X))])|P1] )
        ;   ( cpp_class_of_type(T, C1), cpp_dtor(C1, _) -> cpp_temp_elide(I1, I2) ; I2 = I1 ),   % a temporary of a class without constructors -- a closure built member by member -- IS the local ([class.copy.elision]), destroyed once, by the local's defer
            (   Sto == static, \+ cpp_class_of_type(T, _), \+ ccl_resolve_type(T, arr(_, _)), \+ T = ref(_, _), \+ T = rref(_, _), \+ cpp_thread_local_q(T), \+ cpp_thread_local_q(B),
                cpp_runtime_init(I2)   % A FUNCTION-LOCAL STATIC SCALAR WITH A RUN-TIME INITIALIZER ([stmt.dcl]/3; 0.201): zero, then given its value the first time control passes its declaration, under the Itanium guard, aborted where the initializer throws -- `static int x = f();' was refused, `global_init(call(id(f), []))'
            ->  cpp_static_guard(L, N, G, GT, Acq, Rel), cpp_guard_abort(L, G, GT, Abort),
                Pieces = [declaration(L, static, B, [var(N, T, none)]), declaration(L, static, GT, [var(G, GT, none)]), if(L, Acq, block([Abort, expr(L, assign('=', id(N), I2)), Rel]), none)|P1]
            ;   Pieces = [declaration(L, Sto, B, [var(N, T, I2)])|P1] ) ) ),
    ( Sto \== static, Sto \== extern, cpp_class_of_type(T, C2), cpp_dtor(C2, DName) -> cpp_check_access(Ctx, C2, '$dtor'), cpp_scope_end(L, N, LE), P1 = [defer(L, [], block([expr(LE, call(id(DName), [addr(id(N))]))]))|P2] ; P1 = P2 ),   % THE DESTRUCTOR'S ACCESS where a local of the class ends (0.127; [class.dtor]/15)
    cpp_decl_pieces(Ctx, L, Sto, B, Vs, P2).
%% a declaration's written type that names `std::initializer_list' (0.206): its template-id, or an instance's name, the `auto' road's
cpp_il_written(base(_, [typedef(X)])) :- cpp_il_written_(X).
cpp_il_written_(scoped(_, X)) :- !, cpp_il_written_(X).
cpp_il_written_(tmpl(initializer_list, _)) :- !.
cpp_il_written_(X) :- atom(X), '$cpp_inst'(X, inst(initializer_list, _)), !.
%% a local static's guard, the Itanium ABI's (`$guard.N', a static of its own; `__cxa_guard_acquire' answers non-zero once,
%% `__cxa_guard_release' marks it done), and its destructor's registration with `__cxa_atexit' (the destructor itself the
%% callback, the object its argument, a null DSO handle), for both roads of a local static of class type (0.112, 0.192)
cpp_static_guard(L, N, G, GT, call(id('__cxa_guard_acquire'), [addr(id(G))]), expr(L, call(id('__cxa_guard_release'), [addr(id(G))]))) :-
    atom_concat('$guard.', N, G), GT = base([], [long]), ccl_declare(G, GT),
    cpp_math_declared('__cxa_guard_acquire', base([], [int]), [param(ptr([], GT), g)]),
    cpp_math_declared('__cxa_guard_release', base([], [void]), [param(ptr([], GT), g)]).
cpp_cxa_atexit(L, N, DName, expr(L, call(id('__cxa_atexit'), [cast(FT, id(DName)), cast(VP, addr(id(N))), nullptr]))) :-
    VP = ptr([], base([], [void])), FT = ptr([], fn(base([], [void]), [param(VP, p)], false)),
    cpp_math_declared('__cxa_atexit', base([], [int]), [param(FT, f), param(VP, p), param(VP, d)]).
%% AN INITIALIZATION THAT THROWS IS NOT COMPLETE, AND THE NEXT PASS TRIES AGAIN ([stmt.dcl]/4; 0.201): the guard aborted by a
%% cleanup that only the unwinding runs (eh_cleanup), `__cxa_guard_abort', which the Itanium ABI has for it -- left acquired,
%% the next call of the function met libc++abi's `recursive initialization' and aborted
cpp_guard_abort(L, G, GT, eh_cleanup(L, block([expr(L, call(id('__cxa_guard_abort'), [addr(id(G))]))]))) :-
    cpp_math_declared('__cxa_guard_abort', base([], [void]), [param(ptr([], GT), g)]).
cpp_thread_local_q(T) :- compound(T), T = base(Q, _), memberchk(thread_local, Q).
%% A FORWARDING REFERENCE, `auto &&x = e' (cv-unqualified), GIVEN AN LVALUE IS `T &' ([dcl.spec.auto.general]/4,
%% [temp.deduct.call]/3; 0.132): it was `T &&' whatever e was, so `std::forward<decltype(x)>(x)' moved from an lvalue,
%% and a call that returns a reference was taken for a temporary to extend -- join_view's `auto &&__inner = [this]() ->
%% auto && { ... }();' bound a bitwise COPY of the inner vector and destroyed it at the scope's end
cpp_fwd_auto(base(Q, [auto]), I, _, T) :- memberchk(decltype_auto, Q), !, ( cpp_decltype_auto_of(I, T) -> true ; cpp_refuse(0, decltype_auto_untyped) ).   % `decltype(auto) x = e' (0.132): e's decltype, as a result's
cpp_fwd_auto(rref(Q, base(QA, [auto])), I, rref(Q, T), ref(Q, T)) :- \+ memberchk(const, QA), \+ memberchk(volatile, QA), cpp_lvalue(I), \+ cpp_xvalue_object(I), !.
cpp_fwd_auto(_, _, T, T).
%% ... AND `auto' UNDER A REFERENCE OR A POINTER: `auto &__buffer = *__is.rdbuf()' takes the referent's type, nothing
%% decayed; `const auto *__first = __buffer.gptr()' the pointee's, its qualifiers kept -- libc++'s getline is written
%% in both, and only a plain `auto' was deduced: the reference local stayed `auto', and everything read through it
%% could not be typed
cpp_has_auto(base(_, [auto])) :- !.
cpp_has_auto(ref(_, T)) :- !, cpp_has_auto(T).
cpp_has_auto(rref(_, T)) :- !, cpp_has_auto(T).
cpp_has_auto(ptr(_, T)) :- !, cpp_has_auto(T).
cpp_auto_deduce(base(Q, [auto]), IT, T) :- !, cpp_decayed(IT, T1),                                   % `auto x = e': the decayed type, the qualifiers kept
    ( select(constrained(C, As), Q, Q1) -> cpp_constrained_ok(C, As, T1) ; Q1 = Q ), ccl_add_quals(Q1, T1, T).   % C++20's `Number auto x = e' ([dcl.spec.auto]/2): the type deduced must satisfy the concept
cpp_auto_deduce(ref(Q, X), IT, ref(Q, T)) :- !, ccl_unref(IT, IT1), cpp_auto_bind(X, IT1, T).             % `auto &r = e': the referent's type
cpp_auto_deduce(rref(Q, X), IT, rref(Q, T)) :- !, ccl_unref(IT, IT1), cpp_auto_bind(X, IT1, T).
cpp_auto_deduce(ptr(Q, X), IT, ptr(Q, T)) :- ccl_unref(IT, IT0), ccl_resolve_type(IT0, R), ( R = ptr(_, E) ; R = arr(_, E) ), !, cpp_auto_bind(X, E, T).   % `const auto *p = e': the pointee's
cpp_auto_bind(base(Q, [auto]), IT, T) :- !, ( select(constrained(C, As), Q, Q1) -> cpp_constrained_ok(C, As, IT) ; Q1 = Q ), ccl_add_quals(Q1, IT, T).
cpp_auto_bind(P, IT, T) :- cpp_auto_deduce(P, IT, T).
cpp_constrained_ok(C, As, T) :- ( cpp_concept_holds(C, [T|As]) -> true ; cpp_refuse(0, constraint_not_satisfied(C)) ).
%% the template's name, bare or NAMESPACE-qualified (0.112): libc++ 18 writes `__format::__parse_number_result __r = ...'
cpp_ctad_name(TN, TN) :- atom(TN), !.
cpp_ctad_name(scoped(Path, TN), TN) :- atom(TN), \+ cpp_scope_class(Path, _).
cpp_init_args(ctor(As), As) :- !.
cpp_init_args(init(Items), As) :- !, findall(V, member(item(_, V), Items), As).
cpp_init_args(E, [E]) :- E \== none.
%% A NON-CONST LVALUE REFERENCE BINDS NO CONST LVALUE ([dcl.init.ref]/5; 0.127): `const int c = 1; int &r = c;' compiled and wrote into the
%% const, and so did `int &r = x;' over a by-value capture inside a lambda that is not mutable
cpp_binds_const_lvalue(ref(Q, RT), E) :- \+ memberchk(const, Q), \+ cpp_type_const(RT), \+ ( catch(ccl_resolve_type(RT, R), _, fail), cpp_type_const(R) ),
    \+ ( catch(ccl_resolve_type(RT, R2), _, fail), R2 = fn(_, _, _) ), cpp_lvalue(E), cpp_obj_const(E, const), !.
%% a type with no constructor direct-initialized, `_Tp __t(std::move(__x))', `int n{}', `S s(t)': the value itself, or
%% the type's zero for an empty one
%% A `const' LOCAL OF INTEGRAL TYPE WITH A CONSTANT INITIALIZER IS A CONSTANT EXPRESSION, as C++ has had it since
%% C++98 (C gained it at C23, ccl_note_own_constant): its name may stand where a template argument or an array's bound
%% does. libc++'s `__recommend' writes `const size_type __boundary = ...;' and then `__align_it<__boundary>(...)'.
%% Noted after the initializer is DESUGARED, since the class constants in it fold only then.
%% an unbounded array whose initializer held a pack expansion at the read is SIZED HERE, the pack expanded (0.104)
%% the prvalue a reference extends: of a class with a destructor (a class without one leaves nothing to run, and the
%% lowering's materialized slot lives as long as the function), never an lvalue, a `move' of one or an xvalue call
cpp_ext_temp(T, I, X, XT, XD) :- ( T = ref(_, _) ; T = rref(_, _) ), cpp_class_of_type_of(I, C), cpp_dtor(C, XD),
    \+ cpp_lvalue(I), \+ I = move(_), \+ cpp_xvalue_call(I), \+ I = ccast(_, _, _), !,
    XT = base([], [typedef(C)]), ccl_gensym('$ext', X).
cpp_size_by_init(arr(none, E), init(Items), arr(int(K), E)) :- \+ member(item(_, pack(_)), Items), !, length(Items, K).
cpp_size_by_init(T, _, T).
%% ITS INITIALIZER IS MANIFESTLY CONSTANT-EVALUATED ([expr.const]/20; 0.197): a `const' integral local initialized by a
%% constant expression is usable in constant expressions, so its call is folded with std::is_constant_evaluated() true
%% (cpp_with_ce/1) and the folded value IS the initializer -- `constexpr bool ce = std::is_constant_evaluated();' was 0
cpp_note_const(N, T, I, I1) :- ccl_resolve_type(T, R), R = base(Q, _), memberchk(const, Q), \+ ccl_is_float(R),
    (   ccl_const_eval(I, V) -> I1 = I
    ;   I = call(_, _), catch(cpp_with_ce(cpp_const_value(I, V0)), _, fail) -> ( V0 = bool(B) -> ( B == true -> V = 1 ; V = 0 ) ; V = V0 ),   % a CONSTEXPR CALL folds through the evaluator (0.104): libc++'s `constexpr _CCC __cat = __compute_comp_type(__type_kinds);'
        ( integer(V) -> I1 = int(V) ; V = big(_) -> I1 = int(V) ; I1 = I )
    ;   cpp_trace(const_not_folded(N, I)), fail ), !,
    ccl_declare('$cv'(N), V), cpp_lconst_push(N-V).
%% A `const' LOCAL AGGREGATE WITH A CONSTANT INITIALIZER IS A VALUE TO THE CONSTEXPR EVALUATOR (0.104), as a file-scope
%% one has been since 0.97 (`'$cpp_gagg:N'', marked `local': read only while the name IS a local of the walk, where a
%% global's entry is read only while it is not): libc++'s `__get_comp_type' writes `constexpr _CCC __type_kinds[] =
%% {_StrongOrd, __type_to_enum<_Ts>()...};' and hands it to a constexpr function by reference
cpp_note_const(N, T, I, I) :- I \== none, atom(N), cpp_const_agg_type(T), !,
    (   catch(cpp_eval_init(T, I, [], _, _), Err, ( cpp_trace(const_agg_error(N, Err)), fail ))
    ->  atom_concat('$cpp_gagg:', N, K), nb_setval(K, agg(T, I, local)), cpp_trace(const_local_agg(N))
    ;   cpp_trace(const_agg_not_folded(N, I)), cpp_agg_items_trace(I) ).
cpp_note_const(_, _, I, I).
%% THE EVALUATION OF A CONSTANT EXPRESSION, std::is_constant_evaluated() and __libcpp_is_constant_evaluated() true in it
%% ('$cpp_eval_ce', cpp_eval_reduce/3), the flag put back as it was on success, failure and throw (0.197)
cpp_with_ce(G) :- ( nb_current('$cpp_eval_ce', W) -> true ; W = off ), nb_setval('$cpp_eval_ce', on),
    (   catch(G, X, ( nb_setval('$cpp_eval_ce', W), throw(X) )) -> nb_setval('$cpp_eval_ce', W) ; nb_setval('$cpp_eval_ce', W), fail ).
%% A LOCAL CONSTANT IS ITS BLOCK'S (0.195): the first clause above put it in the file's table of enumerators, before every
%% entry, and it stayed there when its body ended -- after `void f() { const int K = 3; }' a file-scope `int b[K];' over
%% `const int K = 8;' had 3 elements. It is an entry of the frame that declares it, `'$cv'(N)-V' (ccl_frame_constant/3),
%% and of the walk's own list ('$cpp_lconsts', ccl_body_constant/2), which a lambda's body reads, its frames set aside;
%% both leave where the block's walk ends, however it ends (cpp_in_frame/1, cpp_with_fsig/2).
cpp_lconst_push(P) :- cpp_lconsts_now(L), nb_setval('$cpp_lconsts', [P|L]).
cpp_agg_items_trace(init(Items)) :- !, forall(member(item(_, E), Items), ( catch(cpp_eval_effect(E, [], _, V), Err, ( V = error(Err) )) -> cpp_trace(agg_item(E, V)) ; cpp_trace(agg_item(E, failed)) )).   % under the trace: which item of a const aggregate the evaluator cannot take
cpp_agg_items_trace(_).
cpp_const_agg_type(T) :- catch(cpp_eval_agg_kind(T, _), _, fail), ccl_resolve_type(T, R), ( R = arr(_, ET) -> ccl_resolve_type(ET, base(Q, _)) ; R = base(Q, _) ), memberchk(const, Q).
cpp_plain_init('$cpp_walked'(X), _, '$cpp_walked'(X)) :- !.
cpp_plain_init(ctor([X]), _, X) :- !.
cpp_plain_init(ctor([]), T, Z) :- !, ( cpp_braced_scalar_type(T) -> cpp_zero_of(T, Z) ; Z = init([]) ).   % `int arr[9] = {}', `S s{}': an aggregate's empty list is value-initialization of every element (0.99: it had been the scalar zero, `sext i32 0 to [9 x i32]')
cpp_plain_init(init([item(_, X)]), T, X) :- cpp_braced_scalar_type(T), !.   % a braced SCALAR; a plain one-member struct, `S s = {7}', is the aggregate it looks like (0.99: it had been taken as its one item, `sext i32 7 to %struct.S')
cpp_plain_init(init([]), T, Z) :- cpp_braced_scalar_type(T), !, cpp_zero_of(T, Z).
cpp_plain_init(init(Items), T, init(Items1)) :- cpp_class_of_type(T, C), cpp_aggregate_class(C), cpp_agg_skip_bases(C, Items, Items1), Items1 \== Items, !.   % AN AGGREGATE WITH EMPTY BASES (0.121), below
cpp_plain_init(I, _, I).
%% A CLASS VALUE AS AN AGGREGATE'S ITEM converts to its member's or its element's scalar type through its conversion
%% function ([dcl.init.aggr]/4.2: the member is copy-initialized from the item; 0.168): `H h{[](int &x) { x = 7; }}'
%% over `struct H { void (*fp)(int &); }' takes the closure's invoker, where the closure's bytes reached the lowering
%% (`inttoptr %struct.lambda.1', which LLVM refused). The items are paired with the members by position, a nested list
%% with its own member or element; a list with a designator, or over a struct with an array member (whose brace
%% elision moves the positions), is left as it is, and so is a class with constructors, whose items are its
%% constructor's arguments. A local (cpp_decl_pieces), a global (cpp_vars), a braced return and a braced argument to a
%% plain struct or union parameter (cpp_copies_) ask it.
cpp_init_convs(T, init(Items), init(Items1)) :- once(ccl_resolve_type(T, R)), R = arr(_, ET), !, findall(item(D, V1), ( member(item(D, V), Items), once(cpp_init_conv(ET, V, V1)) ), Items1).
cpp_init_convs(T, init(Items), init(Items1)) :- once(ccl_resolve_type(T, RT)), ( RT = base(_, [struct(_, _)]) ; RT = base(_, [union(_, _)]) ), \+ ( cpp_class_of_type(T, C), \+ cpp_aggregate_class(C) ), \+ ( member(item(D, _), Items), D \== [], D \== none ),
    ccl_members_of(RT, Ms), findall(MT, member(member(MT, _, _), Ms), MTs), \+ ( member(MT, MTs), ccl_resolve_type(MT, arr(_, _)) ), !, cpp_init_convs_(MTs, Items, Items1).
cpp_init_convs(_, I, I).
cpp_init_convs_([MT|MTs], [item(D, V)|Is], [item(D, V1)|Is1]) :- !, once(cpp_init_conv(MT, V, V1)), cpp_init_convs_(MTs, Is, Is1).
cpp_init_convs_(_, Is, Is).
cpp_init_conv(MT, init(Is), V) :- !, cpp_init_convs(MT, init(Is), V).
cpp_init_conv(MT, V, V1) :- \+ cpp_class_of_type(MT, _), cpp_class_of_type_of(V, C), !, ( cpp_closure_constant(V, C, MT, Inv) -> V1 = addr(id(Inv)) ; cpp_conv_to(V, MT, V1) ).
cpp_init_conv(_, V, V).
%% A CAPTURELESS LAMBDA'S CONVERSION TO A POINTER TO FUNCTION is the address of its static invoker `lambda.K.fn', which
%% its conversion function returns (cpp_lambda_'s `Conv'): a constant, so an aggregate's item that is one calls nothing
%% at run time, and a global that holds one is constant-initialized, as clang has it (0.168)
cpp_closure_constant(compound_lit(_, init([])), C, MT, Inv) :- atom(C), atom_concat(C, '.fn', Inv), '$cpp_out'(Inv, function(_, _, _, Inv, _, _, _)), cpp_closure_class(C),
    once(ccl_resolve_type(MT, ptr(_, F))), once(ccl_resolve_type(F, fn(_, _, _))).
cpp_braced_scalar_type(T) :- \+ cpp_class_of_type(T, _), ( ccl_resolve_type(T, R) -> true ; R = T ),   % the resolver's FIRST answer (it has more on backtracking, and `R \= arr(_, _)' had backtracked into one that was not the array)
    R \= arr(_, _), R \= base(_, [struct(_, _)]), R \= base(_, [union(_, _)]), R \= base(_, [class(_, _, _, _)]), R \= base(_, [vec(_, _, _)]).   % a VECTOR's braced list is its lanes, the rest zero, as clang has it (0.162): `v4 a{5}' is {5, 0, 0, 0}, never the splat
cpp_zero_of(T, Z) :- ( ccl_resolve_type(T, ptr(_, _)) -> Z = nullptr ; ccl_nullptr_type(T) -> Z = nullptr ; ccl_is_float(T) -> Z = float(0.0) ; Z = int(0) ).
%% THE DEFAULT MEMBER INITIALIZERS of the aggregate's class come along (0.112): from the caller that knows the class
%% (cpp_member_from), else from the object's type; a member with no item takes its own ([dcl.init.aggr]/5.1)
cpp_aggregate_inits(Data0, Es0, Obj, L, Inits) :- ( cpp_agg_defaults(Obj, Defs0) -> Defs = Defs0 ; Defs = [] ),
    ( catch(( ccl_type_of(Obj, OT), cpp_class_of_type(OT, OC) ), _, fail) -> cpp_agg_skip_bases(OC, Es0, Es), cpp_agg_with_bases(OC, Data0, Data) ; Es = Es0, Data = Data0 ),
    cpp_agg_inits(Data, Es, Defs, Obj, L, Inits).
%% ... AND A BASE WITH STORAGE TAKES ITS ITEM BEFORE THE MEMBERS (0.127): the class record's data are its own members, the base
%% sub-objects `$base' and `$base$K' are the layout's (cpp_base_layout_), and the items were matched against the members alone --
%% `D d{}' of `struct D : Q { int b; }' never ran Q's constructor and `D d2{{}, 4}' gave b the base's `{}'
cpp_agg_with_bases(C, Data, Data1) :- \+ memberchk(member(_, '$base', _), Data), cpp_class_l(C, cls(B, _, _, _, _)), B \== none, \+ '$cpp_vbase'(C),
    catch(cpp_base_layout_(C, B, Data, Data1), _, fail), !.
cpp_agg_with_bases(_, Data, Data).
%% THE ITEMS A CLASS'S EMPTY BASES TAKE ([dcl.init.aggr]/4.2; 0.121): C++17 lets an aggregate have public bases, each initialized
%% from the next item of the list in order, before the members -- `overloaded o{ [](int) {...}, [](double) {...} }' over
%% `overloaded : Ts...' (the idiom of std::visit). A base with no sub-object (cpp_empty_class: a closure with no capture)
%% keeps no value, so its item is dropped here; a base with storage is the member `$base' / `$base$K', which the member
%% road below takes in place, its item where the order puts it.
cpp_agg_skip_bases(C, Es0, Es) :- cpp_direct_bases(C, Bs), Bs \== [], cpp_agg_skip(Bs, Es0, Es), !.
cpp_agg_skip_bases(_, Es, Es).
cpp_agg_skip([], Es, Es).
cpp_agg_skip([_|_], [], []) :- !.
cpp_agg_skip([B|Bs], [E|Es], Out) :- ( cpp_empty_class(B) -> Out = Out1 ; Out = [E|Out1] ), cpp_agg_skip(Bs, Es, Out1).
cpp_direct_bases(C, Bs) :- cpp_class_l(C, cls(B, _, _, _, _)), ( B == none -> Bs0 = [] ; Bs0 = [B] ), ( '$cpp_extra'(C, Ex) -> true ; Ex = [] ), append(Bs0, Ex, Bs).
cpp_agg_defaults(Obj, Defs) :- catch(( ccl_type_of(Obj, T), cpp_class_of_type(T, C), cpp_class_l(C, cls(_, _, _, Defs, _)) ), _, fail).
cpp_agg_inits([], _, _, _, _, []).
cpp_agg_inits([member(_, '$vptr', _)|Ds], Es, Defs, Obj, L, Inits) :- !, cpp_agg_inits(Ds, Es, Defs, Obj, L, Inits).
%% FEWER ITEMS THAN MEMBERS: the rest are VALUE-INITIALIZED ([dcl.init.aggr]/5) -- an array zeroed, a class default-
%% constructed, a scalar zero -- where they were left as garbage; `Grid2 g2{}' names nothing and gets all three
cpp_agg_inits([member(MT, M, _)|Ds], [], Defs, Obj, L, Inits) :- !,
    cpp_agg_no_item(MT, M, Defs, Obj, L, Inits, Inits1), cpp_agg_inits(Ds, [], Defs, Obj, L, Inits1).
cpp_agg_inits([member(MT, M, _)|Ds], ['$no_item'|Es], Defs, Obj, L, Inits) :- !,   % a member a designated list skips (cpp_agg_values)
    cpp_agg_no_item(MT, M, Defs, Obj, L, Inits, Inits1), cpp_agg_inits(Ds, Es, Defs, Obj, L, Inits1).
cpp_agg_inits([member(MT, M, _)|Ds], ['$anon_item'(F, V)|Es], Defs, Obj, L, Inits) :- !,   % a member of an anonymous union named by a designator: that member, through the union (cpp_agg_slots)
    cpp_anon_field(MT, F, FT), cpp_member_from(FT, member(member(Obj, M), F), V, L, Inits, Inits1), cpp_agg_inits(Ds, Es, Defs, Obj, L, Inits1).
%% BRACE ELISION ([dcl.init.aggr]/15): an ARRAY member whose item is no braced list of its own takes as
%% many of the items that FOLLOW as it has elements. `std::array<int, 4> a = {1, 2, 3, 4}' is the struct
%% `{ int __elems_[4]; }' -- ONE member and four items -- and libc++ writes every `std::array' so. The
%% guard is that more items than members REMAIN, which is what tells this from 0.84's array member taken
%% from an array VALUE (`S s = {arr}': one item, one member, and its bytes are meant).
cpp_agg_inits([member(MT, M, _)|Ds], [E|Es], Defs, Obj, L, Inits) :- E \= init(_), E \== '$no_item',
    ccl_resolve_type(MT, arr(B, ET)), catch(ccl_const_eval(B, K), _, fail), K >= 1,
    ( K > 1, length(Ds, ND), length(Es, NE), NE > ND -> true ; ccl_elided_item(E, ET) ), !,   % ... or the item is a SCALAR for an array of scalars, never the array's value (0.164)
    cpp_elide_take(K, [E|Es], Take, Rest), findall(item(none, V), member(V, Take), Items),
    cpp_member_from(MT, member(Obj, M), init(Items), L, Inits, Inits1), cpp_agg_inits(Ds, Rest, Defs, Obj, L, Inits1).
cpp_agg_inits([member(MT, M, _)|Ds], [E|Es], Defs, Obj, L, Inits) :- cpp_member_from(MT, member(Obj, M), E, L, Inits, Inits1), cpp_agg_inits(Ds, Es, Defs, Obj, L, Inits1).
%% a member with no item takes its DEFAULT MEMBER INITIALIZER ([dcl.init.aggr]/5.1; 0.112): libc++'s `__code_point<char>'
%% writes `char __data[4] = {' '}', std::format's fill; else it is value-initialized
cpp_agg_no_item(MT, M, Defs, Obj, L, Inits, Inits1) :-
    (   memberchk(M-D, Defs) -> cpp_member_from(MT, member(Obj, M), D, L, Inits, Inits1)
    ;   cpp_value_init(MT, member(Obj, M), L, Inits, Inits1) ).
%% A DESIGNATED LIST IS MADE POSITIONAL over the class's data members ([dcl.init.aggr]/3.1; 0.112): `.f = v' at f's
%% place, an item without a designator at the next one, a member the list skips the hole `'$no_item'', trailing holes
%% dropped. A list without designators is as written. Why: the values were taken in order with their designators
%% dropped, so `F l{.b_ = true}' set the FIRST member (`aggconst.cpp').
cpp_agg_values(Data, Items, Vs) :- member(item(Ds, _), Items), Ds \== [], Ds \== none, cpp_agg_slots(Items, Data, 0, [], Slots), !,
    findall(I, member(I-_, Slots), Is), max_list(Is, Max), cpp_agg_holes(0, Max, Slots, Vs).
cpp_agg_values(_, Items, Vs) :- findall(V, member(item(_, V), Items), Vs).
cpp_agg_holes(I, Max, _, []) :- I > Max, !.
cpp_agg_holes(I, Max, Slots, [V|Vs]) :- ( memberchk(I-V0, Slots) -> V = V0 ; V = '$no_item' ), I1 is I + 1, cpp_agg_holes(I1, Max, Slots, Vs).
cpp_designated(Items) :- member(item(Ds, _), Items), Ds \== [], Ds \== none, !.
%% A DESIGNATED TEMPORARY OF AN AGGREGATE CLASS, `T{.a = 1}' (0.112): built member by member over its zero bytes
%% (cpp_aggregate_inits: a hole from its default member initializer or value-initialized, a member that constructs
%% through its constructors), destroyed with the statement where the class has a destructor, or elided into what it
%% initializes (cpp_temp_elide), as cpp_temporary's own aggregate road
cpp_agg_temp(T, C, Data, Vs, stmt_expr(block(Ss))) :-
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), cpp_aggregate_inits(Data, Vs, id(Tmp), 0, Inits0),
    cpp_zero_stmts(0, T, id(Tmp), Inits, Inits0),
    (   cpp_dtor(C, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts) -> nb_getval('$cpp_temps', Ts1), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts1]), Ss0 = Inits
    ;   Ss0 = [declaration(0, none, T, [var(Tmp, T, none)])|Inits] ),
    append(Ss0, [expr(0, id(Tmp))], Ss).
cpp_elide_take(0, Es, [], Es) :- !.
cpp_elide_take(_, [], [], []) :- !.
cpp_elide_take(K, [E|Es], [E|Take], Rest) :- K1 is K - 1, cpp_elide_take(K1, Es, Take, Rest).
%% ONE MEMBER FROM ITS ITEM: an array from a nested braced list element by element (the rest zero) or from an array
%% value as its bytes; a nested aggregate from its own braced list; a class with constructors through them (the
%% initializer_list one first); a scalar assigned
cpp_member_from(MT, Place, init(Items), L, [expr(L, call(id(memset), [addr(Place), int(0), sizeof_type(MT)]))|Inits], Rest) :- ccl_resolve_type(MT, arr(_, ET)), !,
    findall(V, member(item(_, V), Items), Vs), cpp_array_items(Vs, 0, ET, Place, L, Inits, Rest).
cpp_member_from(MT, Place, init(Items), L, Inits, Rest) :- cpp_class_of_type(MT, MC), cpp_aggregate_class(MC), !,
    cpp_class_l(MC, cls(_, Data, _, Defs, _)), cpp_agg_values(Data, Items, Vs), cpp_agg_inits(Data, Vs, Defs, Place, L, Sub), append(Sub, Rest, Inits).
cpp_member_from(MT, Place, init([]), L, Inits, Rest) :- cpp_class_of_type(MT, MC), cpp_has_ctors(MC), cpp_trivial_default(MC), !, cpp_zero_fill(MT, Place, L, Inits, Rest).   % `m{}' OF A CLASS WHOSE DEFAULT CONSTRUCTOR IS DEFAULTED AND HAS NOTHING TO DO is value-initialized, its bytes zero ([dcl.init.list]/3.5, [dcl.init]/8; 0.201): the constructor road named an implicit constructor that is never made -- <mdspan>'s `__extents_{}' -- and an empty class's byte is no byte to write (cpp_zero_fill)
cpp_member_from(MT, Place, init(Items), L, [S|Rest], Rest) :- cpp_class_of_type(MT, MC), cpp_has_ctors(MC), !,
    ( cpp_il_ctor_for(MC, Items, ET) -> cpp_init_list(ET, Items, IL), Args = [IL] ; findall(V, member(item(_, V), Items), Args) ),
    length(Args, NA), ( cpp_ctor(MC, Args, CName) -> true ; cpp_refuse(L, member_not_constructed(MC, NA)) ), cpp_fill_defaults(CName, Args, Args1), S = expr(L, call(id(CName), [addr(Place)|Args1])).
%% A PRVALUE OF THE MEMBER'S OWN CLASS IS CONSTRUCTED IN THE MEMBER ([dcl.init.aggr]/4.2, [class.copy.elision]/1, C++17; 0.121): `Wrap<S>{S(9)}' runs S's constructor once, over the member's address -- no copy or
%% move constructor runs for it (it moved, and a program that counts its moves printed one more than C++17 does). The constructor call that built the temporary (cpp_temporary) is retargeted from the temporary to the
%% member and the temporary is no more (cpp_prvalue_in_place): the object is never moved, so a class that holds its own address (std::list's sentinel, std::function's small buffer) stays whole -- a bitwise copy of
%% the temporary was this rule's first form, and `Wrap<std::list<int>>{std::list<int>{1, 2}}' freed an invalid pointer. A call that returns the class keeps the constructor road below.
cpp_member_from(MT, Place, E, L, [S|Rest], Rest) :- E \= init(_), cpp_class_of_type(MT, MC), cpp_class_of_type_of(E, MC), cpp_prvalue_in_place(E, Place, S), !.   % an aggregate class's too (0.206)
cpp_member_from(MT, Place, E, L, [S|Rest], Rest) :- cpp_class_of_type(MT, MC), cpp_has_ctors(MC), !,
    ( cpp_ctor(MC, [E], CName) -> true ; cpp_refuse(L, member_not_constructed(MC, 1)) ), cpp_fill_defaults(CName, [E], Args), S = expr(L, call(id(CName), [addr(Place)|Args])).
cpp_member_from(MT, Place, E0, L, Inits, Rest) :- ccl_resolve_type(MT, arr(B, ET)), !, ( E0 = move(E) -> true ; E = E0 ),
    (   cpp_elem_class(ET, EC), cpp_has_ctors(EC)                                                   % an array of objects: element by element, through their constructors
    ->  cpp_array_bound_n(arr(B, ET), N), N1 is N - 1, cpp_array_elems(0, N1, ET, Place, E0, L, Inits, Rest)
    ;   Inits = [expr(L, call(id(memcpy), [addr(Place), addr(E), sizeof_type(MT)]))|Rest] ).
cpp_member_from(ref(_, _), Place, E0, L, [expr(L, bind_ref(Place, E))|Rest], Rest) :- !, ( E0 = init([item(_, E1)]) -> E = E1 ; E = E0 ).   % A REFERENCE MEMBER IS BOUND, never assigned (0.61's rule, here for an aggregate's member: a closure's reference capture)
cpp_member_from(MT, Place, init([]), L, Inits, Rest) :- cpp_scalar_member_type(MT), !, cpp_value_init(MT, Place, L, Inits, Rest).   % a scalar from `{}': its zero
cpp_member_from(MT, Place, init([item(_, X)]), L, [expr(L, assign('=', Place, X))|Rest], Rest) :- cpp_scalar_member_type(MT), !.   % a scalar from `{v}': its one item (0.112: `uint16_t __sign_ : 1 {false}' was assigned the braced list)
cpp_member_from(MT, Place, init(Items), L, [expr(L, assign('=', Place, compound_lit(MT, init(Items))))|Rest], Rest) :- ( cpp_plain_aggregate(MT) ; cpp_vector_member(MT) ), !.   % A PLAIN STRUCT OR UNION MEMBER from a braced list (0.117) is a compound literal of its type, assigned: `__libcpp_mutex_t __m_ = PTHREAD_MUTEX_INITIALIZER' is `{ { 0, 0, 0, 0, PTHREAD_MUTEX_TIMED_NP, 0, 0, { 0, 0 } } }' over glibc's union, and `std::mutex' reached the lowering as a bare braced expression
cpp_member_from(_, Place, E, L, [expr(L, assign('=', Place, E))|Rest], Rest).
cpp_plain_aggregate(MT) :- \+ cpp_class_of_type(MT, _), ccl_resolve_type(MT, base(_, [S])), compound(S), ( S = struct(_, _) ; S = union(_, _) ), !.
%% a member of a VECTOR type, resolved in the class's words: its braced list is its lanes, the rest zero (0.162: `v4 r{7};'
%% is {7, 0, 0, 0} as clang has it, and it reached the lowering as a bare braced expression)
cpp_vector_member(MT) :- ( ccl_resolve_type(MT, base(_, [vec(_, _, _)])) -> true ; catch(( cpp_type(MT, T), ccl_resolve_type(T, base(_, [vec(_, _, _)])) ), _, fail) ), !.
cpp_elems_from(I, K1, _, _, _, _, Inits, Inits) :- I > K1, !.
cpp_elems_from(I, K1, ET, Arr, Es, L, Inits, Rest) :- Place = index(Arr, int(I)),
    ( Es = [E|Es1] -> cpp_elem_from(ET, Place, E, L, Inits, Inits1) ; Es1 = [], cpp_value_init(ET, Place, L, Inits, Inits1) ),
    I1 is I + 1, cpp_elems_from(I1, K1, ET, Arr, Es1, L, Inits1, Rest).
%% A LOCAL ARRAY WHOSE ELEMENT'S CONSTRUCTION THROWS DESTROYS THE ELEMENTS BUILT, the last first ([except.ctor]/3,
%% [dcl.init.aggr]/9; 0.201): each element built is followed by its destructor as a cleanup that only the unwinding runs
%% (eh_cleanup, the lowering's eh_only defer), the elements' construction a block of its own, so that the cleanups end
%% with it and the array's defer at the scope's end takes over -- `T arr[5];' over a constructor that throws at the
%% fourth left three elements built. A static local array's alike, under its guard (cpp_guard_abort/4).
cpp_elems_unwind(I, K1, _, _, _, _, Inits, Inits) :- I > K1, !.
cpp_elems_unwind(I, K1, ET, Arr, Es, L, Inits, Rest) :- Place = index(Arr, int(I)),
    ( Es = [E|Es1] -> cpp_elem_from(ET, Place, E, L, Inits, Inits1) ; Es1 = [], cpp_value_init(ET, Place, L, Inits, Inits1) ),
    ( cpp_member_dtor(ET, Place, L, Ds), Ds \== [] -> Inits1 = [eh_cleanup(L, block(Ds))|Inits2] ; Inits2 = Inits1 ),
    I1 is I + 1, cpp_elems_unwind(I1, K1, ET, Arr, Es1, L, Inits2, Rest).
cpp_elem_from(ET, Place, E, _, [S|Rest], Rest) :-   % A PRVALUE OF THE ELEMENT'S CLASS IS BUILT IN THE ELEMENT (0.206; [dcl.init.aggr]/4.2, [class.copy.elision]/1), as a member's is: it was its temporary's bytes, and a list's sentinel pointed into it
    cpp_class_of_type(ET, C), cpp_class_of_type_of(E, C), \+ cpp_lvalue(E), \+ ( E = move(X), cpp_lvalue(X) ), cpp_prvalue_in_place(E, Place, S), !.
cpp_elem_from(ET, Place, E, L, [expr(L, assign('=', Place, E1))|Rest], Rest) :-
    cpp_class_of_type(ET, C), cpp_class_of_type_of(E, C), \+ cpp_lvalue(E), \+ ( E = move(X), cpp_lvalue(X) ), !, cpp_temp_elide(E, E1).
cpp_elem_from(ET, Place, E, L, Inits, Rest) :- cpp_member_from(ET, Place, E, L, Inits, Rest).
cpp_array_items([], _, _, _, _, Inits, Inits).
cpp_array_items([V|Vs], I, ET, Place, L, Inits, Rest) :- cpp_elem_from(ET, index(Place, int(I)), V, L, Inits, Inits1), I1 is I + 1, cpp_array_items(Vs, I1, ET, Place, L, Inits1, Rest).   % an element that is a prvalue of its class is the element ([dcl.init.aggr]/4.2, C++17's elision), also in a nested list: `N g[2][2] = {{N(1), N(2)}, {N(3), N(4)}}' destroyed four temporaries at once (0.117)
cpp_array_elems(I, N1, _, _, _, _, Inits, Inits) :- I > N1, !.
cpp_array_elems(I, N1, ET, Place, Src0, L, Inits, Rest) :- ( Src0 = move(Src) -> SrcI = move(index(Src, int(I))) ; SrcI = index(Src0, int(I)) ),
    cpp_member_from(ET, index(Place, int(I)), SrcI, L, Inits, Inits1), I1 is I + 1, cpp_array_elems(I1, N1, ET, Place, Src0, L, Inits1, Rest).
%% VALUE-INITIALIZATION of one member ([dcl.init]/8): a class with constructors through its default one, one whose
%% default constructor is not user-provided zero-filled, an array of objects element by element, else zero
cpp_value_init(MT, _, _, Inits, Inits) :- ( MT = ref(_, _) ; MT = rref(_, _) ), !.
cpp_value_init(MT, Place, L, Inits, Rest) :- ccl_resolve_type(MT, arr(B, ET)), cpp_elem_class(ET, EC), cpp_has_ctors(EC), !,
    cpp_array_bound_n(arr(B, ET), N), N1 is N - 1, findall(I, between(0, N1, I), Is), cpp_value_inits(Is, ET, Place, L, Inits, Rest).
cpp_value_init(MT, Place, L, Inits, Rest) :- cpp_class_of_type(MT, MC), cpp_has_ctors(MC), !,
    (   cpp_ctor(MC, [], CName) -> cpp_fill_defaults(CName, [], Args), S = expr(L, call(id(CName), [addr(Place)|Args])),
        ( cpp_value_zeroes(MC) -> cpp_zero_stmts(L, MT, Place, Inits, [S|Rest]) ; Inits = [S|Rest] )   % zeroed before an implicit constructor (0.127)
    ;   cpp_trivial_default(MC) -> cpp_zero_fill(MT, Place, L, Inits, Rest)   % an empty class's byte is no byte to write (0.201): a `[[no_unique_address]]' member of one owns no byte, and a memset of it wrote over the member that shares its address
    ;   cpp_refuse(L, member_not_constructed(MC, 0)) ).
cpp_value_init(MT, Place, L, Inits, Rest) :- cpp_class_of_type(MT, MC), cpp_empty_class(MC), !, cpp_zero_fill(MT, Place, L, Inits, Rest).
cpp_value_init(MT, Place, L, Inits, Rest) :-
    ( \+ ccl_resolve_type(MT, arr(_, _)), cpp_scalar_type(MT) -> cpp_zero_of(MT, Z), Inits = [expr(L, assign('=', Place, Z))|Rest] ; cpp_zero_stmts(L, MT, Place, Inits, Rest) ).
cpp_value_inits([], _, _, _, Inits, Inits).
cpp_value_inits([I|Is], ET, Place, L, Inits, Rest) :- cpp_value_init(ET, index(Place, int(I)), L, Inits, Inits1), cpp_value_inits(Is, ET, Place, L, Inits1, Rest).
%% A CLASS WITH NO BYTES OF ITS OWN IS ZERO-FILLED BY NOTHING, and copied by nothing: it holds no state, its one
%% byte ([class]/4, since 0.89) is PADDING as a complete object, and as a `[[no_unique_address]]' member it owns no
%% byte at all -- its address may be one past its holder's own bytes. libc++'s basic_string writes `: __alloc_()'
%% over a marked allocator, and a `memset' of sizeof -- zero before 0.89 and one after -- wrote that byte OUTSIDE
%% the string: `a + ", "' came back empty and `substr' aborted on out_of_range.
cpp_zero_fill(MT, _, _, Ss, Ss) :- cpp_class_of_type(MT, MC), cpp_empty_class(MC), !.
cpp_zero_fill(MT, Place, L, Ss, Rest) :- cpp_zero_stmts(L, MT, Place, Ss, Rest).
%% the bytes of Place zeroed, then, for a type that holds a pointer to a data member, its zero stored over them (0.161; cpp_zero_not_null/3)
cpp_zero_stmts(L, MT, Place, [expr(L, call(id(memset), [addr(Place), int(0), sizeof_type(MT)]))|Ss0], Ss) :-
    ( cpp_zero_not_null(MT, Place, expr(_, Null)) -> Ss0 = [expr(L, Null)|Ss] ; Ss0 = Ss ).
%% AN INITIALIZER ALREADY WALKED, marked by the `auto' clause above: the pieces must not walk it a second time --
%% a statement expression that builds a temporary would have its declaration desugared again and the temporary
%% constructed twice (`no_constructor(C, 0)' where the second walk found it bare), and a lambda would make a
%% second closure class for nothing.
cpp_ctor_args(_, '$cpp_walked'(E), _, [E]) :- !.
cpp_ctor_args(_, none, _, []) :- !.
cpp_ctor_args(Ctx, ctor(As), _, As1) :- !, cpp_exprs(Ctx, As, As1).
cpp_ctor_args(Ctx, init(Items), C, [IL]) :- cpp_il_ctor_for(C, Items, ET), !, cpp_init_list(Ctx, ET, Items, IL).   % the initializer_list constructor first
cpp_ctor_args(Ctx, init(Items), _, As1) :- !, findall(E, member(item(_, E), Items), As), cpp_exprs(Ctx, As, As1).
cpp_ctor_args(Ctx, E, C, [E2]) :- cpp_expr(Ctx, E, E10), cpp_xvalue_move(E10, E1),
    (   \+ cpp_class_of_type_of(E1, C) -> E2 = E1
    ;   cpp_lvalue(E1), cpp_copy_ctor(C, ref) -> E2 = E1                                          % a copy, through the copy constructor
    ;   E1 = move(X), cpp_lvalue(X), cpp_copy_ctor(C, rref) -> E2 = E1                            % a move, through the move constructor: the MOVE KEPT, by which cpp_ctor chooses it (cpp_ref_args_of passes the address) -- stripped here, `M b = std::move(a)' chose the COPY constructor for the plain lvalue left (0.112)
    ;   cpp_lvalue(E1), \+ cpp_written_copy_ctor(C), cpp_implicit_copy_here(C), \+ cpp_holds_owners(base([], [typedef(C)])), cpp_implicit_copy_ctor(C, copy, _) -> E2 = E1   % THE IMPLICIT COPY, made on demand ([class.copy.ctor]) for a local of THE PROGRAM'S OWN class: `Grid2 g4 = g3' over a promoted struct; never for a class holding owners, whose copy the safe part refuses below; for a LIBRARY class only where it has a destructor (cpp_implicit_copy_here/1, 0.201), whose copy is never bitwise -- any other comes through its own lazy road (made here, basic_string's `__rep' got a copy constructor while its union had not been emitted: a load of `[0 x i8]'); and asked of the WRITTEN copy and move constructors, never the implicit ones made already (0.201: the implicit copy made first kept the implicit move from being made, and the reverse)
    ;   E1 = move(X), cpp_lvalue(X), \+ cpp_written_copy_ctor(C), cpp_implicit_copy_here(C), \+ cpp_holds_owners(base([], [typedef(C)])), cpp_implicit_rvalue_kind(C, K), cpp_implicit_copy_ctor(C, K, _) -> ( K == move -> E2 = E1 ; E2 = X )   % ... and the implicit move, or the copy where the class declares no implicit move ([class.copy.ctor]/8, cpp_implicit_rvalue_kind/2)
    ;   \+ cpp_lvalue(E1), \+ ( E1 = move(X1), cpp_lvalue(X1) ) -> E2 = E1                     % A PRVALUE IS THE OBJECT (C++17 elides the copy), the caller's elision takes it -- where this FAILED, after its walk had registered the initializer's temporaries, and the caller walked it again: `Tag t = plus(Tag(1), 5)' destroyed a second, never-built temporary (0.112)
    ;   fail ).                                                                                    % an lvalue with no copy constructor is refused below
%% AN XVALUE NAMES AN OBJECT, as `std::move(x)' does ([basic.lval]): `static_cast<T &&>(x)' over an lvalue is the move
%% node for the constructor's choice (0.112) -- read as a prvalue it was elided, the local made the bytes of x, and a
%% vector so initialized freed its buffer twice
cpp_xvalue_move(ccast(_, rref(_, _), X), move(X)) :- cpp_lvalue(X), !.
cpp_xvalue_move(E, E).
%% A LIBRARY CLASS TAKES ITS IMPLICIT COPY HERE where it has a destructor (0.201): such a class never copies bitwise, and
%% <regex>'s `std::__state<_CharT>' -- a struct with a written default constructor and vector members, no copy
%% constructor -- was refused `copy_of_a_class_with_destructor' at `__state __snext = __s;'. Any other library class's
%% special members come through its own lazy road, as before.
cpp_implicit_copy_here(C) :- \+ cpp_lib_class(C), !.
cpp_implicit_copy_here(C) :- cpp_dtor(C, _).
%% a constructor from the class itself: Kind ref for `C(const C &)', rref for `C(C &&)'
cpp_copy_ctor(C, Kind) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, [P], _, _), Ms), ( P = param(RT, _) ; P = param(RT, _, _) ), RT =.. [Kind, _, base(_, [typedef(C)])], !.
cpp_copy_ctor(C, K) :- '$cpp_implicit_copy'(C, Kind, _), ( Kind == copy -> K = ref ; K = rref ).   % the implicit one, once made (cpp_implicit_copy_ctor)
cpp_copy_ctor(C, K) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, [P], _, _), Ms), cpp_named_self(C, P, K), !.   % ... and one whose parameter names the class otherwise than by its plain name (0.198, cpp_named_self/3)
%% a copy or move constructor the class WRITES (0.201), never an implicit one made already: the implicit copy and the
%% implicit move are made apart, and the one made first must not stand for the other
cpp_written_copy_ctor(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, Ps, _, _), Ms), cpp_copy_or_move(C, Ps), !.
%% THE CONSTRUCTOR AN RVALUE OF THE CLASS TAKES where the class writes neither ([class.copy.ctor]/8; 0.201): the implicit
%% move, unless the class declares a copy constructor, a copy or move assignment or a destructor, where no implicit move
%% is declared and the rvalue takes the copy -- it was the move whatever the class declared
cpp_implicit_rvalue_kind(C, K) :- ( catch(cpp_move_kind(C, none), _, fail) -> K = copy ; K = move ).
%% a by-value parameter of a class with a destructor takes a copy: the copy constructor's, in a temporary the callee owns
cpp_copies(call(id(Name), Args), call(id(Name), Args1)) :- ccl_declared(Name, fn(_, Ps, _)), !, cpp_copies_(Ps, Args, Args1).
cpp_copies(call(F, Args), call(F, Args1)) :- Args \== [], cpp_callee_params(F, Ps), !, cpp_copies_(Ps, Args, Args1).   % a call through a pointer or a reference to function takes the copy pass by the FUNCTION TYPE (cpp_callee_params)
cpp_copies(E, E).
cpp_copies_([], As, As).
cpp_copies_(_, [], []).
%% A BRACED ARGUMENT TO A SCALAR PARAMETER is its one item, or the type's zero when empty ([dcl.init.list]/3; 0.93):
%% `int p = {}' is how libc++'s ranges write a defaulted count or predicate at C++20, and as an argument `init([])'
%% reached the lowering as an aggregate of nothing -- garbage where C++ has 0
cpp_copies_([P|Ps], [init(Items)|As], [A1|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), cpp_scalar_braced(PT, Items, A1), !, cpp_copies_(Ps, As, Bs).
cpp_copies_([P|Ps], [init(Items)|As], [A1|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), cpp_param_takes_class(PT, C), !,   % A BRACED ARGUMENT to a class-typed parameter list-initializes a temporary of the class ([over.ics.list]): `m.insert({4, 40})' builds the pair; an initializer_list<T> the compiler alone can build (not done)
    findall(E, member(item(_, E), Items), Es),
    (   '$cpp_inst'(C, inst(initializer_list, [ET])) -> cpp_init_list(ET, Items, A10)
    ;   cpp_il_braced(C, Items, ET2) -> cpp_init_list(ET2, Items, IL), cpp_temporary(base([], [typedef(C)]), C, [IL], A10)   % a class WITH an initializer_list constructor takes the braced argument through it first ([over.match.list]; 0.117): `f({"a", "b"})' over a vector<string>
    ;   cpp_temporary(base([], [typedef(C)]), C, Es, A10) ),
    ( cpp_param_ref(PT, PTr), PTr \= ref(_, _), PTr \= rref(_, _) -> cpp_byval_arg(C, A10, A1) ; A1 = A10 ),   % BY VALUE THE TEMPORARY IS THE PARAMETER (0.206), the caller's to destroy (0.207, cpp_byval_arg/3): `g({5, 6})' over `int g(std::vector<int>)' freed the buffer twice when the callee destroyed it too
    cpp_copies_(Ps, As, Bs).
%% A BRACED ARGUMENT TO A PLAIN STRUCT OR UNION PARAMETER, by value or bound to a reference to const, is a compound
%% literal of its type ([dcl.init.list]/3.4, [over.ics.list]; 0.168), its class items converted to its scalar members:
%% `sum({3, 4})' over `int sum(P)' reached the lowering as a bare braced list
%% A BRACED ARGUMENT TO A REFERENCE TO AN ARRAY OF SCALARS binds a temporary array of its items ([dcl.init.list]/3.10,
%% [dcl.init.ref]/5.3; 0.206): `std::to_array({7, 8, 9})' over `to_array(_Tp (&&)[_Size])' reached the lowering as a bare
%% braced list
cpp_copies_([P|Ps], [init(Items)|As], [A1|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), ( PT = ref(_, AT0) ; PT = rref(_, AT0) ), catch(ccl_resolve_type(AT0, arr(_, ET0)), _, fail), catch(cpp_type(ET0, ET), _, fail), \+ cpp_elem_class(ET, _), !,
    length(Items, N), AT = arr(int(N), ET), ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, AT),
    A1 = stmt_expr(block([declaration(0, none, AT, [var(Tmp, AT, init(Items))]), expr(0, id(Tmp))])), cpp_copies_(Ps, As, Bs).
%% ... AND ONE TO A REFERENCE TO AN ARRAY OF OBJECTS a temporary array of objects (0.208; cpp_obj_array/5, an initializer_list's
%% array's road): each element built in place from its item, in order, and destroyed at the end of the full-expression, the last
%% first -- `std::to_array<std::string>({"x", "yy"})' was refused, `not lowered yet: expr(init(...))'
cpp_copies_([P|Ps], [init(Items)|As], [stmt_expr(block(Ss))|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), ( PT = ref(_, AT0) ; PT = rref(_, AT0) ), catch(ccl_resolve_type(AT0, arr(_, ET0)), _, fail),
    catch(cpp_type(ET0, ET), _, fail), cpp_elem_class(ET, EC), ( cpp_has_ctors(EC) ; cpp_dtor(EC, _) ), ccl_global('$cpp_temps', Ts, none), is_list(Ts), !,   % the element's type as the desugaring names it: a declared `std::string (&&)[2]' holds the written name
    findall(E2, ( member(item(_, E1), Items), once(cpp_il_item(ET, E1, E2)) ), Es), cpp_obj_array(ET, Es, Arr, _, Ss0), append(Ss0, [expr(0, id(Arr))], Ss), cpp_copies_(Ps, As, Bs).
cpp_copies_([P|Ps], [init(Items)|As], [compound_lit(ST, I1)|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), cpp_plain_struct_param(PT, ST), !,
    cpp_init_convs(ST, init(Items), I1), cpp_copies_(Ps, As, Bs).
cpp_copies_([P|Ps], [A|As], [A1|Bs]) :-
    ( P = param(PT, _) ; P = param(PT, _, _) ), !,
    (   cpp_param_ref(PT, PTr), ( PTr = ref(_, _) ; PTr = rref(_, _) ), cpp_dtor_prvalue(A, T, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts)   % A CLASS PRVALUE BOUND TO A REFERENCE PARAMETER is a temporary of the statement, destroyed at its end ([class.temporary]/4; 0.197): the slot the lowering materialized for it was never destroyed, `cref(make(1))' ran no `~V' and a string it held leaked
    ->  ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts]), A1 = stmt_expr(block([expr(0, assign('=', id(Tmp), A)), expr(0, id(Tmp))]))
    ;   cpp_param_takes_class(PT, C), ccl_type_of(A, AT), AT \== unknown, \+ cpp_class_of_type_of(A, C), \+ cpp_arg_derives(A, C), cpp_converting_ctor(C, A)   % the argument's type KNOWN and not the parameter's own class: what cannot be typed is never converted -- nor A DERIVED CLASS's (0.201), which binds its base sub-object ([dcl.init.ref]/5.1.1) and copies by its base's copy (the slicing below): a base's converting template that takes it, `template <class U> Al(const Al<U> &)', built a temporary from it whose constructor's parameter took it again, without end (scoped_allocator_adaptor)
    ->  cpp_temporary(base([], [typedef(C)]), C, [A], A10),                                   % A CONVERTING CONSTRUCTOR at a call: libc++ hands a `__long' where a `__rep' is wanted, and `__rep(__long)' is how a string becomes long
        ( cpp_param_ref(PT, PTr), PTr \= ref(_, _), PTr \= rref(_, _) -> cpp_byval_arg(C, A10, A1) ; A1 = A10 )   % ... and BY VALUE the temporary IS the parameter ([class.copy.elision]/1; 0.112), the caller's to destroy (0.207, cpp_byval_arg/3)
    ;   cpp_class_of_type(PT, C), cpp_ret_constructs(C), A = move(X), cpp_lvalue(X), cpp_copy_ctor(C, _)   % (a class with a copy or a move constructor of its own too, 0.197: its effects were lost to a bitwise copy) `f(std::move(s))' with `f(string)': the MOVE constructor into the callee's copy, else the copy one over the object; a class with NEITHER (Cicili's own, over own pointers) keeps the lowering's move, which nulls the source's owners
    ->  ( cpp_copy_ctor(C, rref) -> cpp_move_temp(C, X, A01) ; cpp_copy_temp(C, X, A01) ), cpp_byval_arg(C, A01, A1)
    ;   cpp_class_of_type(PT, C), cpp_ret_constructs(C), cpp_xvalue_arg(A, X), cpp_copy_ctor(C, _)   % AN XVALUE NAMES ITS OBJECT AS `std::move(x)' does ([basic.lval], [dcl.init]/17.6.2; 0.201): `static_cast<R &&>(x)', and `std::forward<R>(x)', a call declared to return `R &&', which libc++'s std::invoke and std::thread hand a by-value parameter: the callee's copy is MOVE-constructed from it, where it was the object itself, bitwise, and destroyed with the caller's own -- a stop_token's shared state freed early, every std::jthread whose function takes one
    ->  ( cpp_copy_ctor(C, rref) -> cpp_move_temp(C, X, A01) ; cpp_copy_temp(C, X, A01) ), cpp_byval_arg(C, A01, A1)
    ;   cpp_class_of_type(PT, C), cpp_ret_constructs(C), cpp_lvalue(A)
    ->  ( cpp_copy_ctor(C, ref) -> cpp_copy_temp(C, A, A01), cpp_byval_arg(C, A01, A1) ; cpp_refuse(0, class_with_destructor_by_value(C)) )
    ;   cpp_class_of_type(PT, C), cpp_class_of_type_of(A, D), D \== C, cpp_base_hops(D, C, Hops)   % A DERIVED OBJECT WHERE ITS BASE IS TAKEN BY VALUE is SLICED to the base sub-object ([conv.ptr]/[class.copy]): libc++'s `__priority_tag<1>()' handed to the `__priority_tag<0>' fallback of __try_key_extraction_impl
    ->  (   A = compound_lit(_, init([])) -> A1 = compound_lit(base([], [typedef(C)]), init([]))
        ;   Hops == []                                                                        % ... AND WITH NO HOPS every base on the path is EMPTY (0.89's rule: such a base has no sub-object, so the object IS it): the value carries nothing but its TYPE must still be the base's, and the guard `Hops \== []' left `__priority_tag<1>' where `__priority_tag<0>' was wanted -- LLVM refused the store. The evaluation is kept beside the base's own empty aggregate, since A may have effects.
        ->  A1 = comma(A, compound_lit(base([], [typedef(C)]), init([])))
        ;   cpp_hops(A, Hops, A1) )
    ;   cpp_class_of_type(PT, C) -> cpp_byval_arg(C, A, A1)                                   % a prvalue IS the parameter, the caller's to destroy (0.207)
    ;   A1 = A ),
    cpp_copies_(Ps, As, Bs).
cpp_copies_([_|Ps], [A|As], [A|Bs]) :- cpp_copies_(Ps, As, Bs).
cpp_xvalue_arg(ccast(_, rref(_, _), X), X) :- cpp_lvalue(X), !.   % the object an xvalue names: a cast's lvalue operand, else the xvalue itself, whose reference the constructor's parameter binds
cpp_xvalue_arg(A, A) :- A \= move(_), cpp_xvalue_object(A), !.
cpp_dtor_prvalue(call(id(F), _), base([], [typedef(C)]), Dtor) :- atom(F), ccl_declared(F, fn(R, _, _)), \+ R = ref(_, _), \+ R = rref(_, _), cpp_class_of_type(R, C), cpp_dtor(C, Dtor), !.
%% THE ARGUMENT OF A BY-VALUE PARAMETER OF A CLASS WITH A DESTRUCTOR IS THE CALLER'S OBJECT (0.207; the Itanium C++ ABI's 3.1.2.3, as
%% clang and gcc have it): a temporary of the statement, built where the callee reads it (the lowering's ir_arg_in_place/4) and
%% destroyed at the end of the full-expression, and on unwinding where it was built (its cleanup flag, cpp_stmt/3). A temporary the
%% roads above registered stays registered, where it was elided before and the callee destroyed it; a copy or a move into `$copy'
%% is registered, its block's declaration the statement's; a call returning the class is materialized into a `$tmp'; a conditional's
%% arms each so, flagged where they are built. Outside a statement walk the argument is as it was.
cpp_byval_arg(C, A0, A) :- cpp_dtor(C, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts), !, cpp_byval_arg_(A0, Dtor, A).
cpp_byval_arg(_, A, A).
cpp_byval_arg_(stmt_expr(block([declaration(0, none, T, [var(Tmp, T, none)])|Is])), Dtor, stmt_expr(block(Is))) :- atom(Tmp), sub_atom(Tmp, 0, _, _, '$copy'), !,
    ccl_declare(Tmp, T), nb_getval('$cpp_temps', Ts), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts]).
cpp_byval_arg_(A, Dtor, A1) :- A = call(_, _), cpp_dtor_prvalue(A, T, _), !,
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), nb_getval('$cpp_temps', Ts), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts]),
    A1 = stmt_expr(block([expr(0, assign('=', id(Tmp), A)), expr(0, id(Tmp))])).
cpp_byval_arg_(cond(C, A0, B0), Dtor, cond(C, A, B)) :- !, cpp_byval_arm(A0, Dtor, A), cpp_byval_arm(B0, Dtor, B).
cpp_byval_arg_(A, _, A).
%% a conditional's arm: a call materialized into a `$tmp' FLAGGED, built only where the arm is taken (cpp_cond_branch/4's rule)
cpp_byval_arm(A, Dtor, stmt_expr(block([expr(0, assign('=', id(Tmp), A)), expr(0, assign('=', id(F), int(1))), expr(0, id(Tmp))]))) :- A = call(_, _), cpp_dtor_prvalue(A, T, _), !,
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), ccl_gensym('$tf', F), ccl_declare(F, base([], [int])),
    nb_getval('$cpp_temps', Ts), nb_setval('$cpp_temps', [tmp(Tmp, T, flag(F, Dtor))|Ts]).
cpp_byval_arm(A, _, A).
cpp_plain_struct_param(PT0, ST) :- cpp_param_ref(PT0, PT), cpp_param_takes_(PT, ST), \+ cpp_class_of_type(ST, _), once(ccl_resolve_type(ST, RT)), ( RT = base(_, [struct(_, _)]) ; RT = base(_, [union(_, _)]) ), !.
%% AN initializer_list<T> IS THE COMPILER'S TO BUILD ([dcl.init.list]/6): a backing array of the items, which lives
%% as long as the full expression -- here a local of the function, since the lowering allocates every block's
%% locals at its entry -- and the list object through the class's own two-argument constructor over it (private in
%% libc++, `initializer_list(const _Ep *, size_t)'; access is not checked here). `s.insert({5, 2, 9})',
%% `std::vector<int> v = {7, 4, 7}', `std::set<int> s = {1, 2, 3}'. The items are desugared as any argument is.
cpp_init_list(ET, Items, IL) :- cpp_init_list(none, ET, Items, IL).
%% ... AN ARRAY OF OBJECTS IS BUILT ELEMENT BY ELEMENT IN PLACE ([dcl.init.list]/5: each element copy-initialized from its
%% item, a prvalue of the class being the element, C++17's elision; 0.206), as a local array of objects is
%% (cpp_decl_pieces/6), and destroyed at the end of the full expression as a temporary is, the last first, where it was
%% built (its cleanup flag, set once the elements are): it was an aggregate of the items' values, each the bytes of a
%% temporary destroyed at the statement's end -- a list's sentinel pointed into the dead temporary, and `std::vector<
%% std::list<int>> v{{1, 2}, {3}}' aborted. Outside a statement walk (no register of temporaries) it keeps that road.
cpp_init_list(Ctx, ET, Items, stmt_expr(block(Ss))) :- cpp_elem_class(ET, EC), ( cpp_has_ctors(EC) ; cpp_dtor(EC, _) ), ccl_global('$cpp_temps', Ts0, none), is_list(Ts0), !,
    findall(E2, ( member(item(_, E0), Items), once(( cpp_expr(Ctx, E0, E1), cpp_il_item(ET, E1, E2) )) ), Es), cpp_obj_array(ET, Es, Arr, N, Ss0),
    cpp_instantiate_type(initializer_list, [ET], ILT), cpp_class_of_type(ILT, ILC), cpp_temporary(ILT, ILC, [id(Arr), int(N)], IL),
    append(Ss0, [expr(0, IL)], Ss).
cpp_init_list(Ctx, ET, Items, stmt_expr(block([declaration(0, none, ET, [var(Arr, arr(int(N), ET), init(Items1))]), expr(0, IL)]))) :-
    findall(item(D, E2), ( member(item(D, E0), Items), once(( cpp_expr(Ctx, E0, E1), cpp_il_item(ET, E1, E2) )) ), Items1), length(Items1, N),   % ONCE: a second answer would register a second temporary (nb_setval survives backtracking) and the array would hold both
    ccl_gensym('$il', Arr), ccl_declare(Arr, arr(int(N), ET)),
    cpp_instantiate_type(initializer_list, [ET], ILT), cpp_class_of_type(ILT, ILC), cpp_temporary(ILT, ILC, [id(Arr), int(N)], IL).
%% the temporary array of objects of the class ET from the element values Es, `$il': its statements, the elements built in place
%% in order and, where the class has a destructor, the array registered with the statement, flagged once the elements are built
cpp_obj_array(ET, Es, Arr, N, Ss) :- cpp_elem_class(ET, EC), length(Es, N), ccl_gensym('$il', Arr), AT = arr(int(N), ET), ccl_declare(Arr, AT), K1 is N - 1,
    ( cpp_dtor(EC, _) -> cpp_elems_unwind(0, K1, ET, id(Arr), Es, 0, Inits0, []), Inits = [block(Inits0)] ; cpp_elems_from(0, K1, ET, id(Arr), Es, 0, Inits, []) ),
    (   cpp_member_dtor(AT, id(Arr), 0, Ds), Ds \== []
    ->  ccl_gensym('$tf', F), ccl_declare(F, base([], [int])), nb_getval('$cpp_temps', Ts1), nb_setval('$cpp_temps', [tmp(Arr, AT, flag(F, stmts(Ds)))|Ts1]),
        Decl = [], Built = [expr(0, assign('=', id(F), int(1)))]
    ;   Decl = [declaration(0, none, AT, [var(Arr, AT, none)])], Built = [] ),
    append([Decl, Inits, Built], Ss).
%% ... and a class WITH an initializer_list constructor takes a braced initializer through it, before any other
%% constructor over the items ([over.match.list]): `vector(initializer_list<value_type>)' beside `vector(size_type,
%% const value_type &)', which three ints would otherwise have gone to
%% an item of another type converts through the element class's converting constructor, as a call's argument does
%% (0.66): `std::set<std::string> names = {"bob", "amy"}' builds its backing array of strings from literals, and
%% taken raw the lowering cast a pointer to a string. The temporary dies with the statement, as the array does in C++.
cpp_il_item(ET, init(Items), E2) :- cpp_class_of_type(ET, C), cpp_has_ctors(C), cpp_il_braced(C, Items, ET2), !,   % ... through its initializer_list constructor where it has one (0.117): `std::vector<std::vector<int>> v = {{1, 2}, {3}}'
    cpp_init_list(ET2, Items, IL), cpp_temporary(ET, C, [IL], E2).
cpp_il_item(ET, init(Items), E2) :- cpp_class_of_type(ET, C), cpp_has_ctors(C), !,   % a BRACED item of a class with constructors list-initializes a temporary through them ([dcl.init.list]): `std::map<std::string, int> m = {{"a", 1}, {"b", 2}}' builds each `pair<const string, int>' from `{"a", 1}', which as an aggregate of the backing array stored the literal's pointer into the string
    findall(V, member(item(_, V), Items), Vs), cpp_temporary(ET, C, Vs, E2).
cpp_il_item(ET, E1, E2) :- cpp_class_of_type(ET, C), ccl_type_of(E1, AT), AT \== unknown, \+ cpp_class_of_type_of(E1, C), cpp_converting_ctor(C, E1), !, cpp_temporary(ET, C, [E1], E2).
cpp_il_item(_, E, E).
%% ... AND IT IS CHOSEN ONLY WHERE EVERY ITEM FITS ITS ELEMENT TYPE ([over.match.list]/1.1: else the constructors are
%% tried over the items; 0.112): `std::string tag{"t"}' took `basic_string(initializer_list<char>)' for a `const char *'
%% and the string came out empty. An item the inference cannot type, or a braced one, is let through as before.
cpp_il_ctor_for(C, Items, ET) :- cpp_il_ctor(C, ET),
    \+ ( cpp_arith_elem(ET), member(item(_, E), Items), E \= init(_), cpp_arg_type(E, AT), AT \== unknown, cpp_arg_fit(ET, E, 0) ).   % only an ARITHMETIC element type refuses: a class one converts its items (`Names{"x", "yy"}' over `initializer_list<std::string>')
cpp_arith_elem(ET) :- catch(ccl_resolve_type(ET, R), _, fail), ( ccl_is_integer(R) ; ccl_is_float(R) ), !.
%% THE CLASS A BRACED TEMPORARY NAMES, through the type hook as a declaration's type goes: a name, a template-id, a qualified name. What is
%% no class, or does not resolve, is no braced class here, and the call road takes the form as it always did
cpp_braced_class(F, T, C) :- cpp_braced_spec(F, Spec), \+ cpp_raw_type(base([], [Spec])),   % a name over a template's own, unbound parameter is no class to ask: an instance by its spelling can run to the budget
    catch(cpp_type(base([], [Spec]), T), error(not_lowered(_), _), fail), cpp_class_of_type(T, C), cpp_class_l(C, _).
cpp_braced_spec(id(N), typedef(N)) :- atom(N).
cpp_braced_spec(tmpl(N, As), typedef(tmpl(N, As))).
cpp_braced_spec(scoped(P, N), typedef(scoped(P, N))).
%% a braced temporary named by a class template's bare name, and the callee that names its deduced instance
cpp_braced_ctad(id(N), N, Args, tmpl(N, Args)) :- atom(N), \+ cpp_local(N).
cpp_braced_ctad(scoped(P, N), N, Args, scoped(P, tmpl(N, Args))) :- atom(N), \+ catch(cpp_scope_class(P, _), _, fail).
%% THE INITIALIZER_LIST CONSTRUCTOR OF A BRACED LIST: a list of items, one that does not come from the class itself or a class derived from it
%% ([dcl.init.list]/3.2: `std::vector<int>{v}' of a vector copies it), and items the element type takes (cpp_il_class_items_fit)
cpp_il_braced(C, Items, ET) :- Items \== [], cpp_il_ctor_for(C, Items, ET), \+ cpp_il_copy(C, Items), cpp_il_class_items_fit(ET, Items).
cpp_il_copy(C, [item(_, E)]) :- E \= init(_), cpp_arg_type(E, AT), AT \== unknown, cpp_class_of_type_of(E, D), ( D == C ; cpp_derives(D, C) ), !.
%% ... AND FOR A CLASS ELEMENT TYPE every item of a known type is one of a class, or one the element's constructors convert: `std::vector<std::string>{3, "x"}'
%% has no list constructor to take it (an int is no string) and is the (count, value) one
cpp_il_class_items_fit(ET, Items) :- cpp_class_of_type(ET, EC), !, \+ ( member(item(_, E), Items), E \= init(_), ccl_type_of(E, AT), AT \== unknown, \+ cpp_class_of_type_of(E, _), \+ cpp_converting_ctor(EC, E) ).   % the INFERENCE's type only: an item it cannot type is let through, and nothing is desugared twice
cpp_il_class_items_fit(_, _).
%% AN ITEM FITS AN initializer_list<T> ELEMENT when it fits T, or T is a class whose converting constructor takes it (0.117): `std::vector<std::string>({"x", "y"})'
%% has the list conversion ([over.ics.rank]/3.1, the better one) though each literal is converted to a string; scored 0 for that, the list constructor was no
%% candidate and the arity alone chose `vector(const allocator_type &)', handing the allocator three strings
cpp_il_elem_fits(T, E) :- cpp_arg_fit(T, E, Sk), Sk > 0, !.
cpp_il_elem_fits(T, E) :- E \= init(_), cpp_class_of_type(T, TC), ccl_type_of(E, AT), AT \== unknown, \+ cpp_class_of_type_of(E, _), cpp_converting_ctor(TC, E).
cpp_il_ctor(C, ET) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, [param(PT0, _)|_], _, _), Ms),
    cpp_in_class(C, cpp_param_ref(PT0, PT)), ccl_unref(PT, PT1), cpp_class_of_type(PT1, ILC), '$cpp_inst'(ILC, inst(initializer_list, [ET])), !.
%% a class with a constructor whose ONE parameter takes the argument -- checked in the class, whose words it is
%% written in, and by the fit rather than the arity, since every class with a one-argument constructor would pass
%% THE CLASS A PARAMETER TAKES: by value, or through a reference that may bind a TEMPORARY -- a const lvalue
%% reference or an rvalue one, which C++ materializes one for. `v.push_back("alpha")' on a vector of strings takes
%% `const_reference', and with only the by-value test the `const char *' went straight through as if it were one.
cpp_param_takes_class(PT0, C) :- cpp_param_ref(PT0, PT), cpp_param_takes_(PT, T), cpp_class_of_type(T, C).
cpp_param_takes_(ref(Q, T), T) :- !, ( memberchk(const, Q) -> true ; T = base(Q2, _), memberchk(const, Q2) ).
cpp_param_takes_(rref(_, T), T) :- !.
cpp_param_takes_(T, T).
%% EXPLICIT(BOOL) ([dcl.fct.spec]/4, C++20; 0.197): a constructor or a conversion function is explicit where its specifier is
%% `explicit', or `explicit(E)' with E true where the member is asked -- desugared in its class, a template's own
%% parameters bound first (cpp_explicit_under/3) -- and E that does not fold is no explicit specifier, as before. The
%% reader kept `explicit(E)' and no road asked it, so every such member converted implicitly: `is_convertible_v<int,
%% std::optional<A>>' over `explicit A(int)' was true, and libc++'s pair and optional write their constructors so at C++20
cpp_is_explicit(_, Qs) :- memberchk(explicit, Qs), !.
cpp_is_explicit(C, Qs) :- memberchk(explicit(E), Qs), !, cpp_explicit_true(C, E).
cpp_explicit_under(_, Qs, _) :- memberchk(explicit, Qs), !.
cpp_explicit_under(C, Qs, B) :- memberchk(explicit(E), Qs), !, cpp_subst(E, B, E1), cpp_explicit_true(C, E1).
cpp_explicit_true(C, E) :- catch(cpp_in_class(C, ( cpp_expr(none, E, E1), cpp_const_bool(E1, V) )), _, fail), !, V == true.
cpp_converting_ctor(C, A) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, Qs, Ps, _, _), Ms), \+ cpp_is_explicit(C, Qs),   % never an EXPLICIT one ([class.conv.ctor]: no implicit conversion through it; libc++'s `explicit basic_string(const _Tp &)' from a string_view)
    cpp_arity_fits(Ps, 1), \+ cpp_own_class_param(C, Ps),   % and never the COPY or the MOVE constructor, which converts nothing: `__self_view(__str)' fitted string_view's defaulted copy constructor THROUGH the string's conversion operator (0.80 synthesizes such constructors), and the copy took the string's bytes for a string_view's -- the conversion operator is the road (cpp_temporary's conversion clause)
    catch(cpp_in_class(C, cpp_args_fit(Ps, [A])), error(not_lowered(_), _), fail), !.   % the fit test resolves types and may REFUSE: a refusal here is no conversion, never the caller's error
cpp_converting_ctor(C, A) :- '$cpp_mt'(C, ctor, TPs, ctor(_, Qs, Ps, _, _)), \+ cpp_is_explicit(C, Qs), cpp_arity_fits(Ps, 1),
    Ps = [P1|_], ( P1 = param(PT0, _) ; P1 = param(PT0, _, _) ), \+ ( member(tparam(_, TP, _), TPs), cpp_names_in(PT0, TP) ),   % ... but never a parameter written over the template's OWN parameters, which the fit would RESOLVE and instantiate on the free name: `reverse_iterator(const reverse_iterator<_Up> &)' made `reverse_iterator<_Up>', whose registration looped (146,000 flattens to the cap); the template road below deduces it
    catch(cpp_in_class(C, cpp_args_fit(Ps, [A])), error(not_lowered(_), _), fail), !.   % ... or a constructor TEMPLATE, which is how libc++ writes `basic_string(const _CharT *, const _Allocator & = _Allocator())' -- the one every `v.push_back("alpha")' needs
cpp_converting_ctor(C, A) :- '$cpp_mt'(C, ctor, _, ctor(_, Qs, Ps, _, _)), \+ memberchk(explicit, Qs), cpp_arity_fits(Ps, 1), !,   % ... or one whose parameter is written over its OWN template parameters, `pair(const pair<_U1, _U2> &)': no fit can be read off the raw type, so the template road decides (deduced, its signature checked in the class); libc++'s map::insert returns the tree's pair<__tree_iterator, bool> where its own pair<iterator, bool> is the result
    catch(cpp_member_template_ctor(C, [A], _), error(not_lowered(_), _), fail).
cpp_arg_derives(A, C) :- cpp_class_of_type_of(A, AC), AC \== C, cpp_derives(AC, C), !.
cpp_own_class_param(C, [P|_]) :- ( P = param(PT0, _) ; P = param(PT0, _, _) ), catch(cpp_in_class(C, cpp_param_ref(PT0, PT1)), error(not_lowered(_), _), fail), ccl_unref(PT1, PT2), cpp_class_of_type(PT2, C), !.
cpp_copy_temp(C, A, stmt_expr(block([declaration(0, none, T, [var(Tmp, T, none)]), expr(0, call(id(CName), [addr(id(Tmp)), A])), expr(0, id(Tmp))]))) :-
    T = base([], [typedef(C)]), cpp_ctor(C, [A], CName), ccl_gensym('$copy', Tmp).
cpp_move_temp(C, X, stmt_expr(block([declaration(0, none, T, [var(Tmp, T, none)]), expr(0, call(id(CName), [addr(id(Tmp)), X])), expr(0, id(Tmp))]))) :-   % the move constructor chosen over `move(x)', the object itself handed to its reference parameter
    T = base([], [typedef(C)]), cpp_ctor(C, [move(X)], CName), ccl_gensym('$copy', Tmp).
