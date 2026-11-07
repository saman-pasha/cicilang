%% ccl_cpp_eval.pl -- the constant evaluator: constant expressions and constexpr functions over cells and values,
%% aggregates and addresses in a constexpr body, a library consteval constructor's check. A part of the C++
%% desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there, in their order.

%% A CONSTANT IS A CONSTANT EXPRESSION, OR A CONSTEXPR FUNCTION OF ONE `return' CALLED ON CONSTANTS -- the one
%% compile-time evaluation this compiler makes, and the shape libc++'s pair chooses its constructors by:
%% `__enable_if_t<_CheckArgsDep::template __is_pair_constructible<_U1, _U2>(), int> = 0', a static constexpr
%% member function template whose body is `return is_constructible<_T1, _U1>::value && ...'. The instance is
%% emitted as any member template's is, at the call; its body is read back from the emitted item ('$cpp_out'),
%% already desugared in its class's words so the traits in it are constants, its parameters bound to the call's
%% arguments (`this' to the null it was passed), and the return's expression folds -- or does not, and the
%% call stays a call. A body of more than one statement, or a loop, is not evaluated: it is a function.
%% The depth is bounded, since a constexpr function may call itself on an argument that never folds.
cpp_const_value(E, V) :- ccl_const_eval(E, V), !.
cpp_const_value(E, V) :- cpp_const_fold(E, V), !.
%% ... and a form the one evaluator cannot take -- a constexpr CALL, an INDEX into a constant array -- is folded
%% to its literal WHEREVER IT SITS and the arithmetic left to that evaluator (the owner's rule: the table is
%% written once), since libc++ writes its search as `__i == _Nx ? __not_found : __find_idx_return(__i,
%% __find_idx(__i + 1, __matches), __matches[__i])' -- a conditional whose arms hold the recursive call, so
%% ccl_const_eval failed on the whole expression and nothing here reached the call.
cpp_const_value(E0, V) :- cpp_const_reduce(E0, E), E \== E0, !, cpp_const_value(E, V).
cpp_const_fold(call(id(F), []), 1) :- nb_current('$cpp_eval_ce', on), memberchk(F, [is_constant_evaluated, '__libcpp_is_constant_evaluated']), !.   % A CONSTANT EVALUATION'S OWN CALL (0.197): the evaluator answers it inside a call, cpp_eval_reduce/3
cpp_const_fold(call(id(F), Args), V) :- atom(F), cpp_eval_fn(F, Params, Ss),   % the evaluator (0.96, 0.98, 0.99): statements, aggregates, pointers, cells; a SCALAR answer here
    cpp_eval_args(Params, Args, [], Args1), cpp_eval_call(F, Params, Ss, Args1, V0),
    ( cpp_eval_ref_fn(F), V0 = ptr(_, _) -> cpp_eval_load(V0, V1) ; V1 = V0 ), cpp_eval_scalar(V1), !, V = V1.   % A REFERENCE'S CALL ANSWERS ITS PLACE, and its value is what the place holds (0.257), as cpp_eval_reduce/3 reads it: `squares()[3]' and `r[3]' over std::array's operator[] answered the element's address, no scalar, and did not fold
cpp_const_fold(call(id(F), Args), V) :- atom(F), \+ cpp_eval_nce(F), ( '$cpp_out'(F, function(_, _, _, F, Params, _, block([return(_, E0)]))) ; '$cpp_ownfn'(F, function(_, _, _, F, Params, _, block([return(_, E0)]))) ), !,   % an emitted instance's, or the program's own (0.95): 0.72's road, the arguments bound as WRITTEN
    cpp_fold_depth(D), D < 32, D1 is D + 1, nb_setval('$cpp_fold_depth', D1),
    (   cpp_param_binds(Params, Args, B0), cpp_road_args(B0, B), cpp_replace_ids(E0, B, E), cpp_eval_body_scope(cpp_const_value(E, V))   % the body's free names the file's, not the caller's (0.258), each argument folded where the caller wrote it
    ->  nb_setval('$cpp_fold_depth', D)
    ;   nb_setval('$cpp_fold_depth', D), fail ).
%% A REDUCTION THAT CHANGED NOTHING IS NO VALUE (0.121): the evaluator leaves an expression it cannot take as it was, and cpp_eval_value hands that back to cpp_const_value -- which came here again with the same
%% term, for ever (no depth limit covers a member): `const bool v = as(b).vl();' over a derived class's object and a template that returns its argument's reference compiled for 20 minutes (the std::visit prologue).
cpp_const_fold(member(E, F), V) :- compound(E), E \= id(_), cpp_eval_reduce(member(E, F), [], R), R \== member(E, F), cpp_eval_value(R, V), cpp_eval_scalar(V), !.   % `make(5).y': a member of a call's aggregate answer (0.98)
cpp_const_fold(index(E, I), V) :- compound(E), E \= id(_), cpp_eval_reduce(index(E, I), [], R), R \== index(E, I), cpp_eval_value(R, V), cpp_eval_scalar(V), !.
cpp_const_fold(bin(Op, A, B), V) :- cpp_float_cmp(Op, A, B), cpp_eval_reduce(bin(Op, A, B), [], int(V)), integer(V), !.   % A COMPARISON OF FLOATING VALUES (0.258, cpp_eval_fbin/4): `static_assert(area(2.0) > 12.5)', `static_assert(0.1 + 0.2 != 0.3)'
cpp_const_fold(not(E), V) :- cpp_float_typed(E), cpp_eval_reduce(not(E), [], int(V)), integer(V), !.   % the evaluator's literal itself: a comparison it leaves as it was came back here through cpp_const_value/2, for ever
cpp_const_fold(stmt_expr(B), V) :- cpp_eval_reduce(stmt_expr(B), [], R), R \== stmt_expr(B), cpp_eval_value(R, V), cpp_eval_scalar(V), !.   % a statement expression's value, an immediately invoked lambda's (0.257, cpp_init_call/1)
%% AN INDEX INTO A CONSTANT ARRAY ([expr.const]): a static member array with an in-class initializer of constants,
%% subscripted by a constant -- `__matches[__i]', the array libc++'s get<T> searches
cpp_const_fold(index(id(Name), I0), V) :- cpp_const_value(I0, K), '$cpp_sinit'(C, N, init(_)), cpp_static_name(C, N, Name), !,
    cpp_static_aggregate(C, N, init(Items)), K1 is K + 1, ccl_nth(K1, Items, item(_, E)), cpp_const_value(E, V).
%% A CLASS'S STATIC CONSTANT FOLDS WHEREVER IT SITS, as a constexpr call and an array index do (0.90) and as
%% a WHOLE template argument already did (0.60): libc++ guards its two-range algorithms with
%% `__enable_if_t<is_same<...>::value && !is_volatile<_Tp>::value && ..., int>', and with the fold only at the
%% top the conjunction stayed an EXPRESSION -- so the instance was keyed by that term spelled letter by letter,
%% `enable_if<binbinbin...notscopedtmplisvolatile...' had no `type', the candidate was refused, and every such
%% argument built another enormous atom. `std::equal', `std::mismatch' and `std::lexicographical_compare' each
%% cost over 180 s where the same file without them costs 28.
cpp_const_fold(index(id(N), I0), V) :- cpp_global_agg(N, arr(L)), cpp_const_value(I0, K), integer(K), K >= 0, nth0(K, L, V), cpp_eval_scalar(V), !.   % a file-scope constant array's element (0.97)
cpp_const_fold(member(id(N), F), V) :- cpp_global_agg(N, obj(Ps)), memberchk(F-V, Ps), cpp_eval_scalar(V), !.                                 % a file-scope constant struct's member
%% A CONSTEXPR FUNCTION WITH STATEMENTS ([dcl.constexpr] since C++14: locals, assignments, if, loops, several
%% returns; 0.96 -- 0.72's fold took one `return' and nothing else) is EVALUATED where a constant is wanted: the
%% body's statements run over an environment of Name-Value (the parameters bound to the arguments' values, the
%% locals declared as they are met, a block's own dropped at its end), every expression folded by ccl_const_eval
%% with the names replaced by their values, under a step budget (`'$cpp_eval_steps'`: 200000 statements) so a loop
%% that does not end is a failure and not a hang. What it does not take -- an aggregate, a pointer, a call to a
%% function it cannot fold, a form below -- FAILS, and the caller's answer is what it was: the call stays a call.
cpp_eval_fn(F, Params, Ss) :- ( '$cpp_out'(F, function(_, _, _, F, Params, _, block(Ss))) ; '$cpp_ownfn'(F, function(_, _, _, F, Params, _, block(Ss))) ), !.   % FOUND BY ITS NAME (0.165): the two tables are keyed by it
cpp_eval_fn(F, Params, Ss) :- atom(F), catch('$cpp_shipped_name'(F, C, K, PK), _, fail), '$cpp_shipped_def'(C, K, PK, M), !, cpp_eval_shipped_fn(F, C, M, Params, Ss).
%% A SHIPPED MEMBER IN A CONSTANT EVALUATION (0.257): the library's binary defines it and the program calls its symbol, so no body
%% was made -- its kept definition (cpp_note_shipped_def/4) is desugared in its class as the library's, under the symbol, where the
%% evaluator alone finds it ('$cpp_ownfn'): basic_string<char>'s `__init', `append', `__grow_by_and_replace' in `std::string s = "hello";
%% s += " world";'. A definition the desugaring refuses leaves the call no constant, as before
cpp_eval_shipped_fn(F, C, M, Params, Ss) :- cpp_class_l(C, cls(Base, _, _, Defaults, _)),
    catch(cpp_eval_only(cpp_as_lib(yes, cpp_isolated(cpp_in_class(C, cpp_member_fns([M], C, Base, Defaults, Fns))))), E, ( cpp_trace(shipped_body_refused(F, E)), fail )),
    member(function(L, Sto, Ret, _, Params, V, block(Ss)), Fns), !,
    assertz('$cpp_ownfn'(F, function(L, Sto, Ret, F, Params, V, block(Ss)))).
%% ... ITS INSTANCES ARE THE EVALUATOR'S (0.258): each function the desugaring of the body makes is marked '$cpp_evonly', and one that
%% nothing of the unit names is no item of it (cpp_drop_evonly/3) -- `std::string s = "hello"; s += " world";' in a static assertion
%% emitted 107 functions of basic_string's internals that no code calls, 286 where the program without the assertion has 179
cpp_eval_only(G) :- ( nb_current('$cpp_evonly_mode', W) -> true ; W = no ), nb_setval('$cpp_evonly_mode', yes),
    (   catch(G, X, ( nb_setval('$cpp_evonly_mode', W), throw(X) )) -> nb_setval('$cpp_evonly_mode', W) ; nb_setval('$cpp_evonly_mode', W), fail ).
%% A FUNCTION THAT RETURNS A REFERENCE answers the ADDRESS of its referent (0.168): its returns are evaluated as places
%% (`'$retref'' in the environment), its call is that place (cpp_eval_addr) and, as a value, what the place holds. It
%% answered the referent's value, a copy: `std::get<0>(t).parse()' over a constexpr tuple changed a temporary and the
%% tuple kept its 0, a silent wrong answer once the base cast of 0.168 let `std::get' through
cpp_eval_ref_fn(F) :- atom(F), ( '$cpp_out'(F, function(_, _, Ret, F, _, _, _)) ; '$cpp_ownfn'(F, function(_, _, Ret, F, _, _, _)) ), !, cpp_eval_ref_type(Ret).
cpp_eval_call(F, Params, Ss, Args, V) :-
    \+ cpp_eval_nce(F),   % a function of the program's that is not constexpr is no call a constant evaluation makes (0.258, cpp_note_nce/4)
    cpp_fold_depth(D), D < 32, D1 is D + 1, nb_setval('$cpp_fold_depth', D1),
    (   cpp_eval_bind_params(Params, Args, Env01), ( cpp_eval_ret_type(F, RT) -> ( cpp_eval_ref_type(RT) -> Env0 = ['$retref'-yes, '$ret'-RT|Env01] ; Env0 = ['$ret'-RT|Env01] ) ; Env0 = Env01 ), ( D == 0 -> nb_setval('$cpp_eval_steps', 0), nb_setval('$cpp_eval_heap', []) ; true ),   % the result type, for a return's conversion (0.258), and a reference's return (0.168), from one look at the item; one budget for the whole fold, a nested constexpr call included; and one heap
        cpp_eval_in_fn(F, cpp_eval_body_scope(cpp_eval_stmts(Ss, Env0, _, R))), ( R = ret(V0) -> true ; R == next, V0 = 0 ),   % a void function falls off its end: a constructor, `fill(a, 4, 5)'
        ( D == 0 -> nb_getval('$cpp_eval_heap', []) ; true )   % every block the evaluation allocated is freed where it ends ([expr.const]/5.19; 0.257)
    ->  nb_setval('$cpp_fold_depth', D), V = V0
    ;   nb_setval('$cpp_fold_depth', D), fail ).
