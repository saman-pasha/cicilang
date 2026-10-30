%% ccl_cpp_library.pl -- the library's functions and classes: the overload sets of a header's free functions, a call
%% qualified by the library's namespace, an instance's key, what the shipped library defines, a header's free
%% functions and inline variables, the lazy instances. A part of the C++ desugaring that ccl_cpp.pl loads (0.223):
%% its rules as they stood there, in their order.

%% ONE DEFINITION BESIDE A DECLARATION OF OTHER PARAMETERS IS AN OVERLOAD TOO (0.181): the name had one definition, kept
%% the plain name, and the table holds one type a name, the first declared -- `int g(const Inc &);' before `int g(const
%% char *s) { ... }' made `g("abc")' call the definition with the literal's address taken for the reference (it printed
%% 8 where clang++ prints 97), and a declared `int g(double)' gave LLVM a pointer converted to a double. The definition
%% is `g.const_char_p' now and the declaration keeps `g'. Only a SURE difference counts: another count of parameters, or
%% at one place a reference against no reference, a pointer against no pointer, or two builtin types of other
%% spellings; a name that only the tables resolve (a typedef, a class) agrees with anything, so a declaration
%% `f(size_t)' and a definition `f(unsigned long n)' stay one function, called by its one name
cpp_params_surely_differ(Ps1, Ps2) :- length(Ps1, N1), length(Ps2, N2), N1 =\= N2, !.
cpp_params_surely_differ([P|Ps], [Q|Qs]) :-
    (   cpp_param_shape(P, S1), cpp_param_shape(Q, S2), S1 \== other, S2 \== other, S1 \== S2 -> true
    ;   cpp_params_surely_differ(Ps, Qs) ).
