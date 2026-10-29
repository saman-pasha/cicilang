%% ccl_cpp_virtual.pl -- the tables and the type information: the vtable prefix, the final overriders, RTTI,
%% dynamic_cast, multiple polymorphic bases, the construction tables and the VTT, the thunks, the vbase and vcall
%% offsets, the destructors of a diamond's paths. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its
%% rules as they stood there, in their order.

cpp_member_path_class(Path, C) :- Path = [_, _|_], catch(cpp_scope_class(Path, C), error(not_lowered(_), _), fail), atom(C), cpp_class_l(C, _), !.
%% A LAZY POLYMORPHIC CLASS emitted EVERY member, where only the ones its table names need a body: libc++'s
%% basic_ostream, basic_ios, ios_base, basic_streambuf and every facet carry a virtual destructor, and
%% `std::cout << "hello"' walked 234 members -- operator<<(double), swap, basic_istream's whole input side --
%% none of which it uses. Its own virtual methods, the ones filling a slot, are emitted with the class (a base's
%% implementation came with the base; the destructor takes cpp_own_dtor's lazy road) and NOTED, so a use of one
%% does not emit it again; the rest come as they are used, as any lazy class's do.
cpp_slot_members(Slots, Ms, Virt) :-
    findall(M, ( member(M, Ms), M = method(_, Qs, _, N, Ps, _, _), length(Ps, A), cpp_slots_of(Slots, N, A, [_|_]), \+ memberchk(pure, Qs) ), Virt).
cpp_note_members(C, Ms) :- forall(( member(M, Ms), cpp_member_mangled(C, M, Name), \+ cpp_instance_done(Name) ), cpp_instance_note(Name, C)).
%% ... and IN PROGRESS while their bodies are walked, as a lazy member is (cpp_make_lazy): a slot's body that calls
%% another slot -- basic_streambuf's uflow calls underflow -- met it not yet noted and emitted it a second time
%% through the lazy road, and LLVM refused the redefinition. Noted once the batch is done; a throw clears them.
cpp_slot_fns(C, Base, Defaults, Slots, Ms, Fns) :-
    cpp_slot_members(Slots, Ms, Virt), findall(N, ( member(M, Virt), cpp_member_mangled(C, M, N) ), Names),
    nb_getval('$cpp_making', M0), append(Names, M0, M1), nb_setval('$cpp_making', M1),
    (   catch(cpp_in_class(C, cpp_member_fns(Virt, C, Base, Defaults, Fns)), E, ( nb_setval('$cpp_making', M0), throw(E) ))
    ->  nb_setval('$cpp_making', M0), cpp_note_members(C, Virt)
    ;   nb_setval('$cpp_making', M0), fail ).
%% the table's struct: a function pointer per slot, over the owner's pointer; the table: the class's implementations
cpp_vt_struct(L, C, Slots, declare(L, base([], [struct(VT, Ms)]))) :-
    cpp_vt_tag(C, VT), cpp_vt_owner(C, Owner), cpp_this_type(Owner, [], ThisT), cpp_this_type(Owner, [], [dying], DyingT),
    findall(member(ptr([], fn(Ret, [param(TT, this)|Ps], V)), SN, none), ( member(slot(M, K, Ret, Ps, V), Slots), cpp_slot_name(M, K, SN), ( memberchk(M, ['$dtor', '$dtor_del']) -> TT = DyingT ; TT = ThisT ) ), Ms).
%% THE ITANIUM VTABLE PREFIX (0.108): the table is `{ offset-to-top, &typeinfo, { slots } }' and an object's pointer
%% holds the address of the slots, so `vptr[-1]' is the dynamic type's type_info -- which typeid and libc++abi's
%% __dynamic_cast read -- and `vptr[-2]' the offset to the complete object (0 here: single inheritance)
cpp_vtable(L, C, Slots, [declare(L, base([], [struct(VTP, VMs)])),
                         declaration(L, static, base([], [struct(VTP, none)]), [var(Name, base([], [struct(VTP, none)]), init(VItems))])]) :-
    cpp_vt_tag(C, VT), atom_concat(VT, p, VTP), cpp_vtable_name(C, Name),
    PMs = [member(base([], [long]), '$off', none), member(ptr([], base([const], [void])), '$ti', none), member(base([], [struct(VT, none)]), '$vt', none)],
    PItems = [item([], int(0)), item([], TI), item([], init(Items))],
    ( cpp_vbase_offsets(C, C, none, VBOs) -> cpp_vbo_fields(VBOs, 0, VBMs, VBItems), append(VBMs, PMs, VMs), append(VBItems, PItems, VItems) ; VMs = PMs, VItems = PItems ),   % one vbase offset a slot (0.171)
    ( catch(cpp_rtti_chain(C, Ch), _, fail) -> TI = rtti(Ch) ; TI = nullptr ),
    findall(item([], E)-Fs, ( member(slot(M, K, Ret, Ps, V), Slots), cpp_primary_entry(L, C, M, K, Ret, Ps, V, E, Fs) ), EFs),
    findall(I, member(I-_, EFs), Items), findall(F, ( member(_-Fs, EFs), member(F, Fs) ), PThunks), nb_setval('$cpp_pthunks', PThunks).
%% THE FINAL OVERRIDER FROM ANOTHER PATH OF A DIAMOND ([class.virtual]/2, 0.110): a method of the shared virtual base
%% that the primary chain leaves as it is and a later path overrides is that path's, reached by a thunk moving `this'
%% to the path's sub-object -- `C::g' through `A *' or `B *' in `struct D : B, C'
cpp_final_impl(C, M, K, Impl, Sub) :- \+ memberchk(M, ['$dtor', '$dtor_del']),
    cpp_slot_impl(C, M, K, I0), cpp_vbases_of(C, Vs), member(V, Vs), cpp_slot_impl(V, M, K, I0),
    '$cpp_base_slot'(C, E, Sub), '$cpp_nv_base'(C, E), cpp_slot_impl(E, M, K, IE), IE \== I0, !, Impl = IE.
cpp_final_impl(C, M, K, Impl, Sub) :- \+ memberchk(M, ['$dtor', '$dtor_del']), '$cpp_vb_holder'(C, _),   % ... and where no first-base chain reaches the overrider, the general search (0.171)
    cpp_final_overrider(C, M, K, Impl-X), \+ cpp_slot_impl(C, M, K, Impl), !,
    ( '$cpp_base_slot'(C, X, Sub) -> true ; atomic_list_concat(['$fo', X], '.', Sub) ).
%% THE FINAL OVERRIDER OF A SLOT IN A CLASS OVER SEVERAL VIRTUAL BASES ([class.virtual]/2; 0.171): the class's own
%% implementation, else the one among its bases' -- the first and the later bases alike -- that no other dominates: an
%% implementation declared in a class that another candidate's class derives from is no final overrider. The first-base
%% chain of cpp_slot_impl/4 does not reach a virtual base that a later base holds: in `D : H1, H2' over `H1 : Q1, R1' and
%% `H2 : Q2, R2' (`R1' and `R2' over `virtual W', `Q1' and `Q2' over `virtual A'), the `fw' of W that `R2' overrides was
%% W's own in every table of D -- a virtual call through `W *', through `R1 *' and in R2's constructor reached `W::fw'.
cpp_final_overrider(C, M, K, Impl-X) :- cpp_class(C, cls(B, _, Ms, _, _, _)),
    (   cpp_slot_method(C, Ms, M, K, Qs, Ps) -> \+ memberchk(pure, Qs), cpp_mangle_q(C, M, Qs, Ps, Impl), X = C
    ;   ( B == none -> Bs0 = [] ; Bs0 = [B] ), ( '$cpp_extra'(C, Es) -> append(Bs0, Es, Bs) ; Bs = Bs0 ),
        findall(F, ( member(Y, Bs), cpp_final_overrider(Y, M, K, F) ), Fs0), sort(Fs0, Fs),
        member(Impl-X, Fs), \+ ( member(_-X2, Fs), X2 \== X, cpp_derives(X2, X) ), ! ).
cpp_primary_entry(L, C, '$dtor_del', _, _, _, _, id(D0), Fs) :- cpp_d0_fn(L, C, D0, Fs), !.   % THE DELETING DESTRUCTOR (0.202): the class's own D0, made with its table (cpp_d0_fn/4)
cpp_primary_entry(L, C, M, K, Ret, Ps, V, id(TN), [Fn]) :- cpp_final_impl(C, M, K, IE, Sub), !,
    cpp_slot_name(M, K, SN), atomic_list_concat([C, '.thunkp', Sub, '.', SN], TN), cpp_vt_owner(C, Owner), cpp_this_type(Owner, [], ThisT),
    cpp_mk_thunk(L, TN, IE, Ret, Ps, V, ThisT, cast(ptr([], base([], [typedef(C)])), id(this)), Fn).   % the complete object: the call's own conversion moves it to the path
cpp_primary_entry(L, C, M, K, Ret, Ps, V, id(TN), [Fn]) :- cpp_vprim_far(C, C, [], M, K, _, _), !,   % a nearly empty primary virtual base's own slot where another sub-object holds the base (0.174): through the complete object
    cpp_slot_impl(C, M, K, Impl), cpp_slot_name(M, K, SN), atomic_list_concat([C, '.thunkpv.', SN], TN), cpp_vt_owner(C, Owner), cpp_this_type(Owner, [], ThisT),
    cpp_mk_thunk(L, TN, Impl, Ret, Ps, V, ThisT, cast(ptr([], base([], [typedef(C)])), id(this)), Fn).
cpp_primary_entry(_, C, M, K, _, _, _, E, []) :- ( cpp_slot_def(C, M, K, Impl) -> E = id(Impl) ; E = nullptr ).
cpp_mk_thunk(L, TN, Impl, Ret, Ps, V, TT, Adj, function(L, static, Ret, TN, [param(TT, this)|Ps1], V, Body)) :-
    cpp_thunk_params(Ps, 1, Ps1, Ids), Call = call(id(Impl), [Adj|Ids]),
    ( ccl_resolve_type(Ret, base(_, [void])) -> Body = block([expr(L, Call)]) ; Body = block([return(L, Call)]) ),
    ( '$cpp_libfn'(TN) -> true ; assertz('$cpp_libfn'(TN)) ).
