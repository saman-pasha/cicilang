%% ccl_cpp.pl -- M6's C++ forms desugared to the C the check and the lowering
%% have, before either runs (cicilang_ir calls ccl_cpp_units/2 in cpp mode).
%%
%% A class is a struct of its data members, its base (one) the first member,
%% '$base'; every method is a function over `this' (C.m.k, k the arity, an
%% operator by its word), a constructor `C.C.k' returning void, run at the
%% declaration of every local of the class (a '$splice' of the declaration,
%% the call, and -- when the class has a destructor -- a defer of `C.dtor.0'
%% over its address: the scope's exits run it, last declared first, as C++
%% has it); a static member is the global `C.N'; `new C(args)' constructs
%% into malloc's block and `delete p' destroys before free; a call `o.m(a)'
%% is `C.m.k(&o, a)' with the default arguments filled, `p->m(a)' passes p,
%% an unqualified `m(a)' inside a method passes this, `Counter(v)' builds a
%% temporary; `o += v', `o[i]', `a + b' go to the class's or a free operator.
%% Inside a method an unqualified data member is `this->n', an inherited one
%% through '$base'. The walk keeps the symbol table's scopes as the check
%% does, so ccl_type_of/2 tells a class-typed operand; the functions it makes
%% are declared as it goes, so their calls have types too.
%%
%% virtual, the third step: a polymorphic class carries `$vptr' (the first
%% member of the class that introduces it, after `$base' when it has one), a
%% pointer to a struct `C.vt' of function pointers, one per virtual method
%% in the order they were introduced (the base's first, an override in its
%% base's slot, `$dtor' for a virtual destructor); every class has its own
%% table, the global `C.vtable', filled with the most derived
%% implementations, and every constructor stores its address after the
%% base's constructor ran; a call through a pointer or a reference goes
%% `p->$vptr->m(p)', a call on a value straight to the function; `delete p'
%% destroys through the slot. Single inheritance puts the base at offset 0,
%% so `this' is never adjusted.
%%
%% Templates, the fourth step: instantiated on use, a copy of the item with
%% the parameters substituted (cpp_subst/3), named `N.key.key' by its
%% arguments (`Buf.int.4', `max2.double'); a class template at every
%% template-id type met by the walk (cpp_type/2, the hook every type goes
%% through), registered and desugared like a class written out; a function
%% template at a call, its type arguments explicit or deduced from the
%% arguments' types (cpp_match/5), declared and walked like a function
%% written out; the instances join the unit's items at its end, the
%% template item itself is nothing. The program's own headers, read whole,
%% give their templates and classes; a library header's summary has no
%% body to copy, and its template is refused: libc++'s containers await
%% the forms their bodies use (the standard library is libc++'s, never the
%% compiler's own -- the owner's rule).
%%
%% Lambdas, the fifth step: a lambda is a class `lambda.K' of its captures
%% -- a member per capture, by value a copy, by reference a reference
%% member (the lowering reads a reference member through, as a reference
%% variable) -- with `operator()' its body, made and desugared like a class
%% written out; the expression is a compound literal of the captures'
%% values (`&t' for a reference), `auto f = ...' takes its type, and a call
%% `f(a)' of a local of such a class goes to `lambda.K.op.call.n(&f, a)'.
%% A default capture takes every enclosing local the body names; the
%% result type is deduced from the first return when not given.
%%
%% Then, over classes of the program's own: overloads by type (a name
%% carries its parameters' types, a call picks by the arguments'), the rule
%% that a class with a destructor is never copied but moved (`std::move' is
%% Cicili's move, a struct moved whole empties its owners behind it, a
%% by-value argument hands its owners to the callee), the explicit
%% destructor call `x.~T()', and a member of class type constructed and
%% destroyed with its holder.
%%
%% Not this step (refused by name): more than one base, a member of class
%% type with a constructor, an array of a class, a global of a class with a
%% constructor, a temporary's destructor, operator= and copy constructors
%% (a struct copies), a pure virtual method, partial and explicit
%% specializations, a template's non-type argument deduced, `[this]' in a
%% lambda, a lambda in a template's body before its instantiation.
%%
%% THE PARTS (0.223): the desugaring is this file and sixteen others, each one or two regions of what was this one
%% file, its rules in their order, a predicate whole in one of them: _namespace, the program's namespaces and the
%% library's keyed names; _mangle, the Itanium mangler; _library, the library's functions and classes; _class, a
%% class's registration; _layout, its layout and tables; _overload, a call's candidates and their ranking; _virtual,
%% the tables and RTTI; _init, the initialization of globals, members and bases; _stmt, statements; _expr,
%% expressions and calls; _eval, the constant evaluator; _template, templates and instances; _deduce, deduction and
%% substitution; _traits; _lambda; _concept, concepts and the function's own name. One namespace: a part calls
%% another's predicates freely.
:- use_module(library(ccl_cpp_namespace)).
:- use_module(library(ccl_cpp_mangle)).
:- use_module(library(ccl_cpp_library)).
:- use_module(library(ccl_cpp_class)).
:- use_module(library(ccl_cpp_layout)).
:- use_module(library(ccl_cpp_overload)).
:- use_module(library(ccl_cpp_virtual)).
:- use_module(library(ccl_cpp_init)).
:- use_module(library(ccl_cpp_stmt)).
:- use_module(library(ccl_cpp_expr)).
:- use_module(library(ccl_cpp_eval)).
:- use_module(library(ccl_cpp_template)).
:- use_module(library(ccl_cpp_deduce)).
:- use_module(library(ccl_cpp_traits)).
:- use_module(library(ccl_cpp_lambda)).
:- use_module(library(ccl_cpp_concept)).

ccl_cpp_units(Units0, Units) :- cpp_ginit_reset, cpp_kind_clashes(Units0), cpp_error_attr_units(Units0, Units0a), cpp_alloc_units(Units0a, Units00), cpp_ns_resolve(Units00, Units1),
    catch(( cpp_register_units(Units1), cpp_units(Units1, Units) ), Err, ( cpp_kept_assert_failure, throw(Err) )), cpp_kept_assert_failure.
%% THE PROGRAM'S OWN FAILED STATIC ASSERTION IS ITS ERROR WHEREVER IT WAS ASKED (0.221; [dcl.pre]/10, [temp.inst]/3: a class template's
%% instance asserts as it is made, in no immediate context of a deduction): the failure is kept ('$cpp_assert_failed', the first one)
%% and reported once the units are desugared, or before a later error -- a probe that made the instance caught the throw, and the
%% program compiled. A library header's failure is reported only where its throw comes out: what this compiler instantiates beyond
%% what clang does is no error of the program's.
cpp_kept_assert_failure :- ( '$cpp_assert_failed'(Err, L) -> throw(error(Err, here(none, L))) ; true ).   % Err: static_assert_failed(Text), or static_assert_unfolded (0.257)
%% GCC'S `error("msg")' IN C++ NAMES ITS FUNCTION AS CLANG++ NAMES IT (1.6.44): the mark of a function's result,
%% `error_attr(M)' (ccl_error_attr_note/1, the reader), is `error_attr(M, S)' before the desugaring names the functions
%% otherwise, S the function's name after its namespaces and classes and before its parameters' types, `S::n(int)',
%% `q::h()', `g(int)' -- a free function's, a namespace's, a class's member's, a nested class's and an own header's --,
%% which the lowering's words take (ir_error_attr_call/1): clang++'s `call to 'S::n(int)' declared with 'error'
%% attribute: no n'. A call of one built, and met the link where nothing defined it
cpp_error_attr_units([], []).
cpp_error_attr_units([unit(Is)|Us], [unit(Js)|Vs]) :- !, cpp_ea_items(Is, '', Js), cpp_error_attr_units(Us, Vs).
cpp_error_attr_units([U|Us], [U|Vs]) :- cpp_error_attr_units(Us, Vs).
cpp_ea_items([], _, []).
cpp_ea_items([I|Is], P, [J|Js]) :- cpp_ea_item(I, P, J), cpp_ea_items(Is, P, Js).
cpp_ea_item(namespace(L, N, Is), P, namespace(L, N, Js)) :- is_list(Is), !, ( atom(N), N \== anon -> atomic_list_concat([P, N, '::'], P1) ; N = inline(N1), atom(N1) -> atomic_list_concat([P, N1, '::'], P1) ; atom_concat(P, '(anonymous namespace)::', P1) ), cpp_ea_items(Is, P1, Js).
cpp_ea_item(extern_c(X, Is), _, extern_c(X, Js)) :- is_list(Is), !, cpp_ea_items(Is, '$c', Js).   % C linkage: the symbol is the bare name
cpp_ea_item(include(L, K, file(F, X, unit(Is))), P, include(L, K, file(F, X, unit(Js)))) :- is_list(Is), !, cpp_ea_items(Is, P, Js).
cpp_ea_item(function(L, Sto, R, N, Ps, V, B), P, function(L, Sto, R1, N, Ps, V, B)) :- atom(N), cpp_ea_ret(R, P, N, Ps, V, '', R1), !.
cpp_ea_item(declaration(L, Sto, B, Vs), P, declaration(L, Sto, B1, Vs1)) :- is_list(Vs), !, cpp_ea_base(B, P, B1), cpp_ea_vars(Vs, P, Vs1).
cpp_ea_item(declare(L, B), P, declare(L, B1)) :- !, cpp_ea_base(B, P, B1).
cpp_ea_item(method(L, Qs, R, N, Ps, V, B), P, method(L, Qs, R1, N, Ps, V, B)) :- atom(N), ( memberchk(const, Qs) -> X = ' const' ; X = '' ), cpp_ea_ret(R, P, N, Ps, V, X, R1), !.
cpp_ea_item(nested(B), P, nested(B1)) :- !, cpp_ea_base(B, P, B1).   % a nested class, `A::B::z()'
cpp_ea_item(I, _, I).
cpp_ea_vars([], _, []).
cpp_ea_vars([var(N, fn(R, Ps, V), I)|Vs], P, [var(N, fn(R1, Ps, V), I)|Ws]) :- atom(N), cpp_ea_ret(R, P, N, Ps, V, '', R1), !, cpp_ea_vars(Vs, P, Ws).
cpp_ea_vars([X|Vs], P, [X|Ws]) :- cpp_ea_vars(Vs, P, Ws).
cpp_ea_base(base(Q, [class(K, Tag, Bs, Ms)]), P, base(Q, [class(K, Tag, Bs, Ms1)])) :- atom(Tag), is_list(Ms), !, atomic_list_concat([P, Tag, '::'], P1), cpp_ea_items(Ms, P1, Ms1).
cpp_ea_base(B, _, B).
cpp_ea_ret(base(Q, S), P, N, Ps, V, X, base([error_attr(M, Sp)|Q0], S)) :- is_list(Q), select(error_attr(M), Q, Q0), !,
    ( P == '$c' -> Sp = N ; cpp_ea_params(Ps, V, A), atomic_list_concat([P, N, '(', A, ')', X], Sp) ).
%% ... CLANG++'S SPELLING IS ITS SYMBOL'S, DEMANGLED (its back end names the callee by llvm::demangle): each parameter's type
%% resolved, a top-level qualifier off, a pointee's and a referent's qualifiers after it, `char const*', `S const&',
%% `int&&', a pointer to a function `int (*)(int)', `size_t' as `unsigned long', an ellipsis after them, and a const member's
%% ` const'; a function of C linkage, an `extern "C"' block's, its bare name. A class's name is its tag, where the symbol
%% names its namespace too, and a library class is `?', where the symbol names its template's instance (Not done)
cpp_ea_params(Ps, V, A) :- findall(T, ( member(Pa, Ps), compound(Pa), arg(1, Pa, PT), cpp_ea_type(PT, T) ), Ts0),
    ( ck_c_variadic(V) -> append(Ts0, ['...'], Ts) ; Ts = Ts0 ), atomic_list_concat(Ts, ', ', A).
cpp_ea_type(T, S) :- catch(once(cpp_ea_dm(T, S0)), _, fail), atom(S0), !, S = S0.
cpp_ea_type(_, '?').
cpp_ea_dm(T0, S) :- cpp_ea_res(T0, T), cpp_ea_dm_(T, S).
cpp_ea_res(T0, T) :- ( catch(once(ccl_resolve_type(T0, T1)), _, fail) -> T = T1 ; T = T0 ).
cpp_ea_dm_(ref(_, X), S) :- !, cpp_ea_cv(X, S0), atom_concat(S0, '&', S).
cpp_ea_dm_(rref(_, X), S) :- !, cpp_ea_cv(X, S0), atom_concat(S0, '&&', S).
cpp_ea_dm_(ptr(_, X), S) :- !, cpp_ea_ptr(X, S).
cpp_ea_dm_(arr(_, X), S) :- !, cpp_ea_ptr(X, S).
cpp_ea_dm_(base(_, Sp), S) :- cpp_ea_base_text(Sp, S).
cpp_ea_ptr(X0, S) :- cpp_ea_res(X0, X), ( X = fn(R, Ps, V) -> cpp_ea_dm(R, RS), cpp_ea_params(Ps, V, PS), atomic_list_concat([RS, ' (*)(', PS, ')'], S) ; cpp_ea_cv(X, S0), atom_concat(S0, '*', S) ).
cpp_ea_cv(X0, S) :- cpp_ea_res(X0, X), ( X = base(Q, Sp) -> cpp_ea_base_text(Sp, S0), cpp_ea_quals(Q, S0, S) ; X = ptr(Q, Y) -> cpp_ea_ptr(Y, S0), cpp_ea_quals(Q, S0, S) ; cpp_ea_dm_(X, S) ).
cpp_ea_quals(Q, S0, S) :- ( memberchk(const, Q) -> atom_concat(S0, ' const', S1) ; S1 = S0 ), ( memberchk(volatile, Q) -> atom_concat(S1, ' volatile', S) ; S = S1 ).
cpp_ea_base_text(Sp, S) :- member(X, Sp), compound(X), ( X = struct(Tag, _) ; X = union(Tag, _) ; X = class(_, Tag, _, _) ; X = enum(Tag, _) ; X = enum_class(Tag, _) ), atom(Tag), !, S = Tag.
cpp_ea_base_text(Sp, S) :- ir_type_text(base([], Sp), S0), atom(S0), S = S0.
%% A NAME OF THE FILE SCOPE DECLARED AGAIN AS ANOTHER KIND OF SYMBOL (1.6.24; [basic.scope.declarative]/4, [dcl.typedef]):
%% an object and a function of one name, a typedef's name and either, an enumerator and either, among the program's own
%% items of the global scope and of its `extern "C"' blocks, are clang++'s `redefinition of 't' as different kind of
%% symbol' at the later one's line, where they were built -- `int t(void); int t;' -- or refused in LLVM's words. A
%% function's overloads are one kind, a class's or an enumeration's tag no name of these, and a namespace's names are
%% its own scope's; C's file scope is the reader's (ccl_kind_clash/2)
cpp_kind_clashes([]).
cpp_kind_clashes([unit(Is0)|Us]) :- !, nb_setval('$cpp_kind_file', none), cpp_live_units(Is0, Is), cpp_kind_walk(Is, [], _), cpp_redef_walk(Is, [], _), cpp_kind_clashes(Us).
cpp_kind_clashes([_|Us]) :- cpp_kind_clashes(Us).
cpp_kind_walk([], K, K).
cpp_kind_walk([extern_c(_, Js)|Is], K0, K) :- !, cpp_kind_walk(Js, K0, K1), cpp_kind_walk(Is, K1, K).
cpp_kind_walk(['$live_header'(P, Js)|Is], K0, K) :- !, cpp_kind_in(P, cpp_kind_walk(Js, K0, K1)), cpp_kind_walk(Is, K1, K).   % THE PROGRAM'S OWN HEADER AS THE RUN KEPT IT (1.6.42), below

cpp_kind_walk([namespace(_, Nm, Js)|Is], K0, K) :- atom(Nm), is_list(Js), !, cpp_kind_walk_ns([Nm], Js, K0, K1), cpp_kind_walk(Is, K1, K).   % A NAMESPACE'S ITEMS (1.6.28), its blocks one scope
cpp_kind_walk([I|Is], K0, K) :- findall(N-Kd-L, cpp_item_kind(I, N, Kd, L), NKs), cpp_kind_note(NKs, K0, K1), cpp_kind_walk(Is, K1, K).
cpp_item_kind(function(L, _, _, N, _, _, _), N, fn, L) :- atom(N).
cpp_item_kind(template(_, _, function(L, _, _, N, _, _, _)), N, fn, L) :- atom(N).
cpp_item_kind(declaration(L, _, B, Vs), N, Kd, L) :- ( member(var(N, T, _), Vs), atom(N), ( T = fn(_, _, _) -> Kd = fn ; Kd = obj ) ; cpp_base_enumerator(B, N), Kd = enumerator ).
cpp_item_kind(declare(L, B), N, enumerator, L) :- cpp_base_enumerator(B, N).
cpp_item_kind(typedef(L, Vs), N, type, L) :- member(var(N, _, _), Vs), atom(N).
cpp_base_enumerator(base(_, [enum(_, Es)]), N) :- is_list(Es), member(enumerator(N, _), Es), atom(N).
%% ... A HEADER AS THE FILE'S RUN KEPT IT IS WALKED WHERE IT STANDS (1.6.42), and a clash in it is refused at the header's
%% line, the header named as the `#include' found it (`'$cpp_kind_file'', which the driver reads through `'$ir_fail_file'',
%% dr_where_file/3), as clang++ names it: `int f(int); int f;' in the header, and `int t;' in the file before an `#include'
%% whose `int t(void);' clashes, are `./h.h:2:5: error: redefinition of 'f' as different kind of symbol', and a header's
%% second definition of a function, or one beside the file's, `redefinition of 'f''. They built, the header's first
%% function called, or met LLVM's `invalid redefinition of function'. The reader reads a header of the program's own at
%% each `#include', raw, so that a guarded header's second inclusion, a `#pragma once' one's and both arms of its
%% conditionals stand among the unit's items: the run of the file records the lines that it keeps of each, as C's does
%% (pp_live_end/1, ccl_live_top/2, `'$cpp_live''), and the walks take a header's item only where a range holds its line
%% (ccl_redef_live/2), an `extern "C"' block's too. A header that the run did not run (ccl_redef_entry/5) -- a macro file's C
%% header, which the reader includes -- is no text of the program's, as in C, and where the run left no record a header
%% is not walked. Through 1.6.41 a header was noted before the items after it with no refusal of its own (1.6.28,
%% cpp_kind_seed/3), each name keeping its first kind (1.6.32), which cpp_kind_note/3 keeps now
cpp_kind_in(P, G) :- nb_getval('$cpp_kind_file', P0), nb_setval('$cpp_kind_file', P), call(G), nb_setval('$cpp_kind_file', P0).
cpp_live_units(Is0, Is) :- ( nb_current('$cpp_live', Es), Es \== none -> cpp_live_items(Is0, all, Es, _, Is) ; Is = Is0 ).
cpp_live_items([], _, Es, Es, []).
cpp_live_items([I|Is], Live, Es0, Es, Out) :- cpp_live_item(I, Live, Es0, Es1, Out, Out1), cpp_live_items(Is, Live, Es1, Es, Out1).
cpp_live_item(I, Live, Es0, Es, Out, Out1) :- I = include(L, local(_), file(P, _, unit(Js))), atom(P), \+ cpp_system_path(P), !,
    (   ccl_redef_live(Live, L), ccl_redef_entry(Es0, P, L, Rs, Es1) -> cpp_live_items(Js, Rs, Es1, Es, Js1), Out = ['$live_header'(P, Js1)|Out1]
    ;   Es = Es0, Out = Out1 ).   % one that the run did not run, a macro file's C header, is no text of the program's
cpp_live_item(extern_c(X, Js), Live, Es0, Es, [extern_c(X, Js1)|Out1], Out1) :- is_list(Js), !, cpp_live_items(Js, Live, Es0, Es, Js1).
cpp_live_item(I, Live, Es, Es, Out, Out1) :- ( compound(I), functor(I, F, _), memberchk(F, [function, declaration, declare, typedef]), arg(1, I, L), \+ cpp_live_at(Live, L) -> Out = Out1 ; Out = [I|Out1] ).
cpp_live_at(Live, L) :- ( integer(L) -> ccl_redef_live(Live, L) ; true ).
%% ... AND A NAMESPACE'S, ITS BLOCKS ONE SCOPE (1.6.28; [namespace.def]/2: a namespace's later blocks extend it): each name
%% keyed by its namespace, `ns([n], t)', and refused by its own name, `int t();' in one block of n and `int t;' in another
%% as in one, which built; a nested namespace is its own scope
cpp_kind_walk_ns(_, [], K, K).
cpp_kind_walk_ns(P, [namespace(_, Nm, Js)|Is], K0, K) :- atom(Nm), is_list(Js), !, append(P, [Nm], P1), cpp_kind_walk_ns(P1, Js, K0, K1), cpp_kind_walk_ns(P, Is, K1, K).
cpp_kind_walk_ns(P, [extern_c(_, Js)|Is], K0, K) :- !, cpp_kind_walk_ns(P, Js, K0, K1), cpp_kind_walk_ns(P, Is, K1, K).
cpp_kind_walk_ns(P, [I|Is], K0, K) :- findall(ns(P, N)-Kd-L, cpp_item_kind(I, N, Kd, L), NKs), cpp_kind_note(NKs, K0, K1), cpp_kind_walk_ns(P, Is, K1, K).
cpp_kind_note([], K, K).
cpp_kind_note([N-Kd-L|T], K0, K) :- ( memberchk(N-Kd0, K0), Kd0 \== Kd -> ( N = ns(_, N1) -> true ; N1 = N ), cpp_redef_throw(kind_redefinition(N1), L) ; true ),   % before the desugaring's state: no trace to note it in
    ( memberchk(N-_, K0) -> K1 = K0 ; K1 = [N-Kd|K0] ), cpp_kind_note(T, K1, K).
%% ... AND A SECOND DEFINITION (1.6.24; [basic.def.odr]/1: no translation unit holds two definitions of a variable, a
%% function, a class or an enumeration), in clang++'s words, `redefinition of 'f'': a function of one name and one list of
%% parameter types, each its adjusted type ([dcl.fct]/5: an array a pointer, a function a pointer, a top-level qualifier
%% off), its typedefs resolved; an object defined twice -- an object with no `extern' is a definition in C++ --, and one
%% declared again with another type, C's words (ccl_redef_obj_compat/2); a class, a union or an enumeration with two
%% bodies. Each was LLVM's `invalid redefinition of function', or built with the first. An instance's function is passed
%% over (`linkonce'), and a type that does not resolve leaves its function out
cpp_redef_walk([], S, S).
cpp_redef_walk([extern_c(_, Js)|Is], S0, S) :- !, cpp_redef_walk(Js, S0, S1), cpp_redef_walk(Is, S1, S).
cpp_redef_walk([namespace(_, _, Js)|Is], S0, S) :- is_list(Js), !, cpp_const_walk(Js), cpp_redef_walk(Is, S0, S).   % a namespace's const objects (1.6.43), below
cpp_redef_walk(['$live_header'(P, Js)|Is], S0, S) :- !, cpp_kind_in(P, cpp_redef_walk(Js, S0, S1)), cpp_redef_walk(Is, S1, S).   % the program's own header as the run kept it (1.6.42)
cpp_redef_walk([I|Is], S0, S) :- ( cpp_redef_item(I, S0, S1) -> true ; S1 = S0 ), cpp_redef_walk(Is, S1, S).
cpp_redef_item(function(L, Sto, _, N, Ps, V, block(_)), S0, [fn(N, Sig)|S0]) :- atom(N), Sto \== linkonce, catch(cpp_redef_sig(Ps, V, Sig), _, fail),
    ( memberchk(fn(N, Sig), S0) -> cpp_redef_throw(redefinition(N), L) ; true ).
cpp_redef_item(declare(L, B), S0, S) :- cpp_redef_tags(B, L, S0, S).
cpp_redef_item(declaration(L, Sto, B, Vs), S0, S) :- Sto \== typedef, Sto \== linkonce, cpp_const_defaults(B, Sto, L, Vs), cpp_redef_tags(B, L, S0, S1), cpp_redef_vars(Vs, Sto, L, S1, S).
cpp_redef_tags(base(_, Specs), L, S0, S) :- ( member(Sp, Specs), cpp_redef_tag_def(Sp, Tag) -> ( memberchk(tag(Tag), S0) -> cpp_redef_throw(redefinition(Tag), L) ; S = [tag(Tag)|S0] ) ; S = S0 ).
cpp_redef_tag_def(struct(Tag, Ms), Tag) :- atom(Tag), Tag \== anon, is_list(Ms).
cpp_redef_tag_def(union(Tag, Ms), Tag) :- atom(Tag), Tag \== anon, is_list(Ms).
cpp_redef_tag_def(class(_, Tag, _, Ms), Tag) :- atom(Tag), Tag \== anon, is_list(Ms).
cpp_redef_tag_def(enum(Tag, Es), Tag) :- atom(Tag), Tag \== anon, is_list(Es).
cpp_redef_tag_def(enum_class(Tag, Es), Tag) :- atom(Tag), is_list(Es).
cpp_redef_vars([], _, _, S, S).
cpp_redef_vars([var(N, T, Init)|Vs], Sto, L, S0, S) :- atom(N), \+ ccl_redef_fn_type(T), !, ( Init == none, Sto == extern -> D = decl ; D = def ),
    (   memberchk(ob(N, T0, D0), S0)
    ->  (   \+ ccl_redef_obj_compat(T0, T) -> ( D == decl -> K = redeclaration ; K = redefinition ), ccl_redef_words(T, A), ccl_redef_words(T0, B0), cpp_redef_throw(redef_type(K, N, A, B0), L)
        ;   D == def, D0 == def -> cpp_redef_throw(redefinition(N), L)
        ;   true )
    ;   true ),
    cpp_redef_vars(Vs, Sto, L, [ob(N, T, D)|S0], S).
cpp_redef_vars([_|Vs], Sto, L, S0, S) :- cpp_redef_vars(Vs, Sto, L, S0, S).
%% A CONST OBJECT WITH NO INITIALIZER IS DEFAULT-INITIALIZED, WHICH A CONST SCALAR IS NOT (1.6.43; [dcl.init.general]/7: a
%% const object of a type that is no class is not default-initialized): an object of the file, of a namespace or of a
%% block, static or not, whose type is a const scalar, a const pointer, a const enumeration or an array of them, and that
%% no `extern' declares, is clang++'s `default initialization of an object of const type 'const int[3]'', at its line; a
%% file's `const int T[3];' was refused as a second definition where its rows came after it, `int *const p;' built a null
%% pointer, and a block's `const int x;' built. A `constexpr' one of such a type is `constexpr variable 'x' must be
%% initialized by a constant expression' (the declaration's base holds the word); one of a class is its constexpr default
%% constructor's, `constexpr OptBool none;' (1.6.45: 1.6.43 refused it, and the C++ gate's within.cpp and
%% itaniumlayout.cpp with it). A class's object asks a user-provided default constructor (Not done)
cpp_const_defaults(B, Sto, L, Vs) :- ( Sto \== extern, member(var(N, T, none), Vs), atom(N), cpp_const_default(B, N, T, W) -> cpp_redef_throw(W, L) ; true ).
cpp_const_default(B, N, T0, W) :- nonvar(T0), catch(once(ccl_resolve_type(T0, R)), _, fail), cpp_const_scalar(R),
    ( nonvar(B), B = base(QB, _), is_list(QB), memberchk(constexpr, QB) -> W = constexpr_uninit(N) ; catch(ir_type_aka(T0, A), _, fail), W = default_const_init(A) ).
cpp_const_scalar(arr(_, E)) :- !, catch(once(ccl_resolve_type(E, R)), _, fail), cpp_const_scalar(R).
cpp_const_scalar(ptr(Q, _)) :- !, memberchk(const, Q).
cpp_const_scalar(base(Q, S)) :- memberchk(const, Q), ( ccl_is_integer(base([], S)) -> true ; ccl_is_float(base([], S)) -> true ; memberchk(nullptr_t, S) ).
%% ... a namespace's, its nested namespaces' and its `extern "C"' blocks' among them
cpp_const_walk([]).
cpp_const_walk([I|Is]) :- ( I = namespace(_, _, Js), is_list(Js) -> cpp_const_walk(Js) ; I = extern_c(_, Js), is_list(Js) -> cpp_const_walk(Js)
    ; I = declaration(L, Sto, B, Vs), Sto \== typedef, Sto \== linkonce -> cpp_const_defaults(B, Sto, L, Vs) ; true ), cpp_const_walk(Is).
cpp_redef_throw(W, L) :- ( nb_current('$cpp_kind_file', P), atom(P), P \== none -> nb_setval('$ir_fail_file', P) ; true ), throw(error(not_lowered(W), where(file, line(L)))).   % a line of the program's own header is named by its file (1.6.42)
%% a function's parameter types as they make its type: adjusted, then each level's typedefs resolved and its qualifiers
%% sorted; a variadic one apart
cpp_redef_sig(Ps, V, sig(Ks, Va)) :- findall(K, ( member(P, Ps), arg(1, P, T), cpp_redef_ptype(T, K) ), Ks), length(Ps, N), length(Ks, N), ( ck_c_variadic(V) -> Va = yes ; Va = no ).
cpp_redef_ptype(T, K) :- ccl_resolve_type(T, R), ( R = arr(_, X) -> R1 = ptr([], X) ; R = fn(_, _, _) -> R1 = ptr([], R) ; R = base(Q, Sp) -> subtract(Q, [const, volatile], Q1), R1 = base(Q1, Sp) ; R = ptr(_, X) -> R1 = ptr([], X) ; R1 = R ), cpp_redef_deep(R1, K).
cpp_redef_deep(T, K) :- ccl_resolve_type(T, R), cpp_redef_deep_(R, K).
cpp_redef_deep_(base(Q, Sp), K) :- !, ccl_type_canon(base(Q, Sp), K).
cpp_redef_deep_(ptr(Q, X), ptr(Q1, K)) :- !, msort(Q, Q1), cpp_redef_deep(X, K).
cpp_redef_deep_(ref(_, X), ref(K)) :- !, cpp_redef_deep(X, K).
cpp_redef_deep_(rref(_, X), rref(K)) :- !, cpp_redef_deep(X, K).
cpp_redef_deep_(arr(N, X), arr(N, K)) :- !, cpp_redef_deep(X, K).
cpp_redef_deep_(fn(R, Ps, V), fn(RK, Ks, Va)) :- !, cpp_redef_deep(R, RK), cpp_redef_sig(Ps, V, sig(Ks, Va)).
cpp_redef_deep_(T, T).
%% the unit's initialization lists, empty before anything registers (0.192): the registration emits the program's own
%% headers' classes and variables, whose statics' initializations and destructors join the first unit's lists
cpp_ginit_reset :- nb_setval('$cpp_ginit', []), nb_setval('$cpp_ginit_pre', []), nb_setval('$cpp_ginit_fns', []).
cpp_units([], []).
cpp_units([unit(Is0)|Us0], [unit(Is)|Us]) :- nb_setval('$cpp_relops', none), nb_setval('$cpp_cplxlit', none), nb_setval('$cpp_usings', []), nb_setval('$cpp_using_skip', []),cpp_items(Is0, Is1a), cpp_ginit_items(Is1a, Is1), cpp_flush_instances(Is1, Is2), cpp_name_anon_items(Is2, Is), cpp_units(Us0, Us).
%% the instances made while the unit was walked join its items; walking them may make more
cpp_flush_instances(Is0, Is) :-
    findall(I, '$cpp_out'(_, I), New0), cpp_drop_evonly(Is0, New0, New),
    ( New0 == [] -> Is = Is0 ; cpp_reset('$cpp_out'/2), append(Is0, New, Is1), cpp_flush_instances(Is1, Is) ).
%% AN INSTANCE THE EVALUATOR ALONE MADE IS NO ITEM WHERE NOTHING NAMES IT (0.258, cpp_eval_only/1): the functions marked '$cpp_evonly'
%% are kept where an item of the unit or a kept one names them (`id(Name)' anywhere in it), the rest dropped and their instance notes
%% with them, so that a later use makes them again. Nothing is walked where nothing is marked
cpp_drop_evonly(_, New, New) :- \+ catch('$cpp_evonly'(_), _, fail), !.
cpp_drop_evonly(Is0, New, Kept) :- cpp_reset('$cpp_ref'/1),
    findall(K-I, ( member(I, New), I = function(_, _, _, K, _, _, _), '$cpp_evonly'(K), '$cpp_inst'(K, _) ), Ev),   % an instance a later use makes again
    forall(( member(I, Is0) ; member(I, New), \+ ( I = function(_, _, _, K, _, _, _), memberchk(K-_, Ev) ) ), cpp_note_refs(I)),
    cpp_evonly_live(Ev, Live),
    findall(I, ( member(I, New), \+ ( I = function(_, _, _, K, _, _, _), memberchk(K-_, Ev), \+ memberchk(K, Live) ) ), Kept),
    forall(( member(K-_, Ev), \+ memberchk(K, Live) ), retractall('$cpp_inst'(K, _))), cpp_reset('$cpp_evonly'/1), cpp_reset('$cpp_ref'/1).
cpp_evonly_live(Ev, Live) :- ( select(K-I, Ev, Ev1), '$cpp_ref'(K) -> cpp_note_refs(I), cpp_evonly_live(Ev1, Live1), Live = [K|Live1] ; Live = [] ).
cpp_note_refs(T) :- ( T = id(N) -> ( atom(N), \+ '$cpp_ref'(N) -> assertz('$cpp_ref'(N)) ; true ) ; compound(T) -> T =.. [_|As], cpp_note_refs_list(As) ; true ).
cpp_note_refs_list([]).
cpp_note_refs_list([A|As]) :- cpp_note_refs(A), cpp_note_refs_list(As).
%% the registries that hold class and template BODIES are facts, one row per name: a global list would be copied
%% whole at every lookup (nb_getval copies), and libc++'s bodies are megabytes (the finding in RULES.md)
cpp_reset(F/A) :- ( catch(abolish(F/A), _, true) -> true ; true ), dynamic(F/A).
cpp_class_put(C, Cls) :- assertz('$cpp_cls'(C, Cls)), ( Cls = cls(B, Data, Ms, Ss, Df, Sl) -> assertz('$cpp_clsl'(C, cls(B, Data, Ss, Df, Sl))), cpp_note_static_fns(C, Ms), cpp_note_decls(Ms, C), cpp_note_alloc_fns(C, Ms) ; true ).
%% THE LIGHT RECORD (0.119): a class's record is `cls(Base, Data, Members, Statics, Defaults, Slots)' and the members are 97% of it -- every
%% method with its body -- so a lookup that wanted only the base copied the class: cpp_base_scope alone asked 44,764 times in a std::vector
%% build, 2.6 seconds of its 9.6 for the copies. `cpp_class_l/2' answers the record WITHOUT the members, `cls(Base, Data, Statics, Defaults,
%% Slots)', from a fact of its own that cpp_class_put writes beside the full one (a hundredth of the size); a class that is not registered yet
%% is asked of cpp_class/2, which loads it, and the light fact is there after. Every caller whose members field was `_' asks this.
%% THE STATIC FUNCTIONS OF A CLASS BY NAME (0.126): `'$cpp_sfn'(Class, Name)', one fact per static method name, written beside the light
%% record, so that a bare name met in a member's body asks one fact of its class (and its bases') before it asks the members, which the
%% full record holds -- the identifier road runs for every name that nothing else claims, and a copy of a class per name was the cost
%% 0.120 took out. cpp_static_fn_value/3 reads it.
cpp_note_static_fns(C, Ms) :- findall(N, ( member(method(_, Qs, _, N, _, _, _), Ms), memberchk(static, Qs), atom(N) ), Ns0), sort(Ns0, Ns), cpp_note_static_fns_(Ns, C).
cpp_note_static_fns_([], _).
cpp_note_static_fns_([N|Ns], C) :- assertz('$cpp_sfn'(C, N)), cpp_note_static_fns_(Ns, C).
%% A CLASS'S OWN ALLOCATION AND DEALLOCATION FUNCTIONS BY KIND (0.202): `'$cpp_alloc_m'(Class, Op)', one fact per kind it declares, written
%% beside the light record, so that a new-expression and a delete-expression ask a fact of the class and its bases (cpp_alloc_owner/3)
cpp_note_alloc_fns(C, Ms) :- forall(( cpp_alloc_op(Op), once(( member(M, Ms), cpp_member_named(M, operator(Op)) )), \+ '$cpp_alloc_m'(C, Op) ), assertz('$cpp_alloc_m'(C, Op))).
%% THE MEMBERS A CLASS ONLY DECLARES (0.153): `'$cpp_decl'(Class, ctor | method(Name), Qualifiers, Parameters)', one fact per
%% constructor and method whose body is `none', in the order the class declares them, written beside the light record.
%% cpp_shipped_member/5 asks them of every member the mangler names -- does the shipped library define it? -- and it copied the
%% class's whole record to walk its members, nearly always to answer no: 16 % of four library builds' CPU time (0.152's time
%% view, its finding timed over the whole builds). A fact is found by its class and copies only the declaration it answers.
cpp_note_decls([], _).
cpp_note_decls([M|Ms], C) :- ( cpp_decl_row(M, What, Qs, Ps) -> assertz('$cpp_decl'(C, What, Qs, Ps)) ; true ), cpp_note_decls(Ms, C).
cpp_decl_row(ctor(_, Qs, Ps, _, B), ctor, Qs, Ps) :- \+ B \= none.
cpp_decl_row(method(_, Qs, _, N, Ps, _, B), method(N), Qs, Ps) :- \+ B \= none.
cpp_class_l(C, L) :- '$cpp_clsl'(C, L), !.
cpp_class_l(C, L) :- cpp_class(C, _), '$cpp_clsl'(C, L), !.
%% SEVEN REGISTRIES THAT WERE LISTS IN A GLOBAL ARE FACTS (0.119): nb_getval/2 copies what it answers, so every lookup copied the whole registry --
%% the class typedefs 38,777 times in a std::vector build (1.5 of its 9.6 seconds), and the heap those copies left behind is what
%% a nested engine does not collect. A fact is found by its first argument (a class, a name) and copies only what it answers. They are
%% written NEWEST FIRST (asserta), as the lists were, and a lookup takes the first match (the cut), as memberchk/2 did.
%%   '$cpp_ctype'(Class, Name, Type)    a class's typedef                  '$cpp_encl'(Nested, Enclosing)   the class a nested class or closure is in
%%   '$cpp_sinit'(Class, Name, Init)    a static data member's initializer  '$cpp_lazy_c'(Class)             a lazy library class
%%   '$cpp_dtor_def'(Class)             a destructor defined out of its class   '$cpp_cname'(Name)           a name that keeps its C linkage
%%   '$cpp_dflt'(Name, Defaults)        the default arguments of a function
cpp_ctype_put(C, N, T) :- asserta('$cpp_ctype'(C, N, T)).
cpp_enclosing(C, E) :- '$cpp_encl'(C, E), !.
cpp_sinit(C, N, E) :- '$cpp_sinit'(C, N, E), !.
cpp_dtor_def(C) :- '$cpp_dtor_def'(C), !.
cpp_template_put(N, TPs0, Item) :- cpp_name_anon(TPs0, TPs), assertz('$cpp_tmpl'(N, TPs, Item)), cpp_tmpl_kind(Item, K), cpp_tmpl_tags(K, Item, Tags),
    assertz('$cpp_tmplh'(N, TPs, K, Tags)), cpp_note_own_tmpl(N, Item).
