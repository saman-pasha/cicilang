%% ccl_cpp_class.pl -- a class's registration: nested classes defined out of their holder, friends, access control,
%% the selected destructor and the special members a class declares, inheriting constructors, using-declared methods,
%% nested enums and unions. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood
%% there, in their order.

%% A NESTED CLASS DEFINED OUT OF ITS ENCLOSING CLASS -- `class locale::facet : public __shared_count { ... };',
%% which is how libc++ writes its facets, its holder declaring only `class facet;' -- is the class `Enclosing.Nested'
%% under the name the forward declaration already gave the type (cpp_nested_names), and the holder's own types are
%% in scope inside it (cpp_encloses). The path is the classes it is written under; a namespace's segment in it
%% would be taken for one, which the flattened headers never write.
cpp_class_item_name(N, N) :- atom(N), !.
cpp_class_item_name(scoped(Path, N), Name) :- atom(N), atomic_list_concat(Path, '.', P), atomic_list_concat([P, '.', N], Name).
cpp_class_encloses(scoped(Path, _), Name) :- !, atomic_list_concat(Path, '.', Enc), cpp_encloses(Name, Enc).
cpp_class_encloses(_, _).
cpp_fn_body_mark(none, no) :- !.
cpp_fn_body_mark(_, yes).
cpp_union_class_members(Ms) :- is_list(Ms), member(M, Ms), ( M = ctor(_, _, _, _, _) ; M = dtor(_, _, _) ; M = method(_, _, _, _, _, _, _) ), !.
cpp_struct_promotes(_, Ms) :- member(member(T, _, _), Ms), cpp_type(T, T1), cpp_elem_class(T1, C), cpp_class_l(C, _), !.
%% ... AND A PLAIN STRUCT NAMED AS A BASE IS A CLASS: `struct Tag { }; struct X : Tag { ... }' is
%% everyday C++ (tag dispatch, and every empty base there is), and the reader keeps a struct of data
%% members as C's -- so nothing registered Tag and the derived class refused base_not_registered.
%% The names are collected BEFORE anything is registered, as the free functions are (cpp_note_fns),
%% since a base is named after its own item and the decision must be made once, for the registration
%% and the emission alike ('$cpp_promoted').
cpp_struct_promotes(N, _) :- '$cpp_base_named'(N), !.
cpp_struct_promotes(_, Ms) :- member(member(T, _, _), Ms), cpp_static_type(T, _), !.   % ... AND ONE WITH A STATIC DATA MEMBER (0.112): a C struct has none, and laid out as C's the static took bytes and its out-of-class definition, `const bool Holder::flags[3] = {...}', found no class
cpp_note_bases([]).
cpp_note_bases([I|Is]) :- cpp_note_bases_(I), cpp_note_bases(Is).
cpp_note_bases_(namespace(_, _, Js)) :- !, cpp_note_bases(Js).
cpp_note_bases_(extern_c(_, Js)) :- !, cpp_note_bases(Js).
cpp_note_bases_(template(_, _, I)) :- !, cpp_note_bases_(I).
cpp_note_bases_(include(_, _, file(_, _, unit(Js)))) :- !, cpp_note_bases(Js).      % the program's own header, read whole
cpp_note_bases_(declare(_, base(_, [class(_, _, Bases, Ms)]))) :- !,
    forall(( member(base(_, B00), Bases), cpp_note_base_atom(B00, B0) ), ( cpp_note_base_name(B0), ( cpp_alias_class(B0, B1) -> cpp_note_base_name(B1) ; true ) )),   % an alias of a struct names the struct too (0.117)
    ( is_list(Ms) -> cpp_note_bases(Ms) ; true ).                                    % a nested class's bases with them
cpp_note_bases_(_).
cpp_note_base_name(N) :- ( '$cpp_base_named'(N) -> true ; assertz('$cpp_base_named'(N)) ).
%% ... AND A BASE QUALIFIED BY A NAMESPACE BY ITS NAME IN THE TABLES (0.221): the namespace's key where the name collided, else its
%% last name -- `struct D : ns::B { };' over `namespace ns { struct B { int n; }; }' promoted nothing, and D refused
%% base_not_registered('B', 'D')
cpp_note_base_atom(B0, B0) :- atom(B0), !.
cpp_note_base_atom(scoped(Path, N), K) :- atom(N), is_list(Path), ( catch(cpp_ns_key(Path, N, K0), _, fail) -> K = K0 ; K = N ).
%% A PLAIN STRUCT BOUND TO A BASE-CLAUSE TYPE PARAMETER IS A CLASS TOO (0.117): in `template <class B> struct D : B { int y; }' over
%% `struct P { int x; }' the base clause names the PARAMETER, so cpp_note_bases -- which runs before any instance exists -- noted
%% `B', promoted nothing, and `D<P>' refused base_not_registered(P, D.P). The instance promotes the base where it names it, before
%% it registers: the struct as a class (a plain struct has no method, no table and no constructor to emit, and its struct stood in
%% the output already), through an alias of the struct too. `baseparam.cpp'.
cpp_promote_plain_bases(Bases) :-
    forall(( member(B, Bases), cpp_base_name_of(B, N), atom(N), \+ cpp_class_l(N, _) ), ( cpp_promote_plain_base(N) -> true ; true )).
cpp_promote_plain_base(N0) :-
    (   ccl_tag(N0, Ms) -> N = N0 ; once(ccl_resolve_type(base([], [typedef(N0)]), base(_, [struct(N, Ms)]))), atom(N) ),   % ... through an alias of the struct too: `using PA = P; D<PA>'
    \+ '$cpp_promoted'(N), \+ cpp_class_l(N, _), is_list(Ms), \+ ccl_class_shape(Ms), \+ ccl_is_union_tag(Ms), \+ ccl_is_enum_tag(Ms),
    assertz('$cpp_promoted'(N)), assertz('$cpp_base_named'(N)), cpp_trace(promoted_base(N)),
    cpp_as_lib(no, cpp_isolated(cpp_register_class(struct, 0, N, [], Ms))).