cpp_eval_nce(F) :- atom(F), catch('$cpp_nce'(F), _, fail), !.
%% A BODY'S FREE NAMES ARE THE FILE'S (0.257; [basic.scope.block], [basic.lookup.unqual]: a function's body sees its own scopes,
%% its class's and its namespaces', never its caller's): the walk's open frames and its own constants ('$ccl_scope',
%% '$cpp_lconsts') are set aside while a body runs, its parameters and locals being cells of its environment, and put back
%% however it ends. They were the walk's: `constexpr int gk() { return K; }' folded to a caller's local `const int K = 5;' --
%% `const int z = gk();' was 5 where the file's K is 1, and 0.256 built it so -- and under a plain `int K' to no constant,
%% a static assertion of the caller's refused. A scope already empty is a body's within the run
cpp_eval_body_scope(G) :- ( nb_current('$ccl_scope', S0) -> true ; S0 = [] ), cpp_lconsts_now(LC0),
    (   S0 == [], LC0 == [] -> call(G)
    ;   nb_setval('$ccl_scope', []), nb_setval('$cpp_lconsts', []),
        (   catch(G, X, ( cpp_eval_scope_back(S0, LC0), throw(X) )) -> cpp_eval_scope_back(S0, LC0) ; cpp_eval_scope_back(S0, LC0), fail ) ).
cpp_eval_scope_back(S0, LC0) :- nb_setval('$ccl_scope', S0), nb_setval('$cpp_lconsts', LC0).
%% THE BODY THE EVALUATOR RUNS, by its function's name ('$cpp_eval_cur', 0.258), put back however the body ends: what a constant
%% evaluation allows may depend on whose body asks (cpp_eval_allocator_body/0)
cpp_eval_in_fn(F, G) :- ( nb_current('$cpp_eval_cur', F0) -> true ; F0 = none ), nb_setval('$cpp_eval_cur', F),
    (   catch(G, X, ( nb_setval('$cpp_eval_cur', F0), throw(X) )) -> nb_setval('$cpp_eval_cur', F0) ; nb_setval('$cpp_eval_cur', F0), fail ).
%% THE CELLS (0.99): every local and every parameter lives in a CELL, a global of its own (`'$cpp_ec:K'`), and the
%% environment maps the name to it (`N-'$cell'(K)`) beside the declared type (`'$t'(N)-T`, for `sizeof(a)'); a reference
%% parameter or local is an ALIAS of an address (`N-'$alias'(Ptr)`). A POINTER is `ptr(cell(K), Path)': the cell and the
%% path into its value -- `[]` the whole, `[2]` an element, `[x]` a member, `[1, y]` nested -- so a store through one,
%% `*p = v', `p[i] = v', `q->x = v', `this->x *= k' in a non-const member function, `a[i] = v' through a callee's pointer
%% parameter, `r += 100' through a reference, writes the cell the pointer names, whichever function holds it. A cell
%% is never freed inside a fold (a fold is small and the store compacts an overwrite), and the counter never restarts.
cpp_ec_new(V, Id) :- ( nb_current('$cpp_ec_n', N) -> true ; N = 0 ), Id is N + 1, nb_setval('$cpp_ec_n', Id), cpp_ec_put(Id, V).
cpp_ec_get(Id, V) :- atom_concat('$cpp_ec:', Id, K), nb_getval(K, V).
cpp_ec_put(Id, V) :- atom_concat('$cpp_ec:', Id, K), nb_setval(K, V).
cpp_ec_str(Id) :- cpp_ec_lit(Id, str).
cpp_ec_lit(Id, Kind) :- atom_concat('$cpp_ecs:', Id, K), once(nb_current(K, V)), ( V == yes -> Kind = str ; V = wide(Kind) ).
cpp_eval_bind_params([], _, []) :- !.
cpp_eval_bind_params(_, [], []) :- !.
cpp_eval_bind_params([param(T, N)|Ps], [A|As], [N-B, '$t'(N)-T|E]) :- !, cpp_eval_bind_one(T, A, B), cpp_eval_bind_params(Ps, As, E).
cpp_eval_bind_params([param(T, N, _)|Ps], [A|As], [N-B, '$t'(N)-T|E]) :- !, cpp_eval_bind_one(T, A, B), cpp_eval_bind_params(Ps, As, E).
cpp_eval_bind_params([_|Ps], [_|As], E) :- cpp_eval_bind_params(Ps, As, E).
cpp_eval_bind_one(T, '$val'(P), '$alias'(P)) :- cpp_eval_ref_type(T), P = ptr(_, _), !.
cpp_eval_bind_one(_, A, '$cell'(Id)) :- cpp_eval_value(A, V), cpp_ec_new(V, Id).
cpp_eval_ref_type(T) :- ( T = ref(_, _) ; T = rref(_, _) ), !.
%% the arguments, by the parameters: a reference parameter takes the ADDRESS of a place, or a fresh cell holding a value
%% that is no place (a temporary bound to a const reference); any other the value
cpp_eval_args([], As, Env, Vs) :- !, cpp_eval_reduce_list(As, Env, Vs).
cpp_eval_args(_, [], _, []) :- !.
cpp_eval_args([param(T, _)|Ps], [A|As], Env, [V|Vs]) :- !, cpp_eval_arg(T, A, Env, V0), cpp_eval_conv_val(T, A, Env, V0, V), cpp_eval_args(Ps, As, Env, Vs).
cpp_eval_args([param(T, _, _)|Ps], [A|As], Env, [V|Vs]) :- !, cpp_eval_arg(T, A, Env, V0), cpp_eval_conv_val(T, A, Env, V0, V), cpp_eval_args(Ps, As, Env, Vs).
cpp_eval_args([_|Ps], [A|As], Env, [V|Vs]) :- cpp_eval_reduce(A, Env, V), cpp_eval_args(Ps, As, Env, Vs).
cpp_eval_arg(T, A, Env, '$val'(P)) :- cpp_eval_ref_type(T), !,
    (   cpp_eval_addr(A, Env, P0) -> P = P0
    ;   cpp_eval_reduce(A, Env, R), cpp_eval_value(R, V) -> cpp_ec_new(V, Id), P = ptr(cell(Id), [])
    ;   cpp_eval_unseen(A, Env), cpp_eval_unseen_cell(A, Id), P = ptr(cell(Id), []) ).
cpp_eval_arg(_, A, Env, V) :- cpp_eval_reduce(A, Env, V).
%% AN OBJECT THE EVALUATION DOES NOT SEE IS BOUND TO A REFERENCE, AND NEVER READ (0.258; [expr.const]/5.9, P2280's unknown reference): `int x
%% = 2; static_assert(gk3(x) == 1);' over `constexpr int gk3(const int &) { return K; }' is a constant expression, the reference
%% bound and never read -- clang++ takes it, and the evaluator found no address for the caller's plain local, and failed. The cell
%% holds `'$unseen'(E)': a read of it or a store into it fails (cpp_eval_load/2, cpp_eval_store_ptr/2), as clang++ refuses them
cpp_eval_unseen(id(N), Env) :- atom(N), \+ memberchk(N-_, Env), catch(ccl_type_of(id(N), T), _, fail), T \== unknown, \+ catch(ccl_resolve_type(T, fn(_, _, _)), _, fail),
    \+ ( catch(cpp_eval_reduce(id(N), Env, R), _, fail), R \== id(N), cpp_eval_value(R, _) ).   % AN OBJECT WHOSE VALUE THE EVALUATOR KNOWS IS SEEN: a constexpr local's, a constant's -- its address a cell of that value, as before 0.258 (`none.has_value()' over `constexpr OptBool none' read an unseen object, and std::is_within_lifetime answered false)
cpp_eval_unseen_cell(id(N), Id) :- atom_concat('$cpp_unseen:', N, K), ( nb_current(K, Id0), catch(cpp_ec_get(Id0, '$unseen'(_)), _, fail) -> Id = Id0 ; cpp_ec_new('$unseen'(id(N)), Id), nb_setval(K, Id) ).   % one cell a name: `&x == &x' holds
cpp_eval_step :- ( nb_current('$cpp_eval_steps', K) -> true ; K = 0 ), K < 200000, K1 is K + 1, nb_setval('$cpp_eval_steps', K1).   % unset where the evaluator is entered below 0.72's road (a fold's depth above 0): the count starts here
%% the statements of a block: the outcome is `next' (fell through), `ret(V)', `break' or `continue'
cpp_eval_stmts([], Env, Env, next).
cpp_eval_stmts(['$splice'(Ss1)|Ss], Env0, Env, R) :- !, append(Ss1, Ss, Ss2), cpp_eval_stmts(Ss2, Env0, Env, R).   % A SPLICE'S STATEMENTS ARE ITS BLOCK'S (0.257), as the lowering runs them (ir_stmt_/1): a `defer' among them is the block's
cpp_eval_stmts([defer(_, _, D)|Ss], Env0, Env, R) :- !, cpp_eval_stmts(Ss, Env0, Env, R), cpp_eval_block(D, Env, _, next).   % A DEFER RUNS WHERE ITS BLOCK ENDS (0.257), after what follows it however that ends -- a return's value taken first: a local's destructor, `Der d;''s
cpp_eval_stmts([S|Ss], Env0, Env, R) :- cpp_eval_step, cpp_eval_stmt(S, Env0, Env1, R1), ( R1 == next -> cpp_eval_stmts(Ss, Env1, Env, R) ; Env = Env1, R = R1 ).
cpp_eval_block(block(Ss), Env0, Env, R) :- length(Env0, N0), cpp_eval_stmts(Ss, Env0, Env1, R), length(Env1, N1), K is N1 - N0, cpp_eval_drop(K, Env1, Env).   % the block's own locals are at the front: dropped, the outer ones keep their values
cpp_eval_block(S, Env0, Env, R) :- S \= block(_), cpp_eval_stmts([S], Env0, Env, R).
cpp_eval_drop(0, E, E) :- !.
cpp_eval_drop(K, [_|E0], E) :- K1 is K - 1, cpp_eval_drop(K1, E0, E).
cpp_eval_stmt(block(Ss), Env0, Env, R) :- !, cpp_eval_block(block(Ss), Env0, Env, R).
cpp_eval_stmt('$splice'(Ss), Env0, Env, R) :- !, cpp_eval_stmts(Ss, Env0, Env, R).
cpp_eval_stmt(empty, Env, Env, next) :- !.
cpp_eval_stmt('$value'(E), Env, Env, ret(V)) :- !, cpp_eval_expr(E, Env, V).   % a statement expression's last expression (0.257)
cpp_eval_stmt(declare(_, _), Env, Env, next) :- !.   % a type a body declares, a local struct's (0.201): its tag is in the table, no effect
cpp_eval_stmt(eh_cleanup(_, _), Env, Env, next) :- !.   % a constructor's cleanup of what it built (0.201): run only while an exception unwinds, which a constant evaluation never does
cpp_eval_stmt(try(_, B, _), Env0, Env, R) :- !, cpp_eval_block(B, Env0, Env, R).   % A TRY BLOCK (C++20's P1002; 0.257): its block runs, and a handler never does -- a throw is no step the evaluator takes (C++26's P3068 is not done), so a throw in the block fails the evaluation
cpp_eval_stmt(static_assert(_, _, _), Env, Env, next) :- !.
cpp_eval_stmt(assume(_, _), Env, Env, next) :- !.
cpp_eval_stmt(declaration(_, _, _, Vars), Env0, Env, next) :- !, cpp_eval_decls(Vars, Env0, Env).
cpp_eval_stmt(expr(_, bind_ref(P, E)), Env, Env, next) :- !, cpp_eval_arg(ref([], none), E, Env, '$val'(A)), cpp_eval_store(P, A, Env, _).   % A REFERENCE MEMBER BOUND in a constructor (0.257): its slot holds the referent's address, as the lowering binds it (ir_bind_ref/2) -- std::vector's `__destroy_vector(vector &__vec) : __vec_(__vec)'
cpp_eval_stmt(expr(_, E), Env0, Env, next) :- !, cpp_eval_effect(E, Env0, Env, _).
cpp_eval_stmt(return(_, E), Env, Env, ret(V)) :- memberchk('$retref'-yes, Env), !, cpp_eval_arg(ref([], none), E, Env, '$val'(V0)), cpp_eval_conv_ret(Env, E, V0, V).   % a reference's return: the place (0.168)
cpp_eval_stmt(return(_, E), Env, Env, ret(V)) :- !, cpp_eval_expr(E, Env, V0), cpp_eval_conv_ret(Env, E, V0, V).
cpp_eval_stmt(return(_), Env, Env, ret(0)) :- !.
cpp_eval_stmt(break(_), Env, Env, break) :- !.
cpp_eval_stmt(continue(_), Env, Env, continue) :- !.
cpp_eval_stmt(if(_, C, T, E), Env0, Env, R) :- !, cpp_eval_effect(C, Env0, Env1, CV),
    ( \+ cpp_eval_false(CV) -> cpp_eval_block(T, Env1, Env, R) ; ( E == none ; E == empty ) -> Env = Env1, R = next ; cpp_eval_block(E, Env1, Env, R) ).
cpp_eval_stmt(if_constexpr(L, C, T, E), Env0, Env, R) :- !, cpp_eval_stmt(if(L, C, T, E), Env0, Env, R).
cpp_eval_stmt(ifce(_, CT, _), Env0, Env, R) :- !, cpp_eval_block(CT, Env0, Env, R).   % constant evaluation takes `if consteval''s own branch (0.108)
cpp_eval_stmt(while(_, C, S), Env0, Env, R) :- !, cpp_eval_while(C, S, Env0, Env, R).
cpp_eval_stmt(do(_, S, C), Env0, Env, R) :- !, cpp_eval_do(C, S, Env0, Env, R).
cpp_eval_stmt(for(_, Init, C, Step, S), Env0, Env, R) :- !, length(Env0, N0),
    ( Init == none -> Env1 = Env0 ; cpp_eval_stmt(Init, Env0, Env1, next) ),
    cpp_eval_for(C, Step, S, Env1, Env2, R), length(Env2, N2), K is N2 - N0, cpp_eval_drop(K, Env2, Env).
cpp_eval_stmt(switch(_, E, S), Env0, Env, R) :- !, cpp_eval_effect(E, Env0, Env1, V),
    ( S = block(Is) -> true ; Is = [S] ), cpp_eval_switch_flat(Is, Flat),
    (   append(_, [label(C)|Rest], Flat), C \== default, cpp_eval_expr(C, Env1, CV), CV == V -> true
    ;   append(_, [label(default)|Rest], Flat) -> true
    ;   Rest = [] ),
    length(Env1, N0), cpp_eval_switch_run(Rest, Env1, Env2, R1), length(Env2, N2), K is N2 - N0, cpp_eval_drop(K, Env2, Env),
    ( R1 == break -> R = next ; R = R1 ).
cpp_eval_stmt(for_each(_, var(N, _, _), Range, S), Env0, Env, R) :- !, cpp_eval_place(Range, Env0, arr(L)), cpp_eval_foreach(L, N, S, Env0, Env, R).
cpp_eval_while(C, S, Env0, Env, R) :- cpp_eval_step,
    ( C == none -> CV = 1 ; cpp_eval_effect(C, Env0, Env1, CV) ), ( C == none -> Env1 = Env0 ; true ),
    (   cpp_eval_false(CV) -> Env = Env1, R = next
    ;   cpp_eval_block(S, Env1, Env2, R1),
        ( R1 = ret(_) -> Env = Env2, R = R1 ; R1 == break -> Env = Env2, R = next ; cpp_eval_while(C, S, Env2, Env, R) ) ).
cpp_eval_do(C, S, Env0, Env, R) :- cpp_eval_step, cpp_eval_block(S, Env0, Env1, R1),
    (   R1 = ret(_) -> Env = Env1, R = R1 ; R1 == break -> Env = Env1, R = next
    ;   cpp_eval_effect(C, Env1, Env2, CV), ( cpp_eval_false(CV) -> Env = Env2, R = next ; cpp_eval_do(C, S, Env2, Env, R) ) ).
cpp_eval_for(C, Step, S, Env0, Env, R) :- cpp_eval_step,
    ( C == none -> Env1 = Env0, CV = 1 ; cpp_eval_effect(C, Env0, Env1, CV) ),
    (   cpp_eval_false(CV) -> Env = Env1, R = next
    ;   cpp_eval_block(S, Env1, Env2, R1),
        (   R1 = ret(_) -> Env = Env2, R = R1 ; R1 == break -> Env = Env2, R = next
        ;   ( Step == none -> Env3 = Env2 ; cpp_eval_effect(Step, Env2, Env3, _) ), cpp_eval_for(C, Step, S, Env3, Env, R) ) ).
cpp_eval_decls([], Env, Env).
cpp_eval_decls([var(N, T, Init)|Vs], Env0, Env) :- atom(N), cpp_eval_ref_type(T), !,                          % a reference: an alias of the place it binds (0.99)
    ( Init = init([item([], E)]) -> true ; E = Init ), cpp_eval_arg(T, E, Env0, '$val'(P0)), cpp_eval_conv_ptr(T, E, Env0, P0, P), cpp_eval_decls(Vs, [N-'$alias'(P), '$t'(N)-T|Env0], Env).
cpp_eval_decls([var(N, T, Init)|Vs], Env0, Env) :- atom(N), cpp_eval_agg_kind(T, _), !, cpp_eval_init(T, Init, Env0, Env1, V),   % an array or a struct: a value (0.97)
    cpp_ec_new(V, Id), cpp_eval_decls(Vs, [N-'$cell'(Id), '$t'(N)-T|Env1], Env).
cpp_eval_decls([var(N, T, Init)|Vs], Env0, Env) :- atom(N), \+ ccl_resolve_type(T, arr(_, _)), \+ T = fn(_, _, _),
    ( Init == none -> V = 0 ; Init = init([item([], E)]) -> cpp_eval_effect(E, Env0, Env1, V0), cpp_eval_conv_ptr(T, E, Env0, V0, V) ; Init = init([]) -> V = 0 ; Init \= init(_), cpp_eval_effect(Init, Env0, Env1, V0), cpp_eval_conv_ptr(T, Init, Env0, V0, V) ),
    ( var(Env1) -> Env1 = Env0 ; true ), cpp_ec_new(V, Id), cpp_eval_decls(Vs, [N-'$cell'(Id), '$t'(N)-T|Env1], Env).
%% an expression with its effects: the assignments and the increments change the environment, the rest folds
cpp_eval_effect(assign('=', P, E), Env0, Env, V) :- cpp_eval_placeish(P), !, cpp_eval_effect(E, Env0, Env1, V0), ( cpp_eval_type_of(P, Env1, PT) -> cpp_eval_conv_ptr(PT, E, Env0, V0, V) ; V = V0 ), cpp_eval_store(P, V, Env1, Env).
cpp_eval_effect(assign(Op, P, E), Env0, Env, V) :- cpp_eval_placeish(P), atom_concat(BinOp, '=', Op), !, cpp_eval_effect(E, Env0, Env1, RV), cpp_eval_place(P, Env1, LV), cpp_eval_binop(BinOp, LV, RV, V0), ( cpp_eval_type_of(P, Env1, PT) -> cpp_eval_conv_ptr(PT, E, Env0, V0, V) ; V = V0 ), cpp_eval_store(P, V, Env1, Env).
cpp_eval_effect(preinc(P), Env0, Env, V) :- cpp_eval_placeish(P), !, cpp_eval_place(P, Env0, V0), cpp_eval_add(V0, 1, V), cpp_eval_store(P, V, Env0, Env).
cpp_eval_effect(predec(P), Env0, Env, V) :- cpp_eval_placeish(P), !, cpp_eval_place(P, Env0, V0), cpp_eval_add(V0, -1, V), cpp_eval_store(P, V, Env0, Env).
cpp_eval_effect(postinc(P), Env0, Env, V) :- cpp_eval_placeish(P), !, cpp_eval_place(P, Env0, V), cpp_eval_add(V, 1, V1), cpp_eval_store(P, V1, Env0, Env).
cpp_eval_effect(postdec(P), Env0, Env, V) :- cpp_eval_placeish(P), !, cpp_eval_place(P, Env0, V), cpp_eval_add(V, -1, V1), cpp_eval_store(P, V1, Env0, Env).
cpp_eval_effect(comma(A, B), Env0, Env, V) :- !, cpp_eval_effect(A, Env0, Env1, _), cpp_eval_effect(B, Env1, Env, V).
cpp_eval_effect(cond(C, A, B), Env0, Env, V) :- !, cpp_eval_effect(C, Env0, Env1, CV), ( \+ cpp_eval_false(CV) -> cpp_eval_effect(A, Env1, Env, V) ; cpp_eval_effect(B, Env1, Env, V) ).
cpp_eval_effect(bin('&&', A, B), Env0, Env, V) :- !, cpp_eval_effect(A, Env0, Env1, AV), ( cpp_eval_false(AV) -> Env = Env1, V = 0 ; cpp_eval_effect(B, Env1, Env, BV), ( cpp_eval_false(BV) -> V = 0 ; V = 1 ) ).
cpp_eval_effect(bin('||', A, B), Env0, Env, V) :- !, cpp_eval_effect(A, Env0, Env1, AV), ( \+ cpp_eval_false(AV) -> Env = Env1, V = 1 ; cpp_eval_effect(B, Env1, Env, BV), ( cpp_eval_false(BV) -> V = 0 ; V = 1 ) ).
cpp_eval_effect(bin(Op, A, B), Env0, Env, V) :- cpp_eval_side_effects(A), !, cpp_eval_effect(A, Env0, Env1, AV), cpp_eval_effect(B, Env1, Env, BV), ccl_const_op(Op, AV, BV, V).   % an increment inside an operand, `n-- > 1': its effect is kept
cpp_eval_effect(bin(Op, A, B), Env0, Env, V) :- cpp_eval_side_effects(B), !, cpp_eval_effect(A, Env0, Env1, AV), cpp_eval_effect(B, Env1, Env, BV), ccl_const_op(Op, AV, BV, V).
cpp_eval_effect(cast(_, E), Env0, Env, V) :- cpp_eval_side_effects(E), !, cpp_eval_effect(E, Env0, Env, V).
cpp_eval_effect(E, Env, Env, V) :- cpp_eval_expr(E, Env, V).
cpp_eval_side_effects(E) :- compound(E), ( E = assign(_, _, _) ; E = preinc(_) ; E = predec(_) ; E = postinc(_) ; E = postdec(_) ), !.
cpp_eval_side_effects(E) :- compound(E), \+ cpp_eval_inert(E), E =.. [_|As], member(A, As), cpp_eval_side_effects(A), !.
cpp_eval_inert(str(_)).  cpp_eval_inert(u8str(_)).   % a literal, a name or a value holds no effect, and a string's codes were walked a code at a time (0.165)
cpp_eval_inert(int(_)).
cpp_eval_inert(id(_)).
cpp_eval_inert('$val'(_)).
%% THE VALUES (0.98): an integer, `big(A)', `arr(L)', `obj(Ps)', and a POINTER `ptr(Base, Off)' -- its base an `arr(L)' (a string
%% literal's codes with their zero, an array named, a pointer's own) or an `obj(Ps)' (`&q', `this') -- a COPY read through
%% and never written: `s[n]', `*s', `s++', `p - s', `p->x', a pointer compared with another, where a store through one
%% FAILS and the call stays a call. An expression is REDUCED bottom up over the environment (`cpp_eval_reduce': a name
%% to its value, a place to what it holds, a string literal to a pointer, a call of a constexpr function to its answer,
%% pointer arithmetic to a pointer, everything else rebuilt) into a term whose leaves are `int(V)' and `'$val'(Agg)', and
%% what is left -- the scalar arithmetic -- is the one evaluator's (`cpp_eval_value' through cpp_const_value).
cpp_eval_expr(E, Env, V) :- cpp_eval_reduce(E, Env, R), cpp_eval_value(R, V).
cpp_eval_value('$val'(V), V) :- !.
cpp_eval_value(int(V), V) :- !.
cpp_eval_value(nullptr, 0) :- !.   % a null pointer: the null `this' a static member function is called with (0.112), `p != nullptr'
cpp_eval_value(R, V) :- cpp_const_value(R, V), !.
cpp_eval_value(R, flt(K, X)) :- cpp_eval_fconst(R, K, X).   % a floating constant, its kind's value (0.258, cpp_eval_fbin/4)
cpp_eval_lit(V, int(V)) :- cpp_eval_scalar(V), !.
cpp_eval_lit(V, '$val'(V)).
cpp_eval_reduce(nullptr, _, int(0)) :- !.   % THE NULL POINTER IS 0 (0.257), as cpp_eval_value/2 reads it: a null dynamic_cast compared with `nullptr' was no constant
cpp_eval_reduce(E, _, E) :- \+ compound(E), !.
cpp_eval_reduce(int(N), _, int(N)) :- !.
cpp_eval_reduce('$val'(V), _, '$val'(V)) :- !.
cpp_eval_reduce(id(N), Env, '$val'(F)) :- atom(N), nb_current('$cpp_flt_seen', yes), \+ memberchk(N-_, Env), cpp_eval_flt_const(N, F), !.   % a constexpr floating object's value (0.258, cpp_note_const/5)
cpp_eval_reduce(id(N), Env, R) :- !, ( cpp_eval_addr(id(N), Env, A), cpp_eval_load(A, V) -> cpp_eval_decay(V, A, R) ; cpp_eval_function(N) -> R = '$val'(fn(N)) ; R = id(N) ).   % a name: its cell's value, an array DECAYED to a pointer to its first element
cpp_eval_reduce(W, _, '$val'(ptr(cell(Id), [0]))) :- ( W = str(Cs) ; W = u8str(Cs) ), !, append(Cs, [0], L), cpp_ec_new(arr(L), Id), atom_concat('$cpp_ecs:', Id, SK), nb_setval(SK, yes).   % the cell is a literal's: a pointer into it may be a global's constant
%% ... A WIDE LITERAL is its code units (0.115): `L"true"' and `U"..."' the code points, `u"..."' UTF-16 units
%% (ir_utf8_decode, ir_wide_units: the lowering's own doors), the cell marked with its kind so a pointer into it spells
%% back as that literal. Why: `__bool_strings<wchar_t>::__true{L"true"}' did not fold, the static stayed an undefined
%% symbol, and std::format(L"...") did not link (`widesv.cpp').
cpp_eval_reduce(W, _, '$val'(ptr(cell(Id), [0]))) :- compound(W), W =.. [Kind, Cs], memberchk(Kind-LL, [wstr-i32, u32str-i32, u16str-i16]), is_list(Cs), !,
    ir_utf8_decode(Cs, Us), ir_wide_units(LL, Us, Ws), append(Ws, [0], L), cpp_ec_new(arr(L), Id), atom_concat('$cpp_ecs:', Id, SK), nb_setval(SK, wide(W)).
cpp_eval_reduce(sizeof(E), Env, int(S)) :- cpp_eval_sizeof(E, Env, S), !.                                     % `sizeof(a)', `sizeof(a) / sizeof(a[0])' over a local (0.99)
cpp_eval_reduce(index(P, I), Env, R) :- cpp_eval_addr(index(P, I), Env, A), cpp_eval_load(A, V), !, cpp_eval_decay(V, A, R).   % a place: through its address
cpp_eval_reduce(member(P, F), Env, R) :- cpp_eval_addr(member(P, F), Env, A), cpp_eval_load(A, V), !, cpp_eval_decay(V, A, R).
%% A VIRTUAL CALL IN A CONSTANT EVALUATION (C++20's P1064; 0.257): the slot the call names in the table the object's `$vptr' holds
%% -- `(*(Base.vt *) b->$vptr).f.0' -- is the function its entry names (cpp_note_vtab/3); it was no value, and every virtual call
%% failed the fold
cpp_eval_reduce(arrow(cast(PT, X), SN), Env, '$val'(fn(Impl))) :- cpp_eval_vt_type(PT), cpp_eval_reduce(X, Env, '$val'(vt(G))), !,
    catch('$cpp_vtab'(G, Ns, Is), _, fail), nth0(K, Ns, SN), nth0(K, Is, item(_, id(Impl))).
%% DYNAMIC_CAST IN A CONSTANT EVALUATION (C++20's P1327; 0.257): the operand's dynamic class is its table's, its complete object the
%% outermost down the `$base' chain (a primary table's; a later base's table is not done); the cast's class is that object where it
%% is the dynamic class, else its base sub-object where it is a base, else the null pointer
cpp_eval_reduce(dyncast(E, _, _, T), Env, R) :- !, cpp_eval_expr(E, Env, P),
    (   P == 0 -> R = int(0)
    ;   P = ptr(Cell, Path), cpp_eval_dynamic(Cell, Path, D, Top), catch(( ccl_resolve_type(T, ptr(_, TT)), cpp_class_of_type(TT, TC) ), _, fail),
        (   TC == D -> R = '$val'(ptr(Cell, Top))
        ;   catch(once(cpp_base_hops(D, TC, Hops0)), _, fail) -> cpp_eval_trim_base(Hops0, Hops), append(Top, Hops, Path1), R = '$val'(ptr(Cell, Path1))
        ;   R = int(0) ) ).
cpp_eval_reduce(arrow(P, F), Env, R) :- cpp_eval_addr(arrow(P, F), Env, A), cpp_eval_load(A, V), !, cpp_eval_decay(V, A, R).
cpp_eval_reduce(deref(P), Env, R) :- \+ cpp_eval_side_effects(P), !, cpp_eval_reduce(P, Env, P1),   % AN OPERAND WITH NO EFFECT REDUCED ONCE (0.165), then its value decides: a pointer's place, a function's value (0.164), else the rest
    (   P1 = '$val'(A), A = ptr(_, _), cpp_eval_load(A, V) -> cpp_eval_decay(V, A, R)
    ;   P1 = '$val'(fn(F)) -> R = '$val'(fn(F))
    ;   R = deref(P1) ).
cpp_eval_reduce(deref(P), Env, R) :- cpp_eval_addr(deref(P), Env, A), cpp_eval_load(A, V), !, cpp_eval_decay(V, A, R).   % an operand with an effect: once, through its address
cpp_eval_reduce(index(P, I), Env, R) :- \+ cpp_eval_side_effects(index(P, I)), cpp_eval_reduce(P, Env, '$val'(PV)), cpp_eval_reduce(I, Env, IR), cpp_eval_value(IR, K), integer(K), cpp_eval_elem(PV, K, V), !, cpp_eval_lit(V, R).   % a value that is no place: `make_arr()[2]'
cpp_eval_reduce(member(P, F), Env, R) :- \+ cpp_eval_side_effects(P), cpp_eval_reduce(P, Env, '$val'(obj(Ps))), memberchk(F-V, Ps), !, cpp_eval_lit(V, R).
cpp_eval_reduce(addr(member(id(G), '$vt')), _, '$val'(vt(G))) :- atom(G), catch('$cpp_vtab'(G, _, _), _, fail), !.   % A TABLE'S ADDRESS IS THE VALUE vt(Table) (0.257): its class's constructor stores it in the object's `$vptr'
cpp_eval_reduce(addr(P), Env, '$val'(A)) :- cpp_eval_addr(P, Env, A), !.
cpp_eval_reduce(addr(P), Env, '$val'(ptr(cell(Id), []))) :- cpp_eval_unseen(P, Env), !, cpp_eval_unseen_cell(P, Id).   % THE ADDRESS OF AN OBJECT THE EVALUATION DOES NOT SEE (0.258, cpp_eval_unseen/2): a lambda's `this' over a closure that is no constexpr object, `l()', which reads nothing of it                                        % the address of a place
cpp_eval_reduce(addr(P), Env, R) :- \+ cpp_eval_side_effects(P), !, cpp_eval_reduce(P, Env, P1),   % of a value no place holds: a temporary's cell, a function's address (0.164), else the rest -- the operand reduced ONCE (0.165)
    (   P1 = '$val'(V), ( V = obj(_) ; V = arr(_) ) -> cpp_ec_new(V, Id), R = '$val'(ptr(cell(Id), []))
    ;   P1 = '$val'(fn(F)) -> R = '$val'(fn(F))
    ;   R = addr(P1) ).
%% WHAT A LIBRARY CONSTEVAL CONSTRUCTOR'S CHECK RUNS INTO (0.164): a FUNCTION'S ADDRESS is the value `fn(F)', stored, loaded
%% and called through (a handle's `__parse_' holds a lambda's invoker); `std::move' and a cast to a reference name their
%% operand (`std::forward' is `static_cast<_Tp &&>(__t)'); an assignment or an increment inside an operand is done where
%% it is reduced, once (`*__out_it++ = *__begin++'), and no road below reduces it again; `?:', `&&' and `||' evaluate the
%% operands C++ evaluates, no more -- an arm not taken may call what is no constant expression (`__throw_format_error')
cpp_eval_reduce(move(E), Env, R) :- !, cpp_eval_reduce(E, Env, R).
cpp_eval_reduce(ccast(_, T, E), Env, R) :- cpp_eval_ref_type(T), !, cpp_eval_reduce(E, Env, R).
cpp_eval_reduce(cast(T, E), Env, R) :- cpp_eval_ref_type(T), !, cpp_eval_reduce(E, Env, R).
cpp_eval_reduce(cast(T, E), Env, R) :- cpp_eval_float_kind(T, K), K \== wide, !, cpp_eval_reduce(E, Env, E1), cpp_eval_fnum(E1, _, X0), cpp_eval_round(K, X0, X), R = '$val'(flt(K, X)).   % A CAST TO `float' OR `double' MAKES A FLOATING VALUE (0.258, cpp_eval_fbin/4) -- `u.f = 1.5f' stores one in a union's member, which `u.i = 4' replaces, 0.257's held value
cpp_eval_reduce(ccast(_, T, E), Env, R) :- cpp_eval_float_kind(T, K), K \== wide, !, cpp_eval_reduce(E, Env, E1), cpp_eval_fnum(E1, _, X0), cpp_eval_round(K, X0, X), R = '$val'(flt(K, X)).
cpp_eval_reduce(cast(T, E), Env, R) :- cpp_eval_int_type(T), !, cpp_eval_reduce(E, Env, E1), ( cpp_eval_float_term(E1), cpp_eval_fnum(E1, K, X), K \== int -> ccl_w_cast(T, X, V), R = int(V) ; R = cast(T, E1) ).   % ... and a floating value to an integer type, truncated toward zero ([conv.fpint]/1; 0.258)
cpp_eval_reduce(ccast(C, T, E), Env, R) :- cpp_eval_int_type(T), !, cpp_eval_reduce(E, Env, E1), ( cpp_eval_float_term(E1), cpp_eval_fnum(E1, K, X), K \== int -> ccl_w_cast(T, X, V), R = int(V) ; R = ccast(C, T, E1) ).
cpp_eval_reduce(cast(base(_, [void]), E), Env, int(0)) :- !, ( E = id(_) -> true ; cpp_eval_reduce(E, Env, R), cpp_eval_value(R, _) ).   % A CAST TO VOID DISCARDS ITS OPERAND ([expr.static.cast]/6, [expr.context]/2): a NAME is not read -- `(void)__first' over a pointer, `(void)__comp' over an object, as clang takes them; anything else is evaluated and must give a value, a null pointer's `(void)*p' refused as clang refuses it. libc++ 18's __check_strict_weak_ordering_sorted is `(void)__first; (void)__last; (void)__comp;', the last call of every constexpr std::sort and std::sort_heap, and the pointer's value, no integer, failed the whole fold (0.257)
cpp_eval_reduce(E, Env, R) :- cpp_eval_effect_place(E, P), cpp_eval_placeish(P), !, cpp_eval_effect(E, Env, _, V), cpp_eval_lit(V, R).
cpp_eval_reduce(cond(C, A, B), Env, R) :- !, cpp_eval_reduce(C, Env, C1),   % THE CONDITION REDUCED ONCE (0.165): one that did not fold went down the generic road and was reduced again, 2^n down a chain of n
    (   cpp_eval_value(C1, CV) -> ( \+ cpp_eval_false(CV) -> cpp_eval_reduce(A, Env, R) ; cpp_eval_reduce(B, Env, R) )
    ;   cpp_eval_reduce(A, Env, A1), cpp_eval_reduce(B, Env, B1), R = cond(C1, A1, B1) ).
cpp_eval_reduce(bin('&&', A, B), Env, R) :- !, cpp_eval_reduce(A, Env, A1),
    (   cpp_eval_value(A1, AV) -> ( cpp_eval_false(AV) -> R = int(0) ; cpp_eval_expr(B, Env, BV), ( cpp_eval_false(BV) -> R = int(0) ; R = int(1) ) )
    ;   cpp_eval_reduce(B, Env, B1), cpp_eval_bin_rest('&&', A1, B1, R) ).
cpp_eval_reduce(bin('||', A, B), Env, R) :- !, cpp_eval_reduce(A, Env, A1),
    (   cpp_eval_value(A1, AV) -> ( \+ cpp_eval_false(AV) -> R = int(1) ; cpp_eval_expr(B, Env, BV), ( cpp_eval_false(BV) -> R = int(0) ; R = int(1) ) )
    ;   cpp_eval_reduce(B, Env, B1), cpp_eval_bin_rest('||', A1, B1, R) ).
cpp_eval_reduce(compound_lit(T, I), Env, R) :- cpp_eval_init(T, I, Env, _, V), !, cpp_eval_lit(V, R).
cpp_eval_reduce(stmt_expr(block(Ss)), Env, R) :- append(Ss0, [expr(_, Last)], Ss), append(Ss0, ['$value'(Last)], Ss1), cpp_eval_stmts(Ss1, Env, _, ret(V)), !, cpp_eval_lit(V, R).   % its last expression's value, taken before its block's defers run (0.257)
%% TRANSIENT ALLOCATION ([expr.const]/5.18, /5.19; C++20's P0784; 0.257): a new-expression's block from a replaceable global
%% allocation function is a CELL OF THE HEAP'S -- one object, or an array of the count its size gives -- and so is std::allocator's
%% in a constant evaluation, `static_cast<T *>(::operator new(n * sizeof(T)))', an array of n; a delete-expression, or
%% `::operator delete(p)' (std::allocator's deallocate), runs the destructor and frees it. A block freed twice or not at its start,
%% a class's own allocation function, and a block the evaluation still holds where it ends (cpp_eval_call/5) make it no constant
%% expression: the evaluation fails. Every `new' and `delete' in a constexpr body did, `int *p = new int(6)' among them
%% AN ARRAY NEW'S COOKIE (0.258; the Itanium ABI's 2.7): an array of a class with a destructor is a char block of the cookie and the
%% elements, `_Znam(8 + n * sizeof(T))', its count written at the block's start through an `unsigned long *' and its elements from
%% `start + 8'; delete[] reads the count at `(char *)p - 8' and frees that start. The block is ONE CELL of two parts,
%% `obj(['$cookie'-N, '$ck'-8, '$elems'-arr(Ts)])': the start's pointer names the count, `start + 8' the first element and
%% `(char *)first - 8' the start again (cpp_eval_padd/3). The bytes were no value, and `new T[3]' with a destructor was no constant
cpp_eval_reduce(alloc(_, CT, call(id(F), [bin('+', int(Ck), bin('*', NE, sizeof_type(ET)))|_])), Env, '$val'(ptr(cell(Id), ['$cookie']))) :-
    cpp_eval_new_fn(F, array), integer(Ck), Ck > 0, catch(ccl_resolve_type(CT, base(_, [char])), _, fail), !,
    cpp_eval_expr(NE, Env, K), integer(K), K >= 0, cpp_eval_zero(ET, Z), length(L, K), cpp_eval_all(L, Z),
    cpp_ec_new(obj(['$cookie'-0, '$ck'-Ck, '$elems'-arr(L)]), Id), cpp_eval_heap_note(Id, F).
cpp_eval_reduce(alloc(_, T, call(id(F), [S|_])), Env, '$val'(P)) :- cpp_eval_new_fn(F, Kind), !, cpp_eval_expr(S, Env, Size), integer(Size), cpp_eval_new_block(Kind, T, Size, P, F).
cpp_eval_reduce(alloc(_, _, E), Env, R) :- !, cpp_eval_reduce(E, Env, R).   % a placement form's block is the pointer it is given (std::construct_at's `::new (p) T(...)')
cpp_eval_reduce(ccast(_, PT, call(id(F), [S])), Env, '$val'(P)) :- cpp_eval_new_fn(F, _), cpp_eval_typed_block(PT, T), !, cpp_eval_allocator_body, cpp_eval_expr(S, Env, Size), integer(Size), cpp_eval_new_block(array, T, Size, P, F).
cpp_eval_reduce(cast(PT, call(id(F), [S])), Env, '$val'(P)) :- cpp_eval_new_fn(F, _), cpp_eval_typed_block(PT, T), !, cpp_eval_allocator_body, cpp_eval_expr(S, Env, Size), integer(Size), cpp_eval_new_block(array, T, Size, P, F).
cpp_eval_reduce(dealloc(D, Free, X), Env, int(0)) :- !, cpp_eval_expr(X, Env, P),
    ( P == 0 -> true ; P = ptr(cell(Id), _), ( D == none -> true ; cpp_eval_expr(D, Env, _) ), cpp_eval_free_call(Free, Id, P) ).
cpp_eval_reduce(call(id(F), [X|_]), Env, int(0)) :- atom(F), cpp_eval_delete_fn(F), !, cpp_eval_allocator_body, cpp_eval_expr(X, Env, P), ( P == 0 -> true ; P = ptr(cell(Id), _), cpp_eval_free(Id, P, F) ).
cpp_eval_reduce(call(id(F), Args), Env, _) :- atom(F), cpp_eval_abort_fn(F, How), !, cpp_eval_abort(How, Args, Env), fail.   % a library THROW HELPER, or its abort: no constant expression (0.164), its message kept for the refusal (cpp_ce_check)
cpp_eval_reduce(call(id(F), []), _, int(1)) :- nb_current('$cpp_eval_ce', on), memberchk(F, [is_constant_evaluated, '__libcpp_is_constant_evaluated']), !.   % IN A CONSTEVAL CHECK the evaluation is a constant one (0.164); the desugaring answered false for the run time
cpp_eval_reduce(call(id(memset), [P, X, sizeof_type(_)]), Env, '$val'(A)) :- cpp_eval_reduce(P, Env, '$val'(A)), A = ptr(_, _), cpp_eval_expr(X, Env, 0), cpp_eval_load(A, W), !, cpp_eval_zeroed(W, Z), cpp_eval_store_ptr(A, Z).   % THE DESUGARING'S OWN ZEROING of a whole object or member, value-initialization (0.164): its value zeroed
cpp_eval_reduce(call(id(memcpy), [D, Src, sizeof_type(_)]), Env, '$val'(A)) :- cpp_eval_reduce(D, Env, '$val'(A)), A = ptr(_, _), cpp_eval_reduce(Src, Env, '$val'(S)), S = ptr(_, _), cpp_eval_load(S, W), !, cpp_eval_store_ptr(A, W).   % ... and its copy of a whole object as its bytes
cpp_eval_reduce(call(id(F), [D, S, N]), Env, '$val'(DP)) :- memberchk(F, [memmove, memcpy, '__builtin_memmove', '__builtin_memcpy']), cpp_eval_elem_count(N, Env, K),   % MEMMOVE AND MEMCPY OF ELEMENTS (0.257), as clang folds `__builtin_memmove' in a constant evaluation: libc++ 21's __constexpr_memmove copies a string's characters by `__builtin_memmove(__dest, __src, __count * sizeof(_Tp))' -- the count is the size's factor beside the element's size, every value read before any is stored (an overlap is memmove's)
    cpp_eval_reduce(D, Env, '$val'(DP)), DP = ptr(_, _), cpp_eval_reduce(S, Env, '$val'(SP)), SP = ptr(_, _), cpp_eval_copy_elems(SP, DP, K), !.
cpp_eval_reduce(call(id(F), Args), Env, R) :- atom(F), cpp_eval_fn(F, Params, Ss), cpp_eval_args(Params, Args, Env, Args1), cpp_eval_call(F, Params, Ss, Args1, V), !,
    ( cpp_eval_ref_fn(F) -> V = ptr(_, _), cpp_eval_load(V, W), cpp_eval_decay(W, V, R) ; cpp_eval_lit(V, R) ).   % a reference's call, as a value: what its place holds (0.168)
cpp_eval_reduce(call(P, Args), Env, R) :- ( P = id(X) -> memberchk(X-_, Env) ; true ), cpp_eval_reduce(P, Env, '$val'(fn(F))), cpp_eval_fn(F, Params, Ss),   % THROUGH A FUNCTION POINTER (0.164)
    cpp_eval_args(Params, Args, Env, Args1), cpp_eval_call(F, Params, Ss, Args1, V), !, cpp_eval_lit(V, R).
%% THE C LIBRARY'S `strlen' OVER A STRING THE EVALUATOR HOLDS (0.112): libc++'s `char_traits<char>::length' is
%% `__builtin_strlen', and `basic_string_view(const char *)' -- every constant string_view, `__bool_strings''s
%% `__true{"true"}' among them -- counts its literal through it
cpp_eval_reduce(call(id(strlen), [A]), Env, int(N)) :- cpp_eval_reduce(A, Env, '$val'(P)), P = ptr(_, _), cpp_eval_strlen(P, 0, N), !.
cpp_eval_reduce(call(id(wcslen), [A]), Env, int(N)) :- cpp_eval_reduce(A, Env, '$val'(P)), P = ptr(_, _), cpp_eval_strlen(P, 0, N), !.   % ... and `wcslen', `char_traits<wchar_t>::length' (0.115)
cpp_eval_reduce(cast(_, bin('-', cast(CT, X), offsetof(_, id(F)))), Env, '$val'(ptr(C, P0))) :- atom(F), sub_atom(F, 0, _, _, '$base'), catch(ccl_resolve_type(CT, ptr(_, base(_, [char]))), _, fail),
    cpp_eval_expr(X, Env, ptr(C, P)), append(P0, [F], P), !.   % A THUNK'S STEP BACK TO ITS OBJECT (0.258): `(D *)((char *)this - offsetof(D, $base$2))' over a pointer into the sub-object `$base$2' is the object the path names without it -- a virtual call through a later base's table runs the thunk the table holds
cpp_eval_reduce(cast(T, E), Env, R) :- cpp_eval_ptr_cast(T, E, Env, R), !.   % A CAST TO A POINTER TYPE keeps the pointer the evaluator holds (0.126): libc++ 21's `__constexpr_strlen' counts through `__builtin_strlen(reinterpret_cast<const char *>(__str))' where the evaluator's `__libcpp_is_constant_evaluated()' is false, and a pointer wrapped in a cast was none to `strlen' above -- `std::string_view s{"true"}' of a constant did not fold, the static member stayed undefined (constsv.cpp, staticsv.cpp)
cpp_eval_reduce(ccast(_, T, E), Env, R) :- cpp_eval_ptr_cast(T, E, Env, R), !.   % ... by a C++ NAMED cast too, which the desugaring keeps as `ccast(reinterpret, T, E)': the evaluator saw none of the two forms until 0.126's second clause
cpp_eval_reduce(call(id('__builtin_is_within_lifetime'), [P]), Env, int(R)) :- cpp_eval_expr(P, Env, A), A = ptr(C, _), !, \+ ( C = cell(Id), cpp_ec_get(Id, '$unseen'(_)) ), ( cpp_eval_alive(A) -> R = 1 ; R = 0 ).   % C++26's std::is_within_lifetime (0.234)
cpp_eval_reduce(call(id(F), [X|Rest]), Env, int(R)) :- cpp_bitcount(F, Dir, W0), cpp_eval_bitcount(Dir, W0, X, Rest, Env, R), !.   % THE BIT COUNTS (0.126): libc++ 21 writes `__countl_zero' as `__builtin_clzg(__t, numeric_limits<_Tp>::digits)' and its radix sort's `static constexpr auto __radix_size = std::__bit_log2<uint64_t>(...)' folds through the evaluator -- the desugaring folded a count of a CONSTANT argument alone (cpp_builtin_call), and the argument here is the callee's parameter (stdalgorithm6.cpp)
cpp_eval_reduce(call(id(F), [X]), Env, int(R)) :- ccl_bswap_builtin(F, W, _), W =< 32, cpp_eval_reduce(X, Env, XR), cpp_eval_value(XR, V), integer(V), !, U is V /\ ((1 << W) - 1), cpp_bswap_bits(U, W, R).   % A BYTE SWAP of 16 or 32 bits (0.206): a constant expression, as std::byteswap is
cpp_eval_reduce(bin(Op, A, B), Env, R) :- !, cpp_eval_reduce(A, Env, A1), cpp_eval_reduce(B, Env, B1), cpp_eval_bin_rest(Op, A1, B1, R).
cpp_eval_reduce(neg(E), Env, R) :- !, cpp_eval_reduce(E, Env, E1), ( cpp_eval_float_term(E1), cpp_eval_fnum(E1, K, X), K \== int -> Y is -X, R = '$val'(flt(K, Y)) ; R = neg(E1) ).   % a floating value's negation (0.258)
cpp_eval_reduce(not(E), Env, R) :- !, cpp_eval_reduce(E, Env, E1), ( cpp_eval_float_term(E1), cpp_eval_fnum(E1, K, X), K \== int -> ( X =:= 0.0 -> R = int(1) ; R = int(0) ) ; R = not(E1) ).
cpp_eval_reduce(E, Env, R) :- \+ ( cpp_eval_tried(E), cpp_eval_side_effects(E) ), E =.. [F|Xs], cpp_eval_reduce_list(Xs, Env, Ys), R =.. [F|Ys].   % never again a term whose own clauses above reduced its effect once (0.164)
%% the replaceable global allocation functions, one object's or an array's, and their deallocation functions ([new.delete])
cpp_eval_new_fn('_Znwm', single).
cpp_eval_new_fn('_ZnwmSt11align_val_t', single).
cpp_eval_new_fn('_Znam', array).
cpp_eval_new_fn('_ZnamSt11align_val_t', array).
cpp_eval_delete_fn(F) :- ( sub_atom(F, 0, _, _, '_ZdlPv') ; sub_atom(F, 0, _, _, '_ZdaPv') ), !.
%% A DIRECT CALL OF `::operator new' OR `::operator delete' IS std::allocator's ALONE in a constant evaluation (0.258; [expr.const]/5.18:
%% the storage is std::allocator<T>'s, its `allocate' and `deallocate'), as clang allows it; a new- or delete-expression is anyone's.
%% `static_cast<int *>(::operator new(sizeof(int)))' in the program's own constexpr function folded, where clang refuses it
cpp_eval_allocator_body :- nb_current('$cpp_eval_cur', F), atom(F), ( sub_atom(F, 0, _, _, 'allocator.'), ( sub_atom(F, _, _, _, '.allocate.') ; sub_atom(F, _, _, _, '.deallocate.') ) ; sub_atom(F, _, _, _, 'dtor_del') ), !.   % ... and the desugaring's own deleting destructor, which a delete-expression of a polymorphic object runs
cpp_eval_typed_block(PT, T) :- catch(( ccl_resolve_type(PT, ptr(_, T)), \+ ccl_resolve_type(T, base(_, [void])) ), _, fail).
%% a block of Size bytes of T: one object (its pointer the cell's whole) or an array (its pointer the first element), zeroed
cpp_eval_new_block(Kind, T, Size, P, F) :- catch(ccl_size_of(T, ST), _, fail), integer(ST), ST > 0, Size >= 0, Size mod ST =:= 0, K is Size // ST, cpp_eval_zero(T, Z),
    ( Kind == single -> K =:= 1, V = Z, P = ptr(cell(Id), []) ; length(L, K), cpp_eval_all(L, Z), V = arr(L), P = ptr(cell(Id), [0]) ),
    cpp_ec_new(V, Id), cpp_eval_heap_note(Id, F).
%% A BLOCK HELD, by its allocation function's family (0.258): `operator new''s or `operator new[]''s, which its deallocation must
%% match ([expr.delete]/2: a delete of the other form is undefined) -- `delete p' over `new T[2]' freed it
cpp_eval_heap_note(Id, F) :- cpp_eval_alloc_family(F, Fam), ( nb_current('$cpp_eval_heap', H) -> true ; H = [] ), nb_setval('$cpp_eval_heap', [Id-Fam|H]).
cpp_eval_alloc_family(F, Fam) :- ( sub_atom(F, 0, _, _, '_Zna') ; sub_atom(F, 0, _, _, '_ZdaPv') ), !, Fam = array.
cpp_eval_alloc_family(_, single).
cpp_eval_free_call(none, _, _) :- !.   % the deleting destructor's own `operator delete' freed it (cpp_delete_expr/3 of a virtual destructor)
cpp_eval_free_call(call(id(F), _), Id, P) :- atom(F), cpp_eval_delete_fn(F), cpp_eval_free(Id, P, F).
%% a block freed: the pointer at its start, the block one the evaluation holds; what it held is gone, so a read through it fails
cpp_eval_free(Id, ptr(cell(Id), Path), F) :- ( Path == [] ; Path == [0] ; Path == ['$cookie'] ; Path == ['$elems', 0], cpp_eval_cookie(Id, _) ), cpp_eval_alloc_family(F, Fam), nb_current('$cpp_eval_heap', H), selectchk(Id-Fam, H, H1), !, nb_setval('$cpp_eval_heap', H1), cpp_ec_put(Id, freed).   % ... a cookie block by its start or its first element (0.258)
%% the count of elements a copy's size names, `n * sizeof(T)'; a size of any other shape is no constant here
cpp_eval_elem_count(bin('*', X, sizeof_type(_)), Env, K) :- !, cpp_eval_expr(X, Env, K), integer(K), K >= 0.
cpp_eval_elem_count(bin('*', sizeof_type(_), X), Env, K) :- cpp_eval_expr(X, Env, K), integer(K), K >= 0.
cpp_eval_copy_elems(SP, DP, K) :- K1 is K - 1, findall(V, ( between(0, K1, I), cpp_eval_padd(SP, I, Q), cpp_eval_load(Q, V) ), Vs), length(Vs, K),
    forall(nth0(I, Vs, V), ( cpp_eval_padd(DP, I, Q), cpp_eval_store_ptr(Q, V) )).
cpp_bswap_bits(U, 16, R) :- !, R is ((U /\ 255) << 8) \/ ((U >> 8) /\ 255).
cpp_bswap_bits(U, 32, R) :- R is ((U /\ 255) << 24) \/ (((U >> 8) /\ 255) << 16) \/ (((U >> 16) /\ 255) << 8) \/ ((U >> 24) /\ 255).
cpp_eval_reduce_list([], _, []).
cpp_eval_reduce_list([X|Xs], Env, [Y|Ys]) :- cpp_eval_reduce(X, Env, Y), cpp_eval_reduce_list(Xs, Env, Ys).
%% two reduced operands: pointer arithmetic or a comparison of pointers where one is a value, else the operation rebuilt
cpp_eval_bin_rest(Op, A1, B1, R) :- ( cpp_eval_float_term(A1) ; cpp_eval_float_term(B1) ), cpp_eval_fbin(Op, A1, B1, V), !, cpp_eval_lit(V, R).   % an operation over a floating value (0.258)
cpp_eval_bin_rest(Op, A1, B1, R) :- ( ( A1 = '$val'(_) ; B1 = '$val'(_) ), cpp_eval_ptr_bin(Op, A1, B1, V) -> cpp_eval_lit(V, R) ; R = bin(Op, A1, B1) ).
cpp_eval_tried(index(_, _)).
cpp_eval_tried(member(_, _)).
cpp_eval_tried(arrow(_, _)).
cpp_eval_tried(deref(_)).
cpp_eval_tried(addr(_)).
cpp_eval_tried(call(_, _)).
cpp_eval_function(F) :- atom(F), ccl_declared(F, T), nonvar(T), T = fn(_, _, _), !.
cpp_eval_function(F) :- atom(F), cpp_eval_fn(F, _, _), !.   % an invoker made in a frame since closed (`lambda.K.fn')
cpp_eval_effect_place(assign(_, P, _), P).
cpp_eval_effect_place(preinc(P), P).
cpp_eval_effect_place(predec(P), P).
cpp_eval_effect_place(postinc(P), P).
cpp_eval_effect_place(postdec(P), P).
%% THE THROW HELPERS: `__throw_format_error(Msg)' (its message), any other library `__throw_*' (its name and its string
%% arguments: `__throw_invalid_type_format_error: a floating-point', which builds its message at run time), and the
%% verbose abort they end in; the first one met is kept, '$cpp_eval_abort'
cpp_eval_abort_fn(F, How) :- cpp_eval_short_name(F, B), cpp_eval_abort_short(F, B, How).   % asked of every call the evaluator meets: the name split ONCE (0.165), where each dot and each suffix were searched
cpp_eval_abort_short(_, '__throw_format_error', message) :- !.
cpp_eval_abort_short(_, B, named(B)) :- atom_concat('__throw_', _, B), !.
cpp_eval_abort_short(F, _, message) :- atomic_list_concat(Ps, '__libcpp_verbose_abort', F), Ps = [_, _|_], !.
cpp_eval_short_name(F, B) :- atomic_list_concat(Ps, '.', F), last(Ps, B).   % the last segment of a dotted name, the name itself without one
cpp_eval_abort(How, Args, Env) :-
    (   nb_current('$cpp_eval_abort', abort(_)) -> true
    ;   findall(Cs, ( member(A, Args), catch(cpp_eval_reduce(A, Env, '$val'(P)), _, fail), P = ptr(_, _), cpp_eval_cstr(P, 0, Cs) ), Css),
        (   How == message -> ( append(_, [Cs], Css) -> atom_codes(Msg, Cs) ; Msg = abort )
        ;   How = named(B), findall(T, ( member(Cs, Css), atom_codes(T, Cs) ), Ts), atomic_list_concat([B|Ts], ': ', Msg) ),
        nb_setval('$cpp_eval_abort', abort(Msg)) ).
cpp_eval_cstr(P, K, Cs) :- K < 10000, cpp_eval_padd(P, K, Q), cpp_eval_load(Q, C), integer(C), ( C =:= 0 -> Cs = [] ; Cs = [C|Cs1], K1 is K + 1, cpp_eval_cstr(P, K1, Cs1) ).
cpp_eval_pointer_cast(T) :- catch(ccl_resolve_type(T, ptr(_, _)), _, fail).
cpp_eval_ptr_cast(T, E, Env, '$val'(P)) :- cpp_eval_pointer_cast(T), cpp_eval_reduce(E, Env, '$val'(P0)), ( P0 = ptr(_, _) ; P0 = vt(_) ), !, cpp_eval_conv_ptr(T, E, Env, P0, P).   % ... and a table's address (0.257); to a base's or a derived class's pointer, converted (0.258)
cpp_eval_vt_type(PT) :- compound(PT), PT = ptr(_, base(_, [struct(VT, _)])), atom(VT), atom_concat(_, '.vt', VT).   % a table's slots, `struct Base.vt'
%% the dynamic class of the object a pointer names: the class whose table its `$vptr' holds, the object the outermost down the `$base' chain
cpp_eval_dynamic(Cell, Path, D, Top) :- cpp_eval_top(Path, Top), cpp_eval_load(ptr(Cell, Top), W), cpp_eval_vptr_of(W, vt(G)), atomic_list_concat([D, ''], '.vtable', G), D \== ''.
cpp_eval_top(Path, Top) :- append(Top0, [F], Path), atom(F), sub_atom(F, 0, _, _, '$base'), !, cpp_eval_top(Top0, Top).   % down every base's step, a later base's `$base$K' too (0.258)
cpp_eval_top(Path, Path).
cpp_eval_vptr_of(obj(Ps), V) :- ( memberchk('$vptr'-V0, Ps) -> V = V0 ; memberchk('$base'-W, Ps), cpp_eval_vptr_of(W, V) ).
cpp_bitcount('__builtin_clz', clz, 32).   cpp_bitcount('__builtin_clzl', clz, 64).   cpp_bitcount('__builtin_clzll', clz, 64).   cpp_bitcount('__builtin_clzg', clz, any).
cpp_bitcount('__builtin_ctz', ctz, 32).   cpp_bitcount('__builtin_ctzl', ctz, 64).   cpp_bitcount('__builtin_ctzll', ctz, 64).   cpp_bitcount('__builtin_ctzg', ctz, any).
cpp_bitcount('__builtin_popcount', pop, 32).   cpp_bitcount('__builtin_popcountl', pop, 64).   cpp_bitcount('__builtin_popcountll', pop, 64).   cpp_bitcount('__builtin_popcountg', pop, any).
%% the count of the argument WRAPPED TO ITS WIDTH, unsigned: the width is the builtin's own (clz, ctz, popcount are `unsigned', `l' and `ll' 64 bits) or, for the `g' forms, the argument's type;
%% zero has no leading or trailing bit: the `g' forms answer their second argument, the others are undefined and do not fold
cpp_eval_bitcount(Dir, W0, X, Rest, Env, R) :-
    cpp_eval_reduce(X, Env, XR), cpp_eval_value(XR, V), ( integer(V) ; V = big(_) ),
    ( W0 == any -> cpp_eval_width(X, Env, W) ; W = W0 ),
    ccl_w_wrap(V, W, false, U), ccl_wide(U, w(_, Ls)),
    (   Dir == pop -> cpp_limb_bits(Ls, 0, R)
    ;   Ls == [] -> Rest = [Fb], cpp_eval_reduce(Fb, Env, FR), cpp_eval_value(FR, R), integer(R)
    ;   Dir == clz -> reverse(Ls, [Top|_]), length(Ls, K), cpp_bits_in(Top, 0, B), R is W - ((K - 1) * 30 + B)
    ;   cpp_zero_limbs(Ls, 0, K, L), cpp_trailing_bits(L, 0, T), R is K * 30 + T ).
cpp_eval_width(X, Env, W) :- ( cpp_eval_type_of(X, Env, T0) -> true ; X = cast(T0, _) -> true ; ccl_type_of(X, T0), T0 \== unknown ),
    ccl_unref(T0, T), ccl_size_of(T, S), S > 0, W is S * 8, !.
cpp_bits_in(0, B, B) :- !.
cpp_bits_in(V, B0, B) :- B1 is B0 + 1, V1 is V >> 1, cpp_bits_in(V1, B1, B).
cpp_zero_limbs([0|Ls], K0, K, L) :- !, K1 is K0 + 1, cpp_zero_limbs(Ls, K1, K, L).
cpp_zero_limbs([L|_], K, K, L).
cpp_trailing_bits(V, T0, T) :- ( V /\ 1 =:= 1 -> T = T0 ; T1 is T0 + 1, V1 is V >> 1, cpp_trailing_bits(V1, T1, T) ).
cpp_eval_elem(arr(L), K, V) :- K >= 0, nth0(K, L, V).
cpp_eval_elem(ptr(C, Path), K, V) :- cpp_eval_padd(ptr(C, Path), K, A), cpp_eval_load(A, V).
cpp_eval_strlen(P, K, N) :- K < 1000000, cpp_eval_padd(P, K, Q), cpp_eval_load(Q, C), integer(C), ( C =:= 0 -> N = K ; K1 is K + 1, cpp_eval_strlen(P, K1, N) ).
cpp_eval_deref(ptr(C, Path), V) :- cpp_eval_load(ptr(C, Path), V).
cpp_eval_deref(arr(L), V) :- nth0(0, L, V).
cpp_eval_ptr_bin(Op, A, B, V) :- cpp_eval_ptrish(A, P), cpp_eval_ptrish(B, Q), !, cpp_eval_poff(P, Q, O1, O2),
    ( Op == '-' -> V is O1 - O2 ; memberchk(Op, ['==', '!=', '<', '>', '<=', '>=']), ccl_const_op(Op, O1, O2, V) ).
cpp_eval_ptr_bin('+', A, B, V) :- cpp_eval_ptrish(A, P), cpp_eval_value(B, K), integer(K), !, cpp_eval_padd(P, K, V).
cpp_eval_ptr_bin('+', A, B, V) :- cpp_eval_ptrish(B, P), cpp_eval_value(A, K), integer(K), !, cpp_eval_padd(P, K, V).
cpp_eval_ptr_bin('-', A, B, V) :- cpp_eval_ptrish(A, P), cpp_eval_value(B, K), integer(K), !, K1 is -K, cpp_eval_padd(P, K1, V).
cpp_eval_ptr_bin(Op, A, B, V) :- memberchk(Op, ['==', '!=']), ( cpp_eval_ptrish(A, _), cpp_eval_value(B, 0) ; cpp_eval_ptrish(B, _), cpp_eval_value(A, 0) ), !,   % a pointer against null: never null here
    ( Op == '==' -> V = 0 ; V = 1 ).
cpp_eval_ptrish('$val'(ptr(B, P)), ptr(B, P)).
%% two pointers compared or subtracted: into the same array, the last step of their paths; else equal or not
cpp_eval_poff(ptr(C, P1), ptr(C, P2), O1, O2) :- append(Pre, [O1], P1), append(Pre, [O2], P2), integer(O1), integer(O2), !.
cpp_eval_poff(ptr(C, P1), ptr(C, P2), 0, 0) :- P1 == P2, !.
cpp_eval_poff(_, _, 0, 1).
cpp_eval_padd(ptr(cell(Id), ['$cookie']), K, P) :- cpp_eval_cookie(Id, Ck), !, ( K =:= 0 -> P = ptr(cell(Id), ['$cookie']) ; K =:= Ck -> P = ptr(cell(Id), ['$elems', 0]) ).   % a cookie block's start: itself, or its first element past the cookie (0.258)
cpp_eval_padd(ptr(cell(Id), ['$elems', 0]), K, ptr(cell(Id), ['$cookie'])) :- K < 0, cpp_eval_cookie(Id, Ck), K =:= -Ck, !.   % ... and back from the first element, `(char *)p - 8'
cpp_eval_padd(ptr(C, Path), K, ptr(C, Path1)) :- append(Pre, [Last], Path), integer(Last), !, L1 is Last + K, append(Pre, [L1], Path1).
cpp_eval_padd(ptr(C, []), 0, ptr(C, [])).                                                                     % `p + 0', `p[0]' on a pointer to a scalar
cpp_eval_cookie(Id, Ck) :- cpp_ec_get(Id, W), W = obj(Ps), memberchk('$ck'-Ck, Ps), !.
cpp_eval_add(P, K, V) :- P = ptr(_, _), !, cpp_eval_padd(P, K, V).
cpp_eval_add(flt(FK, X), K, V) :- !, cpp_eval_fbin('+', flt(FK, X), K, V).   % `x++' over a floating x (0.258)
cpp_eval_add(A, K, V) :- ccl_const_op('+', A, K, V).
cpp_eval_binop(Op, L, RV, V) :- L = ptr(_, _), !, ( Op == '+' -> cpp_eval_padd(L, RV, V) ; Op == '-' -> K is -RV, cpp_eval_padd(L, K, V) ).
cpp_eval_binop(Op, L, RV, V) :- ( L = flt(_, _) ; RV = flt(_, _) ), !, cpp_eval_fbin(Op, L, RV, V).   % `x += 0.5' (0.258)
cpp_eval_binop(Op, L, RV, V) :- ccl_const_op(Op, L, RV, V).
cpp_eval_scalar(V) :- ( integer(V) ; V = big(_) ), !.
%% AGGREGATES IN A CONSTEXPR BODY (0.97): a local ARRAY or STRUCT is a VALUE of the environment -- `arr(Elems)' of
%% values, `obj([Name-Value ...])' over the struct's data members in order -- built from its braced initializer (an
%% item by position, `.f = e' by name, a nested brace for a nested aggregate, what is left value-initialized to zero),
%% read and written through a PLACE (`a[i]', `p.x', `g[1][2]', `ps[i].y': cpp_eval_place, cpp_eval_store), and a
%% file-scope `const' aggregate with a constant initializer is such a value too (`'$cpp_gagg:N'', recorded where its
%% declaration item is walked), so `table[i]' folds inside a body and `table[2]' as a template argument or a bound.
%% A `switch' runs from the matching case label -- or default -- through the fallthrough to a `break'; a range-for
%% over an array binds each element in turn. A POINTER stays outside: the call stays a call (named, not done).
cpp_eval_init_term(V, int(V)) :- cpp_eval_scalar(V), !.
cpp_eval_init_term(flt(double, X), float(X)) :- !.   % a floating member's value as its literal (0.258)
cpp_eval_init_term(flt(float, X), cast(base([], [float]), float(X))) :- !.
cpp_eval_init_term(arr(L), init(Items)) :- !, cpp_eval_init_items(L, Items).
cpp_eval_init_term(obj(Ps), init(Items)) :- !, findall(X, member(_-X, Ps), Xs), cpp_eval_init_items(Xs, Items).
cpp_eval_init_term(ptr(cell(Id), [K]), T) :- integer(K), cpp_ec_str(Id), cpp_ec_get(Id, arr(L)), append(Cs, [0], L), !,   % A POINTER INTO A STRING LITERAL is the literal, at its offset (0.112): `constexpr string_view g{"hello"}'
    ( K =:= 0 -> T = str(Cs) ; T = bin('+', str(Cs), int(K)) ).
cpp_eval_init_term(ptr(cell(Id), [K]), T) :- integer(K), cpp_ec_lit(Id, W), W \== str, !,   % ... and into a wide one, as that literal (0.115)
    ( K =:= 0 -> T = W ; T = bin('+', W, int(K)) ).
%% every value is spelled, or the whole fails: a value it cannot spell -- a pointer to a local's cell -- had been DROPPED,
%% and the items after it moved up a member (`{ ptr 4, i64 0 }' for a string_view whose size is 4)
cpp_eval_init_items([], []).
cpp_eval_init_items([X|Xs], [item([], T)|Ts]) :- cpp_eval_init_term(X, T), !, cpp_eval_init_items(Xs, Ts).
cpp_eval_agg_kind(T, arr(B, ET)) :- ccl_resolve_type(T, arr(B, ET)), !.
cpp_eval_agg_kind(T, obj(Ms)) :- ccl_resolve_type(T, T1), ( T1 = base(_, [struct(_, Ms0)]), Ms0 \== none ; T1 = base(_, [class(_, _, _, _)]) ), !, ccl_members_of(T1, Ms).
cpp_eval_agg_kind(T, uni(Ms)) :- ccl_resolve_type(T, base(_, [union(_, Ms0)])), is_list(Ms0), !, ccl_data_members(Ms0, Ms).   % A UNION (0.234): its value the ACTIVE member, `uni(F-V, Members)', or none -- its data members alone, a union class's `union_tag' mark dropped (0.257: libc++ 22's `__rep', the mark taken for its first member)
cpp_eval_init(T, Init, Env0, Env, V) :- cpp_eval_agg_kind(T, K), !, cpp_eval_agg_init(K, Init, Env0, Env, V).
cpp_eval_init(T, Init, Env, Env, P) :- cpp_eval_ref_type(T), ( Init = init([item(_, E)]) -> true ; E = Init ), E \= init(_), E \== none, \+ cpp_eval_address_item(E, T, Env), !, cpp_eval_arg(T, E, Env, '$val'(P)).   % A REFERENCE MEMBER BINDS ITS ITEM (0.168): its slot holds the item's address (a prvalue's in a cell of its own), as the lowering binds it (ir_init_sub); a closure's item is that address already
cpp_eval_init(_, none, Env, Env, 0) :- !.
cpp_eval_init(_, init([]), Env, Env, 0) :- !.
cpp_eval_init(T, init([item(_, E)]), Env0, Env, V) :- !, cpp_eval_effect(E, Env0, Env, V0), cpp_eval_simple(V0), cpp_eval_num_to(T, V0, V).   % a braced scalar
cpp_eval_init(T, E, Env0, Env, V) :- cpp_eval_effect(E, Env0, Env, V0), cpp_eval_simple(V0), cpp_eval_num_to(T, V0, V).
cpp_eval_num_to(T, V0, V) :- ( V0 = flt(_, _) -> true ; catch(cpp_eval_float_kind(T, _), _, fail) ), !, cpp_eval_conv_ptr(T, none, [], V0, V).   % an item of its member's type: `{1.5, 2}' into two doubles (0.258)
cpp_eval_num_to(_, V, V).
%% AN ADDRESS ITEM of a reference member -- the item a closure gives a capture by reference, `&x' or `this' -- is a
%% pointer to the referent's type, as the lowering tells it (ir_address_item/2): the slot takes the pointer as it is.
%% Where a type is not known, `&x' for a reference to no pointer is one (no valid initializer is). (0.168)
cpp_eval_address_item(V, T, Env) :- T =.. [_, _, R], cpp_eval_item_pointee(V, Env, E), cpp_eval_core(E, U), cpp_eval_core(R, U1), !, U == U1.
cpp_eval_address_item(addr(_), T, _) :- T =.. [_, _, R], \+ ccl_resolve_type(R, ptr(_, _)).
cpp_eval_item_pointee(addr(X), Env, E) :- !, cpp_eval_type_of(X, Env, XT), ( cpp_eval_ref_type(XT) -> XT =.. [_, _, E] ; E = XT ).
cpp_eval_item_pointee(V, Env, E) :- cpp_eval_type_of(V, Env, VT), ccl_resolve_type(VT, ptr(_, E)).
cpp_eval_core(T, U) :- catch(ccl_type_canon(T, K), _, fail), cpp_eval_core_(K, U).
cpp_eval_core_(base(_, S), base([], S)) :- !.
cpp_eval_core_(ptr(K), ptr(K1)) :- !, cpp_eval_core_(K, K1).
cpp_eval_core_(K, K).
cpp_eval_simple(V) :- ( cpp_eval_scalar(V) ; V = ptr(_, _) ; V = fn(_) ; V = flt(_, _) ), !.   % a scalar, a POINTER or a FUNCTION POINTER (0.164): `__parse_number_result{__begin, __value}' holds a pointer
cpp_eval_zeroed(arr(L), arr(Z)) :- !, findall(Y, ( member(X, L), cpp_eval_zeroed(X, Y) ), Z).
cpp_eval_zeroed(obj(Ps), obj(Zs)) :- !, findall(N-Y, ( member(N-X, Ps), cpp_eval_zeroed(X, Y) ), Zs).
cpp_eval_zeroed(uni(_, Ms), uni(F-Z, Ms)) :- Ms = [member(MT, F, _)|_], !, cpp_eval_zero(MT, Z).   % A ZEROED UNION'S FIRST MEMBER IS ZERO AND ACTIVE ([dcl.init]/6.4; 0.257): libc++ 22's `__rep_ = __rep()' through the desugaring's zeroing made the union 0, and no member of it could be stored
cpp_eval_zeroed(_, 0).
cpp_eval_agg_init(arr(B, ET), Init, Env0, Env, arr(L)) :- ( Init == none ; Init == init([]) ), !, Env = Env0, cpp_eval_expr(B, Env0, K), integer(K), cpp_eval_zero(ET, Z), length(L, K), cpp_eval_all(L, Z).
cpp_eval_agg_init(arr(B, ET), init(Items), Env0, Env, arr(L)) :- !, cpp_eval_items(Items, ET, Env0, Env, L0), length(L0, N0),
    ( B == none -> K = N0 ; cpp_eval_expr(B, Env0, K), integer(K), K >= N0 ), P is K - N0, cpp_eval_zero(ET, Z), length(Pad, P), cpp_eval_all(Pad, Z), append(L0, Pad, L).
cpp_eval_agg_init(arr(_, _), E, Env0, Env, V) :- cpp_eval_effect(E, Env0, Env, V), V = arr(_).
cpp_eval_agg_init(obj(Ms), Init, Env, Env, obj(Ps)) :- ( Init == none ; Init == init([]) ), !, cpp_eval_members_zero(Ms, Ps).
cpp_eval_agg_init(uni(Ms), Init, Env, Env, uni(none, Ms)) :- ( Init == none ; Init == init([]) ), !.   % A UNION'S VALUE IS ITS ACTIVE MEMBER (0.234; [class.union]/2): none until one is written,
cpp_eval_agg_init(uni(Ms), init([item([], E)]), Env0, Env, uni(F-V, Ms)) :- Ms = [member(MT, F, _)|_], !, cpp_eval_init(MT, E, Env0, Env, V).   % ... a braced item the first member's
cpp_eval_agg_init(uni(Ms), init([item([field(F)], E)]), Env0, Env, uni(F-V, Ms)) :- !, memberchk(member(MT, F, _), Ms), cpp_eval_init(MT, E, Env0, Env, V).   % ... a designated one the member it names (0.257; [dcl.init.aggr]/3.1: `UU u{.i = 3}')
cpp_eval_agg_init(obj(Ms), init(Items), Env0, Env, obj(Ps)) :- !, cpp_eval_members_zero(Ms, Ps0), cpp_eval_fields(Items, Ms, 0, Ps0, Env0, Env, Ps).
cpp_eval_agg_init(obj(Ms), compound_lit(_, I), Env0, Env, V) :- !, cpp_eval_agg_init(obj(Ms), I, Env0, Env, V).
cpp_eval_agg_init(obj(_), E, Env0, Env, V) :- cpp_eval_effect(E, Env0, Env, V), V = obj(_).
cpp_eval_items([], _, Env, Env, []).
cpp_eval_items([item([], E)|Is], ET, Env0, Env, [V|Vs]) :- cpp_eval_init(ET, E, Env0, Env1, V), cpp_eval_items(Is, ET, Env1, Env, Vs).
cpp_eval_fields([], _, _, Ps, Env, Env, Ps).
cpp_eval_fields([item([], E)|Is], Ms, I, Ps0, Env0, Env, Ps) :- E \= init(_), nth0(I, Ms, member(MT, F, _)), cpp_eval_agg_kind(MT, arr(B, ET)),
    cpp_eval_effect(E, Env0, Env1, V0), V0 \= arr(_), !,   % BRACE ELISION (0.164): `array<T, N>{a, b}' -- an array member given an item that is no braced list and no array takes the items that follow
    cpp_eval_expr(B, Env1, K), integer(K), K1 is K - 1, cpp_eval_take(K1, Is, Taken, Rest), cpp_eval_items(Taken, ET, Env1, Env2, Vs0),
    cpp_eval_zero(ET, Z), length(Vs0, N0), Pad is K - 1 - N0, length(PadL, Pad), cpp_eval_all(PadL, Z), append([V0|Vs0], PadL, L),
    cpp_eval_put_field(F, arr(L), Ps0, Ps1), I1 is I + 1, cpp_eval_fields(Rest, Ms, I1, Ps1, Env2, Env, Ps).
cpp_eval_fields([item(Ds, E)|Is], Ms, I0, Ps0, Env0, Env, Ps) :-
    ( Ds = [field(F)|_] -> nth0(I, Ms, member(MT, F, _)) ; Ds == [], I = I0, nth0(I, Ms, member(MT, F, _)) ),
    cpp_eval_init(MT, E, Env0, Env1, V), cpp_eval_put_field(F, V, Ps0, Ps1), I1 is I + 1, cpp_eval_fields(Is, Ms, I1, Ps1, Env1, Env, Ps).
cpp_eval_take(0, Is, [], Is) :- !.
cpp_eval_take(_, [], [], []) :- !.
cpp_eval_take(K, [I|Is], [I|Ts], Rest) :- K1 is K - 1, cpp_eval_take(K1, Is, Ts, Rest).
cpp_eval_members_zero([], []).
cpp_eval_members_zero([member(MT, N, _)|Ms], [N-Z|Ps]) :- cpp_eval_zero(MT, Z), cpp_eval_members_zero(Ms, Ps).
cpp_eval_zero(T, V) :- cpp_eval_agg_kind(T, K), !, cpp_eval_agg_init(K, none, [], _, V).
cpp_eval_zero(_, 0).
cpp_eval_all([], _).
cpp_eval_all([Z|L], Z) :- cpp_eval_all(L, Z).
cpp_eval_placeish(id(_)).
cpp_eval_placeish(index(P, _)) :- cpp_eval_placeish(P).
cpp_eval_placeish(member(P, _)) :- cpp_eval_placeish(P).
cpp_eval_placeish(arrow(P, _)) :- cpp_eval_placeish(P).
cpp_eval_placeish(deref(_)).   % EVERY `*p' IS A PLACE (0.258; [expr.unary.op]/1), its address the pointer's value: `*(unsigned long *)(raw + 0) = n', an array new's cookie, and `*(p + 1) = v' were no assignment
cpp_eval_placeish(call(id(F), _)) :- cpp_eval_ref_fn(F).   % A CALL OF A FUNCTION THAT RETURNS A REFERENCE IS A PLACE TO STORE THROUGH (0.201): `__partial_sums[__i] = __running_sum;' over a std::array in <mdspan>'s `__static_partial_sums', and `constexpr std::array<int, 3> r = f();' over such a store was a run-time initialization
%% THE ADDRESS OF A PLACE (0.99): a name's cell (an alias: what it aliases; a const global: a cell holding its value, one
%% per fold), an element (the array's address one step deeper, or a pointer's value stepped), a member, `p->f', `*p'
cpp_eval_addr(id(N), Env, A) :- memberchk(N-B, Env), !, ( B = '$cell'(Id) -> A = ptr(cell(Id), []) ; B = '$alias'(A) ).
cpp_eval_addr(id(N), _, ptr(cell(Id), [])) :- cpp_global_agg(N, V), atom_concat('$cpp_gcell:', N, GK),
    ( nb_current(GK, Id0), cpp_ec_get(Id0, V0), V0 == V -> Id = Id0 ; cpp_ec_new(V, Id), nb_setval(GK, Id) ).
cpp_eval_addr(index(P, I), Env, A) :- cpp_eval_expr(I, Env, K), integer(K),
    (   cpp_eval_addr(P, Env, ptr(C, Path)), cpp_eval_shape(ptr(C, Path), arr(_)) -> append(Path, [K], Path1), A = ptr(C, Path1)
    ;   cpp_eval_expr(P, Env, PV), PV = ptr(_, _), cpp_eval_padd(PV, K, A) ).
cpp_eval_addr(member(P, F), Env, A) :- cpp_eval_addr(P, Env, ptr(C, Path)), cpp_eval_shape(ptr(C, Path), W), cpp_eval_has_members(W), cpp_eval_member_path(W, Path, F, Path1), cpp_eval_ref_through(member(P, F), Env, ptr(C, Path1), A).
cpp_eval_addr(arrow(P, F), Env, A) :- cpp_eval_expr(P, Env, ptr(C, Path)), cpp_eval_shape(ptr(C, Path), W), cpp_eval_has_members(W), cpp_eval_member_path(W, Path, F, Path1), cpp_eval_ref_through(arrow(P, F), Env, ptr(C, Path1), A).
cpp_eval_addr(deref(P), Env, A) :- cpp_eval_expr(P, Env, A), A = ptr(_, _).
cpp_eval_addr(move(E), Env, A) :- cpp_eval_addr(E, Env, A).
cpp_eval_addr(ccast(_, T, E), Env, ptr(C, Path1)) :- cpp_eval_ref_type(T), cpp_eval_addr(E, Env, ptr(C, Path)), cpp_eval_base_path(T, E, Env, Hops), !, append(Path, Hops, Path1).   % A CAST TO A BASE'S REFERENCE names the base sub-object (0.168): libc++'s `std::get<I>(t)' is `static_cast<__tuple_leaf<I, T> &>(t.__base_).get()', the I-th leaf a later base of `__tuple_impl', and the cast named the whole object, which has no `__value_' of its own
cpp_eval_addr(ccast(_, T, E), Env, A) :- cpp_eval_ref_type(T), cpp_eval_addr(E, Env, A).
cpp_eval_addr(cast(T, E), Env, A) :- cpp_eval_ref_type(T), cpp_eval_addr(E, Env, A).
cpp_eval_addr(id(N), Env, ptr(cell(Id), [])) :- \+ memberchk(N-_, Env), cpp_eval_static_cell(N, Id).
cpp_eval_addr(call(id(F), Args), Env, A) :- cpp_eval_ref_fn(F), cpp_eval_fn(F, Params, Ss), !, cpp_eval_args(Params, Args, Env, Args1), cpp_eval_call(F, Params, Ss, Args1, A), A = ptr(_, _).   % a call of a function that returns a reference: its referent (0.168)
%% an object whose members an address goes into: a class's, and a union's, through its active member or one written next (0.234)
cpp_eval_has_members(obj(_)).
cpp_eval_has_members(uni(_, _)).
%% A FIRST BASE'S MEMBER THROUGH THE DERIVED OBJECT (0.257): the desugaring writes no cast to a first base, which lies at the object's
%% own address, so a pointer of the base's type may name the derived object -- `Base *b = &d' is `&d' -- and its member, `b->$vptr',
%% is the base's, down the `$base' chain
cpp_eval_member_path(obj(Ps), Path, F, Path1) :- \+ memberchk(F-_, Ps), memberchk('$base'-W, Ps), !, append(Path, ['$base'], Path0), cpp_eval_member_path(W, Path0, F, Path1).
cpp_eval_member_path(_, Path, F, Path1) :- append(Path, [F], Path1).
%% AN OBJECT WITHIN ITS LIFETIME (0.234; C++26 [meta.const.eval], `__builtin_is_within_lifetime'): a union's member is
%% where it is the active one; any other object the pointer reaches is
cpp_eval_alive(ptr(cell(Id), Path)) :- append(Pre, [F], Path), atom(F), cpp_eval_load(ptr(cell(Id), Pre), uni(U, _)), !, U = G-_, G == F.
cpp_eval_alive(P) :- cpp_eval_load(P, _).
%% A CLASS'S STATIC CONSTANT AS A PLACE (0.164): `basic_format_string's `__types_' and `__handles_', whose `.data()' the
%% check hands its context -- the static's initializer desugared in its class, its type resolved there, its value built
%% by the evaluator (the handles by the lambdas called in place) into a cell once per unit (`'$cpp_scell'(Name, Id)'),
%% the statement's register of temporaries set aside while it is desugared
cpp_eval_static_cell(N, Id) :- '$cpp_scell'(N, Id0), !, Id = Id0.
cpp_eval_static_cell(N, Id) :- atom(N), cpp_static_split(N, C, SN), '$cpp_sinit'(C, SN, Init), ccl_declared(N, T0), nonvar(T0),
    ccl_global('$cpp_temps', Ts, none), nb_setval('$cpp_temps', none),
    (   once(catch(cpp_isolated(cpp_in_class(C, ( cpp_type(T0, T), cpp_init_expr(Init, I0) ))), error(not_lowered(_), _), fail)) -> nb_setval('$cpp_temps', Ts)
    ;   nb_setval('$cpp_temps', Ts), fail ),
    cpp_eval_init(T, I0, [], _, V), cpp_ec_new(V, Id), assertz('$cpp_scell'(N, Id)).
cpp_static_split(N, C, SN) :- atomic_list_concat(Ps, '.', N), Ps = [_, _|_], append(CPs, [SN], Ps), SN \== '', !, atomic_list_concat(CPs, '.', C).   % the name SPLIT ONCE (0.165): it searched the name for each dot and each suffix for another, a million times in a std::visit build
cpp_eval_load(ptr(cell(Id), Path), V) :- cpp_ec_get(Id, W), W \= '$unseen'(_), cpp_eval_at(W, Path, V).
%% THE SHAPE AT A PLACE, for its address alone (0.257): what it holds, or -- down an inactive union member, which a store begins
%% (cpp_eval_upd/4) -- that member's type's zero value; a read of it is no constant expression still (cpp_eval_at/3)
cpp_eval_shape(ptr(cell(Id), Path), V) :- cpp_ec_get(Id, W), cpp_eval_shape_at(W, Path, V).
cpp_eval_shape_at(V, [], V) :- !.
cpp_eval_shape_at(uni(Act, Ms), [F|P], V) :- atom(F), \+ Act = F-_, !, memberchk(member(MT, F, _), Ms), cpp_eval_zero(MT, Z), cpp_eval_shape_at(Z, P, V).
cpp_eval_shape_at(W, [K|P], V) :- cpp_eval_at(W, [K], X), cpp_eval_shape_at(X, P, V).
cpp_eval_at(V, [], V) :- !.
cpp_eval_at(arr(L), [K|P], V) :- integer(K), K >= 0, nth0(K, L, X), cpp_eval_at(X, P, V).
cpp_eval_at(obj(Ps), [F|P], V) :- atom(F), memberchk(F-X, Ps), cpp_eval_at(X, P, V).
cpp_eval_at(uni(G-X, _), [F|P], V) :- atom(F), F == G, cpp_eval_at(X, P, V).   % the active member alone is read: another's read is no constant expression (0.234)
cpp_eval_upd(_, [], V, V) :- !.
cpp_eval_upd(arr(L), [K|P], V, arr(L1)) :- integer(K), K >= 0, nth0(K, L, X), cpp_eval_upd(X, P, V, X1), cpp_eval_put(K, L, X1, L1).
cpp_eval_upd(obj(Ps), [F|P], V, obj(Ps1)) :- atom(F), memberchk(F-X, Ps), cpp_eval_upd(X, P, V, X1), cpp_eval_put_field(F, X1, Ps, Ps1).
cpp_eval_upd(uni(G-X, Ms), [F|P], V, uni(F-X1, Ms)) :- atom(F), F == G, !, cpp_eval_upd(X, P, V, X1).
cpp_eval_upd(uni(_, Ms), [F], V, uni(F-V, Ms)) :- atom(F), !.   % a member written whole is the active one (0.234; [class.union]/6)
cpp_eval_upd(uni(_, Ms), [F|P], V, uni(F-X1, Ms)) :- atom(F), memberchk(member(MT, F, _), Ms), cpp_eval_zero(MT, Z), cpp_eval_upd(Z, P, V, X1).   % A STORE INTO A MEMBER OF AN INACTIVE MEMBER BEGINS ITS LIFETIME ([class.union.general]/6; 0.257): `__r_.first().__s.__size_ = n' makes `__s' the active member, its other parts zero where they were indeterminate
cpp_eval_store_ptr(ptr(cell(Id), Path), V) :- cpp_ec_get(Id, W0), W0 \= '$unseen'(_), cpp_eval_upd(W0, Path, V, W1), cpp_ec_put(Id, W1).
cpp_eval_decay(arr(_), ptr(C, Path), '$val'(ptr(C, Path1))) :- !, append(Path, [0], Path1).                   % an array is a pointer to its first element
cpp_eval_decay(V, _, R) :- cpp_eval_lit(V, R).
%% `sizeof' over a local or a parameter: its declared type, an unbounded array's from its value
cpp_eval_sizeof(E, Env, S) :- cpp_eval_type_of(E, Env, T0), ( cpp_eval_ref_type(T0) -> T0 =.. [_, _, T] ; T = T0 ),
    (   ccl_resolve_type(T, arr(B, ET)), \+ ( B \== none, ccl_const_eval(B, _) ) -> cpp_eval_place(E, Env, arr(L)), length(L, K), ccl_size_of(ET, S1), S is K * S1
    ;   ccl_size_of(T, S) ).
cpp_eval_type_of(id(N), Env, T) :- memberchk('$t'(N)-T, Env), !.
cpp_eval_type_of(index(E, _), Env, ET) :- cpp_eval_type_of(E, Env, T), ( ccl_resolve_type(T, arr(_, ET)) ; ccl_resolve_type(T, ptr(_, ET)) ), !.
cpp_eval_type_of(deref(E), Env, ET) :- cpp_eval_type_of(E, Env, T), ( ccl_resolve_type(T, ptr(_, ET)) ; ccl_resolve_type(T, arr(_, ET)) ), !.
cpp_eval_type_of(member(E, F), Env, MT) :- cpp_eval_type_of(E, Env, T0), ( cpp_eval_ref_type(T0) -> T0 =.. [_, _, T] ; T = T0 ), cpp_eval_agg_kind(T, obj(Ms)), memberchk(member(MT, F, _), Ms), !.   % a reference's member is its referent's (0.168)
cpp_eval_type_of(arrow(E, F), Env, MT) :- cpp_eval_type_of(E, Env, T), ccl_resolve_type(T, ptr(_, PT)), cpp_eval_agg_kind(PT, obj(Ms)), memberchk(member(MT, F, _), Ms), !.
cpp_eval_place(P, Env, V) :- cpp_eval_addr(P, Env, A), cpp_eval_load(A, V).
%% A REFERENCE MEMBER NAMES ITS REFERENT (0.168): its slot holds the address it was bound to -- a closure's `$this' and its
%% captures by reference, built as a compound literal of addresses -- so the place `x.r' is that address; the tuple
%% formatter's `[&]<size_t _Index> { auto &__formatter = std::get<_Index>(__underlying_); ... }' reads `this->$this.__underlying_'
cpp_eval_ref_through(E, Env, A0, A) :- cpp_eval_load(A0, V), V = ptr(_, _), cpp_eval_type_of(E, Env, MT), cpp_eval_ref_type(MT), !, A = V.
cpp_eval_ref_through(_, _, A, A).
%% the hops from an object's class down to a base's sub-object, as the desugaring names them (cpp_base_hops/3: `$base',
%% `$base$K'), where the cast's class is a base of the operand's
cpp_eval_base_path(T, E, Env, Hops) :- T =.. [_, _, BT], catch(cpp_class_of_type(BT, B), _, fail), cpp_eval_type_of(E, Env, ET0),
    ( cpp_eval_ref_type(ET0) -> ET0 =.. [_, _, ET] ; ET = ET0 ), catch(cpp_class_of_type(ET, D), _, fail), D \== B,
    catch(once(cpp_base_hops(D, B, Hops)), _, fail), Hops \== [].
%% A POINTER OR A REFERENCE TO A CLASS CONVERTED TO ITS BASE'S OR ITS DERIVED CLASS'S, as the lowering converts it (0.258, ir_convert/6):
%% up, the base sub-object's path added; down, taken off. A first base's step is dropped where it ends a path: its sub-object is
%% the object's own address, which the desugaring writes no cast for (cpp_eval_member_path/4 finds its members). The evaluator
%% kept every pointer as it came, so `B *pb = &d' over `struct D : A, B' named the whole D: `pb->b' found no `b', and a
%% dynamic_cast's base answered `$base' where `&d' is the object -- `pa == &d' was false
cpp_eval_conv_ptr(T, _, _, V0, V) :- cpp_eval_float_kind(T, K), !, K \== wide, cpp_eval_fnum(V0, _, X0), cpp_eval_round(K, X0, X), V = flt(K, X).   % TO A FLOATING TYPE, the value of that type; a long double is none here (0.258)
cpp_eval_conv_ptr(T, _, _, flt(_, X), V) :- cpp_eval_int_type(T), !, ccl_w_cast(T, X, V).   % ... and a floating value to an integer type, truncated (0.258)
cpp_eval_conv_ptr(T, E, Env, V0, V) :- V0 = ptr(_, _), cpp_eval_target_class(T, B), cpp_eval_static_class(E, Env, D), D \== B, !, cpp_eval_conv_class(D, B, V0, V).
cpp_eval_conv_ptr(_, _, _, V, V).
cpp_eval_conv_class(D, B, ptr(Cell, Path), V) :- catch(once(cpp_base_hops(D, B, Hops0)), _, fail), !, cpp_eval_trim_base(Hops0, Hops), append(Path, Hops, Path1), V = ptr(Cell, Path1).
cpp_eval_conv_class(D, B, ptr(Cell, Path), V) :- catch(once(cpp_base_hops(B, D, Hops0)), _, fail), cpp_eval_trim_base(Hops0, Hops), append(Path1, Hops, Path), !, V = ptr(Cell, Path1).
cpp_eval_conv_class(_, _, V, V).
cpp_eval_conv_val(T, A, Env, '$val'(P0), '$val'(P)) :- !, cpp_eval_conv_ptr(T, A, Env, P0, P).
cpp_eval_conv_val(T, A, Env, V0, '$val'(V)) :- cpp_eval_float_kind(T, _), !, cpp_eval_value(V0, X0), cpp_eval_conv_ptr(T, A, Env, X0, V).   % an argument of a floating parameter, of the parameter's type (0.258)
cpp_eval_conv_val(T, _, _, V0, int(V)) :- cpp_eval_float_term(V0), cpp_eval_int_type(T), cpp_eval_value(V0, flt(_, X)), !, ccl_w_cast(T, X, V).
cpp_eval_conv_val(_, _, _, V, V).
cpp_eval_conv_ret(Env, E, V0, V) :- ( memberchk('$ret'-RT, Env) -> cpp_eval_conv_ptr(RT, E, Env, V0, V) ; V = V0 ).
cpp_eval_ret_type(F, Ret) :- atom(F), ( '$cpp_out'(F, function(_, _, Ret, F, _, _, _)) ; '$cpp_ownfn'(F, function(_, _, Ret, F, _, _, _)) ), !.
%% the hops with the first bases' steps that end them dropped
cpp_eval_trim_base(Hops0, Hops) :- append(Hops, Tail, Hops0), \+ ( member(H, Tail), H \== '$base' ), !.
%% the class a pointer type or a reference type names, or a class type's own
cpp_eval_target_class(T0, C) :- cpp_eval_unref(T0, T1), ( catch(ccl_resolve_type(T1, ptr(_, T)), _, fail) -> true ; T = T1 ), catch(cpp_class_of_type(T, C), _, fail).
cpp_eval_unref(T0, T) :- ( cpp_eval_ref_type(T0) -> T0 =.. [_, _, T] ; T = T0 ).
%% THE STATIC CLASS OF AN EXPRESSION (0.258): what its pointer or its reference names, or an object's class -- a local's or a
%% parameter's declared type, an address's operand, a cast's target
cpp_eval_static_class(addr(X), Env, C) :- !, cpp_eval_type_of(X, Env, T0), cpp_eval_unref(T0, T), catch(cpp_class_of_type(T, C), _, fail).
cpp_eval_static_class(cast(T, _), _, C) :- !, cpp_eval_target_class(T, C).
cpp_eval_static_class(ccast(_, T, _), _, C) :- !, cpp_eval_target_class(T, C).
cpp_eval_static_class(dyncast(_, _, _, T), _, C) :- !, cpp_eval_target_class(T, C).
cpp_eval_static_class(E, Env, C) :- cpp_eval_type_of(E, Env, T), cpp_eval_target_class(T, C).
%% FLOATING ARITHMETIC IN A CONSTANT EVALUATION (0.258; [expr.const], [conv.fpint], [expr.arith.conv]): a `float' or a `double' value
%% is flt(Kind, X), X the double it is (a float's rounded to its 24 bits). A literal, a cast and a parameter, a local, a return or a
%% store of a floating type make one; the four operations, the comparisons, `-', `!' and the conversions take them -- the operands
%% converted to their common type, the operation exact and rounded to that type (the lowering's own fold: ir_fp_op/4, ir_fp_to/3),
%% a floating value to an integer truncated toward zero (ccl_w_cast/3), a floating zero false. A division by zero and a NaN are no
%% constant, as clang++ refuses them, and an overflow is the infinity clang++ folds; a `long double' or a `_Float16' is no value here (`wide'), and a
%% fold over one fails. 0.257 held a floating value and computed with none: `constexpr double area(double r) { return 3.14159 * r * r;
%% }' did not fold, a static assertion over it was refused, and a double parameter bound to `2' kept the integer
cpp_eval_float_kind(T, K) :- catch(ccl_resolve_type(T, base(_, S)), _, fail), \+ memberchk('_Complex', S),
    ( memberchk(float, S) -> K = float ; memberchk(double, S) -> ( memberchk(long, S) -> K = wide ; K = double ) ; memberchk('_Float16', S) -> K = wide ), !.
cpp_eval_int_type(T) :- catch(ccl_resolve_type(T, RT), _, fail), ccl_cast_shape(RT, _, _), !.
cpp_eval_float_term('$val'(flt(_, _))) :- !.
cpp_eval_float_term(E) :- ccl_float_shaped(E).
cpp_eval_fnum('$val'(V), K, X) :- !, cpp_eval_fnum(V, K, X).
cpp_eval_fnum(flt(K, X), K, X) :- !.
cpp_eval_fnum(V, int, X) :- integer(V), !, X is float(V).
cpp_eval_fnum(V, int, X) :- V = big(_), !, ccl_w_float(V, X).
cpp_eval_fnum(R, K, X) :- cpp_eval_fconst(R, K, X), !.
cpp_eval_fnum(R, int, X) :- cpp_eval_value(R, V), ( integer(V) -> X is float(V) ; V = big(_) -> ccl_w_float(V, X) ).
%% a floating constant the reader spells -- `float(X)', a double; `cast(float, float(X))', a float; a sign or an operation over them --
%% its value through the folding the lowering gives a constant (ccl_float_operand/2), rounded to its kind
cpp_eval_fconst(float(X0), double, X) :- !, float(X0), X = X0.
cpp_eval_fconst(R, K, X) :- ccl_float_shaped(R), catch(ccl_type_of(R, T), _, fail), cpp_eval_float_kind(T, K), K \== wide, catch(ccl_float_operand(R, X0), _, fail), float(X0), cpp_eval_round(K, X0, X).
cpp_eval_round(float, X0, X) :- !, catch(ir_fp_to(float, X0, X), _, fail), cpp_eval_number(X).
cpp_eval_round(double, X0, X) :- !, ( float(X0) -> X = X0 ; X is float(X0) ), cpp_eval_number(X).
cpp_eval_round(int, X0, X) :- cpp_eval_round(double, X0, X).
cpp_eval_number(X) :- float(X), X =:= X.   % an infinity is a value, as clang++ takes `1e308 * 10'; a NaN is none
cpp_eval_fkind(KA, KB, K) :- ( ( KA == double ; KB == double ) -> K = double ; K = float ).
cpp_eval_fbin(Op, A, B, V) :- cpp_eval_fnum(A, KA, XA0), cpp_eval_fnum(B, KB, XB0), ( KA \== int ; KB \== int ), !, cpp_eval_fkind(KA, KB, K),
    cpp_eval_round(K, XA0, XA), cpp_eval_round(K, XB0, XB),
    (   memberchk(Op, ['+', '-', '*', '/']) -> \+ ( Op == '/', XB =:= 0.0 ), catch(ir_fp_op(Op, XA, XB, X0), _, fail), cpp_eval_round(K, X0, X), V = flt(K, X)   % a division by zero is no constant
    ;   cpp_eval_fcmp(Op, XA, XB, V) ).
cpp_eval_fcmp('==', A, B, V) :- !, ( A =:= B -> V = 1 ; V = 0 ).
cpp_eval_fcmp('!=', A, B, V) :- !, ( A =\= B -> V = 1 ; V = 0 ).
cpp_eval_fcmp('<', A, B, V) :- !, ( A < B -> V = 1 ; V = 0 ).
cpp_eval_fcmp('>', A, B, V) :- !, ( A > B -> V = 1 ; V = 0 ).
cpp_eval_fcmp('<=', A, B, V) :- !, ( A =< B -> V = 1 ; V = 0 ).
cpp_eval_fcmp('>=', A, B, V) :- ( A >= B -> V = 1 ; V = 0 ).
cpp_eval_false(V) :- ( V == 0 -> true ; V = flt(_, X), X =:= 0.0 ).
%% A CONSTEXPR FLOATING OBJECT'S VALUE (0.258): a local's is its frame's entry `'$cvf'(N)-flt(K, X)', which the innermost frame that
%% holds the name decides, a file-scope one's the global `'$cpp_gflt:N'' (cpp_note_const/5, cpp_fold_const_inits_/5); a `const'
%% one that is not constexpr is no value ([expr.const]/4), as clang++ refuses a read of it
cpp_eval_flt_const(N, F) :- ccl_locals(Fs), ccl_frame_with(Fs, N, Fr), !, memberchk('$cvf'(N)-F, Fr).
cpp_eval_flt_const(N, F) :- atom_concat('$cpp_gflt:', N, K), nb_current(K, F).
cpp_eval_note_flt(T, I, V) :- catch(cpp_eval_float_kind(T, K), _, fail), K \== wide, catch(cpp_eval_expr(I, [], V0), _, fail), catch(cpp_eval_conv_ptr(T, I, [], V0, V), _, fail), V = flt(_, _), !, nb_setval('$cpp_flt_seen', yes).
cpp_eval_store(P, V, Env, Env) :- cpp_eval_addr(P, Env, A), cpp_eval_store_ptr(A, V).
cpp_eval_put(0, [_|L], V, [V|L]) :- !.
cpp_eval_put(K, [X|L0], V, [X|L]) :- K > 0, K1 is K - 1, cpp_eval_put(K1, L0, V, L).
cpp_eval_put_field(F, V, [F-_|Ps], [F-V|Ps]) :- !.
cpp_eval_put_field(F, V, [X|Ps0], [X|Ps]) :- cpp_eval_put_field(F, V, Ps0, Ps).
%% a LOCAL's noted aggregate, from the innermost open frame that holds its name (0.257, cpp_note_local_agg/3): a local of the name
%% with no note there is no constant, and hides a file-scope one
cpp_global_agg(N, V) :- atom(N), ccl_locals(Fs), ccl_frame_with(Fs, N, F), !, memberchk('$lagg'(N)-agg(T, Init), F), cpp_agg_value(T, Init, V).
%% a file-scope `const' aggregate with a constant initializer, as a value (recorded by cpp_fold_const_inits_)
cpp_global_agg(N, V) :- atom(N), atom_concat('$cpp_gagg:', N, K), nb_current(K, agg(T, Init, global)), cpp_agg_value(T, Init, V).
cpp_agg_value(_, '$value'(V0), V) :- !, V = V0.   % a constexpr local object's VALUE itself (0.257)
cpp_agg_value(T, Init, V) :- cpp_eval_init(T, Init, [], _, V).
cpp_eval_switch_flat([], []).
cpp_eval_switch_flat([case(_, C, S)|Is], [label(C)|Flat]) :- !, cpp_eval_switch_flat([S|Is], Flat).
cpp_eval_switch_flat([default(_, S)|Is], [label(default)|Flat]) :- !, cpp_eval_switch_flat([S|Is], Flat).
cpp_eval_switch_flat([S|Is], [S|Flat]) :- cpp_eval_switch_flat(Is, Flat).
cpp_eval_switch_run([], Env, Env, next).
cpp_eval_switch_run([label(_)|Ss], Env0, Env, R) :- !, cpp_eval_switch_run(Ss, Env0, Env, R).
cpp_eval_switch_run([S|Ss], Env0, Env, R) :- cpp_eval_step, cpp_eval_stmt(S, Env0, Env1, R1), ( R1 == next -> cpp_eval_switch_run(Ss, Env1, Env, R) ; Env = Env1, R = R1 ).
cpp_eval_foreach([], _, _, Env, Env, next).
cpp_eval_foreach([X|Xs], N, S, Env0, Env, R) :- cpp_eval_step, cpp_ec_new(X, Id), cpp_eval_block(S, [N-'$cell'(Id)|Env0], [_|Env2], R1),
    ( R1 = ret(_) -> Env = Env2, R = R1 ; R1 == break -> Env = Env2, R = next ; cpp_eval_foreach(Xs, N, S, Env2, Env, R) ).
cpp_const_reduce(E, int(V)) :- compound(E), ( E = call(_, _) ; E = index(_, _) ; E = member(_, _) ; E = bin(Op, A, B), cpp_float_cmp(Op, A, B) ), cpp_const_fold(E, V), !.
cpp_const_reduce(E, E1) :- compound(E), !, E =.. [F|Xs], cpp_const_reduce_list(Xs, Ys), E1 =.. [F|Ys].
cpp_const_reduce(E, E).
cpp_const_reduce_list([], []).
cpp_const_reduce_list([X|Xs], [Y|Ys]) :- cpp_const_reduce(X, Y), cpp_const_reduce_list(Xs, Ys).
cpp_float_cmp(Op, A, B) :- memberchk(Op, ['==', '!=', '<', '>', '<=', '>=']), ( cpp_float_typed(A) -> true ; cpp_float_typed(B) ).
cpp_has_float_cmp(bin(Op, A, B)) :- cpp_float_cmp(Op, A, B), !.   % a condition that compares floating values: the evaluator decides it (cpp_const_bool/2)
cpp_has_float_cmp(not(E)) :- cpp_float_typed(E), !.
cpp_has_float_cmp(E) :- compound(E), E =.. [_|As], member(A, As), compound(A), cpp_has_float_cmp(A), !.
cpp_float_typed(E) :- ( ccl_float_shaped(E) -> true ; ( E = call(_, _) ; E = id(_) ; E = member(_, _) ; E = index(_, _) ; E = arrow(_, _) ) -> catch(ccl_type_of(E, T), _, fail), T \== unknown, ccl_is_float(T) ).
cpp_fold_depth(D) :- ( nb_current('$cpp_fold_depth', D) -> true ; D = 0 ).
cpp_param_binds([], _, []) :- !.
cpp_param_binds(_, [], []) :- !.
cpp_param_binds([param(_, N)|Ps], [A|As], [N-A|B]) :- !, cpp_param_binds(Ps, As, B).
cpp_param_binds([param(_, N, _)|Ps], [A|As], [N-A|B]) :- !, cpp_param_binds(Ps, As, B).
cpp_param_binds([_|Ps], [_|As], B) :- cpp_param_binds(Ps, As, B).
%% 0.72'S ROAD BINDS AN ARGUMENT AS ITS VALUE where it folds in the caller's scope, as written where it does not (0.258): the body is
%% then folded with the caller's scope set aside (cpp_eval_body_scope/1), its free names the file's -- `return K;' read a caller's
%% local `const int K = 5;' where the file's K is 1, the one place 0.257 left the caller's names in a callee's body
cpp_road_args([], []).
cpp_road_args([P-A|Bs], [P-A1|Cs]) :- ( catch(cpp_const_value(A, K), _, fail) -> ( integer(K) -> A1 = int(K) ; K = big(_) -> A1 = int(K) ; K = bool(_) -> A1 = K ; A1 = A ) ; A1 = A ), cpp_road_args(Bs, Cs).
cpp_replace_ids(id(N), B, A) :- memberchk(N-A, B), !.
cpp_replace_ids(T, B, T1) :- compound(T), !, T =.. [F|Xs], cpp_replace_ids_list(Xs, B, Ys), T1 =.. [F|Ys].
cpp_replace_ids(T, _, T).
cpp_replace_ids_list([], _, []).
cpp_replace_ids_list([X|Xs], B, [Y|Ys]) :- cpp_replace_ids(X, B, Y), cpp_replace_ids_list(Xs, B, Ys).
cpp_type_or_value(D, A) :- ( cpp_is_type(D) -> cpp_type(D, A) ; cpp_targ_value(D, A) ).
