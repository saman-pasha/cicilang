%% ccl_cpp_expr.pl -- expressions, bottom up: cpp_expr/3, member pointers, immediate functions, noexcept, the
%% awaiter, new and delete and the array cookie, calls and argument-dependent lookup, class template argument
%% deduction, the math builtins, temporaries, operators over classes and enums, the allocation functions. A part of
%% the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there, in their order.

cpp_expr(_, typeid(type(T0)), E) :- !, cpp_rtti_needed(typeid_requires_rtti), cpp_type(T0, T), cpp_rtti_of_type(T, E).
cpp_expr(Ctx, typeid(X), E) :- !, cpp_rtti_needed(typeid_requires_rtti), cpp_expr(Ctx, X, X1),
    (   cpp_class_of_type_of(X1, C), cpp_polymorphic(C) -> E = rtti_dyn(X1)            % a polymorphic object: its DYNAMIC type, through its table's prefix
    ;   X1 == nullptr -> E = rtti(ext('_ZTIDn'))   % `nullptr' is a std::nullptr_t (0.180)
    ;   ccl_type_of(X1, T), T \== unknown -> cpp_rtti_of_type(T, E)
    ;   cpp_refuse(0, typeid_of(X)) ).
%% dynamic_cast: an upcast is the plain conversion; a downcast or a cross-cast asks libc++abi's __dynamic_cast over
%% the two type_info objects, null for a null pointer; `dynamic_cast<void *>' is the complete object (offset-to-top);
%% a reference that does not convert aborts, as a throw of bad_cast with exceptions off would
cpp_expr(Ctx, ccast(dynamic, T0, X), E) :- !, cpp_type(T0, T), cpp_expr(Ctx, X, X1), cpp_dynamic_cast(T, X1, E).
cpp_expr(_, throw(none), eh_rethrow) :- !, cpp_eh_needed(throw_requires_exceptions), nb_setval('$cpp_eh_used', yes).
cpp_expr(Ctx, throw(E), stmt_expr(block([declaration(0, none, VP, [var(X, VP, eh_alloc(sizeof_type(T)))]), expr(0, NewE), expr(0, eh_throw(id(X), R, D))]))) :- !,
    cpp_eh_needed(throw_requires_exceptions), nb_setval('$cpp_eh_used', yes),
    (   E = call(id(C), As), atom(C), cpp_class_l(C, _), cpp_has_ctors(C)                % `throw E(2)': the object made IN the exception's memory, C++17's guaranteed elision (0.110) -- it had been built in a temporary and copied, and the temporary never destroyed
    ->  cpp_type(base([], [typedef(C)]), T), cpp_exprs(Ctx, As, Args)
    ;   cpp_expr(Ctx, E, E1),
        ( ccl_type_of(E1, T0), T0 \== unknown -> true ; cpp_refuse(0, throw_of_untyped(E)) ),
        ccl_unref(T0, T1), ccl_resolve_type(T1, T2), ( T2 = arr(_, El) -> T3 = ptr([], El) ; T3 = T2 ), cpp_strip_top(T3, T), Args = [E1] ),
    VP = ptr([], base([], [void])), ccl_gensym('$exn', X), ccl_declare(X, VP),
    cpp_new_at([id(X)], T, Args, NewE), ( Args == [nullptr] -> R = rtti(ext('_ZTIDn')) ; cpp_rtti_of_type(T, R) ),   % `throw nullptr' throws a std::nullptr_t (0.180), which a pointer handler catches as null
    ( cpp_class_of_type(T, C), cpp_dtor(C, DName) -> D = id(DName) ; D = nullptr ).
cpp_expr(Ctx, arrow(this, '$this'), arrow(id(this), '$this')) :- cpp_closure_this(Ctx, _), !.   % the closure's OWN member holding the captured object, named by a generated body (its destructor's, its copy's): the closure's this, never the enclosing object's (0.101)
cpp_expr(Ctx, this, E) :- cpp_closure_this(Ctx, _), !, cpp_closure_object([], E).      % inside a lambda that captured it, `this' is the enclosing object's address
cpp_expr(_, '$cpp_walked'(E), E) :- !.                                                  % walked already, by the `auto' deduction
%% A USER-DEFINED LITERAL ([lex.ext], [over.literal]; 0.117): the call of its literal operator over the literal as the standard hands it
%% over -- an integer literal as an `unsigned long long', a floating one as a `long double', a string as its pointer and its length,
%% a character as itself. The operator is a free operator, `op.literal_<suffix>.<arity>', the program's own or a header's
%% (cpp_index_name), chosen among its overloads by the argument types: libc++'s `operator""s(const char *, size_t)', `operator""ms(
%% unsigned long long)' beside `operator""ms(long double)'. A raw literal operator (`const char *') and the template form are not asked.
cpp_expr(Ctx, udl(Sfx, Lit), E) :- memberchk(Sfx, [i, if, il]), \+ cpp_cplxlit_visible(Sfx), !, cpp_udl_imag(Sfx, Lit, G), cpp_expr(Ctx, G, E).   % `3i', `2.0i': GNU's imaginary literal where no literal operator of <complex> is visible (0.179, cpp_cplxlit_visible/1)
cpp_expr(Ctx, udl(Sfx, Lit), E) :- !, cpp_udl_args(Lit, As), length(As, K), length(Qs, K), cpp_free_operator(literal(Sfx), Qs, Name), cpp_expr(Ctx, call(id(Name), As), E).
cpp_expr(_, this, id(this)) :- !.
cpp_expr(_, E, E) :- \+ compound(E), !.
cpp_expr(Ctx, id(N), E) :- !,
    (   cpp_local(N) -> E = id(N)
    ;   ccl_func_name(N) -> cpp_fsig_literal(N, E)                                             % `__func__', `__FUNCTION__', `__PRETTY_FUNCTION__': the function's own name, as clang spells it (0.166, below)
    ;   Ctx = self(C, SN), cpp_data_member(C, N, []) -> E = member(id(SN), N)                   % C++23: a capture, through the closure's explicit object parameter
    ;   Ctx \== none, cpp_data_member(Ctx, N, Hops) -> cpp_check_access(Ctx, Ctx, N), cpp_access(id(this), N, Hops, E)
    ;   Ctx \== none, cpp_static_value(Ctx, N, V) -> E = V                                    % a static const with a constant, named bare inside its class: the constant, as `C::value' already folds
    ;   Ctx \== none, cpp_static_use(Ctx, N, Name) -> E = id(Name)
    ;   Ctx == none, cpp_class_ctx(Cx), cpp_static_value(Cx, N, V) -> E = V                    % A HIDDEN FRIEND is in the scope of the class it is written in ([class.friend]/7; 0.117): its body is walked with no `this', in the class's words, and a static const named bare there is the class's (libc++'s `__bit_iterator::__bits_per_word' in the friend `operator-')
    ;   Ctx == none, cpp_class_ctx(Cx), cpp_static_use(Cx, N, Name) -> E = id(Name)
    ;   cpp_closure_this(Ctx, EC), cpp_data_member(EC, N, Hops) -> cpp_closure_member(N, Hops, E)   % a lambda's captured this: the enclosing object's member
    ;   cpp_closure_this(Ctx, EC), cpp_static_use(EC, N, Name) -> E = id(Name)
    ;   cpp_static_fn_value(Ctx, N, E0) -> E = E0                                           % A STATIC MEMBER FUNCTION NAMED BARE AS A VALUE (0.126), below
    ;   cpp_using_key(N, K), cpp_using_value(K, E0) -> E = E0                                  % A HEADER'S KEYED OBJECT OR FUNCTION NAMED BARE through a using of its namespace (0.161; cpp_using_value)
    ;   cpp_global_const(N, V) -> E = V                                                       % a file-scope `const' of integral type with a constant initializer: the constant (below)
    ;   cpp_global_var(N, GName) -> E = id(GName)                                            % a library header's extern global: the symbol the shipped binary exports
    ;   cpp_lazy_fn_value(N, Name) -> E = id(Name)                                          % A HEADER'S FUNCTION NAMED AS A VALUE -- `cout << std::hex', the manipulator handed to the inserter as a pointer -- is emitted as a call would emit it: it was declared, never defined, and the link named nineteen manipulators
    ;   E = id(N) ).
%% A FUNCTION TEMPLATE-ID NAMED AS A VALUE -- `&__thread_proxy<_Gp>', handed to pthread_create by libc++'s std::thread, or `f<int>' given to a
%% function-pointer parameter -- is the function of the instance its EXPLICIT arguments name ([temp.arg.explicit]/4, [over.over]/2; 0.117):
%% there is no call to deduce from, so every template parameter must be given or defaulted, and the first overload of the name whose
%% constraints hold is the one (cpp_explicit_instance). The instance is emitted as any is; the value is its name, the address under `&'.
cpp_expr(_, addr(X), addr(id(Name))) :- cpp_fn_template_id(X, F, TArgs), !, cpp_call_targs(TArgs, TArgs1), cpp_explicit_instance(F, TArgs1, Name).
cpp_expr(_, X, id(Name)) :- cpp_fn_template_id(X, F, TArgs), !, cpp_call_targs(TArgs, TArgs1), cpp_explicit_instance(F, TArgs1, Name).
%% A STATIC MEMBER TEMPLATE-ID NAMED AS A VALUE -- `dispatcher<Is...>::template dispatch<F, Vs...>', which libc++ 18's std::visit stores in
%% an array of function pointers -- is the function of the instance its explicit arguments name, as a free function template's is (above):
%% a thunk over the instance's own parameters, as a static method named as a value is (cpp_static_thunk; the instance takes a null `this').
cpp_expr(_, addr(scoped(Path, tmpl(M, TArgs0))), addr(id(Thunk))) :- cpp_member_template_id(Path, M, C), !,
    cpp_targ_values(TArgs0, TArgs), cpp_member_explicit_instance(C, M, TArgs, Name), cpp_instance_thunk(C, Name, Thunk).
cpp_expr(_, scoped(Path, tmpl(M, TArgs0)), id(Thunk)) :- cpp_member_template_id(Path, M, C), !,
    cpp_targ_values(TArgs0, TArgs), cpp_member_explicit_instance(C, M, TArgs, Name), cpp_instance_thunk(C, Name, Thunk).
%% `&C::f' OF A STATIC MEMBER FUNCTION IS AN ORDINARY POINTER TO FUNCTION ([expr.unary.op]/3: a pointer to member is only
%% for a non-static member; 0.160): the thunk the function's name as a value is (cpp_static_thunk). It took the member
%% pointer road, `{ ptr, i64 }', and `int (*p)(int, int) = &M::sum;' was an `inttoptr' of a struct that LLVM refused
cpp_expr(Ctx, addr(scoped(Path, N)), addr(id(Thunk))) :- atom(N), cpp_scope_class(Path, C), cpp_static_method(C, N, Name), !,
    cpp_check_access(Ctx, C, N), cpp_static_thunk(C, N, Name, Thunk).
%% `&C::m' IS A POINTER TO MEMBER ([expr.unary.op]/4): the address of the one function this compiler emits for
%% that method, wrapped in a cast to the member-pointer type so the deduction and the traits read it for what it
%% is (cpp_type's memptr clause). A method with several overloads has no target here to choose by, a VIRTUAL one
%% would need a table index in the value, and a DATA member an offset: each is refused by name.
cpp_expr(Ctx, addr(scoped(Path, N)), E) :- atom(N), cpp_scope_class(Path, C), \+ cpp_static_member(C, N, _), !, cpp_check_access(Ctx, C, N), cpp_member_address(C, N, E).   % the member's ACCESS where its address is taken (0.127)
cpp_expr(Ctx, addr(scoped(Path, N)), E) :- N = operator(_), cpp_scope_class(Path, C), \+ cpp_static_method(C, N, _), !, cpp_check_access(Ctx, C, N), cpp_member_address(C, N, E).   % ... AN OPERATOR's (0.201): `&_Fp::operator()', which libc++'s std::function guide strips to the call's signature (`std::function g{[](int x) { ... }};'), raised a type error
%% `&C::s' AND A BARE `&s' OF A STATIC DATA MEMBER ARE ITS OBJECT'S ADDRESS ([expr.unary.op]/3; 0.191): a static that folds to a
%% constant is still an object, defined linkonce with its class (cpp_static_decls), a lazy class's where its address is taken
%% (cpp_static_use). It folded to its value, and the address of `int(0)' reached the lowering (`lvalue(int(0))'): libc++'s
%% no-RTTI std::any tells its types apart by `&__unique_typeinfo<_Tp>::__id', a `static constexpr int' of each.
cpp_expr(Ctx, addr(scoped(Path, N)), addr(id(Name))) :- atom(N), cpp_scope_class(Path, C), cpp_static_member(C, N, _), !,
    cpp_check_access(Ctx, C, N), cpp_static_use(C, N, Name).
cpp_expr(Ctx, addr(id(N)), addr(id(Name))) :- atom(N), \+ cpp_local(N), cpp_bare_static_class(Ctx, N, C), !, cpp_static_use(C, N, Name).
%% `x.*pm' and `p->*pm' AS VALUES ([expr.mptr.oper]): for a pointer to a DATA member, the object's bytes at the
%% offset, as the member's type -- `*(T *) ((char *) &x + pm)'; a pointer to a member FUNCTION means something only
%% when it is called (cpp_call's memptr clauses), and named bare is refused
cpp_expr(Ctx, memptr_get(X0, F0), E) :- !, cpp_expr(Ctx, X0, X), cpp_expr(Ctx, F0, F), cpp_memptr_read(addr(X), F, E0), cpp_memptr_qualify(obj, X, E0, E).
cpp_expr(Ctx, memptr_arrow(X0, F0), E) :- !, cpp_expr(Ctx, X0, X), cpp_expr(Ctx, F0, F), cpp_memptr_read(X, F, E0), cpp_memptr_qualify(ptr, X, E0, E).
%% A TYPE ARGUMENT IS A TYPE (0.93): the reader gives a builtin trait's type arguments as `type(T)', and the generic walk
%% below took the term apart and read `typename add_const<_Tp>::type' inside it as an EXPRESSION -- a scoped name, which
%% is the nested type's NAME as an id -- so libc++ 18's is_copy_constructible, `__is_constructible(_Tp,
%% __add_lvalue_reference_t<typename add_const<_Tp>::type>)', compared a name with a type and answered 0 for every
%% pointer and every plain struct, and `__unwrap_iter' (guarded by is_copy_constructible of the iterator) held for nothing
cpp_expr(_, type(T0), type(T)) :- !, cpp_type(T0, T).
cpp_expr(_, sizeof(scoped(Path, N)), sizeof_type(T)) :- atom(N), \+ memberchk(nonclass(_), Path), catch(cpp_scope_class(Path, C), _, fail), catch(cpp_class_typedef(C, N, _), _, fail), !,   % `sizeof(C::type)' OF A MEMBER TYPE IS A TYPE'S SIZE ([expr.sizeof]/1; 0.201): `sizeof(decltype(v)::value_type)' was the size of a static `vector.int.allocator.int.value_type' that is no object
    cpp_type(base([], [typedef(scoped(Path, N))]), T).
cpp_expr(_, scoped(Path, N), _) :- memberchk(nonclass(A), Path), !, cpp_refuse(0, no_member(A, N)).   % `_Tp::value' with _Tp a scalar: no members (cpp_subst_path)
cpp_expr(_, scoped(Path, N), id(K)) :- atom(N), cpp_ns_key(Path, N, K), K \== N, ccl_enum_value(K, _), !.   % `n2::x', an enumerator two namespaces declare: its key (cpp_qualify_enum, 0.127)
cpp_expr(Ctx, scoped(Path, N), E) :- atom(N), cpp_enumerator(Ctx, Path, N, V), !, ( ( cpp_enum_path_tag(Ctx, Path, Tag) -> true ; cpp_ns_enum_tag(Path, N, _, Tag) -> true ; cpp_hdr_enum_tag(Path, N, Tag) ) -> E = cast(base([], [typedef(Tag)]), int(V)) ; E = int(V) ).   % ... OF ITS ENUM'S TYPE (0.127): a bare `int(V)', `k(Fruit::Pear)' chose `k(long)' over `k(Fruit)', and a template deduced an int   % A QUALIFIED ENUMERATOR IS ITS VALUE WHATEVER A LOCAL IS NAMED (0.94): `Kind::ptr' asks the enumerators' table directly, since flattened to `id(ptr)' it would meet the local that now shadows the bare name
cpp_expr(_, scoped(Path, N), id(GName)) :- atom(N), ( cpp_ns_key(Path, N, K) -> true ; K = N ), cpp_global_var(K, GName), !.   % ... a deeper namespace's colliding object by its key (0.100)   % `std::cout': a library header's extern GLOBAL, by the symbol the shipped binary exports (a scoped name is flattened in the lowering, so it must be taken here)
cpp_expr(_, scoped(Path, N), id(Name)) :- atom(N), \+ cpp_scope_class(Path, _), cpp_lazy_fn_value(N, Name), !.   % `std::hex' named as a value: the header's function, emitted (the bare name's road below)
cpp_expr(_, scoped(Path, tmpl(N0, Args0)), E) :- atom(N0), \+ cpp_scope_class(Path, _), ( cpp_ns_key(Path, N0, K), cpp_variable_template(K) -> N = K ; cpp_variable_template(N0), N = N0 ), !,   % A NAMESPACE-QUALIFIED VARIABLE TEMPLATE IS ITS VALUE (0.104): `std::is_same_v<A, B>' in an expression had its value put back INSIDE the scoped path, `scoped([std], bool(false))', which the lowering met as a name
    cpp_targ_values(Args0, Args), cpp_instantiate_variable(N, Args, E).   % ... BY ITS NAMESPACE KEY FIRST (0.132): `views::empty<int>' is `views.empty', libc++'s variable template, and the bare `empty' is the function template std::empty, whose instance over `int' named `__c.empty()'
cpp_expr(_, scoped(Path, N), cast(base([], [typedef(Tag)]), int(V))) :- atom(N), cpp_enum_class_tag(Path, N, Tag), cpp_enum_value(Tag, N, V), !.   % `Shape::Circle': of its enum's type, through the class that holds the enum (0.127)
cpp_expr(Ctx, scoped(Path, N), E) :- cpp_scope_class(Path, C), !,
    (   cpp_static_value(C, N, V) -> E = V                                                        % C::value, a static const with a constant: the constant
    ;   cpp_static_use(C, N, Name) -> E = id(Name)
    ;   cpp_static_method(C, N, Name) -> cpp_static_thunk(C, N, Name, Thunk), E = id(Thunk)   % `_Traits::eq' NAMED AS A VALUE: a plain function (below)
    ;   cpp_qualified_data_member(Ctx, C, N, E) -> true
    ;   atomic_list_concat([C, '.', N], Name), E = id(Name) ).
cpp_expr(_, base(_, [typedef(X)]), E) :- cpp_template_id(X, N, Args0), cpp_variable_template(N), !,   % a variable template READ AS A TYPE in an expression: `!__has_max_size_v<const _Ap>' -- the reader cannot tell, and unevaluated it made the negation false
    cpp_targ_values(Args0, Args), cpp_instantiate_variable(N, Args, E).
cpp_expr(_, tmpl(N, Args0), E) :- cpp_template(N, _, declaration(_, _, _, _)), !,               % a variable template: its instance's value
    cpp_targ_values(Args0, Args), cpp_instantiate_variable(N, Args, E).
%% A BRACED TEMPORARY `T{a, b}' (the reader's braced_temp/1, version 113) of a class WITH an initializer_list constructor takes the
%% list through it FIRST ([over.match.list]/1): `std::vector<int>{5}' is one element and `std::vector<std::string>{"a", "b"}' two
%% strings, never the (size, value) or (first, last) constructors the items would fit as arguments. Any other class, a scalar, a bound
%% type parameter: the call it was, where the braces and the parentheses mean one thing.
cpp_expr(Ctx, braced_temp(call(F, Vs)), E) :- cpp_braced_ctad(F, TN, Args, F1), \+ cpp_class_l(TN, _), \+ ccl_typedef_of(TN, _),   % A BRACED TEMPORARY OF A CLASS TEMPLATE'S NAME deduces as a braced declaration does, the list first (cpp_ctad_init/4; 0.201): `std::vector{4, 5}' is a vector<int> of two, where the call road deduced through `vector(size_type, const value_type &)' and made four copies of 5
    findall(item([], V), member(V, Vs), Items), cpp_ctad_init(TN, init(Items), Vs, Args), !, cpp_expr(Ctx, braced_temp(call(F1, Vs)), E).
cpp_expr(Ctx, braced_temp(call(F, Vs)), E) :- cpp_braced_class(F, T, C), findall(item([], V), member(V, Vs), Items), cpp_il_braced(C, Items, ET), !,
    cpp_init_list(Ctx, ET, Items, IL), cpp_temporary(T, C, [IL], E).
cpp_expr(Ctx, braced_temp(call(F, Vs)), E) :- cpp_vector_named(F, T), !, findall(item([], V), member(V, Vs), Items), cpp_expr(Ctx, compound_lit(T, init(Items)), E).   % A BRACED VECTOR, `_VecT{x...}' (0.162): its lanes, the rest zero, as a C compound literal is
cpp_expr(Ctx, braced_temp(X), E) :- !, cpp_expr(Ctx, X, E).
cpp_expr(Ctx, call(F, As), E) :- !, cpp_where(args(F), cpp_exprs(Ctx, As, As1)), cpp_where(call(F), cpp_call_adl(Ctx, F, As1, E0)), cpp_copies(E0, E1), cpp_consteval_fold(E1, E).
%% A MEMBER NAMED THROUGH AN OBJECT BY ITS QUALIFIED NAME ([expr.ref]/7, [class.qual]; 0.112): `b.A::v' is the member
%% v of b's A sub-object -- a base's data member the derived class hides -- and `b.A::f()', `p->A::f()' call A's f
%% over that sub-object and never virtually, which is 0.73's rule for a qualified call inside a class, through an
%% object. The qualifier names the object's class or a base of it; anything else is refused by name.
cpp_expr(Ctx, member(X, scoped(Path, N)), E) :- atom(N), !, cpp_expr(Ctx, X, X1), cpp_qual_object(X1, Path, C, B), cpp_qual_member(B, C, N, E).
cpp_expr(Ctx, arrow(X, scoped(Path, N)), E) :- atom(N), !, cpp_expr(Ctx, X, X0), cpp_arrow_object(X0, X1), cpp_qual_object(deref(X1), Path, C, B), cpp_qual_member(B, C, N, E).
cpp_expr(Ctx, member(X, N), E) :- !, cpp_expr(Ctx, X, X1),
    ( nb_getval('$cpp_in_lib', no), cpp_class_of_type_of(X1, CA) -> cpp_check_access_obj(Ctx, CA, N) ; true ),   % the member's access, where the program names it (0.117)
    (   cpp_class_of_type_of(X1, C), cpp_data_member(C, N, Hops), Hops \== [] -> cpp_hops(X1, Hops, B), cpp_xvalue_member(member(B, N), E)
    ;   cpp_class_of_type_of(X1, C), \+ cpp_data_member(C, N, _), cpp_static_through_object(C, N, E0) -> E = E0   % A STATIC NAMED THROUGH AN OBJECT, `__ct.space', which C++ allows: ctype_base's masks through a facet
    ;   atom(N), ccl_type_of(X1, XT0), ccl_unref(XT0, XT), cpp_scalar_object(XT) -> cpp_refuse(0, no_member(N, XT))   % a scalar has no member (0.127)
    ;   cpp_xvalue_member(member(X1, N), E) ).
cpp_expr(Ctx, arrow(X, N), E) :- !, cpp_expr(Ctx, X, X0), cpp_arrow_object(X0, X1),
    ( nb_getval('$cpp_in_lib', no), cpp_pointee_class_of(X1, CA) -> cpp_check_access_obj(Ctx, CA, N) ; true ),
    (   cpp_pointee_class_of(X1, C), cpp_data_member(C, N, Hops), Hops \== [] -> cpp_access(X1, N, Hops, E)
    ;   cpp_pointee_class_of(X1, C), \+ cpp_data_member(C, N, _), cpp_static_through_object(C, N, E0) -> E = E0
    ;   E = arrow(X1, N) ).
cpp_expr(Ctx, bin('<=>', A, B), E) :- !, cpp_expr(Ctx, A, A1), cpp_expr(Ctx, B, B1),         % C++20: the three-way comparison, an int for scalars (-1, 0, 1); a class's operator<=> when it has one
    (   cpp_class_of_type_of(A1, C) -> ( cpp_method(C, operator('<=>'), [B1], Name, Hops) -> cpp_hops(A1, Hops, Base), cpp_object_arg(Name, addr(Base), Obj), E = call(id(Name), [Obj, B1]) ; cpp_free_operator_call('<=>', A1, [B1], E0) -> E = E0 ; cpp_refuse(0, three_way_comparison_of_a_class(C)) )
    ;   ( cpp_op_operand(A1) ; cpp_op_operand(B1) ) -> ( cpp_free_operator_call('<=>', A1, [B1], E0) -> E = E0 ; cpp_arg_type(A1, TA), cpp_refuse(0, three_way_comparison_of_a_class(TA)) )
    ;   cpp_scalar_ordering(A1, B1, E) ).   % a FREE `operator<=>' too (0.113), a hidden friend among them ([over.match.oper]/3), and a plain struct with none is no scalar: `friendreq.cpp'
%% `noexcept(e)' ([expr.unary.noexcept]; 0.109): libc++ is compiled without exceptions here (0.50) and nothing it calls
%% throws, so the operator is true unless its operand holds a `throw' -- `integral_constant<bool,
%% noexcept(declval<_Tp>().~_Tp())>' keyed its instance by the unfolded form and ranges::begin's constraint failed
%% A CONCEPT-ID IN AN EXPRESSION is a prvalue of type bool ([temp.names]/8; 0.109): `(int) std::same_as<A, B>'
cpp_expr(_, X, bool(V)) :- ( X = id(tmpl(C, Args)) ; X = tmpl(C, Args) ; X = scoped(_, tmpl(C, Args)) ; X = id(scoped(_, tmpl(C, Args))) ), atom(C), cpp_concept_known(C), !,
    ( catch(cpp_concept_holds(C, Args), error(not_lowered(_), _), fail) -> V = true ; V = false ).
cpp_expr(_, requires_expr(Ps, Rs), bool(V)) :- !, ( catch(cpp_satisfied(requires_expr(Ps, Rs)), error(not_lowered(_), _), fail) -> V = true ; V = false ).   % A REQUIRES-EXPRESSION IS A bool PRVALUE ([expr.prim.req]/1; 0.110): `enable_view = derived_from<T, view_base> || requires { ... }', taken apart as code it folded to nothing
cpp_expr(Ctx, noexcept_expr(E), bool(V)) :- !, ( cpp_nx_throws(Ctx, E) -> V = false ; V = true ).
cpp_expr(Ctx, co_await(E), X) :- !, cpp_coro_operand(E, Op0), cpp_coro_awaiter(Ctx, Op0, Op), cpp_expr(Ctx, co_await_raw(Op, normal), X).
cpp_expr(Ctx, co_yield(E), X) :- !, cpp_expr(Ctx, co_await_raw(call(member(id('$promise'), yield_value), [E]), normal), X).
cpp_expr(Ctx, co_await_raw(Op, Kind), X) :- !, ( ccl_declared('$promise', PT) -> true ; cpp_refuse(0, co_await_outside_a_coroutine) ),
    ccl_gensym('$aw', N), ( cpp_coro_lvalue(Op) -> VT = ref([], base([], [auto])) ; VT = base([], [auto]) ),
    H = call(scoped([std, tmpl(coroutine_handle, [PT])], from_address), [call(id('__builtin_coro_frame'), [])]),
    cpp_expr(Ctx, stmt_expr(block([declaration(0, none, base([], [auto]), [var(N, VT, Op)]),
        if(0, not(call(member(id(N), await_ready), [])), coro_suspend(0, Kind, call(member(id(N), await_suspend), [H])), none),
        expr(0, call(member(id(N), await_resume), []))])), X).
%% a UNARY operator on a class goes to the class's operator, as a binary one already did: `*it', `++it', `it++'
%% (postfix takes the int C++ marks it with), `!x', `-x', `~x'; anything not a class keeps the form it had
cpp_expr(Ctx, deref(A), E)  :- !, cpp_expr(Ctx, A, A1), cpp_deref_operand(A1), cpp_operator('*', A1, [], deref(A1), E).
cpp_expr(Ctx, preinc(A), E) :- !, cpp_expr(Ctx, A, A1), cpp_operator('++', A1, [], preinc(A1), E).
cpp_expr(Ctx, predec(A), E) :- !, cpp_expr(Ctx, A, A1), cpp_operator('--', A1, [], predec(A1), E).
cpp_expr(Ctx, postinc(A), E) :- !, cpp_expr(Ctx, A, A1), ( cpp_class_of_type_of(A1, _) -> cpp_operator('++', A1, [int(0)], postinc(A1), E) ; E = postinc(A1) ).
cpp_expr(Ctx, postdec(A), E) :- !, cpp_expr(Ctx, A, A1), ( cpp_class_of_type_of(A1, _) -> cpp_operator('--', A1, [int(0)], postdec(A1), E) ; E = postdec(A1) ).
cpp_expr(Ctx, not(A), E)    :- !, cpp_expr(Ctx, A, A1), cpp_to_bool(A1, A2), cpp_operator('!', A1, [], not(A2), E).
cpp_expr(Ctx, neg(A), E)    :- !, cpp_expr(Ctx, A, A1), cpp_operator('-', A1, [], neg(A1), E).
cpp_expr(Ctx, bitnot(A), E) :- !, cpp_expr(Ctx, A, A1), cpp_operator('~', A1, [], bitnot(A1), E).
cpp_expr(Ctx, bin(Op, A, B), E) :- memberchk(Op, ['&&', '||']), !, cpp_expr(Ctx, A, A1), cpp_cond_branch(Ctx, B, B0, Tb), cpp_cond_flag(Tb, B0, B1), cpp_to_bool(A1, A2), cpp_to_bool(B1, B2), cpp_operator(Op, A1, [B1], bin(Op, A2, B2), E).   % the right operand's temporaries flagged (cpp_cond_branch, 0.201)
cpp_expr(Ctx, bin(Op, A, B), E) :- !, cpp_expr(Ctx, A, A1), cpp_expr(Ctx, B, B1), cpp_operator(Op, A1, [B1], bin(Op, A1, B1), E).
cpp_expr(Ctx, bind_ref(A, B), bind_ref(A1, B1)) :- !, cpp_expr(Ctx, A, A1), cpp_expr(Ctx, B, B1).   % a reference member BOUND in a constructor: the slot takes the address
cpp_expr(Ctx, assign(Op, A, B), E) :- Op \== '=', !, cpp_expr(Ctx, A, A1), cpp_expr(Ctx, B, B1), cpp_operator(Op, A1, [B1], assign(Op, A1, B1), E0), cpp_rhs_first(E0, E).
cpp_expr(Ctx, assign('=', A, init(Items)), E) :- \+ ( member(item(D, _), Items), D \== [] ), cpp_expr(Ctx, A, A1), cpp_class_of_type_of(A1, C),   % A BRACED LIST ASSIGNED TO A CLASS ([expr.ass]/9; 0.132): where the class's own operator= takes no list, `x = {a, b}' is `x = C{a, b}', the temporary through the constructors, then the assignment -- libc++'s split_view writes `__next_ = {__cur_, __cur_};' over a subrange, and the list reached the lowering
    \+ catch(cpp_method(C, operator('='), [init(Items)], _, _), error(not_lowered(_), _), fail), !,
    findall(V, member(item(_, V), Items), Vs), ( Vs == [] -> T = call(id(C), []) ; T = braced_temp(call(id(C), Vs)) ),
    cpp_expr(Ctx, assign('=', A, T), E).
cpp_expr(Ctx, assign('=', A, B), E) :- !, cpp_expr(Ctx, A, A1), cpp_expr(Ctx, B, B10), cpp_assign_sliced(A1, B10, B1),
    (   cpp_class_of_type_of(A1, C), cpp_assign_from_own(B1, C, B0), \+ cpp_written_copy_assign(C),   % THE IMPLICIT COPY OR MOVE ASSIGNMENT where the class writes operator= for other types only (0.112)
        ( ( cpp_dtor(C, _) ; cpp_dynamic_class(C) ) -> cpp_implicit_assign(C, B1, Name) ; Name = none )   % ... made where it can be: a class holding OWNERS takes the roads below (`d[n] = move(x)', the holder's fresh slot); A CLASS WITH A TABLE assigns memberwise (0.135, cpp_dynamic_class/1)
    ->  ( Name \== none -> cpp_object_arg(Name, addr(A1), Obj), cpp_ref_args_of(Name, [B1], [B2]), cpp_rhs_first(call(id(Name), [Obj, B2]), E) ; E = assign('=', A1, B0) )
    ;   cpp_class_of_type_of(A1, C), cpp_method(C, operator('='), [B1], Name, Hops)              % the class's operator=, copy or move by the value category
    ->  cpp_hops(A1, Hops, Base), cpp_object_arg(Name, addr(Base), Obj), cpp_ref_args_of(Name, [B1], [B2]), cpp_copies(call(id(Name), [Obj, B2]), E0), cpp_rhs_first(E0, E)   % THROUGH THE CALL'S ARGUMENT PASS (0.132), as any call: `l = {4, 5, 6};' over `operator=(std::initializer_list<int>)' left the braced list raw for the lowering
    ;   cpp_class_of_type_of(A1, C), \+ cpp_dtor(C, _), ccl_type_of(B1, BT), BT \== unknown, \+ cpp_class_of_type_of(B1, C), cpp_converting_ctor(C, B1)   % A VALUE OF ANOTHER TYPE ASSIGNED converts through the class's converting constructor, as a call's argument (0.66) and a return (0.79) do: libc++'s `__f = erase(__f)' stores an `iterator' into a `const_iterator', and taken raw the lowering cast one struct to the other
    ->  cpp_temporary(base([], [typedef(C)]), C, [B1], B2), E = assign('=', A1, B2)
    ;   cpp_class_of_type_of(A1, C), \+ cpp_dtor(C, _), cpp_class_of_type_of(B1, D), D \== C, ccl_type_of(A1, AT), AT \== unknown, cpp_conv_to(B1, AT, B2), B2 \== B1   % ... OR THROUGH THE VALUE'S OWN CONVERSION OPERATOR ([over.match.copy]/1.2; 0.216): `sv = s' over a std::string is `sv = s.operator string_view()' -- taken raw, the lowering cast the string's struct to the view's
    ->  E = assign('=', A1, B2)
    ;   ccl_type_of(A1, AT), AT \== unknown, ccl_resolve_type(AT, arr(_, _)) -> ( B1 = move(B0) -> true ; B0 = B1 ), E = call(id(memcpy), [addr(A1), addr(B0), sizeof_type(AT)])   % an array assigned (the memberwise assignment's): its bytes
    ;   cpp_class_of_type_of(A1, C), cpp_dtor(C, _), cpp_class_of_type_of(B1, C), cpp_implicit_assign(C, B1, Name)   % THE IMPLICIT MEMBERWISE ASSIGNMENT, where no operator= is written
    ->  cpp_object_arg(Name, addr(A1), Obj), cpp_ref_args_of(Name, [B1], [B2]), cpp_rhs_first(call(id(Name), [Obj, B2]), E)
    ;   cpp_class_of_type_of(A1, C), cpp_dtor(C, _), \+ B1 = move(_) -> cpp_refuse(0, assignment_to_a_class_with_destructor(C))   % the old value would never be destroyed, the new freed twice; a move into a fresh slot is the holder's business
    ;   cpp_overload_marker(B1), ccl_type_of(A1, AT), AT \== unknown, cpp_conv_to(B1, AT, B2), B2 \== B1 -> E = assign('=', A1, B2)   % AN OVERLOAD SET ASSIGNED, or a member initialized from one (0.126): the target chooses ([over.over]; cpp_conv_to), as an argument's and a declaration's already did
    ;   \+ cpp_class_of_type_of(A1, _), cpp_class_of_type_of(B1, _), ccl_type_of(A1, AT), AT \== unknown   % A CLASS VALUE ASSIGNED TO A SCALAR converts through its conversion operator (0.112), as a declaration's and an argument's have since 0.78: a member of function-pointer type initialized from a captureless lambda
    ->  cpp_conv_to(B1, AT, B2), E = assign('=', A1, B2)
    ;   E = assign('=', A1, B1) ).
cpp_expr(Ctx, index(A, args(Is)), E) :- !, cpp_expr(Ctx, A, A1), cpp_exprs(Ctx, Is, Is1),        % C++23: a[i, j] is the class's operator[](i, j)
    ( cpp_operator('[]', A1, Is1, none, E), E \== none -> true ; length(Is1, N), cpp_refuse(0, subscript_arity(N)) ).
cpp_expr(Ctx, index(A, I), E) :- !, cpp_expr(Ctx, A, A1), cpp_expr(Ctx, I, I1), cpp_operator('[]', A1, [I1], index(A1, I1), E).
cpp_expr(Ctx, decay_copy(X), E) :- !, cpp_expr(Ctx, X, X1),                                       % C++23: auto(x), auto{x}: a copy of the decayed value
    (   ccl_type_of(X1, T0), T0 \== unknown
    ->  cpp_decayed(T0, T), ( cpp_class_of_type(T, C) -> ( cpp_dtor(C, _), cpp_lvalue(X1) -> cpp_refuse(0, copy_of_a_class_with_destructor(C)) ; E = X1 ) ; E = cast(T, X1) )
    ;   E = X1 ).
cpp_expr(Ctx, global(X), E) :- !, cpp_new_expr(Ctx, yes, [], X, E).   % `::new', `::delete': the global allocation and deallocation functions alone ([expr.new]/12, [expr.delete]/9; 0.202)
cpp_expr(Ctx, X, E) :- cpp_new_form(X), !, cpp_new_expr(Ctx, no, [], X, E).   % a new- or a delete-expression (cpp_new_expr/5, the allocation functions' section)
cpp_expr(_, coro_size, coro_size) :- !.                               % a coroutine state's size and block, the lowering's (0.202)
cpp_expr(_, coro_mem, coro_mem) :- !.
cpp_expr(_, alloc(M, T, C), alloc(M, T, C)) :- !.                    % the allocation and the deallocation the desugaring makes, whole where it makes them (0.202)
cpp_expr(_, dealloc(D, F, X), dealloc(D, F, X)) :- !.
cpp_expr(Ctx, cast(T0, X), E) :- !, cpp_type(T0, T), cpp_expr(Ctx, X, X1), cpp_cast_to(X1, T, X2), ( cpp_cast_made(T, X1, X2) -> E = X2 ; E = cast(T, X2) ).   % `(long) pos': a class value through its conversion operator, an explicit one too
cpp_expr(_, tmpl(N, Args0), E) :- atom(N), cpp_variable_template(N), !, cpp_targ_values(Args0, Args), cpp_instantiate_variable(N, Args, E).   % A VARIABLE TEMPLATE'S ID AS A BARE EXPRESSION, `__is_tuple_v<_Tuple1>' in a conjunction (0.50 had the form read as a type): unevaluated it kept the whole `&&' from folding, and the enable_if behind libc++'s piecewise key extraction came out false for every string key
cpp_expr(_, ccast(functional, base(_, [void]), none), cast(base([], [void]), int(0))) :- !.   % `void()', which the reader gives as a functional cast of nothing: the void value
cpp_expr(_, ccast(functional, T0, none), ccast(functional, T, Z)) :- \+ T0 = base(_, [typedef(_)]), !, cpp_type(T0, T), cpp_zero_of(T, Z).   % `int()', `char{}' WRITTEN, value-initialization ([expr.type.conv]/2, [dcl.init]/8): the type's zero (0.201) -- the reader gives a functional cast of nothing, which reached the lowering (`expr(none)') wherever the program wrote one: `int k = int();', `std::string s(3, char());', libc++'s wstring_convert::to_bytes; a bound template parameter's `T()' was cpp_type_called/3's
cpp_expr(_, construct(base(_, [void]), []), cast(base([], [void]), int(0))) :- !.   % `void()' is the void value: libc++ writes `for (__pp = __cp, void(), __cp = ...)' to keep an overloaded comma out, and desugared to nothing the lowering met a missing operand
cpp_expr(Ctx, construct(T0, As0), E) :- !,                                                   % `typename X::y(args)', the reader's construct/2 (0.44), never desugared until libc++'s string wrote `__self_view(typename __self_view::__assume_valid(), data(), size())': the type resolved, then the type-call road (a class's temporary, a scalar's cast)
    ( T0 = base(Q, [typedef(id(N))]) -> T1 = base(Q, [typedef(N)]) ; T1 = T0 ), cpp_type(T1, T), cpp_exprs(Ctx, As0, As), cpp_type_call(T, As, E).
cpp_expr(_, alignof_type(T0), alignof_type(T)) :- !, cpp_type(T0, T).                         % the type goes through the hook, so `alignof(__max_align_impl<...>)' names its instance
cpp_expr(_, sizeof_type(T0), sizeof_type(T)) :- !, cpp_type(T0, T),
    ( T = base(_, [typedef(C)]), atom(C), cpp_incomplete_class(C) -> cpp_refuse(0, incomplete_type(C)) ; true ).   % sizeof AN INCOMPLETE TYPE IS ILL-FORMED ([expr.sizeof]/1), and in a template argument that is the substitution failure libc++'s `__has_default_three_way_comparator<L, R, sizeof(__default_three_way_comparator<L, R>) >= 0>' detects by; folded to a size it said every pair had a default comparator and the eager road called an operator() of nothing
cpp_expr(Ctx, compound_lit(T0, init(Items)), E) :- cpp_designated(Items), cpp_type(T0, T), cpp_class_of_type(T, C), cpp_class_l(C, cls(_, Data, _, _, _)), cpp_agg_slots(Items, Data, 0, [], _), !,
    cpp_agg_values(Data, Items, Vs0), cpp_exprs(Ctx, Vs0, Vs), cpp_agg_temp(T, C, Data, Vs, E).
cpp_expr(Ctx, compound_lit(T0, I), compound_lit(T, I1)) :- !, cpp_type(T0, T), cpp_expr(Ctx, I, I1).
%% `Gen{h}' inside the class template Gen is read as a functional cast (the reader knows Gen as a template there):
%% to an AGGREGATE of another class's value it is LIST-INITIALIZATION ([dcl.init.list]), the first member from it --
%% a coroutine's `return Gen{handle}' (0.108)
cpp_expr(Ctx, ccast(functional, T0, X), E) :- cpp_type(T0, T), ( cpp_class_of_type(T, C) -> true ; T = base(_, [typedef(C)]), atom(C), '$cpp_iname'(_, _, C) ),   % ... the instance still being registered, its nested class walked
    ( cpp_class_l(C, _) -> cpp_aggregate_class(C) ; true ),
    cpp_expr(Ctx, X, X1), cpp_class_of_type_of(X1, XC), XC \== C, !, cpp_expr(Ctx, compound_lit(T, init([item([], '$cpp_walked'(X1))])), E).
cpp_expr(Ctx, ccast(functional, base(Q, [typedef(C)]), X), E) :- cpp_class_l(C, _), !, cpp_expr(Ctx, X, X1), cpp_temporary(base(Q, [typedef(C)]), C, [X1], E).
cpp_expr(Ctx, ccast(K, T0, X), E) :- !, cpp_type(T0, T), cpp_expr(Ctx, X, X1), cpp_cast_to(X1, T, X2), ( cpp_cast_made(T, X1, X2) -> E = X2 ; E = ccast(K, T, X2) ).
cpp_expr(Ctx, paren(X), E) :- !, cpp_expr(Ctx, X, E).   % a returned name's parentheses, which only decltype(auto)'s deduction reads (0.197)
cpp_expr(Ctx, move(X), E) :- !, cpp_expr(Ctx, X, X1),
    (   ccl_type_of(X1, T), T \== unknown, ( cpp_holds_owners(T) ; ccl_unref(T, T1), cpp_class_of_type(T1, _) ) -> E = move(X1)
    ;   cpp_plain_xvalue(X1, RT) -> E = ccast(static, RT, X1)                                                  % THE MOVE OF A PLAIN STRUCT (a C struct: no constructor, destructor or owner) IS AN XVALUE TOO (0.122): `static_cast<S &&>(s)', so `f(const S &)' beside `f(S &&)' chooses the second for `f(std::move(s))' as it does for a class; it was the value, an lvalue, and the first declared won
    ;   cpp_scalar_xvalue(X1, RT) -> E = ccast(static, RT, X1)                                                 % THE MOVE OF A SCALAR IS AN XVALUE (0.201): `static_cast<int &&>(x)', as libc++'s std::move is -- it was the value, an lvalue to every rule that reads a category, so a forwarding reference deduced `int &' (`kind(std::move(x))' an lvalue's answer, libc++ 18's `__reduce(..., std::move(__init), ...)' an `optional<long &>') and `f(int &&)' beside `f(int &)' took the second
    ;   E = X1 ).   % move of an int is the int (a template's T); OF A CLASS VALUE IT STAYS ([expr.xvalue]): the value category is what overload resolution reads, and dropped here `t.insert(std::move(nh))' found no `insert(node_type &&)' and took `insert(const value_type &)' through the handle's `operator bool'
cpp_expr(Ctx, stmt_expr(block(Is)), stmt_expr(block(Js))) :- !, cpp_in_frame(cpp_stmts(Ctx, Is, Js)).
cpp_expr(Ctx, lambda(Caps, Ps, Ret, Body), E) :- !, cpp_lambda(Ctx, Caps, Ps, Ret, Body, E).
cpp_expr(_, str(S), str(S)) :- !.
cpp_expr(_, u8str(S), u8str(S)) :- !.   % C++20's u8 literal (0.196)
cpp_expr(Ctx, cond(C, A, B), cond(C2, A1, B1)) :- !, cpp_expr(Ctx, C, C1), cpp_to_bool(C1, C2), cpp_cond_branch(Ctx, A, A0, Ta0), cpp_cond_branch(Ctx, B, B0, Tb0),
    cpp_cond_copy_arm(A0, B0, Ta0, A00, Ta), cpp_cond_copy_arm(B0, A0, Tb0, B00, Tb), cpp_cond_flag(Ta, A00, A1), cpp_cond_flag(Tb, B00, B1).   % each arm's temporaries flagged (cpp_cond_branch, 0.201), an lvalue arm beside a prvalue arm copied (cpp_cond_copy_arm); THE CONDITION CONTEXTUALLY CONVERTED TO BOOL ([expr.cond]/1; 0.137), through a class's `operator bool' as `if' and `!' have it: `l ? 1 : 0' over an `optional' compared the struct with zero
cpp_expr(Ctx, E, E1) :- E =.. [F|As], cpp_exprs(Ctx, As, Bs), E1 =.. [F|Bs].

%% ---- expressions, bottom up ----------------------------------------------------------
cpp_exprs(_, [], []).
cpp_exprs(Ctx, [E|Es], [E1|Fs]) :- cpp_expr(Ctx, E, E1), cpp_exprs(Ctx, Es, Fs).
cpp_udl_args(Lit, [cast(base([], [unsigned, long, long]), Lit)]) :- ( Lit = int(_) ; Lit = uint(_) ; Lit = long(_) ; Lit = ulong(_) ), !.
cpp_udl_args(float(F), [cast(base([], [long, double]), float(F))]) :- !.
cpp_udl_args(ldbl(A), [cast(base([], [long, double]), ldbl(A))]) :- !.   % the literal's text as a long double, rounded once (0.160)
cpp_udl_args(str(Cs), [str(Cs), cast(base([], [unsigned, long]), int(N))]) :- !, length(Cs, N).
cpp_udl_args(u8str(Cs), [u8str(Cs), cast(base([], [unsigned, long]), int(N))]) :- !, length(Cs, N).   % char8_t's: a unit a byte (0.196)
cpp_udl_args(wstr(Cs), [wstr(Cs), cast(base([], [unsigned, long]), int(N))]) :- !, ccl_utf8_count(Cs, N).
cpp_udl_args(u32str(Cs), [u32str(Cs), cast(base([], [unsigned, long]), int(N))]) :- !, ccl_utf8_count(Cs, N).
cpp_udl_args(u16str(Cs), [u16str(Cs), cast(base([], [unsigned, long]), int(N))]) :- !, ccl_utf16_count(Cs, N).
cpp_udl_args(Lit, [Lit]).
cpp_lazy_fn_value(N, Name) :- \+ cpp_local(N), findall(Ps, '$cpp_fn'(N, _, Ps, yes, lazy(_)), [Ps]), cpp_fn_name(N, Ps, yes, Name), cpp_use_fn(N, Ps, Name).   % one definition: the value has one type; an overload set needs its target (not done)
cpp_lazy_fn_value(N, Name) :- \+ cpp_local(N), \+ '$cpp_fn'(N, _, _, yes, _), findall(Ps, '$cpp_fn'(N, _, Ps, no, decl(_, _)), [Ps]), cpp_fn_name(N, Ps, no, Name), Name \== N, cpp_use_mangled(N, Ps, Name).   % ... and one a header only DECLARES, the shipped library's (0.201): its Itanium symbol, declared -- <barrier> hands `&__destroy_barrier_algorithm_base' to a unique_ptr as its deleter, and the plain name was an undefined symbol at the link
%% A STATIC MEMBER FUNCTION NAMED BARE AS A VALUE IS ITS THUNK (0.126): `fn = prep;' in a member's body, or `Buf{16, prep}' in a base's initializer,
%% with `prep' a static function of the class, its base or its enclosing class ([expr.prim.id]/2, [class.nest]/1). The scoped name `C::prep' had
%% the thunk since 0.100 (cpp_static_thunk: a static method takes a null `this', so its address is no `void (*)(size_t)'); the bare name was
%% left as it stood, `undeclared(prep)'. libc++ 21's `__allocating_buffer' constructor hands its static `__prepare_write' to the output buffer
%% it derives from, and `std::print' and `std::format' to a string went through it. Only a STATIC function is a candidate for a name used as a
%% value ([over.over]: a non-static member needs `&C::f'), so the member `__prepare_write(size_t)' beside the static `__prepare_write(
%% __output_buffer &, size_t)' is no overload set; several static ones are, and the value waits for its target ('$staticfn'(C, N), cpp_conv_to).
%% The class is the one being walked, the hidden friend's, or the one a lambda that captured `this' was made in.
cpp_static_fn_value(Ctx, N, E) :- atom(N), cpp_static_fn_class(Ctx, C),
    cpp_encl_chain(C, Cs), member(K, Cs), cpp_static_fn_owner(K, N, O), !,
    cpp_static_fn_names(O, N, Names),
    (   Names = [Name] -> cpp_static_thunk(O, N, Name, Thunk), E = id(Thunk)
    ;   Names = [_, _|_], E = '$staticfn'(O, N) ).
cpp_static_fn_names(C, N, Names) :- cpp_class(C, cls(_, _, Ms, _, _, _)),
    findall(Name, ( member(method(_, Qs, _, N, Ps, _, _), Ms), memberchk(static, Qs), cpp_mangle_q(C, N, Qs, Ps, Name) ), Names).
cpp_static_fn_class(Ctx, C) :- atom(Ctx), Ctx \== none, !, C = Ctx.
cpp_static_fn_class(none, C) :- cpp_class_ctx(C), C \== none, !.
cpp_static_fn_class(Ctx, C) :- cpp_closure_this(Ctx, C).
cpp_static_fn_owner(C, N, C) :- '$cpp_sfn'(C, N), !.
cpp_static_fn_owner(C, N, O) :- cpp_base_scope(C, B), cpp_static_fn_owner(B, N, O), !.
cpp_static_fn_called(C, N) :- cpp_encl_chain(C, Cs), member(K, Cs), cpp_static_fn_owner(K, N, _), !.   % N a static member function of C, its bases or its enclosing classes (0.201; cpp_targ_value/2)
cpp_overload_marker('$staticfn'(_, _)).
cpp_overload_marker('$memaddr'(_, _)).
%% A FILE-SCOPE `const' OBJECT OF INTEGRAL TYPE WITH A CONSTANT INITIALIZER IS A CONSTANT EXPRESSION
%% ([expr.const]; the rule 0.63 gave a `const' LOCAL, C23's `constexpr' object the C side): libc++ writes
%% `inline const size_t __aligned_storage_max_align = alignof(__max_align_impl<...>);' and EVERY aligned_storage
%% asks for that name inside a variable template's initializer, where only a constant will do -- read as a global
%% it refused `variable_template_not_constant'. The initializer is DESUGARED before it is folded (it names a
%% class template's instance), under a guard per name as a static const's is (cpp_fold_static), and the answer is
%% remembered: folding it instantiates a class, and a program names such a constant everywhere.
cpp_global_const(N, V) :- atom(N), \+ cpp_local(N), atom_concat('$cpp_gconst:', N, K),
    (   nb_current(K, V0) -> V = V0                                      % only a SUCCESS is remembered: the fold instantiates a class, and asked once from inside a candidate whose walk is abandoned it would fail for good
    ;   cpp_fold_global(N, V), nb_setval(K, V) ).
cpp_fold_global(N, V) :-
    cpp_hdr_item(N, declaration(_, Sto, base(Q, S), [var(N, _, Init)|_])), Init \== none, Sto \== extern, memberchk(const, Q),
    atom_concat('$cpp_gfolding:', N, G), \+ nb_current(G, yes), nb_setval(G, yes),
    ( catch(cpp_expr(none, Init, E1), error(not_lowered(_), _), fail) -> true ; E1 = '$none' ),
    nb_setval(G, no), E1 \== '$none', S \== [auto],
    ( E1 = bool(_) -> V = E1 ; cpp_const_value(E1, K2) -> V = int(K2) ; fail ).
cpp_member_address(C, N, E) :- findall(m(Qs, R0, Ps0, V0), cpp_class_method(C, N, Qs, R0, Ps0, V0), [M|Rest]), !,
    ( Rest == [] -> cpp_method_address(C, N, M, E) ; E = '$memaddr'(C, N) ).   % SEVERAL OVERLOADS: the target chooses ([over.over]; 0.112, refused as overloaded_member_address since 0.88), cpp_conv_to
cpp_member_address(C, N, cast(memptr(C, [], MT), long(Off))) :- cpp_data_member(C, N, Hops), !,   % A POINTER TO A DATA MEMBER IS ITS BYTE OFFSET (the Itanium ABI's representation; 0.99), read through by `x.*pm' and `p->*pm' (cpp_memptr_read)
    cpp_data_member_type(C, N, MT), append(Hops, [N], Path), ccl_resolve_type(base([], [typedef(C)]), T), cpp_offsetof(T, Path, 0, Off).
cpp_member_address(C, N, cast(memptr(C, [], MT), long(Off))) :- atom(C), \+ cpp_class_l(C, _), ccl_tag(C, Ms), is_list(Ms), memberchk(member(MT0, N, _), Ms),   % A POINTER TO A DATA MEMBER OF A PLAIN STRUCT (0.126): a struct of data members alone stays C's and is no registered class, `&Pt::x' met `no_member(Pt, x)' unless the program also derived from it -- `std::invoke(&Pt::x, p)', `std::mem_fn(&Pt::x)' and a ranges projection `&Pt::x' are written over exactly such aggregates (invokedata.cpp)
    ccl_resolve_type(MT0, MT), ccl_resolve_type(base([], [typedef(C)]), T), cpp_offsetof(T, [N], 0, Off), !.
%% A MEMBER FUNCTION THAT A BASE DECLARES, named through the derived class (`&C::va', va A's), is a pointer to member OF
%% THAT BASE ([expr.unary.op]/3: `int (A::*)()'), which converts to C's where a C's is wanted, its adj grown by the base's
%% offset (ir_convert/6): it was refused, no_member(C, va) (0.161; memptr_main.cpp).
cpp_member_address(C, N, E) :- atom(C), cpp_method_base(C, N, D), !, cpp_member_address(D, N, E).
cpp_member_address(C, N, _) :- cpp_refuse(0, no_member(C, N)).
cpp_method_address(C, N, m(Qs, R1, Ps1, V0), cast(memptr(C, [], fn(R, Ps, V)), addr(id(Name)))) :- \+ cpp_method_slot_key(C, N, Ps1, _), !,
    cpp_in_class(C, ( cpp_type_or_self(R1, R), cpp_plain_params(Ps1, Ps) )),
    cpp_mangle_q(C, N, Qs, Ps1, Name), cpp_use_member(C, Name), cpp_mfq_v(Qs, V0, V).
%% A POINTER TO A VIRTUAL MEMBER IS `1 + the slot's byte offset' in the table (the Itanium ABI's representation; 0.100),
%% which the call reads back (cpp_memptr_call): the object's own table, so `&Shape::area' on a base pointer dispatches
cpp_method_address(C, N, m(Qs, R1, Ps1, V0), cast(memptr(C, [], fn(R, Ps, V)), Rep)) :-
    cpp_method_slot_key(C, N, Ps1, K), cpp_slot_offset(C, N, K, Off),
    ( ccl_memptr_arm -> Rep = memfn(int(Off), int(1)) ; Bits is Off + 1, Rep = int(Bits) ),   % on arm64 ARM's form (0.161, ccl_memptr_arm): the offset itself, the mark in adj
    cpp_in_class(C, ( cpp_type_or_self(R1, R), cpp_plain_params(Ps1, Ps) )), cpp_mfq_v(Qs, V0, V).
%% A MEMBER'S ADDRESS HAS THE MEMBER'S QUALIFIERS in its type (0.181): `&A::cf' of `int cf(int) const' is `int (A::*)(int) const',
%% `const' and a ref-qualifier on the member function type (q(V, Qs), the reader's form); a member's `volatile' the reader drops
cpp_mfq_v(Qs, V0, V) :- cpp_method_mfq(Qs, Ms), ( Ms == [] -> V = V0 ; V = q(V0, Ms) ).
cpp_method_mfq(Qs, Ms) :- findall(M, ( member(Q-M, [const-const, refq(lvalue)-'&', refq(rvalue)-'&&', noexcept-noexcept, noexcept(_)-noexcept]), memberchk(Q, Qs) ), Ms).   % a noexcept member's type is noexcept too (0.198)
%% a member's qualifiers fit a target's where they are the target's but for noexcept, which the function pointer conversion takes away
%% and never gives ([conv.fctptr]; 0.198): a noexcept member's address goes to `int (A::*)() const', a plain one to no noexcept target
cpp_mfq_fits(MQs, TQs) :- delete(MQs, noexcept, M1), delete(TQs, noexcept, T1), M1 == T1, ( memberchk(noexcept, TQs) -> memberchk(noexcept, MQs) ; true ).
cpp_slot_offset(C, M, K, Off) :- cpp_class_l(C, cls(_, _, _, _, Slots)), nth0(I, Slots, slot(M, K, _, _, _)), !, Off is I * 8.   % a table's slots are pointers, 8 bytes each, in the table's order (cpp_vt_struct)
cpp_data_member_type(C, N, MT) :- cpp_class_l(C, cls(B, Data, _, _, _)),
    ( memberchk(member(MT0, N, _), Data) -> cpp_in_class(C, cpp_type(MT0, MT)) ; B \== none, cpp_data_member_type(B, N, MT) ).
cpp_method_base(C, N, D) :- cpp_base_scope(C, B), ( cpp_class_method(B, N, _, _, _, _) -> D = B ; cpp_method_base(B, N, D) ), !.   % the first base, then each later one, that declares a member function N ([class.member.lookup])
%% THE MEMBER OF A CONST OBJECT IS CONST, AND THE MEMBER OF AN RVALUE IS AN XVALUE ([expr.mptr.oper]/6, [expr.ref]/6; 0.126): `x.*pm' carries the
%% object's `const' and, for an object that is no lvalue, is `T &&'; `p->*pm' the pointee's `const'. libc++ 18's `__invoke' reads
%% `decltype(std::declval<_A0>().*std::declval<_Fp>())' for a data member, and `invoke_result_t<int Pt::*, const Pt &>' was `int &', `<int Pt::*,
%% Pt &&>' `int &' (cpp_invoke_result is the one rule, as `__builtin_invoke' of libc++ 21 has it). A type the inference cannot settle leaves the plain read.
cpp_memptr_qualify(Kind, X, E0, E) :-
    catch(( cpp_arg_type(X, XT0), ccl_unref(XT0, XT1),
            (   Kind == obj -> XT = XT1, ( cpp_arg_lvalue(X) -> Cat = lv ; Cat = rv )
            ;   ccl_resolve_type(XT1, ptr(_, XT)), Cat = lv ),
            ( cpp_type_const(XT) -> Const = const ; Const = none ) ), _, fail), !,
    cpp_invoke_result(Const, Cat, E0, E).
cpp_memptr_qualify(_, _, E, E).
cpp_memptr_read(P, F, deref(cast(ptr([], MT), bin('+', cast(ptr([], base([], [char])), P), cast(base([], [long]), F))))) :-
    cpp_arg_type(F, FT), ccl_resolve_type(FT, memptr(_, _, MT)), MT \= fn(_, _, _), !.
cpp_memptr_read(_, _, _) :- cpp_refuse(0, pointer_to_member_function_read).
cpp_class_method(C, N, Qs, R, Ps, V) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, Qs, R, N, Ps, V, _), Ms).
%% A QUALIFIED DATA MEMBER IN A MEMBER FUNCTION IS THAT MEMBER OF `this' ([class.mfct.non.static]/2: `C::m' is
%% `(*this).C::m' where C is the class or a base of it): the hops from the class being walked down to C's
%% sub-object, then C's own hops to the member -- never the class's own member of that name, which `C::m' names past.
%% libc++ 18's `formatter<const _CharT *, _CharT>::format' reads `_Base::__parser_' through its base alias, and the
%% name `C.m' it had been was declared nowhere (0.112). A lambda that captured `this' reaches it through the closure.
cpp_qualified_data_member(Ctx, C, N, E) :- atom(N), atom(Ctx), Ctx \== none,
    cpp_base_hops(Ctx, C, H1), cpp_data_member(C, N, H2), !, append(H1, H2, Hops), cpp_access(id(this), N, Hops, E).
cpp_qualified_data_member(Ctx, C, N, E) :- atom(N), cpp_closure_this(Ctx, EC),
    cpp_base_hops(EC, C, H1), cpp_data_member(C, N, H2), !, append(H1, H2, Hops), cpp_closure_member(N, Hops, E).
%% A STATIC MEMBER FUNCTION NAMED AS A VALUE IS A PLAIN FUNCTION (0.100): a static method here takes a null `this'
%% as its first parameter (0.36), so its address is no `bool (*)(char, char)', and libc++ hands `_Traits::eq' to
%% `__find_first_of_ce' as the predicate of every `find_first_of' -- `cannot_deduce(_BinaryPredicate)'. The value is
%% a THUNK, `<Name>.fn', a function over the method's own parameters that calls it with the null this, emitted once
%% beside the method (linkonce, the library's where the class is), so its type is the function type C++ gives the
%% name and a template deduces from it; a call `C::f(args)' keeps its direct road.
%% THE THUNK IS IN PROGRESS WHILE ITS METHOD IS MADE (0.191; '$cpp_making', as every emission is): the method's own walk may name
%% it again -- std::any's `_SmallHandler<T>::__handle' makes `__create', which stores `&_SmallHandler::__handle' -- and the
%% thunk, noted only after, was emitted twice, a redefinition LLVM refused at every `std::any a = 5;'. It is declared first.
cpp_static_thunk(C, M, Name, Thunk) :-
    atom_concat(Name, '.fn', Thunk),
    (   cpp_instance_done(Thunk) -> true
    ;   cpp_making(Thunk) -> true
    ;   cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, Qs, R0, M, Ps0, _, _), Ms), memberchk(static, Qs), cpp_mangle_q(C, M, Qs, Ps0, Name), !,
        cpp_in_class(C, ( cpp_type_or_self(R0, R), cpp_resolved_params(Ps0, Ps1) )), cpp_thunk_params(Ps1, 1, Ps, Args),
        ccl_declare(Thunk, fn(R, Ps, false)),
        nb_getval('$cpp_making', K0), nb_setval('$cpp_making', [Thunk|K0]),
        (   catch(cpp_use_member(C, Name), E, ( nb_setval('$cpp_making', K0), throw(E) ))
        ->  nb_setval('$cpp_making', K0)
        ;   nb_setval('$cpp_making', K0), fail ),
        ( ccl_resolve_type(R, base(_, [void])) -> Body = block([expr(0, call(id(Name), [nullptr|Args]))]) ; Body = block([return(0, call(id(Name), [nullptr|Args]))]) ),
        cpp_instance_note(Thunk, thunk),
        ( cpp_lib_class(C) -> Lib = yes ; Lib = no ), cpp_as_lib(Lib, cpp_add_instance_items([function(0, none, R, Thunk, Ps, false, Body)])) ).
cpp_consteval_fold(E0, E) :- E0 = call(id(Name), _), atom(Name), '$cpp_consteval'(Name), !,   % a consteval METHOD (the free road folds its own, cpp_free_call)
    ( cpp_const_fold(E0, V), cpp_eval_scalar(V) -> ( integer(V) -> E = int(V) ; E = V ) ; cpp_immediate_context -> E = E0 ; cpp_refuse(0, consteval_call_not_constant(Name)) ).
cpp_consteval_fold(E, E).
%% AN IMMEDIATE FUNCTION CONTEXT (C++20 [expr.const]/16, C++23's P2564; 0.198): a call of a consteval function that does not fold is no
%% immediate invocation in a consteval function's own body, and in an IMMEDIATE-ESCALATING function -- here an instance of a function
%% template that is being made -- it makes that function an immediate one, whose own calls are then folded where they stand (the
%% caller's cpp_consteval_fold): `template <class T> constexpr int prop(T x) { return cev(x); }' and `prop(4)' are 5, where the call of
%% cev was refused `consteval_call_not_constant(cev)'. A non-constexpr template is escalated too (P2564 asks the constexpr specifier, which
%% the reader keeps on no function), a program that is ill-formed and that clang++ refuses.
cpp_immediate_context :- nb_current('$cpp_fsig', S0), cpp_fsig_unwrap(S0, fsig(_, _, _, R, _, _, Qs, _)), ( nonvar(R), R = base(Q, _), memberchk(consteval, Q) -> true ; is_list(Qs), memberchk(consteval, Qs) ), !.
cpp_immediate_context :- nb_current('$cpp_cur_fn', Cur), atom(Cur), nb_getval('$cpp_making', Ms), memberchk(Cur, Ms), !,
    ( '$cpp_consteval'(Cur) -> true ; assertz('$cpp_consteval'(Cur)), cpp_trace(immediate_escalated(Cur)) ).
cpp_qual_object(X, Path, C, B) :-
    ( cpp_scope_class(Path, C) -> true ; cpp_refuse(0, qualified_member_scope(Path)) ),
    ( cpp_class_of_type_of(X, D) -> true ; cpp_refuse(0, qualified_member_of_unknown(C)) ),
    ( cpp_base_hops(D, C, Hops) -> cpp_hops(X, Hops, B) ; cpp_refuse(0, qualified_member_not_a_base(C, D)) ).
cpp_qual_member(B, C, N, E) :- cpp_data_member(C, N, Hops), !, cpp_hops(B, Hops, B1), E = member(B1, N).
cpp_qual_member(_, C, N, E) :- cpp_static_through_object(C, N, E), !.
cpp_qual_member(_, C, N, _) :- cpp_refuse(0, no_member(C, N)).
cpp_qual_call(X, Path, M, As, E) :- cpp_qual_object(X, Path, C, B),
    ( cpp_method_on(B, C, M, As, Name, Hops) -> true ; length(As, K), cpp_refuse(0, no_member(C, M, K)) ),
    cpp_fill_defaults(Name, As, As1),
    ( cpp_static_method(C, M, Name) -> P = nullptr ; cpp_hops(B, Hops, B1), P = addr(B1) ),
    cpp_object_arg(Name, P, Obj), E = call(id(Name), [Obj|As1]).
cpp_qual_name(M) :- ( atom(M) ; M = operator(Op), Op \= conv(_) ), !.
%% `std::move(x).m' IS `std::move(x.m)' ([expr.ref]/6, 0.121): a member of an xvalue is an xvalue, and the move belongs to the member -- on the object it is a move of a
%% class that holds no owner, which the safe part refuses (libc++ 18's `std::forward<decltype(__rhs_alt)>(__rhs_alt).__value' is the same shape, a call, and needs no rewriting)
cpp_xvalue_member(member(X, N), move(member(Y, N))) :- X = move(Y), !.
cpp_xvalue_member(member(X, N), move(member(Y, N))) :- X = member(_, _), cpp_xvalue_member(X, move(Y)), !.
cpp_xvalue_member(E, E).
%% `x->m' WITH x A CLASS OBJECT goes through its `operator->' ([over.ref]): `(x.operator->())->m', again until a pointer
%% -- how a unique_ptr's node is reached, `__h->__get_value()' in libc++'s __tree; left as an arrow on a struct it
%% typed as nothing and every call through it refused cannot_deduce
cpp_arrow_object(X, P) :- cpp_class_of_type_of(X, C), cpp_method_on(X, C, operator('->'), [], Name, Hops), !,
    cpp_hops(X, Hops, Base), cpp_object_arg(Name, addr(Base), Obj), cpp_arrow_object(call(id(Name), [Obj]), P).
cpp_arrow_object(X, X).
cpp_static_through_object(C, N, V) :- cpp_static_value(C, N, V), !.                    % a static const with a constant: the constant, as `C::value' folds
cpp_static_through_object(C, N, id(Name)) :- cpp_static_use(C, N, Name).
%% THE SCALAR THREE-WAY COMPARISON IS <compare>'S CLASS where the header is in ([expr.spaceship]/4, /5; 0.101):
%% `std::strong_ordering' for integers and pointers, `std::partial_ordering' for floating operands, each libc++'s own
%% class -- one `signed char' holding -1, 0, 1, and -127 for unordered (`_NCmpResult::__unordered') -- built as the
%% aggregate its private constructor would build, so `o < 0', `o == 0', `std::is_lt(o)' and `o == strong_ordering::
%% greater' go to the hidden friends the header writes. A program that writes `<=>' without <compare> keeps the
%% int of 0.42 (C++ calls it ill-formed; the int is what those programs printed).
cpp_scalar_ordering(A, B, E) :-
    ( ( cpp_arg_type(A, AT), ccl_is_float(AT) ; cpp_arg_type(B, BT), ccl_is_float(BT) ) -> Kind = partial ; Kind = strong ),
    cpp_ordering_class(Kind, C), !,
    Sign = bin('-', bin('>', A, B), bin('<', A, B)),
    ( Kind == partial -> V = cond(bin('&&', bin('==', A, A), bin('==', B, B)), Sign, int(-127)) ; V = Sign ),
    cpp_ordering_value(C, V, E).
cpp_scalar_ordering(A, B, bin('-', bin('>', A, B), bin('<', A, B))).
cpp_ordering_class(Kind, C) :- ( Kind == partial -> C = partial_ordering ; Kind == weak -> C = weak_ordering ; C = strong_ordering ),
    ( cpp_class_l(C, _) -> true ; cpp_hdr_item(C, _), cpp_hdr_join(C), cpp_class_l(C, _) ).
cpp_ordering_value(C, V, compound_lit(base([], [typedef(C)]), init([item([], cast(base([], [signed, char]), V))]))).
%% ... AND FALSE FOR A CALL OF A FUNCTION DECLARED WITHOUT `noexcept' (0.110; [expr.unary.noexcept]/3: a
%% potentially-throwing function called): a free function of the program's own whose name no noexcept declaration
%% noted (ccl_nothrow, the reader's), or a method of the program's own class none of whose overloads of that name is
%% declared noexcept; AND A LIBRARY'S (0.193, libc++'s exceptions configuration): a free function or function template
%% that a header declares and whose name no noexcept declaration of the header noted (ccl_lib_nothrow/1, the library's
%% set, which a summary carries), called by its name or a qualified one (`std::stoi(s)', `std::max(a, b)'), and a member
%% function of a library class -- its own, a member template's, else the first base's that declares the name -- none of
%% whose declarations of the name is noexcept (`v.at(0)', `s.c_str()' noexcept). Until 0.193 a library function stayed
%% true, as libc++ ran its no-exceptions configuration (0.50). A destructor is implicitly noexcept ([except.spec]/9).
cpp_nx_throws(_, E) :- cpp_term_mentions_functor(E, throw), !.
cpp_nx_throws(Ctx, E) :- cpp_nx_call(E, C), cpp_nx_throwing(Ctx, C), !.
%% NOEXCEPT ENFORCED (0.110; [except.spec]/5): an exception that leaves a noexcept function calls std::terminate. Where
%% the PROGRAM throws (only its own throws exist: libc++ runs without exceptions, 0.50), the body of each of its noexcept
%% functions and methods is `try { body } catch (...) { std::terminate(); }' -- the handler found in the search phase,
%% as clang's terminate landing pad is; its kind `terminate' runs NO destructor of the scopes the exception leaves on the
%% way (clang's pad calls terminate first, and a local's destructor does not print), ir_unwind_to.
cpp_nx_wrap(L, block(Is), block([try(L, block(Is), [catch(terminate, block([expr(L, eh_terminate)]))])])) :-
    nb_current('$cpp_throws', yes), nb_getval('$cpp_in_lib', no), cpp_nx_may_throw(Is), !.
cpp_nx_wrap(_, B, B).
%% a body that can throw: one that calls, or one that throws itself (0.199: `void d(int v) noexcept { if (v > 0) throw v; }'
%% was no guard's, and its exception left it where clang++ calls std::terminate)
cpp_nx_may_throw(Is) :- ( cpp_term_mentions_functor(Is, call) ; cpp_term_mentions_functor(Is, throw) ), !.
cpp_nx_call(T, T) :- compound(T), T = call(_, _).
cpp_nx_call(T, C) :- compound(T), T \= noexcept_expr(_), T \= lambda(_, _, _, _), T =.. [_|As], member(A, As), cpp_nx_call(A, C).
%% A CALL OF A FUNCTION WITH A CONDITIONAL NOEXCEPT (0.199; [except.spec]/2, /13): the callee the call resolves to -- a
%% function template's instance, an overload -- desugared unevaluated, and its condition evaluated under its bindings
%% (cpp_nx_named_value/2): `noexcept(f(1))' of `template <class T> void f(T) noexcept(sizeof(T) > 4)' is false and
%% `noexcept(f(1.0))' true, and libc++ 18's `std::__invoke' answers `is_nothrow_invocable' by its callee's type. Every
%% condition but `false' was taken as holding until 0.199. A call it cannot resolve takes the rules below.
%% ... BUT FIRST THE CONSTRUCTORS THE CALL RUNS (0.200; [except.spec]/6: an implicit call of a constructor for a function
%% argument): a by-value parameter of a class is initialized by the constructor that takes the argument, and a reference to a
%% class bound to a value that is no object of it by the temporary's -- for a function template whose arguments the call
%% gives, its parameters substituted, and for a plain function of one overload of the call's arity; a temporary `T(args)' or
%% `T{args}' of a class by its constructor. A prvalue of the parameter's class initializes it with no constructor (C++17's
%% elision). libc++ 18's `is_nothrow_convertible' is `noexcept(__test_noexcept<_To>(declval<_Fm>()))' over `template <class
%% _Tp> void __test_noexcept(_Tp) noexcept;', and each such call was nothrow whatever constructor ran: `noexcept(g(1))' over
%% `void g(TH) noexcept' and `TH(int)' that may throw was 1, as was `noexcept(h(TH(1)))'
cpp_nx_throwing(_, call(F0, As)) :- As \== [], cpp_nx_given_targs(F0, F, TAs), length(As, N), cpp_nx_tmpl_params(F, N, TPs, Ps0),
    catch(cpp_bind_targs(TPs, TAs, B), _, fail), cpp_subst(Ps0, B, Ps), cpp_nx_args_init_throw(Ps, As), !.
cpp_nx_throwing(_, call(id(F), As)) :- As \== [], atom(F), \+ cpp_local(F), \+ '$cpp_tmpl'(F, _, _), \+ ccl_fn_template(F), length(As, N),
    findall(K-Ps, ( '$cpp_fn'(F, K, Ps, _, _), length(Ps, N) ), [K0-Ps0|KPs]), \+ ( member(K1-_, KPs), K1 \== K0 ),
    cpp_nx_args_init_throw(Ps0, As), !.
cpp_nx_throwing(Ctx, call(id(F), As)) :- As \== [], atom(F), \+ cpp_local(F), \+ '$cpp_tmpl'(F, _, _), \+ ccl_fn_template(F), length(As, N),   % ... AND OF THE OVERLOAD THE CALL RESOLVES TO where several take as many (0.205): `noexcept(ov3(1))' over `void ov3(TH) noexcept;' and `void ov3(const char *) noexcept;' was 1
    findall(K, ( '$cpp_fn'(F, K, Ps, _, _), length(Ps, N) ), Ks), sort(Ks, [_, _|_]),
    cpp_nx_instance_params(Ctx, call(id(F), As), Ps0), cpp_nx_args_init_throw(Ps0, As), !.
cpp_nx_throwing(_, call(id(C), As)) :- cpp_nx_class_named(C, T), cpp_nx_arg_values(As, ATs), \+ cpp_nothrow_q(cpp_nothrow_ctor(T, ATs)), !.
cpp_nx_throwing(Ctx, call(F0, As)) :- cpp_nx_fn_named(F0, F), cpp_nx_maybe_cond(F), cpp_nx_callee_value(Ctx, call(F0, As), V), !, V == false.
%% ... and `__builtin_invoke(f, args...)' (0.199; libc++ 21's `is_nothrow_invocable' asks `noexcept(__builtin_invoke(...))'): the
%% callable's own type says -- a pointer or a reference to a function its noexcept mark, a pointer to member function its
%% member function type's, a pointer to data member never throws, a class its call operator's declarations
cpp_nx_throwing(_, call(id('__builtin_invoke'), [F|_])) :- !, cpp_nx_invoke_throws(F).
cpp_nx_throwing(_, call(id(F), _)) :- atom(F), \+ ccl_nothrow(F), '$cpp_fn'(F, _, _, yes, own(_)), \+ ccl_declared(F, ptr(_, _)).
cpp_nx_throwing(_, call(id(F), _)) :- atom(F), \+ '$cpp_fn'(F, _, _, yes, own(_)), \+ cpp_local(F), \+ ccl_lib_nothrow(F), \+ ccl_nothrow(F), cpp_nx_lib_fn(F).
cpp_nx_throwing(Ctx, call(scoped(_, F), As)) :- atom(F), cpp_nx_throwing(Ctx, call(id(F), As)).   % `std::stoi(s)': the name as the flattening has it
cpp_nx_throwing(Ctx, call(tmpl(F, _), As)) :- atom(F), cpp_nx_throwing(Ctx, call(id(F), As)).   % A FUNCTION TEMPLATE'S CALL WITH ITS ARGUMENTS GIVEN (0.199): `dv<T>()', `std::declval<T>()', by the template's name
cpp_nx_throwing(Ctx, call(scoped(_, tmpl(F, _)), As)) :- atom(F), cpp_nx_throwing(Ctx, call(id(F), As)).
cpp_nx_throwing(_, call(id(F), _)) :- atom(F), \+ cpp_local(F), \+ ccl_nothrow(F), cpp_nx_prog_fn_template(F).   % ... and a function template of the program declared without `noexcept' (0.199): it was no call that throws
cpp_nx_throwing(_, call(member(O, M), As)) :- atom(M), ( cpp_class_of_type_of(O, C) -> true ; cpp_nx_value_class(O, C) ), cpp_nx_method_call_throws(C, M, As).   % the object a temporary too (0.205): `noexcept(P().h())' of `void h() noexcept(false)' was 1, the inference typing no class's name called
cpp_nx_throwing(_, call(arrow(P, M), As)) :- atom(M), ccl_type_of(P, T), ccl_unref(T, ptr(_, PT)), cpp_class_of_type(PT, C), cpp_nx_method_call_throws(C, M, As).
cpp_nx_throwing(_, call(scoped(Path, M), As)) :- atom(M), Path \== [], catch(cpp_scope_class(Path, C), _, fail), atom(C), cpp_nx_method_call_throws(C, M, As).   % A STATIC MEMBER CALLED THROUGH ITS CLASS (0.205): `noexcept(O::s(1))'
cpp_nx_throwing(Ctx, call(F0, As)) :- As \== [], \+ cpp_nx_given_targs(F0, _, _), cpp_nx_fn_named(F0, F), \+ cpp_local(F), ( '$cpp_tmpl'(F, _, _) -> true ; ccl_fn_template(F) ),   % A FUNCTION TEMPLATE'S CALL WITH ITS ARGUMENTS DEDUCED (0.205): the parameters of the instance the call resolves to, initialized from its arguments -- `noexcept(dt(1, 2))' over `template <class T> void dt(T, TH) noexcept' and a `TH(int)' that may throw was 1
    cpp_nx_instance_params(Ctx, call(F0, As), Ps), cpp_nx_args_init_throw(Ps, As), !.
cpp_nx_throwing(_, call(F, _)) :- cpp_nx_pointer_callee(F, FT), \+ cpp_fn_type_nx(FT).   % A CALL THROUGH A POINTER OR A REFERENCE TO A FUNCTION (0.198; [except.spec]/3): its type says, `void (*q)() noexcept' does not throw and `void (*p)()' may -- every such call was taken as noexcept
cpp_nx_throwing(_, call(F, _)) :- ( F = memptr_get(_, PM) ; F = memptr_arrow(_, PM) ), cpp_nx_memptr_fn(PM, FT), \+ cpp_fn_type_nx(FT).   % ... and THROUGH A POINTER TO MEMBER FUNCTION, `(o.*pm)(args)' (0.198): the member function type's own noexcept
cpp_nx_throwing(Ctx, call(X, As)) :- cpp_nx_object_class(X, C),   % ... and A CALL OF AN OBJECT OF CLASS TYPE ([over.call]; 0.205): its operator()'s, a closure's among them -- the instance a member template's call resolves to, else the declarations'
    ( cpp_nx_callee_value(Ctx, call(X, As), V) -> V == false ; cpp_nx_method_throws(C, operator('()')) ).
%% the class of an object a call is made on: a local's, a data member's (`o.f' with no member function f), a cast's or a call's
%% value -- `static_cast<_Fp &&>(__f)(...)' of libc++'s `__invoke', `std::declval<F>()(...)' -- never a name the clauses above take
cpp_nx_object_class(id(F), C) :- !, atom(F), cpp_local(F), cpp_nx_value_class(id(F), C).
cpp_nx_object_class(X, _) :- ( X = scoped(_, _) ; X = tmpl(_, _) ; X = arrow(_, _) ; X = memptr_get(_, _) ; X = memptr_arrow(_, _) ), !, fail.
cpp_nx_object_class(member(O, M), C) :- !, atom(M), cpp_class_of_type_of(O, OC), cpp_nx_method_quals(OC, M, []), cpp_nx_value_class(member(O, M), C).
cpp_nx_object_class(X, C) :- cpp_nx_value_class(X, C).
cpp_nx_value_class(X, C) :- catch(cpp_arg_type(X, T0), _, fail), T0 \== unknown, ccl_unref(T0, T1), catch(ccl_resolve_type(T1, T2), _, fail), cpp_class_of_type(T2, C), !.
%% a member function's call: its declarations' noexcept (cpp_nx_method_throws/2), and ITS PARAMETERS INITIALIZED FROM THE ARGUMENTS
%% (0.205, [except.spec]/6, as a plain function's since 0.200) where one declaration of the name takes as many: `noexcept(o.m(1))'
%% over `void m(TH) noexcept' and a `TH(int)' that may throw was 1. The parameters' types are resolved in the class
cpp_nx_method_call_throws(C, M, _) :- cpp_nx_method_throws(C, M), !.
cpp_nx_method_call_throws(C, M, As) :- As \== [], length(As, N), cpp_nx_method_quals(C, M, QL), findall(D-Ps, ( member(q(D, _, Ps), QL), length(Ps, N) ), [D0-Ps0]),
    catch(cpp_in_class(D0, cpp_nx_params_typed(Ps0, Ps1)), _, fail), cpp_nx_args_init_throw(Ps1, As), !.
cpp_nx_params_typed([], []).
cpp_nx_params_typed([P|Ps], [param(T, N)|Qs]) :- ( P = param(T0, N) -> true ; P = param(T0, N, _) ), ( T0 \= pack(_), catch(cpp_type(T0, T1), _, fail) -> T = T1 ; T = T0 ), cpp_nx_params_typed(Ps, Qs).
%% the parameters of the instance a function template's call resolves to: the call desugared unevaluated, its callee's declared type
cpp_nx_instance_params(Ctx, Call, Ps) :- catch(cpp_unevaluated(cpp_expr(Ctx, Call, D)), _, fail), cpp_nx_call(D, call(id(I), _)), atom(I),
    catch(ccl_declared(I, T0), _, fail), catch(ccl_resolve_type(T0, fn(_, Ps, _)), _, fail), !.
cpp_nx_given_targs(tmpl(F, TAs), F, TAs) :- atom(F).
cpp_nx_given_targs(scoped(_, tmpl(F, TAs)), F, TAs) :- atom(F).
cpp_nx_tmpl_params(F, N, TPs, Ps) :- ( '$cpp_tmpl'(F, TPs, I) ; catch(cpp_hdr_item(F, template(_, TPs, I)), _, fail) ), cpp_nx_item_params(I, Ps), length(Ps, N), !.
cpp_nx_item_params(template(_, _, I), Ps) :- !, cpp_nx_item_params(I, Ps).
cpp_nx_item_params(function(_, _, _, _, Ps, _, _), Ps) :- !.
cpp_nx_item_params(declaration(_, _, _, Vs), Ps) :- member(var(_, fn(_, Ps, _), _), Vs), !.
cpp_nx_param_type(param(T, _), T) :- !.
cpp_nx_param_type(param(T, _, _), T).
%% a call's parameters initialized from its arguments: one by a constructor that may throw (above)
cpp_nx_args_init_throw(Ps, As) :- nth1(I, Ps, P), nth1(I, As, A), cpp_nx_param_type(P, PT0), PT0 \= pack(_),
    ( catch(cpp_type(PT0, PT), _, fail) -> true ; PT = PT0 ), cpp_nx_arg_value(A, AV), cpp_nx_param_init_throws(PT, A, AV), !.
cpp_nx_param_init_throws(PT, A, AV) :- cpp_class_of_type(PT, C), !, \+ ( cpp_nx_prvalue(A), cpp_class_of_type(AV, C) ), \+ cpp_nothrow_q(cpp_nothrow_ctor(PT, [AV])).
cpp_nx_param_init_throws(PT, _, AV) :- cpp_ref_target(PT, _, R), cpp_class_of_type(R, C), ccl_unref(AV, X), \+ ( cpp_class_of_type(X, D), cpp_class_fits(D, C) ),
    \+ cpp_nothrow_q(cpp_nothrow_ctor(R, [AV])).
%% an argument's type with its value category, as the nothrow traits take it: an lvalue's `T &', an xvalue's `T &&'
cpp_nx_arg_value(A, AV) :- catch(cpp_arg_type(A, AT), _, fail), AT \== unknown, \+ cpp_untyped_arg(AT),
    ( ( AT = ref(_, _) ; AT = rref(_, _) ) -> AV = AT ; cpp_arg_lvalue(A) -> AV = ref([], AT) ; cpp_xvalue_object(A) -> AV = rref([], AT) ; AV = AT ).
cpp_nx_arg_values([], []).
cpp_nx_arg_values([A|As], [V|Vs]) :- cpp_nx_arg_value(A, V), cpp_nx_arg_values(As, Vs).
cpp_nx_prvalue(A) :- \+ cpp_arg_lvalue(A), \+ cpp_xvalue_object(A).
%% a class the program or a loaded header registered, named as a temporary's type: no function's name, no aggregate's
cpp_nx_class_named(C, base([], [typedef(C)])) :- atom(C), \+ cpp_local(C), catch('$cpp_clsl'(C, _), _, fail), \+ '$cpp_fn'(C, _, _, _, _), \+ ccl_fn_template(C),
    \+ cpp_aggregate_class(C), !.
cpp_nx_class_named(N, T) :- atom(N), \+ cpp_local(N), \+ '$cpp_fn'(N, _, _, _, _), \+ ccl_fn_template(N), ccl_typedef_of(N, _),   % ... a class named by a TYPEDEF (0.205): `noexcept(std::string("x"))', whose constructor from a `const char *' may throw, was 1
    catch(cpp_type(base([], [typedef(N)]), T), _, fail), cpp_class_of_type(T, C), \+ cpp_aggregate_class(C), !.
%% a function template of the program, declared or defined without a noexcept-specifier, a condition aside
cpp_nx_prog_fn_template(F) :- '$cpp_tmpl'(F, _, I), \+ '$cpp_lib'(F), cpp_nx_fn_item(I), \+ cpp_nx_item_cond(I), !.
cpp_nx_pointer_callee(id(N), FT) :- atom(N), !, ( cpp_local(N) -> true ; ccl_declared(N, T0), ccl_resolve_type(T0, ptr(_, _)) ), ccl_declared(N, T), cpp_nx_fn_of(T, FT).
cpp_nx_pointer_callee(F, FT) :- \+ F = scoped(_, _), \+ F = member(_, _), \+ F = arrow(_, _), \+ F = tmpl(_, _), catch(ccl_type_of(F, T), _, fail), T \== unknown, cpp_nx_fn_of(T, FT).
cpp_nx_fn_of(T, FT) :- ccl_resolve_type(T, T0), cpp_unref_all(T0, T1), ( ccl_resolve_type(T1, ptr(_, F0)) -> true ; F0 = T1 ), ccl_resolve_type(F0, FT), FT = fn(_, _, _).   % a reference to a pointer too: libc++'s `static_cast<_Fp &&>(__f)(...)'; every reference layer, `_Fp &&' over a function reference before it collapses (0.199)
cpp_fn_type_nx(fn(_, _, V)) :- nonvar(V), V = q(_, Qs), ( memberchk(noexcept, Qs) -> true ; memberchk(nxif(E), Qs), \+ cpp_fn_nx_cond(q(false, [nxif(E)]), false) ).   % a condition left to the desugaring too (0.205): false where it folds so, else it holds (0.199's rule)
%% the member function type of a pointer to member: its type as decltype has it, the expression desugared where it is written
cpp_nx_memptr_fn(PM, FT) :- ( cpp_class_ctx(Cx) -> true ; Cx = none ), catch(( cpp_unevaluated(cpp_expr(Cx, PM, PM1)), cpp_decltype_of(PM1, T0) ), _, fail),
    ccl_resolve_type(T0, T1), ccl_unref(T1, T2), ccl_resolve_type(T2, memptr(_, _, F0)), ccl_resolve_type(F0, FT), FT = fn(_, _, _), !.
cpp_nx_method_throws(C, M) :- cpp_nx_method_quals(C, M, QL), QL \== [], \+ ( member(q(K, Qs, Ps), QL), cpp_qs_nothrow(K, Qs, Ps) ).
%% the qualifiers of each declaration of the member function M of C, with its class and its parameters (0.199: a
%% conditional noexcept is evaluated in them), a member template's among them, else of the first base that declares the
%% name ([class.member.lookup]), [] where none does
cpp_nx_method_quals(C, M, QL) :- catch(cpp_class(C, cls(_, _, Ms, _, _, _)), error(not_lowered(_), _), fail), !,
    findall(q(C, Qs, Ps), ( member(method(_, Qs, _, M, Ps, _, _), Ms) ; '$cpp_mt'(C, _, _, method(_, Qs, _, M, Ps, _, _)) ), QL0),
    (   QL0 \== [] -> QL = QL0
    ;   cpp_base_scope(C, B), atom(B), cpp_nx_method_quals(B, M, QL1), QL1 \== [] -> QL = QL1
    ;   QL = [] ).
cpp_nx_method_quals(_, _, []).
%% the noexcept operator's road over a conditional callee (0.199): a name that a call takes, one of whose definitions --
%% the program's or a header's, a template's -- has a condition
cpp_nx_fn_named(id(F), F) :- atom(F).
cpp_nx_fn_named(scoped(_, F), F) :- atom(F).
cpp_nx_fn_named(tmpl(F, _), F) :- atom(F).
cpp_nx_fn_named(scoped(_, tmpl(F, _)), F) :- atom(F).
cpp_nx_maybe_cond(F) :- '$cpp_nxsrc'(F, _, _), !.
cpp_nx_maybe_cond(F) :- '$cpp_tmpl'(F, _, I), cpp_nx_item_cond(I), !.
cpp_nx_maybe_cond(F) :- catch(cpp_hdr_item(F, I), _, fail), cpp_nx_item_cond(I), !.
cpp_nx_item_cond(template(_, _, I)) :- !, cpp_nx_item_cond(I).
cpp_nx_item_cond(function(_, nxif(_, _), _, _, _, _, _)).
%% the callee a call resolves to, desugared where it stands and unevaluated, and its condition's value: false where the
%% callee is declared with a condition that does not hold
cpp_nx_callee_value(Ctx, Call, V) :- catch(cpp_unevaluated(cpp_expr(Ctx, Call, D)), _, fail), cpp_nx_call(D, call(id(C), _)), atom(C), cpp_nx_named_value(C, V), !.
%% an emitted function's condition ('$cpp_nxdef', the emission's), else a definition's not emitted yet ('$cpp_nxsrc', noted
%% before any body is walked), evaluated once ('$cpp_nxval')
cpp_nx_named_value(C, V) :- '$cpp_nxval'(C, V0), !, V = V0.
cpp_nx_named_value(C, V) :- '$cpp_nxdef'(C, Cx, E, Ps), !, cpp_nx_cond_value(Cx, E, Ps, V), assertz('$cpp_nxval'(C, V)).
cpp_nx_named_value(C, V) :- '$cpp_nxsrc'(N, Ps, E), cpp_nx_src_name(N, Ps, C1), C1 == C, !, cpp_nx_cond_value(none, E, Ps, V), assertz('$cpp_nxval'(C, V)).
cpp_nx_src_name(operator(Op), Ps, C) :- !, cpp_free_operator(Op, Ps, N0), catch(cpp_fn_name(N0, Ps, yes, C), _, fail).
cpp_nx_src_name(N, Ps, C) :- atom(N), catch(cpp_fn_name(N, Ps, yes, C), _, fail).
cpp_nx_note_src(N, Ps, nxif(E, _)) :- !, assertz('$cpp_nxsrc'(N, Ps, E)).
cpp_nx_note_src(_, _, _).
%% THE VALUE OF A NOEXCEPT-SPECIFIER'S CONDITION E (0.199; [except.spec]/2): in class Cx's words (none: a free function's)
%% with the function's parameters Ps declared, its walk unevaluated and isolated from the asker's scopes, folded as a
%% constant condition (cpp_const_bool/2) -- true or false where it folds, true where it does not, as every condition was
%% until 0.199 (trace `nx_cond_unknown'), and true where it asks itself again
cpp_nx_cond_value(_, E, _, true) :- nb_current('$cpp_nx_evaluating', Ev), member(E0, Ev), E0 == E, !.
cpp_nx_cond_value(Cx, E, Ps, V) :- ccl_global('$cpp_nx_evaluating', Ev, []), nb_setval('$cpp_nx_evaluating', [E|Ev]),
    (   catch(cpp_isolated(cpp_nx_in(Cx, cpp_in_frame(( ( catch(cpp_plain_params(Ps, Ps1), _, fail) -> true ; Ps1 = [] ),
                                                        ( catch(ccl_declare_params(Ps1), _, true) -> true ; true ),
                                                        cpp_unevaluated(cpp_expr(Cx, E, E1)), cpp_const_bool(E1, V0) )))), _, fail)
    ->  V1 = V0
    ;   cpp_trace(nx_cond_unknown(E)), V1 = true ),
    nb_setval('$cpp_nx_evaluating', Ev), V = V1.   % the mark taken off BEFORE the answer meets a bound V: the terminate guard asks with `true', and a false condition left its mark on and read true at every later ask
cpp_nx_in(none, G) :- !, call(G).
cpp_nx_in(C, G) :- cpp_in_class(C, G).
%% a member's qualifiers say it does not throw: `noexcept', or `noexcept(E)' whose condition holds in its class with its
%% parameters (0.199), evaluated once a class and condition ('$cpp_nxmval')
cpp_qs_nothrow(_, Qs, _) :- memberchk(noexcept, Qs), !.
cpp_qs_nothrow(C, Qs, Ps) :- memberchk(noexcept(E), Qs), !, cpp_nx_member_value(C, E, Ps, true).
cpp_nx_member_value(C, E, Ps, V) :- '$cpp_nxmval'(C, K, V0), K == E-Ps, !, V = V0.
cpp_nx_member_value(C, E, Ps, V) :- cpp_nx_cond_value(C, E, Ps, V0), assertz('$cpp_nxmval'(C, E-Ps, V0)), V = V0.
%% a method's body guarded by terminate (cpp_nx_wrap/3): `noexcept', or a condition that holds, asked only where a guard
%% can stand (the program's code where it throws, a body that calls)
cpp_qs_guarded(_, Qs, _, _) :- memberchk(noexcept, Qs), !.
cpp_qs_guarded(C, Qs, Params, block(Is)) :- memberchk(noexcept(E), Qs), nb_current('$cpp_throws', yes), nb_getval('$cpp_in_lib', no), cpp_nx_may_throw(Is), !,
    cpp_nx_member_value(C, E, Params, true).
%% ... and a free function's: its name noted noexcept, or the condition its emission was handed
cpp_fn_nx_guarded(none, N, _, _) :- !, ccl_nothrow(N).
cpp_fn_nx_guarded(def(Cx, E), _, Ps, block(Is)) :- nb_current('$cpp_throws', yes), nb_getval('$cpp_in_lib', no), cpp_nx_may_throw(Is), cpp_nx_cond_value(Cx, E, Ps, true).
cpp_nx_def_take(D) :- ( nb_current('$cpp_nx_def', D0), D0 \== none -> nb_setval('$cpp_nx_def', none), D = D0 ; D = none ).
%% `__builtin_invoke(f, ...)' throws as calling f does, by f's type
cpp_nx_invoke_throws(F) :- catch(cpp_arg_type(F, T0), _, fail), T0 \== unknown, ccl_unref(T0, T1), catch(ccl_resolve_type(T1, T2), _, fail), !,
    (   T2 = memptr(_, _, F0) -> catch(ccl_resolve_type(F0, FT), _, fail), FT = fn(_, _, _), \+ cpp_fn_type_nx(FT)
    ;   cpp_nx_fn_of(T2, FT) -> \+ cpp_fn_type_nx(FT)
    ;   cpp_class_of_type(T2, C) -> cpp_nx_method_throws(C, operator('()'))
    ;   fail ).
%% a free function or a function template that a LIBRARY header declares: its items in the header index
cpp_nx_lib_fn(F) :- cpp_hdr_item(F, I), cpp_nx_fn_item(I), !.
cpp_nx_fn_item(function(_, _, _, _, _, _, _)).
cpp_nx_fn_item(declaration(_, _, _, Vs)) :- member(var(_, fn(_, _, _), _), Vs), !.
cpp_nx_fn_item(template(_, _, I)) :- cpp_nx_fn_item(I).
cpp_term_mentions_functor(T, F) :- compound(T), ( functor(T, F, _) -> true ; T =.. [_|As], member(A, As), cpp_term_mentions_functor(A, F) ), !.
%% THE AWAITER ([expr.await]/3.3; 0.110): the awaitable's `operator co_await', a member or a free one, where it has one
cpp_coro_awaiter(_, Op0, call(member(Op0, operator(co_await)), [])) :- cpp_coro_class(Op0, C), cpp_has_member(C, operator(co_await)), !.
cpp_coro_awaiter(Ctx, Op0, Op) :- cpp_free_operator(co_await, [_], FN), ( '$cpp_fn'(FN, _, _, _, _) -> true ; '$cpp_tmpl'(FN, _, _) ), catch(cpp_expr(Ctx, Op0, A), _, fail), catch(cpp_free_operator_call(co_await, A, [], Op1), _, fail), !, Op = Op1.
cpp_coro_awaiter(_, Op, Op).
cpp_coro_class(E, C) :- catch(cpp_arg_type(E, T), _, fail), T \== unknown, ccl_unref(T, T1), cpp_class_of_type(T1, C), !.
%% `*e' OF AN ARITHMETIC VALUE IS ILL-FORMED, and a detection reads it (0.126): libc++ 18's `__invoke' for a pointer to a data member given an
%% `int' has the return type `decltype((*std::declval<_A0>()).*std::declval<_Fp>())', a substitution failure for `_A0 = int'; the dereference
%% stayed in the tree, the candidate held and its body was lowered, `not_a_pointer(rref(int))' (`is_invocable<int Pt::*, int>', invokedata.cpp).
%% Only an operand whose type is KNOWN and arithmetic (an enumeration included) is refused; a type the inference could not settle is let through.
cpp_deref_operand(A) :-
    (   catch(( ccl_type_of(A, T0), T0 \== unknown, ccl_unref(T0, T1), ccl_resolve_type(T1, T), ccl_is_arith(T) ), _, fail)
    ->  cpp_refuse(0, deref_of_arithmetic(T))
    ;   true ).
%% `new T[n]' OF A CLASS THAT CONSTRUCTS OR DESTROYS (0.108; refused by name since 0.86): the Itanium C++ ABI's ARRAY
%% COOKIE -- where the class has a destructor, or the array deallocation function delete[] takes is a sized one, the count
%% is written before the first element, in a cookie of max(sizeof(size_t), alignof(T)) bytes, so `delete[]' knows how many
%% to destroy (cpp_array_cookie/2) -- then each element made in place by the placement new's road (the default
%% constructor, or the item of a braced list, the rest value-initialized). The block is the array allocation function's
%% (cpp_alloc_call/7, 0.202), its size the cookie and the elements; a non-throwing one's null result skips the elements.
cpp_new_objects(Ctx, Spec, T, C, N1, Items, E) :-
    SizeT = base([], [unsigned, long]), CharT = base([], [char]), CharP = ptr([], CharT), PT = ptr([], T),
    cpp_array_cookie(T, Ck),
    ccl_gensym('$an', Nv), ccl_gensym('$araw', Raw), ccl_gensym('$ap', P), ccl_gensym('$ai', I),
    ( Ck > 0 -> CkOff is Ck - 8, Cookie = [expr(0, assign('=', deref(cast(ptr([], SizeT), bin('+', id(Raw), int(CkOff)))), id(Nv)))] ; Cookie = [] ),
    ccl_gensym('$abuilt', Bt), cpp_new_items(Items, T, P, Bt, Placed, K),
    ( cpp_dtor(C, _) -> cpp_member_dtor(T, index(id(P), id(Bt)), 0, Ds) ; Ds = [] ),   % AN ELEMENT'S CONSTRUCTOR THAT THROWS (0.201; [expr.new]/26, [except.ctor]/3): the elements built destroyed, the last first, and the block given back, by a cleanup the unwinding alone runs (eh_cleanup) -- `new T[5]' left them built and its memory taken
    Size = bin('+', int(Ck), bin('*', id(Nv), sizeof_type(T))), cpp_alloc_call(Spec, T, Size, Raw, Call, Undo0, NT),
    ( Undo0 == none -> Free = [] ; Free = [expr(0, Undo0)] ),
    Undo = eh_cleanup(0, block([while(0, bin('>', id(Bt), int(0)), block([expr(0, predec(id(Bt)))|Ds]))|Free])),
    Head = [declaration(0, none, SizeT, [var(Nv, SizeT, '$cpp_walked'(N1))]), declaration(0, none, CharT, [var(Raw, CharP, alloc(garbage, CharT, Call))])],
    (   cpp_items_cover(N1, K) -> Loop = []   % a constant bound the items cover asks no default constructor ([dcl.init.aggr]/5: no element is left)
    ;   Loop = [for(0, decl(SizeT, [var(I, SizeT, int(K))]), bin('<', id(I), id(Nv)), postinc(id(I)),
                    block([expr(0, new_at([addr(index(id(P), id(I)))], new(T, []))), expr(0, preinc(id(Bt)))]))] ),
    (   NT == yes   % `new (std::nothrow) T[n]': a null block is a null result, no element made ([expr.new]/20)
    ->  append([Cookie, [expr(0, assign('=', id(P), cast(PT, bin('+', id(Raw), int(Ck))))), declaration(0, none, SizeT, [var(Bt, SizeT, int(0))]), Undo], Placed, Loop], Built),
        append(Head, [declaration(0, none, PT, [var(P, PT, cast(PT, nullptr))]), if(0, id(Raw), block(Built), none), expr(0, id(P))], Stmts)
    ;   append([Head, Cookie, [declaration(0, none, PT, [var(P, PT, cast(PT, bin('+', id(Raw), int(Ck))))]), declaration(0, none, SizeT, [var(Bt, SizeT, int(0))]), Undo], Placed, Loop, [expr(0, id(P))]], Stmts) ),
    cpp_expr(Ctx, stmt_expr(block(Stmts)), E).
%% ... the elements the items do not cover default-constructed by a loop, unless the bound is a constant they cover (0.202): `new A[2]{A(1),
%% A(2)}' of a class with no default constructor is well-formed, and the loop that never ran named one
cpp_items_cover(N, K) :- K > 0, catch(ccl_const_eval(N, V), _, fail), integer(V), V =< K.
cpp_new_items(Items, T, P, Placed, K) :- cpp_new_items_(Items, T, P, none, 0, Placed, K).   % a placement array new's: no count of the elements built
cpp_new_items(Items, T, P, Bt, Placed, K) :- cpp_new_items_(Items, T, P, Bt, 0, Placed, K).
cpp_new_items_([], _, _, _, K, [], K).
cpp_new_items_([V0|Is], T, P, Bt, K0, [expr(0, new_at([addr(index(id(P), int(K0)))], new(T, As)))|Ss0], K) :- ( V0 = item(_, V) -> true ; V = V0 ), ( V = init(Sub) -> findall(X, member(item(_, X), Sub), As) ; As = [V] ),
    ( Bt == none -> Ss0 = Ss ; Ss0 = [expr(0, preinc(id(Bt)))|Ss] ), K1 is K0 + 1, cpp_new_items_(Is, T, P, Bt, K1, Ss, K).
%% `new T[n]' OF A SCALAR OR OF A CLASS WITH NOTHING TO RUN (0.202): the array allocation function's block over n elements; `new T[n]()'
%% and `new T[n]{a, b}' value-initialize, its bytes zero, the items stored over them ([expr.new]/24) -- calloc's before
cpp_new_scalars(Ctx, Spec, T, N1, Items, E) :-
    PT = ptr([], T), SizeT = base([], [unsigned, long]), ccl_gensym('$an', Nv), ccl_gensym('$ap', P),
    Size = bin('*', id(Nv), sizeof_type(T)), cpp_alloc_call(Spec, T, Size, P, Call, Undo, NT),
    ( Items == none -> M = garbage, Items1 = [] ; NT == yes -> M = nzeroed(Size), Items1 = Items ; M = zeroed(Size), Items1 = Items ),
    findall(expr(0, assign('=', index(id(P), int(J)), V)), ( nth0(J, Items1, V0), ( V0 = item(_, V) -> true ; V = V0 ) ), Sets),
    ( Sets \== [], Undo \== none -> Sets1 = [eh_cleanup(0, block([expr(0, Undo)]))|Sets] ; Sets1 = Sets ),   % an item that throws gives the block back
    ( NT == yes, Sets1 \== [] -> Body = [if(0, id(P), block(Sets1), none)] ; Body = Sets1 ),
    append([declaration(0, none, SizeT, [var(Nv, SizeT, '$cpp_walked'(N1))]), declaration(0, none, T, [var(P, PT, alloc(M, T, Call))])|Body], [expr(0, id(P))], Stmts),
    cpp_expr(Ctx, stmt_expr(block(Stmts)), E).
%% PLACEMENT `new T[n]' (0.117; refused by name before): n objects made in the storage the placement argument names,
%% with NO cookie -- the Itanium ABI asks for none when the allocation function is the global placement
%% `operator new[](size_t, void *)' -- each by the default constructor, or from its braced item, the rest
%% value-initialized (`new (p) T[n]()' and `{}'). A scalar or a class with nothing to run is left alone by plain
%% `new (p) int[4]' ([dcl.init]/7, indeterminate) and zeroed by `()', the items stored first. The result is the pointer.
cpp_new_at_array(Ctx, P1, T0, N, Items0, E) :-
    cpp_type(T0, T), PT = ptr([], T), SizeT = base([], [unsigned, long]), cpp_expr(Ctx, N, N1),
    ccl_gensym('$an', Nv), ccl_gensym('$at', P), ccl_gensym('$ai', I),                          % `$at...': the check reads the result as a borrow of the address it was given (ck_borrows_from)
    Head = [declaration(0, none, SizeT, [var(Nv, SizeT, '$cpp_walked'(N1))]), declaration(0, none, PT, [var(P, PT, cast(PT, P1))])],
    (   cpp_class_of_type(T, C), \+ cpp_trivial_class(C)
    ->  ( Items0 == none -> Items = [] ; Items = Items0 ),
        cpp_new_items(Items, T, P, Placed, K),
        append(Head, Placed, Stmts0),
        (   cpp_items_cover(N1, K) -> Rest = []
        ;   Rest = [for(0, decl(SizeT, [var(I, SizeT, int(K))]), bin('<', id(I), id(Nv)), postinc(id(I)),
                        block([expr(0, new_at([addr(index(id(P), id(I)))], new(T, [])))]))] ),
        append(Stmts0, Rest, Stmts1), append(Stmts1, [expr(0, id(P))], Stmts)
    ;   Items0 == none
    ->  append(Head, [expr(0, id(P))], Stmts)
    ;   findall(expr(0, assign('=', index(id(P), int(J)), V)), ( nth0(J, Items0, V0), ( V0 = item(_, V) -> true ; V = V0 ) ), Sets),
        Zero = expr(0, call(id(memset), [id(P), int(0), bin('*', id(Nv), sizeof_type(T))])),
        append([Head, [Zero], Sets, [expr(0, id(P))]], Stmts) ),
    cpp_expr(Ctx, stmt_expr(block(Stmts)), E).
cpp_incomplete_class(C) :- '$cpp_inst'(C, _), \+ '$cpp_cls'(C, _), \+ cpp_nested_pending(C).   % an instance made of a declared-only primary with no specialization matching
cpp_nested_pending(C) :- nb_current('$cpp_nested', L), memberchk(C-_, L).
%% `delete[] p' (0.108; its deallocation function's since 0.202): of a class with a cookie, the count read from it before the first
%% element, each element destroyed in the reverse order of its construction, then the block given back from the cookie's start --
%% to the class's own array deallocation function unless `::delete[]', else the global one, a sized one told the block's size
%% ([expr.delete]/10); of any other, its deallocation function over p. Nothing where p is null (dealloc/3).
cpp_delete_array(G, X, E) :- cpp_pointee_class_of(X, C), T = base([], [typedef(C)]), cpp_array_cookie(T, Ck), Ck > 0, !,
    SizeT = base([], [unsigned, long]), CharP = ptr([], base([], [char])),
    ccl_gensym('$dn', Nv), ccl_gensym('$dn0', N0), cpp_delete_operand(X, Pre, Q),
    ( cpp_dtor(C, DName) -> cpp_destroy(addr(index(Q, id(Nv))), C, DName, D), Loop = [while(0, id(Nv), block([expr(0, predec(id(Nv))), expr(0, D)]))] ; Loop = [] ),
    Raw = bin('-', cast(CharP, Q), int(Ck)), Size = bin('+', int(Ck), bin('*', id(N0), sizeof_type(T))),
    cpp_usual_delete(G, 'delete[]', T, Raw, Size, Free, _),
    append(Pre, [declaration(0, none, SizeT, [var(N0, SizeT, int(0))]),
                 if(0, Q, block([declaration(0, none, SizeT, [var(Nv, SizeT, deref(cast(ptr([], SizeT), bin('-', cast(CharP, Q), int(8)))))]), expr(0, assign('=', id(N0), id(Nv)))|Loop]), none),
                 expr(0, dealloc(none, Free, Q))], Ss),
    E = stmt_expr(block(Ss)).
cpp_delete_array(G, X, E) :- cpp_delete_pointee(X, T), cpp_delete_operand(X, Pre, Q), cpp_usual_delete(G, 'delete[]', T, Q, int(0), Free, _), cpp_delete_expr(Pre, dealloc(none, Free, Q), E).
%% THE ARRAY COOKIE ([expr.new]/15, the Itanium ABI 2.7): a class with a destructor, or whose array deallocation function is a sized one, keeps
%% the count of its elements before the first, in max(8, alignof(T)) bytes
cpp_array_cookie(T, Ck) :- cpp_class_of_type(T, C), ( cpp_dtor(C, _) -> true ; cpp_usual_delete(no, 'delete[]', T, nullptr, int(0), _, cls(Sh)), memberchk(size, Sh) ), !,
    ( ccl_resolve_type(T, RT), ccl_size_align(RT, _, Al) -> true ; Al = 8 ), Ck is max(8, Al).
cpp_array_cookie(_, 0).
cpp_local(N) :- ccl_locals(Fs), member(F, Fs), memberchk(N-_, F), !.
%% the way to a member: o.$base...n by value, p->n or p->$base...n through a pointer
cpp_hops(X, [], X).
cpp_hops(X, [H|Hs], B) :- cpp_hops(member(X, H), Hs, B).
cpp_access(P, N, [], arrow(P, N)) :- !.
cpp_access(P, N, Hops, member(B, N)) :- cpp_hops(deref(P), Hops, B).
%% calls: a method through its object, a method of this, a constructor as a temporary, a free function with its defaults
cpp_call(Ctx, scoped(Path, N), As, E) :- atom(N), As \== [], \+ cpp_scope_class(Path, _), \+ cpp_class_l(N, _), cpp_ctad_args(N, As, Args), !, cpp_call(Ctx, tmpl(N, Args), As, E).   % `std::pair{a, b}': the namespace-qualified name deduces as the bare one does (0.108; libc++'s ranges __unwrap_range)
cpp_call(Ctx, member(X0, scoped(Path, M)), As, E) :- cpp_qual_name(M), !, cpp_expr(Ctx, X0, X), cpp_qual_call(X, Path, M, As, E).   % `b.A::f()': A's f over b's A sub-object, never virtual (0.112); an operator too, `p->A::operator()(x)' (0.121)
cpp_call(Ctx, arrow(X0, scoped(Path, M)), As, E) :- cpp_qual_name(M), !, cpp_expr(Ctx, X0, P0), cpp_arrow_object(P0, P), cpp_qual_call(deref(P), Path, M, As, E).
cpp_call(Ctx, member(X0, dtor(_)), [], E) :- !, cpp_expr(Ctx, X0, X), ( cpp_class_of_type_of(X, C), cpp_dtor(C, DName) -> E = call(id(DName), [addr(X)]) ; cpp_pseudo_dtor(X, E) ).   % x.~T(): the destructor called, nothing for a trivial one
cpp_call(Ctx, arrow(X0, dtor(_)), [], E) :- !, cpp_expr(Ctx, X0, X), ( cpp_pointee_class_of(X, C), cpp_dtor(C, DName) -> E = call(id(DName), [X]) ; cpp_pseudo_dtor(X, E) ).
cpp_call(Ctx, member(X0, tmpl(M, TArgs0)), As, E) :- !,                                       % o.f<T>(args): a member template, its arguments given
    cpp_expr(Ctx, X0, X), cpp_targ_values(TArgs0, TArgs),
    (   cpp_class_of_type_of(X, C), cpp_member_tmpl_via(C, X, addr(X), M, TArgs, As, E) -> true
    ;   cpp_refuse(0, no_member_template(M)) ).
%% `p->f<T>(args)' (0.121): the same member template, through a pointer -- the class's own or a base's, `this' adjusted through the base sub-objects, null where the template
%% is static. It had no clause: the arrow's general road took the template-id for a method NAME and left a raw call, refused `no_member' at the lowering. libc++ 18's
%% `__assignment::__assign_alt' calls `__this->__emplace<_Ip>(std::forward<_Arg>(__arg))' from the call operator of a local class.
cpp_call(Ctx, arrow(X0, tmpl(M, TArgs0)), As, E) :- !,
    cpp_expr(Ctx, X0, X00), cpp_arrow_object(X00, X), cpp_targ_values(TArgs0, TArgs),
    (   cpp_pointee_class_of(X, C), cpp_member_tmpl_via(C, deref(X), X, M, TArgs, As, E) -> true
    ;   cpp_refuse(0, no_member_template(M)) ).
cpp_call(Ctx, tmpl(M, TArgs), As, E) :- Ctx \== none, \+ cpp_local(M), cpp_call_targs(TArgs, TArgs1),   % `__test<_Tp>(nullptr, nullptr)' inside its own class: a member template, its this null where it is STATIC and the object's own where it is not (libc++'s `__lower_upper_bound_unique_impl<true>(__v)' inside __tree read the tree through a null this)
    cpp_member_template_of(Ctx, M, TArgs1, As, Name, C), !, cpp_fill_defaults(Name, As, As1),
    (   cpp_static_member_template(C, M) -> P = nullptr
    ;   cpp_base_hops(Ctx, C, Hops), Hops \== [] -> cpp_hops(deref(id(this)), Hops, B), P = addr(B)   % a BASE's member template: this through the base sub-objects, as a qualified call has it (0.73)
    ;   P = id(this) ),
    cpp_object_arg(Name, P, Obj), E = call(id(Name), [Obj|As1]).
%% ... AND A NESTED CLASS CALLS A STATIC MEMBER TEMPLATE OF ITS HOLDER BARE, its arguments given (0.121; [class.nest]/1, as a static member function's call is, 0.117): libc++ 18's
%% `__value_visitor' inside `__visitation::__variant' opens its call operator with `__std_visit_exhaustive_visitor_check<_Visitor, ...>();', a private static member
%% template of the holder -- read as a class template-id it refused template_without_body, and std::visit with it. `varvisit.cpp'.
cpp_call(Ctx, tmpl(M, TArgs), As, E) :- atom(Ctx), Ctx \== none, \+ cpp_local(M), cpp_encl_chain(Ctx, [_|Encs]), member(Enc, Encs), cpp_static_member_template(Enc, M),
    cpp_call_targs(TArgs, TArgs1), cpp_member_template_call(Enc, M, TArgs1, As, Name), !,
    cpp_check_access(Ctx, Enc, M), cpp_fill_defaults(Name, As, As1), cpp_object_arg(Name, nullptr, Obj), E = call(id(Name), [Obj|As1]).
cpp_call(_, scoped(Path, tmpl(N, TArgs)), As, E) :- atom(N), catch(cpp_scope_class(Path, C), error(not_lowered(_), _), fail), \+ '$cpp_mt'(C, N, _, _),   % `O<int>::I<double>()': a temporary of a MEMBER CLASS TEMPLATE's instance named through its holder, by the type road a declaration of it takes (0.166); the method road took the template-id for a member's name and raised type_error(atomic, tmpl(...))
    catch(cpp_type(base([], [typedef(scoped(Path, tmpl(N, TArgs)))]), T), error(not_lowered(_), _), fail), cpp_class_of_type(T, _), !, cpp_type_call(T, As, E).
cpp_call(_, scoped(Path, tmpl(M, TArgs0)), As, E) :- atom(M), cpp_scope_class(Path, C), '$cpp_mt'(C, M, _, _), !,   % `X::template f<U>()', `X<T>::f<U>(args)': a static member TEMPLATE with its arguments given, its this null -- read as a class template-id it refused template_without_body, which is how libc++'s pair lost every two-argument constructor
    cpp_targ_values(TArgs0, TArgs),
    ( cpp_member_template_call(C, M, TArgs, As, Name) -> cpp_fill_defaults(Name, As, As1),
        ( \+ cpp_static_member_template(C, M), nb_getval('$cpp_class_ctx', Ctx), Ctx \== none, cpp_base_hops(Ctx, C, Hops) -> cpp_hops(deref(id(this)), Hops, B), P = addr(B) ; P = nullptr ),   % `Base::f<U>(args)' inside the class: this through the base sub-objects (0.73's rule for a plain method), null for a static
        cpp_object_arg(Name, P, Obj), E = call(id(Name), [Obj|As1]) ; cpp_refuse(0, no_member_template(M)) ).
cpp_call(Ctx, scoped(Path, M), As, E) :- cpp_scope_class(Path, C), cpp_method(C, M, As, Name, _), !, cpp_check_access(Ctx, C, M),   % X<T>::f(args), C::f(args): a static method (its this null) ...
    cpp_fill_defaults(Name, As, As1),
    (   Ctx \== none, \+ cpp_static_method(C, M, Name), cpp_base_hops(Ctx, C, Hops)              % ... or, INSIDE A CLASS, a qualified call of its own or a base's method: `this', through the base sub-objects, and never virtual -- libc++'s basic_ios forwards `good()' as `return ios_base::good();', which went out with a null this
    ->  ( Hops == [] -> P = id(this) ; cpp_hops(deref(id(this)), Hops, B), P = addr(B) ), cpp_object_arg(Name, P, Obj)
    ;   cpp_object_arg(Name, nullptr, Obj) ),
    cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2]).
cpp_call(_, id(N), Args, V) :- ccl_builtin_trait(N), !, cpp_trait(N, Args, V).                 % __is_same(T, U): the compiler's trait, decided here
cpp_call(_, operator(Op), As, E) :- cpp_operator_new(Op, As, E), !.                           % `::operator new(n)' written out: the allocation the lowering already has
cpp_call(_, scoped(_, operator(Op)), As, E) :- cpp_operator_new(Op, As, E), !.
cpp_call(_, id(N), As, E) :- cpp_builtin_call(N, As, E), !.                                   % the compiler's own builtins libc++ calls, answered as this compiler can
cpp_call(Ctx, memptr_get(X0, F0), As, E) :- !, cpp_expr(Ctx, X0, X), cpp_expr(Ctx, F0, F),      % `(x.*pm)(args)' ([expr.mptr.oper]), written out by a program
    ( cpp_memptr_call(F, X, As, E) -> true ; cpp_refuse(0, pointer_to_member_call) ).
cpp_call(Ctx, memptr_arrow(X0, F0), As, E) :- !, cpp_expr(Ctx, X0, X), cpp_expr(Ctx, F0, F),
    ( cpp_memptr_call(F, deref(X), As, E) -> true ; cpp_refuse(0, pointer_to_member_call) ).
cpp_call(Ctx, member(X0, M), As, E) :- !,
    cpp_expr(Ctx, X0, X),
    (   cpp_class_of_type_of(X, C), length(As, N), cpp_method_on(X, C, M, As, Name, Hops)
    ->  cpp_check_access_obj(Ctx, C, M), cpp_fill_defaults(Name, As, As1),
        (   cpp_slot_call(C, M, N, Name, Slot), ( \+ cpp_static_object(X) -> true ; cpp_dominated(C, M, Name) ) -> cpp_dispatch(Name, addr(X), C, Slot, As1, E)   % a reference, *p: the dynamic type's -- and a named object whose class finds the method on one path where another path overrides it (0.174): the final overrider, through the table
        ;   Hops \== [], \+ cpp_static_object(X), cpp_hops_class(C, Hops, HC), cpp_slot_call(HC, M, N, Name, Slot) -> cpp_hops(X, Hops, B), cpp_dispatch(Name, addr(B), HC, Slot, As1, E)
        ;   \+ cpp_static_object(X), cpp_hops_class(C, Hops, HC), cpp_vbase_slot_call(HC, M, N, Name, V, Slot) -> cpp_hops(X, Hops, B), cpp_dispatch(Name, cast(ptr([], base([], [typedef(V)])), addr(B)), V, Slot, As1, E)   % an override of a VIRTUAL base's slot: through that base's table (0.139)
        ;   cpp_hops(X, Hops, B), cpp_object_arg(Name, addr(B), Obj), cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2]) )
    ;   atom(M), cpp_class_of_type_of(X, C), cpp_data_member(C, M, DH), cpp_hops(X, DH, B), XM = member(B, M),   % A DATA MEMBER OF CLASS TYPE CALLED THROUGH AN OBJECT, `c.f(x)': its class's operator() -- the closure a range adaptor holds (0.66's rule named bare, one object further out)
        cpp_class_of_type_of(XM, FC), cpp_method(FC, operator('()'), As, Name, _)
    ->  cpp_fill_defaults(Name, As, As1), cpp_object_arg(Name, addr(XM), Obj), cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2])
    ;   atom(M), ( ccl_type_of(X, XT0) -> ccl_unref(XT0, XT) ; XT = unknown ),
        ( XT \== unknown, cpp_class_of_type(XT, XC0), cpp_obj_const(X, const), cpp_class_method(XC0, M, _, _, _, _) -> cpp_refuse(0, non_const_member_on_const(M, XC0))   % a NON-CONST member of a const object is no candidate ([over.match.funcs]/5; 0.127): `c.bump()' over a by-value capture in a lambda that is not mutable
        ; XT \== unknown, ccl_members_of(XT, XMs), \+ memberchk(member(_, M, _), XMs), \+ ccl_anon_route(XT, M, _, _), \+ ( cpp_class_of_type(XT, XC), cpp_data_member(XC, M, _) ) -> cpp_refuse(0, no_member(M, XT))   % (a PLAIN struct's own member is one, 0.168: `h.fp(k)' over `struct H { void (*fp)(int &); }' was refused no_member(fp, H)) a KNOWN type with no such member: a decltype asking for it must refuse, which is the SFINAE that rejects a detection
        ; cpp_scalar_object(XT) -> cpp_refuse(0, no_member(M, XT))                       % ... and a SCALAR has no member at all (0.127): `decltype(c.size(), 0)' over an int held, and the lowering refused the body
        ; E = call(member(X, M), As) )                                                   % ... but a DATA member of function-pointer type is called through, as C calls one
    ;   atom(M), ccl_type_of(X, XT0), ccl_unref(XT0, XT), cpp_scalar_object(XT) -> cpp_refuse(0, no_member(M, XT))
    ;   E = call(member(X, M), As) ).
cpp_call(Ctx, arrow(X0, M), As, E) :- !,
    cpp_expr(Ctx, X0, X00), cpp_arrow_object(X00, X),
    (   cpp_pointee_class_of(X, C), length(As, N), cpp_method_on_ptr(X, C, M, As, Name, Hops)
    ->  cpp_check_access_obj(Ctx, C, M), cpp_fill_defaults(Name, As, As1),
        (   cpp_slot_call(C, M, N, Name, Slot) -> cpp_dispatch(Name, X, C, Slot, As1, E)
        ;   cpp_hops_class(C, Hops, HC), cpp_vbase_slot_call(HC, M, N, Name, V, Slot) -> ( Hops == [] -> P0 = X ; cpp_hops(deref(X), Hops, B0), P0 = addr(B0) ), cpp_dispatch(Name, cast(ptr([], base([], [typedef(V)])), P0), V, Slot, As1, E)   % an override of a VIRTUAL base's slot (0.139)
        ;   Hops \== [], cpp_hops_class(C, Hops, HC), cpp_slot_call(HC, M, N, Name, Slot) -> cpp_hops(deref(X), Hops, B), cpp_dispatch(Name, addr(B), HC, Slot, As1, E)   % a virtual method of a BASE the class does not name: that base's table (a virtual base's, the diamond's final overrider behind it)
        ;   ( Hops == [] -> P = X ; cpp_hops(deref(X), Hops, B), P = addr(B) ), cpp_object_arg(Name, P, Obj), cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2]) )
    ;   atom(M), cpp_scalar_arrow(X, XT) -> cpp_refuse(0, no_member(M, XT))   % `p->f()' over a pointer to a scalar, or over no pointer at all (0.127)
    ;   E = call(arrow(X, M), As) ).
cpp_call(Ctx, id(M), As, E) :- Ctx \== none, \+ cpp_local(M), length(As, N), cpp_method_on_ptr(id(this), Ctx, M, As, Name, Hops), !,
    cpp_check_access(Ctx, Ctx, M), cpp_fill_defaults(Name, As, As1),
    (   cpp_slot_call(Ctx, M, N, Name, Slot) -> cpp_dispatch(Name, id(this), Ctx, Slot, As1, E)
    ;   Hops \== [], cpp_hops_class(Ctx, Hops, HC), cpp_slot_call(HC, M, N, Name, Slot), \+ cpp_static_bare(Ctx, M, Name) -> cpp_hops(deref(id(this)), Hops, B), cpp_dispatch(Name, addr(B), HC, Slot, As1, E)
    ;   cpp_hops_class(Ctx, Hops, HC), cpp_vbase_slot_call(HC, M, N, Name, V, Slot), \+ cpp_static_bare(Ctx, M, Name) -> ( Hops == [] -> P0 = id(this) ; cpp_hops(deref(id(this)), Hops, B0), P0 = addr(B0) ), cpp_dispatch(Name, cast(ptr([], base([], [typedef(V)])), P0), V, Slot, As1, E)   % an override of a VIRTUAL base's slot (0.139)
    ;   cpp_static_bare(Ctx, M, Name) -> cpp_object_arg(Name, nullptr, Obj), cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2])   % a STATIC method: no object, as a static member template already had it (0.47) -- libc++'s detections call one from a class-scope decltype, where there is no `this' at all
    ;   ( Hops == [] -> P = id(this) ; cpp_hops(deref(id(this)), Hops, B), P = addr(B) ), cpp_object_arg(Name, P, Obj), cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2]) ).
%% A NESTED CLASS CALLS A STATIC MEMBER FUNCTION OF ITS ENCLOSING CLASS BY NAME ([class.nest]/1, [expr.prim.id]/2; 0.117): the
%% nested class's scope is inside the holder's, so `compute()' in `A::N::get' is `A::compute()' -- with no object, since it is static
%% (a non-static one needs an object of the holder, which a nested class has none of). The data statics were found so since 0.112
%% (cpp_static_member); the function was `undeclared(compute)'. `accessctl2.cpp'.
cpp_call(Ctx, id(M), As, E) :- atom(Ctx), Ctx \== none, \+ cpp_local(M), cpp_encl_chain(Ctx, [_|Encs]), member(Enc, Encs), cpp_static_bare(Enc, M),
    cpp_method(Enc, M, As, Name, _), cpp_static_bare(Enc, M, Name), !,
    cpp_check_access(Ctx, Enc, M), cpp_fill_defaults(Name, As, As1), cpp_object_arg(Name, nullptr, Obj), cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2]).