%% the program's own function template, by its line and its body, which the merge of its defaults leaves as they are (0.221, cpp_libq_cands/3)
cpp_note_own_tmpl(N, Item) :- ( nb_current('$cpp_in_lib', no), cpp_fn_item(Item, function(L, _, _, _, _, _, Body)) -> assertz('$cpp_own_tmplfn'(N, L, Body)) ; true ).
%% THE LIGHT TEMPLATE RECORD (0.241): `'$cpp_tmplh'(Name, Params, Kind, Tags)', one beside each `'$cpp_tmpl'/3' clause and in its order --
%% Kind `class_def' (cpp_template_class_def/1), `defined' (cpp_template_defined/1, a class's definition aside) or `other', Tags `tags(Ts)'
%% where a class's definition holds `abi_tag(Ts)' among its members, else `none'. A question of a name's templates that wants no item asks
%% the light record: a call of a fact COPIES what it answers, and a class template's item is its whole body (libc++ 18's `basic_string',
%% 81 KB, registered three times in a build of `stdstringstream.cpp' from three summaries), so the class template's lookup, which asked for
%% the items of the name's every clause to choose one and to merge the defaults of the others' parameters, and the mangler, which asked
%% for an item to read its parameters or its tags, copied the bodies at each ask
cpp_tmpl_kind(Item, K) :- ( cpp_template_class_def(Item) -> K = class_def ; cpp_template_defined(Item) -> K = defined ; K = other ).
cpp_tmpl_tags(class_def, declare(_, base(_, [S])), tags(Ts)) :- ( S = class(_, _, _, Ms) ; S = struct(_, Ms) ; S = union(_, Ms) ), is_list(Ms), memberchk(abi_tag(Ts), Ms), !.
cpp_tmpl_tags(_, _, none).
cpp_spec_put(N, TPs0, Pat, Item) :- cpp_name_anon(TPs0, TPs), assertz('$cpp_spec'(N, TPs, Pat, Item)).
cpp_mt_put(C, K, TPs0, M) :- cpp_name_anon(TPs0, TPs), assertz('$cpp_mt'(C, K, TPs, M)).
%% AN UNNAMED TEMPLATE PARAMETER IS NAMED BY ITS POSITION at the three registration doors (`$anon1', `$anon2' ...),
%% so it binds and keys as any other: libc++ forward-declares `template <size_t, class> struct tuple_element;'
%% with NEITHER named, and two bindings of one name `anon' answered the first to both, keying
%% tuple_element<0, tuple<int &&>> as `tuple_element.tuple.int_rr.tuple.int_rr' -- an instance whose specialization
%% then read `_Tp...' as the tuple itself and asked __type_pack_element for the tuple's element `tuple<int &&>'
cpp_name_anon(TPs0, TPs) :- cpp_name_anon_(TPs0, 1, TPs).
cpp_name_anon_([], _, []).
cpp_name_anon_([tparam(K, anon, D)|Ps], I, [tparam(K, P, D)|Qs]) :- !, atom_concat('$anon', I, P), I1 is I + 1, cpp_name_anon_(Ps, I1, Qs).
cpp_name_anon_([P|Ps], I, [P|Qs]) :- I1 is I + 1, cpp_name_anon_(Ps, I1, Qs).
cpp_instance_done(Name) :- '$cpp_inst'(Name, _), !.
cpp_instance_note(Name, What) :- assertz('$cpp_inst'(Name, What)).

%% ---- the classes of the units: '$cpp_classes' = [C-cls(Base, Data, Members, Statics, Defaults) ...] --------
cpp_register_units(Units) :-
    cpp_reset('$cpp_assert_failed'/2),
    cpp_reset('$cpp_nce'/1), cpp_reset('$cpp_encl_consts'/2), cpp_reset('$cpp_evonly'/1), cpp_reset('$cpp_ref'/1),   % the program's functions that are not constexpr, which a constant evaluation does not call (0.258, cpp_note_nce/4); a closure's enclosing constants (0.258)
    cpp_reset('$cpp_fn_del'/3), cpp_reset('$cpp_mem_del'/5), cpp_reset('$cpp_op_del'/3),   % the deleted functions, members and operators (0.257); a deleted template is a candidate (0.258, cpp_deleted_fn_item/2)
    cpp_reset('$cpp_vtab'/3), cpp_reset('$cpp_shipped_def'/4), cpp_reset('$cpp_shipped_name'/4),   % the tables' slots and the shipped members' definitions, for the constant evaluator (0.257)
    cpp_reset('$cpp_cls'/2), cpp_reset('$cpp_clsl'/2), cpp_reset('$cpp_sfn'/2), cpp_reset('$cpp_alloc_m'/2), cpp_reset('$cpp_sfn_pre'/2), cpp_reset('$cpp_decl'/4), cpp_reset('$cpp_sfold'/3), cpp_reset('$cpp_nenum'/1), cpp_reset('$cpp_enumv'/3), cpp_reset('$cpp_tmpl'/3), cpp_reset('$cpp_tmplh'/4), cpp_reset('$cpp_fspec'/3), cpp_reset('$cpp_spec'/4), cpp_reset('$cpp_mt'/4), cpp_reset('$cpp_inst'/2), cpp_reset('$cpp_out'/2), cpp_reset('$cpp_ownfn'/2), cpp_reset('$cpp_consteval'/1), cpp_reset('$cpp_cecheck'/3), cpp_reset('$cpp_scell'/2), cpp_reset('$cpp_mdef'/5), cpp_reset('$cpp_extern'/3), cpp_reset('$cpp_friends'/2), cpp_reset('$cpp_extra'/2), cpp_reset('$cpp_base_slot'/3), cpp_reset('$cpp_primary_moved'/2), cpp_reset('$cpp_vbase'/1), cpp_reset('$cpp_poly_extra'/3), cpp_reset('$cpp_poly_path'/3), cpp_reset('$cpp_hdrfn'/1), cpp_reset('$cpp_nv_base'/2), cpp_reset('$cpp_vb_holder'/2), cpp_reset('$cpp_bad_layout'/2), cpp_reset('$cpp_lvb'/3), cpp_reset('$cpp_vprim'/2), cpp_reset('$cpp_vprim_ind'/2), cpp_reset('$cpp_vb_claim'/3),
    cpp_reset('$cpp_dflt'/2), cpp_reset('$cpp_extern_full'/3), cpp_reset('$cpp_friends_pending'/1), cpp_reset('$cpp_auto_later'/2), cpp_reset('$cpp_localcls'/2), cpp_reset('$cpp_localst'/2), cpp_reset('$cpp_closure_made'/2), cpp_reset('$cpp_lib_closure'/1), cpp_reset('$cpp_lambda_cls'/5), cpp_reset('$cpp_srcloc'/2), cpp_reset('$cpp_pf_closure'/3), cpp_reset('$cpp_pf_local'/3), cpp_reset('$cpp_lname'/3), cpp_reset('$cpp_lcount'/2), cpp_reset('$cpp_lgid'/2), cpp_reset('$cpp_nolink'/1), cpp_reset('$cpp_srcloc_fn'/1), cpp_note_srcloc_fns(Units), nb_setval('$cpp_fsig', none), nb_setval('$cpp_dflt_site', none), nb_setval('$cpp_lambda_memo', []), cpp_reset('$cpp_dtor_def'/1), nb_setval('$cpp_lambdas', 0), nb_setval('$cpp_gen_invs', []), nb_setval('$cpp_caller', none), nb_setval('$cpp_obj_cat', none), nb_setval('$cpp_closure_this', []), nb_setval('$cpp_temps', none), nb_setval('$cpp_making', []), nb_setval('$cpp_obj_const', none),
    nb_setval('$cpp_nontrivial', []), nb_setval('$cpp_req_ctx', none), nb_setval('$cpp_nv', none), nb_setval('$cpp_lconsts', []),
    cpp_reset('$cpp_acc'/3), cpp_reset('$cpp_afriend'/2), cpp_reset('$cpp_bacc'/3), cpp_reset('$cpp_static_abi'/1), nb_setval('$cpp_body_ctx', none), nb_setval('$cpp_cur_fn', none), nb_setval('$cpp_acc_scope', none), nb_setval('$cpp_obj_expr', none),   % the access of a program class's members and its friends (0.117)
    cpp_reset('$cpp_concept'/2), cpp_reset('$cpp_ccm'/3), cpp_reset('$cpp_vtm'/3), cpp_reset('$cpp_friend_in'/3),   % the concepts by name, and the memos of a concept's satisfaction and a variable template's value (0.112)
    cpp_reset('$cpp_ctype'/3), cpp_reset('$cpp_sinit'/3), cpp_reset('$cpp_sinline'/2), cpp_reset('$cpp_encl'/2),
    cpp_reset('$cpp_own_tmplfn'/3), cpp_reset('$cpp_cross_map'/3), cpp_reset('$cpp_cross_none'/2), cpp_reset('$cpp_cross_made'/2), nb_setval('$cpp_ast_gen', 0), nb_setval('$cpp_cross_table', none),   % the cross-read names' memos, by the ASTs loaded (0.219, cpp_cross_table/1)
    cpp_reset('$cpp_lazy_c'/1), cpp_reset('$cpp_lazy_p'/1), nb_setval('$cpp_eh_used', no), nb_setval('$cpp_hdr_loaded', []), nb_setval('$cpp_budget', 0), nb_setval('$cpp_depth', 0), nb_setval('$cpp_class_ctx', none), ( catch(abolish('$cpp_hdr'/2), _, true) -> true ; true ), dynamic('$cpp_hdr'/2), dynamic('$cpp_hdr_ast'/2),
    cpp_reset('$cpp_lib'/1), cpp_reset('$cpp_libfn'/1), cpp_reset('$cpp_math_decl'/1), cpp_reset('$cpp_nested_tmpl'/3), cpp_reset('$cpp_implicit_copy'/3), cpp_reset('$cpp_promoted'/1), cpp_reset('$cpp_deferred'/4), cpp_reset('$cpp_base_named'/1), cpp_reset('$cpp_implicit_assign'/3), nb_setval('$cpp_in_lib', no),
    cpp_reset('$cpp_nxdef'/4), cpp_reset('$cpp_nxsrc'/3), cpp_reset('$cpp_nxval'/2), cpp_reset('$cpp_nxmval'/3), nb_setval('$cpp_nx_def', none), nb_setval('$cpp_nx_evaluating', []),   % the conditional noexcepts (0.199)
    ccl_set_clear('$cpp_nxfns'), cpp_reset('$cpp_dtor_nx'/2),   % the functions emitted noexcept, whose calls are plain (0.232, ir_nothrow_callee/1)
    cpp_reset('$cpp_sdecl'/4), cpp_reset('$cpp_dctor'/2), cpp_reset('$cpp_cpok'/3), cpp_reset('$cpp_aspok'/3),   % the special members a class declares, and whether its parts copy, move and assign (0.200)
    cpp_reset('$cpp_fn'/5), cpp_reset('$cpp_nested'/5), cpp_reset('$cpp_nested_out'/1), cpp_reset('$cpp_union'/1), cpp_reset('$cpp_nonpod'/1), cpp_reset('$cpp_final'/1), cpp_reset('$cpp_abi_tag'/2), cpp_reset('$cpp_default_ctor'/1), cpp_reset('$cpp_iname'/3), nb_setval('$cpp_nesting', []), cpp_reset('$cpp_hdr_ns'/2), dynamic('$cpp_hdr_ast_ns'/2), cpp_reset('$cpp_cname'/1), nb_setval('$cpp_gvar', []), nb_setval('$cpp_fn_refusal', none),
    ( nb_current('$cpp_trace', _) -> true ; nb_setval('$cpp_trace', no) ),
    forall(member(unit(Is), Units), cpp_note_fns(Is)), forall(member(unit(Is), Units), cpp_note_bases(Is)),                                 % the free functions FIRST: a name is overloaded or not before any call to it is read
    ( ( \+ nb_current('$ccl_exceptions', no) ; cpp_term_mentions_functor(Units, throw) ) -> nb_setval('$cpp_throws', yes) ; nb_setval('$cpp_throws', no) ),   % the program throws, or libc++ does (its exceptions configuration, 0.193): the program's noexcept functions are guarded (cpp_nx_wrap)
    cpp_reset('$cpp_extern_var'/1), forall(member(unit(Is), Units), cpp_note_extern_vars(Is)),   % the variables declared `extern', whose definitions keep external linkage (cpp_inline_storage/3, 0.192)
    cpp_reset('$cpp_fwd'/1), forall(member(unit(Is), Units), cpp_note_fwd_classes(Is)),   % the classes the program declares, a header it reads in place among it (cpp_declared_class/1, 0.201)
    cpp_reset('$cpp_hdr_pre'/2), forall(member(unit(Is), Units), cpp_register_(Is)),
    cpp_alloc_declare_implicit,                                                          % the replaceable allocation functions, where the program declared none (0.202)
    forall(member(unit(Is), Units), cpp_include_fns(Is)),                                % the program's own headers' functions, once every name is registered
    forall(retract('$cpp_hdr_pre'(_, Ps)), cpp_ginit_pre_put(Ps)).                       % a header class's static members that no walk of its header put back (cpp_hdr_pre_apart/2)
