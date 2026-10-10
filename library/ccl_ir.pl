%% cicilang -- library(ccl_ir): the lowering. cicilang_ir(+Units, -IR) takes
%% the ASTs cicilang_ast/2 answers and gives an LLVM IR module as text.
%%
%% The symbol table is rebuilt from the units the way the parser builds it
%% (ccl_note_item/1, library(ccl_syntax)), so the lowering types every
%% expression with ccl_type_of/2 (library(ccl_infer)) -- the same inference
%% the macros and `:=' use -- and lays structs out with ccl_size_of/2.
%%
%% One clause per construct: ir_stmt/1 for statements, ir_expr/3 for an
%% expression's value and C type, ir_lval/3 for an address. Locals are
%% allocas in the entry block (mem2reg lifts them); conversions follow C's
%% usual arithmetic conversions; `defer' is the static cleanup chain: every
%% exit of a scope -- its end, a return, a break or continue -- runs the
%% scope's defers last-registered-first, inline on that path.
%%
%% What lowers today (M2): functions and prototypes; globals with constant
%% initializers; int, char, short, long, float, double, pointers, arrays,
%% structs, typedefs, enums; declarations with initializers; if, while, do,
%% for, switch, return, break, continue, goto, defer; every operator, calls
%% (variadic too), casts, sizeof, ?:, the comma, compound literals,
%% statement expressions; unions (a scalar of the union's alignment, padded,
%% every member at its address), bitfields (a struct's shape follows its C
%% layout, a run of bitfields one [K x i8] read and written through masks),
%% static locals (a private global of the function's). Not yet: VLAs,
%% long double (as a double) -- each throws error(not_lowered(What), where(F)); the complex types are lowered since 0.100.
%%
%% A struct by value crosses a call the way the platform's C ABI says (M3):
%% on x86-64 (SysV) a struct of 16 bytes or less is split into eightbytes,
%% each INTEGER (an iN of the bytes it holds) or SSE (float, double,
%% <2 x float>), passed and returned as those pieces; a bigger one is passed
%% in memory (ptr byval) and returned through sret. On arm64 (AAPCS64) 16
%% bytes or less is i64 or [2 x i64], a homogeneous float aggregate [k x T],
%% and a bigger one goes by a pointer to a copy, returned through sret. The
%% host decides (uname -m); ir_abi/2 classifies, ir_fn_sig/6 spells a
%% signature, and a define, a call and a declare all read the same answer.
%%
%% THE SURFACE:
%%   ccl_ir_units(+Units, -IR)     IR the module text, an atom
%%   ccl_ir_function(+Item, -Text) one function, for the curious

:- use_module(library(ccl_infer)).
:- use_module(library(ccl_check)).
:- use_module(library(ccl_cpp)).                                          % M6: the C++ forms desugared to the C below

%% the lowering's version: part of the key of every IR the driver keeps in the
%% store (library(ccl_driver)); BUMP it whenever the check or the lowering
%% changes what they emit, as ccl_reader_version/1 is bumped for the grammar
ccl_lowering_version(72).   % 72 (0.131): another machine -- AAPCS64's HFA before the size, a 16-aligned composite as an i128, Linux aarch64's long double an fp128 (constants, conversions, its complex runtime), plain char and wchar_t unsigned there, va_arg of every type expanded by AAPCS64's rules; x86-64's va_arg of an x87 long double from the overflow area; 71 (0.130): -g's variables (llvm.dbg.declare), types, lexical blocks, each function's type and C++'s names and scopes, no location in the prologue, and -gline-tables-only's kind; 70 (0.129): the decimal floating types (BID values in float, double and fp128 carriers, libgcc's runtime, an SSE class in an aggregate), an explicit specialization of a function template as the body of the instance it matches, a bit builtin's call an int, a folded constant past 64 bits a 128-bit integer, a floating constant under a cast to an integer folded, a floating global's fold through a cast to an integer type and a wide integer, an integer global from a floating initializer converted; 69 (0.128): -g's line tables (a function's subprogram, an instruction's location; the IR's signature folds the option) and the unsigned constants typed; 68 (0.127): the C++ types of expressions -- a comparison, `!', `&&' and `||' are a bool (an i8), a conditional over two arms of one arithmetic type has that type, an enumerator is of its enum and a prvalue (bound to a reference through a temporary), an enum promotes to its underlying type, and an integral or floating promotion ranks above a conversion in overload resolution; 67 (0.126): what the desugaring emits for libc++ 21 -- a bare static member function named as a value is its thunk (or waits for its target when several share the name: `'$staticfn'(C, N)`); a qualified enumerator is the value its OWN enum gives it (`B::X` beside `A::X` took the first of the table; a nested enum named bare in a `case` label folds); a plain struct or union member initialized by parentheses from a value of another type is aggregate initialization (`basic_string() : __rep_(__short())`); a requires-expression's parameter pack expands with the bindings; a pointer to a data member of a plain struct (`&Pt::x`) and `__builtin_invoke` of one; `__builtin_clz*`, `ctz*` and `popcount*` and a pointer cast fold in the constexpr evaluator; a free operator template's declaration is registered (its default lends to the definition); a template parameter that two function parameters deduce deduces one type; a function given to `T &` deduces the function type; a deleted nullary function is indexed (the poison pills); `__builtin_common_type` is not a builtin here; a pointer operand that is a reference to a pointer is read through (`*static_cast<A0 &&>(a0)`, ir_ptr_operand); `*` of an arithmetic value is refused, `x.*pm` carries the object's const and xvalue, and a plain struct is its own base (libc++ 18's `__invoke` for a data member); a later EMPTY base is a base to the deduction (`__pipeable<_Fn> : _Fn, __range_adaptor_closure<__pipeable<_Fn>>') and a header's class being loaded is a class to `__is_class' (the views); the type of a call of a function template that names the template's own parameter is raw whatever a typedef of that name says (`std::addressof(m)' in a base initializer), one function template declared by two headers' summaries is one candidate (`back_inserter' under `<string>' and `<format>'), and a generic lambda's parameter that names its own template parameter stays as written where the tables know the name (`__synth_three_way', a vector's `<=>'); 66 (0.125): a parameter that stands twice deduces one type in the partial ordering of function templates (`f(I1, I1, I2, I2)' beats `f(I1, I1, I2, P)'); 65 (0.122): the move of a plain struct is an xvalue (`static_cast<S &&>(s)', so `f(const S &)' beside `f(S &&)' chooses by the value category) and a return reads a reference value through; a member initialized from a prvalue of its own class is constructed in place; a value-initialized plain struct or union is every byte zero; 64 (0.121): what the desugaring and the lowering emit for std::variant and std::visit -- a method a class brings in from a base by `using Base::f;' is a forwarder, a pack of bases (`struct X : Ts...') and `using Ts::operator()...;' expand over the bound pack, an aggregate with (empty) bases is built from its own items, a local class is a class of its own, `p->f<T>()' reaches a member template through a base, the value category of a forwarded object decides a copy or a move (a member of an xvalue, `decltype(name)' of a reference, a member of a const object is const), a braced list handed to an array reference is checked for narrowing, a scalar conversion ranks among templates, a union class's destructor destroys no member, an aggregate member built from a prvalue of its own class is elided, a call through a temporary callee takes the copy pass; a reference member of an aggregate binds its item (ir_init_sub), a union at namespace scope with a constructor, a destructor or a method is a union class and `U u = {5}' names its first member (ccl_data_members); a prvalue (a temporary's block, a returned local moved into its result, a call that returns through the hidden pointer) is constructed IN the object it initializes -- a local, a returned result, an aggregate member -- never copied bitwise (ir_prvalue_block, ir_in_place, ir_sret_call, '$ir_sret_into'): a std::function, a list or a map holds its own address; the top-level const of a pointer is dropped by the deduction, a class converts to another class through the target's constructor in the traits, and a comparison is rewritten through a free or a reversed `operator<=>' (std::string and std::variant at C++20); 63 (0.120): the drain functions of the tagged structs follow the tags' BUCKETS (the tags table is 128 globals now, and the functions come bucket by bucket, newest first within one: the same functions, in another order); 62 (0.117): an arithmetic value bound to a reference to ANOTHER arithmetic type (`const size_t &' handed an int: std::max<size_t>(2 * n, 1), every std::deque that grew) converted into a temporary of the referent's type (ir_ref_converts), a call whose result is a reference to an array is the array's address (it decays), a function template-id named as a value (`&__thread_proxy<_Gp>') is the address of its instance, an enum's underlying type named through a dependent typedef is settled and the typedef OUTPUT (the lowering reads the enum's size through it; every `-std=c++20' program that stored into a std::atomic), a plain aggregate member from a braced default initializer built by a compound literal (std::mutex), a member template of a plain class defined out of its class emitted, a deferred instance whose base is still registering; 61 (0.117): the SysV register budget (a struct that does not fit the free registers goes wholly on the stack, declare, define and call alike), va_arg of a struct, a union, a complex and an __int128 expanded by the ABI, a VLA zeroed by `= {}', __int128 as i128, a folded wide constant as a global's initializer, a library function's pointer result a borrow of what its arguments borrow, `c ? 0 : p' a pointer (it was an int and truncated the address), an array member's element type resolved before its leaves are taken (`ir_leaves_': a struct with a `size_t __first_[2]' passed or assigned by value), `sizeof' and `_Static_assert' folded to one answer, the dynamic initialization of a scalar global and of a static local array in `$cpp_ginit'; 60 (0.115): a wide literal, or a pointer into one, as a global's constant (ir_wide_lit); 59 (0.112): a compound assignment's and an increment's place taken once, a reference result bound through a statement expression; 58 (0.112): a u"..." literal's surrogate pairs, the `imagl' constant, `dynamic_cast<void *>' through offset-to-top, `@llvm.global_ctors' for `$cpp_ginit', a pointer into a literal as a global's constant; 57 (0.112): a bitfield in a union read and written through its bits (ir_union_slot), a reference handed to a by-value aggregate parameter read through; 56 (0.112): a type's sign written once (a bool bitfield read unsigned, a scoped enum by its underlying type), a qualified data member through the base hops; 55 (0.112): an instance keyed by one spelling per integer type, a hex literal past 2^60 folded as hex, an enum no arithmetic type to the traits and its operators the program's, a captureless lambda's invoker, an init-capture a member; 54 (0.110): a virtual base reached through the table's vbase offset, a diamond's `.nv' paths as their data size of bytes, a global's braced list elided, a virtual base flagged in the type_info; 53 (0.110): a noexcept function guarded by a terminate handler that runs no cleanup, std::terminate; 52 (0.108): the coroutines (LLVM's switch-resumed intrinsics), RTTI and the Itanium vtable prefix, exceptions (invoke, landingpad), secondary vtables and thunks, the array cookie, tentative definitions, _Bool; 51 (0.108): long double as x86_fp80, float and floating global constants folded, va_arg and the va intrinsics, offsetof, anonymous members, designated global initializers normalized; 50 (0.104): the integer imaginary literal's real type from its suffix, a big one spelled whole; 49 (0.103): sizeof a string literal is its bytes; 48 (0.103): _Complex int, two integer components, the integer imaginary literal; 47 (0.101): the imaginary literal, Annex G's multiplication and division through the runtime's __muldc3 and __divdc3, the components as places; 46 (0.100): a function bound to a reference to a pointer converts into a materialized pointer temporary; 45 (0.100): a pointer to member function as the ABI's { ptr, adj }, C's complex types as two components; 44: the VLA's bounds kept in its type, a VLA of a VLA flat, _Alignas on an object, a wide string into an array with the rest zero, a data-member pointer as an offset, a null pointer to a base at an offset, the C11 atomic builtins and _Atomic objects atomic (0.99); 43: an empty `[[no_unique_address]]' member has no element and its address is the ABI's byte offset; 42: a conditional over two void arms has no phi
%% ccl_lowering_version(41).   % 41: a literal past 2^60 spelled whole; 40.   % 40: a base clause naming a bound type parameter takes its class, a scope name is the class's own typedef first (libc++ 18), -lc++ on Linux; 39: C23 (_BitInt as iN, the overflow builtins, unreachable), a VLA at run time, thread_local, the wide literals, [[assume]]; 38: a conditional over two lvalues is an lvalue, and its address the phi of theirs;  % 37: wchar_t, char16_t and char32_t have LLVM types, and a function template's shipped instance its Itanium symbol;  % 36: an rvalue prefers `T &&' where a TEMPLATE's candidate is judged (cpp_ref_rank), so std::get answers `int &&' and not `int &';  % 35: a CAST TO A REFERENCE converts from the operand's class to the cast's own target, so a reference or a pointer to a SECOND base is offset (ir_ref_to);  % 34: an empty class is one byte, an `alignas' one padded to its alignment, and a `[[no_unique_address]]' empty member a zero-sized element -- every struct's shape may move

ccl_ir_units(Units0, IR) :-
    ir_reset, ccl_scope_init, ir_note_units(Units0),                    % the symbol table, once
    (   ccl_lang(cpp)                                                    % C++ (M6): classes and kin desugared to the C below, over that table,
    ->  ( ccl_cpp_units(Units0, Units) -> true ; ir_fail(phase(desugaring)) ),   % each phase says its own name when it merely FAILS, or the driver can only say `without saying why'
        ccl_scope_init, ir_note_units(Units), ir_cpp_prelude              % then the table again from what came out; new and delete are malloc and free
    ;   Units = Units0 ),
    ( ccl_lang(cpp), catch(nb_getval('$cpp_eh_used', yes), _, fail) -> nb_setval('$ir_eh', yes) ; nb_setval('$ir_eh', no) ),   % a program that throws or catches lowers its calls under the EH rules (0.108)
    ir_cpp_trace(phase(check)),
    ( ccl_check_noted(Units) -> true ; ir_fail(phase(check)) ),          % the safe part first: a violation is a compile error
    nb_setval('$ir_fdefs', 0), nb_setval('$ir_gdefs', []), nb_setval('$ir_tent', []),               % a function's text is a global of its own, `'$ir_fdef:K'' (below): a list of every text so far was COPIED at each addition
    ir_drain_functions(Drains), ccl_items_note(Drains),                 % one drain per struct with an own array (below)
    ir_cpp_trace(phase(lowering)),
    ( ( ir_units(Units), ir_items(Drains) ) -> true ; ir_fail(phase(lowering)) ),
    ir_cpp_trace(phase(assemble)),
    ir_flush_tentatives, ir_assemble(IR).

%% C++ (M6): `new T' is malloc(sizeof(T)) and `delete p' free(p) -- declared
%% here when the file did not, so the check consumes at a delete as at a free
ir_cpp_prelude :-
    ( ccl_gdeclared(malloc, _) -> true ; ccl_gdeclare([malloc-fn(ptr([], base([], [void])), [param(base([], [unsigned, long]), size)], false)]) ),
    ( ccl_gdeclared(free, _) -> true ; ccl_gdeclare([free-fn(base([], [void]), [param(ptr([], base([], [void])), p)], false)]) ),
    ( ccl_gdeclared(calloc, _) -> true ; ccl_gdeclare([calloc-fn(ptr([], base([], [void])), [param(base([], [unsigned, long]), n), param(base([], [unsigned, long]), size)], false)]) ),   % `new T[n]()' is calloc's zeroed bytes (cpp_expr(new_array_init))
    ir_prelude_mem(memcpy), ir_prelude_mem(memmove), ir_prelude_mem(memset).      % what the memory builtins become (cpp_builtin_call), when the file declared none
ir_prelude_mem(N) :- ( ccl_gdeclared(N, _) -> true
    ; V = ptr([], base([], [void])), ccl_gdeclare([N-fn(V, [param(V, dst), param(V, src), param(base([], [unsigned, long]), n)], false)]) ).
ir_note_units([]).
ir_note_units([unit(Is)|Us]) :- ccl_items_note(Is), ir_note_units(Us).

ir_units([]).
ir_units([unit(Is)|Us]) :- ir_items(Is), ir_units(Us).
ir_items([]).
ir_items([I|Is]) :- ( catch(nb_getval('$cpp_trace', yes), _, fail) -> ir_item_name(I, W0), ir_mem(M), write(lower(W0, M)), nl, flush_output ; true ),   % under the C++ trace, each item as it is taken, with the heap and the store in KB: which one a silent runaway is in
    ( catch(\+ \+ ir_item(I), E, ir_item_error(I, E)) -> true ; ir_item_name(I, W), ir_fail(item(W)) ), ir_items(Is).   % INSIDE `\+ \+': an item's text goes to the globals, and every intermediate of its lowering is reclaimed (cocolog reclaims on backtracking and by nothing else)
%% the phases named under the C++ trace, so a run killed for its memory says which pass it was in
ir_cpp_trace(T) :- ( catch(nb_getval('$cpp_trace', yes), _, fail) -> ir_mem(M), write(T-M), nl, flush_output ; true ).
ir_mem(kb(G, S)) :- ( catch(( statistics(globalused, G0), statistics(store_used, S0) ), _, fail) -> G is G0 // 1024, S is S0 // 1024 ; G = 0, S = 0 ).   % cocolog 1.2.13's honest instrument (the process's RSS reads low on Darwin after a remap)
%% an error out of an item carries the ITEM with it, so a raw type_error says which one raised it
ir_item_error(I, error(not_lowered(X), Y)) :- !, ( catch(nb_getval('$cpp_trace', yes), _, fail) -> write(item_failed(X, I)), nl, flush_output ; true ), throw(error(not_lowered(X), Y)).   % under the C++ trace, the whole item: which local, which cast carried the type it could not take
ir_item_error(I, E) :- ir_item_name(I, W), ir_fail(item(W, raised(E))).
%% which item the lowering could not take, when it merely FAILS: its shape and its name, not the whole term
ir_item_name(function(_, _, _, N, _, _, B), function(N, BS)) :- !, ( B == none -> BS = none ; compound(B) -> functor(B, BF, BA), BS = BF/BA ; BS = B ).
ir_item_name(declaration(_, _, _, [var(N, _, _)|_]), declaration(N)) :- !.
ir_item_name(declare(_, base(_, [S])), declare(W)) :- !, ( S =.. [K, N|_] -> W = K/N ; W = S ).
ir_item_name(I, W) :- ( compound(I) -> functor(I, F, A), W = F/A ; W = I ).

%% ---- state -----------------------------------------------------------------------
ir_reset :-
    ccl_ensure_globals, ( once(catch(os_env('CCL_IR_TRACE', Tr), _, fail)), Tr \== '' -> nb_setval('$ir_trace', yes) ; nb_setval('$ir_trace', no) ),
    nb_setval('$ir_tcache', []), nb_setval('$ir_abicache', []), nb_setval('$ir_reg', 0), nb_setval('$ir_anons', []), nb_setval('$ir_fn', file), nb_setval('$ir_line', 0), nb_setval('$ir_ret', none), nb_setval('$ir_sret_into', none), nb_setval('$ir_body', []), nb_setval('$ir_allocas', []), nb_setval('$ir_term', no), nb_setval('$ir_env', [[]]), nb_setval('$ir_defers', [[]]), nb_setval('$ir_loops', []), nb_setval('$ir_strings', []), nb_setval('$ir_structs', []),
    nb_setval('$ir_externs', []), nb_setval('$ir_defined', []), nb_setval('$ir_gmap', []), nb_setval('$ir_ret_abi', scalar),
    nb_setval('$ir_maps', []), nb_setval('$ir_statics', 0),
    nb_setval('$ir_dbg_md', []), nb_setval('$ir_dbg_n', 5), nb_setval('$ir_dbg_sp', none), nb_setval('$ir_dbg_locs', []), nb_setval('$ir_fn_line', 0),
    nb_setval('$ir_dbg_types', []), nb_setval('$ir_dbg_globals', []), nb_setval('$ir_dbg_gvars', []), nb_setval('$ir_dbg_args', []), nb_setval('$ir_gline', 0), nb_setval('$ir_dbg_nss', []),
    nb_setval('$ir_dbg_prologue', no), nb_setval('$ir_dbg_scopes', []), nb_setval('$ir_dbg_top', no),
    ir_arch_init.
ir_get(K, V) :- nb_getval(K, V).                                       % every '$ir_*' key is set by ir_reset / ir_function
%% the host's architecture, once per process: sysv (x86-64) or aapcs (arm64)
ir_arch_init :-                                                                  % the module's compile-time arch (ccl_host_arch/1); uname only without it
    (   once(catch(nb_getval('$ir_arch', _), _, fail)) -> true
    ;   once(catch(ccl_host_arch(M0), _, fail)) -> ( M0 == arm64 -> A = aapcs ; A = sysv ), nb_setval('$ir_arch', A)
    ;   ( once(catch(proc_run('uname -m', 5000, Out, 0), _, fail)), ir_text_atom(Out, M), ( sub_atom(M, _, _, _, arm64) ; sub_atom(M, _, _, _, aarch64) ) -> A = aapcs ; A = sysv ),
        nb_setval('$ir_arch', A) ).
ir_text_atom(Out, A) :- ( atom(Out) -> A = Out ; is_list(Out) -> atom_codes(A, Out) ; A = '' ).
ir_arch(A) :- nb_getval('$ir_arch', A).
ir_fresh(R) :- nb_getval('$ir_reg', N), N1 is N + 1, nb_setval('$ir_reg', N1), atomic_list_concat(['%t', N1], R).
ir_label(L) :- nb_getval('$ir_reg', N), N1 is N + 1, nb_setval('$ir_reg', N1), atomic_list_concat(['L', N1], L).
ir_emit(Parts) :-
    ( ir_get('$ir_trace', yes) -> write('| '), write(Parts), nl ; true ),          % CCL_IR_TRACE=1: every line as it is emitted
    atomic_list_concat(Parts, Line), nb_getval('$ir_body', B), nb_setval('$ir_body', [Line|B]).
ir_terminated(T) :- nb_getval('$ir_term', T).
ir_set_term(T) :- nb_setval('$ir_term', T).
%% an instruction: a terminated block gets a fresh (dead) label first
ir_ins(Parts) :- ( ir_terminated(yes) -> ir_label(L), ir_emit([L, ':']), ir_set_term(no) ; true ), ir_dbg_parts(Parts, Parts1), ir_emit(['  '|Parts1]).
%% a terminator
ir_end(Parts) :- ( ir_terminated(yes) -> true ; ir_dbg_parts(Parts, Parts1), ir_emit(['  '|Parts1]), ir_set_term(yes) ).
%% a block starts: fall in from the block before unless it ended
ir_block(L) :- ( ir_terminated(yes) -> true ; ir_dbg_parts(['br label %', L], Br), ir_emit(['  '|Br]) ), ir_emit([L, ':']), ir_set_term(no).
%% DEBUG INFORMATION, LINE TABLES (`-g', 0.128): under the driver's `debug' option ('$ccl_debug' = file(Path)) a function the
%% program defines gets a DISubprogram and every instruction of its body a DILocation of the statement's line ('$ir_line',
%% the function's own line where none is set yet), the metadata gathered in '$ir_dbg_md' and spelled by ir_assemble. A
%% library function gets none: its lines are a header's, and the line table names one file. The locations are
%% one per line and function ('$ir_dbg_locs'). LLVM asks a location of every call in a function that has a
%% subprogram; every instruction here gets one.
ir_dbg_on(F) :- catch(nb_getval('$ccl_debug', file(F)), _, fail).
ir_dbg_full :- catch(nb_getval('$ccl_debug_kind', K), _, fail), K \== lines.                % the variables and the types (0.130): not under -gline-tables-only and -g1
%% ... but NO LOCATION IN THE PROLOGUE, where the parameters are stored (0.130), as clang has it: LLVM puts the prologue's end,
%% where a debugger stops at a breakpoint on the function, at the first instruction with a location, and a parameter read
%% there was not stored yet
ir_dbg_parts(Parts, Parts1) :- ( nb_getval('$ir_dbg_sp', sp(SP, L0)), \+ nb_getval('$ir_dbg_prologue', yes) -> ir_dbg_loc(SP, L0, M), atom_concat(', !dbg !', M, D), append(Parts, [D], Parts1) ; Parts1 = Parts ).
ir_dbg_loc(SP, L0, M) :- nb_getval('$ir_line', L1), ( integer(L1), L1 > 0 -> L = L1 ; L = L0 ), ir_dbg_scope(SP, Sc), ir_dbg_loc_at(L, Sc, M).
ir_dbg_loc_at(L, Sc, M) :- nb_getval('$ir_dbg_locs', Ls),
    ( memberchk(at(L, Sc, M0), Ls) -> M = M0 ; ir_dbg_next(M), atomic_list_concat(['!', M, ' = !DILocation(line: ', L, ', column: 1, scope: !', Sc, ')'], T), ir_dbg_md(T), nb_setval('$ir_dbg_locs', [at(L, Sc, M)|Ls]) ).
ir_dbg_next(N) :- nb_getval('$ir_dbg_n', N), N1 is N + 1, nb_setval('$ir_dbg_n', N1).
ir_dbg_md(T) :- nb_getval('$ir_dbg_md', Ms), nb_setval('$ir_dbg_md', [T|Ms]).
%% a function's subprogram: its name as the source spells it (C++'s qualified name, cpp_dbg_fn_name/2; this compiler's own
%% symbol is the ELF symbol's), its line, its type (the result and the parameters' types), the one file
ir_dbg_begin(Name, Line, Ret, Params, Att) :-
    (   ir_dbg_on(_), \+ catch(cpp_library_function(Name), _, fail)
    ->  ( integer(Line), Line > 0 -> L = Line ; L = 0 ),
        ir_dbg_fn_scope(Name, Src, Scope), ir_dbg_escape(Src, EN),
        ( ir_dbg_full -> ir_dbg_fn_type(Ret, Params, FT) ; FT = '!4' ), ir_dbg_next(SP),
        atomic_list_concat(['!', SP, ' = distinct !DISubprogram(name: "', EN, '", scope: ', Scope, ', file: !3, line: ', L, ', type: ', FT, ', scopeLine: ', L, ', flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !0)'], T),
        ir_dbg_md(T), nb_setval('$ir_dbg_sp', sp(SP, L)), nb_setval('$ir_dbg_locs', []), nb_setval('$ir_dbg_scopes', []), nb_setval('$ir_dbg_top', yes), atom_concat(' !dbg !', SP, Att)
    ;   nb_setval('$ir_dbg_sp', none), Att = '' ).
%% ... in C++ a method's scope is its class and its name the member's, a free function's scope its namespace (cpp_dbg_fn/2)
ir_dbg_fn_scope(Name, Src, Scope) :-
    (   ccl_lang(cpp), catch(cpp_dbg_fn(Name, D), _, fail)
    ->  (   D = member(C, Src), ir_dbg_class_ref(C, Scope) -> true
        ;   D = free(P, Src) -> ir_dbg_ns_ref(P, '!3', Scope)
        ;   Src = Name, Scope = '!3' )
    ;   Src = Name, Scope = '!3' ).
%% the type of a function: its result (`null' for void) and its parameters' types
ir_dbg_fn_type(Ret, Params, FT) :-
    findall(R, ( member(P, [param(Ret, '$ret')|Params]), arg(1, P, PT), ( catch(ir_dbg_type(PT, R0), _, fail) -> R = R0 ; R = null ) ), Rs0),
    ( Rs0 = [_|_] -> Rs = Rs0 ; Rs = [null] ), atomic_list_concat(Rs, ', ', RJ), ir_dbg_next(K),
    atomic_list_concat(['!', K, ' = !DISubroutineType(types: !{', RJ, '})'], T), ir_dbg_md(T), atom_concat('!', K, FT).
%% THE LEXICAL BLOCKS (0.130): a block of statements is a `DILexicalBlock' inside the scope around it, which its variables and
%% its instructions' locations name -- but the function's own body, whose scope is the subprogram ('$ir_dbg_top')
ir_dbg_scope(SP, Sc) :- ( nb_getval('$ir_dbg_scopes', [Sc0|_]) -> Sc = Sc0 ; Sc = SP ).
ir_dbg_block_enter(Is) :-
    (   nb_getval('$ir_dbg_sp', sp(SP, L0))
    ->  nb_getval('$ir_dbg_scopes', Ss),
        (   nb_getval('$ir_dbg_top', yes) -> nb_setval('$ir_dbg_top', no), nb_setval('$ir_dbg_scopes', [SP|Ss])
        ;   ( ir_dbg_first_line(Is, L) -> true ; nb_getval('$ir_line', L1), ( integer(L1), L1 > 0 -> L = L1 ; L = L0 ) ),
            ir_dbg_scope(SP, P), ir_dbg_next(B),
            atomic_list_concat(['!', B, ' = distinct !DILexicalBlock(scope: !', P, ', file: !3, line: ', L, ', column: 1)'], T), ir_dbg_md(T),
            nb_setval('$ir_dbg_scopes', [B|Ss]) )
    ;   true ).
ir_dbg_block_leave :- ( nb_getval('$ir_dbg_sp', sp(_, _)), nb_getval('$ir_dbg_scopes', [_|Ss]) -> nb_setval('$ir_dbg_scopes', Ss) ; true ).
ir_dbg_first_line([S|_], L) :- compound(S), arg(1, S, L), integer(L), L > 0, !.
ir_dbg_first_line([_|Ss], L) :- ir_dbg_first_line(Ss, L).
ir_dbg_escape(N, E) :- atom_codes(N, Cs), ir_dbg_esc(Cs, Es), atom_codes(E, Es).
ir_dbg_esc([], []).
ir_dbg_esc([C|Cs], Es) :- ( ( C =:= 34 ; C =:= 92 ) -> Es = [92, C|Es1] ; Es = [C|Es1] ), ir_dbg_esc(Cs, Es1).
%% THE VARIABLES (0.130): every named local and parameter of a function with a subprogram is a `DILocalVariable' of the scope it
%% is declared in, declared at its place by `llvm.dbg.declare' (ir_local/3, which every local and parameter passes through; a
%% parameter carries its number, `this' the flags of the object pointer); every global the program defines is a
%% `DIGlobalVariableExpression' on its definition, which the compile unit lists, and a static local one in its function's
%% scope. A name the compiler made (`$tmp1', `$ret') is not described. The declaration has the variable's line (a parameter's,
%% the function's), its own location even in the prologue.
ir_dbg_var(_, _, Addr) :- sub_atom(Addr, 0, 1, _, '@'), !.                  % a static local: described as a global (ir_dbg_static_local)
ir_dbg_var(N, T, Addr) :-
    (   nb_getval('$ir_dbg_sp', sp(SP, L0)), ir_dbg_full, atom(N), \+ sub_atom(N, 0, 1, _, '$'), catch(ir_dbg_type(T, TI), _, fail)
    ->  nb_getval('$ir_line', L1), ( integer(L1), L1 > 0 -> L = L1 ; L = L0 ),
        ( nb_getval('$ir_dbg_args', As), memberchk(N-K, As) -> atomic_list_concat([', arg: ', K], ArgT) ; ArgT = '' ),
        ( N == this -> FlT = ', flags: DIFlagArtificial | DIFlagObjectPointer' ; FlT = '' ),
        ir_dbg_scope(SP, Sc), ir_dbg_next(V), ir_dbg_escape(N, EN),
        atomic_list_concat(['!', V, ' = !DILocalVariable(name: "', EN, '"', ArgT, ', scope: !', Sc, ', file: !3, line: ', L, ', type: ', TI, FlT, ')'], Text), ir_dbg_md(Text),
        ir_dbg_loc_at(L, Sc, M),
        ir_note_extern('llvm.dbg.declare', raw('declare void @llvm.dbg.declare(metadata, metadata, metadata)')),
        ( ir_terminated(yes) -> ir_label(Lb), ir_emit([Lb, ':']), ir_set_term(no) ; true ),
        ir_emit(['  call void @llvm.dbg.declare(metadata ptr ', Addr, ', metadata !', V, ', metadata !DIExpression()), !dbg !', M])
    ;   true ).
ir_dbg_global(N, T, Att) :-
    (   ir_dbg_on(_), ir_dbg_full, atom(N), \+ sub_atom(N, 0, 1, _, '$'), ir_dbg_global_scope(N, Src, Scope), catch(ir_dbg_type(T, TI), _, fail)
    ->  (   nb_getval('$ir_dbg_gvars', Gv), memberchk(N-E0, Gv) -> E = E0             % a tentative definition and the definition: one variable
        ;   nb_getval('$ir_gline', L),
            ir_dbg_next(G), ir_dbg_next(E), ir_dbg_escape(Src, EN),
            atomic_list_concat(['!', G, ' = distinct !DIGlobalVariable(name: "', EN, '", scope: ', Scope, ', file: !3, line: ', L, ', type: ', TI, ', isLocal: false, isDefinition: true)'], GT), ir_dbg_md(GT),
            atomic_list_concat(['!', E, ' = !DIGlobalVariableExpression(var: !', G, ', expr: !DIExpression())'], ET), ir_dbg_md(ET),
            nb_getval('$ir_dbg_globals', Gs), nb_setval('$ir_dbg_globals', [E|Gs]), nb_getval('$ir_dbg_gvars', Gv1), nb_setval('$ir_dbg_gvars', [N-E|Gv1]) ),
        atom_concat(', !dbg !', E, Att)
    ;   Att = '' ).
%% ... in C++ a static data member is `Class::name' in its class's namespace (gdb reads `ns::Class::name' so), a namespace's
%% global its name in its namespace, and a global no rule answers (a table, a type's information) is not described
ir_dbg_global_scope(N, N, '!0') :- \+ ccl_lang(cpp), !.
ir_dbg_global_scope(N, Src, Scope) :- catch(cpp_dbg_global(N, D), _, fail),
    (   D = member(C, M) -> catch(cpp_dbg_class_path(C, P, Chain), _, fail), append(Chain, [M], Ss), atomic_list_concat(Ss, '::', Src), ir_dbg_ns_ref(P, '!0', Scope)
    ;   D = free(P, Src), ir_dbg_ns_ref(P, '!0', Scope) ).
%% a namespace's `DINamespace', made once per path
ir_dbg_ns_ref([], D, D) :- !.
ir_dbg_ns_ref(P, _, Ref) :- nb_getval('$ir_dbg_nss', Ns),
    (   memberchk(P-Ref0, Ns) -> Ref = Ref0
    ;   append(P0, [Last], P), ir_dbg_ns_ref(P0, null, Parent), ir_dbg_next(K), atom_concat('!', K, Ref), ir_dbg_escape(Last, EL),
        atomic_list_concat([Ref, ' = !DINamespace(name: "', EL, '", scope: ', Parent, ')'], T), ir_dbg_md(T),
        nb_getval('$ir_dbg_nss', Ns1), nb_setval('$ir_dbg_nss', [P-Ref|Ns1]) ).
%% a class's type, by its name
ir_dbg_class_ref(C, Ref) :- atom(C), catch(ccl_resolve_type(base([], [typedef(C)]), R), _, fail), R = base(_, [X]), compound(X), functor(X, F, _), memberchk(F, [struct, union]),
    ir_dbg_type(R, Ref), Ref \== null.
ir_dbg_static_local(N, T, Att) :-
    (   nb_getval('$ir_dbg_sp', sp(SP, L0)), ir_dbg_full, atom(N), \+ sub_atom(N, 0, 1, _, '$'), catch(ir_dbg_type(T, TI), _, fail)
    ->  nb_getval('$ir_line', L1), ( integer(L1), L1 > 0 -> L = L1 ; L = L0 ), ir_dbg_scope(SP, Sc), ir_dbg_next(G), ir_dbg_next(E), ir_dbg_escape(N, EN),
        atomic_list_concat(['!', G, ' = distinct !DIGlobalVariable(name: "', EN, '", scope: !', Sc, ', file: !3, line: ', L, ', type: ', TI, ', isLocal: true, isDefinition: true)'], GT), ir_dbg_md(GT),
        atomic_list_concat(['!', E, ' = !DIGlobalVariableExpression(var: !', G, ', expr: !DIExpression())'], ET), ir_dbg_md(ET),
        nb_getval('$ir_dbg_globals', Gs), nb_setval('$ir_dbg_globals', [E|Gs]), atom_concat(', !dbg !', E, Att)
    ;   Att = '' ).
%% THE TYPES (0.130), DWARF's from the C types, each described once per module ('$ir_dbg_types', keyed by the type, a tag by
%% its kind and name, so `struct point' named through a pointer and through a typedef is one type): the base types by their
%% encoding, pointers, references, cv, typedefs, arrays, structs, unions and classes with their members at their bit offsets
%% (a bitfield flagged, a base sub-object an inheritance, an anonymous member unnamed), enums with their enumerators. A
%% type's number is taken BEFORE its members are described, so a struct that points to itself names its own number; a type
%% with no description here is described by its size alone.
ir_dbg_type(T, Ref) :- ir_dbg_key(T, K), nb_getval('$ir_dbg_types', Ts), ( memberchk(K-Ref0, Ts) -> Ref = Ref0 ; ir_dbg_type_new(T, K, Ref) ).
ir_dbg_key(base(Q, [S]), tag(F, N, Cv)) :- compound(S), functor(S, F, _), memberchk(F, [struct, union, enum, enum_class]), arg(1, S, N), atom(N), N \== anon, !, ir_dbg_cv(Q, Cv).
ir_dbg_key(base(Q, [typedef(N)]), K) :- atom(N), !, ir_dbg_cv(Q, Cv),   % C++'s class name: its tag, one type
    ( catch(ccl_resolve_type(base([], [typedef(N)]), base(_, [X])), _, fail), compound(X), functor(X, F, _), memberchk(F, [struct, union, enum, enum_class]), arg(1, X, N) -> K = tag(F, N, Cv) ; K = typedef(N, Cv) ).
ir_dbg_key(T, T).
ir_dbg_cv(Q, Cv) :- findall(X, ( member(X, [const, volatile]), memberchk(X, Q) ), Cv).
ir_dbg_type_new(T, K, Ref) :-
    (   ccl_resolve_type(T, base(Q, [void])), ir_dbg_cv(Q, []) -> Ref = null, ir_dbg_type_keep(K, Ref)
    ;   ir_dbg_next(N), atom_concat('!', N, Ref), ir_dbg_type_keep(K, Ref),
        ( catch(ir_dbg_type_text(T, Ref, Text), _, fail) -> true ; ir_dbg_sized(T, Ref, Text) ), ir_dbg_md(Text) ).
ir_dbg_type_keep(K, Ref) :- nb_getval('$ir_dbg_types', Ts), nb_setval('$ir_dbg_types', [K-Ref|Ts]).
ir_dbg_sized(T, Ref, Text) :- ( catch(ccl_size_of(T, B), _, fail), integer(B) -> Bits is B * 8 ; Bits = 0 ),
    atomic_list_concat([Ref, ' = !DIBasicType(name: "?", size: ', Bits, ', encoding: DW_ATE_unsigned)'], Text).
ir_dbg_type_text(base(Q, S), Ref, Text) :- ( memberchk(const, Q) ; memberchk(volatile, Q) ), !,
    ( memberchk(const, Q) -> Tag = 'DW_TAG_const_type', ir_dbg_drop(Q, const, Q1) ; Tag = 'DW_TAG_volatile_type', ir_dbg_drop(Q, volatile, Q1) ),
    ir_dbg_type(base(Q1, S), B), atomic_list_concat([Ref, ' = !DIDerivedType(tag: ', Tag, ', baseType: ', B, ')'], Text).
ir_dbg_type_text(base(_, [typedef(N)]), Ref, Text) :- atom(N), ccl_resolve_type(base([], [typedef(N)]), R), R \= base(_, [typedef(_)]),
    \+ ( R = base(_, [X]), compound(X), arg(1, X, N) ), !,                                         % C++'s class name is its class, never a typedef of it
    ir_dbg_type(R, B), ir_dbg_escape(N, EN), atomic_list_concat([Ref, ' = !DIDerivedType(tag: DW_TAG_typedef, name: "', EN, '", file: !3, baseType: ', B, ')'], Text).
ir_dbg_type_text(ptr(_, E), Ref, Text) :- !, ( ccl_resolve_type(E, fn(_, _, _)) -> B = '!4' ; ir_dbg_type(E, B) ),
    atomic_list_concat([Ref, ' = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: ', B, ', size: 64)'], Text).
ir_dbg_type_text(ref(_, E), Ref, Text) :- !, ir_dbg_type(E, B), atomic_list_concat([Ref, ' = !DIDerivedType(tag: DW_TAG_reference_type, baseType: ', B, ', size: 64)'], Text).
ir_dbg_type_text(rref(_, E), Ref, Text) :- !, ir_dbg_type(E, B), atomic_list_concat([Ref, ' = !DIDerivedType(tag: DW_TAG_rvalue_reference_type, baseType: ', B, ', size: 64)'], Text).
ir_dbg_type_text(arr(int(K), E), Ref, Text) :- integer(K), !, ir_dbg_type(E, B), ( catch(ccl_size_of(E, ES), _, fail), integer(ES) -> Bits is K * ES * 8 ; Bits = 0 ),
    ir_dbg_next(SR), atomic_list_concat(['!', SR, ' = !DISubrange(count: ', K, ')'], ST), ir_dbg_md(ST),
    atomic_list_concat([Ref, ' = !DICompositeType(tag: DW_TAG_array_type, baseType: ', B, ', size: ', Bits, ', elements: !{!', SR, '})'], Text).
ir_dbg_type_text(base(_, [struct(Tag, Ms0)]), Ref, Text) :- ir_dbg_tag_members(Tag, Ms0, Ms), !, ir_dbg_composite(struct, Tag, Ms, Ref, Text).
ir_dbg_type_text(base(_, [union(Tag, Ms0)]), Ref, Text) :- ir_dbg_tag_members(Tag, Ms0, Ms), !, ir_dbg_composite(union, Tag, Ms, Ref, Text).
ir_dbg_type_text(base(_, [E]), Ref, Text) :- compound(E), ccl_enum_spec_members(E, Ms0), arg(1, E, Tag), ir_dbg_tag_members(Tag, Ms0, Ms), !,
    ( atom(Tag), Tag \== anon -> ir_dbg_tag_scope(Tag, TN, ScT), ir_dbg_escape(TN, EN), atomic_list_concat([', name: "', EN, '"', ScT], NameT0) ; NameT0 = '' ),
    ( ( functor(E, enum_class, _) ; catch(ccl_scoped_enum(Tag), _, fail) ) -> atom_concat(NameT0, ', flags: DIFlagEnumClass', NameT) ; NameT = NameT0 ),
    findall(I, ( member(enumerator(EN0, _), Ms), atom(EN0), catch(ccl_enum_value(EN0, V0), _, fail), integer(V0), ir_dbg_next(I), ir_dbg_escape(EN0, EE), atomic_list_concat(['!', I, ' = !DIEnumerator(name: "', EE, '", value: ', V0, ')'], IT), ir_dbg_md(IT) ), Is),
    ( Is == [] -> Els = '!{}' ; atomic_list_concat(Is, ', !', IJ), atomic_list_concat(['!{!', IJ, '}'], Els) ),
    ( memberchk(enum_base(UT), Ms) -> true ; UT = base([], [int]) ), ir_dbg_type(UT, IB), ( catch(ccl_size_of(UT, UB), _, fail), integer(UB) -> UBits is UB * 8 ; UBits = 32 ),
    atomic_list_concat([Ref, ' = !DICompositeType(tag: DW_TAG_enumeration_type', NameT, ', file: !3, size: ', UBits, ', baseType: ', IB, ', elements: ', Els, ')'], Text).
ir_dbg_type_text(T, Ref, Text) :- ccl_resolve_type(T, R), R \== T, !, ir_dbg_type_text(R, Ref, Text).   % a typedef that names no type of its own, a template-id's instance: the type it is
ir_dbg_type_text(base(_, S), Ref, Text) :- ccl_size_of(base([], S), B), integer(B), Bits is B * 8, ir_dbg_encoding(base([], S), Enc), ir_dbg_base_name(S, Name),
    atomic_list_concat([Ref, ' = !DIBasicType(name: "', Name, '", size: ', Bits, ', encoding: ', Enc, ')'], Text).
ir_dbg_drop(Q, X, Q1) :- findall(Y, ( member(Y, Q), Y \== X ), Q1).
%% a tag's members: the ones written in the type term, else the tag table's (a struct named by its tag alone: `struct point *')
ir_dbg_tag_members(_, Ms, Ms) :- is_list(Ms), !.
ir_dbg_tag_members(Tag, _, Ms) :- atom(Tag), Tag \== anon, catch(( ccl_tag(Tag, Ms0), ccl_tag_type(Tag, Ms0, [], base(_, [X])), functor(X, _, 2), arg(2, X, Ms) ), _, fail), is_list(Ms).
%% a tag's name and scope: in C++ its own name in its namespace or in the class that holds it (cpp_dbg_class_path/3)
ir_dbg_tag_scope(Tag, Name, ScT) :-
    (   ccl_lang(cpp), catch(cpp_dbg_class_path(Tag, P, Chain), _, fail), ccl_last(Chain, Name0)
    ->  Name = Name0,
        (   Chain = [_, _|_], catch(cpp_dbg_holder_tag(Tag, E), _, fail), ir_dbg_class_ref(E, ER) -> atom_concat(', scope: ', ER, ScT)
        ;   ir_dbg_ns_ref(P, none, NR), NR \== none -> atom_concat(', scope: ', NR, ScT)
        ;   ScT = '' )
    ;   Name = Tag, ScT = '' ).
ir_dbg_composite(Kind, Tag, Ms, Ref, Text) :-
    ( Kind == union -> TagKind = 'DW_TAG_union_type' ; TagKind = 'DW_TAG_structure_type' ),
    ( atom(Tag), Tag \== anon, \+ sub_atom(Tag, 0, 1, _, '$') -> ir_dbg_tag_scope(Tag, TN, ScT), ir_dbg_escape(TN, EN), atomic_list_concat([', name: "', EN, '"', ScT], NameT) ; NameT = '' ),
    Spec =.. [Kind, Tag, Ms], ( catch(ccl_size_of(base([], [Spec]), B), _, fail), integer(B) -> Bits is B * 8 ; Bits = 0 ),
    (   Kind == union -> ir_dbg_union_members(Ms, Ref, Is)
    ;   catch(ccl_members_layout(Ms, Lays, _, _), _, fail) -> ir_dbg_members(Lays, Ref, Is)
    ;   Is = [] ),
    ( Is == [] -> Els = '!{}' ; atomic_list_concat(Is, ', !', IJ), atomic_list_concat(['!{!', IJ, '}'], Els) ),
    atomic_list_concat([Ref, ' = distinct !DICompositeType(tag: ', TagKind, NameT, ', file: !3, size: ', Bits, ', elements: ', Els, ')'], Text).
%% a member's kind: a base sub-object (`$base', `$base$2' ...) is an inheritance, an anonymous member (`$anonK') a member with no
%% name, the table pointer and the other names the compiler made are not described
ir_dbg_member_kind(N, base) :- sub_atom(N, 0, 5, _, '$base'), !.
ir_dbg_member_kind(N, anon) :- ( sub_atom(N, 0, 5, _, '$anon') ; N == anon ), !.
ir_dbg_member_kind(N, named) :- \+ sub_atom(N, 0, 1, _, '$').
ir_dbg_members([], _, []).
ir_dbg_members([lay(N, T, Off, Bits)|Ls], Scope, Is) :-
    (   atom(N), Bits \== empty, ir_dbg_member_kind(N, Kind), catch(ir_dbg_type(T, TI), _, fail)
    ->  ir_dbg_next(I), ir_dbg_member_text(Kind, I, N, T, TI, Off, Bits, Scope, MT), ir_dbg_md(MT), Is = [I|Is1]
    ;   Is = Is1 ),
    ir_dbg_members(Ls, Scope, Is1).
ir_dbg_member_text(base, I, _, _, TI, Off, _, Scope, MT) :- !, OffBits is Off * 8,
    atomic_list_concat(['!', I, ' = !DIDerivedType(tag: DW_TAG_inheritance, scope: ', Scope, ', baseType: ', TI, ', offset: ', OffBits, ', flags: DIFlagPublic)'], MT).
ir_dbg_member_text(Kind, I, N, T, TI, Off, Bits, Scope, MT) :-
    ( Kind == named -> ir_dbg_escape(N, EN), atomic_list_concat([' name: "', EN, '",'], NameT) ; NameT = '' ),
    (   Bits = bits(BO, W, _) -> OffBits is Off * 8 + BO, Store is Off * 8, atomic_list_concat([', size: ', W, ', offset: ', OffBits, ', flags: DIFlagBitField, extraData: i64 ', Store], SzT)
    ;   ( catch(ccl_size_of(T, SB), _, fail), integer(SB) -> S8 is SB * 8 ; S8 = 0 ), OffBits is Off * 8, atomic_list_concat([', size: ', S8, ', offset: ', OffBits], SzT) ),
    atomic_list_concat(['!', I, ' = !DIDerivedType(tag: DW_TAG_member,', NameT, ' scope: ', Scope, ', file: !3, baseType: ', TI, SzT, ')'], MT).
ir_dbg_union_members([], _, []).
ir_dbg_union_members([M|Ms], Scope, Is) :-
    (   M = member(T, N, _), atom(N), ir_dbg_member_kind(N, Kind), Kind \== base, catch(ir_dbg_type(T, TI), _, fail)
    ->  ir_dbg_next(I), ir_dbg_member_text(Kind, I, N, T, TI, 0, none, Scope, MT), ir_dbg_md(MT), Is = [I|Is1]
    ;   Is = Is1 ),
    ir_dbg_union_members(Ms, Scope, Is1).
ir_dbg_encoding(T, E) :- ccl_resolve_type(T, base(_, S)),
    (   ( memberchk(bool, S) ; memberchk('_Bool', S) ) -> E = 'DW_ATE_boolean'
    ;   memberchk('_Complex', S) -> E = 'DW_ATE_complex_float'
    ;   catch(ccl_decimal_spec(S, _), _, fail) -> E = 'DW_ATE_decimal_float'
    ;   ( memberchk(double, S) ; memberchk(float, S) ; memberchk('_Float16', S) ) -> E = 'DW_ATE_float'
    ;   ( memberchk(char8_t, S) ; memberchk(char16_t, S) ; memberchk(char32_t, S) ) -> E = 'DW_ATE_UTF'
    ;   memberchk(char, S) -> ( memberchk(unsigned, S) -> E = 'DW_ATE_unsigned_char' ; E = 'DW_ATE_signed_char' )
    ;   ir_signed(T) -> E = 'DW_ATE_signed'
    ;   E = 'DW_ATE_unsigned' ).
ir_dbg_base_name(S, Name) :- findall(W, ( member(X, S), ( atom(X) -> W = X ; X = bitint(int(K)) -> atomic_list_concat(['_BitInt(', K, ')'], W) ; fail ) ), Ws), ( Ws == [] -> Name = '?' ; atomic_list_concat(Ws, ' ', Name) ).
%% the module's own: the compile unit over the one file, the two flags LLVM asks, the type every subprogram shares
ir_dbg_module(Lines) :-
    (   ir_dbg_on(F)
    ->  ( ccl_lang(cpp) -> Lang = 'DW_LANG_C_plus_plus_14' ; Lang = 'DW_LANG_C11' ), ( catch(ccl_version(V0), _, fail) -> V = V0 ; V = '' ),
        ( sub_atom(F, B, 1, _, '/'), \+ ( sub_atom(F, B2, 1, _, '/'), B2 > B ) -> sub_atom(F, 0, B, _, Dir0), B1 is B + 1, sub_atom(F, B1, _, 0, Base) ; Dir0 = '.', Base = F ),
        ( Dir0 == '' -> Dir = '/' ; Dir = Dir0 ), ir_dbg_escape(Base, EBase), ir_dbg_escape(Dir, EDir),
        nb_getval('$ir_dbg_globals', GVs0), reverse(GVs0, GVs), ( GVs == [] -> GT = '' ; atomic_list_concat(GVs, ', !', GJ), atomic_list_concat([', globals: !{!', GJ, '}'], GT) ),
        ( ir_dbg_full -> EK = 'FullDebug' ; EK = 'LineTablesOnly' ),
        atomic_list_concat(['!0 = distinct !DICompileUnit(language: ', Lang, ', file: !3, producer: "cicilang ', V, '", isOptimized: false, runtimeVersion: 0, emissionKind: ', EK, GT, ', nameTableKind: None)'], CU),
        atomic_list_concat(['!3 = !DIFile(filename: "', EBase, '", directory: "', EDir, '")'], FL),
        nb_getval('$ir_dbg_md', Ms0), reverse(Ms0, Ms),
        Lines = ['', '!llvm.dbg.cu = !{!0}', '!llvm.module.flags = !{!1, !2}', CU, '!1 = !{i32 7, !"Dwarf Version", i32 5}', '!2 = !{i32 2, !"Debug Info Version", i32 3}', FL, '!4 = !DISubroutineType(types: !{null})'|Ms]
    ;   Lines = [] ).
ir_alloca(R, LL) :- nb_getval('$ir_allocas', A), atomic_list_concat(['  ', R, ' = alloca ', LL], Line), nb_setval('$ir_allocas', [Line|A]).
ir_alloca_aligned(R, LL, Al) :- nb_getval('$ir_allocas', A), atomic_list_concat(['  ', R, ' = alloca ', LL, ', align ', Al], Line), nb_setval('$ir_allocas', [Line|A]).
%% a temporary for a struct crossing a call, over-aligned so every piece's load and store is aligned
ir_tmp(LL, Tmp) :- ir_fresh(Tmp), ir_alloca_aligned(Tmp, LL, 16).
ir_store_at(PL, V, Addr, 0) :- !, ir_ins(['store ', PL, ' ', V, ', ptr ', Addr]).
ir_store_at(PL, V, Addr, Off) :- ir_fresh(G), ir_ins([G, ' = getelementptr inbounds i8, ptr ', Addr, ', i64 ', Off]), ir_ins(['store ', PL, ' ', V, ', ptr ', G]).
ir_load_at(PL, Addr, 0, V) :- !, ir_fresh(V), ir_ins([V, ' = load ', PL, ', ptr ', Addr]).
ir_load_at(PL, Addr, Off, V) :- ir_fresh(G), ir_ins([G, ' = getelementptr inbounds i8, ptr ', Addr, ', i64 ', Off]), ir_fresh(V), ir_ins([V, ' = load ', PL, ', ptr ', G]).
ir_where(where(F, line(L))) :- nb_getval('$ir_fn', F), nb_getval('$ir_line', L).
ir_fail(What) :- ir_where(W), throw(error(not_lowered(What), W)).


%% ---- the environment: locals in frames, then the globals, then the table ------------
ir_env_push :- nb_getval('$ir_env', E), nb_setval('$ir_env', [[]|E]), nb_getval('$ir_defers', D), nb_setval('$ir_defers', [[]|D]), ccl_scope_push.
ir_env_pop :- nb_getval('$ir_env', [_|E]), nb_setval('$ir_env', E), nb_getval('$ir_defers', [_|D]), nb_setval('$ir_defers', D), ccl_scope_pop.
ir_local(N, T, Addr) :- nb_getval('$ir_env', [F|E]), nb_setval('$ir_env', [[N-loc(Addr, T)|F]|E]), ccl_declare(N, T), ir_dbg_var(N, T, Addr).
ir_lookup(N, loc(Addr, T)) :- nb_getval('$ir_env', E), ir_in_frames(E, N, loc(Addr, T)), !.
ir_lookup(N, loc(Addr, T)) :- nb_getval('$ir_gmap', G), memberchk(N-T, G), !, atom_concat('@', N, Addr).
ir_lookup(N, loc(Addr, T)) :- ccl_declared(N, T), !, atom_concat('@', N, Addr), ir_note_extern(N, T).
ir_in_frames([F|Fs], N, L) :- ( memberchk(N-L0, F) -> L = L0 ; ir_in_frames(Fs, N, L) ).
ir_note_extern(N, T) :- nb_getval('$ir_externs', Es), ( memberchk(N-_, Es) -> true ; nb_setval('$ir_externs', [N-T|Es]) ).
ir_defer_push(Body) :- nb_getval('$ir_defers', [F|D]), nb_setval('$ir_defers', [[Body|F]|D]).
%% run the defers of the innermost K frames (all, for a return), each frame LIFO
ir_run_defers(all) :- !, nb_getval('$ir_defers', D), ir_run_frames(D).
ir_run_defers(K) :- nb_getval('$ir_defers', D), ir_take(K, D, Fs), ir_run_frames(Fs).
ir_run_frames([]).
ir_run_frames([F|Fs]) :- ir_run_bodies(F), ir_run_frames(Fs).
ir_run_bodies([]).
ir_run_bodies([B|Bs]) :- ir_stmt(B), ir_run_bodies(Bs).
ir_take(0, _, []) :- !.
ir_take(_, [], []) :- !.
ir_take(K, [F|Fs], [F|Gs]) :- K1 is K - 1, ir_take(K1, Fs, Gs).
ir_depth(K) :- nb_getval('$ir_defers', D), length(D, K).

%% ---- types -------------------------------------------------------------------------
ir_type(T, LL) :- ccl_cached('$ir_tcache', T, LL, ir_type_nocache(T, LL)).      % asked 2300 times for 170 lines: kept per type term
ir_type_nocache(T, LL) :- ccl_resolve_type(T, T1), ir_type_(T1, LL).
ir_type_(base(_, S), LL) :- !, ir_base(S, LL).
ir_type_(ptr(_, _), ptr) :- !.
ir_type_(ref(_, _), ptr) :- !.                                           % C++: a reference is a pointer in memory
ir_type_(rref(_, _), ptr) :- !.
ir_type_(block(_, _), ptr) :- !.
ir_type_(fn(_, _, _), ptr) :- !.
ir_type_(memptr(_, _, F), '{ ptr, i64 }') :- ccl_resolve_type(F, fn(_, _, _)), !.   % A POINTER TO MEMBER FUNCTION IS `{ ptr, adj }' (0.100), the Itanium ABI's 16 bytes: the function's address, or 1 + the slot's byte offset for a virtual one; the desugaring reads `.ptr' and tests the bit (cpp_memptr_call)                           % A POINTER TO MEMBER FUNCTION IS THE ADDRESS of the function this compiler emits for that method, whose first parameter is the object
ir_type_(memptr(_, _, _), i64) :- !.                                      % a pointer to a DATA member: its byte offset (0.99)
ir_type_(arr(NE, E), LL) :- !, ir_type(E, EL), ( ccl_const_eval(NE, N) -> true ; N = 0 ), atomic_list_concat(['[', N, ' x ', EL, ']'], LL).   % a flexible member: [0 x T]
ir_type_(T, _) :- ir_fail(type(T)).
ir_base(S, void) :- memberchk(void, S), !.
ir_base(S, LL) :- memberchk('_Complex', S), !, ccl_complex_real(base([], S), R), ir_type(R, E), atomic_list_concat(['{ ', E, ', ', E, ' }'], LL).   % C's complex types: two components (0.100); `{ i32, i32 }' for a `_Complex int' (0.103)
ir_base(S, LL) :- memberchk(double, S), memberchk(long, S), !, ( ccl_long_double(x87) -> LL = x86_fp80 ; ccl_long_double(quad) -> LL = fp128 ; LL = double ).   % an IEEE quad on Linux aarch64 (0.131)   % LONG DOUBLE IS x87's 80-BIT TYPE on x86-64 (0.108), sixteen bytes aligned sixteen, as the SysV ABI and glibc have it; a double elsewhere
ir_base(S, double) :- memberchk(double, S), !.
ir_base(S, float) :- memberchk(float, S), !.
ir_base(S, half) :- memberchk('_Float16', S), !.
ir_base(S, LL) :- memberchk(bitint(E), S), !, ccl_bitint_width(E, W), atom_concat(i, W, LL).   % C23's _BitInt(N) is LLVM's iN, exactly
ir_base(S, LL) :- ccl_decimal_spec(S, K), !, ir_dec_ll(K, LL).   % C23's decimal floating types (0.129): carried as float, double, fp128 (below)
ir_base(S, i128) :- memberchk('__int128', S), !.   % GNU's 128-bit integer (0.117): LLVM's own i128, sixteen bytes aligned sixteen
ir_base(S, i8) :- ( memberchk(char, S) ; memberchk('_Bool', S) ; memberchk(bool, S) ; memberchk(char8_t, S) ), !.   % C++'s bool: a byte in memory, as clang has it; char8_t too
ir_base(S, i16) :- ( memberchk(short, S) ; memberchk(char16_t, S) ), !.
ir_base(S, i32) :- ( memberchk(wchar_t, S) ; memberchk(char32_t, S) ), !.   % LP64: wchar_t is four bytes and signed, char32_t four and unsigned -- libc++'s __find of an int goes through __constexpr_wmemchr
ir_base(S, i64) :- memberchk(long, S), !.
ir_base(S, i32) :- ( memberchk(int, S) ; memberchk(unsigned, S) ; memberchk(signed, S) ), !.
ir_base([enum(_, [enum_base(T)|_])], LL) :- !, ir_type(T, LL).   % `enum E : size_t' is an i64, and a conversion to size_t is none
ir_base([enum(_, _)], i32) :- !.
ir_base([enum_class(_, _)], i32) :- !.
ir_base([class(_, N, _, _)], _) :- !, ir_fail(class(N)).                 % M6's next step
ir_base(S, _) :- memberchk(auto, S), !, ir_fail(auto).
ir_base([struct(Tag, Ms)], LL) :- !, ir_struct(Tag, Ms, LL).
%% a union is a scalar of its alignment (so it lies where C puts it) padded
%% to its size; every member is read and written at its address
ir_base([union(Tag, Ms0)], LL) :- !,
    ( Ms0 == none -> ( ccl_tag(Tag, Ms) -> true ; ir_fail(union(Tag)) ) ; Ms = Ms0 ),
    ccl_union_layout(Ms, 0, 1, N, A), ir_union_type(N, A, LL).
ir_base([typedef(N)], _) :- !, ir_fail(typedef(N)).
ir_base(S, _) :- ir_fail(specs(S)).
ir_union_type(N, A, LL) :-
    ( A >= 8 -> H = i64, HS = 8 ; A =:= 4 -> H = i32, HS = 4 ; A =:= 2 -> H = i16, HS = 2 ; H = i8, HS = 1 ),
    Pad is N - HS,
    ( HS =:= 1 -> atomic_list_concat(['[', N, ' x i8]'], LL)
    ; Pad =:= 0 -> atomic_list_concat(['{ ', H, ' }'], LL)
    ; atomic_list_concat(['{ ', H, ', [', Pad, ' x i8] }'], LL) ).
ir_is_union(T) :- ccl_resolve_type(T, base(_, [union(_, _)])).
%% a struct type is named once, shaped from its layout (ir_struct_shape/3)
ir_struct(Tag, Ms0, Name) :-
    ( Ms0 == none -> ( ccl_tag(Tag, Ms) -> true ; ir_fail(struct(Tag)) ) ; Ms = Ms0 ),
    ( Tag == anon -> ir_anon_name(Ms, Name) ; atom_concat('%struct.', Tag, Name) ),
    nb_getval('$ir_structs', Ss),
    (   memberchk(Name-_, Ss) -> true
    ;   nb_setval('$ir_structs', [Name-pending|Ss]),
        ir_struct_shape(Ms, Elems, Map), ir_join(Elems, ', ', Body),
        atomic_list_concat([Name, ' = type { ', Body, ' }'], Def),
        nb_getval('$ir_structs', Ss1), ir_replace(Ss1, Name, Def, Ss2), nb_setval('$ir_structs', Ss2),
        nb_getval('$ir_maps', Maps), nb_setval('$ir_maps', [Name-shape(Elems, Map)|Maps]) ).
%% the LLVM shape of a struct, from its C layout: an element per plain member,
%% one [K x i8] per run of bitfields (the bytes their bits span; runs split
%% where a byte is not shared), padding wherever C's offset is past LLVM's
%% natural one and at the tail; the map says which element a member is and,
%% for a bitfield, its bits within the run: m(Name, Index, T, none | bf(RunLL, BitOff, Width, Signed))
ir_struct_shape(Ms, Elems, Map) :-
    ccl_members_layout(Ms, Lays, Size0, A0), ccl_tag_size(Ms, Size0, A0, Size, _),   % the LLVM shape agrees with ccl_size_align: an EMPTY C++ class is one byte there (so two of them have two addresses and an array of three is three bytes), and an `alignas' class is padded to the size its alignment gives it
    ir_shape(Lays, 0, 0, Elems0, Map, Cur),
    ( Size > Cur -> Pad is Size - Cur, atomic_list_concat(['[', Pad, ' x i8]'], PadEl), append(Elems0, [PadEl], Elems) ; Elems = Elems0 ).
ir_shape([], Cur, _, [], [], Cur).
ir_shape([lay(N, T, Off, empty)|Ls], Cur, Idx, Elems, Map, End) :- !,   % a `[[no_unique_address]]' empty member: NO element (0.96) -- its offset is the ABI's (ccl_members_layout_: 0, or past the data where its own type is there already), which may lie BEFORE the running position, so its address is a byte offset from the object (ir_member_slot), not an element's
    Map = [m(N, empty(Off), T, empty)|Map1],
    ir_shape(Ls, Cur, Idx, Elems, Map1, End).
ir_shape([lay(N, T, Off, none)|Ls], Cur, Idx, Elems, Map, End) :- !,
    ccl_resolve_type(T, T1), ccl_size_align(T1, S, A), ( ccl_vbase_kind(T1, nv(_)) -> atomic_list_concat(['[', S, ' x i8]'], LL), Nat = Cur ; ccl_round_up(Cur, A, Nat), ir_type(T, LL) ),   % a `.nv' base is its data size of bytes, so what follows may use its tail padding
    ir_pad_to(Off, Nat, Cur, Idx, Elems, Elems1, Idx1),
    Elems1 = [LL|Elems2], Cur1 is Off + S, Idx2 is Idx1 + 1,
    Map = [m(N, Idx1, T, none)|Map1],
    ir_shape(Ls, Cur1, Idx2, Elems2, Map1, End).
ir_shape([lay(N, T, Off, Bits)|Ls], Cur, Idx, Elems, Map, End) :-
    ir_bit_run([lay(N, T, Off, Bits)|Ls], none, none, Run, Rest, Start, Last),
    K is Last - Start + 1,
    ir_pad_to(Start, Start, Cur, Idx, Elems, Elems1, Idx1),
    atomic_list_concat(['[', K, ' x i8]'], El), Elems1 = [El|Elems2], RBits is K * 8, atom_concat(i, RBits, RunLL),
    ir_run_map(Run, Idx1, Start, RunLL, Map1), append(Map1, Map2, Map),
    Cur1 is Start + K, Idx2 is Idx1 + 1,
    ir_shape(Rest, Cur1, Idx2, Elems2, Map2, End).
%% padding when the member's offset is past where LLVM would put it
ir_pad_to(Off, Nat, Cur, Idx, Elems, Elems1, Idx1) :-
    ( Off > Nat, Off > Cur -> Pad is Off - Cur, atomic_list_concat(['[', Pad, ' x i8]'], PadEl), Elems = [PadEl|Elems1], Idx1 is Idx + 1 ; Elems = Elems1, Idx1 = Idx ).
%% the consecutive bitfields whose bytes chain (each one's first byte within the run so far)
ir_bit_run([lay(N, T, Off, bits(BOff, W, U))|Ls], S0, L0, [lay(N, T, Off, bits(BOff, W, U))|Run], Rest, Start, Last) :-
    First is Off + BOff // 8, LastB is Off + (BOff + W - 1) // 8,
    ( S0 == none -> true ; First =< L0 + 0 ), !,
    ( S0 == none -> S1 = First ; S1 = S0 ), ( L0 == none -> L1 = LastB ; L1 is max(L0, LastB) ),
    ir_bit_run(Ls, S1, L1, Run, Rest, Start, Last).
ir_bit_run(Ls, Start, Last, [], Ls, Start, Last).
ir_run_map([], _, _, _, []).
ir_run_map([lay(N, T, Off, bits(BOff, W, _))|Ls], Idx, Start, RunLL, [m(N, Idx, T, bf(RunLL, ROff, W, Signed))|Ms]) :-
    ROff is Off * 8 + BOff - Start * 8, ( ir_signed(T) -> Signed = true ; Signed = false ),
    ir_run_map(Ls, Idx, Start, RunLL, Ms).
%% a member's slot: an address, or bf(Address, RunLL, BitOff, Width, Signed) for a bitfield
ir_class_pointee(T, Name) :- ccl_resolve_type(T, ptr(_, PT)), ccl_resolve_type(PT, base(_, [struct(Name, _)])), atom(Name).
%% ... and a class may have SEVERAL base sub-objects since 0.88 (`$base', then `$base$2' ...: std::tuple's leaves),
%% so the route is found once and walked, rather than each walk finding its own
ir_base_path(D, A) :- ir_base_route(D, A, _), !.
ir_base_route(D, A, [BN|Rest]) :- ccl_members_of(base([], [struct(D, none)]), Ms0), ( ccl_vbase_kind(base([], [struct(D, none)]), nv(VT)) -> Ms = [member(VT, '$base', none)|Ms0] ; Ms = Ms0 ), member(member(MT, BN, _), Ms), ir_base_member(BN),
    ccl_resolve_type(MT, base(_, [struct(B, _)])), ( ( B == A ; atom(A), atom_concat(A, '.nv', B) ) -> Rest = [] ; ir_base_route(B, A, Rest) ).   % a diamond's later path is the class's `.nv' form (0.110)
ir_base_member('$base') :- !.
ir_base_member(N) :- atom(N), sub_atom(N, 0, 6, _, '$base$').
ir_base_hops(V, D, A, V1) :- ir_base_route(D, A, Route), !, ir_base_walk(V, D, Route, V1).
ir_base_walk(V, _, [], V) :- !.
ir_base_walk(V, D, [BN|Rest], V1) :- ir_member_slot(V, base([], [struct(D, none)]), BN, P, MT), ccl_resolve_type(MT, base(_, [struct(B, _)])), ir_base_walk(P, B, Rest, V1).
%% ... and the same walk for a REFERENCE bound to a derived object (`const A &r = x', `f(x)' over an `A &'): the
%% address the bind takes is the sub-object's
%% A CAST TO A REFERENCE IS A CONVERSION OF ITS OWN, and the offset is from the OPERAND's class to the
%% CAST's target: `ccl_type_of' of the cast answers that target, so taken whole the two classes were
%% equal, no hops were walked and the object's own address went out --
%% `L1::sw(static_cast<L1 &>(o))', which is how libc++'s tuple swaps its leaves, then swapped the
%% second leaf of `this' with the FIRST of the argument. The cast's own conversion is made here, and
%% whatever the binding still needs after it (a base of the target) follows on the result.
ir_ref_to(E0, RefT, P) :- ir_ref_cast(E0, T, E), !, ir_ref_to(E, T, P0), ir_ref_hops(P0, T, RefT, P).
ir_ref_to(E, RefT, P) :- ir_ref_converts(E, RefT, RT), !, ir_ref_convert(E, RT, P).
ir_ref_to(E, RefT, P) :- ir_ref_of(E, P0), ( ccl_type_of(E, ET) -> true ; ET = unknown ),
    (   ir_fn_designator(ET), ir_ref_pointee(RefT, PT), ccl_resolve_type(PT, ptr(_, _))
    ->  ir_fresh(P), ir_alloca_typed(P, ptr([], base([], [void]))), ir_ins(['store ptr ', P0, ', ptr ', P])   % A FUNCTION BOUND TO A REFERENCE TO A POINTER converts first ([conv.func]) and the reference binds the TEMPORARY pointer ([dcl.init.ref]/5): the function's address IS the value a reference to a function carries, and handed on as the pointer's address libc++'s `__tuple_leaf(_Tp &&)' over `int (*const &)(int, int, int)' loaded the CODE of `add3' as the pointer -- std::bind_front jumped into its own callee's bytes
    ;   ir_ref_hops(P0, ET, RefT, P) ).
ir_fn_designator(T) :- ccl_resolve_type(T, T1), ( T1 = ref(_, F) ; T1 = rref(_, F) ; T1 = F ), ccl_resolve_type(F, fn(_, _, _)), !.
ir_ref_pointee(ref(_, T), T).
ir_ref_pointee(rref(_, T), T).
ir_ref_cast(cast(T, E), T, E) :- ( T = ref(_, _) ; T = rref(_, _) ).
ir_ref_cast(ccast(_, T, E), T, E) :- ( T = ref(_, _) ; T = rref(_, _) ).   % a C++ cast keeps its word to here
%% A REFERENCE TO AN ARITHMETIC TYPE BOUND TO AN EXPRESSION OF ANOTHER ARITHMETIC TYPE binds a TEMPORARY of the referent's
%% type, initialized from the expression ([dcl.init.ref]/5.4; 0.117). `std::max<size_t>(2 * n, 1)' hands the int `1' to a
%% `const size_t &', and the temporary was made as wide as the int -- four bytes read as eight, the upper four whatever the
%% stack held -- so `std::deque' asked for a map of 8589934593 pointers and crashed; `const size_t &r = 3' alike. The two
%% types are compared by their LLVM types (an int and a `const unsigned &' share their bits and need no copy), and a `bool'
%% by its own rule: whatever is not 0 becomes 1. A reference MEMBER bound in a constructor is bound so too (ir_bind_into).
ir_ref_converts(E, RefT, RT) :-
    (   RefT = rref(_, PT) -> true ; RefT = ref(_, PT) ), ccl_resolve_type(PT, RT), ir_arith_value(RT),
    (   RefT = rref(_, _) -> true ; RT = base(Qs, _), memberchk(const, Qs) ),   % only a reference that may bind a temporary: a `T &&', a `const T &' -- a non-const lvalue reference binds a reference-related lvalue and nothing else, so it keeps the lvalue's address whatever the inference says of its type
    catch(ccl_type_of(E, ET0), _, fail), ET0 \== unknown, ccl_unref(ET0, ET1), ccl_resolve_type(ET1, ET), ir_arith_value(ET),
    ir_type(RT, RL), ir_type(ET, EL),
    (   RL \== EL -> true ; ir_is_bool(RT), \+ ir_is_bool(ET) ).
ir_ref_convert(E, RT, P) :-
    ir_type(RT, RL), ir_expr(E, V0, T0, L0), ir_convert(V0, T0, L0, RT, RL, V),
    ir_fresh(P), ir_alloca_typed(P, RT), ir_ins(['store ', RL, ' ', V, ', ptr ', P]).
ir_arith_value(T) :- ccl_is_arith(T), \+ ccl_is_complex(T).
ir_ref_hops(P0, ET, RefT, P) :- ( ET \== unknown, ccl_unref(ET, ET1), ccl_resolve_type(ET1, base(_, [struct(D, _)])), ccl_unref(RefT, RT), ccl_resolve_type(RT, base(_, [struct(A, _)])), D \== A, ir_base_path(D, A) -> ir_base_hops(P0, D, A, P) ; P = P0 ).
ir_member_slot(Base, ST, N, Slot, T) :- ccl_resolve_type(ST, memptr(_, _, F)), ccl_resolve_type(F, fn(_, _, _)), !,   % the two fields of a pointer to member function (0.100): `pm.ptr' and `pm.adj', which the call the desugaring builds reads
    ( N == ptr -> Idx = 0, T = ptr([], base([], [void])) ; N == adj -> Idx = 1, T = base([], [long]) ; ir_fail(no_member(N, ST)) ),
    ir_fresh(Slot), ir_ins([Slot, ' = getelementptr inbounds { ptr, i64 }, ptr ', Base, ', i32 0, i32 ', Idx]).
ir_member_slot(Base, ST, '$base!', Slot, T) :- !, ir_member_slot_(Base, ST, '$base', Slot, T).   % the virtual base where the COMPLETE object lays it: its constructor and destructor, before and after the table is the object's
%% A VIRTUAL BASE IS REACHED THROUGH THE VTABLE ([class.mi]; the Itanium ABI's vbase offset, 0.110): the object's
%% table pointer, the offset at `vptr[-3]', the base at that many bytes from the object -- the same code whether the
%% object is complete or a base sub-object of a diamond, where the shared base lies elsewhere
ir_member_slot(Base, ST, '$base', Slot, T) :- ccl_vbase_kind(ST, K), !,
    ( K = nv(T) -> true ; ccl_members_of(ST, Ms), memberchk(member(T, '$base', _), Ms) ),
    ir_member_slot_(Base, ST, '$vptr', VS, _), ir_fresh(VP), ir_ins([VP, ' = load ptr, ptr ', VS]),
    ir_fresh(Q), ir_ins([Q, ' = getelementptr inbounds i8, ptr ', VP, ', i64 -24']), ir_fresh(O), ir_ins([O, ' = load i64, ptr ', Q]),
    ir_fresh(Slot), ir_ins([Slot, ' = getelementptr inbounds i8, ptr ', Base, ', i64 ', O]).
ir_member_slot(Base, ST, N, Slot, T) :- ir_member_slot_(Base, ST, N, Slot, T).
ir_member_slot_(Base, ST, N, Slot, T) :-
    (   ir_is_union(ST) -> ( ccl_members_of(ST, UMs), memberchk(member(T, N, W0), UMs) -> ir_union_slot(Base, T, W0, Slot) ; ccl_anon_route(ST, N, A, AT) -> ir_member_slot(Base, AT, N, Slot, T), A = A ; ir_fail(no_member(N, ST)) )
    ;   ir_type(ST, SLL), nb_getval('$ir_maps', Maps), memberchk(SLL-shape(_, Map), Maps), memberchk(m(N, Idx, T, BF), Map)
    ->  ir_fresh(P),
        (   BF == empty -> Idx = empty(Off), ir_ins([P, ' = getelementptr inbounds i8, ptr ', Base, ', i64 ', Off]), Slot = empty(P)   % the marked empty member's address, by its byte offset (0.96)
        ;   ir_ins([P, ' = getelementptr inbounds ', SLL, ', ptr ', Base, ', i32 0, i32 ', Idx]),
            ( BF == none -> Slot = P ; BF = bf(RunLL, Off, W, Signed), Slot = bf(P, RunLL, Off, W, Signed) ) )
    ;   ccl_anon_route(ST, N, A, AT) -> ir_member_slot(Base, ST, A, S1, _), ir_slot_addr(S1, B1), ir_member_slot(B1, AT, N, Slot, T)   % C11: a member of an anonymous struct or union (0.108)
    ;   ir_fail(no_member(N, ST)) ).
%% A BITFIELD IN A UNION is the low bits of the union's first bytes (SysV, little-endian; 0.112): its slot is a
%% `bf' over the bytes its bits span, so a read masks and a write keeps the other bits. Why: every union member was
%% read at the union's address as a whole value, so `p.al' of a 3-bit `al' read the byte `std_' had written (9 for 1;
%% libc++'s `__parsed_specifications' reads `__alignment_' so, beside its `__std_' and `__chrono_').
ir_union_slot(Base, T, W0, bf(Base, RunLL, 0, W, Signed)) :- \+ ccl_plain_width(W0), ccl_bit_width(W0, W), W > 0, !,
    K is (W + 7) // 8, RB is K * 8, atom_concat(i, RB, RunLL), ( ir_signed(T) -> Signed = true ; Signed = false ).
ir_union_slot(Base, _, _, Base).
ir_slot_addr(bf(_, _, _, _, _), _) :- !, ir_fail(address_of_bitfield).
ir_slot_addr(empty(P), A) :- !, A = P.        % a `[[no_unique_address]]' member HAS an address (C++ gives it one, possibly shared); what it has not is bytes
ir_slot_addr(A, A).
%% a load from a slot (an array decays to its address); a bitfield's bits shifted out of its run
ir_load_slot(Slot, T, V) :- ir_type(T, LL), ir_load_slot(Slot, T, LL, V).
ir_load_slot(bf(P, RunLL, Off, W, Signed), _, LL, V) :- !,
    ir_fresh(U), ir_ins([U, ' = load ', RunLL, ', ptr ', P, ', align 1']),
    ir_bits(RunLL, K), Sh1 is K - Off - W, Sh2 is K - W,
    ( Sh1 =:= 0 -> V1 = U ; ir_fresh(V1), ir_ins([V1, ' = shl ', RunLL, ' ', U, ', ', Sh1]) ),
    ( Signed == true -> Op = ashr ; Op = lshr ),
    ( Sh2 =:= 0 -> V2 = V1 ; ir_fresh(V2), ir_ins([V2, ' = ', Op, ' ', RunLL, ' ', V1, ', ', Sh2]) ),
    ir_int_convert(V2, RunLL, Signed, LL, V).
%% A MEMBER THAT OWNS NO STORAGE MOVES NO BYTES: a `[[no_unique_address]]' member of an empty class occupies
%% nothing, and its address may be one past its holder's own bytes -- a load answers the type's zero (there is no
%% state to read) and a store writes nothing. The desugaring says the same at its own doors (cpp_zero_fill); this
%% is the net under every road that reaches a member slot.
ir_load_slot(empty(_), _, LL, V) :- !, ir_zero(LL, V).
ir_load_slot(_, T, LL, V) :- ir_empty_class(T), !, ir_zero(LL, V).                     % AN EMPTY CLASS VALUE MOVES NO BYTES (0.94): its one byte is padding as a complete object and, as an EMPTY BASE reached through a reference, somebody else's -- libc++ 18's compressed pair swaps its deleter, `swap(second(), __x.second())' over `static_cast<_Base2 &>(*this)', and the byte stored at the pair's address was the pointer's low byte (unique_ptr::swap left one pointer clobbered, and its destructor freed it)
ir_load_slot(A, T, LL, V) :- atom(A), ir_atomic_q(T), ir_atomic_ll(LL), !, ir_atomic_align(T, Al), ir_fresh(V), ir_ins([V, ' = load atomic ', LL, ', ptr ', A, ' seq_cst, align ', Al]).   % an `_Atomic' object (0.99)
ir_load_slot(A, T, LL, V) :- ir_load_or_decay(A, T, LL, V).
%% a store to a slot; a bitfield's bits masked into its run
ir_store_slot(Slot, T, V) :- ir_type(T, LL), ir_store_slot(Slot, T, LL, V).
ir_store_slot(bf(P, RunLL, Off, W, _), _, LL, V) :- !,
    ir_bits(RunLL, K), Mask is (1 << W) - 1, ir_iconst(Mask, K, MaskLit),
    ( K < 64 -> Clear is ((1 << K) - 1) - (Mask << Off) ; Clear is \ (Mask << Off) ), ir_iconst(Clear, K, ClearLit),
    ir_fresh(U), ir_ins([U, ' = load ', RunLL, ', ptr ', P, ', align 1']),
    ir_fresh(C), ir_ins([C, ' = and ', RunLL, ' ', U, ', ', ClearLit]),
    ir_int_convert(V, LL, false, RunLL, V1),
    ir_fresh(M), ir_ins([M, ' = and ', RunLL, ' ', V1, ', ', MaskLit]),
    ( Off =:= 0 -> S = M ; ir_fresh(S), ir_ins([S, ' = shl ', RunLL, ' ', M, ', ', Off]) ),
    ir_fresh(R), ir_ins([R, ' = or ', RunLL, ' ', C, ', ', S]),
    ir_ins(['store ', RunLL, ' ', R, ', ptr ', P, ', align 1']).
ir_store_slot(empty(_), _, _, _) :- !.
ir_store_slot(_, T, _, _) :- ir_empty_class(T), !.
ir_empty_class(T) :- ccl_lang(cpp), ccl_resolve_type(T, RT), ccl_empty_layout(RT).
ir_store_slot(A, T, LL, V) :- atom(A), ir_atomic_q(T), ir_atomic_ll(LL), !, ir_atomic_align(T, Al), ir_ins(['store atomic ', LL, ' ', V, ', ptr ', A, ' seq_cst, align ', Al]).   % an `_Atomic' object (0.99)
ir_store_slot(A, _, LL, V) :- ir_ins(['store ', LL, ' ', V, ', ptr ', A]).
%% an integer constant as LLVM writes it for iK: two's complement when the top bit is set
ir_iconst(Val, K, Lit) :- ( K < 64, Val >= 1 << (K - 1) -> Lit is Val - (1 << K) ; Lit = Val ).
%% an integer of one width to another
ir_int_convert(V, FL, Signed, TL, V1) :-
    ir_bits(FL, FB), ir_bits(TL, TB),
    (   FB =:= TB -> V1 = V
    ;   FB > TB -> ir_op1(trunc, FL, V, TL, V1)
    ;   Signed == true -> ir_op1(sext, FL, V, TL, V1)
    ;   ir_op1(zext, FL, V, TL, V1) ).
%% an anonymous struct is named by its members, in a registry of its own --
%% not in '$ir_structs', where a name means "defined"
ir_anon_name(Ms, Name) :-
    nb_getval('$ir_anons', As),
    ( member(N-Ms0, As), Ms0 == Ms -> Name = N
    ; length(As, K), atomic_list_concat(['%struct.anon.', K], Name), nb_setval('$ir_anons', [Name-Ms|As]) ).
ir_replace([], _, _, []).
ir_replace([N-_|T], N, D, [N-D|T]) :- !.
ir_replace([X|T], N, D, [X|T1]) :- ir_replace(T, N, D, T1).
ir_member_index(T, N, I, MT) :- ccl_members_of(T, Ms), ir_member_index_(Ms, N, 0, I, MT), !.
ir_member_index(T, N, _, _) :- ir_fail(no_member(N, T)).
ir_member_index_([member(MT, N, _)|_], N, I, I, MT) :- !.
ir_member_index_([_|Ms], N, I0, I, MT) :- I1 is I0 + 1, ir_member_index_(Ms, N, I1, I, MT).

%% ---- the ABI of a struct by value --------------------------------------------------
%% ir_abi(+T, -Abi): scalar | direct([piece(LL, ByteOffset) ...]) | memory(LL, Align) | indirect(LL, Align)
ir_abi(T, Abi) :- ccl_cached('$ir_abicache', T, Abi, ir_abi_nocache(T, Abi)).      % once per type: a struct's leaves and eightbytes are walked at every call site
ir_abi_nocache(T, Abi) :-
    ccl_resolve_type(T, T1),
    (   ir_is_aggregate(T1) -> ir_type(T1, LL), ccl_size_align(T1, N, A), ir_arch(Arch), ir_abi_(Arch, T1, LL, N, A, Abi)
    ;   Abi = scalar ).
ir_is_aggregate(base(_, [struct(_, Ms)])) :- Ms \== none.
ir_is_aggregate(base(_, S)) :- memberchk('_Complex', S).
ir_is_aggregate(base(_, [union(_, Ms)])) :- Ms \== none.
%% A CLASS THAT IS NOT TRIVIALLY COPYABLE OR DESTRUCTIBLE crosses a call BY INVISIBLE REFERENCE -- a pointer to the
%% caller's temporary -- and comes back through a hidden pointer, whatever its size: the Itanium C++ ABI's rule on
%% both architectures, which the shipped library follows. `ios_base::getloc()' returns a `locale', one pointer wide
%% with a destructor, through sret; taken as a register value, the library wrote its result over `this'. The
%% desugaring marks such classes ('$cpp_nontrivial', 0.73), and the program's own follow the same rule on both
%% sides of every call.
ir_abi_(_, base(_, [struct(C, _)]), LL, _, A, indirect(LL, A)) :- ir_nontrivial_class(C), !.
ir_nontrivial_class(C) :- atom(C), catch(nb_getval('$cpp_nontrivial', L), _, fail), memberchk(C, L).
ir_abi_(_, _, _, 0, _, direct([piece(i8, 0)])) :- !.   % an EMPTY class (an allocator, a comparator, a tag): C++ gives it size one, and one byte crosses a call -- with no leaves it classified as no pieces at all, which has no type
ir_abi_(sysv, T, LL, N, A, Abi) :- ( N > 16 -> Abi = memory(LL, A) ; ir_leaves(T, 0, Ls), ( memberchk(leaf(_, x87), Ls) -> Abi = memory(LL, A) ; ir_eightbytes(Ls, N, 0, Ps), Abi = direct(Ps) ) ).   % an X87 class goes in memory (0.108)
%% A RESULT HOLDING X87 CLASSES COMES BACK ON THE x87 STACK (SysV 3.2.3, 0.108): a struct of one long double in %st0, a
%% complex long double in %st0 and %st1 -- as LLVM's x86_fp80 and { x86_fp80, x86_fp80 } returned directly; any other
%% result with an X87 class is returned in memory, as an argument always is
ir_ret_abi(T, Abi) :- ir_abi(T, A0), ( A0 = memory(_, _), ir_arch(sysv), ir_x87_ret(T, RLL) -> Abi = direct([piece(RLL, 0)]) ; Abi = A0 ).
ir_x87_ret(T, LL) :- ccl_resolve_type(T, T1), ir_leaves(T1, 0, Ls),
    ( Ls = [leaf(0, x87), leaf(8, x87up)] -> LL = x86_fp80 ; Ls = [leaf(0, x87), leaf(8, x87up), leaf(16, x87), leaf(24, x87up)], T1 = base(_, S), memberchk('_Complex', S) -> LL = '{ x86_fp80, x86_fp80 }' ).
ir_abi_(aapcs, T, LL, N, A, Abi) :-                                                 % AAPCS64 (proven under qemu, 0.131)
    (   ir_leaves(T, 0, Ls), ir_hfa(Ls, K, FT) -> atomic_list_concat(['[', K, ' x ', FT, ']'], P), Abi = direct([piece(P, 0)])   % AN HFA FIRST, whatever its size: three doubles go in v0-v2, never by reference
    ;   N > 16 -> Abi = indirect(LL, A)
    ;   N =< 8 -> Abi = direct([piece(i64, 0)])
    ;   A >= 16 -> Abi = direct([piece(i128, 0)])                                          % aligned 16: an even register pair, as clang passes it
    ;   Abi = direct([piece('[2 x i64]', 0)]) ).
%% the scalar leaves of a type, each at its byte offset: int | float | double
ir_leaves(T, Off, Ls) :-
    ccl_resolve_type(T, T1),
    (   T1 = base(_, [struct(_, Ms)]), Ms \== none -> ir_member_leaves(Ms, Off, 0, Ls)
    ;   T1 = base(_, [union(_, Ms)]), Ms \== none -> ir_union_leaves(Ms, Off, Ls)
    ;   T1 = arr(int(K), E0) -> once(ccl_resolve_type(E0, E)), ccl_size_align(E, ES, _), ir_array_leaves(K, E, ES, Off, Ls)   % the ELEMENT resolved first (0.117): `unsigned long __first_[2]' of a bitset's base holds `typedef(size_t)' here, which has no size, and the failure backtracked into the resolver and every statement before it -- the body was lowered twice
    ;   T1 = memptr(_, _, F), ccl_resolve_type(F, fn(_, _, _)) -> Off8 is Off + 8, Ls = [leaf(Off, int), leaf(Off8, int)]   % a pointer to member function: two INTEGER eightbytes (0.100)
    ;   T1 = base(_, S), memberchk('_Complex', S) -> ccl_complex_real(T1, R), ccl_size_align(R, ES, _), Off2 is Off + ES, ir_leaves(R, Off, L1), ir_leaves(R, Off2, L2), append(L1, L2, Ls)   % a complex crosses a call as its two components (SysV: SSE eightbytes for a floating one, INTEGER ones for a _Complex int; 0.100, 0.103)
    ;   ir_is_fp(T1), ir_type(T1, LLx), LLx == x86_fp80 -> Off8 is Off + 8, Ls = [leaf(Off, x87), leaf(Off8, x87up)]   % a long double: the X87 and X87UP classes (0.108)
    ;   ir_is_fp(T1), ir_type(T1, LLq), LLq == fp128 -> Ls = [leaf(Off, fp128)]          % ... an IEEE quad on Linux aarch64 (0.131)
    ;   ccl_decimal_kind(T1, DK) -> ( DK =:= 32 -> Ls = [leaf(Off, float)] ; DK =:= 64 -> Ls = [leaf(Off, double)] ; Off8 is Off + 8, Ls = [leaf(Off, fp128), leaf(Off8, sseup)] )   % A DECIMAL is SSE, as gcc classes it (0.129): a _Decimal128 SSE and SSEUP, one register
    ;   ir_is_fp(T1) -> ( T1 = base(_, S), memberchk(float, S) -> Ls = [leaf(Off, float)] ; Ls = [leaf(Off, double)] )
    ;   Ls = [leaf(Off, int)] ).
ir_member_leaves(Ms, Base, _, Ls) :- ccl_members_layout(Ms, Lays, _, _), ir_lay_leaves(Lays, Base, Ls).
ir_lay_leaves([], _, []).
ir_lay_leaves([lay(_, T, Off, Bits)|Lays], Base, Ls) :-
    AbsOff is Base + Off,
    ( Bits == none -> ir_leaves(T, AbsOff, L1) ; L1 = [leaf(AbsOff, int)] ),
    ir_lay_leaves(Lays, Base, L2), append(L1, L2, Ls).
ir_union_leaves([], _, []).
ir_union_leaves([member(MT, _, _)|Ms], Off, Ls) :- ir_leaves(MT, Off, L1), ir_union_leaves(Ms, Off, L2), append(L1, L2, Ls).
ir_array_leaves(0, _, _, _, []) :- !.
ir_array_leaves(K, E, ES, Off, Ls) :- ir_leaves(E, Off, L1), K1 is K - 1, Off1 is Off + ES, ir_array_leaves(K1, E, ES, Off1, L2), append(L1, L2, Ls).
%% SysV: each eightbyte is INTEGER when any integer or pointer lies in it, else SSE
ir_eightbytes(_, N, Off, []) :- Off >= N, !.
ir_eightbytes(Ls, N, Off, [piece(fp128, Off)|Ps]) :- End is Off + 8, ir_leaves_in(Ls, Off, End, Cs), memberchk(fp128, Cs), \+ memberchk(int, Cs), !, Off16 is Off + 16, ir_eightbytes(Ls, N, Off16, Ps).   % SSE and SSEUP: one piece of sixteen bytes (0.129)
ir_eightbytes(Ls, N, Off, [piece(P, Off)|Ps]) :-
    End is Off + 8, ir_leaves_in(Ls, Off, End, Cs), Bytes is min(N - Off, 8),
    (   memberchk(int, Cs) -> Bits is Bytes * 8, atom_concat(i, Bits, P)
    ;   memberchk(double, Cs) -> P = double
    ;   Cs == [float, float] -> P = '<2 x float>'
    ;   Cs == [float] -> P = float
    ;   Bits is Bytes * 8, atom_concat(i, Bits, P) ),
    ir_eightbytes(Ls, N, End, Ps).
ir_leaves_in([], _, _, []).
ir_leaves_in([leaf(O, C)|Ls], Off, End, Cs) :- ( O >= Off, O < End -> Cs = [C|Cs1] ; Cs = Cs1 ), ir_leaves_in(Ls, Off, End, Cs1).
%% AAPCS64: a homogeneous floating-point aggregate, up to four of one kind
ir_hfa([leaf(_, FT)|Ls], K, FT) :- memberchk(FT, [float, double, fp128]), ir_all_leaves(Ls, FT), length(Ls, K0), K is K0 + 1, K =< 4.   % an fp128: Linux aarch64's long double (0.131)
ir_all_leaves([], _).
ir_all_leaves([leaf(_, C)|Ls], C) :- ir_all_leaves(Ls, C).
%% the LLVM type a direct struct is passed or returned as
ir_pieces_type([], i8) :- !.
ir_pieces_type([piece(P, _)], P) :- !.
ir_pieces_type([piece(P1, _), piece(P2, _)], CL) :- atomic_list_concat(['{ ', P1, ', ', P2, ' }'], CL).
ir_piece_lls([], []).
ir_piece_lls([piece(P, _)|Ps], [P|Ls]) :- ir_piece_lls(Ps, Ls).
ir_sret_attr(memory(LL, A), S) :- atomic_list_concat(['ptr sret(', LL, ') align ', A], S).
ir_sret_attr(indirect(LL, A), S) :- atomic_list_concat(['ptr sret(', LL, ') align ', A], S).
%% a parameter's type (an array decays) and its ABI
ir_param_abi(T, PT, Abi) :- ccl_resolve_type(T, T1), ( T1 = arr(_, E) -> PT = ptr([], E) ; PT = T ), ir_abi(PT, Abi).
%% a parameter's LLVM types with their attributes (a define, a declare), and plain (a call's type list)
ir_abi_lls(scalar, T, [LL]) :- ir_type(T, LL).
ir_abi_lls(direct(Pcs), _, LLs) :- ir_piece_lls(Pcs, LLs).
ir_abi_lls(memory(LL, A), _, [S]) :- atomic_list_concat(['ptr byval(', LL, ') align ', A], S).
ir_abi_lls(indirect(_, _), _, [ptr]).
%% a function type's signature: the return LL (void, with an sret parameter
%% first, when the struct is returned in memory) and the parameters' LLs
ir_fn_sig(RT, Ps, Var, RetLL, RetAbi, ParamLLs) :-
    ir_ret_abi(RT, RetAbi),
    (   RetAbi = scalar -> ir_type(RT, RetLL), Lead = []
    ;   RetAbi = direct(Pcs) -> ir_pieces_type(Pcs, RetLL), Lead = []
    ;   ir_sret_attr(RetAbi, Sret), RetLL = void, Lead = [Sret] ),
    ir_regs_start(RetAbi, R0), ir_params_lls(Ps, R0, PLs), append(Lead, PLs, ParamLLs0),
    ( Var == true -> append(ParamLLs0, ['...'], ParamLLs) ; ParamLLs = ParamLLs0 ).
ir_params_lls([], _, []).
ir_params_lls([param(T, _)|Ps], R0, LLs) :- ir_param_abi(T, PT, Abi, R0, R1), ir_abi_lls(Abi, PT, L1), ir_params_lls(Ps, R1, L2), append(L1, L2, LLs).
%% THE REGISTER BUDGET (SysV 3.2.3, 0.117). A struct is passed in registers only when the registers still FREE hold every
%% one of its eightbytes: "if there are no registers available for any eightbyte of an argument, the whole argument is
%% passed on the stack", and the registers taken for it are given back. ir_abi/2 classifies a type alone, so the
%% parameter list is walked here, in order, with `regs(Integer, SSE)' left -- six and eight, the first less when the
%% result comes back through a hidden pointer -- and a `direct' struct that does not fit becomes `memory' (byval). A
%% scalar takes one register of its class when one is free (an `x86_fp80' none: it is always in memory), a by-invisible-
%% reference class its pointer's. One walk serves the declaration (ir_params_lls), the definition (ir_params) and the
%% call (ir_args_), the variadic tail of a call included, so the three agree and agree with clang-built code. Else
%% `f(a, b, c, d, e, struct { long x, y; })' put x in the last register and y on the stack, and a `va_arg' that
%% reads the area by the ABI's rule read the wrong place. AAPCS64's rule differs and is not modelled.
ir_regs_start(RetAbi, regs(I, 8)) :- ( ( RetAbi = memory(_, _) ; RetAbi = indirect(_, _) ) -> I = 5 ; I = 6 ).
ir_param_abi(T, PT, Abi, R0, R) :- ir_param_abi(T, PT, Abi0), ir_regs_take(R0, PT, Abi0, Abi, R).
ir_regs_take(R0, PT, Abi0, Abi, R) :- ir_arch(sysv), !, ir_regs_take_(Abi0, PT, R0, Abi, R).
ir_regs_take(R, _, Abi, Abi, R).
ir_regs_take_(direct(Pcs), PT, regs(I0, S0), Abi, regs(I, S)) :- !,
    ir_piece_classes(Pcs, 0, 0, NG, NS),
    (   NG =< I0, NS =< S0 -> Abi = direct(Pcs), I is I0 - NG, S is S0 - NS
    ;   ccl_resolve_type(PT, PT1), ir_type(PT1, LL), ccl_size_align(PT1, _, A), Abi = memory(LL, A), I = I0, S = S0 ).
ir_regs_take_(scalar, PT, regs(I0, S0), scalar, regs(I, S)) :- !,
    ir_type(PT, LL),
    (   memberchk(LL, [float, double, half, fp128]) -> I = I0, ( S0 > 0 -> S is S0 - 1 ; S = S0 )   % an fp128 (a _Decimal128's carrier, 0.129): one SSE register
    ;   LL == x86_fp80 -> I = I0, S = S0
    ;   LL == i128 -> S = S0, ( I0 >= 2 -> I is I0 - 2 ; I = I0 )
    ;   S = S0, ( I0 > 0 -> I is I0 - 1 ; I = I0 ) ).
ir_regs_take_(indirect(LL, A), _, regs(I0, S0), indirect(LL, A), regs(I, S0)) :- !, ( I0 > 0 -> I is I0 - 1 ; I = I0 ).
ir_regs_take_(Abi, _, R, Abi, R).

ir_signed(T) :- ccl_resolve_type(T, T1), ir_signed_(T1).
%% A TYPE'S SIGN, written once (0.112): an enum with a written underlying type has ITS sign ([dcl.enum]/5), so
%% `enum class __alignment : uint8_t' is unsigned; `bool' and the C++ character types char8_t, char16_t and char32_t
%% are unsigned ([basic.fundamental]). A bitfield is read by it -- a `bool f : 1' holding true read as -1 before.
ir_signed_(base(_, [enum(_, [enum_base(B)|_])])) :- !, ir_signed(B).
ir_signed_(base(_, S)) :- \+ memberchk(unsigned, S), \+ memberchk(bool, S), \+ memberchk('_Bool', S),
    \+ memberchk(char8_t, S), \+ memberchk(char16_t, S), \+ memberchk(char32_t, S), \+ ccl_plain_char_unsigned(S).
ir_is_ptr(T) :- ccl_is_pointer(T).
ir_is_fp(T) :- ccl_is_float(T).
ir_is_int(T) :- ccl_is_integer(T).
ir_int(base([], [int])).
ir_long(base([], [long])).
ir_elem(ptr(_, E), E) :- !.
ir_elem(arr(_, E), E) :- !.
ir_elem(T, E) :- ccl_resolve_type(T, T1), ( T1 = ptr(_, E) ; T1 = arr(_, E) ; T1 = block(_, E) ), !.
ir_elem(T, _) :- ir_fail(not_a_pointer(T)).
ir_zero(LL, Z) :- ( LL == ptr -> Z = null ; ( LL == double ; LL == float ; LL == half ) -> Z = '0.0' ; LL == x86_fp80 -> Z = '0xK00000000000000000000' ; LL == fp128 -> Z = '0xL00000000000000000000000000000000' ; sub_atom(LL, 0, 1, _, 'i') -> Z = 0 ; Z = zeroinitializer ).

%% ---- conversions -------------------------------------------------------------------
ir_convert(V, From, To, V1) :- ir_type(From, FL), ir_type(To, TL), ir_convert(V, From, FL, To, TL, V1).
%% with both LLVM types in hand (the value's travels with it, the target's the caller has)
%% a REFERENCE where a value is wanted is read through: its value is an address (a cast to a reference type binds)
ir_convert(V, From, _, To, TL, V1) :- ( From = ref(_, RT) ; From = rref(_, RT) ), \+ ( To = ref(_, _) ; To = rref(_, _) ), !,
    ccl_resolve_type(RT, T),
    (   T = fn(_, _, _) -> V1 = V                                            % A REFERENCE TO A FUNCTION IS THE FUNCTION'S ADDRESS: there is nothing to load ([conv.func]) -- `std::forward<_Func>(__f)' over `optional<int> (&)(int)' loaded the first eight bytes of the code and called them (the C++23 monadic `and_then', given a function name)
    ;   ir_type(T, LL), ir_fresh(L), ir_ins([L, ' = load ', LL, ', ptr ', V]), ir_convert(L, T, LL, To, TL, V1) ).
%% A POINTER TO A CLASS CONVERTS TO A POINTER TO ITS BASE BY THE BASE'S OFFSET: every base sat at offset 0 until
%% 0.72, and a VIRTUAL base is placed after the class's own members (the ABI's complete-object layout), so `A *base
%% = &x' copied the B * unchanged and base->twice() read b's bytes. The base sub-object is the `$base' member, or
%% the `$base' of that, down to the one whose type is the target's (ir_base_path); a pointer to anything else, or
%% to the class itself, converts as it did. A null pointer is not spared the offset (not done).
ir_convert(V, From, ptr, To, ptr, V1) :- ir_class_pointee(From, D), ir_class_pointee(To, A), D \== A, ir_base_path(D, A), !, ir_base_hops(V, D, A, V0),
    ( V == null -> V1 = null ; ir_fresh(Z), ir_ins([Z, ' = icmp eq ptr ', V, ', null']), ir_fresh(V1), ir_ins([V1, ' = select i1 ', Z, ', ptr null, ptr ', V0]) ).   % A NULL POINTER STAYS NULL ([conv.ptr]/3; 0.99): it was given the base's offset
%% A POINTER TO A BASE'S MEMBER FUNCTION CONVERTED TO THE DERIVED CLASS'S ([conv.mem]; 0.108): its `adj' grows by the
%% base sub-object's offset, which the call adds to `this' (cpp_memptr_call)
ir_convert(V, From, '{ ptr, i64 }', To, '{ ptr, i64 }', V1) :- ccl_resolve_type(From, memptr(B, _, _)), ccl_resolve_type(To, memptr(D, _, _)), B \== D,
    ccl_resolve_type(base([], [typedef(D)]), base(_, [struct(DT, _)])), ccl_resolve_type(base([], [typedef(B)]), base(_, [struct(BT, _)])),
    ir_base_route(DT, BT, Route), !, ir_route_desig(Route, Des), ccl_offsetof(base([], [typedef(D)]), Des, Off),
    ir_fresh(A), ir_ins([A, ' = extractvalue { ptr, i64 } ', V, ', 1']), ir_fresh(A1), ir_ins([A1, ' = add i64 ', A, ', ', Off]),
    ir_fresh(V1), ir_ins([V1, ' = insertvalue { ptr, i64 } ', V, ', i64 ', A1, ', 1']).
ir_route_desig([N|Ns], D) :- ir_route_desig_(Ns, id(N), D).
ir_route_desig_([], D, D).
ir_route_desig_([N|Ns], D0, D) :- ir_route_desig_(Ns, member(D0, N), D).
ir_convert(V, From, FL, To, TL, V1) :- ( ccl_is_complex(From) ; ccl_is_complex(To) ), !, ir_complex_convert(V, From, FL, To, TL, V1).
ir_convert(V, From, FL, To, TL, V1) :- ( ccl_is_decimal(From) ; ccl_is_decimal(To) ), !, ir_dec_convert(V, From, FL, To, TL, V1).   % a decimal floating value: libgcc's conversions (0.129)   % by the C TYPES: an ABI piece `{ i64, i64 }' is no complex (0.103)   % a complex from a real (the imaginary part zero), a real from a complex (its real part), one complex to another (0.100)
ir_convert(V, From, FL, To, TL, V1) :-
    (   ir_is_bool(To), \+ ir_is_bool(From) -> ir_to_bool(V, From, FL, V1)   % C++: a bool is 0 or 1, whatever came
    ;   FL == TL -> V1 = V
    ;   ir_fp_ll(FL), ir_fp_ll(TL) -> ( ir_fp_wider(TL, FL) -> Op = fpext ; Op = fptrunc ), ir_op1(Op, FL, V, TL, V1)
    ;   ir_fp_ll(FL) -> ( ir_signed(To) -> Op = fptosi ; Op = fptoui ), ir_op1(Op, FL, V, TL, V1)
    ;   ir_fp_ll(TL) -> ( ir_signed(From) -> Op = sitofp ; Op = uitofp ), ir_op1(Op, FL, V, TL, V1)
    ;   ( FL == ptr ; ir_isfn(From) ), TL == ptr -> V1 = V
    ;   FL == ptr -> ir_op1(ptrtoint, FL, V, TL, V1)
    ;   TL == ptr -> ir_op1(inttoptr, FL, V, TL, V1)
    ;   ir_bits(FL, FB), ir_bits(TL, TB), FB > TB -> ir_op1(trunc, FL, V, TL, V1)
    ;   ir_signed(From) -> ir_op1(sext, FL, V, TL, V1)
    ;   ir_op1(zext, FL, V, TL, V1) ).
ir_isfn(T) :- ccl_resolve_type(T, fn(_, _, _)).
ir_complex_convert(V, _, FL, _, TL, V) :- FL == TL, !.
ir_complex_convert(V, From, FL, To, TL, V1) :- ccl_is_complex(From), ccl_is_complex(To), !, ir_complex_parts(V, FL, R, I), ir_complex_elem(FL, FE), ir_complex_elem(TL, TE),
    ccl_complex_real(From, FR), ccl_complex_real(To, TR), ir_convert(R, FR, FE, TR, TE, R1), ir_convert(I, FR, FE, TR, TE, I1), ir_complex_make(TL, R1, I1, V1).
ir_complex_convert(V, From, FL, To, TL, V1) :- ccl_is_complex(To), !, ir_complex_elem(TL, EL), ccl_complex_real(To, RT), ir_convert(V, From, FL, RT, EL, R), ir_zero(EL, Z), ir_complex_make(TL, R, Z, V1).
ir_complex_convert(V, From, FL, To, TL, V1) :- ir_complex_parts(V, FL, R, _), ir_complex_elem(FL, EL), ccl_complex_real(From, RT), ir_convert(R, RT, EL, To, TL, V1).
ir_is_bool(T) :- ccl_resolve_type(T, base(_, S)), ( memberchk(bool, S) ; memberchk('_Bool', S) ), !.   % C's _Bool too (0.108): `_Bool b = 42' is 1
ir_to_bool(V, From, FL, V1) :- ccl_decimal_kind(From, K), !, ir_dec_nonzero(K, FL, V, C), ir_fresh(V1), ir_ins([V1, ' = zext i1 ', C, ' to i8']).   % a decimal is true where it is no zero (0.129)
ir_to_bool(V, From, FL, V1) :-
    ir_fresh(C),
    (   FL == '{ ptr, i64 }' -> ir_fresh(P), ir_ins([P, ' = extractvalue { ptr, i64 } ', V, ', 0']), ir_ins([C, ' = icmp ne ptr ', P, ', null'])   % a pointer to member function is null when its `ptr' is (0.100): std::function's `__not_null(_Rp _Class::*)' tests it
    ;   ir_fp_ll(FL) -> ir_zero(FL, Z0), ir_ins([C, ' = fcmp une ', FL, ' ', V, ', ', Z0])   % the type's own zero: x86_fp80 takes no `0.0'
    ;   ( FL == ptr ; ir_isfn(From) ) -> ir_ins([C, ' = icmp ne ptr ', V, ', null'])
    ;   ir_ins([C, ' = icmp ne ', FL, ' ', V, ', 0']) ),
    ir_fresh(V1), ir_ins([V1, ' = zext i1 ', C, ' to i8']).
ir_op1(Op, FL, V, TL, R) :- ir_fresh(R), ir_ins([R, ' = ', Op, ' ', FL, ' ', V, ' to ', TL]).
ir_bits(LL, N) :- atom_concat(i, A, LL), atom_codes(A, Cs), catch(number_codes(N, Cs), _, fail), !.
%% C23'S DECIMAL FLOATING TYPES (0.129), as gcc builds them: a `_Decimal32', `_Decimal64', `_Decimal128' value is its BID encoding
%% (IEEE 754-2008's binary integer decimal), CARRIED in LLVM as a float, a double and an fp128 -- never computed on as one -- so the
%% SysV ABI passes it where gcc does, in an SSE register (one xmm for the fp128 too), and every operation is a call of libgcc's
%% decimal runtime, which `cc' links: `__bid_adddd3', `__bid_ltdd2', `__bid_floatsidd', `__bid_truncdddf' ... (the suffix sd, dd or
%% td the kind). A comparison answers a long whose sign tells (eq and ne zero where equal, lt below zero ...); a negation flips the
%% sign bit, as gcc does; a literal is encoded here from its text, exactly, rounded half to even past the precision.
ir_dec_ll(32, float).  ir_dec_ll(64, double).  ir_dec_ll(128, fp128).
ir_dec_ill(32, i32).  ir_dec_ill(64, i64).  ir_dec_ill(128, i128).
ir_dec_sfx(32, sd).  ir_dec_sfx(64, dd).  ir_dec_sfx(128, td).
%% kind: precision, bias, the least and the greatest quantum exponent, the coefficient's bits in the short form, the width
ir_dec_params(32, 7, 101, -101, 90, 23, 32).
ir_dec_params(64, 16, 398, -398, 369, 53, 64).
ir_dec_params(128, 34, 6176, -6176, 6111, 113, 128).
ir_dec_rt(F, Ret, Args, Call) :- atomic_list_concat(Args, ', ', As), atomic_list_concat(['declare ', Ret, ' @', F, '(', As, ')'], D), ir_note_extern(F, raw(D)), Call = F.
ir_dec_call(F, Ret, ArgLLs, Vals, V) :- ir_dec_rt(F, Ret, ArgLLs, _), ir_dec_args(ArgLLs, Vals, Ps), atomic_list_concat(Ps, ', ', PA), ( var(V) -> ir_fresh(V) ; true ), ir_ins([V, ' = call ', Ret, ' @', F, '(', PA, ')']).   % a name already made (a step's) is taken
ir_dec_args([], [], []).
ir_dec_args([L|Ls], [V|Vs], [P|Ps]) :- atomic_list_concat([L, ' ', V], P), ir_dec_args(Ls, Vs, Ps).
ir_dec_arith(Op, K, LL, A, B, V) :- ir_dec_arith_into(Op, K, LL, A, B, V).
ir_dec_arith_into(Op, K, LL, A, B, V) :- ( ir_dec_opname(Op, N) -> true ; ir_fail(decimal_operator(Op)) ), ir_dec_sfx(K, S), atomic_list_concat(['__bid_', N, S, '3'], F), ir_dec_call(F, LL, [LL, LL], [A, B], V).
ir_dec_opname('+', add).  ir_dec_opname('-', sub).  ir_dec_opname('*', mul).  ir_dec_opname('/', div).
ir_dec_cmp(Op, K, LL, A, B, C) :- ir_dec_cmpname(Op, N, P), ir_dec_sfx(K, S), atomic_list_concat(['__bid_', N, S, '2'], F), ir_dec_call(F, i64, [LL, LL], [A, B], R), ir_fresh(C), ir_ins([C, ' = icmp ', P, ' i64 ', R, ', 0']).
ir_dec_cmpname('==', eq, eq).  ir_dec_cmpname('!=', ne, ne).  ir_dec_cmpname('<', lt, slt).  ir_dec_cmpname('<=', le, sle).  ir_dec_cmpname('>', gt, sgt).  ir_dec_cmpname('>=', ge, sge).
ir_dec_nonzero(K, LL, V, C) :- ir_zero(LL, Z), ir_dec_cmp('!=', K, LL, V, Z, C).   % the carrier's all-zero bits are a decimal zero (exponent the least)
ir_dec_negate(K, LL, V0, V) :- ir_dec_ill(K, IL), ir_dec_params(K, _, _, _, _, _, N), N1 is N - 1, ccl_w_shl(1, N1, SB0), ccl_w_sub(0, SB0, SB), ir_dec_num_text(SB, SBT),
    ir_fresh(I), ir_ins([I, ' = bitcast ', LL, ' ', V0, ' to ', IL]), ir_fresh(X), ir_ins([X, ' = xor ', IL, ' ', I, ', ', SBT]), ir_fresh(V), ir_ins([V, ' = bitcast ', IL, ' ', X, ' to ', LL]).
ir_dec_one(K, One) :- ir_dec_text(K, d(0, [0'1], 0, no), One).
ir_dec_literal(K, A, V) :- ( ir_dec_parse(A, Ds, E) -> ir_dec_fit(K, d(0, Ds, E, no), D), ir_dec_text(K, D, V) ; ir_fail(decimal_literal(A)) ).
%% the text of a literal (`0.1', `1.0e5', `.5'): its digits, leading zeros dropped, and the exponent of the last one
ir_dec_parse(A, Ds, E) :- atom_codes(A, Cs),
    ( append(Ms, [X|Es0], Cs), ( X =:= 0'e ; X =:= 0'E ) -> ir_dec_exp(Es0, Ex) ; Ms = Cs, Ex = 0 ),
    ( append(Is, [0'.|Fs], Ms) -> true ; Is = Ms, Fs = [] ), append(Is, Fs, Ds0), length(Fs, F), ir_dec_strip(Ds0, Ds), E is Ex - F.
ir_dec_exp([0'-|Ds], E) :- !, number_codes(E0, Ds), E is -E0.
ir_dec_exp([0'+|Ds], E) :- !, number_codes(E, Ds).
ir_dec_exp(Ds, E) :- number_codes(E, Ds).
ir_dec_strip([0'0|Ds], R) :- !, ir_dec_strip(Ds, R).
ir_dec_strip(Ds, Ds).
%% d(Sign, Digits, Exponent, Inf) fitted to the kind: at most its precision, rounded half to even; an exponent past the greatest
%% clamped by padding the coefficient with zeros where it holds them, else an infinity; one past the least rounded away
ir_dec_fit(K, d(S, Ds0, E0, _), d(S, Ds, E, Inf)) :- ir_dec_params(K, P, _, Emin, Emax, _, _),
    ir_dec_round_to(Ds0, E0, P, Ds1, E1),
    (   Ds1 == [] -> Ds = [], E is max(Emin, min(Emax, E1)), Inf = no
    ;   E1 > Emax -> D is E1 - Emax, length(Ds1, N), ( N + D =< P -> length(Z, D), ir_dec_zeros(Z), append(Ds1, Z, Ds), E = Emax, Inf = no ; Ds = [], E = Emax, Inf = yes )
    ;   E1 < Emin -> D is Emin - E1, ir_dec_drop_round(Ds1, D, Ds), E = Emin, Inf = no
    ;   Ds = Ds1, E = E1, Inf = no ).
ir_dec_zeros([]).
ir_dec_zeros([0'0|Zs]) :- ir_dec_zeros(Zs).
ir_dec_round_to(Ds, E, P, Ds1, E1) :- length(Ds, N),
    (   N =< P -> Ds1 = Ds, E1 = E
    ;   D is N - P, ir_dec_drop_round(Ds, D, Ds2), E2 is E + D, length(Ds2, N2),
        ( N2 > P -> append(Ds3, [_], Ds2), Ds1 = Ds3, E1 is E2 + 1 ; Ds1 = Ds2, E1 = E2 ) ).   % 9...9 rounded up to 10...0: one digit fewer, the exponent one more
%% the last D digits dropped, the rest rounded half to even
ir_dec_drop_round(Ds, D, R) :- length(Ds, N),
    (   D > N -> R = []
    ;   D =:= N -> ( Ds = [F|Rest], ( F > 0'5 ; F =:= 0'5, member(X, Rest), X =\= 0'0 ) -> R = [0'1] ; R = [] )
    ;   Keep is N - D, length(K0, Keep), append(K0, Dropped, Ds), Dropped = [F|Rest], last(K0, LastK),
        ( ( F > 0'5 ; F =:= 0'5, ( member(X, Rest), X =\= 0'0 -> true ; (LastK - 0'0) mod 2 =:= 1 ) ) -> ir_dec_incr(K0, R0) ; R0 = K0 ),
        ir_dec_strip(R0, R) ).
ir_dec_incr(Ds, R) :- reverse(Ds, Rv), ir_dec_incr_(Rv, 1, Rv1), reverse(Rv1, R).
ir_dec_incr_([], 0, []) :- !.
ir_dec_incr_([], 1, [0'1]).
ir_dec_incr_([D|Ds], Cy, [D1|Ds1]) :- V is D - 0'0 + Cy, ( V =:= 10 -> D1 = 0'0, Cy1 = 1 ; D1 is 0'0 + V, Cy1 = 0 ), ir_dec_incr_(Ds, Cy1, Ds1).
%% the BID bits, spelled as the carrier: `bitcast (i64 N to double)', N the signed reading of the pattern
ir_dec_text(K, D, Text) :- ir_dec_bits(K, D, N), ir_dec_ill(K, IL), ir_dec_ll(K, LL), ir_dec_num_text(N, NT), atomic_list_concat(['bitcast (', IL, ' ', NT, ' to ', LL, ')'], Text).
ir_dec_num_text(N, T) :- ( integer(N) -> atom_number(T, N) ; N = big(A), T = A ).
ir_dec_bits(K, d(S, Ds, E, Inf), N) :- ir_dec_params(K, _, Bias, _, _, Sh, W),
    (   Inf == yes -> W8 is W - 8, ccl_w_shl(120, W8, U)                                   % 0x78 in the top byte: an infinity
    ;   ir_dec_digits_value(Ds, C), BE is E + Bias, ccl_w_shl(1, Sh, Lim),
        (   ccl_w_cmp(C, Lim, <) -> ccl_w_shl(BE, Sh, X), ccl_w_add(X, C, U)              % the short form: the exponent, then the coefficient
        ;   Sh2 is Sh - 2, ccl_w_shl(BE, Sh2, X1), W3 is W - 3, ccl_w_shl(3, W3, X0), ccl_w_sub(C, Lim, Low), ccl_w_add(X0, X1, X2), ccl_w_add(X2, Low, U) ) ),   % the long form: `11', the exponent, the coefficient's low bits (its top `100' implied)
    (   S =:= 1 -> W1 is W - 1, ccl_w_shl(1, W1, H), ccl_w_sub(U, H, N) ; N = U ).        % the sign bit set: the pattern read as a signed integer
ir_dec_digits_value([], 0) :- !.
ir_dec_digits_value(Ds, V) :- ccl_limbs_of_dec(Ds, [], Ls0), ccl_mag_norm(Ls0, Ls), ccl_narrow(w(1, Ls), V).
%% a decimal global's constant (0.129): a literal of any decimal kind, re-encoded in the global's own; its negation; an integer constant
ir_dec_fold(E, K, D) :- ir_dec_fold_(E, D0), ir_dec_fit(K, D0, D).
ir_dec_fold_(dec32(A), d(0, Ds, E, no)) :- !, ir_dec_parse(A, Ds, E).
ir_dec_fold_(dec64(A), d(0, Ds, E, no)) :- !, ir_dec_parse(A, Ds, E).
ir_dec_fold_(dec128(A), d(0, Ds, E, no)) :- !, ir_dec_parse(A, Ds, E).
ir_dec_fold_(neg(X), d(S1, Ds, E, I)) :- !, ir_dec_fold_(X, d(S, Ds, E, I)), S1 is 1 - S.
ir_dec_fold_(pos(X), D) :- !, ir_dec_fold_(X, D).
ir_dec_fold_(paren(X), D) :- !, ir_dec_fold_(X, D).
ir_dec_fold_(cast(T, X), D) :- ccl_is_decimal(T), !, ir_dec_fold_(X, D).
ir_dec_fold_(X, d(S, Ds, 0, no)) :- catch(ccl_const_eval(X, N), _, fail), ( integer(N) ; N = big(_) ), !,
    ( ccl_w_cmp(N, 0, <) -> S = 1, ccl_w_neg(N, M) ; S = 0, M = N ), ( integer(M) -> number_codes(M, Cs) ; M = big(A), atom_codes(A, Cs) ), ir_dec_strip(Cs, Ds).
%% the conversions: decimal to decimal, to and from an integer (the width's own routine: si for 32 bits and below, di for 64), to
%% and from a standard floating type (sf, df, xf; a _Float16 through a float), to a bool by the test
ir_dec_convert(V, From, FL, To, TL, V1) :- ir_is_bool(To), \+ ir_is_bool(From), !, ir_to_bool(V, From, FL, V1).
ir_dec_convert(V, From, FL, To, TL, V1) :- ccl_decimal_kind(From, KF), ccl_decimal_kind(To, KT), !,
    (   KF =:= KT -> V1 = V
    ;   ir_dec_sfx(KF, SF), ir_dec_sfx(KT, ST), ( KT > KF -> W = extend ; W = trunc ), atomic_list_concat(['__bid_', W, SF, ST, '2'], F), ir_dec_call(F, TL, [FL], [V], V1) ).
ir_dec_convert(V, From, FL, To, TL, V1) :- ccl_decimal_kind(To, KT), !, ir_dec_sfx(KT, ST),
    (   ir_fp_ll(FL) -> ( FL == half -> ir_op1(fpext, half, V, float, V0), FL0 = float ; V0 = V, FL0 = FL ), ir_dec_fpname(FL0, FS),
        ir_dec_fp_width(FL0, FW), ( DW = KT, FW > DW -> W = trunc ; W = extend ), atomic_list_concat(['__bid_', W, FS, ST], F), ir_dec_call(F, TL, [FL0], [V0], V1)
    ;   ir_is_int(From), ir_bits(FL, B) ->
        (   B > 64 -> ir_fail(decimal_conversion(From, To))
        ;   ( ir_signed(From) -> U = '' ; U = uns ), ( B =< 32 -> IW = si, IL = i32 ; IW = di, IL = i64 ),
            ( FL == IL -> V0 = V ; ( ir_signed(From) -> X = sext ; X = zext ), ir_op1(X, FL, V, IL, V0) ),
            atomic_list_concat(['__bid_float', U, IW, ST], F), ir_dec_call(F, TL, [IL], [V0], V1) )
    ;   ir_fail(decimal_conversion(From, To)) ).
ir_dec_convert(V, From, FL, To, TL, V1) :- ccl_decimal_kind(From, KF), ir_dec_sfx(KF, SF),
    (   ir_fp_ll(TL) -> ( TL == half -> TL0 = float ; TL0 = TL ), ir_dec_fpname(TL0, TS),
        ir_dec_fp_width(TL0, TW), ( DW = KF, DW >= TW -> W = trunc ; W = extend ), atomic_list_concat(['__bid_', W, SF, TS], F), ir_dec_call(F, TL0, [FL], [V], V0),
        ( TL == half -> ir_op1(fptrunc, float, V0, half, V1) ; V1 = V0 )
    ;   ir_is_int(To), ir_bits(TL, B) ->
        (   B > 64 -> ir_fail(decimal_conversion(From, To))
        ;   ( ir_signed(To) -> U = '' ; U = uns ), ( B =< 32 -> IW = si, IL = i32 ; IW = di, IL = i64 ),
            atomic_list_concat(['__bid_fix', U, SF, IW], F), ir_dec_call(F, IL, [FL], [V], V0),
            ( TL == IL -> V1 = V0 ; ir_op1(trunc, IL, V0, TL, V1) ) )
    ;   ir_fail(decimal_conversion(From, To)) ).
ir_dec_fpname(float, sf).  ir_dec_fpname(double, df).  ir_dec_fpname(x86_fp80, xf).  ir_dec_fpname(fp128, tf).
%% libgcc names a conversion `extend' or `trunc' by the formats' widths (the kind is the decimal's): a 32-bit decimal to a double
%% extends, a 64-bit one truncates, and between formats of one width a decimal truncates to binary and a binary extends to decimal
ir_dec_fp_width(float, 32).  ir_dec_fp_width(double, 64).  ir_dec_fp_width(x86_fp80, 80).  ir_dec_fp_width(fp128, 128).
%% a value as a condition (i1)
%% `new T' is malloc(sizeof(T)); `new T(v)' for a scalar T stores v into it; a
%% class with a constructor is the next step
ir_new(T, [], cast(ptr([], T), call(id(malloc), [sizeof_type(T)]))) :- !.
ir_new(T, [A], stmt_expr(block([declaration(0, none, T, [var(P, ptr([], T), cast(ptr([], T), call(id(malloc), [sizeof_type(T)])))]), expr(0, assign('=', deref(id(P)), A)), expr(0, id(P))]))) :-
    ccl_resolve_type(T, T1), \+ T1 = base(_, [struct(_, _)]), \+ T1 = base(_, [class(_, _, _, _)]), !, ccl_gensym('$new', P).
ir_new(T, _, _) :- ir_fail(new_with_constructor(T)).
ir_cond(E, C) :- ir_cmp_op(E, _), !, ir_expr_i1(E, C).
ir_cond(E, C) :-
    ir_expr(E, V, T, LL),
    ( ccl_decimal_kind(T, K) -> ir_dec_nonzero(K, LL, V, C)   % a decimal (0.129)
    ; LL == '{ ptr, i64 }' -> ir_fresh(P), ir_ins([P, ' = extractvalue { ptr, i64 } ', V, ', 0']), ir_fresh(C), ir_ins([C, ' = icmp ne ptr ', P, ', null'])   % `if (pm)' of a pointer to member function
    ; ir_fp_ll(LL) -> ir_fresh(C), ir_zero(LL, Z0), ir_ins([C, ' = fcmp une ', LL, ' ', V, ', ', Z0])
    ; LL == ptr -> ir_fresh(C), ir_ins([C, ' = icmp ne ptr ', V, ', null'])
    ; ir_fresh(C), ir_ins([C, ' = icmp ne ', LL, ' ', V, ', 0']) ).
ir_cmp_op(bin(Op, _, _), Op) :- memberchk(Op, ['<', '>', '<=', '>=', '==', '!=']).
%% an i1 as a C int value
ir_bool(C, V) :- ir_fresh(V), ir_ins([V, ' = zext i1 ', C, ' to i32']).
%% ... the value of a comparison, `!', `&&' and `||': C's int, C++'s BOOL (0.127; ccl_truth_type/1 is the inference's twin)
ir_truth(C, V, T, LL) :- ( ccl_lang(cpp) -> T = base([], [bool]), LL = i8, ir_fresh(V), ir_ins([V, ' = zext i1 ', C, ' to i8']) ; ir_int(T), LL = i32, ir_bool(C, V) ).

%% ---- constants ------------------------------------------------------------------------
ir_wstring(S, EL, Ref) :-
    ir_utf8_decode(S, Us0), ir_wide_units(EL, Us0, Us), append(Us, [0], Us1), length(Us1, N), ir_wstring_elems(Us1, EL, Es), ir_join(Es, ', ', Body),
    nb_getval('$ir_strings', Ss), length(Ss, K), atomic_list_concat(['@.wstr.', K], Ref),
    atomic_list_concat([Ref, ' = private unnamed_addr constant [', N, ' x ', EL, '] [', Body, ']'], Def),
    nb_setval('$ir_strings', [Def|Ss]).
%% a `u"..."' literal is UTF-16 ([lex.string]/10; 0.112): a code point past U+FFFF is a SURROGATE PAIR, two units,
%% where it was one i16 that kept only the low bits; `wchar_t' and `char32_t' hold a code point each
ir_wide_units(i16, Us, Ws) :- !, ir_utf16(Us, Ws).
ir_wide_units(_, Us, Us).
ir_utf16([], []).
ir_utf16([U|Us], Ws) :- U > 65535, !, V is U - 65536, H is 55296 + (V >> 10), Lo is 56320 + (V /\ 1023), Ws = [H, Lo|Ws1], ir_utf16(Us, Ws1).
ir_utf16([U|Us], [U|Ws]) :- ir_utf16(Us, Ws).
ir_wstring_elems([], _, []).
ir_wstring_elems([U|Us], EL, [E|Es]) :- atomic_list_concat([EL, ' ', U], E), ir_wstring_elems(Us, EL, Es).
ir_utf8_decode([], []).
ir_utf8_decode([A|Bs], [U|Us]) :- A >= 240, Bs = [B, C, D|Bs1], !, U is (A - 240) * 262144 + (B - 128) * 4096 + (C - 128) * 64 + (D - 128), ir_utf8_decode(Bs1, Us).
ir_utf8_decode([A|Bs], [U|Us]) :- A >= 224, Bs = [B, C|Bs1], !, U is (A - 224) * 4096 + (B - 128) * 64 + (C - 128), ir_utf8_decode(Bs1, Us).
ir_utf8_decode([A|Bs], [U|Us]) :- A >= 192, Bs = [B|Bs1], !, U is (A - 192) * 64 + (B - 128), ir_utf8_decode(Bs1, Us).
ir_utf8_decode([A|Bs], [A|Us]) :- ir_utf8_decode(Bs, Us).
ir_string(S, Ref) :-
    nb_getval('$ir_strings', Ss), length(Ss, K), atomic_list_concat(['@.str.', K], Ref),
    length(S, N0), N is N0 + 1, ir_escape(S, Esc),
    atomic_list_concat([Ref, ' = private unnamed_addr constant [', N, ' x i8] c"', Esc, '\\00"'], Def),
    nb_setval('$ir_strings', [Def|Ss]).
ir_escape([], '').
ir_escape([C|Cs], A) :- ir_escape(Cs, A1), ( ( C < 32 ; C > 126 ; C =:= 34 ; C =:= 92 ) -> ir_hex2(C, H), atom_concat('\\', H, E) ; atom_codes(E, [C]) ), atom_concat(E, A1, A).
ir_hex2(C, H) :- Hi is C // 16, Lo is C mod 16, ir_hexd(Hi, A), ir_hexd(Lo, B), atom_concat(A, B, H).
ir_hexd(D, A) :- ( D < 10 -> C is 0'0 + D ; C is 0'A + D - 10 ), atom_codes(A, [C]).
%% a double as LLVM's hex literal: sign, 11 exponent bits, 52 fraction bits
ir_fp_text(K, LL, A) :- ir_fp_const(K, LL, A).   % spelled for its LLVM type (0.108): a float rounded, an x86_fp80 in its 0xK form
ir_num_const(float(F), F) :- !.
ir_num_const(neg(float(F)), V) :- !, V is -F.
ir_num_const(cast(_, E), V) :- !, ir_num_const(E, V).
ir_num_const(E, V) :- ccl_const_eval(E, V).   % a component's constant: a double's hex; for a float element LLVM takes the same spelling where the value is exact in a float
ir_double(F, A) :-
    ( F =:= 0.0 -> A = '0x0000000000000000'
    ; X is abs(F), ( F < 0 -> Sg = 8 ; Sg = 0 ),
      E0 is floor(log(X) / log(2)), ir_norm(X, E0, E, M),
      Frac is round((M - 1) * 4503599627370496), Ex is E + 1023,
      D1 is Sg + (Ex >> 8), D23 is Ex mod 256,
      ir_hexd(D1, H1), ir_hex2(D23, H23), ir_hexn(Frac, 13, HF),
      atomic_list_concat(['0x', H1, H23, HF], A) ).
%% a floating constant for its LLVM type (0.108): a double's hex for a double; for a float the double's hex of the value
%% ROUNDED TO A FLOAT's precision, since LLVM takes a float constant only where a float holds it exactly; for x86_fp80 its
%% own `0xK' form -- sign and 15 exponent bits, then the 64-bit mantissa with its explicit integer bit
%% an ARITHMETIC CONSTANT EXPRESSION's value (6.6/8), which a floating global's initializer is: floating literals, integer
%% constants, casts, the four operations and a sign -- the integer constant evaluator (ccl_const_eval) takes none of the
%% floating forms, as an array bound or a case label must not
ir_fp_value(float(F), F) :- !.
ir_fp_value(cast(T, E), V) :- !, ir_fp_value(E, V0), ir_fp_cast(T, V0, V).
ir_fp_value(ccast(_, T, E), V) :- !, ir_fp_value(E, V0), ir_fp_cast(T, V0, V).
ir_fp_value(neg(E), V) :- !, ir_fp_value(E, V0), V is -V0.
ir_fp_value(pos(E), V) :- !, ir_fp_value(E, V).
ir_fp_value(paren(E), V) :- !, ir_fp_value(E, V).
ir_fp_value(bin(Op, A, B), V) :- memberchk(Op, ['+', '-', '*', '/']), !, ir_fp_value(A, VA), ir_fp_value(B, VB), ir_fp_op(Op, VA, VB, V).
ir_fp_value(E, V) :- ccl_const_eval(E, V0), ( number(V0) -> V = V0 ; V0 = big(_), ccl_w_float(V0, V) ).   % an integer past 2^60, a double rounded to nearest (0.129): `double d = (double) ((__int128) 1 << 100)'
%% A CAST TO AN INTEGER TYPE inside a floating initializer truncates and wraps (0.129): `(double) (int) 2.5' was 2.5, the cast
%% passed over; to a floating type the value goes on
ir_fp_cast(T, V0, V) :- ( ccl_resolve_type(T, RT), ccl_cast_shape(RT, _, _) -> ccl_w_cast(T, V0, V1), ( V1 = big(_) -> ccl_w_float(V1, V) ; V = V1 ) ; V = V0 ).
ir_fp_op('+', A, B, V) :- V is A + B.
ir_fp_op('-', A, B, V) :- V is A - B.
ir_fp_op('*', A, B, V) :- V is A * B.
ir_fp_op('/', A, B, V) :- B =\= 0, ( integer(A), integer(B) -> V is truncate(A / B) ; V is A / B ).
ir_fp_global(T, LL) :- ccl_resolve_type(T, base(_, S)), \+ memberchk('_Complex', S), ( memberchk(double, S) ; memberchk(float, S) ; memberchk('_Float16', S) ), !, ir_type(T, LL).
ir_fp_const(V, LL, A) :- F is V * 1.0, ir_fp_const_(LL, F, A).
ir_fp_const_(x86_fp80, F, A) :- !, ir_x87(F, A).
ir_fp_const_(fp128, F, A) :- !, ir_quad(F, A).                                     % an IEEE quad (0.131)
ir_fp_const_(float, F, A) :- abs(F) >= 3.4028235677973366e38, !, ( F < 0 -> A = '0xFFF0000000000000' ; A = '0x7FF0000000000000' ).   % past a float's range: its infinity
ir_fp_const_(float, F, A) :- !, ir_float_round(F, R), ir_double(R, A).
ir_fp_const_(half, F, A) :- abs(F) >= 65520.0, !, ( F < 0 -> A = '0xFFF0000000000000' ; A = '0x7FF0000000000000' ).
ir_fp_const_(half, F, A) :- !, ir_half_round(F, R), ir_double(R, A).
ir_fp_const_(_, F, A) :- ir_double(F, A).
ir_float_round(F, R) :- ir_round_bits(F, 23, -126, 127, R).
ir_half_round(F, R) :- ir_round_bits(F, 10, -14, 15, R).
ir_round_bits(F, _, _, _, R) :- F =:= 0.0, !, R = F.
ir_round_bits(F, MB, EMin, EMax, R) :-
    X is abs(F), E0 is floor(log(X) / log(2)), ir_norm(X, E0, E, _),
    (   E > EMax -> R0 = X
    ;   E >= EMin -> K is MB - E, R0 is round(X * 2.0 ** K) * 2.0 ** (-K)
    ;   K is MB - EMin, R0 is round(X * 2.0 ** K) * 2.0 ** (-K) ),
    ( F < 0 -> R is -R0 ; R = R0 ).
ir_x87(F, A) :- F =:= 0.0, !, A = '0xK00000000000000000000'.
ir_x87(F, A) :-
    X is abs(F), ( F < 0 -> Sg = 1 ; Sg = 0 ),
    E0 is floor(log(X) / log(2)), ir_norm(X, E0, E, M),
    Frac is round((M - 1) * 4503599627370496),                 % the double's 52 fraction bits, exact
    SE is Sg * 32768 + E + 16383,
    Sig is 4503599627370496 + Frac,                             % the 53 significant bits with the integer bit
    Hi is Sig >> 21, Lo is (Sig /\ 2097151) << 11,               % shifted to 64 bits: the high and the low 32
    ir_hexn(SE, 4, HE), ir_hexn(Hi, 8, HH), ir_hexn(Lo, 8, HL),
    atomic_list_concat(['0xK', HE, HH, HL], A).
%% AN IEEE QUAD's 0xL form (0.131): the low 64 bits, then the high 64 (sign, 15 exponent bits biased 16383, the fraction's
%% top 48); the double's 52 fraction bits fill the top of the quad's 112, exactly
ir_quad(F, A) :- F =:= 0.0, !, A = '0xL00000000000000000000000000000000'.
ir_quad(F, A) :-
    X is abs(F), ( F < 0 -> Sg = 1 ; Sg = 0 ),
    E0 is floor(log(X) / log(2)), ir_norm(X, E0, E, M),
    Frac is round((M - 1) * 4503599627370496),
    SE is Sg * 32768 + E + 16383, FH is Frac >> 4, D is Frac /\ 15,
    ir_hexn(SE, 4, HE), ir_hexn(FH, 12, HF), ir_hexd(D, HD),
    atomic_list_concat(['0xL', HD, '000000000000000', HE, HF], A).
ir_norm(X, E0, E, M) :- M0 is X / (2.0 ** E0), ( M0 >= 2.0 -> E1 is E0 + 1, ir_norm(X, E1, E, M) ; M0 < 1.0 -> E1 is E0 - 1, ir_norm(X, E1, E, M) ; E = E0, M = M0 ).
ir_hexn(_, 0, '') :- !.
ir_hexn(N, K, A) :- D is N mod 16, N1 is N // 16, K1 is K - 1, ir_hexn(N1, K1, A1), ir_hexd(D, H), atom_concat(A1, H, A).

%% ---- expressions: a value, its C type, and its LLVM type ------------------------------------
%% ir_expr(+E, -V, -T, -LL): the value, the C type (resolved where the
%% lowering resolved it) and the LLVM type of the value -- `ptr' for an array
%% that decayed, whatever ir_type/2 says of the array. The LLVM type travels
%% with the value so the consumers (a conversion, a store, an arithmetic
%% instruction, a condition) stop deriving it again from the C type: half
%% the lowering's 50,000 calls were the type machinery asked twice.
ir_expr(E, V, T) :- ir_expr(E, V, T, _).
ir_expr(int(big(A)), V, T, LL) :- !, ccl_big_type(A, T), ir_type(T, LL), ir_big_text(A, V).   % past 64 bits an i128 (0.129)             % a literal past 2^60 (0.94): spelled into the IR as it is, `u0x...' for the hex form
ir_expr(uint(big(A)), V, base([], [unsigned, long]), i64) :- !, ir_big_text(A, V).
ir_expr(long(big(A)), V, base([], [long]), i64) :- !, ir_big_text(A, V).
ir_expr(ulong(big(A)), V, base([], [unsigned, long]), i64) :- !, ir_big_text(A, V).
ir_expr(int(N), N, T, LL) :- !, ( ( N > 2147483647 ; N < -2147483648 ) -> ir_long(T), LL = i64 ; ir_int(T), LL = i32 ).
ir_expr(dec32(A), V, base([], ['_Decimal32']), float) :- !, ir_dec_literal(32, A, V).      % C23's decimal floating literals (0.129): encoded exactly
ir_expr(dec64(A), V, base([], ['_Decimal64']), double) :- !, ir_dec_literal(64, A, V).
ir_expr(dec128(A), V, base([], ['_Decimal128']), fp128) :- !, ir_dec_literal(128, A, V).
ir_expr(uint(N), N, base([], [unsigned]), i32) :- !.                       % the suffixes: what the literal is
ir_expr(long(N), N, base([], [long]), i64) :- !.
ir_expr(ulong(N), N, base([], [unsigned, long]), i64) :- !.
ir_expr(wb(N), N, T, LL) :- !, ccl_type_of(wb(N), T), ir_type(T, LL).
ir_expr(uwb(N), N, T, LL) :- !, ccl_type_of(uwb(N), T), ir_type(T, LL).
ir_expr(float(F), A, base([], [double]), double) :- !, ir_double(F, A).
ir_expr(imag(F), V, base([], ['_Complex', double]), LL) :- !, LL = '{ double, double }', ir_double(F, A), ir_complex_make(LL, '0.0', A, V).   % the imaginary literal `2.0i' (0.101): the constant { 0, F }
ir_expr(imagf(F), V, T, LL) :- !, ir_expr(imag(F), V0, T0, L0), T = base([], ['_Complex', float]), LL = '{ float, float }', ir_complex_convert(V0, T0, L0, T, LL, V).
ir_expr(imagl(F), V, T, LL) :- !, ir_expr(imag(F), V0, T0, L0), T = base([], ['_Complex', long, double]), ir_type(T, LL), ir_complex_convert(V0, T0, L0, T, LL, V).   % `1.0li' (0.112): the double constant widened to the long double complex
ir_expr(imagi(Sp, N), V, T, LL) :- !, T = base([], ['_Complex'|Sp]), ir_type(T, LL), ( integer(N) -> Txt = N ; N = big(A), ir_big_text(A, Txt) ), ir_complex_make(LL, 0, Txt, V).   % `3i', `2ui', `3li': the constant { 0, N } of its kind (0.103; the kind from the suffix and a literal past 2^60 spelled as it is, 0.104)
ir_expr(chr(C), C, base([], [char]), i8) :- ccl_lang(cpp), !.   % C++: a char, as the inference types it
ir_expr(chr(C), C, T, i32) :- !, ir_int(T).
ir_expr(str(S), Ref, ptr([], base([], [char])), ptr) :- !, ir_string(S, Ref).
%% the WIDE LITERALS: the UTF-8 bytes both lexers keep, decoded into code points, one element each (i32 for wchar_t
%% and char32_t, i16 for char16_t), a private constant like a plain string's
ir_expr(wstr(S), Ref, ptr([], base([], [wchar_t])), ptr) :- !, ir_wstring(S, i32, Ref).
ir_expr(u16str(S), Ref, ptr([], base([], [char16_t])), ptr) :- !, ir_wstring(S, i16, Ref).
ir_expr(u32str(S), Ref, ptr([], base([], [char32_t])), ptr) :- !, ir_wstring(S, i32, Ref).
ir_expr(wchr(C), C, base([], [wchar_t]), i32) :- !.
ir_expr(u16chr(C), C, base([], [char16_t]), i16) :- !.
ir_expr(u32chr(C), C, base([], [char32_t]), i32) :- !.
ir_expr(id(N), V, T, i32) :- \+ ir_lookup(N, _), ccl_enum_value(N, V), !, ir_int(T).          % an enumerator is its value -- unless A LOCAL SHADOWS IT (0.94): libc++'s <format> has a scoped enum with an enumerator `__ptr' (14), every enumerator is a global name here, and `iterator __r(__ptr)' in the tree's node removal built its iterator from 14 where `__ptr' was the parameter (every erase by iterator in a C++20 program over <set> segfaulted)
ir_expr(id(N), V, T, LL) :- \+ ir_lookup(N, _), ccl_func_name(N), !, nb_getval('$ir_fn', F), atom_codes(F, Cs), ir_expr(str(Cs), V, _, LL), T = ptr([], base([const], [char])).   % `__func__' (0.108)
ir_expr(id(N), V, T, LL) :- !,
    ( ir_lookup(N, loc(Addr0, T00)) -> true ; ir_fail(undeclared(N)) ),
    ir_ref_slot(Addr0, T00, Addr, T0),
    ccl_resolve_type(T0, T1),
    (   T1 = arr(_, E) -> V = Addr, T = ptr([], E), LL = ptr
    ;   T1 = fn(_, _, _) -> V = Addr, T = ptr([], T0), LL = ptr
    ;   ir_type(T1, LL), ir_fresh(V), ir_ins([V, ' = load ', LL, ', ptr ', Addr]), T = T1 ).
%% THE FLOATING CONSTANTS' BUILTINS, which glibc's <math.h> writes INFINITY, NAN, HUGE_VAL and HUGE_VALF on (0.101):
%% `__builtin_inf()', `__builtin_inff()', `__builtin_nan("")', `__builtin_nanf("")', `__builtin_huge_val()', `__builtin_huge_valf()'
ir_expr(call(id(B), _), V, T, LL) :- ir_float_builtin(B, V, T, LL), !.
ir_expr(coro_retval, V, T, LL) :- !, nb_getval('$ir_coro', coro(_, _, _, _, _, _, slot(Tmp, T, LL))), ir_fresh(V), ir_ins([V, ' = load ', LL, ', ptr ', Tmp]).   % the ramp's return object (0.108)
ir_expr(call(id(B), Args), V, T, LL) :- ir_coro_builtin(B, Args, V, T, LL), !.   % libc++'s coroutine_handle: __builtin_coro_resume and kin (0.108)
%% ... AND THE CLASSIFICATION BUILTINS glibc's isnan, isinf, isfinite and signbit expand to under a clang-shaped compiler
%% (0.101): `fcmp' over the value, an int answered
ir_expr(call(id(B), [X]), V, T, i32) :- ir_fp_class(B), !, ir_int(T), ir_expr(X, V0, T0, L0), ( ir_fp_ll(L0) -> V1 = V0, L1 = L0 ; ir_convert(V0, T0, L0, base([], [double]), double, V1), L1 = double ), ir_fp_class_(B, V1, L1, V).
ir_fp_class('__builtin_isnan'). ir_fp_class('__builtin_isinf'). ir_fp_class('__builtin_isinf_sign'). ir_fp_class('__builtin_isfinite'). ir_fp_class('__builtin_signbit'). ir_fp_class('__builtin_isnormal').
ir_fp_class_('__builtin_isnan', X, L, V) :- ir_fresh(C), ir_ins([C, ' = fcmp uno ', L, ' ', X, ', ', X]), ir_fresh(V), ir_ins([V, ' = zext i1 ', C, ' to i32']).
ir_fp_class_('__builtin_isinf', X, L, V) :- ir_fp_inf(X, L, P, N), ir_fresh(C), ir_ins([C, ' = or i1 ', P, ', ', N]), ir_fresh(V), ir_ins([V, ' = zext i1 ', C, ' to i32']).
ir_fp_class_('__builtin_isinf_sign', X, L, V) :- ir_fp_inf(X, L, P, N), ir_fresh(A), ir_ins([A, ' = zext i1 ', P, ' to i32']), ir_fresh(B), ir_ins([B, ' = zext i1 ', N, ' to i32']), ir_fresh(V), ir_ins([V, ' = sub i32 ', A, ', ', B]).
ir_fp_class_('__builtin_isfinite', X, L, V) :- ir_fp_inf(X, L, P, N), ir_fresh(O), ir_ins([O, ' = fcmp ord ', L, ' ', X, ', ', X]), ir_fresh(I), ir_ins([I, ' = or i1 ', P, ', ', N]), ir_fresh(NI), ir_ins([NI, ' = xor i1 ', I, ', true']), ir_fresh(C), ir_ins([C, ' = and i1 ', O, ', ', NI]), ir_fresh(V), ir_ins([V, ' = zext i1 ', C, ' to i32']).
ir_fp_class_('__builtin_isnormal', X, L, V) :- ir_fp_class_('__builtin_isfinite', X, L, F), ( L == float -> Min = '0x3810000000000000' ; L == x86_fp80 -> Min = '0xK00018000000000000000' ; L == fp128 -> Min = '0xL00000000000000000001000000000000' ; Min = '0x0010000000000000' ),   % finite, and no smaller than the least normal
    ir_fresh(Ab), ir_ins([Ab, ' = call ', L, ' @llvm.fabs.', L, '(', L, ' ', X, ')']), atomic_list_concat(['declare ', L, ' @llvm.fabs.', L, '(', L, ')'], D), atomic_list_concat(['llvm.fabs.', L], IN), ir_note_extern(IN, raw(D)),
    ir_fresh(G), ir_ins([G, ' = fcmp oge ', L, ' ', Ab, ', ', Min]), ir_fresh(Gi), ir_ins([Gi, ' = zext i1 ', G, ' to i32']), ir_fresh(V), ir_ins([V, ' = and i32 ', F, ', ', Gi]).
ir_fp_class_('__builtin_signbit', X, L, V) :- ( L == float -> IL = i32, Sh = 31 ; L == x86_fp80 -> IL = i80, Sh = 79 ; L == fp128 -> IL = i128, Sh = 127 ; IL = i64, Sh = 63 ), ir_fresh(B), ir_ins([B, ' = bitcast ', L, ' ', X, ' to ', IL]), ir_fresh(S), ir_ins([S, ' = lshr ', IL, ' ', B, ', ', Sh]), ( IL == i32 -> V = S ; ir_fresh(V), ir_ins([V, ' = trunc ', IL, ' ', S, ' to i32']) ).
ir_fp_inf(X, L, P, N) :- ir_fp_infs(L, PI, NI), ir_fresh(P), ir_ins([P, ' = fcmp oeq ', L, ' ', X, ', ', PI]), ir_fresh(N), ir_ins([N, ' = fcmp oeq ', L, ' ', X, ', ', NI]).
ir_fp_infs(x86_fp80, '0xK7FFF8000000000000000', '0xKFFFF8000000000000000') :- !.   % x87's own spelling (0.108)
ir_fp_infs(fp128, '0xL00000000000000007FFF000000000000', '0xL0000000000000000FFFF000000000000') :- !.   % a quad's (0.131)
ir_fp_infs(_, '0x7FF0000000000000', '0xFFF0000000000000').
ir_expr(call(id('__builtin_complex'), [A, B]), V, T, LL) :- !, ccl_type_of(A, TA0), ccl_complex_of(TA0, T), ir_type(T, LL), ir_complex_elem(LL, EL), ccl_complex_real(T, RT),   % C11's CMPLX(x, y), and I (0.100)
    ir_expr(A, VA, TA, LA), ir_expr(B, VB, TB, LB), ir_convert(VA, TA, LA, RT, EL, R), ir_convert(VB, TB, LB, RT, EL, I), ir_complex_make(LL, R, I, V).
ir_expr(call(F, Args), V, RT, LL) :- !,
    ir_moved_args(F, Args, Args1),
    (   F = id(free), Args1 = [E], ir_drain_free(E, S) -> ir_expr(S, V, RT, LL)
    ;   ir_call(F, Args1, V0, RT0),
        (   ( RT0 = ref(_, RT1) ; RT0 = rref(_, RT1) ), ccl_resolve_type(RT1, RT2), RT2 = fn(_, _, _) -> V = V0, RT = RT2, ir_type(ptr([], RT2), LL)   % a reference TO A FUNCTION is the function's address, nothing to load ([conv.func]): `std::forward<_Func>(__f)' of a function name, which C++23's `and_then' calls -- the load took the first eight bytes of the code
        ;   ( RT0 = ref(_, RT1) ; RT0 = rref(_, RT1) ), ccl_resolve_type(RT1, RT2), RT2 = arr(_, _) -> V = V0, RT = RT2, LL = ptr   % a reference TO AN ARRAY is the array's address, which decays: nothing to load (0.117) -- libc++'s charconv `__pow()' returns `const uint32_t (&)[10]', and `__pow() + 1' added to a loaded [10 x i32]
        ;   ( RT0 = ref(_, RT1) ; RT0 = rref(_, RT1) ) -> ccl_resolve_type(RT1, RT), ir_type(RT, LL), ir_fresh(V), ir_ins([V, ' = load ', LL, ', ptr ', V0])   % C++: a reference result is what it refers to
        ;   V = V0, RT = RT0, ir_type(RT, LL) ) ).
%% C++ (M6): the forms that are C with names
ir_expr(bool(true), 1, base([], [bool]), i8) :- !.
ir_expr(bool(false), 0, base([], [bool]), i8) :- !.
ir_expr(nullptr, null, ptr([], base([], [void])), ptr) :- !.
ir_expr(scoped(_, N), V, T, LL) :- !, ir_expr(id(N), V, T, LL).
ir_expr(ccast(_, T, E), V, T1, LL) :- !, ir_expr(cast(T, E), V, T1, LL).
ir_expr(new(T, Args), V, T1, LL) :- !, ir_new(T, Args, E), ir_expr(E, V, T1, LL).
ir_expr(new_array(T, N), V, T1, LL) :- !,
    ir_expr(cast(ptr([], T), call(id(malloc), [bin('*', cast(base([], [unsigned, long]), N), sizeof_type(T))])), V, T1, LL).
ir_expr(delete(E), V, T, LL) :- !, ir_expr(call(id(free), [E]), V, T, LL).
ir_expr(delete_poly(E, D), none, base([], [void]), void) :- !, ir_expr(E, P, _, _),     % the complete object: `p + vptr[-2]', taken before the destructor runs
    ir_fresh(VP), ir_ins([VP, ' = load ptr, ptr ', P]), ir_fresh(G), ir_ins([G, ' = getelementptr inbounds i64, ptr ', VP, ', i64 -2']),
    ir_fresh(O), ir_ins([O, ' = load i64, ptr ', G]), ir_fresh(C), ir_ins([C, ' = getelementptr inbounds i8, ptr ', P, ', i64 ', O]),
    ir_expr(D, _, _, _), ir_note_extern(free, raw('declare void @free(ptr)')), ir_ins(['call void @free(ptr ', C, ')']).
ir_expr(delete_array(E), V, T, LL) :- !, ir_expr(call(id(free), [E]), V, T, LL).
%% dynamic_cast through libc++abi's __dynamic_cast(sub, &src_type, &dst_type, hint), -1 the hint that says nothing;
%% a null pointer stays null and is never handed to it; a reference that does not convert aborts
ir_expr('$memaddr'(C, N), _, _, _) :- !, ir_fail(overloaded_member_address(C, N)).   % an overloaded member's address no target chose (cpp_conv_to)
ir_expr(dyncast(X, void, void, T), V, T, ptr) :- !, ir_expr(X, P, _, _),   % `dynamic_cast<void *>' (0.112): the object's address plus the offset-to-top its table holds at vptr[-2]; null stays null
    ir_tmp(ptr, Tmp), ir_ins(['store ptr null, ptr ', Tmp]), ir_fresh(NN), ir_ins([NN, ' = icmp ne ptr ', P, ', null']),
    ir_label(LC), ir_label(LM), ir_end(['br i1 ', NN, ', label %', LC, ', label %', LM]), ir_block(LC),
    ir_fresh(VP), ir_ins([VP, ' = load ptr, ptr ', P]), ir_fresh(G), ir_ins([G, ' = getelementptr inbounds i64, ptr ', VP, ', i64 -2']),
    ir_fresh(O), ir_ins([O, ' = load i64, ptr ', G]), ir_fresh(R), ir_ins([R, ' = getelementptr inbounds i8, ptr ', P, ', i64 ', O]),
    ir_ins(['store ptr ', R, ', ptr ', Tmp]), ir_block(LM), ir_fresh(V), ir_ins([V, ' = load ptr, ptr ', Tmp]).
ir_expr(dyncast(X, SC, DC, T), V, T, ptr) :- !, ir_expr(X, P, _, _), ir_rtti_emit(SC, SS), ir_rtti_emit(DC, DS), ir_dyncast_decl,
    ir_tmp(ptr, Tmp), ir_ins(['store ptr null, ptr ', Tmp]), ir_fresh(NN), ir_ins([NN, ' = icmp ne ptr ', P, ', null']),
    ir_label(LC), ir_label(LM), ir_end(['br i1 ', NN, ', label %', LC, ', label %', LM]), ir_block(LC),
    ir_fresh(R), ir_ins([R, ' = call ptr @__dynamic_cast(ptr ', P, ', ptr @', SS, ', ptr @', DS, ', i64 -1)']), ir_ins(['store ptr ', R, ', ptr ', Tmp]),
    ir_block(LM), ir_fresh(V), ir_ins([V, ' = load ptr, ptr ', Tmp]).
ir_expr(dyncast_ref(X, SC, DC, T), V, T, ptr) :- !, ir_expr(X, P, _, _), ir_rtti_emit(SC, SS), ir_rtti_emit(DC, DS), ir_dyncast_decl,
    ir_fresh(V), ir_ins([V, ' = call ptr @__dynamic_cast(ptr ', P, ', ptr @', SS, ', ptr @', DS, ', i64 -1)']),
    ir_fresh(NN), ir_ins([NN, ' = icmp eq ptr ', V, ', null']), ir_label(LA), ir_label(LM), ir_end(['br i1 ', NN, ', label %', LA, ', label %', LM]),
    ir_block(LA), ir_note_extern(abort, raw('declare void @abort()')), ir_ins(['call void @abort()']), ir_end(['unreachable']), ir_block(LM).
ir_dyncast_decl :- ir_note_extern('__dynamic_cast', raw('declare ptr @__dynamic_cast(ptr, ptr, ptr, i64)')).
%% the type_info objects of a chain, the class's first: `__class_type_info' at the root, `__si_class_type_info' over it
ir_rtti_emit(ext(Sym), Sym) :- !, atomic_list_concat(['@', Sym, ' = external constant ptr'], D), ir_note_extern(Sym, raw(D)).
ir_rtti_emit(vmi(N, C, Bs), Sym) :- !, atom_concat('_ZTI', N, Sym), atom_concat('_ZTS', N, SN),
    atom_length(N, K), K1 is K + 1, atomic_list_concat(['@', SN, ' = linkonce_odr constant [', K1, ' x i8] c"', N, '\\00"'], DS), ir_note_extern(SN, raw(DS)),
    findall(E, ( member(b(Ch, S), Bs), ir_rtti_emit(Ch, BS), ( S == virtual -> F = -6141 ; ( S == none -> Off = 0 ; ccl_offsetof(base([], [typedef(C)]), id(S), Off) ), F is Off * 256 + 2 ),   % a VIRTUAL base (0.110): public and virtual, its offset the vbase offset's place in the table, -24 (-24 * 256 + 3)
                 atomic_list_concat(['{ ptr, i64 } { ptr @', BS, ', i64 ', F, ' }'], E) ), Es),
    length(Es, NB), atomic_list_concat(Es, ', ', EsT), V = '_ZTVN10__cxxabiv121__vmi_class_type_infoE', ( catch('$cpp_nv_base'(C, _), _, fail) -> DF = 2 ; DF = 0 ),   % __diamond_shaped_mask
    atomic_list_concat(['@', Sym, ' = linkonce_odr constant { ptr, ptr, i32, i32, [', NB, ' x { ptr, i64 }] } { ptr getelementptr inbounds (ptr, ptr @', V, ', i64 2), ptr @', SN,
                        ', i32 ', DF, ', i32 ', NB, ', [', NB, ' x { ptr, i64 }] [', EsT, '] }'], D),
    atomic_list_concat(['@', V, ' = external global [0 x ptr]'], DV), ir_note_extern(V, raw(DV)), ir_note_extern(Sym, raw(D)).
ir_rtti_emit([N|Rest], Sym) :- atom_concat('_ZTI', N, Sym), atom_concat('_ZTS', N, SN),
    atom_length(N, K), K1 is K + 1, atomic_list_concat(['@', SN, ' = linkonce_odr constant [', K1, ' x i8] c"', N, '\\00"'], DS), ir_note_extern(SN, raw(DS)),
    (   Rest == [] -> V = '_ZTVN10__cxxabiv117__class_type_infoE',
        atomic_list_concat(['@', Sym, ' = linkonce_odr constant { ptr, ptr } { ptr getelementptr inbounds (ptr, ptr @', V, ', i64 2), ptr @', SN, ' }'], D)
    ;   ir_rtti_emit(Rest, BS), V = '_ZTVN10__cxxabiv120__si_class_type_infoE',
        atomic_list_concat(['@', Sym, ' = linkonce_odr constant { ptr, ptr, ptr } { ptr getelementptr inbounds (ptr, ptr @', V, ', i64 2), ptr @', SN, ', ptr @', BS, ' }'], D) ),
    atomic_list_concat(['@', V, ' = external global [0 x ptr]'], DV), ir_note_extern(V, raw(DV)), ir_note_extern(Sym, raw(D)).
%% a C++26 CONTRACT VIOLATED (0.108): the `enforce' semantic -- what failed written on stderr, then abort
ir_expr(contract_violation(K, F, L), none, base([], [void]), void) :- !,
    ( F == none -> nb_getval('$ir_fn', Fn) ; Fn = F ), ( K == pre -> KW = precondition ; K == post -> KW = postcondition ; KW = assertion ),
    atomic_list_concat(['contract violation: ', KW, ' of ', Fn, ' (line ', L, ')'], Msg), atom_codes(Msg, Cs0), append(Cs0, [10], Cs), length(Cs, Len),
    ir_expr(str(Cs), SV, _, _),
    ir_note_extern(write, raw('declare i64 @write(i32, ptr, i64)')), ir_note_extern(abort, raw('declare void @abort()')),
    ir_ins(['call i64 @write(i32 2, ptr ', SV, ', i64 ', Len, ')']), ir_ins(['call void @abort()']).
ir_expr(delete_cookie(E, Ck), V, T, LL) :- !, ir_expr(call(id(free), [bin('-', cast(ptr([], base([], [char])), E), int(Ck))]), V, T, LL).   % the block starts at the cookie (0.108)
ir_expr(lambda(_, _, _, _), _, _, _) :- !, ir_fail(lambda).
ir_expr(throw(_), _, _, _) :- !, ir_fail(throw).
ir_expr(eh_alloc(S), V, ptr([], base([], [void])), ptr) :- !, ir_expr(S, SV, ST, SL), ir_convert(SV, ST, SL, base([], [unsigned, long]), i64, S1),
    ir_note_extern('__cxa_allocate_exception', raw('declare ptr @__cxa_allocate_exception(i64)')), ir_fresh(V), ir_ins([V, ' = call ptr @__cxa_allocate_exception(i64 ', S1, ')']).
ir_expr(eh_throw(P, rtti(Ch), D), none, base([], [void]), void) :- !, ir_expr(P, PV, _, _), ir_rtti_emit(Ch, Sym),
    ( D == nullptr -> DV = null ; ir_expr(D, DV, _, _) ),
    ir_note_extern('__cxa_throw', raw('declare void @__cxa_throw(ptr, ptr, ptr)')),
    atomic_list_concat(['ptr ', PV, ', ptr @', Sym, ', ptr ', DV], Args), ir_emit_call(none, void, '@__cxa_throw', Args), ir_end(['unreachable']).
ir_expr(eh_terminate, none, base([], [void]), void) :- !, ir_note_extern('_ZSt9terminatev', raw('declare void @_ZSt9terminatev()')), ir_ins(['call void @_ZSt9terminatev()']), ir_end(['unreachable']).   % std::terminate, where an exception leaves a noexcept function (0.110)
ir_expr(eh_rethrow, none, base([], [void]), void) :- !, ir_note_extern('__cxa_rethrow', raw('declare void @__cxa_rethrow()')), ir_emit_call(none, void, '@__cxa_rethrow', ''), ir_end(['unreachable']).
ir_expr(drain_free(E), V, RT, LL) :- !, ir_call(id(free), [E], V, RT), ir_type(RT, LL).          % the lowering's own free, past the drain
ir_expr(assign('=', L, R), V, LT, LL) :- ir_own_elem(L), !, ir_elem_assign(L, R, S), ir_expr(S, V, LT, LL).   % an own array's element: the old one freed
ir_expr(assign('=', L, R), V, LT, LL) :- !,
    ir_lval(L, Slot, LT, LL), ir_expr(R, V0, RT, RL), ir_convert(V0, RT, RL, LT, LL, V), ir_store_slot(Slot, LT, LL, V).
%% A COMPOUND ASSIGNMENT EVALUATES ITS LEFT OPERAND ONCE ([expr.ass]/6, C 6.5.16.2/3): the place is taken once and the
%% atomic test asked of it after (0.112). The `_Atomic' road was a clause of its own that took the place to decide,
%% and a lowering emits as it goes -- backtracking undoes no instruction -- so `slot() += 5' called slot twice.
ir_expr(assign(Op, L, R), V, LT, LL) :- !,
    atom_concat(BinOp, '=', Op), ir_lval(L, Slot, LT, LL),
    (   ir_atomic_binop(BinOp, RmwOp), atom(Slot), ir_atomic_q(LT), ir_int_ll(LL)              % `x += n' on an `_Atomic' object: one atomicrmw (0.99)
    ->  ir_expr(R, RV0, RT, RL), ir_convert(RV0, RT, RL, LT, LL, RV), ir_fresh(Old), ir_ins([Old, ' = atomicrmw ', RmwOp, ' ptr ', Slot, ', ', LL, ' ', RV, ' seq_cst']),
        ir_fresh(V), ir_ins([V, ' = ', RmwOp, ' ', LL, ' ', Old, ', ', RV])
    ;   ir_load_slot(Slot, LT, LL, Cur),
        ir_binary(BinOp, Cur, LT, LL, R, V0, RT, RL), ir_convert(V0, RT, RL, LT, LL, V), ir_store_slot(Slot, LT, LL, V) ).
ir_expr(bin('&&', A, B), V, T, LL) :- !,
    ir_label(LB), ir_label(LE), ir_cond(A, CA), ir_cur_label(LA0), ir_end(['br i1 ', CA, ', label %', LB, ', label %', LE]),
    ir_block(LB), ir_cond(B, CB), ir_cur_label(LB1), ir_end(['br label %', LE]),
    ir_block(LE), ir_fresh(C), ir_ins([C, ' = phi i1 [ false, %', LA0, ' ], [ ', CB, ', %', LB1, ' ]']), ir_truth(C, V, T, LL).
ir_expr(bin('||', A, B), V, T, LL) :- !,
    ir_label(LB), ir_label(LE), ir_cond(A, CA), ir_cur_label(LA0), ir_end(['br i1 ', CA, ', label %', LE, ', label %', LB]),
    ir_block(LB), ir_cond(B, CB), ir_cur_label(LB1), ir_end(['br label %', LE]),
    ir_block(LE), ir_fresh(C), ir_ins([C, ' = phi i1 [ true, %', LA0, ' ], [ ', CB, ', %', LB1, ' ]']), ir_truth(C, V, T, LL).
ir_expr(bin(Op, A, B), V, T, BL) :- memberchk(Op, ['==', '!=']), ccl_type_of(A, TA0), ccl_type_of(B, TB0), ( ccl_is_complex(TA0) ; ccl_is_complex(TB0) ), !,   % two complex values are equal when both components are (0.100)
    ccl_complex_usual(TA0, TB0, CT), ir_type(CT, LL), ir_complex_elem(LL, EL),
    ir_expr(A, VA, TA, LA), ir_expr(B, VB, TB, LB), ir_convert(VA, TA, LA, CT, LL, A1), ir_convert(VB, TB, LB, CT, LL, B1),
    ir_complex_parts(A1, LL, Ar, Ai), ir_complex_parts(B1, LL, Br, Bi),
    ( ir_fp_ll(EL) -> Cmp = 'fcmp oeq' ; Cmp = 'icmp eq' ),                                       % an integer complex compares its integer components (0.103)
    ir_fresh(C1), ir_ins([C1, ' = ', Cmp, ' ', EL, ' ', Ar, ', ', Br]), ir_fresh(C2), ir_ins([C2, ' = ', Cmp, ' ', EL, ' ', Ai, ', ', Bi]),
    ir_fresh(C3), ir_ins([C3, ' = and i1 ', C1, ', ', C2]), ( Op == '==' -> C = C3 ; ir_fresh(C), ir_ins([C, ' = xor i1 ', C3, ', true']) ), ir_truth(C, V, T, BL).
ir_expr(bin(Op, A, B), V, T, LL) :- ir_cmp_op(bin(Op, A, B), _), !, ir_expr_i1(bin(Op, A, B), C), ir_truth(C, V, T, LL).
ir_expr(bin(Op, A, B), V, T, LL) :- memberchk(Op, ['+', '-', '*', '/']), ccl_type_of(A, TA0), ccl_type_of(B, TB0), ( ccl_is_complex(TA0) ; ccl_is_complex(TB0) ), !,   % COMPLEX ARITHMETIC (Annex G's formulas without the special cases; 0.100)
    ccl_complex_usual(TA0, TB0, T), ir_type(T, LL), ir_complex_elem(LL, EL),
    ir_expr(A, VA, TA, LA), ir_expr(B, VB, TB, LB), ir_convert(VA, TA, LA, T, LL, A1), ir_convert(VB, TB, LB, T, LL, B1),
    ir_complex_parts(A1, LL, Ar, Ai), ir_complex_parts(B1, LL, Br, Bi), ccl_complex_real(T, RT), ir_complex_op(Op, RT, EL, Ar, Ai, Br, Bi, Rr, Ri), ir_complex_make(LL, Rr, Ri, V).
ir_expr(bin(Op, A, B), V, T, LL) :- !, ir_expr(A, VA, TA, LA), ir_binary(Op, VA, TA, LA, B, V, T, LL).
ir_complex_ll(LL) :- ir_complex_elem(LL, _).
ir_complex_elem('{ double, double }', double).
ir_complex_elem('{ x86_fp80, x86_fp80 }', x86_fp80).   % a complex long double (0.108)
ir_complex_elem('{ fp128, fp128 }', fp128).           % ... a quad's (0.131)
ir_complex_elem('{ float, float }', float).
ir_complex_elem('{ i64, i64 }', i64).   ir_complex_elem('{ i32, i32 }', i32).   % `_Complex long', `_Complex int' (0.103)
ir_complex_elem('{ i16, i16 }', i16).   ir_complex_elem('{ i8, i8 }', i8).
ir_complex_parts(V, LL, R, I) :- ir_fresh(R), ir_ins([R, ' = extractvalue ', LL, ' ', V, ', 0']), ir_fresh(I), ir_ins([I, ' = extractvalue ', LL, ' ', V, ', 1']).
ir_complex_make(LL, R, I, V) :- ir_complex_elem(LL, EL), ir_fresh(V1), ir_ins([V1, ' = insertvalue ', LL, ' undef, ', EL, ' ', R, ', 0']), ir_fresh(V), ir_ins([V, ' = insertvalue ', LL, ' ', V1, ', ', EL, ' ', I, ', 1']).
ir_fop(Op, EL, A, B, V) :- ir_fresh(V), ir_ins([V, ' = ', Op, ' ', EL, ' ', A, ', ', B]).
ir_complex_op('+', _, EL, Ar, Ai, Br, Bi, Rr, Ri) :- ( ir_fp_ll(EL) -> Op = fadd ; Op = add ), ir_fop(Op, EL, Ar, Br, Rr), ir_fop(Op, EL, Ai, Bi, Ri).
ir_complex_op('-', _, EL, Ar, Ai, Br, Bi, Rr, Ri) :- ( ir_fp_ll(EL) -> Op = fsub ; Op = sub ), ir_fop(Op, EL, Ar, Br, Rr), ir_fop(Op, EL, Ai, Bi, Ri).
%% AN INTEGER COMPLEX MULTIPLIES AND DIVIDES BY THE TEXTBOOK FORMULAS (0.103), as clang does for `_Complex int' -- no
%% runtime helper, no infinities to recover: (a + bi)(c + di) = (ac - bd) + (ad + bc)i, and the quotient's components
%% are (ac + bd) / (cc + dd) and (bc - ad) / (cc + dd), each an integer division of the real type's signedness
ir_complex_op('*', _, EL, Ar, Ai, Br, Bi, Rr, Ri) :- \+ ir_fp_ll(EL), !,
    ir_fop(mul, EL, Ar, Br, AC), ir_fop(mul, EL, Ai, Bi, BD), ir_fop(sub, EL, AC, BD, Rr), ir_fop(mul, EL, Ar, Bi, AD), ir_fop(mul, EL, Ai, Br, BC), ir_fop(add, EL, AD, BC, Ri).
ir_complex_op('/', RT, EL, Ar, Ai, Br, Bi, Rr, Ri) :- \+ ir_fp_ll(EL), !, ( ir_signed(RT) -> D = sdiv ; D = udiv ),
    ir_fop(mul, EL, Br, Br, CC), ir_fop(mul, EL, Bi, Bi, DD), ir_fop(add, EL, CC, DD, Den),
    ir_fop(mul, EL, Ar, Br, AC), ir_fop(mul, EL, Ai, Bi, BD), ir_fop(add, EL, AC, BD, Nr), ir_fop(D, EL, Nr, Den, Rr),
    ir_fop(mul, EL, Ai, Br, BC), ir_fop(mul, EL, Ar, Bi, AD), ir_fop(sub, EL, BC, AD, Ni), ir_fop(D, EL, Ni, Den, Ri).
%% ANNEX G's MULTIPLICATION AND DIVISION are the C runtime's own (0.101): `__muldc3' and `__divdc3' (`__mulsc3',
%% `__divsc3' for a complex float), which recover the infinities the textbook formulas turn into NaNs and which
%% clang calls at every `*' and `/' of two complex values -- libgcc's and compiler-rt's alike, linked by cc. A
%% complex double comes back as two SSE eightbytes, `{ double, double }'; a complex float as one, `<2 x float>'.
ir_complex_op('*', _, EL, Ar, Ai, Br, Bi, Rr, Ri) :- !, ir_complex_rt(mul, EL, Ar, Ai, Br, Bi, Rr, Ri).
ir_complex_op('/', _, EL, Ar, Ai, Br, Bi, Rr, Ri) :- !, ir_complex_rt(div, EL, Ar, Ai, Br, Bi, Rr, Ri).
ir_complex_rt(Op, double, Ar, Ai, Br, Bi, Rr, Ri) :- !, atomic_list_concat(['__', Op, 'dc3'], F), atomic_list_concat(['declare { double, double } @', F, '(double, double, double, double)'], D), ir_note_extern(F, raw(D)),
    ir_fresh(V), ir_ins([V, ' = call { double, double } @', F, '(double ', Ar, ', double ', Ai, ', double ', Br, ', double ', Bi, ')']), ir_complex_parts(V, '{ double, double }', Rr, Ri).
ir_complex_rt(Op, x86_fp80, Ar, Ai, Br, Bi, Rr, Ri) :- !, atomic_list_concat(['__', Op, 'xc3'], F), atomic_list_concat(['declare { x86_fp80, x86_fp80 } @', F, '(x86_fp80, x86_fp80, x86_fp80, x86_fp80)'], D), ir_note_extern(F, raw(D)),   % a complex long double's product and quotient: __mulxc3, __divxc3, returned on the x87 stack (0.108)
    ir_fresh(V), ir_ins([V, ' = call { x86_fp80, x86_fp80 } @', F, '(x86_fp80 ', Ar, ', x86_fp80 ', Ai, ', x86_fp80 ', Br, ', x86_fp80 ', Bi, ')']), ir_complex_parts(V, '{ x86_fp80, x86_fp80 }', Rr, Ri).
ir_complex_rt(Op, fp128, Ar, Ai, Br, Bi, Rr, Ri) :- !, atomic_list_concat(['__', Op, 'tc3'], F), atomic_list_concat(['declare { fp128, fp128 } @', F, '(fp128, fp128, fp128, fp128)'], D), ir_note_extern(F, raw(D)),   % a quad complex: libgcc's __multc3, __divtc3 (0.131)
    ir_fresh(V), ir_ins([V, ' = call { fp128, fp128 } @', F, '(fp128 ', Ar, ', fp128 ', Ai, ', fp128 ', Br, ', fp128 ', Bi, ')']), ir_complex_parts(V, '{ fp128, fp128 }', Rr, Ri).
ir_complex_rt(Op, float, Ar, Ai, Br, Bi, Rr, Ri) :- ir_arch(aapcs), !, atomic_list_concat(['__', Op, 'sc3'], F), atomic_list_concat(['declare { float, float } @', F, '(float, float, float, float)'], D), ir_note_extern(F, raw(D)),   % AAPCS64 returns a complex float as an HFA, s0 and s1 (0.131)
    ir_fresh(V), ir_ins([V, ' = call { float, float } @', F, '(float ', Ar, ', float ', Ai, ', float ', Br, ', float ', Bi, ')']), ir_complex_parts(V, '{ float, float }', Rr, Ri).
ir_complex_rt(Op, float, Ar, Ai, Br, Bi, Rr, Ri) :- atomic_list_concat(['__', Op, 'sc3'], F), atomic_list_concat(['declare <2 x float> @', F, '(float, float, float, float)'], D), ir_note_extern(F, raw(D)),
    ir_fresh(V), ir_ins([V, ' = call <2 x float> @', F, '(float ', Ar, ', float ', Ai, ', float ', Br, ', float ', Bi, ')']),
    ir_fresh(Rr), ir_ins([Rr, ' = extractelement <2 x float> ', V, ', i32 0']), ir_fresh(Ri), ir_ins([Ri, ' = extractelement <2 x float> ', V, ', i32 1']).
ir_expr(neg(E), V, T, LL) :- ccl_type_of(E, T0), ccl_is_complex(T0), !, ir_expr(E, V0, T, LL), ir_complex_parts(V0, LL, R, I), ir_complex_elem(LL, EL),   % the negation of a complex: both components
    ( ir_fp_ll(EL) -> ir_fresh(R1), ir_ins([R1, ' = fneg ', EL, ' ', R]), ir_fresh(I1), ir_ins([I1, ' = fneg ', EL, ' ', I])
    ; ir_fop(sub, EL, 0, R, R1), ir_fop(sub, EL, 0, I, I1) ), ir_complex_make(LL, R1, I1, V).                    % an integer complex negates by subtraction (0.103)
ir_expr(real_part(E), V, T, LL) :- !, ir_expr(E, V0, T0, L0), ( ir_complex_ll(L0) -> ir_complex_elem(L0, LL), ccl_complex_real(T0, T), ir_fresh(V), ir_ins([V, ' = extractvalue ', L0, ' ', V0, ', 0']) ; V = V0, T = T0, LL = L0 ).   % `__real__ z' (0.100)
ir_expr(imag_part(E), V, T, LL) :- !, ir_expr(E, V0, T0, L0), ( ir_complex_ll(L0) -> ir_complex_elem(L0, LL), ccl_complex_real(T0, T), ir_fresh(V), ir_ins([V, ' = extractvalue ', L0, ' ', V0, ', 1']) ; T = T0, LL = L0, ir_zero(LL, V) ).   % `__imag__ x' of a real is its type's zero
ir_expr(neg(E), V, T, LL) :- ccl_type_of(E, T0), ccl_decimal_kind(T0, K), !, ir_expr(E, V0, T, LL), ir_dec_negate(K, LL, V0, V).   % a decimal's negation flips its sign bit, as gcc does (0.129)
ir_expr(neg(E), V, T, LL) :- !, ir_expr(E, V0, T0, L0), ccl_promote(T0, T), ir_type(T, LL), ir_convert(V0, T0, L0, T, LL, V1),
    ir_fresh(V), ( ir_fp_ll(LL) -> ir_ins([V, ' = fneg ', LL, ' ', V1]) ; ir_signed(T) -> ir_ins([V, ' = sub nsw ', LL, ' 0, ', V1]) ; ir_ins([V, ' = sub ', LL, ' 0, ', V1]) ).
ir_expr(pos(E), V, T, LL) :- !, ir_expr(E, V, T, LL).
ir_expr(bitnot(E), V, T, LL) :- !, ir_expr(E, V0, T0, L0), ccl_promote(T0, T), ir_type(T, LL), ir_convert(V0, T0, L0, T, LL, V1), ir_fresh(V), ir_ins([V, ' = xor ', LL, ' ', V1, ', -1']).
ir_expr(not(E), V, T, LL) :- !, ir_cond(E, C), ir_fresh(C1), ir_ins([C1, ' = xor i1 ', C, ', true']), ir_truth(C1, V, T, LL).
ir_expr(addr(E), Addr, ptr([], T), ptr) :- !, ir_lval(E, Slot, T, _), ir_slot_addr(Slot, Addr).
ir_expr(deref(E), V, T, LL) :- !, ir_lval(deref(E), Slot, T, LT), ir_load_slot(Slot, T, LT, V), ir_value_ll(LT, LL).
ir_expr(index(A, I), V, T, LL) :- !, ir_lval(index(A, I), Slot, T, LT), ir_load_slot(Slot, T, LT, V), ir_value_ll(LT, LL).
ir_expr(member(E, N), V, T, LL) :- !, ir_lval(member(E, N), Slot, T, LT), ir_load_slot(Slot, T, LT, V), ir_value_ll(LT, LL).
ir_expr(arrow(E, N), V, T, LL) :- !, ir_lval(arrow(E, N), Slot, T, LT), ir_load_slot(Slot, T, LT, V), ir_value_ll(LT, LL).
ir_expr(preinc(E), V, T, LL) :- !, ir_step(E, add, pre, V, T, LL).
ir_expr(predec(E), V, T, LL) :- !, ir_step(E, sub, pre, V, T, LL).
ir_expr(postinc(E), V, T, LL) :- !, ir_step(E, add, post, V, T, LL).
ir_expr(postdec(E), V, T, LL) :- !, ir_step(E, sub, post, V, T, LL).
%% A CAST TO A REFERENCE TYPE IS A BIND, never a conversion: `static_cast<_Tp &&>(__t)' is std::forward's whole
%% body, and taken as a value conversion it loaded the int and made a pointer of it (`inttoptr'), so every element
%% a libc++ container constructed held the low half of an address. The value of a reference is its address.
ir_expr(cast(T, E), P, T, ptr) :- ( T = ref(_, _) ; T = rref(_, _) ), !, ir_ref_to(E, T, P).
ir_expr(cast(T, E), V, T, LL) :- ccl_resolve_type(T, memptr(_, _, F)), ccl_resolve_type(F, fn(_, _, _)), !, LL = '{ ptr, i64 }',   % INTO A POINTER TO MEMBER FUNCTION (0.100): from a function's address, `&C::m', or from the int `1 + slot offset' of a virtual one; adj is 0
    ir_expr(E, V0, T0, L0),
    (   L0 == '{ ptr, i64 }' -> V = V0
    ;   ( L0 == ptr -> P = V0 ; ir_convert(V0, T0, L0, base([], [long]), i64, VI), ir_fresh(P), ir_ins([P, ' = inttoptr i64 ', VI, ' to ptr']) ),
        ir_fresh(V1), ir_ins([V1, ' = insertvalue { ptr, i64 } undef, ptr ', P, ', 0']),
        ir_fresh(V), ir_ins([V, ' = insertvalue { ptr, i64 } ', V1, ', i64 0, 1']) ).
ir_expr(cast(T, E), V, T, LL) :- !, ir_expr(E, V0, T0, L0), ( ccl_resolve_type(T, base(_, [void])) -> V = V0, LL = void ; ir_type(T, LL), ir_convert(V0, T0, L0, T, LL, V) ).
ir_expr(sizeof(E), N, T, i64) :- ir_vla_expr_type(E, VT), ir_vla_bytes(VT, N), !, ccl_size_type(T).   % a VLA's, from the bounds it was made with (0.99)
ir_expr(sizeof(E), N, T, i64) :- ccl_literal_bytes(E, N), !, ccl_size_type(T).                             % sizeof a STRING LITERAL is its array's bytes (0.103): typed as the pointer it decays to, `sizeof("abc")' was 8
ir_expr(sizeof(E), N, T, i64) :- !, ccl_size_type(T), ccl_type_of(E, ET),
    (   ccl_resolve_type(ET, arr(NE, ElT)), \+ ccl_const_eval(NE, _), ccl_size_of(ElT, ES)                % sizeof a VLA, asked FIRST (the layout gives an unsized array no bytes, as a flexible member has none): its bound's value times the element, at run time (the bound read where sizeof is, not where the array was declared: named)
    ->  ir_expr(NE, NV0, NT, NL), ir_convert(NV0, NT, NL, base([], [long]), i64, NV), ir_fresh(N), ir_ins([N, ' = mul i64 ', NV, ', ', ES])
    ;   ccl_size_of(ET, N) -> true
    ;   ir_fail(sizeof(E)) ).
ir_expr(va_arg(AP, T0), V, T, LL) :- !, ccl_resolve_type(T0, T), ir_type(T, LL), ir_expr(AP, P, _, _),
    (   ir_arch(aapcs), \+ catch(pp_os(darwin), _, fail) -> ir_va_arg_aapcs(P, T, LL, V)   % Linux aarch64: every type expanded by AAPCS64's own rules (0.131)
    ;   ( ir_is_aggregate(T) ; LL == i128 ; LL == x86_fp80 )
    ->  ( ir_arch(sysv), ir_va_arg_aggregate(P, T, LL, V0) -> V = V0 ; ir_fail(va_arg_of_aggregate(T0)) )   % a struct, a union, a complex, or an __int128 (two INTEGER eightbytes, 16-aligned in the overflow area) (0.117: x86-64's expansion below; AAPCS64's stays refused)
    ;   ir_fresh(V), ir_ins([V, ' = va_arg ptr ', P, ', ', LL]) ).
ir_expr(offsetof(T0, D), N, T, i64) :- !, ccl_size_type(T), ( ccl_offsetof(T0, D, N) -> true ; ir_fail(offsetof(T0, D)) ).
ir_expr(sizeof_type(ET), N, T, i64) :- !, ccl_size_type(T), ( ccl_size_of(ET, N) -> true ; ir_fail(sizeof_type(ET)) ).
ir_expr(alignof_type(ET), N, T, i64) :- !, ccl_size_type(T), ( ccl_const_eval(alignof_type(ET), N) -> true ; ir_fail(alignof_type(ET)) ).
%% A CONDITIONAL OVER TWO VOID ARMS IS VOID ([expr.cond]/2): both arms are evaluated for their effects and the form
%% has no value, so there is nothing to phi -- `phi void' is what LLVM refused (0.95: libc++ 18's string algorithms,
%% found once stdalgorithmstr built inside the cap)
ir_expr(cond(C, A, B), none, base([], [void]), void) :- ccl_type_of(A, TA), ccl_resolve_type(TA, base(_, [void])), !,
    ir_label(LT), ir_label(LF), ir_label(LE), ir_cond(C, CC), ir_end(['br i1 ', CC, ', label %', LT, ', label %', LF]),
    ir_block(LT), ir_expr(A, _, _, _), ir_end(['br label %', LE]),
    ir_block(LF), ir_expr(B, _, _, _), ir_end(['br label %', LE]),
    ir_block(LE).
ir_expr(cond(C, A, B), V, T, LL) :- !,
    ccl_type_of(A, TA), ccl_type_of(B, TB), ( ccl_is_arith(TA), ccl_is_arith(TB) -> ccl_cond_arith(TA, TB, T)   % one arithmetic type in C++ is the conditional's (0.127)
    ; ccl_null_constant(A), ccl_is_pointer(TB) -> T = TB      % `c ? 0 : p' is a POINTER, the literal zero a null pointer constant ([expr.cond]/7, C 6.5.15/6): it was an int, the pointer arm went through `ptrtoint ... to i32' and back, and a heap address lost its high half (libc++'s `deque::end()': `__map_.empty() ? 0 : *__mp + ...', a crash at the first push_back)
    ; T = TA ), ir_type(T, LL),
    ir_label(LT), ir_label(LF), ir_label(LE), ir_cond(C, CC), ir_end(['br i1 ', CC, ', label %', LT, ', label %', LF]),
    ir_block(LT), ir_expr(A, VA0, TA1, LA), ir_convert(VA0, TA1, LA, T, LL, VA), ir_cur_label(LT1), ir_end(['br label %', LE]),
    ir_block(LF), ir_expr(B, VB0, TB1, LB), ir_convert(VB0, TB1, LB, T, LL, VB), ir_cur_label(LF1), ir_end(['br label %', LE]),
    ir_block(LE), ir_fresh(V), ir_ins([V, ' = phi ', LL, ' [ ', VA, ', %', LT1, ' ], [ ', VB, ', %', LF1, ' ]']).
ir_expr(comma(A, B), V, T, LL) :- !, ir_expr(A, _, _, _), ir_expr(B, V, T, LL).
ir_expr(move(E), V, T, LL) :- ir_own_elem(E), !, ir_lval(E, Slot, T, LL), ir_load_slot(Slot, T, LL, V), ir_store_slot(Slot, T, LL, null).   % out of an own array: the slot nulled
ir_expr(move(E), V, T, LL) :- ir_lvalue_form(E), ir_lval(E, Slot, T, LL), ccl_resolve_type(T, T1), T1 = base(_, [struct(_, _)]), ir_has_own_fields(T1), !,   % a struct with owners moved: its own fields nulled behind it (C++: its destructor then frees nothing)
    ir_load_slot(Slot, T, LL, V), ir_slot_addr(Slot, Addr), ir_null_own_fields(Addr, T1).
ir_expr(move(E), V, T, LL) :- !, ir_expr(E, V, T, LL).                        % a move is the value; the checker did the rest
ir_has_own_fields(T) :- ccl_members_of(T, Ms), member(member(MT, _, _), Ms), ( ck_own_type(MT) ; ccl_resolve_type(MT, MT1), MT1 = base(_, [struct(_, _)]), ir_has_own_fields(MT1) ), !.
ir_null_own_fields(Addr, T) :-
    ccl_members_of(T, Ms),
    forall(( member(member(MT, N, _), Ms), N \== anon ),
           (   ck_own_type(MT), ccl_resolve_type(MT, ptr(_, _)) -> ir_member_slot(Addr, T, N, Slot, _), ir_slot_addr(Slot, A), ir_ins(['store ptr null, ptr ', A])
           ;   ccl_resolve_type(MT, MT1), MT1 = base(_, [struct(_, _)]), ir_has_own_fields(MT1) -> ir_member_slot(Addr, T, N, Slot, _), ir_slot_addr(Slot, A), ir_null_own_fields(A, MT1)
           ;   true )).
ir_expr(compound_lit(T, Init), V, T1, LL) :- !,
    ir_fresh(Addr), ir_alloca_typed(Addr, T), ir_init(Addr, T, Init), ir_load_or_decay(Addr, T, V), ccl_resolve_type(T, RT), ( RT = arr(_, E) -> T1 = ptr([], E), LL = ptr ; T1 = T, ir_type(T, LL) ).
ir_expr(stmt_expr(block(Is)), V, T, LL) :- !,
    ir_env_push, ( append(Init, [expr(_, E)], Is) -> ir_stmts(Init), ir_expr(E, V, T, LL) ; ir_stmts(Is), V = none, T = base([], [void]), LL = void ),
    ir_run_defers(1), ir_env_pop.
ir_expr(E, _, _, _) :- ir_fail(expr(E)).
%% the LLVM type of a loaded value: an array decays to its address
ir_value_ll(LT, LL) :- ( sub_atom(LT, 0, 1, _, '[') -> LL = ptr ; LL = LT ).
ir_fp_ll(double). ir_fp_ll(float). ir_fp_ll(half). ir_fp_ll(x86_fp80). ir_fp_ll(fp128).   % fp128: Linux aarch64's long double (0.131); a decimal's carrier is taken apart by its C type first
ir_fp_wider(double, float). ir_fp_wider(double, half). ir_fp_wider(float, half).
ir_fp_wider(x86_fp80, double). ir_fp_wider(x86_fp80, float). ir_fp_wider(x86_fp80, half).
ir_fp_wider(fp128, double). ir_fp_wider(fp128, float). ir_fp_wider(fp128, half).

%% the label of the block the last instruction went into (for phis)
ir_cur_label(L) :- nb_getval('$ir_body', B), ir_last_label(B, L).
ir_last_label([Line|T], L) :- ( sub_atom(Line, _, 1, 0, ':'), \+ sub_atom(Line, 0, 1, _, ' ') -> sub_atom(Line, 0, _, 1, L) ; ir_last_label(T, L) ).
ir_last_label([], entry).

ir_load_or_decay(Addr, T, V) :- ir_type(T, LL), ir_load_or_decay(Addr, T, LL, V).
ir_load_or_decay(Addr, T, LL, V) :-
    ( ccl_resolve_type(T, arr(_, _)) -> V = Addr ; ir_fresh(V), ir_ins([V, ' = load ', LL, ', ptr ', Addr]) ).

ir_expr_i1(bin(Op, A, B), C) :-
    ir_expr(A, VA, TA, LA), ir_expr(B, VB, TB, LB),
    (   ( LA == ptr ; LB == ptr ) -> ir_to_ptr(VA, TA, LA, PA), ir_to_ptr(VB, TB, LB, PB), ir_icmp(Op, false, ptr, PA, PB, C)
    ;   ccl_usual(TA, TB, T), ccl_decimal_kind(T, K) -> ir_type(T, LL), ir_convert(VA, TA, LA, T, LL, A1), ir_convert(VB, TB, LB, T, LL, B1), ir_dec_cmp(Op, K, LL, A1, B1, C)   % decimals: libgcc's comparisons (0.129)
    ;   ccl_usual(TA, TB, T), ir_type(T, LL), ir_convert(VA, TA, LA, T, LL, A1), ir_convert(VB, TB, LB, T, LL, B1),
        ( ir_fp_ll(LL) -> ir_fcmp(Op, LL, A1, B1, C) ; ( ir_signed(T) -> S = true ; S = false ), ir_icmp(Op, S, LL, A1, B1, C) ) ).
ir_to_ptr(V, T, L, P) :- ( L == ptr -> P = V ; V == 0 -> P = null ; ir_convert(V, T, L, ptr([], base([], [void])), ptr, P) ).
ir_icmp(Op, S, LL, A, B, C) :- ir_icmp_pred(Op, S, P), ir_fresh(C), ir_ins([C, ' = icmp ', P, ' ', LL, ' ', A, ', ', B]).
ir_icmp_pred('==', _, eq). ir_icmp_pred('!=', _, ne).
ir_icmp_pred('<', true, slt). ir_icmp_pred('<', false, ult). ir_icmp_pred('>', true, sgt). ir_icmp_pred('>', false, ugt).
ir_icmp_pred('<=', true, sle). ir_icmp_pred('<=', false, ule). ir_icmp_pred('>=', true, sge). ir_icmp_pred('>=', false, uge).
ir_fcmp(Op, LL, A, B, C) :- ir_fcmp_pred(Op, P), ir_fresh(C), ir_ins([C, ' = fcmp ', P, ' ', LL, ' ', A, ', ', B]).
ir_fcmp_pred('==', oeq). ir_fcmp_pred('!=', une). ir_fcmp_pred('<', olt). ir_fcmp_pred('>', ogt). ir_fcmp_pred('<=', ole). ir_fcmp_pred('>=', oge).

%% a binary arithmetic/bitwise/shift operator over a lowered left operand
ir_binary(Op, VA, TA, LA, B, V, T, LL) :-
    ir_expr(B, VB, TB, LB),
    (   Op == '-', LA == ptr, LB == ptr ->                                          % p - q
            ir_elem(TA, E), ccl_size_of(E, Sz), ir_long(T), LL = i64,
            ir_op1(ptrtoint, ptr, VA, i64, A1), ir_op1(ptrtoint, ptr, VB, i64, B1),
            ir_fresh(D), ir_ins([D, ' = sub i64 ', A1, ', ', B1]), ir_fresh(V), ir_ins([V, ' = sdiv exact i64 ', D, ', ', Sz])
    ;   memberchk(Op, ['+', '-']), LA == ptr -> ir_ptr_add(Op, VA, TA, VB, TB, LB, V), ir_decayed(TA, T), LL = ptr
    ;   Op == '+', LB == ptr -> ir_ptr_add('+', VB, TB, VA, TA, LA, V), ir_decayed(TB, T), LL = ptr
    ;   ccl_usual(TA, TB, T), ccl_decimal_kind(T, K) -> ir_type(T, LL), ir_convert(VA, TA, LA, T, LL, A1), ir_convert(VB, TB, LB, T, LL, B1), ir_dec_arith(Op, K, LL, A1, B1, V)   % decimals: libgcc's arithmetic (0.129)
    ;   ccl_usual(TA, TB, T0), ( memberchk(Op, ['<<', '>>']) -> ccl_promote(TA, T) ; T = T0 ),
        ir_type(T, LL), ir_convert(VA, TA, LA, T, LL, A1), ir_convert(VB, TB, LB, T, LL, B1),
        ir_arith_op(Op, T, LL, Ins), ir_fresh(V), ir_ins([V, ' = ', Ins, ' ', LL, ' ', A1, ', ', B1]) ).
ir_decayed(T, D) :- ccl_resolve_type(T, T1), ( T1 = arr(_, E) -> D = ptr([], E) ; D = T ).
ir_ptr_add(Op, P, PT, I, IT, IL, V) :-
    ir_elem(PT, E), ir_type(E, EL), ir_convert(I, IT, IL, base([], [long]), i64, I1),
    ( Op == '-' -> ir_fresh(N), ir_ins([N, ' = sub i64 0, ', I1]) ; N = I1 ),
    ir_fresh(V), ir_ins([V, ' = getelementptr inbounds ', EL, ', ptr ', P, ', i64 ', N]).
%% signed overflow is undefined in C, so signed integer arithmetic is `nsw':
%% LLVM then widens loop counters and drops the sign extensions before an
%% index (every address is `inbounds' for the same reason: past the object
%% is undefined too); together a third of a B-tree's search time
ir_arith_op('+', T, LL, Ins) :- ( ir_fp_ll(LL) -> Ins = fadd ; ir_signed(T) -> Ins = 'add nsw' ; Ins = add ).
ir_arith_op('-', T, LL, Ins) :- ( ir_fp_ll(LL) -> Ins = fsub ; ir_signed(T) -> Ins = 'sub nsw' ; Ins = sub ).
ir_arith_op('*', T, LL, Ins) :- ( ir_fp_ll(LL) -> Ins = fmul ; ir_signed(T) -> Ins = 'mul nsw' ; Ins = mul ).
ir_arith_op('/', T, LL, Ins) :- ( ir_fp_ll(LL) -> Ins = fdiv ; ir_signed(T) -> Ins = sdiv ; Ins = udiv ).
ir_arith_op('%', T, LL, Ins) :- ( ir_fp_ll(LL) -> Ins = frem ; ir_signed(T) -> Ins = srem ; Ins = urem ).
ir_arith_op('&', _, _, and). ir_arith_op('|', _, _, or). ir_arith_op('^', _, _, xor). ir_arith_op('<<', _, _, shl).
ir_arith_op('>>', T, _, Ins) :- ( ir_signed(T) -> Ins = ashr ; Ins = lshr ).

%% ++ and --, on integers, floats and pointers
ir_step(E, Op, When, V, T, LL) :- ir_lval(E, Slot, T, LL), ir_step_(Slot, Op, When, V, T, LL).   % the place taken ONCE, as a compound assignment's (0.112)
ir_step_(Slot, Op, When, V, T, LL) :- atom(Slot), ir_atomic_q(T), ir_int_ll(LL), !,   % `x++' on an `_Atomic' object: one atomicrmw (0.99)
    ir_fresh(Old), ir_ins([Old, ' = atomicrmw ', Op, ' ptr ', Slot, ', ', LL, ' 1 seq_cst']), ( When == pre -> ir_fresh(V), ir_ins([V, ' = ', Op, ' ', LL, ' ', Old, ', 1']) ; V = Old ).
ir_step_(Slot, Op, When, V, T, LL) :-
    ir_load_slot(Slot, T, LL, Cur),
    ir_fresh(New),
    (   ccl_decimal_kind(T, K) -> ( Op == add -> DOp = '+' ; DOp = '-' ), ir_dec_one(K, One), ir_dec_arith_into(DOp, K, LL, Cur, One, New)   % a decimal steps by its one (0.129)
    ;   LL == ptr -> ir_elem(T, El), ir_type(El, ELL), ( Op == add -> D = 1 ; D = -1 ), ir_ins([New, ' = getelementptr inbounds ', ELL, ', ptr ', Cur, ', i64 ', D])
    ;   ir_fp_ll(LL) -> ( Op == add -> F = fadd ; F = fsub ), ir_fp_const(1.0, LL, One), ir_ins([New, ' = ', F, ' ', LL, ' ', Cur, ', ', One])
    ;   ir_signed(T) -> ir_ins([New, ' = ', Op, ' nsw ', LL, ' ', Cur, ', 1'])
    ;   ir_ins([New, ' = ', Op, ' ', LL, ' ', Cur, ', 1']) ),
    ir_store_slot(Slot, T, LL, New),
    ( When == pre -> V = New ; V = Cur ).

%% ---- own arrays: the drains the source did not write ---------------------------------------
%% `own node *c[4]' holds owners the check cannot tell apart, so the lowering
%% keeps them: every non-null element freed (its own struct drained first)
%% when the struct holding the array is freed -- through one generated
%% function per struct with an own array, ccl_drain_<tag>(T *x), recursive as
%% the type is -- or when a local array's scope ends (a defer registered at
%% the declaration); the old element freed when one is overwritten; the slot
%% nulled when an element is moved out or handed to a consumer.
ir_own_elem(index(A, _)) :- ccl_type_of(A, AT), AT \== unknown, ck_own_array_type(AT).
ir_needs_drain(T) :- ccl_resolve_type(T, T1), T1 = base(_, [struct(_, _)]), ck_has_own_array(T1).
ir_struct_tag(T, Tag) :- ccl_resolve_type(T, base(_, [struct(Tag, _)])).
ir_drain_name(T, D) :- ir_struct_tag(T, Tag), atom_concat(ccl_drain_, Tag, D).
%% the functions: one per tagged struct in the symbol table with an own array
ir_drain_functions(Fns) :-
    ccl_tab_list('$ccl_tags', Tags),
    findall(F, ( member(Tag-Ms, Tags), Tag \== anon, Ms \== none, T = base([], [struct(Tag, Ms)]), ck_has_own_array(T), ir_drain_function(Tag, Ms, F) ), Fns).
ir_drain_function(Tag, Ms, function(0, static, base([], [void]), D, [param(ptr([], base([], [struct(Tag, none)])), x)], false, block(Loops))) :-
    atom_concat(ccl_drain_, Tag, D), ir_array_loops(Ms, id(x), arrow, Loops).
ir_array_loops([], _, _, []).
ir_array_loops([member(MT, F, _)|Ms], Base, How, Loops) :-
    ( How == arrow -> P = arrow(Base, F) ; P = member(Base, F) ),
    (   F \== anon, ck_own_array_type(MT) -> ir_array_bound(MT, Base, How, Bound), ir_drain_loop(P, MT, Bound, Loop), Loops = [Loop|Loops1]
    ;   F \== anon, ccl_resolve_type(MT, MT1), MT1 = base(_, [struct(_, _)]), ck_has_own_array(MT1) -> ccl_members_of(MT1, Sub), ir_array_loops(Sub, P, member, L0), append(L0, Loops1, Loops)
    ;   Loops = Loops1 ),
    ir_array_loops(Ms, Base, How, Loops1).
%% the bound of an own array member: its constant, or the sibling field it names (`own T *a[n]')
ir_array_bound(MT, Base, How, Bound) :-
    ccl_resolve_type(MT, arr(NE, _)),
    ( ck_const(NE, N) -> Bound = int(N) ; NE = id(B), ( How == arrow -> Bound = arrow(Base, B) ; Bound = member(Base, B) ) ).
%% for (int i = 0; i < Bound; i++) if (a[i]) { ccl_drain_T(a[i]); free(a[i]); }
ir_drain_loop(Path, T, Bound, for(0, decl(base([], [int]), [var(I, base([], [int]), int(0))]), bin('<', id(I), Bound), postinc(id(I)), if(0, Elem, block(Calls), none))) :-
    ccl_resolve_type(T, arr(_, ET)), ccl_gensym(i, I), Elem = index(Path, id(I)),
    (   ccl_resolve_type(ET, ptr(_, PT)), ir_needs_drain(PT), ir_drain_name(PT, D) -> Calls = [expr(0, call(id(D), [Elem])), expr(0, drain_free(Elem))]
    ;   Calls = [expr(0, drain_free(Elem))] ).
%% free(p) of a struct with an own array: the drain first
ir_drain_free(E, S) :-
    ck_strip_move(E, E0), ccl_type_of(E0, T), T \== unknown, ccl_resolve_type(T, ptr(_, PT)), ir_needs_drain(PT), ir_drain_name(PT, D),
    (   E = id(_) -> S = stmt_expr(block([expr(0, call(id(D), [E])), expr(0, drain_free(E))]))
    ;   ccl_gensym(drain, Tmp), ccl_base_of(T, Base),
        S = stmt_expr(block([declaration(0, none, Base, [var(Tmp, T, E)]), expr(0, call(id(D), [id(Tmp)])), expr(0, drain_free(id(Tmp)))])) ).
%% an element handed to a consumer (free, fclose, an own parameter) is moved out: the slot nulled
ir_moved_args(F, Args, Args1) :-
    (   F = id(_) -> Callee = F
    ;   ccl_type_of(F, FT), FT \== unknown, ck_fn_params(FT, Ps) -> Callee = params(Ps)
    ;   Callee = none ),
    ir_moved_args_(Args, Callee, 1, Args1).
ir_moved_args_([], _, _, []).
ir_moved_args_([A|As], Callee, I, [A1|As1]) :-
    ( Callee \== none, A = index(_, _), ir_own_elem(A), ck_consumes(Callee, I) -> A1 = move(A) ; A1 = A ),
    I1 is I + 1, ir_moved_args_(As, Callee, I1, As1).
%% a[i] = R: ({ T **p = &a[i]; T *n = R; if (*p) { drain(*p); free(*p); } *p = n; })
ir_elem_assign(L, R, stmt_expr(block([declaration(0, none, Base, [var(P, ptr([], ET), addr(L))]),
                                      declaration(0, none, Base, [var(N, ET, R)]),
                                      if(0, deref(id(P)), block(Calls), none),
                                      expr(0, assign('=', deref(id(P)), id(N)))]))) :-
    L = index(A, _), ccl_type_of(A, AT), ccl_resolve_type(AT, arr(_, ET)), ccl_base_of(ET, Base),
    ccl_gensym(slot, P), ccl_gensym(new, N),
    (   ccl_resolve_type(ET, ptr(_, PT)), ir_needs_drain(PT), ir_drain_name(PT, D) -> Calls = [expr(0, call(id(D), [deref(id(P))])), expr(0, drain_free(deref(id(P))))]
    ;   Calls = [expr(0, drain_free(deref(id(P))))] ).
%% a local own array: drained at every exit of its scope, as a defer
ir_array_defers([], _).
ir_array_defers([var(N, T, _)|Vs], Sto) :-
    ( Sto \== extern, ck_own_array_type(T) -> ccl_resolve_type(T, arr(NE, _)), ck_const(NE, K), ir_drain_loop(id(N), T, int(K), Loop), ir_defer_push(block([Loop])) ; true ),
    ir_array_defers(Vs, Sto).

%% ---- calls ------------------------------------------------------------------------------
%% THE BIT BUILTINS AT RUN TIME are LLVM's intrinsics -- 0.60 folded them where the argument was a constant:
%% __builtin_clz*, __builtin_ctz*, __builtin_popcount*, and the generic `g' forms, over the argument's own width; a
%% zero is defined (the count is the width), which is what libc++'s __countl_zero guards for in any case. An int
%% comes back, as C has it. The intrinsic's declaration is a raw line (an `i1' has no C spelling for the table).
ir_call(id(B), [X|Rest], V, base([], [int])) :- ir_bit_builtin(B, Intr), ( Rest = [] ; Rest = [_] ), !,   % the generic forms take a second argument: the value for a zero
    ir_expr(X, XV, _, XL), ir_bit_width(XL, W), atomic_list_concat(['llvm.', Intr, '.i', W], Name),
    (   Intr == ctpop -> atomic_list_concat(['declare i', W, ' @', Name, '(i', W, ')'], Decl), Extra = ''
    ;   atomic_list_concat(['declare i', W, ' @', Name, '(i', W, ', i1)'], Decl), Extra = ', i1 false' ),
    ir_note_extern(Name, raw(Decl)),
    ir_fresh(R), ir_ins([R, ' = call i', W, ' @', Name, '(i', W, ' ', XV, Extra, ')']),
    (   W =:= 32 -> C = R
    ;   W > 32 -> ir_fresh(C), ir_ins([C, ' = trunc i', W, ' ', R, ' to i32'])
    ;   ir_fresh(C), ir_ins([C, ' = zext i', W, ' ', R, ' to i32']) ),
    (   Rest = [Fb] -> ir_expr(Fb, FV0, FT, FL), ir_convert(FV0, FT, FL, base([], [int]), i32, FV),
        ir_fresh(Z), ir_ins([Z, ' = icmp eq i', W, ' ', XV, ', 0']), ir_fresh(V), ir_ins([V, ' = select i1 ', Z, ', i32 ', FV, ', i32 ', C])
    ;   V = C ).
ir_bit_builtin(B, I) :- ccl_bit_builtin(B, I).   % the table is the inference's (0.129: it types the call)
ir_bit_width(LL, W) :- atom(LL), atom_concat(i, A, LL), atom_number(A, W), integer(W), W > 0.   % any integer width (0.129): an `unsigned __int128' is `i128' -- libc++ 21's __countl_zero calls __builtin_clzg on one, libc++ 18 split it in two 64-bit calls -- and a `_BitInt(N)' its own `iN'
%% THE OVERFLOW BUILTINS, `__builtin_add_overflow(a, b, &r)' and kin, which C23's <stdckdint.h> is written on
%% (`ckd_add(&r, a, b)'): the exact result, computed in i128 over the operands widened by their own signedness (a
%% 64-bit product fits), stored truncated to the result's type, and a bool saying whether that truncation lost
%% anything -- the value read back and widened again differs from the exact one. Any integer types on either side.
ir_call(id(B), [A, C, R], V, base([], [bool])) :- ccl_overflow_builtin(B, Op), !,
    ir_expr(A, AV, AT, AL), ir_expr(C, CV, CT, CL), ir_expr(R, RV, RT, _),
    ccl_resolve_type(RT, RT1), ( RT1 = ptr(_, ET0) -> true ; ir_fail(overflow_result(B)) ), ccl_resolve_type(ET0, ET), ir_type(ET, EL),
    ir_widen128(AV, AT, AL, AW), ir_widen128(CV, CT, CL, CW),
    ir_fresh(X), ir_ins([X, ' = ', Op, ' i128 ', AW, ', ', CW]),
    ( EL == i128 -> T = X ; ir_fresh(T), ir_ins([T, ' = trunc i128 ', X, ' to ', EL]) ),
    ir_ins(['store ', EL, ' ', T, ', ptr ', RV]),
    ir_widen128(T, ET, EL, Y),
    ir_fresh(Cm), ir_ins([Cm, ' = icmp ne i128 ', X, ', ', Y]),
    ir_fresh(V), ir_ins([V, ' = zext i1 ', Cm, ' to i8']).
ir_widen128(V, T, LL, W) :- ( LL == i128 -> W = V ; ir_is_bool(T) -> ir_op1(zext, LL, V, i128, W) ; ir_signed(T) -> ir_op1(sext, LL, V, i128, W) ; ir_op1(zext, LL, V, i128, W) ).
%% `__builtin_unreachable()' -- C23's `unreachable()' in <stddef.h> -- is LLVM's terminator of that name
ir_call(id('__builtin_unreachable'), [], none, base([], [void])) :- !, ir_end(['unreachable']).
%% THE VARIABLE ARGUMENT LIST (0.108): `va_start', `va_end' and `va_copy' are LLVM's intrinsics over the list's
%% address -- a local va_list decays to it, a va_list parameter is it -- and `va_arg' LLVM's own instruction, which
%% the x86-64 and AArch64 backends expand by the ABI's rules for a scalar or a pointer; a struct read by va_arg is
%% refused by name (clang expands that one itself)
ir_call(id(B), [AP|Rest], none, base([], [void])) :- ir_va_intrinsic(B, I, N), length([AP|Rest], K), K >= N, !,
    ir_expr(AP, P, _, _), ( N == 2 -> Rest = [S|_], ir_expr(S, PS, _, _), As = ['ptr ', P, ', ptr ', PS], D = '(ptr, ptr)' ; As = ['ptr ', P], D = '(ptr)' ),
    atomic_list_concat(['declare void @', I, D], Decl), ir_note_extern(I, raw(Decl)), append(['call void @', I, '(' | As], [')'], Ins), ir_ins(Ins).
ir_va_intrinsic('__builtin_va_start', 'llvm.va_start', 1).
ir_va_intrinsic('__builtin_va_end', 'llvm.va_end', 1).
ir_va_intrinsic('__builtin_va_copy', 'llvm.va_copy', 2).
%% `va_arg' OF A STRUCT, A UNION OR A COMPLEX ON x86-64 (SysV 3.5.7, 0.117). LLVM's `va_arg' instruction cannot expand an
%% aggregate -- clang writes that expansion itself, and so does this lowering -- over the list's four fields: gp_offset
%% (i32 at 0), fp_offset (i32 at 4), overflow_arg_area (ptr at 8) and reg_save_area (ptr at 16). A value that ir_abi
%% passes in registers (`direct') takes them when the saved registers still hold all its eightbytes -- gp_offset
%% <= 48 - 8 * INTEGER eightbytes and fp_offset <= 176 - 16 * SSE eightbytes -- and then each eightbyte is read from
%% the slot of its own class (an INTEGER one 8 bytes on from the last, an SSE one 16) into a temporary, and the two
%% offsets move on; otherwise, and always for a value that goes in memory, it lies in the overflow area, which is
%% aligned to 16 for a type that needs more than 8, and moves on by the size rounded up to 8. The value is then
%% loaded from the temporary or from the area.
ir_va_arg_aggregate(P, T, LL, V) :-
    ( LL == i128 -> Abi = direct([piece(i64, 0), piece(i64, 8)]) ; LL == x86_fp80 -> Abi = memory(LL, 16) ; ir_abi(T, Abi) ), ccl_size_align(T, Size, Align),   % a long double is X87: always the overflow area, aligned 16 (0.131: LLVM's own va_arg read it wrong)
    ir_label(LM), ir_label(LJ),
    (   Abi = direct(Pcs), Size > 0
    ->  ir_piece_classes(Pcs, 0, 0, NG, NS), ir_label(LR), ir_tmp(LL, Tmp),
        ir_fresh(FpP), ir_ins([FpP, ' = getelementptr i8, ptr ', P, ', i64 4']),
        ir_fresh(RsP), ir_ins([RsP, ' = getelementptr i8, ptr ', P, ', i64 16']),
        ir_fresh(Gp), ir_ins([Gp, ' = load i32, ptr ', P]), ir_fresh(Fp), ir_ins([Fp, ' = load i32, ptr ', FpP]),
        GpMax is 48 - NG * 8, FpMax is 176 - NS * 16,
        ir_fresh(C1), ir_ins([C1, ' = icmp ule i32 ', Gp, ', ', GpMax]), ir_fresh(C2), ir_ins([C2, ' = icmp ule i32 ', Fp, ', ', FpMax]),
        ir_fresh(C), ir_ins([C, ' = and i1 ', C1, ', ', C2]), ir_end(['br i1 ', C, ', label %', LR, ', label %', LM]),
        ir_block(LR), ir_fresh(Rs), ir_ins([Rs, ' = load ptr, ptr ', RsP]),
        ir_va_fetch(Pcs, Rs, Gp, Fp, 0, 0, Tmp),
        ( NG > 0 -> GpN is NG * 8, ir_fresh(Gp2), ir_ins([Gp2, ' = add i32 ', Gp, ', ', GpN]), ir_ins(['store i32 ', Gp2, ', ptr ', P]) ; true ),
        ( NS > 0 -> FpN is NS * 16, ir_fresh(Fp2), ir_ins([Fp2, ' = add i32 ', Fp, ', ', FpN]), ir_ins(['store i32 ', Fp2, ', ptr ', FpP]) ; true ),
        ir_cur_label(LR1), ir_end(['br label %', LJ]),
        ir_block(LM), ir_va_overflow(P, Size, Align, Oa), ir_cur_label(LM1), ir_end(['br label %', LJ]),
        ir_block(LJ), ir_fresh(Addr), ir_ins([Addr, ' = phi ptr [ ', Tmp, ', %', LR1, ' ], [ ', Oa, ', %', LM1, ' ]'])
    ;   Abi = memory(_, _)
    ->  ir_end(['br label %', LM]), ir_block(LM), ir_va_overflow(P, Size, Align, Addr), ir_end(['br label %', LJ]), ir_block(LJ)
    ),
    ir_fresh(V), ir_ins([V, ' = load ', LL, ', ptr ', Addr]).
%% `va_arg' ON LINUX AARCH64 (AAPCS64 B.4, as clang expands it; 0.131). The va_list is { ptr __stack, ptr __gr_top, ptr
%% __vr_top, i32 __gr_offs, i32 __vr_offs }; LLVM's own `va_arg' takes it for Apple's `char *', and read a scalar wrong
%% here. A floating scalar or an HFA is read from the SIMD registers' save area (__vr_offs, 16 bytes a register, an HFA's
%% members one register each, gathered into a temporary), anything else from the general registers' (__gr_offs, 8 bytes a
%% register, a 16-aligned value from an even one), a composite past 16 bytes as the pointer it was passed by. An offset
%% that is already 0 or more, or that the value takes past 0, sends it to the stack (__stack: aligned 16 for a type that
%% needs it, moved on by the size rounded up to 8), and the registers it took are not given back (AAPCS64's rule).
ir_va_arg_aapcs(P, T, LL, V) :-
    ccl_size_align(T, Size, Align), ( ir_is_aggregate(T) -> ir_abi(T, Abi) ; Abi = scalar ),
    (   Abi = indirect(_, _) -> Ind = yes, Fpr = no, RegSize = 8, NElt = 0
    ;   ir_va_fpr(LL, Abi, NElt, EltLL, EltSize) -> Ind = no, Fpr = yes, RegSize is 16 * NElt
    ;   Ind = no, Fpr = no, NElt = 0, RegSize is (Size + 7) // 8 * 8 ),
    ( Fpr == yes -> OffsAt = 28, TopAt = 16 ; OffsAt = 24, TopAt = 8 ),
    ir_label(LMaybe), ir_label(LReg), ir_label(LStack), ir_label(LEnd),
    ir_fresh(OffsP), ir_ins([OffsP, ' = getelementptr i8, ptr ', P, ', i64 ', OffsAt]),
    ir_fresh(Offs0), ir_ins([Offs0, ' = load i32, ptr ', OffsP]),
    ir_fresh(C0), ir_ins([C0, ' = icmp sge i32 ', Offs0, ', 0']), ir_end(['br i1 ', C0, ', label %', LStack, ', label %', LMaybe]),
    ir_block(LMaybe),
    (   Fpr == no, Ind == no, Align > 8 -> ir_fresh(O1), ir_ins([O1, ' = add i32 ', Offs0, ', 15']), ir_fresh(Offs), ir_ins([Offs, ' = and i32 ', O1, ', -16'])
    ;   Offs = Offs0 ),
    ir_fresh(New), ir_ins([New, ' = add i32 ', Offs, ', ', RegSize]), ir_ins(['store i32 ', New, ', ptr ', OffsP]),
    ir_fresh(C1), ir_ins([C1, ' = icmp sle i32 ', New, ', 0']), ir_end(['br i1 ', C1, ', label %', LReg, ', label %', LStack]),
    ir_block(LReg),
    ir_fresh(TopP), ir_ins([TopP, ' = getelementptr i8, ptr ', P, ', i64 ', TopAt]), ir_fresh(Top), ir_ins([Top, ' = load ptr, ptr ', TopP]),
    ir_fresh(O64), ir_ins([O64, ' = sext i32 ', Offs, ' to i64']), ir_fresh(RA), ir_ins([RA, ' = getelementptr i8, ptr ', Top, ', i64 ', O64]),
    ( Fpr == yes, NElt > 1 -> ir_tmp(LL, Tmp), ir_va_hfa_copy(0, NElt, EltLL, EltSize, RA, Tmp), RegAddr = Tmp ; RegAddr = RA ),
    ir_cur_label(LR1), ir_end(['br label %', LEnd]),
    ir_block(LStack), ir_fresh(SP0), ir_ins([SP0, ' = load ptr, ptr ', P]),
    (   Ind == no, Align > 8
    ->  ir_fresh(I0), ir_ins([I0, ' = ptrtoint ptr ', SP0, ' to i64']), ir_fresh(I1), ir_ins([I1, ' = add i64 ', I0, ', 15']),
        ir_fresh(I2), ir_ins([I2, ' = and i64 ', I1, ', -16']), ir_fresh(SP), ir_ins([SP, ' = inttoptr i64 ', I2, ' to ptr'])
    ;   SP = SP0 ),
    ( Ind == yes -> Step = 8 ; Step is (Size + 7) // 8 * 8 ),
    ir_fresh(SN), ir_ins([SN, ' = getelementptr i8, ptr ', SP, ', i64 ', Step]), ir_ins(['store ptr ', SN, ', ptr ', P]),
    ir_cur_label(LS1), ir_end(['br label %', LEnd]),
    ir_block(LEnd), ir_fresh(A0), ir_ins([A0, ' = phi ptr [ ', RegAddr, ', %', LR1, ' ], [ ', SP, ', %', LS1, ' ]']),
    ( Ind == yes -> ir_fresh(A), ir_ins([A, ' = load ptr, ptr ', A0]) ; A = A0 ),
    ir_fresh(V), ir_ins([V, ' = load ', LL, ', ptr ', A]).
%% the SIMD registers' kind: a floating scalar one register, an HFA (`[K x T]', ir_abi_/6) K registers of its member's type
ir_va_fpr(LL, scalar, 1, LL, Sz) :- memberchk(LL-Sz, [float-4, double-8, half-2, fp128-16]), !.
ir_va_fpr(_, direct([piece(P, 0)]), K, ET, Sz) :- atom(P), atom_concat('[', R0, P), atomic_list_concat([KA, Rest], ' x ', R0), atom_concat(ET, ']', Rest),
    memberchk(ET-Sz, [float-4, double-8, fp128-16]), atom_number(KA, K).
%% an HFA's members, each from its own 16-byte register slot into the temporary, one after the other
ir_va_hfa_copy(I, N, _, _, _, _) :- I >= N, !.
ir_va_hfa_copy(I, N, ET, Sz, RA, Tmp) :- SO is I * 16, DO is I * Sz,
    ir_fresh(S), ir_ins([S, ' = getelementptr i8, ptr ', RA, ', i64 ', SO]), ir_fresh(X), ir_ins([X, ' = load ', ET, ', ptr ', S]),
    ir_fresh(D), ir_ins([D, ' = getelementptr i8, ptr ', Tmp, ', i64 ', DO]), ir_ins(['store ', ET, ' ', X, ', ptr ', D]),
    I1 is I + 1, ir_va_hfa_copy(I1, N, ET, Sz, RA, Tmp).
%% the INTEGER and the SSE eightbytes of a direct value: an integer piece is INTEGER, a floating one SSE
ir_piece_classes([], G, S, G, S).
ir_piece_classes([piece(PLL, _)|Ps], G0, S0, G, S) :-
    ( memberchk(PLL, [double, float, '<2 x float>', fp128]) -> G1 = G0, S1 is S0 + 1 ; G1 is G0 + 1, S1 = S0 ), ir_piece_classes(Ps, G1, S1, G, S).
%% each piece from the saved registers into the temporary: the INTEGER ones from gp_offset on, 8 bytes apart, the SSE ones from fp_offset on, 16 apart
ir_va_fetch([], _, _, _, _, _, _).
ir_va_fetch([piece(PLL, Off)|Ps], Rs, Gp, Fp, GA, FA, Tmp) :-
    (   memberchk(PLL, [double, float, '<2 x float>', fp128]) -> Base = Fp, Add = FA, GA1 = GA, FA1 is FA + 16
    ;   Base = Gp, Add = GA, GA1 is GA + 8, FA1 = FA ),
    ( Add == 0 -> Ix = Base ; ir_fresh(Ix), ir_ins([Ix, ' = add i32 ', Base, ', ', Add]) ),
    ir_fresh(Ix64), ir_ins([Ix64, ' = zext i32 ', Ix, ' to i64']),
    ir_fresh(Src), ir_ins([Src, ' = getelementptr i8, ptr ', Rs, ', i64 ', Ix64]),
    ir_fresh(Val), ir_ins([Val, ' = load ', PLL, ', ptr ', Src]),
    ir_fresh(Dst), ir_ins([Dst, ' = getelementptr i8, ptr ', Tmp, ', i64 ', Off]), ir_ins(['store ', PLL, ' ', Val, ', ptr ', Dst]),
    ir_va_fetch(Ps, Rs, Gp, Fp, GA1, FA1, Tmp).
%% the overflow area: the argument's address (aligned to 16 when its type needs more than 8) and the area moved on by its size rounded up to 8
ir_va_overflow(P, Size, Align, Addr) :-
    ir_fresh(OvP), ir_ins([OvP, ' = getelementptr i8, ptr ', P, ', i64 8']), ir_fresh(Oa), ir_ins([Oa, ' = load ptr, ptr ', OvP]),
    (   Align > 8
    ->  ir_fresh(I0), ir_ins([I0, ' = ptrtoint ptr ', Oa, ' to i64']), ir_fresh(I1), ir_ins([I1, ' = add i64 ', I0, ', 15']),
        ir_fresh(I2), ir_ins([I2, ' = and i64 ', I1, ', -16']), ir_fresh(Addr), ir_ins([Addr, ' = inttoptr i64 ', I2, ' to ptr'])
    ;   Addr = Oa ),
    Step is (Size + 7) // 8 * 8,
    ir_fresh(Next), ir_ins([Next, ' = getelementptr i8, ptr ', Addr, ', i64 ', Step]), ir_ins(['store ptr ', Next, ', ptr ', OvP]).
%% THE ATOMIC BUILTINS ARE LLVM'S OWN INSTRUCTIONS, never a call to anything: `__atomic_add_fetch(p, -1,
%% __ATOMIC_ACQ_REL)' is how libc++'s shared_ptr counts its owners (__libcpp_atomic_refcount_decrement), and the
%% compiler is asked for it by name. An `atomicrmw' answers the OLD value, so a `*_fetch' form applies the
%% operation once more to it and a `fetch_*' form takes it as it is; a load and a store carry the ordering and the
%% type's alignment. The memory order is the constant the header spells -- clang's own numbering, which this
%% preprocessor predefines (__ATOMIC_RELAXED 0 .. __ATOMIC_SEQ_CST 5) -- and anything that does not fold is
%% sequentially consistent, the standard's own default.
ir_call(id(B), [P, X, MO], V, ET) :- ir_atomic_rmw(B, Op, After), !,
    ir_atomic_place(B, P, PV, ET, EL), ir_expr(X, XV0, XT, XL), ir_convert(XV0, XT, XL, ET, EL, XV), ir_atomic_order(MO, Ord),
    ir_fresh(R), ir_ins([R, ' = atomicrmw ', Op, ' ptr ', PV, ', ', EL, ' ', XV, ' ', Ord]),
    ( After == none -> V = R ; ir_fresh(V), ir_ins([V, ' = ', After, ' ', EL, ' ', R, ', ', XV]) ).
ir_call(id('__atomic_load_n'), [P, MO], V, ET) :- !,
    ir_atomic_place('__atomic_load_n', P, PV, ET, EL), ir_atomic_order(MO, Ord), ir_atomic_align(ET, A),
    ir_fresh(V), ir_ins([V, ' = load atomic ', EL, ', ptr ', PV, ' ', Ord, ', align ', A]).
ir_call(id('__atomic_store_n'), [P, X, MO], none, base([], [void])) :- !,
    ir_atomic_place('__atomic_store_n', P, PV, ET, EL), ir_expr(X, XV0, XT, XL), ir_convert(XV0, XT, XL, ET, EL, XV),
    ir_atomic_order(MO, Ord), ir_atomic_align(ET, A),
    ir_ins(['store atomic ', EL, ' ', XV, ', ptr ', PV, ' ', Ord, ', align ', A]).
ir_call(id('__atomic_thread_fence'), [MO], none, base([], [void])) :- !, ir_atomic_order(MO, Ord), ir_ins(['fence ', Ord]).
%% THE C11 BUILTINS (0.99): what <stdatomic.h> -- the compiler's own, library/include -- and libc++'s <atomic> under
%% `__has_extension(c_atomic)' are written on: the same instructions as the `__atomic_*' family's, and cmpxchg
ir_call(id(B), [P, X, MO], V, ET) :- ir_c11_rmw(B, Op), !,
    ir_atomic_place(B, P, PV, ET, EL), ir_expr(X, XV0, XT, XL), ir_convert(XV0, XT, XL, ET, EL, XV), ir_atomic_order(MO, Ord),
    ir_fresh(V), ir_ins([V, ' = atomicrmw ', Op, ' ptr ', PV, ', ', EL, ' ', XV, ' ', Ord]).
ir_c11_rmw('__c11_atomic_fetch_add', add). ir_c11_rmw('__c11_atomic_fetch_sub', sub). ir_c11_rmw('__c11_atomic_fetch_and', and).
ir_c11_rmw('__c11_atomic_fetch_or', or).   ir_c11_rmw('__c11_atomic_fetch_xor', xor). ir_c11_rmw('__c11_atomic_exchange', xchg).
ir_call(id('__c11_atomic_load'), [P, MO], V, ET) :- !, ir_call(id('__atomic_load_n'), [P, MO], V, ET).
ir_call(id('__c11_atomic_store'), [P, X, MO], V, ET) :- !, ir_call(id('__atomic_store_n'), [P, X, MO], V, ET).
ir_call(id('__c11_atomic_init'), [P, X], none, base([], [void])) :- !,
    ir_atomic_place('__c11_atomic_init', P, PV, ET, EL), ir_expr(X, XV0, XT, XL), ir_convert(XV0, XT, XL, ET, EL, XV), ir_ins(['store ', EL, ' ', XV, ', ptr ', PV]).
ir_call(id('__c11_atomic_thread_fence'), [MO], V, ET) :- !, ir_call(id('__atomic_thread_fence'), [MO], V, ET).
ir_call(id('__c11_atomic_signal_fence'), [MO], V, ET) :- !, ir_call(id('__atomic_signal_fence'), [MO], V, ET).
ir_call(id('__c11_atomic_is_lock_free'), [N], V, base([], [int])) :- !, ( ccl_const_eval(N, K), K =< 8 -> V = '1' ; V = '0' ).   % every scalar up to a word is lock-free on the two hosts
ir_call(id(B), [P, E, D, SO, FO], V, base([], [int])) :- ( B == '__c11_atomic_compare_exchange_strong' -> W = '' ; B == '__c11_atomic_compare_exchange_weak' -> W = 'weak ' ), !,
    ir_atomic_place(B, P, PV, ET, EL), ir_expr(E, EV, _, _), ir_fresh(Exp), ir_ins([Exp, ' = load ', EL, ', ptr ', EV]),
    ir_expr(D, DV0, DT, DL), ir_convert(DV0, DT, DL, ET, EL, DV), ir_atomic_order(SO, Ord1), ir_atomic_order(FO, Ord2f), ir_cmpxchg_fail(Ord2f, Ord2),
    ir_fresh(R), ir_ins([R, ' = cmpxchg ', W, 'ptr ', PV, ', ', EL, ' ', Exp, ', ', EL, ' ', DV, ' ', Ord1, ' ', Ord2]),
    ir_fresh(Old), ir_ins([Old, ' = extractvalue { ', EL, ', i1 } ', R, ', 0']), ir_ins(['store ', EL, ' ', Old, ', ptr ', EV]),   % `*expected' takes the value found (on success it is the same value)
    ir_fresh(Ok), ir_ins([Ok, ' = extractvalue { ', EL, ', i1 } ', R, ', 1']), ir_fresh(V), ir_ins([V, ' = zext i1 ', Ok, ' to i32']).
ir_cmpxchg_fail(release, monotonic) :- !.                                                         % a failure ordering is never a release
ir_cmpxchg_fail(acq_rel, acquire) :- !.
ir_cmpxchg_fail(O, O).
%% AN `_Atomic' OBJECT IS READ AND WRITTEN ATOMICALLY (C11 6.7.3, 7.17.7; 0.99: its loads and stores were plain): a
%% load or a store through its slot is the sequentially consistent instruction, `x++', `x += n', `x |= m' an atomicrmw
ir_atomic_q(T) :- ccl_resolve_type(T, base(Q, _)), memberchk('_Atomic', Q), !.
ir_atomic_ll(LL) :- atom(LL), \+ sub_atom(LL, 0, 1, _, '['), \+ sub_atom(LL, 0, 1, _, '{'), \+ sub_atom(LL, 0, 1, _, '<').
ir_int_ll(LL) :- atom(LL), atom_codes(LL, [0'i|Ds]), Ds \== [], catch(number_codes(_, Ds), _, fail).
ir_atomic_binop('+', add). ir_atomic_binop('-', sub). ir_atomic_binop('&', and). ir_atomic_binop('|', or). ir_atomic_binop('^', xor).
ir_call(id('__atomic_signal_fence'), [MO], none, base([], [void])) :- !, ir_atomic_order(MO, Ord), ir_ins(['fence syncscope("singlethread") ', Ord]).
ir_atomic_rmw('__atomic_add_fetch', add, add).     ir_atomic_rmw('__atomic_fetch_add', add, none).
ir_atomic_rmw('__atomic_sub_fetch', sub, sub).     ir_atomic_rmw('__atomic_fetch_sub', sub, none).
ir_atomic_rmw('__atomic_and_fetch', and, and).     ir_atomic_rmw('__atomic_fetch_and', and, none).
ir_atomic_rmw('__atomic_or_fetch', or, or).        ir_atomic_rmw('__atomic_fetch_or', or, none).
ir_atomic_rmw('__atomic_xor_fetch', xor, xor).     ir_atomic_rmw('__atomic_fetch_xor', xor, none).
ir_atomic_rmw('__atomic_exchange_n', xchg, none).
ir_atomic_place(B, P, PV, ET, EL) :-
    ir_expr(P, PV, PT, _), ccl_resolve_type(PT, PT1),
    ( PT1 = ptr(_, ET0) -> true ; PT1 = arr(_, ET0) -> true ; ir_fail(atomic_builtin(B)) ),
    ir_atomic_plain(ET0, ET), ir_type(ET, EL).                             % `volatile _Tp *' is the same object to the instruction
ir_atomic_plain(base(_, S), base([], S)) :- !.
ir_atomic_plain(T, T).
ir_atomic_align(T, A) :- ccl_resolve_type(T, T1), ( ccl_size_align(T1, _, A0) -> A = A0 ; A = 8 ).
ir_atomic_order(MO, Ord) :- ( ccl_const_eval(MO, K), ir_atomic_ord(K, Ord0) -> Ord = Ord0 ; Ord = seq_cst ).
ir_atomic_ord(0, monotonic).  ir_atomic_ord(1, acquire).  ir_atomic_ord(2, acquire).
ir_atomic_ord(3, release).    ir_atomic_ord(4, acq_rel).  ir_atomic_ord(5, seq_cst).
ir_call(id(N), [A0|Args], V, RT) :- atom(N), catch('$cpp_static_abi'(N), _, fail), ccl_declared(N, fn(RT, [_|Ps], Var)), !,   % A SHIPPED STATIC MEMBER FUNCTION is called by its ABI's own signature (0.127): the desugaring's null `this' goes nowhere
    ( A0 == nullptr -> true ; ir_expr(A0, _, _, _) ),
    atom_concat('@', N, Addr), ir_note_extern(N, fn(RT, Ps, Var)), ir_call_(Addr, RT, Ps, Var, Args, V).
ir_call(id(N), Args, V, RT) :-
    ir_lookup(N, loc(Addr, T0)), ccl_resolve_type(T0, fn(RT, Ps, Var)), !,
    ir_call_(Addr, RT, Ps, Var, Args, V).
ir_call(F, Args, V, RT) :-
    ir_expr(F, FV, FT), ccl_resolve_type(FT, FT1),
    ( FT1 = ptr(_, FnT) -> true ; FnT = FT1 ), ccl_resolve_type(FnT, fn(RT, Ps, Var)), !,
    ir_call_(FV, RT, Ps, Var, Args, V).
ir_call(F, _, _, _) :- ir_fail(call(F)).
%% a call under the ABI: a struct returned in memory gets a temporary as its
%% sret argument, one returned in pieces is stored to a temporary and loaded
%% back as the struct; a struct argument is handed over the same way
ir_call_(Callee, RT, Ps, Var, Args, V) :-
    ir_ret_abi(RT, RetAbi),
    nb_getval('$ir_sret_into', Into), nb_setval('$ir_sret_into', none),   % THE DESTINATION OF THIS CALL'S RESULT, if its consumer named one (ir_init, the return of a call): read first, so that no call in the arguments takes it
    (   ( RetAbi = memory(_, _) ; RetAbi = indirect(_, _) )
    ->  ir_type(RT, RLL), ( Into \== none -> Sret = Into ; ir_tmp(RLL, Sret) ), ir_sret_attr(RetAbi, SA), atomic_list_concat([SA, ' ', Sret], LeadPart), Lead = [LeadPart], LeadLL = [ptr], CL = void
    ;   Lead = [], LeadLL = [], ( RetAbi = direct(Pcs) -> ir_pieces_type(Pcs, CL) ; ir_type(RT, CL) ) ),
    ir_regs_start(RetAbi, R0), ir_args_(Args, Ps, R0, Parts0, PLLs0), append(Lead, Parts0, Parts), append(LeadLL, PLLs0, PLLs), ir_join(Parts, ', ', ArgTxt),
    ( Var == true -> ir_join(PLLs, ', ', PL), atomic_list_concat([CL, ' (', PL, ', ...)'], Sig) ; Sig = CL ),
    (   CL == void
    ->  ir_emit_call(none, Sig, Callee, ArgTxt),
        ( RetAbi == scalar -> V = none ; Into \== none -> V = Sret ; ir_fresh(V), ir_ins([V, ' = load ', RLL, ', ptr ', Sret]) )
    ;   ir_fresh(R), ir_emit_call(R, Sig, Callee, ArgTxt),
        (   RetAbi = direct(_) -> ir_type(RT, RLL2), ir_tmp(RLL2, T2), ir_ins(['store ', CL, ' ', R, ', ptr ', T2]), ir_fresh(V), ir_ins([V, ' = load ', RLL2, ', ptr ', T2])
        ;   V = R ) ).
%% ---- EXCEPTIONS (0.108): a call is an INVOKE where an exception it lets out has somewhere to go -- a try around it,
%% or a scope with destructors or defers to run -- and its unwind edge is a landing pad made at the call: it lists
%% every enclosing handler's type_info (innermost first) and `cleanup', runs the defers of the scopes it leaves up to
%% the innermost try, tests the selector against that try's handlers, then the next try's, and else resumes. Code
%% run while unwinding makes plain calls (an exception out of a destructor there is terminate's business).
ir_emit_call(R, Sig, Callee, ArgTxt) :- ir_invoke_needed, !,
    ( ir_terminated(yes) -> ir_label(Ld), ir_emit([Ld, ':']), ir_set_term(no) ; true ),
    ir_label(Lok), ir_label(Llp),
    ( R == none -> Pre = [] ; Pre = [R, ' = '] ),
    append(Pre, ['invoke ', Sig, ' ', Callee, '(', ArgTxt, ') to label %', Lok, ' unwind label %', Llp], Ins), ir_end(Ins),
    ir_landing_pad(Llp), ir_block(Lok).
ir_emit_call(none, Sig, Callee, ArgTxt) :- !, ir_ins(['call ', Sig, ' ', Callee, '(', ArgTxt, ')']).
ir_emit_call(R, Sig, Callee, ArgTxt) :- ir_ins([R, ' = call ', Sig, ' ', Callee, '(', ArgTxt, ')']).
ir_invoke_needed :- catch(nb_getval('$ir_eh', yes), _, fail), nb_getval('$ir_unwinding', no),
    ( nb_getval('$ir_tries', [_|_]) -> true ; nb_getval('$ir_defers', Fs), member(F, Fs), F \== [] ), !.
ir_eh_slots(E, S) :- nb_getval('$ir_ehslots', X), ( X = slots(E, S) -> true ; ir_tmp(ptr, E), ir_tmp(i32, S), nb_setval('$ir_ehslots', slots(E, S)) ).
ir_landing_pad(Llp) :-
    ir_block(Llp), nb_setval('$ir_personality', yes),
    nb_getval('$ir_tries', Tries), findall(C, ( member(t(_, Hs), Tries), member(h(K, _), Hs), ( ( K == any ; K == terminate ) -> C = ' catch ptr null' ; atomic_list_concat([' catch ptr @', K], C) ) ), Cs),
    ir_fresh(LP), atomic_list_concat(Cs, CsT), ir_ins([LP, ' = landingpad { ptr, i32 } cleanup', CsT]),
    ir_eh_slots(ES, SS), ir_fresh(X), ir_ins([X, ' = extractvalue { ptr, i32 } ', LP, ', 0']), ir_ins(['store ptr ', X, ', ptr ', ES]),
    ir_fresh(Y), ir_ins([Y, ' = extractvalue { ptr, i32 } ', LP, ', 1']), ir_ins(['store i32 ', Y, ', ptr ', SS]),
    nb_getval('$ir_defers', Frames), length(Frames, Len),
    nb_setval('$ir_unwinding', yes), ir_unwind_to(Tries, Frames, Len), nb_setval('$ir_unwinding', no).
ir_unwind_to([], Frames, _) :- ir_run_frames(Frames), ir_eh_slots(ES, SS),
    ir_fresh(X), ir_ins([X, ' = load ptr, ptr ', ES]), ir_fresh(Y), ir_ins([Y, ' = load i32, ptr ', SS]),
    ir_fresh(A), ir_ins([A, ' = insertvalue { ptr, i32 } poison, ptr ', X, ', 0']), ir_fresh(B), ir_ins([B, ' = insertvalue { ptr, i32 } ', A, ', i32 ', Y, ', 1']),
    ir_end(['resume { ptr, i32 } ', B]).
ir_unwind_to([t(_, [h(terminate, Lh)])|_], _, _) :- !, ir_end(['br label %', Lh]).   % a noexcept function's boundary: terminate, running no destructor on the way (0.110)
ir_unwind_to([t(D, Hs)|Ts], Frames, Len) :- K is Len - D, ir_take(K, Frames, Fs), length(Fs, KF), length(Pre, KF), append(Pre, Rest, Frames),
    ir_run_frames(Fs), ir_eh_dispatch(Hs), ( ir_terminated(yes) -> true ; ir_unwind_to(Ts, Rest, D) ).
ir_eh_dispatch([]).
ir_eh_dispatch([h(any, Lh)|_]) :- !, ir_end(['br label %', Lh]).
ir_eh_dispatch([h(Sym, Lh)|Hs]) :- ir_eh_slots(_, SS), ir_fresh(S), ir_ins([S, ' = load i32, ptr ', SS]),
    ir_note_extern('llvm.eh.typeid.for', raw('declare i32 @llvm.eh.typeid.for(ptr)')),
    ir_fresh(T), ir_ins([T, ' = call i32 @llvm.eh.typeid.for(ptr @', Sym, ')']), ir_fresh(C), ir_ins([C, ' = icmp eq i32 ', S, ', ', T]),
    ir_label(Ln), ir_end(['br i1 ', C, ', label %', Lh, ', label %', Ln]), ir_block(Ln), ir_eh_dispatch(Hs).
%% the try: its handlers' labels made first, the body lowered with the try on the stack, then each handler --
%% __cxa_begin_catch over the exception, the parameter bound to the object (a reference, or a scalar's value; a
%% class caught by value is bound to the object itself), the body, and __cxa_end_catch as the handler scope's defer,
%% so a return, a break or an exception out of the handler ends the catch too
ir_try(L, Body, Catches) :- ir_line(L), nb_getval('$ir_defers', Fr), length(Fr, D), ir_label(La),
    findall(h(K, Lh)-Cat, ( member(Cat, Catches), ir_label(Lh), ( Cat = catch(any, _) -> K = any ; Cat = catch(terminate, _) -> K = terminate ; Cat = catch(rtti(Ch), _, _, _), ir_rtti_emit(Ch, K) ) ), HCs),
    findall(H, member(H-_, HCs), Hs),
    nb_getval('$ir_tries', T0), nb_setval('$ir_tries', [t(D, Hs)|T0]),
    ir_stmt(Body), nb_setval('$ir_tries', T0), ir_end(['br label %', La]),
    forall(member(h(_, Lh)-Cat, HCs), ir_handler(Cat, Lh, La)),
    ir_block(La).
ir_handler(Cat, Lh, La) :- ir_block(Lh), ir_eh_slots(ES, _), ir_fresh(X), ir_ins([X, ' = load ptr, ptr ', ES]),
    ir_note_extern('__cxa_begin_catch', raw('declare ptr @__cxa_begin_catch(ptr)')), ir_note_extern('__cxa_end_catch', raw('declare void @__cxa_end_catch()')),
    ir_fresh(O), ir_ins([O, ' = call ptr @__cxa_begin_catch(ptr ', X, ')']),
    ir_env_push, ir_defer_push(eh_end_catch),
    (   ( Cat = catch(any, B) ; Cat = catch(terminate, B) ) -> true
    ;   Cat = catch(_, T, N, B), ( N == anon -> true ; ir_catch_bind(N, T, O) ) ),
    ir_stmt(B), ir_run_defers(1), ir_env_pop, ir_end(['br label %', La]).
ir_catch_bind(N, T, O) :- ccl_resolve_type(T, T1),
    (   ( T1 = ref(_, _) ; T1 = rref(_, _) ; ccl_resolve_type(T1, base(_, [struct(_, _)])) ; ccl_resolve_type(T1, base(_, [union(_, _)])) )
    ->  ( T1 = base(_, _) -> RT = ref([], T1) ; RT = T1 ), ir_fresh(A), ir_alloca_typed(A, ptr([], base([], [void]))), ir_ins(['store ptr ', O, ', ptr ', A]), ir_local(N, RT, A)
    ;   ir_type(T1, LL), ir_fresh(A), ir_alloca_typed(A, T1), ir_fresh(V), ir_ins([V, ' = load ', LL, ', ptr ', O]), ir_ins(['store ', LL, ' ', V, ', ptr ', A]), ir_local(N, T1, A) ).
%% the arguments: each as its parts (a struct in pieces is several), and the plain type of each part
ir_args_([], _, _, [], []).
ir_args_([A|As], [param(PT0, _)|Ps], R0, Parts, PLLs) :- ( PT0 = ref(_, _) ; PT0 = rref(_, _) ), !,   % C++: a reference parameter takes the argument's address -- of the base sub-object, for a derived object over a base at an offset
    ir_ref_to(A, PT0, V), atomic_list_concat(['ptr ', V], P1), ir_regs_take(R0, PT0, scalar, _, R1), ir_args_(As, Ps, R1, P2, PLLs2), Parts = [P1|P2], PLLs = [ptr|PLLs2].
ir_args_([A|As], [param(PT0, _)|Ps], R0, Parts, PLLs) :- !,
    ir_param_abi(PT0, PT, Abi, R0, R1), ir_expr(A, V0, T0, L0),
    (   Abi == scalar -> ir_type(PT, PL), ir_convert(V0, T0, L0, PT, PL, V)
    ;   ir_ref_value_type(T0, RV) -> ir_type(PT, PL), ir_convert(V0, RV, L0, PT, PL, V)   % A REFERENCE HANDED TO A BY-VALUE AGGREGATE PARAMETER IS READ THROUGH (0.112): its value is the address, and `std::invoke' of a generic lambda forwards `_Args &&' to an `auto' parameter -- stored as the struct, LLVM refused `store %struct.monostate ptr'
    ;   V = V0 ),
    ir_arg_parts(Abi, PT, V, P1, L1), ir_args_(As, Ps, R1, P2, L2), append(P1, P2, Parts), append(L1, L2, PLLs).
ir_args_([A|As], [], R0, Parts, PLLs) :-                    % the variadic tail: default promotions
    ir_expr(A, V0, T0), ir_promote_arg(V0, T0, V, T), ir_abi(T, Abi0), ir_regs_take(R0, T, Abi0, Abi, R1),
    ir_arg_parts(Abi, T, V, P1, L1), ir_args_(As, [], R1, P2, L2), append(P1, P2, Parts), append(L1, L2, PLLs).
ir_arg_parts(scalar, T, V, [Part], [LL]) :- ir_type(T, LL), atomic_list_concat([LL, ' ', V], Part).
ir_arg_parts(direct(Pcs), T, V, Parts, LLs) :- ir_type(T, LL), ir_tmp(LL, Tmp), ir_ins(['store ', LL, ' ', V, ', ptr ', Tmp]), ir_piece_loads(Pcs, Tmp, Parts, LLs).
ir_arg_parts(memory(LL, A), _, V, [Part], [ptr]) :- ir_tmp(LL, Tmp), ir_ins(['store ', LL, ' ', V, ', ptr ', Tmp]), atomic_list_concat(['ptr byval(', LL, ') align ', A, ' ', Tmp], Part).
ir_arg_parts(indirect(LL, _), _, V, [Part], [ptr]) :- ir_tmp(LL, Tmp), ir_ins(['store ', LL, ' ', V, ', ptr ', Tmp]), atomic_list_concat(['ptr ', Tmp], Part).
%% a type that is a reference, resolved: what a by-value aggregate parameter reads through
ir_ref_value_type(T0, R0) :- ccl_resolve_type(T0, R0), ( R0 = ref(_, _) ; R0 = rref(_, _) ), !.
ir_piece_loads([], _, [], []).
ir_piece_loads([piece(P, Off)|Ps], Tmp, [Part|Parts], [P|LLs]) :- ir_load_at(P, Tmp, Off, V), atomic_list_concat([P, ' ', V], Part), ir_piece_loads(Ps, Tmp, Parts, LLs).
ir_promote_arg(V0, T0, V, T) :-
    ( ccl_resolve_type(T0, arr(_, E)) -> V = V0, T = ptr([], E)                         % an array member or element passed on: its address (0.108; the value was, the type was not)
    ; ccl_resolve_type(T0, base(_, S)), memberchk(float, S) -> T = base([], [double]), ir_convert(V0, T0, T, V)
    ; ir_is_int(T0), ccl_int_rank(T0, R, _), R < 3 -> ir_int(T), ir_convert(V0, T0, T, V)
    ; V = V0, T = T0 ).

%% ---- lvalues: an address and the C type there --------------------------------------------
%% ir_lval(+E, -Slot, -T, -LL): the slot, the C type there (resolved) and its LLVM type
ir_lval(E, Slot, T) :- ir_lval(E, Slot, T, _).
ir_lval(id(N), Addr, T, LL) :- !, ( ir_lookup(N, loc(Addr0, T00)) -> true ; ir_fail(undeclared(N)) ), ir_ref_slot(Addr0, T00, Addr, T0), ccl_resolve_type(T0, T), ir_type(T, LL).
ir_lval(scoped(_, N), Addr, T, LL) :- !, ir_lval(id(N), Addr, T, LL).
ir_lval(call(F, Args), Addr, T, LL) :- !,                                 % C++: a call's reference result is a place
    ir_call(F, Args, V, RT),
    (   ( RT = ref(_, T0) ; RT = rref(_, T0) ) -> ccl_resolve_type(T0, T), ir_type(T, LL), Addr = V
    ;   ccl_resolve_type(RT, T), ir_type(T, LL), ir_fresh(Addr), ir_alloca_typed(Addr, T), ir_ins(['store ', LL, ' ', V, ', ptr ', Addr]) ).   % a PRVALUE used as a place, `end()[-1]' or `f().x': the temporary C++ materializes for it
%% C++ (M6): a reference's slot holds the address of what it refers to, so a
%% use of the name loads that address first and goes on as the referent
ir_ref_slot(A0, T0, A, T) :- ( T0 = ref(_, T) ; T0 = rref(_, T) ), !, ir_fresh(A), ir_ins([A, ' = load ptr, ptr ', A0]).
ir_ref_slot(A, T, A, T).
%% what a reference is bound to: an lvalue's address, or a call's reference result as it is
ir_ref_of(move(E), R) :- !, ir_ref_of(E, R).   % a reference bound to `std::move(x)' binds x (the move stays on a class value since 0.83)
ir_ref_of(E, P) :- ir_lvalue_form(E), !, ir_lval(E, Slot, _, _), ir_slot_addr(Slot, P).   % the ADDRESS, through the one door: a slot may be a bitfield's or a member that owns no storage, and neither is a pointer
ir_ref_of(stmt_expr(block(Is)), P) :- append(Init, [expr(_, E)], Is), ir_ref_result(E, Init), !,   % A STATEMENT EXPRESSION ENDING IN A CALL WHOSE RESULT IS A REFERENCE binds that reference, as the bare call does (0.112): cpp_memptr_call makes `(o.*pm)(args)' one, and libc++'s __invoke returned an `int &' member's result through a temporary it materialized, so `std::invoke(pm, s) += 2' wrote into a dead copy
    ir_env_push, ir_stmts(Init), ir_ref_of(E, P), ir_run_defers(1), ir_env_pop.
ir_ref_of(ccast(_, T, E), P) :- !, ir_ref_of(cast(T, E), P).                          % a C++ cast keeps its word to here
ir_ref_of(cast(T, E), P) :- ( T = ref(_, _) ; T = rref(_, _) ), !, ir_ref_of(E, P).   % the bind again: no temporary between
ir_ref_of(call(F, Args), P) :- !, ir_call(F, Args, V, RT),
    (   ( RT = ref(_, _) ; RT = rref(_, _) ) -> P = V                                     % a reference RESULT is the address already
    ;   ccl_resolve_type(RT, T), ir_type(T, LL), ir_fresh(P), ir_alloca_typed(P, T), ir_ins(['store ', LL, ' ', V, ', ptr ', P]) ).   % a call's VALUE bound to a const reference, `std::min<size_type>(a.max_size(), n)': the temporary C++ materializes for it
ir_ref_of(E, P) :- ir_expr(E, V, T, LL), !,                                % a PRVALUE bound to a const reference: C++ materializes a temporary, and a reference needs an address
    ir_fresh(P), ir_alloca_typed(P, T), ir_ins(['store ', LL, ' ', V, ', ptr ', P]).
ir_ref_of(E, _) :- ir_fail(reference_to_value(E)).
%% a call whose declared result is a reference, read off the form: through a cast to the function's type, a local of
%% that type the block declares, or a function the table declares
ir_ref_result(call(cast(ptr(_, fn(R, _, _)), _), _), _) :- !, ir_ref_type(R).
ir_ref_result(call(id(F), _), Init) :- member(declaration(_, _, _, Vs), Init), memberchk(var(F, ptr(_, fn(R, _, _)), _), Vs), !, ir_ref_type(R).
ir_ref_result(call(id(F), _), _) :- atom(F), ccl_declared(F, fn(R, _, _)), !, ir_ref_type(R).
ir_ref_type(ref(_, _)).
ir_ref_type(rref(_, _)).
ir_lvalue_form(rtti(_)).
ir_lvalue_form(rtti_dyn(_)).
ir_lvalue_form(id(N)) :- \+ ir_enumerator(N).   % AN ENUMERATOR IS A PRVALUE (0.127): `v.push_back(Green)' bound it to `const Color &' through ir_lval, and it was `undeclared'; it takes the temporary C++ materializes (ir_ref_of's last clause)
ir_lvalue_form(scoped(_, _)).
ir_lvalue_form(index(_, _)).
ir_lvalue_form(member(_, _)).
ir_lvalue_form(arrow(_, _)).
ir_lvalue_form(stmt_expr(block(Is))) :- append(_, [expr(_, E)], Is), ir_lvalue_form(E).   % a temporary: the block ends with its object
ir_lvalue_form(deref(_)).
ir_lvalue_form(cond(_, A, B)) :- ir_lvalue_form(A), ir_lvalue_form(B).   % [expr.cond]/4: both arms lvalues of one type, so the conditional IS one
ir_enumerator(N) :- atom(N), \+ ir_lookup(N, _), ccl_enum_value(N, _).   % a name that is no object of the function or the file and has a value: ir_expr(id(N))'s test
%% A POINTER OPERAND THAT IS A REFERENCE TO A POINTER IS READ THROUGH (0.126): `*static_cast<A0 &&>(a0)' with A0 `Pt *' -- the cast to a
%% reference is a bind, so its value is the ADDRESS of the pointer and its type `Pt *&&', and `ir_elem' found no pointer in it
%% (`not_a_pointer(rref(...))'). libc++ 18's `__invoke' for a pointer to a data member of an object given by pointer is written so
%% (`(*static_cast<_A0 &&>(__a0)).*__f'). A named reference or a call's reference result is read through where it is made.
ir_ptr_operand(E, P, PT) :- ir_expr(E, P0, PT0, L0),
    (   ir_ref_to_pointer(PT0, PT1) -> ir_convert(P0, PT0, L0, PT1, ptr, P), PT = PT1
    ;   P = P0, PT = PT0 ).
ir_ref_to_pointer(T0, PT) :- ccl_resolve_type(T0, R), ( R = ref(_, X) ; R = rref(_, X) ), ccl_resolve_type(X, PT), PT = ptr(_, _), !.
ir_lval(deref(E), Addr, T, LL) :- !, ir_ptr_operand(E, Addr, PT), ir_elem(PT, T), ir_type(T, LL).
%% A CONDITIONAL OVER TWO LVALUES IS AN LVALUE ([expr.cond]/4), so its ADDRESS is the phi of the arms' -- where
%% the value form phis the values. `std::min' is `return __b < __a ? __b : __a;' in a `const _Tp &'-returning
%% function, and with no clause here the conditional was a prvalue: `ir_ref_of' materialized a temporary, stored
%% the STRUCT into it and returned its address, so `std::min(a, b).c_str()' read a dead temporary's bytes.
ir_lval(cond(C, A, B), Addr, T, LL) :- ir_lvalue_form(A), ir_lvalue_form(B), !,
    ir_label(LT), ir_label(LF), ir_label(LE), ir_cond(C, CC), ir_end(['br i1 ', CC, ', label %', LT, ', label %', LF]),
    ir_block(LT), ir_lval(A, SA, T, LL), ir_slot_addr(SA, VA), ir_cur_label(LT1), ir_end(['br label %', LE]),
    ir_block(LF), ir_lval(B, SB, _, _), ir_slot_addr(SB, VB), ir_cur_label(LF1), ir_end(['br label %', LE]),
    ir_block(LE), ir_fresh(Addr), ir_ins([Addr, ' = phi ptr [ ', VA, ', %', LT1, ' ], [ ', VB, ', %', LF1, ' ]']).
ir_lval(index(A, I), Addr, T, LL) :- !,
    ir_ptr_operand(A, P, PT), ir_elem(PT, T), ir_expr(I, IV, IT, IL), ir_convert(IV, IT, IL, base([], [long]), i64, I1),
    (   ir_vla_bytes(T, Bytes)                                                                     % a row of a VLA of a VLA: i * (the row's bytes) into the flat allocation
    ->  ir_fresh(Off), ir_ins([Off, ' = mul i64 ', I1, ', ', Bytes]), ir_fresh(Addr), ir_ins([Addr, ' = getelementptr inbounds i8, ptr ', P, ', i64 ', Off]), LL = ptr
    ;   ir_type(T, LL), ir_fresh(Addr), ir_ins([Addr, ' = getelementptr inbounds ', LL, ', ptr ', P, ', i64 ', I1]) ).
%% `__real__ z' AND `__imag__ z' ARE PLACES (GNU's, as clang has them; 0.101): the component's own address inside the
%% complex's slot, so `__real__ z = 5.0' and `__imag__ z += 1.0' write one component
ir_lval(real_part(E), Slot, T, LL) :- !, ir_complex_slot(E, 0, Slot, T, LL).
ir_lval(imag_part(E), Slot, T, LL) :- !, ir_complex_slot(E, 1, Slot, T, LL).
ir_complex_slot(E, I, Slot, T, LL) :- ir_lval(E, Slot0, T0, L0), ir_slot_addr(Slot0, Base),
    (   ir_complex_ll(L0) -> ccl_complex_real(T0, T), ir_type(T, LL), ir_fresh(Slot), ir_ins([Slot, ' = getelementptr inbounds ', L0, ', ptr ', Base, ', i32 0, i32 ', I])
    ;   I =:= 0 -> Slot = Slot0, T = T0, LL = L0
    ;   ir_fail(imaginary_part_of_a_real_as_a_place) ).
ir_lval(member(E, N), Slot, T, LL) :- !,
    ( ir_lval(E, Base0, ST, _) -> ir_slot_addr(Base0, Base) ; ir_expr(E, SV, ST, SLL), ir_fresh(Base), ir_alloca_typed(Base, ST), ir_ins(['store ', SLL, ' ', SV, ', ptr ', Base]) ),
    ir_member_slot(Base, ST, N, Slot0, T0), ir_ref_member(Slot0, T0, Slot, T), ir_type(T, LL).
ir_lval(arrow(E, N), Slot, T, LL) :- !, ir_ptr_operand(E, P, PT), ir_elem(PT, ST), ir_member_slot(P, ST, N, Slot0, T0), ir_ref_member(Slot0, T0, Slot, T), ir_type(T, LL).
%% C++: a member that is a reference (a lambda's capture by reference) holds an address, read through
ir_ref_member(Slot0, T0, Slot, T) :- ( T0 = ref(_, _) ; T0 = rref(_, _) ), !, ir_slot_addr(Slot0, A0), ir_ref_slot(A0, T0, Slot, T).
ir_ref_member(Slot, T, Slot, T).
%% BINDING a reference member: the address goes into the SLOT, where every use of that member reads through it
ir_bind_ref(arrow(E, N), V) :- !, ir_expr(E, P, PT, _), ir_elem(PT, ST), ir_member_slot(P, ST, N, Slot, MT), ir_bind_into(Slot, MT, V).
ir_bind_ref(member(E, N), V) :- !, ir_lval(E, Base, BT, _), ccl_resolve_type(BT, ST), ir_member_slot(Base, ST, N, Slot, MT), ir_bind_into(Slot, MT, V).
ir_bind_into(Slot, MT, V) :- ir_slot_addr(Slot, A), ( ir_ref_converts(V, MT, RT) -> ir_ref_convert(V, RT, R) ; ir_ref_of(V, R) ), ir_ins(['store ptr ', R, ', ptr ', A]).
ir_lval(ccast(_, T, E), S, T1, LL) :- !, ir_lval(cast(T, E), S, T1, LL).
ir_lval(cast(T, E), P, RT, LL) :- ( T = ref(_, RT0) ; T = rref(_, RT0) ), !, ir_ref_to(E, T, P), ccl_resolve_type(RT0, RT), ir_type(RT, LL).   % the bind as a place
%% A STATEMENT EXPRESSION IS A PLACE when the expression it ends with is one -- which is what every temporary this
%% compiler builds is (`({ C $tmp; ctor(&$tmp); $tmp; })'), so a reference to it binds to the OBJECT. Materialized
%% as a prvalue instead, the temporary was copied and a class holding an owner had two holders, one of them freed.
ir_lval(stmt_expr(block(Is)), Slot, T, LL) :- !,
    ir_env_push, append(Init, [expr(_, E)], Is), ir_stmts(Init), ir_lval(E, Slot, T, LL), ir_run_defers(1), ir_env_pop.
%% RTTI (0.108): a type_info object is a place, the global of its name; a polymorphic object's is read off its table's
%% prefix, the word before the slots
ir_lval(rtti(Ch), Addr, T, LL) :- !, ir_rtti_emit(Ch, Sym), atom_concat('@', Sym, Addr), ccl_resolve_type(base([const], [typedef(type_info)]), T), ir_type(T, LL).
ir_lval(rtti_dyn(X), Addr, T, LL) :- !, ir_lval(X, Slot, _, _), ir_slot_addr(Slot, P), ir_fresh(VP), ir_ins([VP, ' = load ptr, ptr ', P]),
    ir_fresh(G), ir_ins([G, ' = getelementptr inbounds ptr, ptr ', VP, ', i64 -1']), ir_fresh(Addr), ir_ins([Addr, ' = load ptr, ptr ', G]),
    ccl_resolve_type(base([const], [typedef(type_info)]), T), ir_type(T, LL).
ir_lval(compound_lit(T, Init), Addr, T, LL) :- !, ir_fresh(Addr), ir_alloca_typed(Addr, T), ir_init(Addr, T, Init), ir_type(T, LL).
ir_lval(E, _, _, _) :- ir_fail(lvalue(E)).
%% an alloca for a value of a C type: a struct or a union aligned as C aligns it
ir_alloca_typed(Addr, T) :-
    ir_type(T, LL), ccl_resolve_type(T, T1),
    (   ir_aligned_q(T1, A0) -> ( ccl_size_align(T1, _, A1) -> A is max(A0, A1) ; A = A0 ), ir_alloca_aligned(Addr, LL, A)   % `_Alignas(16) int x' ([dcl.align]; 0.99)
    ;   ( T1 = base(_, [struct(_, _)]) ; T1 = base(_, [union(_, _)]) ), ccl_size_align(T1, _, A) -> ir_alloca_aligned(Addr, LL, A) ; ir_alloca(Addr, LL) ).
ir_aligned_q(base(Q, _), A) :- memberchk(aligned(E), Q), ccl_const_eval(E, A), !.
ir_aligned_q(ptr(_, T), A) :- ir_aligned_q(T, A).
ir_aligned_q(arr(_, T), A) :- ir_aligned_q(T, A).

%% ---- initializers -------------------------------------------------------------------------
ir_init(_, _, none) :- !.
%% A BRACED LIST ON A SCALAR is its one value, or the type's zero when empty ([dcl.init.list]/3: `int b{2}', `int n{}',
%% and C++20's brace-designated `.b{2}' inside an aggregate, which libc++ 18's <format> writes; 0.93): walked as an
%% aggregate's list it asked a scalar for its members and refused initializer(0, int)
ir_init(Slot, T, init(Items)) :- once(ccl_resolve_type(T, T1)), \+ T1 = arr(_, _), \+ ( T1 = base(_, S), ccl_members_of(base([], S), _) ), !,   % the resolver's FIRST answer (0.99): on backtracking it answered the element, and `int arr[9] = {}' became `sext i32 0 to [9 x i32]'
    ( Items = [] -> ir_init(Slot, T, int(0)) ; Items = [item([], V)] -> ir_init(Slot, T, V) ; ir_fail(initializer_of_a_scalar(T)) ).
ir_init(Slot, T, init(Items)) :- !,
    ir_slot_addr(Slot, Addr), ir_type(T, LL), ir_ins(['store ', LL, ' zeroinitializer, ptr ', Addr]), ir_init_items(Items, Addr, T, 0).
%% A FRESH TEMPORARY THAT INITIALIZES AN OBJECT OF ITS OWN CLASS IS CONSTRUCTED IN THAT OBJECT (C++17, [class.copy.elision]/1; 0.121): the desugaring hands such an initializer on as the statement expression that
%% built the temporary (cpp_temporary: its declaration inside the block, its name last), and lowered as a value it was built in a slot of its own and copied bitwise into the object -- which breaks a class that holds its
%% own address: `std::function<int(int)> f = std::function<int(int)>(g)' freed an invalid pointer, the small buffer left behind. The temporary's name is bound to the OBJECT's address instead, and the constructor
%% works there. `prvalueinplace.cpp'.
ir_init(Slot, T, E) :- ir_prvalue_block(E, Tmp, TT, Pre), ir_same_object(T, TT), !,
    ir_slot_addr(Slot, Addr), ir_in_place(Tmp, TT, Addr, Pre).
%% ... AND SO IS THE RESULT OF A CALL that returns the object's class through the hidden pointer (0.121): `std::map<int, int> m = build();' passes m's address as the callee's result, where the call made a slot of its own
%% and the value was copied bitwise into m -- a class that holds its own address (the map's end node, a list's sentinel) pointed into the dead slot, and the first `m[5] = 6' ran for ever.
ir_init(Slot, T, E) :- ir_sret_call(E, T), !,
    ir_slot_addr(Slot, Addr), nb_setval('$ir_sret_into', Addr), ir_expr(E, _, _, _), nb_setval('$ir_sret_into', none).
ir_init(Slot, T, E) :-
    ccl_resolve_type(T, T1),
    (   T1 = arr(_, El), E = str(S) -> ir_slot_addr(Slot, Addr), ir_type(El, _), ir_init_zero(Addr, T), ir_init_string(Addr, T1, S)
    ;   T1 = arr(_, El), ( E = wstr(S) ; E = u16str(S) ; E = u32str(S) ) -> ir_slot_addr(Slot, Addr), ir_type(El, EL), ir_init_zero(Addr, T),   % `wchar_t a[6] = L"..."' (0.99): the code points, one element each, the rest zero
        ir_utf8_decode(S, Us0), ir_wide_units(EL, Us0, Us), append(Us, [0], Us1), ir_init_chars(Us1, EL, Addr, 0)
    ;   ir_expr(E, V0, ET, EL), ir_type(T, TL), ir_convert(V0, ET, EL, T, TL, V), ir_store_slot(Slot, T, TL, V) ).
ir_sret_call(call(id(N), _), T) :- atom(N), ccl_declared(N, fn(RT, _, _)), ir_same_object(T, RT), ir_ret_abi(RT, Abi), ( Abi = memory(_, _) ; Abi = indirect(_, _) ), !.
ir_prvalue_block(stmt_expr(block(Is)), Tmp, TT, Pre) :-
    append(Pre0, [expr(_, id(Tmp))], Is), atom(Tmp), ( sub_atom(Tmp, 0, _, _, '$tmp') ; sub_atom(Tmp, 0, _, _, '$ret') ), ir_take_tmp_decl(Pre0, Tmp, TT, Pre).
ir_take_tmp_decl([declaration(_, none, TT, [var(Tmp, TT, none)])|Is], Tmp, TT, Is) :- !.
ir_take_tmp_decl([I|Is], Tmp, TT, [I|Js]) :- ir_take_tmp_decl(Is, Tmp, TT, Js).
ir_same_object(T, TT) :- ir_type(T, L1), ir_type(TT, L2), L1 == L2, ccl_resolve_type(T, R), ( R = base(_, [struct(_, _)]) ; R = base(_, [union(_, _)]) ), !.
ir_in_place(Tmp, TT, Addr, Pre) :- ir_env_push, ir_local(Tmp, TT, Addr), ir_stmts(Pre), ir_run_defers(1), ir_env_pop.
ir_init_zero(Addr, T) :- ( ir_type(T, LL), \+ sub_atom(LL, 0, _, _, '[0 x') -> ir_ins(['store ', LL, ' zeroinitializer, ptr ', Addr]) ; true ).   % the elements past the literal are ZERO ([dcl.init.string], C 6.7.9/21): `char b[6] = "ab"' left them as the stack had them
ir_init_string(Addr, arr(_, _), S) :- append(S, [0], Cs), ir_init_chars(Cs, i8, Addr, 0).
ir_init_chars([], _, _, _).
ir_init_chars([C|Cs], EL, Addr, I) :- ir_fresh(P), ir_ins([P, ' = getelementptr inbounds ', EL, ', ptr ', Addr, ', i64 ', I]), ir_ins(['store ', EL, ' ', C, ', ptr ', P]), I1 is I + 1, ir_init_chars(Cs, EL, Addr, I1).
ir_init_items([], _, _, _).
%% BRACE ELISION ([dcl.init.aggr]/15, and C's own rule): a STRUCT member that is an ARRAY, given an item
%% that is no braced list of its own, takes as many of the items that FOLLOW as it has elements --
%% `struct S { int a[4]; } s = {1, 2, 3, 4}' in C, and every `std::array<T, N>' in C++, which libc++
%% writes as exactly one such member. The guard is that MORE ITEMS THAN MEMBERS remain, which is what
%% tells this from an array member given a whole array VALUE, where its bytes are meant.
ir_init_items([item([], V)|Is], Addr, T, I) :- V \= init(_),
    ccl_resolve_type(T, T1), T1 = base(_, _), ccl_members_of(T1, Ms), I1 is I + 1,
    ccl_nth(I1, Ms, member(MT, _, _)), ccl_resolve_type(MT, arr(B, _)), catch(ccl_const_eval(B, K), _, fail), K > 1,
    length(Ms, NM), length(Is, NI), NI > NM - I1, !,
    K1 is K - 1, ir_elide_take(K1, Is, More, Rest),
    findall(item([], W), member(W, [V|More]), Sub),
    ir_init_slot(Addr, T1, I, [], init(Sub)), ir_init_items(Rest, Addr, T, I1).
ir_elide_take(0, Is, [], Is) :- !.
ir_elide_take(_, [], [], []) :- !.
ir_elide_take(K, [item(_, W)|Is], [W|More], Rest) :- K1 is K - 1, ir_elide_take(K1, Is, More, Rest).
ir_init_items([item(Ds, V)|Is], Addr, T, I) :-
    ccl_resolve_type(T, T1),
    (   Ds = [at(int(K))|Rest] -> I0 = K, Ds1 = Rest
    ;   Ds = [field(_)|_], ccl_init_route(T1, Ds, [field(F)|Rest]) -> ir_member_index(T1, F, I0, _), Ds1 = Rest   % through an anonymous member (0.108)
    ;   I0 = I, Ds1 = [] ),
    ir_init_slot(Addr, T1, I0, Ds1, V), I1 is I0 + 1, ir_init_items(Is, Addr, T, I1).
ir_init_slot(Addr, arr(_, El), I, Ds, V) :- !,
    ir_type(El, LL), ir_fresh(P), ir_ins([P, ' = getelementptr inbounds ', LL, ', ptr ', Addr, ', i64 ', I]), ir_init_sub(P, El, Ds, V).
ir_init_slot(Addr, ST, I, Ds, V) :-
    ( ccl_members_of(ST, Ms) -> true ; Ms = [] ), I1 is I + 1, ( ccl_nth(I1, Ms, member(MT, N, _)) -> true ; ir_fail(initializer(I, ST)) ),   % which TYPE has no such member: `initializer(0)' alone named nothing
    ir_member_slot(Addr, ST, N, Slot, MT), ir_init_sub(Slot, MT, Ds, V).
%% A REFERENCE MEMBER OF AN AGGREGATE BINDS ITS ITEM (0.121; [dcl.init.aggr]/4.2, [dcl.init.ref]): the slot holds the item's ADDRESS, as a constructor's member initializer stores it (ir_bind_ref); the item
%% was loaded and converted to a pointer, an inttoptr of a struct. libc++ 18's `__value_visitor<_Visitor>{std::forward<_Visitor>(__visitor)}' of std::visit has `_Visitor &&' as its one member.
%% The item a CLOSURE gives its reference member is the captured object's address already (cpp_closure_value, `[&x]' and `[this]'): a pointer to the referent, stored as it is.
ir_init_sub(P, T, [], V) :- ( T = ref(_, R) ; T = rref(_, R) ), V \= init(_), \+ ir_address_item(V, R), !, ir_bind_into(P, T, V).
ir_init_sub(P, T, [], V) :- !, ( V = init(_) -> ir_init(P, T, V) ; ir_init(P, T, V) ).
ir_init_sub(P, T, Ds, V) :- ir_init_items([item(Ds, V)], P, T, 0).
ir_address_item(V, R) :- catch(ccl_type_of(V, VT), _, fail), ccl_resolve_type(VT, ptr(_, E)), ccl_type_canon(E, K), ccl_type_canon(R, K1), ir_canon_core(K, U), ir_canon_core(K1, U1), U == U1.
ir_canon_core(base(_, S), base([], S)) :- !.
ir_canon_core(ptr(K), ptr(K1)) :- !, ir_canon_core(K, K1).
ir_canon_core(K, K).

%% ---- statements ---------------------------------------------------------------------------
ir_stmts([]).
ir_stmts([S|Ss]) :- ir_stmt(S), ir_stmts(Ss).
ir_stmt(block(Is)) :- !, ir_dbg_block_enter(Is), ir_env_push, ir_stmts(Is), ir_run_defers(1), ir_env_pop, ir_dbg_block_leave.
ir_stmt('$splice'(Is)) :- !, ir_stmts(Is).
ir_stmt(declaration(L, Sto, _, Vs)) :- !, ( integer(L), L > 0 -> ir_line(L) ; true ), ( Sto == static -> ir_static_locals(Vs) ; ir_locals(Vs, Sto), ir_array_defers(Vs, Sto) ).   % the line of a declaration too: its initializer's calls are its own (0.128, -g)
ir_stmt(typedef(_, _)) :- !.
ir_stmt(declare(_, _)) :- !.
ir_stmt(directive(_, _)) :- !.
ir_stmt(include(_, _, _)) :- !.
ir_stmt(static_assert(_, _, _)) :- !.
ir_stmt(expr(_, bind_ref(Slot, V))) :- !, ir_bind_ref(Slot, V).      % a reference member bound in a constructor
ir_stmt(empty) :- !.
ir_stmt(ifce(_, _, RT)) :- !, ir_stmt(RT).                                              % `if consteval': the run-time branch (0.108)
ir_stmt(expr(L, E)) :- !, ir_line(L), ir_expr(E, _, _).
%% C++20 COROUTINES (0.108), LLVM's switch-resumed lowering: the desugaring makes the body a skeleton of these nodes
%% -- the promise declared, `coro_begin' (the frame allocated through operator new and begun over the promise),
%% `coro_ret' (the return object kept for the ramp), the initial await, `coro_body' (the user's body, whose
%% co_return is `coro_return': its scopes' defers run, then the final await), the final await and `coro_done'
%% (every defer run, the frame freed, the ramp's return). A suspension is `coro_suspend': coro.save, the awaiter's
%% await_suspend (void: suspend; bool: suspend when true; a handle: resume that coroutine), coro.suspend and the
%% switch -- resumed goes on, destroyed runs every defer and frees the frame, suspended returns from the ramp.
%% CoroSplit (in every pipeline, default<O0> included) cuts the function at the suspensions.
ir_stmt(coro_begin(L, P)) :- !, ir_line(L), ir_lookup(P, loc(Addr, _)), ir_coro_decls,
    ir_fresh(Id), ir_ins([Id, ' = call token @llvm.coro.id(i32 16, ptr ', Addr, ', ptr null, ptr null)']),
    ir_fresh(Sz), ir_ins([Sz, ' = call i64 @llvm.coro.size.i64()']),
    ir_fresh(M), ir_ins([M, ' = call ptr @_Znwm(i64 ', Sz, ')']),
    ir_fresh(H), ir_ins([H, ' = call ptr @llvm.coro.begin(token ', Id, ', ptr ', M, ')']),
    ir_label(Clean), ir_label(Susp), nb_setval('$ir_coro', coro(Id, H, Clean, Susp, none, 0, none)).
ir_stmt(coro_ret(L, E)) :- !, ir_line(L), ir_expr(E, V, T, LL), ir_tmp(LL, Tmp), ir_ins(['store ', LL, ' ', V, ', ptr ', Tmp]),
    nb_getval('$ir_coro', coro(Id, H, C, S, F, D, _)), nb_setval('$ir_coro', coro(Id, H, C, S, F, D, slot(Tmp, T, LL))).
ir_stmt(coro_body(L, S)) :- !, ir_line(L), ir_label(Fin), ir_depth(D),
    nb_getval('$ir_coro', coro(Id, H, C, Su, _, _, R)), nb_setval('$ir_coro', coro(Id, H, C, Su, Fin, D, R)),
    ir_stmt(S), ir_block(Fin).
ir_stmt(coro_return(L)) :- !, ir_line(L), nb_getval('$ir_coro', coro(_, _, _, _, Fin, D0, _)), ir_depth(D), K is D - D0, ir_run_defers(K), ir_end(['br label %', Fin]).
ir_stmt(coro_suspend(L, Kind, E, SK)) :- !, ir_line(L), nb_getval('$ir_coro', coro(_, H, Clean, Susp, _, _, _)),
    ir_fresh(Sv), ir_ins([Sv, ' = call token @llvm.coro.save(ptr ', H, ')']),
    ir_label(Resume), ir_label(Destroy),
    (   SK == bool -> ir_cond(E, Cn), ir_label(SL), ir_end(['br i1 ', Cn, ', label %', SL, ', label %', Resume]), ir_block(SL)
    ;   SK == handle -> ir_expr(E, V, _, LL), ir_fresh(Pt), ir_ins([Pt, ' = extractvalue ', LL, ' ', V, ', 0']), ir_ins(['call void @llvm.coro.resume(ptr ', Pt, ')'])
    ;   ir_expr(E, _, _, _) ),
    ( Kind == final -> Fl = true, ir_label(R0) ; Fl = false, R0 = Resume ),
    ir_fresh(Sw), ir_ins([Sw, ' = call i8 @llvm.coro.suspend(token ', Sv, ', i1 ', Fl, ')']),
    ir_end(['switch i8 ', Sw, ', label %', Susp, ' [i8 0, label %', R0, ' i8 1, label %', Destroy, ']']),
    ir_block(Destroy), ir_run_defers(all), ir_end(['br label %', Clean]),
    ( Kind == final -> ir_block(R0), ir_end(['unreachable']) ; true ),
    ir_block(Resume).
ir_stmt(coro_done(L)) :- !, ir_line(L), nb_getval('$ir_coro', coro(Id, H, Clean, Susp, _, _, R)),
    ir_run_defers(all), ir_end(['br label %', Clean]),
    ir_block(Clean), ir_fresh(M), ir_ins([M, ' = call ptr @llvm.coro.free(token ', Id, ', ptr ', H, ')']),
    ir_fresh(Nz), ir_ins([Nz, ' = icmp ne ptr ', M, ', null']), ir_label(Fr), ir_end(['br i1 ', Nz, ', label %', Fr, ', label %', Susp]),
    ir_block(Fr), ir_ins(['call void @_ZdlPv(ptr ', M, ')']), ir_end(['br label %', Susp]),
    ir_block(Susp), ir_fresh(En), ir_ins([En, ' = call i1 @llvm.coro.end(ptr ', H, ', i1 false, token none)']),
    nb_getval('$ir_defers', D0), nb_setval('$ir_defers', [[]]),
    ( R = slot(_, _, _) -> ir_stmt(return(L, coro_retval)) ; ir_stmt(return(L)) ),
    nb_setval('$ir_defers', D0).
ir_coro_decls :- forall(member(N-D, ['llvm.coro.id'-'declare token @llvm.coro.id(i32, ptr, ptr, ptr)', 'llvm.coro.size.i64'-'declare i64 @llvm.coro.size.i64()',
        'llvm.coro.begin'-'declare ptr @llvm.coro.begin(token, ptr)', 'llvm.coro.save'-'declare token @llvm.coro.save(ptr)',
        'llvm.coro.suspend'-'declare i8 @llvm.coro.suspend(token, i1)', 'llvm.coro.free'-'declare ptr @llvm.coro.free(token, ptr)',
        'llvm.coro.end'-'declare i1 @llvm.coro.end(ptr, i1, token)', '_Znwm'-'declare ptr @_Znwm(i64)', '_ZdlPv'-'declare void @_ZdlPv(ptr)',
        'llvm.coro.resume'-'declare void @llvm.coro.resume(ptr)']), ir_note_extern(N, raw(D))).
%% the handle's builtins over a frame's address
ir_coro_builtin('__builtin_coro_frame', [], V, ptr([], base([], [void])), ptr) :- ir_note_extern('llvm.coro.frame', raw('declare ptr @llvm.coro.frame()')), ir_fresh(V), ir_ins([V, ' = call ptr @llvm.coro.frame()']).
ir_coro_builtin('__builtin_coro_noop', [], V, ptr([], base([], [void])), ptr) :- ir_note_extern('llvm.coro.noop', raw('declare ptr @llvm.coro.noop()')), ir_fresh(V), ir_ins([V, ' = call ptr @llvm.coro.noop()']).
ir_coro_builtin('__builtin_coro_resume', [P], none, base([], [void]), void) :- ir_expr(P, V0, _, _), ir_note_extern('llvm.coro.resume', raw('declare void @llvm.coro.resume(ptr)')), ir_ins(['call void @llvm.coro.resume(ptr ', V0, ')']).
ir_coro_builtin('__builtin_coro_destroy', [P], none, base([], [void]), void) :- ir_expr(P, V0, _, _), ir_note_extern('llvm.coro.destroy', raw('declare void @llvm.coro.destroy(ptr)')), ir_ins(['call void @llvm.coro.destroy(ptr ', V0, ')']).
ir_coro_builtin('__builtin_coro_done', [P], V, base([], [bool]), i8) :- ir_expr(P, V0, _, _), ir_note_extern('llvm.coro.done', raw('declare i1 @llvm.coro.done(ptr)')),
    ir_fresh(B), ir_ins([B, ' = call i1 @llvm.coro.done(ptr ', V0, ')']), ir_fresh(V), ir_ins([V, ' = zext i1 ', B, ' to i8']).
ir_coro_builtin('__builtin_coro_promise', [P, A, F], V, ptr([], base([], [void])), ptr) :- ir_expr(P, V0, _, _),
    ccl_const_eval(A, AV), ( ccl_const_eval(F, FV) -> true ; FV = 0 ), ( FV =:= 0 -> FB = false ; FB = true ),
    ir_note_extern('llvm.coro.promise', raw('declare ptr @llvm.coro.promise(ptr, i32, i1)')),
    ir_fresh(V), ir_ins([V, ' = call ptr @llvm.coro.promise(ptr ', V0, ', i32 ', AV, ', i1 ', FB, ')']).
ir_stmt(assume(L, E)) :- !, ir_line(L), ir_cond(E, C), ir_note_extern('llvm.assume', raw('declare void @llvm.assume(i1)')), ir_ins(['call void @llvm.assume(i1 ', C, ')']).   % C++23's [[assume(e)]]: told to LLVM as its own intrinsic
ir_stmt(defer(L, _, Body)) :- !, ir_line(L), ir_defer_push(Body).
ir_stmt(if(L, C, T, E)) :- !, ir_line(L),
    ir_label(LT), ir_label(LE), ir_label(LM), ir_cond(C, CC),
    ( E == none -> ir_end(['br i1 ', CC, ', label %', LT, ', label %', LM]) ; ir_end(['br i1 ', CC, ', label %', LT, ', label %', LE]) ),
    ir_block(LT), ir_stmt(T), ir_end(['br label %', LM]),
    ( E == none -> true ; ir_block(LE), ir_stmt(E), ir_end(['br label %', LM]) ),
    ir_block(LM).
ir_stmt(while(L, C, S)) :- !, ir_line(L),
    ir_label(LC), ir_label(LB), ir_label(LE), ir_block(LC), ir_cond(C, CC), ir_end(['br i1 ', CC, ', label %', LB, ', label %', LE]),
    ir_block(LB), ir_loop_push(LE, LC), ir_stmt(S), ir_loop_pop, ir_end(['br label %', LC]), ir_block(LE).
ir_stmt(do(L, S, C)) :- !, ir_line(L),
    ir_label(LB), ir_label(LC), ir_label(LE), ir_block(LB), ir_loop_push(LE, LC), ir_stmt(S), ir_loop_pop,
    ir_block(LC), ir_cond(C, CC), ir_end(['br i1 ', CC, ', label %', LB, ', label %', LE]), ir_block(LE).
ir_stmt(for_each(L, D, R, S)) :- !, ( ccl_for_each_as_for(for_each(L, D, R, S), For) -> ir_stmt(For) ; ir_fail(range_for_over_non_array) ).   % C++ (M6)
ir_stmt(using(_, _)) :- !.
ir_stmt(try(L, Body, Catches)) :- !, ir_try(L, Body, Catches).
ir_stmt(eh_end_catch) :- !, ir_ins(['call void @__cxa_end_catch()']).
ir_stmt(for(L, Init, C, Step, S)) :- !, ir_line(L),
    ir_env_push,
    ( Init = decl(_, Vs) -> ir_locals(Vs, none) ; Init == none -> true ; ir_expr(Init, _, _) ),
    ir_label(LC), ir_label(LB), ir_label(LS), ir_label(LE), ir_block(LC),
    ( C == none -> ir_end(['br label %', LB]) ; ir_cond(C, CC), ir_end(['br i1 ', CC, ', label %', LB, ', label %', LE]) ),
    ir_block(LB), ir_loop_push(LE, LS), ir_stmt(S), ir_loop_pop,
    ir_block(LS), ( Step == none -> true ; ir_expr(Step, _, _) ), ir_end(['br label %', LC]),
    ir_block(LE), ir_run_defers(1), ir_env_pop.
ir_stmt(return(L)) :- !, ir_line(L), ir_run_defers(all), ir_end(['ret void']).
ir_stmt(return(L, E)) :- nb_getval('$ir_ret', RT), ( RT = ref(_, _) ; RT = rref(_, _) ), !, ir_line(L),   % C++: a reference result is the address
    ir_ref_of(E, P), ir_run_defers(all), ir_end(['ret ptr ', P]).
%% ... AND A RETURNED ONE IS CONSTRUCTED IN THE RESULT (0.121): a function that returns its class through the hidden pointer builds `return T(args)' over `%agg.result', where it was built in a slot and stored there
%% (`return std::list<int>{1, 2, 3};' left the list's sentinel pointing into the dead frame, and `std::map<int, int> mk() { return std::map<int, int>{{1, 2}}; }' crashed at its first use).
ir_stmt(return(L, E)) :- nb_getval('$ir_ret_abi', Abi), ( Abi = memory(_, _) ; Abi = indirect(_, _) ), nb_getval('$ir_ret', RT),
    ir_prvalue_block(E, Tmp, TT, Pre), ir_same_object(RT, TT), !, ir_line(L),
    ir_in_place(Tmp, TT, '%agg.result', Pre), ir_run_defers(all), ir_end(['ret void']).
ir_stmt(return(L, E)) :- nb_getval('$ir_ret_abi', Abi), ( Abi = memory(_, _) ; Abi = indirect(_, _) ), nb_getval('$ir_ret', RT), ir_sret_call(E, RT), !, ir_line(L),   % `return build();' hands the callee OUR result pointer
    nb_setval('$ir_sret_into', '%agg.result'), ir_expr(E, _, _, _), nb_setval('$ir_sret_into', none), ir_run_defers(all), ir_end(['ret void']).
ir_stmt(return(L, E)) :- !, ir_line(L),
    nb_getval('$ir_ret', RT), nb_getval('$ir_ret_abi', Abi), ir_expr(E, V0, T0, L0),
    (   ccl_resolve_type(RT, base(_, [void])) -> ir_run_defers(all), ir_end(['ret void'])
    ;   Abi = direct(Pcs) -> ir_type(RT, LL), ir_pieces_type(Pcs, CL), ir_tmp(LL, Tmp), ( ir_ref_value_type(T0, _) -> ir_convert(V0, T0, L0, RT, LL, VD) ; VD = V0 ), ir_ins(['store ', LL, ' ', VD, ', ptr ', Tmp]),
            ir_fresh(C), ir_ins([C, ' = load ', CL, ', ptr ', Tmp]), ir_run_defers(all), ir_end(['ret ', CL, ' ', C])
    ;   ( Abi = memory(_, _) ; Abi = indirect(_, _) ) -> ir_type(RT, LL), ( ir_ref_value_type(T0, _) -> ir_convert(V0, T0, L0, RT, LL, V1) ; V1 = V0 ), ir_ins(['store ', LL, ' ', V1, ', ptr %agg.result']), ir_run_defers(all), ir_end(['ret void'])   % a value that is a REFERENCE (`return std::move(s);' of a plain struct, `static_cast<S &&>(s)'; 0.122) is read through: its value is the address
    ;   ir_type(RT, LL), ir_convert(V0, T0, L0, RT, LL, V), ir_run_defers(all), ir_end(['ret ', LL, ' ', V]) ).
ir_stmt(break(L)) :- !, ir_line(L), ir_loop_top(LE, _, Depth), ir_depth(D), K is D - Depth, ir_run_defers(K), ir_end(['br label %', LE]).
ir_stmt(continue(L)) :- !, ir_line(L), ir_continue_target(LC, Depth), ir_depth(D), K is D - Depth, ir_run_defers(K), ir_end(['br label %', LC]).
ir_stmt(goto(Ln, L)) :- !, ir_line(Ln), atom_concat('L.', L, LL), ir_end(['br label %', LL]).
ir_stmt(label(_, L, S)) :- !, atom_concat('L.', L, LL), ir_block(LL), ir_stmt(S).
ir_stmt(switch(L, E, block(Is))) :- !, ir_line(L),
    ir_expr(E, V0, T0, L0), ir_int(IT), ir_convert(V0, T0, L0, IT, i32, V),
    ir_label(LE), ir_switch_cases(Is, Cases, Default),
    ( Default = none -> DL = LE ; Default = DL ),
    ir_case_lines(Cases, Lines), ir_join(Lines, ' ', CL),
    ir_end(['switch i32 ', V, ', label %', DL, ' [ ', CL, ' ]']),
    ir_env_push, ir_loop_push(LE, none), ir_switch_body(Is, Cases, Default), ir_loop_pop, ir_run_defers(1), ir_env_pop,
    ir_block(LE).
ir_stmt(switch(L, E, S)) :- !, ir_stmt(switch(L, E, block([S]))).
ir_line(L) :- nb_setval('$ir_line', L).
ir_stmt(case(_, _, S)) :- !, ir_stmt(S).
ir_stmt(default(_, S)) :- !, ir_stmt(S).
ir_stmt(S) :- ir_fail(stmt(S)).

ir_locals([], _).
ir_locals([var(N, T, Init)|Vs], Sto) :-
    ccl_resolve_type(T, T1),
    (   ( T1 = ref(_, _) ; T1 = rref(_, _) )                             % C++: a reference, bound once to an address
    ->  nb_getval('$ir_reg', K), K1 is K + 1, nb_setval('$ir_reg', K1), atomic_list_concat(['%', N, '.', K1], Addr),
        ir_alloca_typed(Addr, T1), ir_local(N, T1, Addr),
        ( Init == none -> ir_fail(reference_unbound(N)) ; ir_ref_to(Init, T1, P), ir_ins(['store ptr ', P, ', ptr ', Addr]) )   % of the base sub-object, for a derived object over a base at an offset (ir_ref_to)
    ;   T1 = fn(_, _, _) -> ir_note_extern(N, T)                         % a local prototype
    ;   Sto == extern -> ir_note_extern(N, T)
    ;   ir_has_vla(T1)                                                     % A VARIABLE LENGTH ARRAY (C99, mandatory in C17): allocated HERE, in the body, with the bound's value -- the entry block's allocas are fixed
    ->  ( Init == none -> true ; Init == init([]) -> true ; ir_fail(vla_initialized(N)) ),   % C23 6.7.10: `{}' is the one initializer a VLA takes (0.117)
        %% THE BOUNDS ARE EVALUATED ONCE, at the declaration ([dcl.array], C 6.7.6.2/5), and kept in the type the
        %% lowering holds for the local, `arr(vla(Reg), E)' (0.99): `sizeof(a)' reads them back where it stands, so
        %% `int v[n]; n = 10; sizeof(v)' is the size v was made with (it re-read n before); and a VLA OF A VLA is ONE
        %% allocation of the flattened element count, `int a[n][m]' n*m ints, whose row `a[i]' lies i*m*4 bytes in
        %% (ir_lval(index) over ir_vla_bytes) -- `[0 x i32]' had been the row's LLVM type and every row lay at a[0]
        ir_vla_dims(T1, Dims, Inner), ir_vla_values(Dims, Vals), ir_vla_type(Vals, Inner, VT), ir_vla_product(Vals, Total), ir_type(Inner, EL),
        nb_getval('$ir_reg', K), K1 is K + 1, nb_setval('$ir_reg', K1), atomic_list_concat(['%', N, '.', K1], Addr),
        ir_ins([Addr, ' = alloca ', EL, ', i64 ', Total, ', align 16']), ir_local(N, VT, Addr),
        %% `= {}' (C23 6.7.10) zeroes every element: the bytes are the element count times the element's size, and the
        %% fill is LLVM's own `llvm.memset' (it vanishes for a VLA that is never read)
        (   Init == init([])
        ->  ccl_size_of(Inner, IS), ir_fresh(Bytes), ir_ins([Bytes, ' = mul i64 ', Total, ', ', IS]),
            ir_note_extern('llvm.memset.p0.i64', raw('declare void @llvm.memset.p0.i64(ptr, i8, i64, i1)')),
            ir_ins(['call void @llvm.memset.p0.i64(ptr ', Addr, ', i8 0, i64 ', Bytes, ', i1 false)'])
        ;   true )
    ;   ir_sized_type(T, T1, Init, ST),                                     % int xs[] = {...}: sized by its initializer
        nb_getval('$ir_reg', K), K1 is K + 1, nb_setval('$ir_reg', K1), atomic_list_concat(['%', N, '.', K1], Addr),
        ir_alloca_typed(Addr, ST), ir_local(N, ST, Addr), ir_init(Addr, ST, Init) ),
    ir_locals(Vs, Sto).
ir_has_vla(arr(NE, E)) :- ( \+ ccl_const_eval(NE, _) -> true ; ir_has_vla(E) ).
ir_vla_dims(arr(NE, E), [NE|Ds], Inner) :- ir_has_vla(arr(NE, E)), !, ir_vla_dims(E, Ds, Inner).
ir_vla_dims(T, [], T).
ir_vla_values([], []).
ir_vla_values([NE|Ds], [NV|Vs]) :- ir_expr(NE, NV0, NT, NL), ir_convert(NV0, NT, NL, base([], [long]), i64, NV), ir_vla_values(Ds, Vs).
ir_vla_type([], Inner, Inner).
ir_vla_type([NV|Vs], Inner, arr(vla(NV), T)) :- ir_vla_type(Vs, Inner, T).
ir_vla_product([V], V) :- !.
ir_vla_product([V|Vs], P) :- ir_vla_product(Vs, P0), ir_fresh(P), ir_ins([P, ' = mul i64 ', V, ', ', P0]).
ir_vla_dims_vals(arr(vla(V), E), [V|Vs], Inner) :- !, ir_vla_dims_vals(E, Vs, Inner).
ir_vla_dims_vals(T, [], T).
ir_vla_bytes(T, B) :- ir_vla_dims_vals(T, Vals, Inner), Vals \== [], ccl_size_of(Inner, IS), ir_vla_product([IS|Vals], B).   % the bytes of a type with runtime dims
ir_vla_expr_type(id(N), T) :- ir_lookup(N, loc(_, T)), T = arr(vla(_), _).
ir_vla_expr_type(index(E, _), ET) :- ir_vla_expr_type(E, arr(_, ET)).
ir_vla_expr_type(deref(E), ET) :- ir_vla_expr_type(E, arr(_, ET)).
%% a static local is a private global of the function's, initialized once, constant
ir_static_locals([]).
ir_static_locals([var(N, T, Init)|Vs]) :-
    ccl_resolve_type(T, T1), ir_sized_type(T, T1, Init, GT), ir_gconst_typed(Init, GT, LL, C), ir_galign(GT, Al),
    nb_getval('$ir_fn', F), nb_getval('$ir_statics', K), K1 is K + 1, nb_setval('$ir_statics', K1),
    atomic_list_concat(['@', F, '.', N, '.', K1], Addr),
    ( ir_tls(T) -> TL = 'internal thread_local global ' ; TL = 'internal global ' ),
    ir_dbg_static_local(N, GT, SDbg), atomic_list_concat([Addr, ' = ', TL, LL, ' ', C, Al, SDbg], Def),
    nb_getval('$ir_gdefs', Gs), nb_setval('$ir_gdefs', [Def|Gs]),
    ir_local(N, GT, Addr), ir_static_locals(Vs).
%% the `thread_local' qualifier sits in the innermost base's list, whatever the declarator wrapped around it
ir_tls(base(Q, _)) :- memberchk(thread_local, Q), !.
ir_tls(ptr(_, T)) :- ir_tls(T).
ir_tls(arr(_, T)) :- ir_tls(T).

%% the loop stack: break target, continue target (none in a switch), and the defer depth at entry
ir_loop_push(LE, LC) :- ir_depth(D), nb_getval('$ir_loops', L), nb_setval('$ir_loops', [loop(LE, LC, D)|L]).
ir_loop_pop :- nb_getval('$ir_loops', [_|L]), nb_setval('$ir_loops', L).
ir_loop_top(LE, LC, D) :- nb_getval('$ir_loops', [loop(LE, LC, D)|_]), !.
ir_loop_top(_, _, _) :- ir_fail(break_outside_loop).
ir_continue_target(LC, D) :- nb_getval('$ir_loops', L), ( member(loop(_, LC, D), L), LC \== none -> true ; ir_fail(continue_outside_loop) ).

%% a switch body's cases, at the top level of its block
ir_switch_cases([], [], none).
ir_switch_cases([case(_, E, S)|Is], [case(E, L)|Cs], D) :- !, ir_label(L), ir_switch_cases([S|Is], Cs, D).
ir_switch_cases([default(_, S)|Is], Cs, L) :- !, ir_label(L), ir_switch_cases([S|Is], Cs, _).
ir_switch_cases([_|Is], Cs, D) :- ir_switch_cases(Is, Cs, D).
ir_case_lines([], []).
ir_case_lines([case(E, L)|Cs], [Line|Ls]) :- ir_const_int(E, N), atomic_list_concat(['i32 ', N, ', label %', L], Line), ir_case_lines(Cs, Ls).
ir_const_int(int(N), N) :- !.
ir_const_int(uint(N), N) :- !.
ir_const_int(long(N), N) :- !.
ir_const_int(ulong(N), N) :- !.
ir_const_int(wb(N), N) :- !.
ir_const_int(uwb(N), N) :- !.
ir_const_int(chr(C), C) :- !.
ir_const_int(neg(int(N)), M) :- !, M is -N.
ir_const_int(E, V) :- ccl_const_eval(E, V), !.
ir_const_int(E, _) :- ir_fail(case(E)).
ir_switch_body([], _, _).
ir_switch_body([case(_, E, S)|Is], Cases, D) :- !, memberchk(case(E, L), Cases), ir_block(L), ir_switch_body([S|Is], Cases, D).
ir_switch_body([default(_, S)|Is], Cases, D) :- !, ir_block(D), ir_switch_body([S|Is], Cases, D).
ir_switch_body([S|Is], Cases, D) :- ir_stmt(S), ir_switch_body(Is, Cases, D).

%% ---- functions and globals -------------------------------------------------------------------
ir_item(function(_, _, _, operator(Op), _, _, _)) :- !, ir_fail(operator(Op)).                     % C++: the class step's
ir_item(function(_, _, _, Name, _, _, _)) :- \+ atom(Name), !, ir_fail(member_of_class(Name)).
ir_item(dtor_def(_, _, _, _)) :- !, ir_fail(destructor).
ir_item(declaration(_, _, _, Vs)) :- member(var(N, _, _), Vs), \+ atom(N), !, ir_fail(member_of_class(N)).
ir_item(declare(_, base(_, [class(_, N, _, _)]))) :- !, ir_fail(class(N)).
ir_item(ctor(_, _, _, _, _)) :- !, ir_fail(constructor).
ir_item(dtor(_, _, _)) :- !, ir_fail(destructor).
ir_item(method(_, _, _, N, _, _, _)) :- !, ir_fail(method(N)).
ir_item(function(_, _, _, Name, _, _, none)) :- atom(Name), !.                 % a PROTOTYPE: nothing to define, and its `declare' line comes from the externals a call names (declval and kin, declared and never defined)
ir_item(function(FL, Sto, Ret, Name, Params, Var, Body)) :- !, nb_setval('$ir_fn_line', FL),
    ( Name == '$cpp_ginit' -> ir_note_extern('llvm.global_ctors', raw('@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @$cpp_ginit, ptr null }]')) ; true ),   % C++'s dynamic initialization of the unit's globals, run before main (0.112)
    ir_function(Sto, Ret, Name, Params, Var, Body, Text),
    ir_add_fdef(Text),
    nb_getval('$ir_defined', Ds), nb_setval('$ir_defined', [Name|Ds]).
ir_item(declaration(GL, Sto, _, Vs)) :- !, ( integer(GL) -> nb_setval('$ir_gline', GL) ; true ), ir_globals(Vs, Sto).
ir_item(extern_c(_, Is)) :- !, ir_items(Is).                              % C++ (M6): C linkage is what every name has
ir_item(namespace(_, _, Is)) :- !, ir_items(Is).                          % a namespace flattens to bare names (the symbol table's view too)
ir_item(using(_, _)) :- !.
ir_item(template(_, _, _)) :- !, ir_fail(template).
ir_item(_).

ir_function(Sto, Ret, Name, Params, Var, Body, Text) :-
    nb_setval('$ir_fn', Name), nb_setval('$ir_line', 0), nb_setval('$ir_body', []), nb_setval('$ir_allocas', []), nb_setval('$ir_term', no),
    nb_getval('$ir_fn_line', FL), ir_dbg_begin(Name, FL, Ret, Params, DbgAtt),
    nb_setval('$ir_env', [[]]), nb_setval('$ir_defers', [[]]), nb_setval('$ir_loops', []), nb_setval('$ir_ret', Ret), nb_setval('$ir_reg', 0),
    nb_setval('$ir_tries', []), nb_setval('$ir_personality', no), nb_setval('$ir_ehslots', none), nb_setval('$ir_unwinding', no), nb_setval('$ir_coro', none),
    ir_ret_abi(Ret, RetAbi), nb_setval('$ir_ret_abi', RetAbi),
    ccl_scope_push,
    ir_regs_start(RetAbi, R0), ir_params(Params, 0, R0, Sigs0, Stores),
    (   RetAbi = scalar -> ir_type(Ret, RL), Sigs = Sigs0
    ;   RetAbi = direct(Pcs) -> ir_pieces_type(Pcs, RL), Sigs = Sigs0
    ;   ir_sret_attr(RetAbi, SA), atom_concat(SA, ' %agg.result', S0), RL = void, Sigs = [S0|Sigs0] ),
    ir_join(Sigs, ', ', SigTxt),
    ( Var == true -> ( Sigs == [] -> Sig = '...' ; atom_concat(SigTxt, ', ...', Sig) ) ; Sig = SigTxt ),
    findall(PN-K, ( nth1(K, Params, P), ( P = param(_, PN) ; P = param(_, PN, _) ), atom(PN), PN \== anon ), PArgs), nb_setval('$ir_dbg_args', PArgs),   % -g: the parameters' numbers, and no location in the prologue (0.130)
    nb_setval('$ir_dbg_prologue', yes), ir_run_lines(Stores), nb_setval('$ir_dbg_prologue', no), nb_setval('$ir_dbg_args', []),
    ir_stmt(Body),
    ( ir_terminated(yes) -> true
    ; RL == void -> ir_end(['ret void'])
    ; Name == main -> ir_end(['ret i32 0'])
    ; ir_zero(RL, Z), ir_end(['ret ', RL, ' ', Z]) ),
    ccl_scope_pop,
    ( Sto == static -> Link = 'define internal ' ; Sto == linkonce -> Link = 'define linkonce_odr ' ; Link = 'define ' ),   % linkonce: a header's class or a template's instance, the same in every unit
    nb_getval('$ir_allocas', As0), reverse(As0, As), nb_getval('$ir_body', B0), reverse(B0, B),
    ( nb_getval('$ir_personality', yes) -> Pers = ' personality ptr @__gxx_personality_v0', ir_note_extern('__gxx_personality_v0', raw('declare i32 @__gxx_personality_v0(...)')) ; Pers = '' ),
    ( nb_getval('$ir_coro', none) -> Coro = '' ; Coro = ' presplitcoroutine' ),
    atomic_list_concat([Link, RL, ' @', Name, '(', Sig, ')', Coro, Pers, DbgAtt, ' {'], Head), nb_setval('$ir_dbg_sp', none),
    append([Head, 'entry:'|As], B, Lines0), append(Lines0, ['}', ''], Lines),
    ir_join(Lines, '\n', Text).
%% the parameters: a scalar is stored to its alloca; a struct in pieces arrives
%% as one register per piece, stored into an alloca of the struct; a struct
%% in memory (byval) or by a pointer to a copy is used where it is
ir_params([], _, _, [], []).
ir_params([param(T, N)|Ps], I, R0, Sigs, Stores) :-
    ir_param_abi(T, PT, Abi, R0, R1),
    ( N == anon -> atomic_list_concat(['%p', I], R) ; atomic_list_concat(['%', N], R) ),
    ir_param_sig(Abi, PT, N, R, Sigs0, Stores0),
    I1 is I + 1, ir_params(Ps, I1, R1, Sigs1, Stores1), append(Sigs0, Sigs1, Sigs), append(Stores0, Stores1, Stores).
ir_param_sig(scalar, PT, N, R, [Sig], Stores) :-
    ir_type(PT, LL), atomic_list_concat([LL, ' ', R], Sig),
    ( N == anon -> Stores = [] ; atom_concat(R, '.addr', Addr), Stores = [alloca(Addr, LL), store(LL, R, Addr), local(N, PT, Addr)] ).
ir_param_sig(direct(Pcs), PT, N, R, Sigs, Stores) :-
    ir_type(PT, LL), ir_piece_sigs(Pcs, R, 0, Sigs, Pieces),
    ( N == anon -> Stores = [] ; atom_concat(R, '.addr', Addr), ir_piece_stores(Pieces, Addr, St1), append(St1, [local(N, PT, Addr)], St2), Stores = [alloca_al(Addr, LL, 16)|St2] ).
ir_param_sig(memory(LL, A), PT, N, R, [Sig], Stores) :- atomic_list_concat(['ptr byval(', LL, ') align ', A, ' ', R], Sig), ( N == anon -> Stores = [] ; Stores = [local(N, PT, R)] ).
ir_param_sig(indirect(_, _), PT, N, R, [Sig], Stores) :- atomic_list_concat(['ptr ', R], Sig), ( N == anon -> Stores = [] ; Stores = [local(N, PT, R)] ).
ir_piece_sigs([], _, _, [], []).
ir_piece_sigs([piece(P, Off)|Ps], R, J, [Sig|Sigs], [pc(P, Reg, Off)|Pcs]) :-
    atomic_list_concat([R, '.', J], Reg), atomic_list_concat([P, ' ', Reg], Sig), J1 is J + 1, ir_piece_sigs(Ps, R, J1, Sigs, Pcs).
ir_piece_stores([], _, []).
ir_piece_stores([pc(P, Reg, Off)|Pcs], Addr, [store_at(P, Reg, Addr, Off)|Ss]) :- ir_piece_stores(Pcs, Addr, Ss).
ir_run_lines([]).
ir_run_lines([alloca(A, LL)|T]) :- ir_alloca(A, LL), ir_run_lines(T).
ir_run_lines([alloca_al(A, LL, Al)|T]) :- ir_alloca_aligned(A, LL, Al), ir_run_lines(T).
ir_run_lines([store(LL, R, A)|T]) :- ir_ins(['store ', LL, ' ', R, ', ptr ', A]), ir_run_lines(T).
ir_run_lines([store_at(PL, R, A, Off)|T]) :- ir_store_at(PL, R, A, Off), ir_run_lines(T).
ir_run_lines([local(N, T0, A)|T]) :- ir_local(N, T0, A), ir_run_lines(T).

ir_globals([], _).
ir_globals([var(N, T, Init)|Vs], Sto) :-
    ccl_resolve_type(T, T1),
    (   ( T1 = fn(_, _, _) ; Sto == extern ; Sto == typedef ) -> true
    ;   ir_sized_type(T, T1, Init, GT), ( ir_gconst_typed(Init, GT, LL, C) -> true ; ir_cpp_trace(global_failed(N, GT, Init)), fail ), ir_galign(GT, Al),
        ( Sto == static -> Link0 = 'internal global' ; Sto == linkonce -> Link0 = 'linkonce_odr global' ; Link0 = 'global' ),   % linkonce: a class's static with its initializer, the same in every unit
        ( ir_tls(T) -> atom_concat(Link0, '', L0), ( L0 == global -> Link = 'thread_local global' ; sub_atom(L0, B, _, 0, ' global'), sub_atom(L0, 0, B, _, Pre), atomic_list_concat([Pre, ' thread_local global'], Link) ) ; Link = Link0 ),   % _Thread_local, thread_local: one per thread
        ir_dbg_global(N, GT, GDbg), atomic_list_concat(['@', N, ' = ', Link, ' ', LL, ' ', C, Al, GDbg], Def),
        nb_getval('$ir_gmap', M), nb_setval('$ir_gmap', [N-GT|M]),
        nb_getval('$ir_defined', Ds),
        (   memberchk(N, Ds) -> true                                                     % defined already: a tentative one after it is nothing
        ;   Init == none, \+ ccl_lang(cpp) -> nb_getval('$ir_tent', Ts), nb_setval('$ir_tent', [N-Def|Ts])   % A TENTATIVE DEFINITION (C 6.9.2): emitted at the unit's end, unless a definition with an initializer came
        ;   nb_getval('$ir_gdefs', Gs), nb_setval('$ir_gdefs', [Def|Gs]), nb_setval('$ir_defined', [N|Ds]) ) ),
    ir_globals(Vs, Sto).
ir_flush_tentatives :- nb_getval('$ir_tent', Ts), reverse(Ts, Ts1), ir_flush_tentatives(Ts1).
ir_flush_tentatives([]).
ir_flush_tentatives([N-Def|Ts]) :- nb_getval('$ir_defined', Ds),
    ( memberchk(N, Ds) -> true ; nb_getval('$ir_gdefs', Gs), nb_setval('$ir_gdefs', [Def|Gs]), nb_setval('$ir_defined', [N|Ds]) ), ir_flush_tentatives(Ts).
%% an unsized array, global or local, takes its size from its initializer
ir_sized_type(_, arr(none, E), init(Items), arr(int(K), E)) :- !, length(Items, K).
ir_sized_type(_, arr(none, E), str(S), arr(int(K), E)) :- !, length(S, K0), K is K0 + 1.
ir_sized_type(T, _, _, T).
ir_float_builtin('__builtin_inf', '0x7FF0000000000000', base([], [double]), double).
ir_float_builtin('__builtin_huge_val', '0x7FF0000000000000', base([], [double]), double).
ir_float_builtin('__builtin_inff', '0x7FF0000000000000', base([], [float]), float).
ir_float_builtin('__builtin_huge_valf', '0x7FF0000000000000', base([], [float]), float).
ir_float_builtin('__builtin_nan', '0x7FF8000000000000', base([], [double]), double).
ir_float_builtin('__builtin_nanf', '0x7FF8000000000000', base([], [float]), float).
ir_float_builtin('__builtin_infl', '0xK7FFF8000000000000000', base([], [long, double]), x86_fp80) :- ccl_long_double(x87), !.   % the long double forms (0.108), x87's where a long double is
ir_float_builtin('__builtin_huge_vall', '0xK7FFF8000000000000000', base([], [long, double]), x86_fp80) :- ccl_long_double(x87), !.
ir_float_builtin('__builtin_nanl', '0xK7FFFC000000000000000', base([], [long, double]), x86_fp80) :- ccl_long_double(x87), !.
ir_float_builtin('__builtin_infl', '0xL00000000000000007FFF000000000000', base([], [long, double]), fp128) :- ccl_long_double(quad), !.   % ... a quad's where a long double is one (0.131)
ir_float_builtin('__builtin_huge_vall', '0xL00000000000000007FFF000000000000', base([], [long, double]), fp128) :- ccl_long_double(quad), !.
ir_float_builtin('__builtin_nanl', '0xL00000000000000007FFF800000000000', base([], [long, double]), fp128) :- ccl_long_double(quad), !.
ir_float_builtin('__builtin_infl', '0x7FF0000000000000', base([], [long, double]), double).
ir_float_builtin('__builtin_huge_vall', '0x7FF0000000000000', base([], [long, double]), double).
ir_float_builtin('__builtin_nanl', '0x7FF8000000000000', base([], [long, double]), double).
ir_imag_const(imag(F), F).
ir_imag_const(imagf(F), F).
ir_imag_const(imagl(F), F).
ir_imag_const(imagi(_, N), N).   % `3i' (0.103); a `big(A)' spelled by ir_complex_text
ir_imag_const(neg(X), F) :- ir_imag_const(X, F0), F is -F0.
ir_gconst(E, T, Text) :- ccl_is_complex(T), !, ccl_complex_real(T, RT), ir_type(RT, EL),                          % a complex global's constant: `{ double R, double I }' (0.100)
    (   E == none -> R = 0, I = 0 ; E = call(id('__builtin_complex'), [A, B]) -> ir_num_const(A, R), ir_num_const(B, I)
    ;   ir_imag_const(E, I) -> R = 0                                                                       % `2.0i' (0.101)
    ;   E = bin('+', A, Im), ir_imag_const(Im, I) -> ir_num_const(A, R)                                   % `1.0 + 2.0i'
    ;   E = bin('+', Im, A), ir_imag_const(Im, I) -> ir_num_const(A, R)
    ;   E = bin('-', A, Im), ir_imag_const(Im, I0) -> ir_num_const(A, R), I is -I0                        % `1.0 - 2.0i'
    ;   ir_num_const(E, R), I = 0 ),
    ir_complex_text(R, EL, RT1), ir_complex_text(I, EL, IT1), atomic_list_concat(['{ ', EL, ' ', RT1, ', ', EL, ' ', IT1, ' }'], Text).
ir_complex_text(big(A), _, T) :- !, ir_big_text(A, T).
ir_complex_text(V, EL, A) :- ( ir_fp_ll(EL) -> ir_fp_text(V, EL, A) ; A is truncate(V) ).   % an integer complex's components are integers (0.103); a floating constant truncates as a conversion does
ir_gconst(none, T, Z) :- !, ir_type(T, LL), ir_zero(LL, Z).
ir_gconst(E, T, Text) :- E \= init(_), ccl_decimal_kind(T, K), !, ( ir_dec_fold(E, K, D) -> ir_dec_text(K, D, Text) ; ir_fail(decimal_constant(E)) ).   % a decimal global (0.129): a literal, its negation, an integer constant
ir_gconst(E, T, Text) :- E \= init(_), ir_fp_global(T, LL), ir_fp_value(E, V), !, ir_fp_const(V, LL, Text).   % A FLOATING GLOBAL (0.108): its initializer folded and spelled for ITS type -- `float g = 1.5f', `float h = 2', `long double x = 3.5L'; LLVM takes a float only as a double's hex that a float holds exactly, and an x86_fp80 only as its own 0xK form
ir_gconst(int(big(A)), _, V) :- !, ir_big_text(A, V).
ir_gconst(uint(big(A)), _, V) :- !, ir_big_text(A, V).
ir_gconst(long(big(A)), _, V) :- !, ir_big_text(A, V).
ir_gconst(ulong(big(A)), _, V) :- !, ir_big_text(A, V).
ir_gconst(neg(long(big(A))), _, V) :- !, \+ sub_atom(A, 0, 2, _, '0x'), atom_concat('-', A, V).   % LLVM takes a negative decimal, never `-u0x'
ir_gconst(neg(int(big(A))), _, V) :- !, \+ sub_atom(A, 0, 2, _, '0x'), atom_concat('-', A, V).
ir_big_text(A, V) :- ( sub_atom(A, 0, 2, _, '0x') -> sub_atom(A, 2, _, 0, H), atom_concat('u0x', H, V) ; V = A ).
ir_gconst(int(N), _, N) :- !.
ir_gconst(uint(N), _, N) :- !.
ir_gconst(long(N), _, N) :- !.
ir_gconst(ulong(N), _, N) :- !.
ir_gconst(wb(N), _, N) :- !.
ir_gconst(uwb(N), _, N) :- !.
ir_gconst(neg(long(N)), _, M) :- !, M is -N.
ir_gconst(bool(true), _, 1) :- !.                                         % C++
ir_gconst(bool(false), _, 0) :- !.
ir_gconst(nullptr, _, null) :- !.
ir_gconst(neg(int(N)), _, M) :- !, M is -N.
ir_gconst(id(N), _, Ref) :- ccl_declared(N, T), ccl_resolve_type(T, fn(_, _, _)), !, atom_concat('@', N, Ref), ir_note_extern(N, T).   % a function's address (a C++ table)
ir_gconst(cast(T, E), _, Text) :- ccl_resolve_type(T, memptr(_, _, F)), ccl_resolve_type(F, fn(_, _, _)), !,   % a pointer to member function as a constant (0.100): `{ ptr @f, i64 0 }', or the virtual bits
    ( E = addr(id(N)) -> atom_concat('@', N, Ref), atomic_list_concat(['{ ptr ', Ref, ', i64 0 }'], Text)
    ; ccl_const_eval(E, K) -> atomic_list_concat(['{ ptr inttoptr (i64 ', K, ' to ptr), i64 0 }'], Text) ).
ir_gconst(addr(id(N)), _, Ref) :- ccl_declared(N, _), !, atom_concat('@', N, Ref).
ir_gconst(chr(C), _, C) :- !.
ir_gconst(bin('+', str(S), int(K)), _, C) :- integer(K), !, ir_string(S, R), atomic_list_concat(['getelementptr inbounds (i8, ptr ', R, ', i64 ', K, ')'], C).   % a pointer into a literal, folded by the constexpr evaluator (0.112)
%% ... A WIDE LITERAL as a pointer's constant, or a pointer into one (0.115): `wstring_view{L"true"}' folded by the
%% evaluator, std::format's `__bool_strings<wchar_t>' (`widesv.cpp'); an array of wide characters stays refused here
ir_gconst(bin('+', W, int(K)), T, C) :- integer(K), ir_wide_lit(W, S, EL), \+ ccl_resolve_type(T, arr(_, _)), !, ir_wstring(S, EL, R), atomic_list_concat(['getelementptr inbounds (', EL, ', ptr ', R, ', i64 ', K, ')'], C).
ir_gconst(W, T, R) :- ir_wide_lit(W, S, EL), \+ ccl_resolve_type(T, arr(_, _)), !, ir_wstring(S, EL, R).
ir_gconst(float(F), T, A) :- !, ( ir_fp_global(T, LL) -> ir_fp_const(F, LL, A) ; ir_int_of_float(T, F, A) -> true ; ir_double(F, A) ).
ir_gconst(str(S), T, C) :- !,
    ccl_resolve_type(T, T1),
    ( T1 = arr(K, _) -> ir_escape(S, Esc), ir_str_tail(K, S, Tail), atomic_list_concat(['c"', Esc, Tail, '"'], C) ; ir_string(S, C) ).
%% a literal shorter than its array is ZERO-FILLED to the bound (C's rule: `char s[33] = "abc"'), and one that fills
%% it exactly has no terminator; a bound the literal alone gives takes its one `\00' -- the constant's type must be
%% the global's, and `[17 x i8]' into a `[33 x i8]' was refused by LLVM (libc++'s __num_get_base::__src[33])
ir_wide_lit(wstr(S), S, i32).
ir_wide_lit(u32str(S), S, i32).
ir_wide_lit(u16str(S), S, i16).
ir_str_tail(int(K), S, Tail) :- length(S, L), Z is K - L, Z >= 0, !, ir_zeros(Z, Tail).
ir_str_tail(_, _, '\\00').
ir_zeros(0, '') :- !.
ir_zeros(N, Z) :- N1 is N - 1, ir_zeros(N1, Z1), atom_concat('\\00', Z1, Z).
ir_gconst(rtti(Ch), _, C) :- !, ir_rtti_emit(Ch, Sym), atom_concat('@', Sym, C).   % the table's prefix names its class's type_info (0.108)
ir_gconst(compound_lit(_, init(Items)), T, C) :- !, ir_gconst(init(Items), T, C).   % C++: a global of an EMPTY class made by its type's name, `inline constexpr piecewise_construct_t piecewise_construct = piecewise_construct_t();' (the desugaring's temporary of a class with nothing to construct is a compound literal)
ir_gconst(init([]), T, Z) :- ccl_resolve_type(T, T1), \+ T1 = base(_, [struct(_, _)]), \+ T1 = base(_, [union(_, _)]), \+ T1 = arr(_, _), !, ir_type(T, LL), ir_zero(LL, Z).   % `int{}': the type's zero
ir_gconst(init(Items0), T, C) :- !,
    ccl_resolve_type(T, T1), ccl_init_norm(T1, Items0, Items),   % a designated list made positional (0.108)
    (   T1 = arr(int(K), E) -> ir_type(E, EL), ir_gitems(Items, K, E, EL, Parts), ir_join(Parts, ', ', Body), atomic_list_concat(['[', Body, ']'], C)
    ;   T1 = base(_, [struct(_, _)]) -> ir_gstruct(Items, T1, C)                 % the type is written by whoever holds the constant
    ;   T1 = base(_, [union(_, _)]) -> ir_gunion(Items, T1, _, C)
    ;   ir_fail(global_init(T)) ).
ir_gconst(E, T, C) :- E \= init(_), ccl_resolve_type(T, RT), ccl_is_integer(RT), catch(ccl_const_eval(E, V), _, fail), ( integer(V) -> atom_number(C, V) ; V = big(A), ir_big_text(A, C) ), !.   % any integer constant expression: a secondary table's offset-to-top, `-offsetof(C, $base$2)' (0.108)
%% AN INTEGER GLOBAL FROM A FLOATING INITIALIZER converts (C 6.3.1.4, [conv.fpint]; 0.129): `int g = 2.5;' and `unsigned __int128 g =
%% 3e38;' were spelled as a double's hex, which LLVM refuses for an integer, and `int g = -2.5;' was refused, global_init
ir_gconst(E, T, C) :- E \= init(_), ccl_resolve_type(T, RT), ccl_is_integer(RT), catch(ir_fp_value(E, F), _, fail), float(F), ir_int_of_float(T, F, C), !.
ir_gconst(E, _, _) :- ir_fail(global_init(E)).
ir_int_of_float(T, F, C) :- ccl_resolve_type(T, RT), ccl_cast_shape(RT, _, _), ccl_w_cast(T, F, V), ( integer(V) -> atom_number(C, V) ; V = big(A), ir_big_text(A, C) ).
%% a global's constant with its type: a union initialized takes the literal
%% type of the member given, padded to the union's size
ir_gconst_typed(init(Items0), T, LL, C) :- ccl_resolve_type(T, T1), T1 = base(_, [union(_, _)]), !, ccl_init_norm(T1, Items0, Items), ir_gunion(Items, T1, LL, C).
ir_gconst_typed(Init, T, LL, C) :- ir_type(T, LL), ir_gconst(Init, T, C).
ir_galign(T, Al) :- ccl_resolve_type(T, T1),
    (   ir_aligned_q(T1, A0) -> ( ccl_size_align(T1, _, A1) -> A is max(A0, A1) ; A = A0 ), atomic_list_concat([', align ', A], Al)
    ;   ( T1 = base(_, [struct(_, _)]) ; T1 = base(_, [union(_, _)]) ), ccl_size_align(T1, _, A) -> atomic_list_concat([', align ', A], Al) ; Al = '' ).
ir_gitems([], 0, _, _, []) :- !.
ir_gitems([], K, E, EL, [Z|Zs]) :- ir_type(E, _), ir_zero(EL, Z0), atomic_list_concat([EL, ' ', Z0], Z), K1 is K - 1, ir_gitems([], K1, E, EL, Zs).
ir_gitems([item(_, V)|Is], K, E, EL, [P|Ps]) :- ir_gconst(V, E, C), atomic_list_concat([EL, ' ', C], P), K1 is K - 1, ir_gitems(Is, K1, E, EL, Ps).
%% a struct constant over its shape: a plain member's constant, a run of
%% bitfields packed into its bytes, padding zero
ir_gstruct(Items0, ST, C) :-
    ccl_members_of(ST, Ms), ir_gelide(Items0, Ms, 0, Items), ir_gvalues(Items, Ms, 0, Vals),
    ir_type(ST, SLL), nb_getval('$ir_maps', Maps), memberchk(SLL-shape(Elems, Map), Maps),
    ir_gelems(Elems, 0, Map, Vals, Parts), ir_join(Parts, ', ', Body), atomic_list_concat(['{ ', Body, ' }'], C).
%% BRACE ELISION in a GLOBAL's constant too (0.91's rule for a local and the desugaring, 0.110): `static constexpr
%% std::array<K, 2> ks{K::a, K::c}' -- the array member takes as many of the items that follow as it has elements
ir_gelide([], _, _, []).
ir_gelide([item([], V)|Is], Ms, I, [item([], init(Sub))|Out]) :- V \= init(_), I1 is I + 1,
    ccl_nth(I1, Ms, member(MT, _, _)), ccl_resolve_type(MT, arr(B, _)), catch(ccl_const_eval(B, K), _, fail), K > 1,
    length(Ms, NM), length(Is, NI), NI > NM - I1, !,
    K1 is K - 1, ir_elide_take(K1, Is, More, Rest), findall(item([], W), member(W, [V|More]), Sub), ir_gelide(Rest, Ms, I1, Out).
ir_gelide([It|Is], Ms, I, [It|Out]) :- I1 is I + 1, ir_gelide(Is, Ms, I1, Out).
ir_gvalues([], _, _, []).
ir_gvalues([item(Ds, V)|Is], Ms, I, [N-V|Vs]) :-
    (   Ds = [field(F)|_] -> N = F, ir_member_index_(Ms, F, 0, I0, _), I1 is I0 + 1
    ;   I1 is I + 1, ccl_nth(I1, Ms, member(_, N, _)) ),
    ir_gvalues(Is, Ms, I1, Vs).
ir_gelems([], _, _, _, []).
ir_gelems([LL|Ls], Idx, Map, Vals, [P|Ps]) :-
    findall(M, ( member(M, Map), M = m(_, Idx, _, _) ), Here),
    (   Here == [] -> ir_zero(LL, Z), atomic_list_concat([LL, ' ', Z], P)
    ;   Here = [m(N, _, MT, none)] -> ( memberchk(N-V, Vals) -> ir_gconst(V, MT, C) ; ir_zero(LL, C) ), atomic_list_concat([LL, ' ', C], P)
    ;   ir_gpack(Here, Vals, 0, Packed), ir_array_count(LL, K),
        ir_le_bytes(Packed, K, Bytes), ir_escape(Bytes, Esc), atomic_list_concat([LL, ' c"', Esc, '"'], P) ),
    Idx1 is Idx + 1, ir_gelems(Ls, Idx1, Map, Vals, Ps).
%% the K of a `[K x i8]'
ir_array_count(LL, K) :- atom_codes(LL, [0'[|Cs]), ir_digits(Cs, Ds), number_codes(K, Ds).
ir_digits([C|Cs], [C|Ds]) :- C >= 0'0, C =< 0'9, !, ir_digits(Cs, Ds).
ir_digits(_, []).
ir_gpack([], _, Acc, Acc).
ir_gpack([m(N, _, _, bf(_, Off, W, _))|Ms], Vals, Acc, Packed) :-
    ( memberchk(N-V, Vals) -> ir_gbit_value(V, I) ; I = 0 ), Mask is (1 << W) - 1, Bits is (I mod (1 << W)) /\ Mask,
    Acc1 is Acc \/ (Bits << Off), ir_gpack(Ms, Vals, Acc1, Packed).
%% a bitfield's value in a global's constant: a HOLE between two designators is `init([])', the type's zero (ccl_init_norm),
%% and a braced scalar is its one item -- `.a = 1, .c = 1' over `int a : 1, b : 1, c : 1' met `case(init([]))' (0.112)
ir_gbit_value(init([]), 0) :- !.
ir_gbit_value(init([item(_, V)]), I) :- !, ir_gbit_value(V, I).
ir_gbit_value(bool(true), 1) :- !.
ir_gbit_value(bool(false), 0) :- !.
ir_gbit_value(V, I) :- ir_const_int(V, I).
ir_le_bytes(_, 0, []) :- !.
ir_le_bytes(V, K, [B|Bs]) :- B is V /\ 255, V1 is V >> 8, K1 is K - 1, ir_le_bytes(V1, K1, Bs).
%% a union constant: the member given (the first, or the designated one) in its own type, padded
ir_gunion(Items, UT, LL, C) :-
    ccl_members_of(UT, Ms), ccl_union_layout(Ms, 0, 1, N, _),
    (   Items = [item(Ds, V)|_] -> ( Ds = [field(F)|_] -> memberchk(member(MT, F, _), Ms) ; Ms = [member(MT, _, _)|_] ),
        ir_type(MT, MLL), ir_gconst(V, MT, MC), ccl_resolve_type(MT, MT1), ccl_size_align(MT1, S, _), Pad is N - S,
        ( Pad =:= 0 -> atomic_list_concat(['{ ', MLL, ' }'], LL), atomic_list_concat(['{ ', MLL, ' ', MC, ' }'], C)
        ; atomic_list_concat(['{ ', MLL, ', [', Pad, ' x i8] }'], LL), atomic_list_concat(['{ ', MLL, ' ', MC, ', [', Pad, ' x i8] zeroinitializer }'], C) )
    ;   ir_type(UT, LL), C = zeroinitializer ).

%% ---- the module -----------------------------------------------------------------------------------
ir_assemble(IR) :-
    nb_getval('$ir_structs', Ss), ir_struct_defs(Ss, SDefs),
    nb_getval('$ir_strings', Strs), reverse(Strs, Strings),
    nb_getval('$ir_gdefs', Gs0), reverse(Gs0, Gs),
    nb_getval('$ir_fdefs', NF), ir_fdef_texts(1, NF, Fs),
    nb_getval('$ir_externs', Es), nb_getval('$ir_defined', Ds), ir_declares(Es, Ds, Decls),
    append(['; cicilang', ''|SDefs], Strings, L1), append(L1, Gs, L2), append(L2, [''|Fs], L3), append(L3, Decls, L4),
    ir_dbg_module(DL), append(L4, DL, L5),
    ir_join(L5, '\n', IR).
%% a function's text under its own key: `nb_getval/2' copies what it answers, and a list of every function's text
%% so far, read and written once per function, was quadratic over libc++'s six hundred items
ir_add_fdef(Text) :- nb_getval('$ir_fdefs', N), N1 is N + 1, nb_setval('$ir_fdefs', N1), atomic_list_concat(['$ir_fdef:', N1], K), nb_setval(K, Text).
ir_fdef_texts(I, N, []) :- I > N, !.
ir_fdef_texts(I, N, [T|Ts]) :- atomic_list_concat(['$ir_fdef:', I], K), nb_getval(K, T), I1 is I + 1, ir_fdef_texts(I1, N, Ts).
ir_struct_defs([], []).
ir_struct_defs([_-pending|T], D) :- !, ir_struct_defs(T, D).
ir_struct_defs([_-Def|T], [Def|D]) :- ir_struct_defs(T, D).
ir_declares([], _, []).
ir_declares([_-raw(D)|Es], Ds, [D|Decls]) :- !, ir_declares(Es, Ds, Decls).       % an intrinsic's line, spelled where it was used
ir_declares([N-_|Es], Ds, Decls) :- memberchk(N, Ds), !, ir_declares(Es, Ds, Decls).
ir_declares([N-T|Es], Ds, [D|Decls]) :-
    ccl_resolve_type(T, T1),
    (   T1 = fn(RT, Ps, Var) -> ir_fn_sig(RT, Ps, Var, RL, _, PLs), ir_join(PLs, ', ', PL),
            atomic_list_concat(['declare ', RL, ' @', N, '(', PL, ')'], D)
    ;   ir_type(T, LL), atomic_list_concat(['@', N, ' = external global ', LL], D) ),
    ir_declares(Es, Ds, Decls).
%% joins go through codes: atomic_list_concat/2 dies silently past ~8 KB
%% (a cocolog finding), atom_codes/2 takes hundreds of KB
%% the builtin joins 5000 lines in no time where a walk over their codes took
%% 0.3 s (the walk was for cocolog before 1.1.0, whose atomic_list_concat died
%% past 8 KB; it takes 16 MB since)
ir_join(Xs, Sep, A) :- atomic_list_concat(Xs, Sep, A).