cpp_call(Ctx, id(M), As, E) :- cpp_closure_this(Ctx, EC), \+ cpp_local(M), length(As, N), cpp_method(EC, M, As, Name, Hops), !,   % a lambda's captured this: the enclosing class's method
    cpp_fill_defaults(Name, As, As1), cpp_closure_object(Hops, P),
    (   cpp_slot_call(EC, M, N, Name, Slot) -> cpp_dispatch(Name, P, EC, Slot, As1, E)
    ;   cpp_object_arg(Name, P, Obj), cpp_ref_args_of(Name, As1, As2), E = call(id(Name), [Obj|As2]) ).
cpp_call(Ctx, scoped([std], move), [X], E) :- !, cpp_expr(Ctx, move(X), E).                     % std::move is Cicili's move: the fields go, the source is emptied; of an int, the int
cpp_call(_, scoped(Path, tmpl(F, TArgs)), As, E) :- \+ cpp_scope_class(Path, _), !, ( atom(F), cpp_ns_key(Path, F, K) -> F1 = K ; F1 = F ), cpp_without_using(F1, cpp_call(none, tmpl(F1, TArgs), As, E)).        % std::swap<int>(a, b): the namespace flattens -- to a deeper namespace's KEY where the name collided (0.112): `__elements::__fn<0>{}', views::keys, is no bare `__fn'
cpp_call(Ctx, scoped(Path, F), As, E) :- atom(F), Path \== [], cpp_ns_key(Path, F, K), \+ ( catch(cpp_scope_class(Path, SC), _, fail), cpp_has_member(SC, F) ), !,   % A NAMESPACE'S KEY BEFORE A CLASS OF THE SAME NAME (0.109): namespaces flatten here, and libc++ has both `ranges::views::__all', the namespace of `__all::__fn', and a class template `__all' -- taken as that class's member, `views::all' was built as the wrong `__fn'; the key the header indexed is the namespace's own, unless the class truly has such a member
    ( cpp_callable_global(K, Name, C) -> cpp_object_call(Name, C, As, E)
    ;   K \== F, cpp_bare_fn(F)                                                              % THE OUTER NAMESPACE'S OVERLOADS TOO (0.117): `std::abs(x)' with <complex> included is the key `std.abs', complex's template, and `using ::abs' brings the plain overloads into std
    ->  (   catch(cpp_call(Ctx, id(K), As, E0), error(not_lowered(W), _), ( W \= instance_refused(_, _), fail )) -> E = E0
        ;   cpp_without_using(F, cpp_call(Ctx, id(F), As, E)) )   % a QUALIFIED name: no using redirects it (0.160)
    ;   cpp_call(Ctx, id(K), As, E) ).
