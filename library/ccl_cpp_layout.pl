%% ccl_cpp_layout.pl -- a class's layout: POD for the purpose of layout, a member's resolution and alignment, the
%% bases and the virtual bases as the Itanium ABI lays them, defaulted members, the virtual slots and the tables,
%% bitfields. A part of the C++ desugaring that ccl_cpp.pl loads (0.223): its rules as they stood there, in their
%% order.

%% POD FOR THE PURPOSE OF LAYOUT (the Itanium ABI 2.2's term, which is C++03's POD; 0.135), as clang 18 and 21 decide it, measured
%% shape by shape: no base, no virtual function, no non-static data member that is not public, no reference member and no member
%% (or array element) of a class that is no POD, no user-provided constructor (a constructor template counts; `= default' and
%% `= delete' in the class do not, one defaulted out of it does), no default member initializer, no user-provided COPY assignment (a
%% move assignment and an `operator=' from another type do not count), no user-provided destructor, and no lambda's closure. A class that is NOT one is
%% marked `$nonpod' in its tag, and as a base or a `[[no_unique_address]]' member lends its tail padding (ccl_data_size/2).
cpp_layout_pod(K, C, Bases, Ms, Data, Defaults, Slots) :-
    Bases == [], Slots == [], \+ memberchk(member(_, '$vptr', _), Data),
    \+ ( member(N-_, Defaults), memberchk(member(_, N, _), Data) ),
    \+ ( member(M, Ms), M = ctor(_, _, _, _, _), cpp_user_ctor(M) ),
    \+ memberchk(template(_, _, ctor(_, _, _, _, _)), Ms),
    \+ memberchk(dtor(_, _, _), Ms), \+ cpp_dtor_def(C),
    \+ ( member(method(_, _, _, operator('='), [P], _, _), Ms), cpp_copy_assign_param(C, P) ),
    ( K == class -> A0 = private ; A0 = public ), \+ cpp_nonpublic_data(Ms, A0),
    \+ ( member(M1, Ms), cpp_closure_op(M1) ),   % a closure type is none: its captures are its private members, as clang has them
    \+ ( member(member(MT, _, _), Data), cpp_member_not_pod(MT) ).
cpp_copy_assign_param(C, P) :- ( P = param(T, _) ; P = param(T, _, _) ), !, ( T = ref(_, B) -> true ; T = B ), B = base(_, [S]), ( S = typedef(N) ; S = tmpl(N, _) ), atom(N),
    ( cpp_own_name(C, N) -> true ; atom_concat('.', N, DN), atom_concat(_, DN, C) ).   % the class's own name, its template's, or a nested class's short one
cpp_nonpublic_data([access(A)|Ms], _) :- !, cpp_nonpublic_data(Ms, A).
cpp_nonpublic_data([member(T, _, _)|_], A) :- A \== public, \+ cpp_static_type(T, _), !.
cpp_nonpublic_data([_|Ms], A) :- cpp_nonpublic_data(Ms, A).
cpp_member_not_pod(MT) :- ( MT = ref(_, _) ; MT = rref(_, _) ), !.
cpp_member_not_pod(MT) :- catch(cpp_elem_class(MT, MC), _, fail), atom(MC), catch(ccl_tag(MC, TMs), _, fail), TMs \== none, memberchk('$nonpod', TMs), !.
cpp_pod_mark(C, D0, D) :- ( '$cpp_nonpod'(C) -> append(D0, ['$nonpod'], D) ; D = D0 ).
%% A MEMBER WHOSE TYPE NAMES A CALL IS RESOLVED ONCE THE RECORD EXISTS (0.136): a type, or the class typedef it names, with
%% a call in it -- libc++ 20's hh_mm_ss holds `precision __f_;' over `using precision = duration<typename __CommonType::rep,
%% ratio<1, __pow10(fractional_width)>>;' -- asks one of the class's own static member functions, which the evaluator
%% reaches only through the class's record (a template's instance makes its members as they are named). Resolved before
%% it, the argument stayed the call, keyed by its spelling (`ratio.1.callidpow10idfw'), and `ratio''s `__static_gcd' of
%% unfolded terms made instances without end: every `std::chrono::hh_mm_ss', and with it `std::format' of a duration. Such
%% a member is left as written in a first record, resolved, and the record put again (cpp_register_class_).
cpp_member_types_now(C, Ms, Ns, Later) :- ( member(member(T, _, _), Ms), cpp_type_names_call(C, T) -> Later = yes, Ns = Ms ; Later = no, cpp_member_types(Ms, Ns) ).
cpp_type_names_call(_, T) :- cpp_has_call(T), !.
cpp_type_names_call(C, T) :- cpp_mentions_typedef(T, N), '$cpp_ctype'(C, N, Def), cpp_has_call(Def), !.
cpp_type_names_call(C, T) :- cpp_fn_targ_name(T, N), '$cpp_sfn_pre'(C, N), \+ '$cpp_ctype'(C, N, _), !.   % ... and so does `array<int, rank()>' over the class's own static `rank' (0.201): read as a function type, it is the call cpp_targ_value/2 makes of it, which asks the record
cpp_fn_targ_name(fn(base([], [typedef(N)]), [], false), N) :- atom(N), !.
cpp_fn_targ_name(T, N) :- compound(T), T =.. [_|As], member(A, As), cpp_fn_targ_name(A, N), !.
cpp_mentions_typedef(typedef(N), N) :- atom(N).
cpp_mentions_typedef(T, N) :- compound(T), T \= typedef(_), T =.. [_|As], member(A, As), cpp_mentions_typedef(A, N).
%% a data member's type as the struct will hold it: the class's typedef resolved (`pointer' is `int *'), a template-id
%% its instance -- so the inference, asked the member's type by a method's body, answers what a call deduces from; a
%% type that does not resolve here stays as written and is refused where it is used
cpp_member_types([], []).
cpp_member_types([member(base(Q, [union(anon, Us0)]), N, I)|Ms], [member(base(Q, [union(anon, Us)]), N, I)|Ns]) :- !, cpp_member_types(Us0, Us), cpp_member_types(Ms, Ns).
cpp_member_types([member(base(Q, [struct(anon, Us0)]), N, I)|Ms], [member(base(Q, [struct(anon, Us)]), N, I)|Ns]) :- is_list(Us0), !, cpp_member_types(Us0, Us), cpp_member_types(Ms, Ns).   % an anonymous struct kept inside a union (cpp_norm_union_members)
cpp_member_types([member(T0, N, I)|Ms], [member(T, N, I)|Ns]) :- !,
    ( catch(cpp_type(T0, T1), error(not_lowered(W), _), ( cpp_trace(member_type_unresolved(N, W)), fail )) -> cpp_fold_aligned(T1, T) ; T = T0 ), cpp_member_types(Ms, Ns).
cpp_member_types([M|Ms], [M|Ns]) :- cpp_member_types(Ms, Ns).
%% A MEMBER'S ALIGNMENT SPECIFIER FOLDS IN THE CLASS'S WORDS (0.194; [dcl.align]), as its bitfield width and the class's own
%% `alignas' do (cpp_bit_width, cpp_align_tag): `alignas(_Alignment) char __data;' of an instance of libc++ 21's
%% `__alignment_checker_type', `_ALIGNAS_TYPE(_Tp) char __buffer_[sizeof(_Tp)]', `alignas(K)' over a constexpr global -- the
%% layout reads the qualifier `aligned(E)' by the inference's fold, which knows no template's value nor the evaluator
cpp_fold_aligned(base(Q0, S), base(Q, S)) :- !, cpp_fold_align_qs(Q0, Q).
cpp_fold_aligned(ptr(Q0, P0), ptr(Q, P)) :- !, cpp_fold_align_qs(Q0, Q), cpp_fold_aligned(P0, P).   % a pointer member's own (0.203), and its pointee's type's (0.205)
cpp_fold_aligned(arr(B, E0), arr(B, E)) :- !, cpp_fold_aligned(E0, E).
cpp_fold_aligned(T, T).
%% an object's `aligned(E)' and a TYPEDEF's `taligned(E)' folded (0.205: the type of a pointee too, GCC's `aligned' on a class's
%% alias -- libc++ 21's atomic_ref writes `using _Aligned_Tp [[__gnu__::__aligned__(required_alignment)]] = _Tp; _Aligned_Tp
%% *__ptr_;', the alignment a static member of its class)
cpp_fold_align_qs(Q0, Q) :- member(A0, Q0), ( A0 = aligned(E) ; A0 = taligned(E) ), E \= int(_), !, select(A0, Q0, Q1), cpp_array_bound(E, N),
    functor(A0, F, 1), A =.. [F, N], Q = [A|Q1].
cpp_fold_align_qs(Q, Q).
%% what else a class carries: its member templates (by name; a constructor under `ctor'), its typedefs
%% (`typedef T value_type;', `using x = T;': what a dependent name `C::value_type' resolves to), and the
%% constant initializers of its static members (`static const bool value = true;': what `C::value' folds to)
cpp_register_class_extras(C, Ms) :-
    forall(( member(template(_, TPs, M), Ms), cpp_member_key(M, K) ), cpp_mt_put(C, K, TPs, M)),
    forall(member(template(L, TPs, nested(base(_, [class(K, N0, Bs, NMs)]))), Ms), cpp_nested_template_put(C, L, TPs, K, N0, Bs, NMs)),   % a MEMBER CLASS TEMPLATE (below)
    forall(( member(template(L, TPs, nested(base(_, [struct(N0, SMs)]))), Ms), SMs \== none ), cpp_nested_template_put(C, L, TPs, struct, N0, [], SMs)),   % ... WITH A PLAIN STRUCT BODY, empty or of data members only (0.132): the reader gives `template <class> struct __outer_iterator_category {};' of libc++'s lazy_split_view as C's struct, which no clause took -- `template_without_body' for the iterator's base
    forall(member(template(L, TPs, nested(base(_, [struct(N0, none)]))), Ms), cpp_nested_template_put(C, L, TPs, struct, N0, [], none)),   % ... DECLARED ONLY, `template <class _Fp, bool = ...> struct __callable;' beside its two specializations (libc++ 18's std::function): the reader gives a bodyless tag, not a class, and unregistered the primary the specializations were never consulted -- template_without_body (0.93)
    forall(member(template(L, TPs, nested(base(_, [class(N0, none)]))), Ms), cpp_nested_template_put(C, L, TPs, class, N0, [], none)),   % ... and a `class' one DECLARED ONLY, defined out of the class (0.201): `template <class _Extents> class mapping;' of <mdspan>'s layout_left (cpp_mct_def/7)
    forall(( member(typedef(_, Vs), Ms), member(var(N, T, _), Vs) ), cpp_ctype_put(C, N, T)),
    forall(( member(member(MT, N, _), Ms), cpp_static_type(MT, _), member(default_init(N, E), Ms) ), asserta('$cpp_sinit'(C, N, E))),
    forall(( member(member(MT, N, _), Ms), cpp_static_type(MT, _), \+ member(default_init(N, _), Ms), cpp_hdr_item(C, declaration(_, _, _, [var(scoped([C], N), _, E)])), E \== none ),   % ... or defined out of the class in its header (0.101)
           asserta('$cpp_sinit'(C, N, E))),   % the `static' sits in the INNERMOST base's qualifiers, so an array's or a pointer's is reached through cpp_static_type (0.72), where a plain `base(Q, _)' missed it and `static constexpr bool __matches[N] = {...}' -- the array libc++'s get<T> searches -- had no initializer here and was emitted extern
    cpp_class_enums(C, Ms).
%% A MEMBER CLASS TEMPLATE -- `template <class _From> struct _CheckArrayPointerConversion : is_same<_From, pointer> {};'
%% and its partial specialization over `_FromElem *', which guard the array unique_ptr's `reset(_Pp)' -- is a class
%% template under the enclosing class's name (`C.N', as a nested class is named), its specializations with it, and
%% the bare name resolves inside the class and its nested classes ('$cpp_nested_tmpl', cpp_nested_template); an
%% instance of it is ENCLOSED by the class, so the enclosing class's typedefs (`pointer', `element_type') are in
%% scope in its members (cpp_instantiate_class_). Refused as template_without_body since the fourth step.
cpp_nested_template_put(C, L, TPs, K, N0, Bs, NMs) :-
    ( N0 = tmpl(N, Pattern) -> true ; N = N0 ), atomic_list_concat([C, '.', N], MN),
    ( '$cpp_nested_tmpl'(C, N, MN) -> true ; assertz('$cpp_nested_tmpl'(C, N, MN)) ), cpp_trace(nested_template(C, N0)),
    (   N0 = tmpl(_, _) -> cpp_spec_put(MN, TPs, Pattern, declare(L, base([], [class(K, tmpl(MN, Pattern), Bs, NMs)])))
    ;   cpp_template_put(MN, TPs, declare(L, base([], [class(K, MN, Bs, NMs)]))) ).
cpp_nested_template(N, MN) :- nb_getval('$cpp_class_ctx', C), atom(C), C \== none, cpp_nested_template_of(C, N, MN).
cpp_nested_template_of(C, N, MN) :- '$cpp_nested_tmpl'(C, N, MN), !.
cpp_nested_template_of(C, N, MN) :- cpp_enclosing(C, EC), !, cpp_nested_template_of(EC, N, MN).
cpp_nested_template_of(C, N, MN) :- cpp_base_scope(C, B), cpp_nested_template_of(B, N, MN), !.
%% A CLASS-SCOPE ENUMERATOR is a constant OF THE CLASS, as a static const is -- libc++'s `basic_string' writes its
%% short-string capacity as `enum { __min_cap = (sizeof(__long) - 1) / sizeof(value_type) > 2 ? ... : 2 }' and names
%% it bare in its members and in an array's bound. The value stays RAW, since it is written in the class's own words,
%% and folds where it is used (cpp_fold_static); an implicit one is the previous plus one, an expression like any other.
cpp_class_enums(C, Ms) :- forall(( member(M, Ms), cpp_member_enum(M, Es) ), cpp_class_enums_(C, Es, int(0))).
cpp_member_enum(nested(base(_, [enum(_, Es)])), Es) :- is_list(Es).
cpp_member_enum(member(base(_, S), _, _), Es) :- member(enum(_, Es), S), is_list(Es), !.   % AN ENUM THAT TYPES A DATA MEMBER declares its enumerators in the class too (0.112): libc++ 18's `__consume_result' writes `enum : char32_t { __ok, __error } __status : 1 {__ok};', and `__consume_result::__error' named nothing
cpp_class_enums_(_, [], _).
cpp_class_enums_(C, [enum_base(_)|Es], Next) :- !, cpp_class_enums_(C, Es, Next).
cpp_class_enums_(C, [enumerator(N, E)|Es], Next) :- !,
    ( E == none -> V = Next ; V = E ),
    asserta('$cpp_sinit'(C, N, V)),
    cpp_class_enums_(C, Es, bin('+', V, int(1))).
cpp_class_enums_(C, [_|Es], Next) :- cpp_class_enums_(C, Es, Next).
cpp_member_key(method(_, _, _, M, _, _, _), M).
cpp_member_key(ctor(_, _, _, _, _), ctor).
cpp_member_key(typedef(_, [var(N, _, _)|_]), N).      % a member ALIAS template: `template <class A, class B> using _Select = ...' inside its class
%% the class whose members are being declared, walked or emitted: a bare name in them may be its typedef
cpp_in_class(C, Goal) :- nb_getval('$cpp_class_ctx', C0), nb_setval('$cpp_class_ctx', C), ( catch(Goal, E, (nb_setval('$cpp_class_ctx', C0), throw(E))) -> nb_setval('$cpp_class_ctx', C0) ; nb_setval('$cpp_class_ctx', C0), fail ).
%% THE ARGUMENTS ARE THE CALLER'S: a candidate's parameters are read in the callee's class (0.65), and an argument
%% that must be DESUGARED to be typed (cpp_arg_type) is read in the CALLER's -- `__pointer_alloc_traits::allocate(__npa,
%% __nbc)' names the hash table's own alias, which resolved to nothing in unique_ptr's words, so the conditional
%% it sat in was typed by its other arm, `nullptr', and `reset(nullptr_t)' took it: the buckets were never kept
cpp_as_callee(C, Goal) :- nb_getval('$cpp_class_ctx', Caller), ccl_global('$cpp_caller', Old, none), nb_setval('$cpp_caller', caller(Caller)),
    ( catch(cpp_in_class(C, Goal), E, ( nb_setval('$cpp_caller', Old), throw(E) )) -> nb_setval('$cpp_caller', Old) ; nb_setval('$cpp_caller', Old), fail ).
cpp_caller_ctx(Ctx, Class) :- ( ccl_global('$cpp_caller', caller(Class), none) -> ( atom(Class), Class \== none, cpp_class_l(Class, _) -> Ctx = Class ; Ctx = none ) ; nb_getval('$cpp_class_ctx', Class), Ctx = none ).
cpp_class_ctx(C) :- nb_getval('$cpp_class_ctx', C), C \== none.
cpp_class_typedef(C, N, T) :- cpp_class_typedef(C, N, T, _).
%% ... and the class that DEFINES it, whose own typedefs its text is written in: allocator_traits's `pointer' is
%% its base's `__pointer<value_type, allocator_type>', value_type and allocator_type the base's
cpp_class_typedef(C, N, T, C) :- '$cpp_ctype'(C, N, T), !.
cpp_class_typedef(C, N, T, Def) :- cpp_base_scope(C, B), cpp_class_typedef(B, N, T, Def).
cpp_class_typedef(C, N, T, Def) :- cpp_enclosing(C, Enc), cpp_class_typedef(Enc, N, T, Def).   % a nested class sees the enclosing one's types, its inherited ones with them
cpp_static_const(C, N, V) :- cpp_sinit(C, N, E), !, ( catch('$cpp_sfold'(C, N, V0), _, fail) -> V = V0 ; cpp_fold_static(C, N, E, V1), cpp_static_held(C, N, V1, V0), ( ground(V0) -> assertz('$cpp_sfold'(C, N, V0)) ; true ), V = V0 ).   % ONCE PER CLASS AND NAME (0.136), IN ITS OWN TYPE (0.250; both below)
cpp_static_const(C, N, V) :- cpp_base_scope(C, B), cpp_static_const(B, N, V).       % inherited: is_move_constructible<T>::value is integral_constant's
cpp_static_const(C, N, V) :- cpp_enclosing(C, Enc), cpp_static_const(Enc, N, V).   % a NESTED class sees the enclosing one's statics, as it sees its types: libc++'s `basic_string::__long' divides by its holder's `__endian_factor'
%% ... AND THE CONSTANT KEEPS THE MEMBER'S TYPE where it stands in an expression (0.117): `static const long long v = -3;' named `A::v' was the
%% INT literal -3, passed to a variadic call as an int -- `printf("%lld", A::v)' read the upper half of the slot as zero and printed
%% 4294967293 (libc++'s `ratio<-1, 2>::num'), and `static const unsigned n = 4; n - 5' was an int. Only an arithmetic type other
%% than int, an enumeration excepted (it keeps its value's kind, as the inference types an enumerator).
cpp_static_value(C, N, E) :- cpp_static_const(C, N, V), cpp_typed_const(C, N, V, E).
cpp_typed_const(C, N, int(K), E) :- cpp_static_decl_type(C, N, T), !, E = cast(T, int(K)).
cpp_typed_const(_, _, V, V).
cpp_static_decl_type(C, N, base([], Sp)) :-
    catch(( cpp_static_member(C, N, SN), ccl_declared(SN, T0), ccl_resolve_type(T0, T1), T1 = base(_, Sp0), findall(X, ( member(X, Sp0), X \== static ), Sp), Sp \== [], Sp \== [int], cpp_arith(base([], Sp)) ), _, fail).
%% A STATIC CONSTANT HOLDS ITS TYPE'S VALUE (0.250): its fold is converted to the static's own type before it is kept, as C++
%% converts an initializer to the declared type. A library class's statics keep their raw type (cpp_declare_statics: resolving
%% them all at registration took std::format past 3.5 GB), where cpp_typed_const gives no cast, so a value past the type
%% stood as it was folded: libc++'s `__independent_bits_engine<_Engine, unsigned>::_Rp = _Engine::max() - _Engine::min() +
%% _Working_result_type(1)' over a 32-bit engine -- mt19937 where uint_fast32_t is 32 bits, as on macOS -- is 0 in C++ and was
%% 2^32 here, so `integral_constant<bool, _Rp != 0>' chose the overload that draws until a value is below 0, and the CI's C++
%% job on the Intel Mac never finished `stdrandom.cpp' (`stdrandom32.cpp' holds it on every machine). The type is the class
%% record's (cpp_split_members), resolved in the class where its spelling alone does not resolve (a class's typedef), once
%% per static; one of 32 bits or fewer wraps, and a 64-bit static keeps its fold (`npos = -1' is used as -1 throughout).
cpp_static_held(C, N, int(K), int(K1)) :- ( integer(K) ; K = big(_) ), cpp_static_shape(C, N, Bits, Signed), Bits =< 32, !, ccl_w_wrap(K, Bits, Signed, K1).
cpp_static_held(_, _, V, V).
cpp_static_shape(C, N, Bits, Signed) :- catch(cpp_class_l(C, cls(_, _, Ss, _, _)), _, fail), memberchk(N-T0, Ss), !,
    (   catch(( ccl_resolve_type(T0, T1), ccl_cast_shape(T1, Bits, Signed) ), _, fail) -> true
    ;   catch(( cpp_in_class(C, cpp_type(T0, T2)), ccl_resolve_type(T2, T3), ccl_cast_shape(T3, Bits, Signed) ), _, fail) ).
%% a static const's initializer: a constant as it stands, else DESUGARED in the class's own words -- a detection
%% idiom reads `decltype(__test<_Tp>(nullptr, ...))::value', which is a constant only after the overload is picked.
%% A guard per name, since folding it may ask for it again.
%% A STATIC CONSTANT IS FOLDED ONCE (0.136): its value is a function of its class and its name alone, and a SUCCESS is remembered
%% ('$cpp_sfold'/3; a failure is not, since a class still being registered may answer later). Every fold had been made again
%% where the static was named, and a fold asked each static its initializer names twice -- the typed constant's road asks it
%% again -- so libc++'s `__log2_imp<_Xp, _Rp>::value = _Xp & (1ULL << _Rp) ? _Rp : __log2_imp<_Xp, _Rp - 1>::value', 32
%% levels for a 32-bit engine, was 2^32 folds: `std::mt19937' through a distribution never finished (killed at 1500 s since
%% 0.117; `<random>' in Not done, "the cause is not found"). The memo is reset with the unit's registries.
cpp_fold_static(_, _, E, E) :- E = bool(_), !.
cpp_fold_static(C, _, E, int(K)) :- \+ cpp_shadowing_static(C, E), cpp_const_value(E, K), !.
cpp_fold_static(C, N, E, V) :-
    atomic_list_concat(['$cpp_folding:', C, '.', N], K), \+ nb_current(K, yes), nb_setval(K, yes),
    ( catch(cpp_in_class(C, cpp_expr(C, E, E1)), error(not_lowered(_), _), fail) -> true ; E1 = '$none' ),
    nb_setval(K, no), E1 \== '$none',
    ( E1 = bool(_) -> V = E1 ; cpp_const_value(E1, K2) -> V = int(K2) ; fail ).   % a constexpr function's call among them (cpp_const_value)
%% ... BUT THE CLASS'S OWN STATIC SHADOWS A GLOBAL ENUMERATOR OF THE SAME NAME ([basic.lookup.unqual]: class scope
%% before namespace scope; 0.94): `static const fmtflags floatfield = scientific | fixed;' in ios_base names its own
%% `scientific' and `fixed', and the flattened <iostream> of libc++ 18 also holds `enum class chars_format { scientific
%% = 1, fixed = 2, ... }', whose enumerators are global names here -- so the raw fold read 1 | 2 = 3 where the class
%% means 256 | 4 = 260, `setf(fixed, floatfield)' masked the flag away, and `std::fixed' did nothing. Such an
%% initializer is folded in the class's words (the clause below), never raw.
cpp_shadowing_static(C, E) :- cpp_id_in(E, N), ccl_enum_value(N, _), cpp_own_static(C, N), !.
cpp_id_in(id(N), N) :- !.
cpp_id_in(E, N) :- compound(E), E =.. [_|As], member(A, As), cpp_id_in(A, N).
cpp_own_static(C, N) :- cpp_sinit(C, N, _), !.
cpp_own_static(C, N) :- cpp_base_scope(C, B), cpp_own_static(B, N).
%% MULTIPLE INHERITANCE where every base after the first is EMPTY -- no data of its own, no slots, nothing to
%% construct or destroy. C++'s empty base optimization puts such a base at offset 0 and gives it no bytes, so it
%% is no sub-object here either: it is a SCOPE, and its typedefs, its nested enums, its statics and its methods
%% are looked up as the first base's are (cpp_base_scope/2). libc++'s `ctype<char> : public locale::facet, public
%% ctype_base' is one of these, and so is every facet's tag base. A second base WITH storage or slots is refused
%% as before: two sub-objects need a `this' adjusted at every call, which nothing here does.
cpp_extra_bases(L, C, [base(_, B0)|Rest], Base) :-
    cpp_base_name(B0, Base),
    (   cpp_extra_bases_(Rest, 2, Extras, Slots, LVBs)                                % the slots are asserted only once the WHOLE list holds: a refusal part way along would leave one behind for a class registered again later
    ->  forall(( member(N-S, LVBs), \+ '$cpp_lvb'(C, N, _) ), assertz('$cpp_lvb'(C, N, S))),   % A LATER VIRTUAL BASE (0.172; cpp_lvb_holders below)
        cpp_diamond_paths(L, C, [Base|Extras]),   % A DIAMOND ([class.mi]/6): one virtual base reached through two bases is ONE sub-object
        assertz('$cpp_extra'(C, Extras)), cpp_put_base_slots(C, Slots), cpp_trace(extra_bases(C, Extras)),
        forall(( member(N-S, Slots), \+ memberchk(N-S, LVBs), cpp_has_table(N) ), assertz('$cpp_poly_extra'(C, N, S)))   % a later base with a TABLE gets this class's secondary one: its slots, or only its virtual base's offset (0.160) -- a later VIRTUAL one where the class holds it (cpp_held_poly_extras)
    ;   cpp_refuse(L, multiple_inheritance(C)) ).