%% the class a member's type names, through an array's element (`std::string names[2]' is two strings)
cpp_elem_class(MT, MC) :- cpp_class_of_type(MT, MC), !.
cpp_elem_class(MT, MC) :- ( MT = arr(_, ET) -> true ; ccl_resolve_type(MT, arr(_, ET)) ), cpp_elem_class(ET, MC).
cpp_array_bound_n(arr(B, _), N) :- ( ccl_const_eval(B, N) -> true ; cpp_refuse(0, array_member_bound(B)) ).
%% A FRIEND DEFINED IN THE CLASS BODY is a free function of the enclosing namespace that only argument-dependent
%% lookup finds -- the HIDDEN FRIEND, which is how `<iomanip>' writes every manipulator's inserter (`friend
%% basic_ostream<_CharT, _Traits> &operator<<(basic_ostream<_CharT, _Traits> &, const __iom_t6 &)' inside the
%% class `setw' returns) and how a program prints its own class (`friend ostream &operator<<(ostream &, const P &)').
%% Split out of the members at registration (cpp_split_friends), each is registered as the free function it is: a
%% template as a template (instantiated on use, the free operator road of 0.67 finds it), a plain one in a LIBRARY
%% class as a lazy function of the header (noted by its word for an operator, emitted where it is called), a plain
%% one in the PROGRAM's class declared as a file-scope function is and EMITTED WITH THE CLASS ('$cpp_friends').
cpp_register_class(L, C, Bases, Ms0) :- cpp_register_class(struct, L, C, Bases, Ms0).
cpp_register_class(K, L, C, Bases, Ms0) :- cpp_note_access(K, C, Ms0), cpp_note_base_access(K, C, Bases), cpp_split_friends(Ms0, Ms1, Friends),
    ( Friends == [] -> cpp_register_class__(K, L, C, Bases, Ms1) ; cpp_friends_pending(C, cpp_register_class__(K, L, C, Bases, Ms1)) ),
    cpp_register_friends(C, Friends), cpp_declare_later(C).
%% A MEMBER WHOSE DEDUCED RESULT NEEDS A HIDDEN FRIEND OF ITS CLASS WAITS FOR THE FRIENDS (0.201; [dcl.spec.auto]/11: the result
%% is deduced where the function is used, and the friends are the class's): the deduction is asked as the class registers, before
%% its friends are registered (they name the class), and `*(*this + __n)' of libc++ 21's `__ra_iterator::operator[]', flat_set's
%% iterator, over the friend `operator+', had no type -- `auto_result(C)'. While a class with friends registers
%% ('$cpp_friends_pending'), a member whose deduced result is refused is kept ('$cpp_auto_later', cpp_auto_waits/3) and deduced and
%% declared once the friends are (cpp_declare_later/1), in the class's words; refused again, the refusal is the class's, as it was.
cpp_friends_pending(C, G) :- assertz('$cpp_friends_pending'(C)),
    catch(( call(G) -> R = yes ; R = no ), E, ( retractall('$cpp_friends_pending'(C)), throw(E) )), retractall('$cpp_friends_pending'(C)), R == yes.
cpp_declare_later(C) :- \+ '$cpp_auto_later'(C, _), !.
cpp_declare_later(C) :- forall(retract('$cpp_auto_later'(C, m(Sig, Ret0, ThisT, Ps1, Body, V, Name, Ps, Qs))),
    cpp_in_class(C, cpp_with_sigdecl(C, cpp_declare_later_(C, Sig, Ret0, ThisT, Ps1, Body, V, Name, Ps, Qs)))).
cpp_declare_later_(C, Sig, Ret0, ThisT, Ps1, Body, V, Name, Ps, Qs) :- nb_getval('$ccl_scope', S0),
    (   catch(cpp_with_fsig(Sig, cpp_method_ret(C, Ret0, [param(ThisT, this)|Ps1], Body, Ret)), E, ( nb_setval('$ccl_scope', S0), throw(E) )) -> true
    ;   nb_setval('$ccl_scope', S0), cpp_refuse(0, auto_result(C)) ),
    ccl_declare(Name, fn(Ret, [param(ThisT, this)|Ps1], V)), cpp_note_defaults(Name, Ps), cpp_note_static_abi(Qs, Name).
%% a deduced result refused while the class's friends wait: the member's declaration kept for after them
cpp_auto_waits(error(not_lowered(_), _), C, Ret0, Rec) :- cpp_auto_result(Ret0), '$cpp_friends_pending'(C), !, Rec = m(_, _, _, _, _, _, Name, _, _),
    ( '$cpp_auto_later'(C, m(_, _, _, _, _, _, N0, _, _)), N0 == Name -> true ; assertz('$cpp_auto_later'(C, Rec)) ).   % once a member: a record replaced declares the members twice (cpp_register_class_)
%% ACCESS CONTROL ([class.access], 0.117; "not done" since 0.34, when `public', `private' and `protected' were read and ignored).
%% THE PROGRAM'S OWN classes only -- a library class's discipline is the library's, as its functions are not checked -- note
%% at registration, `'$cpp_acc'(Class, Name, Access)', the access each member NAME was declared under (a `class' starts private,
%% a `struct' and a `union' public; `public:' and kin move it on; a `using Base::m;' puts m under the access it stands at;
%% an overload set is as open as its most open member, so a name is refused only where every overload is), `'$ctor'' and
%% `'$dtor'' for the special members, and `'$cpp_afriend'(Class, class(F) | fn(F) | any)' for its friends (`friend class F;',
%% `friend void f(C &);', a friend function template included; a friend class template or anything this cannot name: `any', which opens the class to everyone). The
%% walk of the PROGRAM'S code asks cpp_check_access/3 where it NAMES a member: `x.m', `p->m', a bare `m' in a member or a
%% derived class's, `C::f()', a method call, a constructor chosen for a local or a `new'. It refuses by name,
%% `access(private, Owner, m)'. An access in a library function (`$cpp_in_lib') is the library's own and never asked.
%% What is not asked, so is accepted (the rule is applied where it is cheap and certain): an inheritance's own access
%% (`class D : private B' leaves B's public members public here), a pointer to member, a nested type's name, a
%% destructor, an operator used as one, and a protected member's object type ([class.protected]).
cpp_note_access(K, C, Ms) :- nb_getval('$cpp_in_lib', no), atom(C), !, ( K == class -> A0 = private ; A0 = public ), cpp_note_access_(Ms, C, A0).
cpp_note_access(_, _, _).
cpp_note_access_([], _, _).
cpp_note_access_([M|Ms], C, A0) :- ( M = access(A) -> A1 = A ; cpp_access_decl(M, C, A0), A1 = A0 ), cpp_note_access_(Ms, C, A1).
cpp_access_decl(member(base(_, [S]), anon, _), C, A) :- ( S = struct(anon, Ns) ; S = union(anon, Ns) ), is_list(Ns), !, cpp_note_access_(Ns, C, A).   % an anonymous aggregate's members are the holder's, under the section's access
cpp_access_decl(member(_, N, _), C, A) :- atom(N), !, cpp_acc_put(C, N, A).
cpp_access_decl(method(_, _, _, M, _, _, _), C, A) :- ( atom(M) ; M = operator(Op), \+ Op = conv(_) ), !, cpp_acc_put(C, M, A).   % an OPERATOR by its name `operator(Op)' (0.127): `a < b' over a private operator< is refused
cpp_access_decl(nested(base(_, [S])), C, A) :- cpp_nested_type_name(S, N), !, cpp_acc_put(C, N, A).   % A NESTED TYPE'S NAME has the access it is declared under (0.127; [class.access]/4): `Outer::Secret' named outside
cpp_access_decl(typedef(_, Vs), C, A) :- !, forall(( member(var(N, _, _), Vs), atom(N) ), cpp_acc_put(C, N, A)).   % ... a member typedef's and alias's too
cpp_access_decl(method(_, _, _, _, _, _, _), _, _) :- !.
cpp_access_decl(ctor(_, _, _, _, _), C, A) :- !, cpp_acc_put(C, '$ctor', A).
cpp_access_decl(dtor(_, _, _), C, A) :- !, cpp_acc_put(C, '$dtor', A).
cpp_access_decl(template(_, _, M), C, A) :- !, cpp_access_decl(M, C, A).
cpp_access_decl(using(_, name(Q)), C, A) :- !, cpp_using_last(Q, N), ( atom(N), N \== C -> cpp_acc_put(C, N, A) ; true ).
cpp_access_decl(friend(_, Fs), C, _) :- !, ( Fs == [] -> cpp_afriend_put(C, any) ; forall(member(F, Fs), cpp_note_friend(C, F)) ).
cpp_access_decl(_, _, _).
cpp_nested_type_name(class(_, N, _, _), N) :- atom(N), N \== anon.
cpp_nested_type_name(struct(N, _), N) :- atom(N), N \== anon.
cpp_nested_type_name(union(N, _), N) :- atom(N), N \== anon.
cpp_nested_type_name(enum(N, _), N) :- atom(N), N \== anon.
cpp_nested_type_name(enum_class(N, _), N) :- atom(N).
%% THE ACCESS OF A BASE (0.127; [class.access.base]/1): `class D : private B' -- a class's unwritten one private, a struct's public -- under
%% which B's public and protected members are D's private ones (`protected B': D's protected ones); noted by the base AS WRITTEN and
%% matched to the resolved base where it is asked (cpp_base_access)
cpp_note_base_access(K, C, Bases) :- nb_getval('$cpp_in_lib', no), atom(C), !, ( K == class -> D = private ; D = public ),
    forall(member(base(A0, Q), Bases), ( cpp_base_acc_word(A0, D, A), assertz('$cpp_bacc'(C, Q, A)) )).
cpp_note_base_access(_, _, _).
cpp_base_acc_word(virtual(A0), D, A) :- !, cpp_base_acc_word(A0, D, A).
cpp_base_acc_word(none, D, D) :- !.
cpp_base_acc_word(A, _, A).
cpp_base_access(C, B, A) :- '$cpp_bacc'(C, Q, A0), ( Q == B ; catch(cpp_base_name(Q, B1), _, fail), B1 == B ), !, A = A0.
cpp_base_access(_, _, public).
cpp_note_friend(C, friend_class(Q)) :- !, ( cpp_friend_class_name(Q, F) -> cpp_afriend_put(C, class(F)) ; cpp_afriend_put(C, any) ).
cpp_note_friend(C, F) :- cpp_friend_fn_name(F, N), !, cpp_afriend_put(C, fn(N)).
cpp_note_friend(C, _) :- cpp_afriend_put(C, any).
cpp_friend_fn_name(method(_, _, _, N, _, _, _), N) :- cpp_friend_fn_atom(N).
cpp_friend_fn_name(function(_, _, _, N, _, _, _), N) :- cpp_friend_fn_atom(N).
cpp_friend_fn_name(declaration(_, _, _, [var(N, _, _)|_]), N) :- cpp_friend_fn_atom(N).
cpp_friend_fn_name(template(_, _, I), N) :- cpp_friend_fn_name(I, N).
cpp_friend_fn_atom(N) :- ( atom(N) ; N = operator(_) ), !.
cpp_friend_class_name(Q, F) :- ( atom(Q) -> F = Q ; Q = tmpl(F0, _), atom(F0) -> F = F0 ; Q = scoped(_, L), cpp_friend_class_name(L, F) ).
cpp_afriend_put(C, F) :- ( '$cpp_afriend'(C, F) -> true ; assertz('$cpp_afriend'(C, F)) ).
%% most open wins: public before protected before private
cpp_acc_put(C, N, A) :- ( '$cpp_acc'(C, N, A0) -> ( cpp_acc_rank(A, R), cpp_acc_rank(A0, R0), R < R0 -> retract('$cpp_acc'(C, N, A0)), assertz('$cpp_acc'(C, N, A)) ; true ) ; assertz('$cpp_acc'(C, N, A)) ).
cpp_acc_rank(public, 0).
cpp_acc_rank(protected, 1).
cpp_acc_rank(private, 2).
%% may the code of Ctx (a member of a class, a lambda in one, a function) name member N of class C?
cpp_check_access(Ctx, C, N) :- cpp_check_access(Ctx, C, N, none).
%% ... and named through an OBJECT of class C (`x.m', `p->m'), where a protected non-static member asks the object's class too
cpp_check_access_obj(Ctx, C, N) :- cpp_check_access(Ctx, C, N, obj(C)).
cpp_check_access(Ctx, C, N, Obj) :-
    (   nb_getval('$cpp_in_lib', no), atom(C), ( atom(N) ; N = operator(_) ), cpp_acc_owner(C, N, Owner, A), A \== public, \+ cpp_may_access(Ctx, Owner, A, N, Obj)
    ->  ( nb_current('$cpp_line', L) -> true ; L = 0 ), cpp_refuse(L, access(A, Owner, N))
    ;   true ).
%% the class on C's way down through its bases that declares N, and the access it has AS A MEMBER OF C: a base's private member stays
%% the base's; a public or protected one reached through a protected or private base is C's own protected or private one (0.127,
%% [class.access.base]/1) -- a library base's member counts public, as nothing notes it, where C is the program's
cpp_acc_owner(C, N, Owner, A) :-
    (   '$cpp_acc'(C, N, A0) -> Owner = C, A = A0
    ;   memberchk(N, ['$ctor', '$dtor']) -> fail                                          % a constructor and a destructor are the class's own, never a base's (an implicit one is public)
    ;   cpp_class_l(C, cls(B, _, _, _, _)), atom(B), B \== none, \+ '$cpp_vprim'(C, B), cpp_acc_base(C, B, N, Owner, A) -> true
    ;   '$cpp_extra'(C, Es), member(E, Es), cpp_acc_base(C, E, N, Owner, A) -> true
    ;   cpp_class_l(C, cls(B, _, _, _, _)), '$cpp_vprim'(C, B), \+ '$cpp_vprim_ind'(C, B), cpp_acc_base(C, B, N, Owner, A) -> true ).   % a primary virtual base moved first after the bases written after it (0.176)
cpp_acc_base(C, B, N, Owner, A) :-
    (   cpp_acc_owner(B, N, Owner0, A1) -> true
    ;   '$cpp_bacc'(C, _, _), cpp_lib_class(B), atom(N), catch(cpp_has_member(B, N), _, fail) -> Owner0 = B, A1 = public ),
    (   A1 == private -> Owner = Owner0, A = private
    ;   cpp_base_access(C, B, BA), cpp_acc_rank(BA, RB), cpp_acc_rank(A1, R1), RB > R1 -> Owner = C, A = BA
    ;   Owner = Owner0, A = A1 ).
%% ... a PROTECTED non-static member named through an object, from a class S derived from its owner, only on an object of S or of a class
%% derived from S ([class.protected]; 0.127): `b.secret' of a Base inside Derived's member is refused, `o.secret' of an OwnType is not
cpp_may_access(Ctx, Owner, A, N, Obj) :-
    cpp_access_scopes(Ctx, Scopes),
    (   memberchk(Owner, Scopes) -> true
    ;   A == protected, member(S, Scopes), cpp_derives(S, Owner), cpp_protected_object(Obj, S, Owner, N) -> true
    ;   '$cpp_afriend'(Owner, F), cpp_friend_match(F, Scopes) -> true ).
cpp_protected_object(none, _, _, _) :- !.
cpp_protected_object(obj(C), S, Owner, N) :- ( C == S ; cpp_derives(C, S) ; atom(N), cpp_static_member(Owner, N, _) ), !.
cpp_friend_match(any, _) :- !.
cpp_friend_match(class(F), Scopes) :- !, member(S, Scopes), cpp_friend_is(F, S).
cpp_friend_match(fn(F), _) :- nb_current('$cpp_cur_fn', N), cpp_fn_is(F, N).
%% the friend `S<!C>' of a MEMBER class template (V<T>::S) is named by its SHORT name, and its instances are those of the template `V.S' (0.118; sentinelpair.cpp, which 0.117's gate refused: `friend class S<!C>;' did not open S<false>'s members to S<true>)
cpp_friend_is(F, F) :- !.
cpp_friend_is(F, S) :- '$cpp_inst'(S, inst(T, _)), ( T == F -> true ; '$cpp_nested_tmpl'(_, F, T) ), !.
%% a friend FUNCTION TEMPLATE's instance is the friend: `peekg.G' (an instance is `F.<keys>') for `friend int peekg(T &, const G &)', `op.shl.2.c1...' for an operator
cpp_fn_is(F, F) :- !.
cpp_fn_is(operator(Op), N) :- !, atom(N), cpp_op_word(Op, W), atomic_list_concat(['op.', W, '.'], Pfx), sub_atom(N, 0, _, _, Pfx).
cpp_fn_is(F, N) :- atom(F), atom(N), atom_concat(F, '.', Pfx), sub_atom(N, 0, _, _, Pfx).
%% the classes whose members the code is: its own class and the classes it is nested in, a closure's through the class it was made in
cpp_access_scopes(Ctx, Scopes) :- ( Ctx = self(C0, _) -> true ; atom(Ctx), Ctx \== none -> C0 = Ctx ; nb_current('$cpp_acc_scope', C0) -> true ; C0 = none ), cpp_encl_chain(C0, Scopes).
cpp_encl_chain(none, []) :- !.
cpp_encl_chain(C, [C|Cs]) :- ( cpp_enclosing(C, E), E \== C -> cpp_encl_chain(E, Cs) ; Cs = [] ).
cpp_with_access_scope(C, Goal) :- ( nb_current('$cpp_acc_scope', C0) -> true ; C0 = none ), nb_setval('$cpp_acc_scope', C),
    ( catch(Goal, E, (nb_setval('$cpp_acc_scope', C0), throw(E))) -> nb_setval('$cpp_acc_scope', C0) ; nb_setval('$cpp_acc_scope', C0), fail ).
cpp_with_fn(N, Goal) :- ( nb_current('$cpp_cur_fn', N0) -> true ; N0 = none ), nb_setval('$cpp_cur_fn', N),
    ( catch(Goal, E, (nb_setval('$cpp_cur_fn', N0), throw(E))) -> nb_setval('$cpp_cur_fn', N0) ; nb_setval('$cpp_cur_fn', N0), fail ).
cpp_friend_items([], []).
cpp_friend_items([F|Fs], Items) :- cpp_item(F, Is), cpp_friend_items(Fs, Js), append(Is, Js, Items).
cpp_split_friends(Ms, Ms1, Friends) :- cpp_split_friends_(Ms, Ms, Ms1, Friends).
cpp_split_friends_([], _, [], []).
cpp_split_friends_([friend(_, Fs)|Ms], All, Ms1, Friends) :- !, findall(F, ( member(M, Fs), cpp_friend_item(M, All, F0), cpp_friend_req(M, F0, F) ), F1), cpp_split_friends_(Ms, All, Ms1, F2), append(F1, F2, Friends).
cpp_split_friends_([template(L, TPs, friend(_, Fs))|Ms], All, Ms1, Friends) :- !, findall(template(L, TPs, F), ( member(M, Fs), cpp_friend_item(M, All, F) ), F1), cpp_split_friends_(Ms, All, Ms1, F2), append(F1, F2, Friends).
cpp_split_friends_([M|Ms], All, [M|Ms1], Friends) :- cpp_split_friends_(Ms, All, Ms1, Friends).
%% A DEFAULTED FRIEND `operator==' ([class.compare.default]/1: a friend of the class taking two of it) compares the
%% data members in order, as a defaulted member `==' does -- libc++'s ordering classes write `friend constexpr bool
%% operator==(strong_ordering, strong_ordering) noexcept = default;', and taken as a body it would have been emitted
%% as the word `default' (0.101)
cpp_friend_item(method(L, _, _, operator('=='), [P1, P2], V, default), All, function(L, none, base([], [bool]), operator('=='), [param(T1, A), param(T2, B)], V, block([return(L, Cond)]))) :- !,
    cpp_friend_param(P1, '$a', T1, A), cpp_friend_param(P2, '$b', T2, B),
    findall(Pc, ( member(member(MT, N, _), All), atom(N), \+ cpp_static_type(MT, _), cpp_cmp_pieces(MT, member(id(A), N), member(id(B), N), Pcs), member(Pc, Pcs) ), Pieces),
    cpp_eq_conj(Pieces, Cond).
cpp_friend_item(method(L, Qs, Ret, M, Ps, V, Body), _, function(L, Sto, Ret, M, Ps, V, Body)) :- Body \== none, Body \== default,   % a friend DECLARED only names a function defined elsewhere: nothing here
    ( memberchk(noexcept, Qs) -> Sto = nxif(bool(true), none) ; memberchk(noexcept(E), Qs) -> Sto = nxif(E, none) ; Sto = none ),   % ITS NOEXCEPT KEPT (0.199): `friend void swap(A &, A &) noexcept' was dropped, and `noexcept(swap(a, b))' answered false
    ( Sto = nxif(E1, _) -> assertz('$cpp_nxsrc'(M, Ps, E1)) ; true ).
%% A HIDDEN FRIEND WHOSE REQUIRES-CLAUSE IS UNMET is no candidate and is not instantiated ([temp.inst]/11,
%% [over.match.viable]/3), as a member is not (0.110): the split keeps the clause, `req(R, F)', and the friend is
%% registered only where R holds in its class, decided once the class is registered (`cpp_friends_viable/3'). Why:
%% libc++ 18's transform_view iterator declares `friend constexpr auto operator<=>(const __iterator &, const
%% __iterator &) requires random_access_range<_Base> && three_way_comparable<iterator_t<_Base>>', and deducing its
%% `auto' over a `__wrap_iter', which has no `<=>', refused and left the view's `begin()' undeclared (0.113).
%% `friendreq.cpp'.
cpp_friend_req(method(_, Qs, _, _, _, _, _), F, req(R, F)) :- memberchk(requires(R), Qs), !.
cpp_friend_req(_, F, F).
cpp_friends_viable(_, [], []).
cpp_friends_viable(C, [req(R, F)|Fs], Out) :- !, F = function(_, _, _, _, Ps, _, _),
    ( cpp_member_req_holds(C, [], Ps, R) -> Out = [F|Out1] ; cpp_trace(friend_req_unmet(C, R)), Out = Out1 ), cpp_friends_viable(C, Fs, Out1).
cpp_friends_viable(C, [F|Fs], [F|Out]) :- cpp_friends_viable(C, Fs, Out).
cpp_friend_param(P, D, T, N) :- ( P = param(T, N0) ; P = param(T, N0, _) ), ( atom(N0), N0 \== none, N0 \== anon -> N = N0 ; N = D ).
cpp_register_friends(_, []) :- !.
cpp_register_friends(C, Friends0) :- cpp_friends_viable(C, Friends0, Friends),
    (   nb_getval('$cpp_in_lib', yes) -> cpp_register_lazy_friends(C, Friends)
    ;   cpp_friends_resolved(C, Friends, Friends1),   % THE PROGRAM'S HIDDEN FRIEND IS WRITTEN IN ITS CLASS'S WORDS TOO (0.115), as the library's is (0.112): `friend T operator-(const It &, const It &)' of a class template's nested `It' kept `It' bare, and the lowering met `typedef('It')'
        cpp_register_(Friends1), ( retract('$cpp_friends'(C, Old)) -> append(Old, Friends1, New) ; New = Friends1 ), assertz('$cpp_friends'(C, New)) ).