cpp_call(_, scoped(Path, F), As, E) :- atom(F), \+ cpp_scope_class(Path, _), ( cpp_ns_key(Path, F, K) -> true ; K = F ), \+ ( K == F, cpp_object_elsewhere(Path, F) ), cpp_callable_global(K, Name, C), !, cpp_object_call(Name, C, As, E).   % A NAMESPACE-SCOPE OBJECT CALLED goes to its class's operator() (0.100): `ranges::iter_move(x)' is libc++'s customization point object, `inline constexpr auto iter_move = __iter_move::__fn{}', where the bare name also names the hidden friends
cpp_call(_, scoped(Path, F), As, E) :- atom(F), \+ cpp_scope_class(Path, _), cpp_ns_key(Path, F, K), !, cpp_call(none, id(K), As, E).   % a deeper namespace's colliding name, qualified: its key
cpp_call(_, scoped(Path, F), As, E) :- atom(F), \+ cpp_scope_class(Path, _), cpp_cross_fn_key(Path, F, K), !, cpp_without_using(K, cpp_call(none, id(K), As, E)).   % ... and a name two reads define in two namespaces, qualified by one of them that is not std: that namespace's functions (0.227, cpp_cross_fn_key/3)
cpp_call(_, scoped(Path, F), As, E) :- atom(F), \+ cpp_scope_class(Path, _), \+ ( cpp_class_l(F, _), cpp_class_takes(F, As) ), !, cpp_lib_qualified(Path, F, cpp_without_using(F, cpp_call(none, id(F), As, E))).   % std::swap(a, b): as the bare name would, never a member (a qualified name finds no method); a class of that name which cannot take the arguments is another namespace's
%% THE ARGUMENT PASS ON A CALL THROUGH AN OBJECT'S operator() (0.221; cpp_ref_args_of), as the other member roads have it: a local
%% object, a namespace-scope object, a callable data member and a qualified method call took their arguments as written, so a class
%% value went to a by-value parameter of another class without its conversion function -- `h(s)' over `int operator()(V) const',
%% with `S::operator V()', stored the S as a V, and libc++ 18's `__invoke', whose `static_cast<_Fp &&>(__f)(static_cast<_Args &&>(
%% __args)...)' calls the parameter `__f', cast a std::string to the std::string_view of a transparent hash (`std::invoke(h, s)',
%% `std::is_invocable_r_v'; the unordered containers' static assertion `__check_hash_requirements' makes that instance)
cpp_call(_, id(F), As, call(id(Name), [Obj|As2])) :- cpp_local(F), cpp_class_of_type_of(id(F), C), cpp_method_on(id(F), C, operator('()'), As, Name, _), !, cpp_fill_defaults(Name, As, As1), cpp_ref_args_of(Name, As1, As2), cpp_object_arg(Name, addr(id(F)), Obj).   % a lambda, or any object with operator()
%% A NAMESPACE-SCOPE OBJECT IS NOT SEEN BY ITS OWN CLASS'S MEMBERS (0.219; [basic.scope.pdecl]/1, [temp.res.general]/1,
%% [basic.lookup.argdep]/4): its initializer makes its class complete first, so a member's unqualified call of its name finds
%% what was declared before the class, and argument-dependent lookup finds functions alone. libc++ 18's `__strong_order::__fn'
%% calls `strong_order(...)' unqualified, with no poison pill beside it (libc++ 21 declares `void strong_order() = delete;'),
%% and the call went to the object `std::strong_order', whose noexcept and result asked the call again without end:
%% `std::strong_order(1, 2)', `std::weak_order' and `std::partial_order' ran past the memory cap. A function of the name the
%% call finds is called; none is a refusal, which takes the candidate out where its type is asked (SFINAE)
cpp_call(Ctx, id(F), As, E) :- atom(Ctx), Ctx \== none, \+ cpp_local(F), cpp_callable_global(F, _, C), C == Ctx, !,
    ( cpp_fn_best(F, As, Ps, D) -> cpp_free_call(F, Ps, D, As, E) ; cpp_refuse(0, object_unseen_by_its_class(F, C)) ).
cpp_call(_, id(F), As, E) :- \+ cpp_local(F), \+ cpp_libq_elsewhere(F), cpp_callable_global(F, Name, C), !, cpp_object_call(Name, C, As, E).   % a namespace-scope object with operator(), named bare (0.100)
cpp_call(_, scoped(Path, F), As, E) :- atom(F), catch(cpp_scope_class(Path, C0), _, fail), cpp_static_member(C0, F, SN), cpp_callable_global(SN, Name, C), !, cpp_static_use(C0, F, _), cpp_object_call(Name, C, As, E).   % A STATIC DATA MEMBER OF CLASS TYPE CALLED goes to its class's operator(): `_Ops::__iter_move(__start)' with `_Ops' the range policy's `_IterOps', whose `__iter_move' is `static constexpr auto __iter_move = ranges::iter_move;'
cpp_call(Ctx, id(F), As, E) :- atom(F), Ctx \== none, \+ cpp_local(F), atom(Ctx), catch(cpp_static_member(Ctx, F, SN), _, fail), cpp_callable_global(SN, Name, C), !, cpp_static_use(Ctx, F, _), cpp_object_call(Name, C, As, E).   % ... named bare inside its class
%% A DATA MEMBER THAT IS CALLABLE, named bare inside its class, is called through its own class's operator(), as a
%% local of such a class already was: libc++'s scope guard holds the closure it was made with and its destructor
%% writes `__func_()', which is the whole of how `basic_string' unwinds an append. The member is reached the way
%% every bare member name is (this->f_, a base's hops with it), and the closure's call takes its address.
cpp_call(Ctx, id(F), As, call(id(Name), [Obj|As2])) :- Ctx \== none, \+ cpp_local(F), cpp_data_member(Ctx, F, Hops),
    cpp_access(id(this), F, Hops, X), cpp_class_of_type_of(X, C), cpp_method(C, operator('()'), As, Name, _), !,
    cpp_fill_defaults(Name, As, As1), cpp_ref_args_of(Name, As1, As2), cpp_object_arg(Name, addr(X), Obj).
%% A DATA MEMBER OF POINTER-TO-FUNCTION TYPE named bare and called is a call through the pointer, as C calls one (0.112):
%% libc++ 18's `__output_buffer::__flush()' writes `__flush_(__ptr_, __size_, __obj_)', and read as a free function the
%% name was undeclared (`fnptrmember.cpp')
cpp_call(Ctx, id(F), As, call(X, As)) :- Ctx \== none, atom(Ctx), \+ cpp_local(F), cpp_data_member(Ctx, F, Hops),
    cpp_access(id(this), F, Hops, X), catch(ccl_type_of(X, T), _, fail), ccl_resolve_type(T, ptr(_, FT)), ccl_resolve_type(FT, fn(_, _, _)), !.
%% A NAME A USING OF A HEADER NAMESPACE BROUGHT (0.160; cpp_hdr_using): the key first, then the bare name's own road where the key's
%% candidates refuse -- a refusal of a body that held is the call's (`instance_refused'), as a keyed qualified call has it
cpp_call(Ctx, id(F), As, E) :- atom(F), \+ cpp_local(F), cpp_using_key(F, K), !,
    (   catch(cpp_call(Ctx, id(K), As, E0), error(not_lowered(W), Wh), ( W = instance_refused(_, _) -> throw(error(not_lowered(W), Wh)) ; fail )) -> E = E0
    ;   cpp_without_using(F, cpp_call(Ctx, id(F), As, E)) ).
cpp_call(Ctx, tmpl(F, TArgs), As, E) :- atom(F), \+ cpp_local(F), cpp_using_key(F, K), !,
    (   catch(cpp_call(Ctx, tmpl(K, TArgs), As, E0), error(not_lowered(W), Wh), ( W = instance_refused(_, _) -> throw(error(not_lowered(W), Wh)) ; fail )) -> E = E0
    ;   cpp_without_using(F, cpp_call(Ctx, tmpl(F, TArgs), As, E)) ).
cpp_call(_, tmpl(N, TArgs0), As, E) :- cpp_variable_template(N), \+ ( cpp_template(N, _, I), cpp_fn_item(I, _) ), !, cpp_targ_values(TArgs0, TArgs), cpp_instantiate_variable(N, TArgs, V),   % A VARIABLE TEMPLATE'S INSTANCE CALLED is its object's operator() (0.113): `views::elements<1>(r)'
    ( cpp_temp_call(V, As, E0) -> E = E0 ; E = call(V, As) ).
cpp_call(_, tmpl(F, TArgs), As, call(id(Name), As1)) :- cpp_template(F, _, Item), cpp_fn_item(Item, _), !, cpp_call_targs(TArgs, TArgs1), cpp_instantiate_function(F, TArgs1, As, Name), cpp_fill_defaults(Name, As, As0), cpp_ref_args(Name, As0, As1).   % THE INSTANCE'S DEFAULTS ARE FILLED AT THE CALL (0.93): `g(1)' of `template <class T> T g(T a, int b = 5)' went out with ONE argument to a function of two, garbage where C++ has 6 -- the plain road filled them, the template road never did   % a DECLARED-only one too: declval
cpp_call(_, tmpl(N, TArgs), As, E) :- cpp_template(N, _, typedef(_, _)), !,                      % an ALIAS template called by its template-id: the type it names, cast or constructed
    cpp_targ_values(TArgs, TArgs1), cpp_instantiate_type(N, TArgs1, T), cpp_type_call(T, As, E).
%% CLASS TEMPLATE ARGUMENT DEDUCTION ([over.match.class.deduct]): a class template's name written with arguments and
%% no template arguments -- `__allocation_result{__res.ptr, __res.count}', `pair{a, b}' -- deduces them from the
%% IMPLICIT GUIDES: each constructor taken as a function template over the class's own parameters, else, for an
%% aggregate, its data members in order (C++20's aggregate deduction). libc++'s C++23 `__allocate_at_least' returns
%% one, and with the bare name deduced for `auto __buffer' its `.ptr' had no type -- `std::addressof' then refused
%% `cannot_deduce', which is where `s + "!"' stopped at that level.
cpp_call(Ctx, id(N), As, E) :- \+ cpp_local(N), \+ cpp_class_l(N, _), cpp_ctad_args(N, As, Args), !, cpp_call(Ctx, tmpl(N, Args), As, E).   % no argument too: the template's defaults (0.201, cpp_ctad_args_/3)
cpp_call(Ctx, tname(N), As, E) :- atom(N), !, cpp_call(Ctx, id(N), As, E).   % A TEMPLATE TEMPLATE PARAMETER CALLED, `_Container(std::declval<_Range>())' (0.132): its template's name, the arguments deduced from the call ([over.match.class.deduct]) -- libc++'s `ranges::to<std::vector>(r)' finds its container so, and the call reached the decltype untyped
cpp_call(_, tmpl(C, TArgs), As, E) :- cpp_targ_values(TArgs, TArgs1), cpp_targs_settled(TArgs1),   % `Guard<A, I>(a, i, j)': a temporary of a class TEMPLATE's instance, as a plain class's already was
    cpp_instantiate_type(C, TArgs1, T), cpp_class_of_type(T, C1), !, cpp_temporary(T, C1, As, E).
cpp_call(_, id(F), As, E) :- \+ cpp_local(F), cpp_fn_exact(F, As, Ps, D), !, cpp_free_call(F, Ps, D, As, E).   % an overload whose parameters take the arguments EXACTLY: C++ prefers such a non-template to any template
cpp_call(_, id(F), As, E) :- \+ cpp_local(F), cpp_template(F, _, Item), cpp_fn_item(Item, _), !,
    nb_setval('$cpp_fn_refusal', none),
    (   catch(cpp_instantiate_function(F, [], As, Name), error(not_lowered(W), _), ( nb_setval('$cpp_fn_refusal', W), fail ))
    ->  cpp_fill_defaults(Name, As, As0), cpp_ref_args(Name, As0, As1), E = call(id(Name), As1)   % THE INSTANCE'S DEFAULTS FILLED (0.93, as at the explicit call above), then THE ARGUMENT PASS RUNS ON A TEMPLATE'S INSTANCE TOO (the free road's since 0.79): a class value where the instance's parameter wants another class goes through its conversion operator, and `std::__concatenate_strings(a.get_allocator(), __lhs, __rhs)' -- whose parameters are `__type_identity_t<basic_string_view<...>>' -- stored a basic_string's bytes into a string_view, which LLVM refused
    ;   nb_getval('$cpp_fn_refusal', W0), W0 = instance_refused(_, _) -> cpp_refuse(0, W0)        % a template HELD and its body refused: no plain overload stands in for it
    ;   cpp_fn_best(F, As, Ps, D) -> cpp_free_call(F, Ps, D, As, E)                                % no template held: the plain overloads of the name, ONE overload set with them
    ;   nb_getval('$cpp_fn_refusal', W1), ( W1 == none -> cpp_refuse(0, no_matching_template(F)) ; cpp_refuse(0, W1) ) ).
cpp_call(Ctx, id(N), As, E) :- Ctx \== none, \+ cpp_local(N), cpp_class_typedef(Ctx, N, T0),   % a class-scope TYPE named bare inside its class: `__destroy_vector(*this)' a nested class, `size_type(~0)' a cast
    catch(cpp_type(T0, T), error(not_lowered(_), _), fail), !, cpp_type_call(T, As, E).
cpp_call(none, id(N), As, E) :- \+ cpp_local(N), cpp_class_ctx(Cx), cpp_class_typedef(Cx, N, T0),   % ... AND IN A HIDDEN FRIEND's body, walked with no `this' in its class's words ([class.friend]/7; 0.132): iota_view's iterator writes `return difference_type(difference_type(__x.__value_) - difference_type(__y.__value_));' in its friend `operator-', and the calls reached the lowering raw, `undeclared(difference_type)' (views::common over views::iota, `cv.end() - cv.begin()')
    catch(cpp_type(T0, T), error(not_lowered(_), _), fail), !, cpp_type_call(T, As, E).
%% the same for a typedef at FILE scope, which libc++ calls by its own name: `__destruct_at_end(p, false_type())'
%% makes a temporary of integral_constant<bool, false> by its alias, and `size_t(n)' is the cast it looks like
cpp_call(_, id(N), As, E) :- \+ cpp_local(N), \+ ccl_declared(N, fn(_, _, _)), ccl_typedef_of(N, T0),
    catch(cpp_type(T0, T), error(not_lowered(_), _), fail), !, cpp_type_call(T, As, E).
cpp_call(_, id(K), As, E) :- atom(K), \+ cpp_local(K), cpp_hdr_keyed_typedef(K, T0),   % ... AND A HEADER'S KEYED ONE (0.201, cpp_ns_typedef_quals/4), its bare uses in its namespace gone to the key: a cast, a temporary or the type's zero
    catch(cpp_type(T0, T), error(not_lowered(_), _), fail), !, cpp_type_call(T, As, E).
cpp_call(_, id(C), As, E) :- cpp_class_l(C, _), cpp_class_takes(C, As), !, cpp_temporary(base([], [typedef(C)]), C, As, E).
cpp_call(_, id(T), As, E) :- ccl_tag(T, Ms), cpp_tag_takes(Ms, As), !,
    (   ( Ms == [] ; ccl_is_enum_tag(Ms) ), As = [X] -> E = cast(base([], [typedef(T)]), X)   % an ENUM's name: `__element_count(n)', `Color(2)' -- a cast, never a literal of members
    ;   ccl_is_enum_tag(Ms), As == [] -> E = cast(base([], [typedef(T)]), int(0))   % `E()' and `E{}' VALUE-INITIALIZE an enum ([dcl.init]/8, 0.117): the zero, `r.ec == std::errc()' of <charconv>
    ;   As = [X], cpp_record_own_value(X, base([], [typedef(T)])) -> E = X   % ONE VALUE OF THE STRUCT'S OWN TYPE IS ITS COPY ([expr.type.conv]/1, [dcl.init]/17.6.1; 0.205), as the typedef's road has it (0.161): `R(grab(3))' was the aggregate of one item, the struct stored into its first member, which LLVM refused
    ;   findall(item([], A), member(A, As), Items), E = compound_lit(base([], [typedef(T)]), init(Items)) ).   % P{3, 4} of a plain struct: C's compound literal
cpp_call(_, scoped(Path, N), As, E) :- atom(N), cpp_scope_class(Path, Enc), cpp_class_typedef(Enc, N, T0),   % `Plain::Nested(7)': a temporary of a NESTED class; `ios_base::fmtflags(0)': a class-scope typedef's cast, as the bare name's road has it
    catch(cpp_type(T0, T), error(not_lowered(_), _), fail), !, cpp_type_call(T, As, E).
cpp_call(_, scoped(_, C), As, E) :- atom(C), cpp_class_l(C, _), cpp_class_takes(C, As), !, cpp_temporary(base([], [typedef(C)]), C, As, E).   % std::string("x"): a temporary of the class
%% `X::f(args)' ON A CLASS WITHOUT SUCH A MEMBER REFUSES, as `o.f()' has since 0.51 -- the rejection a detection
%% needs: libc++ chooses `__to_address' by `decltype((void) pointer_traits<_Pointer>::to_address(declval<const
%% _Pointer &>()))', and flattened to a call of the global name `to_address' it was void either way, so every
%% pointer had one and the wrong overload held. A nested class or a class-scope typedef called by that name is a
%% temporary or a cast (above), a static data member a value: only a name the class has NOTHING of refuses.
cpp_call(_, scoped(Path, M), As, _) :- atom(M), cpp_scope_class(Path, C), \+ cpp_has_member(C, M), \+ cpp_class_typedef(C, M, _), !,
    length(As, K), cpp_refuse(0, no_member(C, M, K)).
cpp_call(_, id(F), As, E) :- !, ( cpp_fn_best(F, As, Ps, D) -> cpp_free_call(F, Ps, D, As, E)   % the overload the arguments fit best; a name with one definition keeps it, as C does
    ;   cpp_deleted_hdr_fn(F) -> cpp_refuse(0, deleted_function(F))   % A HEADER'S DELETED FUNCTION, a poison pill (0.219, cpp_deleted_hdr_fn/1)
    ;   cpp_libq_elsewhere(F) -> cpp_refuse(0, no_member_of_std(F))   % ... AND A NAME THAT std DECLARES NOTHING OF HERE (0.221, cpp_object_elsewhere/2)
    ;   cpp_use_cdecl(F), cpp_fill_defaults(F, As, As1), cpp_ref_args(F, As1, As2), E = call(id(F), As2) ).   % a C function a header declares in C++'s words, its types resolved (0.227, cpp_use_cdecl/1)
cpp_call(Ctx, ccast(_, R, X0), As, E) :- ( R = ref(_, T) ; R = rref(_, T) ), cpp_this_form(X0, X),   % A CALL THROUGH A CAST TO A REFERENCE CALLS THE OPERAND ([expr.static.cast]: the cast names the object, an lvalue or an xvalue; 0.93): libc++ 18's `__invoke' writes `static_cast<_Fp &&>(__f)(static_cast<_Args &&>(__args)...)', and the callee reached the lowering as the cast itself
    (   cpp_class_of_type(T, C)
    ->  cpp_operand_class(Ctx, X, D),                                                    % ... AND A CAST TO A BASE'S REFERENCE CALLS THE BASE'S operator() OVER THE BASE SUB-OBJECT (0.94): libc++ 18's `__map_value_compare' writes `static_cast<const _Compare &>(*this)(x.first, y.first)' over its empty base `less<K>', and `*this' -- the reader's `deref(this)', the bare atom -- was untyped, so the guard below took the operand's road and the comparator called ITSELF until the stack was gone (every map of strings segfaulted before its first line). The operand `*this' is the class being walked; a class the cast does not change takes the operand's road, a base of it its own operator() -- dispatched when virtual, as `(*p)(a)' is
        ( D == C -> cpp_call(Ctx, X, As, E) ; cpp_base_hops(D, C, Hops0), cpp_base_operator_call(X, C, Hops0, As, E) )
    ;   cpp_call(Ctx, X, As, E) ), !.
cpp_call(Ctx, F, As, E) :- ( F = move(X0) -> true ; cpp_std_move_call(F, X0) ), !, cpp_call(Ctx, X0, As, E).   % ... AND THROUGH `std::move' THE OBJECT IT NAMES (0.206): libc++'s `basic_string::resize_and_overwrite' calls `std::move(__op)(data(), __n)', and the call of a `move' reached the lowering
cpp_call(Ctx, F, As, E) :- cpp_expr(Ctx, F, F1), ( cpp_temp_call(F1, As, E0) -> E = E0 ; cpp_object_unfit(F1, As, C) -> cpp_refuse(0, no_call_operator_fits(C)) ; cpp_callee_params(F1, Ps), cpp_callee_mismatch(Ps, As) -> cpp_refuse(0, argument_mismatch) ; cpp_callee_params(F1, Ps), cpp_ref_args_(Ps, As, As1) -> E = call(F1, As1) ; E = call(F1, As) ).   % ... and A PLAIN STRUCT HANDED TO A SCALAR PARAMETER through a function pointer or reference is refused (0.127), the detection's answer; AN OBJECT WHOSE operator() NOTHING FITS too (0.221, cpp_object_unfit/3)
%% A HEADER'S DELETED FUNCTION CALLED, and no overload that fits (0.219): libc++'s poison pill, `void strong_order() =
%% delete;' inside std::__strong_order (libc++ 21; and weak_order, partial_order, iter_move kin), stands where ordinary lookup
%% would find the object of the outer namespace, and the call is ill-formed but by argument-dependent lookup -- a refusal,
%% which takes the candidate out where its type is asked. A deleted function is declared in no table (reader 152), and the
%% call went on as one of an undeclared name: `decltype(strong_ordering(strong_order(t, u)))' was strong_ordering, the
%% candidate stood, and `std::strong_order(1, 2)' was `undeclared('__strong_order.strong_order')' in its body
cpp_deleted_hdr_fn(F) :- atom(F), \+ ccl_declared(F, fn(_, _, _)), catch(cpp_hdr_item(F, declaration(_, _, _, Vs)), _, fail), memberchk(var(F, fn(_, _, _), delete), Vs), !.
%% A CALL THROUGH AN OBJECT WHOSE operator() NOTHING FITS IS A REFUSAL (0.221; [over.call.object]/1, [temp.deduct.general]/8):
%% a temporary or an object of class type called, `compare_three_way()(t, u)', where no operator() of its class takes the
%% arguments -- one whose constraint fails among them -- is ill-formed, and where its type is asked the refusal takes the
%% candidate out. The call went on as `call(compound_lit(...), As)', of no type, and inside a functional cast, libc++'s
%% `strong_ordering(compare_three_way()(t, u))', the candidate had the cast's type and stood: `std::strong_order' over a
%% class with `==' and `<' and no `<=>' chose `__go(t, u, __priority_tag<0>())', and `std::compare_strong_order_fallback'
%% over it was `not lowered yet: call(compound_lit(... compare_three_way ...))'. A class with a conversion function to a
%% pointer or a reference to a function is left as it was ([over.call.object]/2's surrogate call functions)
cpp_object_unfit(F1, As, C) :- cpp_class_of_type_of(F1, C), \+ cpp_method(C, operator('()'), As, _, _),
    \+ ( cpp_class_method(C, operator(conv(T)), _, _, _, _), cpp_fn_target(T, fn(_, _, _)) ), !.
%% ARGUMENT-DEPENDENT LOOKUP OF THE PROGRAM'S KEYED FUNCTIONS (0.221; [basic.lookup.argdep]/2, /3): a call written unqualified
%% whose name the program's namespace keyed apart from the library's (cpp_lib_quals/4), one of whose arguments is of a class of
%% that namespace, finds the keyed function there where it takes the arguments -- ahead of the library's of the name, which is
%% how C++ ranks a non-template that fits beside a library template. A block-scope object or a member of the class the call is in
%% stops it, as ordinary lookup that finds one does (/3); a C function that the walk declared again for its type in the
%% function's frame (cpp_c_decl_current/2: `std::abs(-4)' over libc++ 21 and <algorithm>) is no block-scope name, and `abs(v)'
%% after it in the same function went on as the C function's call. libc++ 18's `std::strong_order' over the program's `ns::Q'
%% calls `strong_order(t, u)' inside `__strong_order::__fn', and libc++ 21's names it `__strong_order.strong_order', its poison
%% pill's key: the bare name is asked, and the program's `ns::strong_order(const Q &, const Q &)' is the one found. A qualified
%% call comes as `scoped(...)' and asks no argument's namespace ([basic.lookup.argdep]/1)
cpp_call_adl(Ctx, id(F), As, E) :- atom(F), \+ cpp_block_object(F), cpp_adl_own_key(Ctx, F, As, K), cpp_adl_call(K, As, E0), !, E = E0.
cpp_call_adl(Ctx, F, As, E) :- cpp_call(Ctx, F, As, E).
cpp_adl_own_key(Ctx, F, As, K) :- cpp_bare_name(F, N), catch('$cpp_ns_libkeyed'(N), _, fail), \+ cpp_member_scope(Ctx, N),
    member(A, As), cpp_adl_arg_class(A, C), cpp_own_class_ns(C, P), cpp_ns_key(P, N, K), K \== F, !.
%% THE ARGUMENT'S ASSOCIATED CLASSES ([basic.lookup.argdep]/3): its class, a plain struct or union, or an enumeration, each of the
%% namespace it is declared in -- a pointer's pointee's (0.221) -- and, for an instance of a class template, the classes of its
%% template's arguments too (0.221): `count(&s)' over the program's `ns::S *' and `size(v)' over a `std::vector<ns::S>' find
%% the program's `ns::count' and `ns::size'; ... AND A CLASS'S DIRECT AND INDIRECT BASES (/3.2; 0.221): `size(d)' over a `D :
%% ns::B' finds `ns::size(const ns::B &)'; ... AND A COMPOUND TYPE'S PARTS (0.229; /3.3, /3.5 to /3.7): a pointer's and an
%% array's element, a function type's parameters and its result, a pointer to member's class and its member's type --
%% `count(take)' over a `void take(ns::S)', `find(make)' over a `ns::S make()', `sort(&ns::M::x)', `size(arr)' over a
%% `ns::S[2]' -- AND A TEMPLATE TEMPLATE ARGUMENT'S NAMESPACE (/3.2): `data(Holder<ns::Box>{})' over a global `Holder'
cpp_adl_arg_class(A, C) :- catch(cpp_class_of_type_of(A, C0), _, fail), !, cpp_adl_assoc(C0, C).
cpp_adl_arg_class(A, C) :- catch(cpp_arg_type(A, T), _, fail), ccl_unref(T, T1), catch(ccl_resolve_type(T1, R), _, fail),
    cpp_adl_type_classes(R, 0, C0), cpp_adl_assoc(C0, C).
cpp_adl_type_class(T, C) :- catch(cpp_class_of_type(T, C), _, fail), !.
cpp_adl_type_class(base(_, [S]), C) :- compound(S), ( S = struct(C, _) ; S = union(C, _) ; S = enum(C, _) ), atom(C), C \== anon.
cpp_adl_assoc(C, C).
cpp_adl_assoc(C, D) :- catch('$cpp_inst'(C, inst(_, TArgs)), _, fail), is_list(TArgs), member(TA, TArgs), compound(TA),
    ( TA = tname(D) -> atom(D) ; catch(ccl_resolve_type(TA, R), _, fail), cpp_adl_type_class(R, D) ), D \== C.
cpp_adl_assoc(C, D) :- cpp_adl_base(C, 0, D).
%% a type's associated classes, its parts' too, some levels deep (a pointer to a function returning a pointer ...)
cpp_adl_type_classes(T, _, C) :- cpp_adl_type_class(T, C).
cpp_adl_type_classes(T, K, C) :- K < 6, cpp_adl_type_part(T, P0), cpp_adl_resolve(P0, P), K1 is K + 1, cpp_adl_type_classes(P, K1, C).
cpp_adl_type_part(ptr(_, P), P).
cpp_adl_type_part(arr(_, E), E).
cpp_adl_type_part(fn(R, _, _), R).
cpp_adl_type_part(fn(_, Ps, _), P) :- is_list(Ps), member(param(P, _), Ps).
cpp_adl_type_part(memptr(X, _, _), base([], [typedef(X)])).
cpp_adl_type_part(memptr(_, _, M), M).
%% ... a part as the declaration wrote it, resolved in the desugaring's words first: a function's parameter `ns::S' is
%% scoped([ns], 'S'), which the table's resolution alone does not name
cpp_adl_resolve(P0, P) :- ( catch(cpp_type(P0, P1), _, fail) -> true ; P1 = P0 ), catch(ccl_resolve_type(P1, P), _, fail).
cpp_adl_base(C, K, D) :- K < 32, catch(cpp_direct_bases(C, Bs), _, fail), member(B, Bs), atom(B), ( D = B ; K1 is K + 1, cpp_adl_base(B, K1, D) ).
%% the call qualified by the library's namespace, `std::f(...)' or `::std::f(...)', chosen with the program's own overloads of
%% the name hidden at its depth (cpp_fn_hidden/2)
cpp_lib_qualified(Path, F, G) :- ( Path = [std|_] ; Path = [global, std|_] ), !, nb_getval('$cpp_depth', D),
    ( nb_current('$cpp_libq', Q0) -> true ; Q0 = none ), nb_setval('$cpp_libq', F-D),
    ( catch(G, Ex, ( nb_setval('$cpp_libq', Q0), throw(Ex) )) -> nb_setval('$cpp_libq', Q0) ; nb_setval('$cpp_libq', Q0), fail ).
cpp_lib_qualified(_, _, G) :- call(G).
%% A QUALIFIED CALL TAKES NO OBJECT OF ANOTHER NAMESPACE (0.221; [namespace.qual]/2): a read keys apart only the names that collide
%% in it, so a bare name can hold a function template of std in one header's read and an object of std::ranges or std::ranges::views
%% in another's -- `<ranges>' holds `views::reverse' and `views::transform' bare, `<vector>' at C++20 `ranges::upper_bound' and
%% `ranges::for_each', `<algorithm>' `ranges::size' -- and `std::reverse(b, e)' went to the object's road, the adaptor's
%% operator(). A call qualified by std takes an object of the name only where one of the name's object items stands in std itself
%% (the AST's paths, `'$cpp_hdr_ast_ns''; an inline namespace's segment is none, so the comparison objects of <compare> are
%% std's); else it takes the functions' roads, and where nothing of std takes it, it is refused by name (`no_member_of_std(F)'):
%% `std::size(a)' at C++23 with <algorithm> alone, whose read holds `ranges::size' and no `std::size', called the object, where
%% clang++ over libc++ says "no member named 'size' in namespace 'std'". Another qualifier keeps its road (a namespace alias of
%% the program's names no path); a keyed name is its own
cpp_object_elsewhere(Path, F) :- findall(S, ( member(S, Path), atom(S), S \== global ), QP), last(QP, std), cpp_object_paths(F, NPs), NPs \== [],
    \+ ( member(NP, NPs), last(NP, std) ).
cpp_libq_elsewhere(F) :- nb_current('$cpp_libq', F-D), nb_getval('$cpp_depth', D), cpp_object_elsewhere([std], F).
%% ... and its function templates' candidates leave the program's own out, as its overloads do (cpp_fn_hidden/2): the program's
%% `template <class T> T max(T, T)' answered `std::max(2, 3)', 2 for clang's 3
cpp_libq_cands(F, Cs0, Cs) :- nb_current('$cpp_libq', F-D), nb_getval('$cpp_depth', D), \+ catch('$cpp_own_ns'(F, [std|_]), _, fail),
    catch('$cpp_own_tmplfn'(F, _, _), _, fail), !,
    findall(TPs-Fn, ( member(TPs-Fn, Cs0), \+ ( Fn = function(L, _, _, _, _, _, Body), catch('$cpp_own_tmplfn'(F, L, Body), _, fail) ) ), Cs).
cpp_libq_cands(_, Cs, Cs).
cpp_object_paths(F, NPs) :- findall(I, catch('$cpp_hdr_ast'(F, I), _, fail), Is), Is \== [], findall(P, catch('$cpp_hdr_ast_ns'(F, P), _, fail), Ps),
    cpp_cross_zip(Is, Ps, IPs), !, findall(NP, ( member(I-P, IPs), P \== c, cpp_object_item(I, F), cpp_ns_named_path(P, NP), NP \== [] ), NPs).
cpp_object_paths(_, []).
cpp_object_item(declaration(_, _, _, Vs), F) :- member(var(F, T, _), Vs), \+ T = fn(_, _, _), !.
cpp_bare_name(F, N) :- atomic_list_concat(Ss, '.', F), last(Ss, N), !.
cpp_block_object(N) :- ccl_locals(Fs), member(F, Fs), memberchk(N-T, F), T \= fn(_, _, _), !.
cpp_member_scope(Ctx, N) :- atom(Ctx), Ctx \== none, catch(cpp_has_member(Ctx, N), _, fail), !.
cpp_own_class_ns(C, P) :- ( catch('$cpp_inst'(C, inst(C0, _)), _, fail) -> true ; C0 = C ), atom(C0), ( catch('$cpp_type_ns'(C0, P), _, fail) ; catch('$cpp_own_ns'(C0, P), _, fail) ), is_list(P), !.
cpp_adl_call(K, As, E) :- cpp_fn_exact(K, As, Ps, D), !, cpp_free_call(K, Ps, D, As, E).
cpp_adl_call(K, As, E) :- catch(cpp_template(K, _, Item), _, fail), cpp_fn_item(Item, _), catch(cpp_instantiate_function(K, [], As, Name), error(not_lowered(_), _), fail), !,
    cpp_fill_defaults(Name, As, As0), cpp_ref_args(Name, As0, As1), E = call(id(Name), As1).
cpp_adl_call(K, As, E) :- cpp_fn_best(K, As, Ps, D), !, cpp_free_call(K, Ps, D, As, E).
%% A TRIVIAL DESTRUCTOR'S CALL STILL EVALUATES ITS OBJECT EXPRESSION (0.136; [expr.call]/5): `(--__end_)->~value_type()' over an
%% int, in libc++'s valarray::__clear, decrements -- dropped with the call, the loop never ended (every std::valarray's
%% destructor). A plain name has nothing to evaluate.
cpp_pseudo_dtor(X, int(0)) :- ( X = id(_) ; X = this ), !.
cpp_pseudo_dtor(X, comma(X, int(0))).
%% A BASE'S MEMBER TEMPLATE CALLED BARE WITH EXPLICIT ARGUMENTS (0.93): the class's own first, then each base's
%% ([class.member.lookup]: the bases are searched where the class itself has no such name), the signature checked in
%% the class that DECLARES it. libc++'s `__tuple_sfinae_base' declares `__do_test<_Trait>(...)' and every derived
%% trait calls it bare -- found in the derived class alone, the call fell to the CLASS-template road and refused
%% `template_without_body(__do_test)', which the static fold caught, leaving the trait's `value' an undefined extern.
cpp_member_template_of(C, M, TArgs, As, Name, C) :- '$cpp_mt'(C, M, _, _), !, cpp_member_template_call(C, M, TArgs, As, Name).
cpp_member_template_of(C, M, TArgs, As, Name, Owner) :- cpp_base_scope(C, B), cpp_member_template_of(B, M, TArgs, As, Name, Owner), !.
cpp_static_member_template(C, M) :- '$cpp_mt'(C, M, _, method(_, Qs, _, _, _, _, _)), memberchk(static, Qs), !.
%% THE CALL OF A MEMBER TEMPLATE WITH ITS ARGUMENTS GIVEN, through an object or a pointer (0.121): the class's own template or a BASE's, `this' moved through the base
%% sub-objects, null where the template is static, the defaults filled. libc++ 18's `variant::emplace' calls `__impl_.__emplace<_Ip>(...)' of a base of `__impl'.
cpp_member_tmpl_via(C, ObjLv, Ptr, M, TArgs, As, E) :-   % ... THE OBJECT the call is made on known to the candidates (0.206), as a call without arguments given has it: one with an explicit object parameter deduces its `Self' from it -- C++26's `v.visit<R>(f)', `template <class _Rp, class _Self, class _Visitor> _Rp visit(this _Self &&, _Visitor &&)' in libc++ 21, was `no_member_template(visit)'
    cpp_with_obj_expr(ObjLv, cpp_member_template_of(C, M, TArgs, As, Name, Owner)), cpp_fill_defaults(Name, As, As1),
    (   cpp_static_member_template(Owner, M) -> P = nullptr
    ;   cpp_base_hops(C, Owner, Hops), Hops \== [] -> cpp_hops(ObjLv, Hops, B), P = addr(B)
    ;   P = Ptr ),
    cpp_object_arg(Name, P, Obj), E = call(id(Name), [Obj|As1]).
%% A BARE CALL OF A STATIC MEMBER passes no object (0.115): a static method, or a static member TEMPLATE of the class
%% (cpp_static_member_template). Why: a hidden friend template walked in its class calls the static member template
%% `cur(i)' bare, and `this' was passed where none is declared, `undeclared(this)'. `friendtmpl.cpp'.
cpp_static_bare(C, M) :- ( cpp_static_method(C, M, _) ; cpp_static_member_template(C, M) ), !.
%% ... AND THE FUNCTION CHOSEN is the static one (0.117): `vector<bool>' declares `void swap(vector &)' and `static void swap(reference,
%% reference)', and `swap(__v)' in `reserve' went out with a null `this' because the NAME has a static overload -- a segmentation fault on
%% the first `reserve' of any `vector<bool>'. The name decides only what to ask; the chosen function decides the object. `vectorbool.cpp'.
cpp_static_bare(C, M, Name) :- ( cpp_static_method(C, M, Name) ; cpp_static_member_template(C, M) ), !.
cpp_static_method(C, M, Name) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, Qs, _, M, Ps, _, _), Ms), memberchk(static, Qs), cpp_mangle_q(C, M, Qs, Ps, Name), !.
cpp_base_hops(C, C, []) :- !.
cpp_base_hops(Ctx, C, Hops1) :- cpp_class_l(Ctx, cls(B, _, _, _, _)), B \== none, cpp_base_hops(B, C, Hops), cpp_base_hop(B, ['$base'|Hops], Hops1).
cpp_base_hops(Ctx, C, [Slot|Hops]) :- '$cpp_base_slot'(Ctx, B, Slot), cpp_base_hops(B, C, Hops).
cpp_base_hops(Ctx, C, Hops) :- '$cpp_extra'(Ctx, Es), member(B, Es), \+ '$cpp_base_slot'(Ctx, B, _), cpp_base_hops(B, C, Hops).   % A LATER EMPTY BASE has no sub-object (0.121): its address is the object's, no hop -- `this->B::f()' in a class over two empty closures (the `overloaded' idiom)
%% `::operator new(n)' AND ITS KIN WRITTEN OUT, and libc++'s __builtin_operator_new and __builtin_operator_delete (0.202; malloc and
%% free before, an alignment dropped): the allocation or deallocation function a call of that name takes -- a replaceable one by its
%% arguments' kinds (the program's where it replaces it), a reserved placement form its pointer ([new.delete.placement]), any other the
%% program's own overload set
cpp_operator_new(Op, As, E) :- cpp_alloc_op(Op), cpp_arg_kinds(As, Ks), cpp_written_alloc(Op, Ks, As, E).
cpp_written_alloc(Op, [size, ptr], [_, P], cast(ptr([], base([], [void])), P)) :- memberchk(Op, [new, 'new[]']), !.
cpp_written_alloc(Op, [ptr, ptr], _, cast(base([], [void]), int(0))) :- memberchk(Op, [delete, 'delete[]']), !.
cpp_written_alloc(Op, Ks, As, E) :- cpp_alloc_sym(Op, Ks, F), !, cpp_copies(call(id(F), As), E).
cpp_written_alloc(Op, _, As, E) :- length(As, N), length(Qs, N), cpp_free_operator(Op, Qs, Set), cpp_call(none, id(Set), As, E).
%% nothing here is evaluated at compile time, so a run-time answer is the true one
cpp_builtin_call('__builtin_source_location', [], E) :- !, cpp_srcloc(E).   % the place of the call whose default argument it is: std::source_location::current() (0.166, below)
cpp_builtin_call(B, [], E) :- cpp_srcloc_builtin(B, K), !, cpp_srcloc_value(K, B, E).   % clang's `__builtin_FILE()', `__builtin_LINE()' and kin: the same place (0.201, below; glibc's `assert')
cpp_builtin_call('__builtin_invoke', [F, O], E) :-        % A POINTER TO A DATA MEMBER applied to an object is `o.*pm', and `p->*pm' for a pointer to the object ([func.require]/1.4, 1.5; 0.126): libc++ 21 writes std::invoke and __invoke_result on __builtin_invoke, where libc++ 18 had overloads of __invoke that read `std::forward<_A0>(__a0).*__f' -- a detection of `int Pt::*' called with a `Pt &' met no_member_type(__invoke_result_impl..., type)
    cpp_arg_type(F, FT), ccl_resolve_type(FT, memptr(C, _, MT)), MT \= fn(_, _, _), !,
    (   cpp_invoke_object(O, C, P, Const-Cat), cpp_memptr_read(P, F, E0) -> cpp_invoke_result(Const, Cat, E0, E)
    ;   cpp_refuse(0, invoke_object(C)) ).                    % an argument that is no object of the class (or derived) and no pointer to one: not invocable, which a detection reads