%% A SLOT OF A NEARLY EMPTY PRIMARY VIRTUAL BASE that the table's sub-object N (at NHops in C) leaves to the base itself, where the
%% base does not share N's table pointer -- another sub-object took it as its primary, or the holder lays it apart (0.174): the
%% entry is a thunk that moves `this' to the base, as clang's virtual thunk does through its vcall offset
cpp_vprim_far(C, N, NHops, M, K, I, IH) :- \+ memberchk(M, ['$dtor', '$dtor_del']), cpp_chain_vprim(N, I),
    cpp_class_l(I, cls(_, _, _, _, ISlots)), memberchk(slot(M, K, _, _, _), ISlots), cpp_slot_def(I, M, K, Impl), cpp_slot_impl(N, M, K, Impl),
    cpp_vbase_loc(C, I, IH), ( cpp_data_member(N, '$vptr', H) -> true ; H = [] ), append(NHops, H, NP), IH \== NP, !.
cpp_chain_vprim(N, I) :- '$cpp_vprim'(N, I), !.
cpp_chain_vprim(N, I) :- cpp_primary_of(N, P), cpp_chain_vprim(P, I).
cpp_far_adj(C, FH, I, IH, cast(ptr([], base([], [typedef(I)])), bin('+', cast(ptr([], base([], [char])), id(this)), bin('-', IO, FO)))) :-
    cpp_hops_offset(C, FH, none, FO), cpp_hops_offset(C, IH, none, IO).   % the object's own address an offset of 0 (0.176: it had no designator, and the entry was dropped)
%% whether a virtual base taken as a primary at CH shares the table pointer of the sub-object P at Hops
cpp_vptr_shared(P, Hops, CH) :- ( cpp_data_member(P, '$vptr', H) -> true ; H = [] ), append(Hops, H, CH), !.
%% ---- RTTI (0.108; refused by name since 0.86) ------------------------------------------------------------------
%% The PROGRAM's typeid and dynamic_cast, with libc++ still configured without RTTI (its own bodies use none): a
%% class's type_info object is the Itanium ABI's -- `__class_type_info' for a class with no base, `__si_class_type_info'
%% over its base's for single inheritance, each pointing at libc++abi's vtable of that kind -- named `_ZTI<name>',
%% its name `_ZTS<name>' one linkonce string per type, so libc++'s type_info (a unique name pointer) compares them.
%% The chain is the class's key and its bases' up to the root, which the lowering spells (ir_rtti_emit).
cpp_rtti_chain(C, vmi(N, C, WBs)) :- '$cpp_extra'(C, Es), Es \== [], !, cpp_class_l(C, cls(B, Data, _, _, _)), cpp_rtti_name(C, N),   % SEVERAL BASES: `__vmi_class_type_info', each base with its offset (0.108)
    ( '$cpp_vprim'(C, _) -> cpp_lvb_off(C, B, VO1), S1 = virtual(VO1) ; cpp_vbase_dynamic(C), \+ cpp_empty_class(B) -> S1 = virtual ; \+ cpp_empty_class(B), memberchk(member(_, '$vptr', _), Data) -> S1 = '$base' ; S1 = none ),   % the first base behind the class's own table pointer (0.135) -- reached through the table where it is virtual (0.172), its offset's own place where it is a nearly empty primary (0.174)
    cpp_rtti_chain(B, BCh), findall(b(ECh, S), ( member(E, Es), cpp_rtti_chain(E, ECh), ( '$cpp_lvb'(C, E, _) -> cpp_lvb_off(C, E, VO), S = virtual(VO) ; '$cpp_base_slot'(C, E, S0) -> S = S0 ; S = none ) ), Bs),   % a later VIRTUAL base flagged virtual, its offset at its slot (0.172)
    ( '$cpp_vprim_ind'(C, B) -> WBs = Bs ; '$cpp_primary_moved'(C, K), length(Front, K), append(Front, Back, Bs) -> append(Front, [b(BCh, S1)|Back], WBs) ; WBs = [b(BCh, S1)|Bs] ).   % in the order WRITTEN, as clang lists them (0.174): a primary base moved first goes back to its place, a primary further in none (0.176)
cpp_rtti_chain(C, vmi(N, C, [b(BCh, S)])) :- '$cpp_vbase'(C), !, cpp_class_l(C, cls(B, _, _, _, _)), cpp_rtti_name(C, N),   % over a VIRTUAL base (0.110): the base lies LAST here, so it is a vmi entry at its offset -- flagged public, not virtual: with one path to the base its place in every complete object is this layout's, which is what the offset says
    cpp_rtti_chain(B, BCh), ( cpp_empty_class(B) -> S = none ; '$cpp_vprim'(C, _) -> cpp_lvb_off(C, B, VO), S = virtual(VO) ; cpp_vbase_dynamic(C) -> S = virtual ; S = '$base' ).   % reached through the table: flagged VIRTUAL, its offset read from the object's table, so a diamond's paths name ONE sub-object to libc++abi
cpp_rtti_chain(C, vmi(N, C, [b(BCh, '$base')])) :- cpp_class_l(C, cls(B, Data, _, _, _)), B \== none, \+ '$cpp_vbase'(C), memberchk(member(_, '$vptr', _), Data), \+ cpp_empty_class(B), !,   % ONE BASE NOT AT OFFSET 0, behind the class's own table pointer (0.135): `__si_class_type_info' is for a base at 0, so a vmi one with the offset, as clang has it
    cpp_rtti_name(C, N), cpp_rtti_chain(B, BCh).
cpp_rtti_chain(C, [N|Rest]) :- cpp_class_l(C, cls(B, _, _, _, _)), \+ '$cpp_vbase'(C), cpp_rtti_name(C, N),
    ( B == none -> Rest = [] ; cpp_rtti_chain(B, Rest) ).