cpp_friends_resolved(_, [], []).
cpp_friends_resolved(C, [function(L, Sto, Ret0, M, Ps0, V, Body)|Fs], [function(L, Sto, Ret, M, Ps, V, Body)|Rs]) :- !,
    ( catch(cpp_in_class(C, ( cpp_type_or_self(Ret0, Ret), cpp_resolved_params(Ps0, Ps) )), error(not_lowered(_), _), fail) -> true ; Ret = Ret0, Ps = Ps0 ),
    cpp_friends_resolved(C, Fs, Rs).
cpp_friends_resolved(C, [template(L, TPs0, I0)|Fs], [template(L, TPs, I)|Rs]) :- !, cpp_friend_tmpl_words(C, TPs0, I0, TPs, I), cpp_friends_resolved(C, Fs, Rs).
cpp_friends_resolved(C, [F|Fs], [F|Rs]) :- cpp_friends_resolved(C, Fs, Rs).
cpp_register_lazy_friends(_, []).
cpp_register_lazy_friends(C, [template(L, TPs0, Item0)|Fs]) :- !,
    cpp_friend_tmpl_words(C, TPs0, Item0, TPs, Item),
    cpp_register_([template(L, TPs, Item)]), ( cpp_template_name(Item, N), \+ '$cpp_lib'(N) -> assertz('$cpp_lib'(N)) ; true ), cpp_register_lazy_friends(C, Fs).
