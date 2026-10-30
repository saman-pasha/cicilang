%% ccl_cpp_overload.pl -- the candidates of a call and their ranking: the last resorts, the implicit copy and move
%% assignment, the abstract class, the object of a member call, promotions and conversions, aggregates, a member's
%% name and its default arguments. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they
%% stood there, in their order.

%% a method by its name and the ARGUMENTS: the overloads whose arity fits, the
%% one whose parameter types fit the arguments' best (cpp_pick/3); the base's
%% when the class has none
%% A CANDIDATE WHOSE ARGUMENT DOES NOT FIT IS TRIED LAST, after every template: libc++ writes
%% `explicit basic_string(const allocator_type &)' beside the constructor TEMPLATE that takes a `const char *', and
%% the plain one -- alone in fitting the ARITY -- won every `std::string s = "abc"', which came out empty. The
%% arity-only set is still the last resort, so nothing that resolved before resolves differently.
cpp_args_fit([], _) :- !.
cpp_args_fit(_, []) :- !.
cpp_args_fit([P|Ps], [A|As]) :- ( ( P = param(PT, _) ; P = param(PT, _, _) ) -> cpp_arg_fit(PT, A, S), S > 0 ; true ), cpp_args_fit(Ps, As).
%% THE ARITY ALONE IS THE LAST RESORT, but never a CLASS-typed parameter for an argument of ANOTHER known class:
%% that is no conversion this compiler makes, and libc++'s copy constructor writes `__rep_(__str.__rep_)', whose
%% `__rep' argument took `__rep(__short)' by arity and stored a union into a byte.
%% ... the parameter read IN ITS OWN CLASS'S WORDS (cpp_param_ref, the door cpp_arg_fit uses since 0.66) and the
%% argument's class through a move and, where the raw form cannot tell, the desugared one. libc++'s union-class
%% writes `__rep(__short __r)' with its holder's nested names, which the INFERENCE cannot resolve, so the clash
%% went unseen and `__rep_(std::move(__str.__rep_))' took `__rep(__short)' by arity -- a union into a byte.
cpp_args_no_clash([], _) :- !.
cpp_args_no_clash(_, []) :- !.
cpp_args_no_clash([P|Ps], [A|As]) :-
    \+ ( ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_nullptr_param(PT0), \+ cpp_null_arg(A) ),   % a `nullptr_t' parameter takes a null pointer constant or a `nullptr_t' value only
    \+ ( ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_param_ref(PT0, PT1), ccl_unref(PT1, PT), cpp_class_of_type(PT, C), cpp_init_arg_class(A, AC), AC \== C, \+ cpp_derives(AC, C),   % a DERIVED class is no clash (0.112); a REFERENCE to a class too (0.115, [over.ics.ref]): read with its reference, the class was never found, and `iota_view<int, int>::__iterator''s hidden friend `operator-' took two filter iterators, so filter_view was a sized_range after `views::iota'
         \+ cpp_converting_ctor(C, A), \+ cpp_conv_result(AC, PT, _) ),   % ... unless a CONVERTING CONSTRUCTOR bridges it, which cpp_copies_ then builds: `__reset_internal_buffer(__long)' is `__rep(__long)' -- or a CONVERSION OPERATOR of the argument's class (cpp_ref_args_)
    \+ ( ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_param_ref(PT0, PT), \+ cpp_class_of_type(PT, _), ccl_resolve_type(PT, RT), ( ccl_is_arith(RT) ; RT = ptr(_, _) ),
         cpp_init_arg_class(A, AC), \+ cpp_method(AC, operator(conv(_)), [], _, _) ),
    \+ ( ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_scalar_param_plain_arg(PT0, A) ),   % ... nor for a PLAIN struct or union argument, which has no conversion at all (0.127): `requires(F &&f, P &p, char &c) { f(p, c); }' held for `bool operator()(char, char)'   % and NEVER A SCALAR PARAMETER FOR A CLASS ARGUMENT without a conversion operator: `__s = std::copy(...)' on an ostreambuf_iterator took its `operator=(char)' by 
    \+ ( ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_param_ref(PT0, PT), \+ cpp_null_to_pointer(PT, A), ccl_resolve_type(PT, RT), cpp_arg_type(A, AT), ccl_unref(AT, AT1), cpp_scalar_mismatch(RT, AT1) ),
    \+ ( ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_param_ref(PT0, PT), cpp_param_takes_class(PT, C), cpp_arg_type(A, AT), AT \== unknown, ccl_unref(AT, AT1), \+ cpp_class_of_type(AT1, _),
         \+ cpp_converting_ctor(C, A) ),   % and NEVER A CLASS PARAMETER FOR A SCALAR ARGUMENT without a converting constructor: a program's friend `operator<<(ostream &, const P &)' took every `cout << x' the members were not exact for   % and NO POINTER FOR AN ARITHMETIC PARAMETER, nor the reverse (0.73's rule, here too): `__str.append(__first, __last)' took `append(const char *, size_type)' by arity, the pointer as the SIZE, and the library asked for a string the size of an address -- C++ takes the member template `append(_InputIterator, _InputIterator)'arity, and the struct was sign-extended to a byte
    cpp_args_no_clash(Ps, As).
cpp_method(C, M, Args, Name, Hops) :-
    cpp_class(C, cls(B, _, Ms, _, _, _)), length(Args, N),
    findall(Qs-Ps, ( member(method(_, Qs, _, M, Ps, _, _), Ms), cpp_arity_fits(Ps, N), cpp_const_viable(Qs), cpp_method_viable(C, Qs, Ps) ), Cands0),   % a member whose trailing requires-clause is unmet is no candidate, nor a non-const one on a const object
   
    %% IN ITS OWN CLASS: a candidate's parameter type is written in the class's words and read at the CALL SITE,
    %% where the context is the caller's or none at all -- libc++ gives `operator+=' an overload taking
    %% `initializer_list<value_type>', and scoring it outside the class made an instance keyed by the free name
    %% `value_type'. The rule a member template's signature has had since 0.51, for the plain overloads too.
    (   cpp_as_callee(C, ( findall(Q-Ps, ( member(Q-Ps, Cands0), cpp_args_fit(Ps, Args) ), [C1|Cs]), cpp_pick_q([C1|Cs], Args, Qs1-Ps1) ))
    ->  cpp_mangle_q(C, M, Qs1, Ps1, Name), Hops = [], cpp_use_member(C, Name)
    ;   cpp_member_template_call(C, M, [], Args, Name) -> Hops = []                              % a member template, deduced from the arguments
    ;   cpp_as_callee(C, ( findall(Q-Ps, ( member(Q-Ps, Cands0), cpp_args_no_clash(Ps, Args) ), [C1|Cs]), cpp_pick_q([C1|Cs], Args, Qs1-Ps1) ))   % THE ARITY ALONE IS THE LAST RESORT, after every template (0.63's rule, which cpp_ctor had and this road did not): basic_string's `compare(const _Tp &)' template takes a string_view, and the arity-only `compare(const basic_string &)' took it first and called itself
    ->  cpp_mangle_q(C, M, Qs1, Ps1, Name), Hops = [], cpp_use_member(C, Name)
    ;   cpp_as_callee(C, ( findall(Q-Ps, ( member(method(_, Q, _, M, Ps, true, _), Ms), length(Ps, Mx), Mx =< N ), [C1|Cs]), cpp_pick_q([C1|Cs], Args, Qs1-Ps1) ))   % AN ELLIPSIS IS C++'S WORST MATCH ([over.ics.ellipsis]), tried after every other overload and every template, which is how a detection's `static void __find_base(...)' answers where the template beside it deduces nothing -- the rule 0.47 gave a member TEMPLATE, for the plain overloads too
    ->  cpp_mangle_q(C, M, Qs1, Ps1, Name), Hops = [], cpp_use_member(C, Name)
    ;   B \== none, \+ '$cpp_vprim'(C, B), cpp_method(B, M, Args, Name, Hops1), cpp_base_hop(B, ['$base'|Hops1], Hops)
    ;   cpp_extra_method(C, M, Args, Name, Hops)
    ;   B \== none, '$cpp_vprim'(C, B), \+ '$cpp_vprim_ind'(C, B), cpp_method(B, M, Args, Name, Hops1), cpp_base_hop(B, ['$base'|Hops1], Hops) ).   % a primary virtual base moved first after the bases written after it (0.176; cpp_base_scope/2)
cpp_implicit_copy_ctor(C, Kind, Name) :- '$cpp_implicit_copy'(C, Kind, Name), !.
%% ... IN PROGRESS WHILE IT IS MADE ('$cpp_making', as every emission is; 0.206): a member's copy may copy the class again --
%% `struct Node { int v; std::vector<Node> kids; };' copies its vector, whose copy constructs each element by the class's
%% copy -- and the copy, noted after it is emitted, was made twice, which LLVM refused (`invalid redefinition')
cpp_implicit_copy_ctor(C, Kind, Name) :- cpp_making(icopy(C, Kind, Name0)), !, Name = Name0.
cpp_implicit_copy_ctor(C, Kind, Name) :- catch(cpp_type(base([], [typedef(C)]), _), _, true), fail.   % THE CLASS'S OWN DECLARATION FIRST (the type hook registers and emits a nested one, 0.63): basic_string's `__rep' got an implicit copy constructor while its union was never emitted, and the lowering read the source as `[0 x i8]'
cpp_implicit_copy_ctor(C, Kind, Name) :- cpp_class_l(C, cls(Base, _, _, Defaults, _)),
    ( Kind == copy -> PT = ref([const], base([], [typedef(C)])) ; PT = rref([], base([], [typedef(C)])) ),
    Ps = [param(PT, '$src')], M = ctor(0, [], Ps, memberwise('$src', Kind), block([])), cpp_mangle(C, C, Ps, Name),
    ( cpp_lib_class(C) -> Lib = yes ; Lib = no ),
    nb_getval('$cpp_making', K0), nb_setval('$cpp_making', [icopy(C, Kind, Name)|K0]),
    (   catch(\+ \+ cpp_as_lib(Lib, ( cpp_isolated(cpp_in_class(C, ( cpp_declare_members([M], C), cpp_member_fns([M], C, Base, Defaults, Fns) ))), cpp_add_instance_items(Fns) )), E, ( nb_setval('$cpp_making', K0), throw(E) ))
    ->  nb_setval('$cpp_making', K0)
    ;   nb_setval('$cpp_making', K0), fail ),
    assertz('$cpp_implicit_copy'(C, Kind, Name)), cpp_trace(implicit_copy(C, Kind)).   % NOTED WHEN EMITTED, NOT BEFORE (0.69's rule, in its fifth place, 0.93): the fact was asserted first, so a walk abandoned by a throw -- SFINAE, a candidate rejected -- left the name with no definition behind it, and libc++ 18's allocator<Rec>::construct met `undeclared(Rec.Rec.Rec_rr)' for a program's own struct
%% THE IMPLICIT COPY AND MOVE ASSIGNMENT ([class.copy.assign]): a class that writes no `operator=' assigns
%% MEMBERWISE, each member through its own -- a string member takes basic_string's, an array its bytes or its
%% elements, a base its sub-object -- and the move form moves each. Made once per class and kind
%% ('$cpp_implicit_assign') as a method written out would be, so the method road serves it; only a class with a
%% destructor asks (a plain aggregate assigns as C's struct does), and never one holding owners of its own, whose
%% plain copy the safe part refuses as ever. `vm[1] = Val{"alpha", 1}' on a map of the program's own struct.
cpp_implicit_assign(C, B, Name) :- ( B = move(_) -> Kind = move ; cpp_lvalue(B) -> Kind = copy ; Kind = move ), cpp_implicit_assign_(C, Kind, Name).
%% ... which a class has wherever it writes no copy or move assignment of its own ([class.copy.assign]/1): an
%% `operator=' over another type, or a template, is no such operator, and the implicit one is the exact match for a
%% value of the class ([over.match.best]). libc++ 18's back_insert_iterator writes `operator=(const value_type &)', and
%% `__out_it_ = std::move(__it)' -- basic_format_context::advance_to -- pushed the iterator's low byte into the output,
%% around every value std::format wrote (`implicitassign.cpp').
cpp_written_copy_assign(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, _, _, operator('='), [param(PT, _)], _, _), Ms),
    catch(cpp_in_class(C, cpp_type(PT, T)), _, fail), ccl_unref(T, T1), cpp_class_of_type(T1, C), !.
cpp_assign_from_own(B, C, B0) :- ( B = move(B0) -> true ; B0 = B ), cpp_class_of_type_of(B0, C), !.
%% AN OBJECT OF A DERIVED CLASS ASSIGNED TO A BASE'S IS ITS BASE SUB-OBJECT, the slicing copy ([class.copy.assign]: the implicit
%% `C &operator=(const C &)' binds the derived object's C part, [over.ics.ref]; 0.163) -- `sd2 = se' over `SE : SD' was refused
%% `assignment_to_a_class_with_destructor(SD)', the implicit memberwise assignment taking SD's own value only. Where the class
%% writes its copy or move `operator=', that road chooses as before.
cpp_assign_sliced(A1, B1, B) :- cpp_class_of_type_of(A1, C), ( B1 = move(X) -> Mv = yes ; X = B1, Mv = no ), cpp_class_of_type_of(X, DC), DC \== C,
    cpp_class_fits(DC, C), \+ cpp_written_copy_assign(C), !,
    Sub = deref(cast(ptr([], base([], [typedef(C)])), addr(X))), ( Mv == yes -> B = move(Sub) ; B = Sub ).
cpp_assign_sliced(_, B, B).
%% AN OVERLOADED ASSIGNMENT'S RIGHT OPERAND IS EVALUATED FIRST (C++17, [expr.ass]/1, [over.match.oper]/2: the operands of an
%% operator function are sequenced as the built-in operator's; 0.197): the call `F(&a, b)' of `a = b' or `a += b' evaluates
%% the object first, so where both operands can do something the right one is bound first, to a local of the parameter's
%% type -- a reference, or a scalar's value -- and handed on from it: `({ const T &$rhs = b; F(&a, $rhs); })'. A parameter
%% by value of a class keeps the call's order (Not done). `vs[next()] = std::to_string(next())' stored into `vs[1]', where
%% clang++ stores into `vs[2]', and `ms[next()] = std::to_string(ms.size())' read the size after the new element was made.
%% ... AND A PARAMETER BY VALUE OF A CLASS (0.198): the argument, the temporary the call's argument pass built (a copy, a
%% prvalue), is built first and the object bound after it, a reference `$lhs', the temporary handed on in place (the lowering's
%% ir_arg_in_place/4, its statement expression's own name): `left() = right();' over `S &operator=(S)' called left() first.
cpp_rhs_first(call(F, [A, B]), E) :- \+ cpp_fixed_operand(A), \+ cpp_fixed_operand(B), F = id(Name), atom(Name),
    ccl_declared(Name, fn(_, [_, P2|_], _)), ( P2 = param(PT0, _) ; P2 = param(PT0, _, _) ), once(ccl_resolve_type(PT0, PT)),
    ( PT = ref(_, _) ; PT = rref(_, _) ; PT = ptr(_, _) ; ccl_is_arith(PT) ), !,
    ccl_gensym('$rhs', N), ccl_declare(N, PT0),
    E = stmt_expr(block([declaration(0, none, PT0, [var(N, PT0, B)]), expr(0, call(F, [A, id(N)]))])).
cpp_rhs_first(call(F, [addr(X), B]), E) :- \+ cpp_fixed_operand(X), F = id(Name), atom(Name),
    ccl_declared(Name, fn(_, [_, P2|_], _)), ( P2 = param(PT0, _) ; P2 = param(PT0, _, _) ), once(ccl_resolve_type(PT0, PT)), cpp_class_of_type(PT, _),
    (   B = stmt_expr(block(Is)), append(Ss, [expr(L, id(T))], Is), Ss \== [], atom(T), ( sub_atom(T, 0, _, _, '$tmp') ; sub_atom(T, 0, _, _, '$copy') ) -> true
    ;   B = call(_, _), L = 0, ccl_gensym('$tmp', T), ccl_declare(T, PT0), Ss = [declaration(0, none, PT0, [var(T, PT0, B)])] ),   % a call's value, built in a local of its own through the hidden pointer
    catch(ccl_type_of(X, XT0), _, fail), XT0 \== unknown, ccl_unref(XT0, XT), !,
    ccl_gensym('$lhs', N), RT = ref([], XT), ccl_declare(N, RT),
    append(Ss, [declaration(0, none, RT, [var(N, RT, X)]), expr(0, call(F, [addr(id(N)), stmt_expr(block([expr(L, id(T))]))]))], Js), E = stmt_expr(block(Js)).
cpp_rhs_first(E, E).
%% an operand whose place or value nothing else that is evaluated can change: a name, a literal, `*this', a member, a cast or
%% the address of one of these
cpp_fixed_operand(E) :- atomic(E), !.
cpp_fixed_operand(id(_)) :- !.
cpp_fixed_operand(deref(id(this))) :- !.
cpp_fixed_operand(arrow(id(this), _)) :- !.
cpp_fixed_operand(addr(X)) :- !, cpp_fixed_operand(X).
cpp_fixed_operand(member(X, _)) :- !, cpp_fixed_operand(X).
cpp_fixed_operand(move(X)) :- !, cpp_fixed_operand(X).
cpp_fixed_operand(cast(_, X)) :- !, cpp_fixed_operand(X).
cpp_fixed_operand(ccast(_, _, X)) :- !, cpp_fixed_operand(X).
cpp_fixed_operand(E) :- functor(E, F, 1), memberchk(F, [int, uint, long, ulong, big, float, ldbl, chr, wchr, u8chr, u16chr, u32chr, str, wstr, u8str, u16str, u32str, sizeof_type, alignof_type, alignof_expr, imag, imagf, imagl]), !.
cpp_implicit_assign_(C, Kind, Name) :- '$cpp_implicit_assign'(C, Kind, Name), !.
cpp_implicit_assign_(C, Kind, Name) :- cpp_class_l(C, cls(Base, Data, _, Defaults, _)), \+ cpp_written_copy_assign(C),
    \+ cpp_holds_owners(base([], [typedef(C)])),
    ( Kind == copy -> PT = ref([const], base([], [typedef(C)])) ; PT = rref([], base([], [typedef(C)])) ),
    findall(expr(0, assign('=', Dst, Src)), ( cpp_assign_base_slot(C, Base, BN, BC), cpp_assign_base_dst(C, BC, BN, Dst), cpp_memberwise_base_src(C, BC, Kind, '$src', member(id('$src'), BN), Src) ), BStmts),   % THE BASE SUB-OBJECTS FIRST, each through its own assignment (0.135; [class.copy.assign]/12): the memberwise assignment took the class's own members alone, and a base's string was never copied
    findall(expr(0, assign('=', arrow(this, N), Src)), ( member(member(_, N, _), Data), N \== '$vptr', cpp_memberwise_src(Kind, member(id('$src'), N), Src) ), MStmts), append(BStmts, MStmts, Stmts),
    Ps = [param(PT, '$src')], M = method(0, [], ref([], base([], [typedef(C)])), operator('='), Ps, false, block(Stmts0)), append(Stmts, [return(0, deref(id(this)))], Stmts0),
    cpp_mangle(C, operator('='), Ps, Name),
    assertz('$cpp_implicit_assign'(C, Kind, Name)), cpp_trace(implicit_assign(C, Kind)),
    ( cpp_lib_class(C) -> Lib = yes ; Lib = no ),
    \+ \+ cpp_as_lib(Lib, ( cpp_isolated(cpp_in_class(C, ( cpp_declare_members([M], C), cpp_member_fns([M], C, Base, Defaults, Fns) ))), cpp_add_instance_items(Fns) )).
%% the base sub-objects a memberwise assignment assigns: the first base's where it has one (a virtual one where the table puts
%% it), each later base's with storage
cpp_assign_base_slot(_, Base, '$base', Base) :- Base \== none, \+ cpp_empty_class(Base).
cpp_assign_base_slot(C, _, Slot, B) :- '$cpp_base_slot'(C, B, Slot).
cpp_assign_base_dst(C, B, _, ccast(static, ref([], base([], [typedef(B)])), deref(id(this)))) :- '$cpp_nv_base'(C, B), !.   % a diamond's path: the object as the base (its slot is the `.nv' struct)
cpp_assign_base_dst(_, _, Slot, arrow(this, Slot)).
%% A CLASS WITH A TABLE POINTER, its own or a base's, or a virtual base, has no trivial copy assignment ([class.copy.assign]/9):
%% its implicit one copies the members and leaves the table pointer alone (0.135). Assigned as its bytes, `B &r = d; r = b;'
%% gave d the table of B and `r.f()' called B::f, a defect since 0.34; the byte copy now writes the data size alone, too.
cpp_dynamic_class(C) :- ( cpp_polymorphic(C) -> true ; '$cpp_vbase'(C) -> true ; '$cpp_lvb'(C, _, _) ).   % a later virtual base too (0.172)
cpp_extra_method(C, M, Args, Name, Hops) :- '$cpp_extra'(C, Es), member(E, Es), cpp_method(E, M, Args, Name, Hops0), !,   % an EMPTY base has no sub-object: the object's own address is the base's; one WITH storage is reached through its slot
    ( '$cpp_base_slot'(C, E, Slot) -> Hops = [Slot|Hops0] ; Hops = Hops0 ).
%% an abstract class (a pure virtual method no class of the chain overrides) is declared, never constructed
cpp_not_abstract(C) :- ( nb_current('$cpp_base_ctor', yes) -> true   % a BASE sub-object of an abstract class is constructed by every derived class ([class.abstract]/6: only a complete object of it is ill-formed) -- libc++'s __shared_ptr_emplace over __shared_weak_count
    ; cpp_abstract_class(C) -> cpp_refuse(0, pure_virtual(C)) ; true ).
%% ONE TEST for an abstract class, asked by the construction above and by the trait `__is_abstract' (0.112: the trait
%% asked only for a slot nothing implements, and the pure declaration counts as its implementation since 0.99, so
%% `std::is_abstract_v' was false for every class -- test/cpp/run/abstracttrait.cpp)
cpp_abstract_class(C) :- cpp_class_l(C, cls(_, _, _, _, Slots)), member(slot(M, K, _, _, _), Slots), ( \+ cpp_slot_impl(C, M, K, _) ; cpp_slot_pure(C, M, K) ), !.
cpp_base_ctor(B, BArgs, BName) :- nb_setval('$cpp_base_ctor', yes),
    ( catch(cpp_ctor(B, BArgs, BName), E, ( nb_setval('$cpp_base_ctor', no), throw(E) )) -> nb_setval('$cpp_base_ctor', no) ; nb_setval('$cpp_base_ctor', no), fail ).
cpp_slot_pure(C, M, K) :- cpp_class(C, cls(B, _, Ms, _, _, _)),   % the slot's implementation is the PURE declaration itself ([class.abstract]; 0.99: cpp_slot_impl answered it as an implementation, so an abstract class was constructed and the link named nothing)
    ( cpp_slot_method(C, Ms, M, K, Qs, _) -> memberchk(pure, Qs) ; B \== none, cpp_slot_pure(B, M, K) ).
cpp_ctor(C, _, _) :- \+ nb_current('$cpp_base_ctor', yes), '$cpp_bad_layout'(C, V), !, cpp_refuse(0, empty_virtual_base_moved(C, V)).   % A COMPLETE OBJECT OF A CLASS THIS MODEL LAYS OTHERWISE than the ABI (0.235; cpp_empty_vbases_laid/3): refused by name where it is built
cpp_ctor(C, [E0], Name) :- ( E0 = move(E) -> true ; E = E0 ), cpp_own_value(E, C, Cat), !,   % THE CLASS'S OWN VALUE takes its COPY or MOVE constructor, written or implicit, and never another constructor taking a class ([over.best.ics]): `ostreambuf_iterator(ostream_type &)' had taken an ostreambuf_iterator in the copy road's aggregate, and the stream buffer's pointer was the iterator's bytes
    cpp_not_abstract(C),
    (   cpp_class(C, cls(_, _, Ms, _, _, _)), findall(Ps, ( member(ctor(_, Qs, Ps, _, _), Ms), cpp_copy_or_move(C, Ps), cpp_method_viable(C, Qs, Ps) ), Cands), Cands \== []
    ->  cpp_as_callee(C, cpp_pick(Cands, [E0], Ps)), cpp_mangle(C, C, Ps, Name), cpp_use_member(C, Name)
    ;   ( ( E0 = move(_) ; Cat == rvalue ) -> cpp_implicit_rvalue_kind(C, Kind) ; Kind = copy ), cpp_implicit_copy_ctor(C, Kind, Name) ).
cpp_ctor(C, Args, Name) :-
    cpp_not_abstract(C), cpp_class(C, cls(_, _, Ms, _, _, _)), length(Args, N),
    cpp_as_callee(C, findall(Ps, ( member(ctor(_, Qs, Ps, _, _), Ms), cpp_arity_fits(Ps, N), cpp_method_viable(C, Qs, Ps), cpp_args_fit(Ps, Args) ), Cands)), Cands \== [], !,   % in its own class, as above; a constructor whose trailing requires-clause is unmet is no candidate (0.112, 0.110's rule for a method)
    cpp_as_callee(C, cpp_pick(Cands, Args, Ps)), cpp_mangle(C, C, Ps, Name), cpp_use_member(C, Name).
cpp_ctor(C, Args, Name) :- \+ ( Args = [E], cpp_class_of_type_of(E, C) ), cpp_member_template_ctor(C, Args, Name), !.   % a constructor template, deduced -- never for the class's own value: that is the copy (implicit, or the class's own), as C++ prefers the non-template
cpp_ctor(C, [E0], Name) :- ( E0 = move(E) -> cpp_implicit_rvalue_kind(C, Kind) ; E = E0, Kind = copy ), cpp_class_of_type_of(E, C), \+ cpp_written_copy_ctor(C), !,   % THE IMPLICIT COPY (OR MOVE) CONSTRUCTOR, memberwise, made on demand ([class.copy.ctor]): optional's `__optional_iterator_base' inherits its base's constructors, which brings no copy constructor, and the memberwise copy of `optional' asked its base for one
    cpp_implicit_copy_ctor(C, Kind, Name).
%% ... AND A DERIVED OBJECT COPIES ITS BASE SUB-OBJECT through it ([dcl.init]/17.6.2, the reference binding to the base;
%% 0.135): `B b = d;' over a D derived from B, where B writes no copy constructor (a written one takes it above, by the fit),
%% was `no_constructor(B, 1)' -- the implicit copy asked the argument to be of the class itself. The copy stores B's own table.
cpp_ctor(C, [E0], Name) :- ( E0 = move(E) -> true ; E = E0 ), cpp_class_of_type_of(E, D), D \== C, cpp_derives(D, C),
    \+ ( cpp_class(C, cls(_, _, Ms, _, _, _)), member(ctor(_, _, Ps, _, _), Ms), cpp_copy_or_move(C, Ps) ), !,
    cpp_not_abstract(C), ( E0 = move(_) -> cpp_implicit_rvalue_kind(C, Kind) ; cpp_arg_lvalue(E) -> Kind = copy ; cpp_implicit_rvalue_kind(C, Kind) ), cpp_implicit_copy_ctor(C, Kind, Name).
cpp_ctor(C, Args, Name) :-                                                                      % nothing fitted, no template held: the arity alone, as it always was
    cpp_not_abstract(C), cpp_class(C, cls(_, _, Ms, _, _, _)), length(Args, N),
    cpp_as_callee(C, findall(Ps, ( member(ctor(_, Qs, Ps, _, _), Ms), cpp_arity_fits(Ps, N), cpp_method_viable(C, Qs, Ps), cpp_args_no_clash(Ps, Args) ), Cands)), Cands \== [], !,
    cpp_pick(Cands, Args, Ps), cpp_mangle(C, C, Ps, Name), cpp_use_member(C, Name).
cpp_ctor(C, [], Name) :- cpp_implicit_ctor_needed(C), cpp_mangle(C, C, [], Name).
%% the class's own value, and its category: read off the raw form where the inference types it, else off the
%% DESUGARED one (0.66's rule for a member initialized from a call): pair's piecewise constructor hands
%% `std::forward<_Args2>(std::get<_I2>(__second_args))' -- a `Val &&' -- to Val's member initializer
cpp_own_value(E, C, Cat) :- cpp_class_of_type_of(E, C), !, ( cpp_arg_lvalue(E) -> Cat = lvalue ; Cat = rvalue ).   % A MEMBER OF AN XVALUE is an xvalue ([expr.ref]/6; 0.121): `std::forward<A>(x).value' of an rvalue is moved from, the copy constructor took it before
cpp_own_value(E, C, Cat) :- cpp_init_arg_class(E, C), ( cpp_arg_lvalue(E) -> Cat = lvalue ; Cat = rvalue ).
%% ... AND BY THE OBJECT'S CONSTNESS, where the parameters tie: a non-const object takes the non-const overload, a
%% const one the const overload ([over.match.best], the implicit object parameter), the caller having said which
%% through cpp_method_on; unsaid, the first declared, as before
cpp_pick_q([Q-Ps], _, Q-Ps) :- !.
cpp_pick_q(Cands, Args, Best) :- cpp_best_q(Cands, Args, none, -1, Best).
cpp_best_q([], _, Best, _, Best).
cpp_best_q([Q-Ps|Cs], Args, B0, S0, Best) :- cpp_score(Ps, Args, S1), cpp_const_bonus(Q, Bonus), cpp_ref_bonus(Q, RB), cpp_constraint_count(Q, CB), S is (S1 * 2 + Bonus + RB) * 64 + CB, ( S > S0 -> cpp_best_q(Cs, Args, Q-Ps, S, Best) ; S =:= S0, B0 = _-Ps0, cpp_nearer_bases(Ps, Ps0, Args) -> cpp_best_q(Cs, Args, Q-Ps, S, Best) ; cpp_best_q(Cs, Args, B0, S0, Best) ).
%% ... AND, LAST, BY ITS CONSTRAINTS ([over.match.best]/2.6; 0.112): of two members that tie, the one whose trailing
%% requires-clause holds -- the only kind still a candidate -- is the more constrained, counted by conjuncts as a partial
%% specialization's are (cpp_constraint_count). libc++'s iota_view writes `constexpr auto end() const' beside
%% `constexpr __iterator end() const requires same_as<_Start, _BoundSentinel>', and the first declared answered a
%% __sentinel the range-for's `__e' could not hold beside `__b'
%% ... AND BY THE OBJECT'S VALUE CATEGORY ([over.match.funcs]/5): an lvalue takes `&' (never `&&'), an rvalue `&&' (never `&'); an unqualified member takes both
cpp_ref_bonus(Qs, B) :- cpp_obj_cat_now(Cat), Cat \== none, memberchk(refq(R), Qs), !, ( R == Cat -> B = 1 ; B = -100 ).
cpp_ref_bonus(_, 0).
cpp_obj_cat_now(K) :- ( nb_current('$cpp_obj_cat', K0) -> K = K0 ; K = none ).
cpp_with_obj_cat(K, Goal) :- cpp_obj_cat_now(K0), nb_setval('$cpp_obj_cat', K),
    ( catch(Goal, E, ( nb_setval('$cpp_obj_cat', K0), throw(E) )) -> nb_setval('$cpp_obj_cat', K0) ; nb_setval('$cpp_obj_cat', K0), fail ).
cpp_obj_cat(move(_), rvalue) :- !.
cpp_obj_cat(call(scoped(_, move), _), rvalue) :- !.
cpp_obj_cat(Obj, lvalue) :- cpp_lvalue(Obj), !.
cpp_obj_cat(stmt_expr(_), rvalue) :- !.
cpp_obj_cat(compound_lit(_, _), rvalue) :- !.
cpp_obj_cat(call(id(F), _), rvalue) :- atom(F), ccl_declared(F, fn(R, _, _)), \+ R = ref(_, _), !.
cpp_obj_cat(_, none).
%% A NON-CONST MEMBER IS NO CANDIDATE ON A CONST OBJECT ([over.match.funcs]/5: its implicit object parameter, `C &',
%% does not bind a const lvalue) -- a static member and one with an explicit object parameter excepted. It was only
%% scored lower (cpp_const_bonus), so a class whose const member's requires-clause is unmet still answered through
%% the non-const one: `range<const transform_view<filter_view<...>>>' held by transform_view's `begin()', and
%% take_view's `end() const requires range<const _View>' was walked and refused no_constructor (0.113). `constmember.cpp'.
cpp_const_viable(Qs) :- ( cpp_obj_const_now(const) -> ( memberchk(const, Qs) ; memberchk(static, Qs) ; memberchk(explicit_this(_, _), Qs) ; memberchk(closure, Qs) ), ! ; true ).   % a closure's operator() is const unless `mutable' ([expr.prim.lambda.closure]/5), which this compiler does not mark (`mutable' is read and dropped)
cpp_const_bonus(Qs, 1) :- cpp_obj_const_now(K), K \== none, ( K == const -> memberchk(const, Qs) ; \+ memberchk(const, Qs) ), !.
cpp_const_bonus(_, 0).
cpp_method_on(Obj, C, M, Args, Name, Hops) :- cpp_obj_const(Obj, K), cpp_obj_cat(Obj, Cat), cpp_with_obj_expr(Obj, cpp_with_obj_cat(Cat, cpp_with_obj_const(K, cpp_method(C, M, Args, Name, Hops)))).
cpp_method_on_ptr(P, C, M, Args, Name, Hops) :- cpp_ptr_const(P, K), cpp_with_obj_expr(deref(P), cpp_with_obj_cat(lvalue, cpp_with_obj_const(K, cpp_method(C, M, Args, Name, Hops)))).
%% THE OBJECT EXPRESSION A MEMBER CALL IS MADE ON (0.117), for a member with an explicit object parameter ([dcl.fct]/6, C++23's
%% `this Self &&self'): the object is the call's first argument, and the template parameter of its type is deduced from it
%% as from any argument -- an lvalue gives `Self = D &', a prvalue `D', the DERIVED class the call was made on, which is what
%% makes the explicit object parameter the CRTP's replacement
cpp_obj_expr_now(O) :- nb_current('$cpp_obj_expr', O0), O0 \== none, !, O = O0.
cpp_with_obj_expr(O, Goal) :- ( nb_current('$cpp_obj_expr', O0) -> true ; O0 = none ), nb_setval('$cpp_obj_expr', O),
    ( catch(Goal, E, (nb_setval('$cpp_obj_expr', O0), throw(E))) -> nb_setval('$cpp_obj_expr', O0) ; nb_setval('$cpp_obj_expr', O0), fail ).
cpp_obj_const_now(K) :- ( nb_current('$cpp_obj_const', K0) -> K = K0 ; K = none ).
cpp_with_obj_const(K, Goal) :- cpp_obj_const_now(K0), nb_setval('$cpp_obj_const', K),
    ( catch(Goal, E, (nb_setval('$cpp_obj_const', K0), throw(E))) -> nb_setval('$cpp_obj_const', K0) ; nb_setval('$cpp_obj_const', K0), fail ).
cpp_obj_const(arrow(P, M), K) :- cpp_ptr_const(P, K0), K0 \== none, cpp_member_own_const(ptr(P), M, K1), !, ( K1 == inherit -> K = K0 ; K = K1 ).   % A MEMBER OF A CONST OBJECT IS CONST ([dcl.type.cv]): `__table_.begin()' inside `unordered_map::begin() const' is the const begin, where the member's own type -- no const of its own -- chose the non-const one and a `__hash_iterator' was stored as a const one
cpp_obj_const(member(O, M), K) :- cpp_obj_const(O, K0), K0 \== none, cpp_member_own_const(obj(O), M, K1), !, ( K1 == inherit -> K = K0 ; K = K1 ).
cpp_obj_const(Obj, K) :- ( ccl_type_of(Obj, T), T \== unknown -> ( cpp_type_const(T) -> K = const ; K = nonconst ) ; K = none ).
%% ... unless the member is a REFERENCE, whose referent keeps its own constness; a member the class's own list does not hold (a base's) inherits
cpp_member_own_const(ptr(P), M, K) :- !, ( ccl_type_of(P, T), T \== unknown, ccl_resolve_type(T, ptr(_, PT)), cpp_class_of_type(PT, C) -> cpp_member_own_const_(C, M, K) ; K = inherit ).
cpp_member_own_const(obj(O), M, K) :- ( cpp_class_of_type_of(O, C) -> cpp_member_own_const_(C, M, K) ; K = inherit ).
cpp_member_own_const_(C, M, K) :- ( cpp_class_l(C, cls(_, Data, _, _, _)), member(member(T, M, _), Data), ( T = ref(_, _) ; T = rref(_, _) ) -> ( cpp_type_const(T) -> K = const ; K = nonconst ) ; K = inherit ).
cpp_ptr_const(P, K) :- ( ccl_type_of(P, T), T \== unknown, ccl_resolve_type(T, ptr(_, PT)) -> ( cpp_type_const(PT) -> K = const ; K = nonconst ) ; K = none ).
cpp_type_const(base(Q, _)) :- memberchk(const, Q), !.
cpp_type_const(ref(_, T)) :- !, cpp_type_const(T).
cpp_type_const(rref(_, T)) :- !, cpp_type_const(T).
cpp_pick([Ps], _, Ps) :- !.
cpp_pick(Cands, Args, Ps) :- cpp_best(Cands, Args, none, -1, Ps).
cpp_best([], _, Best, _, Best).
cpp_best([Ps|Cs], Args, B0, S0, Best) :- cpp_score(Ps, Args, S), ( S > S0 -> cpp_best(Cs, Args, Ps, S, Best) ; S =:= S0, B0 \== none, cpp_nearer_bases(Ps, B0, Args) -> cpp_best(Cs, Args, Ps, S, Best) ; cpp_best(Cs, Args, B0, S0, Best) ).
%% OF TWO THAT TIE, THE ONE TAKING A DERIVED CLASS AS A NEARER BASE ([over.ics.rank]/4.4.4; 0.206), the template road's demerit per step
%% (cpp_base_steps_demerit/2): the steps summed over the arguments, fewer wins -- `f(input_iterator_tag)' beside
%% `f(forward_iterator_tag)' took a `random_access_iterator_tag' through the first declared
cpp_nearer_bases(Ps, Ps0, Args) :- cpp_base_steps_sum(Ps, Args, 0, K), cpp_base_steps_sum(Ps0, Args, 0, K0), K < K0.
cpp_base_steps_sum([], _, K, K) :- !.
cpp_base_steps_sum(_, [], K, K) :- !.
cpp_base_steps_sum([P|Ps], [A|As], K0, K) :-
    (   ( P = param(PT, _) ; P = param(PT, _, _) ), catch(cpp_param_ref(PT, PT1), _, fail), ccl_unref(PT1, PT2), cpp_class_of_type(PT2, C),
        catch(cpp_arg_type(A, AT), _, fail), ccl_unref(AT, AT1), cpp_class_of_type(AT1, D), D \== C, cpp_base_steps(D, C, 0, N)
    ->  K1 is K0 + N ; K1 = K0 ),
    cpp_base_steps_sum(Ps, As, K1, K).
cpp_score([], _, 0) :- !.
cpp_score(_, [], 0) :- !.
cpp_score([P|Ps], [A|As], S) :- ( P = param(PT, _) ; P = param(PT, _, _) ), !, cpp_arg_fit(PT, A, S1), cpp_score(Ps, As, S2), S is S1 + S2.
%% how an argument fits a parameter: the same class 3, both pointers 2, both arithmetic 2, unknown 1, else 0
%% THROUGH AN ALIAS TO ITS REFERENCE first: libc++ writes `push_back(const_reference)' beside
%% `push_back(value_type &&)', and no value category can be read off the alias's own name -- the const lvalue
%% overload won a temporary, which then had to be COPIED into it, and a class with an owner had two holders.
cpp_arg_fit(PT0, A, S) :- cpp_nullptr_param(PT0), !, ( cpp_null_arg(A) -> S = 3 ; S = 0 ).   % `nullptr_t' takes a null pointer constant, or a value of its own type (0.206), and nothing else ([conv.ptr]): unique_ptr's `reset(nullptr_t = nullptr)' sits beside its `reset(_Pp)' template, and resolved to `void *' it took every pointer
cpp_arg_fit(PT0, A, S) :- cpp_param_ref(PT0, PT), cpp_arg_fit_(PT, A, S).
cpp_nullptr_param(base(_, [typedef(nullptr_t)])).
cpp_nullptr_param(base(_, [typedef(scoped(_, nullptr_t))])).
cpp_nullptr_param(base(_, [nullptr_t])).   % ... and the type resolved, a template parameter bound to it (0.206)
cpp_null_constant(nullptr).
cpp_null_constant(int(0)).
%% A NULL POINTER VALUE AS AN ARGUMENT: a null pointer constant, or a value of `std::nullptr_t' (0.206; [conv.ptr]/1: a prvalue of
%% the type is one, and an lvalue converts to it) -- `std::nullptr_t n; f(n)' took no `f(std::nullptr_t)'
cpp_null_arg(A) :- cpp_null_constant(A), !.
cpp_null_arg(A) :- catch(cpp_arg_type(A, T), _, fail), ccl_unref(T, T1), ccl_nullptr_type(T1).
%% A NULL POINTER CONSTANT CONVERTS TO ANY POINTER ([conv.ptr]/1), which only `nullptr_t' knew: libc++'s
%% stable_partition writes `pair<value_type *, ptrdiff_t> __p(0, 0);' and the pair's `(const _T1 &, const _T2 &)'
%% constructor was refused for the literal 0, no constructor of arity two was left, and every algorithm that
%% buffers -- stable_partition, inplace_merge, stable_sort -- stopped at `no_constructor(pair..., 2)'
cpp_null_to_pointer(PT, A) :- cpp_null_constant(A), ccl_unref(PT, PT1), ccl_resolve_type(PT1, RP), ( RP = ptr(_, _) ; RP = memptr(_, _, _) ), !.
%% ... AND THROUGH THE CLASS'S OWN WORDS: a parameter type is written there (`__rep(__long __r)' names two of
%% `basic_string''s nested classes by their short names), and the fit test resolves with the INFERENCE, which knows
%% typedefs and tags but no class scope. cpp_type/2 is the door that does, and the caller has put us in the class.
cpp_param_ref(T0, T) :- ( catch(cpp_type(T0, T1), _, fail) -> true ; T1 = T0 ), cpp_param_ref_(T1, T).
cpp_param_ref_(T0, T) :- \+ ( T0 = ref(_, _) ; T0 = rref(_, _) ), ccl_resolve_type(T0, R), ( R = ref(_, _) ; R = rref(_, _) ), !, T = R.
cpp_param_ref_(T, T).
cpp_arg_fit_(PT, A, 0) :- cpp_category_mismatch(PT, A), !.                                    % an rvalue reference binds no lvalue, a plain one no rvalue
cpp_arg_fit_(PT, A, S) :- cpp_fn_template_ref(A, F), !, ( cpp_fn_target(PT, FnT), cpp_target_deduces(F, FnT) -> S = 3 ; S = 0 ).   % a template's name: exact where the parameter's target type deduces it, no fit otherwise
cpp_arg_fit_(PT, init(Items), S) :- !, ccl_unref(PT, PT1),                                   % A BRACED LIST fits a class it constructs (an aggregate, or a constructor over its items) and an initializer_list<T> whose every item fits T; nothing else ([over.ics.list])
    (   cpp_class_of_type(PT1, C)
    ->  findall(E, member(item(_, E), Items), Es),
        (   '$cpp_inst'(C, inst(initializer_list, [T])) -> ( forall(member(E, Es), cpp_il_elem_fits(T, E)) -> S = 3 ; S = 0 )   % the BETTER list conversion ([over.ics.rank]/3.1; 0.112): `vector(initializer_list<int>)' over `vector(const vector &)' for `{1, 2, 3}', which had tied at 2 and gone to the first declared
        ;   cpp_aggregate_class(C) -> S = 2
        ;   catch(cpp_ctor(C, Es, _), _, fail) -> S = 2
        ;   S = 0 )
    ;   S = 0 ).
cpp_arg_fit_(PT, A, S) :-
    (   cpp_arg_type(A, AT)
    ->  ccl_unref(PT, PT1), ccl_unref(AT, AT1),
        (   cpp_class_of_type(PT1, C), cpp_class_of_type(AT1, C) -> ( PT = rref(_, _), \+ cpp_arg_lvalue(A) -> S = 4 ; S = 3 )   % an rvalue takes the move constructor first; so does a member of an xvalue (0.121)
        ;   cpp_class_of_type(PT1, C), cpp_class_of_type(AT1, AC), AC \== C, cpp_derives(AC, C) -> S = 2                % A DERIVED OBJECT for a base's reference or value ([over.ics.ref]/1, [over.best.ics]/6; 0.112): a derived-to-base Conversion, worse than the class itself. Scored 0, libc++'s `__save_flags<_CharT, _Traits> __sf(__is)' over an istream took the PRIVATE copy constructor, declared and never defined, where `explicit __save_flags(basic_ios &)' is meant -- the link named it
        ;   cpp_class_of_type(PT1, C), cpp_class_of_type(AT1, AC), AC \== C, cpp_conv_result(AC, PT1, _) -> S = 2                % a class with a conversion operator to the parameter's class
        ;   ccl_resolve_type(PT1, RT1), ccl_resolve_type(AT1, RT2), cpp_bare_type(RT1, BT), cpp_bare_type(RT2, BT) -> ( PT = rref(_, _), \+ cpp_arg_lvalue(A) -> S = 4 ; S = 3 )   % the SAME type, registered class or not, in one spelling (`unsigned' is `unsigned int'): two plain structs alike fit each other
        ;   cpp_class_of_type(AT1, AC), \+ cpp_class_of_type(PT1, _), cpp_conv_result(AC, PT1, RCT)   % a class with a conversion operator to the parameter's kind
        ->  ( ccl_resolve_type(PT1, RP), cpp_bare_type(RP, B1), cpp_bare_type(RCT, B2), B1 == B2 -> S = 2 ; S = 1 )
        ;   cpp_pointerish(PT1), cpp_null_constant(A) -> S = 2                        % a literal 0 IS a pointer's value
        ;   cpp_pointerish(PT1), ccl_nullptr_type(AT1) -> S = 2                       % ... and so is a `std::nullptr_t' (0.206)
        ;   ccl_resolve_type(PT1, PM), PM = memptr(_, _, _), ccl_resolve_type(AT1, AM), AM = memptr(_, _, _) -> cpp_memptr_fit(PM, AM, S)
        ;   cpp_pointerish(PT1), cpp_pointerish(AT1) -> ( cpp_pointer_fit(PT1, AT1) -> ( cpp_void_for_class(PT1, AT1) -> S = 1 ; S = 2 ) ; S = 0 )   % B * to A * is a better conversion than B * to void * ([over.ics.rank]/4.2; 0.117): `cout << in.rdbuf()' took the member over `const void *', declared first, and printed the filebuf's address
        ;   ccl_is_arith(PT1), ccl_is_arith(AT1) -> cpp_arith_fit(PT1, AT1, S)
        ;   S = 0 )
    ;   S = 1 ).
%% A PROMOTION IS BETTER THAN A CONVERSION ([over.ics.rank]/4.2, [conv.prom], [conv.fpprom]; 0.127): 2.5 against 2, so
%% `p(short)' beside `p(long)' and `p(int)' calls `p(int)', and `std::cout << c' of an enum is the int inserter. Both
%% were 2, the first declared won -- `p(long)', and for an enum basic_ostream's FIRST member, `operator<<(bool)'. A
%% SCOPED enum converts to no other arithmetic type ([dcl.enum]/10): no fit.
cpp_arith_fit(PT, AT, 0) :- ccl_resolve_type(AT, base(_, [E])), compound(E), ( E = enum(Tag, _) ; E = enum_class(Tag, _) ), ccl_scoped_enum(Tag), !.
cpp_arith_fit(PT, AT, S) :- ( cpp_promotes_to_underlying(AT, PT) -> S = 2.75 ; cpp_promotes_to(AT, PT) -> S = 2.5 ; S = 2 ).   % an enum with a FIXED underlying type promotes better to that type than to its promoted type ([over.ics.rank]/4.2): `std::cout << e' of an `enum : unsigned char' is the unsigned char inserter
cpp_promotes_to_underlying(AT, PT) :- ccl_resolve_type(AT, base(_, [E])), compound(E), ccl_enum_spec_members(E, Ms), is_list(Ms), memberchk(enum_base(B), Ms), !,
    ccl_resolve_type(B, RB), cpp_bare_type(RB, BB), ccl_resolve_type(PT, RP), cpp_bare_type(RP, BB).
cpp_promotes_to(AT, PT) :- ccl_resolve_type(PT, RP), cpp_bare_type(RP, BP), cpp_promotion_target(AT, T), ccl_resolve_type(T, RT), cpp_bare_type(RT, BP), !.
cpp_promotion_target(AT, T) :- ccl_resolve_type(AT, RA), RA = base(_, S),
    (   S == [float] -> T = base([], [double])                                                                        % [conv.fpprom]
    ;   S = [E], compound(E), ccl_enum_spec_members(E, Ms) -> ccl_enum_underlying(Ms, U), ( T = U ; ccl_promote(U, T) )   % an enum: its underlying type, and that promoted ([conv.prom]/4)
    ;   ccl_is_integer(RA), \+ ccl_is_bitint(RA), ccl_promote(RA, T), T \== RA ).                                        % the integral promotions
%% A POINTER TO MEMBER FOR ONE (0.181): the same type is exact whatever its parameters are named (`int (A::*)(int)'
%% written names its parameter `anon', `&A::f' has the member's own names), and a member function type of other
%% qualifiers converts to none ([conv.mem]): `g(&A::cf)' is `g(int (A::*)(int) const)', where every pointer to member fit
%% every other at 2 and the first `g' declared took it. Any other pair keeps that fit.
cpp_memptr_fit(PM, AM, S) :- ( cpp_memptr_key_same(PM, AM) -> S = 3 ; cpp_memptr_quals_differ(PM, AM) -> S = 0 ; S = 2 ).
cpp_memptr_key_same(memptr(PC, _, PT), memptr(AC, _, AT)) :- catch(( cpp_type_key(memptr(PC, [], PT), K), cpp_type_key(memptr(AC, [], AT), K) ), _, fail), !.
cpp_memptr_quals_differ(memptr(_, _, PT), memptr(_, _, AT)) :- ccl_resolve_type(PT, fn(_, _, PV)), ccl_resolve_type(AT, fn(_, _, AV)), cpp_fn_q(PV, _, PQs), cpp_fn_q(AV, _, AQs), PQs \== AQs.
cpp_void_for_class(P, A) :- ccl_resolve_type(P, ptr(_, PE)), ccl_resolve_type(PE, base(_, [void])), ccl_resolve_type(A, ptr(_, AE)), cpp_pointee_kind(AE, class(_)), !.
cpp_pointerish(T) :- ccl_resolve_type(T, R), ( R = ptr(_, _) ; R = arr(_, _) ; R = fn(_, _, _) ; R = memptr(_, _, _) ), !.   % a function decays to a pointer; a pointer to member takes a null pointer constant ([conv.mem]/1: `_CmpUnspecifiedParam(int _CmpUnspecifiedParam::*)' is how <compare> takes the literal 0 of `o < 0')
%% ... BY WHAT THEY POINT TO: `void *' takes any object pointer, a FUNCTION pointer takes only a function, a pointer
%% to a class one to a class; the rest -- the scalars, `char *' to `const char *' -- fit as they always did. Scored
%% as any two pointers, basic_ostream's manipulator inserter, `operator<<(basic_ostream &(*)(basic_ostream &))',
%% took `cout << "hello"' and the literal was CALLED.
cpp_pointer_fit(P, A) :- ccl_resolve_type(P, ptr(_, PE)), ccl_resolve_type(A, AR), ( AR = ptr(_, AE) ; AR = arr(_, AE) ; AR = fn(_, _, _), AE = AR ), !, cpp_pointee_fit(PE, AE).
cpp_pointer_fit(_, _).
cpp_pointee_fit(PE, AE) :- ccl_resolve_type(AE, fn(_, _, _)), !, ccl_resolve_type(PE, fn(R1, Ps1, V1)), ccl_resolve_type(AE, fn(R2, Ps2, V2)), cpp_fn_types_agree(fn(R1, Ps1, V1), fn(R2, Ps2, V2)).   % A FUNCTION FITS ONLY A FUNCTION POINTER: `cout << std::hex' went to the character-string inserter and printed the manipulator's code bytes; `cin >> std::noskipws' to the char extractor, writing into code
cpp_pointee_fit(PE, AE) :- ccl_resolve_type(PE, base(_, [void])), !, \+ ccl_resolve_type(AE, fn(_, _, _)).
cpp_pointee_fit(PE, AE) :- ccl_resolve_type(PE, fn(R1, Ps1, V1)), !, ccl_resolve_type(AE, fn(R2, Ps2, V2)), cpp_fn_types_agree(fn(R1, Ps1, V1), fn(R2, Ps2, V2)).   % a function pointer takes only a function OF ITS TYPE: `std::hex' is `ios_base &(ios_base &)', and the inserter over `basic_ostream &(*)(basic_ostream &)' would call it on the wrong sub-object
cpp_pointee_fit(PE, AE) :- cpp_pointee_kind(PE, K1), K1 \== other, !, cpp_pointees_agree(PE, AE).
cpp_pointee_fit(_, _).
%% two function types agree parameter for parameter and in their result, whatever the parameters are named
cpp_fn_types_agree(fn(R1, Ps1, V1), fn(R2, Ps2, V2)) :- cpp_fn_nx_off(V1, V), cpp_fn_nx_off(V2, V), cpp_types_agree(R1, R2), cpp_param_types_agree(Ps1, Ps2).   % noexcept aside (0.198): a function pointer conversion, and a noexcept function's declared type has no mark
cpp_param_types_agree([], []).
cpp_param_types_agree([P|Ps], [Q|Qs]) :- cpp_param_type_of(P, T1), cpp_param_type_of(Q, T2), cpp_types_agree(T1, T2), cpp_param_types_agree(Ps, Qs).
cpp_param_type_of(param(T, _), T).
cpp_param_type_of(param(T, _, _), T).
cpp_types_agree(T1, T2) :- cpp_type_or_self(T1, R1), cpp_type_or_self(T2, R2), ccl_resolve_type(R1, S1), ccl_resolve_type(R2, S2), cpp_bare_type(S1, B1), cpp_bare_type(S2, B2), B1 == B2.
cpp_type_or_self(T, R) :- ( catch(cpp_type(T, R0), _, fail) -> R = R0 ; R = T ).
%% the pointees agree where both are settled -- a class or a struct tag on each side, the same or the argument's derived from the parameter's; an arithmetic type on each side -- and where either is not
cpp_pointees_agree(PE, AE) :- cpp_pointee_kind(PE, K1), cpp_pointee_kind(AE, K2), cpp_pointee_kinds_agree(K1, K2).
cpp_pointee_kinds_agree(other, _) :- !.
cpp_pointee_kinds_agree(_, other) :- !.
cpp_pointee_kinds_agree(arith, arith) :- !.
cpp_pointee_kinds_agree(class(C), class(D)) :- ( D == C -> true ; cpp_class_fits(D, C) ), !.
cpp_pointee_kind(T, class(C)) :- cpp_class_of_type(T, C), !.
cpp_pointee_kind(T, class(N)) :- ccl_resolve_type(T, base(_, [struct(N, _)])), atom(N), !.
cpp_pointee_kind(T, class(N)) :- ccl_resolve_type(T, base(_, [union(N, _)])), atom(N), !.
cpp_pointee_kind(T, arith) :- ccl_resolve_type(T, R), ccl_is_arith(R), !.
cpp_pointee_kind(_, other).   % A POINTER TO A CLASS TAKES A POINTER TO THAT CLASS OR A CLASS DERIVED FROM IT ([conv.ptr]; 0.94): any class pointer took any, so libc++ 18's `__has_destroy<allocator<__tree_node>, string *>' held, `allocator<__tree_node>::destroy(__tree_node *)' ran the NODE's destructor on the string's address, and the string it destroyed lay eight bytes past the block (stdset3, a set of strings, nondeterministic)
cpp_category_mismatch(rref(_, _), A) :- cpp_arg_lvalue(A), !.   % an lvalue by its desugared form too, a member of an xvalue none (0.121)
cpp_category_mismatch(ref(Q, base(Q2, _)), A) :- \+ memberchk(const, Q), \+ memberchk(const, Q2), \+ cpp_lvalue(A), \+ A = move(_), !.
%% a reference parameter takes the object: `move(x)' handed to `C &&' is x itself (its address), the move being the callee's
cpp_ref_args(Name, As, As1) :- ccl_declared(Name, fn(_, Ps, _)), !, ( cpp_raw_params(Ps) -> As1 = As ; cpp_ref_args_(Ps, As, As1) ).   % the table's ONE type of a name may be a template's raw signature (`abs' after <chrono>): no pass is read off it (0.136)
cpp_ref_args(Name, As, As1) :- atom(Name), cpp_callee_params(id(Name), Ps), !, cpp_ref_args_(Ps, As, As1).   % a pointer or a reference to function named by a local, a parameter or a global
cpp_ref_args(_, As, As).
cpp_ref_args_of(Name, As, As1) :- ccl_declared(Name, fn(_, [_|Ps], _)), !, cpp_ref_args_(Ps, As, As1).   % a method's or constructor's: the object apart
cpp_ref_args_of(_, As, As).
cpp_ref_args_([], As, As).
cpp_ref_args_(_, [], []).
cpp_ref_args_([P|Ps], [A|As], [id(Inst)|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), cpp_fn_template_ref(A, F), cpp_fn_target(PT, FnT), cpp_deduce_target(F, FnT, Inst), !, cpp_ref_args_(Ps, As, Bs).   % A TEMPLATE'S NAME TAKES ITS INSTANCE from the parameter's target type, here where the candidate is chosen
cpp_ref_args_([P|Ps], [A|As], [cast(PT1, A)|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ),   % ... and ACCEPTING a null pointer constant is not CONVERTING it: bound to a `const _T1 &' the literal materialized an INT temporary whose address went out as the pointer, so `pair<int *, ptrdiff_t> p(0, 0)' held a non-null first
    ( PT = ref(_, _) ; PT = rref(_, _) ), \+ cpp_nullptr_param(PT), cpp_null_to_pointer(PT, A), ccl_unref(PT, PT1), !, cpp_ref_args_(Ps, As, Bs).
cpp_ref_args_([P|Ps], [A|As], [A1|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), cpp_conv_to(A, PT, A1), A1 \== A, !, cpp_ref_args_(Ps, As, Bs).   % a class value through its conversion operator
cpp_ref_args_([P|Ps], [A|As], [A1|Bs]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), !, ( ( PT = rref(_, _) ; PT = ref(_, _) ), A = move(X) -> A1 = X ; A1 = A ), cpp_ref_args_(Ps, As, Bs).
cpp_ref_args_([_|Ps], [A|As], [A|Bs]) :- cpp_ref_args_(Ps, As, Bs).
%% THE PARAMETERS OF A CALL'S CALLEE WHERE IT IS NO NAME OF A FUNCTION BUT AN EXPRESSION OF FUNCTION TYPE (0.117): a pointer to function, a
%% reference to one (libc++'s `__invoke' writes `static_cast<_Fp &&>(__f)(static_cast<_Args &&>(__args)...)' with `_Fp' a function
%% reference), a function pointer member or element. Its arguments take the passes a call by name gives them -- the reference
%% parameters their objects, the conversion operators, the copies of a class taken by value -- read off the FUNCTION TYPE; they
%% took none, so `std::invoke(bump, std::ref(c), 5)' over `void bump(Counter &, int)' passed the reference_wrapper's address as the
%% Counter, and every `std::thread t(bump, std::ref(c), 500)' ran the callee on the thread block's bytes
cpp_callee_params(F, Ps) :-
    catch(ccl_type_of(F, T0), _, fail), T0 \== unknown, ccl_unref(T0, T1), ccl_resolve_type(T1, T2),
    (   T2 = ptr(_, FT) -> true ; FT = T2 ),
    ccl_resolve_type(FT, fn(_, Ps, _)).
%% a type that holds an owner: an own pointer, an own array, a struct with one inside
cpp_holds_owners(T) :- ck_own_type(T), !.
cpp_holds_owners(T) :- ccl_resolve_type(T, base(_, [struct(_, Ms)])), Ms \== none, member(member(MT, _, _), Ms), cpp_holds_owners(MT), !.
cpp_has_ctors(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), memberchk(ctor(_, _, _, _, _), Ms), !.
cpp_has_ctors(C) :- '$cpp_mt'(C, ctor, _, _), !.                                              % a constructor template
cpp_has_ctors(C) :- cpp_implicit_ctor_needed(C).
%% AN AGGREGATE ([dcl.init.aggr]): no constructor WRITTEN OUT -- the defaulted copy and move (memberwise markers)
%% and the implicit constructor made for a member that constructs do not count -- no constructor template, no
%% virtual function or base. `Val{"beta", 2}' over a promoted struct holding a string list-initializes member by
%% member; taken for a class with constructors it asked for `Val(const char *, int)' and refused.
cpp_aggregate_class(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), \+ ( member(ctor(_, _, _, I, _), Ms), I \= memberwise(_, _) ), \+ '$cpp_mt'(C, ctor, _, _), \+ cpp_polymorphic(C), \+ '$cpp_vbase'(C), \+ '$cpp_lvb'(C, _, _).
cpp_implicit_ctor_needed(C) :- cpp_class(C, cls(B, Data, Ms, _, Defaults, _)), ( memberchk(ctor(_, _, _, _, _), Ms) -> '$cpp_default_ctor'(C) ; '$cpp_mt'(C, ctor, _, _) -> '$cpp_default_ctor'(C) ; true ), \+ cpp_closure_class(C),   % ... AND A CONSTRUCTOR TEMPLATE IS A USER-DECLARED CONSTRUCTOR ([class.default.ctor]/1): it suppresses the implicit default constructor as a written one does. libc++ 18's `__compressed_pair' has ONLY templates -- `template <bool _Dummy = true, class = __enable_if_t<...>> explicit __compressed_pair() : _Base1(__value_init_tag()), _Base2(__value_init_tag()) {}' -- and the implicit one made beside it took the SAME NAME (`C.C.0'), was emitted first, and constructed neither base: the tree's end node was garbage and `std::map' walked it   % `C() = default' BESIDE OTHER CONSTRUCTORS is the implicit default constructor too ([class.default.ctor]): it constructs the base and the members -- optional's chain ends in a storage whose default constructor nulls the pointer, and `std::optional<int &> none;' was left as garbage, `has_value()' true   % a CLOSURE has no default constructor: it is built from its captures (the compound literal), and libc++'s `[this, __p]' captures an iterator BY VALUE, a class with constructors
    ( Defaults \== [] ; B \== none, cpp_has_ctors(B) ; cpp_has_table(C) ; '$cpp_vb_holder'(C, _) ; member(member(MT, _, _), Data), cpp_elem_class(MT, MC), cpp_has_ctors(MC) ), !,
    cpp_members_default(Data, Defaults),
    \+ ( B \== none, cpp_no_default_ctor(B) ).                                               % ... and a BASE with no default constructor deletes it too ([class.default.ctor]/2): made, its body would refuse the base (0.112)
%% ... unless C++ DELETES it: a member whose class has no default constructor leaves its holder without one too, and
%% the class stays the AGGREGATE it was written as -- libc++'s `__in_out_result' holds an `ostreambuf_iterator',
%% which takes a stream, and is built `return { a, b }'; making the implicit constructor refused the whole class
%% (member_not_constructed). The test asks no constructor to be emitted: a zero-argument one declared, or none at all.
cpp_members_default([], _).
cpp_members_default([member(MT, N, _)|Ds], Defs) :-
    ( memberchk(N-_, Defs) -> true ; cpp_class_of_type(MT, MC), cpp_has_ctors(MC) -> cpp_default_ctor_exists(MC) ; true ),
    cpp_members_default(Ds, Defs).
cpp_default_ctor_exists(C) :- '$cpp_default_ctor'(C), !.   % `C() = default' beside other constructors, dropped at registration and noted (0.108): libc++'s coroutine_handle, `__handle_ = nullptr'
cpp_default_ctor_exists(C) :- '$cpp_mt'(C, ctor, TPs, ctor(_, Qs, Ps, _, _)), cpp_params_no_args(Ps), cpp_tparams_defaulted(TPs),
    catch(cpp_in_class(C, ( cpp_bind_defaults(TPs, [], B), cpp_constraints_hold(ctor, TPs, B), cpp_member_tmpl_req(C, Qs, [], B) )), _, fail), !.   % ... where its defaults BIND and its constraints hold: the default of `__enable_if_t<_And<is_default_constructible<_Tp>...>::value, int>' is the SFINAE, and a tuple of ref_views has no default constructor (`views::zip' over two vectors, `viewsmore.cpp')
cpp_default_ctor_exists(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)),
    ( member(ctor(_, _, Ps, _, _), Ms), cpp_arity_fits(Ps, 0) -> true ; \+ memberchk(ctor(_, _, _, _, _), Ms) ).
%% A CONSTRUCTOR TEMPLATE CALLABLE WITH NO ARGUMENT IS A DEFAULT CONSTRUCTOR (0.133; [class.default.ctor]/1 counts any
%% constructor that can be called with no argument): std::tuple's is `template <template <class...> class _And = _And,
%% __enable_if_t<_And<is_default_constructible<_Tp>...>::value, int> = 0> tuple()', its parameters none and its template
%% parameters all defaulted. Counted as none, it deleted the implicit default constructor of every class holding a tuple
%% (cpp_members_default), and a local of such a class was left as the stack had it: libc++ 21's `__formatter_tuple' holds
%% the elements' formatters in a tuple, and `std::format("{}", std::pair{1, 2})' parsed an int formatter of garbage
%% ("The type option contains an invalid value for an integer formatting argument").
cpp_tparams_defaulted([]).
cpp_tparams_defaulted([requires(_)|TPs]) :- !, cpp_tparams_defaulted(TPs).
cpp_tparams_defaulted([ttp(_, _)|TPs]) :- !, cpp_tparams_defaulted(TPs).
cpp_tparams_defaulted([tparam(K, _, D)|TPs]) :- ( cpp_pack_kind(K) -> true ; D \== none ), cpp_tparams_defaulted(TPs).
%% an implicit destructor: none of its own, a member with one to destroy
cpp_implicit_dtor_needed(C) :- '$cpp_vbase'(C), cpp_class(C, cls(B, _, Ms, _, _, _)), \+ memberchk(dtor(_, _, _), Ms), \+ ( cpp_dtor_def(C) ), B \== none, cpp_dtor(B, _), !.   % over a virtual base: the base's destructor runs on the sub-object where it lies, never on `this' as if at offset 0
cpp_implicit_dtor_needed(C) :- cpp_class(C, cls(B, Data, Ms, _, _, _)), B \== none, memberchk(member(_, '$vptr', _), Data), \+ '$cpp_vbase'(C), \+ cpp_empty_class(B),
    \+ memberchk(dtor(_, _, _), Ms), \+ cpp_dtor_def(C), cpp_dtor(B, _), !.   % ... and over a first base that is no longer at offset 0, behind the class's own table pointer (0.135): the base's destructor runs on the base where it lies, never on `this'
cpp_implicit_dtor_needed(C) :- '$cpp_vb_holder'(C, _), cpp_class(C, cls(_, _, Ms, _, _, _)), \+ memberchk(dtor(_, _, _), Ms), \+ ( cpp_dtor_def(C) ), !.   % a diamond's holder destroys its paths and the shared base itself
cpp_implicit_dtor_needed(C) :- cpp_class(C, cls(_, Data, Ms, _, _, _)), \+ memberchk(dtor(_, _, _), Ms), \+ ( cpp_dtor_def(C) ),
    member(member(MT, _, _), Data), cpp_elem_class(MT, MC), cpp_dtor(MC, _), !.
cpp_implicit_dtor_needed(C) :- '$cpp_base_slot'(C, E, _), \+ '$cpp_lvb'(C, E, _), cpp_dtor(E, _), cpp_class(C, cls(_, _, Ms, _, _, _)), \+ memberchk(dtor(_, _, _), Ms), \+ cpp_dtor_def(C), !.   % ... and over a LATER base with a destructor (0.177; [class.dtor]/8): the implicit destructor destroys it where it lies -- `struct T : P, Q {}' over `~Q()' had none, a local T never ran ~Q, a delete through a T * freed the bytes alone, and std::tuple<int, std::string> never destroyed its string (a leaf per element)
cpp_implicit_dtor(L, C, Fs) :- cpp_implicit_dtor_(L, C, F), cpp_nv_twin(C, F, cpp_implicit_dtor_(L, C, F2), F2, Fs, []).
cpp_implicit_dtor_(L, C, function(L, none, base([], [void]), Name, Params, false, Body1)) :-
    atomic_list_concat([C, '.dtor.0'], Name), cpp_this_type(C, [], [dying], ThisT), cpp_vtt_params(C, [param(ThisT, this)], Params),
    ( cpp_nv_body(C) -> true ; ccl_declare(Name, fn(base([], [void]), Params, false)) ),   % the base variant is declared under its own name (cpp_nv_twin)
    cpp_dtor_body(L, C, block([]), Body0), cpp_method_body(C, Params, Body0, Body1).
cpp_dtor(C, Name) :- cpp_own_dtor(C, Name), !.
cpp_dtor(C, Name) :- cpp_class_l(C, cls(B, _, _, _, _)), B \== none, cpp_dtor(B, Name).      % none of its own: the base's runs on it (the base at offset 0)
cpp_own_dtor(C, Name) :- cpp_class(C, cls(_, _, Ms, _, _, _)), ( memberchk(dtor(_, _, _), Ms) ; cpp_dtor_def(C) ; cpp_implicit_dtor_needed(C) ), !,
    ( memberchk(dtor(_, _, Body), Ms) -> true ; Body = implicit ), cpp_dtor_name(C, Body, Name), cpp_use_member(C, Name).
cpp_arity_fits(Ps, N) :- length(Ps, Max), Max >= N, cpp_required(Ps, Min), Min =< N.
cpp_required([], 0).
cpp_required([param(_, _, _)|_], 0) :- !.
cpp_required([_|Ps], N) :- cpp_required(Ps, N0), N is N0 + 1.

%% ---- names ----------------------------------------------------------------------
%% A MEMBER A LIBRARY HEADER DECLARES AND THE SHIPPED LIBRARY DEFINES is called by its Itanium name, at the one door
%% every member's name comes through -- the emission of its declaration, the call, the table's slot: `__num_put_base::
%% __identify_padding', `ctype<char>::do_narrow'. A constructor is `C1', a destructor `D1' (0.72's cpp_dtor_name,
%% folded in). Where the encoder has no spelling the member keeps its own name, and the link names it.
%% A CONST METHOD IS ANOTHER FUNCTION ([over.match.funcs]: the implicit object parameter differs): libc++ declares
%% `iterator find(const key_type &)' beside `const_iterator find(const key_type &) const', and under ONE name the
%% const one's result type was declared last and won every `auto it = m.find(3)' while the body emitted was the
%% other's -- a const_iterator cast from an iterator, which LLVM refused. Its name ends `.c'; a member the shipped
%% library defines keeps its Itanium symbol, which spells the const itself (`K').
%% A MEMBER WITH A TRAILING REQUIRES-CLAUSE IS ANOTHER FUNCTION ([dcl.decl]/4, [over.match.best]/2.6; 0.112): `.rq' and a
%% fold of the clause's text after the rest of the name, so `end() const' and `end() const requires same_as<...>'
%% (libc++'s iota_view) are two definitions and two declarations -- under one name the program's own class template
%% emitted both (`invalid redefinition') and a lazy library class took whichever was found first by that name
cpp_mangle_q(C, M, Qs, Ps, Name) :- \+ M = operator(conv(_)), select(requires(R), Qs, Qs1), \+ cpp_shipped_member_q(C, M, Ps, Qs), !,
    cpp_mangle_q(C, M, Qs1, Ps, N0), cpp_req_key(R, K), atomic_list_concat([N0, '.rq', K], Name).
cpp_mangle_q(C, M, Qs, Ps, Name) :- ( memberchk(const, Qs) ; memberchk(refq(_), Qs) ), \+ M = operator(conv(_)), \+ cpp_shipped_member_q(C, M, Ps, Qs), !,
    cpp_mangle(C, M, Ps, N0), ( memberchk(const, Qs) -> Cq = '.c' ; Cq = '' ),
    ( memberchk(refq(lvalue), Qs) -> Rq = '.r' ; memberchk(refq(rvalue), Qs) -> Rq = '.rr' ; Rq = '' ),   % A REF-QUALIFIED MEMBER IS ANOTHER FUNCTION too ([over.match.funcs]): `.r' for `&', `.rr' for `&&', after the `.c' -- optional's storage writes `__get() &', `const &', `&&' and `const &&', and on one name the last declared won
    atomic_list_concat([N0, Cq, Rq], Name).
cpp_mangle_q(C, M, _, Ps, Name) :- cpp_mangle(C, M, Ps, Name).
cpp_shipped_member_q(C, M, Ps, Qs) :- cpp_shipped_member(C, M, Ps, Qs0, _), cpp_same_constness(Qs, Qs0).
cpp_req_key(R, K) :- ground(R), term_to_atom(R, A), atom_codes(A, Cs), !, cpp_req_fold(Cs, 7, K0), K is K0 mod 1000003.
cpp_req_key(_, v).   % a clause still holding a free variable is named alike wherever it is met, never by its variables' print names
cpp_req_fold([], S, S).
cpp_req_fold([C|Cs], S0, S) :- S1 is (S0 * 131 + C) mod 2147483647, cpp_req_fold(Cs, S1, S).
cpp_same_constness(Q1, Q2) :- ( memberchk(const, Q1) -> memberchk(const, Q2) ; \+ memberchk(const, Q2) ).
cpp_mangle(C, M, Ps, Name) :- cpp_shipped_member(C, M, Ps, Qs, Kind), cpp_class_scope(C, Path, Chain),
    catch(( cpp_in_class(C, cpp_plain_params(Ps, Ps1)), cpp_ita_function(Path, Chain, Kind, Qs, Ps1, false, Name) ), _, fail), !.   % the parameters RESOLVED IN THE CLASS first: `do_narrow(char_type, char)' is written in ctype's own words
cpp_mangle(C, operator(Op), Ps, Name) :- !, cpp_op_word(Op, W), cpp_params_key(Ps, K), atomic_list_concat([C, '.op.', W, '.', K], Name).
cpp_mangle(_, M, _, _) :- \+ atom(M), !, cpp_refuse(0, member_name(M)).   % never a raw type_error out of atomic_list_concat: say which name could not be mangled
cpp_mangle(C, M, Ps, Name) :- cpp_params_key(Ps, K), atomic_list_concat([C, '.', M, '.', K], Name).
cpp_shipped_member(C, M, Ps, Qs, Kind) :- ( atom(M) -> true ; M = operator(_) ), cpp_lib_class(C), cpp_class_l(C, _), cpp_params_key(Ps, K),   % an operator member too: `cin >> n' is the shipped `rs'
    (   M == C -> '$cpp_decl'(C, ctor, Qs, Ps0), cpp_params_key(Ps0, K), Kind = '$ctor'   % the members the class only DECLARES, by their facts (0.153: its whole record was copied here)
    ;   '$cpp_decl'(C, method(M), Qs, Ps0), \+ memberchk(pure, Qs), cpp_params_key(Ps0, K), Kind = M ),
    \+ cpp_defined_out_of_class(C, Kind, K), !.
%% ... and not DEFINED OUT OF ITS CLASS in the header (`inline ios_base::fmtflags ios_base::flags() const { ... }'),
%% whose body the class's own member list does not hold: that one is compiled here, under its own name
cpp_defined_out_of_class(C, Kind, K) :- '$cpp_mdef'(C, Kind, _, _, Item), cpp_member_shape(Item, Kind, Ps1, B), B \== none, cpp_params_key(Ps1, K), !.
cpp_defined_out_of_class(C, Kind, K) :- cpp_last_segment(C, Last), Last \== C, '$cpp_mdef'(Last, Kind, _, _, Item), cpp_member_shape(Item, Kind, Ps1, B), B \== none, cpp_params_key(Ps1, K), !.   % a nested class's, keyed by its bare name (the reader's spelling of `X<T>::sentry::sentry')
%% the parameters' types, keyed (cpp_type_key): overloads by type get names of their own; none is `0'
cpp_params_key([], '0') :- !.
cpp_params_key(Ps, K) :- member(P, Ps), cpp_param_t(P, T), cpp_has_decltype(T), !, cpp_params_keys_seq(Ps, [], Ks), atomic_list_concat(Ks, '.', K).   % A PARAMETER'S NAME IS IN SCOPE IN THE LATER PARAMETERS' TYPES ([basic.scope.param]; 0.109): libc++'s `__rewrap(_Iter __orig_iter, decltype(std::__unwrap_iter(__orig_iter)) __iter)'
cpp_params_key(Ps, K) :- findall(TK, ( member(P, Ps), ( P = param(T0, _) ; P = param(T0, _, _) ), cpp_param_fn_type(T0, T), cpp_type_key(T, TK) ), Ks), atomic_list_concat(Ks, '.', K).
cpp_param_t(param(T, _), T).
cpp_param_t(param(T, _, _), T).
cpp_params_keys_seq([], _, []).
cpp_params_keys_seq([P|Ps], Prev, [TK|Ks]) :- cpp_param_t(P, T0), !, cpp_param_fn_type(T0, T),
    ( Prev == [] -> cpp_type_key(T, TK) ; cpp_params_in_scope(Prev, cpp_type_key(T, TK)) ), append(Prev, [P], Prev1), cpp_params_keys_seq(Ps, Prev1, Ks).
cpp_params_keys_seq([_|Ps], Prev, Ks) :- cpp_params_keys_seq(Ps, Prev, Ks).
cpp_params_in_scope(Ps, Goal) :- cpp_in_frame(( forall(( member(P, Ps), cpp_param_t(P, T), arg(2, P, N), atom(N) ), ccl_declare(N, T)), Goal )).
%% ... a by-value parameter's TOP-LEVEL qualifiers are no part of the function's type ([dcl.fct]/5): `f(int)' declared
%% and `f(const int x)' defined are one function, and their keys must agree (the keys carry qualifiers since 0.95)
cpp_param_fn_type(base(Q, S), base(Q1, S)) :- !, cpp_no_cv(Q, Q1).
cpp_param_fn_type(ptr(Q, T), ptr(Q1, T)) :- !, cpp_no_cv(Q, Q1).
cpp_param_fn_type(T, T).
cpp_no_cv(Q, Q1) :- findall(X, ( member(X, Q), X \== const, X \== volatile ), Q1).
cpp_cv_key(Q, CV) :- findall(X, ( member(X, [const, volatile]), memberchk(X, Q) ), CV).
cpp_free_operator(Op, Ps, Name) :- cpp_alloc_op(Op), cpp_alloc_shape(Ps, Sh), cpp_alloc_sym(Op, Sh, Name), !.   % A REPLACEABLE ALLOCATION OR DEALLOCATION FUNCTION IS ITS ITANIUM SYMBOL (0.202; [replacement.functions]): the program's `void *operator new(std::size_t)' is `_Znwm', which replaces the library's at the link
cpp_free_operator(Op, Ps, Name) :- length(Ps, K), cpp_op_word(Op, W), atomic_list_concat(['op.', W, '.', K], Name).
cpp_op_word('+', plus) :- !.        cpp_op_word('-', minus) :- !.       cpp_op_word('*', times) :- !.       cpp_op_word('/', divide) :- !.     cpp_op_word('%', modulo) :- !.
cpp_op_word('==', eq) :- !.         cpp_op_word('!=', ne) :- !.         cpp_op_word('<', lt) :- !.          cpp_op_word('>', gt) :- !.         cpp_op_word('<=', le) :- !.        cpp_op_word('>=', ge) :- !.
cpp_op_word('+=', plus_assign) :- !. cpp_op_word('-=', minus_assign) :- !. cpp_op_word('*=', times_assign) :- !. cpp_op_word('/=', divide_assign) :- !. cpp_op_word('%=', modulo_assign) :- !.
cpp_op_word('[]', index) :- !.      cpp_op_word('()', call) :- !.       cpp_op_word('<<', shl) :- !.        cpp_op_word('>>', shr) :- !.       cpp_op_word('!', not) :- !.
cpp_op_word('&&', and) :- !.        cpp_op_word('||', or) :- !.         cpp_op_word('&', bitand) :- !.      cpp_op_word('|', bitor) :- !.      cpp_op_word('^', bitxor) :- !.     cpp_op_word('~', bitnot) :- !.
cpp_op_word('++', inc) :- !.        cpp_op_word('--', dec) :- !.        cpp_op_word('=', assign) :- !.      cpp_op_word('->', arrow) :- !.
cpp_op_word('<<=', shl_assign) :- !. cpp_op_word('>>=', shr_assign) :- !. cpp_op_word('&=', bitand_assign) :- !. cpp_op_word('|=', bitor_assign) :- !. cpp_op_word('^=', bitxor_assign) :- !.
cpp_op_word(co_await, co_await) :- !.
cpp_op_word(new, new) :- !.         cpp_op_word('new[]', new_array) :- !. cpp_op_word(delete, delete) :- !. cpp_op_word('delete[]', delete_array) :- !.   % `op.new.2', `C.op.delete.void_p' (0.202), where the word was the codes of the name
cpp_op_word(conv(T), W) :- !, cpp_type_key(T, K), atomic_list_concat([conv, K], '_', W).                 % operator bool(): op.conv_bool
cpp_op_word(literal(S), W) :- !, atom_concat(literal_, S, W).                                          % operator"" _km: op.literal__km.1 (0.117)
cpp_op_word(Op, W) :- atom_codes(Op, Cs), atomic_list_concat([op|Cs], '_', W).
%% the default arguments of a function, by its (mangled) name: '$cpp_dflt'(Name, [none | E ...]) (0.119: a fact, as a global list it was copied at every call)
cpp_note_defaults(Name, Ps) :- ( member(param(_, _, _), Ps) -> cpp_defaults_of(Ps, Ds), asserta('$cpp_dflt'(Name, Ds)) ; true ).
cpp_defaults_of([], []).
cpp_defaults_of([param(_, _, D)|Ps], [D|Ds]) :- !, cpp_defaults_of(Ps, Ds).
cpp_defaults_of([_|Ps], [none|Ds]) :- cpp_defaults_of(Ps, Ds).
%% A DEFAULT ARGUMENT IS DESUGARED WHERE IT IS FILLED IN, which is where C++ evaluates it: it is kept raw from the
%% declaration, and a default that BUILDS something -- libc++'s `const _Allocator & __a = _Allocator()' on the
%% constructor template every `std::string s = "abc"' goes through -- reached the lowering as a call to a type.
cpp_fill_defaults(Name, As, As1) :- '$cpp_dflt'(Name, Ds), !, length(As, N), cpp_drop(N, Ds, Rest), cpp_take_defaults(Rest, Tail0),
    cpp_with_dflt_site(Name, Tail0, (   cpp_default_ctx(Name, C) -> ( cpp_in_class(C, cpp_exprs(C, Tail0, Tail)) -> true ; Tail = Tail0 )   % A MEMBER'S DEFAULT ARGUMENT IS DESUGARED IN ITS CLASS, where C++ looks its names up: `__reset_internal_buffer(__rep __new_rep = __short())' names the string's nested __short, and filled inside a lambda (no class at all) it named nothing
    ;   cpp_exprs(none, Tail0, Tail1) -> true
    ;   Tail1 = Tail0 )),   % the call's place, while its defaults are desugared (0.166): a source location's (cpp_srcloc)
    cpp_braced_defaults(Name, N, Tail1, Tail),
    append(As, Tail, As1).
cpp_fill_defaults(_, As, As).
cpp_with_dflt_site(Name, Tail0, Goal) :-
    (   Tail0 == [] -> call(Goal)
    ;   nb_current('$cpp_dflt_site', site(_, _)) -> call(Goal)                                % the OUTERMOST call's: a default's own defaults are filled at it
    ;   ( nb_current('$cpp_line', L) -> true ; L = 0 ), ( nb_current('$cpp_dflt_site', S0) -> true ; S0 = none ), nb_setval('$cpp_dflt_site', site(L, Name)),
        ( catch(Goal, E, ( nb_setval('$cpp_dflt_site', S0), throw(E) )) -> nb_setval('$cpp_dflt_site', S0) ; nb_setval('$cpp_dflt_site', S0), fail ) ).
%% A BRACED DEFAULT ON A SCALAR PARAMETER is its value where the default is filled in (0.93): the defaults are recorded
%% by the function's name as bare expressions, and `int __n = {}' (libc++'s ranges at C++20, `adv(I, S, int p = {})'
%% in the fixture) went out as `init([])', which the lowering took for an aggregate of nothing -- garbage where C++
%% has 0; the parameter's type is read off the function's declaration, position by position
cpp_braced_defaults(Name, N, Ds, Es) :- ccl_declared(Name, fn(_, Ps, _)), cpp_drop(N, Ps, Rest), !, cpp_braced_defaults_(Rest, Ds, Es).
cpp_braced_defaults(_, _, Ds, Ds).
cpp_braced_defaults_([P|Ps], [init(Items)|Ds], [E|Es]) :- ( P = param(PT, _) ; P = param(PT, _, _) ), cpp_scalar_braced(PT, Items, E), !, cpp_braced_defaults_(Ps, Ds, Es).
cpp_braced_defaults_([_|Ps], [D|Ds], [D|Es]) :- !, cpp_braced_defaults_(Ps, Ds, Es).
cpp_braced_defaults_(_, Ds, Ds).
cpp_scalar_braced(PT, Items, E) :- cpp_type(PT, PT1), ccl_unref(PT1, PT2), ccl_resolve_type(PT2, RT), ( RT = base(_, S), \+ ccl_members_of(base([], S), _) ; RT = ptr(_, _) ),
    ( Items = [] -> E = cast(PT2, int(0)) ; Items = [item([], V)] -> cpp_expr(none, V, E) ; cpp_refuse(0, braced_scalar_argument(PT2)) ).
cpp_default_ctx(Name, C) :- ccl_declared(Name, fn(_, [param(PT, this)|_], _)), PT = ptr(_, base(_, [typedef(C)])), atom(C).
cpp_params_bare([], []).
cpp_params_bare([P|Ps], [param(T, N)|Qs]) :- ( P = param(T, N, _) -> true ; P = param(T, N) ), !, cpp_params_bare(Ps, Qs).
cpp_params_bare([P|Ps], [P|Qs]) :- cpp_params_bare(Ps, Qs).
cpp_drop(0, L, L) :- !.
cpp_drop(_, [], []) :- !.   % MORE ARGUMENTS THAN RECORDED DEFAULTS: a method's defaults do not count `this', and a call the desugaring has already built carries it -- `SC(static_cast<long>(r) - 1)' in a derived class's initializer list walked as call(id('SC.SC.long'), [addr(this->$base), ...]), where the drop ran off the end and the whole walk FAILED, silently
cpp_drop(N, [_|L], R) :- N1 is N - 1, cpp_drop(N1, L, R).
cpp_take_defaults([], []).
cpp_take_defaults([none|_], []) :- !.
cpp_take_defaults([D|Ds], [D|Es]) :- cpp_take_defaults(Ds, Es).
cpp_plain_params(Ps, Qs) :- Ps = [_, _|_], member(P, Ps), cpp_param_t(P, T), cpp_has_decltype(T), !,   % A PARAMETER'S NAME IS IN SCOPE IN THE LATER ONES' TYPES ([basic.scope.param]; 0.109): libc++'s `__rewrap(_Iter __orig_iter, decltype(std::__unwrap_iter(__orig_iter)) __iter)'
    ccl_scope_push, ( catch(cpp_plain_params_seq(Ps, Qs), E, ( ccl_scope_pop, throw(E) )) -> ccl_scope_pop ; ccl_scope_pop, fail ).
cpp_plain_params([], []).
cpp_plain_params([param(T0, N, _)|Ps], [param(T, N)|Qs]) :- !, cpp_type(T0, T), cpp_plain_params(Ps, Qs).
cpp_plain_params([param(T0, N)|Ps], [param(T, N)|Qs]) :- !, cpp_type(T0, T), cpp_plain_params(Ps, Qs).
cpp_plain_params([P|Ps], [P|Qs]) :- cpp_plain_params(Ps, Qs).
cpp_plain_params_seq([], []).
cpp_plain_params_seq([P|Ps], [param(T, N)|Qs]) :- cpp_param_t(P, T0), !, arg(2, P, N), cpp_type(T0, T), ( atom(N) -> ccl_declare(N, T) ; true ), cpp_plain_params_seq(Ps, Qs).
cpp_plain_params_seq([P|Ps], [P|Qs]) :- cpp_plain_params_seq(Ps, Qs).
cpp_this_type(C, Quals, T) :- cpp_this_type(C, Quals, [], T).
%% a constructor's this is marked fresh, a destructor's dying: the check reads the marks (ck_this_marker/2)
cpp_this_type(C, Quals, Marks, ptr([], base(Q, [typedef(C)]))) :- ( memberchk(const, Quals) -> Q = [const|Marks] ; Q = Marks ).
cpp_refuse(L, What) :- ( nb_getval('$cpp_trace', yes) -> ( nb_current('$cpp_wstack', W), W \== off -> true ; nb_current('$cpp_where', W) -> true ; W = top ), cpp_trace(refuse(What, in(W))) ; true ), throw(error(not_lowered(What), where(file, line(L)))).   % the breadcrumb STACK (0.87's, eight frames) where it is kept, not the innermost frame alone: `in(class(__base))' named the class being loaded where the constraint that refused was two headers away (0.93)
