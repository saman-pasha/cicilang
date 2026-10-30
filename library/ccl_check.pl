%% cicilang -- library(ccl_check): the safe part. The ownership check,
%% run by cicilang_ir/2 before anything is lowered.
%%
%% An OWNER is a pointer declared with the qualifier `own' -- a local, a
%% parameter (the callee owns what it is given), or a FIELD of a struct held
%% by an owner or by value (`a->name', `p.name', `p.inner.name'). An owner is
%% linear: it is CONSUMED exactly once on every path, by free(p) or fclose(p),
%% by move(p) (into another owner, or as an argument), by `return p', or by
%% passing it to a function whose parameter is `own'; a defer(p) { free(p); }
%% consumes it at the scope's exit, on every path, as the lowering runs it.
%% A consumed owner may own again by assignment. clone(p) hands a function a
%% fresh copy of what p points to (a statement expression whose last value is
%% a new owner), so p is not consumed.
%%
%% The states of an owner: live (holds memory), null (holds nothing: a null
%% constant was assigned; freeing or moving it is fine, so is overwriting it),
%% unset (declared without a value, or a field of a struct fresh from malloc:
%% garbage, not to be read, freed or moved), moved (consumed), partial (moved
%% on one path and not on another: not to be used, and a leak where a live one
%% would be). The walk is flow-sensitive: the states are threaded through the
%% statements and joined at every merge; a path that ends (return, break,
%% continue) contributes its state where it goes.
%%
%% A struct's own fields go with the struct. Freeing an owner (free, fclose)
%% demands its fields consumed first, else the field leaks; moving it (move,
%% an own parameter, return) demands them complete -- live or null -- and moves
%% them along; a struct copied by value moves its fields into the copy. An own
%% pointer from a call other than malloc/calloc/realloc is complete; one from
%% malloc has unset fields. Only a variable's own fields are tracked, and the
%% fields of the structs it holds by value: what an own pointer FIELD points to
%% is not opened (a list's next is one owner, whatever it holds).
%%
%% A BORROW is a plain pointer whose value came from an owner -- `char *q = p',
%% `q = p + 1', `&p[i]', `&p->x', `a->name', or from another borrow. It is
%% bound to the owner: the moment the owner is consumed the borrow dangles, and
%% a use of it is refused; a borrow may not be returned, since the owner is
%% consumed by then; and a borrow, or an owner's pointer, may only be held by a
%% local plain pointer -- stored into a plain struct field, an array element,
%% through a pointer, or into a global, the checker could not follow it, so
%% that is refused. An OWN field or slot receives an owner (moved in), a null,
%% or a fresh value, never a borrow. Assigning a borrow from something else
%% unbinds it.
%%
%% A PLAIN POINTER PARAMETER is a borrow of the caller's, tagged with its own
%% name: the callee may read it, pass it on, and return it (the caller still
%% owns what it points to), but not store it, free it, or move it -- so a
%% borrow handed to any function is safe, and `own' is the one way memory
%% comes in. What a borrowed pointer reaches -- a member, an element, what it
%% points to -- is borrowed from the same. A callee's prototype is read the
%% same way through a function pointer.
%%
%% A TIE is declared with the word tie, `x tie y': x lives within y. y is
%% declared before x -- in scope, an earlier parameter, an earlier member of
%% the struct -- and x is dead the moment y is consumed or y's scope ends. A
%% tied plain value is a BORROW of y (of y's root, when y is itself a borrow),
%% whatever its type: it dangles when y goes, may not escape, and takes only
%% values whose root outlives y (y within the root: the same, or tied to it).
%% A tied OWNER must be consumed before y is, and may be moved
%% only into a slot within y, or to a parameter tied the same way. A struct
%% member tied to an earlier member is such a slot in every instance (`l.cur'
%% tied to `l.head'), where a borrow of the tie may be stored -- the one place
%% a borrow is stored; a struct instance tied to an owner may hold borrows of
%% it in any plain field. On a prototype the tie is a contract: a parameter
%% tied to an earlier one is checked at every call, the argument within the
%% argument; a result tied to a parameter makes the caller's variable a borrow
%% of that argument, and the callee's returns are checked against it. A tie
%% to a plain local ANCHORS it: a root consumed by nothing, ending with its
%% scope, so what is tied to it dangles there; `&x' of a plain local and a
%% local array used as a pointer anchor it the same way.
%%
%% THE ERRORS, each error(ownership(Kind, Name, Form), where(Function, line(L))),
%% the line the statement's, Name the owner's path (`a->name'):
%%   use_after_move      a consumed owner read, passed, freed again (the double free)
%%   owner_unset         an owner read, passed, freed or moved before it was given anything
%%   borrow_after_move   a borrow used after its owner was consumed (a tied value after its tie went)
%%   borrow_escapes      a borrow returned from the function
%%   borrow_stored       a borrow stored into a struct field, an element, a global, through a pointer, or into an own slot
%%   borrow_consumed     a borrow freed, or passed where an owner is taken (a parameter freed in its callee)
%%   borrow_incomplete   an own field of a struct a parameter points to, freed or moved out and not replaced by the return
%%   owner_stored        an owner's pointer stored into a plain slot (its ownership would be lost)
%%   owner_leaked        an owner live, or partial, at its scope's end, at a return, or a field when its struct is freed
%%   move_in_loop        an owner from outside a loop consumed inside it (and not re-assigned)
%%   move_of_non_owner   move(x) of something that is not an owner
%%   owner_overwritten   assignment to a live owner (what it held would leak)
%%   goto_with_owners    a goto over a plain pointer's fresh memory or an own array's declaration (it would be garbage)
%%   goto_over_defer     a goto over a `defer' (or a C++ local with a destructor) to a label in its scope
%%   tie_unknown         `tie y' with no y declared before it (in scope, an earlier parameter or member)
%%   tie_outlived        an owner tied to y still live when y is consumed
%%   tie_escapes         a tied owner moved beyond its tie: into an untied slot, to an untied own parameter, returned with no result tie
%%   tie_mismatch        a value not within the tie of the slot, the parameter or the result it is given to
%%   own_unbounded       an own pointer with no owner to name: behind a plain pointer, in an array with no constant bound, an array parameter
%%   own_array_by_value  a struct with an own array held by value
%%   own_array_untagged  an own array in a struct without a tag
%%   array_unset         an own array not zeroed at birth: from malloc or realloc, or a local without an initializer
%% A plain pointer LOCAL given fresh memory -- malloc's result, an untied
%% function's, anything not null, not static, not a borrow -- is LOOSE: memory
%% with no owner behind it, that the check follows as an owner without the
%% word. free (fclose, realloc, an own parameter), a return, a store into a
%% slot, or an own slot taking it over consumes it; a borrow of it dangles
%% when it is freed, as an owner's would; and where it is still unconsumed --
%% its scope's end, a return, an overwrite -- it is refused (owner's rule:
%% every pointer has an ownership path, or the program is not accepted):
%%   unconsumed          a loose pointer (a plain local holding fresh memory) at its scope's end, a return, or overwritten
%%   untied              a slot the check cannot follow -- a field, an element, a global, *p, a struct by value -- given a value with no owner behind it
%% An OWN ARRAY, `own node *c[4]', holds a fixed number of owners: which one an
%% index names cannot be told at compile time, so the array is one key whose
%% elements are null or owned -- an invariant the lowering keeps by draining
%% it: every non-null element freed (its own struct drained first) when the
%% struct holding it is freed or the local's scope ends, the old element freed
%% when one is overwritten, the slot nulled when an element is moved out or
%% consumed. The check asks the rest: an element takes an owner (moved in), a
%% null or a fresh value, never a borrow; an element leaves by move (or free,
%% or an own parameter), and every borrow of the array dangles when any
%% element goes; the array is zeroed at birth (calloc, an initializer, a call:
%% `array_unset' for malloc or nothing); it lives as a local or in a struct
%% behind an own pointer, never by value (`own_array_by_value': a copy would
%% own its elements twice), in a struct with a tag (`own_array_untagged': the
%% drain is a function named by it); and an own pointer sits nowhere else --
%% behind a plain pointer, in an array with no constant bound, as an array
%% parameter -- `own_unbounded'. One more bound the check can name: a struct's
%% LAST member may be `own T *a[n]' with n an earlier integer member of the
%% same struct, a flexible array the developer allocates room for and counts
%% (`calloc(1, sizeof(struct s) + k * sizeof(T *))', `s->n = k'); the drain
%% loops to n. A wrong n is the developer's, as a wrong index is.
%%
%% A function's result may be tied to a static local of its own or to a global
%% (`tie table'): the caller's variable is then a borrow of static storage,
%% static(Name), which nothing ends and nothing may free. `if (!p)' and
%% `if (p == NULL)' make an owner null on the then path, `if (p)' and
%% `if (p != NULL)' on the else path, its own fields with it.
%% Not tracked: what a plain pointer reaches is not opened for ownership (a
%% borrowed struct's own field may be given an owner, that is all).

:- use_module(library(ccl_infer)).

ccl_check_units(Units) :- ccl_ensure_globals, ccl_scope_init, catch(retractall('$ir_hlib'(_)), _, true), ck_note_units(Units), ck_flows(Units), ck_units(Units).   % no lowering's library functions (0.212)
ccl_check_noted(Units) :- ck_flows(Units), ck_units(Units).                            % on the table the caller built
ck_note_units([]).
ck_note_units([unit(Is)|Us]) :- ccl_items_note_program(Is), ck_note_units(Us).
ck_units([]).
ck_units([unit(Is)|Us]) :- ck_items(Is), ck_units(Us).
ck_trace(T) :- ( nb_current('$cpp_trace', yes) -> print(T), nl ; true ).
ck_items([]).
ck_items([function(L, _, Ret, Name, Params, _, Body)|Is]) :- !,
    ( ck_library_fn(Name) -> true ; \+ \+ ck_function(L, Ret, Name, Params, Body) -> true ; ck_trace(check_failed(Name)), fail ),   % a library header's function: C++'s rules, not these (ccl_cpp); inside `\+ \+', so a function's walk is reclaimed; one that merely FAILS says its name under the trace (0.108)
    ck_items(Is).
ck_items([_|Is]) :- ck_items(Is).
%% a library's function, its code not the program's: C++'s (cpp_library_function/1), and in C one that a library's header
%% defines and the unit uses, lowered with it (ir_header_defs/2, '$ir_hlib'/1; 0.212)
ck_library_fn(Name) :- ( ccl_lang(cpp) -> cpp_library_function(Name) ; catch('$ir_hlib'(Name), _, fail) ).

%% ---- state: frames of Key-State, innermost first; with each frame its defers ----------
ck_function(L, Ret, Name, Params0, Body) :-
    ck_ref_params(Params0, Params),                                      % C++: a reference parameter is a borrow, as a pointer is
    nb_setval('$ck_fn', Name), nb_setval('$ck_ret', Ret), nb_setval('$ck_line', L), nb_setval('$ck_loops', []), nb_setval('$ck_trys', []), nb_setval('$ck_ties', []), nb_setval('$ck_statics', []), nb_setval('$ck_arrays', []),
    nb_setval('$ck_arrlocals', []), nb_setval('$ck_ref_binds', []), nb_setval('$ck_holders', []), ck_note_arrparams(Params),
    ccl_scope_push, ccl_declare_params(Params),
    ck_param_names(Params, Names), nb_setval('$ck_params', Names),
    (   ccl_tie_of(Ret, RY)
    ->  (   memberchk(RY, Names) -> RT = RY
        ;   ck_body_static(Body, RY) -> RT = static(RY)                   % a static local of the function's, or a global: storage nothing ends
        ;   ck_is_global(RY) -> RT = static(RY)
        ;   ck_fail(tie_unknown, RY, result(Name)) ),
        nb_setval('$ck_ret_tie', RT)
    ;   nb_setval('$ck_ret_tie', none) ),
    ck_borrowed_fields(Params, Borrowed), nb_setval('$ck_borrowed', Borrowed),
    ck_dying_fields(Params, Dying), nb_setval('$ck_dying_fields', Dying),
    ck_param_owners(Params, Owners),
    ck_param_selves(Names, Selves), append(Owners, Selves, Owners1),
    ck_param_ties(Params, [], st([fr(Owners1, [])]), St0),
    ck_param_dtors(Params, Body, Body1),
    ck_walk_body(Body1, St0, St1),
    ( St1 == dead -> true ; St1 = st([fr(Os, _)]), ck_complete_owners(Os, function_end), ck_leaks_all(St1, function_end) ),
    ccl_scope_pop.
%% A BY-VALUE PARAMETER OF A CLASS WITH A DESTRUCTOR IS DESTROYED BY THE CALLER (0.207; the Itanium C++ ABI's 3.1.2.3, the
%% desugaring's cpp_byval_arg/3), and the callee's code destroys no parameter; to the check it is the callee's object all the
%% same, moved from or not, and its destructor runs at every exit: the walk takes a defer of it at the body's head, as the
%% desugaring's own defer was until 0.207. A borrow instead, as a reference parameter is, refused `push(T x) { v.push_back(move(x)); }'
%% as a move of a non-owner; no defer, `int len(Name n)' over an own member as `owner leaked'
ck_param_dtors(Ps, block(Ss), block(Ss1)) :- ccl_lang(cpp),
    findall(defer(0, [], block([expr(0, call(id(D), [addr(id(N))]))])),
            ( member(param(T, N), Ps), atom(N), N \== anon, N \== this, once(( catch(cpp_class_of_type(T, C), _, fail), catch(cpp_dtor(C, D), _, fail) )) ), Ds),
    Ds \== [], !, append(Ds, Ss, Ss1).
ck_param_dtors(_, B, B).
%% the own fields of the structs the plain pointer parameters point to: the
%% struct's, not the callee's -- one may be freed and replaced, and must be
%% whole (live or null) again when the callee returns
ck_borrowed_fields([], []).
ck_borrowed_fields([param(T, N)|Ps], Fs) :-
    ck_borrowed_fields(Ps, Fs0),
    ( N \== anon, \+ ck_own_type(T), ck_pointee_fields(N, T, Fs1) -> append(Fs1, Fs0, Fs) ; Fs = Fs0 ).
ck_pointee_fields(N, T, Fs) :- ccl_resolve_type(T, ptr(_, PT)), ccl_members_of(PT, Ms), ck_member_fields(Ms, N, '->', Fs), Fs \== [].
ck_is_borrowed_field(N) :- nb_getval('$ck_borrowed', Bs), memberchk(N, Bs).
ck_complete_owners([], _).
ck_complete_owners([N-S|Os], Form) :-
    ( ck_is_borrowed_field(N), \+ ck_is_dying_field(N), \+ memberchk(S, [live, null, array]) -> ck_fail(borrow_incomplete, N, Form) ; true ),
    ck_complete_owners(Os, Form).
%% C++ (M6): a constructor's `this' points at fresh storage -- its own fields
%% start unset, and must be live or null when it returns -- and a destructor's
%% at dying storage: its fields may be consumed and left, and the caller of a
%% destructor (delete, a scope's end) takes the object's own fields as moved.
%% The desugaring marks the pointee: ptr(_, base([fresh | dying], ...)).
ck_this_marker(T, M) :- ccl_resolve_type(T, ptr(_, base(Q, _))), memberchk(M, Q), !.
ck_dying_fields([], []).
ck_dying_fields([param(T, N)|Ps], Fs) :-
    ck_dying_fields(Ps, Fs0),
    ( N \== anon, ck_this_marker(T, dying), ck_pointee_fields(N, T, Fs1) -> ck_field_names(Fs1, Ns), append(Ns, Fs0, Fs) ; Fs = Fs0 ).
ck_field_names([], []).
ck_field_names([K-_|Fs], [K|Ns]) :- !, ck_field_names(Fs, Ns).
ck_field_names([K|Fs], [K|Ns]) :- ck_field_names(Fs, Ns).
ck_is_dying_field(N) :- nb_getval('$ck_dying_fields', Ds), memberchk(N, Ds).
ck_dying_param(Callee, I) :- ck_callee_params(Callee, Ps), ccl_nth(I, Ps, param(PT, _)), ck_this_marker(PT, dying).
ck_fresh_param(Callee, I) :- ck_callee_params(Callee, Ps), ccl_nth(I, Ps, param(PT, _)), ck_this_marker(PT, fresh).
%% the callee takes the argument by value (not by C++'s reference, which borrows); an unknown callee is taken to
ck_param_by_value(Callee, I) :- ( ck_callee_params(Callee, Ps), ccl_nth(I, Ps, param(PT, _)) -> \+ PT = ref(_, _), \+ PT = rref(_, _) ; true ).
ck_arg_base(addr(id(K)), K) :- !.
ck_arg_base(addr(E), K) :- ck_path(E, K), !.                                   % &this->name, &p.name: the member's own fields
ck_arg_base(id(K), K).
ck_body_static(declaration(_, static, _, Vs), N) :- member(var(N, _, _), Vs), !.
ck_body_static(T, N) :- compound(T), T =.. [_|As], member(A, As), ck_body_static(A, N), !.
ck_param_names([], []).
ck_param_names([param(_, N)|Ps], Ns) :- ck_param_names(Ps, Ns0), ( N == anon -> Ns = Ns0 ; Ns = [N|Ns0] ).
ck_is_param(N) :- nb_getval('$ck_params', Ps), memberchk(N, Ps).
%% an own parameter is an owner, complete: its own fields are live; a struct
%% given by value with own fields owns those fields (the struct itself is not
%% freed); a plain pointer parameter is a BORROW of the caller's, tagged with
%% its own name: read, passed on and returned, never stored, freed or moved
ck_param_owners([], []).
ck_param_owners([param(T, N)|Ps], Os) :-
    ck_param_owners(Ps, Os0),
    (   N == anon -> Os = Os0
    ;   ck_own_type(T)
    ->  ck_var_fields(N, T, Fs), ck_field_states(Fs, complete, FOs),
        ( ck_is_pointer_type(T) -> append([N-live|FOs], Os0, Os) ; append(FOs, Os0, Os) )
    ;   ck_is_pointer_type(T) -> ( ck_pointee_fields(N, T, Fs) -> ( ck_this_marker(T, fresh) -> Mode = garbage ; Mode = complete ), ck_field_states(Fs, Mode, FOs) ; FOs = [] ), append([N-borrow(N)|FOs], Os0, Os)
    ;   ccl_resolve_type(T, arr(_, _)) -> Os = [N-borrow(N)|Os0]
    ;   ck_var_fields(N, T, Fs), Fs \== [] -> ck_field_states(Fs, complete, FOs), append(FOs, Os0, Os)   % a struct by value with owners inside: theirs to consume (a moved string)
    ;   Os = Os0 ).
%% the ties of the parameters, in order: the fields' (a struct's members tied
%% to earlier members, in what an own or a plain pointer parameter points to,
%% or a struct given by value), then the parameter's own, to an earlier one
ck_param_ties([], _, St, St).
ck_param_ties([param(T, N)|Ps], Seen, St0, St) :-
    (   N == anon -> St2 = St0, Seen1 = Seen
    ;   ( ck_own_array_type(T) -> ck_fail(own_unbounded, N, param(N)) ; ck_type_rules(N, T, param(N)) ),
        (   ck_own_type(T) -> ck_var_ties(N, T, Ts)
        ;   ck_is_pointer_type(T) -> ( ck_pointee_ties(N, T, Ts) -> true ; Ts = [] )
        ;   ck_var_ties(N, T, Ts) ),
        ck_field_ties_(Ts, St0, St1),
        (   ccl_tie_of(T, Y) -> ( memberchk(Y, Seen) -> true ; ck_fail(tie_unknown, Y, param(N)) ), ck_var_tie(N, T, St1, St2)
        ;   St2 = St1 ),
        Seen1 = [N|Seen] ),
    ck_param_ties(Ps, Seen1, St2, St).
%% `own char *p': C's grammar puts the qualifier with the pointee, so an owner
%% is a pointer with own on itself or on what it points to
ck_own_type(ptr(Q, B)) :- ( memberchk(own, Q) ; B = base(Q2, _), memberchk(own, Q2) ), !.
ck_own_type(base(Q, _)) :- memberchk(own, Q), !.
ck_is_pointer_type(T) :- ccl_resolve_type(T, T1), T1 = ptr(_, P), \+ ccl_resolve_type(P, fn(_, _, _)), !.   % a FUNCTION pointer is code, never memory the check follows (0.100): `int (*f)(int) = c ? a : b' was a loose pointer
%% a type whose value carries a pointer: a pointer, an array of them, a struct
%% holding one at any depth -- what a borrow, or a tie, travels in
ck_carries_type(T) :- ccl_resolve_type(T, T1), ck_carries_(T1).
ck_carries_(memptr(_, _, _)) :- !, fail.
ck_carries_(ptr(_, F)) :- ccl_resolve_type(F, fn(_, _, _)), !, fail.                    % nor a pointer to a function                                            % a pointer to member is a code address or an offset, never an owner or a borrow (0.100: the ABI's `{ ptr, adj }' has a pointer field, which is not memory)
ck_carries_(ptr(_, _)) :- !.
ck_carries_(block(_, _)) :- !.
ck_carries_(arr(_, E)) :- !, ck_carries_type(E).
ck_carries_(base(_, [struct(N, _)])) :- ccl_lang(cpp), ck_library_class(N), !, fail.   % A LIBRARY CLASS'S VALUE IS OPAQUE: its pointers are libc++'s own discipline, as its functions' bodies are (0.45) -- a map's iterator, `auto it = m.find(3)', holds a node pointer the safe part cannot follow and need not, since nothing here frees it
ck_carries_(T) :- ccl_members_of(T, Ms), member(member(MT, MN, _), Ms), MN \== '$vptr', ck_carries_type(MT), !.   % a class's TABLE POINTER is static storage, never memory the check follows (0.127): `V v = V();' of a polymorphic class was refused `untied'
%% A CLOSURE IS FOLLOWED AS A BORROW OF WHAT IT CAPTURES (0.100): its reference captures are `ref' members, which
%% `ck_carries_' does not count (a reference member is bound once and read through, and counting it refused every
%% closure's construction as a borrow stored), so the two places that make a value a borrow -- a declaration's
%% initializer and a return -- ask this test beside it. A closure that holds `&x' of a local and leaves the function
%% is borrow_escapes, where a dangling reference compiled and ran (the hole 0.59 named).
ck_borrowing_type(T) :- ck_carries_type(T), !.
ck_borrowing_type(T) :- ccl_lang(cpp), ck_closure_type(T), !.
ck_borrowing_type(T) :- ck_holds_lib_borrow(T).
ck_closure_type(T) :- ccl_resolve_type(T, base(_, [struct(N, _)])), atom(N), atom_concat('lambda.', _, N), !.
ck_library_class(N) :- atom(N), catch(cpp_lib_class(N), _, fail).
ck_library_root(P) :- ccl_lang(cpp), atom(P), ccl_type_of(id(P), T), T \== unknown, catch(ccl_resolve_type(T, base(_, [struct(N, _)])), _, fail), ck_library_class(N).   % a borrow rooted at a local of a library class's type
%% A LIBRARY OBJECT THAT HOLDS BORROWS (0.216; the owner's decision of 0.190): an instance whose template arguments carry a
%% pointer, a reference or a closure -- `std::vector<int *>', `std::pair<int *, int>', an iterator over raw pointers, a map
%% of functions -- or a view or a holder of a callable by its nature (ck_lib_view/1). The safe part follows the borrows it
%% is handed (ck_lib_store/4) and the ones its value carries out (ck_borrows_from/3), as a closure's; its own memory stays
%% the library's (0.45's decision): a `std::string' or a `std::vector<int>' holds no borrow, and no rule of the owners asks
%% one, `ck_carries_/1' keeping a library class opaque, so a library object is never loose memory nor `untied'
ck_holds_lib_borrow(T) :- ccl_lang(cpp), catch(ccl_resolve_type(T, T1), _, fail), ck_holds_lib_borrow_(T1).
ck_holds_lib_borrow_(base(_, [struct(N, _)])) :- atom(N), ck_library_class(N), !, ck_lib_borrowing(N).
ck_holds_lib_borrow_(T) :- T = base(_, [struct(_, _)]), !, ccl_members_of(T, Ms), member(member(MT, MN, _), Ms), MN \== '$vptr', ck_holds_lib_borrow(MT), !.   % a class of the program's holding such an object by value: `struct S { std::vector<int *> v; }'
ck_holds_lib_borrow_(arr(_, E)) :- ck_holds_lib_borrow(E).
ck_lib_borrowing(N) :- atom_concat('$ck_lb:', N, K), ( nb_current(K, V) -> true ; nb_setval(K, no), ( ck_lib_borrowing_(N) -> V = yes ; V = no ), nb_setval(K, V) ), V == yes.   % `no' while it is asked: `struct Node { std::vector<Node> kids; }' asks itself
ck_lib_borrowing_(N) :- catch('$cpp_inst'(N, inst(T, Args)), _, fail), ( ck_lib_view(T) -> true ; member(A, Args), ck_lib_arg_carries(A) ), !.
ck_lib_view(T) :- memberchk(T, [basic_string_view, span, reference_wrapper, function, move_only_function, copyable_function, function_ref, ref_view, mdspan]).
ck_lib_arg_carries(A) :- compound(A), catch(ccl_resolve_type(A, A1), _, fail), ck_lib_arg_carries_(A1).
ck_lib_arg_carries_(ptr(_, F)) :- !, \+ catch(ccl_resolve_type(F, fn(_, _, _)), _, fail).
ck_lib_arg_carries_(ref(_, _)) :- !.
ck_lib_arg_carries_(rref(_, _)) :- !.
ck_lib_arg_carries_(base(Q, [struct(M, Ms)])) :- atom(M), ( atom_concat('lambda.', _, M) -> true ; ck_library_class(M) -> ck_lib_borrowing(M) ; ck_carries_type(base(Q, [struct(M, Ms)])) -> true ; ck_holds_lib_borrow(base(Q, [struct(M, Ms)])) ).

%% the own fields of a variable: N->f under an own pointer to a struct, N.f in a
%% struct held by value; a member held by value opens its own fields too
%% (N.inner.f); an own pointer member is one field and stops there
ck_var_fields(N, T, Fs) :-
    ccl_resolve_type(T, T1),
    (   T1 = ptr(_, PT), ck_own_type(T), ccl_members_of(PT, Ms) -> ck_member_fields(Ms, N, '->', Fs)
    ;   T1 = base(_, [struct(_, _)]), ccl_members_of(T1, Ms) -> ck_member_fields(Ms, N, '.', Fs)
    ;   Fs = [] ).
ck_member_fields([], _, _, []).
ck_member_fields([M|Ms], Base, Sep, Fs) :- M \= member(_, _, _), !, ck_member_fields(Ms, Base, Sep, Fs).   % a C++ class's methods, labels
ck_member_fields([member(MT, F, _)|Ms], Base, Sep, Fs) :-
    (   F == anon -> Fs = Fs1
    ;   atomic_list_concat([Base, Sep, F], K),
        (   ck_own_type(MT) -> Fs = [K|Fs1]
        ;   ck_own_array_type(MT) -> ck_note_array(K), Fs = [K|Fs1]
        ;   ccl_resolve_type(MT, MT1), MT1 = base(_, [struct(_, _)]), ccl_members_of(MT1, Sub) -> ck_member_fields(Sub, K, '.', Fs0), append(Fs0, Fs1, Fs)
        ;   Fs = Fs1 ) ),
    ck_member_fields(Ms, Base, Sep, Fs1).
ck_states([], _, []).
ck_states([K|Ks], S, [K-S|Ps]) :- ck_states(Ks, S, Ps).
%% the fields' states by how the struct was born: complete (a call, a move),
%% zeroed (calloc: null), garbage (malloc: unset); an own array is `array' or
%% refused, since the lowering drains it and garbage cannot be drained
ck_field_states([], _, []).
ck_field_states([K|Ks], Mode, [K-S|Ps]) :- ck_field_state(K, Mode, S), ck_field_states(Ks, Mode, Ps).
ck_field_state(K, Mode, S) :- ( ck_is_array_key(K) -> S = array ; Mode == garbage -> S = unset ; Mode == zeroed -> S = null ; S = live ).
ck_alloc_mode(call(id(F), _), garbage) :- memberchk(F, [malloc, realloc]), !.
ck_alloc_mode(call(id(calloc), _), zeroed) :- !.
ck_alloc_mode(cast(_, E), M) :- !, ck_alloc_mode(E, M).                              % C++'s new T is (T *) malloc(sizeof(T))
ck_alloc_mode(new(_, []), garbage) :- !.                                            % new T of a struct without a constructor: malloc's bytes
ck_alloc_mode(new_array(_, _), garbage) :- !.
ck_alloc_mode(alloc(M, _, _), Mode) :- !, ( M == garbage -> Mode = garbage ; Mode = zeroed ).   % a new-expression's block from its allocation function (0.202): its bytes as they are, or value-initialization's zero bytes
ck_alloc_mode(_, complete).
ck_set_fields(St0, Key, Mode, Form, St) :-
    ck_under_states(St0, Key, Ps),
    ( Mode == garbage, member(A-_, Ps), ck_is_array_key(A) -> ck_fail(array_unset, A, Form) ; true ),
    ck_set_fields_(Ps, Mode, St0, St).
ck_set_fields_([], _, St, St).
ck_set_fields_([K-S|Ps], Mode, St0, St) :-
    (   ck_is_array_key(K) -> ck_set(St0, K, array, St1)
    ;   ck_owner_state(S) -> ck_field_state(K, Mode, S1), ck_set(St0, K, S1, St1)
    ;   St1 = St0 ),
    ck_set_fields_(Ps, Mode, St1, St).

%% ---- own arrays ---------------------------------------------------------------------------
%% `own node *c[4]': the key is the array's (a local's name, a field's path,
%% listed in '$ck_arrays'), its state `array'; an element is index(Path, _)
ck_own_array_type(arr(_, ET)) :- !, ck_own_type(ET).                            % asked of every type the lowering meets: the shape first
ck_own_array_type(ptr(_, _)) :- !, fail.
ck_own_array_type(base(_, [S|_])) :- atom(S), !, fail.
ck_own_array_type(T) :- ccl_resolve_type(T, arr(_, ET)), ck_own_type(ET), !.
ck_const(E, N) :- ccl_const_eval(E, N), !.                          % a literal, an enumerator, a constant expression
ck_note_array(K) :- nb_getval('$ck_arrays', As), ( memberchk(K, As) -> true ; nb_setval('$ck_arrays', [K|As]) ).
ck_is_array_key(K) :- nb_getval('$ck_arrays', As), memberchk(K, As).
ck_own_elem(index(A, _), K) :- ck_path(A, K), ck_is_array_key(K).
ck_has_array_under(St, K) :- ck_under_states(St, K, Ps), member(A-_, Ps), ck_is_array_key(A), !.
%% the rules a declared type must meet: an own pointer only where its owner is
%% named (never behind a plain pointer, never in an array without a constant
%% bound); a struct with an own array behind a pointer, never by value, and
%% with a tag
ck_type_rules(N, T, Form) :-
    ck_bounds_ok(T, N, Form),
    ccl_resolve_type(T, T1),
    (   T1 = ptr(_, PT) -> ck_array_struct_ok(PT, N, Form)
    ;   T1 = base(_, [struct(_, _)]) -> ( ck_has_own_array(T1) -> ck_fail(own_array_by_value, N, Form) ; true )
    ;   true ).
ck_bounds_ok(T, N, Form) :- ccl_resolve_type(T, T1), ck_bounds_ok_(T1, N, Form).
ck_bounds_ok_(arr(NE, ET), N, Form) :- !, ( ck_own_type(ET), \+ ck_const(NE, _) -> ck_fail(own_unbounded, N, Form) ; true ), ck_bounds_ok(ET, N, Form).
ck_bounds_ok_(ptr(_, ET), N, Form) :- !,
    ccl_resolve_type(ET, ET1),
    (   ( ET1 = ptr(_, _), ck_own_type(ET1) ; ck_own_array_type(ET1) ) -> ck_fail(own_unbounded, N, Form)
    ;   ( ET1 = ptr(_, _) ; ET1 = arr(_, _) ) -> ck_bounds_ok(ET1, N, Form)
    ;   true ).
ck_bounds_ok_(_, _, _).
ck_array_struct_ok(T, N, Form) :-
    ccl_resolve_type(T, T1),
    (   ck_has_own_array(T1)
    ->  ( T1 = base(_, [struct(anon, _)]) -> ck_fail(own_array_untagged, N, Form) ; true ),
        ccl_members_of(T1, Ms), ck_members_ok(Ms, [], Form)
    ;   true ).
%% a member's bound: a constant, or -- for the last member -- an earlier integer member
ck_members_ok([], _, _).
ck_members_ok([member(MT, F, _)|Ms], Seen, Form) :-
    (   ccl_resolve_type(MT, arr(NE, ET)), ck_own_type(ET), \+ ck_const(NE, _)
    ->  ( NE = id(B), memberchk(B-BT, Seen), ccl_is_integer(BT), Ms == [] -> true ; ck_fail(own_unbounded, F, Form) )
    ;   ck_bounds_ok(MT, F, Form) ),
    ( ccl_resolve_type(MT, MT1), MT1 = base(_, [struct(_, _)]) -> ck_array_struct_ok(MT1, F, Form) ; true ),
    ck_members_ok(Ms, [F-MT|Seen], Form).
%% answered once per tag: the lowering asks it of every struct in the symbol
%% table, the headers' too, and walks their members with a resolution each
ck_has_own_array(T) :-
    (   ccl_resolve_type(T, base(_, [struct(Tag, _)])), Tag \== anon
    ->  ccl_cached_named('$ck_oa:', Tag, V, ( ck_has_own_array_nocache(T) -> V = yes ; V = no )), V == yes
    ;   ck_has_own_array_nocache(T) ).
ck_has_own_array_nocache(T) :-
    ccl_members_of(T, Ms), member(member(MT, _, _), Ms),
    ( ck_own_array_type(MT) -> true ; ccl_resolve_type(MT, MT1), MT1 = base(_, [struct(_, _)]), ck_has_own_array(MT1) ), !.
ck_no_array_copy(St, K, Form) :- ( ck_has_array_under(St, K) -> ck_fail(own_array_by_value, K, Form) ; true ).
%% the tied fields of a variable, Key-TieKey in member order (a tie names an
%% earlier member, else tie_unknown): under an own pointer with `->', in a
%% struct by value with `.', a member held by value opened the same way
ck_var_ties(N, T, Ts) :-
    ccl_resolve_type(T, T1),
    (   T1 = ptr(_, PT), ck_own_type(T), ccl_members_of(PT, Ms) -> ck_member_ties(Ms, N, '->', [], Ts)
    ;   T1 = base(_, [struct(_, _)]), ccl_members_of(T1, Ms) -> ck_member_ties(Ms, N, '.', [], Ts)
    ;   Ts = [] ).
ck_pointee_ties(N, T, Ts) :- ccl_resolve_type(T, ptr(_, PT)), ccl_members_of(PT, Ms), ck_member_ties(Ms, N, '->', [], Ts).
ck_member_ties([], _, _, _, []).
ck_member_ties([member(MT, F, _)|Ms], Base, Sep, Seen, Ts) :-
    (   F == anon -> Ts = Ts1, Seen1 = Seen
    ;   atomic_list_concat([Base, Sep, F], K),
        (   ccl_tie_of(MT, Y) -> ( memberchk(Y, Seen) -> true ; ck_fail(tie_unknown, Y, member(F)) ), atomic_list_concat([Base, Sep, Y], YK), Ts = [K-YK|Ts0]
        ;   Ts = Ts0 ),
        (   ccl_resolve_type(MT, MT1), MT1 = base(_, [struct(_, _)]), ccl_members_of(MT1, Sub) -> ck_member_ties(Sub, K, '.', [], Sub1), append(Sub1, Ts1, Ts0)
        ;   Ts0 = Ts1 ),
        Seen1 = [F|Seen] ),
    ck_member_ties(Ms, Base, Sep, Seen1, Ts1).

%% the path an lvalue names: a, a.f, a->f, a->inner.f
ck_path(id(N), N) :- atom(N).
ck_path(member(id(R), F), K) :- ck_is_ref(R), !, ck_path(arrow(id(R), F), K).            % C++: r.f with r a reference is the referent's field, r->f
ck_path(member(E, F), K) :- ck_path(E, B), atomic_list_concat([B, '.', F], K).
ck_path(arrow(E, F), K) :- ck_path(E, B), atomic_list_concat([B, '->', F], K).
ck_owner_path(St, E, K) :- ck_path(E, K), ck_is_owner(St, K).
%% the base of a path: `a' of `a.f', `a->f' of `a->f.g'
ck_base_path(K, B) :-
    atom(K), sub_atom(K, Bl, _, _, Sep), memberchk(Sep, ['.', '->']),
    \+ ( sub_atom(K, Bl2, _, _, Sep2), memberchk(Sep2, ['.', '->']), Bl2 > Bl ),
    sub_atom(K, 0, Bl, _, B).
%% the keys under a base: its fields, at any depth; the own ones among them
ck_under(st(Frs), Base, Keys) :- ck_under_states(st(Frs), Base, Ps), ck_keys(Ps, Keys).
ck_own_under(St, Base, Keys) :- ck_under_states(St, Base, Ps), ck_own_keys(Ps, Keys).
ck_under_states(st(Frs), Base, Ps) :-
    atom_concat(Base, '.', P1), atom_concat(Base, '->', P2),
    findall(K-S, ( member(fr(Os, _), Frs), member(K-S, Os), atom(K), ( sub_atom(K, 0, _, _, P1) ; sub_atom(K, 0, _, _, P2) ) ), Ps).
ck_keys([], []).
ck_keys([K-_|T], [K|Ks]) :- ck_keys(T, Ks).
ck_own_keys([], []).
ck_own_keys([K-S|T], Ks) :- ( ck_owner_state(S) -> Ks = [K|Ks1] ; Ks = Ks1 ), ck_own_keys(T, Ks1).
ck_owner_state(S) :- memberchk(S, [live, moved, partial, null, unset]).
%% the base of a path is read when the path is
ck_base_use(id(_), St, St) :- !.
ck_base_use(member(E, _), St0, St) :- !, ck_base_read(E, St0, St).
ck_base_use(arrow(E, _), St0, St) :- !, ck_expr(E, St0, St).
ck_base_use(move(E), St0, St) :- !, ck_base_use(E, St0, St).
ck_base_use(_, St, St).
%% the base of a member read or written: its own state and its members' own keys, not what it holds whole (0.217)
ck_base_read(id(N), St, St) :- !, ( ck_state(St, N, S) -> ck_read(N, S) ; true ).
ck_base_read(member(E, F), St0, St) :- !, ck_base_read(E, St0, St), ( ck_path(member(E, F), K), ck_state(St, K, S) -> ck_read(K, S) ; true ).
ck_base_read(E, St0, St) :- ck_expr(E, St0, St).
ck_strip_move(move(E), E) :- !.
ck_strip_move(E, E).
%% a null constant
ck_null(int(0)).
ck_null(id('NULL')).
ck_null(cast(ptr(_, base(_, [void])), int(0))).                                  % NULL expanded: ((void *)0)
ck_null(int(0)).
ck_null(cast(_, E)) :- ck_null(E).
ck_null(nullptr).                                                                % C++
ck_null(long(0)).
ck_null(uint(0)).
ck_null(ulong(0)).
ck_null(ccast(_, _, E)) :- ck_null(E).
%% C++ (M6): the check sees a reference as the pointer it is -- a parameter a
%% borrow, a local bound to an lvalue a borrow of its address (an anchor, an
%% array's element); one bound to a call's result is not followed (no state)
%% The reference names of the function are '$ck_refs': a use of one as a
%% place is a use of what it refers to (`x = v' stores through, `&x' is the
%% pointer held), never a rebinding of the pointer.
ck_ref_params(Ps0, Ps) :- ck_ref_params_(Ps0, Ps, Names), nb_setval('$ck_refs', Names).
ck_ref_params_([], [], []).
ck_ref_params_([param(T0, N)|Ps], [param(T, N)|Ps1], Ns) :- !, ck_ref_as_ptr(T0, T), ( T \== T0 -> Ns = [N|Ns1] ; Ns = Ns1 ), ck_ref_params_(Ps, Ps1, Ns1).
ck_ref_params_([P|Ps], [P|Ps1], Ns) :- ck_ref_params_(Ps, Ps1, Ns).
ck_ref_as_ptr(ref(Q, T), ptr(Q, T)) :- !.
ck_ref_as_ptr(rref(Q, T), ptr(Q, T)) :- !.
ck_ref_as_ptr(T, T).
ck_ref_decl(N, T0, Init0, T, Init) :-
    (   ck_ref_as_ptr(T0, T), T \== T0
    ->  nb_getval('$ck_refs', Rs), nb_setval('$ck_refs', [N|Rs]),
        ( ck_lvalue_form(Init0) -> Init = addr(Init0) ; Init = none ), ck_ref_bind(N, Init0)
    ;   T = T0, Init = Init0,
        ( nb_getval('$ck_refs', Rs), memberchk(N, Rs) -> ccl_delete_one(Rs, N, Rs1), nb_setval('$ck_refs', Rs1) ; true ) ).
ck_is_ref(N) :- nb_getval('$ck_refs', Rs), memberchk(N, Rs).
%% the place a local reference was bound to, the latest binding of the name first: where a library object reached
%% through it lives (ck_resolve/3, 0.216, 0.217)
ck_ref_bind(N, E) :- ( ck_mentions(E, N) -> true ; ( nb_current('$ck_ref_binds', Bs) -> true ; Bs = [] ), nb_setval('$ck_ref_binds', [N-E|Bs]) ).
ck_ref_bound(N, E) :- nb_current('$ck_ref_binds', Bs), memberchk(N-E, Bs).
ck_mentions(id(N), N) :- !.
ck_mentions(E, N) :- compound(E), E =.. [_|As], member(A, As), ck_mentions(A, N), !.
ck_lvalue_form(id(_)).
ck_lvalue_form(scoped(_, _)).
ck_lvalue_form(index(_, _)).
ck_lvalue_form(member(_, _)).
ck_lvalue_form(arrow(_, _)).
ck_lvalue_form(deref(_)).
%% a value that lives as long as the program: a string literal, a global's
%% address, a global array or function used as a pointer
ck_static_value(str(_)) :- !.
ck_static_value(wstr(_)) :- !.
ck_static_value(u16str(_)) :- !.
ck_static_value(u32str(_)) :- !.
ck_static_value(u8str(_)) :- !.   % C23's and C++20's u8 literal (0.196)
ck_static_value(cast(_, E)) :- !, ck_static_value(E).
ck_static_value(ccast(_, _, E)) :- !, ck_static_value(E).
ck_static_value(addr(E)) :- !, ck_storage_base(E, N), ck_is_global(N).
ck_static_value(id(N)) :- !, ck_is_global(N), ccl_declared(N, T), ccl_resolve_type(T, T1), ( T1 = arr(_, _) ; T1 = fn(_, _, _) ), !.
ck_static_value(bin(Op, A, _)) :- memberchk(Op, ['+', '-']), !, ck_static_value(A).
ck_static_value(cond(_, A, B)) :- !, ck_static_value(A), ck_static_value(B).
ck_static_value(comma(_, B)) :- !, ck_static_value(B).
ck_static_value(call(id(F), _)) :- atom(F), ck_library_static(F), !.   % the C library's own static storage, and a source-location builtin's literal (0.201, ck_library_static/1)
ck_static_value(call(id(F), [A|_])) :- atom(F), ck_library_borrow(F), !, ck_static_value(A).   % a place in its first argument's object (0.206, ck_library_borrow/1): static where that is
ck_static_value(call(id(F), As)) :- ccl_lang(cpp), atom(F), cpp_library_function(F),   % A POINTER TO CONST THAT A C++ LIBRARY FUNCTION RETURNS FROM NO POINTER ARGUMENT is the library's storage (0.138): libc++'s `locate_zone' answers a zone of the database it keeps for the whole run; a pointer to const cannot be freed, and what the function does is the library's discipline (its functions are not checked)
    catch(ccl_declared(F, fn(R, _, _)), _, fail), catch(ccl_resolve_type(R, ptr(_, base(Q, _))), _, fail), memberchk(const, Q),
    \+ ( member(A, As), A \== nullptr, ck_pointer_arg(A) ), !.
ck_pointer_arg(addr(_)) :- !.
ck_pointer_arg(A) :- catch(ccl_type_of(A, T), _, fail), T \== unknown, catch(ccl_resolve_type(T, T1), _, fail), ( T1 = ptr(_, _) ; T1 = arr(_, _) ), !.
%% A POINTER THAT THE C LIBRARY ANSWERS FROM ITS OWN STATIC STORAGE (C17 7.11.1.1, 7.11.2.1, 7.22.4.6, 7.24.6.2, 7.27.3; 0.201):
%% `getenv', `setlocale', `localeconv', `strerror', `asctime', `ctime', `gmtime' and `localtime' answer an object the library
%% keeps for the whole run, which a later call may overwrite and the program never frees, as a string literal is; and
%% clang's `__builtin_FILE()', `__builtin_FILE_NAME()' and `__builtin_FUNCTION()' answer a literal (the lowering's
%% ir_call/4). Each was fresh memory to the check, `plain pointer not consumed'. `cwrap.c', `srcbuiltins.c'.
ck_library_static(F) :- memberchk(F, [getenv, setlocale, localeconv, strerror, asctime, ctime, gmtime, localtime, '__builtin_FILE', '__builtin_FILE_NAME', '__builtin_FUNCTION']).

ck_line(L) :- ( integer(L), L > 0 -> nb_setval('$ck_line', L) ; true ).
ck_fail(Kind, Name, Form) :- nb_getval('$ck_fn', F), nb_getval('$ck_line', L), ck_short(Form, Short0), ck_squash(Short0, Short), throw(error(ownership(Kind, Name, Short), where(F, line(L)))).
%% a form without a macro's whole expansion in it
ck_squash(stmt_expr(_), '({ ... })') :- !.
ck_squash(T, S) :- compound(T), !, T =.. [F|As], ck_squash_list(As, Bs), S =.. [F|Bs].
ck_squash(T, T).
ck_squash_list([], []).
ck_squash_list([A|As], [B|Bs]) :- ck_squash(A, B), ck_squash_list(As, Bs).
%% a statement form is named without its line
ck_short(T, S) :- compound(T), functor(T, F, A), A > 1, memberchk(F, [expr, if, while, do, for, return, switch, case, default, label, goto]), arg(1, T, L), integer(L), !, T =.. [F, _|As], S =.. [F|As].
ck_short(return(L), return) :- integer(L), !.
ck_short(break(_), break) :- !.
ck_short(continue(_), continue) :- !.
ck_short(T, T).

%% lookup and update, innermost frame first
ck_state(st(Frs), N, S) :- ck_in(Frs, N, S).
ck_in([fr(Os, _)|Frs], N, S) :- ( memberchk(N-S0, Os) -> S = S0 ; ck_in(Frs, N, S) ).
ck_set(st(Frs), N, S, st(Frs1)) :- ck_set_(Frs, N, S, Frs1).
ck_set_([fr(Os, Ds)|Frs], N, S, [fr(Os1, Ds)|Frs]) :- memberchk(N-_, Os), !, ck_put(Os, N, S, Os1).
ck_set_([F|Frs], N, S, [F|Frs1]) :- ck_set_(Frs, N, S, Frs1).
ck_put([], _, _, []).
ck_put([N-_|T], N, S, [N-S|T]) :- !.
ck_put([X|T], N, S, [X|T1]) :- ck_put(T, N, S, T1).
ck_set_all(St, [], _, St).
ck_set_all(St0, [K|Ks], S, St) :- ( ck_state(St0, K, _) -> ck_set(St0, K, S, St1) ; St1 = St0 ), ck_set_all(St1, Ks, S, St).
ck_set_if(St0, K, S, St) :- ( ck_state(St0, K, _) -> ck_set(St0, K, S, St) ; St = St0 ).
ck_is_owner(St, N) :- ck_state(St, N, S), ck_owner_state(S).
%% a key declared in the innermost frame; a tie it had before is gone with it
ck_declare(st([fr(Os, Ds)|Frs]), N, S, st([fr([N-S|Os], Ds)|Frs])) :- ck_drop_tie(N).
ck_declare_all(St, [], St).
ck_declare_all(St0, [K-S|Ps], St) :- ck_declare(St0, K, S, St1), ck_declare_all(St1, Ps, St).
ck_push(st(Frs), st([fr([], [])|Frs])).
ck_declare_borrow(st([fr(Os, Ds)|Frs]), N, P, st([fr([N-borrow(P)|Os], Ds)|Frs])).
%% a plain pointer assigned again: a borrow of something else, or of nothing
ck_rebind(St0, N, none, St) :- !, ( ck_state(St0, N, S), ( S = borrow(_) ; S = dangling(_) ; S == loose ) -> ck_set(St0, N, none, St) ; St = St0 ).
ck_rebind(St0, N, S, St) :- ( ck_state(St0, N, _) -> ck_set(St0, N, S, St) ; ck_declare_at(St0, N, S, St) -> true ; ck_declare(St0, N, S, St) ).
%% a local: declared in a frame of the function's, not the file's, and not
%% static (a static local's storage never ends: a global's); its type from there
ck_is_local(N) :- \+ ck_is_static(N), ccl_locals(Ls), member(F, Ls), memberchk(N-_, F), !.
ck_is_static(N) :- nb_getval('$ck_statics', Ss), memberchk(N, Ss).
ck_note_statics([]).
ck_note_statics([var(N, _, _)|Vs]) :- nb_getval('$ck_statics', Ss), nb_setval('$ck_statics', [N|Ss]), ck_note_statics(Vs).
ck_local_type(N, T) :- ccl_locals(Ls), member(F, Ls), memberchk(N-T, F), !.
ck_is_global(N) :- atom(N), \+ ck_is_local(N), ccl_declared(N, _).

%% ---- ties ---------------------------------------------------------------------------------
%% '$ck_ties' holds Key-Root for every declared tie: a local's, a parameter's,
%% a field's in an instance; the root is an owner, an anchor, a parameter or a
%% global -- what y borrows when y is a borrow. A slot under a tied base is
%% tied to the base's root.
ck_note_tie(K, R) :- nb_getval('$ck_ties', Ts), ck_del_tie(K, Ts, Ts1), nb_setval('$ck_ties', [K-R|Ts1]).
ck_drop_tie(K) :- nb_getval('$ck_ties', Ts), ( memberchk(K-_, Ts) -> ck_del_tie(K, Ts, Ts1), nb_setval('$ck_ties', Ts1) ; true ).
ck_del_tie(_, [], []).
ck_del_tie(K, [K-_|T], T1) :- !, ck_del_tie(K, T, T1).
ck_del_tie(K, [X|T], [X|T1]) :- ck_del_tie(K, T, T1).
ck_declared_tie(K, R) :- nb_getval('$ck_ties', Ts), memberchk(K-R, Ts).
ck_tied_to(K, R) :- ck_declared_tie(K, R), !.
ck_tied_to(K, R) :- ck_base_path(K, B), ck_tied_to(B, R).
%% P lies within Y: the same; P tied to something within Y; P a borrow of
%% something within Y; P a field of something within Y
ck_within(_, P, P) :- !.
ck_within(St, _, P) :- ck_state(St, P, loose), !.                      % nobody ends a loose pointer's memory
ck_within(_, _, static(_)) :- !.                                        % nor static storage
ck_within(St, P, Y) :- ck_declared_tie(P, T), !, ck_within(St, T, Y).
ck_within(St, P, Y) :- ck_state(St, P, S), ( S = borrow(R) ; S = dangling(R) ), R \== P, !, ck_within(St, R, Y).
ck_within(St, P, Y) :- ck_base_path(P, B), ck_within(St, B, Y), !.
ck_within(St, Y, P) :- ck_base_path(P, B), ck_within(St, Y, B).        % a value rooted at a field: its holder stands for it (a child of x, returned as x's)
%% what `tie y' refers to, for a local or a parameter: a key's root (its state
%% borrow or dangling when y is a borrow); a plain local, anchored now; a
%% global, which never ends; else nothing declared before, tie_unknown
ck_tie_ref(St0, Y, Form, St, Kind, R) :-
    (   ck_state(St0, Y, S) -> St = St0, ck_root_of(Y, S, Kind, R)
    ;   ck_is_local(Y) -> ck_anchor(St0, Y, St), Kind = borrow, R = Y
    ;   ck_is_global(Y) -> St = St0, Kind = borrow, R = Y
    ;   ck_fail(tie_unknown, Y, Form) ).
ck_root_of(_, borrow(R), borrow, R) :- !.
ck_root_of(_, dangling(R), dangling, R) :- !.
ck_root_of(Y, _, borrow, Y).
%% a field's tie: the sibling's key, anchored when it is a plain member
ck_field_tie_ref(St0, YK, St, Kind, R) :-
    (   ck_state(St0, YK, S) -> St = St0, ck_root_of(YK, S, Kind, R)
    ;   ck_declare(St0, YK, anchor, St), Kind = borrow, R = YK ).
%% an anchor for a plain local: a root in the frame where the local was
%% declared (the state's frames and the symbol table's are pushed together)
ck_anchor(St, Y, St1) :- ck_declare_at(St, Y, anchor, St1).
ck_declare_at(st(Frs), N, S, st(Frs1)) :- ccl_locals(Ls), ( ck_frame_index(Ls, N, 0, I) -> true ; ccl_gdeclared(N, _), length(Ls, I) ), ck_insert_at(Frs, I, N-S, Frs1).   % the file scope is the LAST frame: a name in no open frame is there if it is declared at all -- asked of the table, the list of all its names no longer copied (0.119)
ck_frame_index([F|Fs], Y, I0, I) :- ( memberchk(Y-_, F) -> I = I0 ; I1 is I0 + 1, ck_frame_index(Fs, Y, I1, I) ).
ck_insert_at([fr(Os, Ds)|Frs], 0, P, [fr(Os1, Ds)|Frs]) :- !, append(Os, [P], Os1).
ck_insert_at([F|Frs], I, P, [F|Frs1]) :- I1 is I - 1, ck_insert_at(Frs, I1, P, Frs1).
%% `&x' of a plain local, `&x.f', `&a[i]' of a local array, a local array used
%% as a pointer: the local's storage is what is pointed to, so it is anchored
%% before the expression is read, and the pointer is a borrow of it
ck_anchor_addrs(E, St, St) :- \+ compound(E), !.
ck_anchor_addrs(addr(E), St0, St) :- !, ( ck_storage_base(E, N), \+ ck_is_ref(N) -> ck_anchor_local(N, St0, St1) ; St1 = St0 ), ck_anchor_addrs(E, St1, St).
ck_anchor_addrs(id(N), St0, St) :- !, ( ck_arrlocal(N), ck_local_type(N, T), ccl_resolve_type(T, arr(_, _)) -> ck_anchor_local(N, St0, St) ; St = St0 ).
ck_anchor_addrs(bin(_, A, B), St0, St) :- !, ck_anchor_addrs(A, St0, St1), ck_anchor_addrs(B, St1, St).      % the common shapes, without a univ
ck_anchor_addrs(index(A, I), St0, St) :- !, ck_anchor_addrs(A, St0, St1), ck_anchor_addrs(I, St1, St).
ck_anchor_addrs(arrow(E, _), St0, St) :- !, ck_anchor_addrs(E, St0, St).
ck_anchor_addrs(member(E, F), St0, St) :- !, ( ck_storage_base(E, N), ck_is_local(N), \+ ck_is_ref(N), ck_array_member(E, F) -> ck_anchor_local(N, St0, St1) ; St1 = St0 ), ck_anchor_addrs(E, St1, St).   % an ARRAY member of a local struct used as a pointer anchors the struct (0.108)
ck_anchor_addrs(assign(_, L, R), St0, St) :- !, ck_anchor_addrs(L, St0, St1), ck_anchor_addrs(R, St1, St).
ck_anchor_addrs(call(F, As), St0, St) :- !, ck_anchor_addrs(F, St0, St1), ck_anchor_addrs_list(As, St1, St).
ck_anchor_addrs(E, St0, St) :- E =.. [_|As], ck_anchor_addrs_list(As, St0, St).
%% the names declared with an array type in this function, so the walk over
%% every expression asks the scope only of those (every id cost a lookup and
%% a resolution: 7 ms of the B-tree's check); the scope still decides
ck_note_arrlocal(N, T) :- ( ccl_resolve_type(T, arr(_, _)) -> nb_getval('$ck_arrlocals', As), nb_setval('$ck_arrlocals', [N|As]) ; true ).
ck_note_arrparams([]).
ck_note_arrparams([P|Ps]) :- ( ( P = param(T, N) ; P = param(T, N, _) ), N \== anon -> ck_note_arrlocal(N, T) ; true ), ck_note_arrparams(Ps).
ck_arrlocal(N) :- nb_getval('$ck_arrlocals', As), memberchk(N, As).
ck_array_member(E, F) :- ccl_type_of(member(E, F), MT), ccl_resolve_type(MT, arr(_, _)).
ck_anchor_addrs_list([], St, St).
ck_anchor_addrs_list([A|As], St0, St) :- ck_anchor_addrs(A, St0, St1), ck_anchor_addrs_list(As, St1, St).
ck_anchor_local(N, St0, St) :- ( ck_state(St0, N, _) -> St = St0 ; ck_is_local(N) -> ck_anchor(St0, N, St) ; St = St0 ).
ck_storage_base(id(N), N).
ck_storage_base(member(E, _), N) :- ck_storage_base(E, N).
ck_storage_base(index(E, _), N) :- ccl_type_of(E, T), ccl_resolve_type(T, arr(_, _)), ck_storage_base(E, N).
%% the tie a variable declares for itself: an owner (or a struct by value with
%% own fields) keeps its state and the tie is noted; anything else becomes a
%% borrow of the root, whatever its type
ck_var_tie(N, T, St0, St) :-
    (   ccl_tie_of(T, Y)
    ->  ( Y == N -> ck_fail(tie_unknown, Y, tie(N, Y)) ; true ),
        ck_tie_ref(St0, Y, tie(N, Y), St1, Kind, R),
        (   ck_state(St1, N, S), ck_owner_state(S) -> St = St1
        ;   ck_own_under(St1, N, [_|_]) -> St = St1
        ;   Sn =.. [Kind, R], ( ck_state(St1, N, _) -> ck_set(St1, N, Sn, St) ; ck_declare(St1, N, Sn, St) ) ),
        ck_note_tie(N, R)
    ;   St = St0 ).
%% the tied fields of an instance: each an own field (the tie noted) or a
%% borrow of its sibling's root, declared in order
ck_field_ties(N, T, St0, St, Ts) :- ck_var_ties(N, T, Ts), ck_field_ties_(Ts, St0, St).
ck_field_ties_([], St, St).
ck_field_ties_([K-YK|Ts], St0, St) :-
    ck_field_tie_ref(St0, YK, St1, Kind, R),
    (   ck_state(St1, K, S), ck_owner_state(S) -> St2 = St1
    ;   ck_own_under(St1, K, [_|_]) -> St2 = St1
    ;   Sn =.. [Kind, R], ck_declare(St1, K, Sn, St2) ),
    ck_note_tie(K, R),
    ck_field_ties_(Ts, St2, St).
%% a tied owner consumed: nothing tied to it may still hold memory
ck_tied_consumed(St, K, Form) :- nb_getval('$ck_ties', Ts), ck_tied_consumed_(Ts, St, K, Form).
ck_tied_consumed_([], _, _, _).
ck_tied_consumed_([X-R|Ts], St, K, Form) :-
    ( X \== K, ck_within(St, R, K), ck_state(St, X, S), memberchk(S, [live, partial]) -> ck_fail(tie_outlived, X, Form) ; true ),
    ck_tied_consumed_(Ts, St, K, Form).
%% an owner moved: its tie, if any, must cover the slot it goes into
ck_tie_kept(St, P, Key, Form) :- ( ck_tied_to(P, T) -> ( Key \== none, ck_within(St, Key, T) -> true ; ck_fail(tie_escapes, P, Form) ) ; true ).
%% a value with no owner behind it, given to a variable that carries a pointer
%% without being one (a struct by value: the check cannot follow it)
ck_no_owner_behind(N, T, V, Form) :-
    (   ck_carries_type(T), \+ ck_is_pointer_type(T), \+ ck_declared_tie(N, _), ck_fresh_value(V) -> ck_fail(untied, N, Form)
    ;   true ).
ck_fresh_value(V) :- V \== none, V \= init(_), \+ ck_null(V), \+ ck_static_value(V), \+ ck_ref_rooted(V), \+ ck_va_value(V).
%% a value read by `va_arg' is the CALLER's argument, handed on and never this function's to consume (0.108)
ck_va_value(va_arg(_, _)).
ck_va_value(compound_lit(_, _)).   % C99's compound literal is an object of the enclosing block, never a fresh value to consume (0.108)
ck_va_value(dyncast(_, _, _, _)).
ck_va_value(eh_alloc(_)).
ck_va_value(call(id(B), _)) :- memberchk(B, ['__builtin_coro_frame', '__builtin_coro_promise', '__builtin_coro_noop']).   % a coroutine's frame: the lowering's (0.108)
ck_va_value(dyncast_ref(_, _, _, _)).
ck_va_value(addr(deref(X))) :- ck_va_value(X).
ck_va_value(cast(_, X)) :- ck_va_value(X).
%% C++: THE ADDRESS OF A PATH UNDER A REFERENCE THE CHECK DOES NOT FOLLOW is no fresh value -- a reference bound to
%% a call (a container's element, `*it') has no state, and `const auto &[k, v] = *it' binds v to a member of it:
%% nothing here is to be consumed, so the binding is a plain value, never a loose pointer (0.79)
ck_ref_rooted(addr(P)) :- ck_path_root(P, R), ck_is_ref(R).
ck_path_root(id(R), R).
ck_path_root(member(X, _), R) :- ck_path_root(X, R).
ck_path_root(arrow(X, _), R) :- ck_path_root(X, R).
ck_path_root(index(X, _), R) :- ck_path_root(X, R).
ck_path_root(deref(X), R) :- ck_path_root(X, R).
%% a loose pointer's memory taken: by free, a return, a slot, an owner
ck_consume_loose(St0, P, St) :- ck_set(St0, P, none, St1), ck_dangle(St1, P, St).
ck_loose_taken(E, St0, St) :- ( ck_borrows_from(E, St0, P), ck_state(St0, P, loose) -> ck_set(St0, P, none, St) ; St = St0 ).
%% the borrows of a loose pointer, once an owner holds its memory, borrow the owner
ck_retarget(st(Frs), P, Key, st(Frs1)) :- ck_retarget_frames(Frs, P, Key, Frs1).
ck_retarget_frames([], _, _, []).
ck_retarget_frames([fr(Os, D)|T], P, K, [fr(Os1, D)|T1]) :- ck_retarget_owners(Os, P, K, Os1), ck_retarget_frames(T, P, K, T1).
ck_retarget_owners([], _, _, []).
ck_retarget_owners([N-borrow(P)|T], P, K, [N-borrow(K)|T1]) :- !, ck_retarget_owners(T, P, K, T1).
ck_retarget_owners([X|T], P, K, [X|T1]) :- ck_retarget_owners(T, P, K, T1).
%% a borrow of P bound to N: within N's tie when N has one, else a plain borrow
ck_bind_var(N, P, Form, St0, St) :-
    (   ck_declared_tie(N, R) -> ( ck_within(St0, R, P) -> true ; ck_fail(tie_mismatch, N, Form) ), ck_tied_state(St0, R, S), ck_set(St0, N, S, St)
    ;   ck_declare_borrow(St0, N, P, St) ).
%% the state of something tied to root R now: dangling when R is gone
ck_tied_state(St, R, S) :-
    (   ck_state(St, R, RS) -> ( memberchk(RS, [moved, partial]) -> S = dangling(R) ; RS = dangling(R1) -> S = dangling(R1) ; S = borrow(R) )
    ;   S = borrow(R) ).
%% what an expression borrows from: an owner named, a field, through arithmetic,
%% a cast, the address of an element or a member, another borrow
%% (an anchored plain variable's VALUE borrows nothing -- only its address does,
%% and a local array's value, which is its address)
ck_borrows_from(scoped(_, N), St, P) :- !, ck_borrows_from(id(N), St, P).        % C++ (M6): a qualified name is its bare name
ck_borrows_from(ccast(_, _, E), St, P) :- !, ck_borrows_from(E, St, P).
%% A LOCAL THAT HOLDS BORROWS IN ITS STORAGE (0.217, ck_hold_key/6): its value carries what it holds -- a struct with a
%% pointer member given `&x', a library object handed one --, the borrow that can dangle first; its address is its own
ck_borrows_from(id(N), St, P) :- ck_holder(N), \+ ck_arrlocal(N), ck_held_borrow(St, N, P), !.
ck_borrows_from(id(N), St, P) :- ck_state(St, N, S), !, ( S == anchor -> ck_local_type(N, T), ccl_resolve_type(T, arr(_, _)), P = N ; ck_borrow_source(N, S, P) ).
ck_borrows_from(member(E, F), St, P) :- ck_path(member(E, F), K), ck_state(St, K, S), !, ck_borrow_source(K, S, P).
ck_borrows_from(arrow(E, F), St, P) :- ck_path(arrow(E, F), K), ck_state(St, K, S), !, ck_borrow_source(K, S, P).
ck_borrows_from(bin(Op, A, _), St, P) :- memberchk(Op, ['+', '-']), !, ck_borrows_from(A, St, P).
ck_borrows_from(cast(_, A), St, P) :- !, ck_borrows_from(A, St, P).
ck_borrows_from(dyncast(A, _, _, _), St, P) :- !, ck_borrows_from(A, St, P).   % the object a dynamic_cast finds is the one it was given (0.108)
ck_borrows_from(dyncast_ref(A, _, _, _), St, P) :- !, ck_borrows_from(A, St, P).
ck_borrows_from(addr(index(A, _)), St, P) :- !, ck_borrows_from(addr(A), St, P).             % &a[i], &c.f: what &a, &c borrow (an anchor, an owner's slot)
ck_borrows_from(addr(member(A, _)), St, P) :- !, ck_borrows_from(addr(A), St, P).
ck_borrows_from(addr(arrow(A, _)), St, P) :- !, ck_borrows_from(A, St, P).
ck_borrows_from(addr(deref(A)), St, P) :- !, ck_borrows_from(A, St, P).                       % &*p: what p borrows (0.132) -- a reference bound to `*it', which every `for (auto&& x : r)' over raw-pointer iterators makes (std::array, std::string_view, the empty and single views), was fresh memory, `plain pointer not consumed'
ck_borrows_from(addr(id(N)), St, P) :- ck_is_ref(N), !, ck_state(St, N, S), ck_borrow_source(N, S, P).   % C++: &x of a reference is the pointer held
ck_borrows_from(id(N), St, P) :- ck_is_ref(N), !, ck_local_type(N, ptr(_, RT)), ck_carries_type(RT), ck_state(St, N, S), ck_borrow_source(N, S, P).   % its value: what it refers to
%% THE ADDRESS OF A POINTER OR ARRAY PARAMETER is a borrow of the parameter's own storage (0.219), keyed `&p' apart from p,
%% which keys what p points to, the caller's: anchored in the function's outer frame (ck_param_selves/2) and short-lived
%% (ck_short_lived/1). `int **f(int *p) { return &p; }' answered p's referent and was accepted, a dead parameter's address
ck_borrows_from(addr(id(N)), _, K) :- atom(N), ck_is_param(N), \+ ck_is_ref(N), \+ ck_param_storage(N), !, atom_concat('&', N, K).
%% THE ADDRESS OF A LOCAL is a borrow of the local: an anchored one's, an owner's slot, and one that holds a borrow -- a
%% pointer, a view, an iterator (0.217): `&p' over `int *p = q' answered what p points to, so `int **f(int *q) { int *p = q;
%% return &p; }' and the address of a local view of a static string returned were accepted, each a dead local's address
ck_borrows_from(addr(id(N)), St, P) :- !, ck_state(St, N, S),
    (   S == anchor -> P = N
    ;   ( S = borrow(_) ; S = dangling(_) ), ck_is_local(N), \+ ck_is_param(N) -> P = N
    ;   ck_borrow_source(N, S, P) ).
%% what a borrowed pointer reaches -- a member, an element, what it points to -- is borrowed from the same
ck_borrows_from(arrow(E, _), St, P) :- !, ck_borrows_from(E, St, P).
ck_borrows_from(member(E, F), St, P) :- ck_storage_base(E, N), ck_state(St, N, anchor), ck_array_member(E, F), !, P = N.   % the array member of an anchored local struct: a borrow of the struct (0.108)
ck_borrows_from(member(E, _), St, P) :- !, ck_borrows_from(E, St, P).
ck_borrows_from(index(A, _), St, P) :- ck_held_key_array(A, K), ck_state(St, K, S), ( S = borrow(P) ; S = dangling(P) ), !.   % an element's value: what the array's elements hold (0.217)
ck_borrows_from(index(A, _), St, P) :- !, ck_borrows_from(A, St, P).
ck_borrows_from(deref(E), St, P) :- !, ck_borrows_from(E, St, P).
ck_borrows_from(cond(_, A, B), St, P) :- !, ( ck_borrows_from(A, St, P) -> true ; ck_borrows_from(B, St, P) ).
ck_borrows_from(comma(_, B), St, P) :- !, ck_borrows_from(B, St, P).
ck_borrows_from(stmt_expr(block(Is)), St, P) :- append(_, [expr(_, id(N))], Is), atom(N), ( atom_concat('$at', _, N) ; atom_concat('$new', _, N) ),   % A NEW-EXPRESSION'S RESULT, `$new', what its block's allocation borrows (alloc/3, 0.202); A PLACEMENT NEW'S RESULT is the address it was given (0.112): the desugaring's `$at', declared in the block from that address and never assigned again, borrows what the address borrows -- `int *p = new (buf) int(7)' over a local buffer had read as a loose pointer, `plain pointer not consumed'
    member(declaration(_, _, _, Vs), Is), memberchk(var(N, _, I), Vs), I \== none, !, ck_borrows_from(I, St, P).
%% A LIBRARY OBJECT MADE IN A BLOCK BORROWS WHAT ITS MEMBERS ARE HANDED THERE (0.216, ck_lib_handed/4): the desugaring's
%% `$tmp' or `$ret', declared in the block and built there by the library's constructor -- `return std::function<int()>([&x]
%% { return x; })', `std::string_view(buf)', the move out of a parameter by value `return v' -- is a borrow of what its
%% arguments borrow, the closure's captures among them
ck_borrows_from(stmt_expr(block(Is)), St, P) :- append(_, [expr(_, id(N))], Is), atom(N), member(declaration(_, _, _, Vs), Is), memberchk(var(N, _, _), Vs),
    member(expr(_, call(id(F), [addr(id(N))|As])), Is), atom(F), cpp_library_function(F), ck_lib_handed(As, none, St, P), !.
ck_borrows_from(stmt_expr(block(Is)), St, P) :- append(_, [expr(_, E)], Is), !, ck_borrows_from(E, St, P).
ck_borrows_from(alloc(_, _, Call), St, P) :- !, ck_borrows_from(Call, St, P).   % A NEW-EXPRESSION'S BLOCK borrows what its allocation function's result borrows (0.202): an arena's `void *operator new(std::size_t, Arena &a) tie a' hands back memory of `a'
%% A CLOSURE BORROWS WHAT ITS CAPTURES BORROW (0.100): the desugaring makes a lambda a compound literal of the
%% captures' values, `&x' for a reference capture and `this' for the object, so a closure local is a borrow of the
%% captured local (an anchor) or of the parameter, and `return f' of one that holds `&x' is borrow_escapes where a
%% dangling reference had compiled and run -- the hole 0.59 named. A by-value capture of a plain value borrows nothing.
ck_borrows_from(compound_lit(_, init(Items)), St, P) :- member(item(_, V), Items), ck_borrows_from(V, St, P), !.
%% a call whose result is tied to a parameter borrows from that argument (an
%% own result is an owner instead: fresh, checked against the tie where it lands)
%% A PLAIN POINTER A LIBRARY CLASS'S MEMBER ANSWERS IS A BORROW OF THE OBJECT, never fresh memory:
%% `std::array''s iterators ARE raw pointers, where a vector's are a `__wrap_iter' class and opaque since
%% 0.79 (`ck_carries_'), so the range-for's own `auto __e = a.end()' was a loose pointer and the owner's
%% rule refused it at the scope's end (`plain pointer not consumed'). The library's discipline is its own
%% (0.45's decision), and what its member hands back points INTO the object -- which is what a borrow says,
%% so the lifetime rules still hold rather than the pointer being merely exempted.
ck_borrows_from(call(id(F), [addr(E)|_]), St, P) :- ccl_lang(cpp), atom(F), cpp_library_function(F), ck_path_root(E, R), !, ck_borrow_of(R, St, P).
%% ... AND SO IS WHAT A LIBRARY STATIC FUNCTION ANSWERS OVER AN OBJECT IT TAKES BY REFERENCE (0.117): a static member takes a null
%% `this' first, and the object is the first argument whose parameter is a reference -- `std::allocator_traits<A>::allocate(a, n)'
%% hands back memory the allocator `a' manages, so the pointer is a borrow of `a' and not loose memory that nothing consumes
ck_borrows_from(call(id(F), [nullptr|As]), St, P) :- ccl_lang(cpp), atom(F), cpp_library_function(F), ccl_declared(F, fn(_, [_|Ps], _)), ck_ref_object(As, Ps, E), ck_path_root(E, R), !, ck_borrow_of(R, St, P).
%% ... AND A LIBRARY FUNCTION'S POINTER RESULT BORROWS WHAT ITS POINTER ARGUMENTS BORROW (0.117), the first that borrows anything:
%% `std::construct_at(p + 2, 42)' hands back its first argument, `std::find' a place in its range -- not fresh memory
ck_borrows_from(call(id(F), Args), St, P) :- ccl_lang(cpp), atom(F), cpp_library_function(F), member(A, Args), A \== nullptr, \+ ck_lib_container_arg(F, Args, A), ck_borrows_from(A, St, P), !.
%% ... AND WHAT A FREE LIBRARY FUNCTION ANSWERS OVER AN OBJECT IT TAKES BY REFERENCE BORROWS THAT OBJECT (0.216; the owner's
%% decision of 0.190): `Del *d = std::get_deleter<Del>(sp)' points into sp's control block, `std::ref(x)' refers to x,
%% `std::data(v)' into v -- an object that holds no borrow of its own, a pointer's or a view's value being the clause above's.
%% The deleter's pointer was fresh memory, `plain pointer not consumed', and a returned `std::ref' of a local compiled
ck_borrows_from(call(id(F), Args), St, P) :- ccl_lang(cpp), atom(F), cpp_library_function(F), catch(ccl_declared(F, fn(_, Ps, _)), _, fail),
    ck_ref_object(Args, Ps, E), ck_path_root(E, R), \+ ( catch(ccl_type_of(E, ET), _, fail), ET \== unknown, ( ck_carries_type(ET) ; ck_value_like(ET) ) ), !, ck_borrow_of(R, St, P).
ck_borrows_from(call(id(F), [A|_]), St, P) :- atom(F), ck_library_borrow(F), !, ck_borrows_from(A, St, P).   % a place in its first argument's object (0.206, ck_library_borrow/1)
ck_borrows_from(call(F, Args), St, P) :- ck_callee_sig(F, fn(R, _, _)), \+ ck_own_type(R), ck_call_tie(call(F, Args), St, P0), !, P = P0.
%% a container that holds borrows, bound to a function's lvalue reference: its result is in the container (0.217) --
%% `std::back_inserter(dst)', `std::begin(v)' -- where a value's borrow (std::move's) is the clause before it
ck_lib_container_arg(F, Args, A) :- catch(ccl_declared(F, fn(_, Ps, _)), _, fail), ck_ref_object(Args, Ps, E), E == A, catch(ccl_type_of(A, AT), _, fail), AT \== unknown,
    ck_holds_lib_borrow(AT), \+ ck_value_like(AT).
%% A C LIBRARY FUNCTION WHOSE POINTER RESULT LIES IN ITS FIRST ARGUMENT'S OBJECT (C17 7.24.2, 7.24.3, 7.24.5, 7.24.6.1,
%% 7.29.4; C23 7.26.2.2; POSIX's `stpcpy' and `stpncpy', glibc's `mempcpy', `memrchr', `rawmemchr' and `strchrnul'; 0.206):
%% the copies, the concatenations and `memset' answer the destination, the searches a place in the object searched or null,
%% `memccpy' a place in the destination or null -- a borrow of what that argument borrows, never fresh memory: `char *e =
%% memccpy(buf, s, ',', n)' was `plain pointer not consumed'. clang's `__builtin_' spelling of one is the function.
ck_library_borrow(F) :- atom_concat('__builtin_', G, F), !, ck_library_borrow(G).
ck_library_borrow(F) :- memberchk(F, [memcpy, memmove, memset, memccpy, memchr, strcpy, strncpy, strcat, strncat, strchr, strrchr, strpbrk, strstr,
    wmemcpy, wmemmove, wmemset, wmemchr, wcscpy, wcsncpy, wcscat, wcsncat, wcschr, wcsrchr, wcspbrk, wcsstr,
    stpcpy, stpncpy, wcpcpy, wcpncpy, mempcpy, wmempcpy, memrchr, rawmemchr, strchrnul]).
ck_ref_object([A|_], [param(T, _)|_], A) :- catch(ccl_resolve_type(T, ref(_, _)), _, fail), !.
ck_ref_object([_|As], [_|Ps], E) :- ck_ref_object(As, Ps, E).
ck_borrow_of(R, St, P) :- ck_state(St, R, S), !, ( ck_borrow_source(R, S, P) -> true ; P = R ).
ck_borrow_of(R, _, R).
%% A LIBRARY OBJECT BORROWS WHAT IT IS HANDED (0.216; the owner's decision of 0.190): a library member's call -- its
%% constructor, `push_back', `insert', `operator=', the assignment through `operator[]' -- whose object holds borrows
%% (ck_holds_lib_borrow/1) and whose arguments borrow (ck_lib_handed/4) stores the borrow where the object lives
%% (ck_where/3): a local object holds it (ck_hold_place/5), so returning the object obeys the borrow rules
%% (ck_no_escape/2, `borrow_escapes') and it dangles where that local's scope ends; an object that outlives the function --
%% through a reference or pointer parameter, `this', a global or a static -- that is handed a borrow of this function's own
%% local is `borrow_stored'. A parameter's borrow and static storage may go anywhere, as they may leave by a return. `int x
%% = 5; std::vector<int *> v; v.push_back(&x); return v;' and `return std::function<int()>([&x] { return x; })' compiled
%% and ran, each handing out a dead local
ck_lib_store(F, [A0|As], St0, St) :- ccl_lang(cpp), atom(F), cpp_library_function(F), ck_lib_member(F), ck_lib_holder(A0, St0, Obj), ck_lib_obj_type(Obj, T),
    ck_holds_lib_borrow(T), \+ ck_lib_no_store(F), ck_lib_self(Obj, St0, Self), ck_lib_handed(As, Self, St0, P), !, ck_lib_store_into(Obj, P, join, call(id(F), [A0|As]), St0, St).
ck_lib_store(_, _, St, St).
%% the object a member's call is on: `this', or the element another member answers by reference -- in a container its
%% object (`m[k] = f' stores into m, `g[0].push_back(&x)' into g), through an iterator or a view what that borrows (`*it =
%% &x' over `it = v.begin()' stores into v, 0.217); a free function's arguments are not its objects (`std::copy(a.begin(),
%% a.end(), o)')
ck_lib_holder(addr(call(id(G), As)), St, Obj) :- !, ck_lib_holder(call(id(G), As), St, Obj).
ck_lib_holder(addr(Obj), _, Obj) :- !.
ck_lib_holder(id(P), _, deref(id(P))) :- atom(P), !.
ck_lib_holder(call(id(G), [A|_]), St, Obj) :- atom(G), cpp_library_function(G), ck_lib_member(G), ck_lib_holder(A, St, O),
    ( O = id(V), ck_lib_obj_type(O, T), ck_value_like(T), ck_state(St, V, borrow(R)), atom(R) -> Obj = id(R) ; Obj = O ).
ck_lib_member(F) :- catch(ccl_declared(F, fn(_, [param(_, this)|_], _)), _, fail).
%% its type as the check sees it, a reference the pointer it is: `s.v' over a reference parameter s is `s->v'
ck_lib_obj_type(Obj, T) :- ck_lib_through_refs(Obj, Obj1), catch(ccl_type_of(Obj1, T), _, fail), T \== unknown.
ck_lib_through_refs(id(R), deref(id(R))) :- atom(R), ck_is_ref(R), !.
ck_lib_through_refs(member(E, F), member(E1, F)) :- !, ck_lib_through_refs(E, E1).
ck_lib_through_refs(index(E, I), index(E1, I)) :- !, ck_lib_through_refs(E, E1).
ck_lib_through_refs(E, E).
%% a member that stores nothing it is handed: a const one, and the lookups and the erasures by their names
ck_lib_no_store(F) :- catch(ccl_declared(F, fn(_, [param(ptr(_, base(Q, _)), this)|_], _)), _, fail), memberchk(const, Q), !.
ck_lib_no_store(F) :- member(W, ['.find.', '.count.', '.contains.', '.lower_bound.', '.upper_bound.', '.equal_range.', '.erase.', '.at.', '.rfind.',
    '.find_first_of.', '.find_last_of.', '.find_first_not_of.', '.find_last_not_of.', '.starts_with.', '.ends_with.', '.compare.', '.remove.',
    '.remove_if.', '.extract.']), sub_atom(F, _, _, _, W), !.
%% WHERE A PLACE LIVES (0.217): ck_resolve/3 follows a place to the storage it names -- a local reference to the place it
%% was bound to (ck_ref_bound/2), a local pointer to the local it borrows now where the types agree (`p->f' over `p = &s'
%% is `s.f'; a pointer into a library container is in the container), an element a library member answers to its holder
%% (ck_lib_holder/3) -- and ck_where/3 says where that is: local(E), a local's own storage by value, a parameter's by
%% value among them; `out', storage that outlives the function (through a reference or a pointer parameter, `this', a
%% global, a static); `unknown', through a pointer the check does not follow
ck_where(E, St, W) :- ck_resolve(E, St, E1), ck_root(E1, R, V), !,
    (   V == own, ck_is_local(R) -> W = local(E1)
    ;   V == ref, ck_is_local(R), \+ ck_is_param(R) -> W = unknown
    ;   W = out ).
ck_where(_, _, unknown).
ck_resolve(id(N), St, E) :- atom(N), ck_is_ref(N), \+ ck_is_param(N), ck_ref_bound(N, B), !, ck_resolve(B, St, E).
ck_resolve(member(X, F), St, member(X1, F)) :- !, ck_resolve(X, St, X1).
ck_resolve(index(id(P), I), St, E) :- ck_points_to(P, St, T), !, ( T = into(R) -> E = id(R) ; E = index(T, I) ).
ck_resolve(index(X, I), St, index(X1, I)) :- !, ck_resolve(X, St, X1).
ck_resolve(arrow(id(P), F), St, E) :- ck_points_to(P, St, T), !, ( T = into(R) -> E = id(R) ; E = member(T, F) ).
ck_resolve(deref(id(P)), St, E) :- ck_points_to(P, St, T), !, ( T = into(R) -> E = id(R) ; E = T ).
ck_resolve(C, St, E) :- C = call(_, _), ck_lib_holder(C, St, O), O \== C, !, ck_resolve(O, St, E).
ck_resolve(E, _, E).
%% a local pointer's target now: the local it borrows, of the type it points to (`p = &s'), an array's element (`p = a'),
%% or into(R), in a library container R it points into
ck_points_to(P, St, T) :- atom(P), \+ ck_is_ref(P), ck_is_local(P), \+ ck_is_param(P), ck_state(St, P, borrow(R)), atom(R), ck_is_local(R),
    ck_local_type(P, PT), catch(ccl_resolve_type(PT, ptr(_, PE)), _, fail), ck_local_type(R, RT), catch(ccl_resolve_type(RT, RT1), _, fail),
    (   ck_same_type(PE, RT1) -> T = id(R)
    ;   RT1 = arr(_, RE), ck_same_type(PE, RE) -> T = index(id(R), int(0))
    ;   ck_holds_lib_borrow(RT1) -> T = into(R) ).
ck_same_type(A, B) :- catch(ccl_resolve_type(A, A1), _, fail), catch(ccl_resolve_type(B, B1), _, fail), ck_unqual(A1, U), ck_unqual(B1, U).
ck_unqual(ptr(_, T), ptr([], U)) :- !, catch(ccl_resolve_type(T, T1), _, fail), ck_unqual(T1, U).
ck_unqual(base(_, S), base([], S)) :- !.
ck_unqual(arr(N, T), arr(N, U)) :- !, ck_unqual(T, U).
ck_unqual(T, T).
%% the variable a place's storage is, and how it is reached: `own', it holds the place by value; `ref', through a pointer
%% or a reference
ck_root(id(N), N, V) :- atom(N), !, ( ck_is_ref(N) -> V = ref ; V = own ).
ck_root(member(E, _), R, V) :- !, ck_root(E, R, V).
ck_root(index(E, _), R, V) :- !, ck_root(E, R, V0), ( ck_lib_obj_type(E, T), catch(ccl_resolve_type(T, arr(_, _)), _, fail) -> V = V0 ; V = ref ).
ck_root(deref(E), R, ref) :- !, ck_root(E, R, _).
ck_root(arrow(E, _), R, ref) :- ck_root(E, R, _).
%% the object's own variable, whose borrow is left out of what it is handed (`v.insert(v.begin(), &x)')
ck_lib_self(Obj, St, Self) :- ( ck_resolve(Obj, St, O1), ck_root(O1, R, _) -> Self = R ; Self = none ).
%% what an object is handed: its arguments' borrows (an initializer list's items for the list), its own (Self, its
%% storage's root) left out; of several, the one that cannot leave the function -- a borrow of a local here -- first
ck_lib_handed(As, Self, St, P) :- findall(P0, ( member(A, As), ck_lib_arg_borrow(A, St, P0), P0 \== Self ), Ps), Ps = [_|_], ck_first_of(Ps, P).
ck_lib_arg_borrow(A, St, P) :- ck_il_items(A, Items), !, member(item(_, V), Items), ck_borrows_from(V, St, P).
ck_lib_arg_borrow(A, St, P) :- ck_borrows_from(A, St, P).
ck_il_items(stmt_expr(block(Is)), Items) :- member(declaration(_, _, _, Vs), Is), member(var(IL, _, init(Items)), Vs), atom(IL), atom_concat('$il', _, IL), !.   % the desugaring's array under a list
%% a borrow that can dangle while the function runs: of a local of its own, a parameter's own storage among them (0.217)
%% -- `int *f(int n) { return &n; }' was accepted, the parameter counted as the caller's --, no static storage, no pointer
%% or reference parameter's referent; the one a join keeps (ck_merge_state/3) and an object that outlives the function may
%% not hold
ck_short_lived(P) :- atom(P), ck_param_self(P), !.                     % a pointer or array parameter's own storage, `&p' (0.219)
ck_short_lived(P) :- atom(P), ck_is_local(P), ( ck_is_param(P) -> ck_param_storage(P) ; true ).
ck_param_storage(P) :- ck_local_type(P, T), \+ ck_is_pointer_type(T), \+ catch(ccl_resolve_type(T, arr(_, _)), _, fail).
ck_param_self(K) :- atom_concat('&', N, K), N \== '', ck_is_param(N).
%% the outer frame's anchors of the pointer and array parameters' own storage, `&p' (0.219, the address of a parameter above)
ck_param_selves(Names, Selves) :- findall(K-anchor, ( member(N, Names), atom(N), N \== anon, N \== this, \+ ck_is_ref(N), \+ ck_param_storage(N), atom_concat('&', N, K) ), Selves).
%% OF SEVERAL BORROWS, THE ONE THAT DANGLES FIRST (0.217): a local's before a parameter's or static storage's (0.216), and
%% of two locals the inner one, whose scope ends first -- a vector given `&a' and then `&b' of an inner block kept a's,
%% and was used after b's end unseen
ck_first_to_dangle(P, Q, R) :- ( ck_short_lived(Q), ( \+ ck_short_lived(P) -> true ; ck_inner_of(Q, P) ) -> R = Q ; R = P ).
ck_inner_of(Q, P) :- ccl_locals(Ls), ck_frame_index(Ls, Q, 0, IQ), ck_frame_index(Ls, P, 0, IP), IQ < IP.
ck_first_of([P1|Ps], P) :- ck_first_of_(Ps, P1, P).
ck_first_of_([], P, P).
ck_first_of_([Q|Qs], P0, P) :- ck_first_to_dangle(P0, Q, P1), ck_first_of_(Qs, P1, P).
ck_lib_store_into(Obj, P, Mode, Form, St0, St) :- ck_where(Obj, St0, W),
    (   W = local(E1) -> ck_hold_place(E1, P, Mode, St0, St)
    ;   W == out, ck_short_lived(P) -> ( ck_slot_name(Obj, N) -> true ; ck_name(Obj, N) ), ck_fail(borrow_stored, N, Form)
    ;   St = St0 ).
%% a borrow joined to what an object holds: a dangling one stays, two borrows as a join keeps them (ck_merge_state/3)
ck_lib_more(dangling(P0), _, dangling(P0)) :- !.
ck_lib_more(borrow(P0), P, S) :- !, ck_merge_state(borrow(P0), borrow(P), S).
ck_lib_more(_, P, borrow(P)).
ck_lib_dtor(F) :- atom(F), sub_atom(F, _, _, _, '.dtor.'), cpp_library_function(F).
%% A MEMBER THAT REPLACES WHAT ITS OBJECT HOLDS (0.216): `operator=', `assign', `clear', `reset' -- the old borrows are not
%% read, a dangling one among them, and what the member is handed, read where the object still held its old value (`sv =
%% sv.substr(1)' borrows what sv borrowed), is all the object holds after; nothing handed, it holds nothing. A view
%% given a new string after the old one died was `use of a borrow after its owner was consumed'
ck_lib_replacing(F, A0, St, Obj) :- ccl_lang(cpp), atom(F), ck_lib_replace_name(F), cpp_library_function(F), ck_lib_member(F), ck_lib_holder(A0, St, Obj),
    ck_lib_obj_type(Obj, T), ck_holds_lib_borrow(T).
ck_lib_replace_name(F) :- member(W, ['.assign.', '.clear.', '.reset.']), sub_atom(F, _, _, _, W), !.
ck_lib_replace(Obj, F, Args, St0, St1, St) :- Args = [_|As], ck_lib_self(Obj, St0, Self),
    (   ck_lib_handed(As, Self, St0, P) -> ck_lib_store_into(Obj, P, replace, call(id(F), Args), St1, St)
    ;   ck_where(Obj, St1, local(E1)) -> ck_unhold(E1, St1, St)
    ;   St = St1 ).
%% ---- what a function of the program stores of its parameters (0.217) ----
%% A FUNCTION THAT STORES ONE PARAMETER'S BORROW IN ANOTHER'S OBJECT -- a member's `items.push_back(w)', `put(v, p)' over
%% `v.push_back(p)', a view member's `sv = v', `r = p' through a reference -- makes its call do the same (ck_flow_store/4):
%% what the caller hands for the holder holds what it hands for the stored one, so `Registry r; r.add(&w); return r;' is
%% `borrow_escapes' and `r.add(&w)' over a reference parameter r `borrow_stored', where until 0.217 the call stored
%% nothing; and one that stores it in a global's or a static's object (`all.push_back(p)', `gsv = v') makes its call
%% store it there, `borrow_stored' for a borrow of the caller's local. The flows are found before the walk, over the
%% program's own functions (ck_flows/1): a store whose object or slot is reached through a parameter that is a pointer or
%% a reference, or is a global's or a static's, of an argument that is another parameter's value, and a call of a
%% function with a flow over the caller's own parameters, until no flow is new. C has none: a store of a pointer
%% parameter's borrow is `borrow_stored' in the function itself, wherever it goes (ck_into_plain/6), and so is one into a
%% plain pointer member in C++; the flows are what the function accepts -- a library object's store, a library value's,
%% a slot through a reference
ck_flows(Units) :- nb_setval('$ck_flows', []), ccl_lang(cpp),
    findall(f(F, Ps, B, Ls), ( member(unit(Is), Units), member(function(_, _, _, F, Ps, _, B), Is), atom(F), \+ catch(cpp_library_function(F), _, fail),
        ck_body_locals(B, Ls) ), Fns),
    Fns = [_|_], !,
    findall(flow(F, J, I), ( member(f(F, Ps, B, Ls), Fns), ck_flow_direct(Ps, B, Ls, J, I) ), Fl0), sort(Fl0, Fl1),
    ck_flows_close(Fns, Fl1, 8, Fl), nb_setval('$ck_flows', Fl).
ck_flows(_).
%% the names a body declares, each with its storage class: a static local's slot outlives every call, a plain one's is the
%% call's own, whatever global it hides
ck_body_locals(B, Ls) :- findall(N-Sto, ( ck_sub_term(declaration(_, Sto, _, Vs), B), member(var(N, _, _), Vs) ), Ls).
ck_flow_direct(Ps, B, Ls, J, I) :- ck_sub_term(C, B), ck_flow_target(C, Ps, Ls, I, Hs), member(H, Hs), ck_flow_value(H, Ps, J), J \== I.
%% where a form stores: a library member's object, or a plain assignment's slot, reached through a parameter (its
%% position) or a global's or a static's (`out(G)')
ck_flow_target(C, Ps, Ls, I, Hs) :- ck_flow_form(C, A0, Hs), ( ck_flow_root(A0, Ps, I) -> true ; ck_flow_obj_out(A0, Ps, Ls, G), I = out(G) ).
ck_flow_target(assign('=', L, R), Ps, Ls, I, [R]) :- L \= call(_, _), ( ck_flow_slot_root(L, Ps, I) -> true ; ck_flow_out_slot(L, Ps, Ls, G), I = out(G) ).
ck_flow_form(call(id(G), [A0|As]), A0, As) :- atom(G), catch(cpp_library_function(G), _, fail), ck_lib_member(G), \+ ck_lib_no_store(G).
ck_flow_form(assign('=', call(id(G), [A0|_]), R), A0, [R]) :- atom(G), catch(cpp_library_function(G), _, fail), ck_lib_member(G).
ck_flows_close(_, Fl, 0, Fl) :- !.
ck_flows_close(Fns, Fl0, K, Fl) :-
    findall(flow(F, J, I), ( member(f(F, Ps, B, Ls), Fns), ck_sub_term(call(id(G), Args), B), atom(G), member(flow(G, GJ, GI), Fl0),
        ccl_nth(GJ, Args, AJ), ck_flow_value(AJ, Ps, J), ck_flow_close_target(GI, Args, Ps, Ls, I), J \== I ), New),
    append(Fl0, New, Fl1), sort(Fl1, Fl2), ( Fl2 == Fl0 -> Fl = Fl0 ; K1 is K - 1, ck_flows_close(Fns, Fl2, K1, Fl) ).
%% the holder: an object reached through a parameter that is a pointer or a reference -- `this', `v' of `std::vector<int *>
%% &v' -- never one by value, whose store is the callee's copy's
ck_flow_root(addr(E), Ps, I) :- !, ck_flow_name(E, N), ck_param_pos(Ps, N, 1, I), ck_flow_indirect(Ps, I).
ck_flow_root(id(N), Ps, I) :- !, ck_param_pos(Ps, N, 1, I), ck_flow_indirect(Ps, I).
ck_flow_root(call(id(G), [A|_]), Ps, I) :- atom(G), catch(cpp_library_function(G), _, fail), ck_flow_root(A, Ps, I).
%% the holder of a callee's flow, at a call in the caller: the argument for it, rooted at the caller's parameter or a global
ck_flow_close_target(out(G), _, _, _, out(G)) :- !.
ck_flow_close_target(GI, Args, Ps, Ls, I) :- ccl_nth(GI, Args, AI), ( ck_flow_root(AI, Ps, I) -> true ; ck_flow_obj_out(AI, Ps, Ls, G), I = out(G) ).
%% a library member's object that outlives every call: a global's or a static's, by its address or through a pointer
ck_flow_obj_out(addr(E), Ps, Ls, G) :- !, ck_flow_out_slot(E, Ps, Ls, G).
ck_flow_obj_out(id(N), Ps, Ls, G) :- !, ck_flow_out_slot(id(N), Ps, Ls, G).
ck_flow_obj_out(call(id(F), [A|_]), Ps, Ls, G) :- atom(F), catch(cpp_library_function(F), _, fail), ck_flow_obj_out(A, Ps, Ls, G).
%% a plain store's slot reached through a pointer or a reference parameter -- `s->p', `*pp', `a[i]' over a pointer, `r.p'
%% and `r' over a reference --, never the parameter's own variable nor a member of one by value, the callee's copy
ck_flow_slot_root(id(N), Ps, I) :- !, atom(N), ck_param_pos(Ps, N, 1, I), ck_flow_by_ref(Ps, I).
ck_flow_slot_root(member(E, _), Ps, I) :- !, ck_flow_slot_root(E, Ps, I).
ck_flow_slot_root(arrow(E, _), Ps, I) :- !, ck_flow_ptr_root(E, Ps, I).
ck_flow_slot_root(deref(E), Ps, I) :- !, ck_flow_ptr_root(E, Ps, I).
ck_flow_slot_root(index(E, _), Ps, I) :- ck_flow_ptr_root(E, Ps, I).
ck_flow_ptr_root(id(N), Ps, I) :- !, atom(N), ck_param_pos(Ps, N, 1, I), ck_flow_indirect(Ps, I).
ck_flow_ptr_root(E, Ps, I) :- ck_flow_slot_root(E, Ps, I).
ck_flow_by_ref(Ps, I) :- ck_param_type(Ps, I, T), catch(ccl_resolve_type(T, T1), _, fail), ( T1 = ref(_, _) ; T1 = rref(_, _) ), !.
%% a slot that outlives every call, reached by a name that is no parameter's: a static local's, or a global's that the body
%% declares no local of -- `g', `g.p', `g[i]', `*g'
ck_flow_out_slot(L, Ps, Ls, G) :- ck_flow_name(L, G), \+ ck_param_pos(Ps, G, 1, _),
    ( memberchk(G-Sto, Ls) -> Sto == static ; catch(ccl_declared(G, T), _, fail), T \= fn(_, _, _) ), !.
ck_flow_name(id(N), N) :- atom(N).
ck_flow_name(member(E, _), N) :- ck_flow_name(E, N).
ck_flow_name(arrow(E, _), N) :- ck_flow_name(E, N).
ck_flow_name(deref(E), N) :- ck_flow_name(E, N).
ck_flow_name(index(E, _), N) :- ck_flow_name(E, N).
ck_param_pos([P|_], N, I, I) :- ( P = param(_, N) ; P = param(_, N, _) ), !.
ck_param_pos([_|Ps], N, I0, I) :- I1 is I0 + 1, ck_param_pos(Ps, N, I1, I).
ck_flow_indirect(Ps, I) :- ck_param_type(Ps, I, T), catch(ccl_resolve_type(T, T1), _, fail), ( T1 = ptr(_, _) ; T1 = ref(_, _) ; T1 = rref(_, _) ), !.
%% what is stored: a parameter's value that borrows -- a pointer's, a reference's referent (`&r'), a library object's --, under
%% a cast, a move or a forward, or an initializer list's item; ... AND A VALUE COMPUTED FROM ONE (0.221): a pointer or an
%% iterator moved within what it points into (`p + n', `n + p', `p - n'), and a place in a pointer's pointee (`&p->f',
%% `&p[i]', `&*p'), which a flow took for none, so `out.push_back(&p->v)' over the caller's `&s' let `s' escape with `out'
ck_flow_value(id(N), Ps, J) :- !, ck_param_pos(Ps, N, 1, J), ck_param_type(Ps, J, T), catch(ccl_resolve_type(T, T1), _, fail),
    ( T1 = ptr(_, _) -> true ; T1 = ref(_, RT) -> ck_borrowing_type(RT) ; T1 = rref(_, RT) -> ck_borrowing_type(RT) ; ck_borrowing_type(T1) ).
ck_flow_value(addr(E), Ps, J) :- !, ck_flow_name(E, N), ck_param_pos(Ps, N, 1, J), ck_param_type(Ps, J, T), catch(ccl_resolve_type(T, T1), _, fail), ( T1 = ref(_, _) ; T1 = rref(_, _) ; T1 = ptr(_, _), ck_flow_pointee(E) ), !.
ck_flow_value(bin(Op, X, Y), Ps, J) :- memberchk(Op, ['+', '-']), !, ( ck_flow_value(X, Ps, J), \+ ck_flow_ptr_operand(Y, Ps) ; Op == '+', ck_flow_value(Y, Ps, J), \+ ck_flow_ptr_operand(X, Ps) ).   % a pointer moved by an INTEGER: `b - a' of two pointers is a number, which borrows nothing (0.221: `n = (int) (b - a)' made a flow of b into *this)
ck_flow_value(cast(_, X), Ps, J) :- !, ck_flow_value(X, Ps, J).
ck_flow_value(ccast(_, _, X), Ps, J) :- !, ck_flow_value(X, Ps, J).
ck_flow_value(move(X), Ps, J) :- !, ck_flow_value(X, Ps, J).
ck_flow_value(call(id(G), [X]), Ps, J) :- atom(G), catch(cpp_library_function(G), _, fail), \+ ck_lib_member(G), !, ck_flow_value(X, Ps, J).
ck_flow_value(S, Ps, J) :- ck_il_items(S, Items), member(item(_, V), Items), ck_flow_value(V, Ps, J).
%% an operand of pointer type: a parameter's by the parameter list, else as the inference types it
ck_flow_ptr_operand(id(N), Ps) :- ck_param_pos(Ps, N, 1, J), ck_param_type(Ps, J, T), catch(ccl_resolve_type(T, T1), _, fail), ( T1 = ptr(_, _) ; T1 = arr(_, _) ), !.
ck_flow_ptr_operand(E, _) :- ck_pointer_arg(E).
%% a place reached through the pointer, not the pointer's own variable: `p->f', `p[i]', `*p', a member of one
ck_flow_pointee(arrow(_, _)).
ck_flow_pointee(index(_, _)).
ck_flow_pointee(deref(_)).
ck_flow_pointee(member(E, _)) :- ck_flow_pointee(E).
ck_sub_term(T, T).
ck_sub_term(X, T) :- compound(T), T =.. [_|As], member(A, As), ck_sub_term(X, A).
%% a call of a function with flows: the holder's object takes the stored argument's borrow, as a library member's would
ck_flow_store(F, Args, St0, St) :- atom(F), nb_current('$ck_flows', [_|_]), nb_getval('$ck_flows', Fl), findall(J-I, member(flow(F, J, I), Fl), JIs), JIs \== [],
    catch(ccl_declared(F, fn(_, Ps, _)), _, fail), !, ck_flow_apply(JIs, F, Args, Ps, St0, St).
ck_flow_store(_, _, St, St).
ck_flow_apply([], _, _, _, St, St).
ck_flow_apply([J-out(_)|T], F, Args, Ps, St0, St) :- !,   % stored where it outlives the caller: a borrow of the caller's local may not go
    (   ccl_nth(J, Args, AJ), ck_param_type(Ps, J, PJ), ck_flow_borrow(AJ, PJ, St0, P), ck_short_lived(P) -> ck_fail(borrow_stored, P, call(id(F), Args))
    ;   true ),
    ck_flow_apply(T, F, Args, Ps, St0, St).
ck_flow_apply([J-I|T], F, Args, Ps, St0, St) :-
    (   ccl_nth(J, Args, AJ), ccl_nth(I, Args, AI), ck_param_type(Ps, I, PT), ck_flow_holder(AI, PT, Obj), ck_param_type(Ps, J, PJ),
        ck_flow_borrow(AJ, PJ, St0, P)
    ->  ck_lib_store_into(Obj, P, join, call(id(F), Args), St0, St1)
    ;   St1 = St0 ),
    ck_flow_apply(T, F, Args, Ps, St1, St).
ck_flow_holder(addr(O), _, O) :- !.
ck_flow_holder(A, PT, A) :- catch(ccl_resolve_type(PT, PT1), _, fail), ( PT1 = ref(_, _) ; PT1 = rref(_, _) ), !.
ck_flow_holder(id(P), _, deref(id(P))) :- atom(P).
ck_param_type(Ps, I, T) :- ccl_nth(I, Ps, P), ( P = param(T, _) ; P = param(T, _, _) ), !.
%% the borrow an argument hands: an object bound to a reference parameter is borrowed whole -- a local's own storage, a
%% reference's referent --, any other argument as a library member's is (ck_lib_handed/4)
ck_flow_borrow(A, PT, St, P) :- catch(ccl_resolve_type(PT, PT1), _, fail), ( PT1 = ref(_, _) ; PT1 = rref(_, _) ), A \= addr(_), !,
    ( ck_storage_base(A, N), atom(N), \+ ck_is_ref(N), ck_is_local(N) -> P = N ; ck_lib_handed([addr(A)], none, St, P) ).
ck_flow_borrow(A, _, St, P) :- ck_lib_handed([A], none, St, P).
%% A FREE LIBRARY FUNCTION THAT STORES (0.217), known by its template's name (an instance is the name, then a key per
%% argument): `std::swap(a, b)' and `std::exchange(o, n)' give each object what the other held; `std::fill', `fill_n',
%% `replace', `replace_if' and `uninitialized_fill' put their value's borrow in the container of the range; `std::copy'
%% and its kin put what the source ranges' containers hold in the destination's -- the container an iterator borrows
%% (`v.begin()', `std::back_inserter(dst)', an array). `std::swap(a, b)' over a vector holding `&x' and another returned,
%% `std::fill(v.begin(), v.end(), &x)' and a copy into a back inserter stored nothing until 0.217
ck_lib_free_store(F, Args, St0, St) :- ccl_lang(cpp), atom(F), cpp_library_function(F), \+ ck_lib_member(F), ck_lib_base_name(F, B), ck_lib_free_kind(B, Args, K), !,
    ck_lib_free_apply(K, call(id(F), Args), Args, St0, St).
ck_lib_free_store(_, _, St, St).
ck_lib_base_name(F, B) :- ( sub_atom(F, Bf, _, _, '.') -> sub_atom(F, 0, Bf, _, B) ; B = F ).
ck_lib_free_kind(swap, [_, _], swap) :- !.
ck_lib_free_kind(exchange, [_, _], exchange) :- !.
ck_lib_free_kind(B, Args, value) :- memberchk(B, [fill, fill_n, replace, replace_if, uninitialized_fill, uninitialized_fill_n]), length(Args, N), N >= 3, !.
ck_lib_free_kind(B, Args, copy(O)) :- ck_lib_copy_out(B, O), length(Args, N), N >= O, !.
ck_lib_copy_out(B, 3) :- memberchk(B, [copy, copy_n, copy_if, copy_backward, move, move_backward, reverse_copy, unique_copy, replace_copy, replace_copy_if,
    remove_copy, remove_copy_if, uninitialized_copy, uninitialized_copy_n, uninitialized_move, uninitialized_move_n]), !.
ck_lib_copy_out(rotate_copy, 4) :- !.
ck_lib_copy_out(B, 5) :- memberchk(B, [merge, set_union, set_intersection, set_difference, set_symmetric_difference]).
ck_lib_free_apply(swap, Form, [A, B], St0, St) :- ck_lib_ref_obj(A, OA), ck_lib_ref_obj(B, OB),
    ( ck_lib_value_borrow(OA, St0, PA) -> HA = yes(PA) ; HA = no ), ( ck_lib_value_borrow(OB, St0, PB) -> HB = yes(PB) ; HB = no ),
    ck_lib_take(OA, HB, Form, St0, St1), ck_lib_take(OB, HA, Form, St1, St).
ck_lib_free_apply(exchange, Form, [A, B], St0, St) :- ck_lib_ref_obj(A, OA), ( ck_lib_value_borrow(B, St0, PB) -> HB = yes(PB) ; HB = no ), ck_lib_take(OA, HB, Form, St0, St).
ck_lib_free_apply(value, Form, [First|Rest], St0, St) :- last(Rest, V),
    ( ck_lib_container_of(First, St0, C), ck_lib_handed([V], none, St0, P) -> ck_lib_store_into(C, P, join, Form, St0, St) ; St = St0 ).
ck_lib_free_apply(copy(O), Form, Args, St0, St) :- ccl_nth(O, Args, Out),
    (   ck_lib_container_of(Out, St0, D), O1 is O - 1, length(Pre, O1), append(Pre, _, Args),
        findall(P, ( member(A, Pre), ck_lib_container_of(A, St0, C), C \== D, ck_lib_value_borrow(C, St0, P) ), Ps), Ps = [_|_]
    ->  ck_first_of(Ps, P1), ck_lib_store_into(D, P1, join, Form, St0, St)
    ;   St = St0 ).
ck_lib_ref_obj(addr(O), O) :- !.
ck_lib_ref_obj(O, O).
%% what an object's value carries: a holder's held borrow, a pointer's or a view's own
ck_lib_value_borrow(O, St, P) :- ck_borrows_from(O, St, P), atom(P).
ck_lib_take(O, yes(P), Form, St0, St) :- !, ck_lib_store_into(O, P, replace, Form, St0, St).
ck_lib_take(O, no, _, St0, St) :- ( ck_where(O, St0, local(E1)) -> ck_unhold(E1, St0, St) ; St = St0 ).
%% the container an iterator or a range's start lies in, as a place: the object of a member's (`v.begin()'), the object a
%% free function takes by reference (`std::back_inserter(dst)', `std::begin(v)'), an array, and what an iterator or a
%% pointer local borrows
ck_lib_container_of(call(id(G), [addr(E)|_]), _, E) :- atom(G), cpp_library_function(G), ck_lib_member(G), !.
ck_lib_container_of(call(id(G), Args), _, Pl) :- atom(G), cpp_library_function(G), \+ ck_lib_member(G), catch(ccl_declared(G, fn(_, Ps, _)), _, fail), ck_ref_object(Args, Ps, E), !, ck_lib_ref_obj(E, Pl).
ck_lib_container_of(bin(Op, X, _), St, Pl) :- memberchk(Op, ['+', '-']), !, ck_lib_container_of(X, St, Pl).
ck_lib_container_of(cast(_, X), St, Pl) :- !, ck_lib_container_of(X, St, Pl).
ck_lib_container_of(id(N), St, Pl) :- atom(N), ( ck_local_type(N, T), catch(ccl_resolve_type(T, arr(_, _)), _, fail) -> Pl = id(N)
    ; ck_state(St, N, borrow(C)), atom(C), ( ck_local_type(C, CT), ck_is_pointer_type(CT) -> Pl = deref(id(C)) ; Pl = id(C) ) ).
%% ---- what a local's storage holds (0.217) ----
%% THE BORROWS A LOCAL'S STORAGE HOLDS ARE KEYS UNDER IT: a pointer's, a pointer member's or a view's own path (`q', `s.p',
%% `s.sv'), and `$held' below a library container or an array for what it or its elements hold (`v.$held', `s.v.$held',
%% `a.$held'). A holder's own key stays its storage's, so `&s', `v.begin()' and a reference bound to v borrow the local
%% itself and dangle when it ends; what it holds dangles when the held local ends (ck_dangle/3), and a read of the holder
%% after is `borrow_after_move' (ck_held_read/2). Until 0.217 a library object's own state took the borrow, so an
%% iterator into `std::vector<int *> v{&x}' borrowed x and outlived v unseen, and a struct's member kept a local's address
%% with no state at all
ck_hold_place(E1, P, Mode0, St0, St) :- ck_held_key(E1, K, KMode), ck_root(E1, R, _), !, ( Mode0 == default -> Mode = KMode ; Mode = Mode0 ), ck_hold_key(R, K, Mode, P, St0, St).
ck_hold_place(_, _, _, St, St).
ck_hold_key(R, K, Mode, P, St0, St) :-
    (   ck_state(St0, K, S0) -> ( Mode == join -> ck_lib_more(S0, P, S) ; S = borrow(P) ), ck_set(St0, K, S, St)
    ;   ck_declare_under(St0, R, K, borrow(P), St) ),
    ( K == R -> true ; ck_note_holder(R) ).
ck_declare_under(st(Frs), R, K, S, st(Frs1)) :- ccl_locals(Ls), ( ck_frame_index(Ls, R, 0, I) -> true ; length(Ls, I) ), ck_insert_at(Frs, I, K-S, Frs1).
%% a place given nothing a borrow names: what it held is let go -- a path's key and a pointer hold nothing, a view's own key
%% is its storage again
ck_unhold(E1, St0, St) :- ck_held_key(E1, K, _), ck_root(E1, R, _), ck_state(St0, K, S0), ( S0 = borrow(_) ; S0 = dangling(_) ), !,
    ( K == R, \+ ( ck_local_type(R, T), ck_is_pointer_type(T) ) -> S = anchor ; S = none ), ck_set(St0, K, S, St).
ck_unhold(_, St, St).
%% the key a place's held borrow is under, and how a store joins it: a pointer's or a view's own key is replaced, a holder's
%% `$held' joined
ck_held_key(E, K, replace) :- ck_path(E, K), ck_holds_itself(E), !.
ck_held_key(E, K, join) :- ck_path(E, K0), !, atom_concat(K0, '.$held', K).
ck_held_key(index(E, _), K, join) :- ck_held_key_array(E, K).
ck_held_key_array(E, K) :- ck_path(E, K0), !, atom_concat(K0, '.$held', K).
ck_held_key_array(index(E, _), K) :- ck_held_key_array(E, K).
ck_holds_itself(E) :- ck_lib_obj_type(E, T), ( ck_is_pointer_type(T) -> true ; ck_value_like(T) ).
%% a value that is a reference to what it borrows, never a holder of it: a closure, a library view, an iterator, a range
%% adaptor -- its own state is the borrow, as a pointer's is
ck_value_like(T) :- ccl_lang(cpp), ( ck_closure_type(T) -> true ; catch(ccl_resolve_type(T, base(_, [struct(N, _)])), _, fail), atom(N), ck_library_class(N),
    catch('$cpp_inst'(N, inst(Tm, _)), _, fail), atom(Tm), ( ck_lib_view(Tm) -> true ; sub_atom(Tm, _, _, _, iter) -> true ; sub_atom(Tm, _, _, _, '_view') -> true ; Tm == subrange ) ).
ck_note_holder(R) :- ( nb_current('$ck_holders', Hs) -> true ; Hs = [] ), ( memberchk(R, Hs) -> true ; nb_setval('$ck_holders', [R|Hs]) ).
ck_holder(R) :- nb_current('$ck_holders', Hs), Hs \== [], memberchk(R, Hs).
%% what a holder's storage holds, the borrow that can dangle first
ck_held_borrow(St, N, P) :- ck_under_states(St, N, Ps), findall(P0, ( member(_-S, Ps), ( S = borrow(P0) ; S = dangling(P0) ) ), Bs), Bs = [_|_], ck_first_of(Bs, P).
%% a holder read whole -- copied, handed on, returned, a library member called on it -- reads what it holds: a dangling
%% borrow under it is `borrow_after_move'; a member read reads what that member holds, not its siblings
ck_held_read(St, K) :- ( nb_current('$ck_holders', [_|_]), ck_key_root(K, R), ck_holder(R), ck_under_states(St, K, Ps), member(HK-dangling(P), Ps) -> ck_held_name(HK, N), ck_fail(borrow_after_move, N, borrowed_from(P)) ; true ).
ck_held_name(HK, N) :- ( atom_concat(N0, '.$held', HK) -> N = N0 ; N = HK ).   % a holder's `$held' is named by the holder
ck_key_root(K, R) :- atom(K), findall(B, ( sub_atom(K, B, _, _, '.') ; sub_atom(K, B, _, _, '->') ), Bs), ( sort(Bs, [B0|_]) -> sub_atom(K, 0, B0, _, R) ; R = K ).
ck_call_tie(call(F, Args), St, P) :-
    ck_callee_sig(F, fn(R, Ps, _)), ccl_tie_of(R, Y),
    (   ck_param_index(Ps, Y, 1, I) -> ccl_nth(I, Args, A0), ( ccl_nth(I, Ps, param(PT, _)), ( PT = ref(_, _) ; PT = rref(_, _) ) -> A = addr(A0) ; A = A0 ), ck_borrows_from(A, St, P)   % a result tied to a REFERENCE parameter borrows the object the reference binds, its argument (0.202): `void *operator new(std::size_t, Arena &a) tie a' over `new (ar) S' borrows `ar'
    ;   P = static(Y) ).
ck_param_index([param(_, Y)|_], Y, I, I) :- !.
ck_param_index([_|Ps], Y, I0, I) :- I1 is I0 + 1, ck_param_index(Ps, Y, I1, I).
ck_callee_sig(id(F), Sig) :- ccl_declared(F, T), !, ck_fn_sig(T, Sig).
ck_callee_sig(F, Sig) :- ccl_type_of(F, T), T \== unknown, ck_fn_sig(T, Sig).
ck_fn_sig(T, Sig) :- ccl_resolve_type(T, T1), ( T1 = fn(_, _, _) -> Sig = T1 ; T1 = ptr(_, FT), ccl_resolve_type(FT, Sig), Sig = fn(_, _, _) ).
ck_borrow_source(K, S, P) :- ( ck_owner_state(S) -> P = K ; memberchk(S, [anchor, loose, array]) -> P = K ; S = borrow(P) -> true ; S = dangling(P) ).
%% a return: a tied owner only within the result's tie; a borrow of a parameter
%% or a global may leave, and with a result tie only what lies within it
ck_no_escape(cond(_, A, B), St) :- !, ck_no_escape(A, St), ck_no_escape(B, St).           % c ? a : b returns either
ck_no_escape(comma(_, B), St) :- !, ck_no_escape(B, St).
ck_no_escape(E, St) :-
    nb_getval('$ck_ret_tie', RT),
    (   nb_getval('$ck_ret', Ret), ck_ref_as_ptr(Ret, RP), RP \== Ret                 % C++: a reference result is a pointer out
    ->  (   E = id(N), ck_is_ref(N) -> ( ck_state(St, N, borrow(P)) -> ck_ret_borrow(St, P, RT, N, borrowed_from(P)) ; true )
        ;   ck_lvalue_form(E), ck_storage_base(E, B), ck_is_local(B), \+ ck_is_ref(B), ( ck_is_param(B) -> ck_param_storage(B) ; true ) -> ck_fail(borrow_escapes, B, reference_to_local(E))   % a parameter by value too (0.217): `int &f(int n) { return n; }'
        ;   true )
    ;   E = id(N), ck_is_ref(N) -> true                                                % a value out of the referent
    ;   ck_owner_path(St, E, K) -> ( ck_tied_to(K, R) -> ck_ret_tied(St, R, RT, K, E) ; true )
    ;   E = id(N), ck_state(St, N, dangling(P)) -> ck_fail(borrow_after_move, N, borrowed_from(P))
    ;   E = id(N), ck_state(St, N, borrow(P)) -> ( ck_local_type(N, T), ck_borrowing_type(T) -> ck_ret_borrow(St, P, RT, N, borrowed_from(P)) ; true )
    ;   ccl_type_of(E, T), ck_borrowing_type(T), ck_borrows_from(E, St, P) -> ck_ret_borrow(St, P, RT, P, E)
    ;   true ).
ck_ret_borrow(St, P, RT, N, Form) :-
    (   ck_state(St, P, loose) -> true                                  % the caller takes the memory over
    ;   P = static(_) -> true
    ;   RT \== none -> ( ck_within(St, RT, P) -> true ; ck_fail(tie_mismatch, N, Form) )
    ;   ( ck_is_param(P), \+ ck_param_storage(P) ; ck_is_global(P) ) -> true
    ;   ck_fail(borrow_escapes, N, Form) ).
ck_ret_tied(St, R, RT, K, Form) :- ( RT \== none, ck_within(St, RT, R) -> true ; ck_fail(tie_escapes, K, Form) ).
ck_pop(st([_|Frs]), st(Frs)).
ck_defer(st([fr(Os, Ds)|Frs]), Body, st([fr(Os, [Body|Ds])|Frs])).

%% a join: the same owner in the same state on both sides keeps it; null beside
%% live is live (one path holds memory), null or unset beside moved is moved,
%% unset beside null is unset (garbage on one path); anything else is partial
ck_merge(dead, S, S) :- !.
ck_merge(S, dead, S) :- !.
ck_merge(st(A), st(B), st(C)) :- ck_merge_frames(A, B, C).
ck_merge_frames([], [], []).
ck_merge_frames([fr(Oa, D)|As], [fr(Ob, _)|Bs], [fr(Oc, D)|Cs]) :- ck_merge_owners(Oa, Ob, Oc0), ck_only_in(Ob, Oa, Extra), append(Oc0, Extra, Oc), ck_merge_frames(As, Bs, Cs).
%% A KEY ONE SIDE MADE IN AN OUTER FRAME IS KEPT (0.217): what a local holds is declared where the local is, from inside a
%% branch or a loop's body (ck_declare_under/5), and the join that took one side's keys alone lost it -- `for (auto &row
%% : g) row.push_back(&b); return g;' was accepted
ck_only_in([], _, []).
ck_only_in([K-S|T], Oa, E) :- ( memberchk(K-_, Oa) -> E = E1 ; E = [K-S|E1] ), ck_only_in(T, Oa, E1).
ck_merge_owners([], _, []).
ck_merge_owners([N-Sa|T], Ob, [N-Sc|T1]) :- ( memberchk(N-Sb, Ob) -> ck_merge_state(Sa, Sb, Sc) ; Sc = Sa ), ck_merge_owners(T, Ob, T1).
ck_merge_state(S, S, S) :- !.
ck_merge_state(dangling(P), _, dangling(P)) :- !.
ck_merge_state(_, dangling(P), dangling(P)) :- !.
ck_merge_state(borrow(P), borrow(Q), borrow(R)) :- !, ck_first_to_dangle(P, Q, R).   % of two borrows, the one that can dangle first (0.216, 0.217)
ck_merge_state(loose, borrow(P), borrow(P)) :- !.                   % fresh memory on one path, a borrow on the other: the borrow is what can dangle
ck_merge_state(borrow(P), loose, borrow(P)) :- !.
ck_merge_state(anchor, borrow(P), borrow(P)) :- !.                  % a library object anchored on one path, holding a borrow on the other (0.216)
ck_merge_state(borrow(P), anchor, borrow(P)) :- !.
ck_merge_state(none, S, S) :- !.                    % a plain pointer, bound on one side only: bound
ck_merge_state(S, none, S) :- !.
ck_merge_state(null, live, live) :- !.
ck_merge_state(live, null, live) :- !.
ck_merge_state(null, moved, moved) :- !.
ck_merge_state(moved, null, moved) :- !.
ck_merge_state(unset, moved, moved) :- !.
ck_merge_state(moved, unset, moved) :- !.
ck_merge_state(unset, null, unset) :- !.
ck_merge_state(null, unset, unset) :- !.
ck_merge_state(_, _, partial).

%% ---- statements: ck_stmt(+S, +St0, -St), St dead when the path ends here --------------
ck_stmt(S, dead, dead) :- S \= label(_, _, _), !.   % dead code is not walked -- but a LABEL is, the gotos to it may bring a state (0.133)
ck_stmt(block(Is), St0, St) :- !, ccl_scope_push, ck_bpath_push, ck_push(St0, St1), ck_stmts(Is, St1, St2), ck_scope_end(St2, St), ck_bpath_pop, ccl_scope_pop.
ck_stmt('$splice'(Is), St0, St) :- !, ck_stmts(Is, St0, St).
ck_stmt(declaration(L, Sto, Base, Vs), St0, St) :- !, ck_line(L), ( Sto == static -> ck_note_statics(Vs) ; true ), ck_decls(Vs, St0, St), ccl_note_block_constants(Base, Vs).   % a C23 `constexpr' local is a constant of its block (0.195)
ck_stmt(typedef(_, _), St, St) :- !.
ck_stmt(declare(_, _), St, St) :- !.
ck_stmt(directive(_, _), St, St) :- !.
ck_stmt(include(_, _, _), St, St) :- !.
ck_stmt(static_assert(_, _, _), St, St) :- !.
ck_stmt(expr(_, bind_ref(_, E)), St0, St) :- !, ck_expr(E, St0, St).   % a REFERENCE MEMBER BOUND: the object outlives its holder, as a reference capture's does -- the safe part follows neither
ck_stmt(empty, St, St) :- !.
ck_stmt(expr(L, E), St0, St) :- !, ck_line(L), ck_anchor_addrs(E, St0, St1), ck_expr(E, St1, St).
ck_stmt(defer(L, _, Body), St0, St) :- !, ck_line(L), ck_defer(St0, Body, St).
ck_stmt(eh_cleanup(_, _), St, St) :- !.   % a constructor's cleanup of what it built, run only while an exception unwinds (0.201): the check follows no unwinding path
ck_stmt(eh_drop(_, _), St, St) :- !.   % ... and a statement's temporary's, dropped at its end (0.207)
ck_stmt(ifce(_, _, RT), St0, St) :- !, ck_stmt(RT, St0, St).                                % `if consteval': the run-time branch (0.108)
%% a try (0.108): the body, then each handler from the state the try began in (what the body did before it threw is
%% not known there), the states merged
%% A HANDLER IS ENTERED FROM ANY POINT OF ITS TRY'S BODY where a call may throw (0.193: libc++'s calls throw now), so it
%% starts from the join of the body's entry, its exit and the state before each statement of the body, each cut to the
%% try's own frames (ck_try_body/4, ck_try_note/1): an owner the body consumed is `partial' there, refused on use and a
%% leak, where the handler took it as the entry's and freed it again. A terminate handler (a noexcept function's guard,
%% cpp_nx_wrap) ends the path, and asks no record.
ck_stmt(try(L, Body, Catches), St0, St) :- !, ck_line(L),
    ( Catches = [catch(terminate, _)] -> ck_stmt(Body, St0, StB), StH = St0 ; ck_try_body(Body, St0, StB, StH) ),
    ck_catches(Catches, StH, StB, St).
ck_stmt(if(L, C, T, E), St0, St) :- !, ck_line(L),
    ck_expr(C, St0, St1), ck_refine(C, St1, StThen, StElse),
    ck_stmt(T, StThen, StT), ( E == none -> StE = StElse ; ck_stmt(E, StElse, StE) ), ck_merge(StT, StE, St).
ck_stmt(while(L, C, S), St0, St) :- !, ck_line(L), ck_expr(C, St0, St1), ck_loop(S, St1, St2), ck_expr(C, St2, St).
ck_stmt(do(L, S, C), St0, St) :- !, ck_line(L), ck_loop(S, St0, St1), ck_expr(C, St1, St).
ck_stmt(for_each(L, D, R, S), St0, St) :- !, ck_line(L),                        % C++: a range-for over an array is the for it stands for
    ( ccl_for_each_as_for(for_each(L, D, R, S), For) -> ck_stmt(For, St0, St) ; ck_fail(not_checked, range_for, for_each(L, D, R, S)) ).
ck_stmt(using(_, _), St, St) :- !.
ck_stmt(for(L, Init, C, Step, S), St0, St) :- !, ck_line(L),
    ccl_scope_push, ck_bpath_push, ck_push(St0, St1),
    ( Init = decl(_, Vs) -> ck_decls(Vs, St1, St2) ; Init == none -> St2 = St1 ; ck_anchor_addrs(Init, St1, St1a), ck_expr(Init, St1a, St2) ),
    ( C == none -> St3 = St2 ; ck_expr(C, St2, St3) ),
    ck_loop_with_step(S, Step, St3, St4),
    ck_scope_end(St4, St), ck_bpath_pop, ccl_scope_pop.
ck_stmt(return(L), St0, dead) :- !, ck_line(L), ck_exit_all(St0, return).
%% a coroutine's skeleton (0.108): co_return leaves every scope as a return does; the promise, the frame and the
%% suspensions are the lowering's, their expressions read as any
ck_stmt(coro_begin(L, _, _, _), St, St) :- !, ck_line(L).
ck_stmt(coro_ret(L, E), St0, St) :- !, ck_line(L), ck_expr(E, St0, St).
ck_stmt(coro_body(_, S), St0, St) :- !, ck_stmt(S, St0, St).
ck_stmt(coro_return(L), St0, dead) :- !, ck_line(L), ck_exit_all(St0, return).
ck_stmt(coro_suspend(L, _, E, _), St0, St) :- !, ck_line(L), ck_expr(E, St0, St).
ck_stmt(coro_done(L, _), _, dead) :- !, ck_line(L).
ck_stmt(return(L, move(E)), St0, St) :- nb_getval('$ck_ret', Ret), ck_ref_as_ptr(Ret, RP), RP \== Ret, !, ck_stmt(return(L, E), St0, St).   % `return std::move(x);' WITH A REFERENCE RESULT IS A CAST ([expr.static.cast]; 0.132): `T &&' bound to x, which stays the caller's -- nothing moves, and the reference leaves as any other does (a parameter's referent, never a local's); it was refused `move_of_non_owner' for a reference parameter
ck_stmt(return(L, E), St0, dead) :- !, ck_line(L), ck_anchor_addrs(E, St0, St1), ck_no_escape(E, St1), ck_consume_or_use(E, St1, St2), ck_exit_all(St2, return(E)).
ck_stmt(break(L), St0, dead) :- !, ck_line(L), ck_exit_to_loop(St0, break).
ck_stmt(continue(L), St0, dead) :- !, ck_line(L), ck_exit_to_loop(St0, continue).
ck_stmt(goto(Ln, L), St, dead) :- !, ck_line(Ln), ck_goto(L, Ln, St).
ck_stmt(label(Ln, L, S), St0, St) :- !, ck_label_in(L, Ln, St0, StL), ck_stmt(S, StL, St).
ck_stmt(switch(L, E, S), St0, St) :- !, ck_line(L),
    ck_expr(E, St0, St1),
    ( S = block(Is) -> true ; Is = [S] ),
    ccl_scope_push, ck_bpath_push, ck_push(St1, St2), ck_loop_enter(St2, switch), ck_switch_items(Is, St2, St2, St3), ck_loop_leave(Brk),
    ck_merge_all([St3|Brk], St4), ( ck_has_default(Is) -> St5 = St4 ; ck_merge(St4, St2, St5) ),
    ck_scope_end(St5, St), ck_bpath_pop, ccl_scope_pop.
ck_stmt(assume(L, E), St0, St) :- !, ck_line(L), ck_expr(E, St0, St).   % C++23's [[assume(e)]]: its expression is read, nothing else
ck_stmt(case(_, _, S), St0, St) :- !, ck_stmt(S, St0, St).
ck_stmt(default(_, S), St0, St) :- !, ck_stmt(S, St0, St).
%% GNU'S ASM STATEMENT (0.215): its inputs are read and its outputs written, as an expression's operands are; an output
%% whose value carries a pointer (ck_carries_type/1: a pointer, an array of them, a struct holding one) is refused by
%% name, since the safe part follows no pointer that an asm makes. `asm goto''s labels (0.231) are each a `goto''s edge,
%% the state after the outputs brought to the label, and the state falls through to the next statement too
ck_stmt(gnu_asm(L, basic(_)), St, St) :- !, ck_line(L).
ck_stmt(gnu_asm(L, ext(_, _, Os, Is, _, Ls)), St0, St) :- !, ck_line(L), ck_asm_ops(Is, St0, St1), ck_asm_outs(Os), ck_asm_ops(Os, St1, St),
    ck_asm_gotos(Ls, L, St).   % `asm goto' (0.231): an edge to each of its labels, as a `goto' makes, and the state falls through too
ck_stmt(S, _, _) :- functor(S, F, _), nb_getval('$ck_fn', Fn), nb_getval('$ck_line', L), throw(error(not_lowered(F), where(Fn, line(L)))).   % a form of C++'s later steps
ck_asm_ops([], St, St).
ck_asm_ops([op(_, _, E)|Os], St0, St) :- ck_expr(E, St0, St1), ck_asm_ops(Os, St1, St).
ck_asm_outs([]).
ck_asm_outs([op(_, _, E)|Os]) :-
    (   catch(ccl_type_of(E, T), _, fail), T \== unknown, catch(ck_carries_type(T), _, fail)
    ->  nb_getval('$ck_fn', Fn), nb_getval('$ck_line', L), throw(error(not_lowered(asm_pointer_output), where(Fn, line(L))))
    ;   ck_asm_outs(Os) ).
ck_asm_gotos([], _, _).
ck_asm_gotos([Lb|Ls], L, St) :- ck_goto(Lb, L, St), ck_asm_gotos(Ls, L, St).
ck_catches([], _, St, St).
ck_catches([catch(K, B)|Cs], St0, Acc, St) :- ( K == any ; K == terminate ), !, ck_stmt(B, St0, S1), ck_merge(Acc, S1, Acc1), ck_catches(Cs, St0, Acc1, St).
%% A HANDLER'S PARAMETER HAS A FRAME OF ITS OWN, in the state as in the symbol table (0.201): the two are pushed together,
%% and a defer of a frame outside the handler that an exit from inside it runs -- a `return' in the handler over a local's
%% destructor -- names its local by the symbol table's frame, which the state did not have: the check failed with no word.
ck_catches([catch(_, T, N, B)|Cs], St0, Acc, St) :- ccl_scope_push, ck_bpath_push, ( St0 = st(_) -> ck_push(St0, St0a) ; St0a = St0 ), ( N == anon -> true ; ccl_declare(N, T) ),
    ck_stmt(B, St0a, S0), ( St0 = st(_) -> ck_scope_end(S0, S1) ; S1 = S0 ), ck_bpath_pop, ccl_scope_pop, ck_merge(Acc, S1, Acc1), ck_catches(Cs, St0, Acc1, St).
%% a null test on an owner refines it: `if (!p)', `if (p == NULL)' make p null
%% on the then path, `if (p)', `if (p != NULL)' on the else path -- and its
%% own fields with it, there being nothing behind a null
ck_refine(C, St, StThen, StElse) :-
    (   ck_null_test(C, E, Sense) -> ( Sense == null -> ck_set_null(E, St, StThen), StElse = St ; StThen = St, ck_set_null(E, St, StElse) )
    ;   StThen = St, StElse = St ).
ck_null_test(not(E), E, null) :- !.
ck_null_test(bin('==', E, N), E, null) :- ck_null(N), !.
ck_null_test(bin('==', N, E), E, null) :- ck_null(N), !.
ck_null_test(bin('!=', E, N), E, live) :- ck_null(N), !.
ck_null_test(bin('!=', N, E), E, live) :- ck_null(N), !.
ck_null_test(E, E, live) :- ( E = id(_) ; E = member(_, _) ; E = arrow(_, _) ), !.
ck_set_null(E, St0, St) :-
    (   ck_path(E, K), ck_state(St0, K, S), memberchk(S, [live, partial]) -> ck_own_under(St0, K, Ks), ck_set_all(St0, [K|Ks], null, St)
    ;   St = St0 ).
ck_stmts([], St, St).
ck_stmts([S|Ss], St0, St) :- ck_try_note(St0), ck_stmt(S, St0, St1), ck_stmts(Ss, St1, St).
%% the states a try's handlers may be entered from: one record a try open, `t(Depth, States)' in `'$ck_trys'', each state
%% before a statement of its body cut to the try's frames (a state is st(Frames), the innermost frame first)
ck_try_body(Body, St0, StB, St0) :- St0 \= st(_), !, ck_stmt(Body, St0, StB).   % a try on an ended path
ck_try_body(Body, St0, StB, StH) :- St0 = st(Fs0), length(Fs0, D), nb_getval('$ck_trys', Ts0), nb_setval('$ck_trys', [t(D, [])|Ts0]),
    (   catch(ck_stmt(Body, St0, StB), E, ( nb_setval('$ck_trys', Ts0), throw(E) ))
    ->  nb_getval('$ck_trys', [t(_, Rec)|_]), nb_setval('$ck_trys', Ts0), ck_merge_all([St0, StB|Rec], StH)
    ;   nb_setval('$ck_trys', Ts0), fail ).
ck_try_note(st(Fs)) :- nb_current('$ck_trys', [_|_]), !, nb_getval('$ck_trys', Ts0), length(Fs, N), ck_try_note_(Ts0, Fs, N, Ts), nb_setval('$ck_trys', Ts).
ck_try_note(_).
ck_try_note_([], _, _, []).
ck_try_note_([t(D, R)|Ts], Fs, N, [t(D, R1)|Ts1]) :- K is N - D, ( K >= 0, length(Pre, K), append(Pre, P, Fs) -> R1 = [st(P)|R] ; R1 = R ), ck_try_note_(Ts, Fs, N, Ts1).

ck_switch_items([], _, St, St).
ck_switch_items([case(_, E, S)|Is], Entry, St0, St) :- !, ck_merge(St0, Entry, St1), ck_switch_items([S|Is], Entry, St1, St).
ck_switch_items([default(_, S)|Is], Entry, St0, St) :- !, ck_merge(St0, Entry, St1), ck_switch_items([S|Is], Entry, St1, St).
ck_switch_items([S|Is], Entry, St0, St) :- ck_stmt(S, St0, St1), ck_switch_items(Is, Entry, St1, St).
ck_has_default(Is) :- member(default(_, _), Is), !.
ck_has_default(Is) :- member(case(_, _, S), Is), ck_has_default([S]), !.

%% ---- declarations -----------------------------------------------------------------------
%% every local joins the symbol table (the types of paths come from it); an own
%% pointer is an owner from here, unset until given something, its own fields
%% unset too; a struct by value with own fields owns them; the tied fields are
%% declared with them; then the variable's own tie; a plain pointer given an
%% owner's value is a borrow, given a value with no owner behind it a warning
ck_decls([], St, St).
ck_decls([var(N, T0, Init0)|Vs], St0, St) :-
    ck_ref_decl(N, T0, Init0, T, Init),
    ccl_declare(N, T), ck_note_arrlocal(N, T), ck_type_rules(N, T, var(N, Init)),
    ck_var_fields(N, T, Fs), ck_states(Fs, unset, FOs),
    ck_declare_all(St0, FOs, St1), ck_field_ties(N, T, St1, St2, Ts), ck_anchor_addrs(Init, St2, St3),
    (   ck_own_array_type(T)
    ->  ck_note_array(N),
        ( Init = init(Items) -> ck_declare(St3, N, array, St5), ck_init_slots(Items, T, N, St5, St6) ; ck_fail(array_unset, N, var(N, Init)) )
    ;   ck_own_type(T), ck_is_pointer_type(T)
    ->  ck_declare(St3, N, unset, St4), ck_var_tie(N, T, St4, St5),
        ( Init == none -> St6 = St5 ; ck_into_own(N, Init, var(N, Init), St5, St6, _) )
    ;   ( Fs \== [] ; Ts \== [] )
    ->  ck_var_tie(N, T, St3, St5), ( Init == none -> St6 = St5 ; ck_fill(N, T, Init, var(N, Init), St5, St6) )
    ;   ck_var_tie(N, T, St3, St5),
        (   Init == none -> St6 = St5
        ;   Init = init(Items) -> ck_init_slots(Items, T, N, St5, St6)
        ;   ck_expr(Init, St5, St5a),
            (   ck_borrowing_type(T), ck_borrows_from(Init, St5a, P) -> ck_bind_var(N, P, var(N, Init), St5a, St6)   % a closure of a reference capture is a borrow of the captured local (0.100)
            ;   ck_is_pointer_type(T), Init = id(P), ck_plain_copy(St5a, P) -> ck_declare(St5a, N, null, St6)   % A POINTER only (0.100): `int x = n' had made x an owner in the null state, and a closure capturing x by value borrowed it                 % a COPY OF A NULL, OR OF A LOCAL WITH NO OWNERSHIP STATE, IS NULL TO THE CHECK (0.99): `int *q = p' with p null was a fresh value, and q `not consumed'
            ;   ck_is_pointer_type(T), \+ ck_declared_tie(N, _), ck_fresh_value(Init) -> ck_declare(St5a, N, loose, St6)
            ;   ck_no_owner_behind(N, T, Init, var(N, Init)), St6 = St5a ) ) ),
    ck_decls(Vs, St6, St).

%% what a right-hand side is to a slot: an owner (moved in), a null, a borrow, or a fresh value
ck_kind(E, _, null) :- ck_null(E), !.
ck_kind(ccast(_, rref(_, T), E), St, K) :- catch(ccl_resolve_type(T, R), _, fail), ( R = ptr(_, _) ; ccl_is_arith(R) ), !, ck_kind(E, St, K).   % an xvalue cast of a scalar is the object it names (0.201: `std::move(p)' of a plain pointer is `static_cast<T *&&>(p)', cpp_scalar_xvalue/2)
ck_kind(id(P), St, null) :- ck_plain_copy(St, P), !.                   % a copy of a null pointer, or of a plain local with no state (0.99)
ck_kind(move(E), _, fresh) :- ck_own_elem(E, _), !.                  % an element moved out: an owner, complete
ck_kind(move(E), St, K) :- ck_path(E, P), ck_by_value(E), ck_own_under(St, P, Fs), Fs \== [], !, ck_kind(E, St, K).   % a struct with owners moved whole: the value's kind, the fields going in ck_expr
ck_kind(move(E), St, K) :- !, ( ck_owner_path(St, E, P) -> K = owner(P) ; ck_moves_library(E) -> ck_kind(E, St, K) ; ck_name(E, N), ck_fail(move_of_non_owner, N, move(E)) ).   % a library class's value: the kind its own form has (ck_moves_library)
ck_kind(E, St, owner(P)) :- ck_owner_path(St, E, P), !.
ck_kind(E, St, borrow(P)) :- ck_borrows_from(E, St, P), !.
ck_kind(_, _, fresh).
ck_plain_copy(St, P) :- atom(P), ( ck_state(St, P, null) -> true ; ck_is_local(P), \+ ck_state(St, P, _) ).
ck_name(E, N) :- ( ck_path(E, N) -> true ; N = E ).

%% an own slot -- an owner, an own field (Key), or an untracked own place (none) --
%% receives a value: an owner is consumed into it and its own fields come along
%% (a tied owner only into a slot within its tie), a null makes it null, a
%% fresh value makes it live (an own result tied to an argument, the same
%% rule), a borrow is refused
ck_into_own(Key, R, Form, St0, St, Kind) :-
    ck_kind(R, St0, Kind),
    (   Kind = owner(P) -> ck_strip_move(R, E), ck_base_use(E, St0, St1), ck_tie_kept(St1, P, Key, Form), ck_under_states(St1, P, Src), ck_consume(P, move, Form, St1, St2, Prior), New = Prior, ck_transfer(St2, Src, P, Key, St3a), ck_complete_rest(St3a, Key, Prior, St3)
    ;   Kind = null -> ck_expr(R, St0, St3), New = null
    ;   Kind = borrow(P) -> ( ck_state(St0, P, loose) -> ck_expr(R, St0, St3a), ck_set(St3a, P, none, St3b), ( Key == none -> St3 = St3b ; ck_retarget(St3b, P, Key, St3) ), New = live   % the owner takes loose memory over
                              ; ck_fail(borrow_stored, P, Form) )
    ;   ck_strip_move(R, E), ( ck_call_tie(E, St0, PR) -> ( Key \== none, ck_within(St0, Key, PR) -> true ; ck_fail(tie_escapes, Key, Form) ) ; true ),
        ck_expr(R, St0, St3a), New = live,
        ( Key == none -> St3 = St3a ; ck_alloc_mode(E, Mode), ck_set_fields(St3a, Key, Mode, Form, St3) ) ),   % its fields: complete, zeroed, or garbage
    (   Key == none -> St = St3
    ;   ck_state(St3, Key, Cur) -> ( Cur == live -> ck_fail(owner_overwritten, Key, Form) ; ck_set(St3, Key, New, St) )
    ;   St = St3 ).
%% a plain slot (named, for the warning) receives a value: an owner's pointer
%% or a borrow may not be stored there -- but the address of a plain local (a
%% borrow of its anchor) may, as C has always had it: nothing consumes an
%% anchor; a fresh value that is not static has no owner behind it, a warning
ck_into_plain(Name, R, Form, W, St0, St) :-
    ck_kind(R, St0, Kind),
    (   Kind = owner(P) -> ck_fail(owner_stored, P, Form)
    ;   Kind = borrow(P) -> (   ck_state(St0, P, anchor) -> ck_expr(R, St0, St1), ck_anchor_stored(W, P, Form, St1, St)
                            ;   P = static(_) -> ck_expr(R, St0, St1), ck_unhold_at(W, St1, St)
                            ;   ck_state(St0, P, loose) -> ck_fail(untied, Name, Form)             % stored, still nobody's
                            ;   ck_il_slot(Name) -> ck_expr(R, St0, St)   % AN INITIALIZER LIST'S ARRAY hands its items to the library object, which holds the borrow (ck_lib_handed/4, 0.216): `std::vector<int *> v{p}' over a parameter p was borrow_stored
                            ;   ck_fail(borrow_stored, P, Form) )
    ;   Kind == null -> ck_expr(R, St0, St1), ck_unhold_at(W, St1, St)
    ;   ( ck_static_value(R) -> true ; ck_fail(untied, Name, Form) ), ck_expr(R, St0, St1), ck_unhold_at(W, St1, St) ).
ck_il_slot(Name) :- atom(Name), atom_concat('$il', _, Name).
%% THE ADDRESS OF A LOCAL STORED IN A PLAIN SLOT (0.217): held where the slot is a local's own storage (ck_hold_key/6),
%% so the local that holds it may not leave with it and dangles with it; `borrow_stored' where the slot outlives the
%% function -- `void put(struct S *s) { int x; s->p = &x; }', `g = &x' over a global, `*pp = &x' over a parameter, each
%% accepted until 0.217; through a pointer the check does not follow, as C has had it
ck_anchor_stored(local(E1), P, _, St0, St) :- !, ck_hold_place(E1, P, default, St0, St).
ck_anchor_stored(key(R, K, Mode), P, _, St0, St) :- !, ck_hold_key(R, K, Mode, P, St0, St).
ck_anchor_stored(out, P, Form, _, _) :- !, ck_fail(borrow_stored, P, Form).
ck_anchor_stored(_, _, _, St, St).
ck_unhold_at(local(E1), St0, St) :- !, ck_unhold(E1, St0, St).
ck_unhold_at(key(_, K, _), St0, St) :- !, ( ck_state(St0, K, S0), ( S0 = borrow(_) ; S0 = dangling(_) ) -> ck_set(St0, K, none, St) ; St = St0 ).
ck_unhold_at(_, St, St).
%% a slot's name for a diagnostic: a path, `*p', `a[]', else the expression
ck_slot_name(E, N) :- ck_path(E, N), !.
ck_slot_name(deref(E), N) :- ck_slot_name(E, N0), atom(N0), !, atom_concat('*', N0, N).
ck_slot_name(index(E, _), N) :- ck_slot_name(E, N0), atom(N0), !, atom_concat(N0, '[]', N).
ck_slot_name(E, E).
%% a tied slot (Key, tied to Root) receives a value: a borrow of something
%% within the root, a null, a fresh value; an owner's pointer is refused as
%% for any plain slot; the slot is a borrow of the root from here
ck_into_tied(Key, Root, R, Form, St0, St) :-
    (   R = move(_) -> ck_fail(owner_stored, Key, Form)
    ;   ck_borrows_from(R, St0, P) -> ( ck_within(St0, Root, P) -> true ; ck_fail(tie_mismatch, Key, Form) )
    ;   true ),
    ck_expr(R, St0, St1), ck_loose_taken(R, St1, St2), ck_tied_state(St2, Root, S), ck_set_if(St2, Key, S, St).
%% the fields the source did not cover -- an own FIELD's pointee is not opened,
%% so it has none -- are complete, as the source was when it moved
ck_complete_rest(St, none, _, St) :- !.
ck_complete_rest(St0, Key, Prior, St) :- ck_under_states(St0, Key, Ps), ( Prior == null -> S = null ; S = live ), ck_complete_unset(Ps, S, St0, St).
ck_complete_unset([], _, St, St).
ck_complete_unset([K-KS|Ps], S, St0, St) :- ( KS == unset -> ( ck_is_array_key(K) -> ck_set(St0, K, array, St1) ; ck_set(St0, K, S, St1) ) ; St1 = St0 ), ck_complete_unset(Ps, S, St1, St).
%% the fields of an owner moved into another owner: the same states, under the
%% new base; a field's borrow of a sibling is re-rooted to the sibling's copy
ck_transfer(St, _, _, none, St) :- !.
ck_transfer(St, [], _, _, St) :- !.
ck_transfer(St0, [SK-SS|Ps], P, Key, St) :-
    ( atom_concat(P, Suffix, SK), ( atom_concat(Key, Suffix, TK) ) -> ck_reroot(SS, P, Key, SS1), ck_set_if(St0, TK, SS1, St1) ; St1 = St0 ),
    ck_transfer(St1, Ps, P, Key, St).
ck_reroot(borrow(R0), P, Key, borrow(R)) :- ck_under_root(R0, P, Key, R), !.
ck_reroot(dangling(R0), P, Key, dangling(R)) :- ck_under_root(R0, P, Key, R), !.
ck_reroot(S, _, _, S).
ck_under_root(R0, P, Key, R) :- atom_concat(P, Sfx, R0), ( sub_atom(Sfx, 0, 1, _, '.') ; sub_atom(Sfx, 0, 2, _, '->') ), !, atom_concat(Key, Sfx, R).
%% a struct by value with own fields receives a whole value: from another such
%% struct its fields move over; from an initializer list, item by item; from a
%% call or anything else, fresh: every own field live
ck_fill(Key, T, R, Form, St0, St) :-
    ck_no_array_copy(St0, Key, Form),
    (   R = init(Items) -> ck_init_slots(Items, T, Key, St0, St)
    ;   R = compound_lit(_, init(Items)) -> ck_init_slots(Items, T, Key, St0, St)
    ;   ck_path(R, P), ck_under_states(St0, P, Src), Src \== [] -> ck_expr(R, St0, St1), ck_move_fields(St1, Src, P, Key, Form, St)
    ;   ck_expr(R, St0, St1), ck_own_under(St1, Key, Ks), ck_set_live(St1, Ks, Form, St) ).
ck_set_live(St, [], _, St).
ck_set_live(St0, [K|Ks], Form, St) :- ( ck_state(St0, K, live) -> ck_fail(owner_overwritten, K, Form) ; ck_set(St0, K, live, St1) ), ck_set_live(St1, Ks, Form, St).
ck_move_fields(St, [], _, _, _, St).
ck_move_fields(St0, [SK-SS|Ps], P, Key, Form, St) :- \+ ck_owner_state(SS), !,          % a tied field, an anchor: copied, re-rooted
    atom_concat(P, Suffix, SK), atom_concat(Key, Suffix, TK), ck_reroot(SS, P, Key, SS1), ck_set_if(St0, TK, SS1, St1),
    ck_move_fields(St1, Ps, P, Key, Form, St).
ck_move_fields(St0, [SK-SS|Ps], P, Key, Form, St) :-
    ( SS == live -> New = live ; SS == null -> New = null ; SS == unset -> ck_fail(owner_unset, SK, Form) ; ck_fail(use_after_move, SK, Form) ),
    atom_concat(P, Suffix, SK), atom_concat(Key, Suffix, TK),
    ck_set(St0, SK, moved, St1), ck_dangle(St1, SK, St2),
    ( ck_state(St2, TK, live) -> ck_fail(owner_overwritten, TK, Form) ; ck_set_if(St2, TK, New, St3) ),
    ck_move_fields(St3, Ps, P, Key, Form, St).

%% an initializer list against its type: every slot is own, tied, or plain;
%% under a base (a variable's key) an own or tied slot is that field
ck_init_slots(Items, T, Base, St0, St) :- ccl_resolve_type(T, T1), ck_init_slots_(Items, T1, Base, 0, St0, St).
ck_init_slots_([], _, _, _, St, St).
ck_init_slots_([item(Ds, V)|Is], T, Base, I, St0, St) :-
    ck_slot(T, Ds, I, SlotT, F, I1),
    ( ( Base == none ; F == none ) -> Key = none ; atomic_list_concat([Base, '.', F], Key) ),
    ck_slot_label(Base, F, Key, Name),
    (   F == '$this' -> ck_expr(V, St0, St1)                                            % A CLOSURE'S CAPTURED OBJECT: `[this]' keeps the enclosing this, which outlives the
    ;   ck_init_where(Base, Key, W), ck_init_slot(V, SlotT, Key, Name, W, St0, St1) ),   % closure -- a lambda is scope-bound here, as a reference capture already is
    ck_init_slots_(Is, T, Base, I1, St1, St).
ck_slot_label(_, _, Key, Key) :- Key \== none, !.
ck_slot_label(Base, none, _, Name) :- Base \== none, !, atom_concat(Base, '[]', Name).
ck_slot_label(_, F, _, F) :- F \== none, !.
ck_slot_label(_, _, _, element).
ck_slot(T, [field(F)|_], _, MT, F, I1) :- ccl_members_of(T, Ms), ck_member_at(Ms, F, 0, MT, Idx), !, I1 is Idx + 1.
ck_slot(arr(_, ET), [at(int(K))|_], _, ET, none, I1) :- !, I1 is K + 1.
ck_slot(arr(_, ET), [], I, ET, none, I1) :- !, I1 is I + 1.
ck_slot(T, [], I, MT, F, I1) :- ccl_members_of(T, Ms), I0 is I + 1, ccl_nth(I0, Ms, member(MT, F, _)), !, I1 is I + 1.
ck_slot(_, _, I, unknown, none, I1) :- I1 is I + 1.
ck_member_at([member(MT, F, _)|_], F, I, MT, I) :- !.
ck_member_at([_|Ms], F, I0, MT, I) :- I1 is I0 + 1, ck_member_at(Ms, F, I1, MT, I).
ck_init_slot(init(Sub), SlotT, Key, _, _, St0, St) :- !, ck_init_slots(Sub, SlotT, Key, St0, St).
ck_init_slot(V, SlotT, Key, Name, W, St0, St) :-
    (   SlotT \== unknown, ck_own_type(SlotT) -> ck_into_own(Key, V, init(V), St0, St, _)
    ;   Key \== none, ck_tied_to(Key, Root) -> ck_into_tied(Key, Root, V, init(V), St0, St)
    ;   SlotT \== unknown, ck_carries_type(SlotT) -> ck_into_plain(Name, V, init(V), W, St0, St)
    ;   ck_expr(V, St0, St) ).
%% where an initializer's slot lands (0.217): in the variable it initializes, a static outliving the function
ck_init_where(none, _, unknown) :- !.
ck_init_where(Base, Key, W) :- ck_key_root(Base, R),
    (   ( ck_is_static(R) ; \+ ck_is_local(R) ) -> W = out
    ;   Key \== none -> W = key(R, Key, replace)
    ;   atom_concat(Base, '.$held', K), W = key(R, K, join) ).

%% ---- loops: a body may not consume an owner from outside, unless it re-owns it ------------
ck_loop(S, St0, St) :- ck_loop_with_step(S, none, St0, St).
ck_loop_with_step(S, Step, St0, St) :-
    ck_loop_enter(St0, loop),
    ck_stmt(S, St0, St1),
    ck_loop_leave(Exits), ck_continues(Conts),
    ck_merge_all([St1|Conts], StEnd),
    ( Step == none -> StEnd1 = StEnd ; StEnd == dead -> StEnd1 = dead ; ck_expr(Step, StEnd, StEnd1) ),
    ck_no_moves_across(St0, StEnd1, S),
    ck_merge_all([St0, StEnd1|Exits], St).
ck_loop_enter(St, Kind) :- nb_getval('$ck_loops', L), nb_setval('$ck_loops', [lp(Kind, St, [], [])|L]).
ck_loop_leave(Exits) :- nb_getval('$ck_loops', [lp(_, _, Exits, _)|L]), nb_setval('$ck_loops', L).
ck_continues(Cs) :- nb_getval('$ck_loops', L), ( L = [] -> Cs = [] ; Cs = [] ).   % continues were merged when leaving
ck_no_moves_across(_, dead, _) :- !.
ck_no_moves_across(st(Before), st(After), S) :- ck_frames_kept(Before, After, S).
ck_frames_kept([], _, _).
ck_frames_kept([fr(Ob, _)|Bs], [fr(Oa, _)|As], S) :-
    ( member(N-live, Ob), memberchk(N-SA, Oa), SA \== live -> ck_fail(move_in_loop, N, S) ; true ),
    ck_frames_kept(Bs, As, S).
%% a break or continue: its state joins the loop's exits (or the switch's), the frames inside the loop closed first
ck_exit_to_loop(St0, Kind) :-
    nb_getval('$ck_loops', [lp(LKind, StIn, Exits, Conts)|L]),
    st(FrsIn) = StIn, length(FrsIn, Depth), ck_close_to(St0, Depth, St1),
    ( Kind == continue, LKind == switch -> nb_setval('$ck_loops', [lp(LKind, StIn, Exits, Conts)|L]), ck_exit_to_loop_outer(St1, L, continue)
    ; Kind == continue -> nb_setval('$ck_loops', [lp(LKind, StIn, [St1|Exits], Conts)|L])   % a continue rejoins the head: checked as an exit too
    ; nb_setval('$ck_loops', [lp(LKind, StIn, [St1|Exits], Conts)|L]) ).
ck_exit_to_loop_outer(St1, [lp(K, StIn, Exits, Conts)|L], Kind) :- !, nb_setval('$ck_loops', [lp(K, StIn, [St1|Exits], Conts)|L]), true.
ck_exit_to_loop_outer(_, [], _) :- ck_fail(not_checked, continue, continue).
%% close the frames opened inside the loop: their defers run, their owners must be consumed
ck_close_to(St, Depth, St) :- st(Frs) = St, length(Frs, Depth), !.
ck_close_to(St0, Depth, St) :- ck_in_state_scope(St0, ck_scope_end(St0, St1)), ck_close_to(St1, Depth, St).

%% ---- goto (0.133): the walk follows it ------------------------------------------------------
%% A goto was refused wherever an owner lived (`goto_with_owners', M3) and the code after a label that only a goto
%% reaches was never walked (a dead state skips statements). Now the goto is an edge of the flow: every frame the check
%% pushes has an id, `'$ck_bpath'' the open ones' (innermost first), and a label is where a goto's state, the frames
%% it leaves closed -- their defers run, their owners consumed or leaked, their borrows dangling, as a `break' closes
%% them -- joins the state that falls through. A FORWARD goto's state waits for its label (`'$ck_fwd''); a BACKWARD
%% one, the label walked already, is closed down to the label's frames and, where the label's frame is one of its own,
%% that frame loses what was declared since the label (jumping back past a declaration ends it: its owner must be
%% consumed, its defers run); its state joins the label's on the NEXT walk (`'$ck_seed''): the function is walked again
%% until no label's state changes, as a loop's state settles -- an owner freed and taken again (`retry:') settles, one
%% left live and taken again is `owner_overwritten'. A goto whose label no walk reached (a label in dead code inside a
%% statement) is `not_checked'. The lowering runs the same defers on the jump (ir_goto, 0.133).
%% A GOTO INTO A BLOCK, OR OVER A DECLARATION, IS FOLLOWED (0.138; C 6.8.6.1 allows both but for a VLA): the frames it
%% enters are new to it, and at the label every owner the fall-through holds and the edge does not -- its declaration
%% skipped -- is `unset' on that edge (`ck_skipped/4'): a merge with a live owner is `partial', refused on use and at
%% the scope's end, one with null is `unset', and the code after the label must give it a value before it frees it.
%% A plain pointer holding fresh memory and an own array, skipped, would be garbage that must be freed: refused,
%% `goto_with_owners'. A goto over a `defer' (or a C++ local with a destructor, a defer of the desugaring) is refused,
%% `goto_over_defer' (`ck_defers_agree/2'): the defer runs at its scope's end on every path, the skipped one too. A
%% backward goto into a block closes its frames to the one it shares with the label and ends what that frame declared
%% since the label, as a goto in the label's own frame does (`lab(LP, KDs)': the keys and defers of each frame).
ck_bpath_push :- ( nb_current('$ck_bpath', P) -> true ; P = [] ), ( nb_current('$ck_bid', N0) -> true ; N0 = 0 ),
    N is N0 + 1, nb_setval('$ck_bid', N), nb_setval('$ck_bpath', [N|P]).
ck_bpath_pop :- ( nb_current('$ck_bpath', [_|P]) -> nb_setval('$ck_bpath', P) ; true ).
ck_bpath_root(P) :- ( nb_current('$ck_bpath', P0) -> true ; P0 = [] ), reverse(P0, P).
ck_common_prefix([X|Xs], [Y|Ys], [X|Zs]) :- X == Y, !, ck_common_prefix(Xs, Ys, Zs).
ck_common_prefix(_, _, []).
ck_goto(L, Ln, St) :- ck_bpath_root(GP), nb_getval('$ck_labels', Ls),
    (   memberchk(L-lab(LP, KDs), Ls)
    ->  ck_edge_state(GP, LP, St, KDs, StC),
        nb_getval('$ck_back', B0), ck_add_edge(L, StC, B0, B1), nb_setval('$ck_back', B1)
    ;   nb_getval('$ck_fwd', F0), nb_setval('$ck_fwd', [g(L, St, GP, Ln)|F0]) ).
%% the state an edge brings to a label at the path LP: the frames the goto leaves closed; for a backward goto (KDs, the
%% label's keys and defers per frame, innermost first) the frame it shares with the label without what that frame
%% declared since the label; the frames it enters (a jump into a block) new and empty
ck_edge_state(GP, LP, St0, KDs, St) :- ck_common_prefix(GP, LP, CP), length(CP, NC), D is NC + 1, ck_close_to(St0, D, St1),
    length(LP, NL), Enter is NL - NC,
    (   St1 \== dead, KDs \== none, nth0(Enter, KDs, LKeys-LDefs) -> ck_close_since_label(St1, LKeys, LDefs, St2) ; St2 = St1 ),
    (   Enter =:= 0 -> St = St2
    ;   St2 == dead -> St = dead
    ;   St2 = st(Frs), length(New, Enter), ck_fresh_frames(New), append(New, Frs, Frs2), St = st(Frs2) ).
ck_fresh_frames([]).
ck_fresh_frames([fr([], [])|Fs]) :- ck_fresh_frames(Fs).
%% back past declarations in the label's own frame: the defers registered since the label run, the keys declared
%% since it end (consumed or leaked, their borrows dangling), as at the frame's end
ck_close_since_label(st([fr(Os, Ds)|Frs]), LKeys, LDefs, St) :-
    length(Ds, ND), New is ND - LDefs,
    ( New > 0 -> length(NewDs, New), append(NewDs, OldDs, Ds) ; NewDs = [], OldDs = Ds ),
    ck_run_defers(NewDs, st([fr(Os, OldDs)|Frs]), St1),
    (   St1 == dead -> St = dead
    ;   St1 = st([fr(Os1, Ds1)|Frs1]),
        findall(K-S, ( member(K-S, Os1), \+ memberchk(K, LKeys) ), Gone), findall(K-S, ( member(K-S, Os1), memberchk(K, LKeys) ), Kept),
        ck_leaks(Gone, scope_end), ck_keys(Gone, GKs), ck_dangle_all(st([fr(Kept, Ds1)|Frs1]), GKs, St) ).
ck_add_edge(L, St, B0, [L-St2|B1]) :- ( select(L-St1, B0, B1) -> ck_merge(St1, St, St2) ; B1 = B0, St2 = St ).
%% a label: the state that falls through, then every forward goto's, then the back edges of the last walk
ck_label_in(L, _, St0, StL) :- ck_bpath_root(LP),
    nb_getval('$ck_fwd', F0), findall(G, ( member(G, F0), G = g(L, _, _, _) ), Mine), findall(G, ( member(G, F0), \+ G = g(L, _, _, _) ), Rest), nb_setval('$ck_fwd', Rest),
    ck_label_edges(Mine, LP, L, Es),
    nb_getval('$ck_seed', Seed), ( memberchk(L-SS, Seed) -> Es1 = [SS|Es] ; Es1 = Es ),
    ck_defers_agree([St0|Es1], L),
    ck_skipped_all(Es1, St0, L, Es2),
    ck_merge_all([St0|Es2], StL),
    ( StL = st(Frs) -> findall(Ks-ND, ( member(fr(Os, Ds), Frs), ck_keys(Os, Ks), length(Ds, ND) ), KDs) ; KDs = none ),
    nb_getval('$ck_labels', Ls), nb_setval('$ck_labels', [L-lab(LP, KDs)|Ls]).
ck_label_edges([], _, _, []).
ck_label_edges([g(_, St, GP, GLn)|Gs], LP, L, [StC|Es]) :- nb_getval('$ck_line', L0), ck_line(GLn), ck_edge_state(GP, LP, St, none, StC), nb_setval('$ck_line', L0), ck_label_edges(Gs, LP, L, Es).
%% every path to a label has run the same defers of each frame it shares with the label: one that jumped over a defer
%% would have it run at the scope's end with its operands never set (`goto_over_defer')
ck_defers_agree(Sts, L) :- findall(Ns, ( member(st(Frs), Sts), findall(N, ( member(fr(_, Ds), Frs), length(Ds, N) ), Ns) ), All),
    ( All = [N0|Rest], member(N1, Rest), N1 \== N0 -> ck_fail(goto_over_defer, L, goto(L)) ; true ).
%% the owners the fall-through holds and an edge does not: their declarations skipped, `unset' on that edge
ck_skipped_all([], _, _, []).
ck_skipped_all([E|Es], St0, L, [E2|Es2]) :- ck_skipped(E, St0, L, E2), ck_skipped_all(Es, St0, L, Es2).
ck_skipped(E, St0, L, E2) :- E = st(FE), St0 = st(F0), length(FE, N), length(F0, N), !, ck_skipped_frames(FE, F0, L, FE2), E2 = st(FE2).
ck_skipped(E, _, _, E).
ck_skipped_frames([], [], _, []).
ck_skipped_frames([fr(OE, DE)|Fs], [fr(O0, _)|F0s], L, [fr(OE2, DE)|Fs2]) :-
    findall(K-unset, ( member(K-S0, O0), \+ memberchk(K-_, OE), ck_skipped_owner(S0, K, L) ), Add), append(OE, Add, OE2),
    ck_skipped_frames(Fs, F0s, L, Fs2).
ck_skipped_owner(S0, K, L) :- ( memberchk(S0, [loose, array]) -> ck_fail(goto_with_owners, K, goto(L)) ; ck_owner_state(S0) ).
%% the walk of a function's body, again while a back edge changes a label's state
ck_walk_body(Body, St0, St) :- ck_walk_snapshot(Snap), nb_setval('$ck_seed', []), ck_walk_iter(Body, St0, Snap, 1, St).
ck_walk_iter(Body, St0, Snap, I, St) :-
    ck_walk_restore(Snap), nb_setval('$ck_bpath', []), nb_setval('$ck_labels', []), nb_setval('$ck_fwd', []), nb_setval('$ck_back', []),
    ck_stmt(Body, St0, St1),
    nb_getval('$ck_fwd', Pend), ( Pend = [g(PL, _, _, PLn)|_] -> ck_line(PLn), ck_fail(not_checked, goto, goto(PL)) ; true ),
    nb_getval('$ck_back', Back), nb_getval('$ck_seed', Seed0), ck_seed_merge(Back, Seed0, Seed1),
    (   Seed1 == Seed0 -> St = St1
    ;   I >= 8 -> ck_fail(not_checked, goto, goto)
    ;   nb_setval('$ck_seed', Seed1), I1 is I + 1, ck_walk_iter(Body, St0, Snap, I1, St) ).
ck_seed_merge([], S, S).
ck_seed_merge([L-St|Bs], S0, S) :- ( select(L-Old, S0, S1) -> ck_merge(Old, St, New), ck_seed_put(S1, L, New, Old, S0, S2) ; S2 = [L-St|S0] ), ck_seed_merge(Bs, S2, S).
ck_seed_put(S1, L, New, Old, S0, S) :- ( New == Old -> S = S0 ; S = [L-New|S1] ).
%% what a walk writes and a second walk must start from as the first did
ck_walk_snapshot(snap(Ti, Sa, Ar, Al, Rf)) :- nb_getval('$ck_ties', Ti), nb_getval('$ck_statics', Sa), nb_getval('$ck_arrays', Ar), nb_getval('$ck_arrlocals', Al),
    ( nb_current('$ck_refs', Rf) -> true ; Rf = '$none' ).
ck_walk_restore(snap(Ti, Sa, Ar, Al, Rf)) :- nb_setval('$ck_ties', Ti), nb_setval('$ck_statics', Sa), nb_setval('$ck_arrays', Ar), nb_setval('$ck_arrlocals', Al),
    ( Rf == '$none' -> true ; nb_setval('$ck_refs', Rf) ).

%% ---- scope ends and returns -----------------------------------------------------------------
%% the frame's defers run, last first; then its owners must be consumed; then
%% whatever borrowed one of its keys -- an anchor, an owner -- dangles
ck_scope_end(dead, dead) :- !.
ck_scope_end(st([fr(Os, Ds)|Frs]), St) :-
    ck_run_defers(Ds, st([fr(Os, [])|Frs]), St1),
    ( St1 == dead -> St = dead ; st([fr(Os1, _)|Frs1]) = St1, ck_leaks(Os1, scope_end), ck_keys(Os1, Ks), ck_dangle_all(st(Frs1), Ks, St) ).
ck_run_defers([], St, St).
ck_run_defers([B|Bs], St0, St) :- ck_stmt(B, St0, St1), ck_run_defers(Bs, St1, St).
%% a return: every frame's defers run, innermost first, then no owner may be live
ck_exit_all(St0, Form) :- ck_exit_frames(St0, Form).
ck_exit_frames(dead, _) :- !.
ck_exit_frames(st([]), _) :- !.
ck_exit_frames(st([fr(Os, Ds)|Frs]), Form) :-
    ck_in_state_scope(st([fr(Os, [])|Frs]), ck_run_defers(Ds, st([fr(Os, [])|Frs]), St1)),
    (   St1 == dead -> true
    ;   st([fr(Os1, _)|Frs1]) = St1, ( Frs1 == [] -> ck_complete_owners(Os1, Form) ; true ),
        ck_leaks(Os1, Form), ck_exit_frames(st(Frs1), Form) ).
%% AN EXIT RUNS A FRAME'S DEFERS UNDER THAT FRAME'S SYMBOL TABLE (0.201): the state's frames and the symbol table's are
%% pushed together, and a `return', a `break' or a `goto' closes the state's frames one by one while the symbol table
%% keeps the walk's own; a defer of an outer frame that anchors its local (`&h' of a destructor's call, the local's
%% first anchor where an aggregate's braces made it) put the anchor in the state frame of the symbol table's index, a
%% frame too deep or none: `H h{1}; for (...) { H d{2}; if (c) return 3; }' failed the check with no word. The table is
%% cut to the frame's while its defers run, and is the walk's again afterwards, however they end.
ck_in_state_scope(st(Frs), G) :- nb_getval('$ccl_scope', S0), length(Frs, N), length(S0, M), M > N, !,
    K is M - N, length(Drop, K), append(Drop, S1, S0), nb_setval('$ccl_scope', S1), ccl_tables_changed,
    ( catch(G, E, true) -> R = done ; R = failed ), nb_setval('$ccl_scope', S0), ccl_tables_changed,
    ( R == failed -> fail ; var(E) -> true ; throw(E) ).
ck_in_state_scope(_, G) :- call(G).
ck_leaks_all(st(Frs), Form) :- ck_leaks_frames(Frs, Form).
ck_leaks_frames([], _).
ck_leaks_frames([fr(Os, _)|Frs], Form) :- ck_leaks(Os, Form), ck_leaks_frames(Frs, Form).
ck_leaks([], _).
ck_leaks([N-S|Os], Form) :-
    (   S == loose -> ck_fail(unconsumed, N, Form)
    ;   ( memberchk(S, [moved, unset, null, none, anchor, array]) ; S = borrow(_) ; S = dangling(_) ; ck_is_borrowed_field(N) ) -> true
    ;   ck_fail(owner_leaked, N, Form) ),
    ck_leaks(Os, Form).
ck_any_owner(st(Frs)) :- member(fr(Os, _), Frs), member(_-S, Os), ck_owner_state(S), !.
ck_merge_all([S], S) :- !.
ck_merge_all([A, B|T], S) :- ck_merge(A, B, C), ck_merge_all([C|T], S).

%% ---- expressions --------------------------------------------------------------------------------
%% a value that is consumed if it is an owner or a struct with own fields (a return), else used
ck_consume_or_use(E, St0, St) :- ck_owner_path(St0, E, K), ck_is_borrowed_field(K), nb_getval('$ck_ret', Ret), \+ ck_own_type(Ret), !,   % a parameter's own field returned as a plain pointer: a borrow out, the caller's still (c_str)
    ck_base_use(E, St0, St).
ck_consume_or_use(E, St0, St) :- ck_owner_path(St0, E, K), !, ck_base_use(E, St0, St1), ck_consume(K, move, E, St1, St, _).
ck_consume_or_use(move(E), St0, St) :- !, ck_expr(move(E), St0, St).
ck_consume_or_use(E, St0, St) :- ck_path(E, K), ck_by_value(E), ck_has_array_under(St0, K), !, ck_fail(own_array_by_value, K, E).
ck_consume_or_use(E, St0, St) :- ck_path(E, K), ck_by_value(E), ck_own_under(St0, K, Fs), Fs \== [], !, ck_expr(E, St0, St1), ck_move_out(St1, Fs, E, St).
ck_consume_or_use(E, St0, St) :- ck_expr(E, St0, St1), ck_loose_taken(E, St1, St).
%% a struct held by value, not a pointer to one (whose own fields are the struct's, not the pointer's to move)
ck_by_value(E) :- ccl_type_of(E, T), T \== unknown, \+ ck_is_pointer_type(T).
%% consuming an owner, by free (fclose) or by move: it must be live or null; its
%% own fields must be consumed already when it is freed, complete when it is
%% moved; nothing tied to it may still hold memory; then it and they are moved,
%% and their borrows dangle
ck_consume(K, How, Form, St0, St, Prior) :-
    ck_state(St0, K, Prior),
    ( Prior == live -> true ; Prior == null -> true ; Prior == unset -> ck_fail(owner_unset, K, Form) ; ck_fail(use_after_move, K, Form) ),
    ck_own_under(St0, K, Fs),
    ( Prior == null -> true ; ck_fields_consumable(Fs, How, St0, Form) ),
    ck_tied_consumed(St0, K, Form),
    ck_set(St0, K, moved, St1), ck_set_all(St1, Fs, moved, St2),
    ck_under(St2, K, All), ck_dangle_all(St2, [K|All], St).
ck_fields_consumable([], _, _, _).
ck_fields_consumable([F|Fs], How, St, Form) :-
    ck_state(St, F, S),
    (   How == free -> ( memberchk(S, [moved, unset, null]) -> true ; ck_fail(owner_leaked, F, Form) )
    ;   memberchk(S, [live, null]) -> true
    ;   S == unset -> ck_fail(owner_unset, F, Form)
    ;   ck_fail(use_after_move, F, Form) ),
    ck_fields_consumable(Fs, How, St, Form).
%% a struct by value moved out (returned, passed to an own parameter): its fields go, complete
ck_move_out(St0, Fs, Form, St) :- ck_fields_consumable(Fs, move, St0, Form), ck_set_all(St0, Fs, moved, St1), ck_dangle_all(St1, Fs, St).
%% the borrows of a consumed owner dangle, in every frame
ck_dangle_all(St, [], St).
ck_dangle_all(St0, [K|Ks], St) :- ck_dangle(St0, K, St1), ck_dangle_all(St1, Ks, St).
ck_dangle(st(Frs), P, st(Frs1)) :- ck_dangle_frames(Frs, P, Frs1).
ck_dangle_frames([], _, []).
ck_dangle_frames([fr(Os, D)|T], P, [fr(Os1, D)|T1]) :- ck_dangle_owners(Os, P, Os1), ck_dangle_frames(T, P, T1).
ck_dangle_owners([], _, []).
ck_dangle_owners([N-borrow(P)|T], P, [N-dangling(P)|T1]) :- !, ck_dangle_owners(T, P, T1).
ck_dangle_owners([X|T], P, [X|T1]) :- ck_dangle_owners(T, P, T1).
%% a read of an owner, a field, a borrow, an anchor
ck_read(K, S) :- ( memberchk(S, [live, null, none, anchor, loose, array]) -> true ; S = borrow(_) -> true ; S = dangling(P) -> ck_fail(borrow_after_move, K, borrowed_from(P)) ; S == unset -> ck_fail(owner_unset, K, id(K)) ; ck_fail(use_after_move, K, id(K)) ).

%% the walk's clauses are ordered by what a node is most often (counted on
%% the B-tree: a third are names, then members, operators, literals), and a
%% node no clause below cares for is walked without a univ: an operator or a
%% number was tried against every head before the last clause took it, a
%% `x->f' that is no owner's key computed its path, looked it up, then went
%% the generic way with its field name as a child
ck_expr(_, dead, dead) :- !.
ck_expr(E, St, St) :- \+ compound(E), !.                                          % an operator, a number, a name as a field
ck_expr(id(N), St, St) :- !, ( ck_state(St, N, S) -> ck_read(N, S) ; true ), ck_held_read(St, N).   % what a holder's storage holds is read with it (0.217)
ck_expr(int(_), St, St) :- !.
ck_expr(uint(_), St, St) :- !.
ck_expr(long(_), St, St) :- !.
ck_expr(ulong(_), St, St) :- !.
ck_expr(wstr(_), St, St) :- !.
ck_expr(u16str(_), St, St) :- !.
ck_expr(u32str(_), St, St) :- !.
ck_expr(u8str(_), St, St) :- !.
ck_expr(wchr(_), St, St) :- !.
ck_expr(u16chr(_), St, St) :- !.
ck_expr(u32chr(_), St, St) :- !.
ck_expr(wb(_), St, St) :- !.
ck_expr(uwb(_), St, St) :- !.
ck_expr(float(_), St, St) :- !.
ck_expr(imag(_), St, St) :- !.
ck_expr(imagf(_), St, St) :- !.
ck_expr(imagl(_), St, St) :- !.
ck_expr(imagi(_, _), St, St) :- !.
ck_expr(chr(_), St, St) :- !.
ck_expr(str(_), St, St) :- !.
ck_expr(member(E, F), St0, St) :- ck_path(member(E, F), K), ck_state(St0, K, S), !, ck_base_read(E, St0, St), ck_read(K, S), ck_held_read(St, K).
ck_expr(member(E, F), St0, St) :- !, ck_base_read(E, St0, St), ( ck_path(member(E, F), K) -> ck_held_read(St, K) ; true ).   % a member reads what it holds, not its siblings (0.217)
ck_expr(arrow(E, F), St0, St) :- ck_path(arrow(E, F), K), ck_state(St0, K, S), !, ck_expr(E, St0, St), ck_read(K, S).
ck_expr(arrow(E, _), St0, St) :- !, ck_expr(E, St0, St).
ck_expr(index(A, I), St0, St) :- !, ck_expr(A, St0, St1), ck_expr(I, St1, St).
ck_expr(bin(Op, A, B), St0, St) :- Op \== '&&', Op \== '||', !, ck_expr(A, St0, St1), ck_expr(B, St1, St).
ck_expr(E, St0, St) :- ck_unary_shape(E, A), !, ck_expr(A, St0, St).           % a wrapper around one expression: its child
ck_expr(move(E), St0, St) :- ck_own_elem(E, K), !, ck_expr(E, St0, St1), ck_dangle(St1, K, St).   % an element out: the array's borrows dangle
ck_expr(move(E), St0, St) :- ck_path(E, K), ck_by_value(E), ck_own_under(St0, K, Fs), Fs \== [], !, ck_expr(E, St0, St1), ck_move_out(St1, Fs, move(E), St).   % a struct with owners moved whole: its fields go
ck_expr(move(E), St0, St) :- !, ( ck_owner_path(St0, E, K) -> ck_base_use(E, St0, St1), ck_consume(K, move, move(E), St1, St, _) ; ck_moves_library(E) -> ck_expr(E, St0, St) ; ck_name(E, N), ck_fail(move_of_non_owner, N, move(E)) ).
ck_expr(scoped(_, N), St0, St) :- !, ck_expr(id(N), St0, St).                  % C++ (M6)
ck_expr(ccast(_, _, E), St0, St) :- !, ck_expr(E, St0, St).
ck_expr(new(_, Args), St0, St) :- !, ck_exprs(Args, St0, St).
ck_expr(new_array(_, N), St0, St) :- !, ck_expr(N, St0, St).
ck_expr(delete(E), St0, St) :- !, ck_expr(call(id(free), [E]), St0, St).
ck_expr(delete_array(E), St0, St) :- !, ck_expr(call(id(free), [E]), St0, St).
ck_expr(delete_poly(E, D, _), St0, St) :- !, ck_expr(D, St0, St1), ck_expr(call(id(free), [E]), St1, St).   % the destructor, then the free of the complete object (0.108)
ck_expr(alloc(_, _, Call), St0, St) :- !, ( Call = call(_, As) -> ck_exprs(As, St0, St) ; St = St0 ).   % a new-expression's block (0.202): the allocation function's arguments read, the block fresh
ck_expr(dealloc(D, _, X), St0, St) :- !, ( D == none -> St1 = St0 ; ck_expr(D, St0, St1) ), ck_expr(call(id(free), [X]), St1, St).   % a delete-expression (0.202): the destructor, then the block given back -- a free of the pointer to the check
ck_expr(call(id(F), [addr(_)]), St, St) :- ck_lib_dtor(F), !.   % a library object's destructor reads nothing it holds (0.216)
ck_expr(call(id(F), [A0|As]), St0, St) :- ck_lib_replacing(F, A0, St0, Obj), !,   % what it held replaced: not read (0.216)
    ( A0 = addr(P0), ck_path(P0, _) -> St0a = St0 ; ck_expr(A0, St0, St0a) ), ck_args_(As, id(F), 2, St0a, St1), ck_lib_replace(Obj, F, [A0|As], St0, St1, St).
ck_expr(call(id(F), Args), St0, St) :- !, ck_args(Args, id(F), St0, St1), ck_lib_store(F, Args, St1, St2), ck_flow_store(F, Args, St2, St3), ck_lib_free_store(F, Args, St3, St).   % what a library object is handed it holds (0.216), what a function of the program or a free library function stores (0.217)
ck_expr(call(F, Args), St0, St) :- !,
    ck_expr(F, St0, St1),
    ( ccl_type_of(F, FT), ck_fn_params(FT, Ps) -> ck_args(Args, params(Ps), St1, St) ; ck_exprs(Args, St1, St) ).
%% assignment: to an owner or an own field; to a struct by value with own fields;
%% to a tied slot; to a local plain pointer (a borrow, or not); to any other
%% place, by its type
ck_expr(assign('=', L, R), St0, St) :- ck_vptr_slot(L), !, ck_expr(R, St0, St1), ck_lval_use(L, St1, St).   % A TABLE POINTER is static storage, never memory the check follows (ck_carries_, 0.127): a base-variant constructor stores the construction tables its `$vtt' names (0.172)
ck_expr(assign(Op, id(N), R), St0, St) :- ck_is_ref(N), !, ck_expr(assign(Op, deref(id(N)), R), St0, St).   % C++: through the reference
%% THE RIGHT SIDE IS WALKED FIRST, as the lowering evaluates it (C++17 [expr.ass]/1; 0.197), then the place: `p->next =
%% take(p)' over an own parameter of take frees p before p->next is written, a use after the move
ck_expr(assign('=', L, R), St0, St) :- ck_owner_path(St0, L, K), !,
    ck_into_own(K, R, assign('=', L, R), St0, St1, _), ck_base_use(L, St1, St).
ck_expr(assign('=', L, R), St0, St) :- ck_path(L, K), ck_by_value(L), ck_own_under(St0, K, [_|_]), !,
    ( ccl_type_of(L, T) -> true ; T = unknown ), ck_fill(K, T, R, assign('=', L, R), St0, St1), ck_base_use(L, St1, St).
ck_expr(assign('=', L, R), St0, St) :- ck_path(L, K), ck_tied_to(K, Root), !,
    ck_into_tied(K, Root, R, assign('=', L, R), St0, St1), ck_base_use(L, St1, St).
ck_expr(assign('=', L, R), St0, St) :- ck_own_elem(L, K), !,                 % an element: an own slot; the old one freed by the lowering
    ck_into_own(none, R, assign('=', L, R), St0, St1, _), ck_lval_use(L, St1, St2), ck_dangle(St2, K, St).
ck_expr(assign('=', id(N), R), St0, St) :- ( ck_state(St0, N, _) ; ck_is_local(N) ), !,
    ck_expr(R, St0, St1),
    (   ck_is_param(N), ck_state(St1, N, borrow(N)) -> ck_rebind(St1, N, none, St2)   % a parameter re-assigned is a plain local from here
    ;   St2 = St1 ),
    ( ck_local_type(N, T) -> true ; T = unknown ),
    ( ck_state(St2, N, loose) -> ck_fail(unconsumed, N, assign('=', id(N), R)) ; true ),      % overwritten, its memory still nobody's
    (   T \== unknown, ck_borrowing_type(T), ck_borrows_from(R, St1, P) -> ck_rebind(St2, N, borrow(P), St)   % read before the parameter was unbound; a library object a trivial assignment copies (`sv = s', 0.216) as a pointer
    ;   T \== unknown, ck_is_pointer_type(T), ck_fresh_value(R) -> ck_rebind(St2, N, loose, St)
    ;   ck_state(St2, N, S), ( S = borrow(_) ; S = dangling(_) ; S == loose ) -> ck_rebind(St2, N, none, St), ( T \== unknown -> ck_no_owner_behind(N, T, R, assign('=', id(N), R)) ; true )
    ;   T \== unknown, \+ ck_state(St2, N, _) -> ck_no_owner_behind(N, T, R, assign('=', id(N), R)), St = St2
    ;   St = St2 ).
%% A STORE THROUGH A LIBRARY MEMBER (0.216): `m[k] = &x' and `v[0] = &y' write what a library object holds, through the
%% reference its member answers; the object holds the borrow as its own member calls do (ck_lib_store/4)
ck_expr(assign('=', call(id(G), [A0|As]), R), St0, St) :- atom(G), cpp_library_function(G), ck_lib_member(G), ck_lib_holder(A0, St0, Obj),
    ck_lib_obj_type(Obj, T), ck_holds_lib_borrow(T), !,
    ck_expr(R, St0, St1), ck_exprs([A0|As], St1, St2), ck_lib_self(Obj, St2, Self),
    ( ck_lib_no_store(G) -> Hs = [R] ; Hs = [R|As] ),   % through a lookup (`m.at(k) = &x') the key is not stored
    ( ck_lib_handed(Hs, Self, St2, P) -> ck_lib_store_into(Obj, P, join, assign('=', call(id(G), [A0|As]), R), St2, St) ; St = St2 ).
ck_expr(assign('=', L, R), St0, St) :- !,
    ( ck_path(R, RK), ck_by_value(R), ck_has_array_under(St0, RK) -> ck_fail(own_array_by_value, RK, assign('=', L, R)) ; true ),
    (   ccl_type_of(L, T), T \== unknown
    ->  (   ck_own_type(T) -> ck_into_own(none, R, assign('=', L, R), St0, St1, _)
        ;   ck_carries_type(T) -> ck_slot_name(L, Name), ck_where(L, St0, W), ck_into_plain(Name, R, assign('=', L, R), W, St0, St1)
        ;   ck_holds_lib_borrow(T) -> ck_into_lib_slot(L, R, assign('=', L, R), St0, St1)
        ;   ck_expr(R, St0, St1) )
    ;   ck_lib_obj_type(L, T), ck_carries_type(T) -> ck_ref_slot(L, R, assign('=', L, R), St0, St1)
    ;   ck_lib_obj_type(L, T), ck_holds_lib_borrow(T) -> ck_into_lib_slot(L, R, assign('=', L, R), St0, St1)
    ;   ck_expr(R, St0, St1) ),
    ck_lval_use(L, St1, St).
ck_expr(assign(_, L, R), St0, St) :- !, ck_expr(R, St0, St1), ( L = member(_, _) -> ck_expr(L, St1, St) ; ck_lval_use(L, St1, St) ).   % a compound assignment reads the member it writes
ck_expr(sizeof(_), St, St) :- !.
ck_expr(sizeof_type(_), St, St) :- !.
ck_expr(alignof_expr(_), St, St) :- !.                                 % GNU's `__alignof__(e)' (0.205): unevaluated, as sizeof's operand
ck_expr(offsetof(_, _), St, St) :- !.
ck_expr(contract_violation(_, _, _), St, St) :- !.
ck_expr(rtti(_), St, St) :- !.                                                     % RTTI's nodes (0.108)
ck_expr(eh_alloc(_), St, St) :- !.                                                 % an exception's storage, handed to __cxa_throw (0.108)
ck_expr(eh_throw(P, _, _), St0, St) :- !, ck_expr(P, St0, St).
ck_expr(eh_rethrow, St, St) :- !.
ck_expr(eh_terminate, St, St) :- !.
ck_expr(rtti_dyn(X), St0, St) :- !, ck_expr(X, St0, St).
ck_expr(dyncast(X, _, _, _), St0, St) :- !, ck_expr(X, St0, St).
ck_expr(dyncast_ref(X, _, _, _), St0, St) :- !, ck_expr(X, St0, St).
ck_expr(va_arg(AP, _), St0, St) :- !, ck_expr(AP, St0, St).
ck_expr(cond(C, A, B), St0, St) :- !, ck_expr(C, St0, St1), ck_expr(A, St1, StA), ck_expr(B, St1, StB), ck_merge(StA, StB, St).
ck_expr(bin('&&', A, B), St0, St) :- !, ck_expr(A, St0, St1), ck_expr(B, St1, St2), ck_merge(St1, St2, St).
ck_expr(bin('||', A, B), St0, St) :- !, ck_expr(A, St0, St1), ck_expr(B, St1, St2), ck_merge(St1, St2, St).
%% a statement expression: its last expression is its value, consumed when it
%% is an owner (clone's fresh copy leaves this way), else used
ck_expr(stmt_expr(block(Is)), St0, St) :- append(Init, [expr(L, E)], Is), !,
    ccl_scope_push, ck_bpath_push, ck_push(St0, St1), ck_stmts(Init, St1, St2), ck_line(L),
    ( St2 == dead -> St3 = dead ; ck_anchor_addrs(E, St2, St2a), ck_consume_or_use(E, St2a, St3) ),
    ck_scope_end(St3, St), ck_bpath_pop, ccl_scope_pop.
ck_expr(stmt_expr(B), St0, St) :- !, ck_stmt(B, St0, St).
ck_expr(compound_lit(T, init(Items)), St0, St) :- !, ck_init_slots(Items, T, none, St0, St).
ck_expr(E, St0, St) :- compound(E), !, E =.. [_|Args], ck_exprs(Args, St0, St).
ck_expr(_, St, St).
%% A PLAIN SLOT THROUGH A REFERENCE (0.217): `s.p = &x' over a reference parameter s lands outside -- `borrow_stored' for a
%% local's address; what else such a slot is given stays unchecked, as before
ck_ref_slot(L, R, Form, St0, St) :- ( ck_kind(R, St0, borrow(P)), ck_state(St0, P, anchor) -> ck_where(L, St0, W), ck_expr(R, St0, St1), ck_anchor_stored(W, P, Form, St1, St) ; ck_expr(R, St0, St) ).
%% A LIBRARY VALUE ASSIGNED TO A MEMBER OR AN ELEMENT (0.217): `s.sv = str', a trivial assignment of a view or of a pair
%% of pointers -- the place holds what the value carries, as a library member's store does (ck_lib_store_into/6)
ck_into_lib_slot(L, R, Form, St0, St) :- ck_expr(R, St0, St1),
    (   ck_lib_handed([R], none, St1, P) -> ck_lib_store_into(L, P, replace, Form, St1, St)
    ;   ck_where(L, St1, local(E1)) -> ck_unhold(E1, St1, St)
    ;   St = St1 ).
ck_vptr_slot(member(_, '$vptr')).
ck_vptr_slot(arrow(_, '$vptr')).
ck_unary_shape(neg(E), E). ck_unary_shape(not(E), E). ck_unary_shape(bitnot(E), E). ck_unary_shape(pos(E), E).
ck_unary_shape(deref(E), E). ck_unary_shape(cast(_, E), E). ck_unary_shape(postinc(E), E). ck_unary_shape(postdec(E), E).
ck_unary_shape(preinc(E), E). ck_unary_shape(predec(E), E).
ck_unary_shape(real_part(E), E). ck_unary_shape(imag_part(E), E).   % a complex's components (0.100)
%% A LIBRARY CLASS'S VALUE MAY BE MOVED: what it holds is libc++'s own discipline, as its pointers are
%% (ck_carries_) and its functions' bodies are (0.45) -- `auto r = std::move(q)' over a unique_ptr is the
%% ordinary way to use one, and the check has no owner behind it to move and needs none.
ck_moves_library(E) :- ccl_lang(cpp), catch(ccl_type_of(E, T), _, fail), T \== unknown, ccl_unref(T, T1),
    catch(ccl_resolve_type(T1, base(_, [struct(N, _)])), _, fail), ck_library_class(N), !.
%% the parameters of a function type, or of a pointer to one
ck_fn_params(T, Ps) :- ccl_resolve_type(T, T1), ( T1 = fn(_, Ps, _) -> true ; T1 = ptr(_, FT), ccl_resolve_type(FT, fn(_, Ps, _)) ).
ck_exprs([], St, St).
ck_exprs([A|As], St0, St) :- ( is_list(A) -> ck_exprs(A, St0, St1) ; ck_expr(A, St0, St1) ), ck_exprs(As, St1, St).
%% an assignment target: its base is used, not consumed
ck_lval_use(id(_), St, St) :- !.
ck_lval_use(member(E, _), St0, St) :- !, ck_base_read(E, St0, St).   % a member written: its base read, not what it held (0.217)
ck_lval_use(index(A, I), St0, St) :- !, ck_base_read(A, St0, St1), ck_expr(I, St1, St).
ck_lval_use(E, St0, St) :- ck_expr(E, St0, St).

%% arguments: first the callee's ties -- an argument for a parameter tied to
%% an earlier one lies within that argument -- then each in turn: the i-th is
%% consumed when the callee consumes it -- freed by free and fclose, moved by
%% an own parameter, the callee named or a function type (a pointer's) -- else
%% used; a borrow is not the callee's to take; a tied owner goes only to a
%% parameter tied itself
ck_args(Args, Callee, St0, St) :- ck_arg_ties(Args, Callee, St0), ck_args_(Args, Callee, 1, St0, St).
ck_arg_ties(Args, Callee, St) :- ( ck_callee_params(Callee, Ps) -> ck_arg_ties_(Ps, 1, Ps, Args, Callee, St) ; true ).
ck_arg_ties_([], _, _, _, _, _).
ck_arg_ties_([param(PT, _)|Rest], I, Ps, Args, Callee, St) :-
    (   ccl_tie_of(PT, Y), ck_param_index(Ps, Y, 1, J), ccl_nth(I, Args, A), ccl_nth(J, Args, B),
        ck_borrows_from(A, St, PA), ck_borrows_from(B, St, PB), \+ ck_within(St, PB, PA)
    ->  ck_name(A, N), ck_fail(tie_mismatch, N, call(Callee, Args))
    ;   true ),
    I1 is I + 1, ck_arg_ties_(Rest, I1, Ps, Args, Callee, St).
ck_callee_params(id(F), Ps) :- ccl_declared(F, T), ck_fn_params(T, Ps).
ck_callee_params(params(Ps), Ps).
ck_param_tied(Callee, I) :- ck_callee_params(Callee, Ps), ccl_nth(I, Ps, param(PT, _)), ccl_tie_of(PT, _).
ck_args_([], _, _, St, St).
ck_args_([A|As], Callee, I, St0, St) :-
    ( ck_path(A, AK), ck_by_value(A), ck_has_array_under(St0, AK) -> ck_fail(own_array_by_value, AK, call(Callee, [A|As])) ; true ),
    (   ck_consumes(Callee, I)
    ->  ( Callee = id(F), memberchk(F, [free, fclose]) -> How = free ; How = move ),
        ( Callee = id(_) -> Form = call(Callee, [A|As]) ; Form = call(pointer, [A|As]) ),
        ck_strip_move(A, A1),
        (   ck_owner_path(St0, A1, K)
        ->  ( How == move, ck_tied_to(K, _), \+ ck_param_tied(Callee, I) -> ck_fail(tie_escapes, K, Form) ; true ),
            ck_base_use(A1, St0, St1a), ck_consume(K, How, Form, St1a, St1, _)
        ;   ck_own_elem(A1, K) -> ck_expr(A1, St0, St1a), ck_dangle(St1a, K, St1)          % an element freed, or taken: the slot nulled by the lowering
        ;   A = move(_) -> ck_expr(A, St0, St1)
        ;   ck_path(A, K), ck_by_value(A), ck_own_under(St0, K, Fs), Fs \== [] -> ck_expr(A, St0, St1a), ck_move_out(St1a, Fs, Form, St1)
        ;   ck_borrows_from(A, St0, P), ck_state(St0, P, loose) -> ck_expr(A, St0, St1a), ck_consume_loose(St1a, P, St1)   % loose memory freed, or taken by an own parameter
        ;   ck_kind(A, St0, borrow(P)), \+ ck_library_root(P) -> ( A = id(N) -> true ; N = P ), ck_fail(borrow_consumed, N, Form)   % ... unless the borrow is of a LIBRARY OBJECT (0.94): a plain pointer a library class's member answers is a borrow of it (0.91, so an array's `end()' is no loose pointer), and what the program then does with it is the library's discipline -- `delete u.release()' is how a unique_ptr hands its object out, and the check refused it as a borrow freed
        ;   ck_expr(A, St0, St1) )
    ;   ck_strip_move(A, A1), ck_path(A1, K), ck_by_value(A1), ck_own_under(St0, K, Fs), Fs \== [], ck_param_by_value(Callee, I)   % a struct with owners handed by value: its fields go to the callee's copy
    ->  ck_expr(A1, St0, St1a), ck_move_out(St1a, Fs, call(Callee, [A|As]), St1)
    ;   ck_expr(A, St0, St1) ),
    (   ck_dying_param(Callee, I), ck_arg_base(A, K), ck_own_under(St1, K, Fs), Fs \== []                % a destructor ran: the object's own fields are gone
    ->  ck_set_all(St1, Fs, moved, St1m), ck_dangle_all(St1m, Fs, St1d)
    ;   ck_fresh_param(Callee, I), ck_arg_base(A, K), ck_own_under(St1, K, Fs), Fs \== []               % a constructor ran: the object's own fields are live (or null, as good)
    ->  ck_set_all(St1, Fs, live, St1d)
    ;   St1d = St1 ),
    ( ck_this_handed_unset(A, Callee, I, St1d, F) -> ck_fail(owner_unset, F, call(Callee, [A|As])) ; true ),
    I1 is I + 1, ck_args_(As, Callee, I1, St1d, St).
%% `this' HANDED OUT OF A CONSTRUCTOR (0.133; "not followed" since 0.37): a constructor's own fields start unset (the
%% `fresh' mark), and a function given `this' -- a method called in the body, a helper, `register(this)' -- takes the
%% object as complete, its owners live or null, and may read or free one that holds garbage: `Q::Q() { look(this); buf
%% = malloc(4); }' was accepted and crashed. Where an argument is `this' or a member of it, in a constructor, and the
%% callee's parameter is no constructor's or destructor's `this' (a base's or a member's constructor initializes what it
%% is given), every own field under it must hold a value already: an unset one is `owner_unset'.
ck_this_handed_unset(A, Callee, I, St, F) :- ck_arg_base(A, K), atom(K), ( K == this -> true ; sub_atom(K, 0, _, _, 'this->') ),
    \+ ck_fresh_param(Callee, I), \+ ck_dying_param(Callee, I),
    catch(ccl_declared(this, TT), _, fail), ck_this_marker(TT, fresh),
    ck_own_under(St, K, Fs), member(F, Fs), ck_state(St, F, unset), !.
ck_consumes(id(free), 1) :- !.
ck_consumes(id(fclose), 1) :- !.
ck_consumes(id(realloc), 1) :- !.                                    % the old block goes; the result is the new owner
ck_consumes(id(F), I) :- ccl_declared(F, T), ck_fn_params(T, Ps), ccl_nth(I, Ps, param(PT, _)), ck_own_type(PT).
ck_consumes(params(Ps), I) :- ccl_nth(I, Ps, param(PT, _)), ck_own_type(PT).