%% A LIBRARY CLASS'S HIDDEN FRIEND IS WRITTEN IN THE CLASS'S WORDS (0.112): `friend bool operator==(const __iterator &,
%% const __iterator &)' inside filter_view's iterator names the NESTED class bare, and kept so the call site -- the
%% range-for's `__b != __e', rewritten `!(__b == __e)' -- read `__iterator' in its own words and matched nothing
%% (no_operator(==)). Its types are resolved in the class where it is registered, and its body is walked there when
%% it is emitted ('$cpp_friend_in'), as a member's is; the program's own class emits its friends with the class.
cpp_register_lazy_friends(C, [function(L, Sto, Ret0, M, Ps0, V, Body)|Fs]) :- !,
    ( catch(cpp_in_class(C, ( cpp_type_or_self(Ret0, Ret), cpp_resolved_params(Ps0, Ps) )), error(not_lowered(_), _), fail) -> true ; Ret = Ret0, Ps = Ps0 ),
    ( M = operator(Op) -> cpp_free_operator(Op, Ps, N) ; N = M ), Item = function(L, Sto, Ret, N, Ps, V, Body),
    cpp_fn_put(N, Ps, Body, lazy(Item)), assertz('$cpp_friend_in'(N, Ps, C)), ( '$cpp_lib'(N) -> true ; assertz('$cpp_lib'(N)) ), cpp_register_lazy([Item]), cpp_register_lazy_friends(C, Fs).
cpp_register_lazy_friends(C, [_|Fs]) :- cpp_register_lazy_friends(C, Fs).
%% A FRIEND TEMPLATE IS WRITTEN IN ITS CLASS'S WORDS (0.115): libc++'s `elements_view<_View, _Np>::__sentinel' declares
%% `template <bool _OtherConst> requires sentinel_for<sentinel_t<_Base>, ...> friend bool operator==(const
%% __iterator<_OtherConst> &, const __sentinel &)', and deduced at the call site, with no class, `__iterator' named no
%% template, `__sentinel' no class and `_Base' nothing: `deduction_failed(__iterator)', and the range-for's `!=' over
%% `m | views::keys' had taken the iterator's own `==' by arity, a sentinel bound to an `__iterator &'. Its head and its
%% parameters are rewritten where it is registered: a member class template's short name to its registered name (the
%% sibling's, an enclosing class's), the class's own short name to the class, a class typedef to its type in the class.
cpp_friend_tmpl_words(C, TPs0, function(L, S, R0, M, Ps0, V, B0), TPs, function(L, S, R, M, Ps, V, B)) :- !,
    cpp_tparam_names(TPs0, TNs),
    ( '$cpp_inst'(C, inst(T, _)), '$cpp_nested_tmpl'(_, Own, T) -> true ; Own = none ),
    cpp_ftw(TPs0, C, TNs, Own, TPs), cpp_ftw(R0, C, TNs, Own, R), cpp_ftw(Ps0, C, TNs, Own, Ps),
    ( B0 = block(_) -> B = block(['$in_class'(C, B0)]) ; B = B0 ).   % and its BODY is walked in the class where it is instantiated, as a plain hidden friend's is: `__get_current(__x)' is the sentinel's own static member template
cpp_friend_tmpl_words(_, TPs, Item, TPs, Item).
cpp_ftw(X, _, _, _, X) :- var(X), !.
cpp_ftw(tmpl(N, As0), C, TNs, Own, tmpl(MN, As)) :- atom(N), \+ memberchk(N, TNs), catch(cpp_nested_template_of(C, N, MN), _, fail), !, cpp_ftw(As0, C, TNs, Own, As).
cpp_ftw(typedef(N), C, _, Own, typedef(C)) :- N == Own, !.
cpp_ftw(typedef(N), C, TNs, _, T) :- atom(N), \+ memberchk(N, TNs), catch(cpp_class_typedef(C, N, T0, Def), _, fail), !,
    ( catch(cpp_in_class(Def, cpp_type(base([], [typedef(N)]), T1)), _, fail), T1 = base(_, [_]) -> T1 = base(_, [T]) ; T0 = base(_, [T]) -> true ; T = typedef(N) ).