cpp_builtin_call('__builtin_invoke', [F, O|As], E) :- cpp_memptr_call(F, O, As, E), !.   % ... and a POINTER TO MEMBER as the callee is `(obj.*pm)(args...)': std::invoke and std::mem_fn are written on it
cpp_builtin_call('__builtin_invoke', [F|As], E) :- !, cpp_call(none, F, As, E).   % clang's __builtin_invoke(f, args...) is std::invoke: the callee applied to the arguments (a callable object through its operator(), a function by name); libc++'s __invoke_result asks it under a decltype
cpp_builtin_call('__builtin_is_constant_evaluated', [], bool(false)).
cpp_builtin_call('__atomic_always_lock_free', [S, P], B) :- cpp_const_value(S, K), !, ( ccl_lock_free_at(K, P) -> B = bool(true) ; B = bool(false) ).   % over the desugared pointer (0.194): libc++ 21's atomic_ref hands it `std::addressof' of an aligned instance
cpp_builtin_call('__builtin_classify_type', [X], int(K)) :- cpp_arg_type(X, T), ccl_type_class(T, K), !.   % the class of the operand's type, clang's numbers (0.194)
cpp_builtin_call('__builtin_launder', [P], P).
cpp_builtin_call('__builtin_addressof', [X], addr(X)).
cpp_builtin_call('__builtin_expect', [E, _], E).
cpp_builtin_call('__builtin_assume_aligned', [P|_], P).
cpp_builtin_call('__builtin_operator_new', As, E) :- cpp_operator_new(new, As, E).          % the global allocation function its arguments name (0.202): a size, an alignment, the nothrow tag
cpp_builtin_call('__builtin_operator_delete', As, E) :- cpp_operator_new(delete, As, E).
%% the memory builtins are the C library's functions, which the lowering declares when the file did not
%% (ir_cpp_prelude): libc++ relocates a vector's elements with __builtin_memcpy
cpp_builtin_call('__builtin_memcpy', As, call(id(memcpy), As)).
%% THE MATH BUILTINS ARE LIBM'S FUNCTIONS, declared here when no header did: libc++'s <cmath> wrappers are
%% `inline float ceil(float __x) { return __builtin_ceilf(__x); }', which the hash table's rehash calls, and
%% <unordered_map>'s closure declares no `ceilf'. The long double form is libm's (`sqrtl'), a long double being x87's
%% 80 bits on x86-64 since 0.108; the prototype is emitted once, as a mangled declaration is (cpp_use_mangled).
cpp_builtin_call(B, As, call(id(F), As)) :- atom(B), atom_concat('__builtin_', F0, B), cpp_math_fn(F0, F, Ret, Ps), !, cpp_math_declared(F, Ret, Ps).
%% THE INTEGER ABSOLUTE VALUES (0.117) are the C library's too: libc++'s <stdlib.h> writes `abs(long)' as `__builtin_labs(__x)', which
%% `std::abs(-4L)' met as an undeclared name
cpp_builtin_call('__builtin_abs', As, call(id(abs), As)) :- cpp_math_declared(abs, base([], [int]), [param(base([], [int]), anon)]).
cpp_builtin_call('__builtin_labs', As, call(id(labs), As)) :- cpp_math_declared(labs, base([], [long]), [param(base([], [long]), anon)]).
cpp_builtin_call('__builtin_llabs', As, call(id(llabs), As)) :- cpp_math_declared(llabs, base([], [long, long]), [param(base([], [long, long]), anon)]).
cpp_builtin_call('__builtin_memmove', As, call(id(memmove), As)).
cpp_builtin_call('__builtin_memset', As, call(id(memset), As)).
cpp_builtin_call('__builtin_memcmp', As, call(id(memcmp), As)).
cpp_builtin_call('__builtin_memchr', As, call(id(memchr), As)).
cpp_builtin_call('__builtin_char_memchr', As, call(id(memchr), As)).   % clang's memchr over char: libc++'s char_traits<char>::find, which getline scans a buffer with
%% THE WIDE ONES are the C library's too, and are DECLARED here when no header did (as the math builtins are):
%% libc++ calls them through `__constexpr_wmemchr' and kin precisely so its <string> and <algorithm> need no
%% <cwchar>, and `std::find' of an INT goes that road -- `sizeof(int) == sizeof(wchar_t)' on this ABI
cpp_builtin_call('__builtin_wmemchr', As, call(id(wmemchr), As)) :- cpp_wide_fn(wmemchr, Ret, Ps), cpp_math_declared(wmemchr, Ret, Ps).
cpp_builtin_call('__builtin_wmemcmp', As, call(id(wmemcmp), As)) :- cpp_wide_fn(wmemcmp, Ret, Ps), cpp_math_declared(wmemcmp, Ret, Ps).
cpp_builtin_call('__builtin_wcslen', As, call(id(wcslen), As)) :- cpp_wide_fn(wcslen, Ret, Ps), cpp_math_declared(wcslen, Ret, Ps).
cpp_builtin_call('__builtin_strlen', As, call(id(strlen), As)).
%% what this compiler can only answer at run time, or need not answer at all: a constant test is FALSE (nothing
%% here is folded past ccl_const_eval), an assumption and a prefetch are nothing, and an unreachable point is nothing
cpp_builtin_call('__builtin_constant_p', [_], int(0)).
cpp_builtin_call('__builtin_assume', [_], int(0)).
cpp_builtin_call('__builtin_assume_dereferenceable', [_|_], int(0)).   % libc++'s `__assume_valid_range', which EVERY range algorithm over a vector's iterators calls
cpp_builtin_call('__builtin_unreachable', [], int(0)).
cpp_builtin_call('__builtin_prefetch', [_|_], int(0)).
%% THE BIT COUNT, folded here where the argument folds: libc++ writes a type's `digits' as
%% `__builtin_popcountg(~__make_unsigned_t<type>(0)) - is_signed', and numeric_limits<ptrdiff_t>::__max is built
%% from it -- a static const that does not fold is emitted `extern' and the link finds nothing. cocolog's integers
%% are 61-bit, so `~0' is -1 and the count is taken from the type's WIDTH: 64 - popcount(\ -1) = 64 - 0.
cpp_builtin_call(N, [X], int(P)) :- cpp_popcount_name(N), cpp_popcount(X, P).
%% a member pointer applied to an object: the object's address first, the pointer called as the function it is
cpp_memptr_call(F, O, As, E) :-
    cpp_arg_type(F, FT), ccl_resolve_type(FT, memptr(C, _, fn(R, Ps, VQ))), cpp_memptr_object(O, C, P), cpp_fn_q(VQ, V, Qs), cpp_memptr_obj_ok(O, C, Qs),
    FnT = ptr([], fn(R, [param(ptr([], base([], [typedef(C)])), '$this')|Ps], V)),
    MT = memptr(C, [], fn(R, Ps, VQ)),
    ccl_gensym('$pm', M), ccl_gensym('$pf', Fn),
    ( ccl_memptr_arm -> Adj = bin('>>', member(id(M), adj), int(1)) ; Adj = member(id(M), adj) ),   % ARM's adj is twice the adjustment (0.161)
    P1 = cast(ptr([], base([], [typedef(C)])), bin('+', cast(ptr([], base([], [char])), P), Adj)),   % THE ADJUSTMENT (0.108): `this' moves by the pointer's `adj' before anything is read through it -- a member of a second base, reached through a pointer converted to the derived class's member pointer
    (   cpp_polymorphic(C), cpp_data_member(C, '$vptr', Hops)
    ->  PC = P1, cpp_access(PC, '$vptr', Hops, Vptr),          % the object's address AS THE MEMBER'S CLASS (a derived object's table pointer sits in that base sub-object; the lowering converts by the base's offset), read twice, never copied into a local the check would have to follow                                                  % THE VIRTUAL BIT ([expr.mptr.oper]; the ABI's representation, 0.100): an odd `ptr' is 1 + the slot's byte offset in the OBJECT'S table, an even one the function's address
        Bits = cast(base([], [long]), member(id(M), ptr)),
        (   ccl_memptr_arm -> Mark = bin('&', member(id(M), adj), int(1)), SlotOff = Bits   % ARM's (0.161): the mark adj's low bit, ptr the offset itself
        ;   Mark = bin('&', Bits, int(1)), SlotOff = bin('-', Bits, int(1)) ),
        Target = cond(Mark,
                      deref(cast(ptr([], ptr([], base([], [void]))), bin('+', cast(ptr([], base([], [char])), Vptr), SlotOff))),
                      member(id(M), ptr)),
        E = stmt_expr(block([declaration(0, none, MT, [var(M, MT, F)]),
                             declaration(0, none, FnT, [var(Fn, FnT, cast(FnT, Target))]), expr(0, call(id(Fn), [P1|As]))]))
    ;   E = stmt_expr(block([declaration(0, none, MT, [var(M, MT, F)]), expr(0, call(cast(FnT, member(id(M), ptr)), [P1|As]))])) ).