cpp_note_extern_vars([]).
cpp_note_extern_vars([I|Is]) :-
    (   I = declaration(_, extern, _, Vs) -> forall(( member(var(N, T, _), Vs), atom(N), T \= fn(_, _, _) ), assertz('$cpp_extern_var'(N)))
    ;   ( I = namespace(_, _, Js) ; I = extern_c(_, Js) ; I = include(_, _, file(_, _, unit(Js))) ), is_list(Js) -> cpp_note_extern_vars(Js)
    ;   true ),
    cpp_note_extern_vars(Is).
cpp_note_fwd_classes([]).
cpp_note_fwd_classes([I|Is]) :-
    (   cpp_fwd_class_item(I, N) -> ( '$cpp_fwd'(N) -> true ; assertz('$cpp_fwd'(N)) )
    ;   ( I = namespace(_, _, Js) ; I = extern_c(_, Js) ; I = include(_, _, file(_, _, unit(Js))) ), is_list(Js) -> cpp_note_fwd_classes(Js)
    ;   true ),
    cpp_note_fwd_classes(Is).
cpp_include_fns([]).
cpp_include_fns([include(_, local(_), file(P, _, unit(Js)))|Is]) :- atom(P), \+ cpp_system_path(P), !, cpp_include_fns(Js), cpp_header_fns(Js), cpp_include_fns(Is).   % a "..." header of the PROGRAM's; a system header read raw keeps its declarations (`abs' over __builtin_labs)
cpp_include_fns([include(_, _, _)|Is]) :- !, cpp_include_fns(Is).
cpp_include_fns([namespace(_, _, Js)|Is]) :- !, cpp_include_fns(Js), cpp_include_fns(Is).
cpp_include_fns([_|Is]) :- cpp_include_fns(Is).
cpp_system_path(P) :- ( sub_atom(P, 0, _, _, '/usr/') ; sub_atom(P, 0, _, _, '/opt/') ; sub_atom(P, 0, _, _, '/Library/') ; sub_atom(P, 0, _, _, '/Applications/') ), !.