cpp_ftw(T0, C, TNs, Own, T) :- compound(T0), !, T0 =.. [F|As0], cpp_ftw_list(As0, C, TNs, Own, As), T =.. [F|As].
cpp_ftw(T, _, _, _, T).
cpp_ftw_list([], _, _, _, []).
cpp_ftw_list([A|As], C, TNs, Own, [B|Bs]) :- cpp_ftw(A, C, TNs, Own, B), cpp_ftw_list(As, C, TNs, Own, Bs).
cpp_register_class__(K, L, C, Bases, Ms00) :-                                               % the traces fire only under '$cpp_trace'
    cpp_note_specials(C, Ms00),                                                                  % what the class DECLARES of its special members, before the record drops a deleted one (0.200)
    ( memberchk(final_class, Ms00), \+ '$cpp_final'(C) -> assertz('$cpp_final'(C)) ; true ),            % a class declared `final' (0.206): `__is_final' asks it
    cpp_inherit_ctors(L, Bases, Ms00, Ms01), cpp_inherit_methods(L, C, Bases, Ms01, Ms0),
    ( cpp_norm_members(Ms0, Bases, Ms) -> true ; cpp_refuse(L, members_not_normalized(C)) ),
    %% `C() = default;' IS the implicit default constructor, and declaring it keeps the class default-constructible
    %% where its other constructors would have suppressed it -- libc++'s `union __rep' writes it beside three others,
    %% and a member of that type had nothing to construct with (member_not_constructed).
    %% ... but a CONSTRAINED one, `filter_view() requires default_initializable<_View> && ... = default', is a default
    %% constructor only where its constraints hold ([temp.inst]/11, 0.110's rule for a member): for a ref_view they do
    %% not, and made the implicit way it default-constructed the ref_view member, which has no default constructor
    %% (member_not_constructed). Decided once the class is registered, in its own words.
    ( memberchk(ctor(_, DQs, [], _, default), Ms0), \+ '$cpp_default_ctor'(C) -> ( memberchk(requires(_), DQs) -> DReq = DQs ; assertz('$cpp_default_ctor'(C)), DReq = none ) ; DReq = none ),
    cpp_nested_names(L, C, Ms),                                                                  % the NAMES first: a member of a nested type resolves before the nested class exists
    ( cpp_register_class_extras(C, Ms) -> true ; cpp_refuse(L, class_extras(C)) ),
    cpp_selected_dtor(C, Ms0, Ms, MsD),                                                          % of its prospective destructors, the one whose constraints hold (0.201)
    ( cpp_in_class(C, cpp_register_class_(K, L, C, Bases, MsD)) -> true ; cpp_refuse(L, class_not_registered(C)) ),   % its own typedefs resolve its members' types
    ( DReq == none -> true ; cpp_method_viable(C, DReq, []) -> ( '$cpp_default_ctor'(C) -> true ; assertz('$cpp_default_ctor'(C)) ) ; cpp_trace(default_ctor_unmet(C)) ),
    ( '$cpp_inst'(C, _) -> true ; cpp_member_asserts(C, Ms00) ),                                 % its static assertions, in its words (0.205); an instance's once it is complete (cpp_instance_body_/4, 0.221)
    cpp_nested_classes(L, C, Ms).                                                                % then the nested classes themselves, the enclosing one registered so its own name resolves inside them
%% A STATIC ASSERTION AMONG A CLASS'S MEMBERS ([class.mem]/1, [dcl.pre]/10; 0.205) is checked once the class is registered, in
%% its words (its statics and typedefs, cpp_in_class/2): an instance's once its template's arguments are substituted, a template's
%% never. It was read and dropped: `struct A { static_assert(sizeof(int) == 8); };' compiled, where clang++ refuses it.
%% ... AND AN INSTANCE'S ONCE THE INSTANCE IS COMPLETE (0.221): its struct, its vtable and its friends emitted (cpp_instance_body_/4).
%% Asked while it registered, a failure threw out of the middle of it, a probe that made the instance caught the throw (a candidate's
%% check, a type resolved where it can, cpp_type_or_self/2), and the instance was left named and half made -- its destructor, emitted
%% later, read a vtable nothing declared (`template <class T> struct B { static_assert(sizeof(T) == 1); virtual ~B() {} };').
cpp_member_asserts(C, Ms) :- forall(member(static_assert(L, E, M), Ms), cpp_in_class(C, cpp_static_assert(none, L, E, M))).
%% THE SELECTED DESTRUCTOR (C++20 [class.dtor]/4; 0.201): of the prospective destructors a class declares, the one whose constraints
%% hold is its destructor, chosen once the class's typedefs are noted, in its own words (cpp_method_viable/3). libc++'s std::expected
%% writes `~__repr() requires(is_trivially_destructible_v<_Err>) = default;' beside `~__repr() requires(!is_trivially_destructible_v<_Err>)
%% { __destroy_union_member(); }': the defaulted one is the implicit destructor (the normalization drops it), and the other was kept
%% whatever its clause said, so `std::expected<void, int>'s destructor named a member whose own clause is unmet (`undeclared').
cpp_selected_dtor(C, Ms0, Ms, Ms1) :- findall(x, member(dtor(_, _, _), Ms0), [_, _|_]), !, cpp_drop_unmet_dtors(C, Ms, Ms1).
cpp_selected_dtor(_, _, Ms, Ms).
cpp_drop_unmet_dtors(_, [], []).
cpp_drop_unmet_dtors(C, [dtor(_, Qs, _)|Ms], Ms1) :- memberchk(requires(_), Qs), \+ cpp_method_viable(C, Qs, []), !, cpp_trace(dtor_unmet(C)), cpp_drop_unmet_dtors(C, Ms, Ms1).
cpp_drop_unmet_dtors(C, [M|Ms], [M|Ms1]) :- cpp_drop_unmet_dtors(C, Ms, Ms1).
%% THE SPECIAL MEMBERS A CLASS DECLARES (0.200; [class.copy.ctor]/1, /6, /8, [class.copy.assign]/2, /4): `'$cpp_sdecl'(C, What, P,
%% Body)' for each constructor of one parameter P (or of more, the others defaulted) and each assignment of one, What `ctor' or
%% `assign', and for the destructor, What `dtor' and P `none'; Body `delete', `default' or `user'; and `'$cpp_dctor'(C, Ps)' for
%% each constructor declared deleted. The class's record drops a member `= delete' and keeps a defaulted one as the implicit one,
%% so it does not say what the class declared, which decides whether the implicit copy and move are there and whether one is
%% deleted (cpp_special_there/2). Which of them is a copy or a move is asked once the class is registered (cpp_sdecl/3).
cpp_note_specials(C, Ms) :- retractall('$cpp_sdecl'(C, _, _, _)), retractall('$cpp_dctor'(C, _)), retractall('$cpp_cpok'(C, _, _)),
    forall(( member(M, Ms), cpp_special_decl(M, What, P, Body) ), assertz('$cpp_sdecl'(C, What, P, Body))),
    forall(member(ctor(_, _, Ps, _, delete), Ms), assertz('$cpp_dctor'(C, Ps))).
cpp_special_decl(ctor(_, _, [P|Ps], _, B), ctor, P, K) :- forall(member(Q, Ps), Q = param(_, _, _)), cpp_body_kind(B, K).
cpp_special_decl(method(_, _, _, operator('='), [P], _, B), assign, P, K) :- cpp_body_kind(B, K).
cpp_special_decl(dtor(_, _, B), dtor, none, K) :- cpp_body_kind(B, K).
cpp_body_kind(B, K) :- ( B == delete -> K = delete ; B == default -> K = default ; K = user ).
%% INHERITING CONSTRUCTORS: `using Base::Base;' in a class body gives the class every constructor of its base --
%% each synthesized here as a constructor of the same parameters (the base's words resolved, the defaults kept,
%% an unnamed parameter named) whose initializer hands them to the base and whose body is empty; the base's copy
%% and move constructors are not inherited (C++11 [class.inhctor]). libc++'s tree writes its node destructor as
%% `struct __generic_container_node_destructor<__tree_node<...>, _Alloc> : __tree_node_destructor<_Alloc> { using
%% __tree_node_destructor<_Alloc>::__tree_node_destructor; };', and `_Dp(__na, true)' found no constructor.
cpp_inherit_ctors(L, [base(_, B0)], Ms0, Ms) :-
    member(using(_, name(U)), Ms0), cpp_using_last(U, N), catch(cpp_base_name(B0, Base), _, fail), ( cpp_own_name(Base, N) -> true ; cpp_alias_names_base(Ms0, N, Base) -> true ; cpp_tmpl_head(B0, N) ), !,   % `using __base::__base;' through the class's own alias (optional's storage chain); `using __perfect_forward<_Op, _Args...>::__perfect_forward;' through an ALIAS TEMPLATE's name, the base clause's own head (libc++'s bind_front, 0.100)
    cpp_class(Base, cls(_, _, BMs, _, _, _)),
    findall(ctor(L, Qs, Ps1, [init(Base, Args)], block([])),
            ( member(ctor(_, Qs0, Ps0, _, Body), BMs), Body \== delete, \+ cpp_copy_or_move(Base, Ps0),
              cpp_in_class(Base, cpp_named_params(Ps0, 1, Ps1, Args)), ( memberchk(explicit, Qs0) -> Qs = [explicit] ; memberchk(explicit(XE), Qs0) -> Qs = [explicit(XE)] ; Qs = [] ) ),
            Ctors),
    findall(template(L, TPs, ctor(L, Qs, Ps1, [init(Base, Args)], block([]))),                                   % ... AND THE BASE'S CONSTRUCTOR TEMPLATES ([namespace.udecl]): optional's storage chain inherits, level by level, `template <class... _Args> __optional_destruct_base(in_place_t, _Args &&...)', and without them `optional(_Up &&)' found no base constructor
            ( member(template(_, TPs, ctor(_, Qs0, Ps0, _, Body)), BMs), Body \== delete,
              cpp_named_params_t(Ps0, 1, Ps1, Args), ( memberchk(explicit, Qs0) -> Qs = [explicit] ; memberchk(explicit(XE), Qs0) -> Qs = [explicit(XE)] ; Qs = [] ) ),
            TCtors),
    append(Ms0, Ctors, Ms1), append(Ms1, TCtors, Ms), length(Ctors, NC), length(TCtors, NT), cpp_trace(inherit(Base, NC, NT)).
cpp_inherit_ctors(_, _, Ms, Ms).
%% a constructor template's parameters stay as written (its own parameters resolve at the call), a pack forwarded as an expansion
cpp_named_params_t([], _, [], []).
cpp_named_params_t([P|Ps], I, [P1|Ps1], [A|As]) :-
    ( P = param(T, N0) -> D = none ; P = param(T, N0, D) ), ( N0 == anon -> atom_concat('$i', I, N) ; N = N0 ),
    ( D == none -> P1 = param(T, N) ; P1 = param(T, N, D) ), ( T = pack(_) -> A = pack(id(N)) ; A = id(N) ), I1 is I + 1, cpp_named_params_t(Ps, I1, Ps1, As).