cpp_memptr_object(O, C, O) :- cpp_arg_type(O, OT), ccl_resolve_type(OT, ptr(_, PT)), ( cpp_class_of_type(PT, C) ; ccl_resolve_type(PT, base(_, [struct(C, _)])) ), !.   % a pointer to the object: `(p->*pm)(...)' -- to a PLAIN struct too (0.126)
cpp_memptr_object(O, _, addr(O)).
%% THE OBJECT OF A CALL THROUGH A POINTER TO MEMBER FUNCTION has the rights the member's qualifiers give ([expr.mptr.oper]/6,
%% [over.match.funcs]/5; 0.181): a const object takes only a const member, an lvalue no `&&' member and an rvalue no `&' member
%% -- from C++20 one whose qualifiers are `const' (P0704) -- else no call, which a detection reads (`is_invocable<int (A::*)(),
%% const A &>' held). An object whose type the inference cannot settle passes, as before.
cpp_memptr_obj_ok(O, C, Qs) :-
    (   catch(( cpp_arg_type(O, OT0), OT0 \== unknown, ccl_unref(OT0, OT1),
                (   ccl_resolve_type(OT1, ptr(_, OT)) -> Cat = lv
                ;   OT = OT1, ( cpp_arg_lvalue(O) -> Cat = lv ; Cat = rv ) ) ), _, fail)
    ->  (   cpp_type_const(OT), \+ memberchk(const, Qs) -> cpp_refuse(0, non_const_member_on_const(pointer_to_member, C))
        ;   Cat == lv, memberchk('&&', Qs) -> cpp_refuse(0, ref_qualified_member(pointer_to_member, C, '&&'))
        ;   Cat == rv, memberchk('&', Qs), \+ cpp_rvalue_takes_lref(Qs) -> cpp_refuse(0, ref_qualified_member(pointer_to_member, C, '&'))
        ;   true )
    ;   true ).