%% THE PRIMARY BASE COMES FIRST (the Itanium ABI's layout, 2.4 II.3; 0.112): where the first base written has no table
%% and a later non-virtual one has, the first such is the PRIMARY base, laid out at offset 0 with the class's table
%% pointer in it, and the bases written before it follow it in their order. They are still CONSTRUCTED in the order
%% written and destroyed in the reverse ('$cpp_primary_moved'(C, K), K the bases written before it; cpp_ctor_body,
%% cpp_dtor_body). Refused by name since 0.108, `polymorphic_base_after_a_plain_one(C)'. A virtual base is never the primary
%% here, and a virtual FIRST base is none where a non-virtual dynamic base follows it (0.172).
cpp_primary_first(C, [B1|Bs], Bases) :- B1 = base(Q1, N1),
    catch(cpp_base_name(N1, C1), _, fail), ( Q1 = virtual(_) -> true ; \+ cpp_has_table(C1) ),   % a DYNAMIC base (a table, or a virtual base reached through one: 0.160) is the primary, the Itanium ABI's II.3 -- and a VIRTUAL first base is none where a non-virtual dynamic base follows it (II.1b; 0.172: `X : virtual A, R1' shares R1's table, A is a later virtual base)
    append(Before, [base(QV, NV)|After], Bs), QV \= virtual(_), catch(cpp_base_name(NV, CV), _, fail), cpp_has_table(CV),
    \+ ( member(base(QX, NX), Before), QX \= virtual(_), catch(cpp_base_name(NX, CX), _, fail), cpp_has_table(CX) ), !,
    length([B1|Before], K), append([[base(QV, NV), B1], Before, After], Bases),
    retractall('$cpp_primary_moved'(C, _)), assertz('$cpp_primary_moved'(C, K)), cpp_trace(primary_moved(C, CV, K)).
cpp_primary_first(C, Bs, Bases) :- cpp_vprim_select(Bs, VB, IC), !,   % A NEARLY EMPTY VIRTUAL BASE IS THE PRIMARY where no non-virtual base has a table (the Itanium ABI 2.4 II.1b; 0.174)
    retractall('$cpp_vprim'(C, _)), assertz('$cpp_vprim'(C, IC)), retractall('$cpp_vprim_ind'(C, _)), retractall('$cpp_primary_moved'(C, _)), cpp_trace(vprim(C, IC)),
    (   VB == none -> assertz('$cpp_vprim_ind'(C, IC)), Bases = [base(virtual(public), IC)|Bs]   % ... one further in: the first base, no base written (0.176)
    ;   append(Before, [VB|After], Bs), append([[VB], Before, After], Bases), length(Before, K), ( K > 0 -> assertz('$cpp_primary_moved'(C, K)) ; true ) ).
cpp_primary_first(_, Bases, Bases).
%% THE NEARLY EMPTY PRIMARY VIRTUAL BASE (0.174; the Itanium ABI 2.4 II.1b, clang's SelectPrimaryVBase): a class none of whose
%% non-virtual bases has a table takes a NEARLY EMPTY virtual base I -- dynamic, its non-virtual part its table pointer alone -- as
%% its primary: I lies at the class's own address and shares its table pointer, the class's table is I's with its own slots after
%% them, and the class's own members follow the pointer. `X : virtual I' over `struct I { virtual int f(); }' is sixteen bytes, as
%% clang lays it, where it was twenty-four with I after the members. WHICH ONE (0.175): the first nearly empty virtual base in a
%% depth-first walk of the bases as written that is no INDIRECT PRIMARY BASE -- the virtual primary of one of the class's bases --
%% else the first that is one, which clang STEALS (cpp_vprim_walk/5, cpp_indirect_primaries/3; 0.176): `D : virtual X' over `X :
%% virtual I' takes I, X's own primary, and lays it at D's own address, X after D's members, where it lay at X's place; and `D2 :
%% virtual X, virtual I' takes the I it writes. Taken where its own virtual bases lie inside it, at its own address
%% (cpp_vprim_inside/1): `XJ2 : virtual K, virtual I' takes the I written second, `C : virtual N' over `N : virtual V' takes N with V
%% inside it. A primary further in than the class's own bases (0.176) -- stolen, or a virtual base of a virtual base that no base
%% takes -- is the class's FIRST BASE, a virtual one that no base wrote (VB `none', '$cpp_vprim_ind'), which the order of the bases
%% as written, the type information and the lookup of names leave out (cpp_written_order/3, cpp_rtti_chain/2, cpp_base_scope/2,
%% cpp_method/5, cpp_acc_owner/4): its members are the written bases' through them.
cpp_vprim_select(Bs, VB, IC) :-
    \+ ( member(base(Q, NX), Bs), Q \= virtual(_), catch(cpp_base_name(NX, CX), _, fail), cpp_has_table(CX) ),
    findall(N-K, ( member(base(Q, N0), Bs), catch(cpp_base_name(N0, N), _, fail), ( Q = virtual(_) -> K = virtual ; K = plain ) ), WBs),
    cpp_indirect_primaries(WBs, [], IPB), cpp_vprim_walk(WBs, IPB, none, P, F), ( P \== none -> IC = P ; F \== none, IC = F ), ( cpp_vprim_inside(IC) -> true ; cpp_has_nv_form(IC) ),   % ... or laid as its base-variant form, its virtual bases outside it the class's (0.178)
    ( member(VB0, Bs), VB0 = base(virtual(_), N1), catch(cpp_base_name(N1, IC0), _, fail), IC0 == IC -> VB = VB0 ; VB = none ), !.
%% clang's SelectPrimaryVBase: P the first nearly empty virtual base no indirect primary, F the first nearly empty one that is
cpp_vprim_walk([], _, F, none, F).
cpp_vprim_walk([B-K|Bs], IPB, F0, P, F) :-
    (   K == virtual, cpp_nearly_empty(B), \+ memberchk(B, IPB) -> P = B, F = F0
    ;   ( K == virtual, F0 == none, cpp_nearly_empty(B) -> F1 = B ; F1 = F0 ),
        cpp_bases_written(B, BBs), cpp_vprim_walk(BBs, IPB, F1, P1, F2),
        ( P1 \== none -> P = P1, F = F2 ; cpp_vprim_walk(Bs, IPB, F2, P, F) ) ).
%% clang's getIndirectPrimaryBases: the virtual primary of each base that has virtual bases, and of each of its bases that has them
cpp_indirect_primaries([], S, S).
cpp_indirect_primaries([B-_|Bs], S0, S) :-
    (   cpp_vbases_of(B, [_|_]) -> ( '$cpp_vprim'(B, P), \+ memberchk(P, S0) -> S1 = [P|S0] ; S1 = S0 ), cpp_bases_written(B, BBs), cpp_indirect_primaries(BBs, S1, S2)
    ;   S2 = S0 ),
    cpp_indirect_primaries(Bs, S2, S).
%% clang's isNearlyEmpty: dynamic, and its non-virtual part its table pointer alone -- a non-virtual first base that is nearly
%% empty, the later ones empty, its virtual bases outside that part (or the nearly empty one it shares the pointer with: 0.175)
cpp_nearly_empty(I) :- cpp_has_table(I), cpp_class_l(I, cls(B, Data, _, _, _)), \+ ( member(member(_, N, _), Data), N \== '$vptr' ),
    ( B == none -> true ; cpp_empty_class(B) -> true ; '$cpp_vbase'(I) -> true ; cpp_nearly_empty(B) ),
    \+ ( '$cpp_extra'(I, Es), member(E, Es), \+ cpp_empty_class(E), \+ '$cpp_lvb'(I, E, _) ).
%% a nearly empty base whose virtual bases lie inside it, at its own address: none, or its complete object no more than its pointer
cpp_vprim_inside(I) :- cpp_vbases_of(I, Vs), ( Vs == [] -> true ; catch(once(( ccl_resolve_type(base([], [typedef(I)]), T), ccl_size_align(T, S, _) )), _, fail), S =:= 8 ).   % the size asked once (0.178): backtracking into it laid `I : virtual A' out without A
%% A NEARLY EMPTY PRIMARY WHOSE VIRTUAL BASES LIE OUTSIDE IT (0.178; clang's SelectPrimaryVBase asks nothing of them): `C : virtual I'
%% over `I : virtual A', A with data, takes I, laid as its base-variant form -- its table pointer alone, at the class's own address,
%% built by its base-variant constructor and its part of the VTT -- and the class HOLDS every virtual base of I ('$cpp_nv_base'(C,
%% I), '$cpp_vb_holder'(C, A); cpp_lvb_holders/3): those outside it at its end, A at 16 in 32 bytes as clang lays it, where C kept a
%% table pointer of its own and I whole after its members, 40 bytes; and those at I's own address, its own primary chain's, which
%% lie at the class's (cpp_vbase_loc/3) and have no member (cpp_vb_at_self/2), built and destroyed by the class too, since I's base
%% variant builds none of them.
cpp_vprim_outside(I) :- \+ cpp_vprim_inside(I).
%% a virtual base the class holds at its own address: one at its nearly empty primary's, laid as its base-variant form (0.178)
cpp_vb_at_self(C, V) :- '$cpp_vb_holder'(C, V), cpp_vbase_loc(C, V, H), H == [], !.
%% the base calls in the order the bases were WRITTEN: the later bases' calls come in one GROUP per base (a base with
%% nothing to construct or destroy has an empty one), and the first K groups go before the primary where it was moved
cpp_bases_in_order(C, First, Groups, Ordered) :- '$cpp_primary_moved'(C, K), \+ '$cpp_vprim'(C, _), length(GA, K), append(GA, GB, Groups), !,   % a VIRTUAL primary is built before every non-virtual base (0.174)
    cpp_concat(GA, A), cpp_concat(GB, B), append(A, First, AF), append(AF, B, Ordered).
cpp_bases_in_order(_, First, Groups, Ordered) :- cpp_concat(Groups, Ex), append(First, Ex, Ordered).
cpp_concat([], []).
cpp_concat([L|Ls], Out) :- cpp_concat(Ls, O2), append(L, O2, Out).
%% ... the first path holds it, where that base lays it; every later base whose OWN virtual base it is gets embedded
%% as its `.nv' form, without the shared base, and reaches it through its table's vbase offset (0.110). A later path
%% that does not hold the shared base as its own first, table-reached virtual base is refused by name, never a copy of
%% its own -- which is what this compiler did: `pb->a = 11' was not seen through `pc->a'.
%% THE ABI'S LAYOUT where it can be had: every path is the base's `.nv' form and the complete object holds the shared
%% base once, `$vb', at its END ('$cpp_vb_holder'), building it first and destroying it last -- clang's record layout
%% of `struct D : B, C' over `virtual A' byte for byte. Where a path holds the base only further in (its own first base
%% does), that path is kept whole and the later ones are `.nv' (the mixed form).
cpp_diamond_paths(L, C, Bs) :- '$cpp_lvb'(C, _, _), !, cpp_written_order(C, Bs, WBs), cpp_lvb_holders(L, C, WBs).   % A LATER VIRTUAL BASE (0.172; below)
cpp_diamond_paths(L, C, Bs) :- '$cpp_vprim'(C, I), cpp_vprim_outside(I), !, cpp_written_order(C, Bs, WBs), cpp_lvb_holders(L, C, WBs).   % ... and A NEARLY EMPTY PRIMARY WHOSE VIRTUAL BASES LIE OUTSIDE IT, beside a plain base (0.178)
cpp_diamond_paths(_, C, Bs) :- \+ '$cpp_vbase'(C), cpp_holder_paths(Bs, Hs, Vs), !, cpp_note_holder(C, Hs, Vs).   % EVERY PATH THAT HOLDS VIRTUAL BASES IS ITS `.nv' FORM, and the class holds them all, last (0.171; cpp_holder_paths/3)
cpp_diamond_paths(L, C, Bs) :- cpp_shared_vbase(Bs, V), !,
    findall(X, ( member(X, Bs), cpp_vbases_of(X, VX), memberchk(V, VX) ), Hs),
    (   forall(member(H, Hs), cpp_direct_nv(C, H, V))
    ->  forall(member(H, Hs), assertz('$cpp_nv_base'(C, H))), assertz('$cpp_vb_holder'(C, V)), cpp_trace(vb_holder(C, V, Hs))
    ;   Hs = [_|Later], forall(member(H, Later), cpp_direct_nv(C, H, V))
    ->  forall(member(H, Later), assertz('$cpp_nv_base'(C, H))), cpp_trace(nv_bases(C, Later, V))
    ;   cpp_refuse(L, virtual_base_by_two_paths(C, V)) ).