%% USING-DECLARED METHODS, `using Base::f;' and `using Bs::operator()...;' (0.121): the class's overload set for the name is
%% its own methods AND the named base's ([namespace.udecl]/16), and the call road looks in the class first and in a base only
%% where nothing in the class fits -- so the base's `f(int)' was taken for a call of `f(2.0)' that the base's other `f(double)'
%% answers exactly, and libc++'s `__all_overloads<__overload<int, 0>, __overload<double, 1>>' (std::variant's converting
%% constructor, C++17's `overloaded' idiom) chose by position. Each method and method template of the named base becomes a
%% FORWARDER of the class: the same name, qualifiers, parameters and result, whose body calls the base's by its qualified
%% name over the base sub-object (`this->Base::f(args)', never virtual). The overload rules then see one set. A virtual
%% name is left to the old road (the call must stay virtual), a static one too, and one the class declares itself with the
%% same parameter types hides the base's ([namespace.udecl]/15).
cpp_inherit_methods(L, C, Bases, Ms0, Ms) :-
    findall(Base-N, ( member(using(_, name(scoped([Q], N))), Ms0), cpp_fwd_name(N), cpp_using_base(Q, Bases, Base) ), Us0), Us0 \== [], !,
    cpp_dedupe(Us0, Us),
    findall(F, ( member(Base-N, Us), cpp_fwd_member(Base, N, Ms0, L, F) ), Fs),
    append(Ms0, Fs, Ms), length(Fs, K), cpp_trace(inherit_methods(C, K)).
cpp_inherit_methods(_, _, _, Ms, Ms).
cpp_fwd_name(N) :- ( atom(N) ; N = operator(Op), Op \= conv(_) ), !.
cpp_using_base(Q, Bases, Base) :- catch(cpp_base_name(Q, QB), _, fail), member(base(_, B0), Bases), B0 \= virtual(_), catch(cpp_base_name(B0, Base), _, fail), Base == QB, !.
cpp_fwd_member(Base, N, Ms0, L, F) :-
    cpp_class(Base, cls(_, _, BMs, _, _, _)), \+ ( cpp_class_l(Base, cls(_, _, _, _, Slots)), member(slot(N, _, _, _, _), Slots) ),
    (   member(method(_, Qs0, Ret, N, Ps0, V, Body0), BMs), TPs = none, TNs = []
    ;   member(template(_, TPs, method(_, Qs0, Ret, N, Ps0, V, Body0)), BMs), cpp_tparam_names(TPs, TNs) ),
    Body0 \== delete, Body0 \== default, \+ memberchk(static, Qs0), \+ memberchk(virtual, Qs0), \+ memberchk(pure, Qs0), \+ memberchk(requires(_), Qs0), \+ memberchk(explicit_this(_, _), Qs0),
    \+ cpp_fwd_hidden(Ms0, N, Ps0),
    findall(Q, ( member(Q, Qs0), ( Q == const ; Q == noexcept ; Q = noexcept(_) ; Q = refq(_) ; Q = trailing(_) ) ), Qs1),
    ( memberchk(closure, Qs0), \+ memberchk(const, Qs1) -> Qs = [const|Qs1] ; Qs = Qs1 ),   % a lambda's operator() is const unless mutable, which the closure mark stands for
    cpp_fwd_params(Ps0, TNs, 1, Ps, As),
    Call = call(arrow(this, scoped([Base], N)), As),
    ( Ret = base(_, [void]) -> Stmt = expr(L, Call) ; Stmt = return(L, Call) ),
    M = method(L, Qs, Ret, N, Ps, V, block([Stmt])),
    ( TPs == none -> F = M ; F = template(L, TPs, M) ).
cpp_fwd_hidden(Ms0, N, Ps0) :- cpp_fwd_ptypes(Ps0, Ts), ( member(method(_, _, _, N, Ps1, _, _), Ms0) ; member(template(_, _, method(_, _, _, N, Ps1, _, _)), Ms0) ), cpp_fwd_ptypes(Ps1, Ts), !.
cpp_fwd_ptypes([], []).
cpp_fwd_ptypes([P|Ps], [T|Ts]) :- ( P = param(T, _) ; P = param(T, _, _) ), !, cpp_fwd_ptypes(Ps, Ts).
%% the parameters named, and each handed on as it came: a forwarding reference (`_Up &&' of a template) by the cast
%% `std::forward' is, any other rvalue reference and a value by `move', an lvalue reference as it is, a pack as an expansion
cpp_fwd_params([], _, _, [], []).
cpp_fwd_params([P|Ps], TNs, I, [P1|Ps1], [A|As]) :-
    ( P = param(T, N0) -> D = none ; P = param(T, N0, D) ), ( N0 == anon -> atom_concat('$i', I, N) ; N = N0 ),
    ( D == none -> P1 = param(T, N) ; P1 = param(T, N, D) ),
    cpp_fwd_arg(T, TNs, N, A), I1 is I + 1, cpp_fwd_params(Ps, TNs, I1, Ps1, As).
cpp_fwd_arg(pack(T), TNs, N, pack(A)) :- !, cpp_fwd_arg(T, TNs, N, A).
cpp_fwd_arg(rref(Qs, base(Q, [typedef(P)])), TNs, N, ccast(static, rref(Qs, base(Q, [typedef(P)])), id(N))) :- atom(P), memberchk(P, TNs), !.
cpp_fwd_arg(rref(_, _), _, N, move(id(N))) :- !.
cpp_fwd_arg(ref(_, _), _, N, id(N)) :- !.
cpp_fwd_arg(_, _, N, move(id(N))).
cpp_alias_names_base(Ms, N, Base) :- member(typedef(_, Vs), Ms), member(var(N, T0, _), Vs), catch(cpp_type(T0, T), _, fail), cpp_class_of_type(T, Base), !.
%% the head of a base clause: the template-id's name, an alias template's included, under any scope
cpp_tmpl_head(tmpl(N, _), N) :- !.
cpp_tmpl_head(scoped(_, X), N) :- !, cpp_tmpl_head(X, N).
cpp_tmpl_head(N, N) :- atom(N).
cpp_using_last(scoped(_, N), N) :- ( atom(N) ; N = operator(_) ), !.   % an operator too, `using Bs::operator()...' (0.121): the name failed here and with it the whole registration of the class
cpp_using_last(N, N) :- atom(N).
%% the class's OWN name: the instance's, or the template's it was made from -- an initializer naming the injected class name
%% (`__value_func(std::forward<_Fp>(__f), allocator<_Fp>())', libc++'s delegating constructor) arrives SUBSTITUTED to the
%% instance's name (cpp_subst on init/2, 0.100), and answered only by the template's name the delegation fell to the
%% `a class named as a base' clause of cpp_init_known and was dropped: every std::function was constructed empty
cpp_own_name(Base, N) :- Base == N, !.
cpp_own_name(Base, N) :- '$cpp_inst'(Base, inst(N0, _)), N0 == N.
cpp_copy_or_move(Base, [P]) :- ( P = param(T, _) ; P = param(T, _, _) ), ( T = ref(_, base(_, [typedef(Base)])) ; T = rref(_, base(_, [typedef(Base)])) ), !.
cpp_copy_or_move(Base, [P]) :- cpp_named_self(Base, P, _), !.   % ... or one that names the class otherwise, `S(const S<T> &)' (0.198, cpp_named_self/3)
cpp_named_params([], _, [], []).
cpp_named_params([P|Ps], I, [P1|Ps1], [id(N)|As]) :-
    ( P = param(T0, N0) -> D = none ; P = param(T0, N0, D) ), ( N0 == anon -> atom_concat('$i', I, N) ; N = N0 ),
    cpp_type_or_self(T0, T), ( D == none -> P1 = param(T, N) ; P1 = param(T, N, D) ), I1 is I + 1, cpp_named_params(Ps, I1, Ps1, As).