cpp_rvalue_takes_lref(Qs) :- ccl_std_at_least(20), memberchk(const, Qs), \+ memberchk(volatile, Qs).   % from C++20 a `const &' member, exactly const (P0704: `const volatile &' stays refused, as clang++ has it)
%% the object of `pm' in an invocation (0.126): an object of the member's class or of a class derived from it (its address), or a pointer to one (itself);
%% the result carries the object's `const' ([expr.ref]/6: `const Pt &' gives `const int &'), and anything else is no object
cpp_invoke_object(O, C, P, Const-Cat) :- cpp_arg_type(O, OT0), ccl_unref(OT0, OT),
    (   ccl_resolve_type(OT, ptr(_, PT)) -> cpp_record_of(PT, X), cpp_record_is(X, C), P = O, Cat = lv, ( cpp_type_const(PT) -> Const = const ; Const = none )
    ;   cpp_record_of(OT, X), cpp_record_is(X, C), P = addr(O), ( cpp_arg_lvalue(O) -> Cat = lv ; Cat = rv ), ( cpp_type_const(OT) -> Const = const ; Const = none ) ), !.
cpp_record_of(T, X) :- ( cpp_class_of_type(T, X) -> true ; ccl_resolve_type(T, base(_, [struct(X, _)])) ).
cpp_record_is(X, C) :- ( X == C -> true ; cpp_derives(X, C) ).
cpp_invoke_result(Const, Cat, deref(cast(ptr(Q, MT), A)), E) :- !,
    ( Const == const -> ccl_add_quals([const], MT, MT1) ; MT1 = MT ), E0 = deref(cast(ptr(Q, MT1), A)),
    ( Cat == rv -> E = cast(rref([], MT1), E0) ; E = E0 ).        % the member of an rvalue object is an xvalue, `int &&' ([expr.ref]/6)
cpp_invoke_result(_, _, E, E).
cpp_math_fn(F0, F, Ret, Ps) :-
    cpp_math_stem(F0, Stem, Sfx), cpp_math_shape(Stem, Arity, Kind),
    ( Sfx == f -> T = base([], [float]), F = F0 ; Sfx == l -> T = base([], [long, double]), F = F0 ; T = base([], [double]), F = F0 ),   % the l form is libm's own long double function (0.108: it went to the double one while a long double was lowered as a double)
    (   cpp_math_odd(Kind, T, Ret, Ps) -> true                                                           % the ones with an int or a pointer among their parameters (0.117)
    ;   ( Kind == same -> Ret = T ; Kind == long -> Ret = base([], [long]) ; Ret = base([], [long, long]) ),
        length(Ps, Arity), cpp_math_params(Ps, T) ).
cpp_math_stem(F0, Stem, Sfx) :- ( atom_concat(S1, f, F0), cpp_math_shape(S1, _, _) -> Stem = S1, Sfx = f ; atom_concat(S2, l, F0), cpp_math_shape(S2, _, _) -> Stem = S2, Sfx = l ; Stem = F0, Sfx = '' ), cpp_math_shape(Stem, _, _).
%% THE MATH BUILTINS WITH AN int OR A POINTER AMONG THEIR PARAMETERS (0.117; <complex>'s division calls `std::scalbn' and `std::logb' through
%% `__builtin_scalbn', which was `undeclared'): scalbn and ldexp take (T, int), frexp (T, int *), modf (T, T *), and ilogb answers an int
cpp_math_odd(int_arg, T, T, [param(T, anon), param(base([], [int]), anon)]).
cpp_math_odd(ptr_int, T, T, [param(T, anon), param(ptr([], base([], [int])), anon)]).
cpp_math_odd(ptr_same, T, T, [param(T, anon), param(ptr([], T), anon)]).
cpp_math_odd(int_ret, T, base([], [int]), [param(T, anon)]).
cpp_math_params([], _).
cpp_math_params([param(T, anon)|Ps], T) :- cpp_math_params(Ps, T).
cpp_math_shape(S, 1, same) :- memberchk(S, [ceil, floor, trunc, round, rint, nearbyint, sqrt, fabs, exp, exp2, expm1, log, log2, log10, log1p, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, asinh, acosh, atanh, cbrt, erf, erfc, lgamma, tgamma, logb]).
cpp_math_shape(S, 2, same) :- memberchk(S, [pow, fmod, atan2, hypot, fmax, fmin, fdim, copysign, nextafter, remainder]).
cpp_math_shape(fma, 3, same).
cpp_math_shape(S, 2, int_arg) :- memberchk(S, [scalbn, ldexp]).
cpp_math_shape(frexp, 2, ptr_int).
cpp_math_shape(modf, 2, ptr_same).
cpp_math_shape(ilogb, 1, int_ret).
cpp_math_shape(S, 1, long) :- memberchk(S, [lround, lrint]).
cpp_math_shape(S, 1, longlong) :- memberchk(S, [llround, llrint]).
cpp_math_declared(F, _, _) :- '$cpp_math_decl'(F), !.
cpp_math_declared(F, _, _) :- ccl_declared(F, _), !, assertz('$cpp_math_decl'(F)).   % a header declared it (the C math.h through <cmath>)
cpp_math_declared(F, Ret, Ps) :- assertz('$cpp_math_decl'(F)), cpp_isolated(ccl_declare(F, fn(Ret, Ps, false))),
    cpp_as_lib(yes, cpp_add_instance_items([function(0, extern, Ret, F, Ps, false, none)])).
cpp_wide_fn(wmemchr, ptr([], base([], [wchar_t])), [param(ptr([], base([const], [wchar_t])), s), param(base([], [wchar_t]), c), param(base([], [unsigned, long]), n)]).
cpp_wide_fn(wmemcmp, base([], [int]), [param(ptr([], base([const], [wchar_t])), a), param(ptr([], base([const], [wchar_t])), b), param(base([], [unsigned, long]), n)]).
cpp_wide_fn(wcslen, base([], [unsigned, long]), [param(ptr([], base([const], [wchar_t])), s)]).
cpp_popcount_name('__builtin_popcountg').
cpp_popcount_name('__builtin_popcount').
cpp_popcount_name('__builtin_popcountl').
cpp_popcount_name('__builtin_popcountll').
cpp_popcount(X, P) :- ccl_const_eval(X, V),
    ( ccl_type_of(X, T), T \== unknown, ccl_size_of(T, S), S > 0 -> W is S * 8 ; W = 64 ),
    ccl_w_wrap(V, W, false, U), ccl_wide(U, w(_, Ls)), cpp_limb_bits(Ls, 0, P).   % over the value WRAPPED TO THE TYPE'S WIDTH, unsigned (0.94): `(unsigned long) ~(unsigned long) 0' is 2^64-1 now, a `big' the old `V >= 0' could not take, and the bits are counted limb by limb
cpp_limb_bits([], P, P).
cpp_limb_bits([L|Ls], P0, P) :- cpp_bits(L, P0, P1), cpp_limb_bits(Ls, P1, P).
cpp_bits(0, P, P) :- !.
cpp_bits(V, P0, P) :- P1 is P0 + (V /\ 1), V1 is V >> 1, cpp_bits(V1, P1, P).
%% A SCALAR HAS NO MEMBER (0.127): an arithmetic value, an enum's, a pointer or an array named through `.', and through `->' a pointer to
%% one of them (or a scalar that is no pointer). Refused where the walk meets it, which is the immediate context of a `decltype' (SFINAE);
%% it reached the lowering, which refused the body that a detection should have passed over
cpp_scalar_object(XT) :- XT \== unknown, ccl_resolve_type(XT, R), ( R = ptr(_, _) ; R = arr(_, _) ; R = base(_, S), S \== [], \+ ( member(Sp, S), compound(Sp), \+ ( Sp = enum(_, _) ; Sp = enum_class(_, _) ) ), ccl_is_arith(R) ), !.
cpp_scalar_arrow(X, XT) :- ccl_type_of(X, XT0), XT0 \== unknown, ccl_unref(XT0, XT), ccl_resolve_type(XT, R),
    ( R = ptr(_, PT) -> ccl_unref(PT, PT1), cpp_scalar_object(PT1), \+ ccl_resolve_type(PT1, ptr(_, _)) ; R \= ptr(_, _), R \= arr(_, _), cpp_scalar_object(R) ), !.
cpp_hops_class(C, [], C).
cpp_hops_class(C, [H|Hs], B) :- cpp_class_l(C, cls(B0, _, _, _, _)),
    (   H == '$base', B0 \== none, \+ cpp_empty_class(B0) -> cpp_hops_class(B0, Hs, B)
    ;   '$cpp_base_slot'(C, B1, H) -> cpp_hops_class(B1, Hs, B)
    ;   B0 \== none, cpp_empty_class(B0) -> cpp_hops_class(B0, [H|Hs], B) ).
%% A DISPATCH TAKES ITS ARGUMENTS THROUGH THE PASSES A DIRECT CALL DOES (0.112), read off the method chosen, whose
%% slot is called: the conversion operator, a null pointer constant and a template's name (cpp_ref_args_of), the
%% copy and the converting constructor (cpp_copies, which the call wrapper runs only on a call by name). A virtual
%% call took its arguments RAW: libc++'s `basic_stringbuf::seekpos' writes `this->seekoff(__sp, ...)' and handed an
%% fpos to an `off_type' (LLVM refused the sext of a struct; std::quoted over an istringstream), and a class taken by
%% value went bitwise to a callee that destroys it. A bare call inside a class missed the first pass too.
cpp_dispatch(Name, P, C, Slot, As, E) :- cpp_ref_args_of(Name, As, As1), cpp_dispatch_copied(Name, P, C, Slot, As1, E).
cpp_dispatch_copied(Name, P, C, Slot, As1, E) :- cpp_copies(call(id(Name), [P|As1]), call(_, [_|As2])), cpp_dispatch(P, C, Slot, As2, E).
%% p->$vptr->slot(p, args), the pointer to the table found through the base sub-objects
%% A DISPATCH READS THE OBJECT'S OWN CLASS'S TABLE: the pointer member is typed by the class that INTRODUCED the
%% table (`__shared_count.vt' under every libc++ facet), whose struct has that class's slots and none of the ones
%% a derived class adds -- ctype<char>::widen dispatching `do_widen' found no such member. The tables are laid out
%% base first, so the derived class's table struct extends the owner's, and the pointer is cast to it; its tag is
%% noted here where the walk meets it first, before the class's items are.
cpp_dispatch(P, C, Slot, As, call(arrow(cast(ptr([], base([], [struct(VT, none)])), Vptr), Slot), [P|As])) :-
    cpp_data_member(C, '$vptr', Hops), cpp_access(P, '$vptr', Hops, Vptr), cpp_vt_tag(C, VT),
    (   ccl_tag(VT, _) -> true
    ;   cpp_class_l(C, cls(_, _, _, _, Slots)), cpp_vt_struct(0, C, Slots, declare(_, base(_, [struct(VT, VMs)]))), ccl_note_tag(VT, VMs) ).
%% a value whose dynamic type is its static one: a named object, or a member of one; not a reference
cpp_static_object(id(N)) :- ccl_declared(N, T), \+ T = ref(_, _), \+ T = rref(_, _).
cpp_static_object(member(X, _)) :- cpp_static_object(X).
%% A METHOD THAT ANOTHER PATH OVERRIDES ([class.member.lookup]/6: the override in a class derived from the base dominates it): a call on a
%% named object of a class over a shared virtual base -- `z.f()' with `Z : X1, X2' where X2 overrides I's f -- is the final overrider's
%% (0.174), where the lookup down the first base found I's
cpp_dominated(C, M, Name) :- \+ memberchk(M, ['$dtor', '$dtor_del']), cpp_class_l(C, cls(_, _, _, _, Slots)), member(slot(M, K, _, _, _), Slots),
    cpp_slot_impl(C, M, K, Name), cpp_final_impl(C, M, K, IE, _), IE \== Name, !.
%% THE COPY DEDUCTION CANDIDATE ([over.match.class.deduct]/1.3; 0.112): `template <P...> C(C<P...>) -> C<P...>', so ONE
%% initializer that is a value of an instance of the template deduces that instance's arguments, before any guide:
%% `__format::__parse_number_result __r = __format::__parse_arg_id(...)' (`ctadcopy.cpp')
%% THE DEDUCED SPECIALIZATION SATISFIES ITS TEMPLATE'S CONSTRAINTS ([temp.names]/8; 0.132): `owning_view{c}' of a
%% `char' deduces `owning_view<char>' through its constructor, and `template <range _Rp> requires movable<_Rp> class
%% owning_view' does not take a char -- unchecked, libc++'s `views::all' held for a char through its third overload, so
%% `views::all_t<char>' named a type and views::split(s, ' ') took the guide over `views::all_t<_Pattern>'. The refusal
%% is the deduction's: a requirement that makes it is unmet, any other use an error, as C++ has it
cpp_ctad_args(N, As, Args) :- cpp_ctad_caller(cpp_ctad_args_(N, As, Args)), cpp_ctad_satisfied(N, Args).
%% THE ARGUMENTS OF A DEDUCTION ARE THE CALLER'S (0.201): an argument that only the desugaring can type -- a data member named
%% bare in a member function, `shared_lock __lock{__mutex_};' in libc++'s <syncstream> -- is desugared in the words of the
%% class being walked, as a candidate's arguments are (cpp_as_callee/2, cpp_caller_ctx/2); typed with no class, it was
%% `unknown', the guides deduced nothing, `Lk lock{m_};' named the bare template, and every `std::osyncstream' was refused
cpp_ctad_caller(G) :- ccl_global('$cpp_caller', Old, none),
    ( Old == none -> nb_getval('$cpp_class_ctx', Cl), nb_setval('$cpp_caller', caller(Cl)) ; true ),
    ( catch(G, E, ( nb_setval('$cpp_caller', Old), throw(E) )) -> nb_setval('$cpp_caller', Old) ; nb_setval('$cpp_caller', Old), fail ).
%% A BRACED INITIALIZER DEDUCES THROUGH THE INITIALIZER-LIST CONSTRUCTORS FIRST ([over.match.class.deduct]/1, [over.match.list];
%% 0.201): the list as one argument, which only an `initializer_list<P>' parameter deduces from, each item a P -- `std::vector
%% v{1, 2, 3};' is a vector<int>, where its items were three arguments and no constructor deduced the element -- then the items
%% as the arguments; a list of one item of the template's own class, or a class derived from one, is its copy (P0702: `std::vector
%% w{v};' is v's type), and a designated list goes to the items as before
cpp_ctad_init(TN, init(Items), As, Args) :- Items = [_|_], \+ cpp_designated_items(Items), \+ cpp_ctad_copy_item(TN, As), cpp_ctad_args(TN, [init(Items)], Args), \+ cpp_ctad_unknown(Args), !.   % a list deduces no other parameter ([temp.deduct.call]/1): `std::tuple t{1, 'c', 3.5};' is no tuple of one unknown
cpp_ctad_init(TN, _, As, Args) :- cpp_ctad_args(TN, As, Args).
cpp_ctad_copy_item(TN, [A]) :- catch(cpp_init_arg_class(A, IC), error(not_lowered(_), _), fail), cpp_ctad_of_template(TN, IC), !.
cpp_ctad_of_template(TN, C) :- '$cpp_inst'(C, inst(TN, _)), !.
cpp_ctad_of_template(TN, C) :- cpp_base_scope(C, B), cpp_ctad_of_template(TN, B), !.
cpp_ctad_unknown(unknown) :- !.
cpp_ctad_unknown(T) :- compound(T), T =.. [_|As], member(A, As), cpp_ctad_unknown(A), !.
cpp_ctad_args_(N, [], Args) :- !, atom(N), catch(cpp_class_template(N, TPs, Item), _, fail), cpp_template_class_def(Item), TPs \== [],   % NO ARGUMENT DEDUCES THE TEMPLATE'S DEFAULTS ([over.match.class.deduct]: the default constructor's guide; 0.201): `less{}' in libc++'s parallel algorithms is less<void>, where it was the bare template and no call took it
    \+ ( member(tparam(K, _, D), TPs), K \== pack, D == none ), catch(cpp_bind_targs(TPs, [], B), error(not_lowered(_), _), fail), cpp_ctad_bind(TPs, B, Args), Args \== [], !.
cpp_ctad_args_(N, [A], Args) :- atom(N), catch(cpp_init_arg_class(A, IC), error(not_lowered(_), _), fail), '$cpp_inst'(IC, inst(N, Args)), !.
cpp_ctad_args_(N, As, Args) :- atom(N), atom_concat('$guide.', N, G),   % THE WRITTEN DEDUCTION GUIDES FIRST ([over.match.class.deduct]; 0.108): libc++'s pair has template constructors only, and `std::pair{a, b}' deduces through `pair(_T1, _T2) -> pair<_T1, _T2>'
    findall(TPs-Ps-RT, catch(cpp_template(G, TPs, deduction_guide(_, _, Ps, RT)), _, fail), Gs),
    (   member(TPs-Ps-RT, Gs), cpp_ctad_guide_args(N, TPs, Ps, RT, As, Args), catch(cpp_types(Args, _), error(not_lowered(_), _), fail)   % A GUIDE WHOSE RESULT DOES NOT SUBSTITUTE IS NO CANDIDATE (0.132; the guide is a function template whose result is part of its signature): `split_view(_Range &&, _Pattern &&) -> split_view<views::all_t<_Range>, views::all_t<_Pattern>>' with `_Pattern = char' names `views::all_t<char>', which has no type, and the guide over `range_value_t<_Range>' is the one views::split(s, ' ') takes
    ->  true
    ;   member(TPs-Ps-RT, Gs), cpp_ctad_guide_args(N, TPs, Ps, RT, As, Args) ), cpp_trace(ctad_guide(N, Args)), !.   % ... else the first that deduces, as before
cpp_ctad_args_(N, As, Args) :-
    catch(cpp_class_template(N, TPs, Item), _, fail), cpp_template_class_def(Item), Item = declare(_, base(_, [Spec])), ( Spec = class(_, _, _, Ms) ; Spec = struct(_, Ms) ), Ms \== none,   % a plain struct template reads as `struct(N, Ms)'
    cpp_guide_params(Ms, Ps00), cpp_guide_member_types(Ms, Ps00, Ps0), cpp_ctad_self(N, TPs, Ps0, Ps), catch(cpp_signature_holds(N, TPs, Ps, [], As, B), error(not_lowered(_), _), fail),
    cpp_ctad_bind(TPs, B, Args), Args \== [], cpp_trace(ctad(N, Args)), !.
%% AN IMPLICIT GUIDE'S PARAMETER THAT NAMES A MEMBER TYPEDEF OF THE TEMPLATE is the typedef's type ([over.match.class.deduct]/1:
%% the guide is the constructor in the class template's own terms; 0.201): `explicit lock_guard(mutex_type &)' over `typedef
%% _Mutex mutex_type;' deduces `_Mutex' from a mutex -- C++17's `std::lock_guard g(m);', `std::unique_lock u(m);' and
%% `std::shared_lock s(sm);' named the bare template, a `no_member' at its first use or a lock that locked nothing
cpp_guide_member_types(Ms, Ps0, Ps) :- findall(A-T, ( member(typedef(_, Vs), Ms), member(var(A, T, _), Vs), atom(A) ), Map), Map \== [], !, cpp_guide_subst(4, Map, Ps0, Ps).
cpp_guide_member_types(_, Ps, Ps).
cpp_guide_subst(0, _, Ps, Ps) :- !.
cpp_guide_subst(K, Map, Ps0, Ps) :- cpp_subst(Ps0, Map, Ps1), ( Ps1 == Ps0 -> Ps = Ps0 ; K1 is K - 1, cpp_guide_subst(K1, Map, Ps1, Ps) ).
cpp_ctad_guide_args(N, TPs, Ps, RT, As, Args) :- catch(cpp_signature_holds(N, TPs, Ps, [], As, B), error(not_lowered(_), _), fail),
    RT = base(_, [typedef(tmpl(_, RArgs))]), cpp_subst(RArgs, B, Args), Args \== [].
cpp_ctad_satisfied(N, Args) :-
    (   catch(cpp_class_template(N, TPs, _), error(not_lowered(_), _), fail), memberchk(requires(_), TPs), catch(cpp_bind_targs(TPs, Args, B), error(not_lowered(_), _), fail)
    ->  cpp_constraints_hold(N, TPs, B)
    ;   true ).