cpp_rtti_name(C, N) :- \+ sub_atom(C, _, _, _, '.'), \+ cpp_lib_class(C), \+ catch('$cpp_type_ns'(C, _), _, fail), !, ccl_byte_length(C, K), atomic_list_concat([K, C], N).   % a class of the program at file scope: `1A', as clang spells it; in a namespace of its own the mangler's (0.180: `N2ns1AE', which was `1A')
cpp_rtti_name(C, N) :- once(catch(cpp_ita_type(base([], [typedef(C)]), [], _, T, _), _, fail)), atom(T), !, N = T.
cpp_rtti_name(C, N) :- atom_codes(C, Cs), findall(X, ( member(X, Cs), X \== 0'. ), Cs1), atom_codes(A, Cs1), ccl_byte_length(A, K), atomic_list_concat([K, A], N).
%% the type_info of a TYPE: a class's own, a builtin's the one libc++abi exports (`_ZTIi')
cpp_rtti_of_type(T0, E) :- ccl_unref(T0, T1), cpp_nullptr_param(T1), !, E = rtti(ext('_ZTIDn')).   % STD::NULLPTR_T, libc++abi's `_ZTIDn' (0.180): resolved, its typedef `decltype(nullptr)' was a `void *', `Pv'
cpp_rtti_of_type(T0, E) :- ccl_unref(T0, T1), ccl_resolve_type(T1, T2), cpp_strip_top(T2, T),
    (   cpp_class_of_type(T, C), cpp_lib_class(C), cpp_polymorphic(C), cpp_rtti_name(C, N) -> atom_concat('_ZTI', N, Sym), E = rtti(ext(Sym))   % a LIBRARY class's type_info is the one libc++ exports (`_ZTISt13runtime_error'), a POLYMORPHIC one's, whose key function the library defines; one with no table is emitted where it is used, as clang does (0.179: `_ZTINSt3__17complexIdEE', which no library exports, failed the link)
    ;   cpp_class_of_type(T, C) -> cpp_rtti_chain(C, Ch), E = rtti(Ch)
    ;   T = base(_, [Sp]), ( Sp = struct(Tag, _) ; Sp = union(Tag, _) ), atom(Tag) -> cpp_rtti_tag_name(Tag, N), E = rtti([N])   % a plain struct or union: a root of its own, named as clang names it (0.180; a plain union's tag is a union's since 0.201, `typeid' of it was refused)
    ;   T = base(_, S), memberchk('_Complex', S) -> cpp_complex_code(S, Code), E = rtti(fund(Code))   % A COMPLEX TYPE's (0.179): `_ZTICd', which no library exports, emitted as clang emits it -- it was the real type's, `_ZTId'
    ;   T = ptr(_, base(Q, S)), memberchk('_Complex', S) -> cpp_complex_code(S, Code), cpp_ptr_cv(Q, CV, F), atomic_list_concat(['P', CV, Code], N), E = rtti(pointer(N, F, fund(Code)))   % ... and a pointer to one, `_ZTIPKCd'
    ;   T = base(_, S), cpp_mangle_basic(S, Code) -> ( cpp_abi_fundamental(Code) -> atom_concat('_ZTI', Code, Sym), E = rtti(ext(Sym)) ; E = rtti(fund(Code)) )   % a builtin's, libc++abi's, else emitted (0.180): `_ZTIDB37_', `_ZTIDF16_'
    ;   T = ptr(_, base(Q, S)), \+ memberchk(volatile, Q), cpp_mangle_basic(S, Code), cpp_abi_fundamental(Code) -> ( memberchk(const, Q) -> atomic_list_concat(['_ZTIPK', Code], Sym) ; atomic_list_concat(['_ZTIP', Code], Sym) ), E = rtti(ext(Sym))   % libc++abi's, a plain or a const pointee's (a volatile one's is emitted, below, 0.180: `volatile int *' named `_ZTIPi')
    ;   T = ptr(_, PT), PT = base(Q, _), cpp_rtti_pointee(PT, PN, PI) -> cpp_ptr_cv(Q, CV, F), atomic_list_concat(['P', CV, PN], N), E = rtti(pointer(N, F, PI))   % A POINTER TO A CLASS or a plain struct (0.179): `_ZTIP1A', `_ZTIPKNSt3__17complexIdEE', over the class's own, as clang emits it -- it was refused
    ;   cpp_rtti_other(T, X) -> E = rtti(X)   % an enum, an array, a function, a pointer to member, a pointer to any other type (0.180)
    ;   cpp_refuse(0, typeid_of(T)) ).
%% THE TYPE INFORMATION OF EVERY OTHER TYPE (0.180), as clang emits it, `linkonce_odr', its name the mangler's spelling of
%% the type (cpp_rtti_mangled/2): an enum's `__enum_type_info' (`5Color'), an array's `__array_type_info' (`A3_i'), a
%% function's `__function_type_info' (`FidE'), a pointer to member's `__pointer_to_member_type_info' over the member's type
%% and its class's (`M1Ai', `M1AFiiE'), a vector's `__fundamental_type_info' (`Dv4_i'), a pointer to any other type
%% `__pointer_type_info' over its pointee's, the pointee's cv in its flags (`PPi', `PKPKc', `P5Color', `PVi'): `typeid' of
%% each was refused, `typeid_of', and an enum could not be thrown or caught
cpp_rtti_other(T, simple(enum, N)) :- T = base(_, [E]), ( E = enum(_, _) ; E = enum_class(_, _) ), !, cpp_rtti_mangled(T, N).
cpp_rtti_other(T, simple(array, N)) :- T = arr(_, _), !, cpp_rtti_mangled(T, N).
cpp_rtti_other(T, simple(function, N)) :- T = fn(_, _, _), !, cpp_rtti_mangled(T, N).
cpp_rtti_other(T, fund(N)) :- T = base(_, [vec(_, _, _)]), !, cpp_rtti_mangled(T, N).
cpp_rtti_other(T, memptr(N, F, PI, CI)) :- T = memptr(C, _, MT), atom(C), !, cpp_rtti_mangled(T, N), cpp_pointee_cv(MT, F, MT1),
    cpp_rtti_of_type(MT1, rtti(PI)), cpp_rtti_of_type(base([], [typedef(C)]), rtti(CI)).
cpp_rtti_other(T, pointer(N, F, PI)) :- T = ptr(_, PT0), cpp_rtti_mangled(T, N), cpp_pointee_cv(PT0, F, PT), cpp_rtti_of_type(PT, rtti(PI)).
cpp_rtti_mangled(T, N) :- once(catch(cpp_ita_type(T, [], _, N, _), _, fail)), atom(N).
cpp_pointee_cv(base(Q, S), F, base([], S)) :- !, cpp_ptr_cv(Q, _, F).
cpp_pointee_cv(ptr(Q, X), F, ptr([], X)) :- !, cpp_ptr_cv(Q, _, F).
cpp_pointee_cv(T, 0, T).
%% the builtin types whose type information libc++abi exports, and a pointer and a pointer to const to each (18, 21, 22)
cpp_abi_fundamental(C) :- memberchk(C, [v, b, c, a, h, s, t, i, j, l, m, x, y, n, o, f, d, e, g, w, 'Ds', 'Di', 'Du', 'Dn', 'Dh']).
cpp_complex_code(S, Code) :- ccl_delete_one(S, '_Complex', S0), ( S0 == [] -> S1 = [double] ; S1 = S0 ), cpp_mangle_basic(S1, C0), atom_concat('C', C0, Code).   % `C' and the real type's code, a bare `_Complex' a double's
%% a class's or a plain struct's type information as a pointer's pointee: its name and its own (0.179)
cpp_rtti_pointee(PT, CN, I) :- cpp_class_of_type(PT, C), !, cpp_rtti_name(C, CN), ( cpp_lib_class(C), cpp_polymorphic(C) -> atom_concat('_ZTI', CN, Sym), I = ext(Sym) ; cpp_rtti_chain(C, I) ).
cpp_rtti_pointee(PT, CN, [CN]) :- once(ccl_resolve_type(PT, base(_, [Sp]))), ( Sp = struct(Tag, _) ; Sp = union(Tag, _) ), atom(Tag), cpp_rtti_tag_name(Tag, CN).
%% a plain struct's (or union's) name: the mangler's in a namespace of the program's own (0.180: `N2ns1PE'), else `1P'
cpp_rtti_tag_name(Tag, N) :- catch('$cpp_type_ns'(Tag, _), _, fail), cpp_rtti_mangled(base([], [typedef(Tag)]), N0), !, N = N0.
cpp_rtti_tag_name(Tag, N) :- ccl_byte_length(Tag, K), atomic_list_concat([K, Tag], N).
cpp_ptr_cv(Q, CV, F) :- ( memberchk(volatile, Q) -> V = 'V', FV = 2 ; V = '', FV = 0 ), ( memberchk(const, Q) -> K = 'K', FK = 1 ; K = '', FK = 0 ), atom_concat(V, K, CV), F is FV + FK.   % the pointee's cv, as the name spells it and __pbase_type_info's flags hold it
cpp_strip_top(base(_, S), base([], S)) :- !.
cpp_strip_top(ptr(_, P), ptr([], P)) :- !.
cpp_strip_top(T, T).
%% the class whose static data member a bare name is, where its address is taken (cpp_expr's `&s', above): the class being
%% walked, else a hidden friend's class (cpp_class_ctx), never one where the name is a data member
cpp_bare_static_class(Ctx, N, Ctx) :- atom(Ctx), Ctx \== none, \+ cpp_data_member(Ctx, N, _), cpp_static_member(Ctx, N, _), !.
cpp_bare_static_class(none, N, C) :- cpp_class_ctx(C), C \== none, \+ cpp_data_member(C, N, _), cpp_static_member(C, N, _), !.
cpp_dynamic_cast(T, X, E) :- T = ptr(_, base(_, [void])), !,   % `dynamic_cast<void *>': THE COMPLETE OBJECT, the table's offset-to-top added (0.112; refused by name since 0.108)
    ( ccl_type_of(X, XT), ccl_unref(XT, XT1), ccl_resolve_type(XT1, ptr(_, S0)), cpp_class_of_type(S0, S), cpp_polymorphic(S) -> E = dyncast(X, void, void, T) ; cpp_refuse(0, dynamic_cast_to_void) ).
cpp_dynamic_cast(T, X, E) :- T = ptr(_, D0), cpp_class_of_type(D0, D), !, ccl_type_of(X, XT), ccl_unref(XT, XT1), ccl_resolve_type(XT1, ptr(_, S0)), cpp_class_of_type(S0, S),
    ( ( S == D ; cpp_derives(S, D) ) -> E = cast(T, X) ; cpp_rtti_needed(dynamic_cast_requires_rtti), cpp_rtti_chain(S, SC), cpp_rtti_chain(D, DC), E = dyncast(X, SC, DC, T) ).
cpp_dynamic_cast(T, X, E) :- ( T = ref(_, D0) ; T = rref(_, D0) ), cpp_class_of_type(D0, D), !, cpp_class_of_type_of(X, S),
    ( ( S == D ; cpp_derives(S, D) ) -> E = ccast(static, T, X) ; cpp_rtti_needed(dynamic_cast_requires_rtti), cpp_rtti_chain(S, SC), cpp_rtti_chain(D, DC), E = deref(dyncast_ref(addr(X), SC, DC, ptr([], D0))) ).
cpp_dynamic_cast(T, _, _) :- cpp_refuse(0, dynamic_cast_to(T)).
%% -fno-rtti (0.191): `typeid' and a `dynamic_cast' that asks the type information (a downcast or a cross-cast) are
%% refused, as clang++ -fno-rtti refuses them (`use of typeid requires -frtti'); a cast to a base and `dynamic_cast<void
%% *>' need none. A header's code is refused alike: libc++'s no-RTTI configuration guards its own typeids, and leaves
%% `std::dynamic_pointer_cast' unguarded, which clang++ -fno-rtti refuses where a program calls it
cpp_rtti_needed(What) :- ( nb_current('$ccl_rtti', no) -> cpp_refuse(0, What) ; true ).
%% -fno-exceptions (0.193): the program's own `throw' and `try' are refused, as clang++ -fno-exceptions refuses them
%% (`cannot use 'throw' with exceptions disabled'); libc++'s no-exceptions configuration guards its own, and the
%% desugaring's terminate guard of a noexcept function (cpp_nx_wrap) is none of the program's
cpp_eh_needed(What) :- ( nb_current('$ccl_exceptions', no), nb_getval('$cpp_in_lib', no) -> cpp_refuse(0, What) ; true ).

%% the store of the table's address, first thing after the base was constructed
cpp_vptr_store(L, C, [expr(L, assign('=', arrow(this, '$vptr'), cast(ptr([], base([], [struct(VT, none)])), addr(member(id(Table), '$vt')))))|Secs]) :-
    cpp_has_table(C), !, cpp_vt_owner(C, Owner), cpp_vt_tag(Owner, VT), cpp_vtable_name(C, Table),
    findall(expr(L, assign('=', VAcc, cast(ptr([], base([], [struct(VT2, none)])), addr(member(id(T2), '$vt'))))),
            ( '$cpp_poly_extra'(C, N, S), cpp_poly_hops(C, S, Hops), cpp_poly_access(Hops, Acc), cpp_vptr_at(N, Acc, VAcc), cpp_vt_owner(N, O2), cpp_vt_tag(O2, VT2), atomic_list_concat([C, '.vtable', S], T2) ), Secs).   % each polymorphic second base's pointer: this class's secondary table
cpp_vptr_store(_, _, []).
%% THE TABLE POINTER OF A SUB-OBJECT of class N at Acc: N's own `$vptr', or its primary base's, as many `$base' hops further in as
%% the class lays it (0.163): a holder's pointer lies in its base's `.nv' form, `P2.nv' having none of its own
cpp_vptr_at(N, Acc, VAcc) :- ( cpp_data_member(N, '$vptr', H), H \== [] -> cpp_hops(Acc, H, A1), VAcc = member(A1, '$vptr') ; VAcc = member(Acc, '$vptr') ).
%% ---- MULTIPLE POLYMORPHIC BASES (0.108; refused as multiple_inheritance since 0.34) ----------------------------------
%% A base after the first that has a table keeps its own table pointer in its own sub-object. The class makes for
%% each such base a SECONDARY TABLE -- the Itanium ABI's: prefixed with the offset to the complete object (minus the
%% sub-object's offset) and the class's type_info -- whose slots are the base's own implementations or, where this
%% class overrides one, a THUNK that moves `this' back from the sub-object to the complete object and calls the
%% override. A call through a pointer to that base then reaches the most derived override with the right `this'.
%% ... AND A CLASS DERIVED FROM SUCH A CLASS makes its OWN secondary tables for the same sub-objects, one `$base' hop
%% further in (0.110): kept, the base's table held the base's overriders, so `B *pb = &d; pb->g()' called C::g where
%% D overrides it. The sub-object is named by the hops from `this' ('$cpp_poly_path'), the table and its thunks by
%% their joined names; the class's constructor stores its table after the base's constructor has stored the base's.
cpp_inherit_poly_extras(C, Base) :- Base \== none, \+ cpp_empty_class(Base), !,
    forall(( '$cpp_poly_extra'(Base, N, S0), cpp_poly_hops(Base, S0, H0), \+ ( '$cpp_nv_base'(C, Base), cpp_in_vbase(Base, H0) ), Hops = ['$base'|H0], atomic_list_concat(Hops, '.', S), \+ '$cpp_poly_extra'(C, N, S) ),   % a `.nv' path lays no virtual base: the holder's own `$vb' takes its table
           ( assertz('$cpp_poly_extra'(C, N, S)), assertz('$cpp_poly_path'(C, S, Hops)) )),
    cpp_inherit_later_poly_extras(C), cpp_held_poly_extras(C).
cpp_inherit_poly_extras(C, _) :- cpp_inherit_later_poly_extras(C), cpp_held_poly_extras(C).
%% ... AND A LATER BASE'S OWN SUB-OBJECTS WITH TABLES are this class's too (0.171): in `D : H1, H2' over `H2 : Q2, R2', R2's
%% table pointer lies at `$base$2.$base$2', and no base-variant constructor stores a table, so D stores its own there; a later
%% VIRTUAL base held as its `.nv' form lends none inside its own virtual bases, which the class holds (0.173)
cpp_inherit_later_poly_extras(C) :-
    forall(( '$cpp_base_slot'(C, E, Slot), '$cpp_poly_extra'(E, N, S0), cpp_poly_hops(E, S0, H0), \+ ( ( '$cpp_nv_base'(C, E) ; '$cpp_lvb'(C, E, _), cpp_vb_nv(E) ), cpp_in_vbase(E, H0) ), Hops = [Slot|H0], atomic_list_concat(Hops, '.', S), \+ '$cpp_poly_extra'(C, N, S) ),
           ( assertz('$cpp_poly_extra'(C, N, S)), assertz('$cpp_poly_path'(C, S, Hops)) )).
cpp_held_poly_extras(C) :- forall(( '$cpp_vb_holder'(C, V), ( cpp_polymorphic(V) ; cpp_vb_nv(V) ), \+ cpp_empty_class(V), \+ '$cpp_vb_claim'(C, V, _), \+ cpp_vb_at_self(C, V), cpp_vb_name(C, V, VN), \+ '$cpp_poly_extra'(C, V, VN) ), assertz('$cpp_poly_extra'(C, V, VN))).   % one with virtual bases of its own has a table though it has no virtual function (0.173)
cpp_in_vbase(Base, ['$base'|_]) :- cpp_vbase_dynamic(Base), !.   % the table-reached base of a class over a virtual base
cpp_in_vbase(Base, [N|_]) :- cpp_vb_member(N), '$cpp_vb_holder'(Base, _).      % ... or a holder's own (0.163; each of several, 0.171)
cpp_poly_hops(C, S, Hops) :- '$cpp_poly_path'(C, S, Hops), !.
cpp_poly_hops(_, S, [S]).
cpp_poly_designator([H], id(H)) :- !.
cpp_poly_designator(Hs, member(D, H)) :- append(Front, [H], Hs), cpp_poly_designator(Front, D).
cpp_poly_access([H|Hs], A) :- cpp_poly_access_(Hs, arrow(this, H), A).
cpp_poly_access_([], A, A).
cpp_poly_access_([H|Hs], A0, A) :- cpp_poly_access_(Hs, member(A0, H), A).
cpp_secondary_tables(L, C, Items) :- findall(I, ( '$cpp_poly_extra'(C, N, S), cpp_secondary_table(L, C, N, S, Is), member(I, Is) ), Items).
%% CONSTRUCTION VTABLES AND THE VTT (0.139; at every depth since 0.172, the Itanium ABI's 2.6 in a form of our own). While a
%% base-variant sub-object X of a holder D -- a path, or a path's path at any depth -- is built or destroyed by its `.nv'
%% constructor or destructor, the object is an X ([class.cdtor]/4): X's table pointer holds `D.ctvtable<J>' (J the hops from D
%% to X joined by `.'), X's own implementations laid out for D -- the virtual bases' offsets from X in D's layout, offset to top
%% 0 and X's type_info, as clang's construction tables have them -- and each polymorphic virtual base V of X holds
%% `D.ctvtable<VN><J>', V's slots with X's final overriders, reached by thunks that move `this' from V to X in D's layout
%% (`D.ctthunk<VN><J>.<slot>'). Their addresses are D's VTT, `D.vtt', a static array: for each base-variant sub-object in
%% turn, X's own entries -- its primary table, then one for each polymorphic virtual base of X in X's order (cpp_vtt_vbs/2),
%% then one for each sub-object N of X that is no primary and holds virtual bases, `D.ctvtable<J>.sec<S>' (S N's hops in X; N's
%% slots with X's overriders, its virtual bases' offsets in D's layout, its offset to top in X, X's type_info: the ABI's
%% secondary virtual pointers; cpp_vtt_secs/2) -- then the parts of X's own base-variant bases (cpp_vtt_children/2), each X's
%% part contiguous (cpp_vtt_size/2). A `.nv'
%% constructor or destructor takes, after `this', the pointer `$vtt' to its part, or null where the most derived class keeps
%% no VTT (a library class: its paths store nothing, as before); the constructor stores X's entries once its bases are built,
%% the destructor first, each with X's own tables of its other sub-objects (cpp_vtt_stores/3), and each hands its bases their
%% parts (cpp_vtt_arg/3). Until 0.172 the holder stored its direct paths' tables before their calls and their base variants
%% stored none: a path's own first base, built by its complete constructor, left that base's table in place, and the path's
%% call of a slot of its own read past it and crashed (`P : PB, X' over `X : virtual PA', a 0.171 shape); a path two levels
%% down ran under its parent's table (`YZ : YY : Y', Y's constructor called YY's override over YY's unbuilt member); and the
%% offset to top was the path's offset in D. Without the secondary pointers, an `.nv' child of X with a table of its own kept
%% the one its base variant stored, N's own: `X : R, N' over `N : virtual A' as a path of D, X's constructor's call through N
%% reached N::h where X overrides it.
cpp_ctor_tables(L, C, Items) :- cpp_vtt_holder(C), !,
    findall(I, ( cpp_vtt_top(C, X, Hops), ( cpp_ctor_table(L, C, X, Hops, Is) ; cpp_vtt_vbs(X, Vs), member(V, Vs), cpp_ctor_vb_table(L, C, X, Hops, V, Is) ; cpp_vtt_secs(X, Ss), member(N-S, Ss), cpp_ctor_sec_table(L, C, X, Hops, N, S, Is) ), member(I, Is) ), Items0),
    cpp_vtt_items(C, VItems), length(VItems, N), cpp_vtt_name(C, VTT),
    ( N =:= 0 -> Items = Items0 ; append(Items0, [declaration(L, static, base([const], [void]), [var(VTT, arr(int(N), ptr([], base([const], [void]))), init(VItems))])], Items) ).
cpp_ctor_tables(_, _, []).
cpp_ctor_table(L, C, P, Hops, Items) :-
    cpp_ct_j(C, P, Hops, J), cpp_hops_offset(C, Hops, none, Off),   % at the class's own address an offset of 0 (0.178)
    cpp_vt_owner(P, Owner), cpp_slots_vt(P, Owner, VT), atomic_list_concat([C, '.ctvtp', J], VTP), atomic_list_concat([C, '.ctvtable', J], TName),
    cpp_class_l(P, cls(_, _, _, _, PSlots)), cpp_this_type(Owner, [], ThisT),
    findall(E-Fs, ( member(slot(M, K, Ret, Ps, Var), PSlots), once(cpp_ct_entry(L, C, P, Hops, M, K, Ret, Ps, Var, ThisT, E, Fs)) ), EFs),
    findall(item([], E), member(E-_, EFs), SlotItems), findall(F, ( member(_-Fs, EFs), member(F, Fs) ), Thunks),
    ( catch(cpp_rtti_chain(P, Ch), _, fail) -> TI = rtti(Ch) ; TI = nullptr ),
    PMs = [member(base([], [long]), '$off', none), member(ptr([], base([const], [void])), '$ti', none), member(base([], [struct(VT, none)]), '$vt', none)],
    PItems = [item([], int(0)), item([], TI), item([], init(SlotItems))],   % offset to top 0: the sub-object being built is the most derived one (0.172)
    ( '$cpp_vb_holder'(C, P), cpp_vbase_loc(C, P, PH), PH == Hops -> PK = virtual ; Hops == [], '$cpp_vprim'(C, P) -> PK = virtual ; PK = plain ),   % a held virtual base built by its base variant, where it lies (a claimed one at its claimant's place): its own vcall offsets (0.175)
    ( cpp_vbase_offsets(C, P, PK, Off, dyn(P, Hops), VBOs) -> cpp_vbo_fields(VBOs, 0, VBMs, VBItems), append(VBMs, PMs, VMs), append(VBItems, PItems, VItems) ; VMs = PMs, VItems = PItems ),   % the vcall offsets the one being built gives (0.174)
    append(Thunks, [declare(L, base([], [struct(VTP, VMs)])), declaration(L, static, base([], [struct(VTP, none)]), [var(TName, base([], [struct(VTP, none)]), init(VItems))])], Items).
cpp_ct_entry(L, C, P, Hops, M, K, Ret, Ps, Var, ThisT, id(TN), [Fn]) :- \+ memberchk(M, ['$dtor', '$dtor_del']),
    catch(cpp_final_overrider(P, M, K, Impl-X), _, fail), \+ cpp_slot_impl(P, M, K, Impl), !,   % THE SUB-OBJECT'S FINAL OVERRIDER where its first-base chain reaches another, a primary further in among them (0.176): a thunk moving `this' to the overrider's place
    cpp_slot_name(M, K, SN), cpp_ct_j(C, P, Hops, J), atomic_list_concat([C, '.ctthunkf', J, '.', SN], TN),
    cpp_overrider_hops(C, P, Hops, X, XH), cpp_far_adj(C, Hops, X, XH, Adj), cpp_mk_thunk(L, TN, Impl, Ret, Ps, Var, ThisT, Adj, Fn).
cpp_ct_entry(L, C, P, Hops, M, K, Ret, Ps, Var, ThisT, id(TN), [Fn]) :- cpp_vprim_far(C, P, Hops, M, K, I, IH), !,   % a nearly empty primary virtual base's own slot, the base claimed by another sub-object (0.174): a thunk moving `this' to it
    cpp_slot_impl(P, M, K, Impl), cpp_slot_name(M, K, SN), cpp_ct_j(C, P, Hops, J), atomic_list_concat([C, '.ctthunkv', J, '.', SN], TN),
    cpp_far_adj(C, Hops, I, IH, Adj), cpp_mk_thunk(L, TN, Impl, Ret, Ps, Var, ThisT, Adj, Fn).
cpp_ct_entry(_, _, P, _, M, K, _, _, _, _, E, []) :- ( memberchk(M, ['$dtor', '$dtor_del']) -> cpp_dtor(P, Impl) ; cpp_slot_def(P, M, K, Impl) ), !, E = id(Impl).
cpp_ct_entry(_, _, _, _, _, _, _, _, _, _, nullptr, []).
cpp_ctor_vb_table(L, C, P, Hops, V, Items) :- cpp_vb_table_name(C, V, VN), ( VN == '$vp' -> Hops \== [], cpp_vp_class(C, P, V), VDes = [] ; '$cpp_vb_claim'(C, V, CH) -> \+ cpp_vptr_shared(P, Hops, CH), cpp_poly_designator(CH, VDes) ; '$cpp_poly_extra'(C, V, VN), VDes = id(VN) ),   % a virtual base a sub-object takes as its primary has a table of its own only where it does not share the pointer of the one being built (0.174) -- the ones at the object's own address, the class's primary virtual base and those inside it, one (0.176)
    cpp_ct_j(C, P, Hops, J), cpp_hops_offset(C, Hops, none, POff),
    cpp_vt_owner(V, VO), cpp_slots_vt(V, VO, VT), atomic_list_concat([C, '.ctvtp', VN, J], VTP), atomic_list_concat([C, '.ctvtable', VN, J], TName),
    cpp_class_l(V, cls(_, _, _, _, VSlots)), CT = base([], [typedef(C)]), cpp_des_off(CT, VDes, VOff), Delta = bin('-', VOff, POff),
    cpp_this_type(VO, [], ThisT),
    findall(E-Fs, ( member(slot(M, K, Ret, Ps, Var), VSlots), once(cpp_ct_vb_entry(L, C, P, V, J, M, K, Ret, Ps, Var, Delta, ThisT, E, Fs)) ), EFs),
    findall(item([], E), member(E-_, EFs), SlotItems), findall(F, ( member(_-Fs, EFs), member(F, Fs) ), Thunks),
    ( catch(cpp_rtti_chain(P, Ch), _, fail) -> TI = rtti(Ch) ; TI = nullptr ),
    PMs = [member(base([], [long]), '$off', none), member(ptr([], base([const], [void])), '$ti', none), member(base([], [struct(VT, none)]), '$vt', none)],
    PItems = [item([], neg(Delta)), item([], TI), item([], init(SlotItems))],
    ( cpp_vbase_offsets(C, V, virtual, VOff, dyn(P, Hops), VBOs) -> cpp_vbo_fields(VBOs, 0, VBMs, VBItems), append(VBMs, PMs, VMs), append(VBItems, PItems, VItems) ; VMs = PMs, VItems = PItems ),   % its own virtual bases' offsets, where it has some (0.173), and its own vcall offsets (0.175)
    append(Thunks, [declare(L, base([], [struct(VTP, VMs)])), declaration(L, static, base([], [struct(VTP, none)]), [var(TName, base([], [struct(VTP, none)]), init(VItems))])], Items).
cpp_ct_vb_entry(_, _, _, V, _, M, K, _, _, _, _, _, E, []) :- memberchk(M, ['$dtor', '$dtor_del']), !, ( cpp_slot_def(V, M, K, Impl) -> E = id(Impl) ; E = nullptr ).
cpp_ct_vb_entry(L, C, P, V, S, M, K, Ret, Ps, Var, Delta, ThisT, id(TN), [Fn]) :- ( cpp_final_overrider(P, M, K, Impl-_) -> true ; cpp_slot_impl(P, M, K, Impl) ), \+ cpp_slot_impl(V, M, K, Impl), !,   % the path's final overrider, a later base's too (0.171)
    cpp_slot_name(M, K, SN), cpp_vb_table_name(C, V, VN), atomic_list_concat([C, '.ctthunk', VN, S, '.', SN], TN),
    Adj = cast(ptr([], base([], [typedef(P)])), bin('-', cast(ptr([], base([], [char])), id(this)), Delta)),
    cpp_mk_thunk(L, TN, Impl, Ret, Ps, Var, ThisT, Adj, Fn).
cpp_ct_vb_entry(L, C, _, V, S, M, K, Ret, Ps, Var, _, ThisT, id(TN), [Fn]) :- cpp_vbase_loc(C, V, VH), VH \== [], cpp_vprim_far(C, V, VH, M, K, I, IH), !,   % a nearly empty primary virtual base's own slot, the base claimed by another sub-object (0.174)
    cpp_slot_impl(V, M, K, Impl), cpp_slot_name(M, K, SN), cpp_vb_table_name(C, V, VN), atomic_list_concat([C, '.ctthunkv', VN, S, '.', SN], TN),
    cpp_far_adj(C, VH, I, IH, Adj), cpp_mk_thunk(L, TN, Impl, Ret, Ps, Var, ThisT, Adj, Fn).
cpp_ct_vb_entry(_, _, _, V, _, M, K, _, _, _, _, _, E, []) :- ( cpp_slot_def(V, M, K, Impl) -> E = id(Impl) ; E = nullptr ).
%% THE SECONDARY CONSTRUCTION TABLE of a sub-object N of X at S, in D's layout (0.172): N's slots with X's final overriders --
%% a thunk moving `this' from N back to X, a fixed distance in X's non-virtual part --, N's virtual bases' offsets from N where D
%% lays them, the offset to top -(N's offset in X) and X's type_info, as clang's construction vtable group of X-in-D has it
cpp_ctor_sec_table(L, C, X, Hops, N, S, Items) :-
    cpp_ct_j(C, X, Hops, J), cpp_hops_offset(C, Hops, none, OffX), cpp_poly_hops(X, S, HN), append(Hops, HN, HopsN), cpp_poly_designator(HopsN, DesN),
    cpp_vt_owner(N, NO), cpp_slots_vt(N, NO, VT), atomic_list_concat([C, '.ctvtp', J, '.sec', S], VTP), atomic_list_concat([C, '.ctvtable', J, '.sec', S], TName),
    atomic_list_concat([C, '.ctthunk', J, '.sec', S], TPre),
    cpp_class_l(N, cls(_, _, _, _, NSlots)), CT = base([], [typedef(C)]), OffN = offsetof(CT, DesN), Delta = bin('-', OffN, OffX),
    cpp_this_type(NO, [], ThisT),
    findall(E-Fs, ( member(slot(M, K, Ret, Ps, Var), NSlots), once(cpp_ct_sec_entry(L, X, N, sec(TPre, C, HopsN), M, K, Ret, Ps, Var, Delta, ThisT, E, Fs)) ), EFs),
    findall(item([], E), member(E-_, EFs), SlotItems), findall(F, ( member(_-Fs, EFs), member(F, Fs) ), Thunks),
    ( catch(cpp_rtti_chain(X, Ch), _, fail) -> TI = rtti(Ch) ; TI = nullptr ),
    PMs = [member(base([], [long]), '$off', none), member(ptr([], base([const], [void])), '$ti', none), member(base([], [struct(VT, none)]), '$vt', none)],
    PItems = [item([], neg(Delta)), item([], TI), item([], init(SlotItems))],
    ( cpp_vbase_offsets(C, N, OffN, dyn(X, Hops), VBOs) -> cpp_vbo_fields(VBOs, 0, VBMs, VBItems), append(VBMs, PMs, VMs), append(VBItems, PItems, VItems) ; VMs = PMs, VItems = PItems ),
    append(Thunks, [declare(L, base([], [struct(VTP, VMs)])), declaration(L, static, base([], [struct(VTP, none)]), [var(TName, base([], [struct(VTP, none)]), init(VItems))])], Items).
cpp_ct_sec_entry(_, _, N, _, M, K, _, _, _, _, _, E, []) :- memberchk(M, ['$dtor', '$dtor_del']), !, ( cpp_slot_def(N, M, K, Impl) -> E = id(Impl) ; E = nullptr ).
cpp_ct_sec_entry(L, X, N, sec(TPre, _, _), M, K, Ret, Ps, Var, Delta, ThisT, id(TN), [Fn]) :- ( cpp_final_overrider(X, M, K, Impl-_) -> true ; cpp_slot_impl(X, M, K, Impl) ), \+ cpp_slot_impl(N, M, K, Impl), !,
    cpp_slot_name(M, K, SN), atomic_list_concat([TPre, '.', SN], TN),
    Adj = cast(ptr([], base([], [typedef(X)])), bin('-', cast(ptr([], base([], [char])), id(this)), Delta)),
    cpp_mk_thunk(L, TN, Impl, Ret, Ps, Var, ThisT, Adj, Fn).
cpp_ct_sec_entry(L, _, N, sec(TPre, C, HopsN), M, K, Ret, Ps, Var, _, ThisT, id(TN), [Fn]) :- cpp_vprim_far(C, N, HopsN, M, K, I, IH), !,   % a nearly empty primary virtual base's own slot, the base claimed by another sub-object (0.174)
    cpp_slot_impl(N, M, K, Impl), cpp_slot_name(M, K, SN), atomic_list_concat([TPre, '.v.', SN], TN),
    cpp_far_adj(C, HopsN, I, IH, Adj), cpp_mk_thunk(L, TN, Impl, Ret, Ps, Var, ThisT, Adj, Fn).
cpp_ct_sec_entry(_, _, N, _, M, K, _, _, _, _, _, E, []) :- ( cpp_slot_def(N, M, K, Impl) -> E = id(Impl) ; E = nullptr ).
%% the classes that keep a VTT: the program's holders; and its name
cpp_vtt_holder(C) :- \+ cpp_lib_class(C), '$cpp_vb_holder'(C, _).
cpp_vtt_name(C, N) :- atomic_list_concat([C, '.vtt'], N).
cpp_vtt_type(ptr([], ptr([], base([const], [void])))).
%% the parameters of a constructor or a destructor: a base variant's take its part of the VTT after `this'
cpp_vtt_params(C, [This|Ps], Out) :- ( cpp_nv_body(C) -> cpp_vtt_type(T), Out = [This, param(T, '$vtt')|Ps] ; Out = [This|Ps] ).
%% the polymorphic virtual bases of X, in X's order; X's base-variant bases, the first one's slot `$base'
cpp_vtt_vbs(X, Vs) :- cpp_vbases_of(X, Vs0), cpp_first_each(Vs0, Vs1), findall(V, ( member(V, Vs1), cpp_polymorphic(V), \+ cpp_empty_class(V) ), Vs).
%% the sub-objects of X that are no primary and hold virtual bases, each N-S (S its hops' name in X), in X's order: their tables
%% differ from X's complete object's, and the VTT gives X one for each (the ABI's secondary virtual pointers; 0.172)
cpp_vtt_secs(X, Ss) :- findall(N-S, ( '$cpp_poly_extra'(X, N, S), cpp_vbases_of(N, [_|_]), cpp_poly_hops(X, S, [H1|_]), \+ cpp_vb_member(H1), \+ ( H1 == '$base', '$cpp_vbase'(X) ) ), Ss).
cpp_vtt_children(X, Cs) :- cpp_class_l(X, cls(B, _, _, _, _)), ( B \== none, '$cpp_nv_base'(X, B), \+ '$cpp_vbase'(X) -> C0 = [B-'$base'] ; C0 = [] ),
    findall(E-S, ( '$cpp_base_slot'(X, E, S), '$cpp_nv_base'(X, E) ), C1), append(C0, C1, Cs).
%% the size of X's part, and where the part of X's base-variant base Q starts in a list of parts that starts at K0
cpp_vtt_size(X, N) :- cpp_vtt_vbs(X, Vs), length(Vs, NV), cpp_vtt_secs(X, Ss), length(Ss, NS), cpp_vtt_children(X, Cs), cpp_vtt_sizes(Cs, 0, NC), N is 1 + NV + NS + NC.
cpp_vtt_sizes([], N, N).
cpp_vtt_sizes([Q-_|Cs], N0, N) :- cpp_vtt_size(Q, NQ), N1 is N0 + NQ, cpp_vtt_sizes(Cs, N1, N).
cpp_vtt_at([Q0-_|Cs], Q, K0, K) :- ( Q0 == Q -> K = K0 ; cpp_vtt_size(Q0, N0), K1 is K0 + N0, cpp_vtt_at(Cs, Q, K1, K) ).
%% every base-variant sub-object of the class Y at the hops H0, at its hops, in the VTT's order: each, then its own
cpp_vtt_sub(Y, H0, X, Hops) :- cpp_vtt_children(Y, Cs), member(Q-S, Cs), append(H0, [S], H1), ( X = Q, Hops = H1 ; cpp_vtt_sub(Q, H1, X, Hops) ).
%% ... and from the most derived class, whose parts include those of the virtual bases it holds as their base-variant forms (0.173)
cpp_vtt_top(C, X, Hops) :- cpp_vtt_top_children(C, Cs), member(Q-H, Cs), ( X = Q, Hops = H ; cpp_vtt_sub(Q, H, X, Hops) ).
cpp_vtt_top_children(C, Cs) :- cpp_vtt_children(C, Cs00), findall(E-[S], member(E-S, Cs00), Cs0),
    findall(V-H, ( '$cpp_vb_holder'(C, V), cpp_vb_nv(V), \+ cpp_empty_class(V), ( '$cpp_vb_claim'(C, V, H) -> true ; cpp_vb_at_self(C, V) -> H = [] ; cpp_vb_name(C, V, VN), H = [VN] ) ), Cs1),   % each part at its sub-object's hops, a held virtual base that a base sub-object takes as its primary at that one's (0.175)
    ( '$cpp_vprim'(C, I), '$cpp_nv_base'(C, I) -> Cs2 = [I-[]] ; Cs2 = [] ), append([Cs0, Cs1, Cs2], Cs).   % ... and a nearly empty primary laid as its base-variant form at the class's own address (0.178)
%% the name a sub-object's construction tables take from its hops -- a claimed virtual base, at its claimant's hops, its own class's
%% name beside them (0.175)
cpp_ct_j(_, P, [], J) :- !, atomic_list_concat(['$at.', P], J).   % the class's own address, by the sub-object's class: its nearly empty primary's, and one inside it the class builds (0.178)
cpp_ct_j(C, P, Hops, J) :- atomic_list_concat(Hops, '.', J0), ( '$cpp_vb_claim'(C, P, H), H == Hops -> atomic_list_concat([J0, '.$v.', P], J) ; J = J0 ).
%% the name of a virtual base's construction tables: its member's (`$vb' ...), or `$vp' for the class's own primary virtual base and
%% those inside it, which lie at the object's own address and share its table pointer (0.176): one table for them, the one with the
%% most slots among the sub-object's virtual bases, their slots a primary chain's (cpp_vp_class/3) -- one the class holds there too
%% (0.178), and while a sub-object at the class's own address is built they hold that one's own table
cpp_vb_table_name(C, V, '$vp') :- cpp_vbase_loc(C, V, H), H == [], !.
cpp_vb_table_name(C, V, VN) :- cpp_vb_name(C, V, VN).
cpp_vp_class(C, X, V) :- cpp_vtt_vbs(X, Vs), findall(N-W, ( member(W, Vs), cpp_vb_table_name(C, W, VN), VN == '$vp', cpp_class_l(W, cls(_, _, _, _, Sl)), length(Sl, N) ), NWs), msort(NWs, S), last(S, _-V0), V == V0.
cpp_des_off(_, [], int(0)) :- !.
cpp_des_off(CT, Des, offsetof(CT, Des)).
%% the VTT's items: each sub-object's own entries, in that order
cpp_vtt_items(C, Items) :- findall(I, ( cpp_vtt_top(C, X, Hops), cpp_vtt_own(C, X, Hops, Is), member(I, Is) ), Items).
cpp_vtt_own(C, X, Hops, [item([], addr(member(id(T), '$vt')))|VIs]) :- cpp_ct_j(C, X, Hops, J), atomic_list_concat([C, '.ctvtable', J], T),
    cpp_vtt_vbs(X, Vs), findall(item([], addr(member(id(VT), '$vt'))), ( member(V, Vs), cpp_vb_table_name(C, V, VN), ( '$cpp_vb_claim'(C, V, CH), cpp_vptr_shared(X, Hops, CH) -> VT = T ; Hops == [], VN == '$vp' -> VT = T ; atomic_list_concat([C, '.ctvtable', VN, J], VT) ) ), VIs0),   % a virtual base that shares the pointer of the sub-object being built has that one's own table (0.174), the ones at the object's own address one (0.176)
    cpp_vtt_secs(X, Ss), findall(item([], addr(member(id(ST), '$vt'))), ( member(_-S, Ss), atomic_list_concat([C, '.ctvtable', J, '.sec', S], ST) ), SIs), append(VIs0, SIs, VIs).
%% the arguments of a call of a base's constructor or destructor: a base variant's take, after the place, its part of the VTT
%% -- of C's own where C is complete and keeps one, of the part C's base variant was handed (null passed on as null), else null
cpp_vtt_pass(C, B, BName, [P|As], Out) :- ( atom_concat(_, '.nv', BName) -> cpp_vtt_arg(C, B, V), Out = [P, V|As] ; Out = [P|As] ).
cpp_vtt_arg(C, Q, Arg) :-
    (   cpp_nv_body(C) -> cpp_vtt_children(C, Cs), cpp_vtt_vbs(C, Vs), length(Vs, NV), cpp_vtt_secs(C, Ss), length(Ss, NS), K0 is 1 + NV + NS, cpp_vtt_at(Cs, Q, K0, K), Arg = cond(id('$vtt'), bin('+', id('$vtt'), int(K)), nullptr)
    ;   cpp_vtt_holder(C) -> cpp_vtt_top_children(C, Cs), cpp_vtt_at(Cs, Q, 0, K), cpp_vtt_name(C, VTT), cpp_vtt_declare(C, VTT), Arg = addr(index(id(VTT), int(K)))
    ;   Arg = nullptr ).
cpp_vtt_declare(C, VTT) :- ( ccl_declared(VTT, _) -> true ; cpp_vtt_top_children(C, Cs), cpp_vtt_sizes(Cs, 0, N), ccl_gdeclare([VTT-arr(int(N), ptr([], base([const], [void])))]) ).
%% A BASE VARIANT'S STORES of its own entries of the VTT it was handed, nothing where it was handed null: its primary table, then
%% each polymorphic virtual base's, reached through the table just stored, then its own tables of its other polymorphic
%% sub-objects that hold no virtual base -- their slots with its overriders and its offsets, as in any object of its class --
%% then each of those that hold virtual bases from its entry (cpp_vtt_secs/2)
cpp_vtt_stores(L, C, [if(L, id('$vtt'), block([St0|Sts]), none)]) :- cpp_has_table(C), !,
    cpp_vt_owner(C, Owner), cpp_vt_tag(Owner, VT),
    St0 = expr(L, assign('=', arrow(this, '$vptr'), cast(ptr([], base([], [struct(VT, none)])), index(id('$vtt'), int(0))))),
    cpp_vtt_vbs(C, Vs),
    findall(expr(L, assign('=', VAcc, cast(ptr([], base([], [struct(VVT, none)])), index(id('$vtt'), int(I))))),
            ( nth1(I, Vs, V), cpp_vt_owner(V, VO), cpp_vt_tag(VO, VVT), cpp_vptr_at(V, deref(ccast(static, ptr([], base([], [typedef(V)])), id(this))), VAcc) ), VSts),
    findall(expr(L, assign('=', NAcc, cast(ptr([], base([], [struct(NVT, none)])), addr(member(id(T2), '$vt'))))),
            ( '$cpp_poly_extra'(C, N, S), cpp_vbases_of(N, []), cpp_poly_hops(C, S, Hops), Hops = [H1|_], \+ cpp_vb_member(H1), \+ ( H1 == '$base', '$cpp_vbase'(C) ),
              cpp_poly_access(Hops, Acc), cpp_vptr_at(N, Acc, NAcc), cpp_vt_owner(N, O2), cpp_vt_tag(O2, NVT), atomic_list_concat([C, '.vtable', S], T2) ), SSts),
    length(Vs, NV), cpp_vtt_secs(C, Ss),
    findall(expr(L, assign('=', SAcc, cast(ptr([], base([], [struct(SVT, none)])), index(id('$vtt'), int(Idx))))),
            ( nth1(I, Ss, SN-SS), Idx is NV + I, cpp_poly_hops(C, SS, SHops), cpp_poly_access(SHops, SA), cpp_vptr_at(SN, SA, SAcc), cpp_vt_owner(SN, SO), cpp_vt_tag(SO, SVT) ), XSts),
    append([VSts, SSts, XSts], Sts).
cpp_vtt_stores(_, _, []).
cpp_secondary_table(L, C, N, S, Items) :-
    cpp_vt_owner(N, Owner), cpp_slots_vt(N, Owner, VT), atomic_list_concat([C, '.vtp', S], VTP), atomic_list_concat([C, '.vtable', S], TName),
    cpp_class_l(N, cls(_, _, _, _, NSlots)), CT = base([], [typedef(C)]), cpp_poly_hops(C, S, Hops), cpp_poly_designator(Hops, Des), Off = offsetof(CT, Des),
    cpp_this_type(Owner, [], ThisT), cpp_this_type(Owner, [], [dying], DyingT),
    findall(E-Fs, ( member(slot(M, K, Ret, Ps, V), NSlots), once(cpp_thunk_entry(L, C, N, S, M, K, Ret, Ps, V, Off, ThisT, DyingT, E, Fs)) ), EFs), cpp_trace(secondary(C, N, NSlots)),
    findall(item([], E), member(E-_, EFs), SlotItems), findall(F, ( member(_-Fs, EFs), member(F, Fs) ), Thunks),
    ( catch(cpp_rtti_chain(C, Ch), _, fail) -> TI = rtti(Ch) ; TI = nullptr ),
    PMs = [member(base([], [long]), '$off', none), member(ptr([], base([const], [void])), '$ti', none), member(base([], [struct(VT, none)]), '$vt', none)],
    PItems = [item([], neg(Off)), item([], TI), item([], init(SlotItems))],
    ( cpp_poly_virtual(C, S) -> VK = virtual ; VK = plain ),   % a virtual base's table: its own vcall offsets (0.175)
    ( cpp_vbase_offsets(C, N, VK, Off, dyn(C, []), VBOs) -> cpp_vbo_fields(VBOs, 0, VBMs, VBItems), append(VBMs, PMs, VMs), append(VBItems, PItems, VItems) ; VMs = PMs, VItems = PItems ),
    Decl = declare(L, base([], [struct(VTP, VMs)])),
    Table = declaration(L, static, base([], [struct(VTP, none)]), [var(TName, base([], [struct(VTP, none)]), init(VItems))]),
    append(Thunks, [Decl, Table], Items).
cpp_thunk_entry(L, C, _, S, M, K, Ret, Ps, V, Off, ThisT, _, id(E), Fs) :- cpp_final_impl(C, M, K, IE, Sub), !,   % a diamond's final overrider: the table's own sub-object's directly, another path's through a thunk
    (   Sub == S -> E = IE, Fs = []
    ;   cpp_slot_name(M, K, SN), atomic_list_concat([C, '.thunk', S, '.', SN], E),
        cpp_mk_thunk(L, E, IE, Ret, Ps, V, ThisT, cast(ptr([], base([], [typedef(C)])), bin('-', cast(ptr([], base([], [char])), id(this)), Off)), Fn), Fs = [Fn] ).
cpp_thunk_entry(L, C, N, S, M, K, Ret, Ps, V, Off, ThisT, DyingT, id(TN), [function(L, static, Ret, TN, [param(TT, this)|Ps1], V, Body)]) :-
    ( M == '$dtor' -> cpp_dtor(C, Impl), \+ cpp_dtor(N, Impl), TT = DyingT ; M == '$dtor_del' -> cpp_d0_name(C, Impl), \+ cpp_d0_name(N, Impl), TT = DyingT ; cpp_slot_impl(C, M, K, Impl), \+ cpp_slot_impl(N, M, K, Impl), TT = ThisT ), !,   % a deleting destructor's thunk moves `this' to the complete object and deletes it there (0.202)
    cpp_slot_name(M, K, SN), atomic_list_concat([C, '.thunk', S, '.', SN], TN),
    cpp_thunk_params(Ps, 1, Ps1, Ids),
    Adj = cast(ptr([], base([], [typedef(C)])), bin('-', cast(ptr([], base([], [char])), id(this)), Off)),
    Call = call(id(Impl), [Adj|Ids]),
    ( ccl_resolve_type(Ret, base(_, [void])) -> Body = block([expr(L, Call)]) ; Body = block([return(L, Call)]) ),
    ( '$cpp_libfn'(TN) -> true ; assertz('$cpp_libfn'(TN)) ).                                   % compiler-made: the safe part walks the override it calls, not the thunk
cpp_thunk_entry(L, C, N, S, M, K, Ret, Ps, V, Off, ThisT, _, id(TN), [Fn]) :- cpp_poly_hops(C, S, NHops), cpp_vprim_far(C, N, NHops, M, K, _, _), !,   % a nearly empty primary virtual base's own slot, the base claimed by another sub-object (0.174): through the complete object, as an override is
    cpp_slot_impl(N, M, K, Impl), cpp_slot_name(M, K, SN), atomic_list_concat([C, '.thunk', S, '.', SN], TN),
    cpp_mk_thunk(L, TN, Impl, Ret, Ps, V, ThisT, cast(ptr([], base([], [typedef(C)])), bin('-', cast(ptr([], base([], [char])), id(this)), Off)), Fn).
cpp_thunk_entry(_, _, N, _, M, K, _, _, _, _, _, _, E, []) :- ( M == '$dtor' -> cpp_dtor(N, Impl) ; M == '$dtor_del' -> cpp_d0_name(N, Impl) ; cpp_slot_def(N, M, K, Impl) ) -> E = id(Impl) ; E = nullptr.
%% a thunk's parameters, each named for the call it makes: an unnamed one, or one whose name is no atom, `$t<I>' (0.141: the
%% instance thunk's copy of this predicate, further down, was joined to it by cocolog and answered second)
cpp_thunk_params([], _, [], []).
cpp_thunk_params([P|Ps], I, [param(T, N)|Qs], [id(N)|Ids]) :- ( P = param(T, N0) -> true ; P = param(T, N0, _) ), ( atom(N0), N0 \== anon -> N = N0 ; atom_concat('$t', I, N) ), I1 is I + 1, cpp_thunk_params(Ps, I1, Qs, Ids).
cpp_sec_store(L, C, S, [expr(L, assign('=', VAcc, cast(ptr([], base([], [struct(VT2, none)])), addr(member(id(T2), '$vt')))))]) :-
    '$cpp_poly_extra'(C, N, S), !, cpp_poly_hops(C, S, Hops), cpp_poly_access(Hops, Acc), cpp_vptr_at(N, Acc, VAcc), cpp_vt_owner(N, O2), cpp_vt_tag(O2, VT2), atomic_list_concat([C, '.vtable', S], T2).
cpp_sec_store(_, _, _, []).
%% THE VBASE OFFSET a table carries ([class.mi]; the Itanium ABI's `vptr[-3]', 0.110): where the table's sub-object is
%% of a class whose primary chain holds a virtual base reached through the table, the distance from that sub-object
%% (at Off in the complete object C, `none' for the primary) to where C lays that virtual base
cpp_vbase_offset(_, N, Off, E) :- cpp_primary_vbase(N, V), cpp_empty_class(V), !, ( Off == none -> E = int(0) ; E = neg(Off) ).   % AN EMPTY VIRTUAL BASE has no sub-object (0.163): it lies at the complete object's own address, offset 0, as clang lays it where nothing else of its type is there (the Itanium ABI's II.3); `offsetof(EB, $base)' named no member, and a class over one was refused
cpp_vbase_offset(C, N, Off, E) :- cpp_primary_vbase(N, V), cpp_vbase_loc(C, V, Hops), !, cpp_poly_designator(Hops, Des), CT = base([], [typedef(C)]),
    ( Off == none -> E = offsetof(CT, Des) ; E = bin('-', offsetof(CT, Des), Off) ).
cpp_primary_vbase(N, V) :- cpp_vbase_dynamic(N), !, cpp_class_l(N, cls(V, _, _, _, _)).
cpp_primary_vbase(N, V) :- cpp_class_l(N, cls(B, _, _, _, _)), B \== none, \+ '$cpp_vbase'(N), \+ cpp_empty_class(B), cpp_primary_vbase(B, V).
%% where a class lays a virtual base V, statically: through its first base, or a later base embedded whole (never a `.nv' one)
cpp_vbase_loc(C, V, H) :- '$cpp_vb_claim'(C, V, H), !.   % a virtual base a base sub-object takes as its primary lies at that sub-object (0.174)
cpp_vbase_loc(C, V, []) :- '$cpp_vprim'(C, V), !.        % ... and a class's own nearly empty primary virtual base at the class's own address
cpp_vbase_loc(C, V, []) :- '$cpp_vprim'(C, P), cpp_vbases_of(P, PVs), memberchk(V, PVs), cpp_vbase_loc(P, V, PH), PH == [], !.   % ... and the virtual bases inside it, at its own address (0.175; cpp_vprim_inside/1) -- the others the class holds (0.178)
cpp_vbase_loc(C, V, [N]) :- '$cpp_vb_holder'(C, V), !, cpp_vb_name(C, V, N).
cpp_vbase_loc(C, V, ['$base']) :- '$cpp_vbase'(C), cpp_class_l(C, cls(V, _, _, _, _)), !.
cpp_vbase_loc(C, V, ['$base'|H]) :- cpp_class_l(C, cls(B, _, _, _, _)), B \== none, \+ cpp_empty_class(B), \+ '$cpp_nv_base'(C, B), cpp_vbase_loc(B, V, H), !.
cpp_vbase_loc(C, V, [S|H]) :- '$cpp_base_slot'(C, E, S), \+ '$cpp_nv_base'(C, E), cpp_vbase_loc(E, V, H), !.
%% THE VBASE OFFSETS a table carries, one a slot (0.171; the Itanium ABI 2.5.2, as clang's AddVBaseOffsets builds them): the
%% table of an N-subobject (at Off in the complete object C, `none' for the primary) has a slot for each of N's virtual bases,
%% -24 - 8I for the I-th -- its primary base's slots first, at their places, then the others in the order a depth-first walk of
%% its bases as written meets them -- each the distance from the sub-object to where C lays that base. Where a base has no place
%% to be named, the table keeps the one slot of 0.110 (cpp_vbase_offset/4). The code here reads a path's own first slot only;
%% the rest are the ABI's, for code that clang built: `H1 : Q1, R1' has W at -32 of its primary table.
cpp_vbase_offsets(C, N, Off, Es) :- cpp_vbase_offsets(C, N, Off, dyn(C, []), Es).
cpp_vbase_offsets(C, N, Off, Dyn, Es) :- cpp_vbase_offsets(C, N, plain, Off, Dyn, Es).
cpp_vbase_offsets(C, N, Kind, Off, Dyn, Es) :- cpp_vbo(N, Kind, [], Vs), Vs \== [], cpp_vbase_entries(Vs, C, Off, Dyn, Es), !.   % ... and a VIRTUAL base's table its own vcall offsets after them (0.175; cpp_vbo/4)
cpp_vbase_offsets(C, N, _, Off, _, [E]) :- cpp_vbase_offset(C, N, Off, E).
%% whether the sub-object a secondary table is for is a virtual base of the class: one it holds, or its virtual first base laid last
cpp_poly_virtual(C, S) :- cpp_poly_hops(C, S, Hops), cpp_hops_end_virtual(C, Hops).
%% ... a virtual base laid inside a virtual base the class lays (`E : virtual C' over `C : virtual A': A at [`$base', `$base'])
cpp_hops_end_virtual(C, [H]) :- !, cpp_virtual_hop(C, H).
cpp_hops_end_virtual(C, [H|Hs]) :- cpp_hop_class(C, H, N), cpp_hops_end_virtual(N, Hs).
cpp_virtual_hop(_, H) :- cpp_vb_member(H), !.
cpp_virtual_hop(C, H) :- '$cpp_lvb'(C, _, H), !.
cpp_virtual_hop(C, '$base') :- '$cpp_vbase'(C), \+ '$cpp_vprim'(C, _).
cpp_hop_class(C, '$base', N) :- !, cpp_class_l(C, cls(N, _, _, _, _)), N \== none.
cpp_hop_class(C, H, N) :- cpp_vb_member(H), !, '$cpp_vb_holder'(C, N), cpp_vb_name(C, N, H0), H0 == H, !.
cpp_hop_class(C, H, N) :- '$cpp_base_slot'(C, N, H), !.
cpp_vbase_entries([], _, _, _, []).
cpp_vbase_entries([V|Vs], C, Off, Dyn, [E|Es]) :- cpp_vbase_entry(C, V, Off, Dyn, E), cpp_vbase_entries(Vs, C, Off, Dyn, Es).
cpp_vbase_entry(C, vcn(T, I, M, K, SH), Off, Dyn, E) :- !, cpp_vcalln_entry(C, T, I, M, K, SH, Off, Dyn, E).   % ... and a later non-virtual base's, where its own primary chain defines the function at its place in the virtual base T (0.175)
cpp_vbase_entry(C, vc(I, M, K), Off, Dyn, E) :- !, cpp_vcall_hops(C, I, M, K, Dyn, Hops), cpp_hops_offset(C, Hops, Off, E).   % A VCALL OFFSET (0.174): from the table's sub-object to the final overrider's -- the dynamic class's (the complete object's, or the one being built for a construction table)
cpp_vbase_entry(_, V, Off, _, E) :- cpp_empty_class(V), !, ( Off == none -> E = int(0) ; E = neg(Off) ).
cpp_vbase_entry(C, V, Off, _, E) :- cpp_vbase_loc(C, V, Hops), !, cpp_hops_offset(C, Hops, Off, E).
cpp_hops_offset(_, [], Off, E) :- !, ( Off == none -> E = int(0) ; E = neg(Off) ).
cpp_hops_offset(C, Hops, Off, E) :- cpp_poly_designator(Hops, Des), CT = base([], [typedef(C)]), ( Off == none -> E = offsetof(CT, Des) ; E = bin('-', offsetof(CT, Des), Off) ).
%% where the final overrider of a primary virtual base's function lies, for its vcall offset (the Itanium ABI 2.5.2): the destructor's
%% is the dynamic class's own; an override where its class lies (a virtual base where the layout class lays it); the base's own where
%% the layout class lays the base
cpp_vcall_hops(_, _, '$dtor', _, dyn(_, DH), DH) :- !.
cpp_vcall_hops(C, I, M, K, dyn(D, _), Hops) :- catch(cpp_final_overrider(D, M, K, _-X), _, fail), X \== I, cpp_in_primary_chain(I, X), !, cpp_vbase_loc(C, I, Hops).   % the base's own primary chain defines it: where the base lies (0.175)
cpp_vcall_hops(C, I, M, K, dyn(D, DH), Hops) :- catch(cpp_final_overrider(D, M, K, _-X), _, fail), X \== I, !, cpp_overrider_hops(C, D, DH, X, Hops).
cpp_vcall_hops(C, I, _, _, _, Hops) :- cpp_vbase_loc(C, I, Hops), !.
cpp_vcall_hops(_, _, _, _, dyn(_, DH), DH).
cpp_vcalln_entry(_, T, I, M, K, SH, _, dyn(D, _), E) :- \+ memberchk(M, ['$dtor', '$dtor_del']), catch(cpp_final_overrider(D, M, K, _-X), _, fail), ( X == I -> true ; cpp_in_primary_chain(I, X) ), !,
    cpp_poly_designator(SH, Des), E = offsetof(base([], [typedef(T)]), Des).
cpp_vcalln_entry(C, _, I, M, K, _, Off, Dyn, E) :- cpp_vcall_hops(C, I, M, K, Dyn, Hops), cpp_hops_offset(C, Hops, Off, E).
cpp_overrider_hops(_, D, DH, X, DH) :- X == D, !.
cpp_overrider_hops(C, _, _, X, Hops) :- cpp_vbase_loc(C, X, Hops), !.
cpp_overrider_hops(_, D, DH, X, Hops) :- cpp_nv_hops(D, X, H), !, append(DH, H, Hops).
cpp_overrider_hops(_, _, DH, _, DH).
cpp_nv_hops(D, X, H) :- cpp_class_l(D, cls(B, _, _, _, _)), B \== none, \+ '$cpp_vbase'(D), \+ cpp_empty_class(B), ( B == X -> H = ['$base'] ; cpp_nv_hops(B, X, H1), H = ['$base'|H1] ).
cpp_nv_hops(D, X, H) :- '$cpp_base_slot'(D, E, S), \+ '$cpp_lvb'(D, E, _), \+ cpp_empty_class(E), ( E == X -> H = [S] ; cpp_nv_hops(E, X, H1), H = [S|H1] ).
cpp_vb_slots(N, Vs) :- cpp_vbo(N, plain, [], Vs).
%% THE VCALL AND VBASE OFFSETS OF A TABLE (the Itanium ABI 2.5.2, clang's AddVCallAndVBaseOffsets; 0.174, 0.175): the primary base's
%% first -- a nearly empty primary virtual base's own, its VCALL offsets with them, one for each of its virtual functions in its table's
%% order, its destructor's pair one, nearest the offset to top --, then the class's vbase offsets in the order a depth-first walk of
%% its bases as written meets them, then, for a virtual base, a vcall offset for each function it adds: `XJ2 : virtual K, virtual I'
%% has I's two vcall offsets, then K's vbase offset, then I's; `C : virtual N' over `N : virtual V' V's, V's offset, N's new n, N's
cpp_vbo(N, Kind, V0, Vs) :-
    ( '$cpp_vprim'(N, I) -> cpp_vbo(I, virtual, V0, V1) ; cpp_primary_of(N, P) -> cpp_vbo(P, plain, V0, V1) ; V1 = V0 ),
    cpp_bases_written(N, Bs), cpp_vb_walk(Bs, V1, V2),
    ( Kind == virtual -> cpp_vcall_new(N, N, [], V2, Vs) ; Vs = V2 ).
%% clang's AddVCallOffsets for a virtual base T (0.175): one vcall offset for each function of a sub-object's table that has none
%% yet -- its primary chain's and its own, in its table's order, an override of a later base's function a slot of its own among
%% them -- then the same for each later non-virtual base with a table, where it lies in T (SH, its hops; `vcn/5'), whose functions
%% that its own virtual primary declares are that base's: `V : P, Q' as a virtual base has P's a, b and destructor, its own e and
%% d (an override of Q's), then Q's c
cpp_vcall_new(T, N, SH, V0, Vs) :- cpp_class_l(N, cls(_, _, _, _, Slots)),
    findall(VC, ( member(slot(M, K, _, _, _), Slots), M \== '$dtor_del', \+ cpp_vc_has(V0, M, K), ( SH \== [], '$cpp_vprim'(N, _) -> cpp_slot_own(N, M, K) ; true ),
                  ( SH == [] -> VC = vc(N, M, K) ; VC = vcn(T, N, M, K, SH) ) ), New),
    append(V0, New, V1), ( cpp_primary_of(N, P) -> true ; P = none ),
    cpp_bases_written(N, Bs), cpp_vcall_bases(Bs, T, N, P, SH, V1, Vs).
cpp_vcall_bases([], _, _, _, _, Vs, Vs).
cpp_vcall_bases([B-K|Bs], T, N, P, SH, V0, Vs) :-
    ( K == plain, B \== P, cpp_has_table(B), '$cpp_base_slot'(N, B, S) -> append(SH, [S], SH1), cpp_vcall_new(T, B, SH1, V0, V1) ; V1 = V0 ),
    cpp_vcall_bases(Bs, T, N, P, SH, V1, Vs).
cpp_vc_has(V0, M, K) :- ( memberchk(vc(_, M, K), V0) -> true ; memberchk(vcn(_, _, M, K, _), V0) ).
%% a function of N's table that N itself declares: its destructor, an override, a new one
cpp_slot_own(_, M, _) :- memberchk(M, ['$dtor', '$dtor_del']), !.
cpp_slot_own(N, M, K) :- cpp_class(N, cls(_, _, Ms, _, _, _)), cpp_slot_method(N, Ms, M, K, _, _), !.
%% whether X is in I's primary chain, at I's own address
cpp_in_primary_chain(I, X) :- ( '$cpp_vprim'(I, P) -> true ; cpp_primary_of(I, P) ), ( P == X -> true ; cpp_in_primary_chain(P, X) ).
cpp_vb_walk([], Vs, Vs).
cpp_vb_walk([B-K|Bs], V0, Vs) :- ( K == virtual, \+ memberchk(B, V0) -> append(V0, [B], V1) ; V1 = V0 ), cpp_bases_written(B, BBs), cpp_vb_walk(BBs, V1, V2), cpp_vb_walk(Bs, V2, Vs).
%% the base whose table pointer a class shares: its first, where it has none of its own
cpp_primary_of(N, P) :- cpp_class_l(N, cls(P, Data, _, _, _)), P \== none, \+ '$cpp_vbase'(N), \+ memberchk(member(_, '$vptr', _), Data), \+ cpp_empty_class(P), cpp_has_table(P).
%% a class's bases in the order written, each `virtual' or `plain' (a primary base moved first, 0.112, put back)
cpp_bases_written(N, Bs) :- cpp_class_l(N, cls(B, _, _, _, _)), !, ( B == none -> Bs = [] ; ( '$cpp_extra'(N, Es) -> true ; Es = [] ), cpp_written_order(N, [B|Es], Bs) ).   % a later virtual base `virtual' (0.172)
cpp_bases_written(_, []).
%% the table's fields of the slots, the last slot first: `$vbo$K' ... `$vbo$1', `$vbo' (at -24)
cpp_vbo_fields([], _, [], []).
cpp_vbo_fields([E|Es], I, Ms, Items) :- I1 is I + 1, cpp_vbo_fields(Es, I1, Ms0, Items0), ( I =:= 0 -> N = '$vbo' ; atomic_list_concat(['$vbo$', I], N) ),
    append(Ms0, [member(base([], [long]), N, none)], Ms), append(Items0, [item([], E)], Items).
%% a destructor's body, then the base's destructor over the base sub-object
cpp_dtor_body(L, C, fntry(Block, Cs), block([try(L, block(Body1), Cs1)])) :- !, cpp_dtor_body(L, C, Block, block(Body1)), cpp_fntry_handlers(L, Cs, Cs1).   % a FUNCTION-TRY-BLOCK (0.201): the body and the members' and bases' destruction under one try, the exception rethrown at a handler's end, as a constructor's (cpp_ctor_body/7)
cpp_dtor_body(L, C, block(Body), block(Body1)) :-
    cpp_class_l(C, cls(B, Data, _, _, _)),
    reverse(Data, RData),
    (   '$cpp_union'(C) -> MemberDtors = []   % A UNION'S DESTRUCTOR DESTROYS NO MEMBER (0.121; [class.dtor]/16): the members share their storage, and which one is alive is the program's to say -- libc++'s `__union' writes `~__union() {}' and std::variant's own destructor destroys the active alternative; every member destroyed here freed a string twice
    ;   findall(S, ( member(member(MT, N, _), RData), cpp_member_dtor(MT, arrow(this, N), L, Ss), member(S, Ss) ), MemberDtors) ),
    findall(G, ( '$cpp_base_slot'(C, E, Slot), findall(expr(L, call(id(EName), EArgs)), ( \+ '$cpp_lvb'(C, E, _), cpp_dtor(E, EName0), cpp_nv_dtor(C, E, EName0, EName), EName \== '$no_dtor', cpp_vtt_pass(C, E, EName, [addr(arrow(this, Slot))], EArgs) ), G) ), ExtraDtors0),   % one group per later base, empty where it has no destructor -- or is virtual, destroyed with the held ones (0.172)
    ( B \== none, \+ ( cpp_nv_body(C), '$cpp_vbase'(C) ), cpp_dtor(B, BName0), cpp_nv_dtor(C, B, BName0, BName), BName \== '$no_dtor' -> cpp_class_base_place(C, B, BPlace), cpp_vtt_pass(C, B, BName, [BPlace], BArgs), FirstDtor = [expr(L, call(id(BName), BArgs))] ; FirstDtor = [] ),
    ( '$cpp_vbase'(C), '$cpp_vb_holder'(C, _) -> BaseDtor0 = [], LastDtor = FirstDtor ; BaseDtor0 = FirstDtor, LastDtor = [] ),   % a virtual first base beside later virtual bases is destroyed LAST, as it was built first (0.172)
    cpp_bases_in_order(C, BaseDtor0, ExtraDtors0, Written), reverse(Written, BasesDtors),   % the bases in the reverse of the order WRITTEN (a moved primary base among them; one call per base, so the reverse of the calls is the reverse of the bases)
    ( \+ cpp_nv_body(C) -> ( '$cpp_vbase'(C), '$cpp_vb_holder'(C, _) -> cpp_vb_build_all(C, B, Vs0) ; cpp_vb_build_order(C, Vs0) ), reverse(Vs0, Vs) ; Vs = [] ),
    cpp_vb_dtors(Vs, L, C, B, LastDtor, VDtors), append(BasesDtors, VDtors, BaseDtor),   % the virtual bases it holds last, in the reverse of the order they were built in (0.171, 0.173) -- one with virtual bases of its own by its base variant, its part of the VTT handed to it (0.173)
    ( cpp_nv_body(C) -> cpp_vtt_stores(L, C, Store) ; cpp_vptr_store(L, C, Store) -> true ; Store = [] ),   % the base variant the tables of the VTT it was handed, first (0.172)
    append(Store, Body, BodyS), append(BodyS, MemberDtors, Body0), append(Body0, BaseDtor, Body1).
%% THE DESTRUCTOR OF A PATH BASE OF A DIAMOND is its base-variant form, `D.nv' (0.110) -- a path base the library SHIPS a destructor for
%% (`~basic_ostream<wchar_t>()', out of class and not hidden) has none to call, and its definition in the header is empty
%% (0.117): the destructor of a stream base has nothing to do but the virtual base's, which the holder destroys, so the call is
%% left out and `std::wstringstream' (a diamond libc++ does not ship for wchar_t) is destroyed. Any other shipped path destructor
%% keeps the `.nv' name and is refused at the link.
cpp_nv_dtor(C, E, Name0, Name) :-
    (   '$cpp_nv_base'(C, E)
    ->  ( sub_atom(Name0, 0, _, _, '_ZN'), cpp_empty_header_dtor(E) -> Name = '$no_dtor' ; atom_concat(Name0, '.nv', Name) )
    ;   Name = Name0 ).
cpp_empty_header_dtor(E) :- '$cpp_inst'(E, inst(N, _)), '$cpp_mdef'(N, '$dtor', _, _, Item0), cpp_mdef_inner(Item0, dtor(_, _, block([]))), !.
%% the destructor of a held virtual base: a base-variant one's `.nv' form, as a path's (cpp_nv_dtor/4; 0.173)
cpp_vb_dtor_name(V, Name0, Name) :- ( cpp_vb_nv(V) -> ( sub_atom(Name0, 0, _, _, '_ZN'), cpp_empty_header_dtor(V) -> Name = '$no_dtor' ; atom_concat(Name0, '.nv', Name) ) ; Name = Name0 ).
%% ... AND A DESTRUCTOR STORES ITS OWN CLASS'S TABLES FIRST ([class.cdtor]/4, the Itanium ABI's destructor; 0.112): while
%% it runs the object's dynamic type is its class, so a virtual call in it, or in a base's destructor after it, reaches
%% that class's override and never one of a derived class whose members are already destroyed -- `~A() { f(); }'
%% under a D called D::f. A diamond path's base variant (`.nv') stores those of the VTT it is handed (0.172).
%% a member's destruction: a class through its destructor, an array of objects element by element in reverse
cpp_member_dtor(MT, Place, L, [expr(L, call(id(DName), [addr(Place)]))]) :- cpp_class_of_type(MT, MC), cpp_dtor(MC, DName), !.
cpp_member_dtor(MT, Place, L, Ss) :- ccl_resolve_type(MT, arr(B, ET)), cpp_elem_class(ET, EC), cpp_dtor(EC, _), !,
    cpp_array_bound_n(arr(B, ET), N), N1 is N - 1, findall(S, ( between(0, N1, I0), I is N1 - I0, cpp_member_dtor(ET, index(Place, int(I)), L, Es), member(S, Es) ), Ss).
cpp_member_dtor(_, _, _, []).