%% A NESTED CLASS is a type of the class that holds it (`Plain::Nested' outside, `Nested' within) and a class of its
%% own under the mangled name `Enclosing.Nested'; the enclosing class's typedefs are in scope inside it, as C++ has it
cpp_nested_name(nested(base(_, [class(_, N, _, Ms)])), N, Ms) :- atom(N), Ms \== none.
cpp_nested_name(nested(base(_, [class(N, none)])), N, none) :- atom(N).     % `class facet;' inside its holder: the NAME of a class defined out of it, a type of the holder all the same
cpp_nested_name(nested(base(_, [struct(N, Ms)])), N, Ms) :- atom(N), Ms \== none.
cpp_nested_name(nested(base(_, [union(N, Ms)])), N, Ms) :- atom(N), Ms \== none.     % a nested UNION: a type of the class, no class of its own
%% the TYPE a nested name has: a union's is a union's, or its layout would be a struct's -- libc++'s `__rep' holds
%% the short and the long representation of a string in the same bytes, and as a struct it was their sum
cpp_nested_spec(M, Name, base([], [union(Name, none)])) :- M = nested(base(_, [union(_, _)])), \+ cpp_nested_union_class(M), !.
cpp_nested_spec(_, Name, base([], [typedef(Name)])).       % a union-CLASS is named as any class is; its tag carries the union marker
cpp_nested_names(L, C, Ms) :-
    forall( ( member(M, Ms), cpp_nested_name(M, N, _) ),
            ( atomic_list_concat([C, '.', N], Name), cpp_nested_spec(M, Name, Spec), cpp_ctype_put(C, N, Spec),
              ( '$cpp_nested'(Name, _, _, _, _) -> true ; assertz('$cpp_nested'(Name, L, C, N, M)) ) ) ),
    forall( ( member(M, Ms), cpp_nested_enum(C, M, N, Name, Spec) ),
            ( cpp_ctype_put(C, N, base([], [typedef(Name)])),
              cpp_enum_members(Spec, Es), ccl_note_tag(Name, Es), cpp_note_nested_enum(N) ) ).    % in the tag table AT ONCE: a member's type names it while the class is being declared
cpp_nested_classes(L, C, Ms) :- forall( ( member(M, Ms), cpp_nested_name(M, N, NMs), NMs \== none ), cpp_nested_class(L, C, N, NMs, M) ),
    forall( ( member(M, Ms), cpp_nested_enum(C, M, _, Name, Spec) ), cpp_nested_enum_item(L, Name, Spec) ).
%% A NESTED ENUM is a type of the class that holds it, as a nested class is: `ios_base::seekdir', which libc++'s
%% basic_streambuf writes in three of its methods and which refused as no_member_type -- only a typedef, a nested
%% class and a nested union were class-scope types. The enum is ONE TAG at file scope under the mangled name
%% `Enclosing.Name' and no class of its own; its enumerators keep their own names, as every enum's do here.
cpp_nested_enum(C, nested(base(_, [enum(N, Es)])), N, Name, enum(Name, Es)) :- atom(N), is_list(Es), atomic_list_concat([C, '.', N], Name).
cpp_nested_enum(C, nested(base(_, [enum_class(N, Es)])), N, Name, enum_class(Name, Es)) :- atom(N), is_list(Es), atomic_list_concat([C, '.', N], Name).
cpp_enum_members(enum(_, Es), Es).
cpp_enum_members(enum_class(_, Es), Es).
cpp_nested_enum_item(_, Name, _) :- '$cpp_nested_out'(Name), !.
cpp_nested_enum_item(L, Name, Spec) :- assertz('$cpp_nested_out'(Name)), cpp_trace(nested_enum(Name)),
    cpp_add_instance_items([declare(L, base([], [Spec]))]).
%% A QUALIFIED ENUMERATOR IS THE VALUE ITS OWN ENUM GIVES IT (0.126). The enumerators' table ('$ccl_enums') is keyed by the bare name, so
%% `B::X' beside `A::X' -- two enum classes, two classes' nested enums, a namespace's -- took the value of whichever the table
%% answered first, a SILENT wrong answer: `(int) B::X' printed A::X's value, `T::D::W' (an enum nested in a class T) the one of `S::D::W',
%% and a `case state::Consonant:' naming an enum nested in the class being walked reached the lowering raw (`case(scoped([state], ...))':
%% only a file-scope enum's name was asked, the nested one is `Enclosing.Name' in the tag table). libc++ 21's grapheme-cluster
%% rules switch over `__GB9c_indic_conjunct_break_state' whose `__Consonant' is also `__inCB_property::__Consonant'
%% (std::print and std::format of a string). The path names the enum (cpp_enum_path_tag/3: the class-nested one by the class being
%% walked or the class the path names, the file-scope one by its name) and the value is taken from THAT enum's own list, an
%% initializer folded with the enumerators before it substituted, as the reader gives it (ccl_declare_enumerators); an enum with an
%% initializer that does not fold is left to the table, which answers as it did. Remembered per enum and name ('$cpp_enumv'). The nested
%% enums' names are '$cpp_nenum' facts, so that a qualified name which is no enum's costs one failed lookup. `enumscope.cpp'.
cpp_enumerator(Path, N, V) :- ( cpp_class_ctx(Cx) -> true ; Cx = none ), cpp_enumerator(Cx, Path, N, V).
cpp_enumerator(Ctx, Path, N, V) :- atom(N), cpp_enum_path_tag(Ctx, Path, Tag), ( cpp_enum_value(Tag, N, V) -> true ; cpp_enum_key_name(Path, N, NK), cpp_enum_value(Tag, NK, V) ), !.
cpp_enumerator(_, Path, N, V) :- atom(N), cpp_ns_enum_tag(Path, N, NK, Tag), cpp_enum_value(Tag, NK, V), !.   % `n::y': an unscoped enum's enumerator named through its namespace (0.198, below)
cpp_enumerator(_, Path, N, V) :- atom(N), cpp_hdr_enum_tag(Path, N, Tag), cpp_enum_value(Tag, N, V), !.   % ... a HEADER's (0.201, below)
cpp_enumerator(_, Path, N, V) :- atom(N), cpp_enum_scope(Path), ccl_enum_value(N, V), !.   % the table's answer, where the enum's own list does not fold
cpp_enum_path_tag(Ctx, [E], Tag) :- atom(E), '$cpp_nenum'(E), cpp_enum_class_of(Ctx, C), cpp_class_typedef(C, E, base(_, [typedef(Tag)]), _), !.   % `state::Consonant' in a member of the class that declares `state', or of one derived from it or nested in it
cpp_enum_path_tag(_, Path, Tag) :- append(Prefix, [E], Path), Prefix = [_|_], atom(E), '$cpp_nenum'(E), ccl_last(Prefix, Q), atom(Q), cpp_class_l(Q, _), cpp_class_typedef(Q, E, base(_, [typedef(Tag)]), _), !.   % `S::D::X': the class named before the enum
cpp_enum_path_tag(_, Path, K) :- append(Prefix, [E], Path), Prefix = [_|_], atom(E), cpp_ns_key(Prefix, E, K), K \== E, ccl_tag(K, Ms), Ms \== none, ccl_is_enum_tag(Ms), !.   % `n2::Mode::Fast': a tag two namespaces declare, by its key (0.127)
cpp_enum_path_tag(_, Path, E) :- append(_, [E], Path), atom(E), ccl_tag(E, Ms), Ms \== none, ccl_is_enum_tag(Ms), !.   % a file-scope enum, its namespaces flattened away
cpp_enum_class_of(Ctx, C) :- atom(Ctx), Ctx \== none, !, C = Ctx.
cpp_enum_class_of(_, C) :- cpp_class_ctx(C).
%% `Shape::Circle', an enumerator of an UNSCOPED enum nested in the class the path names: the enumerators are the class's
%% members ([dcl.enum]/11), and the enum is the nested one whose list holds the name (0.127; the path names no enum)
cpp_enum_class_tag(Path, N, Tag) :- append(_, [Q], Path), atom(Q), catch(cpp_class_l(Q, _), _, fail), '$cpp_nenum'(E),
    catch(cpp_class_typedef(Q, E, base(_, [typedef(Tag)]), _), _, fail), atom(Tag), ccl_tag(Tag, Ms), is_list(Ms), memberchk(enumerator(N, _), Ms), !.
cpp_enum_key_name(Path, N, NK) :- append(Prefix, [_], Path), Prefix = [_|_], cpp_ns_key(Prefix, N, NK), NK \== N.   % ... its enumerator renamed with it (cpp_qualify_enum)
%% `n::y', AN ENUMERATOR OF AN UNSCOPED ENUM OF THE PROGRAM'S NAMESPACE named through the namespace (0.198; [namespace.qual],
%% [dcl.enum]/10: an unscoped enum's enumerators are names of the enum's scope): the enum is the one of that namespace -- its tag
%% recorded with the namespace's named path ('$cpp_type_ns', cpp_ns_resolve) -- whose list holds the name, or its key where two
%% namespaces declare it (cpp_ns_key, cpp_qualify_enum). No road took it: `enum C { c = n::y + 1 };' was refused
%% `enumerator_not_constant(c)', the path naming no enum
cpp_ns_enum_tag(Path, N, NK, Tag) :- is_list(Path), Path = [_|_], cpp_ns_named_path(Path, NP0), delete(NP0, global, NP), NP \== [],
    ( cpp_ns_key(Path, N, NK0) -> NK = NK0 ; NK = N ), '$cpp_type_ns'(NK, NP), '$cpp_type_ns'(Tag, NP), atom(Tag),
    ccl_tag(Tag, Ms), is_list(Ms), ccl_is_enum_tag(Ms), \+ ccl_scoped_enum(Tag), memberchk(enumerator(NK, _), Ms), !.
%% A LIBRARY HEADER'S UNSCOPED ENUMERATOR NAMED THROUGH ITS NAMESPACE (0.201): `regex_constants::ECMAScript' in a case label
%% of <regex>, inside basic_regex, whose class has a static member of that name -- the name flattened into the class's scope
%% and the label reached the lowering raw. The enum is the one the table of values names for the enumerator, its tag placed
%% by the header index in a namespace whose named path ends with the path's, and the path names no class.
cpp_hdr_enum_tag(Path, N, Tag) :- is_list(Path), Path = [_|_], forall(member(S, Path), ( atom(S) ; S = inline(_) )),
    cpp_ns_named_path(Path, Q0), delete(Q0, global, Q), Q \== [],
    nb_current('$ccl_enums', L), ccl_enumerator_tag(N, L, Tag), atom(Tag), \+ ccl_scoped_enum(Tag),
    ( catch('$cpp_hdr_ns'(Tag, P0), _, fail) -> true ; catch('$cpp_hdr_ast_ns'(Tag, P0), _, fail) ), is_list(P0), cpp_ns_named_path(P0, NP), append(_, Q, NP),
    \+ catch(cpp_scope_class(Path, _), _, fail), !.
cpp_enum_value(Tag, N, V) :- '$cpp_enumv'(Tag, N, V0), !, V = V0.
cpp_enum_value(Tag, N, V) :- \+ '$cpp_enumv'(Tag, '$walked', _), ccl_tag(Tag, Es), is_list(Es), ccl_is_enum_tag(Es),   % the whole list once: every enumerator that folds is remembered, the rest are the table's
    ( nb_current('$cpp_enum_walking', W0) -> true ; W0 = [] ), \+ memberchk(Tag, W0),   % never an enum's walk inside its own (0.198: an initializer names another enum's enumerators, cpp_enum_quals/2)
    nb_setval('$cpp_enum_walking', [Tag|W0]), ( catch(cpp_enum_walk(Es, 0, [], Pairs), _, fail) -> nb_setval('$cpp_enum_walking', W0) ; nb_setval('$cpp_enum_walking', W0), fail ),
    cpp_enum_remember(Pairs, Tag), assertz('$cpp_enumv'(Tag, '$walked', 0)), '$cpp_enumv'(Tag, N, V0), !, V = V0.
cpp_enum_walk([], _, Seen, Seen) :- !.
cpp_enum_walk([enum_base(_)|Es], K, Seen, Pairs) :- !, cpp_enum_walk(Es, K, Seen, Pairs).
cpp_enum_walk([enumerator(M, E)|Es], K, Seen, Pairs) :-
    (   E == none -> V0 = K
    ;   cpp_replace_ids(E, Seen, E1), cpp_enum_quals(E1, E2), catch(ccl_const_eval(E2, V1), _, fail), integer(V1) -> V0 = V1 ), !,
    K1 is V0 + 1, cpp_enum_walk(Es, K1, [M-int(V0)|Seen], Pairs).
cpp_enum_walk(_, _, Seen, Seen).   % an initializer that does not fold ends the walk: the enumerators before it stand
%% AN INITIALIZER THAT NAMES ANOTHER ENUM'S ENUMERATOR BY ITS QUALIFIED NAME folds it as its own enum gives it (0.198):
%% libc++ 21's `_PartialOrdResult::__less = static_cast<signed char>(_OrdResult::__less)' ended the walk, and the name was the
%% table's, right only by the order of <compare>'s two enums
cpp_enum_quals(scoped(P, N), int(V)) :- atom(N), is_list(P), catch(cpp_enumerator(P, N, V), _, fail), !.
cpp_enum_quals(T, T1) :- compound(T), !, T =.. [F|Xs], cpp_enum_quals_list(Xs, Ys), T1 =.. [F|Ys].
cpp_enum_quals(T, T).
cpp_enum_quals_list([], []).
cpp_enum_quals_list([X|Xs], [Y|Ys]) :- cpp_enum_quals(X, Y), cpp_enum_quals_list(Xs, Ys).
cpp_enum_remember([], _).
cpp_enum_remember([M-int(V)|Ps], Tag) :- assertz('$cpp_enumv'(Tag, M, V)), cpp_enum_remember(Ps, Tag).
cpp_note_nested_enum(N) :- ( '$cpp_nenum'(N) -> true ; assertz('$cpp_nenum'(N)) ).
%% THE ENCLOSING CLASS'S OWN REGISTRATION CAN ASK FOR A NESTED CLASS: declaring vector's members resolves types that
%% instantiate templates, whose bodies call vector's members, whose bodies name `_ConstructTransaction' -- all before
%% cpp_nested_classes, which comes last so a nested class's own members see the enclosing one registered. So the name
%% is recorded when the TYPE is (cpp_nested_names) and the class is registered on the first ask, once ('$cpp_nesting').
cpp_nested_ready(Name) :- '$cpp_nested'(Name, L, C, N, M), \+ ( nb_getval('$cpp_nesting', Ns), memberchk(Name, Ns) ), !,
    nb_getval('$cpp_nesting', Ns0), nb_setval('$cpp_nesting', [Name|Ns0]),
    cpp_nested_name(M, N, NMs), NMs \== none,
    (   catch(cpp_nested_class(L, C, N, NMs, M), E, ( nb_setval('$cpp_nesting', Ns0), throw(E) ))   % IN PROGRESS while it registers, and no longer after: a registration a candidate's check abandons must not leave the name marked, or every later ask fails silently (0.69's rule)
    ->  nb_setval('$cpp_nesting', Ns0)
    ;   nb_setval('$cpp_nesting', Ns0), fail ).