cpp_param_shape(P, S) :- ( cpp_param_t(P, T) -> cpp_type_shape(T, S) ; S = other ).
cpp_type_shape(ref(_, _), ref) :- !.
cpp_type_shape(rref(_, _), ref) :- !.
cpp_type_shape(ptr(_, _), ptr) :- !.
cpp_type_shape(arr(_, _), ptr) :- !.
cpp_type_shape(fn(_, _, _), ptr) :- !.
cpp_type_shape(base(_, Ss), arith(C)) :- Ss = [_|_], forall(member(X, Ss), ( atom(X), cpp_builtin_word(X) )), !, cpp_canon_specs(Ss, C).
cpp_type_shape(_, other).
cpp_builtin_word(W) :- memberchk(W, [void, char, short, int, long, float, double, signed, unsigned, bool, '_Bool', wchar_t, char8_t, char16_t, char32_t, '__int128', '_Float16', nullptr_t]).
%% the overload an argument list names: one whose parameters take it EXACTLY (C++ prefers such a non-template
%% to any template), else the one whose parameters fit best (cpp_pick, the methods')
cpp_fn_exact(F, As, Ps, D) :- cpp_fn_ready(F), length(As, N),
    findall(Ps0, ( '$cpp_fn'(F, _, Ps0, _, O), \+ cpp_fn_hidden(F, O), length(Ps0, N), \+ cpp_raw_params(Ps0), cpp_exact_params(Ps0, As) ), Cs), Cs = [C1|Cs1],   % AMONG THE EXACT OVERLOADS an rvalue argument takes the `T &&' one (0.122; [over.ics.rank]/3.2.3): `f(const S &)' beside `f(S &&)' for `f(S{2})' and `f(std::move(s))' -- the first declared won
    cpp_prefer_rvalue(Cs1, C1, As, Ps), cpp_fn_defined(F, Ps, D), !.
%% A PLAIN OVERLOAD'S PARAMETERS NAME NO FREE TEMPLATE PARAMETER (0.136): a template's raw signature among the noted
%% overloads of a name (`duration<_Rep, _Period> abs(duration<_Rep, _Period>)' beside `int abs(int)') is the template's
%% to deduce; resolved here, it instantiated `duration' over the free names, and ratio's arithmetic over `_Period::num'
%% made `__static_gcd' instances without end -- the chrono formatter's `std::abs(__t.tm_year + 1900)'
cpp_raw_params(Ps) :- member(P, Ps), ( P = param(T, _) ; P = param(T, _, _) ), cpp_raw_type(T), !.
cpp_prefer_rvalue([], Best, _, Best).
cpp_prefer_rvalue([C|Cs], Best, As, Out) :- ( cpp_rvalue_binds(C, As, K1), cpp_rvalue_binds(Best, As, K0), K1 > K0 -> cpp_prefer_rvalue(Cs, C, As, Out) ; cpp_prefer_rvalue(Cs, Best, As, Out) ).
cpp_rvalue_binds([], [], 0).
cpp_rvalue_binds([P|Ps], [A|As], K) :- ( P = param(T, _) ; P = param(T, _, _) ), !, ( T = rref(_, _), \+ cpp_arg_lvalue(A) -> K1 = 1 ; K1 = 0 ), cpp_rvalue_binds(Ps, As, K0), K is K0 + K1.
cpp_rvalue_binds(_, _, 0).
cpp_fn_best(F, As, Ps, D) :- cpp_fn_ready(F), length(As, N),
    findall(Ps0, ( '$cpp_fn'(F, _, Ps0, _, O), \+ cpp_fn_hidden(F, O), cpp_fn_arity_fits(Ps0, O, N), \+ cpp_raw_params(Ps0), cpp_args_no_clash(Ps0, As) ), Cands), Cands \== [],   % the arity alone is the last resort, never a clash (as the members' is)
    cpp_pick(Cands, As, Ps), cpp_fn_defined(F, Ps, D).
%% A CALL QUALIFIED BY THE LIBRARY'S NAMESPACE FINDS NONE OF THE PROGRAM'S OWN FUNCTIONS OF THE NAME (0.221; [namespace.qual]/2):
%% the program's global names keep the bare name beside the library's, one overload set (cpp_lib_quals/4 keys its named
%% namespaces' alone), so `std::max(2, 3)' beside the program's `int max(int, int)' called it, 5 for clang's 3, and the
%% qualified `std::swap(a, b)' the program's `swap(S &, S &)'. The qualified call marks its name and the depth it is chosen
%% at (cpp_lib_qualified/3, `'$cpp_libq''), and the program's own overloads of the name are no candidates there -- not in
%% the bodies it instantiates, where argument-dependent lookup can find them -- unless the program declares the name in
%% namespace std itself
cpp_fn_hidden(F, own(_)) :- nb_current('$cpp_libq', F-D), nb_getval('$cpp_depth', D), \+ catch('$cpp_own_ns'(F, [std|_]), _, fail).
%% an ELLIPSIS takes any number past the named parameters: `__libcpp_verbose_abort(const char *, ...)' is
%% called with a format and its arguments, and the plain arity test found no candidate for those calls
cpp_fn_arity_fits(Ps, O, N) :- cpp_fn_variadic(O), !, cpp_required(Ps, Min), N >= Min.
cpp_fn_arity_fits(Ps, _, N) :- cpp_arity_fits(Ps, N).
cpp_fn_variadic(decl(_, true)).
cpp_fn_variadic(own(true)).
cpp_fn_variadic(lazy(function(_, _, _, _, _, true, _))).
cpp_fn_ready(F) :- atom(F), cpp_hdr_join(F), '$cpp_fn'(F, _, _, _, _), !.   % the header's overloads of the name join the program's (cpp_hdr_join)   % a LIBRARY header's functions of the name, registered on the first ask: `std::__throw_length_error'
%% is defined inline in the header and emitted where it is called, so the name must be loaded here. A load that
%% REFUSES throws through (it marks the name loaded before it registers it, so a refusal swallowed here would
%% leave the name marked and its templates unregistered ever after -- std::swap linked to nothing for a turn).
cpp_fn_defined(F, Ps, D) :- ( '$cpp_fn'(F, _, Ps, yes, _) -> D = yes ; D = no ).
cpp_exact_params([], []).
cpp_exact_params([P|Ps], [A|As]) :- ( P = param(T, _) ; P = param(T, _, _) ), cpp_arg_exact(T, A), cpp_exact_params(Ps, As).
cpp_arg_exact(PT, A) :- cpp_fn_template_ref(A, F), !, cpp_fn_target(PT, FnT), cpp_target_deduces(F, FnT).   % a template's name the target deduces is exact
cpp_arg_exact(PT, A) :- ccl_type_of(A, AT), ccl_resolve_type(AT, fn(R2, Ps2, V2)), !, ccl_unref(PT, PT1), ccl_resolve_type(PT1, ptr(_, PF)), ccl_resolve_type(PF, fn(R1, Ps1, V1)), cpp_fn_types_agree(fn(R1, Ps1, V1), fn(R2, Ps2, V2)).   % a function DECAYS to the pointer: `std::hex' is exact for `ios_base &(*)(ios_base &)'
cpp_arg_exact(PT0, A) :- ccl_type_of(A, AT), AT \== unknown,
    cpp_type_or_self(PT0, PT),                                                              % the parameter as WRITTEN, resolved: a program's `operator<<(std::ostream &, const P &)' is noted raw, and `std::ostream' is nothing to the inference
    ccl_unref(PT, PT1), ccl_unref(AT, AT1), ccl_resolve_type(PT1, R1), ccl_resolve_type(AT1, R2),
    cpp_bare_type(R1, B1), cpp_bare_type(R2, B2), ( B1 == B2 -> true ; cpp_memptr_key_same(B1, B2) ),
    \+ cpp_category_mismatch(PT, A).                                                          % an rvalue reference takes no lvalue ([dcl.init.ref]/5; 0.122)
cpp_bare_type(base(_, S), base([], S1)) :- !, cpp_canon_specs(S, S1).   % `unsigned' IS `unsigned int', `long' `long int': one spelling, or the member `operator<<(unsigned int)' was no exact match for an `unsigned' and the free `unsigned char' template took it
cpp_bare_type(T, T).
cpp_canon_specs(S, S1) :- ( cpp_int_spelling(S, S0) -> S1 = S0 ; msort(S, S1) ).
%% AN INTEGER TYPE HAS ONE SPELLING, the shortest ([basic.fundamental]/2: `signed int', `int' and `signed' are one
%% type, as are `long int' and `long', `unsigned int' and `unsigned'), in a comparison (cpp_canon_specs) and in the
%% KEY an instance is named by (cpp_type_key): libc++ specializes `__libcpp_is_signed_integer' over `signed int',
%% `signed long' and `signed short', and keyed by the words as written those specializations never matched `int',
%% `long' or `short' -- `__libcpp_signed_integer<int>' was false and std::format took an int for a `__handle'
%% (test/cpp/run/intspell.cpp). `signed char' stays a type of its own beside `char'.
cpp_int_spelling(S, S1) :- S = [_|_], forall(member(W, S), ( atom(W), memberchk(W, [int, signed, unsigned, long, short, char, '__int128']) )),
    msort(S, Ss), cpp_int_spelling_(Ss, S1), !.
cpp_int_spelling_([int], [int]).
cpp_int_spelling_([signed], [int]).
cpp_int_spelling_([int, signed], [int]).
cpp_int_spelling_([unsigned], [unsigned]).
cpp_int_spelling_([int, unsigned], [unsigned]).
cpp_int_spelling_([short], [short]).
cpp_int_spelling_([int, short], [short]).
cpp_int_spelling_([short, signed], [short]).
cpp_int_spelling_([int, short, signed], [short]).
cpp_int_spelling_([short, unsigned], [unsigned, short]).
cpp_int_spelling_([int, short, unsigned], [unsigned, short]).
cpp_int_spelling_([long], [long]).
cpp_int_spelling_([int, long], [long]).
cpp_int_spelling_([long, signed], [long]).
cpp_int_spelling_([int, long, signed], [long]).
cpp_int_spelling_([long, unsigned], [unsigned, long]).
cpp_int_spelling_([int, long, unsigned], [unsigned, long]).
cpp_int_spelling_([long, long], [long, long]).
cpp_int_spelling_([int, long, long], [long, long]).
cpp_int_spelling_([long, long, signed], [long, long]).
cpp_int_spelling_([int, long, long, signed], [long, long]).
cpp_int_spelling_([long, long, unsigned], [unsigned, long, long]).
cpp_int_spelling_([int, long, long, unsigned], [unsigned, long, long]).
cpp_int_spelling_([char, signed], [signed, char]).
cpp_int_spelling_([char, unsigned], [unsigned, char]).
cpp_int_spelling_(['__int128'], ['__int128']).
cpp_int_spelling_(['__int128', signed], ['__int128']).   % `signed __int128' is __int128 (0.198): libc++'s make_signed_t<unsigned __int128> is `[signed, __int128]', and a static assertion of int128lib.cpp that it is __int128 failed once C++'s were checked
cpp_int_spelling_(['__int128', unsigned], [unsigned, '__int128']).
cpp_free_call(F, Ps, D, As, E) :- cpp_free_call_(F, Ps, D, As, E0),
    (   E0 = call(id(Name), _), '$cpp_consteval'(Name)                                             % a consteval function is EVALUATED AT COMPILE TIME ([dcl.constexpr]/13; 0.99: it ran at run time like constexpr since 0.42)
    ->  ( cpp_const_fold(E0, V), cpp_eval_scalar(V) -> ( integer(V) -> E = int(V) ; E = V ) ; cpp_immediate_context -> E = E0 ; cpp_refuse(0, consteval_call_not_constant(F)) )
    ;   E = E0 ).
cpp_free_call_(F, Ps, D, As, call(id(Name), As2)) :-
    cpp_fn_name(F, Ps, D, Name), cpp_use_fn(F, Ps, Name), cpp_use_mangled(F, Ps, Name),
    cpp_fill_defaults(Name, As, As1), cpp_ref_args(Name, As1, As2).
%% a mangled name is nothing this compiler defines, so the unit needs its PROTOTYPE: the item the lowering
%% takes a `declare' line from, emitted once, and the symbol table's entry so the call has a type
cpp_use_mangled(F, _, Name) :- Name == F, !, cpp_use_cdecl(F).
cpp_use_mangled(F, Ps, Name) :-
    (   '$cpp_fn'(F, _, Ps, no, decl(Ret0, V)), \+ cpp_instance_done(Name)
    ->  cpp_instance_note(Name, mangled), cpp_resolved_type(Ret0, Ret), cpp_resolved_params(Ps, Ps1),   % ITS TYPES RESOLVED, as a header's inline function's are (0.58): libc++ declares `string to_string(int)' and the passes rebuild the tables from the summary, where `string' is the raw alias -- `std::to_string(x) + "!"' then deduced nothing for `operator+(const basic_string<_CharT, _Traits, _Allocator> &, const _CharT *)', and the concatenation stayed a raw `+' on a struct
        cpp_params_bare(Ps1, Ps2), ccl_gdeclare([Name-fn(Ret, Ps2, V)]), cpp_note_defaults(Name, Ps),   % DECLARED AT FILE SCOPE (0.117), not in the innermost frame -- an instance's body walk is one, and the name was noted done: the second function that called `__thread_local_data()' met a call of no type, and `.set_pointer(...)' on it no_member. Its DEFAULT ARGUMENTS under the symbol it is called by (0.108): stoi's `size_t *__idx = nullptr, int __base = 10'
        cpp_as_lib(yes, cpp_add_instance_items([function(0, extern, Ret, Name, Ps2, V, none)]))
    ;   true ).
%% A C FUNCTION A HEADER DECLARES IN C++'S WORDS (0.227): libc++ 22 declares `void *__cxa_allocate_exception(std::size_t)
%% throw();' in `extern "C"' inside namespace __cxxabiv1, and the table held the type as the reader left it, `typedef(scoped([std],
%% size_t))', which the lowering cannot type -- std::make_exception_ptr was refused. Where it is first called (here, and on the
%% plain call's road, cpp_call/4) its types are resolved and it is declared again, as a mangled declaration is above; its name
%% stays its own. A name with a definition is left as it is: its definition declares it (cpp_item/2, cpp_use_fn/3)
cpp_use_cdecl(F) :- atom(F), \+ '$cpp_fn'(F, _, _, yes, _), ccl_declared(F, fn(Ret0, Ps, V)), cpp_mentions_scoped(fn(Ret0, Ps)), \+ cpp_instance_done(F), !,
    cpp_instance_note(F, cdecl), cpp_resolved_type(Ret0, Ret), cpp_resolved_params(Ps, Ps1), cpp_params_bare(Ps1, Ps2), ccl_gdeclare([F-fn(Ret, Ps2, V)]),
    cpp_as_lib(yes, cpp_add_instance_items([function(0, extern, Ret, F, Ps2, V, none)])).   % the item too, which the table is built again from after the desugaring
cpp_use_cdecl(_).
cpp_mentions_scoped(T) :- compound(T), ( T = scoped(_, _) -> true ; T =.. [_|As], member(A, As), cpp_mentions_scoped(A) ), !.
%% A LIBRARY HEADER'S FREE FUNCTION IS EMITTED WHERE IT IS CALLED, as its classes and its templates already are:
%% libc++ writes ten `__convert_to_integral' overloads, one per integer type, and a program calls one -- the others
%% would drag in what this compiler cannot lower (`__int128_t') for nothing.
cpp_use_fn(F, Ps, Name) :-
    (   '$cpp_fn'(F, _, Ps, yes, lazy(function(L, Sto, Ret, N, Ps2, V, Body))), \+ cpp_instance_done(Name), \+ cpp_making(Name)
    ->  cpp_trace(use_fn(Name, emit)), nb_getval('$cpp_making', M0), nb_setval('$cpp_making', [Name|M0]),                % IN PROGRESS while it emits, NOTED after (0.69's rule, in its fourth place): noted first, an emission a candidate's check abandoned left the name behind, and the real call to `__convert_to_integral' had no declaration and no type
        ( '$cpp_friend_in'(F, Ps, FC) -> Walk = cpp_in_class(FC, cpp_item(function(L, Sto, Ret, N, Ps2, V, Body), Items)) ; Walk = cpp_item(function(L, Sto, Ret, N, Ps2, V, Body), Items) ),   % a hidden friend's body in its class (0.112)
        (   catch(\+ \+ cpp_as_lib(yes, ( cpp_isolated(Walk), cpp_add_instance_items(Items), cpp_declare_emitted(Items) )), E, ( nb_setval('$cpp_making', M0), throw(E) ))   % inside `\+ \+': the items go to the facts, the walk's intermediates are reclaimed
        ->  nb_setval('$cpp_making', M0), cpp_instance_note(Name, hdr)
        ;   nb_setval('$cpp_making', M0), cpp_refuse(0, function_not_emitted(Name)) )   % never silently: the call would be emitted and the definition not, and the linker would say so
    ;   ( cpp_instance_done(Name) -> cpp_trace(use_fn(Name, done)) ; cpp_making(Name) -> cpp_trace(use_fn(Name, making)) ; '$cpp_fn'(F, _, Ps, yes, O) -> cpp_trace(use_fn(Name, origin(O))) ; cpp_c_decl_current(F, Ps), cpp_trace(use_fn(Name, no_entry)) ) ).
%% ... DECLARED UNDER THE NAME IT IS EMITTED UNDER (0.202): the call names a header's overload by the parameters the pre-pass noted, raw, and the
%% registration declared it by the parameters it resolved -- `operator==(coroutine_handle<>, coroutine_handle<>)' is `op.eq.2.coroutine_handle...'
%% to the call and `...coroutine_handle.void...' to the table, so `h == nullptr' found its operator emitted and undeclared (`no_operator(==)')
cpp_declare_emitted(Items) :- forall(( member(function(_, _, R, FN, FPs, V, _), Items), atom(FN), \+ ccl_declared(FN, fn(_, _, _)) ), ccl_gdeclare([FN-fn(R, FPs, V)])).
%% THE TABLE HOLDS ONE TYPE PER NAME, so a C function that shares its name with a library template is called under whichever
%% declaration the table kept (0.117): `std::remove(path)' after <fstream> -- the algorithm's template, `remove(_ForwardIterator,
%% _ForwardIterator, const _Tp &)', came first in the summary and the lowering met `_ForwardIterator' in the call of stdio's
%% `remove(const char *)'. A plain C declaration that is the one CALLED is declared again, as the header wrote it, when the table's
%% entry is another overload's.
cpp_c_decl_current(F, Ps) :-
    (   cpp_header_c_name(F), '$cpp_fn'(F, _, Ps, no, decl(Ret0, V)), cpp_params_key(Ps, K),
        \+ ( ccl_declared(F, T), T = fn(_, Ps0, _), cpp_params_key(Ps0, K0), K0 == K )
    ->  cpp_resolved_type(Ret0, Ret), cpp_resolved_params(Ps, Ps1), cpp_params_bare(Ps1, Ps2), ccl_declare(F, fn(Ret, Ps2, V)),   % for this walk, AND FOR EVERY WALK whose table holds the other overload (0.137: the mark kept it to the first, and the chrono formatter's `std::abs(y) % 100' in a later walk was typed by chrono::abs's raw `duration<_Rep, _Period>')
        atomic_list_concat([F, '.cdecl.', K], Mark),
        (   cpp_instance_done(Mark) -> true
        ;   cpp_instance_note(Mark, cdecl), cpp_as_lib(yes, cpp_add_instance_items([function(0, extern, Ret, F, Ps2, V, none)])) )   % the prototype item once: the passes rebuild the table from the items (the unit's own items come first and shadow the header's)
    ;   true ).
cpp_register_([template(_, TPs, concept(_, N, E))|Is]) :- !, asserta('$cpp_concept'(N, concept(TPs, E))), cpp_register_(Is).   % C++20
cpp_register_([concept(_, N, E)|Is]) :- !, asserta('$cpp_concept'(N, concept([], E))), cpp_register_(Is).
%% A FUNCTION TEMPLATE WITH AN `auto' PARAMETER BESIDE ITS WRITTEN HEAD ([dcl.fct]/22: the invented parameters follow
%% the written ones): libc++ 18's `template <contiguous_iterator _Iterator> ... __parse_arg_id(_Iterator, _Iterator, auto
%% &__parse_ctx)' kept its `auto' as a type, and std::format's replacement-field parser had no candidate (0.112;
%% test/cpp/run/autohead.cpp). The abbreviated function template with no head is the clause below (0.42).
cpp_register_([template(L, TPs0, function(FL, Sto, Ret, N, Ps, V, Body))|Is]) :- atom(N), cpp_auto_params(Ps, 0, Ps1, ATPs), ATPs \== [], !,
    append(TPs0, ATPs, TPs), cpp_register_([template(L, TPs, function(FL, Sto, Ret, N, Ps1, V, Body))|Is]).
cpp_register_([template(L, TPs, Item)|Is]) :- !,
    (   TPs = [_|_], cpp_mct_def(Item, C, L1, K, N0, Bs, NMs) -> cpp_nested_template_put(C, L1, TPs, K, N0, Bs, NMs)   % a MEMBER CLASS TEMPLATE of a PLAIN class, defined out of it (0.201, cpp_mct_def/7)
    ;   TPs = [_|_], cpp_mdef_item(Item, C, none, Member) -> cpp_mdef_put(C, [], none, template(L, TPs, Member)), cpp_refresh_mts(C)   % a MEMBER TEMPLATE of a PLAIN class, defined out of it (0.117): `template <class F> T::T(F f, int x) : v(f(x)) {}' -- kept as a member template of the class, its body given to the declaration already registered
    ;   cpp_mdef_item(Item, C, Pattern, Member) -> cpp_mdef_put(C, TPs, Pattern, Member)                                           % a member DEFINED out of its class, by the class's name
    ;   TPs = [_|_], nb_getval('$cpp_in_lib', no), cpp_static_noinit_item(Item, C, Pattern, Member) -> cpp_mdef_put(C, TPs, Pattern, Member)   % the PROGRAM's static data member of a class template defined out of it with no initializer (0.218, cpp_static_noinit_item/4)
    ;   TPs == [], cpp_fspec_item(Item, FN, FArgs) -> assertz('$cpp_fspec'(FN, FArgs, Item))                                      % an EXPLICIT SPECIALIZATION of a function template (0.129): no candidate, the body of the instance it matches (cpp_fspec_for)
    ;   cpp_spec_name(Item, N, Pattern) -> cpp_spec_put(N, TPs, Pattern, Item)                                                     % a partial or full specialization, by its pattern
    ;   cpp_template_name(Item, N) -> cpp_template_put(N, TPs, Item)
    ;   true ),
    cpp_register_(Is).
cpp_register_([function(L, Sto, Ret, N, Ps, V, Body)|Is]) :- atom(N), cpp_auto_params(Ps, 0, Ps1, TPs), TPs \== [], !,    % C++20: an abbreviated function template, a template of invented parameters
    cpp_template_put(N, TPs, function(L, Sto, Ret, N, Ps1, V, Body)), cpp_register_(Is).
cpp_register_([include(_, _, file(P, preprocessed, unit(Js)))|Is]) :- !, ( cpp_read_now_summarized(P, F) -> cpp_load_ast(F) ; cpp_index_header(Js) ), cpp_register_(Is).   % a library header, flattened: indexed by name, each item registered when a name is first asked for -- from the AST its read wrote, where there is one (0.218, below)
cpp_register_([include(_, _, file(_, summary, summary(F)))|Is]) :- !, cpp_load_ast(F), cpp_register_(Is).              % served from its summary: its items from the AST file beside it (ccl_ast_write)
cpp_register_([include(_, _, file(_, _, unit(Js)))|Is]) :- !, cpp_register_header(Js), cpp_register_(Is).   % a header read whole (the program's own): its classes and templates
cpp_register_(I) :- \+ ( I == [] ; I = [_|_] ), !, cpp_register_([I]).
cpp_register_([]).
cpp_register_([extern_template(_, I)|Is]) :- !, cpp_note_extern(I), cpp_register_(Is).
cpp_register_([declare(L, base(_, [class(K, C0, Bases, Ms)]))|Is]) :- !,
    ( cpp_class_item_name(C0, C) -> cpp_class_encloses(C0, C), cpp_register_class(K, L, C, Bases, Ms) ; true ), cpp_register_(Is).
cpp_register_([function(_, _, Ret0, operator(Op), Ps, V, Body)|Is]) :- !,
    cpp_free_operator(Op, Ps, N), cpp_fn_put(N, Ps, Body, own(false)), cpp_fn_name(N, Ps, yes, Name),   % A FREE OPERATOR IS AN OVERLOAD SET like a function's (0.56): noted by its word, named by its parameters where two definitions share the word -- two classes' friend inserters are both `operator<<(ostream &, ...)', and the first took the second's argument
    cpp_plain_params(Ps, Ps1), cpp_type_or_self(Ret0, Ret), ccl_declare(Name, fn(Ret, Ps1, V)), cpp_note_defaults(Name, Ps),
    cpp_register_(Is).
cpp_register_([function(_, _, Ret, N, Ps, V, Body)|Is]) :- atom(N), !,
    cpp_fn_body_mark(Body, D), cpp_fn_name(N, Ps, D, Name), cpp_note_defaults(Name, Ps),
    ( Name == N -> true ; ccl_declare(Name, fn(Ret, Ps, V)) ),                                     % an overload's own name is not in the table the reader built
    cpp_register_(Is).
cpp_register_([dtor_def(_, C, _, _)|Is]) :- !, asserta('$cpp_dtor_def'(C)), cpp_register_(Is).
cpp_register_([namespace(_, _, Js)|Is]) :- !, cpp_register_(Js), cpp_register_(Is).
cpp_register_([extern_c(_, Js)|Is]) :- !, cpp_register_(Js), cpp_register_(Is).
%% A PLAIN STRUCT WHOSE MEMBER IS A CLASS IS A CLASS. The reader keeps a C++ `struct' of data members as C's struct
%% (ccl_make_class: no base, no method), and `struct Rec { std::string name; int n; }' then had a member type the
%% tables never resolved (`no_member(name, ...)') and no constructor, destructor or copy for the string it holds.
%% Promoted at registration ('$cpp_promoted', by a member whose type -- or whose array's element type -- names a
%% class), it goes a class's whole road: the implicit constructor, destructor and copy, the aggregate initialization
%% member by member. A struct of plain members stays C's, its member types resolved in place (cpp_item's clause).
cpp_register_([declare(L, base(Q, [struct(N, Ms)]))|Is]) :- atom(N), Ms \== none, \+ '$cpp_promoted'(N), cpp_struct_promotes(N, Ms), !,
    assertz('$cpp_promoted'(N)), cpp_trace(promoted(N)), cpp_register_([declare(L, base(Q, [class(struct, N, [], Ms)]))|Is]).
%% A UNION AT NAMESPACE SCOPE WITH A CONSTRUCTOR, A DESTRUCTOR OR A METHOD IS A UNION CLASS (0.121), as a nested one (cpp_nested_class) and a
%% union template's instance are: a class's whole road over the storage of a union ('$cpp_union'). The reader keeps it `union(N, Ms)', which the
%% lowering took for a plain union and refused at its first use, `class(U)'. A union of data members alone stays C's.
cpp_register_([declare(L, base(_, [union(N, Ms)]))|Is]) :- atom(N), N \== anon, cpp_union_class_members(Ms), \+ cpp_class_l(N, _), !,
    ( '$cpp_union'(N) -> true ; assertz('$cpp_union'(N)) ), cpp_trace(union_class(N)), cpp_register_class(union, L, N, [], Ms), cpp_register_(Is).
cpp_register_([_|Is]) :- cpp_register_(Is).
%% A HEADER READ IN THE BUILD'S OWN PROCESS IS REGISTERED AS ONE SERVED FROM ITS SUMMARY IS (0.218): its read wrote the summary
%% and the AST beside it (ccl_read_unit/3), and its items come from that AST, in the include's order among the headers served
%% from theirs. Indexed apart, as '$cpp_hdr' facts that cpp_hdr_item/2 asks first, its items took a flattened name from a
%% header included before it: `<system_error>' read cold after `<charconv>' was served warm gave `__traits' to `<variant>'s
%% `__variant_detail::__traits<_Types...>' over `<charconv>'s `__itoa::__traits<_Tp>', and `std::from_chars' was refused,
%% `instance_refused(..., no_member_type('__traits.unsigned', type))', where a warm build and a build of every header cold
%% in turn compiled it. A read that wrote no summary is indexed as before; the read notes what it wrote (ccl_note_read_wrote/2)
cpp_read_now_summarized(P, F) :- atom(P), nb_current('$ccl_read_wrote', L), memberchk(P-F, L), ccl_ast_file(F, A), exists_file(A), !.
%% A MEMBER CLASS TEMPLATE OF A PLAIN CLASS DEFINED OUT OF IT (0.201): `template <class _Extents> class layout_left::mapping
%% { ... };' of libc++'s <mdspan>, the class declaring `template <class _Extents> class mapping;' -- registered as the member
%% class template it is (cpp_nested_template_put/7), where the road of a member template defined out of a plain class kept
%% it as a member's body and `layout_left::mapping<E>' had no template
cpp_mct_def(declare(L, base(_, [class(K, scoped(Path, N0), Bs, Ms)])), C, L, K, N0, Bs, Ms) :- Ms \== none, cpp_mct_owner(Path, N0, C).
cpp_mct_owner(Path, N0, C) :- cpp_mdef_class(Path, C, none), ( N0 = tmpl(N, _) -> true ; N = N0 ), atom(N), '$cpp_nested_tmpl'(C, N, _), !.
%% the declaration of a member template of a plain class, registered with the class and bodyless, takes the body of its out-of-class definition
%% (the same merge an instance of a class template makes: the declaration's default arguments and template-parameter defaults stay)
cpp_refresh_mts(C) :-
    findall(K-TPs-M, ( '$cpp_mt'(C, K, TPs, M), cpp_member_shape(M, _, _, none) ), Rows),   % the row's key is `ctor' where the member's shape key is `$ctor'
    nb_setval('$cpp_mdef_types', []),
    forall(( member(K-TPs-M, Rows), catch(cpp_member_def(C, C, [], template(0, TPs, M), template(_, TPs1, M1)), error(not_lowered(_), _), fail), M1 \== M ),
           ( retract('$cpp_mt'(C, K, TPs, M)), assertz('$cpp_mt'(C, K, TPs1, M1)) )).
%% AN EXPLICIT SPECIALIZATION OF A FUNCTION TEMPLATE IS NO CANDIDATE ([temp.expl.spec], [over.match.funcs]/7: overload resolution
%% sees the templates; the chosen one's instance for those arguments IS the specialization; 0.129). `template <> int f(unsigned
%% long, int)' was registered as one more template with no parameter, it tied with the primary (both exact), and the first
%% declared -- the primary -- won; `template <> int f<char>(char, int)' went to the class specializations and was read by
%% nothing. Every explicit specialization of a function was silently ignored: libc++'s `__to_chars_itoa(char *, char *,
%% __uint128_t, false_type)', its 128-bit road, printed `42' as twenty digits. Kept apart, '$cpp_fspec'(Template, Args | none,
%% Item), by the name it specializes, its explicit template arguments where it writes them.
cpp_fspec_item(function(_, _, _, N, _, _, _), N, none) :- atom(N), !.
cpp_fspec_item(function(_, _, _, tmpl(N, Args), _, _, _), N, Args) :- atom(N), !.
cpp_fspec_item(function(_, _, _, operator(Op), Ps, _, _), N, none) :- cpp_free_operator(Op, Ps, N), !.
cpp_fspec_item(declaration(_, _, _, [var(N, fn(_, _, _), none)]), N, none) :- atom(N), !.
cpp_fspec_item(declaration(_, _, _, [var(tmpl(N, Args), fn(_, _, _), none)]), N, Args) :- atom(N), !.
%% ... and an instance of the template takes the body of the DEFINED specialization whose parameter types are the instance's,
%% resolved, by-value top-level cv dropped ([dcl.fct]/5), whose explicit arguments are the instance's bindings, and whose result
%% is the instance's unless either is deduced ([temp.deduct.decl]: a specialization's own arguments are deduced from its function
%% type, the result included). A specialization declared and not defined here leaves the primary's body, as before.
cpp_fspec_for(F, TPs, B, Ret1, Ps1, function(L, Sto, Ret, N, Ps, V, Body)) :-
    \+ \+ '$cpp_fspec'(F, _, _), length(Ps1, NP),
    '$cpp_fspec'(F, Args, function(L, Sto, Ret, N, Ps, V, Body)), Body \== none, length(Ps, NP),
    catch(cpp_fspec_args_match(Args, TPs, B), _, fail),
    catch(cpp_fspec_params_match(Ps1, Ps), _, fail),
    catch(cpp_fspec_ret_match(Ret1, Ret), _, fail), !.
cpp_fspec_args_match(none, _, _) :- !.
cpp_fspec_args_match(Args, TPs, B) :- findall(P, member(tparam(_, P, _), TPs), Names), cpp_fspec_args_(Args, Names, B).
cpp_fspec_args_([], _, _).
cpp_fspec_args_([A|As], [P|Ps], B) :- memberchk(P-V, B), cpp_fspec_arg_same(A, V), cpp_fspec_args_(As, Ps, B).
cpp_fspec_arg_same(A, V) :- ( cpp_targ_value(A, AV) -> true ; AV = A ), ( AV == V -> true ; cpp_fspec_same(AV, V) ), !.
cpp_fspec_params_match([], []).
cpp_fspec_params_match([P|Ps], [Q|Qs]) :- cpp_param_t(P, T0), cpp_param_t(Q, U0), cpp_param_fn_type(T0, T1), cpp_param_fn_type(U0, U1),
    cpp_type(T1, T), cpp_type(U1, U), cpp_fspec_same(T, U), cpp_fspec_params_match(Ps, Qs).
cpp_fspec_ret_match(R1, R) :- ( ( R1 = base(_, [auto]) ; R = base(_, [auto]) ) -> true ; cpp_type(R1, T), cpp_type(R, U), cpp_fspec_same(T, U) ).
cpp_fspec_same(T, U) :- T == U, !.
cpp_fspec_same(T, U) :- cpp_type_key(T, K), cpp_type_key(U, K), !.
cpp_fspec_same(T, U) :- ccl_resolve_type(T, RT), ccl_resolve_type(U, RU), RT == RU, !.
cpp_spec_name(declare(_, base(_, [class(_, tmpl(N, P), _, _)])), N, P).
cpp_spec_name(declare(_, base(_, [class(_, scoped(_, tmpl(N, P)), _, _)])), N, P).   % a specialization named with its namespace, `template <class... A> struct std::coroutine_traits<R, A...>' (0.110; the namespaces flatten)
cpp_spec_name(declare(_, base(_, [struct(scoped(_, tmpl(N, P)), _)])), N, P).
cpp_spec_name(declare(_, base(_, [struct(tmpl(N, P), _)])), N, P).
cpp_spec_name(declare(_, base(_, [union(scoped(_, tmpl(N, P)), _)])), N, P).   % a UNION template's specialization (0.121): libc++ 18's std::variant stores its alternatives in `union __union<_Trait::_TriviallyAvailable, _Index, _Tp, _Types...>'
cpp_spec_name(declare(_, base(_, [union(tmpl(N, P), _)])), N, P).
cpp_spec_name(declaration(_, _, _, [var(tmpl(N, P), _, _)]), N, P).
cpp_spec_name(declaration(_, _, _, [var(scoped(_, tmpl(N, P)), _, _)]), N, P).   % ... a VARIABLE template's, named with its namespace: libc++'s `__format::__enable_insertable<basic_string<_CharT>>' (0.112)
cpp_spec_name(function(_, _, _, tmpl(N, P), _, _, _), N, P).
%% the out-of-class definitions of the batch, noted BEFORE any class of it registers (the class item comes first in
%% the header, its members' bodies after it), so the class takes them as its members' bodies (cpp_lazy_class)
cpp_note_hdr_mdefs([]).
cpp_note_hdr_mdefs([I|Is]) :- ( I \= template(_, _, _), cpp_mdef_item(I, C, Pat, Member) -> cpp_mdef_put(C, [], Pat, Member) ; true ), cpp_note_hdr_mdefs(Is).
%% THE LIBRARY'S FUNCTIONS ARE COMPILED AS C++ HAS THEM, NOT CHECKED: libc++'s bodies keep raw pointers by their own
%% discipline (a vector's begin, end and capacity; a swap of two pointers through references), which the safe part
%% would refuse at every line -- so a function that comes from a library header (an inline one, a lazy class's
%% member, an instance of the header's template, whatever such a walk emits) is marked '$cpp_libfn'(Name) and the
%% check skips it, while the program's own functions, its own templates' instances included, wherever they are
%% instantiated from, are checked as always. The lowering lowers both.
cpp_as_lib(Flag, Goal) :- nb_getval('$cpp_in_lib', Was), nb_setval('$cpp_in_lib', Flag), ( catch(Goal, E, ( nb_setval('$cpp_in_lib', Was), throw(E) )) -> nb_setval('$cpp_in_lib', Was) ; nb_setval('$cpp_in_lib', Was), fail ).
cpp_lib_origin(N, Flag) :- ( '$cpp_lib'(N) -> Flag = yes ; '$cpp_nested_tmpl'(EC, _, N), cpp_lib_class(EC) -> Flag = yes ; Flag = no ).   % a MEMBER class template of a library class is the library's (0.113): transform_view's `__iterator<_Const>', checked as the program's, refused its `__parent_(std::addressof(__parent))'
cpp_lib_class(C) :- ( '$cpp_lazy_c'(C) -> true ; '$cpp_lib'(C) -> true ; '$cpp_inst'(C, inst(N, _)), '$cpp_lib'(N) ).   % a LIBRARY class is lazy; a lazy class is not always the library's (0.127: the program's instances are lazy too, '$cpp_lazy_p')
cpp_lib_class(C) :- '$cpp_lib_closure'(C), !.   % A CLOSURE MADE IN A LIBRARY'S WALK (0.201): a generic lambda's call operator template is instantiated where it is called, and its instance took the class's origin -- the program's, for a closure made in a free function template of a header: libc++ 18's `__pstl_transform_reduce' makes `[__transform, __reduce](auto __brick_first, auto __brick_last, _Tp __brick_init) { ... std::move(__transform) ... }', checked as the program's, `move of a non-owner'
cpp_lib_class(C) :- cpp_enclosing(C, E), E \== C, cpp_lib_class(E).   % a NESTED class of a library class is the library's: basic_string's `__rep', whose implicit move constructor was emitted as the program's and checked (`move of a non-owner')
cpp_library_function(Name) :- catch('$cpp_libfn'(Name), _, fail).
cpp_register_lazy([]).
cpp_register_lazy([declare(L, base(_, [class(K, C0, Bases, Ms)]))|Is]) :- !,
    ( cpp_class_item_name(C0, C) -> cpp_class_encloses(C0, C), cpp_lazy_class(L, K, C, Bases, Ms) ; true ), cpp_register_lazy(Is).
cpp_register_lazy([declare(L, base(_, [struct(C, Ms)]))|Is]) :- !, cpp_lazy_class(L, struct, C, [], Ms), cpp_register_lazy(Is).
cpp_register_lazy([function(_, _, _, scoped(_, _), _, _, Body)|Is]) :- Body \== none, !, cpp_register_lazy(Is).   % a member defined out of its class: noted already (cpp_note_hdr_mdefs)
cpp_register_lazy([declaration(_, _, _, [var(scoped([_], _), _, _)])|Is]) :- !, cpp_register_lazy(Is).   % a static data member defined out of its class: the class's static declarations carry its initializer (cpp_static_constructed, 0.101)
cpp_register_lazy([ctor_def(_, _, _, _, _, _)|Is]) :- !, cpp_register_lazy(Is).
cpp_register_lazy([dtor_def(_, _, _, _)|Is]) :- !, cpp_register_lazy(Is).
%% A FREE OPERATOR of a header (a literal operator, <string>'s `operator""s'; a class's `operator==', <thread>'s -- 0.117) is an inline function under its free operator name, declared now and emitted where it is called
cpp_register_lazy([function(L, Sto, Ret, operator(Op), Ps, V, Body)|Is]) :- Body \== none, Op \= conv(_), cpp_free_operator(Op, Ps, N0), !,
    cpp_register_lazy([function(L, Sto, Ret, N0, Ps, V, Body)|Is]).
cpp_register_lazy([function(L, Sto, Ret, N, Ps, V, Body)|Is]) :- atom(N), Body \== none, !,      % an inline function of the header: declared now, emitted (linkonce) where it is called
    cpp_resolved_params(Ps, Ps1), ( Ret = base(_, [auto]) -> Ret1 = Ret ; cpp_type_or_self(Ret, Ret1) ),   % ... DECLARED WITH ITS TYPES RESOLVED: `setiosflags(ios_base::fmtflags)' declared raw, the lowering converted the call's argument to `ios_base::fmtflags' and could not
    cpp_register_([function(L, Sto, Ret1, N, Ps1, V, Body)]), cpp_register_lazy(Is).
cpp_register_lazy([declaration(L, extern, _, Vs)|Is]) :- forall(( member(var(N, T, none), Vs), \+ T = fn(_, _, _) ), cpp_lazy_var(L, N, T)), !, cpp_register_lazy(Is).
cpp_register_lazy([declaration(L, Sto, _, Vs)|Is]) :- Sto \== extern, member(var(_, T, Init), Vs), Init \== none, \+ T = fn(_, _, _), !,
    forall(( member(var(N, T0, Init0), Vs), Init0 \== none ), cpp_lazy_inline_var(L, N, T0, Init0)), cpp_register_lazy(Is).
%% ... AND ONE WITH NO INITIALIZER, which C++ VALUE-INITIALIZES ([dcl.init]/8; a `constexpr' object must be
%% initialized, and none written is that): `inline constexpr __ignore_type ignore;' is `std::ignore', an
%% EMPTY class with nothing to construct, and left a declaration it reached the lowering as an `external
%% global' the link could not find. Only an empty class is taken -- a class with a constructor would have to
%% be constructed, and nothing here is evaluated at compile time.
cpp_register_lazy([declaration(L, Sto, _, Vs)|Is]) :- Sto \== extern, member(var(_, T, none), Vs), \+ T = fn(_, _, _),
    once(catch(cpp_type(T, T1), _, fail)), cpp_class_of_type(T1, C), cpp_empty_class(C), !,   % a refusal in the type is no such variable, and must not take the header's load down with it
    forall(member(var(N, T0, none), Vs), cpp_lazy_inline_var(L, N, T0, init([]))), cpp_register_lazy(Is).
cpp_register_lazy([extern_template(_, I)|Is]) :- !, cpp_note_extern(I), cpp_register_lazy(Is).
cpp_register_lazy([template(L, TPs, concept(L2, N, E))|Is]) :- !, cpp_register_([template(L, TPs, concept(L2, N, E))]), cpp_register_lazy(Is).   % a header's concept joins the concepts ('$cpp_concept'/2, by name)
cpp_register_lazy([I|Is]) :- cpp_register_(I), cpp_register_lazy(Is).
cpp_resolved_params([], []).
cpp_resolved_params([param(T0, N, D)|Ps], [param(T, N, D)|Qs]) :- !, cpp_type_or_self(T0, T), cpp_resolved_params(Ps, Qs).
cpp_resolved_params([param(T0, N)|Ps], [param(T, N)|Qs]) :- !, cpp_type_or_self(T0, T), cpp_resolved_params(Ps, Qs).
cpp_resolved_params([P|Ps], [P|Qs]) :- cpp_resolved_params(Ps, Qs).
%% A HEADER'S INLINE VARIABLE -- C++17's, DEFINED in the header with its initializer, which no shipped library
%% exports: libc++'s digit tables, `__digits_base_10', `__pow10_64' -- is emitted by the program that names it, a
%% `linkonce' global as a header's inline function is emitted where it is called, under its own name; the
%% initializer's items desugared (constants, folded). Named through the summary alone it was an `external global'
%% and the link named five of them.
cpp_lazy_inline_var(L, N, T0, Init0) :- \+ cpp_instance_done(N), !, cpp_instance_note(N, inline_var),
    cpp_type(T0, T1),
    (   cpp_has_auto(T1) -> cpp_init_expr(Init0, Init1), ( ccl_type_of(Init1, IT), IT \== unknown -> cpp_auto_deduce(T1, IT, T) ; cpp_refuse(L, auto_inline_var(N)) )   % C++20's customization points, `inline constexpr auto iter_move = __iter_move::__fn{}': the auto deduced from the initializer, where it reached the lowering as `auto'
    ;   T = T1, Init1 = none ),
    (   cpp_class_of_type(T, C), cpp_empty_class(C) -> Init = init([])   % A GLOBAL OF AN EMPTY CLASS IS ITS ZERO BYTES, its constructor not run: a TAG -- `inline constexpr nullopt_t nullopt{nullopt_t::__secret_tag{}, nullopt_t::__secret_tag{}}', `in_place', `piecewise_construct' -- has nothing to construct, and this compiler runs no dynamic initialization
    ;   Init1 \== none -> Init = Init1
    ;   cpp_init_expr(Init0, Init2), ( Init2 = init(_), cpp_class_of_type(T, C2), cpp_agg_constant(C2, Init2, Init3) -> Init = Init3 ; Init = Init2 ) ),   % an aggregate's list completed by its defaults (cpp_agg_constant)
    ccl_declare(N, T), nb_getval('$cpp_gvar', G), nb_setval('$cpp_gvar', [N-N|G]),
    ( atom(N), Init \== none, T = base(Qs, _), memberchk(const, Qs), catch(cpp_eval_agg_kind(T, _), _, fail) -> atom_concat('$cpp_gagg:', N, GK), nb_setval(GK, agg(T, Init, global)) ; true ),   % A HEADER'S CONSTANT AGGREGATE is a value for the evaluator (0.164), as the program's own is (cpp_fold_const_inits_): `inline constexpr __fields __fields_integral{...}', which every integer's format spec is parsed against
    cpp_as_lib(yes, cpp_add_instance_items([declaration(L, linkonce, T, [var(N, T, Init)])])).
cpp_lazy_inline_var(_, _, _, _).
cpp_init_expr(init(Items), init(Items1)) :- !, findall(item(D, V1), ( member(item(D, V0), Items), once(cpp_init_expr(V0, V1)) ), Items1).   % ONE walk per item (0.112): a template-id's call has two answers, and the list of a static `array' was doubled
cpp_init_expr(E0, E) :- cpp_expr(none, E0, E).
%% A LIBRARY HEADER'S EXTERN GLOBAL is DEFINED IN THE SHIPPED BINARY and reached by the symbol that binary
%% exports, as a declared-only function has been since 0.61: `extern ostream cout;' inside `std::__1' is
%% `_ZNSt3__14coutE' -- `_ZN', the namespace path, the length-prefixed name, `E', and no parameters. Its name HERE
%% is that symbol, so nothing has to rewrite the call; the declaration is emitted once and the linker finds it.
cpp_lazy_var(L, N, T0) :- cpp_mangled_var(N, Name), \+ cpp_instance_done(Name), !,
    cpp_instance_note(Name, mangled),
    ( catch(cpp_type(T0, T), _, fail) -> true ; T = T0 ),
    ( catch(cpp_class_of_type(T, _), _, fail) -> true ; true ),   % ITS CLASS REGISTERED, its struct emitted (0.202): `std::nothrow' handed to `operator new(std::size_t, const std::nothrow_t &)' calls no member of its class, and the lowering met the raw class
    ccl_declare(Name, T), nb_getval('$cpp_gvar', G), nb_setval('$cpp_gvar', [N-Name|G]),
    cpp_as_lib(yes, cpp_add_instance_items([declaration(L, extern, T, [var(Name, T, none)])])).
cpp_lazy_var(_, _, _).
cpp_mangled_var(N, Name) :- atom(N), \+ cpp_c_name(N), cpp_hdr_ns(N, Path), Path = [_|_], ccl_byte_length(N, NL),
    (   Path == [std] -> atomic_list_concat(['_ZSt', NL, N], Name)   % DIRECTLY IN std an unscoped name, `_ZSt7nothrow' (0.202; the Itanium ABI's <unscoped-name>): libc++ declares `std::nothrow' in the unversioned namespace, and `_ZNSt7nothrowE' named nothing at the link
    ;   cpp_mangle_ns(Path, NsText), atomic_list_concat(['_ZN', NsText, NL, N, 'E'], Name) ).
%% ... and the name a program writes is that symbol, the header's items loaded on the first ask as a function's are
cpp_global_var(N, Name) :- nb_getval('$cpp_gvar', G), memberchk(N-Name, G), !.
cpp_global_var(N, Name) :- atom(N), cpp_hdr_item(N, _), cpp_hdr_load(N), nb_getval('$cpp_gvar', G), memberchk(N-Name, G), !.
cpp_global_var(N, N) :- atom(N), catch('$cpp_ns_own'(N), _, fail), ccl_gdeclared(N, _), !.   % the program's own, renamed by cpp_ns_resolve
%% a namespace-scope object whose class has an operator(): a header's (loaded on the first ask) or the program's own
cpp_callable_global(F, Name, C) :- atom(F), \+ cpp_local(F),
    ( cpp_global_var(F, Name) -> true ; ccl_gdeclared(F, T0), \+ T0 = fn(_, _, _) -> Name = F ),
    ccl_type_of(id(Name), T), T \== unknown, cpp_class_of_type(T, C), cpp_has_member(C, operator('()')), !.
cpp_object_call(Name, C, As, call(id(MN), [Obj|As2])) :- cpp_method_on(id(Name), C, operator('()'), As, MN, _), cpp_fill_defaults(MN, As, As1), cpp_ref_args_of(MN, As1, As2), cpp_object_arg(MN, addr(id(Name)), Obj).
%% a lazy class: registered, its struct emitted, its members emitted as they are first used (the standard's rule for a
%% template's members; a library class's methods are hundreds, a program uses three)
cpp_lazy_class(_, _, _, _, none) :- !.                                                   % `class bad_alloc;': nothing to register or emit
cpp_lazy_class(L, K, C, Bases, Ms0) :-
    ( cpp_class_l(C, _) -> true
    ; asserta('$cpp_lazy_c'(C)),
      cpp_member_defs(C, C, [], Ms0, Ms),                                                 % the members DEFINED out of the class: their bodies, as an instance takes them
      ( cpp_isolated(( cpp_register_class(K, L, C, Bases, Ms), cpp_item(declare(L, base([], [class(K, C, Bases, Ms)])), Items) )) -> true ; cpp_refuse(L, class_not_emitted(C)) ),
      cpp_add_instance_items(Items) ).
cpp_is_lazy(C) :- ( '$cpp_lazy_c'(C) ; '$cpp_lazy_p'(C) ), !.
cpp_lazy_lib(C, Lib) :- ( cpp_lib_class(C) -> Lib = yes ; Lib = no ).   % what a lazy class's member is emitted as: the library's (unchecked) or the program's (checked)
%% A LIBRARY TEMPLATE'S INSTANCE IS LAZY. A class instance used to emit every member function it has, so
%% `std::vector<int> v; v.push_back(1);' compiled vector's hundred members and stopped at the first one this compiler
%% could not take -- `__swap_allocator', reached through a `swap' the program never calls. A library header's plain
%% class already emitted members only as they were named (cpp_use_member); an instance of a library template does so
%% too now, which is what the standard says a template instantiates. THE PROGRAM'S OWN TEMPLATES ARE LAZY TOO (0.127,
%% [temp.inst]/3: a member is instantiated where it is used), marked apart ('$cpp_lazy_p') so their members are emitted and
%% CHECKED as the program's: eager, a member nothing called was walked over every argument, and `D<Q>::sum()' naming
%% `this->x' over a Q without x, or `T::no_such_function()' in a member never called, refused the program.
cpp_lazy_instance(yes, Name) :- \+ cpp_is_lazy(Name), !, asserta('$cpp_lazy_c'(Name)).
cpp_lazy_instance(prog, Name) :- \+ cpp_is_lazy(Name), !, asserta('$cpp_lazy_p'(Name)).
cpp_lazy_instance(_, _).
cpp_incomplete_arg(base(_, [typedef(X)])) :- atom(X), ( '$cpp_inst'(X, _) ; '$cpp_iname'(_, _, X) ), \+ '$cpp_cls'(X, _).
%% a member of a lazy class, first used: its function emitted now
cpp_use_member(C, Name) :-
    (   cpp_is_lazy(C), \+ cpp_instance_done(Name), \+ cpp_making(Name),
        cpp_class(C, cls(Base, _, Ms, _, Defaults, _)), cpp_lazy_pick(C, Ms, Name, M)   % THE ONE WHOSE REQUIRES-CLAUSE HOLDS (0.136): two constructors of one signature share a name
    ->  cpp_make_lazy(Name, C, Base, Defaults, M)                                                       % lazy: a header's
    ;   true ).
%% ... and NOTED only once it is EMITTED, as a member template's instance is (cpp_make_member): the emission can
%% run inside another candidate's signature check, whose catch rejects that candidate and leaves the note behind.
%% `std::vector<std::string>' lost `basic_string''s move constructor exactly so.
cpp_make_lazy(Name, C, Base, Defaults, M) :-
    cpp_trace(make_lazy(Name)),                                                                             % which member, for the loop: what a program pulls in is read off these
    nb_getval('$cpp_making', M0), nb_setval('$cpp_making', [Name|M0]),
    cpp_lazy_lib(C, Lib),
    (   catch(\+ \+ cpp_as_lib(Lib, ( cpp_isolated(cpp_in_class(C, cpp_member_fns([M], C, Base, Defaults, Fns))), cpp_add_instance_items(Fns) )),   % inside `\+ \+': the member's items go to the facts, its walk is reclaimed
              E, ( nb_setval('$cpp_making', M0), throw(E) ))
    ->  nb_setval('$cpp_making', M0), cpp_instance_note(Name, C)
    ;   nb_setval('$cpp_making', M0), cpp_refuse(0, member_not_emitted(Name)) ).
cpp_member_mangled(C, method(_, Qs, _, M, Ps, _, _), Name) :- cpp_mangle_q(C, M, Qs, Ps, Name).
cpp_member_mangled(C, ctor(_, _, Ps, _, _), Name) :- cpp_mangle(C, C, Ps, Name).
cpp_member_mangled(C, dtor(_, _, Body), Name) :- cpp_dtor_name(C, Body, Name).
%% A DESTRUCTOR A LIBRARY HEADER DECLARES AND THE SHIPPED LIBRARY DEFINES -- `virtual ~ios_base();', `~locale();' --
%% is called by its Itanium name, as a declared-only function is (0.61): `_ZN', the namespace path, the class's
%% nested name (a nested class by its segments, locale::facet), `D1Ev' -- the complete-object destructor, the one a
%% delete calls before its free, and the same code as the base-object one for a class without virtual bases. A
%% template instance's keeps its own name: its body is in the header and compiled here. Two symbols short of a
%% running `std::cout << "hello"', the link named exactly these.
cpp_dtor_name(C, none, Name) :- atom(C), cpp_lib_class(C), cpp_class_scope(C, Path, Chain), catch(cpp_ita_function(Path, Chain, '$dtor', [], [], false, Name), _, fail), !.
cpp_dtor_name(C, _, Name) :- atomic_list_concat([C, '.dtor.0'], Name).
%% a header's items: its templates registered, its classes registered AND emitted into the unit (once), as an instance is
%% (a library header's summary carries names, not bodies: libc++'s templates do not instantiate yet)
cpp_register_header([]).
cpp_register_header([declare(L, base(_, [class(K, C0, Bases, Ms)]))|Is]) :- cpp_class_item_name(C0, C), !,
    (   cpp_class_l(C, _) -> true
    ;   cpp_class_encloses(C0, C),
        cpp_hdr_pre_apart(C, cpp_isolated(( cpp_register_class(K, L, C, Bases, Ms), cpp_item(declare(L, base([], [class(K, C, Bases, Ms)])), Items) ))), cpp_add_instance_items(Items) ),
    cpp_register_header(Is).
cpp_register_header([namespace(_, _, Js)|Is]) :- !, cpp_register_header(Js), cpp_register_header(Is).
cpp_register_header([declare(L, base(Q, [struct(N, Ms)]))|Is]) :- atom(N), Ms \== none, \+ '$cpp_promoted'(N), \+ cpp_class_l(N, _), cpp_struct_promotes(N, Ms), !,   % a header's plain struct promoted (cpp_struct_promotes): emitted with the header's classes
    assertz('$cpp_promoted'(N)), cpp_trace(promoted(N)), cpp_register_header([declare(L, base(Q, [class(struct, N, [], Ms)]))|Is]).
cpp_register_header([I|Is]) :- cpp_note_fns([I]), cpp_register_([I]), cpp_register_header(Is).
%% A HEADER CLASS'S STATIC MEMBERS ARE INITIALIZED AT THE CLASS'S PLACE among the header's variables (0.192), as clang
%% orders a unit's inline variables by their definitions: the class is emitted at its registration, and the guarded
%% initializations its emission adds are set apart, `'$cpp_hdr_pre'(C, Ss)', until cpp_header_fns meets the class
cpp_hdr_pre_apart(C, G) :- nb_getval('$cpp_ginit_pre', P0), nb_setval('$cpp_ginit_pre', []),
    (   catch(G, E, ( nb_setval('$cpp_ginit_pre', P0), throw(E) ))
    ->  nb_getval('$cpp_ginit_pre', Ps), nb_setval('$cpp_ginit_pre', P0), ( Ps == [] -> true ; assertz('$cpp_hdr_pre'(C, Ps)) )
    ;   nb_setval('$cpp_ginit_pre', P0), fail ).
%% a function the program's own header DEFINES (a body, no template): emitted with the header's classes, linkonce, once
%% -- an included unit's items are not the includer's, so an inline `int twelve() { return 12; }' was declared and never
%% defined, and the link named it
cpp_header_fns([]).
cpp_header_fns([namespace(_, _, Js)|Is]) :- !, cpp_header_fns(Js), cpp_header_fns(Is).
cpp_header_fns([declare(_, base(_, [S]))|Is]) :- ( S = class(_, C0, _, _), cpp_class_item_name(C0, C) ; S = struct(C, _), atom(C) ), retract('$cpp_hdr_pre'(C, Ps)), !,   % a class's static members at its place (cpp_hdr_pre_apart/2)
    cpp_ginit_pre_put(Ps), cpp_header_fns(Is).
cpp_header_fns([I|Is]) :- I = function(_, _, _, N, _, _, B), atom(N), B \== none, \+ '$cpp_hdrfn'(N), !,
    assertz('$cpp_hdrfn'(N)),
    ( cpp_isolated(cpp_item(I, Items)) -> cpp_add_instance_items(Items) ; cpp_trace(header_fn_not_emitted(N)) ),
    cpp_header_fns(Is).
cpp_header_fns([I|Is]) :- I = declaration(_, Sto, _, [var(N, T, _)|_]), Sto \== extern, T \= fn(_, _, _), \+ '$cpp_hdrfn'(var(N)), !,   % ... AND A VARIABLE IT DEFINES (0.192): an inline one linkonce, initialized and destroyed once (cpp_ginit_add/3), a const one the unit's own -- it was defined nowhere, and `inline Cnt gc(5);' in a header was an undefined symbol at the link
    assertz('$cpp_hdrfn'(var(N))),
    ( cpp_isolated(cpp_item(I, Items)) -> cpp_add_instance_items(Items) ; cpp_trace(header_var_not_emitted(N)) ),
    cpp_header_fns(Is).
cpp_header_fns([_|Is]) :- cpp_header_fns(Is).
cpp_ginit_pre_put(Ps) :- nb_getval('$cpp_ginit_pre', P0), append(P0, Ps, P1), nb_setval('$cpp_ginit_pre', P1).