%% THE INJECTED CLASS NAME IN A CONSTRUCTOR TAKEN AS A GUIDE is the class over its own parameters ([temp.local]/1;
%% 0.112): libc++ 18's `basic_format_context(_OutIt, basic_format_args<basic_format_context>, ...)' deduces `_CharT'
%% only from `basic_format_args<basic_format_context<_OutIt, _CharT>>', and `std::basic_format_context(...)' reached
%% the lowering as the bare template (`ctadself.cpp')
cpp_ctad_self(N, TPs, Ps0, Ps) :- findall(A, ( member(tparam(K, P, _), TPs), cpp_ctad_self_arg(K, P, A) ), SArgs), SArgs \== [], !,
    cpp_subst(Ps0, [N-base([], [typedef(tmpl(N, SArgs))])], Ps).
cpp_ctad_self(_, _, Ps, Ps).
cpp_ctad_self_arg(type, P, base([], [typedef(P)])) :- !.
cpp_ctad_self_arg(pack, P, pack(base([], [typedef(P)]))) :- !.
cpp_ctad_self_arg(template, P, tname(P)) :- !.
cpp_ctad_self_arg(vpack(_), P, pack(id(P))) :- !.
cpp_ctad_self_arg(_, P, id(P)).
cpp_guide_params(Ms, Ps) :- member(ctor(_, _, Ps, _, _), Ms), Ps \== [].                          % a constructor's parameters are the guide's
cpp_guide_params(Ms, Ps) :- \+ memberchk(ctor(_, _, _, _, _), Ms), findall(param(T, A), member(member(T, A, _), Ms), Ps), Ps \== [].   % an AGGREGATE: its members, in order
cpp_ctad_bind([], _, []).
cpp_ctad_bind([requires(_)|TPs], B, Args) :- !, cpp_ctad_bind(TPs, B, Args).
cpp_ctad_bind([ttp(_, _)|TPs], B, Args) :- !, cpp_ctad_bind(TPs, B, Args).
cpp_ctad_bind([tparam(pack, P, _)|TPs], B, Args) :- memberchk(P-pack(L), B), is_list(L), !, cpp_ctad_bind(TPs, B, Args0), append(L, Args0, Args).   % A PACK's elements are the arguments (0.201): `std::scoped_lock both(m, sm);' is scoped_lock<mutex, shared_mutex>, where the instance took the pack whole
cpp_ctad_bind([tparam(_, P, D)|TPs], B, [A|Args]) :- ( memberchk(P-A0, B) -> A = A0 ; D \== none, cpp_subst(D, B, A) ), cpp_ctad_bind(TPs, B, Args).
%% every argument a type or a constant: an expression that did not fold would name an instance by its spelling
cpp_targs_settled([]).
cpp_targs_settled([A|As]) :- ( cpp_is_type(A) -> true ; cpp_settled_value(A) -> true ; A = tname(_) ), cpp_targs_settled(As).
%% a value argument that names its instance: a literal of any integral kind or a bool, a typed value's cast (0.199: `S<5u>'
%% was `uint(5)' no longer turned into an int, and `S<5u>{}' over `template <auto N>' reached the lowering as the template-id)
cpp_settled_value(A) :- compound(A), functor(A, F, 1), memberchk(F, [int, uint, long, ulong, chr, wchr, u16chr, u32chr, bool]), !.
cpp_settled_value(cast(base(_, _), X)) :- cpp_settled_value(X).
cpp_settled_value(id(F)) :- atom(F), cpp_nttp_fn_name(F), !.   % A FUNCTION'S NAME OR ADDRESS names its instance too (0.206): `NF<is_odd>()', libc++ 21's
cpp_settled_value(addr(id(F))) :- atom(F), cpp_nttp_fn_name(F), !.   % `__nttp_not_fn_t<_Fn>()', is a temporary of the instance, where it was refused `expr(tmpl(...))'
%% a name the program declares as a function (0.206)
cpp_nttp_fn_name(F) :- catch(ccl_type_of(id(F), T), _, fail), nonvar(T), T = fn(_, _, _).
%% A TYPE'S NAME CALLED: a temporary of the class it names, an aggregate of the items, the cast it looks like, or
%% its zero -- written once for the three names a type has here (a class-scope typedef, a file-scope one, and an
%% ALIAS TEMPLATE's template-id, `__make_unsigned_t<type>(0)', which libc++ takes a type's digits through)
cpp_type_call(T, As, E) :-
    (   cpp_class_of_type(T, C1)
    ->  ( cpp_has_ctors(C1) -> cpp_temporary(T, C1, As, E) ; findall(item([], A), member(A, As), Items), E = compound_lit(T, init(Items)) )
    ;   As == [], cpp_record_type(T) -> E = compound_lit(T, init([]))                                  % VALUE-INITIALIZATION OF A PLAIN STRUCT OR UNION is every byte zero (0.122): libc++ 21's `__rep_ = __rep();' over `union __rep { __short __s; __long __l; }' was the scalar zero, an int stored into a union
    ;   As = [_|_], cpp_record_type(T), \+ ( As = [X0], cpp_record_own_value(X0, T) )   % A PLAIN STRUCT OR UNION NAMED THROUGH A TYPEDEF AND GIVEN ITEMS IS ITS AGGREGATE (0.161; [dcl.init.list]/3.4, C++20's parenthesized form): `T{k}' with `typedef S T;'
    ->  findall(item([], A), member(A, As), Items), E = compound_lit(T, init(Items))                    % was a cast of k to the struct, which LLVM refused (`sext i32 to %struct.S'); the struct's own name took the tag's road (cpp_tag_takes)
    ;   As = [X] -> E = cast(T, X)
    ;   As == [] -> cpp_zero_of(T, Z), ( ccl_nullptr_type(T) -> E = Z ; ccl_resolve_type(T, RT) -> E = cast(RT, Z) ; E = cast(T, Z) )   % THE ZERO OF ITS TYPE (0.221; [expr.type.conv]/2): `std::uint8_t{}' was the int 0, so libc++ 21's `__impl(uint8_t{})' deduced `_MaskT := int' and `std::__countr_zero<int>' failed its static assertion -- the type RESOLVED, as a deduction takes it: cast to `ptrdiff_t' as written, the pstl's `_DiffT()' made `optional<ptrdiff_t>' beside `optional<long>', two instances of one type
    ;   fail ).
%% A TAG'S OR A CLASS'S NAME CALLED WITH MORE ARGUMENTS THAN IT CAN TAKE IS NO TEMPORARY: namespaces flatten to
%% bare names here, and libc++ has both `_Algorithm::__fill_n', an EMPTY tag struct used as a template argument,
%% and `std::__fill_n(first, n, value)' -- so the call built an aggregate of three items for a type with no
%% members. An empty tag takes a cast or nothing, an enum a cast, an aggregate at most one item per member; a
%% class with constructors chooses among them as before.
%% one value of the record type T itself, its top-level qualifiers aside: the inference's type, else the desugaring's
cpp_record_own_value(X, T) :- ( catch(ccl_type_of(X, XT0), _, fail), XT0 \== unknown -> true ; catch(cpp_arg_type(X, XT0), _, fail), XT0 \== unknown ),
    ccl_unref(XT0, XT1), ( XT1 = base(_, S) -> cpp_same_type(base([], S), T) ; cpp_same_type(XT1, T) ), !.
cpp_tag_takes(Ms, As) :- ( Ms == [] -> ( As == [] -> true ; As = [_] ) ; ccl_is_enum_tag(Ms) -> ( As == [] -> true ; As = [_] ) ; length(As, K), length(Ms, N), K =< N ).
cpp_class_takes(C, As) :- cpp_class(C, cls(_, Data, Ms, _, _, _)),
    (   memberchk(ctor(_, _, _, _, _), Ms) -> true
    ;   '$cpp_mt'(C, ctor, _, _) -> true                                % only a constructor TEMPLATE, which libc++'s __bind is built on: `typedef __bind<_Fp, _BoundArgs...> type; return type(f, args...)' took more arguments than the class has members and was left as a call to the class's name
    ;   length(As, K), length(Data, N0), ( cpp_aggregate_class(C), cpp_direct_bases(C, Bs) -> findall(B, ( member(B, Bs), cpp_empty_class(B) ), Es), length(Es, NE) ; NE = 0 ), N is N0 + NE, K =< N ).   % an aggregate's empty bases take an item each (0.121)
cpp_this_form(deref(this), deref(id(this))) :- !.
cpp_this_form(X, X).
cpp_operand_class(Ctx, deref(id(this)), D) :- atom(Ctx), Ctx \== none, !, D = Ctx.
cpp_operand_class(_, X, D) :- catch(cpp_class_of_type_of(X, D), _, fail).
cpp_base_operator_call(X, C, Hops0, As, E) :-
    cpp_hops(X, Hops0, B0), length(As, N), cpp_method_on(B0, C, operator('()'), As, Name, Hops), cpp_hops(B0, Hops, B),
    cpp_fill_defaults(Name, As, As1), cpp_ref_args_of(Name, As1, As2),
    (   cpp_slot_call(C, operator('()'), N, Name, Slot), \+ cpp_static_object(X) -> cpp_dispatch_copied(Name, addr(B), C, Slot, As2, E)
    ;   cpp_object_arg(Name, addr(B), Obj), E = call(id(Name), [Obj|As2]) ).
%% a scalar parameter given a PLAIN struct or union, which converts to nothing (0.127)
cpp_scalar_param_plain_arg(PT0, A) :- cpp_param_ref(PT0, PT), \+ cpp_class_of_type(PT, _), ccl_resolve_type(PT, RT), ( ccl_is_arith(RT) ; RT = ptr(_, _) ),
    cpp_arg_type(A, AT), AT \== unknown, ccl_unref(AT, AT1), cpp_plain_record(AT1), !.
cpp_plain_record(T) :- \+ cpp_class_of_type(T, _), ccl_resolve_type(T, base(_, [S])), compound(S), ( S = struct(_, _) ; S = union(_, _) ), !.
cpp_callee_mismatch([P|Ps], [A|As]) :- ( ( P = param(PT0, _) ; P = param(PT0, _, _) ), cpp_scalar_param_plain_arg(PT0, A) -> true ; cpp_callee_mismatch(Ps, As) ).
%% A TEMPORARY'S operator(), `__destroy_vector(*this)()', which is how libc++'s vector destroys itself: the callee
%% is no function but an object, and the call goes INSIDE the block that built it, where that object has an address.
cpp_temp_call(stmt_expr(block(Ss)), As, stmt_expr(block(Ss1))) :- !,
    cpp_class_of_type_of(stmt_expr(block(Ss)), C), cpp_method(C, operator('()'), As, Name, Hops),
    append(Pre, [expr(L, Last)], Ss), cpp_hops(Last, Hops, B), cpp_object_arg(Name, addr(B), Obj),
    cpp_fill_defaults(Name, As, As1), cpp_ref_args_of(Name, As1, As2), cpp_copies(call(id(Name), [Obj|As2]), Call),   % THE COPY PASS ON A TEMPORARY CALLEE'S CALL TOO (0.121): `std::hash<std::string>{}("hello")' handed the literal's address to a `const string &'
    append(Pre, [expr(L, Call)], Ss1).
%% `_Algorithm()(a, b, c)': an AGGREGATE temporary -- a class with no constructor, libc++'s algorithm dispatch
%% tags are such -- is a compound literal with no block of its own, so it gets one: declared, then its operator()
%% over its address, the block's value the call's. A `auto __result = ...' of it had no type at all.
cpp_temp_call(compound_lit(T, init(Items)), As, stmt_expr(block([declaration(0, none, T, [var(Tmp, T, init(Items))]), expr(0, Call)]))) :-
    cpp_class_of_type(T, C), cpp_method(C, operator('()'), As, Name, Hops), !,
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), cpp_hops(id(Tmp), Hops, B), cpp_object_arg(Name, addr(B), Obj),
    cpp_fill_defaults(Name, As, As1), cpp_ref_args_of(Name, As1, As2), cpp_copies(call(id(Name), [Obj|As2]), Call).
cpp_temp_call(X, As, stmt_expr(block(Ss))) :- X = call(id(F), _), atom(F), ccl_declared(F, fn(R, _, _)), \+ R = ref(_, _), \+ R = rref(_, _), cpp_class_of_type(R, C), cpp_method(C, operator('()'), As, Name, Hops), !,   % A CALL RETURNING A CLASS BY VALUE, CALLED: `g.key_comp()(3, 1)' -- the prvalue materialized in a temporary of the statement (destroyed with it where the class has a destructor), then its operator()
    cpp_type(R, T), ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T),
    (   cpp_dtor(C, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts) -> nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts]), First = expr(0, assign('=', id(Tmp), X))
    ;   First = declaration(0, none, T, [var(Tmp, T, X)]) ),
    cpp_hops(id(Tmp), Hops, B), cpp_object_arg(Name, addr(B), Obj), cpp_fill_defaults(Name, As, As1), cpp_ref_args_of(Name, As1, As2), cpp_copies(call(id(Name), [Obj|As2]), Call), Ss = [First, expr(0, Call)].
cpp_temp_call(X, As, E) :- cpp_addressable(X),                                                 % `(*p)(a)', `fs[i](a)' of an object: its own address, no temporary
    cpp_class_of_type_of(X, C), length(As, N), cpp_method_on(X, C, operator('()'), As, Name, Hops),
    cpp_hops(X, Hops, B),
    cpp_fill_defaults(Name, As, As1), cpp_ref_args_of(Name, As1, As2),
    (   cpp_slot_call(C, operator('()'), N, Name, Slot), \+ cpp_static_object(X)                % ... AND A VIRTUAL operator() DISPATCHES, as a named method already did: std::function calls the callable it holds
    ->  cpp_dispatch_copied(Name, addr(B), C, Slot, As2, E)                                     % through `(*__f_)(std::forward<_ArgTypes>(__args)...)', whose __base::operator() is PURE -- called directly, the link named it
    ;   cpp_object_arg(Name, addr(B), Obj), cpp_copies(call(id(Name), [Obj|As2]), E) ).
cpp_addressable(deref(_)).
cpp_addressable(index(_, _)).
cpp_addressable(call(id(F), _)) :- atom(F), ccl_declared(F, fn(R, _, _)), ( R = ref(_, _) ; R = rref(_, _) ), !.   % a call whose result is a REFERENCE names an object: `std::declval<_WithoutKey>()(args...)', the type libc++'s __try_key_extraction returns
%% a temporary of the class: constructed in a statement expression, its value the last expression
cpp_temporary(T, C, [A], E1) :- cpp_class_of_type_of(A, D), D \== C, \+ cpp_converting_ctor(C, A), cpp_conv_to(A, T, E1), E1 \== A, !.   % `__self_view(__str)': the class has no constructor taking the argument, and the argument's class CONVERTS to it -- the operator's result is the temporary ([over.match.copy])
cpp_temporary(T, C, As, stmt_expr(block(Ss))) :- cpp_not_abstract(C), cpp_aggregate_class(C), As \== [],   % AN AGGREGATE WHOSE MEMBER CONSTRUCTS is built member by member (cpp_aggregate_inits, 0.41's road for a local): the tree's `_InsertReturnType{end(), false, _NodeHandle()}' put a `__tree_iterator' into a `__tree_const_iterator' member bitwise, where its converting constructor was meant
    cpp_class_l(C, cls(_, Data, _, _, _)), member(member(MT, _, _), Data), cpp_class_of_type(MT, MC), cpp_has_ctors(MC), !,
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), cpp_aggregate_inits(Data, As, id(Tmp), 0, Inits),
    (   cpp_dtor(C, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts) -> nb_getval('$cpp_temps', Ts1), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts1]), Ss0 = Inits   % declared by the statement, destroyed with it (or elided into a result)
    ;   Ss0 = [declaration(0, none, T, [var(Tmp, T, none)])|Inits] ),
    append(Ss0, [expr(0, id(Tmp))], Ss).
cpp_temporary(T, C, As, compound_lit(T, init(Items))) :- cpp_not_abstract(C), cpp_aggregate_class(C), As \== [], !, findall(item([], A), member(A, As), Items0), cpp_agg_skip_bases(C, Items0, Items).   % an AGGREGATE, `__allocation_result{p, n}': braced, no constructor; its empty bases' items dropped (0.121)
cpp_temporary(T, C, [], compound_lit(T, init([]))) :- cpp_not_abstract(C), cpp_trivial_default(C), !.   % `__less<>()': nothing to construct, as a member and a local already had it
%% A TEMPORARY OF A CLASS WITH A DESTRUCTOR is declared by the STATEMENT that holds it, never here: its slot and
%% its defer belong to the full expression's scope (cpp_stmt), and only the construction stays in place, where the
%% evaluation order puts it. Outside a statement walk ('$cpp_temps' unset) it is declared here as it always was.
cpp_temporary(T, C, As, stmt_expr(block([expr(0, Call), expr(0, id(Tmp))]))) :-
    cpp_not_abstract(C), cpp_dtor(C, Dtor), ccl_global('$cpp_temps', Ts, none), is_list(Ts), !,
    length(As, N), ( cpp_ctor(C, As, Name) -> true ; cpp_refuse(0, no_constructor(C, N)) ), cpp_fill_defaults(Name, As, As0), cpp_ref_args_of(Name, As0, As1),
    cpp_copies(call(id(Name), [addr(id(Tmp))|As1]), Call0), cpp_ce_check(Name, T, Call0), cpp_temp_zeroed(C, As, T, Tmp, Call0, Call),   % THE COPY PASS ON A TEMPORARY'S CONSTRUCTOR CALL TOO: `pair<const string, int>("a", 1)' takes `pair(const T1 &, const T2 &)', and the literal went raw into the `const string &' -- the map's keys were the pointer's bytes
    ccl_gensym('$tmp', Tmp), ccl_declare(Tmp, T), nb_getval('$cpp_temps', Ts1), nb_setval('$cpp_temps', [tmp(Tmp, T, Dtor)|Ts1]).   % the register READ AGAIN here: the copy pass above may have registered a temporary of its own (a string for a `const string &' parameter), and the list read at the head would have dropped it (undeclared('$tmp_8')); DECLARED here as well as by the statement that holds it: its block no longer carries the declaration, so nothing else could type the value the block yields
cpp_temporary(T, C, As, stmt_expr(block([declaration(0, none, T, [var(Tmp, T, none)]), expr(0, Call), expr(0, id(Tmp))]))) :-
    cpp_not_abstract(C), length(As, N), ( cpp_ctor(C, As, Name) -> true ; cpp_refuse(0, no_constructor(C, N)) ), cpp_fill_defaults(Name, As, As0), cpp_ref_args_of(Name, As0, As1), ccl_gensym('$tmp', Tmp),
    cpp_copies(call(id(Name), [addr(id(Tmp))|As1]), Call0), cpp_ce_check(Name, T, Call0), cpp_temp_zeroed(C, As, T, Tmp, Call0, Call).
%% `R()' VALUE-INITIALIZES (0.127): with no argument, a class whose default constructor is not user-provided is zeroed before it runs
cpp_temp_zeroed(C, [], T, Tmp, Call0, comma(Zero, Call0)) :- cpp_value_zeroes(C), !,
    ( cpp_zero_not_null(T, id(Tmp), expr(_, Null)) -> Zero = Null ; Zero = call(id(memset), [addr(id(Tmp)), int(0), sizeof_type(T)]) ).   % a pointer to a data member's zero is -1 (0.161)
cpp_temp_zeroed(_, _, _, _, Call, Call).
%% A LIBRARY CLASS'S CONSTEVAL CONSTRUCTOR IS RUN AT COMPILE TIME where its object is made ([dcl.constexpr]/13,
%% [expr.const]; 0.164; dropped since 0.110): the check twin runs in the evaluator over a cell of the class's zero and the
%% constructor call's own arguments, std::is_constant_evaluated() true. A call of a library throw helper met on the way --
%% `__throw_format_error', `__throw_invalid_type_format_error' -- is the call that makes the expression no constant one:
%% the program is refused by name, the library's message in the refusal, as clang++ refuses it (`std::format("{} {}", 1)'
%% is `consteval_call_not_constant(basic_format_string.char.int, 'Argument index outside the valid range')'). A form the
%% evaluator cannot take leaves the check to the library's own parser at run time, as before (`consteval_ctor_unevaluated').
cpp_ce_check(Name, T, call(_, [_|As])) :- '$cpp_cecheck'(Name, Twin, C), !,
    nb_setval('$cpp_eval_abort', none), nb_setval('$cpp_eval_ce', on),
    (   catch(cpp_eval_construct(T, Twin, As, _), _, fail) -> nb_setval('$cpp_eval_ce', off), cpp_trace(consteval_ctor_checked(C))
    ;   nb_setval('$cpp_eval_ce', off), nb_current('$cpp_eval_abort', abort(Msg))
    ->  ( nb_current('$cpp_line', L) -> true ; L = 0 ), cpp_refuse(L, consteval_call_not_constant(C, Msg))   % at the statement's line, as clang++ names it
    ;   cpp_trace(consteval_ctor_unevaluated(C)) ).
cpp_ce_check(_, _, _).
%% an operator on a class-typed left operand: the class's member operator, else a free one declared, else the form as it is
cpp_operator(Op, A, Args, Plain, E) :-
    (   cpp_class_of_type_of(A, C), cpp_method_on(A, C, operator(Op), Args, Name, Hops)
    ->  (   \+ cpp_member_exact(Name, Args), cpp_free_operator_call(Op, A, Args, E0), cpp_prefer_free(E0, Name, Args) -> E = E0
        ;   cpp_body_ctx(BC), cpp_check_access(BC, C, operator(Op)), fail   % AN OPERATOR USED AS ONE is a member named (0.127): its access asked from the body being walked   % ... and a member that takes the arguments by PROMOTIONS beats a free one that needs a conversion (0.127): `std::cout << c' of an enum is the member `operator<<(int)', never the free `char' template, which printed the byte; C++ weighs the members and the free ones TOGETHER: a free operator that fits EXACTLY beats a member that needs a conversion -- `cout << "hello"' is the free template over `const _CharT *', never the member over `const void *'
        ;   cpp_hops(A, Hops, B), cpp_fill_defaults(Name, Args, Args0), cpp_ref_args_of(Name, Args0, Args1), cpp_object_arg(Name, addr(B), Obj), cpp_copies(call(id(Name), [Obj|Args1]), E) )   % THE COPY PASS HERE TOO (0.79): an operator's call is a call, and `w["apple"]' on a map of strings hands `const char *' to `operator[](const key_type &)', which takes it only through the string's converting constructor -- passed raw, the key was a pointer read as a string
    ;   cpp_free_operator_call(Op, A, Args, E0)
    ->  cpp_copies(E0, E)
    ;   cpp_enum_operator_call(Op, A, Args, E0)
    ->  cpp_copies(E0, E)
    ;   cpp_relops_call(Op, A, Args, E0)
    ->  cpp_copies(E0, E)
    ;   cpp_rewritten_cmp(Op, A, Args, E0)
    ->  E = E0
    ;   Plain \== none, cpp_builtin_via_conv(A, Args, Plain, E0)
    ->  E = E0
    ;   Plain \== none, \+ memberchk(Op, ['!', '&&', '||']), ( cpp_op_operand(A) ; Args = [B], cpp_op_operand(B) )   % ... never for `!', `&&' and `||', whose class operand converts contextually through its operator bool AFTER this road (0.72's rule 19, cpp_to_bool): `return !__f;' is how std::function compares with nullptr
    ->  cpp_refuse(0, no_operator(Op))   % AN OPERATOR OVER A CLASS OPERAND THAT NO ROAD ANSWERS IS ILL-FORMED (0.94): kept as the raw form it read as an `int' in a `decltype', so libc++ 18's constraint on `operator==(const optional<_Tp> &, const _Up &)', `is_convertible_v<decltype(declval<const _Tp &>() == declval<const _Up &>()), bool>', HELD for `int == nullopt_t' and that generic candidate beat the `nullopt_t' one, whose body then met the same `int == nullopt_t' (stdoptional2: `type(unknown)' in the lowering); refused, a constraint's decltype is the substitution failure C++ has there, and elsewhere the defect is named
    ;   E = Plain ).
%% A BUILT-IN OPERATOR OVER A CLASS WITH A CONVERSION FUNCTION TO AN ARITHMETIC TYPE ([over.match.oper]/3.3, [over.built]; 0.117) is the
%% operator on what the function gives: `count += v[i]' over a vector<bool>'s `__bit_reference' (its `operator bool'), `m * 2' over a
%% `Meters' with `operator double'. Only after the class's own operators and the free ones have answered nothing, and only a
%% non-explicit function (cpp_scalar_conv); a compound assignment keeps its left side, which must be the object assigned to.
cpp_builtin_via_conv(A, Args, Plain, E) :- Plain =.. [F, Op, _, _], memberchk(F, [bin, assign]), Args = [B],
    (   cpp_scalar_conv(A, A1) -> true ; \+ cpp_op_operand(A), A1 = A ),
    (   cpp_scalar_conv(B, B1) -> true ; \+ cpp_op_operand(B), B1 = B ),
    ( A1 \== A ; B1 \== B ), ( F == assign -> A1 == A ; true ),
    E =.. [F, Op, A1, B1].
cpp_builtin_via_conv(A, [], Plain, E) :- Plain =.. [F, _], memberchk(F, [neg, bitnot]), cpp_scalar_conv(A, A1), E =.. [F, A1].
cpp_scalar_conv(E, E1) :- cpp_class_of_type_of(E, C), cpp_arith_conv_result(C, RCT), cpp_conv_to(E, RCT, E1), E1 \== E.
cpp_arith_conv_result(C, RCT) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(method(_, Qs, _, operator(conv(CT0)), [], _, _), Ms), \+ cpp_is_explicit(C, Qs),
    cpp_in_class(C, cpp_type_or_self(CT0, CT)), ccl_resolve_type(CT, RCT), ccl_is_arith(RCT), !.
cpp_arith_conv_result(C, RCT) :- cpp_base_scope(C, B), cpp_arith_conv_result(B, RCT).
%% AN OPERAND OF ENUMERATION TYPE takes a free operator too ([over.match.oper]/1: a class OR AN ENUMERATION operand):
%% `bool operator==(E, E)' written by the program is what `==' on two E means, and libc++'s std::find over such an enum
%% compares through it -- the form stayed the built-in comparison, which found the wrong element (0.112;
%% test/cpp/run/enumeq.cpp). A candidate is an operator whose parameter takes the enum: the program's own are noted
%% before anything is walked (cpp_note_fns), a header's are loaded by the operator's name but for a comparison (0.127,
%% below), and with no candidate the built-in operator stands.
cpp_enum_operator_call(Op, A, Args, E) :-
    cpp_enum_operand_any([A|Args]),   % AN OPERAND OF AN ENUMERATION TYPE FIRST (0.136): the candidates' parameters were collected for every `<<' and `&' of two integers, each template's whole item copied to read them
    length(Args, N2), N3 is N2 + 1, length(Qs, N3), cpp_free_operator(Op, Qs, Name),
    ( memberchk(Op, ['==', '!=', '<', '>', '<=', '>=', '<=>']) -> true ; cpp_hdr_join(Name) ),
    findall(En0, ( cpp_enum_op_param(Name, PT), cpp_names_enum(PT, En0) ), Ens0), sort(Ens0, Ens),
    member(En, Ens), ( cpp_enum_operand(A, En) -> true ; Args = [B], cpp_enum_operand(B, En) ), !,
    cpp_enum_args([A|Args], En, As1),
    catch(cpp_call(none, id(Name), As1, E), error(not_lowered(_), _), fail), E = call(id(F), _), atom(F), ccl_declared(F, fn(_, _, _)), !.
%% ... AND A HEADER'S OPERATORS JOIN, its templates among them (0.127): a SCOPED enum has no built-in arithmetic, `~b' of a
%% `std::byte' is libc++'s `operator~(byte)' and `b << 1' its `operator<<(byte, _Integer)' template; with the enum promoted
%% to its underlying type (0.127) the built-in gave `~15', -16, where the operator gives the byte 0xF0. A comparison keeps
%% the program's operators only: every enum has the built-in one, and `op.eq.2' is the biggest overload set of the library.
%% A TEMPLATE'S parameter is asked only where it names a type by its bare name: resolving `const duration<_Rep1, _Period1> &'
%% instantiated the class over its free names, and <ratio>'s `__static_gcd<_Yp, _Xp % _Yp>' recursed on spellings that never fold.
cpp_enum_op_param(Name, PT) :- catch('$cpp_fn'(Name, _, Ps, _, _), _, fail), member(P, Ps), cpp_param_type_of(P, PT).
cpp_enum_op_param(Name, base([], [typedef(N)])) :- catch('$cpp_tmpl'(Name, _, Item), _, fail), cpp_fn_item(Item, function(_, _, _, _, Ps, _, _)), member(P, Ps),
    cpp_param_type_of(P, PT0), ( PT0 = ref(_, B) -> true ; PT0 = rref(_, B) -> true ; B = PT0 ), B = base(_, [typedef(N)]), atom(N).
cpp_enum_operand_any(Xs) :- member(X, Xs), ( X = id(N), atom(N), ccl_enum_value(N, _) -> true ; cpp_arg_type(X, T), T \== unknown, ccl_unref(T, T1), cpp_enum_named(T1, _) ), !.   % an enumerator by its name (cpp_enumerator_of below), else a value of an enumeration type
cpp_enum_operand(X, En) :- cpp_arg_type(X, T), T \== unknown, ccl_unref(T, T1), cpp_enum_named(T1, En), !.
cpp_enum_operand(X, En) :- cpp_enumerator_of(X, En).
%% AN ENUMERATOR'S TYPE IS ITS ENUM ([dcl.enum]/5; 0.112): the inference types one as `int' (0.100), so an operator the
%% program writes for the enum never saw `Red | Green' -- the built-in answered. Where such an operator is declared, an
%% enumerator operand of that enum is the enum's value (a cast), and the overload road chooses as for any enum value.
cpp_enumerator_of(id(N), En) :- atom(N), \+ cpp_local(N), ccl_tag(En, Ms), is_list(Ms), memberchk(enumerator(N, _), Ms), !.
cpp_enum_args([], _, []).
cpp_enum_args([X|Xs], En, [Y|Ys]) :- ( cpp_enumerator_of(X, En) -> Y = cast(base([], [typedef(En)]), X) ; Y = X ), cpp_enum_args(Xs, En, Ys).
cpp_names_enum(PT, En) :- catch(cpp_type_or_self(PT, PT1), _, fail), ccl_unref(PT1, PT2), cpp_enum_named(PT2, En).
cpp_enum_named(T, En) :- catch(ccl_resolve_type(T, base(_, S)), _, fail), member(Sp, S), ( Sp = enum(En, _) ; Sp = enum_class(En, _) ), !.
%% C++20's REWRITTEN CANDIDATES ([over.match.oper]/3.4): a class with an operator<=> and no operator< of its own
%% compares `a < b' as `(a <=> b) < 0' (and >, <=, >= alike), and one with an operator== compares `a != b' as
%% `!(a == b)' -- which is how a class with the two defaulted comparisons above answers all six
cpp_rewritten_cmp(Op, A, [B], E) :- memberchk(Op, ['<', '>', '<=', '>=']),
    cpp_class_of_type_of(A, C), cpp_method(C, operator('<=>'), [B], Name, Hops), !, cpp_hops(A, Hops, Base), cpp_object_arg(Name, addr(Base), Obj),
    E0 = call(id(Name), [Obj, B]),
    ( cpp_class_of_type_of(E0, _), cpp_operator(Op, E0, [int(0)], none, E1), E1 \== none -> E = E1 ; E = bin(Op, E0, int(0)) ).   % the `<=>' answers <compare>'s class (0.101): `(a <=> b) < 0' is that class's hidden friend over the literal
%% ... through a FREE `operator<=>' too (C++20; 0.121): libc++ 18 writes a string's comparison as `operator<=>(const basic_string &, const basic_string &)' alone -- no `operator<' -- so `a < b' of two strings, and every
%% `std::map<std::string, ...>', `std::sort' of strings and `std::less<std::string>' at C++20, is `(a <=> b) < 0' over that function; only a member `<=>' was looked for, and the form was refused `no_operator(<)'.
cpp_rewritten_cmp(Op, A, [B], E) :- memberchk(Op, ['<', '>', '<=', '>=']), cpp_op_operand(A),
    cpp_free_operator_call('<=>', A, [B], E00), !, cpp_copies(E00, E0),   % the argument pass on the call, as a free operator's call has it (a literal for a `type_identity_t<basic_string_view>' parameter)
    ( cpp_class_of_type_of(E0, _), cpp_operator(Op, E0, [int(0)], none, E1), E1 \== none -> E = E1 ; E = bin(Op, E0, int(0)) ).
%% ... AND REVERSED ([over.match.oper]/3.4.3): `x < y' is `0 < (y <=> x)', i.e. `(y <=> x) > 0' -- the operands swapped and the comparison mirrored -- where only the right operand's class has a `<=>' that takes
%% them (`"b" < s' over `operator<=>(const basic_string &, const _CharT *)', `s < v' of a string and a string_view over the view's `operator<=>(basic_string_view, type_identity_t<basic_string_view>)').
cpp_rewritten_cmp(Op, A, [B], E) :- memberchk(Op, ['<', '>', '<=', '>=']), cpp_op_operand(B), cpp_cmp_mirror(Op, Op2),
    cpp_operator('<=>', B, [A], none, E0), E0 \== none, E0 = call(_, _), !,
    ( cpp_class_of_type_of(E0, _), cpp_operator(Op2, E0, [int(0)], none, E1), E1 \== none -> E = E1 ; E = bin(Op2, E0, int(0)) ).
cpp_rewritten_cmp('!=', A, [B], not(E)) :- ( cpp_op_operand(A) ; cpp_op_operand(B) ), !, cpp_operator('==', A, [B], none, E), E \== none.   % a class on either side (0.115): `8 != b' is `!(b == 8)' reversed
%% ... and the REVERSED `==' (C++20, [over.match.oper]/3.4.4; 0.115): `x == y' takes `operator==(y, x)' where no
%% candidate takes the operands in order, and `x != y' is then `!(y == x)'. Asked once per comparison, never from
%% inside its own reversal (`'$cpp_reversing'', the pairs being reversed), and only from C++20. Why: libc++ 18 writes `operator==(const _CharT *,
%% __nul_terminator)' alone, and `sentinel_for<__nul_terminator, const char *>' asks `__nul_terminator == p', so
%% ranges::copy refused, `__write_escaped_code_unit' was not emitted, and std::print at C++23 stopped. `reversedeq.cpp'.
cpp_rewritten_cmp('==', A, [B], E) :- ccl_std_at_least(20), ( nb_current('$cpp_reversing', R0) -> true ; R0 = [] ),
    \+ ( member(X-Y, R0), X == A, Y == B ), ( cpp_op_operand(A) ; cpp_op_operand(B) ), !,
    nb_setval('$cpp_reversing', [B-A|R0]),
    (   catch(cpp_operator('==', B, [A], none, E0), Err, ( nb_setval('$cpp_reversing', R0), throw(Err) ))
    ->  nb_setval('$cpp_reversing', R0), E0 \== none, E = E0
    ;   nb_setval('$cpp_reversing', R0), fail ).
cpp_cmp_mirror('<', '>').
cpp_cmp_mirror('>', '<').
cpp_cmp_mirror('<=', '>=').
cpp_cmp_mirror('>=', '<=').
%% ... AND A LIBRARY HEADER'S OWN, which is a TEMPLATE: `operator==(const basic_string<C, T, A> &, const C *)' is how
%% a string compares, and the registry above holds only the program's written-out operators. The name is the same
%% (`op.eq.2'), so the free-function road takes it from here -- its lazy load, its candidates, its deduction. It
%% must ANSWER a call, or the form stays as it was and the scalar rule applies.
%% ... ON A CLASS OR A PLAIN STRUCT: a program writing `bool operator<(const S &, const S &)' over a struct of
%% plain members is everyday C++, and the struct is never PROMOTED to a class (0.84 promotes only one holding a
%% class), so the road was skipped and the form stayed the raw `bin(<, ...)' the lowering cannot take -- `type(unknown)'
cpp_op_operand(X) :- cpp_class_of_type_of(X, _), !.
cpp_op_operand(X) :- cpp_arg_type(X, T), T \== unknown, ccl_unref(T, T1), ccl_resolve_type(T1, R), ( R = base(_, [struct(_, _)]) ; R = base(_, [union(_, _)]) ), !.
cpp_free_operator_call(Op, A, Args, E) :-
    ( cpp_op_operand(A) -> true ; Args = [B], cpp_op_operand(B) ),   % a class on EITHER side: `"amy" < s' is libc++'s `operator<(const _CharT *, const basic_string &)', which the transparent comparator `less<>' writes as `std::forward<_T1>(__t) < std::forward<_T2>(__u)' -- with the class on the right only, the form stayed raw and the lowering compared a pointer with a struct
    length(Args, N2), N3 is N2 + 1, length(Qs, N3), cpp_free_operator(Op, Qs, Name),
    (   catch(cpp_call(none, id(Name), [A|Args], E0), error(not_lowered(W), H), ( W = instance_refused(_, _) -> throw(error(not_lowered(W), H)) ; cpp_trace(free_op_refused(Name, W)), fail ))   % a held candidate's body refused: the refusal, never the plain form
    ->  true ; cpp_trace(free_op_none(Name)), fail ),
    ( E0 = call(id(F0), _), ccl_declared(F0, fn(_, _, _)) -> E = E0 ; cpp_trace(free_op_undeclared(Name, E0)), fail ).
%% a member operator takes its arguments EXACTLY: every parameter after `this' the argument's own type (cpp_arg_exact)
cpp_member_exact(Name, Args) :- ccl_declared(Name, fn(_, [_|Ps], _)), cpp_args_exact(Ps, Args).
%% ... THE FREE ONE WHERE IT FITS AT LEAST AS WELL, scored as the plain overloads are (0.127): before the promotions ranked, a member
%% that was not exact always gave way -- right for `cout << "hello"' (two pointer conversions: the free one), wrong for an enum, whose
%% promotion to the member's `int' beats the free `char' template's conversion
cpp_prefer_free(call(id(F), _), Name, Args) :- atom(F), ccl_declared(F, fn(_, [_|PsF], _)), ccl_declared(Name, fn(_, [_|PsM], _)), !,
    cpp_score(PsF, Args, SF), cpp_score(PsM, Args, SM), SF >= SM.
cpp_prefer_free(E0, Name, Args) :- ( cpp_free_exact(E0, Args) -> true ; \+ cpp_member_promotes(Name, Args) ).
cpp_free_exact(call(id(F), _), Args) :- atom(F), ccl_declared(F, fn(_, [_|Ps], _)), cpp_args_exact(Ps, Args).
cpp_member_promotes(Name, Args) :- ccl_declared(Name, fn(_, [_|Ps], _)), cpp_args_promote(Ps, Args).
cpp_args_promote([], []).
cpp_args_promote([param(P, _)|Ps], [A|As]) :- ( cpp_arg_exact(P, A) ; cpp_arg_conv_exact(P, A) ; cpp_arg_promotes(P, A) ), !, cpp_args_promote(Ps, As).
cpp_arg_promotes(P, A) :- cpp_arg_type(A, AT), AT \== unknown, ccl_unref(AT, AT1), cpp_param_ref(P, P0), ccl_unref(P0, P1), cpp_promotes_to(AT1, P1).
cpp_args_exact([], []).
cpp_args_exact([param(P, _)|Ps], [A|As]) :- ( cpp_arg_exact(P, A) ; cpp_arg_conv_exact(P, A) ), !, cpp_args_exact(Ps, As).
%% ... AND A CLASS ARGUMENT WHOSE CONVERSION OPERATOR GIVES EXACTLY THE PARAMETER'S TYPE is as good as an exact one ([over.ics.rank]/3.3:
%% two user-defined conversions through the SAME function are ranked by the second standard conversion, and the identity
%% wins; 0.117): `cout << os.tellp()' is the member `operator<<(long long)' over an fpos's `operator streamoff()', never the
%% free `char' inserter that the operator's arithmetic result also converts to -- it printed the byte 6.
cpp_arg_conv_exact(PT0, A) :- cpp_class_of_type_of(A, D), catch(cpp_type_or_self(PT0, PT), _, fail), ccl_unref(PT, PT1), ccl_resolve_type(PT1, R1), \+ cpp_class_of_type(R1, _),
    cpp_conv_member(implicit, D, R1, _, RCT), cpp_bare_type(R1, B1), cpp_bare_type(RCT, B2), B1 == B2.
%% A NEW-EXPRESSION'S BLOCK (0.202; malloc's and calloc's before): the allocation function's (cpp_new_block/6) over sizeof(T), then
%% the initialization. An AGGREGATE FROM VALUES (C++20's parentheses, and braces at every level, one node after `new';
%% cpp_paren_aggregate/2, 0.197): its members initialized as a local's are (cpp_aggregate_inits), a plain struct or union from the
%% compound literal of its values
cpp_new(Spec, T, As, E) :- cpp_class_of_type(T, C), cpp_paren_aggregate(T, As), !,
    ccl_gensym('$new', P), PT = ptr([], T), ccl_declare(P, PT), cpp_class_l(C, cls(_, Data, _, _, _)),
    cpp_aggregate_inits(Data, As, deref(id(P)), 0, Inits), cpp_new_block(Spec, T, garbage, P, Inits, E).
cpp_new(Spec, T, As, E) :- \+ cpp_class_of_type(T, _), \+ ccl_resolve_type(T, arr(_, _)), cpp_paren_aggregate(T, As), !,
    findall(item([], A), member(A, As), Items), ccl_gensym('$new', P), PT = ptr([], T), ccl_declare(P, PT),
    cpp_new_block(Spec, T, garbage, P, [expr(0, assign('=', deref(id(P)), compound_lit(T, init(Items))))], E).
cpp_new(Spec, T, As, E) :- cpp_class_of_type(T, C), cpp_has_ctors(C), !, ( As == [], cpp_value_zeroes(C) -> M = zeroed ; M = garbage ), cpp_new_ctor(Spec, M, T, C, As, E).
cpp_new(Spec, T, [], E) :- !, cpp_new_zeroed(Spec, T, E).
cpp_new(Spec, T, [A], E) :- !, ccl_gensym('$new', P), cpp_new_block(Spec, T, garbage, P, [expr(0, assign('=', deref(id(P)), A))], E).   % `new T(v)' of a type with no constructor: v stored
cpp_new(_, T, _, _) :- cpp_refuse(0, new_with_constructor(T)).
%% `new T()' and `new T{}' VALUE-INITIALIZE (0.127; [expr.new]/24, [dcl.init]/8): a scalar is its zero and a type with nothing to
%% construct every byte zero (the zeroed block, whose own fields the check takes as null), a class whose default constructor is not
%% user-provided zeroed BEFORE that constructor runs. `new T' alone, the reader's `new_default(T)', default-initializes: the
%% constructor, or the block's bytes as they are. Both were malloc's bytes: `new int()' over reused memory was garbage, as was the
%% member of `new R()' that R's implicit constructor leaves alone.
cpp_new_default(Spec, T, E) :- cpp_class_of_type(T, C), cpp_has_ctors(C), !, cpp_new_ctor(Spec, garbage, T, C, [], E).
cpp_new_default(Spec, T, E) :- ccl_gensym('$new', P), cpp_new_block(Spec, T, garbage, P, [], E).
cpp_new_ctor(Spec, Mode, T, C, As, E) :-
    length(As, N), ( cpp_ctor(C, As, Name) -> true ; cpp_refuse(0, no_constructor(C, N)) ), cpp_fill_defaults(Name, As, As1), ccl_gensym('$new', P),
    Ctor = expr(0, call(id(Name), [id(P)|As1])),   % A CONSTRUCTOR THAT THROWS GIVES THE BLOCK BACK ([expr.new]/26; 0.201, its deallocation function's since 0.202): the unwinding's cleanup only (cpp_new_block/6)
    ( Mode == zeroed, cpp_zero_not_null(T, deref(id(P)), Null) -> Inits = [Null, Ctor] ; Inits = [Ctor] ),
    cpp_new_block(Spec, T, Mode, P, Inits, E).
cpp_new_zeroed(Spec, T, E) :- \+ ccl_resolve_type(T, arr(_, _)), cpp_scalar_type(T), cpp_zero_of(T, Z), !,
    ccl_gensym('$new', P), cpp_new_block(Spec, T, garbage, P, [expr(0, assign('=', deref(id(P)), Z))], E).
cpp_new_zeroed(Spec, T, E) :- ccl_gensym('$new', P), ( cpp_zero_not_null(T, deref(id(P)), Null) -> Inits = [Null] ; Inits = [] ), cpp_new_block(Spec, T, zeroed, P, Inits, E).
%% A TYPE WHOSE ZERO BYTES ARE NOT ITS ZERO (0.161): one that holds a pointer to a data member, whose null is -1 (ir_null_const/3) --
%% its object zero-initialized by calloc or memset is given the type's zero after the bytes, a compound literal with no items, which the
%% lowering spells with the -1s; an array of them keeps the bytes
cpp_zero_not_null(T, Place, expr(0, assign('=', Place, compound_lit(T, init([]))))) :- \+ ccl_resolve_type(T, arr(_, _)), ir_nonzero_null(T).
%% PLACEMENT NEW constructs WHERE IT IS TOLD and allocates nothing: `::new ((void *) p) T(args)', which is what
%% `std::__construct_at' is and what every libc++ container makes its elements with. Read as the allocating new it
%% looks like, it called malloc and dropped the block: a vector's size grew and its elements were never stored.
cpp_new_at(Ps, T, As, E) :- cpp_new_at(value, Ps, T, As, E).
cpp_new_at(_, [P], T, As, stmt_expr(block([declaration(0, none, PT, [var(N, PT, cast(PT, P))])|Ss]))) :-   % AN AGGREGATE CLASS FROM VALUES (cpp_paren_aggregate/2, 0.197): `v.emplace_back(14)' places it so (std::construct_at)
    cpp_class_of_type(T, C), cpp_paren_aggregate(T, As), !,
    ccl_gensym('$at', N), PT = ptr([], T), ccl_declare(N, PT), cpp_class_l(C, cls(_, Data, _, _, _)),
    cpp_aggregate_inits(Data, As, deref(id(N)), 0, Inits), append(Inits, [expr(0, id(N))], Ss).
cpp_new_at(Init, [P], T, As, stmt_expr(block([declaration(0, none, PT, [var(N, PT, cast(PT, P))])|Ss]))) :-
    cpp_class_of_type(T, C), cpp_has_ctors(C), \+ cpp_trivial_copy_init(C, As), !,
    length(As, K), ( cpp_ctor(C, As, CName) -> true ; cpp_refuse(0, no_constructor(C, K)) ), cpp_fill_defaults(CName, As, As1), cpp_copies(call(id(CName), [id(N)|As1]), Call),   % the copy pass, as a temporary's constructor call has it (0.83): a converting constructor's argument
    ccl_gensym('$at', N), PT = ptr([], T),
    ( Init == value, As == [], cpp_value_zeroes(C) -> ( cpp_zero_not_null(T, deref(id(N)), Nl) -> Ns = [Nl] ; Ns = [] ), append([expr(0, call(id(memset), [id(N), int(0), sizeof_type(T)]))|Ns], [expr(0, Call), expr(0, id(N))], Ss) ; Ss = [expr(0, Call), expr(0, id(N))] ).   % `new (p) T()' zeroes a class whose default constructor is not user-provided (0.127); a pointer to a data member's zero is -1 (0.161)
cpp_new_at(default, [P], T, [], stmt_expr(block([declaration(0, none, PT, [var(N, PT, cast(PT, P))]), expr(0, id(N))]))) :- !,   % `new (p) T' with nothing to construct: its bytes as they are ([dcl.init]/7; 0.127)
    ccl_gensym('$at', N), PT = ptr([], T).
cpp_new_at(_, [P], T, As, stmt_expr(block([declaration(0, none, PT, [var(N, PT, cast(PT, P))]), expr(0, assign('=', deref(id(N)), V)), expr(0, id(N))]))) :-
    cpp_placed_value(T, As, V), !,
    ccl_gensym('$at', N), PT = ptr([], T).
cpp_new_at(_, Ps, T, As, _) :- length(Ps, NP), length(As, NA), cpp_refuse(0, placement_new(T, NP, NA)).
%% WHAT A PLACEMENT NEW STORES where no constructor runs ([expr.new]/24, [dcl.init]): with no argument the type
%% VALUE-INITIALIZED -- a scalar's zero, a struct's or a union's every byte zero (`new (p) T' alone, which leaves the
%% bytes, is the reader's `new_default(T)' since 0.127); one value of the type itself, or a scalar's one value,
%% copied; anything else a struct's items, braced or (C++20) in parentheses. A plain struct had taken the scalar
%% zero of cpp_zero_of/2, an `int' stored into a struct (0.112; test/cpp/run/placeplain.cpp).
cpp_placed_value(T, [], V) :- !, \+ ccl_resolve_type(T, arr(_, _)), ( cpp_record_type(T) -> V = compound_lit(T, init([])) ; \+ cpp_class_of_type(T, _), cpp_zero_of(T, V) ).
cpp_placed_value(T, [V0], V) :- ( \+ cpp_record_type(T) ; cpp_same_record(T, V0) ), !, V = V0.
cpp_placed_value(T, As, compound_lit(T, init(Is))) :- cpp_record_type(T), \+ ccl_resolve_type(T, arr(_, _)), findall(item([], A), member(A, As), Is).
cpp_record_type(T) :- catch(ccl_resolve_type(T, base(_, Sp)), _, fail), ( memberchk(struct(_, _), Sp) ; memberchk(union(_, _), Sp) ; memberchk(class(_, _, _, _), Sp) ), !.
cpp_same_record(T, V) :- ( ccl_type_of(V, VT0), VT0 \== unknown -> true ; catch(cpp_arg_type(V, VT0), _, fail) ), VT0 \== unknown, ccl_unref(VT0, VT), catch(( cpp_same_type(VT, T) ; cpp_same_unqualified(VT, T) ), _, fail), !.   % a CONST value of the class is the class's value too (its cv is no other type); the value's type read off its DESUGARED form where the inference has none (0.122): `std::construct_at(p, std::forward<const S &>(x))' of a plain struct had a call for its argument, took it for the first item of a braced list, and stored a struct into an int
%% A VALUE OF THE CLASS ITSELF placed where the class writes no copy or move constructor of its own (`= default', or
%% none) and holds nothing that needs one is the IMPLICIT one, a copy of the bytes ([class.copy.ctor]/14): a map's
%% node takes its `pair<int, int>' so, through std::__construct_at. A class whose members have constructors of
%% their own waits for the memberwise one (not done).
cpp_trivial_copy_init(C, [E]) :- cpp_class_of_type_of(E, C), \+ cpp_copy_ctor(C, _), \+ cpp_dtor(C, _), \+ cpp_implicit_ctor_needed(C).
%% `delete p' ([expr.delete]/6-11; 0.202): where p is not null, the object's destructor, then the deallocation function --
%% the class's own unless `::delete', else the global one (cpp_usual_delete/7). A class with a VIRTUAL DESTRUCTOR is deleted by
%% its deleting destructor through the table (the Itanium ABI's D0, cpp_d0_fn/4): the dynamic type's destructor and the dynamic
%% type's deallocation function over the complete object, which a secondary table's thunk finds; `::delete' of one is the complete
%% object's destructor and the global function over the address its table's offset-to-top gives (delete_poly, 0.108). A
%% DESTROYING delete (C++20, [expr.delete]/9) runs in place of the destructor. The pointer is a name or a temporary of its own
%% (cpp_delete_operand/3): the check frees a borrow otherwise.
cpp_delete(G, X, E) :- cpp_pointee_class_of(X, C), cpp_slot(C, '$dtor', 0, _), !, cpp_dtor(C, DName), cpp_delete_operand(X, Pre, Q),
    (   G == no -> cpp_slot(C, '$dtor_del', 0, Slot), cpp_dispatch(Q, C, Slot, [], D0), D = dealloc(D0, none, Q)
    ;   cpp_destroy(Q, C, DName, D1), ( cpp_alloc_align(base([], [typedef(C)]), A) -> AA = ulong(A) ; AA = none ), D = delete_poly(Q, D1, AA) ),
    cpp_delete_expr(Pre, D, E).
cpp_delete(G, X, E) :- cpp_delete_pointee(X, T), cpp_delete_operand(X, Pre, Q), cpp_usual_delete(G, delete, T, Q, sizeof_type(T), Free, K),
    (   K = cls([objptr, destroying|_]) -> D = dealloc(none, Free, Q)
    ;   cpp_class_of_type(T, C), cpp_dtor(C, DName) -> cpp_destroy(Q, C, DName, D1), D = dealloc(D1, Free, Q)
    ;   D = dealloc(none, Free, Q) ),
    cpp_delete_expr(Pre, D, E).
cpp_delete_expr([], D, D) :- !.
cpp_delete_expr(Pre, D, stmt_expr(block(Ss))) :- append(Pre, [expr(0, D)], Ss).
cpp_delete_operand(X, [], X) :- X = id(_), !.
cpp_delete_operand(X, [declaration(0, none, PT, [var(P, PT, X)])], id(P)) :- ( ccl_type_of(X, PT), PT \== unknown -> true ; PT = ptr([], base([], [void])) ), ccl_gensym('$del', P).
cpp_delete_pointee(X, T) :- catch(( ccl_type_of(X, PT0), ccl_resolve_type(PT0, ptr(_, T)) ), _, fail), !.
cpp_delete_pointee(_, base([], [void])).
cpp_destroy(P, C, _, E) :- cpp_slot(C, '$dtor', 0, Slot), !, cpp_dispatch(P, C, Slot, [], E).
cpp_destroy(P, _, DName, call(id(DName), [P])).

%% ---- THE ALLOCATION FUNCTIONS (0.202) ------------------------------------------------------------------------------
%% A new-expression OBTAINS ITS STORAGE BY CALLING AN ALLOCATION FUNCTION, and a delete-expression gives it back by a
%% DEALLOCATION FUNCTION ([expr.new]/9, /12, [expr.delete]/9, [basic.stc.dynamic], [class.free]): for a class type not
%% written `::new', the class's own if it or a base declares one, else the global one -- the program's where it replaces it
%% ([replacement.functions]), else the library's. Every `new' was malloc and every `delete' free (M6): a program's
%% `operator new' was never called, nor a class's, nor the matching delete where a constructor throws, and an alignment past
%% 16 was never asked for. The global replaceable functions are their Itanium symbols (`_Znwm' ..., cpp_free_operator/3), so a
%% program's replaces the library's at the link as clang's does. What a new-expression makes is `alloc(Mode, T, Call)', T's
%% block from Call (Mode garbage, or zeroed(Size) for value-initialization's zero bytes, nzeroed(Size) under a function that
%% may answer null), and a delete-expression's `dealloc(Destroy, Free, X)': where X is not null, its destructor, then its
%% deallocation -- which the check reads as the allocation and the free they are.
cpp_alloc_op(new).  cpp_alloc_op('new[]').  cpp_alloc_op(delete).  cpp_alloc_op('delete[]').
cpp_dealloc_kind(new, delete).  cpp_dealloc_kind('new[]', 'delete[]').
cpp_new_form(new(_, _)).  cpp_new_form(new_default(_)).  cpp_new_form(new_array(_, _)).  cpp_new_form(new_array_init(_, _, _)).
cpp_new_form(new_at(_, _)).  cpp_new_form(delete(_)).  cpp_new_form(delete_array(_)).
%% the replaceable forms by their parameters' kinds ([new.delete.single], [new.delete.array]), and their symbols; then the reserved
%% placement forms, which libc++ defines inline ([new.delete.placement])
cpp_alloc_sym(new, [size], '_Znwm').
cpp_alloc_sym(new, [size, align], '_ZnwmSt11align_val_t').
cpp_alloc_sym(new, [size, nothrow], '_ZnwmRKSt9nothrow_t').
cpp_alloc_sym(new, [size, align, nothrow], '_ZnwmSt11align_val_tRKSt9nothrow_t').
cpp_alloc_sym('new[]', [size], '_Znam').
cpp_alloc_sym('new[]', [size, align], '_ZnamSt11align_val_t').
cpp_alloc_sym('new[]', [size, nothrow], '_ZnamRKSt9nothrow_t').
cpp_alloc_sym('new[]', [size, align, nothrow], '_ZnamSt11align_val_tRKSt9nothrow_t').
cpp_alloc_sym(delete, [ptr], '_ZdlPv').
cpp_alloc_sym(delete, [ptr, size], '_ZdlPvm').
cpp_alloc_sym(delete, [ptr, align], '_ZdlPvSt11align_val_t').
cpp_alloc_sym(delete, [ptr, size, align], '_ZdlPvmSt11align_val_t').
cpp_alloc_sym(delete, [ptr, nothrow], '_ZdlPvRKSt9nothrow_t').
cpp_alloc_sym(delete, [ptr, align, nothrow], '_ZdlPvSt11align_val_tRKSt9nothrow_t').
cpp_alloc_sym('delete[]', [ptr], '_ZdaPv').
cpp_alloc_sym('delete[]', [ptr, size], '_ZdaPvm').
cpp_alloc_sym('delete[]', [ptr, align], '_ZdaPvSt11align_val_t').
cpp_alloc_sym('delete[]', [ptr, size, align], '_ZdaPvmSt11align_val_t').
cpp_alloc_sym('delete[]', [ptr, nothrow], '_ZdaPvRKSt9nothrow_t').
cpp_alloc_sym('delete[]', [ptr, align, nothrow], '_ZdaPvSt11align_val_tRKSt9nothrow_t').
cpp_alloc_sym(new, [size, ptr], '_ZnwmPv').
cpp_alloc_sym('new[]', [size, ptr], '_ZnamPv').
cpp_alloc_sym(delete, [ptr, ptr], '_ZdlPvS_').
cpp_alloc_sym('delete[]', [ptr, ptr], '_ZdaPvS_').
%% a parameter list's kinds: the size (std::size_t), the alignment (std::align_val_t), the nothrow tag (const std::nothrow_t &), the
%% destroying tag (std::destroying_delete_t), a pointer to void, a pointer to an object (a destroying delete's), anything else
cpp_alloc_shape([], []).
cpp_alloc_shape([P|Ps], [K|Ks]) :- nonvar(P), cpp_param_type_of(P, T), nonvar(T), cpp_alloc_kind(T, K), cpp_alloc_shape(Ps, Ks).
cpp_alloc_kind(T, K) :- once(cpp_alloc_kind_(T, K)).
cpp_alloc_kind_(ref(_, T), nothrow) :- cpp_alloc_named(T, nothrow_t).
cpp_alloc_kind_(T, align) :- cpp_alloc_named(T, align_val_t).
cpp_alloc_kind_(T, destroying) :- cpp_alloc_named(T, destroying_delete_t).
cpp_alloc_kind_(ptr(_, base(_, [void])), ptr).
cpp_alloc_kind_(ptr(_, _), objptr).
cpp_alloc_kind_(T, size) :- cpp_alloc_named(T, size_t).
cpp_alloc_kind_(T, size) :- catch(ccl_resolve_type(T, base(_, S)), _, fail), msort(S, [long, unsigned]).
cpp_alloc_kind_(_, other).
cpp_alloc_named(base(_, [typedef(N)]), L) :- ( atom(N) -> N == L ; N = scoped(_, L1), L1 == L ), !.
cpp_alloc_named(base(_, [Sp]), L) :- ( Sp = enum(L1, _) ; Sp = enum_class(L1, _) ; Sp = struct(L1, _) ; Sp = class(_, L1, _, _) ), L1 == L, !.
%% an argument's kind, by the type the desugaring gives it: an integer is a size
cpp_arg_kinds([], []).
cpp_arg_kinds([A|As], [K|Ks]) :- cpp_arg_kind(A, K), cpp_arg_kinds(As, Ks).
cpp_arg_kind(A, K) :- ( catch(cpp_arg_type(A, T0), _, fail), T0 \== unknown, ccl_unref(T0, T) -> once(cpp_arg_kind_(T, K)) ; K = other ).
cpp_arg_kind_(T, nothrow) :- cpp_alloc_named(T, nothrow_t).
cpp_arg_kind_(T, align) :- cpp_alloc_named(T, align_val_t).
cpp_arg_kind_(T, destroying) :- cpp_alloc_named(T, destroying_delete_t).
cpp_arg_kind_(T, ptr) :- catch(ccl_resolve_type(T, R), _, fail), ( R = ptr(_, _) ; R = arr(_, _) ), !.
cpp_arg_kind_(T, size) :- catch(ccl_resolve_type(T, R), _, fail), ccl_is_integer(R), !.
cpp_arg_kind_(_, other).
%% THE USUAL DEALLOCATION FUNCTIONS ([basic.stc.dynamic.deallocation]/3), whose first parameter is the block given back: an OWNER to
%% the safe part, its body frees it -- `void operator delete(void *p) noexcept { free(p); }' was refused `a borrow consumed'. A
%% placement deallocation function's first parameter is as the program writes it.
cpp_alloc_own_params(Where, Op, Ps0, Ps) :- memberchk(Op, [delete, 'delete[]']), cpp_alloc_shape(Ps0, Sh), cpp_alloc_usual(Where, Sh), Ps0 = [param(PT0, N)|Rest], cpp_own_pointer(PT0, PT), !, Ps = [param(PT, N)|Rest].
cpp_alloc_own_params(_, _, Ps, Ps).
cpp_alloc_usual(_, Sh) :- memberchk(Sh, [[ptr], [ptr, size], [ptr, align], [ptr, size, align]]), !.
cpp_alloc_usual(global, Sh) :- memberchk(Sh, [[ptr, nothrow], [ptr, align, nothrow]]), !.
cpp_alloc_usual(class, [objptr, destroying|Ks]) :- memberchk(Ks, [[], [size], [align], [size, align]]).
cpp_own_pointer(ptr(Q, base(Q2, S)), ptr(Q, base(Q3, S))) :- ( memberchk(own, Q2) -> Q3 = Q2 ; Q3 = [own|Q2] ).
%% ... at namespace scope, before the namespaces are resolved: a function or a declaration of one, a class's defined out of it
cpp_alloc_units([], []).
cpp_alloc_units([unit(Is0)|Us0], [unit(Is)|Us]) :- !, cpp_alloc_items(Is0, Is), cpp_alloc_units(Us0, Us).
cpp_alloc_units([U|Us0], [U|Us]) :- cpp_alloc_units(Us0, Us).
cpp_alloc_items([], []).
cpp_alloc_items([I0|Is0], [I|Is]) :- cpp_alloc_item(I0, I), cpp_alloc_items(Is0, Is).
cpp_alloc_item(function(L, Sto, R, operator(Op), Ps0, V, B), function(L, Sto, R, operator(Op), Ps, V, B)) :- !, cpp_alloc_own_params(global, Op, Ps0, Ps).
cpp_alloc_item(function(L, Sto, R, scoped(P, operator(Op)), Ps0, V, B), function(L, Sto, R, scoped(P, operator(Op)), Ps, V, B)) :- !, cpp_alloc_own_params(class, Op, Ps0, Ps).
cpp_alloc_item(declaration(L, Sto, T, Vs0), declaration(L, Sto, T, Vs)) :- !, cpp_alloc_vars(Vs0, Vs).
cpp_alloc_item(namespace(L, N, Is0), namespace(L, N, Is)) :- !, cpp_alloc_items(Is0, Is).
cpp_alloc_item(extern_c(L, Is0), extern_c(L, Is)) :- !, cpp_alloc_items(Is0, Is).
cpp_alloc_item(include(L, S, file(P, raw, unit(Js0))), include(L, S, file(P, raw, unit(Js)))) :- !, cpp_alloc_items(Js0, Js).   % the program's own header, read whole
cpp_alloc_item(I, I).
cpp_alloc_vars([], []).
cpp_alloc_vars([var(operator(Op), fn(R, Ps0, V), I)|Vs0], [var(operator(Op), fn(R, Ps, V), I)|Vs]) :- !, cpp_alloc_own_params(global, Op, Ps0, Ps), cpp_alloc_vars(Vs0, Vs).
cpp_alloc_vars([X|Vs0], [X|Vs]) :- cpp_alloc_vars(Vs0, Vs).
%% THE IMPLICIT DECLARATIONS ([basic.stc.dynamic]/2): the replaceable functions are declared in every unit -- here under their symbols,
%% where nothing declared them (the program's replacement, <new>) -- the size and the alignment unsigned longs, a deallocation
%% function's block an owner
cpp_alloc_declare_implicit :- forall(( cpp_alloc_sym(Op, Sh, F), \+ memberchk(Sh, [[size, ptr], [ptr, ptr]]), \+ ccl_gdeclared(F, _) ), ( cpp_alloc_decl_type(Op, Sh, T), ccl_gdeclare([F-T]) )).
cpp_alloc_decl_type(Op, Sh, fn(R, Ps, false)) :- ( memberchk(Op, [new, 'new[]']) -> R = ptr([], base([], [void])) ; R = base([], [void]) ), cpp_alloc_decl_params(Sh, 1, Ps).
cpp_alloc_decl_params([], _, []).
cpp_alloc_decl_params([K|Ks], I, [param(T, N)|Ps]) :- cpp_alloc_decl_param(K, T), atom_concat('$a', I, N), I1 is I + 1, cpp_alloc_decl_params(Ks, I1, Ps).
cpp_alloc_decl_param(size, base([], [unsigned, long])).
cpp_alloc_decl_param(align, base([], [unsigned, long])).
cpp_alloc_decl_param(nothrow, ref([], base([const], [typedef(nothrow_t)]))).
cpp_alloc_decl_param(ptr, ptr([], base([own], [void]))).
%% the class whose allocation or deallocation functions of kind Op a new- or a delete-expression of class C finds ([class.free]: in the class,
%% else its bases, as a member's name is)
cpp_alloc_owner(C, Op, C) :- '$cpp_alloc_m'(C, Op), !.
cpp_alloc_owner(C, Op, O) :- cpp_base_scope(C, B), cpp_alloc_owner(B, Op, O), !.
cpp_alloc_class_of(T, C) :- catch(cpp_class_of_type(T, C), _, fail), !.
%% a type of NEW-EXTENDED ALIGNMENT ([basic.align]/3, [expr.new]/19): past __STDCPP_DEFAULT_NEW_ALIGNMENT__, 16 here as in clang
cpp_alloc_align(T, A) :- catch(( ccl_resolve_type(T, R), ccl_size_align(R, _, A) ), _, fail), A > 16.
cpp_align_value(A, cast(base([], [typedef(align_val_t)]), ulong(A))).
%% THE NEW-EXPRESSIONS: Spec = aspec(Kind, Global, Placement), the placement arguments desugared once
cpp_new_expr(Ctx, G, Ps, new(T0, As), E) :- !, cpp_type(T0, T), cpp_exprs(Ctx, As, As1), ( cpp_class_of_type(T, CN) -> cpp_check_access(Ctx, CN, '$ctor') ; true ), cpp_new(aspec(new, G, Ps), T, As1, E).
cpp_new_expr(Ctx, G, Ps, new_default(T0), E) :- !, cpp_type(T0, T), ( cpp_class_of_type(T, CN) -> cpp_check_access(Ctx, CN, '$ctor') ; true ), cpp_new_default(aspec(new, G, Ps), T, E).   % `new T' with no initializer (0.127)
%% `new T[n]' of a class that constructs or destroys, or that keeps a cookie (cpp_new_objects); `new T[n]()' AND `new T[n]{}'
%% VALUE-INITIALIZE every element ([expr.new]/24), which for a scalar and for a class with nothing to run is its zero bytes
%% (cpp_new_scalars); libc++'s `make_unique<_Tp[]>(__n)' is `unique_ptr<_Tp>(new _Up[__n]())'
cpp_new_expr(Ctx, G, Ps, new_array_init(T0, N, Items), E) :- cpp_type(T0, T), cpp_class_of_type(T, C), ( \+ cpp_trivial_class(C) ; cpp_array_cookie(T, Ck), Ck > 0 ), !, cpp_expr(Ctx, N, N1), cpp_new_objects(Ctx, aspec('new[]', G, Ps), T, C, N1, Items, E).
cpp_new_expr(Ctx, G, Ps, new_array_init(T0, N, Items), E) :- !, cpp_type(T0, T), cpp_expr(Ctx, N, N1), cpp_new_scalars(Ctx, aspec('new[]', G, Ps), T, N1, Items, E).   % `new int[n]{a, b}': the items, the rest zero
cpp_new_expr(Ctx, G, Ps, new_array(T0, N), E) :- cpp_type(T0, T), cpp_class_of_type(T, C), ( \+ cpp_trivial_class(C) ; cpp_array_cookie(T, Ck), Ck > 0 ), !, cpp_expr(Ctx, N, N1), cpp_new_objects(Ctx, aspec('new[]', G, Ps), T, C, N1, [], E).
cpp_new_expr(Ctx, G, Ps, new_array(T0, N), E) :- !, cpp_type(T0, T), cpp_expr(Ctx, N, N1), cpp_new_scalars(Ctx, aspec('new[]', G, Ps), T, N1, none, E).
%% PLACEMENT: `new (p) T' over a pointer is the reserved form, which constructs where it is told and allocates nothing (cpp_new_at/4,
%% unless the class's own allocation function takes the pointer); any other placement is an allocation function's arguments
cpp_new_expr(Ctx, G, [], new_at(Ps, N0), E) :- !, cpp_exprs(Ctx, Ps, Ps1),
    (   cpp_reserved_placement(G, Ps1, N0) -> cpp_new_placed(Ctx, Ps1, N0, E)
    ;   cpp_new_expr(Ctx, G, Ps1, N0, E) ).
cpp_new_expr(Ctx, G, [], delete(X), E) :- !, cpp_expr(Ctx, X, X1), ( cpp_pointee_class_of(X1, DC), cpp_dtor(DC, _) -> cpp_check_access(Ctx, DC, '$dtor') ; true ), cpp_delete(G, X1, E).   % ... and where one is deleted (0.127)
cpp_new_expr(Ctx, G, [], delete_array(X), E) :- !, cpp_expr(Ctx, X, X1), cpp_delete_array(G, X1, E).
cpp_new_placed(Ctx, Ps1, N0, E) :-
    (   N0 = new(T0, As) -> cpp_type(T0, T), cpp_exprs(Ctx, As, As1), cpp_new_at(Ps1, T, As1, E)
    ;   N0 = new_default(T0) -> cpp_type(T0, T), cpp_new_at(default, Ps1, T, [], E)   % `new (p) T' (0.127)
    ;   N0 = new_array(T0, N), Ps1 = [P1] -> cpp_new_at_array(Ctx, P1, T0, N, none, E)
    ;   N0 = new_array_init(T0, N, Items), Ps1 = [P1] -> cpp_new_at_array(Ctx, P1, T0, N, Items, E)
    ;   cpp_refuse(0, placement_new_array) ).
cpp_reserved_placement(G, [P], N0) :- cpp_arg_kind(P, ptr),
    \+ ( G == no, cpp_new_node_type(N0, K, T0), catch(cpp_type(T0, T), _, fail), cpp_alloc_class_of(T, C), cpp_alloc_owner(C, K, _), cpp_class_alloc(C, K, T, sizeof_type(T), [P], _, _, _) ),
    \+ cpp_global_placement(N0, P).
cpp_new_node_type(new(T, _), new, T).  cpp_new_node_type(new_default(T), new, T).  cpp_new_node_type(new_array(T, _), 'new[]', T).  cpp_new_node_type(new_array_init(T, _, _), 'new[]', T).
%% ... NOR WHERE A GLOBAL PLACEMENT ALLOCATION FUNCTION OF THE PROGRAM'S TAKES THE POINTER TO AN OBJECT ([expr.new]/19, [over.match.best]:
%% the pointer exact, or converted to a base, beats the reserved form's conversion to `void *'; 0.203): `void *operator new(std::size_t,
%% Arena *)' and `new (&ar) S' were read as the reserved placement new, a silent wrong answer. A `void *' is the reserved form's
%% exact match; the set is asked only where the program declares one of two parameters (cpp_global_alloc/9 then calls it)
cpp_global_placement(N0, P) :- cpp_new_node_type(N0, K, T0), cpp_free_operator(K, [_, _], Set), '$cpp_fn'(Set, _, _, _, _), !,
    catch(( cpp_arg_type(P, PT0), ccl_unref(PT0, PT1), ccl_resolve_type(PT1, ptr(_, AT)), \+ ccl_resolve_type(AT, base(_, [void])) ), _, fail),
    catch(cpp_type(T0, T), _, fail),
    catch(cpp_call(none, id(Set), [sizeof_type(T), P], call(id(F), _)), _, fail), atom(F), F \== Set,
    ccl_declared(F, fn(_, [_, param(QT, _)|_], _)), catch(( ccl_resolve_type(QT, ptr(_, QP)), \+ ccl_resolve_type(QP, base(_, [void])) ), _, fail).
%% the block a new-expression is: its pointer P over the block the allocation function gives, its initialization Inits (statements over
%% id(P)) under a cleanup that gives the block back where they throw ([expr.new]/26), P its value; under a non-throwing allocation
%% function the initialization runs only where there is a block ([expr.new]/20)
cpp_new_block(Spec, T, Mode, P, Inits, stmt_expr(block(Ss))) :-
    PT = ptr([], T), S = sizeof_type(T), cpp_alloc_call(Spec, T, S, P, Call, Undo, NT),
    ( Mode == zeroed -> ( NT == yes -> M = nzeroed(S) ; M = zeroed(S) ) ; M = garbage ),
    Decl = declaration(0, none, T, [var(P, PT, alloc(M, T, Call))]),
    ( Undo \== none, Inits \== [] -> Body = [eh_cleanup(0, block([expr(0, Undo)]))|Inits] ; Body = Inits ),
    (   NT == yes, Body \== [] -> Ss = [Decl, if(0, id(P), block(Body), none), expr(0, id(P))]
    ;   append([Decl|Body], [expr(0, id(P))], Ss) ).
%% cpp_alloc_call(+Spec, +T, +Size, +P, -Call, -Undo, -NoThrow): the call of the allocation function a new-expression of T makes over
%% Size and the placement arguments; Undo the call that gives the block, id(P), back where its initialization throws (the matching
%% deallocation function, [expr.new]/27; none where none matches); NoThrow `yes' for a non-throwing allocation function
cpp_alloc_call(aspec(K, no, Ps), T, S, P, Call, Undo, NT) :- cpp_alloc_class_of(T, C), cpp_alloc_owner(C, K, _),
    cpp_class_alloc(C, K, T, S, Ps, Call, Qs, AAs), !,
    ( memberchk(noexcept, Qs) -> NT = yes ; NT = no ),
    cpp_dealloc_kind(K, DK), ( cpp_class_undo(C, DK, T, S, AAs, Ps, Call, P, Undo0) -> Undo = Undo0 ; Undo = none ).
cpp_alloc_call(aspec(K, G, Ps), T, S, P, Call, Undo, NT) :- cpp_global_alloc(G, K, T, S, Ps, P, Call, Undo, NT), !.
cpp_alloc_call(aspec(K, _, Ps), T, _, _, _, _, _) :- length(Ps, N), cpp_refuse(0, no_allocation_function(K, T, N)).
%% the CLASS'S OWN ([class.free]/1): its static `operator new' over the size, the alignment first where the type asks for one and a
%% function takes it ([expr.new]/19), and the placement arguments
cpp_class_alloc(C, K, T, S, Ps, Call, Qs, AAs) :-
    ( cpp_alloc_align(T, A) -> cpp_align_value(A, AV), Tries = [[AV], []] ; Tries = [[]] ),
    member(AAs, Tries), append([S|AAs], Ps, As),
    catch(cpp_call(none, scoped([C], operator(K)), As, Call0), _, fail), Call0 = call(id(Name), _), cpp_alloc_method(C, K, Name, Qs, _), !,
    cpp_copies(Call0, Call).
cpp_alloc_method(C, K, Name, Qs, Ps) :- cpp_alloc_owner(C, K, O), cpp_class(O, cls(_, _, Ms, _, _, _)), member(method(_, Qs, _, operator(K), Ps, _, _), Ms),
    catch(cpp_mangle_q(O, operator(K), Qs, Ps, N1), _, fail), N1 == Name, !.
cpp_alloc_method(C, K, Name, Qs, Ps) :- cpp_alloc_owner(C, K, O), '$cpp_inst'(Name, O), '$cpp_mt'(O, operator(K), _, method(_, Qs, _, operator(K), Ps, _, _)), !.   % A MEMBER TEMPLATE'S INSTANCE (0.203; [temp.mem]): `template <class... Ts> static void *operator new(std::size_t, Ts...)' was refused, no_allocation_function(new, A, 2)
%% ... the matching deallocation function where the initialization throws: the usual one for a usual allocation, else the class's
%% placement deallocation function whose parameters after the first are the allocation function's after the first ([expr.new]/27)
cpp_class_undo(C, DK, T, S, [], [], _, P, Undo) :- !, cpp_usual_delete(no, DK, T, id(P), S, Undo, _).
cpp_class_undo(C, DK, _, _, AAs, Ps, call(id(AName), _), P, call(id(DName), [nullptr, id(P)|Rest])) :- cpp_dealloc_kind(K, DK),
    cpp_alloc_method(C, K, AName, _, [_|APs]), cpp_alloc_owner(C, DK, O), cpp_class(O, cls(_, _, Ms, _, _, _)),
    member(method(_, DQs, _, operator(DK), [_|DPs], _, _), Ms), cpp_params_key(APs, KA), cpp_params_key(DPs, KD), KA == KD, !,
    member(method(_, DQs, _, operator(DK), DPs1, _, _), Ms), DPs1 = [_|DPs], cpp_mangle_q(O, operator(DK), DQs, DPs1, DName), append(AAs, Ps, Rest).
%% the GLOBAL ONES: a replaceable form by the arguments -- none, the nothrow tag -- the alignment first where the type asks for one; any
%% other placement the program's own overload set ([expr.new]/19: with the alignment, then without). A non-placement allocation's matching
%% deallocation is the one a delete-expression would call ([expr.new]/27): the class's own unless `::new', else the global one
cpp_global_alloc(G, K, T, S, [], P, call(id(F), [S|AA]), Undo, no) :- !,
    cpp_alloc_align_parts(T, AK, AA), cpp_alloc_sym(K, [size|AK], F), cpp_dealloc_kind(K, DK), cpp_usual_delete(G, DK, T, id(P), S, Undo, _).
cpp_global_alloc(_, K, T, S, [N], P, call(id(F), As), call(id(DF), DAs), yes) :- cpp_arg_kind(N, nothrow), !,
    cpp_alloc_align_parts(T, AK, AA), append([[size], AK, [nothrow]], Sh), cpp_alloc_sym(K, Sh, F), append([[S], AA, [N]], As),
    cpp_dealloc_kind(K, DK), append([[ptr], AK, [nothrow]], DSh), cpp_alloc_sym(DK, DSh, DF), append([[id(P)], AA, [N]], DAs).
cpp_global_alloc(_, K, T, S, Ps, P, Call, Undo, no) :-
    cpp_alloc_align_parts(T, _, AA0), ( AA0 == [] -> Tries = [[]] ; Tries = [AA0, []] ),
    member(AA, Tries), append([S|AA], Ps, As), length(As, KN), length(Qs, KN), cpp_free_operator(K, Qs, Set),
    catch(cpp_call(none, id(Set), As, Call0), _, fail), Call0 = call(id(F), _), atom(F), ccl_declared(F, fn(_, _, _)), !,
    cpp_copies(Call0, Call), cpp_dealloc_kind(K, DK), ( cpp_global_undo(Set, F, DK, P, AA, Ps, Undo0) -> Undo = Undo0 ; Undo = none ).
cpp_alloc_align_parts(T, [align], [ulong(A)]) :- cpp_alloc_align(T, A), !.
cpp_alloc_align_parts(_, [], []).
cpp_global_undo(Set, F, DK, P, AA, Ps, call(id(DName), [id(P)|Rest])) :-
    cpp_set_member(Set, F, [_|APs]), cpp_params_key(APs, KA), length([_|APs], N), length(Qs, N), cpp_free_operator(DK, Qs, DSet),
    catch('$cpp_fn'(DSet, _, [D1|DPs], _, _), _, fail), cpp_params_key(DPs, KD), KD == KA, !,
    cpp_fn_name(DSet, [D1|DPs], yes, DName), append(AA, Ps, Rest).
cpp_set_member(Set, Name, Ps) :- catch('$cpp_fn'(Set, _, Ps, _, _), _, fail), catch(cpp_fn_name(Set, Ps, yes, N0), _, fail), N0 == Name, !.
%% cpp_usual_delete(+Global, +DK, +T, +X, +Size, -Call, -Kind): the usual deallocation function of kind DK for an object of type T at X,
%% Size its block's size ([expr.delete]/10): the class's own unless `::delete' -- a DESTROYING one first (C++20), then by the
%% alignment the type asks for, then the one without a size -- else the global one, by the alignment, SIZED for a complete type and for an
%% array of a class with a non-trivial destructor, as the standard selects it (clang 19 and later, `-fsized-deallocation'; clang 18 calls the
%% unsized one); Kind cls(Shape) or glob(Shape)
cpp_usual_delete(no, DK, T, X, S, Call, cls(Sh)) :- cpp_alloc_class_of(T, C), cpp_alloc_owner(C, DK, O), cpp_class(O, cls(_, _, Ms, _, _, _)),
    findall(u(Sh0, Qs0, Ps0), ( member(method(_, Qs0, _, operator(DK), Ps0, _, _), Ms), cpp_alloc_shape(Ps0, Sh0), cpp_alloc_usual(class, Sh0) ), Us), Us \== [], !,
    cpp_usual_pick(Us, T, u(Sh, Qs, Ps)), cpp_mangle_q(O, operator(DK), Qs, Ps, Name),
    Sh = [_|Ks], cpp_usual_rest(Ks, S, T, Rest), Call = call(id(Name), [nullptr, X|Rest]).
cpp_usual_delete(_, DK, T, X, S, call(id(F), [X|Rest]), glob([ptr|Ks])) :- cpp_alloc_align_parts(T, AK, AA),
    ( cpp_global_sized(DK, T) -> Ks = [size|AK], Rest = [S|AA] ; Ks = AK, Rest = AA ), cpp_alloc_sym(DK, [ptr|Ks], F).
cpp_global_sized(delete, T) :- catch(( ccl_resolve_type(T, R), \+ R = base(_, [void]), ccl_size_align(R, _, _) ), _, fail), !.
cpp_global_sized('delete[]', T) :- cpp_alloc_class_of(T, C), cpp_dtor(C, _), !.
cpp_usual_pick(Us, T, U) :- ( cpp_alloc_align(T, _) -> OA = yes ; OA = no ),
    findall(k(D, AP, SP)-U0, ( member(U0, Us), U0 = u(Sh, _, _), ( Sh = [objptr, destroying|_] -> D = 0 ; D = 1 ), ( memberchk(align, Sh) -> HA = yes ; HA = no ), ( HA == OA -> AP = 0 ; AP = 1 ), ( memberchk(size, Sh) -> SP = 1 ; SP = 0 ) ), KUs),
    msort(KUs, [_-U|_]).
cpp_usual_rest([], _, _, []).
cpp_usual_rest([size|Ks], S, T, [S|As]) :- !, cpp_usual_rest(Ks, S, T, As).
cpp_usual_rest([align|Ks], S, T, [AV|As]) :- !, ( catch(( ccl_resolve_type(T, R), ccl_size_align(R, _, A) ), _, fail) -> true ; A = 16 ), cpp_align_value(A, AV), cpp_usual_rest(Ks, S, T, As).
cpp_usual_rest([destroying|Ks], S, T, [compound_lit(base([], [typedef(destroying_delete_t)]), init([]))|As]) :- !, cpp_usual_rest(Ks, S, T, As).
cpp_usual_rest([_|Ks], S, T, As) :- cpp_usual_rest(Ks, S, T, As).
%% THE DELETING DESTRUCTOR (0.202), the Itanium ABI's D0, in a class's table where its destructor is virtual: the complete object's
%% destructor, then the class's usual deallocation function over it ([class.dtor]/16: the one a delete-expression in the destructor's
%% class would find) -- or the class's destroying delete alone. The slot held the complete destructor, so a `delete' through the
%% table -- the program's, and the library's own `delete this' of a facet the program made -- destroyed and kept the block. A shipped
%% class's is the library's (its D1's symbol with D0); the program's and the library's instances' are static functions of the unit,
%% made with the table (cpp_primary_entry/9) and called by a secondary table's thunk.
cpp_d0_name(C, D0) :- catch(cpp_own_dtor(C, D1), _, fail), atom_concat('_Z', _, D1), atom_concat(Pre, 'D1Ev', D1), !, atom_concat(Pre, 'D0Ev', D0).
cpp_d0_name(C, D0) :- atomic_list_concat([C, '.dtor_del.0'], D0).
cpp_d0_fn(L, C, D0, Fs) :- cpp_d0_name(C, D0), atom_concat('_Z', _, D0), !,   % the library's, declared once
    ( cpp_instance_done(D0) -> Fs = [] ; cpp_instance_note(D0, mangled), cpp_this_type(C, [], [dying], ThisT), Fs = [function(L, extern, base([], [void]), D0, [param(ThisT, this)], false, none)] ).
cpp_d0_fn(L, C, D0, [function(L, static, base([], [void]), D0, [param(ThisT, this)], false, block(Body))]) :-
    cpp_d0_name(C, D0), cpp_this_type(C, [], [dying], ThisT), T = base([], [typedef(C)]),
    cpp_usual_delete(no, delete, T, id(this), sizeof_type(T), Free, K),
    ( K = cls([objptr, destroying|_]) -> Body = [expr(L, Free)] ; cpp_dtor(C, D1), Body = [expr(L, call(id(D1), [id(this)])), expr(L, Free)] ),
    ( '$cpp_libfn'(D0) -> true ; assertz('$cpp_libfn'(D0)) ).