%% A NESTED UNION is a nested TYPE and no class of its own: it has no methods and no constructors, and its LAYOUT
%% must stay a union's. Its name resolves inside the enclosing class as a nested class's does (cpp_nested_names),
%% and the union itself is emitted once at file scope under the mangled name. libc++'s `basic_string' keeps its
%% short and its long representation in one -- `union __rep' -- and hands it to a template as an argument, where
%% the name did not resolve and the instance came out with no members at all.
%% A NESTED UNION THAT DECLARES A CONSTRUCTOR OR A METHOD is a CLASS whose members share storage -- libc++'s
%% `basic_string::__rep' has four constructors and is how a string is short or long -- so it goes the class's whole
%% road ('$cpp_union' spells its tag and its declaration a union's; ccl_is_union_tag is the one test). One with
%% only data members is a plain union: a type of the enclosing class and nothing more, emitted once.
cpp_nested_union_class(nested(base(_, [union(_, Ms)]))) :- cpp_union_class_members(Ms).
cpp_nested_class(L, C, N, NMs, M) :- M = nested(base(_, [union(_, _)])), \+ cpp_nested_union_class(M), !,
    atomic_list_concat([C, '.', N], Name),
    (   '$cpp_nested_out'(Name) -> true
    ;   assertz('$cpp_nested_out'(Name)), cpp_trace(nested_union(Name)), cpp_encloses(Name, C),
        cpp_isolated(cpp_in_class(C, ( cpp_member_types(NMs, NMs1), ccl_note_tag(Name, NMs1),   % in the tag table AT ONCE: a template argument names it before the unit's items are noted
                       cpp_item(declare(L, base([], [union(Name, NMs1)])), Items) ))),
        cpp_add_instance_items(Items) ).
cpp_nested_class(L, C, N, NMs, M) :- M = nested(base(_, [union(_, _)])), !, atomic_list_concat([C, '.', N], Name),
    (   cpp_class_l(Name, _) -> true
    ;   ( '$cpp_union'(Name) -> true ; assertz('$cpp_union'(Name)) ), cpp_encloses(Name, C), cpp_trace(nested_union_class(Name)),
        \+ \+ ( cpp_isolated(( cpp_register_class(L, Name, [], NMs), cpp_item(declare(L, base([], [class(union, Name, [], NMs)])), Items) )),
                cpp_add_instance_items(Items) ) ).
cpp_nested_class(L, C, N, NMs, M) :-
    atomic_list_concat([C, '.', N], Name), cpp_trace(nested(Name)),
    (   cpp_class_l(Name, _) -> true
    ;   ( M = nested(base(_, [class(K0, _, Bs0, _)])) -> K = K0, Bases = Bs0 ; K = struct, Bases = [] ),
        cpp_encloses(Name, C),
        ( '$cpp_lazy_c'(C) -> cpp_lazy_instance(yes, Name) ; '$cpp_lazy_p'(C) -> cpp_lazy_instance(prog, Name) ; true ),   % A NESTED CLASS OF A LAZY CLASS IS LAZY: its members come as they are used. Registered eagerly, basic_ostream's `sentry' walked its constructor, which calls flush(), whose body declares a sentry -- the class still mid-registration, so the ask failed and the local was initialized as a plain value
        \+ \+ ( cpp_isolated(( cpp_register_class(K, L, Name, Bases, NMs), cpp_item(declare(L, base([], [class(K, Name, Bases, NMs)])), Items) )),   % inside `\+ \+', as an instantiation is (0.68): `__tree_deleter''s registration left 148 MB behind
                cpp_add_instance_items(Items) ) ).
%% which class holds a nested one: its typedefs are in scope inside, INCLUDING the ones it inherits, so the lookup
%% goes to the enclosing class itself (which walks its own bases) rather than a copy of its direct entries
cpp_encloses(Nested, C) :- ( '$cpp_encl'(Nested, _) -> true ; asserta('$cpp_encl'(Nested, C)) ).
cpp_register_class_(K, L, C, Bases0, Ms) :-
    forall(( member(method(_, Qs, _, N, _, _, _), Ms), memberchk(static, Qs), atom(N), \+ '$cpp_sfn_pre'(C, N) ), assertz('$cpp_sfn_pre'(C, N))),   % its static functions' names before its record: a member's type may call one (cpp_type_names_call/2, 0.201)
    cpp_primary_first(C, Bases0, Bases),
    ( Bases = [base(virtual(_), _)|_] -> ( '$cpp_vbase'(C) -> true ; assertz('$cpp_vbase'(C)) ) ; true ),
    (   Bases = [] -> Base = none
    ;   Bases = [base(_, B0)] -> cpp_base_name(B0, Base), cpp_path_holder(C, Bases, Base)
    ;   cpp_extra_bases(L, C, Bases, Base) ),

    ( cpp_split_members(Ms, Data00, Statics, Defaults) -> true ; cpp_refuse(L, members_not_split(C)) ),
    ( cpp_member_types_now(C, Data00, Data0a, Later) -> true ; cpp_refuse(L, member_types(C)) ),   % each member's type resolved under the class's own typedefs (`pointer __begin_;'), but one that names a call (below)
    ( '$cpp_vbase'(C), \+ '$cpp_vprim'(C, _) -> cpp_slots(none, Base, Ms, C, Slots) ; cpp_slots(Base, none, Ms, C, Slots) ),   % over a VIRTUAL base the table is the class's own: the shared base keeps its own pointer inside its sub-object, and an override of its functions is a slot of the class's own table (0.177) -- but a NEARLY EMPTY one is the primary, its slots the table's first (0.174)
    (   ( Slots \== [], ( '$cpp_vbase'(C) ; \+ cpp_has_table(Base) ) ; '$cpp_vbase'(C) ; '$cpp_lvb'(C, _, _), \+ cpp_has_table(Base) )      % the class introduces the table: its pointer is a member of its own -- and a class over a VIRTUAL base always has one (0.160): its table carries the base's offset
    ->  cpp_vt_tag(C, VT), VPtr = [member(ptr([], base([], [struct(VT, none)])), '$vptr', none)]
    ;   VPtr = [] ),
    append(VPtr, Data0a, DataA), cpp_class_put(C, cls(Base, DataA, Ms, Statics, Defaults, Slots)),
    (   Later == no -> Data = DataA
    ;   cpp_declare_members(Ms, C), cpp_declare_statics(Statics, C),   % the class's functions and statics declared first, as a typedef resolved after the registration finds them
        ( cpp_member_types(Data0a, Data0) -> true ; cpp_refuse(L, member_types(C)) ), append(VPtr, Data0, Data),
        retractall('$cpp_cls'(C, _)), retractall('$cpp_clsl'(C, _)), retractall('$cpp_sfn'(C, _)), retractall('$cpp_decl'(C, _, _, _)), cpp_class_put(C, cls(Base, Data, Ms, Statics, Defaults, Slots)) ),   % the record REPLACED
    cpp_note_claims(C),   % the virtual bases a base sub-object takes as its primary (0.174)
    ( '$cpp_vbase'(C), \+ '$cpp_vprim'(C, _), Base \== none, cpp_has_table(Base), \+ cpp_empty_class(Base), \+ '$cpp_poly_extra'(C, Base, '$base') -> assertz('$cpp_poly_extra'(C, Base, '$base')) ; true ),   % ... one with a table and no virtual function too, a table of virtual bases' offsets (0.235): it kept its own, whose offsets are its complete object's
    cpp_inherit_poly_extras(C, Base),   % A POLYMORPHIC VIRTUAL BASE is a sub-object with a table of its own (0.110): this class's SECONDARY table goes in it, the base's slots with this class's overriders behind thunks, the offset to the complete object and this class's type_info -- it had kept the base's own table, so `pa->f()' through the base called the base's f and typeid named the base
    cpp_note_nontrivial(C, Base, Data, Ms, Slots),
    ( cpp_layout_pod(K, C, Bases, Ms, Data, Defaults, Slots) -> true ; '$cpp_nonpod'(C) -> true ; assertz('$cpp_nonpod'(C)) ),
    cpp_base_layout(C, Base, Data, Data1), cpp_align_tag(C, Ms, Data1, Data20), cpp_pod_mark(C, Data20, Data2),
    cpp_empty_vbases_laid(L, C, Data2),   % an empty virtual base this model cannot move refused by name (0.235)
    ( '$cpp_union'(C) -> Tagged = [union_tag|Data2] ; Tagged = Data2 ), ccl_note_tag(C, Tagged),
    ( cpp_nv_form(C, Data2, NVData) -> cpp_nv_tag(C, NV), ccl_note_tag(NV, NVData) ; true ),   % the struct (or UNION) it becomes, in the table at once: its members have types while its methods are walked
    cpp_in_class(C, ( cpp_with_sigdecl(C, cpp_declare_members(Ms, C)), cpp_declare_statics(Statics, C) )).   % its signatures name instances of its own template as names only (cpp_sig_waits, 0.136)