cpp_diamond_paths(_, _, _).
%% A LATER VIRTUAL BASE (0.172; [class.mi]/4, the Itanium ABI 2.4 II.1b and III): `X : virtual A, virtual W', `Y : B, virtual
%% A', and a virtual first base beside a primary one, `X : virtual A, R1' (cpp_primary_first) -- refused as
%% multiple_inheritance until 0.171. The class HOLDS every virtual base its bases name ('$cpp_vb_holder': `$vb', `$vb$2' ...,
%% built first by the complete object and destroyed last), a path's through the path's `.nv' form, in inheritance graph
%% order: the bases as written, a virtual one before the virtual bases of its own (clang's LayoutVirtualBases) -- but a
%% virtual first base that is no primary, which keeps the 0.110 model, `$base' and the table's first slot, and is built
%% first. A later one is reached by its slot `$base$K', a pseudo-member the class's struct marks `vbase_ref(Slot, T,
%% Off)', the table's vbase offset at Off, -24 - 8I for its I-th slot (cpp_vb_slots/2, cpp_vbase_refs/2); an EMPTY one has no
%% slot and no member and lies at the object's own address, its offset the table's (cpp_vbase_entry/4). A LATER VIRTUAL BASE
%% WITH VIRTUAL BASES OF ITS OWN (0.173; `X : B, virtual V' over `V : virtual A') is held as its base-variant form, `V.nv', and its
%% virtual bases with it (cpp_vb_nv/1: a member of the nv struct, built by the base-variant constructor and its part of the VTT);
%% a virtual FIRST base with virtual bases of its own keeps the 0.110 model, whole and last, its own virtual bases inside it (the
%% same bytes as clang's V.nv and A after it). A later virtual base whose virtual bases cannot be laid so and a path not laid as
%% a `.nv' form are refused by name.
cpp_lvb_holders(L, C, WBs) :-
    ( '$cpp_vprim'(C, V0) -> true ; '$cpp_vbase'(C), WBs = [V0-virtual|_] -> true ; V0 = none ),   % a nearly empty primary written after another virtual base (0.175)
    ( member(V-virtual, WBs), V \== V0, cpp_vbases_of(V, [_|_]), \+ cpp_nv_vbase(V) -> cpp_refuse(L, virtual_base_over_virtual_base(C, V)) ; true ),
    ( member(P-plain, WBs), cpp_vbases_of(P, [_|_]), \+ cpp_nv_capable(P) -> cpp_refuse(L, virtual_base_laid_otherwise(C, P)) ; true ),
    cpp_vbases_walk(WBs, Vs0), cpp_first_each(Vs0, VBs),
    (   V0 == none -> Held = VBs
    ;   '$cpp_vprim'(C, V0), cpp_vprim_outside(V0) -> cpp_drop_all(VBs, V0, Held), ( '$cpp_nv_base'(C, V0) -> true ; assertz('$cpp_nv_base'(C, V0)) )   % a nearly empty primary whose virtual bases lie outside it: its base-variant form, the class holding every one of them (0.178)
    ;   cpp_vbases_of(V0, V0s), cpp_drop_all(VBs, V0, H0), cpp_drop_list(V0s, H0, Held) ),
    findall(P, ( member(P-plain, WBs), cpp_vbases_of(P, [_|_]) ), Ps), cpp_note_holder(C, Ps, Held).
%% a later virtual base laid as its base-variant form: one that can be (0.173)
cpp_nv_vbase(V) :- cpp_nv_capable(V).
cpp_drop_list([], Xs, Xs).
cpp_drop_list([D|Ds], Xs, Ys) :- cpp_drop_all(Xs, D, Xs1), cpp_drop_list(Ds, Xs1, Ys).
%% a class's bases in the order WRITTEN, each `virtual' or `plain', from its first base and its later ones (a primary base
%% moved first, 0.112, put back)
cpp_written_order(C, [B|Es], WBs) :- '$cpp_vprim_ind'(C, B), !, findall(E-K, ( member(E, Es), ( '$cpp_lvb'(C, E, _) -> K = virtual ; K = plain ) ), WBs).   % a primary virtual base further in is no base written (0.176)
cpp_written_order(C, [B|Es], WBs) :- ( '$cpp_vbase'(C) -> K0 = virtual ; K0 = plain ),
    findall(E-K, ( member(E, Es), ( '$cpp_lvb'(C, E, _) -> K = virtual ; K = plain ) ), Ex), Bs1 = [B-K0|Ex],
    ( '$cpp_primary_moved'(C, K1), Bs1 = [P|Rest], length(Front, K1), append(Front, Back, Rest) -> append(Front, [P|Back], WBs) ; WBs = Bs1 ).
cpp_direct_nv(_, E, V) :- cpp_vbase_dynamic(E), cpp_class_l(E, cls(V1, _, _, _, _)), V1 == V.   % a library path too (0.160): `struct X : std::istream, std::ostream' over one basic_ios
cpp_direct_nv(_, E, V) :- '$cpp_vb_holder'(E, V1), V1 == V.   % a path that holds the shared base FURTHER IN, itself a holder (0.163): its `.nv' form is the ABI's
%% EVERY CLASS OVER A VIRTUAL BASE IS LAID OUT AS THE ITANIUM ABI LAYS IT (2.4 II; 0.163): its non-virtual part is the same in every
%% context, and its virtual base lies at the end of the COMPLETE object. A class whose one non-virtual base holds a virtual base V
%% -- a class over a virtual base (`B : virtual V'), or a holder itself -- is a HOLDER of V: that base is its `.nv' form, the class's
%% own members follow it, and V is the class's own `$vb', last ('$cpp_nv_base', '$cpp_vb_holder'), built first by the complete
%% object and destroyed last, the bases built by their base-variant constructors (`.nv'). Embedded whole, `struct D : B' over `B :
%% virtual V' was [B (its table pointer, its members, V), D's members], where clang lays [B's table pointer and members, D's
%% members, V]: a member of D lay past V, and a class with TWO such paths (`P1 : Q1', `P2 : Q2' over `Q1, Q2 : virtual A') could not
%% be laid at all (`virtual_base_by_two_paths') -- its paths' own methods read their members where their complete layout put them.
%% Since 0.171 every virtual base of the path, as cpp_holder_paths/3 below gives them (one virtual base only, from 0.163).
cpp_path_holder(C, [base(virtual(_), _)], B) :- !, ( '$cpp_vprim'(C, B), cpp_vprim_outside(B) -> cpp_written_order(C, [B], WBs), cpp_lvb_holders(0, C, WBs) ; true ).   % a nearly empty primary whose virtual bases lie outside it: the class holds them (0.178)
cpp_path_holder(C, _, B) :- cpp_holder_paths([B], Hs, Vs), !, cpp_note_holder(C, Hs, Vs).
cpp_path_holder(_, _, _).
%% A CLASS HOLDS EVERY VIRTUAL BASE OF ITS PATHS (0.171; the Itanium ABI 2.4 III): each base that has virtual bases -- one path
%% or several, one virtual base or several -- is its `.nv' form, its virtual bases left out, and the class lays them all at its
%% end, each once, in the order a depth-first walk of its bases meets them (`$vb', `$vb$2' ...; clang's LayoutVirtualBases),
%% building them first and destroying them last; an EMPTY one at the object's own address, with no member (0.173: the base stayed
%% whole until then). Where a path cannot be `.nv' (its virtual bases laid otherwise), the class is laid as before. `struct H1 :
%% Q1, R1' over `Q1 : virtual A' and `R1 : virtual W' was its bases
%% whole, A inside Q1 and W inside R1, where clang lays [Q1, R1, h1, A, W]; and a diamond over the two, `D : H1, H2', was
%% refused (`virtual_base_by_two_paths'): its paths' own members were read where their complete layout put them.
cpp_holder_paths(Bs, Hs, Vs) :- findall(H, ( member(H, Bs), cpp_vbases_of(H, [_|_]) ), Hs), Hs \== [],
    forall(member(H, Hs), cpp_nv_capable(H)), findall(V, ( member(H, Hs), cpp_vbases_of(H, HV), member(V, HV) ), Vs0), cpp_first_each(Vs0, Vs).
cpp_nv_capable(H) :- cpp_vbases_of(H, Vs), sort(Vs, S), ( cpp_vbase_dynamic(H) -> cpp_class_l(H, cls(V0, _, _, _, _)), cpp_vbases_of(V0, V0s), F = [V0|V0s] ; F = [] ), findall(V, '$cpp_vb_holder'(H, V), HV), append(F, HV, All), All \== [], sort(All, S).   % its table-reached first base -- and that one's own virtual bases, reached through its table (0.173) --, its held ones, or both (0.172)
cpp_first_each([], []).
cpp_first_each([X|Xs], [X|Ys]) :- cpp_drop_all(Xs, X, Xs1), cpp_first_each(Xs1, Ys).
cpp_drop_all([], _, []).
cpp_drop_all([Y|Ys], X, Zs) :- ( Y == X -> Zs = Zs1 ; Zs = [Y|Zs1] ), cpp_drop_all(Ys, X, Zs1).
cpp_note_holder(C, Hs, Vs) :-
    forall(( member(H, Hs), \+ '$cpp_nv_base'(C, H) ), assertz('$cpp_nv_base'(C, H))), forall(( member(V, Vs), \+ '$cpp_vb_holder'(C, V) ), assertz('$cpp_vb_holder'(C, V))), cpp_trace(vb_holder(C, Vs, Hs)).
%% the member a held virtual base lies in, by its place in the order: `$vb', `$vb$2' ...
cpp_vb_name(C, V, N) :- findall(X, '$cpp_vb_holder'(C, X), Xs), once(nth1(I, Xs, V)), ( I =:= 1 -> N = '$vb' ; atomic_list_concat(['$vb$', I], N) ).
cpp_vb_member(N) :- atom(N), ( N == '$vb' -> true ; sub_atom(N, 0, 4, _, '$vb$') ).
%% the base-subobject form, `C.nv', of a class over a virtual base (its `$base' the table-reached base) or of a holder (without its
%% `$vb', the shared base not laid out)
cpp_has_nv_form(C) :- ( cpp_vbase_dynamic(C) -> true ; '$cpp_vb_holder'(C, _) -> true ).   % one answer: a holder of two virtual bases was two (0.178)
cpp_nv_form(C, Data2, NVData) :- cpp_vbase_dynamic(C), !, cpp_nv_data(C, Data2, NVData).
cpp_nv_form(C, Data2, NVData) :- '$cpp_vb_holder'(C, _), !, findall(M, ( member(M, Data2), \+ ( M = member(_, N, _), cpp_vb_member(N) ), M \= empty_vsub(_, _) ), NVData).   % no empty virtual base either (0.235): a base-variant form holds no virtual base
cpp_shared_vbase(Bs, V) :- append(_, [X|Ys], Bs), member(Y, Ys), cpp_vbases_of(X, VX), cpp_vbases_of(Y, VY), member(V, VX), memberchk(V, VY), !.
cpp_diamond_shaped(C) :- cpp_vbases_of(C, Vs), msort(Vs, S), append(_, [X, Y|_], S), X == Y, !.   % the type information's __diamond_shaped_mask: a virtual base reached twice below the class, as clang sets it (0.163)
cpp_vbases_of(C, Vs) :- cpp_class_l(C, _), !, cpp_bases_written(C, Bs), cpp_vbases_walk(Bs, Vs).   % in the order the bases were WRITTEN, a later virtual one among them (0.172)
cpp_vbases_of(_, []).
cpp_vbases_walk([], []).
cpp_vbases_walk([B-K|Bs], Vs) :- cpp_vbases_of(B, VB), ( K == virtual -> V1 = [B|VB] ; V1 = VB ), cpp_vbases_walk(Bs, V2), append(V1, V2, Vs).
%% THE ORDER THE VIRTUAL BASES ARE BUILT IN ([class.base.init]/13; 0.173): a depth-first left-to-right traversal, each base's own
%% virtual bases before it -- a post-order, where the layout is a pre-order (cpp_vbases_walk/2): `X : B, virtual V' over `V :
%% virtual A' lays V then A and builds A then V, as clang's vbases() has it; the two agree for every shape before 0.173
cpp_vb_post(C, Vs) :- cpp_bases_written(C, Bs), cpp_vb_post_walk(Bs, [], Vs).
cpp_vb_post_walk([], Vs, Vs).
cpp_vb_post_walk([B-K|Bs], V0, Vs) :- cpp_vb_post(B, BV), findall(X, ( member(X, BV), \+ memberchk(X, V0) ), New), append(V0, New, V1),
    ( K == virtual, \+ memberchk(B, V1) -> append(V1, [B], V2) ; V2 = V1 ), cpp_vb_post_walk(Bs, V2, Vs).
cpp_vb_build_order(C, Vs) :- findall(V, '$cpp_vb_holder'(C, V), Hs), cpp_vb_post(C, P), findall(V, ( member(V, P), memberchk(V, Hs) ), Vs1),
    findall(V, ( member(V, Hs), \+ memberchk(V, Vs1) ), Rest), append(Vs1, Rest, Vs).
%% a held virtual base laid, built and destroyed as its base-variant form: one with virtual bases of its own (0.173)
cpp_vb_nv(V) :- cpp_has_nv_form(V).
%% A VIRTUAL BASE THAT A BASE SUB-OBJECT TAKES AS ITS PRIMARY (the Itanium ABI 2.4 II.1b and III; 0.174): a nearly empty virtual base I
%% lies where the first base sub-object whose own primary it is lies -- clang's ComputeBaseSubobjectInfo claims it for the first
%% such in a depth-first walk of the bases as written, each virtual base walked once -- and shares that sub-object's table pointer:
%% the holder lays no member for it ('$cpp_vb_claim'(C, I, Hops)), builds it there and reaches it through the tables as before.
%% `Y : X' over `X : virtual I' is X's pointer and members, then Y's, I at offset 0; `Z : X1, X2' lays I at X1's place.
cpp_note_claims(C) :- ( '$cpp_vb_holder'(C, _) -> cpp_bases_written(C, WBs), cpp_claim_walk(WBs, C, C, [], [], _) ; true ).
cpp_claim_walk([], _, _, _, Seen, Seen).
cpp_claim_walk([B-virtual|Bs], Top, N, H, Seen0, Seen) :- memberchk(B, Seen0), !, cpp_claim_walk(Bs, Top, N, H, Seen0, Seen).
cpp_claim_walk([B-K|Bs], Top, N, H, Seen0, Seen) :-
    (   K == virtual -> Seen1 = [B|Seen0], ( cpp_claim_vloc(Top, B, BH) -> true ; BH = none )
    ;   Seen1 = Seen0, ( cpp_claim_hop(N, B, Hop) -> append(H, Hop, BH) ; BH = none ) ),
    (   BH \== none, '$cpp_vprim'(B, I), '$cpp_vb_holder'(Top, I), \+ '$cpp_vb_claim'(Top, I, _) -> assertz('$cpp_vb_claim'(Top, I, BH)), cpp_trace(vb_claim(Top, I, BH)) ; true ),
    (   BH \== none -> cpp_bases_written(B, BBs), cpp_claim_walk(BBs, Top, B, BH, Seen1, Seen2) ; Seen2 = Seen1 ),
    cpp_claim_walk(Bs, Top, N, H, Seen2, Seen).
%% where a plain base lies in its class, and where the class being laid lays a virtual base
cpp_claim_hop(N, B, Hop) :- cpp_class_l(N, cls(B0, _, _, _, _)), B0 == B, \+ '$cpp_vbase'(N), !, ( cpp_empty_class(B) -> Hop = [] ; Hop = ['$base'] ).
cpp_claim_hop(N, B, [S]) :- '$cpp_base_slot'(N, B, S), \+ '$cpp_lvb'(N, B, _), !.
cpp_claim_vloc(Top, V, H) :- '$cpp_vb_claim'(Top, V, H), !.
cpp_claim_vloc(Top, V, _) :- cpp_vb_at_self(Top, V), !, fail.   % one at the class's own address: in its primary's chain, no sub-object of its own to claim from (0.178)
cpp_claim_vloc(Top, V, [VN]) :- '$cpp_vb_holder'(Top, V), \+ cpp_empty_class(V), !, cpp_vb_name(Top, V, VN).
cpp_claim_vloc(Top, V, ['$base']) :- '$cpp_vbase'(Top), \+ '$cpp_vprim'(Top, _), cpp_class_l(Top, cls(V0, _, _, _, _)), V0 == V, !.
cpp_put_base_slots(_, []).
cpp_put_base_slots(C, [N-Slot|Ss]) :- ( '$cpp_base_slot'(C, N, _) -> true ; assertz('$cpp_base_slot'(C, N, Slot)) ), cpp_put_base_slots(C, Ss).
%% ... AND A SECOND BASE WITH STORAGE IS A SUB-OBJECT OF ITS OWN, `$base$2', `$base$3' ..., laid out after the
%% first base and before the class's own members, as the ABI has the non-virtual bases ([class.derived]): that is
%% how std::tuple is built -- `__tuple_impl<__tuple_indices<_Indx...>, _Tp...> : public __tuple_leaf<_Indx, _Tp>...',
%% one base per element, each holding a value -- and std::bind stores its bound arguments in one. Only a
%% POLYMORPHIC extra base is still refused: two tables need a `this' adjusted at every call, which nothing here does.
cpp_extra_bases_([], _, [], [], []).
cpp_extra_bases_([base(Q, B0)|Bs], K, [N|Ns], Slots, LVBs) :- cpp_base_name(B0, N),   % a POLYMORPHIC second base keeps its own table pointer in its sub-object (0.108): the class makes it a secondary table of this-adjusting thunks (cpp_secondary_table)
    (   cpp_empty_class(N) -> Slots = Slots1, ( Q = virtual(_) -> LVBs = [N-none|LVBs1] ; LVBs = LVBs1 )   % EMPTY: no sub-object, C++'s empty base optimization (0.71) -- a virtual one still a virtual base, at the object's own address (0.172)
    ;   atomic_list_concat(['$base$', K], Slot), Slots = [N-Slot|Slots1], ( Q = virtual(_) -> LVBs = [N-Slot|LVBs1] ; LVBs = LVBs1 ) ),   % a later VIRTUAL base's slot is reached through the table (0.172; cpp_lvb_holders)
    K1 is K + 1, cpp_extra_bases_(Bs, K1, Ns, Slots1, LVBs1).
cpp_empty_class(N) :- cpp_class_l(N, cls(B, Data, _, _, Slots)), Slots == [], ( B == none -> true ; cpp_empty_class(B) ), cpp_empty_data(Data).
%% ... ITS DATA MEMBERS, IF ANY, ARE EMPTY DATA MEMBERS (0.198), `[[no_unique_address]]' members of empty class type, as the layout has
%% them (ccl_no_data_members/1): `struct S : H { int x; }' over `struct H { [[no_unique_address]] E e; }' is four bytes, H an empty
%% base, and no zero-fill of such a member writes its byte over the member that shares its address
cpp_empty_data([]) :- !.
cpp_empty_data(Data) :- \+ ( member(D, Data), \+ cpp_empty_data_member(D) ).
cpp_empty_data_member(member(T, _, W)) :- W == no_unique_address,
    ( catch(cpp_class_of_type(T, C), _, fail), cpp_class_l(C, _) -> cpp_empty_class(C) ; catch(ccl_resolve_type(T, T1), _, fail), ccl_empty_layout(T1) ).   % a plain struct, which is no registered class, by the layout's test
%% every class a name is looked up in: the base sub-object first, then the empty bases
cpp_base_scope(C, B) :- cpp_class_l(C, cls(B, _, _, _, _)), B \== none, \+ '$cpp_vprim'(C, B).
cpp_base_scope(C, B) :- '$cpp_extra'(C, Bs), member(B, Bs).
cpp_base_scope(C, B) :- '$cpp_vprim'(C, B), \+ '$cpp_vprim_ind'(C, B).   % a primary virtual base moved first after the bases written after it, which may hide its names; one no base wrote, found through them (0.176)
%% a base named by a template-id is its instance
cpp_base_name(B, B) :- atom(B), cpp_class_l(B, _), !.                 % a class's own name
%% ... and an ALIAS of an instance names the INSTANCE, as a parameter's type has since 0.58: libc++ derives its
%% traits from `true_type', which is `integral_constant<bool, true>', and the atom was taken for a class's name
%% (base_not_registered). A name that is neither resolves to itself, as it did.
%% ... AND A BASE WRITTEN `decltype(e)' ([class.derived]/1: a class-or-decltype) IS THE CLASS OF ITS EXPRESSION'S TYPE (0.191):
%% libc++'s `struct __well_formed_deleter : decltype(std::__well_formed_deleter_test<_Dp, _Pt>(0)) {}', a true_type or a
%% false_type by overload resolution, was refused base_shape, so `__shared_ptr_deleter_ctor_reqs<_Dp, _Yp, _Tp>::value' did
%% not fold and `std::shared_ptr<int> sp(new int(7), d)' had no constructor (no_constructor('shared_ptr.int', 2)).
cpp_base_name(B0, B) :- ( B0 = decltype(E) -> T0 = base([], [decltype(E)]) ; T0 = base([], [typedef(B0)]) ), cpp_type(T0, T), !,   % what came back, when it is not a class's name
    (   T = base(_, [typedef(B1)]), atom(B1), B1 \== B0 -> B = B1
    ;   T = base(_, [S]), cpp_tag_name(S, B1) -> B = B1                                      % a name the tag table resolved to its STRUCT: `__tuple_leaf<_Ip, _Hp, true> : private _Hp' with _Hp an empty class (libc++'s tuple, the empty base optimization)
    ;   cpp_alias_class(B0, B1) -> B = B1                                                    % AN ALIAS OF A CLASS (0.117): `using ZA = Z; struct Y : ZA' -- cpp_type leaves the alias as it is, and `ZA' was refused base_not_registered
    ;   T = base(_, [typedef(B1)]), atom(B1) -> B = B1
    ;   cpp_refuse(0, base_shape(T)) ).
cpp_base_name(B0, _) :- cpp_template_id(B0, N, Args), !,                                  % say WHICH half failed: the arguments, or the instantiation
    (   \+ cpp_targ_values(Args, _) -> cpp_refuse(0, base_arguments(N))
    ;   cpp_targ_values(Args, As), \+ cpp_instantiate_class(N, As, _) -> cpp_refuse(0, base_instance(N))
    ;   cpp_refuse(0, base_not_a_class(N)) ).
cpp_base_name(B0, _) :- cpp_refuse(0, base_not_a_class(B0)).
cpp_alias_class(A, N) :- atom(A), once(ccl_resolve_type(base([], [typedef(A)]), base(_, [S]))), cpp_tag_name(S, N), N \== A.
cpp_tag_name(struct(N, _), N) :- atom(N).
cpp_tag_name(union(N, _), N) :- atom(N).
cpp_tag_name(class(_, N, _, _), N) :- atom(N).
%% the class a scope names: `C', `X<T>' (its instance), `A::B<T>'; a namespace is no class
cpp_scope_class(Path, C) :- cpp_where(scope(Path), cpp_scope_class_(Path, C)).
cpp_scope_class_(Path, C) :- Path = [_, _|_], cpp_path_keys(Path, Path1), Path1 \== Path, !, cpp_scope_class_(Path1, C).   % A COLLIDED CLASS NAMED THROUGH ITS NAMESPACES is its key (0.121), below
cpp_scope_class_(Path, C) :- Path = [_, _|_], cpp_scope_walk(Path, none, C), !.   % TWO OR MORE SEGMENTS ARE WALKED FIRST, each named inside the one before (0.112): the last one alone is looked up in the CURRENT class, and libc++'s `_ITER_CONCEPT' is `typename __iter_concept_cache<_Iter>::type::template _Apply<_Iter>' -- asked inside `__invokable_r', which has a `type' of its own, the path took that one, `_Apply' was no member of it and was instantiated bare (template_without_body), and `input_iterator' of a vector's iterator came out unmet
cpp_scope_class_(Path, C) :- ccl_last(Path, P), cpp_path_class(P, C), !.
cpp_scope_class_(Path, C) :- cpp_scope_walk(Path, none, C).      % a path of two or more CLASS segments, each named inside the one before: allocator_traits<A>::propagate_on_container_swap::value
cpp_scope_walk([], C, C) :- C \== none.
cpp_scope_walk([S|Ss], none, C) :- !, ( cpp_path_class(S, C1) -> cpp_scope_walk(Ss, C1, C) ; cpp_scope_walk(Ss, none, C) ).   % a namespace's segment names no class: skipped
cpp_scope_walk([S|Ss], Cx, C) :- ( cpp_in_class(Cx, cpp_path_class(S, C1)) -> cpp_scope_walk(Ss, C1, C)
    ;   cpp_class_typedef(Cx, S, _, _) -> fail                                          % a TYPE of the class that is no class ENDS the path: `B::strong::two' names a nested enum's enumerator, and skipping the segment made the static member `B.two'
    ;   cpp_scope_walk(Ss, Cx, C) ).
%% `ns::visitation::base::make_dispatch<F>(...)' with `base' declared by three namespaces: the class segment, qualified by the namespaces before it, is the KEY
%% cpp_ns_key finds (`visitation.base'), as a type name's is (cpp_type) -- walked bare it was the first declared class of the name, which has no such member.
%% Only a segment that follows namespace segments (atoms) is looked at; a class's own member segments are not.
cpp_path_keys(Path, Path1) :- cpp_path_keys_(Path, [], Path1).
cpp_path_keys_([], _, []).
cpp_path_keys_([S|Ss], Pre, [K|Ks]) :- atom(S), Pre \== [], cpp_ns_key(Pre, S, K), !, cpp_path_keys_(Ss, [], Ks).
cpp_path_keys_([S|Ss], Pre, [S|Ks]) :- ( atom(S) -> append(Pre, [S], Pre1) ; Pre1 = [] ), cpp_path_keys_(Ss, Pre1, Ks).
%% THE CLASS'S OWN TYPEDEF FIRST, as C++ looks a name up ([basic.lookup.unqual]; 0.93): libc++ 18's numeric_limits writes
%% `typedef __libcpp_numeric_limits<...> __base; typedef typename __base::type type;', and a class named `__base' elsewhere in
%% the header (loaded lazily by that name) won the scope, refusing no_member_type(__base, type)
cpp_path_class(P, C) :- atom(P), cpp_class_ctx(Cx), cpp_class_typedef(Cx, P, T0, Def), !, cpp_in_class(Def, cpp_type(T0, T)), cpp_class_of_type(T, C).   % __alloc_traits::pointer inside its class
cpp_path_class(P, P) :- atom(P), cpp_class_l(P, _), !.
cpp_path_class(P, P) :- atom(P), ( '$cpp_inst'(P, _) ; '$cpp_iname'(_, _, P) ), !.   % AN INSTANCE STILL BEING REGISTERED IS A SCOPE ALREADY ([class.mem]: a name declared before a member is found from it): its typedefs are noted before its members are resolved (cpp_register_class_extras), and libc++'s basic_format_context holds basic_format_args<basic_format_context>, whose __basic_format_arg_value reads `typename _Context::char_type' -- flattened as a namespace it was the bare `char_type' (0.112; test/cpp/run/inprogscope.cpp)
cpp_path_class(P, P) :- atom(P), ccl_tag(P, Ms), Ms \== none, \+ ccl_is_enum_tag(Ms), !.   % a plain struct is a scope too: `NoPtr::pointer' is refused (no_member_type), never a namespace's bare name; an enum's name is not (Color::Green is its enumerator)
cpp_path_class(decltype(E), C) :- !, ( cpp_class_ctx(Cx) -> true ; Cx = none ),   % `decltype(__test<_Tp>(...))::value': the expression's own class is the scope
    cpp_expr(Cx, E, E1), ccl_type_of(E1, T), T \== unknown, cpp_class_of_type(T, C).
cpp_path_class(tmpl(N, Args0), C) :- !, cpp_targ_values(Args0, Args), cpp_instantiate_type(N, Args, T), cpp_class_of_type(T, C).
cpp_path_class(P, C) :- atom(P), ccl_typedef_of(P, T0), catch(cpp_type(T0, T), error(not_lowered(_), _), fail), cpp_class_of_type(T, C), !.   % A FILE-SCOPE ALIAS IS THE CLASS IT NAMES: `std::string::npos' is `basic_string<char, ...>::npos', where the path stopped at the alias and the static was flattened to the bare name `npos' (undeclared at the link)
cpp_path_class(scoped(_, Last), C) :- cpp_path_class(Last, C).
%% C++23: a method's explicit object parameter (`this Self &self', read as param(this(T), N) first among
%% the parameters) becomes the qualifier explicit_this(N, T), so the parameters are the ones a caller passes
cpp_norm_members(Ms, Ms1) :- cpp_norm_members(Ms, [], Ms1).
cpp_norm_members(Ms, Bases, Ms1) :-
    ( member(method(_, _, _, operator(Op), _, _, default), Ms), memberchk(Op, ['==', '<=>']) -> nb_setval('$cpp_norm_all', Ms), nb_setval('$cpp_norm_bases', Bases) ; true ),   % the defaulted comparisons below need the data members and the bases: kept only where one is there (nb_setval copies)
    cpp_trailing_rets(Ms, MsT), cpp_auto_members(MsT, Ms00), cpp_alloc_members(Ms00, Ms01), cpp_default_vdtor(Ms01, Bases, Ms0), cpp_norm_members_(Ms0, 0, Ms1).
%% A DEFAULTED VIRTUAL DESTRUCTOR IS A DESTRUCTOR OF ITS OWN (0.177): `virtual ~B() = default;', `~D() override = default;' and `~D() =
%% default;' over a base whose destructor is virtual are written with an empty body, which cpp_dtor_body completes as it completes the
%% implicit one, so the table has its slots at its place. Dropped as the implicit destructor, a class whose one virtual function it was
%% had no table, and a delete through it ran no derived destructor. A defaulted destructor that is not virtual stays the implicit one.
cpp_default_vdtor(Ms, Bases, Ms1) :-
    (   memberchk(dtor(_, Qs, default), Ms), ( memberchk(virtual, Qs) ; memberchk(override, Qs) ; cpp_raw_bases_virtual_dtor(Bases) )
    ->  cpp_default_vdtor_(Ms, Ms1)
    ;   Ms1 = Ms ).
%% A CLASS'S ALLOCATION AND DEALLOCATION FUNCTIONS ARE STATIC MEMBERS whether or not they say so ([class.free]/1, /3; 0.202): the probe's
%% `void *operator new[](std::size_t)' took a `this', and a new-expression handed it the size for one; a usual deallocation function's
%% block is an owner (cpp_alloc_own_params/4)
cpp_alloc_members([], []).
cpp_alloc_members([method(L, Qs0, R, operator(Op), Ps0, V, B)|Ms0], [method(L, Qs, R, operator(Op), Ps, V, B)|Ms]) :- cpp_alloc_op(Op), !,
    ( memberchk(static, Qs0) -> Qs = Qs0 ; Qs = [static|Qs0] ), cpp_alloc_own_params(class, Op, Ps0, Ps), cpp_alloc_members(Ms0, Ms).
cpp_alloc_members([template(L, TPs, M0)|Ms0], [template(L, TPs, M)|Ms]) :- M0 = method(_, _, _, operator(Op), _, _, _), cpp_alloc_op(Op), !,   % a member template's too (0.203)
    cpp_alloc_members([M0], [M]), cpp_alloc_members(Ms0, Ms).
cpp_alloc_members([M|Ms0], [M|Ms]) :- cpp_alloc_members(Ms0, Ms).
cpp_default_vdtor_([], []).
cpp_default_vdtor_([dtor(L, Qs, default)|Ms], [dtor(L, Qs, block([]))|Ms1]) :- !, cpp_default_vdtor_(Ms, Ms1).
cpp_default_vdtor_([M|Ms], [M|Ms1]) :- cpp_default_vdtor_(Ms, Ms1).
cpp_raw_bases_virtual_dtor(Bases) :- member(base(_, B0), Bases), catch(cpp_base_name(B0, B), _, fail), cpp_bases_virtual_dtor([B]), !.
%% A MEMBER FUNCTION WITH AN `auto' PARAMETER IS A MEMBER FUNCTION TEMPLATE ([dcl.fct]/22), its invented parameters
%% after any written ones: libc++ 18's format-spec parser writes `int32_t __get_width(auto &__ctx) const', and kept as a
%% method whose parameter type is `auto' its body typed nothing through `__ctx' -- std::format's width substitution
%% had no context to deduce (0.112; test/cpp/run/automember.cpp). A closure's operator() is made a template where it
%% is made (cpp_lambda_), and `this auto' stays the refusal it is (deduced_this).
cpp_auto_members([], []).
cpp_auto_members([method(L, Qs, Ret, M, Ps, V, Body)|Ms], [template(L, TPs, method(L, Qs, Ret, M, Ps2, V, Body))|Ms1]) :-
    \+ memberchk(closure, Qs), cpp_this_auto(Ps, Ps1, TPs1, K1), cpp_auto_params(Ps1, K1, Ps2, TPs2), append(TPs1, TPs2, TPs), TPs \== [], !, cpp_auto_members(Ms, Ms1).
cpp_auto_members([template(L, TPs0, method(L2, Qs, Ret, M, Ps, V, Body))|Ms], [template(L, TPs, method(L2, Qs, Ret, M, Ps2, V, Body))|Ms1]) :-
    cpp_this_auto(Ps, Ps1, TPs1, K1), cpp_auto_params(Ps1, K1, Ps2, TPs2), append(TPs1, TPs2, ATPs), ATPs \== [], !, append(TPs0, ATPs, TPs), cpp_auto_members(Ms, Ms1).
%% ... AND A CONSTRUCTOR with an `auto' parameter is a constructor template (0.132, [dcl.fct]/22): libc++'s
%% `subrange(__convertible_to_non_slicing<_Iter> auto __iter, _Sent __sent)', which views::counted and views::chunk_by
%% build, was a constructor named by the key `auto', its parameter's type never deduced
cpp_auto_members([ctor(L, Qs, Ps, Is, Body)|Ms], [template(L, TPs, ctor(L, Qs, Ps2, Is, Body))|Ms1]) :-
    cpp_auto_params(Ps, 0, Ps2, TPs), TPs \== [], !, cpp_auto_members(Ms, Ms1).
cpp_auto_members([template(L, TPs0, ctor(L2, Qs, Ps, Is, Body))|Ms], [template(L, TPs, ctor(L2, Qs, Ps2, Is, Body))|Ms1]) :-
    cpp_auto_params(Ps, 0, Ps2, ATPs), ATPs \== [], !, append(TPs0, ATPs, TPs), cpp_auto_members(Ms, Ms1).
cpp_auto_members([M|Ms], [M|Ms1]) :- cpp_auto_members(Ms, Ms1).
%% `this auto &&self' (0.117, C++23 [dcl.fct]/6): the explicit object parameter's `auto' is the first invented parameter, so
%% the method is a member template whose first template parameter is the type of the object it is called on
cpp_this_auto([param(this(T0), N)|Ps], [param(this(T), N)|Ps], [tparam(type, A, none)], K1) :- cpp_auto_in(T0, 0, T, K1), !, atom_concat('$A', K1, A).
cpp_this_auto(Ps, Ps, [], 0).
%% A TRAILING RETURN TYPE IS THE RESULT ([dcl.fct]/2; 0.93): the reader keeps `-> T' as `trailing(T)' among a
%% member's qualifiers with the result `auto', and nothing read it -- a member DEFINED deduced its result from its
%% first return (0.42's rule) and a member DECLARED had none. libc++'s `__tuple_sfinae_base' writes `static auto
%% __do_test(...) -> __all<...>;' with no body, whose declared result is the whole point (a decltype reads it), and
%% the instance came out `auto': the static const it feeds never folded and stayed an undefined extern at the link.
cpp_trailing_rets([], []).
cpp_trailing_rets([M0|Ms], [M|Ms1]) :- cpp_trailing_ret(M0, M), cpp_trailing_rets(Ms, Ms1).
cpp_trailing_ret(method(L, Qs, base(_, [auto]), M, Ps, V, Body), method(L, Qs, T, M, Ps, V, Body)) :- memberchk(trailing(T), Qs), !.
cpp_trailing_ret(template(L, TPs, M0), template(L, TPs, M)) :- !, cpp_trailing_ret(M0, M).
cpp_trailing_ret(M, M).
cpp_norm_members_([], _, []).
cpp_norm_members_([nested(base(_, [class(_, anon, _, Ns0)]))|Ms], K, Ms1) :- !,            % the same struct in C++'s own shape, which is what it is with default member initializers
    cpp_anon_unpack(Ns0, Ns), cpp_norm_members_(Ns, 0, Ns1), cpp_norm_members_(Ms, K, Ms2), append(Ns1, Ms2, Ms1).
cpp_norm_members_([nested(base(_, [struct(anon, Ns0)]))|Ms], K, Ms1) :- !,                  % an anonymous struct's members are the class's own (libc++'s compressed pair)
    cpp_anon_unpack(Ns0, Ns), cpp_norm_members_(Ns, 0, Ns1), cpp_norm_members_(Ms, K, Ms2), append(Ns1, Ms2, Ms1).
cpp_norm_members_([nested(base(_, [union(anon, Ns)]))|Ms], K, [member(base([], [union(anon, Ns1)]), A, none)|Ms1]) :- !,   % an anonymous union: one member, its names reached through it (cpp_data_member)
    K1 is K + 1, atomic_list_concat(['$anon', K1], A), cpp_norm_union_members(Ns, 0, Ns1), cpp_norm_members_(Ms, K1, Ms1).
cpp_norm_members_([using(_, _)|Ms], K, Ms1) :- !, cpp_norm_members_(Ms, K, Ms1).       % a using-declaration: its constructors are inherited above, a member's name is the base's already (cpp_base_scope)
cpp_norm_members_([using(_)|Ms], K, Ms1) :- !, cpp_norm_members_(Ms, K, Ms1).
%% A DEFAULTED COPY OR MOVE CONSTRUCTOR IS THE MEMBERWISE ONE ([class.copy.ctor]/14), kept as a constructor with the
%% marker `memberwise(Source, copy | move)' for its initializers, which cpp_ctor_body writes out: every data member
%% from the source's, through its own copy or move constructor where it has one, a base alike, a union as its bytes.
%% Dropped as "the implicit one" it left `std::set<int> t = s' refused (a class with a destructor and no copy
%% constructor), where libc++ writes `set(const set &) = default' over a tree that copies itself deep. The trivial
%% tests below (cpp_trivial_class, cpp_note_nontrivial) do not count it: its members decide, as C++ has it.
cpp_norm_members_([ctor(L, Qs, [param(T, S0)], _, default)|Ms], K, [ctor(L, Qs, [param(T, S)], memberwise(S, Kind), block([]))|Ms1]) :- cpp_copy_param(T, Kind), !,
    ( S0 == anon -> S = '$src' ; S = S0 ), cpp_norm_members_(Ms, K, Ms1).
%% C++20's DEFAULTED COMPARISONS ([class.compare.default]): `bool operator==(const C &) const = default' compares the
%% data members in order, `auto operator<=>(const C &) const = default' compares them lexicographically and answers
%% the first that differs -- an int here, where C++ has std::strong_ordering (the scalar `<=>' of 0.42 is an int and
%% <compare>'s classes are not modelled: a written result type is taken as int), and a defaulted `<=>' declares a
%% defaulted `==' beside it when none is written. A base sub-object and an array member are not compared (named).
cpp_norm_members_([method(L, Qs, Ret0, operator(Op), Ps, V, default)|Ms], K, Out) :- memberchk(Op, ['==', '<=>']), !,
    nb_getval('$cpp_norm_all', All), cpp_defaulted_cmp(Op, L, Qs, Ret0, Ps, V, All, M1),
    (   Op == '<=>', \+ member(method(_, _, _, operator('=='), _, _, _), All)                     % a defaulted <=> brings a defaulted == where none is declared at all
    ->  cpp_defaulted_cmp('==', L, Qs, base([], [bool]), Ps, V, All, M2), Out = [M1, M2|Ms1]
    ;   Out = [M1|Ms1] ),
    cpp_norm_members_(Ms, K, Ms1).
cpp_norm_members_([M|Ms], K, Ms1) :- cpp_member_body(M, B), ( B == delete ; B == default ), !, cpp_norm_members_(Ms, K, Ms1).   % `= delete': not there; `= default': the implicit one
cpp_norm_members_([method(L, Qs, Ret, M, Ps, V, pure)|Ms], K, [method(L, [pure|Qs], Ret, M, Ps, V, none)|Ms1]) :- !, cpp_norm_members_(Ms, K, Ms1).
cpp_norm_members_([method(L, Qs, Ret, M, [param(this(T), N)|Ps], V, Body)|Ms], K, [method(L, [explicit_this(N, T)|Qs], Ret, M, Ps, V, Body)|Ms1]) :- !, cpp_norm_members_(Ms, K, Ms1).
cpp_norm_members_([template(L, TPs, method(L2, Qs, Ret, M, [param(this(T), N)|Ps], V, Body))|Ms], K, [template(L, TPs, method(L2, [explicit_this(N, T)|Qs], Ret, M, Ps, V, Body))|Ms1]) :- !, cpp_norm_members_(Ms, K, Ms1).   % ... a member TEMPLATE's too (0.117): `template <class Self> int get(this Self &&self)'
cpp_norm_members_([M|Ms], K, [M|Ms1]) :- cpp_norm_members_(Ms, K, Ms1).
%% AN ANONYMOUS STRUCT'S `packed' IS ITS MEMBERS', NEVER ITS HOLDER'S (0.203): its members are the holder's, and GCC's `packed' on it
%% packs each of them, a member's own `packed' (ccl_packed_field/2) -- libc++ 21's string writes `struct _LIBCPP_PACKED { size_type
%% __is_long_ : 1; size_type __cap_ : 63; };' in its `__long', and the marker, carried into `__long', packed the whole string at one
cpp_anon_unpack(Ns0, Ns) :- memberchk(packed(_), Ns0), !, cpp_anon_unpack_(Ns0, Ns).
cpp_anon_unpack(Ns, Ns).
cpp_anon_unpack_([], []).
cpp_anon_unpack_([packed(_)|Ms0], Ms) :- !, cpp_anon_unpack_(Ms0, Ms).
cpp_anon_unpack_([member(T0, N, W)|Ms0], [member(T, N, W)|Ms]) :- !, ccl_add_layout_q(packed, T0, T), cpp_anon_unpack_(Ms0, Ms).
cpp_anon_unpack_([M|Ms0], [M|Ms]) :- cpp_anon_unpack_(Ms0, Ms).
%% AN ANONYMOUS STRUCT INSIDE A UNION IS ONE MEMBER of the union, its own members in sequence ([class.union.anon]; 0.112):
%% flattened into the union, every one of them lay at the union's offset. libc++ 18's `basic_format_args' keeps
%% `union { struct { const __basic_format_arg_value *__values_; uint64_t __types_; }; const basic_format_arg *__args_; }',
%% and `__types_' overwrote `__values_': std::format's `get(i)' read through the packed type bits and crashed.
cpp_norm_union_members([], _, []).
cpp_norm_union_members([nested(base(_, [S]))|Ms], K, [member(base([], [struct(anon, Ns1)]), A, none)|Ms1]) :- ( S = struct(anon, Ns) ; S = class(_, anon, _, Ns) ), is_list(Ns), !,
    K1 is K + 1, atomic_list_concat(['$anon', K1], A), cpp_norm_members_(Ns, 0, Ns1), cpp_norm_union_members(Ms, K1, Ms1).
cpp_norm_union_members([M|Ms], K, Out) :- cpp_norm_members_([M], K, Out1), ( Out1 = [member(_, A, _)], atom(A), atom_concat('$anon', KA, A), atom_number(KA, K1) -> true ; K1 = K ), cpp_norm_union_members(Ms, K1, Out2), append(Out1, Out2, Out).
cpp_copy_param(ref(_, base(_, [typedef(_)])), copy).
cpp_copy_param(rref(_, base(_, [typedef(_)])), move).
cpp_user_ctor(ctor(_, _, _, I, _)) :- I \= memberwise(_, _).
cpp_defaulted_cmp(Op, L, Qs, Ret0, Ps, V, All, method(L, Qs, Ret, operator(Op), [param(PT, O)], V, Body)) :-
    ( Ps = [param(PT0, O0)|_] -> true ; PT0 = none, O0 = none ), ( atom(O0), O0 \== none, O0 \== anon -> O = O0 ; O = '$other' ),
    ( PT0 == none -> cpp_cmp_self(All, PT) ; PT = PT0 ),
    %% THE PIECES COMPARED, in order ([class.compare.default]/6; 0.99): the BASE sub-object first (one with storage; an
    %% empty base has none here, 0.89, and nothing of its own to compare), then every data member, an ARRAY member
    %% element by element (a nested array through its rows) -- before, a base was not compared at all and an array
    %% member reached the lowering as `==' over two arrays
    ( nb_current('$cpp_norm_bases', Bases) -> true ; Bases = [] ),
    ( Bases = [B0|_], cpp_base_name_of(B0, BN), atom(BN), \+ cpp_empty_class(BN) -> P0 = [pc(member(deref(id(this)), '$base'), member(id(O), '$base'), none)] ; P0 = [] ),
    findall(Pc, ( member(member(MT, N, _), All), atom(N), cpp_cmp_pieces(MT, id(N), member(id(O), N), Pcs), member(Pc, Pcs) ), P1), append(P0, P1, Pieces),
    (   Op == '=='
    ->  Ret = base([], [bool]), cpp_eq_conj(Pieces, Cond), Body = block([return(L, Cond)])
    ;   cpp_defaulted_ordering(Ret0, Pieces, Ret, RetC),                                               % <compare>'s class where the header is in (0.101), the int of 0.42 without it
        findall(if(L, bin('!=', assign('=', id('$c'), Sign), int(0)), return(L, RV), none), ( member(pc(A, B, PcT), Pieces), cpp_cmp_sign(RetC, PcT, A, B, Sign), cpp_ordering_ret(RetC, id('$c'), RV) ), Ifs),   % a piece's sign as `>' minus `<': a member of a class with its own `<=>' answers the class, whose `>' and `<' the rewritten candidates take
        D = declaration(L, none, base([], [int]), [var('$c', base([], [int]), int(0))]), cpp_ordering_ret(RetC, int(0), R0), append([D|Ifs], [return(L, R0)], B1), Body = block(B1) ).
%% the result of a defaulted `<=>': the class WRITTEN (`std::strong_ordering operator<=>(...) const = default'), else
%% the common comparison category of the members ([class.spaceship]/4: partial_ordering where one is floating, else
%% strong_ordering) when <compare> is in, else an int
cpp_defaulted_ordering(Ret0, _, Ret0, C) :- Ret0 \= base(_, [auto]), catch(cpp_type(Ret0, T), _, fail), cpp_class_of_type(T, C), memberchk(C, [strong_ordering, weak_ordering, partial_ordering]), !.
cpp_defaulted_ordering(_, Pieces, base([], [typedef(C)]), C) :- ( member(pc(_, _, PT), Pieces), cpp_float_piece(PT) -> Kind = partial ; Kind = strong ), cpp_ordering_class(Kind, C), !.
cpp_defaulted_ordering(_, _, base([], [int]), none).
cpp_float_piece(PT) :- PT \== none, ccl_is_float(PT).
%% A FLOATING PIECE OF A DEFAULTED `<=>' THAT ANSWERS partial_ordering IS UNORDERED WHERE EITHER SIDE IS A NaN
%% ([class.spaceship]/2: the member's own `<=>', which for a floating type is a partial_ordering; 0.103): its sign is
%% -127 unless both compare equal to themselves, as the scalar `<=>' already had it (cpp_scalar_ordering) -- before,
%% the lexicographic chain took `>' minus `<' and a NaN member read as equivalent
cpp_cmp_sign(partial_ordering, PT, A, B, cond(bin('&&', bin('==', A, A), bin('==', B, B)), S, int(-127))) :- cpp_float_piece(PT), !, S = bin('-', bin('>', A, B), bin('<', A, B)).
cpp_cmp_sign(_, _, A, B, bin('-', bin('>', A, B), bin('<', A, B))).
cpp_ordering_ret(none, V, V) :- !.
cpp_ordering_ret(C, V, E) :- cpp_ordering_value(C, V, E).
cpp_base_name_of(base(_, N), N).
cpp_base_name_of(base(_, N, _), N).
cpp_base_name_of(N, N) :- atom(N).
cpp_cmp_pieces(T, A, B, Pieces) :- ccl_resolve_type(T, arr(Bound, ET)), ccl_const_eval(Bound, K), !, K1 is K - 1,
    findall(Pc, ( between(0, K1, I), cpp_cmp_pieces(ET, index(A, int(I)), index(B, int(I)), Pcs), member(Pc, Pcs) ), Pieces).
cpp_cmp_pieces(T, A, B, [pc(A, B, T)]).   % a piece: the two operands and the member's type, for the floating test above
cpp_cmp_self(_, ref([], base([const], [typedef(C)]))) :- once(nb_current('$cpp_class_ctx', C)), atom(C), !.
cpp_cmp_self(_, ref([], base([const], [auto]))).
cpp_eq_conj([], bool(true)).
cpp_eq_conj([pc(A, B, _)], bin('==', A, B)) :- !.
cpp_eq_conj([pc(A, B, _)|Ps], bin('&&', bin('==', A, B), R)) :- cpp_eq_conj(Ps, R).
cpp_member_body(method(_, _, _, _, _, _, B), B).
cpp_member_body(ctor(_, _, _, _, B), B).
cpp_member_body(dtor(_, _, B), B).
%% A DELETED MEMBER TEMPLATE IS DROPPED as a deleted plain member is (0.44): libc++ writes `unique_ptr(pointer,
%% __libcpp_remove_reference_t<deleter_type> &&) = delete' under `is_reference<_Deleter>' to steer construction to
%% the overload taking the deleter by lvalue reference, and KEPT it won overload resolution and then had no body to
%% emit -- `member_instance_not_emitted', where every buffered algorithm (stable_partition, inplace_merge) makes a
%% `unique_ptr<T, __destruct_n &>'
cpp_member_body(template(_, _, M), B) :- cpp_member_body(M, B).
%% THE VIRTUAL SLOTS OF A CLASS, as the Itanium ABI lays its primary table (2.5.2, clang's AddMethods; 0.177): the primary base's (Base,
%% or none), then each virtual function the class declares that overrides none of them, in the order declared -- one marked
%% `virtual', or one that overrides a function of any other base at any depth (cpp_overrides_base/4: a virtual first base that is no
%% primary, Other; a later base, virtual or not; a virtual base a path holds) -- and a destructor that is virtual by its word or by a
%% base's virtual destructor at its own place; then, LAST, the implicit destructor where the class declares none and a base's is
%% virtual (cpp_implicit_dtor_slots/4). Before 0.177 an override of a virtual first base's function was no slot of the class's own
%% table (`C : virtual A' overriding A's g had h at slot 0, clang's at 1), the pair of a destructor virtual by a virtual base went
%% FIRST (cpp_vbase_dtor_slots/3, gone), and a destructor virtual by a later base was no slot at all, so a delete through the class
%% ran no derived destructor.
cpp_slots(Base, Other, Ms, C, Slots) :-
    ( Base == none -> S0 = [] ; cpp_class_l(Base, cls(_, _, _, _, S0)) -> true ; cpp_refuse(0, base_not_registered(Base, C)) ),   % never a silent failure: a half-registered class corrupts every later lookup
    ( '$cpp_extra'(C, Es) -> true ; Es = [] ), findall(H, '$cpp_vb_holder'(C, H), Hs), append([[Base, Other], Es, Hs], Bs0), findall(X, ( member(X, Bs0), X \== none ), Bs),
    cpp_own_slots(Ms, Bs, S0, S1), cpp_implicit_dtor_slots(Ms, Bs, S1, Slots).
cpp_own_slots([], _, S, S).
cpp_own_slots([method(_, Qs, Ret, M, Ps, V, _)|Ms], Bs, S0, S) :-
    length(Ps, A), cpp_slots_of(S0, M, A, Same),
    (   cpp_overridden_slot(Same, Qs, Ps) -> S1 = S0                                    % it overrides a slot of the table so far
    ;   ( memberchk(virtual, Qs) ; cpp_overrides_base(Bs, M, A, Ps) )                % ... or a function of another base: `int g() override' over B::g is virtual in C too, and `pc->g()' through a C * must dispatch (0.110, a later base's; any base's, 0.177)
    ->  cpp_plain_params(Ps, Ps1), cpp_slot_ret(Ret, Ret1), cpp_slot_key(S0, M, A, K), append(S0, [slot(M, K, Ret1, Ps1, V)], S1)
    ;   S1 = S0 ),
    cpp_own_slots(Ms, Bs, S1, S).
cpp_own_slots([dtor(_, Qs, _)|Ms], Bs, S0, S) :- ( memberchk(virtual, Qs) ; memberchk(override, Qs) ; cpp_bases_virtual_dtor(Bs) ), \+ memberchk(slot('$dtor', 0, _, _, _), S0), !,   % virtual by the word, by `override' (libc++'s `~basic_ostream() override'), or by a base's virtual destructor (0.177)
    append(S0, [slot('$dtor', 0, base([], [void]), [], false), slot('$dtor_del', 0, base([], [void]), [], false)], S1), cpp_own_slots(Ms, Bs, S1, S).
%% ... TWO entries for it, the complete-object and the deleting destructor, as the Itanium ABI lays a table out --
%% and it must be laid out so, since a virtual call INTO an object the shipped library made (std::cout's streambuf,
%% its `overflow') indexes that object's own table: with one entry every slot past the destructor was off by one.
%% Both hold the one destructor here; a delete is that call and a free (cpp_destroy).
cpp_own_slots([_|Ms], Bs, S0, S) :- cpp_own_slots(Ms, Bs, S0, S).
cpp_implicit_dtor_slots(Ms, Bs, S0, S) :-
    (   \+ memberchk(dtor(_, _, _), Ms), \+ memberchk(slot('$dtor', 0, _, _, _), S0), cpp_bases_virtual_dtor(Bs)
    ->  append(S0, [slot('$dtor', 0, base([], [void]), [], false), slot('$dtor_del', 0, base([], [void]), [], false)], S)
    ;   S = S0 ).
%% a function of a base overridden: a slot of that base's table, or of its own bases', at any depth (each base's table holds its
%% primary chain's functions and its own; a later base's are in that base's own table)
cpp_overrides_base(Bs, M, A, Ps) :- member(X, Bs), cpp_base_overrides(X, M, A, Ps), !.
cpp_base_overrides(X, M, A, Ps) :- cpp_class_l(X, cls(XB, _, _, _, XS)),
    (   cpp_slots_of(XS, M, A, Same), cpp_overridden_slot(Same, [], Ps) -> true
    ;   ( '$cpp_extra'(X, XEs) -> true ; XEs = [] ), findall(H, '$cpp_vb_holder'(X, H), Hs), append([[XB], XEs, Hs], Ys),
        member(Y, Ys), Y \== none, cpp_base_overrides(Y, M, A, Ps) -> true ).
%% a base's destructor is virtual: its table has the destructor's slots (a class with a base whose destructor is virtual has them
%% itself, so a direct base tells)
cpp_bases_virtual_dtor(Bs) :- member(X, Bs), cpp_class_l(X, cls(_, _, _, _, XS)), memberchk(slot('$dtor', 0, _, _, _), XS), !.
%% a slot's RESULT type resolved in the class, as its parameters are: the table's struct is written from the slots, and
%% `virtual int_type uflow()' -- basic_streambuf's, a class-scope typedef -- reached the lowering raw there; one that
%% does not resolve stays as written, as it always did
cpp_slot_ret(Ret, Ret1) :- ( catch(cpp_type(Ret, Ret1), error(not_lowered(_), _), fail) -> true ; Ret1 = Ret ).
%% TWO VIRTUAL OVERLOADS OF ONE NAME AND ONE ARITY ARE TWO SLOTS (0.134), in declaration order, as the Itanium table has them:
%% libc++'s `money_put' declares `do_put(iter_type, bool, ios_base &, char_type, long double)' and `do_put(..., const
%% string_type &)', `num_put' eight `do_put' of four parameters, `num_get' eleven `do_get' of five. A slot was named by the
%% method and its arity, so the second overload overrode the first: the table had one `do_put', `put_money' of a string
%% dispatched to the long double one, and LLVM refused the `sitofp' of a struct. The KEY of a slot is its arity for the
%% first virtual of a name and arity and `A_I' for the I-th (cpp_slot_key), so the table's struct and the thunks name each.
%% A method overrides the one slot of its name and arity as it always did -- unless it is marked `virtual' and its
%% parameter types are not that slot's, which makes it an overload of its own -- and, where several slots share them, the
%% slot whose parameter types are its own (cpp_overridden_slot).
cpp_slot_arity(K, A) :- integer(K), !, A = K.
cpp_slot_arity(K, A) :- atom(K), atomic_list_concat([AA, _], '_', K), atom_number(AA, A).
cpp_slot_key(S0, M, A, K) :- cpp_slots_of(S0, M, A, Same), length(Same, I0), ( I0 =:= 0 -> K = A ; I is I0 + 1, atomic_list_concat([A, '_', I], K) ).
cpp_slots_of(Slots, M, A, Same) :- findall(slot(M, K, R, Ps, V), ( member(slot(M, K, R, Ps, V), Slots), cpp_slot_arity(K, A) ), Same).
cpp_overridden_slot([], _, _) :- !, fail.
cpp_overridden_slot([slot(_, _, _, SPs, _)], Qs, Ps) :- !, \+ ( memberchk(virtual, Qs), \+ memberchk(override, Qs), \+ memberchk(final, Qs), cpp_params_differ(Ps, SPs) ).
cpp_overridden_slot(Same, _, Ps) :- catch(cpp_plain_params(Ps, Ps1), _, fail), member(slot(_, _, _, SPs, _), Same), cpp_params_agree(Ps1, SPs), !.
%% two parameter lists AGREE where each type is the other's, the top-level cv of a value parameter dropped ([dcl.fct]/5);
%% a type that cannot be compared is taken to agree, so only a sure difference makes a method a new overload
cpp_params_differ(Ps, SPs) :- catch(cpp_plain_params(Ps, Ps1), _, fail), \+ cpp_params_agree(Ps1, SPs).
cpp_params_agree([], []).
cpp_params_agree([P|Ps], [Q|Qs]) :- cpp_param_t(P, T1), cpp_param_t(Q, T2), cpp_param_fn_type(T1, U1), cpp_param_fn_type(T2, U2), catch(cpp_same_type(U1, U2), _, true), !, cpp_params_agree(Ps, Qs).
%% THE METHOD OF A MEMBER LIST THAT A SLOT NAMES: of the slot's name and arity -- and where the class's table has several
%% slots of that name and arity, the one whose parameter types are the slot's, so an override of `do_put(..., const
%% string_type &)' never stands in the slot of `do_put(..., long double)'
cpp_slot_method(C, Ms, M, K, Qs, Ps) :- cpp_slot_arity(K, A),
    (   cpp_class_l(C, cls(_, _, _, _, Slots)), cpp_slots_of(Slots, M, A, [_, _|_]), memberchk(slot(M, K, _, SPs, _), Slots)
    ->  member(method(_, Qs, _, M, Ps, _, _), Ms), length(Ps, A), cpp_in_class(C, ( catch(cpp_plain_params(Ps, Ps1), _, fail), cpp_params_agree(Ps1, SPs) )), !
    ;   member(method(_, Qs, _, M, Ps, _, _), Ms), length(Ps, A), ! ).
%% THE SLOT A CALL DISPATCHES THROUGH: the CHOSEN method's (0.134) -- its name and its own arity, which a call that leaves a
%% defaulted argument out does not have (`p->f(3)' over `virtual int f(int a, int b = 2)' found no slot of one parameter
%% and called the base's f statically), and where the table has several slots of that name and arity, the one whose
%% parameter types are the method's, as it was declared under its mangled name
cpp_slot_call(C, M, N, Name, Slot) :- cpp_class_l(C, cls(_, _, _, _, Slots)),
    ( catch(ccl_declared(Name, fn(_, [_|Ps], _)), _, fail) -> length(Ps, A) ; A = N, Ps = none ),
    cpp_slots_of(Slots, M, A, Same),
    (   Same = [slot(_, K, _, _, _)] -> true
    ;   Same = [_, _|_], Ps \== none, member(slot(_, K, _, SPs, _), Same), cpp_params_agree(Ps, SPs) -> true ), !,
    cpp_slot_name(M, K, Slot).
%% ... AND A VIRTUAL BASE'S SLOT that the method overrides (0.139): a class over a virtual base has a table of its own for its own
%% new virtual functions, and an override of the virtual base's is no slot of it, so the call goes through the virtual base's
%% sub-object and its table, whose entry is the final overrider (a thunk moving `this' to it)
cpp_vbase_slot_call(C, M, N, Name, V, Slot) :- \+ cpp_slot_call(C, M, N, Name, _), cpp_vbases_of(C, Vs), member(V, Vs), cpp_slot_call(V, M, N, Name, Slot), !.
%% ... and the slot of a method named by its address, `&C::f' (cpp_method_address)
cpp_method_slot_key(C, M, Ps, K) :- length(Ps, A), cpp_class_l(C, cls(_, _, _, _, Slots)), cpp_slots_of(Slots, M, A, Same),
    (   Same = [slot(_, K, _, _, _)] -> true
    ;   Same = [_, _|_], cpp_in_class(C, catch(cpp_plain_params(Ps, Ps1), _, fail)), member(slot(_, K, _, SPs, _), Same), cpp_params_agree(Ps1, SPs) -> true ), !.
cpp_polymorphic(C) :- C \== none, cpp_class_l(C, cls(_, _, _, _, Slots)), Slots \== [].
%% A CLASS WITH A TABLE (0.160): one with slots, or one whose primary chain holds a virtual base reached through a table -- the
%% Itanium ABI's DYNAMIC class. Every class with a virtual base has its own table pointer now, whose table carries the base's
%% offset, so a diamond's paths reach the one shared base wherever the complete object lays it; the tables, their stores and the
%% primary base are decided by this test, and a virtual call, typeid and dynamic_cast by cpp_polymorphic/1 as before.
cpp_has_table(C) :- cpp_polymorphic(C), !.
cpp_has_table(C) :- C \== none, cpp_primary_vbase(C, _), !.
cpp_has_table(C) :- C \== none, cpp_lvb_chain(C).   % a later virtual base reached through the table, the class's own or its primary chain's (0.172)
cpp_lvb_chain(C) :- '$cpp_lvb'(C, _, _), !.
cpp_lvb_chain(C) :- cpp_class_l(C, cls(B, _, _, _, _)), B \== none, \+ '$cpp_vbase'(C), \+ cpp_empty_class(B), cpp_lvb_chain(B).
cpp_slot(C, M, K, Slot) :- cpp_class_l(C, cls(_, _, _, _, Slots)), memberchk(slot(M, K, _, _, _), Slots), !, cpp_slot_name(M, K, Slot).
%% A SLOT IS NAMED BY THE METHOD AND ITS ARITY, since two virtual overloads of one name are two slots: libc++'s
%% std::function holds its callable through `__base', whose `virtual __base *__clone() const' and `virtual void
%% __clone(__base *) const' are both `__clone' -- named alike, the table's struct had the member twice, the
%% dispatch took the first and a copy of a function called the wrong one with the wrong arguments.
cpp_slot_name('$dtor', _, '$dtor') :- !.
cpp_slot_name('$dtor_del', _, '$dtor_del') :- !.
cpp_slot_name(M, K, Name) :- ( atom(M) -> M1 = M ; M = operator(Op), cpp_op_word(Op, W) -> atom_concat('op.', W, M1) ; term_to_atom(M, M1) ), atomic_list_concat([M1, '.', K], Name).
%% the class whose table a pointer to C dispatches through: the first polymorphic one up the chain
cpp_vt_owner(C, Owner) :- cpp_class_l(C, cls(B, _, _, _, _)), ( \+ '$cpp_vbase'(C), cpp_has_table(B) -> cpp_vt_owner(B, Owner) ; Owner = C ).
%% A CLASS THAT IS NOT TRIVIALLY COPYABLE OR DESTRUCTIBLE is marked for the lowering, which passes it by invisible
%% reference and returns it through a hidden pointer as the Itanium ABI has it (ir_abi): a destructor, a copy or
%% move constructor, a virtual function, a VIRTUAL BASE (0.160: its copy constructor is never trivial, [class.copy.ctor]/11), or a
%% base or a member that is such
cpp_note_nontrivial(C, Base, Data, Ms, Slots) :-
    (   (   Slots \== [] ; '$cpp_vbase'(C) ; '$cpp_lvb'(C, _, _) ; memberchk(dtor(_, _, _), Ms) ; cpp_dtor_def(C) ; cpp_user_copy_ctor(C)
        ;   Base \== none, cpp_nontrivial(Base)
        ;   member(member(MT, _, _), Data), cpp_elem_class(MT, MC), cpp_nontrivial(MC) )
    ->  nb_getval('$cpp_nontrivial', L), ( memberchk(C, L) -> true ; nb_setval('$cpp_nontrivial', [C|L]) )
    ;   true ).
cpp_nontrivial(C) :- nb_getval('$cpp_nontrivial', L), memberchk(C, L).
cpp_user_copy_ctor(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(M, Ms), M = ctor(_, _, [P], _, _), cpp_user_ctor(M), ( P = param(RT, _) ; P = param(RT, _, _) ), RT =.. [Kind, _, base(_, [typedef(C)])], memberchk(Kind, [ref, rref]), !.   % a copy or move constructor the class WRITES (a memberwise one is its members' business)
cpp_user_copy_ctor(C) :- cpp_class(C, cls(_, _, Ms, _, _, _)), member(M, Ms), M = ctor(_, _, [P], _, _), cpp_user_ctor(M), cpp_named_self(C, P, _), !.   % ... or names it otherwise (0.198, cpp_named_self/3)
%% ... AND AN EMPTY BASE STILL CONTRIBUTES ITS ALIGNMENT, though it takes no bytes ([class.derived]:
%% the empty base optimization is about storage, not alignment) -- which is exactly what an `align_as'
%% marker says, so it is written as one. libc++ finds the widest alignment a platform has by deriving
%% `__max_align_impl' from six `alignas'-carrying EMPTY bases and asking alignof of it; with their
%% alignment dropped it answered 1, and std::function's inline buffer was aligned by it.
cpp_base_layout(C, Base, Data, Data2) :- cpp_base_layout_(C, Base, Data, Data00), cpp_vptr_first(C, Data00, Data0),
    findall(member(VT, VN, W), ( '$cpp_vb_holder'(C, V), \+ '$cpp_vb_claim'(C, V, _), \+ cpp_vb_at_self(C, V), cpp_vb_name(C, V, VN), ( cpp_empty_class(V) -> VT = base([], [typedef(V)]), W = no_unique_address ; W = none, ( cpp_vb_nv(V) -> cpp_nv_tag(V, VNV), VT = base([], [struct(VNV, none)]) ; VT = base([], [typedef(V)]) ) ) ), VMs), append(Data0, VMs, Data10),   % the virtual bases it holds, each once, last, in their order (0.171) -- one with virtual bases of its own its `.nv' form (0.173), an EMPTY one a member of no storage (0.235; it had none, at the object's own address, 0.172): offset 0, or past the data where an empty subobject of its type lies at 0 already, as the ABI places it (2.4 III over II.3; ccl_members_layout/5) -- `C2 : C0, C1' over `C1 : virtual C0' lays the virtual C0 at 8, sixteen bytes, as clang does, where it shared offset 0 with the plain C0 in eight
    cpp_vbase_refs(C, Refs0), cpp_every_vbase_refs(C, ERefs), append(Refs0, ERefs, Refs), append(Data10, Refs, Data1),   % each later virtual base's slot, a pseudo-member of no storage reached through the table (0.172), and every virtual base's (0.235)
    cpp_empty_base_align(C, Base, Data1, Al), append(Data1, Al, Data2).
cpp_vbase_refs(C, Refs) :- ( '$cpp_lvb'(C, _, _) -> findall(vbase_ref(S, base([], [typedef(V)]), Off), ( '$cpp_lvb'(C, V, S), S \== none, cpp_lvb_off(C, V, Off) ), Refs) ; Refs = [] ).
%% ... EVERY VIRTUAL BASE IS REACHED THROUGH THE TABLE (0.235): a slot `$base$v<I>' for each, its vbase offset at its place
%% (cpp_vbase_ref_name/3), so a pointer converts to an empty one where the sub-object lies in any object -- the pointer was kept,
%% the address of the sub-object it named, where the base lies at the complete object's address or past its data (ir_base_route/3)
%% -- and a base variant stores a virtual base's table there (cpp_vtt_stores/3): a static cast of `this', which took a plain base of
%% the class too, where it has one of that class
cpp_every_vbase_refs(C, Refs) :- findall(vbase_ref(N, base([], [typedef(V)]), Off), ( cpp_vbases_of(C, Vs0), cpp_first_each(Vs0, Vs), member(V, Vs), cpp_vbase_ref_name(C, V, N), cpp_lvb_off(C, V, Off) ), Refs).
cpp_vbase_ref_name(C, V, N) :- cpp_vbases_of(C, Vs0), cpp_first_each(Vs0, Vs), nth1(I, Vs, V0), V0 == V, !, catch(cpp_lvb_off(C, V, _), _, fail), atomic_list_concat(['$base$v', I], N).
%% the place of a later virtual base's offset in the class's table: -24 - 8I for its I-th slot
cpp_lvb_off(C, V, Off) :- cpp_vb_slots(C, Vs), once(nth0(I, Vs, V)), Off is -24 - 8 * I.
cpp_empty_base_align(C, Base, Data, Ms) :- findall(align_as(int(A)), ( cpp_empty_base(C, Base, B), catch(cpp_base_align(B, A), _, fail), A > 1 ), Ms0),
    findall(E, ( cpp_empty_base(C, Base, B), ( cpp_empty_vbase(C, Base, B) -> \+ cpp_empty_held(C, B), cpp_nv_last(Data, After), E = empty_vsub(base([], [typedef(B)]), After) ; cpp_empty_after(C, Base, B, After), E = empty_sub(base([], [typedef(B)]), After) ) ), Es), append(Ms0, Es, Ms).   % ... and its PLACE (0.199): a member of its type is put past it -- laid after the base before it, in the bases' order (0.235; ccl_empty_bases_at/11) -- a VIRTUAL one marked apart (0.235): it lies at the complete object's address, not at the class's own where the class is a base, so the lowering's route to an empty base stops at no class that names it (ir_empty_base_of/2)
%% THE TABLE POINTER COMES FIRST (the Itanium ABI 2.4 I; 0.135): a class that introduces its table has no primary base -- none of
%% its bases has a table, or cpp_primary_first would have moved that one to the front, where it shares the pointer -- and its own
%% pointer lies at offset 0, the bases after it: `struct D : B { virtual void f(); int x; }' over `struct B { int b; }' lays B at 8
%% and x at 12 in sixteen bytes, as clang does; B lay at 0, the pointer at 8 and x at 16 in twenty-four. Its base is then no longer
%% at offset 0: the type information is a vmi one (cpp_rtti_chain), and the base's destructor runs on the base where it lies
%% (cpp_implicit_dtor_needed). A class over a virtual FIRST base lays its pointer first too, ahead of a later plain base
%% (0.172): `Z : virtual A, B' laid B at 0 and the pointer at 8, where clang lays the pointer at 0, B at 8, z at 12, A at 16.
cpp_vptr_first(_, Ds, [V|Rest]) :- V = member(_, '$vptr', _), select(V, Ds, Rest), !.
cpp_vptr_first(_, Ds, Ds).
cpp_base_align(B, A) :- ccl_resolve_type(base([], [typedef(B)]), T), ccl_size_align(T, _, A).   % RESOLVED first: ccl_size_align takes a resolved type, and a bare name simply fails it
cpp_empty_base(_, Base, Base) :- Base \== none, cpp_empty_class(Base).
cpp_empty_base(C, _, B) :- '$cpp_extra'(C, Es), member(B, Es), cpp_empty_class(B).
%% AN EMPTY VIRTUAL BASE THE CLASS DOES NOT HOLD AS A MEMBER lies at the complete object's address (0.172), and where an empty
%% subobject of its type lies there already in the class's non-virtual part, the ABI moves it past the data (2.4 III over II.3),
%% which this model does not do for one of no member: the class's virtual FIRST base of the 0.110 model, or one inside such a base --
%% `C2 : virtual C0, C1' over `C1 : C0' is sixteen bytes to clang, the virtual C0 at 8, and was eight here. REFUSED by name (0.235),
%% `empty_virtual_base_moved(C, V)', where a COMPLETE object of the class is constructed (cpp_ctor/3; '$cpp_bad_layout'(C, V)): as
%% a base the class lays only its base-variant form, which holds no virtual base. One the class holds is placed so (cpp_base_layout/4)
cpp_empty_vbases_laid(_, C, Data) :-
    (   cpp_vbases_of(C, Vs0), cpp_first_each(Vs0, Vs), member(V, Vs), cpp_empty_class(V)
    ->  findall(M, ( member(M, Data), M \= empty_vsub(_, _), \+ ( M = member(_, N, _), ( cpp_vb_member(N) ; N == '$base', '$cpp_vbase'(C) ) ) ), NV),
        ( catch(ccl_class_empty_subs(base([], [struct('$nv_part', NV)]), Subs0), _, fail) -> true ; Subs0 = [] ),
        findall(S, ( member(X, Vs), \+ cpp_empty_class(X), catch(cpp_vbase_loc(C, X, H), _, fail), H == [], cpp_self_subs(X, S) ), SelfSubs),   % ... and a nearly empty primary virtual base at the class's own address, whose empty subobjects no member lays
        append([Subs0|SelfSubs], Subs),
        forall(( member(V1, Vs), cpp_empty_class(V1), memberchk(V1-0, Subs), \+ cpp_empty_held_past(C, V1, Data) ), cpp_bad_layout(C, V1, Data)),
        forall(( catch(ccl_members_layout(Data, Lays, _, _), _, fail), member(lay('$vempty'(V2), _, Off2, empty), Lays), Off2 > 0 ), cpp_bad_layout(C, V2, Data))   % one it does not hold, which the walk moved: no member gives the place
    ;   true ).
%% ... WHERE A PROGRAM CAN SEE IT: such a base meets one of its own type, so it is ambiguous, and no conversion names its address;
%% the complete object's SIZE differs where the ABI's place past the data passes the model's size, and its functions see `this'
%% where it or a base of it declares any (0.235): `C2 : virtual C1, C0' over `C1 : virtual C0 { int m; virtual int f(); }' is
%% 32 bytes either way, the virtual C0 at 28 to clang and at 0 here, and builds
cpp_bad_layout(C, V, Data) :-
    (   cpp_fns_see_this(V) -> true
    ;   catch(ccl_members_layout(Data, _, Size, Align, DSize), _, fail), catch(ccl_resolve_type(base([], [typedef(V)]), VT), _, fail),
        ccl_empty_subs(VT, VSubs), ( catch(ccl_class_empty_subs(base([], [struct('$whole', Data)]), Seen), _, fail) -> true ; Seen = [] ),
        ccl_empty_step(VSubs, 1, Seen, DSize, O), E is max(Size, O + 1), ccl_round_up(E, Align, Size1), Size1 =\= Size ),
    !, ( '$cpp_bad_layout'(C, V) -> true ; assertz('$cpp_bad_layout'(C, V)) ).
cpp_bad_layout(_, _, _).
cpp_fns_see_this(V) :- cpp_class(V, cls(B, _, Ms, _, _, _)), ( member(M, Ms), ( M = ctor(_, _, _, _, _) ; M = dtor(_, _, _) ; M = method(_, _, _, _, _, _, _) ; M = template(_, _, _) ) -> true ; B \== none, cpp_fns_see_this(B) -> true ; '$cpp_extra'(V, Es), member(E, Es), cpp_fns_see_this(E) ), !.
cpp_self_subs(X, Subs) :- ( cpp_nv_tag(X, XNV), catch(ccl_tag(XNV, Ms), _, fail), is_list(Ms) -> true ; catch(ccl_tag(X, Ms), _, fail), is_list(Ms) ), catch(ccl_class_empty_subs(base([], [struct(X, Ms)]), Subs), _, fail), !.
cpp_self_subs(_, []).
%% an empty virtual base the class holds, its member laid past offset 0 by the walk (a conflict there seen)
cpp_empty_held_past(C, V, Data) :- cpp_empty_held(C, V), cpp_vb_name(C, V, VN), catch(ccl_members_layout(Data, Lays, _, _), _, fail), memberchk(lay(VN, _, Off, empty), Lays), Off > 0.
cpp_empty_vbase(C, Base, B) :- B == Base, !, '$cpp_vbase'(C).
cpp_empty_vbase(C, _, B) :- '$cpp_lvb'(C, B, _).
%% the last member of a class's non-virtual part, after which an empty virtual base it does not hold is laid -- before those it holds,
%% at offset 0 or past the data, so the held ones meet its empty subobjects there (0.235): `C2 : virtual C1, virtual C0' over `C1 : C0'
%% lays the held C0 at 16, past C1's own C0 at 0, as clang does; the model kept the first virtual base, empty, out of the walk
cpp_nv_last(Data, After) :- findall(N, ( member(member(_, N, _), Data), \+ cpp_vb_member(N) ), Ns), ( last(Ns, After) -> true ; After = start ).
%% the member of the plain base laid before the empty base B, in the bases' order -- the first base, then the later ones -- or `start'
cpp_empty_after(C, Base, B, After) :- ( '$cpp_extra'(C, Es) -> true ; Es = [] ), append(Before, [B0|_], [Base|Es]), B0 == B, !,
    findall(N, ( member(X, Before), X \== none, \+ cpp_empty_class(X), cpp_plain_base_member(C, Base, X, N) ), Ns), ( last(Ns, After) -> true ; After = start ).
cpp_plain_base_member(C, Base, X, '$base') :- X == Base, !, \+ '$cpp_vbase'(C), \+ '$cpp_vprim'(C, _).
cpp_plain_base_member(C, _, X, Slot) :- '$cpp_base_slot'(C, X, Slot), \+ '$cpp_lvb'(C, X, _).
cpp_base_layout_(_, none, Data, Data) :- !.
%% ... AND AN EMPTY BASE HAS NO SUB-OBJECT AT ALL ([class]/4, the empty base optimization), which is
%% what the extra empty bases have had since 0.71: the derived class takes no byte for it, the base's
%% address IS the object's, and its typedefs, statics and methods are found through cpp_base_scope as
%% they always were. Without this the byte an empty class now has as a COMPLETE object would be paid
%% by every class deriving from one -- libc++'s allocators, comparators and tuple leaves.
cpp_base_layout_(C, Base, Data, Data1) :- cpp_empty_class(Base), !, cpp_extra_members(C, Ex), append(Ex, Data, Data1).
cpp_base_layout_(C, Base, Data, Data1) :- '$cpp_vprim'(C, _), !, cpp_extra_members(C, Ex), append(Ex, Data, D0), cpp_lvb_off(C, Base, Off),   % A NEARLY EMPTY PRIMARY VIRTUAL BASE has no member (0.174): it lies at the object's own address, sharing its table pointer, and the class's `$base' is a pseudo-member reached through the table, its vbase offset after the vcall offsets of the base's functions (cpp_vb_slots/2)
    append(D0, [vbase_ref('$base', base([], [typedef(Base)]), Off), virtual_base], Data1).
cpp_base_layout_(C, Base, Data, Data1) :- '$cpp_vbase'(C), !, cpp_extra_members(C, Ex), append(Ex, Data, D0),
    ( cpp_vbase_dynamic(C) -> Mk = [virtual_base] ; Mk = [] ),
    append(D0, [member(base([], [typedef(Base)]), '$base', none)|Mk], Data1).
cpp_base_layout_(C, Base, Data, [member(BT, '$base', none)|Data1]) :- cpp_extra_members(C, Ex), append(Ex, Data, Data1),
    ( '$cpp_nv_base'(C, Base) -> cpp_nv_tag(Base, NV), BT = base([], [struct(NV, none)]) ; BT = base([], [typedef(Base)]) ).
%% A CLASS WITH A VIRTUAL BASE AND ITS OWN TABLE reaches the base through the table's vbase offset (0.110), which is
%% what a diamond needs: the shared base lies where the COMPLETE object put it, which a base sub-object cannot know.
%% Every class over a virtual base has its table since 0.160 (cpp_register_class_), a base with no virtual function among
%% them: until then such a class had none, the base stayed where the class laid it, and a diamond over it was refused by
%% name (`virtual_base_by_two_paths').
cpp_vbase_dynamic(C) :- '$cpp_vbase'(C), cpp_class_l(C, cls(_, Data, _, _, _)), memberchk(member(_, '$vptr', _), Data).
%% ... and its BASE-SUBOBJECT form, `C.nv': the class without the shared base, which a diamond's later path embeds
cpp_nv_tag(C, NV) :- atom_concat(C, '.nv', NV).
cpp_nv_data(C, Data2, NVData) :- cpp_class_l(C, cls(Base, _, _, _, _)),
    findall(M, ( member(M, Data2), M \= member(_, '$base', _), M \== virtual_base, \+ ( M = member(_, N, _), cpp_vb_member(N) ), M \= empty_vsub(_, _) ), Ms0), append(Ms0, [virtual_base_of(base([], [typedef(Base)]))], NVData).   % ... and the later virtual bases it holds (0.172)
%% `alignas' travels with the tag, its expression folded in the class's own words as a bitfield's width and
%% an array's bound are: `union alignas(_Align) type { ... }' in an instance of libc++'s aligned_storage
%% states an alignment the layout must know wherever the tag is noted from (ccl_align_as).
cpp_align_tag(C, Ms, Data, Data1) :-
    ( memberchk(align_as(E), Ms) -> cpp_in_class(C, cpp_array_bound(E, N)), append(Data, [align_as(N)], Data2) ; Data2 = Data ),
    ( memberchk(packed(P), Ms) -> append(Data2, [packed(P)], Data3) ; Data3 = Data2 ),   % GCC's `packed' travels with the tag too (0.203)
    findall(align_as(N2), ( member(align_as(E2), Ms), E2 \== E, cpp_in_class(C, cpp_array_bound(E2, N2)) ), More), append(Data3, More, Data1).   % ... and GCC's `aligned' beside an `alignas'
%% where a class's base sub-object lies, and where the source's lies in a memberwise copy: its own
%% `$base' member, or the object itself when the base is empty and has none
cpp_class_base_place(C, B, cast(ptr([], base([], [typedef(B)])), cast(ptr([], base([], [void])), id(this)))) :- '$cpp_vprim'(C, _), !.   % a nearly empty primary virtual base at the object's own address (0.174), by a cast through `void *', which takes no route through a table not yet stored
cpp_class_base_place(C, B, addr(arrow(this, '$base!'))) :- cpp_vbase_dynamic(C), \+ cpp_empty_class(B), !.   % the virtual base AT ITS PLACE: the complete object's constructor and destructor, before and after its table is set
cpp_class_base_place(_, B, P) :- cpp_base_place(B, P).
cpp_base_place(B, addr(arrow(this, '$base'))) :- \+ cpp_empty_class(B), !.
cpp_base_place(_, id(this)).
cpp_base_src(B, S, member(id(S), '$base')) :- \+ cpp_empty_class(B), !.
cpp_base_src(B, S, ccast(static, ref([], base([], [typedef(B)])), id(S))).   % an EMPTY base sub-object lies at the object's own address, but a memberwise copy must name it AS THE BASE: handed the object itself, the overload choice looked for a base constructor taking the DERIVED class and refused base_constructor
cpp_base_hop(B, ['$base'|Hops], Hops1) :- ( cpp_empty_class(B) -> Hops1 = Hops ; Hops1 = ['$base'|Hops] ).
cpp_extra_members(C, Ms) :- findall(member(T, Slot, none), ( '$cpp_base_slot'(C, B, Slot), \+ '$cpp_lvb'(C, B, _), ( '$cpp_nv_base'(C, B) -> cpp_nv_tag(B, NV), T = base([], [struct(NV, none)]) ; T = base([], [typedef(B)]) ) ), Ms).   % a diamond's later path is the base's `.nv' form (0.110)
cpp_vt_tag(C, VT) :- atomic_list_concat([C, '.vt'], VT).
cpp_vtable_name(C, N) :- atomic_list_concat([C, '.vtable'], N).
%% THE STRUCT OF A TABLE OF N's SLOTS (0.172): N's own, `N.vt', a function pointer for each of N's slots, where N has any --
%% else the struct of its table's owner. A secondary or a construction table of a base that shares its primary base's pointer
%% and adds virtual functions of its own was typed by the primary base's struct, one slot short, and LLVM's constant could not
%% hold it: `D : X, P' over `P : PB' with `virtual int h()' was refused since 0.108, `item(declaration('D.vtable$base$2'))'.
cpp_slots_vt(N, Owner, VT) :- ( cpp_class_l(N, cls(_, _, _, _, [_|_])) -> cpp_vt_tag(N, VT) ; cpp_vt_tag(Owner, VT) ).
%% the implementation a class's table holds for a slot: its own, else the base's
cpp_slot_impl(C, '$dtor', _, Name) :- !, cpp_dtor(C, Name).
cpp_slot_impl(C, '$dtor_del', _, Name) :- !, cpp_dtor(C, Name).
cpp_slot_impl(C, M, K, Name) :- cpp_class(C, cls(B, _, Ms, _, _, _)), ( cpp_slot_method(C, Ms, M, K, Qs, Ps) -> cpp_mangle_q(C, M, Qs, Ps, Name) ; B \== none, cpp_slot_impl(B, M, K, Name) ).
%% ... and whether that implementation is DEFINED: a PURE virtual slot nothing overrides takes a NULL in the table
%% (C++ puts __cxa_pure_virtual there, and there is no runtime here to put), since no object of an abstract class
%% is ever made -- libc++'s `__shared_count::__on_zero_shared() = 0' is one, and the table named a symbol that
%% nothing defines: the link said so, where the emission of a pure member rightly emits nothing.
cpp_slot_def(C, '$dtor', K, Name) :- !, cpp_slot_impl(C, '$dtor', K, Name).
cpp_slot_def(C, '$dtor_del', K, Name) :- !, cpp_slot_impl(C, '$dtor', K, Name).
cpp_slot_def(C, M, K, Name) :- cpp_class(C, cls(B, _, Ms, _, _, _)),
    ( cpp_slot_method(C, Ms, M, K, Qs, Ps) -> \+ memberchk(pure, Qs), cpp_mangle_q(C, M, Qs, Ps, Name) ; B \== none, cpp_slot_def(B, M, K, Name) ).
cpp_split_members([], [], [], []).
cpp_split_members([member(T0, N, _)|Ms], Data, [N-T|Ss], Ds) :- cpp_static_type(T0, T1), !, cpp_static_inline_take(N, T1, T), cpp_split_members(Ms, Data, Ss, Ds).
cpp_split_members([member(T0, N, W0)|Ms], [member(T, N, W)|Data], Ss, Ds) :- !, ( cpp_class_ctx(C), cpp_type_names_call(C, T0) -> T = T0 ; cpp_type(T0, T1), cpp_fold_aligned(T1, T) ), cpp_bit_width(W0, W), cpp_split_members(Ms, Data, Ss, Ds).   % a type that names a call waits for the class's record (cpp_member_types_now, 0.136)
cpp_split_members([default_init(N, E)|Ms], Data, Ss, [N-E|Ds]) :- !, cpp_split_members(Ms, Data, Ss, Ds).
cpp_split_members([_|Ms], Data, Ss, Ds) :- cpp_split_members(Ms, Data, Ss, Ds).
%% `static' sits in the INNERMOST base's qualifiers, so a static POINTER or ARRAY member -- `static const char
%% __src[33]', libc++'s __num_get_base -- was split as DATA: a class of statics alone was no empty base, and
%% num_get's second base refused multiple_inheritance
cpp_static_type(base(Q, S), base(Q1, S)) :- memberchk(static, Q), !, ccl_delete_one(Q, static, Q1).
cpp_static_type(ptr(Q, T0), ptr(Q, T)) :- !, cpp_static_type(T0, T).
cpp_static_type(arr(N, T0), arr(N, T)) :- !, cpp_static_type(T0, T).
cpp_static_type(ref(Q, T0), ref(Q, T)) :- !, cpp_static_type(T0, T).
%% AN INLINE STATIC WITH NO INITIALIZER (0.218; the reader's `inline' beside `static', ccl_inline_statics/3): noted for its
%% class, '$cpp_sinline'(C, N), and the word taken off its type, which every use of the member reads
cpp_static_inline_take(N, T1, T) :- cpp_static_inline_type(T1, T), !, ( cpp_class_ctx(C) -> ( catch('$cpp_sinline'(C, N), _, fail) -> true ; assertz('$cpp_sinline'(C, N)) ) ; true ).
cpp_static_inline_take(_, T, T).
cpp_static_inline_type(base(Q, S), base(Q1, S)) :- memberchk(inline, Q), !, ccl_delete_one(Q, inline, Q1).
cpp_static_inline_type(ptr(Q, T0), ptr(Q, T)) :- !, cpp_static_inline_type(T0, T).
cpp_static_inline_type(arr(N, T0), arr(N, T)) :- !, cpp_static_inline_type(T0, T).
cpp_static_inline_type(ref(Q, T0), ref(Q, T)) :- cpp_static_inline_type(T0, T).
%% A BITFIELD KEEPS ITS WIDTH, folded in the class's words as an array's bound is: libc++'s string is `unsigned char
%% __is_long_ : 1; unsigned char __size_ : 7;' in its short form and `size_type __is_long_ : 1; size_type __cap_ :
%% sizeof(size_type) * CHAR_BIT - 1;' in its long one -- with the widths dropped each was a whole byte or word, the
%% string 40 bytes where the library's is 24, and the library's own push_back wrote by its layout while our size()
%% read by ours (self-consistent, the string fixtures had never met the library's members)
cpp_bit_width(none, none) :- !.
cpp_bit_width(no_unique_address, no_unique_address) :- !.                        % the mark travels to the layout with the member
cpp_bit_width(W0, W) :- cpp_array_bound(W0, W).
%% the functions a class makes are declared in the symbol table at once, so
%% a rewritten call has a type while the walk goes on
cpp_declare_members([], _).
cpp_declare_members([method(L, Qs, Ret0, M, Ps, V, Body)|Ms], C) :- memberchk(explicit_this(N, T0), Qs), !,        % C++23: the object parameter as declared, no implicit this
    cpp_mangle_q(C, M, Qs, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_self_param(L, C, N, T0, Self),
    cpp_fsig_own(M, fsig(member, C, M, Ret0, Ps, V, Qs, none), Sig), cpp_with_fsig(Sig, cpp_method_ret(C, Ret0, [Self|Ps1], Body, Ret)),   % (its body walked as the method's own, 0.166: a lambda it makes is the one its emission makes) the result resolved as any method's is, an `auto' one as the first return's type with the object parameter in scope (0.117): `std::string name(this const Box &self)' was left as written
    ccl_declare(Name, fn(Ret, [Self|Ps1], V)), cpp_note_defaults(Name, Ps), cpp_declare_members(Ms, C).
cpp_declare_members([method(_, Qs, Ret0, M, Ps, V, Body)|Ms], C) :- !,
    cpp_mangle_q(C, M, Qs, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_this_type(C, Qs, ThisT),
    nb_getval('$ccl_scope', S0),   % the deduction's frame is popped by its success only: a member left undeclared restores the scope
    cpp_fsig_own(M, fsig(member, C, M, Ret0, Ps, V, Qs, none), Sig),   % the body walked as the method's own (0.166): the lambda an `auto' result returns is the one the emission makes
    (   catch(cpp_with_fsig(Sig, cpp_method_ret(C, Ret0, [param(ThisT, this)|Ps1], Body, Ret)), E, ( nb_setval('$ccl_scope', S0), ( cpp_unmet_member(C, Qs, Ps, Name) -> Ret = '$unmet' ; cpp_auto_waits(E, C, Ret0, m(Sig, Ret0, ThisT, Ps1, Body, V, Name, Ps, Qs)) -> Ret = '$later' ; throw(E) ) )) -> true
    ;   nb_setval('$ccl_scope', S0), cpp_unmet_member(C, Qs, Ps, Name) -> Ret = '$unmet' ),
    ( ( Ret == '$unmet' ; Ret == '$later' ) -> true ; ccl_declare(Name, fn(Ret, [param(ThisT, this)|Ps1], V)), cpp_note_defaults(Name, Ps), cpp_note_static_abi(Qs, Name) ),
    cpp_declare_members(Ms, C).
cpp_declare_members([ctor(_, Qs, Ps, _, _)|Ms], C) :- memberchk(requires(_), Qs), cpp_mangle(C, C, Ps, Name), nb_getval('$ccl_scope', S0),
    catch(( cpp_plain_params(Ps, _), fail ), _, ( nb_setval('$ccl_scope', S0), cpp_unmet_member(C, Qs, Ps, Name) )), !,   % a constrained constructor whose PARAMETER TYPES do not resolve and whose clause is unmet (0.113): transform_view's iterator `__iterator(__iterator<!_Const>) requires _Const', where `__iterator<true>' over a const filter_view has no iterator type
    cpp_declare_members(Ms, C).
cpp_declare_members([ctor(_, _, Ps, _, _)|Ms], C) :- !,
    cpp_mangle(C, C, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_this_type(C, [], [fresh], ThisT),
    ccl_declare(Name, fn(base([], [void]), [param(ThisT, this)|Ps1], false)), cpp_note_defaults(Name, Ps),
    ( cpp_has_nv_form(C), \+ cpp_lib_class(C) -> atom_concat(Name, '.nv', NV), cpp_vtt_type(VttT), ccl_declare(NV, fn(base([], [void]), [param(ThisT, this), param(VttT, '$vtt')|Ps1], false)) ; true ),   % the base variant takes its part of the VTT (0.172)
    cpp_declare_members(Ms, C).
cpp_declare_members([dtor(_, _, _)|Ms], C) :- !,
    atomic_list_concat([C, '.dtor.0'], Name), cpp_this_type(C, [], [dying], ThisT),
    ccl_declare(Name, fn(base([], [void]), [param(ThisT, this)], false)), cpp_declare_members(Ms, C).
cpp_declare_members([_|Ms], C) :- cpp_declare_members(Ms, C).
%% A STATIC MEMBER FUNCTION THE SHIPPED LIBRARY DEFINES takes no `this' there (0.127): the desugaring keeps its own null first argument, which every
%% pass reads as the object's place, and the lowering drops it at the call and in the declaration (ir_call). `ios_base::sync_with_stdio(true)'
%% handed the library a null in the register of its bool, and `locale::global(loc)' a null for its locale.
%% ... AND SO IS THE PROGRAM'S OWN (0.160): declared, defined and called with no `this' (ir_item, ir_call), the null kept for the passes
%% before the lowering alone -- an inner convention of 0.37 that a static's every call paid a register for.
cpp_note_static_abi(Qs, Name) :- memberchk(static, Qs), atom(Name), \+ '$cpp_static_abi'(Name), !, assertz('$cpp_static_abi'(Name)).
cpp_note_static_abi(_, _).
%% `auto f()': the first return's expression, desugared (an instance's call has a type only then), typed
cpp_method_ret(C, base(Q, [auto]), Params, Body0, Ret) :- Body0 \== none, memberchk(decltype_auto, Q), !, cpp_decltype_auto_ret(C, Params, Body0, Ret0), ( Ret0 == none -> cpp_refuse(0, auto_result(C)) ; Ret = Ret0 ).
cpp_method_ret(C, base(_, [auto]), Params, Body0, Ret) :- Body0 \== none, !, cpp_in_frame(cpp_method_auto_ret(C, Params, Body0, Ret)), ( Ret == none -> cpp_refuse(0, auto_result(C)) ; true ).
%% ... `auto &', `const auto &' and `auto &&' (0.121): the first return's type under the reference its form says (cpp_ref_auto_result), as a plain function's is
cpp_method_ret(C, Ret0, Params, Body0, Ret) :- Body0 \== none, Ret0 =.. [K, Q, base(QA, [auto])], memberchk(K, [ref, rref]), !,
    cpp_in_frame(cpp_method_ref_ret(C, Ret0, K, Q, QA, Params, Body0, Ret)), ( Ret == none -> cpp_refuse(0, auto_result(C)) ; true ).
cpp_method_ret(_, Ret0, Params, _, Ret) :- ( cpp_has_decltype(Ret0) -> cpp_with_params(Params, [], cpp_type(Ret0, Ret)) ; cpp_type(Ret0, Ret) ).   % a trailing decltype over the parameters (0.100)
%% ... the deductions in a frame of their own (cpp_in_frame, 0.133): THE PARAMETERS DECLARED BEFORE THE BLOCK TYPEDEFS ARE RESOLVED (0.121): `using alt_type =
%% remove_cvref_t<decltype(__alt)>;' names a parameter, and resolved outside its scope it was untyped; the locals before the return declared on the way, a
%% discarded `if constexpr' branch never entered (the lambda's rule)
cpp_method_auto_ret(C, Params, Body0, Ret) :- ccl_declare_params(Params), cpp_body_typedefs(Body0, Body),
    (   cpp_first_return_in(C, Body, E)
    ->  cpp_expr(C, E, E1), ( cpp_deduced_ret(E1, T), T \== unknown -> cpp_decayed(T, Ret) ; Ret = none )
    ;   Ret = base([], [void]) ).
cpp_method_ref_ret(C, Ret0, K, Q, QA, Params, Body0, Ret) :- ccl_declare_params(Params), cpp_body_typedefs(Body0, Body),
    (   cpp_first_return_in(C, Body, E)
    ->  cpp_expr(C, E, E1), ( cpp_lvalue(E1), \+ cpp_xvalue_object(E1) -> Lv = yes ; Lv = no ),
        ( cpp_deduced_ret(E1, T0), T0 \== unknown -> ccl_unref(T0, T1), cpp_merge_quals(QA, T1, T), cpp_ref_auto_result(K, Q, T, Lv, Ret) ; Ret = none )
    ;   Ret = Ret0 ).
cpp_has_decltype(base(_, [decltype(_)])) :- !.
cpp_has_decltype(ref(_, T)) :- !, cpp_has_decltype(T).
cpp_has_decltype(rref(_, T)) :- !, cpp_has_decltype(T).
cpp_has_decltype(ptr(_, T)) :- !, cpp_has_decltype(T).
cpp_has_decltype(base(_, [typedef(X)])) :- compound(X), cpp_term_mentions_functor(X, decltype), !.   % ... AND ONE IN A TEMPLATE-ID'S ARGUMENTS (0.206): libc++'s `std::ssize' returns `common_type_t<ptrdiff_t, make_signed_t<decltype(__c.size())>>', resolved with no parameter in scope -- `decltype_unknown'
%% A MEMBER WHOSE REQUIRES-CLAUSE IS UNMET is not declared where its `auto' result cannot be deduced ([temp.inst]/11:
%% its definition is not instantiated, and no call can choose it): ref_view<map<...>>'s `data() const requires
%% contiguous_range<_Range> { return ranges::data(*__r_); }' has no type, and refusing it left views::keys
%% undeclared (0.113). Only asked where the deduction failed, so the clause is walked once per such member.
cpp_unmet_member(C, Qs, Ps, Name) :- memberchk(requires(R), Qs), \+ cpp_member_req_holds(C, Qs, Ps, R), cpp_trace(member_unmet_undeclared(Name)).
%% the explicit object parameter as the function's first: `this auto` on a method would make it a template (deduced_this)
cpp_self_param(L, C, N, T0, param(T, N)) :- ( cpp_auto_in(T0, 0, _, _) -> cpp_refuse(L, deduced_this(C)) ; cpp_type(T0, T) ).
%% a method with an explicit object parameter takes the object as declared -- by reference (its address, as any
%% reference argument), or a copy -- where an implicit this takes its address
cpp_object_arg(Name, addr(move(X)), Obj) :- !, cpp_object_arg(Name, addr(X), Obj).   % `std::move(w).f()': the object is w itself, its value category having chosen the overload (0.112: libc++ 18's `std::move(__writer_).__out_it()')
cpp_object_arg(Name, Addr, Obj) :- ccl_declared(Name, fn(_, [param(_, First)|_], _)), First \== this, !, ( Addr = addr(B) -> Obj = B ; Obj = deref(Addr) ).
cpp_object_arg(_, Addr, Addr).
cpp_declare_statics([], _).
cpp_declare_statics([N-T0|Ss], C) :- atomic_list_concat([C, '.', N], Name), ( cpp_has_auto(T0), catch(cpp_with_gvar(gv(smem(C, N), inline), cpp_static_auto(C, N, T0, T1)), error(not_lowered(_), _), fail) -> T = T1 ; \+ cpp_has_auto(T0), \+ cpp_lib_class(C), catch(cpp_in_class(C, cpp_type(T0, T2)), error(not_lowered(_), _), fail) -> T = T2 ; T = T0 ), ccl_declare(Name, T), cpp_declare_statics(Ss, C).   % ITS TYPE THROUGH THE TEMPLATE ROAD (0.115): `static constexpr std::string_view yes{...}' resolved by the table alone named the instance's struct with no class registered, and `Words::yes.size()' stayed a raw member call (`staticsv.cpp'); the PROGRAM's classes only -- every library class's statics instantiated at its registration took std::format past 3.5 GB   % an `auto' static takes its initializer's type where it can here (cpp_static_auto)
cpp_class(C, Cls) :- '$cpp_cls'(C, Cls), !.
cpp_class(C, Cls) :- cpp_nested_ready(C), '$cpp_cls'(C, Cls), !.      % a NESTED class asked for while its enclosing one is still being registered
cpp_class(C, Cls) :- cpp_hdr_load(C), '$cpp_cls'(C, Cls), !.
cpp_class(C, Cls) :- catch('$cpp_deferred'(C, _, _, _), _, fail), cpp_run_deferred(C), '$cpp_cls'(C, Cls), !.   % an instance that waited for its base (cpp_instance_body)
%% the class a type names, and the one a pointer's or an array's element names
cpp_class_of_type(T, C) :- ccl_resolve_type(T, T1), cpp_class_of_type_(T1, C).
cpp_class_of_type_(base(_, [class(_, C, _, _)]), C) :- cpp_class_l(C, _), !.
cpp_class_of_type_(base(_, [struct(C, _)]), C) :- cpp_class_l(C, _), !.
cpp_class_of_type_(base(_, [union(C, _)]), C) :- cpp_class_l(C, _), !.        % a UNION-CLASS resolves to its union spec, and is its class all the same
cpp_class_of_type_(base(_, [typedef(C)]), C) :- cpp_class_l(C, _), !.
cpp_class_of_type_(base(_, [typedef(X)]), C) :- cpp_template_id(X, N, Args), !, cpp_targ_values(Args, Args1), cpp_instantiate_type_of(X, N, Args1, T), cpp_class_of_type(T, C).   % a template-id the table still holds raw
cpp_class_of_type_(base(_, [typedef(scoped(_, C))]), C) :- cpp_class_l(C, _), !.
cpp_pointee_class(T, C) :- ccl_resolve_type(T, T1), ( T1 = ptr(_, E) ; T1 = arr(_, E) ), cpp_class_of_type(E, C).
cpp_class_of_type_of(move(X), C) :- !, cpp_class_of_type_of(X, C).
%% ... AND NEVER FROM A RAW TYPE, the guard `cpp_arg_type' has had since 0.83: the inference types a call of a
%% FUNCTION TEMPLATE from the raw signature a summary declares it under, so `std::invoke(f, a...)' is
%% `invoke_result_t<_Fn, _Args...>' with `_Fn' still invoke's own parameter. Resolved here to find the class,
%% it instantiated the traits on that name; its SFINAE specialization -- a `void_t<decltype(...)>' first
%% element, matched in the non-deduced pass -- cannot match a free name, so the PRIMARY was chosen and the
%% primary has no `type'. Left raw, the value falls to `cpp_init_arg_class', which desugars the call and
%% instantiates it, and the instance's result is concrete.
cpp_class_of_type_of(X, C) :- ccl_type_of(X, T), T \== unknown, \+ cpp_raw_type(T), ccl_unref(T, T1), cpp_class_of_type(T1, C).   % the class an EXPRESSION has: through a reference, since `declval<C &>()' names C's members (the TYPE-level test keeps its reference, where the value category depends on it)
cpp_pointee_class_of(X, C) :- ccl_type_of(X, T), T \== unknown, cpp_pointee_class(T, C).
%% the members: data (own and inherited, with the hops through '$base'), the statics, methods, constructors, the destructor
cpp_data_member(C, N, []) :- cpp_class_l(C, cls(_, Data, _, _, _)), memberchk(member(_, N, _), Data), !.
cpp_data_member(C, N, Hops) :- cpp_class_l(C, cls(_, Data, _, _, _)), cpp_anon_path(Data, N, Hops), !.   % in an anonymous union, or an anonymous struct inside one (0.112), through each hidden member
cpp_data_member(C, N, ['$base'|Hops]) :- cpp_class_l(C, cls(B, _, _, _, _)), B \== none, cpp_data_member(B, N, Hops).
cpp_data_member(C, N, [Slot|Hops]) :- '$cpp_base_slot'(C, B, Slot), cpp_data_member(B, N, Hops).
cpp_anon_path(Ms, N, [A|H]) :- member(member(base(_, [U]), A, _), Ms), ( U = union(anon, Ns) ; U = struct(anon, Ns) ), is_list(Ns), ( memberchk(member(_, N, _), Ns) -> H = [] ; cpp_anon_path(Ns, N, H) ), !.
cpp_static_member(C, N, Name) :- cpp_class_l(C, cls(_, _, Ss, _, _)), ( memberchk(N-_, Ss) -> cpp_static_name(C, N, Name) ; cpp_base_scope(C, B), cpp_static_member(B, N, Name) ).
cpp_static_member(C, N, Name) :- cpp_enclosing(C, Enc), cpp_static_member(Enc, N, Name).   % A NESTED CLASS, AND A CLOSURE MADE IN ONE, SEE THE ENCLOSING CLASS'S STATICS BY NAME ([class.nest]/4; 0.112): only a static const had been looked up there (0.63), so `scale' in Outer::Inner's method, or in a lambda inside it, was undeclared
%% A STATIC DATA MEMBER OF A LAZY CLASS IS DEFINED WHERE IT IS NAMED, as its member functions are ([temp.inst]/3: the
%% initialization of a static data member does not occur unless the member is used; 0.112). Its declaration in the
%% table is the registration's (cpp_declare_statics); its definition -- the initializer folded, a constant, an
%% aggregate, a constructed object, or an extern -- is cpp_static_decls' over that one member. Why: checking
%% `std::format''s second candidate instantiates `basic_format_string<wchar_t, int, int>', and its statics' initializers
%% (`__types_', `__handles_') pulled the whole `wchar_t' format road, `numpunct<wchar_t>' with it, into a `char' program.
cpp_static_use(C, N, Name) :- cpp_static_member(C, N, Name), ( cpp_static_owner(C, N, O) -> cpp_use_static(O, N) ; true ).
cpp_static_owner(C, N, C) :- cpp_class_l(C, cls(_, _, Ss, _, _)), memberchk(N-_, Ss), !.
cpp_static_owner(C, N, O) :- cpp_base_scope(C, B), cpp_static_owner(B, N, O), !.
cpp_static_owner(C, N, O) :- cpp_enclosing(C, Enc), cpp_static_owner(Enc, N, O), !.
cpp_use_static(C, N) :-
    (   cpp_is_lazy(C), \+ cpp_instance_done(static(C, N)), \+ cpp_making(static(C, N)),
        cpp_class_l(C, cls(_, _, Ss, _, _)), memberchk(N-T, Ss)
    ->  cpp_trace(use_static(C, N)),
        nb_getval('$cpp_making', M0), nb_setval('$cpp_making', [static(C, N)|M0]),
        cpp_lazy_lib(C, Lib),
        (   catch(\+ \+ cpp_as_lib(Lib, ( cpp_isolated(cpp_in_class(C, cpp_static_decls(0, C, [N-T], Ds))), cpp_add_instance_items(Ds), cpp_static_gdeclare(Ds) )),
                  E, ( nb_setval('$cpp_making', M0), throw(E) ))
        ->  nb_setval('$cpp_making', M0), cpp_instance_note(static(C, N), C)
        ;   nb_setval('$cpp_making', M0), cpp_refuse(0, static_not_emitted(C, N)) )
    ;   true ).
%% ... ITS GLOBAL DECLARED UNDER ITS NAME, its type resolved (0.202): a library class's statics are declared at its registration under the
%% compiler's own name with the table's raw type, and a shipped one's global is its Itanium symbol, so `__f->id.__get()' in libc++'s
%% `locale(const locale &, _Facet *)' had an object of no type and stayed a raw member call (`type(unknown)': every program facet)
cpp_static_gdeclare(Ds) :- forall(( member(declaration(_, _, _, Vs), Ds), member(var(VN, VT, _), Vs), atom(VN) ), ccl_gdeclare([VN-VT])).
%% A STATIC DATA MEMBER A LIBRARY HEADER DECLARES AND THE SHIPPED LIBRARY DEFINES -- every facet's `static locale::id
%% id', `_ZNSt3__15ctypeIcE2idE' -- is named by its Itanium symbol, where it is declared (extern) and where it is
%% used; one with its initializer in the class is this compiler's own definition, under its own name (0.45)
%% A SHIPPED static data member is named by its Itanium symbol (0.73) -- but only one the header DECLARES and does
%% not define: a static with its initializer written IN THE CLASS is its own definition here (0.45), whether it
%% folds to a constant or is an AGGREGATE, and named by its symbol libc++'s `__matches' had no type at the call
%% that searches it and `__find_idx' could not deduce its bound -- every get-by-type refused.
cpp_static_here(C, N) :- cpp_sinit(C, N, _).
cpp_static_name(C, N, Name) :- cpp_lib_class(C), \+ cpp_static_const(C, N, _), \+ cpp_static_here(C, N), cpp_class_scope(C, Path, Chain),
    catch(( cpp_ita_prefix(Path, Chain, [], PText, _), cpp_ita_member_name(N, MText), atomic_list_concat(['_ZN', PText, MText, 'E'], Name) ), _, fail), !.
cpp_static_name(C, N, Name) :- atomic_list_concat([C, '.', N], Name).