%% ---- FREE FUNCTION OVERLOADS ----------------------------------------------------------------------
%% C++ tells `int f(int)' from `double f(double)' by the arguments and gives each its own symbol; C has one
%% name one function, which is what this compiler emitted -- so of libc++'s ten `__convert_to_integral'
%% overloads only the first got a body and every call went to it, whatever it passed. Each DEFINITION of an
%% overloaded name is mangled by its parameters' type keys, `F.int', `F.unsigned_long', as a method already
%% was; a name with ONE definition keeps it, so every C function, every `main' and everything a linker must
%% find by name is untouched, and so is a DECLARATION of an overload (we may name only what we define).
%% The key is taken from the parameters AS WRITTEN, at the registration, the emission and the call alike.
cpp_note_fns([]).
cpp_note_fns([namespace(_, _, Js)|Is]) :- !, cpp_note_fns(Js), cpp_note_fns(Is).
cpp_note_fns([extern_c(_, Js)|Is]) :- !, cpp_c_names(Js), cpp_note_fns(Js), cpp_note_fns(Is).      % extern "C": C linkage, never a mangled name
cpp_note_fns([function(_, Sto, Ret, N, Ps, V, Body)|Is]) :- atom(N), !, cpp_fn_origin(Ret, V, Body, O), cpp_fn_put(N, Ps, Body, O), cpp_nx_note_src(N, Ps, Sto), cpp_note_fns(Is).
cpp_note_fns([declaration(_, _, _, Vs)|Is]) :- !, forall(member(var(N, fn(Ret, Ps, V), I), Vs), ( atom(N) -> cpp_fn_put(N, Ps, none, decl(Ret, V)), cpp_note_fn_del(N, Ps, I) ; N = operator(Op) -> cpp_note_op_del(Op, Ps, I) ; true )), cpp_note_fns(Is).
cpp_note_fns([_|Is]) :- cpp_note_fns(Is).
cpp_fn_origin(Ret, V, none, decl(Ret, V)) :- !.                                          % what a DECLARATION alone can say: the result and the ellipsis a mangled name needs
cpp_fn_origin(_, V, _, own(V)).                                                          % the program's own definition keeps its ELLIPSIS (0.100): `int f(...)' beside a template had the origin `own' alone, so the arity test never fitted it and a call the template rightly refused had no plain overload to fall to
%% a LIBRARY header's items of one name, before any of them is registered: its definitions kept whole, to emit on use
cpp_note_hdr_fns([]).
cpp_note_hdr_fns([function(L, Sto, Ret, N, Ps, V, Body)|Is]) :- atom(N), Body \== none, !,
    cpp_fn_put(N, Ps, Body, lazy(function(L, Sto, Ret, N, Ps, V, Body))), cpp_nx_note_src(N, Ps, Sto), cpp_note_hdr_fns(Is).
%% A HEADER'S FREE OPERATOR (a literal operator, 0.117; any other, 0.117 too) is noted under its free operator name, as an inline function is: lazy, emitted where it is called
cpp_note_hdr_fns([function(L, Sto, Ret, operator(Op), Ps, V, Body)|Is]) :- Body \== none, Op \= conv(_), cpp_free_operator(Op, Ps, N0), !,
    cpp_note_hdr_fns([function(L, Sto, Ret, N0, Ps, V, Body)|Is]).
cpp_note_hdr_fns([I|Is]) :- cpp_note_fns([I]), cpp_note_hdr_fns(Is).
cpp_fn_put(N, Ps, Body, Origin) :- ( Body == none -> D = no ; D = yes ), cpp_params_key(Ps, K),
    ( '$cpp_fn'(N, K, _, D, O0), cpp_fn_same_ellipsis(O0, Origin) -> true ; assertz('$cpp_fn'(N, K, Ps, D, Origin)) ).
%% two noted functions of one name and key are one where both have the ellipsis or neither has it (1.6.38, below)
cpp_fn_same_ellipsis(O1, O2) :- ( cpp_fn_variadic(O1) -> cpp_fn_variadic(O2) ; \+ cpp_fn_variadic(O2) ).
%% A FUNCTION DECLARED DELETED (0.257): `'$cpp_fn_del'(N, Key, Why)', its reason or none, which a call that chooses it asks
%% (cpp_deleted_call/3). It is a candidate as any declaration is ([over.match]/2: a deleted function takes part in overload
%% resolution), and chosen it was called by a name nothing defines: `undeclared(g)'
cpp_note_fn_del(N, Ps, I) :- ( ccl_deleted_body(I, Why) -> cpp_params_key(Ps, K), ( '$cpp_fn_del'(N, K, _) -> true ; assertz('$cpp_fn_del'(N, K, Why)) ) ; true ).
%% ... and a free OPERATOR declared deleted, by its operator and its number of operands, `'$cpp_op_del'(Op, K, Why)', which the
%% operator's road asks where nothing else answers it (cpp_deleted_operator/3): it is no candidate there, and the operator was
%% refused `not lowered yet: no_operator(==)'
cpp_note_op_del(Op, Ps, I) :- ( ccl_deleted_body(I, Why) -> length(Ps, K), ( '$cpp_op_del'(Op, K, _) -> true ; assertz('$cpp_op_del'(Op, K, Why)) ) ; true ).
cpp_c_names([]).
cpp_c_names([I|Is]) :- ( cpp_item_name(I, N) -> asserta('$cpp_cname'(N)) ; true ), cpp_c_names(Is).
cpp_item_name(function(_, _, _, N, _, _, _), N) :- atom(N).
cpp_item_name(declaration(_, _, _, [var(N, fn(_, _, _), _)|_]), N) :- atom(N).
cpp_c_name(N) :- '$cpp_cname'(N), !.
%% the name a free function is emitted and called under: its own, unless the name has two definitions of
%% different parameters and this item is one of them
cpp_fn_name(F, _, _, F) :- cpp_c_name(F), !.
cpp_fn_name(F, Ps, no, Name) :- cpp_mangled_name(F, Ps, Name), !.                        % declared here and DEFINED in the shipped library: its own C++ symbol
%% ... AFTER THE HEADER'S FUNCTIONS OF THE NAME HAVE JOINED ITS SET (cpp_hdr_join/1; 0.227), as a call's resolution has them
%% (cpp_fn_ready/1): libc++ 22 defines a plain `std::swap(exception_ptr &, exception_ptr &)', registered at the first call of
%% `std::swap' -- the program's `void swap(Box &, Box &)' was emitted as `swap' before its body made that call, and `main''s
%% call named `swap.Box_r.Box_r', declared nowhere
cpp_fn_name(F, Ps, yes, Name) :- cpp_hdr_join(F), cpp_fn_overloaded(F), !, cpp_params_key(Ps, K), atomic_list_concat([F, '.', K], Name).
cpp_fn_name(F, _, _, F).
%% A DEFINITION WITH AN ELLIPSIS BESIDE ONE OF THE SAME PARAMETERS WITHOUT IT IS AN OVERLOAD OF ITS OWN (1.6.38;
%% [dcl.fct]/4, [over.load]: the ellipsis is part of the function's type), named by the parameters' key and `z', the
%% Itanium ABI's code of an ellipsis: `int f(int)' and `int f(int, ...)' were noted under one key, the first kept, and
%% both were emitted as `f' -- LLVM's `invalid redefinition of function 'f'' --, and `f(1, 2)' was `no matching function
%% for call to 'f''. A call that passes more arguments than the named parameters takes the one with the ellipsis
%% (cpp_free_call_/5); one that passes as many takes the other, where clang++ says the call is ambiguous (Not done)
cpp_fn_name_va(F, Ps, V, D, Name) :- V == true, D == yes, cpp_fn_va_twin(F, Ps), !, cpp_fn_name(F, Ps, D, Name0), atom_concat(Name0, '.z', Name).
cpp_fn_name_va(F, Ps, _, D, Name) :- cpp_fn_name(F, Ps, D, Name).
cpp_fn_va_twin(F, Ps) :- cpp_params_key(Ps, K), '$cpp_fn'(F, K, _, yes, O1), cpp_fn_variadic(O1), '$cpp_fn'(F, K, _, yes, O2), \+ cpp_fn_variadic(O2), !.

%% ---- items ----------------------------------------------------------------------
cpp_items([], []).
cpp_items([I|Is], Out) :- cpp_item(I, Js), append(Js, Out1, Out), cpp_items(Is, Out1).
%% a class: the struct, the statics, then its members as functions
cpp_item(declare(L, base(Q, [class(K, C0, Bs, Ms)])), Items) :- ( cpp_class_item_name(C0, C) -> true ; C = C0 ), '$cpp_friends'(C, Fs), Fs \== [], !,   % the program's hidden friends, emitted with their class
    retract('$cpp_friends'(C, Fs)), assertz('$cpp_friends'(C, [])),
    cpp_item(declare(L, base(Q, [class(K, C0, Bs, Ms)])), Items0), cpp_in_class(C, cpp_friend_items(Fs, FItems)), append(Items0, FItems, Items).   % their bodies walked in the class (0.115)
cpp_item(declare(L, base(Q, [class(_, C0, _, _)])), Items) :- !, ( cpp_class_item_name(C0, C) -> true ; C = C0 ),
    ( cpp_class(C, cls(Base, Data, Ms, Statics, Defaults, Slots)) -> true ; cpp_trace(item_no_class(C)), fail ),
    cpp_base_layout(C, Base, Data, Data1),
    (   cpp_is_lazy(C) -> Fns0 = []                                                                  % a LAZY class's statics come as they are named (cpp_use_static, 0.112)
    ;   cpp_in_class(C, cpp_static_decls(L, C, Statics, Fns0)) -> true ; cpp_trace(item_statics(C)), fail ),   % IN ITS CLASS: a static's type is written in the class's own words, `static constexpr const type __max'
    ( cpp_is_lazy(C), Slots == [] -> Fns1 = []
    ; cpp_is_lazy(C) -> ( cpp_slot_fns(C, Base, Defaults, Slots, Ms, Fns1) -> true ; cpp_trace(item_member_fns(C)), fail )   % a lazy POLYMORPHIC class emits what its table names -- its own slot implementations -- and nothing else
    ; cpp_in_class(C, cpp_member_fns(Ms, C, Base, Defaults, Fns1)) -> true ; cpp_trace(item_member_fns(C)), fail ),   % a lazy class's members come as they are used
    ( \+ cpp_implicit_ctor_needed(C) -> Fns2 = [] ; cpp_in_class(C, cpp_implicit_ctor(L, C, Base, Defaults, Fns2)) -> cpp_mangle(C, C, [], ICName), cpp_instance_note(ICName, C) ; cpp_trace(item_implicit_ctor(C)), fail ),   % ... and the implicit one is NOTED where the class emits it, so a later naming does not emit it again (cpp_use_member takes a written `C()' of a lazy class by the same name: two identical definitions, which LLVM refuses)
    ( \+ cpp_implicit_dtor_needed(C) -> Fns3 = [] ; cpp_in_class(C, cpp_implicit_dtor(L, C, Fns3)) -> cpp_nx_note_dtor(C, Fns3) ; cpp_trace(item_implicit_dtor(C)), fail ),   % BOTH IMPLICIT MEMBERS ARE MADE IN THE CLASS (0.113), as its written members are: a default member initializer is written in the class's words ([class.mem]/7, a complete-class context), and libc++'s view sentinels write `sentinel_t<_Base> __end_ = sentinel_t<_Base>();' over their own alias `_Base' -- made outside, the implicit constructor named nothing and the instance was not emitted. `sentbase.cpp'.
    append(Fns0, Fns1, Fns01), append(Fns01, Fns2, Fns012), append(Fns012, Fns3, FnsA),
    cpp_own_fns(FnsA),   % a class's methods, where the constexpr evaluator finds them: `q.sum()' over a constant q (0.98)
    cpp_align_tag(C, Ms, Data1, Data20), cpp_pod_mark(C, Data20, Data2),   % the `$nonpod' mark rides with the struct (0.135): the passes note the tags again from the items
    ( '$cpp_union'(C) -> Spec = union(C, [union_tag|Data2]) ; Spec = struct(C, Data2) ),   % a union-class shares its members' storage, and its tag says so wherever it is noted from (ccl_is_union_tag)
    ( cpp_nv_form(C, Data2, NVData) -> cpp_nv_tag(C, NV), Fns = [declare(L, base([], [struct(NV, NVData)]))|FnsA] ; Fns = FnsA ),   % the base-subobject form beside the class (0.110), a holder's too (0.163)
    (   Slots == [], \+ cpp_has_table(C) -> Items = [declare(L, base(Q, [Spec]))|Fns]   % a class with no slot has a table still where it holds a virtual base (0.160): the base's offset, the offset to top, the type_info
    ;   cpp_vt_struct(L, C, Slots, VtDecl), cpp_vtable(L, C, Slots, Tables00), nb_getval('$cpp_pthunks', PTh), append(PTh, Tables00, Tables0), cpp_secondary_tables(L, C, Secs0), cpp_ctor_tables(L, C, CTs), append(Secs0, CTs, Secs), append(Tables0, Secs, Tables),
        cpp_own_fns(Tables),   % ... and the functions its tables name, its deleting destructor and its thunks, where a virtual call in a constant evaluation finds them (0.257)
        Items = [VtDecl, declare(L, base(Q, [Spec]))|Fns1x], append(Fns, Tables, Fns1x) ).
%% A FREE FUNCTION'S CONDITIONAL NOEXCEPT (0.199; [except.spec]/2): `nxif(E, Sto)' in its storage slot (the reader's
%% ccl_nx_sto/3) is taken off where the function is emitted, and E goes to the emission's own clause below through
%% '$cpp_nx_def', which that clause reads first (its terminate guard, cpp_fn_nx_guarded/4); the emitted function's name keeps
%% E for the operator `noexcept' ('$cpp_nxdef', evaluated where it is asked, cpp_nx_named_value/2)
cpp_item(function(L, nxif(E, Sto), Ret, N, Ps, V, Body), Out) :- !, ( cpp_class_ctx(Cx0) -> Cx = Cx0 ; Cx = none ),
    ccl_global('$cpp_nx_def', D0, none), nb_setval('$cpp_nx_def', def(Cx, E)),
    (   catch(cpp_item(function(L, Sto, Ret, N, Ps, V, Body), Out), X, ( nb_setval('$cpp_nx_def', D0), throw(X) )) -> nb_setval('$cpp_nx_def', D0)
    ;   nb_setval('$cpp_nx_def', D0), fail ),
    ( Out = [function(_, _, _, Name, Ps1, _, _)|_], atom(Name) -> assertz('$cpp_nxdef'(Name, Cx, E, Ps1)) ; true ).
%% a declaration of SEVERAL declarators, one of them a class's member defined out of its class (`int Tag::made = 0, Tag::gone = 0;'), is one item per declarator
%% A MEMBER DEFINED OUT OF ITS CLASS BY A QUALIFIED NAME OF SEVERAL SEGMENTS (0.166; [class.mfct]/2, [namespace.memdef]/2):
%% `int n::C::m() {...}' of a class in a namespace, `int Outer::Inner::f() {...}' of a nested class, `int n::C::count = 3;'
%% -- its class found through the whole path, as a qualified type's is (cpp_scope_class/2), and the item taken as the
%% one-segment definition below. Only `C::m' was taken: the others reached the lowering, `member_of_class(scoped([n, 'C'], m))'.
cpp_item(function(L, Sto, Ret, scoped(Path, M), Ps, V, Body), Out) :- cpp_member_path_class(Path, C), !, cpp_item(function(L, Sto, Ret, scoped([C], M), Ps, V, Body), Out).
cpp_item(declaration(L, Sto, B, Vs0), Out) :- ccl_std_at_least(20), cpp_paren_agg_vars(Vs0, Vs), Vs \== Vs0, !, cpp_item(declaration(L, Sto, B, Vs), Out).   % C++20'S PARENTHESIZED AGGREGATE INITIALIZATION AT NAMESPACE SCOPE (cpp_paren_aggregate/2, 0.197): `P g(1, 2);' reached the lowering as `global_init(ctor([1, 2]))'
cpp_item(declaration(L, Sto, B, Vs0), Out) :- member(var(scoped(Path, _), _, _), Vs0), cpp_member_path_class(Path, _), !,
    findall(V1, ( member(V, Vs0), ( V = var(scoped(P, N), T, I), cpp_member_path_class(P, C) -> V1 = var(scoped([C], N), T, I) ; V1 = V ) ), Vs), cpp_item(declaration(L, Sto, B, Vs), Out).
cpp_item(declaration(L, Sto, B, Vs), Out) :- Vs = [_, _|_], member(var(scoped([C], _), _, _), Vs), cpp_class_l(C, _), !,
    findall(declaration(L, Sto, B, [V]), member(V, Vs), Ds), cpp_items(Ds, Out).
cpp_item(declaration(L, Sto, B, [var(scoped([C], N), T0, Init)]), [declaration(L, Sto1, B, Vs1)]) :- cpp_class_l(C, _), !,
    ( catch(cpp_in_class(C, cpp_type(T0, T1)), _, fail) -> T = T1 ; T = T0 ),   % ITS TYPE RESOLVED IN ITS CLASS'S SCOPE (0.218; [basic.scope.class]): `std::vector<int> K::all;' reached the lowering as `typedef(scoped([std], tmpl(vector, ...)))', and no constructor ran; `int K::arr[N]' over the class's N was `global_init(arr(id('N'), ...))'; a type it does not resolve goes on as before
    atomic_list_concat([C, '.', N], Name), cpp_with_access_scope(C, cpp_expr(none, Init, Init1)),   % the initializer is in the class's scope ([basic.scope.class]): its private statics are the program's to name (0.117)
    cpp_static_object_init(C, Sto, Name, T, Init, Init1, Init2),                                    % a class-typed one constructed (0.186)
    cpp_dynamic_scalars(L, C, Sto, B, [var(Name, T, Init)], [var(Name, T, Init2)], Vs1), ( Sto == inline -> Sto1 = linkonce ; Sto1 = Sto ).   % an inline one linkonce (0.192); a const one keeps its class's external linkage
cpp_item(function(L, Sto, Ret, scoped([C], M), Ps, V, Body), [function(L, Sto0, Ret, Name, [param(ThisT, this)|Ps1], V, Body1)]) :- cpp_class_l(C, _), !,
    cpp_sto_quals(Sto, Qs1, Sto0), cpp_member_va_quals(C, M, Ps, V, Qs1, Qs), cpp_mangle_q(C, M, Qs, Ps, Name), cpp_plain_params(Ps, Ps1), cpp_this_type(C, Qs, ThisT),
    cpp_pf_decl_quals(C, M, Ps, Qs, FQs0), ( cpp_sto_word(Sto, inline) -> FQs = FQs0 ; FQs = [out_of_line|FQs0] ),   % defined out of its class and not inline: its closures are clang's `$_N' (0.236)
    cpp_with_fsig(fsig(member, C, M, Ret, Ps, V, FQs, none), cpp_method_body(C, Ret, [param(ThisT, this)|Ps1], Body, Body1)),
    cpp_own_fns([function(L, Sto0, Ret, Name, [param(ThisT, this)|Ps1], V, Body1)]), cpp_note_nce_free(L, M, Name).
cpp_item(ctor_def(L, C0, Qs0, Ps, Inits, Body), Out) :- Body \== none, catch(cpp_class_item_name(C0, C), _, fail), cpp_class(C, cls(B, _, _, _, Ds, _)), !,   % A CONSTRUCTOR DEFINED OUT OF ITS CLASS (0.133): `P::P() { v = 3; }', `P::P(int k) : v(k) {}', `Outer::Inner::Inner()' -- the catch-all clause passed the item through raw, the lowering made nothing of it, and every call named `P.P.0', defined nowhere (a link error; no fixture had one). Built as an in-class one is (cpp_ctor_fn: the bases, the table pointer, the member initializers, the body), its declaration in the class a declaration
    cpp_take_pattern(Qs0, _, Qs),
    cpp_ctor_fn(L, C, B, Ds, Ps, Inits, Body, F), cpp_nv_twin(C, F, cpp_ctor_fn(L, C, B, Ds, Ps, Inits, Body, F2), F2, Out, []), cpp_own_fns(Out),
    ( F = function(_, _, _, CName, _, _, _) -> cpp_note_consteval(C, Qs, CName), cpp_note_nce(C, Qs, Body, CName) ; true ).
cpp_item(dtor_def(L, C0, _, Body),[function(L, none, base([], [void]), Name, [param(ThisT, this)], false, Body1)]) :- ( catch(cpp_class_item_name(C0, C), _, fail) -> true ; C = C0 ), !,   % a nested class's by its dotted name too (0.133)
    atomic_list_concat([C, '.dtor.0'], Name), cpp_this_type(C, [], [dying], ThisT), cpp_with_fsig(fsig(dtor, C, C, none, [], false, [], none), ( cpp_dtor_body(L, C, Body, Body0), cpp_method_body(C, [param(ThisT, this)], Body0, Body1) )),
    cpp_own_fns([function(L, none, base([], [void]), Name, [param(ThisT, this)], false, Body1)]).
cpp_item(function(L, Sto, Ret0, operator(Op), Ps, V, Body), [function(L, Sto, Ret, Name, Ps1, V, Body1)]) :- !,   % the result type resolved, as a plain function's is: a program's friend inserter returns `std::ostream &'
    cpp_nx_def_take(_), cpp_free_operator(Op, Ps, N0), cpp_fn_name(N0, Ps, yes, Name), cpp_plain_params(Ps, Ps1),
    ( Ret0 = base(_, [auto]) -> cpp_lambda_ret(Ps1, Body, Ret), ccl_declare(Name, fn(Ret, Ps1, V)) ; cpp_decltype_ret(Ret0, Ps, Ret) -> ccl_declare(Name, fn(Ret, Ps1, V)) ; cpp_type_or_self(Ret0, Ret), cpp_declare_resolved(Name, Ret0, Ret, Ps1, V) ),   % an `auto' operator DEDUCES, as a plain function does (0.113): `friend auto operator<=>(...)'
    cpp_fsig_marks(Sto, operator(Op), FMs), cpp_with_fsig(fsig(free, none, operator(Op), Ret0, Ps, V, FMs, none), cpp_with_fn(operator(Op), cpp_method_body(none, Ret, Ps1, Body, Body1))),
    cpp_own_fns([function(L, Sto, Ret, Name, Ps1, V, Body1)]), cpp_note_nce_free(L, operator(Op), Name).
cpp_item(function(_, _, _, N, Ps, _, _), []) :- atom(N), cpp_auto_params(Ps, 0, _, TPs), TPs \== [], !.   % an abbreviated template: instantiated on use
cpp_item(function(L, Sto, Ret0, N, Ps, V, Body), [function(L, Sto, Ret, Name, Ps1, V, Body1)]) :- !,
    cpp_nx_def_take(NxD),                                                                          % its conditional noexcept (0.199), from the clause above
    cpp_fn_body_mark(Body, D), cpp_fn_name_va(N, Ps, V, D, Name),                                  % an overloaded name's definition carries its parameters' keys, and an ellipsis's (1.6.38)
    cpp_fsig_marks(Sto, N, FMs), cpp_fsig_own(N, fsig(free, none, N, Ret0, Ps, V, FMs, none), Sig),   % what its own name says (0.166): an instance's, its pattern's; inline, static, C's linkage for its local names (0.236)
    cpp_plain_params(Ps, Ps1), ( cpp_auto_result(Ret0) -> cpp_with_fsig(Sig, cpp_fn_auto_ret(Ret0, Ps1, Body, Ret)), ccl_declare(Name, fn(Ret, Ps1, V)) ; cpp_decltype_ret(Ret0, Ps, Ret) -> ccl_declare(Name, fn(Ret, Ps1, V)) ; cpp_type(Ret0, Ret), cpp_declare_resolved(Name, Ret0, Ret, Ps1, V) ),   % C++14: auto f(...): the first return's type -- DECLARED under the deduced type (0.100): the table held the raw `auto', so `auto f = make(3)' in a later function typed the call as `auto' and asked again without end; [dcl.spec.auto]: such a function is defined before its type is used, so the item order serves
    ( cpp_fn_nx_guarded(NxD, N, Ps1, Body) -> cpp_nx_wrap(L, Body, BodyG) ; BodyG = Body ), cpp_with_fsig(Sig, cpp_with_fn(N, cpp_method_body(none, Ret, Ps1, BodyG, Body1))),   % the function's own name is what a friend declaration names (0.117)
    cpp_nx_note_fn(NxD, N, Name, Ps1),   % noexcept: its calls are plain (0.232)
    assertz('$cpp_ownfn'(Name, function(L, Sto, Ret, Name, Ps1, V, Body1))),   % THE PROGRAM'S OWN FUNCTION, DESUGARED, where a constant fold can find it (0.95): `constexpr int N = twice(21);' at file scope
    ( Ret0 = base(Q0, _), memberchk(consteval, Q0) -> assertz('$cpp_consteval'(Name)) ; true ), cpp_note_nce_free(L, N, Name).   % C++20's IMMEDIATE FUNCTION: every call of it is folded (cpp_free_call), or refused (0.99)
cpp_item(declare(L, base(Q, [struct(N, Ms)])), Items) :- atom(N), '$cpp_promoted'(N), !, cpp_item(declare(L, base(Q, [class(struct, N, [], Ms)])), Items), cpp_trace(promoted_items(N, Items)).   % promoted at registration (cpp_struct_promotes)
cpp_item(declare(L, base(Q, [union(N, Ms)])), Items) :- atom(N), '$cpp_union'(N), cpp_class_l(N, _), cpp_union_class_members(Ms), !, cpp_item(declare(L, base(Q, [class(union, N, [], Ms)])), Items).   % a union class (cpp_register_): its struct, its members as functions
cpp_item(declare(L, base(Q, [struct(N, Ms)])), [declare(L, base(Q, [struct(N, Ms1)]))]) :- atom(N), Ms \== none, !,       % a plain struct: its member types resolved in place (`std::size_t n')
    cpp_plain_members(Ms, Ms1), ( Ms1 == Ms -> true ; ccl_note_tag(N, Ms1) ).
cpp_item(declaration(L, Sto, B, Vs), [declaration(L, Sto1, B, Vs3)]) :- !, cpp_gvar_walk(Sto, Vs, cpp_vars(none, Vs, Vs1)), cpp_fold_const_inits(B, Sto, Vs, Vs1, Vs2), cpp_redeclare_globals(Vs, Vs1),
    ( nb_current('$cpp_in_lib', yes) -> true ; ccl_note_own_constant(declaration(L, Sto, B, Vs2)) ),   % the program's named constant, its constexpr call folded (0.195)
    cpp_dynamic_scalars(L, none, Sto, B, Vs, Vs2, Vs3), cpp_inline_storage(Sto, Vs3, Sto1).
cpp_item(typedef(L, Vs), [typedef(L, Vs1)]) :- !, cpp_vars(none, Vs, Vs1), ccl_note_typedefs(Vs1).   % the table learns the instance's name at once
cpp_item(template(_, _, _), []) :- !.
cpp_item(concept(_, _, _), []) :- !.                                                               % C++20: a constraint, checked where a template is instantiated
cpp_item(namespace(L, N, Is), [namespace(L, N, Js)]) :- !, cpp_with_cplxlit([], cpp_with_usings([], cpp_items(Is, Js))).   % a using of a header's namespace INSIDE a namespace ends with it (0.160): `namespace d { using namespace b; }' was in force for the rest of the unit; <complex>'s literals' too (0.179)
cpp_item(extern_c(L, Is), [extern_c(L, Js)]) :- !, cpp_items(Is, Js).
cpp_item(using(L, U), Is) :- cpp_cplxlit_using(U, Sx), \+ cpp_cplxlit_covered(Sx), !, nb_getval('$cpp_cplxlit', C0), cpp_relops_join(C0, Sx, C), nb_setval('$cpp_cplxlit', C), cpp_item(using(L, U), Is).   % <complex>'s literal operators made visible at namespace scope (0.179): noted, and the using taken as before
cpp_item(using(L, U), [using(L, U)]) :- ( cpp_hdr_using(U, Us) ; cpp_hdr_type_using(U, Us) ), !, ( nb_current('$cpp_usings', U0) -> true ; U0 = [] ), append(Us, U0, U1), nb_setval('$cpp_usings', U1).   % a header namespace's names at namespace scope (0.160): in force for the rest of the unit -- and a using-declaration of its keyed TYPE (0.161), which a block takes by the substitution of 0.121 (cpp_stmts)
cpp_item(using(L, U), [using(L, U)]) :- cpp_relops_using(U, Ops), !, nb_getval('$cpp_relops', R0), cpp_relops_join(R0, Ops, R), nb_setval('$cpp_relops', R).   % `using namespace std::rel_ops;' at namespace scope (0.136): in force for the rest of the unit
cpp_item(declare(L, base(Q, [E0])), Out) :- compound(E0), ( E0 = enum(Tag, Es0) ; E0 = enum_class(Tag, Es0) ), is_list(Es0),   % AN UNDERLYING TYPE NAMED BY A QUALIFIED NAME (0.194): `enum class Color : std::uint8_t' -- resolved here, so the table the passes build again from the output holds the type the lowering sizes the enum by (it met `typedef(scoped([std], uint8_t))')
    Es0 = [enum_base(B0)|Rest], B0 = base(_, [typedef(scoped(_, _))]), catch(cpp_type(B0, B), error(not_lowered(_), _), fail), B \== B0, !,
    functor(E0, F, 2), Es1 = [enum_base(B)|Rest], E1 =.. [F, Tag, Es1], ( atom(Tag) -> ccl_note_tag(Tag, Es1) ; true ), cpp_item(declare(L, base(Q, [E1])), Out).
cpp_item(declare(L, base(Q, [E0])), [declare(L, base(Q, [E]))]) :- compound(E0), ( E0 = enum(Tag, Es0) ; E0 = enum_class(Tag, Es0) ), is_list(Es0),
    cpp_enum_unfolded(Es0, 0, []), !, functor(E0, F, 2), cpp_fold_enumerators(L, Es0, 0, [], Es), E =.. [F, Tag, Es].
cpp_item(static_assert(L, E, M), [static_assert(L, E, M)]) :- !, cpp_static_assert(none, L, E, M).   % checked (0.198, cpp_static_assert/4)
cpp_item(I, [I]).
%% THE PROGRAM'S FUNCTIONS WHERE THE EVALUATOR FINDS THEM ('$cpp_ownfn', 0.95, 0.98): a class's members and the functions its tables name,
%% a free function, and since 0.258 a member and a constructor defined out of the class and a free operator -- `constexpr int S::m5() const
%% {...}', `constexpr T2::T2(int k) : w(k * 2) {}' and `constexpr bool operator<(const S &, const S &)' had no body to it, and a static
%% assertion over a call of one, which clang++ takes, was refused (since 0.257) or passed unasked (before it)
cpp_own_fns(Fns) :- forall(( member(Fn, Fns), Fn = function(_, _, _, FN, _, _, _), atom(FN) ), assertz('$cpp_ownfn'(FN, Fn))).
