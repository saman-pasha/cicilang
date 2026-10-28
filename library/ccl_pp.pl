%% cicilang -- library(ccl_pp): the preprocessor, in cocolog. Owner's rule:
%% no clang and no LLVM binary, the embedded LLVM alone -- so what `clang -E'
%% did for a header the reader could not read raw is done here: the directives,
%% the conditional groups (#if with its constant expression, #ifdef, #elif,
%% #else, #endif), macro expansion (object-like and function-like, `#', `##',
%% __VA_ARGS__, hide sets against recursion, rescanning), #include and
%% #include_next resolved on the reader's own path, #pragma once, and the
%% built-ins a header asks (__has_include, __has_feature, __has_attribute,
%% __has_builtin ...). The target's predefined macros are data at the end of
%% this file, taken once from the reference compiler for both architectures
%% and for C++: the ABI's facts, no tool run.
%%
%%   ccl_pp_file(+Path, -Tokens, -Files)   Path preprocessed standalone -- the predefined
%%                                         macros and its own -- into the reader's tokens
%%                                         tok(Kind, Value, Line), and every file it pulled
%%   ccl_pp_macros(-Macros)                the macros defined when the last run ended,
%%                                         macro(Name, Params, Body), for a header's summary
%%
%% A file is worked LINE BY LINE: one pass strips its comments and joins its
%% continuations (pp_source/2, kept per process), then only the lines of the
%% groups taken are lexed, a false group being skipped by its `#' lines
%% alone, and a macro's body is lexed the first time it is used -- the SDK's
%% headers are mostly groups for other configurations and macros never
%% called. A header's own #error stops that file where it stands. An unknown
%% __has_feature, __has_attribute or __has_builtin answers 0, so a header
%% takes its plainest path, the one the reader reads best; __has_include is
%% answered for real. Every token a macro expands to carries the line of the
%% invocation.

%% ---- a run --------------------------------------------------------------------
ccl_pp_file(Path, Tokens, Files) :- ccl_pp_run(Path, no, Tokens, Files).
%% -fdebug-macro (0.134): A RUN THAT RECORDS THE MACROS as the files define them, for the debug information -- the user's
%% file preprocessed standalone, its includes in place (as `-E' runs it), each `#define' and `#undef' an event at its line,
%% each file entered an event at the line of the `#include' that enters it and left another (clang's `DIMacroFile' tree;
%% a guarded header included again is not entered, as clang's is not). An event is a global of its own, numbered: a list
%% would be copied whole at each one. A run that stops (a header's `#error', a line that does not lex) keeps what it saw.
ccl_pp_macro_trace(Path, Events) :-
    nb_setval('$pp_mt_n', 0), nb_setval('$pp_mt_line', 0), nb_setval('$pp_mtrace', on),
    ( catch(ccl_pp_file(Path, _, _), _, true) -> true ; true ),
    nb_setval('$pp_mtrace', off), nb_getval('$pp_mt_n', N),
    findall(E, ( between(1, N, I), atom_concat('$pp_mt:', I, K), nb_getval(K, E) ), Events).
pp_mt_on :- nb_current('$pp_mtrace', on).
pp_mt_note(E) :- nb_getval('$pp_mt_n', N0), N is N0 + 1, nb_setval('$pp_mt_n', N), atom_concat('$pp_mt:', N, K), nb_setval(K, E).
%% a definition as clang's debug information spells it: `F(a,b)', `F(fmt,...)', `F(x,rest...)'; the body's blanks one
%% space each, none at its ends, a literal's own kept (`"a  b"')
pp_mt_define(Rest, L) :- pp_ws(Rest, R1), pp_word(R1, W, R2), W \== [], !, atom_codes(N, W),
    (   R2 = [0'(|R3] -> pp_upto_close(R3, PCs, R4), pp_param_names(PCs, Ps), pp_mt_params(Ps, PT), atomic_list_concat([N, '(', PT, ')'], Name)
    ;   Name = N, R4 = R2 ),
    pp_mt_squash(R4, V), pp_mt_note(def(L, Name, V)).
pp_mt_define(_, _).
pp_mt_params(Ps, T) :- findall(A, ( member(P, Ps), ( P = va('__VA_ARGS__') -> A = '...' ; P = va(X) -> atom_concat(X, '...', A) ; A = P ) ), As), atomic_list_concat(As, ',', T).
pp_mt_squash(Cs0, V) :- pp_ws(Cs0, Cs1), pp_mt_sq(Cs1, Out), reverse(Out, ROut), pp_ws(ROut, ROut1), reverse(ROut1, Out1), atom_codes(V, Out1).
pp_mt_sq([], []).
pp_mt_sq([Q|Cs], [Q|Out]) :- ( Q =:= 34 ; Q =:= 39 ), !, pp_mt_quoted(Cs, Q, Out0, Rest), append(Out0, Out1, Out), pp_mt_sq(Rest, Out1).
pp_mt_sq([C|Cs], [32|Out]) :- ( C =:= 32 ; C =:= 9 ), !, pp_ws(Cs, Cs1), pp_mt_sq(Cs1, Out).
pp_mt_sq([C|Cs], [C|Out]) :- pp_mt_sq(Cs, Out).
pp_mt_quoted([], _, [], []).
pp_mt_quoted([92, C|Cs], Q, [92, C|Out], R) :- !, pp_mt_quoted(Cs, Q, Out, R).
pp_mt_quoted([Q|Cs], Q, [Q], Cs) :- !.
pp_mt_quoted([C|Cs], Q, [C|Out], R) :- pp_mt_quoted(Cs, Q, Out, R).
%% THE USER'S OWN FILE (Top = yes): its directives run and its macros expanded
%% like a header's, but an #include is passed on as the directive token for
%% the reader to resolve and read (the declarations come from the reader's
%% cache, the summaries and the store), with the header's MACROS loaded at
%% that point (ccl_header_macros/2 in ccl_include: from the summary, the
%% store, or one standalone run, made ready before this run begins, since a
%% run is not re-entrant); a #define or #undef is done and kept as a
%% directive item; a `#cocolog ... #end' block is the reader's, one token of
%% its raw lines; a `.pl' include is the reader's macro file. A line that
%% does not lex whole is the lexical error it always was.
ccl_pp_top(Path, Tokens, Files) :- nb_setval('$pp_warnings', []), ccl_pp_prescan(Path), ccl_pp_top_run(Path, [], Tokens, Files), ( memberchk(tok(other, C, L), Tokens) -> ( integer(C), C >= 128 -> throw(lexical_char(L, C)) ; throw(lexical(L)) ) ; true ).   % the warnings are the run's, read by the driver after the read (pp_reset leaves them: a nested header's run must not wipe the file's)
ccl_pp_run(Path, Top, Tokens, Files) :-
    ccl_ensure_globals, pp_reset, nb_setval('$pp_top', Top),
    nb_setval('$ccl_hash', punct),                                                   % the run lexes in the preprocessor's mode: `#' a punctuator, a number as spelled
    ( once(catch(pp_include_file(Path, Out, []), E, true)) -> true ; E = failed ),
    nb_setval('$ccl_hash', line), nb_setval('$pp_top', no),
    ( var(E) -> true ; E == failed -> fail ; throw(E) ),
    pp_finish(Out, Tokens),
    nb_getval('$pp_files', Fs), reverse(Fs, Files).
%% A COMPUTED #include IN THE USER'S FILE (C17 6.10.2/4; 0.211): the header that a macro names is known only in the run,
%% and a run is not re-entrant, so the macros of one that the prescan did not make ready are made ready after the run
%% and the file is run again, once for each such header new to the file (pp_do_include/6 lists them in '$pp_late')
%% ... AND AGAIN UNDER THE PROGRAM'S CONFIGURATION (0.215, pp_ftm_result/1) where the run found one other than the one
%% its headers were read under -- a feature-test macro the file defines after its first system #include -- the headers
%% made ready under it and the computed ones tried afresh; twice at most
ccl_pp_top_run(Path, Tried, Tokens, Files) :-
    ccl_pp_run(Path, yes, Tokens0, Files0), nb_getval('$pp_late', Late0), reverse(Late0, Late1), pp_new_specs(Late1, Tried, Late),
    (   Late \== [] -> pp_prescan_ready(Late, Path), nb_setval('$pp_warnings', []), append(Tried, Late, Tried1), ccl_pp_top_run(Path, Tried1, Tokens, Files)
    ;   pp_ftm_result(C), ( nb_current('$pp_ftm', C0) -> true ; C0 = [] ), C \== C0, ( nb_current('$pp_ftm_reruns', R) -> true ; R = 0 ), R < 2
    ->  R1 is R + 1, nb_setval('$pp_ftm_reruns', R1), nb_setval('$pp_ftm', C), ccl_pp_prescan(Path), nb_setval('$pp_warnings', []), ccl_pp_top_run(Path, [], Tokens, Files)
    ;   Tokens = Tokens0, Files = Files0 ).
pp_new_specs([], _, []).
pp_new_specs([S|Ss], Seen, New) :- ( memberchk(S, Seen) -> New = New1, Seen1 = Seen ; New = [S|New1], Seen1 = [S|Seen] ), pp_new_specs(Ss, Seen1, New1).
%% the includes a file names, their headers read and their macros made ready, in the file's order; the cold library
%% headers among them first read by processes of their own, where there are two or more (0.188; ccl_cold_headers_read/2)
ccl_pp_prescan(Path) :- pp_source(Path, Lines), pp_prescan_specs(Lines, Specs), ccl_cold_headers_read(Specs, Path), pp_prescan_ready(Specs, Path).
pp_prescan_specs([], []).
pp_prescan_specs([line(_, A)|Ls], Specs) :-
    (   pp_directive_line(A, Body), pp_ws(Body, B1), pp_word(B1, W, Rest), atom_codes(D, W), ( D == include ; D == include_next ),
        pp_ws(Rest, R1), pp_inc_name(R1, Spec0)
    ->  ( D == include_next -> Spec = next(Spec0) ; Spec = Spec0 ), Specs = [Spec|Specs1]
    ;   pp_import_line(A, Spec) -> Specs = [Spec|Specs1]
    ;   Specs = Specs1 ),
    pp_prescan_specs(Ls, Specs1).
pp_prescan_ready([], _).
pp_prescan_ready([Spec|Specs], Path) :- ( catch(ccl_header_macros_ready(Spec, Path), _, true) -> true ; true ), pp_prescan_ready(Specs, Path).
%% THE PROGRAM'S FEATURE-TEST MACROS (0.214, 0.215): a name of pp_ftm_name/1's that the user's file, or a local header it
%% includes, defines or undefines configures every header's read, as the command line's -D and -U do (POSIX 2.2.1,
%% glibc's features.h, C's __STDC_WANT_*, libc++'s _LIBCPP_*). `'$pp_ftm'' holds them, N-def(Params, Codes) or N-undef
%% where they differ from the predefined macros and the command line's: a header's run asks them first
%% (pp_outer_macro/3), every key of a read folds them (ccl_read_level/1, ccl_sum_file/2), and the processes for cold
%% headers are given them. As clang has it, a name of pp_ftm_fixed/1's counts as it stands at the file's first #include
%% of a header that reads the C library (pp_spec_clib/1): glibc reads features.h once, and a later definition reaches no
%% header. A name of pp_ftm_each/1's counts as it stands at the file's last system #include (0.215): every glibc header
%% asks __STDC_WANT_* again (bits/libc-header-start.h), and libc++'s headers their _LIBCPP_ENABLE_* names. It is one
%% configuration for the file, so a header included before such a definition is read under it too. The fixed names'
%% state comes before the read (pp_ftm_find/1, so the store's key of the file is the right one), from one run of the
%% file that stops at its first #include of a header that reads the C library (pp_do_include/6 throws
%% pp_prologue(State)), or at its end where it has none; a file whose lines before it define none of the names and
%% include no local header is not run. The others' come from the top run (pp_ftm_at_include/1, pp_ftm_result/1), which
%% runs the file again where they differ from what its headers were read under (ccl_pp_top_run/4)
pp_ftm_find(Path) :-
    nb_setval('$pp_ftm', []), nb_setval('$pp_ftm_reruns', 0), pp_source(Path, Lines), pp_prologue_scan(Lines, Locals, Asks),
    (   Asks == yes
    ->  pp_prescan_ready(Locals, Path), ( nb_current('$pp_warnings', W0) -> true ; W0 = [] ), nb_setval('$pp_prologue', yes),
        catch(( ccl_pp_run(Path, yes, _, _) -> pp_ftm_state(St1), E = pp_prologue(St1) ; true ), E, true),
        nb_setval('$pp_prologue', no), nb_setval('$pp_warnings', W0),
        ( nonvar(E), E = pp_prologue(St) -> nb_setval('$pp_ftm', St) ; true )
    ;   true ).
%% the lines before the first #include of a header that reads the C library: the local headers they include, and
%% whether one of them is such a header or defines or undefines a name of pp_ftm_name/1's
pp_prologue_scan([], [], no).
pp_prologue_scan([line(_, A)|Ls], Locals, Asks) :-
    (   pp_directive_line(A, Body), pp_ws(Body, B1), pp_word(B1, W, Rest), atom_codes(D, W)
    ->  (   ( D == include ; D == include_next ), pp_ws(Rest, R1), pp_inc_name(R1, Spec)
        ->  (   D == include, Spec = local(_) -> Locals = [Spec|L1], Asks = yes, pp_prologue_scan(Ls, L1, _)
            ;   D == include, \+ pp_spec_clib(Spec) -> pp_prologue_scan(Ls, Locals, Asks)
            ;   Locals = [], Asks = no )
        ;   ( D == define ; D == undef ), pp_ws(Rest, R2), pp_word(R2, W2, _), W2 \== [], atom_codes(N, W2), pp_ftm_name(N)
        ->  Asks = yes, pp_prologue_scan(Ls, Locals, _)
        ;   pp_prologue_scan(Ls, Locals, Asks) )
    ;   pp_import_line(A, _) -> Locals = [], Asks = no
    ;   pp_prologue_scan(Ls, Locals, Asks) ).
%% the names a library header asks the program for: glibc's and POSIX's feature-test macros and Apple's, which
%% features.h and its kin read once (pp_ftm_fixed/1), and every __STDC_WANT_* and _LIBCPP_* name, which a header asks at
%% its own inclusion (pp_ftm_each/1). NDEBUG is <assert.h>'s alone, at each inclusion (pp_assert_include/1)
pp_ftm_name(N) :- pp_ftm_fixed(N), !.
pp_ftm_name(N) :- pp_ftm_each(N).
pp_ftm_each(N) :- atom(N), ( sub_atom(N, 0, _, _, '__STDC_WANT_') ; sub_atom(N, 0, _, _, '_LIBCPP_') ), !.
pp_ftm_fixed(N) :- member(N, ['_GNU_SOURCE', '_DEFAULT_SOURCE', '_BSD_SOURCE', '_SVID_SOURCE', '_POSIX_SOURCE', '_POSIX_C_SOURCE',
    '_XOPEN_SOURCE', '_XOPEN_SOURCE_EXTENDED', '_ISOC99_SOURCE', '_ISOC11_SOURCE', '_ISOC2X_SOURCE', '_ISOC23_SOURCE',
    '_LARGEFILE_SOURCE', '_LARGEFILE64_SOURCE', '_FILE_OFFSET_BITS', '_TIME_BITS', '_ATFILE_SOURCE', '_DYNAMIC_STACK_SIZE_SOURCE',
    '_REENTRANT', '_THREAD_SAFE', '_FORTIFY_SOURCE', '_DARWIN_C_SOURCE', '_ANSI_SOURCE', '_NONSTD_SOURCE',
    '__STDC_FORMAT_MACROS', '__STDC_LIMIT_MACROS', '__STDC_CONSTANT_MACROS']).
%% a header that reads the C library (0.215): in C every system header but those of clang's that include nothing of it
%% (pp_ftm_free_header/1), so `#include <stdarg.h>' before `#define _GNU_SOURCE' keeps it for <string.h> after, as in
%% clang; clang's <stdatomic.h> reads <stdint.h>, and <stdbit.h> is glibc's. In C++ every one, libc++'s __config
%% reading features.h
pp_spec_clib(Spec) :- pp_spec_system(Spec), \+ ( ccl_lang(c), Spec = system(H), pp_ftm_free_header(H) ).
pp_ftm_free_header(H) :- memberchk(H, ['stddef.h', 'stdarg.h', 'stdbool.h', 'float.h', 'iso646.h', 'stdalign.h', 'stdnoreturn.h', 'stdckdint.h']).
%% the state, against the predefined macros and the command line's: of pp_ftm_fixed/1's names and pp_ftm_want/1's, what
%% the run defined, undefined, or took from a local header's table; of the other names of pp_ftm_each/1's, what the file
%% itself defined or undefined ('$pp_ftm_defs', pp_ftm_note/1), since a library header's table defines _LIBCPP_* names
pp_ftm_state(St) :- pp_ftm_fixed_state(F), pp_ftm_each_state(E), append(F, E, St0), msort(St0, St).
pp_ftm_fixed_state(St) :- findall(N-D, ( pp_ftm_fixed(N), pp_ftm_own(N, D), \+ pp_ftm_base(N, D) ), St).
pp_ftm_each_state(St) :- nb_getval('$pp_ftm_defs', Ns0), findall(N, pp_ftm_want(N), Ws), append(Ws, Ns0, Ns1), sort(Ns1, Ns), findall(N-D, ( member(N, Ns), pp_ftm_own(N, D), \+ pp_ftm_base(N, D) ), St).
%% the __STDC_WANT_* names glibc's headers ask (bits/libc-header-start.h; LIB_EXT1 in <string.h> and kin), which no
%% system header defines and a local one may: autoconf's config.h defines them
pp_ftm_want(N) :- member(N, ['__STDC_WANT_LIB_EXT1__', '__STDC_WANT_LIB_EXT2__', '__STDC_WANT_IEC_60559_EXT__', '__STDC_WANT_IEC_60559_BFP_EXT__',
    '__STDC_WANT_IEC_60559_DFP_EXT__', '__STDC_WANT_IEC_60559_FUNCS_EXT__', '__STDC_WANT_IEC_60559_TYPES_EXT__', '__STDC_WANT_IEC_60559_ATTRIBS_EXT__',
    '__STDC_WANT_MATH_SPEC_FUNCS__']).
pp_ftm_own(N, D) :- pp_key(N, K), nb_getval('$pp_gen', G), ( nb_current(K, V) -> true ; V = none ),
    (   V = mac(G, Ps, codes(Cs), _) -> D = def(Ps, Cs)
    ;   V == undef(G) -> D = undef
    ;   pp_header_macro(N, Ps, Cs) -> D = def(Ps, Cs) ).
pp_ftm_base(N, D) :- ( pp_cmdline(N, B) -> true ; pp_predef_macro(N, Ps, Cs) -> B = def(Ps, Cs) ; B = undef ), D == B.
%% at a system #include of the top run: pp_ftm_find/1's run stops at the first that reads the C library; the real run
%% notes the state of pp_ftm_each/1's names, the last kept (0.215)
pp_ftm_at_include(Spec) :-
    (   nb_current('$pp_prologue', yes) -> ( pp_spec_clib(Spec) -> pp_ftm_state(St), throw(pp_prologue(St)) ; true )
    ;   pp_ftm_each_state(E), nb_setval('$pp_ftm_last', E) ).
%% the configuration the top run found (0.215): the fixed names' as pp_ftm_find/1 found them, the others' at the last
%% system #include, at the run's end where it met none -- the fixed names are not taken again, since a local header's
%% table made under them lacks what it defines only where they are undefined (`#ifndef _GNU_SOURCE')
pp_ftm_result(C) :-
    ( nb_current('$pp_ftm', C0) -> true ; C0 = [] ), findall(N-D, ( member(N-D, C0), pp_ftm_fixed(N) ), F),
    ( nb_getval('$pp_ftm_last', E), E \== none -> true ; pp_ftm_each_state(E) ),
    append(F, E, C1), msort(C1, C).
%% a #define or #undef of the user's file (the top run) of a name of pp_ftm_each/1's, noted for pp_ftm_each_state/1
pp_ftm_note(Rest) :- ( nb_getval('$pp_top', yes), pp_ws(Rest, R1), pp_word(R1, W, _), W \== [], atom_codes(N, W), pp_ftm_each(N) -> nb_getval('$pp_ftm_defs', Ns), nb_setval('$pp_ftm_defs', [N|Ns]) ; true ).
%% A HEADER UNIT'S MACROS ARE THE IMPORTER'S ([module.import]/5; 0.110): `import "h";' and `import <h>;' (and `export
%% import') make the header's macros visible after the line, as an #include does -- the line itself is passed on for
%% the reader, which reads the header as the include it amounts to
pp_import_line(A, Spec) :- atom(A), nb_getval('$ccl_lang', cpp), atom_codes(A, Cs), pp_ws(Cs, C1), pp_word(C1, W0, R0), atom_codes(W0A, W0),
    ( W0A == export -> pp_ws(R0, R1), pp_word(R1, W1, R2), atom_codes(import, W1) ; W0A == import, R2 = R0 ), pp_ws(R2, R3), pp_inc_name(R3, Spec).
%% the macros defined when the run ended, macro(Name, Params, text(Body)) --
%% the run's own, not the predefined: what a header's summary or store keeps
ccl_pp_macros(Macros) :-
    nb_getval('$pp_names', Ns), sort(Ns, Names), nb_getval('$pp_gen', G), pp_macro_terms(Names, G, Macros).
pp_macro_terms([], _, []).
pp_macro_terms([N|Ns], G, Ms) :-
    pp_macro_terms(Ns, G, Ms1),
    ( pp_key(N, K), nb_current(K, V), V = mac(G, Ps, codes(Cs), _) -> atom_codes(A, Cs), Ms = [macro(N, Ps, text(A))|Ms1] ; Ms = Ms1 ).
%% a header's macros reach the run on their first use (pp_header_macro/3):
%% <stdio.h> brings 1200 and a file names a dozen

%% a run is a GENERATION: a macro is mac(Gen, Params, codes(Cs), Tokens), and
%% one from an earlier run is simply not this run's -- no walk undefines them
pp_reset :-
    ( nb_current('$pp_gen', G0) -> G is G0 + 1 ; G = 1 ), nb_setval('$pp_gen', G),
    nb_setval('$pp_names', []), nb_setval('$pp_files', []), nb_setval('$pp_once', []), nb_setval('$pp_stack', []), nb_setval('$pp_linemap', []),
    nb_setval('$pp_counter', 0), nb_setval('$pp_outs', 0), nb_setval('$pp_errors', []), nb_setval('$pp_paste', no), nb_setval('$pp_top', no), nb_setval('$pp_hdrs', []), nb_setval('$pp_ninc', 0), nb_setval('$pp_late', []),
    nb_setval('$pp_ftm_last', none), nb_setval('$pp_ftm_defs', []).   % the program's configuration as the top run finds it (0.215)
pp_key(N, K) :- atom_concat('$pp:', N, K).
%% a macro: its parameters (obj for an object-like one; va(N) the variadic
%% one) and its body -- the codes as defined, the tokens once used
pp_define(N, Ps, Cs) :- pp_set_macro(N, Ps, Cs), nb_getval('$pp_names', Ns), nb_setval('$pp_names', [N|Ns]).   % a name twice is harmless: sorted where read
pp_set_macro(N, Ps, Cs) :- nb_getval('$pp_gen', G), pp_key(N, K), nb_setval(K, mac(G, Ps, codes(Cs), none)).
pp_undefine(N) :- nb_getval('$pp_gen', G), pp_key(N, K), nb_setval(K, undef(G)).
%% a name's macro: this run's, or, in the user's file, one of its headers'
%% (the tables made ready before the run; '$pp_hdrs' the headers passed
%% through, the last first), defined into the run on that first use; one
%% undefined in this run stays so
pp_macro(N, Ps, Body) :- pp_key(N, K), nb_getval('$pp_gen', G), ( nb_current(K, V) -> true ; V = none ), pp_macro_(V, G, N, K, Ps, Body).
pp_macro_(mac(G, Ps, C, T0), G, _, K, Ps, Body) :- !, ( T0 == none -> C = codes(Cs), pp_lex_mbody(Cs, Body1), pp_body_ops(Ps, Body1, Body0), pp_obj_paste(Ps, Body0, Body), nb_setval(K, mac(G, Ps, C, Body)) ; Body = T0 ).
pp_macro_(undef(G), G, _, _, _, _) :- !, fail.
pp_macro_(nomac(G, I), G, _, _, _, _) :- nb_getval('$pp_ninc', I), !, fail.                 % a miss remembered, good until the next include
pp_macro_(_, G, N, K, Ps, Body) :- ( pp_outer_macro(N, Ps, Cs) -> pp_macro_(mac(G, Ps, codes(Cs), none), G, N, K, Ps, Body) ; pp_note_miss(K, G), fail ).
pp_note_miss(K, G) :- nb_getval('$pp_ninc', I), nb_setval(K, nomac(G, I)).
%% AN OBJECT-LIKE MACRO'S `##' PASTES TOO (C17 6.10.3.3/3, both kinds of macro; 0.210), once, where its body is read:
%% `#define AB a ## b' is `ab' and `# ## #' the one token `##'. They were the tokens as written, and the reader met `##'
pp_obj_paste(obj, B0, B) :- memberchk(tok(p, '##', _), B0), !, pp_paste(B0, B).
pp_obj_paste(_, B, B).
%% A BODY'S `%:%:' AND `%:' ARE ITS OPERATORS `##' and `#' (C17 6.4.6/3; 0.211), `%:' in a function-like macro's, where
%% it is the stringizing one; anywhere else the digraph is spelled as written
pp_body_ops(Ps, B0, B) :- memberchk(tok(dg, _, _), B0), !, pp_body_ops_(B0, Ps, B).
pp_body_ops(_, B, B).
pp_body_ops_([], _, []).
pp_body_ops_([tok(dg, '%:%:', M)|Ts], Ps, [tok(p, '##', M)|Us]) :- !, pp_body_ops_(Ts, Ps, Us).
pp_body_ops_([tok(dg, '%:', M)|Ts], Ps, [tok(p, '#', M)|Us]) :- Ps \== obj, !, pp_body_ops_(Ts, Ps, Us).
pp_body_ops_([T|Ts], Ps, [T|Us]) :- pp_body_ops_(Ts, Ps, Us).
pp_defined(N) :- ( pp_builtin_name(N) -> true ; pp_key(N, K), nb_getval('$pp_gen', G), ( nb_current(K, V) -> true ; V = none ), pp_defined_(V, G, N) ).
pp_defined_(mac(G, _, _, _), G, _) :- !.
pp_defined_(undef(G), G, _) :- !, fail.
pp_defined_(nomac(G, I), G, _) :- nb_getval('$pp_ninc', I), !, fail.
pp_defined_(_, G, N) :- ( pp_outer_macro(N, _, _) -> true ; pp_key(N, K), pp_note_miss(K, G), fail ).
%% a macro from outside the run, defined into it: a header's (the run's own
%% name list takes it, as a #define would) or a predefined one (never listed:
%% a header's table is the header's own)
pp_outer_macro(N, Ps, Cs) :-                                                       % the predefined first: no header redefines one
    (   \+ nb_getval('$pp_top', yes), nb_current('$pp_ftm', F), F \== [], memberchk(N-D, F) -> ( D = def(Ps, Cs) -> pp_set_macro(N, Ps, Cs) ; pp_header_macro(N, Ps, Cs), pp_define(N, Ps, Cs) )   % THE PROGRAM'S FEATURE-TEST MACROS (0.214, pp_ftm_find/1) in a header's run, the file's after the command line's
    ;   pp_cmdline(N, D), \+ pp_ndebug_hidden(N) -> ( D = def(Ps, Cs) -> pp_set_macro(N, Ps, Cs) ; pp_header_macro(N, Ps, Cs), pp_define(N, Ps, Cs) )   % THE COMMAND LINE'S FIRST (0.112): `-DN=v' defines N before every file, `-UN' takes away a predefined one (a header may still define it)
    ;   pp_predef_macro(N, Ps, Cs) -> pp_set_macro(N, Ps, Cs)
    ;   pp_header_macro(N, Ps, Cs), pp_define(N, Ps, Cs) ).
%% ... BUT NOT NDEBUG IN THE READ OF <assert.h>'S OWN TABLE (0.221; C17 7.2/1: assert is defined by NDEBUG as it stands at each
%% inclusion, pp_assert_include/1): in the run whose first file is <assert.h> or <cassert> the command line's NDEBUG is no macro,
%% so the table holds the asserting `assert' and `__assert_fail', and each inclusion in the user's file applies NDEBUG there.
%% Under -DNDEBUG the table held `assert' as ((void)0) and no `__assert_fail', and `#undef NDEBUG' before `#include
%% <assert.h>' left the program's assertions out where clang's build asserts. A header that includes <assert.h> in its own
%% run sees the command line's NDEBUG, as clang's does
pp_ndebug_hidden('NDEBUG') :- nb_current('$pp_stack', St), St \== [], last(St, Root), atom(Root), ( sub_atom(Root, _, _, 0, '/assert.h') ; sub_atom(Root, _, _, 0, '/cassert') ), !.
%% -D and -U, as clang reads them: `-DN' is N defined as 1, `-DN=v' as v, `-D"F(x)=x+1"' a function-like macro; `-UN'
%% undefines N, the later of a -D and a -U of one name winning. The list is a process's own global, read where a
%% name's macro is first looked for, so a header's table made in the same process is made under it too.
ccl_pp_cmdline(Os) :- pp_cmdline_list(Os, [], L), nb_setval('$pp_cmdline', L).
pp_cmdline_list([], L, L).
pp_cmdline_list([define(T)|Os], L0, L) :- !, atom_codes(T, Cs), pp_cmd_define(Cs, N, D), pp_cmdline_put(N, D, L0, L1), pp_cmdline_list(Os, L1, L).
pp_cmdline_list([undef(N)|Os], L0, L) :- !, pp_cmdline_put(N, undef, L0, L1), pp_cmdline_list(Os, L1, L).
pp_cmdline_list([_|Os], L0, L) :- pp_cmdline_list(Os, L0, L).
pp_cmdline_put(N, D, L0, [N-D|L1]) :- ( select(N-_, L0, L1) -> true ; L1 = L0 ).
pp_cmd_define(Cs, N, def(Ps, Body)) :-
    pp_word(Cs, W, R0), W \== [], atom_codes(N, W),
    ( R0 = [0'(|R1] -> pp_upto_close(R1, PCs, R2), pp_param_names(PCs, Ps) ; Ps = obj, R2 = R0 ),
    ( R2 = [0'=|Body] -> true ; R2 == [] -> Body = [0'1] ; Body = R2 ).
pp_cmdline(N, D) :- nb_current('$pp_cmdline', L), memberchk(N-D, L).
pp_predef_macro(N, obj, Cs) :-
    (   ccl_lang(cpp), ccl_std(S), pp_std_table(S, Tab), pp_predef(N, Tab, T) -> true   % the level's own value first (__cplusplus, __cpp_constexpr ...)
    ;   ccl_lang(c), ccl_c_std(CS), pp_c_std_table(CS, CTab), ( pp_predef(N, CTab, T) ; pp_c_os_table(CTab, OTab), pp_predef(N, OTab, T) ) -> true   % C's own level (-std=c23): __STDC_VERSION__ and what the forms answer, the OS's own after it (0.194)
    ;   pp_target_table(TT), pp_predef(N, TT, T) -> T \== '$undef'                     % THE TARGET'S OWN, before the rest (0.131): Linux aarch64's long double, char and wchar_t; `$undef' is no macro
    ;   pp_predef(N, any, T) -> true
    ;   pp_os(O), pp_predef(N, O, T) -> true                                          % the host's own: __APPLE__ and __MACH__, or __linux__ and __ELF__
    ;   pp_arch(A), pp_predef(N, A, T) -> true
    ;   ccl_lang(cpp), \+ nb_current('$ccl_rtti', no), pp_predef(N, cpp_rtti, T) -> true   % RTTI unless -fno-rtti (0.191)
    ;   ccl_lang(cpp), \+ nb_current('$ccl_exceptions', no), pp_predef(N, cpp_eh, T) -> true   % exceptions unless -fno-exceptions (0.193)
    ;   ccl_lang(cpp), pp_os(linux), pp_predef(N, cpp_linux, T) -> true                % C++ on Linux's own (0.194): _GNU_SOURCE
    ;   nb_current('$ccl_iso', yes), pp_predef(N, iso, T) -> true                         % an ISO mode's own (0.214): __STRICT_ANSI__
    ;   \+ nb_current('$ccl_iso', yes), pp_gnu_table(Tab), pp_predef(N, Tab, T) -> true    % a GNU mode's own (0.214): linux and unix, C++'s __GLIBCXX_TYPE_INT_N_0
    ;   ccl_lang(cpp), pp_predef(N, cpp, T)
    ;   ccl_lang(c), pp_predef(N, c, T) ),                                            % C's own beyond the levels' (0.117): __SIZEOF_INT128__
    atom_codes(T, Cs).
%% A FUNCTION-LIKE PREDEFINED MACRO (0.194), `__INT64_C(c)' and kin, is the fact whose name holds its parameter list as
%% clang writes it, `'__INT64_C(c)'': asked by the name alone where no object-like one is, through the same tables. They
%% were facts no lookup reached, and `__INT64_C(5)' was a call of an undeclared function
pp_predef_macro(N, [c], Cs) :- atom_concat(N, '(c)', FN), pp_predef_macro(FN, obj, Cs).
pp_target_table(TT) :- pp_os(O), pp_arch(A), atomic_list_concat([O, '_', A], TT).
%% C's levels, the newest first: what -std=c23 answers where C17's table would -- and C11's and C99's own `__STDC_VERSION__'
%% (0.221; C11 6.10.8.1, C99 6.10.8): C17's 201710L answered -std=c11, and -std=c99, taken for C23 by `S >= 23', C23's 202311L
pp_c_std_table(S, c23) :- ccl_c_year(S, Y), Y >= 2023, !.
pp_c_std_table(11, c11) :- !.
pp_c_std_table(99, c99).
pp_c_os_table(CTab, OTab) :- pp_os(O), atomic_list_concat([CTab, '_', O], OTab).   % c23_linux, c23_darwin
pp_gnu_table(Tab) :- pp_os(O), atom_concat(gnu_, O, Tab).   % gnu_linux; gnu_darwin has no row
pp_gnu_table(cpp_gnu) :- ccl_lang(cpp).
%% the tables a level sees beyond cpp's (C++17's): the newest first
pp_std_table(S, cpp26) :- S >= 26.
pp_std_table(S, cpp23) :- S >= 23.
pp_std_table(S, cpp20) :- S >= 20.
%% the headers' tables, the last included first, by the table's kind
%% (ccl_header_macros/2): the summary's facts, the store's rows, or a list
pp_header_macro(N, Ps, Cs) :- nb_getval('$pp_hdrs', Hs), Hs \== [], pp_header_macro_(Hs, N, Ps, Cs).
pp_header_macro_([H|Hs], N, Ps, Cs) :-
    (   ccl_header_macros_known(H, Kind), pp_header_macro_in(Kind, H, N, Ps, A) -> atom_codes(A, Cs)
    ;   pp_header_macro_(Hs, N, Ps, Cs) ).
pp_header_macro_in(indexed, H, N, Ps, A) :- '$ccl_hml'(N, H, raw(L)), !, pp_raw_macro(L, N, Ps, A).
pp_header_macro_in(store(K), H, N, Ps, A) :- ccl_kb_macro(H, K, N, Ps, A).
pp_header_macro_in(list, H, N, Ps, A) :- ccl_hml_list(H, N, Ps, A).
pp_raw_macro(L, N, Ps, A) :-                                                       % the line as written, its `.' off; parsed into a FRESH term: term_to_atom given a bound one compares
    atom_length(L, Len), L1 is Len - 1, sub_atom(L, 0, L1, 1, A0), term_to_atom(T, A0), T = macro(N, Ps, text(A)).
pp_builtin_name(N) :- memberchk(N, ['__has_include', '__has_include_next', '__has_feature', '__has_extension', '__has_attribute', '__has_cpp_attribute',
    '__has_c_attribute', '__has_embed', '__has_declspec_attribute', '__has_builtin', '__has_warning', '__is_identifier', '__building_module', '__FILE__', '__LINE__',
    '__COUNTER__', '__DATE__', '__TIME__', '__is_target_arch', '__is_target_vendor', '__is_target_os', '__is_target_environment']).

%% the predefined macros, pp_predef(Name, any | Arch | cpp, Text) at the end of
%% the file, are answered by name on a miss (pp_predef_macro/3): 580 of them,
%% defined at every run they cost 25 ms, and a file names ten
%% THE OPERATING SYSTEM IS A TABLE OF ITS OWN (the Linux port, 0.93): the predefined table was taken from the
%% reference compiler on macOS, so `__APPLE__' and `__MACH__' were `any' and Linux compiled as a Mac with glibc's
%% headers under it -- glibc's and libc++'s __config each branch on the platform's macros. darwin or linux, from the
%% module's compile-time answer (ccl_host_os/1), `uname -s' only without the module.
pp_os(O) :-
    (   nb_current('$pp_os', O0) -> O = O0
    ;   once(catch(ccl_host_os(O1), _, fail)) -> O = O1, nb_setval('$pp_os', O)
    ;   ( once(catch(proc_run('uname -s', 5000, Out, _), _, fail)), atom_codes(A1, Out), sub_atom(A1, 0, _, _, 'Linux') -> O = linux ; O = darwin ),
        nb_setval('$pp_os', O) ).
pp_arch(A) :-                                                                    % the module's compile-time arch; uname only without the module
    (   nb_current('$pp_arch', A0) -> A = A0
    ;   once(catch(ccl_host_arch(A1), _, fail)) -> A = A1, nb_setval('$pp_arch', A)
    ;   ( once(catch(proc_run('uname -m', 5000, Out, _), _, fail)), atom_codes(A1, Out), sub_atom(A1, 0, _, _, arm) -> A = arm64 ; A = x86_64 ),
        nb_setval('$pp_arch', A) ).

%% ---- a file as lines --------------------------------------------------------------
%% line(N, Atom): a logical line -- continuations joined, comments gone (a
%% block comment's lines counted), strings and character constants kept as
%% they stand -- kept per process by path. The physical lines come from
%% atomic_list_concat/3, and only a line holding a slash or ending in a
%% backslash is walked code by code: a walk in cocolog costs about a
%% microsecond a character, and the SDK's closure of <stdio.h> is 700,000.
%% (sub_atom/5 with a free position enumerates, 150 us a call: a line is
%% tested through atom_codes/2 and memberchk/2, builtins both.)
pp_source(Path, Lines) :-
    ( nb_current('$ccl_trigraphs', yes) -> Tri = yes, KP = '$pp_srct:' ; Tri = no, KP = '$pp_src:' ),
    atom_concat(KP, Path, K),
    (   nb_current(K, L0), L0 \== none -> Lines = L0
    ;   ( catch(read_file_to_codes(Path, Codes0), _, fail) -> pp_trigraphs(Tri, Codes0, Codes), atom_codes(A, Codes), atomic_list_concat(Phys, '\n', A), pp_lines(Phys, 1, out, Lines) ; Lines = [] ),
        nb_setval(K, Lines) ).
%% TRANSLATION PHASE 1's TRIGRAPHS (C17 5.2.1.1), before the lines are spliced, so `??/' at a line's end continues
%% it: only in the ISO modes before C23, as clang (`-std=c17' reads them, `gnu17' and C23 do not), and only a file
%% that holds a `??' is walked at all
pp_trigraphs(yes, Cs0, Cs) :- append(_, [63, 63|_], Cs0), !, pp_tri(Cs0, Cs).
pp_trigraphs(_, Cs, Cs).
pp_tri([], []).
pp_tri([63, 63, C|R], [M|Out]) :- pp_trigraph(C, M), !, pp_tri(R, Out).
pp_tri([C|R], [C|Out]) :- pp_tri(R, Out).
pp_trigraph(61, 35).     % ??=  #
pp_trigraph(40, 91).     % ??(  [
pp_trigraph(47, 92).     % ??/  backslash
pp_trigraph(41, 93).     % ??)  ]
pp_trigraph(39, 94).     % ??'  ^
pp_trigraph(60, 123).    % ??<  {
pp_trigraph(33, 124).    % ??!  |
pp_trigraph(62, 125).    % ??>  }
pp_trigraph(45, 126).    % ??-  ~
pp_lines([], _, _, []).
pp_lines([P|Ps], N, in, Lines) :- !,                                              % inside a block comment: to its end
    (   atom_codes(P, Cs), pp_close(Cs, R1) -> atom_codes(Rest, R1), pp_lines([Rest|Ps], N, out, Lines)
    ;   N1 is N + 1, pp_lines(Ps, N1, in, Lines) ).
pp_lines([P|Ps], N, out, Lines) :- pp_raw_join(P, Ps, P1, Ps1, K), !, N1 is N + K, pp_lines_raw(P1, Ps1, N, N1, Lines).
pp_lines([P|Ps], N, out, Lines) :-
    atom_codes(P, Cs),
    (   \+ memberchk(47, Cs), \+ pp_ends_backslash(P) -> pp_line_mark(P, Cs, X), Lines = [line(N, X)|Lines1], N1 is N + 1, St1 = out, Ps1 = Ps
    ;   pp_join(Cs, P, Ps, N, Joined, Ps1, N1), pp_clean(Joined, Out, St1),
        atom_codes(OA, Out), pp_line_mark(OA, Out, X), Lines = [line(N, X)|Lines1] ),
    pp_lines(Ps1, N1, St1, Lines1).
%% A RAW STRING LITERAL THAT SPANS LINES (C++ only, 0.138): a line that opens `R"d(' and does not close it with `)d"'
%% takes the next lines, newlines kept, up to the line that closes it, and the whole is one line of the first one's
%% number; the lexers count the newlines inside the literal, and the lines after it keep their numbers. A line holds
%% `R"' where the split by it gives two parts or more (0.184): sub_atom/5 with its start free tries every start in
%% cocolog 2.11 (clauses over between/3), 26 us a line of 80 characters, where the split takes 0.7 us.
pp_raw_join(P, Ps, P1, Ps1, K) :- nb_current('$ccl_lang', cpp), atomic_list_concat(Rs, 'R"', P), Rs = [_, _|_], atom_codes(P, Cs), pp_raw_open(Cs, D), !,
    pp_raw_more(Ps, D, Qs, Ps1), length(Qs, K), atomic_list_concat([P|Qs], '\n', P1).
pp_raw_more([Q|Qs], D, [Q|Rs], Rest) :- atom_codes(Q, QCs), append([41|D], [34], Close),
    (   append(_, Tail, QCs), append(Close, After, Tail) -> ( pp_raw_open(After, D2) -> pp_raw_more(Qs, D2, Rs, Rest) ; Rs = [], Rest = Qs )
    ;   pp_raw_more(Qs, D, Rs, Rest) ).
%% the joined line goes on as any other: one that holds a `/' or ends in a backslash through the cleaning
pp_lines_raw(P1, Ps1, N, N1, [line(N, X)|Lines1]) :- atom_codes(P1, Cs),
    (   \+ memberchk(47, Cs), \+ pp_ends_backslash(P1) -> OA = P1, Out = Cs, N2 is N1 + 1, Ps2 = Ps1, St1 = out
    ;   pp_join(Cs, P1, Ps1, N1, Joined, Ps2, N2), pp_clean(Joined, Out, St1), atom_codes(OA, Out) ),
    pp_line_mark(OA, Out, X), pp_lines(Ps2, N2, St1, Lines1).
%% A DIRECTIVE LINE IS MARKED AS IT IS MADE (0.188): line(N, d(Atom)), its codes at hand here, once a file and process
%% (pp_source/2 keeps the lines); a text line keeps its atom. pp_directive_line/2 takes the mark: a line was converted
%% to codes at every test -- each run over the file, each false group skipped -- 1.40 million tests and as many
%% conversions in a cold read of <thread> over libc++ 21, the most of them text lines
pp_line_mark(A, Cs, X) :- ( pp_ws(Cs, R), pp_hash_intro(R, _) -> X = d(A) ; X = A ).
pp_hash_intro([35|Body], Body) :- !.
pp_hash_intro([37, 58|Body], Body).   % `%:' IS `#' (C 6.4.6/3, [lex.digraph]; 0.201): `%:include <x>' and `%:define' are directives
%% does the line open a raw string it leaves open? Its delimiter: a walk over ordinary strings, character literals and
%% comments, so a `R"' inside them is no literal
pp_raw_open([], _) :- !, fail.
pp_raw_open([47, 47|_], _) :- !, fail.
pp_raw_open([47, 42|R], D) :- !, append(_, [42, 47|R1], R), !, pp_raw_open(R1, D).
pp_raw_open([34|R], D) :- !, pp_skip_quoted(R, 34, R1), pp_raw_open(R1, D).
pp_raw_open([39|R], D) :- !, pp_skip_quoted(R, 39, R1), pp_raw_open(R1, D).
pp_raw_open([C|R], D) :- pp_ident_start(C), !, pp_take_ident(R, Id, R1),
    ( R1 = [34|R2], memberchk([C|Id], ["R", "u8R", "uR", "UR", "LR"]) -> pp_raw_lit(R2, D) ; pp_raw_open(R1, D) ).
pp_raw_open([C|R], D) :- C >= 0'0, C =< 0'9, !, pp_take_number(R, R1), pp_raw_open(R1, D).   % a pp-number with its separators, `1'000'
pp_raw_open([_|R], D) :- pp_raw_open(R, D).
pp_raw_lit(R, D) :- append(D0, [40|Body], R), length(D0, ND), ND =< 16, \+ ( member(X, D0), memberchk(X, [32, 41, 92, 9, 34]) ), !, append([41|D0], [34], Close),
    ( append(_, Tail, Body), append(Close, After, Tail) -> pp_raw_open(After, D) ; D = D0 ).
pp_skip_quoted([], _, []).
pp_skip_quoted([92, _|R], Q, R1) :- !, pp_skip_quoted(R, Q, R1).
pp_skip_quoted([Q|R], Q, R) :- !.
pp_skip_quoted([_|R], Q, R1) :- pp_skip_quoted(R, Q, R1).
pp_ident_start(C) :- ( C >= 0'a, C =< 0'z ; C >= 0'A, C =< 0'Z ; C == 0'_ ; C >= 128 ), !.   % a character past ASCII is an identifier's (0.196)
pp_take_ident([C|R], [C|Id], R1) :- ( pp_ident_start(C) ; C >= 0'0, C =< 0'9 ), !, pp_take_ident(R, Id, R1).
pp_take_ident(R, [], R).
pp_take_number([C|R], R1) :- ( pp_ident_start(C) ; C >= 0'0, C =< 0'9 ; C == 39 ; C == 0'. ), !, pp_take_number(R, R1).
pp_take_number(R, R).
pp_ends_backslash(P) :- atom_length(P, L), L > 0, L1 is L - 1, sub_atom(P, L1, 1, 0, Last),
    ( Last == '\\' -> true ; atom_codes(Last, [C]), ( C == 32 ; C == 9 ), atom_codes(P, Cs), memberchk(92, Cs), pp_before_backslash(Cs, _) ).   % TRAILING WHITESPACE AFTER THE BACKSLASH still splices ([lex.phases]/2 as clang reads it, with a warning; 0.99): the last character asked first, since every line comes through here
pp_before_backslash(Cs, C1) :- reverse(Cs, R), pp_skip_ws(R, [92|R1]), reverse(R1, C1).
pp_skip_ws([C|R], R1) :- ( C == 32 ; C == 9 ), !, pp_skip_ws(R, R1).
pp_skip_ws(R, R).
%% a line ending in a backslash continues on the next
pp_join(Cs, P, Ps, N, Joined, Ps1, N1) :-
    (   pp_ends_backslash(P), Ps = [Q|Qs] -> pp_before_backslash(Cs, C1), !, N0 is N + 1, atom_codes(Q, QCs), pp_join(QCs, Q, Qs, N0, J1, Ps1, N1), append(C1, J1, Joined)
    ;   Joined = Cs, Ps1 = Ps, N1 is N + 1 ).
%% one line's codes without its comments; `in' when a block comment stays open
pp_clean([], [], out).
pp_clean([C|R], Out, St) :- pp_cc(C, R, Out, St).
pp_cc(47, [47|_], [], out) :- !.
pp_cc(47, [42|R], [32|Out], St) :- !, ( pp_close(R, R1) -> pp_clean(R1, Out, St) ; Out = [], St = in ).
pp_cc(34, R, [34|Out], St) :- !, pp_quoted(R, 34, R1, S), pp_clean(R1, Out1, St), append(S, Out1, Out).
pp_cc(39, R, [39|Out], St) :- !, pp_quoted(R, 39, R1, S), pp_clean(R1, Out1, St), append(S, Out1, Out).
pp_cc(C, R, [C|Out], St) :- pp_clean(R, Out, St).
pp_close([42, 47|R], R) :- !.
pp_close([_|R], R1) :- pp_close(R, R1).
pp_quoted([], _, [], []) :- !.
pp_quoted([Q|R], Q, R, [Q]) :- !.
pp_quoted([92, C|R], Q, R1, [92, C|S]) :- !, pp_quoted(R, Q, R1, S).
pp_quoted([C|R], Q, R1, [C|S]) :- pp_quoted(R, Q, R1, S).
%% a directive line: `#' first, blanks before it allowed; Body the codes after
%% it (atom_codes/2 and a walk over the blanks: sub_atom/5 costs 70 us here);
%% a text line fails at the head, its atom no d(_) (pp_line_mark/3, 0.188)
pp_directive_line(d(A), Body) :- atom_codes(A, Cs), pp_ws(Cs, R), pp_hash_intro(R, Body).
%% a text line's tokens, at its line; a macro body or a directive's tail --
%% all in the preprocessor's mode: `#' and `##' punctuators, a number as spelled;
%% a text line's tokens that white space precedes marked, h(T, ['$sp']) (0.209)
pp_lex_line(N, A, Toks) :-
    (   ccl_lex_atom_marked(A, N, T, Rest) -> Toks = T, ( Rest \== [], nb_getval('$pp_top', yes) -> throw(lexical(N)) ; true )
    ;   Toks = [] ).
pp_lex_body(Codes, Toks) :- atom_codes(A, Codes), ( ccl_lex_atom(A, 0, T, _) -> Toks = T ; Toks = [] ).
%% A MACRO'S BODY (0.209): each token's mark in its line, 1 where white space came before it -- a body's tokens have no
%% line of their own, pp_wrap/6 gives them the invocation's
pp_lex_mbody(Codes, Toks) :- atom_codes(A, Codes), ( ccl_lex_atom_marked(A, 0, T, _) -> pp_body_marks(T, Toks) ; Toks = [] ).
pp_body_marks([], []).
pp_body_marks([h(tok(K, V, _), _)|Xs], [tok(K, V, 1)|Ts]) :- !, pp_body_marks(Xs, Ts).
pp_body_marks([tok(K, V, _)|Xs], [tok(K, V, 0)|Ts]) :- pp_body_marks(Xs, Ts).

%% ---- the run: files, lines, tokens ----------------------------------------------
%% a file whose whole text is one `#ifndef X ... #endif' with X defined by
%% its end is guarded: a later #include of it, X still defined, is nothing --
%% the SDK's headers include sys/cdefs.h ten times over, 760 lines each
pp_include_file(Path, Out0, Out) :-
    nb_getval('$pp_files', Fs), ( memberchk(Path, Fs) -> true ; nb_setval('$pp_files', [Path|Fs]) ),
    nb_getval('$pp_stack', St), length(St, Depth),
    (   Depth > 120 -> Out0 = Out
    ;   pp_guarded(Path) -> Out0 = Out
    ;   nb_setval('$pp_stack', [Path|St]), pp_out_key(K),
        ( pp_mt_on -> nb_getval('$pp_mt_line', IL), pp_mt_note(enter(IL, Path)) ; true ),
        \+ \+ ( pp_source(Path, Lines), pp_run(Lines, OutF, []), nb_setval(K, OutF), pp_note_guard(Path, Lines) ),   % EACH FILE IN A SCOPE THAT BACKTRACKS (below)
        ( pp_mt_on -> pp_mt_note(leave) ; true ),
        nb_getval('$pp_stack', [_|St1]), nb_setval('$pp_stack', St1),
        Out0 = [pp_out(K)|Out] ).
%% cocolog reclaims the heap on backtracking and by nothing else (its DESIGN-compiling.md: no collector), so a
%% deterministic run keeps every term it ever built: the flatten of <vector>'s closure peaked at 3.1 GB. Each file is
%% preprocessed inside \+ \+, which throws its garbage away -- the lines, the lexed tokens, the expansions -- and only
%% its output survives, copied once into a global under a fresh key; the stream carries pp_out(K) where the file's
%% tokens go, and pp_finish splices them in. The macro table, the guards, the file list are globals and survive alike.
pp_out_key(K) :- nb_getval('$pp_outs', N), N1 is N + 1, nb_setval('$pp_outs', N1), atom_concat('$pp_out:', N1, K).
pp_guarded(Path) :- atom_concat('$pp_guard:', Path, K), nb_current(K, G), G \== none, pp_defined(G).
pp_note_guard(Path, Lines) :-
    atom_concat('$pp_guard:', Path, K),
    (   nb_current(K, _) -> true
    ;   Lines = [line(_, First)|_], pp_directive_line(First, B), pp_ws(B, B1), pp_word(B1, W, R), atom_codes(ifndef, W),
        pp_ws(R, R1), pp_word(R1, GW, _), GW \== [], atom_codes(G, GW), pp_defined(G),
        pp_last(Lines, line(_, Last)), pp_directive_line(Last, LB), pp_ws(LB, LB1), pp_word(LB1, LW, _), atom_codes(endif, LW)
    ->  nb_setval(K, G)
    ;   nb_setval(K, none) ).
pp_last([X], X) :- !.
pp_last([_|Xs], X) :- pp_last(Xs, X).
pp_current_file(F) :- nb_getval('$pp_stack', [F|_]), !.
pp_current_file(none).
pp_run([], Out, Out).
pp_run([line(N, A)|Ls], Out0, Out) :-
    (   pp_directive_line(A, Body) -> pp_directive(Body, N, Ls, Ls1, Out0, Out1), pp_run(Ls1, Out1, Out)
    ;   nb_getval('$pp_top', yes), pp_import_line(A, Spec), pp_current_file(From), ccl_resolve_include(Spec, From, Path), ccl_header_macros_known(Path, _), nb_getval('$pp_hdrs', Hs), \+ memberchk(Path, Hs),
        nb_setval('$pp_hdrs', [Path|Hs]), nb_getval('$pp_ninc', I0), I1 is I0 + 1, nb_setval('$pp_ninc', I1), fail
    ;   pp_lex_line(N, A, Toks), pp_toks(top, Toks, Ls, Ls1, Out0, Out1), pp_run(Ls1, Out1, Out) ).
%% the stream: tokens, or h(Token, HideSet) from an expansion
pp_unwrap(h(T, HS), T, HS) :- !.
pp_unwrap(T, T, []).
pp_strip([], []).
pp_strip([X|Xs], [T|Ts]) :- pp_unwrap(X, T, _), pp_strip(Xs, Ts).
%% the tokens of a line (or of an argument), expanded into the output; a
%% function-like macro's arguments may run on to the following lines, pulled
%% as needed. M top gives the bare tokens; marks keeps each token as the
%% stream has it, its mark and its hide set, for an argument's substitution
%% (0.209, 0.210)
pp_toks(_, [], Ls, Ls, Out, Out).
pp_toks(M, [X|Xs], Ls, Ls1, Out0, Out) :-
    pp_unwrap(X, T, HS),
    (   T = tok(id, '_Pragma', _), pp_pragma_op(Xs, Ls, Xs1, Ls2) -> pp_toks(M, Xs1, Ls2, Ls1, Out0, Out)          % _Pragma("...") is a #pragma: nothing
    ;   T = tok(K, N, L), ( K == id ; K == kw ), \+ memberchk(N, HS), pp_expand(N, L, HS, Xs, Ls, Xs1, Ls2) -> pp_toks(M, Xs1, Ls2, Ls1, Out0, Out)
    ;   M == marks -> Out0 = [X|Out1], pp_toks(M, Xs, Ls, Ls1, Out1, Out)
    ;   Out0 = [T|Out1], pp_toks(M, Xs, Ls, Ls1, Out1, Out) ).
%% its operand, the parenthesized group as it stands -- a macro's #x is still unexpanded there
pp_pragma_op(Xs, Ls, Rest, Ls1) :- pp_paren_next(Xs, Ls, Xs0, Ls0), pp_collect_args(Xs0, Ls0, _, _, _, Rest, Ls1).
%% a name that is a macro: its expansion, hidden from itself, pushed back for the rescan; the name's mark of white space
%% the expansion's first token's (pp_wrap/6)
pp_expand(N, L, HS, Xs, Ls, Xs1, Ls) :- pp_builtin_obj(N, L, Body), !, pp_mark_of(HS, M0, HS1), pp_wrap(Body, M0, [N|HS1], L, W, _), append(W, Xs, Xs1).
pp_expand(N, L, HS, Xs, Ls, Xs1, Ls1) :- pp_text_builtin(N), pp_paren_next(Xs, Ls, Xs0, Ls0), !,   % A FEATURE QUESTION IN A TEXT LINE (0.198), as clang answers one: `__has_cpp_attribute(nodiscard)' in an expression was a call of nothing
    pp_collect_args(Xs0, Ls0, Args0, _, _, Rest, Ls1), ( Args0 = [A0] -> pp_strip(A0, Args) ; Args = [] ), pp_builtin_answer(N, Args, V), pp_mark_of(HS, M0, HS1), pp_wrap([tok(int, V, L)], M0, [N|HS1], L, W, _), append(W, Rest, Xs1).
pp_expand(N, L, HS, Xs, Ls, Xs1, Ls1) :-
    pp_macro(N, Ps, Body), pp_mark_of(HS, M0, HS1),
    (   Ps == obj -> pp_wrap(Body, M0, [N|HS1], L, W, ME), pp_push(W, ME, Xs, Xs1), Ls1 = Ls
    ;   pp_paren_next(Xs, Ls, Xs0, Ls0) -> pp_collect_args(Xs0, Ls0, Args0, RSeps, RP, Rest, Ls1), pp_fit_args(Ps, Args0, RSeps, Args), pp_subst(Body, Ps, Args, Subst), pp_rparen_meet(RP, HS1, HS2), pp_wrap(Subst, M0, [N|HS2], L, W, ME), pp_push(W, ME, Rest, Xs1) ).
pp_mark_of(['$sp'|HS], 1, HS) :- !.
pp_mark_of(HS, 0, HS).
%% A FUNCTION-LIKE MACRO'S EXPANSION IS HIDDEN FROM WHAT ITS NAME AND ITS CLOSING `)' BOTH ARE (0.210; the hide sets of
%% Prosser's algorithm, as clang and gcc expand): `NIL(G_1)(arg)' expands G_1, out of NIL's expansion, and NIL again --
%% the name's hide set alone kept NIL hidden there, and `G_0(42)' gave `NIL(42)' where both give `42'
pp_rparen_meet(none, HS, HS) :- !.
pp_rparen_meet(RP, HS, HS1) :- pp_unwrap(RP, _, RHS0), pp_mark_of(RHS0, _, RHS), pp_hs_meet(HS, RHS, HS1).
pp_hs_meet(_, [], []) :- !.
pp_hs_meet([], _, []).
pp_hs_meet([N|Ns], RHS, Out) :- ( memberchk(N, RHS) -> Out = [N|Out1] ; Out = Out1 ), pp_hs_meet(Ns, RHS, Out1).
pp_builtin_obj('__LINE__', L, [tok(int, P, L)]) :- pp_presumed(L, P, _).
pp_builtin_obj('__FILE__', L, [tok(str, Cs, L)]) :- pp_presumed(L, _, F), ccl_atom_bytes(F, Cs).   % a string's value in bytes (0.211)
pp_builtin_obj('__COUNTER__', L, [tok(int, C, L)]) :- nb_getval('$pp_counter', C), C1 is C + 1, nb_setval('$pp_counter', C1).
pp_builtin_obj('__DATE__', L, [tok(str, Cs, L)]) :- atom_codes('Jan  1 2026', Cs).
pp_builtin_obj('__TIME__', L, [tok(str, Cs, L)]) :- atom_codes('00:00:00', Cs).
pp_text_builtin(N) :- memberchk(N, ['__has_cpp_attribute', '__has_c_attribute', '__has_attribute', '__has_builtin', '__has_feature', '__has_extension', '__has_declspec_attribute', '__has_warning', '__is_identifier']).   % the questions clang answers in a text line too; `__has_include' is #if's alone
%% `#line N "file"' (C 6.10.4) and GNU's `# N "file"': the PRESUMED line and file from the next line on, per file --
%% what __LINE__ and __FILE__ answer (0.108); a diagnostic still names the physical place
pp_presumed(L, P, F) :- pp_current_file(F0), nb_getval('$pp_linemap', M), ( memberchk(F0-lm(D, F1), M) -> P is L + D, F = F1 ; P = L, F = F0 ).
%% AN EXPANSION'S TOKENS (0.209): at the invocation's line L, hidden from the name (HS), the first with the name's mark of
%% white space M0, each other with its own -- its line in a body (pp_lex_mbody/2) -- or the one an empty argument left before
%% it (spmark); the mark the hide set's head, '$sp'. ME is the mark that the token after the expansion takes: an expansion
%% of nothing passes the name's on, a last empty argument its own (clang and gcc: `a E+b' with E empty is "a +b")
pp_wrap([], M0, _, _, [], M0).
pp_wrap([spmark|Ts], M0, HS, L, W, ME) :- !, pp_wrap(Ts, M0, HS, L, W, ME).
pp_wrap([E|Ts], M0, HS, L, [X|Ws], ME) :- pp_body_el(E, K, V, _, HS, HS1), pp_mark(M0, tok(K, V, L), HS1, X), pp_wrap_(Ts, 0, HS, L, Ws, ME).
pp_wrap_([], P, _, _, [], P).
pp_wrap_([spmark|Ts], _, HS, L, Ws, ME) :- !, pp_wrap_(Ts, 1, HS, L, Ws, ME).
pp_wrap_([E|Ts], P, HS, L, [X|Ws], ME) :- pp_body_el(E, K, V, M, HS, HS1), M1 is M \/ P, pp_mark(M1, tok(K, V, L), HS1, X), pp_wrap_(Ts, 0, HS, L, Ws, ME).
pp_mark(1, T, HS, h(T, ['$sp'|HS])) :- !.
pp_mark(_, T, HS, h(T, HS)).
%% a substitution's element (0.210): a body's own token, tok(K, V, Mark), or an argument's, h(tok(K, V, Mark), HideSet),
%% whose hide set the expansion's joins
pp_body_el(tok(K, V, M), K, V, M, HS, HS).
pp_body_el(h(tok(K, V, M), AHS), K, V, M, HS, HS1) :- pp_hs_add(AHS, HS, HS1).
pp_hs_add([], HS, HS) :- !.
pp_hs_add([N|Ns], HS, HS1) :- ( memberchk(N, HS) -> HS1 = HS2 ; HS1 = [N|HS2] ), pp_hs_add(Ns, HS, HS2).   % a union, each name once: an argument through k macros would hold k(k+1)/2
%% ... pushed back for the rescan, the token after it marked where ME says so
pp_push(W, 1, Xs, Xs1) :- !, pp_mark_head(Xs, Xs2), append(W, Xs2, Xs1).
pp_push(W, _, Xs, Xs1) :- append(W, Xs, Xs1).
pp_mark_head([X|Xs], [h(T, ['$sp'|HS])|Xs]) :- pp_unwrap(X, T, HS), HS \= ['$sp'|_], !.
pp_mark_head(Xs, Xs).
pp_reline(tok(K, V, _), L, tok(K, V, L)).
%% `(' next -- on this line, or on the next text line
pp_paren_next([X|Xs], Ls, [X|Xs], Ls) :- pp_unwrap(X, tok(p, '(', _), _), !.
pp_paren_next([], Ls, Xs, Ls1) :- pp_pull(Ls, Xs, Ls1), Xs = [X|_], pp_unwrap(X, tok(p, '(', _), _).
pp_pull([line(N, A)|Ls], Toks, Ls) :- \+ pp_directive_line(A, _), pp_lex_line(N, A, Toks).
%% the arguments: balanced, split at the commas of depth one; an argument keeps its wrappers, and the commas are kept
%% apart, the last first (RSeps), for the variadic argument they join as they stood (0.209); RP the closing `)', whose
%% hide set the expansion's meets (pp_rparen_meet/3; 0.210), none where a directive or the file's end closes them
pp_collect_args([_|Xs], Ls, Args, RSeps, RP, Rest, Ls1) :- pp_args(Xs, Ls, 1, [], [], [], Args, RSeps, RP, Rest, Ls1).
pp_args([], Ls, D, Cur, Acc, SAcc, Args, RSeps, RP, Rest, Ls1) :- pp_pull(Ls, Toks, Ls0), !, pp_args(Toks, Ls0, D, Cur, Acc, SAcc, Args, RSeps, RP, Rest, Ls1).
pp_args([], Ls, _, Cur, Acc, SAcc, Args, SAcc, none, [], Ls) :- !, reverse(Cur, A), reverse([A|Acc], Args).          % a directive, or the file's end: the arguments close here
pp_args([X|Xs], Ls, D, Cur, Acc, SAcc, Args, RSeps, RP, Rest, Ls1) :-
    pp_unwrap(X, T, _),
    (   T = tok(p, '(', _) -> D1 is D + 1, pp_args(Xs, Ls, D1, [X|Cur], Acc, SAcc, Args, RSeps, RP, Rest, Ls1)
    ;   T = tok(p, ')', _), D =:= 1 -> reverse(Cur, A), reverse([A|Acc], Args), RSeps = SAcc, RP = X, Rest = Xs, Ls1 = Ls
    ;   T = tok(p, ')', _) -> D1 is D - 1, pp_args(Xs, Ls, D1, [X|Cur], Acc, SAcc, Args, RSeps, RP, Rest, Ls1)
    ;   T = tok(p, ',', _), D =:= 1 -> reverse(Cur, A), pp_args(Xs, Ls, D, [], [A|Acc], [X|SAcc], Args, RSeps, RP, Rest, Ls1)
    ;   pp_args(Xs, Ls, D, [X|Cur], Acc, SAcc, Args, RSeps, RP, Rest, Ls1) ).
%% as many arguments as parameters: `f()' for no parameter is none; the rest to the variadic one, joined by their commas
pp_fit_args([], [[]], _, []) :- !.
pp_fit_args(Ps, Args, RSeps, Args1) :-
    length(Ps, NP),
    (   append(_, [va(_)], Ps) -> NF is NP - 1, pp_split_at(NF, Args, Fixed, Va), reverse(RSeps, Seps), pp_va_seps(NF, Seps, VaSeps), pp_join_commas(Va, VaSeps, VaArg), append(Fixed, [VaArg], Args1)
    ;   Args1 = Args ).
pp_split_at(0, As, [], As) :- !.
pp_split_at(N, [A|As], [A|Fs], Va) :- !, N1 is N - 1, pp_split_at(N1, As, Fs, Va).
pp_split_at(N, [], Fs, []) :- N1 is N - 1, ( N1 >= 0 -> pp_split_at(N1, [], Fs0, _), Fs = [[]|Fs0] ; Fs = [] ).
pp_va_seps(0, Ss, Ss) :- !.
pp_va_seps(N, [_|Ss], Vs) :- !, N1 is N - 1, pp_va_seps(N1, Ss, Vs).
pp_va_seps(_, [], []).
pp_join_commas([], _, []).
pp_join_commas([A], _, A) :- !.
pp_join_commas([A|As], Ss, J) :- ( Ss = [S|Ss1] -> true ; S = tok(p, ',', 0), Ss1 = [] ), pp_join_commas(As, Ss1, J1), append(A, [S|J1], J).
%% substitution: a parameter by its argument -- expanded, unless `#' stringizes
%% it or `##' pastes it -- then the pastes
pp_subst(Body, Ps, Args, Out) :- pp_subst_(Body, Ps, Args, S0), pp_paste(S0, Out).
pp_subst_([], _, _, []).
pp_subst_([tok(p, '#', L), tok(K, P, _)|Bs], Ps, Args, [tok(str, Cs, L)|Out]) :- ( K == id ; K == kw ), pp_param(P, Ps, Args, Arg), !, pp_stringize(Arg, Cs), pp_subst_(Bs, Ps, Args, Out).
%% C++20's and C23's `#__VA_OPT__(tokens)' (0.209): the group substituted and pasted, stringized; "" where the variadic
%% argument has no token (clang and gcc)
pp_subst_([tok(p, '#', L), tok(id, '__VA_OPT__', _), tok(p, '(', _)|Bs], Ps, Args, [tok(str, Cs, L)|Out]) :- memberchk(va(VP), Ps), pp_va_group(Bs, 1, [], G, Rest), !,
    (   pp_param(VP, Ps, Args, Arg), pp_va_present(Arg) -> pp_subst_(G, Ps, Args, G1), pp_paste(G1, G2), pp_wrap(G2, 0, [], 0, W, _), pp_stringize(W, Cs)
    ;   Cs = [] ),
    nb_setval('$pp_paste', no), pp_subst_(Rest, Ps, Args, Out).
%% C23's and C++20's `__VA_OPT__(tokens)': the group substituted where the variadic argument has tokens, a
%% placemarker where it has none ([cpp.subst]) -- `#define LOG(f, ...) printf(f __VA_OPT__(,) __VA_ARGS__)'; the
%% group's first token takes the mark of white space before `__VA_OPT__', and an empty group passes it on (0.209, clang's);
%% the variadic argument's tokens are those of its expansion (0.210: `F(EMP)' with EMP empty is `f(0)', the standards'
%% example, where the argument as written gave `f(0 , )')
pp_subst_([tok(id, '__VA_OPT__', VL), tok(p, '(', _)|Bs], Ps, Args, Out) :- memberchk(va(VP), Ps), pp_va_group(Bs, 1, [], G, Rest), !,
    ( pp_last_was_paste -> PB = yes ; PB = no ),
    (   pp_param(VP, Ps, Args, Arg), pp_va_present(Arg) -> pp_subst_(G, Ps, Args, GOut0), pp_mark_first(GOut0, VL, GOut), ( GOut == [] -> pp_none_mark(VL, PB, Rest, E), Out = [E|Out1] ; append(GOut, Out1, Out) )
    ;   pp_none_mark(VL, PB, Rest, E), Out = [E|Out1] ),
    nb_setval('$pp_paste', no), pp_subst_(Rest, Ps, Args, Out1).
%% a parameter: its argument's tokens, the first with the parameter's mark of white space and each other with its own;
%% an empty one expanded leaves its mark for the next token, spmark (0.209: `G(a,)' over `S(x y+)' is "a +")
pp_subst_([tok(K, P, L)|Bs], Ps, Args, Out) :- ( K == id ; K == kw ), pp_param(P, Ps, Args, Arg), !,
    (   ( Bs = [tok(p, '##', _)|_] ; pp_last_was_paste ) -> pp_reline_marks(Arg, L, Ins),
        ( Ins == [], memberchk(va(P), Ps) -> Out = [vamarker|Out1] ; Ins == [] -> Out = [placemarker|Out1] ; append(Ins, Out1, Out) )
    ;   pp_expand_marked(Arg, Exp), pp_reline_marks(Exp, L, Ins), ( Ins == [], L == 1 -> Out = [spmark|Out1] ; append(Ins, Out1, Out) ) ),
    nb_setval('$pp_paste', no), pp_subst_(Bs, Ps, Args, Out1).
pp_subst_([tok(p, '##', L)|Bs], Ps, Args, [tok(p, '##', L)|Out]) :- !, nb_setval('$pp_paste', yes), pp_subst_(Bs, Ps, Args, Out).
pp_subst_([T|Bs], Ps, Args, [T|Out]) :- nb_setval('$pp_paste', no), pp_subst_(Bs, Ps, Args, Out).
pp_mark_first([tok(K, V, _)|Ts], 1, [tok(K, V, 1)|Ts]) :- !.
pp_mark_first([h(tok(K, V, _), AHS)|Ts], 1, [h(tok(K, V, 1), AHS)|Ts]) :- !.
pp_mark_first(Ts, _, Ts).
pp_none_mark(1, no, Rest, spmark) :- \+ Rest = [tok(p, '##', _)|_], !.
pp_none_mark(_, _, _, placemarker).
pp_va_present(Arg) :- pp_strip(Arg, Raw), Raw \== [], ( member(tok(K, _, _), Raw), ( K == id ; K == kw ) -> pp_expand_all(Arg, E), E \== [] ; true ).
pp_va_group([tok(p, ')', _)|Ts], 1, Acc, G, Ts) :- !, reverse(Acc, G).
pp_va_group([tok(p, ')', L)|Ts], D, Acc, G, Rest) :- !, D1 is D - 1, pp_va_group(Ts, D1, [tok(p, ')', L)|Acc], G, Rest).
pp_va_group([tok(p, '(', L)|Ts], D, Acc, G, Rest) :- !, D1 is D + 1, pp_va_group(Ts, D1, [tok(p, '(', L)|Acc], G, Rest).
pp_va_group([T|Ts], D, Acc, G, Rest) :- pp_va_group(Ts, D, [T|Acc], G, Rest).
pp_last_was_paste :- nb_getval('$pp_paste', yes).
pp_param(P, Ps, Args, Arg) :- Ps \== obj, pp_param_index(Ps, P, 0, I), nth0(I, Args, Arg).
pp_param_index([va(P)|_], P, I, I) :- !.
pp_param_index([P|_], P, I, I) :- !.
pp_param_index([_|Ps], P, I0, I) :- I1 is I0 + 1, pp_param_index(Ps, P, I1, I).
pp_reline_all([], _, []).
pp_reline_all([T|Ts], L, [T1|Ts1]) :- pp_reline(T, L, T1), pp_reline_all(Ts, L, Ts1).
%% AN ARGUMENT'S TOKENS IN A BODY'S FORM, h(tok(K, V, Mark), HideSet) (0.209, 0.210): the mark in the line, as a body's
%% own token has it (pp_lex_mbody/2), the first the parameter's M; the hide set the token's own, which the expansion's
%% joins (pp_wrap/6), so a name that its own expansion left unexpanded stays so (C17 6.10.3.4/2: `id(obj)' over `#define
%% obj obj+1' was `obj+1+1'); and a `##' that an argument brings is no operator to pp_paste/2 (C17 6.10.3.3/3: `# ## #'
%% through two arguments)
pp_reline_marks([], _, []).
pp_reline_marks([X|Xs], M, [h(tok(K, V, M), AHS)|Ts]) :- pp_unwrap(X, tok(K, V, _), HS), pp_mark_of(HS, _, AHS), pp_reline_marks_(Xs, Ts).
pp_reline_marks_([], []).
pp_reline_marks_([X|Xs], [h(tok(K, V, B), AHS)|Ts]) :- pp_unwrap(X, tok(K, V, _), HS), pp_mark_of(HS, B, AHS), pp_reline_marks_(Xs, Ts).
%% a token list of its own, expanded whole (an argument, an #if line); for a substitution, its marks kept (0.209)
pp_expand_all(Toks, Out) :- pp_toks(top, Toks, [], _, Out0, []), pp_strip(Out0, Out).
pp_expand_marked(Toks, Out) :- pp_toks(marks, Toks, [], _, Out, []).
%% `##': the two sides spelled together and read as one token (or as they come)
pp_paste([], []).
pp_paste([tok(p, ',', _), tok(p, '##', _), vamarker|Ts], Out) :- !, pp_paste(Ts, Out).     % GNU's `, ## __VA_ARGS__' with none: the comma goes
pp_paste([A, tok(p, '##', _), B|Ts], Out) :- !, pp_paste_two(A, B, AB), append(AB, Ts, Ts1), pp_paste(Ts1, Out).
pp_paste([placemarker|Ts], Out) :- !, pp_paste(Ts, Out).
pp_paste([vamarker|Ts], Out) :- !, pp_paste(Ts, Out).
pp_paste([T|Ts], [T|Out]) :- pp_paste(Ts, Out).
pp_paste_two(placemarker, B, [B]) :- !.
pp_paste_two(A, placemarker, [A]) :- !.
pp_paste_two(vamarker, B, [B]) :- !.
pp_paste_two(A, vamarker, [A]) :- !.
pp_paste_two(A, B, Toks) :- pp_body_el(A, KA, VA, MA, [], HA), pp_body_el(B, KB, VB, _, [], HB), pp_spell(tok(KA, VA, 0), Ca), pp_spell(tok(KB, VB, 0), Cb), append(Ca, Cb, C), pp_lex_body(C, T0),
    ( T0 = [_|_] -> pp_reline_all(T0, MA, T1), pp_hs_meet(HA, HB, H), pp_glued(H, T1, Toks) ; Toks = [A, B] ).
%% ... the pasted token hidden from what both sides are hidden from (Prosser's glue; 0.210)
pp_glued([], Ts, Ts) :- !.
pp_glued(H, [T|Ts], [h(T, H)|Ws]) :- pp_glued(H, Ts, Ws).
pp_glued(_, [], []).
%% `#x': the argument spelled, a space where white space stood between two of its tokens, none before the first or after
%% the last (C17 6.10.3.2/2; 0.209: it was a space between every two)
pp_stringize(Arg, Cs) :- pp_spell_marked(Arg, Cs1), pp_utf8_bytes(Cs1, Cs0), ( member(X, Arg), pp_unwrap(X, tok(other, 92, _), _) -> pp_str_decode(Arg, Cs0, Cs) ; Cs = Cs0 ).
%% ... in bytes, a string's value, the spelling in characters (0.211: `S(caf\u00e9)' gave the byte 0xE9 for its `\u00e9')
pp_utf8_bytes([], []).
pp_utf8_bytes([C|Cs], Bs) :- ( C < 128 -> Bs = [C|Bs1] ; ccl_utf8(C, Bs, Bs1) ), pp_utf8_bytes(Cs, Bs1).
%% ... the string's value is that spelling, a literal's quote and `\' escaped only to be read back; a `\' of no literal
%% begins an escape of the string made (0.210: the standard's `str(: @\n)' is ": @" and a new-line), so the spelling is
%% escaped where it is a literal's and read as a string's body
pp_str_decode(Arg, Cs0, Cs) :- pp_spell_esc(Arg, E), append([34|E], [34], Q), atom_codes(A, Q), nb_getval('$ccl_hash', M), nb_setval('$ccl_hash', line),
    ( catch(ccl_lex_atom(A, 0, [tok(str, Cs1, _)], []), _, fail) -> Cs = Cs1 ; Cs = Cs0 ), nb_setval('$ccl_hash', M).
pp_spell_esc([], []).
pp_spell_esc([X|Xs], Cs) :- pp_unwrap(X, T, _), pp_spell(T, C0), ( pp_lit_kind(T) -> pp_escape(C0, 34, raw, C1) ; C1 = C0 ), pp_spell_esc(Xs, C2),
    ( Xs = [X1|_], pp_unwrap(X1, _, ['$sp'|_]) -> append(C1, [0' |C2], Cs) ; append(C1, C2, Cs) ).
pp_lit_kind(tok(K, _, _)) :- ( K == lit ; K == str ; K == chr ; pp_str_prefix(K, _) ; pp_chr_prefix(K, _) ), !.
pp_spell_marked([], []).
pp_spell_marked([X|Xs], Cs) :- pp_unwrap(X, T, _), pp_spell(T, C1), pp_spell_marked_(Xs, C2), append(C1, C2, Cs).
pp_spell_marked_([], []).
pp_spell_marked_([X|Xs], Cs) :- pp_unwrap(X, T, HS), pp_spell(T, C1), pp_spell_marked_(Xs, C2), ( HS = ['$sp'|_] -> Cs = [0' |Cs1] ; Cs = Cs1 ), append(C1, C2, Cs1).
pp_spell_all([], []).
pp_spell_all([T], Cs) :- !, pp_spell(T, Cs).
pp_spell_all([T|Ts], Cs) :- pp_spell(T, C1), pp_spell_all(Ts, C2), append(C1, [0' |C2], Cs).
pp_spell(tok(id, N, _), Cs) :- !, atom_codes(N, Cs).
pp_spell(tok(kw, N, _), Cs) :- !, atom_codes(N, Cs).
pp_spell(tok(num, Cs, _), Cs) :- !.
pp_spell(tok(int, N, _), Cs) :- !, pp_int_codes(N, Cs).
pp_spell(tok(float, N, _), Cs) :- !, pp_float_codes(N, Cs).
pp_spell(tok(floatf, N, _), Cs) :- !, pp_float_codes(N, Cs0), append(Cs0, [0'f], Cs).     % `1.5f' and `1.5L' spelled with their suffixes (0.108)
pp_spell(tok(floatl, A, _), Cs) :- !, atom_codes(A, Cs0), append(Cs0, [0'L], Cs).          % a long double literal: its text (0.154)
pp_spell(tok(floatudl, fs(A, S), _), Cs) :- !, atom_codes(A, C1), atom_codes(S, C2), append(C1, C2, Cs).   % a user-defined floating literal: its text and its suffix, no space between (0.160)
pp_spell(tok(K, A, _), Cs) :- pp_dec_suffix(K, Sfx), !, atom_codes(A, Cs0), append(Cs0, Sfx, Cs).   % a decimal literal: its text and its suffix (0.129)
pp_spell(tok(imag, N, _), Cs) :- !, number_codes(N, Cs0), append(Cs0, [0'i], Cs).
pp_spell(tok(imagf, N, _), Cs) :- !, number_codes(N, Cs0), append(Cs0, [0'i, 0'f], Cs).
pp_spell(tok(imagl, A, _), Cs) :- !, atom_codes(A, Cs0), append(Cs0, [0'i, 0'l], Cs).
pp_spell(tok(K, N, _), Cs) :- pp_imag_suffix(K, Sfx), !, pp_int_codes(N, Cs0), append(Cs0, Sfx, Cs).   % `3i', `2ui', `3li', `4uli' (0.104)
pp_spell(tok(str, S, _), Cs) :- !, pp_escape(S, 34, raw, E), append([34|E], [34], Cs).
pp_spell(tok(chr, C, _), Cs) :- !, pp_escape([C], 39, raw, E), append([39|E], [39], Cs).
pp_spell(tok(K, S, _), Cs) :- pp_str_prefix(K, P), !, pp_lit_x(K, X), pp_escape(S, 34, X, E), append(P, [34|E], Cs0), append(Cs0, [34], Cs).   % L"...", u"...", U"..." (0.93: the prefixed literals)
pp_spell(tok(K, C, _), Cs) :- pp_chr_prefix(K, P), !, pp_lit_x(K, X), pp_escape([C], 39, X, E), append(P, [39|E], Cs0), append(Cs0, [39], Cs).
pp_spell(tok(p, P, _), Cs) :- !, atom_codes(P, Cs).
pp_spell(tok(other, C, _), [C]) :- !.   % a character that begins no token (0.210)
pp_spell(tok(_, V, _), Cs) :- ( atom(V) -> atom_codes(V, Cs) ; number(V) -> number_codes(V, Cs) ; Cs = [] ).
pp_spell(_, []).
pp_dec_suffix(dec32, [0'd, 0'f]).  pp_dec_suffix(dec64, [0'd, 0'd]).  pp_dec_suffix(dec128, [0'd, 0'l]).
pp_imag_suffix(imagi, [0'i]).   pp_imag_suffix(imagui, [0'u, 0'i]).   pp_imag_suffix(imagli, [0'l, 0'i]).   pp_imag_suffix(imaguli, [0'u, 0'l, 0'i]).
pp_imag_suffix(imaglli, [0'l, 0'l, 0'i]).   pp_imag_suffix(imagulli, [0'u, 0'l, 0'l, 0'i]).   % (0.179)
pp_str_prefix(wstr, [0'L]).    pp_str_prefix(u16str, [0'u]).    pp_str_prefix(u32str, [0'U]).    pp_str_prefix(u8str, [0'u, 0'8]).   % u8 (0.196)
pp_chr_prefix(wchr, [0'L]).    pp_chr_prefix(u16chr, [0'u]).    pp_chr_prefix(u32chr, [0'U]).    pp_chr_prefix(u8chr, [0'u, 0'8]).
pp_lit_x(K, wide) :- memberchk(K, [wstr, u16str, u32str, wchr, u16chr, u32chr]), !.
pp_lit_x(_, raw).
%% A LITERAL'S CHARACTERS SPELLED (0.209), one way for `#x', `##', a directive's text and -E's: the quote Q and `\'
%% escaped, a control character by its name or three octal digits, and past ASCII (X) raw for a token's own text -- a
%% narrow literal's bytes as they are, a wide one's code point (wide) in UTF-8 -- or esc for -E's file, three octal digits
%% below 256 and \u{...} above. An escape `\x41' is spelled `A', its value. `#x' escaped a second time the text this
%% escapes (`S("x y")' printed \"x y\"), and pp_spell/2 left a tab, a character constant and a control character raw
pp_escape([], _, _, []).
pp_escape([C|Cs], Q, X, Es) :- pp_escape_utf8(C, X, Cs, U, Cs1), !, Es = [U|Es1], pp_escape(Cs1, Q, X, Es1).
pp_escape([C|Cs], Q, X, Es) :- pp_escape_c(C, Q, X, Cs, Es, Es1), pp_escape(Cs, Q, X, Es1).
%% a narrow literal's bytes are spelled in characters (0.211): a UTF-8 sequence its character, a byte of none three octal
%% digits below (pp_escape_c/6), so `#x' and `##' read the spelling as the characters they are
pp_escape_utf8(C, raw, Cs, U, Cs1) :- C >= 0xC2, C =< 0xF4, ( C < 0xE0 -> N = 1, U0 is C /\ 0x1F ; C < 0xF0 -> N = 2, U0 is C /\ 0x0F ; N = 3, U0 is C /\ 0x07 ), pp_utf8_tail(N, Cs, U0, U, Cs1), U >= 0x80.
pp_utf8_tail(0, Cs, U, U, Cs) :- !.
pp_utf8_tail(N, [B|Cs], U0, U, Cs1) :- B >= 0x80, B =< 0xBF, U1 is (U0 << 6) \/ (B /\ 0x3F), N1 is N - 1, pp_utf8_tail(N1, Cs, U1, U, Cs1).
pp_escape_c(Q, Q, _, _, [92, Q|R], R) :- !.
pp_escape_c(92, _, _, _, [92, 92|R], R) :- !.
pp_escape_c(C, _, _, _, [92, N|R], R) :- pp_named_escape(C, N), !.
pp_escape_c(0, _, _, Cs, [92, 0'0|R], R) :- \+ ( Cs = [D|_], D >= 0'0, D =< 0'7 ), !.
pp_escape_c(C, _, X, _, [92, O1, O2, O3|R], R) :- ( C < 32 ; C =:= 127 ; X \== wide, C >= 128, C < 256 ), !, O1 is 0'0 + C // 64, O2 is 0'0 + (C // 8) mod 8, O3 is 0'0 + C mod 8.   % \NNN: three octal digits, which no digit after can extend
pp_escape_c(C, _, esc, _, Out, R) :- C >= 256, !, atom_codes('\\u{', H), ccl_pp_hexn(C, Hs), append(H, Hs, O1), append(O1, [125|R], Out).                     % a code point: \u{...}
pp_escape_c(C, _, _, _, [C|R], R).
pp_named_escape(10, 0'n).   pp_named_escape(9, 0't).   pp_named_escape(13, 0'r).   pp_named_escape(7, 0'a).
pp_named_escape(8, 0'b).   pp_named_escape(12, 0'f).   pp_named_escape(11, 0'v).
%% the output: bare tokens, a number from a macro body read as the reader has it
pp_finish(Out, Tokens) :- pp_finish_(Out, Tokens, []).
pp_finish_([], T, T).
pp_finish_([pp_out(K)|Xs], T0, T) :- !, nb_getval(K, Sub), nb_setval(K, none), pp_finish_(Sub, T0, T1), pp_finish_(Xs, T1, T).   % a file's output, spliced (its global freed of it)
pp_finish_([X|Xs], Out, Tail) :- pp_unwrap(X, T0, _), pp_norm_toks(T0, Ts), append(Ts, Mid, Out), pp_finish_(Xs, Mid, Tail).
%% A USER-DEFINED LITERAL is a pp-number with its suffix in it, `5_km' or `1500ms' (0.117): the lexer cuts it in two, the number
%% and the suffix's identifier, which the reader reads as one literal (ccl_udl). It was `tok(int, 0)' -- the lexer's answer was not
%% ONE token -- and every user-defined literal read as zero.
pp_norm_toks(tok(num, Cs, L), Ts) :- \+ pp_plain_int(Cs), nb_getval('$ccl_hash', M), nb_setval('$ccl_hash', line), atom_codes(A, Cs),
    ( ccl_lex_atom(A, 0, Ts0, []), Ts0 = [_, _|_] -> pp_relined(Ts0, L, Ts), nb_setval('$ccl_hash', M) ; nb_setval('$ccl_hash', M), fail ), !.
pp_norm_toks(T0, [T]) :- pp_norm(T0, T).
pp_relined([], _, []).
pp_relined([tok(K, V, _)|Ts], L, [tok(K, V, L)|Us]) :- pp_relined(Ts, L, Us).
pp_norm(tok(num, Cs, L), tok(int, V, L)) :- pp_plain_int(Cs), !, ccl_int_value(Cs, V).   % ... through the reader's one door, so a literal past 2^60 is big(Atom) here too (0.94)   % a plain decimal, most of them: no lexer run
pp_norm(tok(num, Cs, L), T) :- !, nb_getval('$ccl_hash', M), nb_setval('$ccl_hash', line), atom_codes(A, Cs), ( ccl_lex_atom(A, 0, [tok(K, V, _)], []) -> T0 = tok(K, V, L) ; T0 = tok(int, 0, L) ), nb_setval('$ccl_hash', M), T = T0.   % the mode restored before the answer meets the caller's (0.201)
%% A TOKEN SPELLED AS WRITTEN (0.211; the lexers' ccl_pp_spelled/4): the reader's token from its spelling -- a literal read
%% again in the reader's mode, a digraph and an alternative token their punctuator
pp_norm(tok(lit, A, L), T) :- !, nb_getval('$ccl_hash', M), nb_setval('$ccl_hash', line), ( ccl_lex_atom(A, 0, [tok(K, V, _)], []) -> T0 = tok(K, V, L) ; T0 = tok(str, [], L) ), nb_setval('$ccl_hash', M), T = T0.
pp_norm(tok(dg, A, L), tok(p, P, L)) :- !, pp_digraph(A, P).
pp_norm(tok(alt, A, L), tok(p, P, L)) :- !, ccl_alt_token(A, P).
pp_norm(T, T).
pp_digraph('<:', '[').   pp_digraph(':>', ']').   pp_digraph('<%', '{').   pp_digraph('%>', '}').   pp_digraph('%:', '#').   pp_digraph('%:%:', '##').
pp_norm_all([], []).
pp_norm_all([T|Ts], [U|Us]) :- pp_norm(T, U), pp_norm_all(Ts, Us).

%% ---- directives -------------------------------------------------------------
pp_directive(Body, L, Ls, Ls1, Out0, Out) :-
    pp_ws(Body, B1), pp_word(B1, W, Rest), atom_codes(D, W),
    pp_directive_(D, Rest, Body, L, Ls, Ls1, Out0, Out).
pp_directive_(define, Rest, Body, L, Ls, Ls, Out0, Out) :- !, ( pp_do_define(Rest) -> true ; true ), ( pp_mt_on -> pp_mt_define(Rest, L) ; true ), pp_ftm_note(Rest), pp_pass(Body, L, Out0, Out).
pp_directive_(undef, Rest, Body, L, Ls, Ls, Out0, Out) :- !, pp_ws(Rest, R1), pp_word(R1, W, _), atom_codes(N, W), pp_undefine(N), ( pp_mt_on -> pp_mt_note(undef(L, N)) ; true ), pp_ftm_note(Rest), pp_pass(Body, L, Out0, Out).
pp_directive_(include, Rest, Body, L, Ls, Ls, Out0, Out) :- !, pp_do_include(Rest, plain, Body, L, Out0, Out).
pp_directive_(include_next, Rest, Body, L, Ls, Ls, Out0, Out) :- !, pp_do_include(Rest, next, Body, L, Out0, Out).
pp_directive_(cocolog, _, _, L, Ls, Ls1, Out0, Out) :- nb_getval('$pp_top', yes), !, pp_cocolog_block(Ls, L, Ls1, Out0, Out).
pp_directive_(if, Rest, _, _, Ls, Ls1, Out, Out) :- !, pp_lex_body(Rest, Ts), ( pp_eval(Ts) -> Ls1 = Ls ; pp_skip_false(Ls, Ls1) ).
pp_directive_(ifdef, Rest, _, _, Ls, Ls1, Out, Out) :- !, pp_ws(Rest, R1), pp_word(R1, W, _), atom_codes(N, W), ( pp_defined(N) -> Ls1 = Ls ; pp_skip_false(Ls, Ls1) ).
pp_directive_(ifndef, Rest, _, _, Ls, Ls1, Out, Out) :- !, pp_ws(Rest, R1), pp_word(R1, W, _), atom_codes(N, W), ( pp_defined(N) -> pp_skip_false(Ls, Ls1) ; Ls1 = Ls ).
pp_directive_(elif, _, _, _, Ls, Ls1, Out, Out) :- !, pp_skip_to_endif(Ls, Ls1).          % a taken group ended: the branches left go
pp_directive_(elifdef, _, _, _, Ls, Ls1, Out, Out) :- !, pp_skip_to_endif(Ls, Ls1).       % C++23 (and C23): #elifdef X, #elifndef X
pp_directive_(elifndef, _, _, _, Ls, Ls1, Out, Out) :- !, pp_skip_to_endif(Ls, Ls1).
pp_directive_(else, _, _, _, Ls, Ls1, Out, Out) :- !, pp_skip_to_endif(Ls, Ls1).
pp_directive_(endif, _, _, _, Ls, Ls, Out, Out) :- !.
pp_directive_(pragma, Rest, _, _, Ls, Ls, Out, Out) :- !, pp_ws(Rest, R1), pp_word(R1, W, _), ( atom_codes(once, W) -> pp_current_file(F), nb_getval('$pp_once', O), nb_setval('$pp_once', [F|O]) ; true ).
%% IN THE USER'S FILE `#error' IS A DIAGNOSTIC (before, it was listed in '$pp_errors' and nobody read the list, so a
%% program's own #error compiled to `cicilang: ok') and `#warning' is printed after the read, `file:line: warning: ...',
%% by the driver (dr_pp_warnings); in a header both stay what they were, the file stopping at an #error (libc++'s
%% other branch), a warning nothing.
pp_directive_(error, Rest, _, L, _, [], Out, Out) :- nb_getval('$pp_top', yes), !, pp_ws(Rest, R1), atom_codes(M, R1), throw(pp_error(L, M)).
pp_directive_(warning, Rest, _, L, Ls, Ls, Out, Out) :- nb_getval('$pp_top', yes), !, pp_current_file(F), pp_ws(Rest, R1), atom_codes(M, R1), nb_getval('$pp_warnings', Ws), nb_setval('$pp_warnings', [warning(F, L, M)|Ws]).
pp_directive_(embed, Rest, Body, L, Ls, Ls, Out0, Out) :- !, pp_do_embed(Rest, Body, L, Out0, Out).
pp_directive_(line, Rest, _, L, Ls, Ls, Out, Out) :- !, pp_do_line(Rest, L).
pp_directive_(D, Rest, _, L, Ls, Ls, Out, Out) :- atom_codes(D, [C|Cs]), C >= 0'0, C =< 0'9, !, pp_do_line([C|Cs], Rest, L).   % GNU's linemarker, `# 12 "f.c" 1'
pp_directive_(error, Rest, _, L, _, [], Out, Out) :- !, pp_current_file(F), atom_codes(M, Rest), nb_getval('$pp_errors', Es), nb_setval('$pp_errors', [error(F, L, M)|Es]).   % the file stops here
pp_directive_(_, _, _, _, Ls, Ls, Out, Out).                                       % line, warning, ident, an empty #: nothing
%% in the user's file a directive is kept as the token the reader has always read
pp_pass(Body, L, Out0, Out) :- ( nb_getval('$pp_top', yes) -> atom_codes(Text, [35|Body]), Out0 = [tok(pp, Text, L)|Out] ; Out0 = Out ).
%% #cocolog ... #end in the user's file: the raw lines between, one token
pp_cocolog_block(Ls, L, Ls1, [tok(cocolog, Text, L)|Out], Out) :-
    pp_block_end(Ls, L, EndN, Ls1), pp_current_file(F), pp_raw_lines(F, Raw), From is L + 1, To is EndN - 1,
    pp_raw_slice(Raw, 1, From, To, Cs), atom_codes(Text, Cs).
pp_block_end([], L, E, []) :- E is L + 1000000.
pp_block_end([line(N, A)|Ls], L, EndN, Ls1) :-
    (   pp_directive_line(A, Body), pp_ws(Body, B1), pp_word(B1, W, _), atom_codes(end, W) -> EndN = N, Ls1 = Ls
    ;   pp_block_end(Ls, L, EndN, Ls1) ).
pp_raw_lines(F, Raw) :- read_file_to_codes(F, Codes), atom_codes(A, Codes), atomic_list_concat(Raw, '\n', A).
pp_raw_slice([], _, _, _, []).
pp_raw_slice([R|Rs], N, From, To, Cs) :-
    N1 is N + 1,
    (   N >= From, N =< To -> atom_codes(R, C1), append(C1, [10|C2], Cs), pp_raw_slice(Rs, N1, From, To, C2)
    ;   N > To -> Cs = []
    ;   pp_raw_slice(Rs, N1, From, To, Cs) ).
pp_do_line(Rest, L) :- pp_lex_body(Rest, Ts), pp_expand_all(Ts, Es), pp_spell_all(Es, Cs), pp_ws(Cs, C1), pp_word(C1, W, R), pp_do_line(W, R, L).
pp_do_line(W, R, L) :- W \== [], number_codes(N, W), pp_current_file(F0), nb_getval('$pp_linemap', M0),
    ( memberchk(F0-lm(_, FOld), M0) -> true ; FOld = F0 ),
    pp_ws(R, R1), ( R1 = [34|R2], append(NCs, [34|_], R2) -> atom_codes(FN, NCs) ; FN = FOld ),
    D is N - (L + 1), ( select(F0-_, M0, M1) -> true ; M1 = M0 ), nb_setval('$pp_linemap', [F0-lm(D, FN)|M1]), !.
pp_do_line(_, _, _).
pp_ws([C|Cs], R) :- ( C =:= 32 ; C =:= 9 ), !, pp_ws(Cs, R).
pp_ws(Cs, Cs).
%% A UNIVERSAL CHARACTER NAME IN A MACRO'S NAME is the character it names (C17 6.4.3, 6.4.2.1; 0.213), as the lexers read
%% one in an identifier (ccl_ucn//1): `#define caf\u00e9 1' named `caf' and was `café' nowhere
pp_word([92|Cs0], [U|W], R) :- phrase(ccl_ucn(U), Cs0, Cs), U >= 128, pp_wide_id(U), !, pp_word(Cs, W, R).
pp_word([C|Cs], [C|W], R) :- ( C >= 0'a, C =< 0'z ; C >= 0'A, C =< 0'Z ; C =:= 0'_ ; C >= 0'0, C =< 0'9 ; C =:= 0'$ ), !, pp_word(Cs, W, R).   % with `$' (0.210)
pp_word([C|Cs], [C|W], R) :- C >= 128, pp_wide_id(C), !, pp_word(Cs, W, R).   % a macro's name past ASCII (0.196), as the lexers take it at the level (0.221)
pp_word(Cs, [], Cs).
pp_wide_id(C) :- ( ccl_text_chars -> ccl_id_cp(more, C) ; true ).   % read in bytes, a byte past ASCII as before
%% #define NAME body | #define NAME(params) body -- function-like when `(' follows the name at once
pp_do_define(Rest) :-
    pp_ws(Rest, R1), pp_word(R1, W, R2), W \== [], atom_codes(N, W),
    (   R2 = [0'(|R3] -> pp_upto_close(R3, PCs, R4), pp_param_names(PCs, Ps), pp_define(N, Ps, R4)
    ;   pp_define(N, obj, R2) ).
pp_upto_close([0')|R], [], R) :- !.
pp_upto_close([C|Cs], [C|Ps], R) :- pp_upto_close(Cs, Ps, R).
pp_upto_close([], [], []).
pp_param_names(Cs, Ps) :- ccl_split(Cs, 0',, Parts), pp_param_names_(Parts, Ps).
pp_param_names_([], []).
pp_param_names_([P|Ps], Names) :-
    pp_ws(P, P1), pp_word(P1, W, R), pp_ws(R, R1), pp_param_names_(Ps, Ns),
    (   W == [], R1 = [0'., 0'., 0'.|_] -> Names = [va('__VA_ARGS__')|Ns]
    ;   W == [] -> Names = Ns
    ;   R1 = [0'., 0'., 0'.|_] -> atom_codes(A, W), Names = [va(A)|Ns]
    ;   atom_codes(A, W), Names = [A|Ns] ).
%% #include: the name as written, or through the macros; resolved on the
%% reader's path from the including file; once per #pragma once; a `.pl'
%% is a macro file, the reader's own: the directive is passed on as a token
pp_do_include(Rest, How, Body, L, Out0, Out) :-
    pp_ws(Rest, R1),
    (   pp_inc_name(R1, Spec0) -> Cmp = no
    ;   pp_computed_codes(R1, ECs), pp_inc_name(ECs, Spec0), Cmp = yes ),
    !,
    ( How == next -> Spec = next(Spec0) ; Spec = Spec0 ),
    pp_current_file(From),
    ( nb_getval('$pp_top', yes), pp_spec_system(Spec) -> pp_ftm_at_include(Spec) ; true ),   % the program's configuration at each system #include (0.214, 0.215)
    (   ccl_resolve_include(Spec, From, Path)
    ->  (   sub_atom(Path, _, 3, 0, '.pl') -> pp_inc_text(Cmp, Spec, Body, Text), Out0 = [tok(pp, Text, L)|Out]
        ;   nb_getval('$pp_top', yes) -> pp_inc_text(Cmp, Spec, Body, Text), Out0 = [tok(pp, Text, L)|Out],
                                        (   ccl_header_macros_known(Path, _) -> nb_getval('$pp_hdrs', Hs), nb_setval('$pp_hdrs', [Path|Hs]), nb_getval('$pp_ninc', I0), I1 is I0 + 1, nb_setval('$pp_ninc', I1), pp_assert_include(Spec)
                                        ;   Cmp == yes -> nb_getval('$pp_late', Lt), nb_setval('$pp_late', [Spec|Lt])
                                        ;   true )
        ;   nb_getval('$pp_once', O), memberchk(Path, O) -> Out0 = Out
        ;   nb_setval('$pp_mt_line', L), pp_include_file(Path, Out0, Out) )
    ;   nb_getval('$pp_top', yes) -> pp_inc_text(Cmp, Spec, Body, Text), Out0 = [tok(pp, Text, L)|Out]      % nowhere: the reader says `missing'
    ;   Out0 = Out ).
pp_do_include(_, _, _, _, Out, Out).
pp_spec_system(system(_)).
pp_spec_system(next(_)).
%% <assert.h> DEFINES assert BY NDEBUG AS IT STANDS AT EACH INCLUSION (C17 7.2/1, [cassert]; 0.214): in the user's file an
%% #include of <assert.h> or <cassert> defines assert as ((void)0) where NDEBUG is defined, and glibc's assert_perror
%% with it, else as the header's table has it, which is read with no NDEBUG. The table alone answered, and
%% `#define NDEBUG' before the include still asserted. An inclusion through another header asks no NDEBUG
pp_assert_include(system(H)) :- memberchk(H, ['assert.h', cassert]), !,
    (   pp_defined('NDEBUG') -> atom_codes('((void)0)', Cs), pp_define(assert, [expr], Cs), ( pp_header_macro(assert_perror, _, _) -> pp_define(assert_perror, [errnum], Cs) ; true )
    ;   pp_header_macro(assert, Ps, Cs) -> pp_define(assert, Ps, Cs), ( pp_header_macro(assert_perror, Ps2, Cs2) -> pp_define(assert_perror, Ps2, Cs2) ; true )
    ;   true ).
pp_assert_include(_).
%% the directive passed on to the reader: as written, or a computed one with the name it resolved to (0.211: the reader
%% read no name from `#include INC', and the header's declarations were lost with its macros)
pp_inc_text(no, _, Body, Text) :- !, atom_codes(Text, [35|Body]).
pp_inc_text(yes, Spec, _, Text) :- ccl_spec_text(Spec, ST), ( Spec = next(_) -> D = '#include_next ' ; D = '#include ' ), atom_concat(D, ST, Text).
%% A COMPUTED NAME (C17 6.10.2/4): the operand macro-replaced and spelled, a space only where white space stood, as clang
%% and gcc join `<' NAME `>' (0.211: a space between every two tokens, and `#define SYS <stdint.h>' named ` stdint . h ')
pp_computed_codes(R1, ECs) :- atom_codes(A, R1), ( ccl_lex_atom_marked(A, 0, Ts, _) -> true ; Ts = [] ), pp_expand_marked(Ts, Es), pp_spell_marked(Es, ECs).
%% C23's (and C++26's) `#embed "file" [limit(N)] [prefix(toks)] [suffix(toks)] [if_empty(toks)]': the resource's bytes
%% as a comma-separated list of integers where the directive stood -- in the user's file and in a header alike, since
%% the bytes ARE the meaning and the reader has no node for one. The name resolves as an #include's does (a quoted
%% name beside the including file, an angled one on the inclusion path); a resource nowhere is a diagnostic. A file
%% is read as codes, a code past 255 spelled back into its UTF-8 bytes, so a text resource embeds as its bytes.
pp_do_embed(Rest, _, L, Out0, Out) :-
    pp_ws(Rest, R1),
    (   pp_inc_name(R1, Spec), pp_inc_rest(R1, R2) -> true
    ;   pp_computed_codes(R1, ECs), pp_inc_name(ECs, Spec), pp_inc_rest(ECs, R2) ),
    !,
    pp_current_file(From),
    (   ccl_resolve_include(Spec, From, Path) -> true ; pp_spec_name(Spec, N), atom_concat('#embed: no such resource: ', N, M), throw(pp_error(L, M)) ),
    pp_lex_body(R2, PTs), pp_embed_params(PTs, Params),
    read_file_to_codes(Path, Codes), pp_bytes(Codes, Bytes0),
    ( memberchk(limit(K), Params) -> pp_take(K, Bytes0, Bytes) ; Bytes = Bytes0 ),
    (   Bytes == [] -> ( memberchk(if_empty(E), Params) -> Toks = E ; Toks = [] )
    ;   pp_embed_ints(Bytes, L, Ints), ( memberchk(prefix(P), Params) -> true ; P = [] ), ( memberchk(suffix(S), Params) -> true ; S = [] ),
        append(P, Ints, T0), append(T0, S, Toks) ),
    pp_reline_all(Toks, L, Toks1), append(Toks1, Out, Out0).
pp_do_embed(_, _, L, _, _) :- throw(pp_error(L, '#embed: expected "file" or <file>')).
pp_spec_name(local(N), N).  pp_spec_name(system(N), N).
pp_inc_rest([34|R], R2) :- pp_after(R, 34, R2).
pp_inc_rest([0'<|R], R2) :- pp_after(R, 0'>, R2).
pp_after([End|R], End, R) :- !.
pp_after([_|Cs], End, R) :- pp_after(Cs, End, R).
pp_after([], _, []).
pp_bytes([], []).
pp_bytes([C|Cs], Bs) :- ( C < 256 -> Bs = [C|Bs1] ; ccl_utf8(C, Bs, Bs1) ), pp_bytes(Cs, Bs1).
pp_take(0, _, []) :- !.
pp_take(_, [], []) :- !.
pp_take(N, [B|Bs], [B|Rs]) :- N1 is N - 1, pp_take(N1, Bs, Rs).
pp_embed_ints([B], L, [tok(int, B, L)]) :- !.
pp_embed_ints([B|Bs], L, [tok(int, B, L), tok(p, ',', L)|Ts]) :- pp_embed_ints(Bs, L, Ts).
pp_embed_params([], []).
pp_embed_params([tok(id, W, _), tok(p, '(', _)|Ts], [P|Ps]) :- pp_embed_word(W, K), pp_builtin_args(Ts, Args, Rest), !, pp_embed_param(K, Args, P), pp_embed_params(Rest, Ps).
pp_embed_params([_|Ts], Ps) :- pp_embed_params(Ts, Ps).
pp_embed_word(W, K) :- memberchk(W-K, [limit-limit, '__limit__'-limit, prefix-prefix, '__prefix__'-prefix, suffix-suffix, '__suffix__'-suffix, if_empty-if_empty, '__if_empty__'-if_empty]).
pp_embed_param(limit, Args, limit(N)) :- !, pp_expand_all(Args, Es), pp_normalize(Es, Ns), phrase(ccl_cond_expr(E), Ns, _), ccl_const_eval(E, N).
pp_embed_param(K, Args, P) :- P =.. [K, Args].
%% `__has_embed("file")' in an #if: found (1), empty (2), nowhere (0) -- the values __STDC_EMBED_* name
pp_has_embed(Args0, V) :- pp_has_args(Args0, Args),
    (   Args = [tok(str, S, _)|_] -> atom_codes(N, S), Spec = local(N)
    ;   pp_angle_name(Args, N) -> Spec = system(N)
    ;   fail ),
    pp_current_file(From),
    (   ccl_resolve_include(Spec, From, Path) -> ( read_file_to_codes(Path, []) -> V = 2 ; V = 1 ) ; V = 0 ).
pp_has_embed(_, 0).
pp_inc_name([34|R], local(N)) :- pp_upto(R, 34, Cs), atom_codes(N, Cs).
pp_inc_name([0'<|R], system(N)) :- pp_upto(R, 0'>, Cs), atom_codes(N, Cs).
pp_upto([End|_], End, []) :- !.
pp_upto([C|Cs], End, [C|Rs]) :- pp_upto(Cs, End, Rs).
%% a false group: past its lines to the branch that follows, and that branch's fate
pp_skip_false(Ls, Ls1) :-
    pp_skip_group(Ls, 0, Found, Rest),
    (   Found = elif(Ts) -> ( pp_eval(Ts) -> Ls1 = Rest ; pp_skip_false(Rest, Ls1) )
    ;   Ls1 = Rest ).                                                             % else, endif, or the end of the file
pp_skip_group([], _, endif, []).
pp_skip_group([line(_, A)|Ls], D, Found, Rest) :-
    (   pp_directive_line(A, Body), pp_ws(Body, B1), pp_word(B1, W, R), atom_codes(Dn, W), pp_cond_word(Dn, Kind)
    ->  (   Kind == open -> D1 is D + 1, pp_skip_group(Ls, D1, Found, Rest)
        ;   Kind == endif, D =:= 0 -> Found = endif, Rest = Ls
        ;   Kind == endif -> D1 is D - 1, pp_skip_group(Ls, D1, Found, Rest)
        ;   D =:= 0, Kind == elif -> pp_lex_body(R, Ts), Found = elif(Ts), Rest = Ls
        ;   D =:= 0, Kind == elifdef -> pp_defined_body('defined(', R, Ts), Found = elif(Ts), Rest = Ls      % C++23: as #elif defined(X)
        ;   D =:= 0, Kind == elifndef -> pp_defined_body('!defined(', R, Ts), Found = elif(Ts), Rest = Ls
        ;   D =:= 0 -> Found = else, Rest = Ls
        ;   pp_skip_group(Ls, D, Found, Rest) )
    ;   pp_skip_group(Ls, D, Found, Rest) ).
pp_cond_word(if, open). pp_cond_word(ifdef, open). pp_cond_word(ifndef, open).
pp_cond_word(elif, elif). pp_cond_word(else, else). pp_cond_word(endif, endif).
pp_cond_word(elifdef, elifdef). pp_cond_word(elifndef, elifndef).
pp_defined_body(Head, R, Ts) :- atom_codes(Head, H), pp_ws(R, R1), pp_word(R1, W, _), append(H, W, C0), append(C0, [0')], Cs), pp_lex_body(Cs, Ts).
pp_skip_to_endif(Ls, Ls1) :- pp_skip_group(Ls, 0, Found, Rest), ( Found = elif(_) -> pp_skip_to_endif(Rest, Ls1) ; Found == else -> pp_skip_to_endif(Rest, Ls1) ; Ls1 = Rest ).

%% ---- #if: defined, the built-ins, expansion, then the reader's constant expression ----
pp_eval(Ts) :- once(catch(pp_eval_(Ts), _, fail)).
pp_eval_(Ts) :-
    pp_defined_pass(Ts, T1), pp_expand_all(T1, T2), pp_defined_pass(T2, T3), pp_normalize(T3, T4),   % a built-in a macro expanded to is answered too
    phrase(ccl_cond_expr(E), T4, _), nb_setval('$ccl_cv_pp', yes), ( catch(ccl_const_eval(E, V), Err, ( nb_setval('$ccl_cv_pp', no), throw(Err) )) -> nb_setval('$ccl_cv_pp', no) ; nb_setval('$ccl_cv_pp', no), fail ), V =\= 0.   % C's intmax arithmetic, untyped (0.128: the evaluator types the program's constants)
pp_defined_pass([], []).
pp_defined_pass([tok(id, defined, L), tok(p, '(', _), tok(K, N, _), tok(p, ')', _)|Ts], [tok(int, V, L)|Os]) :- ( K == id ; K == kw ), !, ( pp_defined(N) -> V = 1 ; V = 0 ), pp_defined_pass(Ts, Os).
pp_defined_pass([tok(id, defined, L), tok(K, N, _)|Ts], [tok(int, V, L)|Os]) :- ( K == id ; K == kw ), !, ( pp_defined(N) -> V = 1 ; V = 0 ), pp_defined_pass(Ts, Os).
pp_defined_pass([tok(id, B, L), tok(p, '(', _)|Ts], [tok(int, V, L)|Os]) :- pp_builtin_name(B), pp_builtin_args(Ts, Args, Rest), !, pp_builtin_answer(B, Args, V), pp_defined_pass(Rest, Os).
pp_defined_pass([T|Ts], [T|Os]) :- pp_defined_pass(Ts, Os).
pp_builtin_args(Ts, Args, Rest) :- pp_builtin_args_(Ts, 1, [], Args, Rest).
pp_builtin_args_([tok(p, '(', L)|Ts], D, Acc, Args, Rest) :- !, D1 is D + 1, pp_builtin_args_(Ts, D1, [tok(p, '(', L)|Acc], Args, Rest).
pp_builtin_args_([tok(p, ')', _)|Ts], 1, Acc, Args, Ts) :- !, reverse(Acc, Args).
pp_builtin_args_([tok(p, ')', L)|Ts], D, Acc, Args, Rest) :- !, D1 is D - 1, pp_builtin_args_(Ts, D1, [tok(p, ')', L)|Acc], Args, Rest).
pp_builtin_args_([T|Ts], D, Acc, Args, Rest) :- pp_builtin_args_(Ts, D, [T|Acc], Args, Rest).
pp_builtin_answer('__has_include', Args, V) :- !, pp_has_include(Args, plain, V).
pp_builtin_answer('__has_include_next', Args, V) :- !, pp_has_include(Args, next, V).
pp_builtin_answer('__has_embed', Args, V) :- !, pp_has_embed(Args, V).
%% C23's `__has_c_attribute(x)' answers the standard attributes' dates ([[deprecated]] 201904 ... [[unsequenced]]
%% 202207), the `__x__' spellings alike, and 0 for anything else; ... AND C++'s `__has_cpp_attribute(x)' ITS STANDARD
%% ATTRIBUTES' (0.198; [cpp.cond]/5, clang 21's values at every level: [[nodiscard]] 201907, [[no_unique_address]] 201803 ...),
%% 0 for anything else, a scoped one (`clang::...', which this compiler drops) among them. It was 0 for every attribute:
%% `__has_cpp_attribute(nodiscard)' was false, and libc++ 18 defined `_LIBCPP_NO_UNIQUE_ADDRESS' as nothing, where clang++'s
%% build lays its views' members `[[__no_unique_address__]]' (libc++ 21 writes the attribute whatever the answer)
pp_builtin_answer('__has_c_attribute', Args, V) :- ccl_lang(c), !, ( pp_attr_name(Args, N), ( atom(N) -> pp_c_attribute(N, V0) ; N = scoped(S, A), pp_attr_vendor(S, gnu), pp_vendor_attribute(gnu, A), V0 = 1 ) -> V = V0 ; V = 0 ).   % ... a GNU one too (0.205, below), as clang answers it in C
pp_builtin_answer('__has_cpp_attribute', Args, V) :- ccl_lang(cpp), !, ( pp_attr_name(Args, N), pp_cpp_attr_value(N, V0) -> V = V0 ; V = 0 ).
%% ... AND GCC'S `__has_attribute(x)' 1 FOR AN ATTRIBUTE THIS COMPILER RECOGNIZES IN THE `__attribute__((x))' FORM (0.221; clang's
%% answer for each attribute it knows): one it honours -- `packed', `aligned', `vector_size', `ext_vector_type' -- and one
%% whose meaning is a diagnostic, an optimization's hint or the debug information, which reading and dropping implements (the
%% `gnu' list of `__has_cpp_attribute', 0.205), its name with or without its underscores; 0 for any other, `weak', `section',
%% `constructor', `cleanup' and `visibility' among them, which the reader drops and a program would lean on. It was 0 for every
%% attribute: a program's `#if __has_attribute(packed)' took its other branch, a layout clang's build does not lay, and libc++
%% defined `_LIBCPP_PACKED', `_LIBCPP_NOALIAS' and `_LIBCPP_NOINLINE' as nothing where clang++'s build writes the attributes
pp_builtin_answer('__has_attribute', Args, V) :- !, ( pp_attr_name(Args, N), atom(N), pp_gnu_attribute(N) -> V = 1 ; V = 0 ).
%% `__has_extension(c_atomic)' answers 1 (0.100): libc++ decides its <atomic> by `__has_feature(cxx_atomic) ||
%% __has_extension(c_atomic) || __has_keyword(_Atomic)', and with all three 0 it defines NO implementation
%% (`template_without_body(__cxx_atomic_base_impl)'); this compiler has C11's `_Atomic(T)' and the `__c11_atomic_*'
%% builtins (0.99), which is exactly the road _LIBCPP_HAS_C_ATOMIC_IMP takes. ... AND `datasizeof' answers 1 (0.112), as
%% clang's does: libc++ 18 takes a type's size without its tail padding from `__datasizeof(T)' (folded by cpp_trait),
%% where its fallback is a member template's explicit specialization the desugaring does not fold, and
%% `__libcpp_datasizeof<T>::value' -- every trivially copyable range copied through `__constexpr_memmove' -- was an
%% undefined symbol at the link. The two extensions answered; every other feature, extension and attribute keeps its 0
%% (the plainest path)
pp_builtin_answer('__has_extension', [tok(_, c_atomic, _)], 1) :- !.
pp_builtin_answer('__has_extension', [tok(_, datasizeof, _)], 1) :- !.
pp_builtin_answer('__is_identifier', _, 1) :- !.
pp_builtin_answer('__has_builtin', [tok(_, B, _)], 0) :- pp_no_builtin(B), !.        % A BUILTIN THIS COMPILER DOES NOT PROVIDE answers 0, and libc++ takes the branch it writes for a compiler without it (0.126)
pp_builtin_answer('__has_builtin', _, 1) :- !.                                    % LLVM's builtins are there (libc++'s other branch is an #error)
pp_builtin_answer('__is_target_arch', [tok(_, A, _)], V) :- !, pp_arch(Arch), ( A == Arch -> V = 1 ; V = 0 ).
pp_builtin_answer('__is_target_vendor', [tok(_, V0, _)], V) :- !, pp_os(O), ( O == darwin, V0 == apple -> V = 1 ; O == linux, V0 == pc -> V = 1 ; V = 0 ).
pp_builtin_answer('__is_target_environment', [tok(_, E, _)], V) :- !, pp_os(O), ( O == linux, E == gnu -> V = 1 ; V = 0 ).
pp_builtin_answer('__is_target_os', [tok(_, OS, _)], V) :- !, pp_os(O), ( O == darwin, memberchk(OS, [macos, darwin, macosx]) -> V = 1 ; O == linux, OS == linux -> V = 1 ; V = 0 ).
pp_builtin_answer(_, _, 0).                                                       % features, attributes, warnings, modules: the plainest path
pp_gnu_attribute(N) :- pp_vendor_attribute(gnu, N), !.
pp_gnu_attribute(N) :- memberchk(N, [vector_size, ext_vector_type]).

%% THE BUILTINS LIBC++ HAS A FALLBACK FOR AND THIS COMPILER DOES NOT PROVIDE (0.126). Every other `__has_builtin' is 1 (the
%% lowering and the desugaring answer them, and libc++'s other branch is often an #error). libc++ 21 writes
%% `common_type' on clang's template `__builtin_common_type<__common_type_t, __type_identity, __empty, _Args...>' where it
%% is there, and on the `decltype(true ? declval<_Tp>() : declval<_Up>())' specializations of libc++ 18 where it is not:
%% the second is the one this desugaring runs: clang's template has no body here, and `common_type_t<_Tp, _Up>' refused
%% `template_without_body' -- `std::accumulate' and the rest of <numeric>, the comparisons of `unique_ptr', the `std::atomic'
%% operations of C++20 and the visitation table of `std::variant' (stdnumeric, stdptrcmp, stdatomic20, stdvariant).
%% `__builtin_clear_padding' (0.194) is GCC's, and clang 18, 21 and 22 do not have it: libc++ 21's atomic_ref then clears no
%% padding and compares the whole object in its compare-exchange, the branch clang++'s build takes.
pp_no_builtin('__builtin_common_type').
pp_no_builtin('__builtin_clear_padding').
pp_attr_name([tok(_, N0, _)], N) :- pp_attr_plain(N0, N).
pp_attr_name([tok(_, S0, _), tok(p, ':', _), tok(p, ':', _), tok(_, N0, _)], scoped(S, N)) :- pp_attr_plain(S0, S), pp_attr_plain(N0, N).   % `::' is two colons to C's lexer
pp_attr_name([tok(_, S0, _), tok(p, '::', _), tok(_, N0, _)], scoped(S, N)) :- pp_attr_plain(S0, S), pp_attr_plain(N0, N).
pp_attr_plain(N0, N) :- ( atom_concat('__', X, N0), atom_concat(N1, '__', X) -> N = N1 ; N = N0 ).
pp_c_attribute(deprecated, 201904).  pp_c_attribute(fallthrough, 201904).  pp_c_attribute(maybe_unused, 201904).
pp_c_attribute(nodiscard, 202003).   pp_c_attribute(noreturn, 202202).     pp_c_attribute('_Noreturn', 202202).
pp_c_attribute(unsequenced, 202207). pp_c_attribute(reproducible, 202207).
pp_cpp_attribute(assume, 202207).              pp_cpp_attribute(carries_dependency, 200809). pp_cpp_attribute(deprecated, 201309).
pp_cpp_attribute(fallthrough, 201603).         pp_cpp_attribute(likely, 201803).             pp_cpp_attribute(maybe_unused, 201603).
pp_cpp_attribute(no_unique_address, 201803).   pp_cpp_attribute(nodiscard, 201907).          pp_cpp_attribute(noreturn, 200809).
pp_cpp_attribute(unlikely, 201803).
%% ... AND A VENDOR'S ATTRIBUTE THIS COMPILER RECOGNIZES IS 1 (0.205; [cpp.cond]/5: an attribute the implementation recognizes
%% and the standard does not specify has an implementation-defined value; clang 21's, which are 1): one whose meaning is a
%% diagnostic, an optimization's hint or the debug information -- `gnu::unused', `gnu::always_inline', `clang::fallthrough',
%% `clang::lifetimebound', the thread-safety analysis' -- which reading and dropping implements, in its `gnu' or `__gnu__'
%% and its `clang' or `_Clang' spellings, its name with or without its underscores, and `gnu::packed' and `gnu::aligned',
%% which the reader honours in that form as in GCC's (ccl_skip_attr//0). One that changes what a program does and that
%% the reader drops in that form (`gnu::vector_size', `gnu::weak', `gnu::section', `gnu::constructor', `gnu::cleanup',
%% `gnu::used', `gnu::visibility', `clang::trivial_abi', `clang::no_destroy', `clang::musttail', `clang::internal_linkage')
%% stays 0. A scoped attribute was 0 for every vendor: a program's
%% `#if __has_cpp_attribute(clang::fallthrough)' took its other branch where clang++'s build takes the first. libc++ 21 asks
%% `_Clang::__lifetimebound__', `__preferred_name__', `__no_specializations__' and the capabilities and writes them into its
%% declarations, which the reader drops; `__no_destroy__' stays its fallback
pp_cpp_attr_value(N, V) :- atom(N), !, pp_cpp_attribute(N, V).
pp_cpp_attr_value(scoped(S, N), 1) :- pp_attr_vendor(S, Ns), pp_vendor_attribute(Ns, N).
pp_attr_vendor(gnu, gnu).
pp_attr_vendor(clang, clang).
pp_attr_vendor('_Clang', clang).
pp_vendor_attribute(gnu, A) :- memberchk(A, [unused, always_inline, noinline, cold, hot, deprecated, warn_unused_result, format, format_arg, nonnull,
    returns_nonnull, pure, const, noreturn, malloc, flatten, artificial, nothrow, fallthrough, leaf, error, warning, may_alias, packed, aligned]).
pp_vendor_attribute(clang, A) :- memberchk(A, [always_inline, noinline, warn_unused_result, fallthrough, lifetimebound, noescape, preferred_name,
    standalone_debug, no_specializations, capability, scoped_lockable, acquire_capability, acquire_shared_capability, release_capability,
    release_shared_capability, try_acquire_capability, try_acquire_shared_capability, requires_capability, ptrauth_vtable_pointer, assume,
    nomerge, noduplicate, optnone, minsize, unavailable, no_sanitize, disable_tail_calls, suppress, unsafe_buffer_usage]).
pp_has_include(Args0, How, V) :- pp_has_args(Args0, Args),
    (   Args = [tok(str, S, _)] -> atom_codes(N, S), Spec0 = local(N)
    ;   pp_angle_name(Args, N) -> Spec0 = system(N)
    ;   fail ),
    ( How == next -> Spec = next(Spec0) ; Spec = Spec0 ),
    pp_current_file(From), ( ccl_resolve_include(Spec, From, _) -> V = 1 ; V = 0 ).
pp_has_include(_, _, 0).
%% the operand of __has_include and __has_embed as written, or macro-replaced where it begins with no header name (C23
%% 6.10.1/4's second form, [cpp.cond]/4; 0.211: `__has_include(INC)' was 0)
pp_has_args(Args0, Args) :- pp_norm_all(Args0, Args1), ( pp_name_first(Args1) -> Args = Args1 ; pp_expand_all(Args0, Es), pp_norm_all(Es, Args) ).
pp_name_first([tok(str, _, _)|_]) :- !.
pp_name_first([tok(p, '<', _)|_]).
pp_angle_name([tok(p, '<', _)|Ts], N) :- pp_angle_(Ts, Cs), atom_codes(N, Cs).
pp_angle_([tok(p, '>', _)], []) :- !.
pp_angle_([T|Ts], Cs) :- pp_spell(T, C1), pp_angle_(Ts, C2), append(C1, C2, Cs).
%% what is left is numbers: an unknown name is 0, true 1, a spelled number its value
pp_plain_int([0'0]) :- !.
pp_plain_int([C|Cs]) :- C >= 0'1, C =< 0'9, pp_digits(Cs).                         % a leading 0 is octal or hex, a suffix or a point the lexer's
pp_digits([]).
pp_digits([C|Cs]) :- C >= 0'0, C =< 0'9, pp_digits(Cs).
pp_normalize([], []).
pp_normalize([tok(kw, true, L)|Ts], [tok(int, 1, L)|Os]) :- !, pp_normalize(Ts, Os).
pp_normalize([tok(id, _, L)|Ts], [tok(int, 0, L)|Os]) :- !, pp_normalize(Ts, Os).
pp_normalize([tok(kw, _, L)|Ts], [tok(int, 0, L)|Os]) :- !, pp_normalize(Ts, Os).
%% IN `#if' AN INT IS AN INTMAX_T (C 6.10.1/4, [cpp.cond]/12; 0.201): a hex, octal or binary literal with no `u' that the lexers
%% made an unsigned int, past INT_MAX (ccl_int_end//4), is signed there, as clang evaluates `#if 0x80000000 > -1'
pp_normalize([tok(num, Cs, L)|Ts], [tok(int, V, L)|Os]) :- \+ pp_plain_int(Cs), \+ ( member(C, Cs), ( C =:= 0'u ; C =:= 0'U ) ), pp_norm(tok(num, Cs, L), T), T = tok(uint, V, _), !, pp_normalize(Ts, Os).   % asked with T free: a bound output fails pp_norm/2 before it restores the lexer's mode
pp_normalize([T|Ts], [T1|Os]) :- pp_norm(T, T1), pp_normalize(Ts, Os).
pp_predef('TARGET_IPHONE_SIMULATOR', darwin, '0').
pp_predef('TARGET_OS_DRIVERKIT', darwin, '0').
pp_predef('TARGET_OS_EMBEDDED', darwin, '0').
pp_predef('TARGET_OS_FIRMWARE', darwin, '0').
pp_predef('TARGET_OS_IOS', darwin, '0').
pp_predef('TARGET_OS_IPHONE', darwin, '0').
pp_predef('TARGET_OS_LINUX', darwin, '0').
pp_predef('TARGET_OS_MAC', darwin, '1').
pp_predef('TARGET_OS_MACCATALYST', darwin, '0').
pp_predef('TARGET_OS_NANO', darwin, '0').
pp_predef('TARGET_OS_OSX', darwin, '1').
pp_predef('TARGET_OS_SIMULATOR', darwin, '0').
pp_predef('TARGET_OS_TV', darwin, '0').
pp_predef('TARGET_OS_UEFI', darwin, '0').
pp_predef('TARGET_OS_UIKITFORMAC', darwin, '0').
pp_predef('TARGET_OS_UNIX', darwin, '0').
pp_predef('TARGET_OS_VISION', darwin, '0').
pp_predef('TARGET_OS_WATCH', darwin, '0').
pp_predef('TARGET_OS_WIN32', darwin, '0').
pp_predef('TARGET_OS_WINDOWS', darwin, '0').
pp_predef('_LP64', any, '1').
pp_predef('__APPLE_CC__', darwin, '6000').
pp_predef('__APPLE__', darwin, '1').
pp_predef('__ATOMIC_ACQUIRE', any, '2').
pp_predef('__ATOMIC_ACQ_REL', any, '4').
pp_predef('__ATOMIC_CONSUME', any, '1').
pp_predef('__ATOMIC_RELAXED', any, '0').
pp_predef('__ATOMIC_RELEASE', any, '3').
pp_predef('__ATOMIC_SEQ_CST', any, '5').
pp_predef('__BLOCKS__', darwin, '1').
pp_predef('__BOOL_WIDTH__', any, '1').
pp_predef('__BYTE_ORDER__', any, '__ORDER_LITTLE_ENDIAN__').
pp_predef('__CHAR16_TYPE__', any, 'unsigned short').
pp_predef('__CHAR32_TYPE__', any, 'unsigned int').
pp_predef('__CHAR_BIT__', any, '8').
pp_predef('__CLANG_ATOMIC_BOOL_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_CHAR16_T_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_CHAR32_T_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_CHAR_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_INT_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_LLONG_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_LONG_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_POINTER_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_SHORT_LOCK_FREE', any, '2').
pp_predef('__CLANG_ATOMIC_WCHAR_T_LOCK_FREE', any, '2').
pp_predef('__CONSTANT_CFSTRINGS__', any, '1').
pp_predef('__DBL_DECIMAL_DIG__', any, '17').
pp_predef('__DBL_DENORM_MIN__', any, '4.9406564584124654e-324').
pp_predef('__DBL_DIG__', any, '15').
pp_predef('__DBL_EPSILON__', any, '2.2204460492503131e-16').
pp_predef('__DBL_HAS_DENORM__', any, '1').
pp_predef('__DBL_HAS_INFINITY__', any, '1').
pp_predef('__DBL_HAS_QUIET_NAN__', any, '1').
pp_predef('__DBL_MANT_DIG__', any, '53').
pp_predef('__DBL_MAX_10_EXP__', any, '308').
pp_predef('__DBL_MAX_EXP__', any, '1024').
pp_predef('__DBL_MAX__', any, '1.7976931348623157e+308').
pp_predef('__DBL_MIN_10_EXP__', any, '(-307)').
pp_predef('__DBL_MIN_EXP__', any, '(-1021)').
pp_predef('__DBL_MIN__', any, '2.2250738585072014e-308').
pp_predef('__DBL_NORM_MAX__', any, '1.7976931348623157e+308').
pp_predef('__DECIMAL_DIG__', any, '__LDBL_DECIMAL_DIG__').
pp_predef('__DYNAMIC__', darwin, '1').
pp_predef('__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__', darwin, '260000').
pp_predef('__ENVIRONMENT_OS_VERSION_MIN_REQUIRED__', darwin, '260000').
pp_predef('__FINITE_MATH_ONLY__', any, '0').
pp_predef('__FLT16_DECIMAL_DIG__', any, '5').
pp_predef('__FLT16_DENORM_MIN__', any, '5.9604644775390625e-8F16').
pp_predef('__FLT16_DIG__', any, '3').
pp_predef('__FLT16_EPSILON__', any, '9.765625e-4F16').
pp_predef('__FLT16_HAS_DENORM__', any, '1').
pp_predef('__FLT16_HAS_INFINITY__', any, '1').
pp_predef('__FLT16_HAS_QUIET_NAN__', any, '1').
pp_predef('__FLT16_MANT_DIG__', any, '11').
pp_predef('__FLT16_MAX_10_EXP__', any, '4').
pp_predef('__FLT16_MAX_EXP__', any, '16').
pp_predef('__FLT16_MAX__', any, '6.5504e+4F16').
pp_predef('__FLT16_MIN_10_EXP__', any, '(-4)').
pp_predef('__FLT16_MIN_EXP__', any, '(-13)').
pp_predef('__FLT16_MIN__', any, '6.103515625e-5F16').
pp_predef('__FLT16_NORM_MAX__', any, '6.5504e+4F16').
pp_predef('__FLT_DECIMAL_DIG__', any, '9').
pp_predef('__FLT_DENORM_MIN__', any, '1.40129846e-45F').
pp_predef('__FLT_DIG__', any, '6').
pp_predef('__FLT_EPSILON__', any, '1.19209290e-7F').
pp_predef('__FLT_HAS_DENORM__', any, '1').
pp_predef('__FLT_HAS_INFINITY__', any, '1').
pp_predef('__FLT_HAS_QUIET_NAN__', any, '1').
pp_predef('__FLT_MANT_DIG__', any, '24').
pp_predef('__FLT_MAX_10_EXP__', any, '38').
pp_predef('__FLT_MAX_EXP__', any, '128').
pp_predef('__FLT_MAX__', any, '3.40282347e+38F').
pp_predef('__FLT_MIN_10_EXP__', any, '(-37)').
pp_predef('__FLT_MIN_EXP__', any, '(-125)').
pp_predef('__FLT_MIN__', any, '1.17549435e-38F').
pp_predef('__FLT_NORM_MAX__', any, '3.40282347e+38F').
pp_predef('__FLT_EVAL_METHOD__', any, '0').   % a builtin macro in clang (`#pragma clang fp eval_method' moves it), so no -dM lists it; 0 on both machines (0.194: <float.h>'s FLT_EVAL_METHOD)
pp_predef('__FLT_RADIX__', any, '2').
pp_predef('__FPCLASS_NEGINF', any, '0x0004').
pp_predef('__FPCLASS_NEGNORMAL', any, '0x0008').
pp_predef('__FPCLASS_NEGSUBNORMAL', any, '0x0010').
pp_predef('__FPCLASS_NEGZERO', any, '0x0020').
pp_predef('__FPCLASS_POSINF', any, '0x0200').
pp_predef('__FPCLASS_POSNORMAL', any, '0x0100').
pp_predef('__FPCLASS_POSSUBNORMAL', any, '0x0080').
pp_predef('__FPCLASS_POSZERO', any, '0x0040').
pp_predef('__FPCLASS_QNAN', any, '0x0002').
pp_predef('__FPCLASS_SNAN', any, '0x0001').
pp_predef('__GCC_ASM_FLAG_OUTPUTS__', any, '1').
pp_predef('__GCC_ATOMIC_BOOL_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_CHAR16_T_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_CHAR32_T_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_CHAR_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_INT_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_LLONG_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_LONG_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_POINTER_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_SHORT_LOCK_FREE', any, '2').
pp_predef('__GCC_ATOMIC_TEST_AND_SET_TRUEVAL', any, '1').
pp_predef('__GCC_ATOMIC_WCHAR_T_LOCK_FREE', any, '2').
pp_predef('__GCC_CONSTRUCTIVE_SIZE', any, '64').
pp_predef('__GCC_HAVE_DWARF2_CFI_ASM', any, '1').
pp_predef('__GCC_HAVE_SYNC_COMPARE_AND_SWAP_1', any, '1').
pp_predef('__GCC_HAVE_SYNC_COMPARE_AND_SWAP_16', any, '1').
pp_predef('__GCC_HAVE_SYNC_COMPARE_AND_SWAP_2', any, '1').
pp_predef('__GCC_HAVE_SYNC_COMPARE_AND_SWAP_4', any, '1').
pp_predef('__GCC_HAVE_SYNC_COMPARE_AND_SWAP_8', any, '1').
pp_predef('__GNUC_MINOR__', any, '2').
pp_predef('__GNUC_PATCHLEVEL__', any, '1').
pp_predef('__GNUC_STDC_INLINE__', c, '1').   % C's alone (0.194): C++ has __GNUC_GNU_INLINE__ (the `cpp' table)
pp_predef('__GNUC__', any, '4').
pp_predef('__GXX_ABI_VERSION', any, '1002').
pp_predef('__INT16_C(c)', any, 'c').
pp_predef('__INT16_C_SUFFIX__', any, '').
pp_predef('__INT16_FMTd__', any, '"hd"').
pp_predef('__INT16_FMTi__', any, '"hi"').
pp_predef('__INT16_MAX__', any, '32767').
pp_predef('__INT16_TYPE__', any, 'short').
pp_predef('__INT32_C(c)', any, 'c').
pp_predef('__INT32_C_SUFFIX__', any, '').
pp_predef('__INT32_FMTd__', any, '"d"').
pp_predef('__INT32_FMTi__', any, '"i"').
pp_predef('__INT32_MAX__', any, '2147483647').
pp_predef('__INT32_TYPE__', any, 'int').
pp_predef('__INT64_C(c)', any, 'c##LL').
pp_predef('__INT64_C_SUFFIX__', any, 'LL').
pp_predef('__INT64_FMTd__', any, '"lld"').
pp_predef('__INT64_FMTi__', any, '"lli"').
pp_predef('__INT64_MAX__', any, '9223372036854775807LL').
pp_predef('__INT64_TYPE__', any, 'long long int').
pp_predef('__INT8_C(c)', any, 'c').
pp_predef('__INT8_C_SUFFIX__', any, '').
pp_predef('__INT8_FMTd__', any, '"hhd"').
pp_predef('__INT8_FMTi__', any, '"hhi"').
pp_predef('__INT8_MAX__', any, '127').
pp_predef('__INT8_TYPE__', any, 'signed char').
pp_predef('__INTMAX_C(c)', any, 'c##L').
pp_predef('__INTMAX_C_SUFFIX__', any, 'L').
pp_predef('__INTMAX_FMTd__', any, '"ld"').
pp_predef('__INTMAX_FMTi__', any, '"li"').
pp_predef('__INTMAX_MAX__', any, '9223372036854775807L').
pp_predef('__INTMAX_TYPE__', any, 'long int').
pp_predef('__INTMAX_WIDTH__', any, '64').
pp_predef('__INTPTR_FMTd__', any, '"ld"').
pp_predef('__INTPTR_FMTi__', any, '"li"').
pp_predef('__INTPTR_MAX__', any, '9223372036854775807L').
pp_predef('__INTPTR_TYPE__', any, 'long int').
pp_predef('__INTPTR_WIDTH__', any, '64').
pp_predef('__INT_FAST16_FMTd__', any, '"hd"').
pp_predef('__INT_FAST16_FMTi__', any, '"hi"').
pp_predef('__INT_FAST16_MAX__', any, '32767').
pp_predef('__INT_FAST16_TYPE__', any, 'short').
pp_predef('__INT_FAST16_WIDTH__', any, '16').
pp_predef('__INT_FAST32_FMTd__', any, '"d"').
pp_predef('__INT_FAST32_FMTi__', any, '"i"').
pp_predef('__INT_FAST32_MAX__', any, '2147483647').
pp_predef('__INT_FAST32_TYPE__', any, 'int').
pp_predef('__INT_FAST32_WIDTH__', any, '32').
pp_predef('__INT_FAST64_FMTd__', any, '"lld"').
pp_predef('__INT_FAST64_FMTi__', any, '"lli"').
pp_predef('__INT_FAST64_MAX__', any, '9223372036854775807LL').
pp_predef('__INT_FAST64_TYPE__', any, 'long long int').
pp_predef('__INT_FAST64_WIDTH__', any, '64').
pp_predef('__INT_FAST8_FMTd__', any, '"hhd"').
pp_predef('__INT_FAST8_FMTi__', any, '"hhi"').
pp_predef('__INT_FAST8_MAX__', any, '127').
pp_predef('__INT_FAST8_TYPE__', any, 'signed char').
pp_predef('__INT_FAST8_WIDTH__', any, '8').
pp_predef('__INT_LEAST16_FMTd__', any, '"hd"').
pp_predef('__INT_LEAST16_FMTi__', any, '"hi"').
pp_predef('__INT_LEAST16_MAX__', any, '32767').
pp_predef('__INT_LEAST16_TYPE__', any, 'short').
pp_predef('__INT_LEAST16_WIDTH__', any, '16').
pp_predef('__INT_LEAST32_FMTd__', any, '"d"').
pp_predef('__INT_LEAST32_FMTi__', any, '"i"').
pp_predef('__INT_LEAST32_MAX__', any, '2147483647').
pp_predef('__INT_LEAST32_TYPE__', any, 'int').
pp_predef('__INT_LEAST32_WIDTH__', any, '32').
pp_predef('__INT_LEAST64_FMTd__', any, '"lld"').
pp_predef('__INT_LEAST64_FMTi__', any, '"lli"').
pp_predef('__INT_LEAST64_MAX__', any, '9223372036854775807LL').
pp_predef('__INT_LEAST64_TYPE__', any, 'long long int').
pp_predef('__INT_LEAST64_WIDTH__', any, '64').
pp_predef('__INT_LEAST8_FMTd__', any, '"hhd"').
pp_predef('__INT_LEAST8_FMTi__', any, '"hhi"').
pp_predef('__INT_LEAST8_MAX__', any, '127').
pp_predef('__INT_LEAST8_TYPE__', any, 'signed char').
pp_predef('__INT_LEAST8_WIDTH__', any, '8').
pp_predef('__INT_MAX__', any, '2147483647').
pp_predef('__INT_WIDTH__', any, '32').
pp_predef('__LDBL_HAS_DENORM__', any, '1').
pp_predef('__LDBL_HAS_INFINITY__', any, '1').
pp_predef('__LDBL_HAS_QUIET_NAN__', any, '1').
pp_predef('__LITTLE_ENDIAN__', any, '1').
pp_predef('__LLONG_WIDTH__', any, '64').
pp_predef('__LONG_LONG_MAX__', any, '9223372036854775807LL').
pp_predef('__LONG_MAX__', any, '9223372036854775807L').
pp_predef('__LONG_WIDTH__', any, '64').
pp_predef('__LP64__', any, '1').
pp_predef('__MACH__', darwin, '1').
pp_predef('__linux__', linux, '1').  pp_predef('__linux', linux, '1').  pp_predef('__gnu_linux__', linux, '1').
pp_predef('__unix__', linux, '1').   pp_predef('__unix', linux, '1').   pp_predef('__ELF__', linux, '1').
pp_predef('__PIE__', linux, '2').    pp_predef('__pie__', linux, '2').
pp_predef('__MEMORY_SCOPE_CLUSTR', any, '5').
pp_predef('__MEMORY_SCOPE_DEVICE', any, '1').
pp_predef('__MEMORY_SCOPE_SINGLE', any, '4').
pp_predef('__MEMORY_SCOPE_SYSTEM', any, '0').
pp_predef('__MEMORY_SCOPE_WRKGRP', any, '2').
pp_predef('__MEMORY_SCOPE_WVFRNT', any, '3').
pp_predef('__NO_INLINE__', any, '1').
pp_predef('__NO_MATH_ERRNO__', any, '1').
pp_predef('__OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES', any, '3').
pp_predef('__OPENCL_MEMORY_SCOPE_DEVICE', any, '2').
pp_predef('__OPENCL_MEMORY_SCOPE_SUB_GROUP', any, '4').
pp_predef('__OPENCL_MEMORY_SCOPE_WORK_GROUP', any, '1').
pp_predef('__OPENCL_MEMORY_SCOPE_WORK_ITEM', any, '0').
pp_predef('__ORDER_BIG_ENDIAN__', any, '4321').
pp_predef('__ORDER_LITTLE_ENDIAN__', any, '1234').
pp_predef('__ORDER_PDP_ENDIAN__', any, '3412').
pp_predef('__PIC__', any, '2').
pp_predef('__POINTER_WIDTH__', any, '64').
pp_predef('__PRAGMA_REDEFINE_EXTNAME', any, '1').
pp_predef('__PTRDIFF_FMTd__', any, '"ld"').
pp_predef('__PTRDIFF_FMTi__', any, '"li"').
pp_predef('__PTRDIFF_MAX__', any, '9223372036854775807L').
pp_predef('__PTRDIFF_TYPE__', any, 'long int').
pp_predef('__PTRDIFF_WIDTH__', any, '64').
pp_predef('__REGISTER_PREFIX__', any, '').
pp_predef('__SCHAR_MAX__', any, '127').
pp_predef('__SHRT_MAX__', any, '32767').
pp_predef('__SHRT_WIDTH__', any, '16').
pp_predef('__SIG_ATOMIC_MAX__', any, '2147483647').
pp_predef('__SIG_ATOMIC_MIN__', any, '(-__SIG_ATOMIC_MAX__ - 1)').
pp_predef('__SIG_ATOMIC_TYPE__', any, 'int').
pp_predef('__SIG_ATOMIC_WIDTH__', any, '32').
pp_predef('__SIZEOF_DOUBLE__', any, '8').
pp_predef('__SIZEOF_FLOAT__', any, '4').
%% NO 128-BIT INTEGER, the fourth question of the kind below (0.112): libc++ decides `_LIBCPP_HAS_NO_INT128' by
%% `!defined(__SIZEOF_INT128__)', the one place in libc++ 18 that reads the macro, and nothing here lowers an
%% `__int128' (the reader knows `__int128_t' and `__uint128_t' as names; nothing gives them a type). Predefined,
%% std::format's `__basic_format_arg_value' held an `__int128_t __i128_' member, its visitor was instantiated over
%% that unknown type and `invoke_result<F, unknown>' refused kind_mismatch(_Tp). Left undefined, libc++ compiles its
%% own no-int128 configuration, as it does under MSVC; glibc's headers do not read the macro.
%% pp_predef('__SIZEOF_INT128__', any, '16').
%% 0.117: `__int128' lowers (LLVM's i128), and C asks the macro (`#ifdef __SIZEOF_INT128__'; glibc's headers do not), so C
%% has it; C++ stays without it, libc++'s own no-int128 configuration by design, while a C++ program's `__int128' runs.
pp_predef('__SIZEOF_INT128__', any, '16').
pp_predef('__SIZEOF_INT__', any, '4').
pp_predef('__SIZEOF_LONG_LONG__', any, '8').
pp_predef('__SIZEOF_LONG__', any, '8').
pp_predef('__SIZEOF_POINTER__', any, '8').
pp_predef('__SIZEOF_PTRDIFF_T__', any, '8').
pp_predef('__SIZEOF_SHORT__', any, '2').
pp_predef('__SIZEOF_SIZE_T__', any, '8').
pp_predef('__SIZEOF_WCHAR_T__', any, '4').
pp_predef('__SIZEOF_WINT_T__', any, '4').
pp_predef('__SIZE_FMTX__', any, '"lX"').
pp_predef('__SIZE_FMTo__', any, '"lo"').
pp_predef('__SIZE_FMTu__', any, '"lu"').
pp_predef('__SIZE_FMTx__', any, '"lx"').
pp_predef('__SIZE_MAX__', any, '18446744073709551615UL').
pp_predef('__SIZE_TYPE__', any, 'long unsigned int').
pp_predef('__SIZE_WIDTH__', any, '64').
pp_predef('__SSP__', darwin, '1').
pp_predef('__STDC_EMBED_EMPTY__', any, '2').
pp_predef('__STDC_EMBED_FOUND__', any, '1').
pp_predef('__STDC_EMBED_NOT_FOUND__', any, '0').
pp_predef('__STDC_HOSTED__', any, '1').
pp_predef('__STDC_NO_THREADS__', darwin, '1').
pp_predef('__STDC_UTF_16__', any, '1').
pp_predef('__STDC_UTF_32__', any, '1').
pp_predef('__STDC_VERSION__', c, '201710L').   % C's alone (0.194): clang++ defines no __STDC_VERSION__, and in the `any' table C++ had it
%% ---- C11 and C99 (-std=c11, -std=c99): the level's own, answered before C17's (0.221) ----------------
pp_predef('__STDC_VERSION__', c11, '201112L').
pp_predef('__STDC_VERSION__', c99, '199901L').
%% ---- C23 (-std=c23): the level's own macros, answered before C17's ------------------------------
pp_predef('__STDC_VERSION__', c23, '202311L').
pp_predef('__STDC_EMBED_NOT_FOUND__', c23, '0').
pp_predef('__STDC_EMBED_FOUND__', c23, '1').
pp_predef('__STDC_EMBED_EMPTY__', c23, '2').
%% C23's char8_t and its lock-free answer, and the binary formats of <inttypes.h> (`%b', `%B'), as clang 22 predefines
%% them at C23 (0.194); a header's __STDC_VERSION_*_H__ is the header's own (C23 7.x.1: <stddef.h>, <limits.h>, <stdarg.h>,
%% <float.h> and <stdatomic.h> here, <stdbit.h> and <stdckdint.h> too), never predefined: five were, and clang and gcc
%% predefine none of them
pp_predef('__CHAR8_TYPE__', c23, 'unsigned char').
pp_predef('__CLANG_ATOMIC_CHAR8_T_LOCK_FREE', c23, '2').
pp_predef('__GCC_ATOMIC_CHAR8_T_LOCK_FREE', c23, '2').
pp_predef('__UINT8_FMTB__', c23, '"hhB"').
pp_predef('__UINT8_FMTb__', c23, '"hhb"').
pp_predef('__UINT_LEAST8_FMTB__', c23, '"hhB"').
pp_predef('__UINT_LEAST8_FMTb__', c23, '"hhb"').
pp_predef('__UINT_FAST8_FMTB__', c23, '"hhB"').
pp_predef('__UINT_FAST8_FMTb__', c23, '"hhb"').
pp_predef('__UINT16_FMTB__', c23, '"hB"').
pp_predef('__UINT16_FMTb__', c23, '"hb"').
pp_predef('__UINT_LEAST16_FMTB__', c23, '"hB"').
pp_predef('__UINT_LEAST16_FMTb__', c23, '"hb"').
pp_predef('__UINT_FAST16_FMTB__', c23, '"hB"').
pp_predef('__UINT_FAST16_FMTb__', c23, '"hb"').
pp_predef('__UINT32_FMTB__', c23, '"B"').
pp_predef('__UINT32_FMTb__', c23, '"b"').
pp_predef('__UINT_LEAST32_FMTB__', c23, '"B"').
pp_predef('__UINT_LEAST32_FMTb__', c23, '"b"').
pp_predef('__UINT_FAST32_FMTB__', c23, '"B"').
pp_predef('__UINT_FAST32_FMTb__', c23, '"b"').
pp_predef('__SIZE_FMTB__', c23, '"lB"').
pp_predef('__SIZE_FMTb__', c23, '"lb"').
pp_predef('__UINTMAX_FMTB__', c23, '"lB"').
pp_predef('__UINTMAX_FMTb__', c23, '"lb"').
pp_predef('__UINTPTR_FMTB__', c23, '"lB"').
pp_predef('__UINTPTR_FMTb__', c23, '"lb"').
%% the 64-bit ones are the OS's: `long' on Linux, `long long' on Darwin (pp_c_os_table/2)
pp_predef('__UINT64_FMTB__', c23_linux, '"lB"').
pp_predef('__UINT64_FMTb__', c23_linux, '"lb"').
pp_predef('__UINT_LEAST64_FMTB__', c23_linux, '"lB"').
pp_predef('__UINT_LEAST64_FMTb__', c23_linux, '"lb"').
pp_predef('__UINT_FAST64_FMTB__', c23_linux, '"lB"').
pp_predef('__UINT_FAST64_FMTb__', c23_linux, '"lb"').
pp_predef('__UINT64_FMTB__', c23_darwin, '"llB"').
pp_predef('__UINT64_FMTb__', c23_darwin, '"llb"').
pp_predef('__UINT_LEAST64_FMTB__', c23_darwin, '"llB"').
pp_predef('__UINT_LEAST64_FMTb__', c23_darwin, '"llb"').
pp_predef('__UINT_FAST64_FMTB__', c23_darwin, '"llB"').
pp_predef('__UINT_FAST64_FMTb__', c23_darwin, '"llb"').
pp_predef('__STDC__', any, '1').
pp_predef('__UINT16_C(c)', any, 'c').
pp_predef('__UINT16_C_SUFFIX__', any, '').
pp_predef('__UINT16_FMTX__', any, '"hX"').
pp_predef('__UINT16_FMTo__', any, '"ho"').
pp_predef('__UINT16_FMTu__', any, '"hu"').
pp_predef('__UINT16_FMTx__', any, '"hx"').
pp_predef('__UINT16_MAX__', any, '65535').
pp_predef('__UINT16_TYPE__', any, 'unsigned short').
pp_predef('__UINT32_C(c)', any, 'c##U').
pp_predef('__UINT32_C_SUFFIX__', any, 'U').
pp_predef('__UINT32_FMTX__', any, '"X"').
pp_predef('__UINT32_FMTo__', any, '"o"').
pp_predef('__UINT32_FMTu__', any, '"u"').
pp_predef('__UINT32_FMTx__', any, '"x"').
pp_predef('__UINT32_MAX__', any, '4294967295U').
pp_predef('__UINT32_TYPE__', any, 'unsigned int').
pp_predef('__UINT64_C(c)', any, 'c##ULL').
pp_predef('__UINT64_C_SUFFIX__', any, 'ULL').
pp_predef('__UINT64_FMTX__', any, '"llX"').
pp_predef('__UINT64_FMTo__', any, '"llo"').
pp_predef('__UINT64_FMTu__', any, '"llu"').
pp_predef('__UINT64_FMTx__', any, '"llx"').
pp_predef('__UINT64_MAX__', any, '18446744073709551615ULL').
pp_predef('__UINT64_TYPE__', any, 'long long unsigned int').
pp_predef('__UINT8_C(c)', any, 'c').
pp_predef('__UINT8_C_SUFFIX__', any, '').
pp_predef('__UINT8_FMTX__', any, '"hhX"').
pp_predef('__UINT8_FMTo__', any, '"hho"').
pp_predef('__UINT8_FMTu__', any, '"hhu"').
pp_predef('__UINT8_FMTx__', any, '"hhx"').
pp_predef('__UINT8_MAX__', any, '255').
pp_predef('__UINT8_TYPE__', any, 'unsigned char').
pp_predef('__UINTMAX_C(c)', any, 'c##UL').
pp_predef('__UINTMAX_C_SUFFIX__', any, 'UL').
pp_predef('__UINTMAX_FMTX__', any, '"lX"').
pp_predef('__UINTMAX_FMTo__', any, '"lo"').
pp_predef('__UINTMAX_FMTu__', any, '"lu"').
pp_predef('__UINTMAX_FMTx__', any, '"lx"').
pp_predef('__UINTMAX_MAX__', any, '18446744073709551615UL').
pp_predef('__UINTMAX_TYPE__', any, 'long unsigned int').
pp_predef('__UINTMAX_WIDTH__', any, '64').
pp_predef('__UINTPTR_FMTX__', any, '"lX"').
pp_predef('__UINTPTR_FMTo__', any, '"lo"').
pp_predef('__UINTPTR_FMTu__', any, '"lu"').
pp_predef('__UINTPTR_FMTx__', any, '"lx"').
pp_predef('__UINTPTR_MAX__', any, '18446744073709551615UL').
pp_predef('__UINTPTR_TYPE__', any, 'long unsigned int').
pp_predef('__UINTPTR_WIDTH__', any, '64').
pp_predef('__UINT_FAST16_FMTX__', any, '"hX"').
pp_predef('__UINT_FAST16_FMTo__', any, '"ho"').
pp_predef('__UINT_FAST16_FMTu__', any, '"hu"').
pp_predef('__UINT_FAST16_FMTx__', any, '"hx"').
pp_predef('__UINT_FAST16_MAX__', any, '65535').
pp_predef('__UINT_FAST16_TYPE__', any, 'unsigned short').
pp_predef('__UINT_FAST32_FMTX__', any, '"X"').
pp_predef('__UINT_FAST32_FMTo__', any, '"o"').
pp_predef('__UINT_FAST32_FMTu__', any, '"u"').
pp_predef('__UINT_FAST32_FMTx__', any, '"x"').
pp_predef('__UINT_FAST32_MAX__', any, '4294967295U').
pp_predef('__UINT_FAST32_TYPE__', any, 'unsigned int').
pp_predef('__UINT_FAST64_FMTX__', any, '"llX"').
pp_predef('__UINT_FAST64_FMTo__', any, '"llo"').
pp_predef('__UINT_FAST64_FMTu__', any, '"llu"').
pp_predef('__UINT_FAST64_FMTx__', any, '"llx"').
pp_predef('__UINT_FAST64_MAX__', any, '18446744073709551615ULL').
pp_predef('__UINT_FAST64_TYPE__', any, 'long long unsigned int').
pp_predef('__UINT_FAST8_FMTX__', any, '"hhX"').
pp_predef('__UINT_FAST8_FMTo__', any, '"hho"').
pp_predef('__UINT_FAST8_FMTu__', any, '"hhu"').
pp_predef('__UINT_FAST8_FMTx__', any, '"hhx"').
pp_predef('__UINT_FAST8_MAX__', any, '255').
pp_predef('__UINT_FAST8_TYPE__', any, 'unsigned char').
pp_predef('__UINT_LEAST16_FMTX__', any, '"hX"').
pp_predef('__UINT_LEAST16_FMTo__', any, '"ho"').
pp_predef('__UINT_LEAST16_FMTu__', any, '"hu"').
pp_predef('__UINT_LEAST16_FMTx__', any, '"hx"').
pp_predef('__UINT_LEAST16_MAX__', any, '65535').
pp_predef('__UINT_LEAST16_TYPE__', any, 'unsigned short').
pp_predef('__UINT_LEAST32_FMTX__', any, '"X"').
pp_predef('__UINT_LEAST32_FMTo__', any, '"o"').
pp_predef('__UINT_LEAST32_FMTu__', any, '"u"').
pp_predef('__UINT_LEAST32_FMTx__', any, '"x"').
pp_predef('__UINT_LEAST32_MAX__', any, '4294967295U').
pp_predef('__UINT_LEAST32_TYPE__', any, 'unsigned int').
pp_predef('__UINT_LEAST64_FMTX__', any, '"llX"').
pp_predef('__UINT_LEAST64_FMTo__', any, '"llo"').
pp_predef('__UINT_LEAST64_FMTu__', any, '"llu"').
pp_predef('__UINT_LEAST64_FMTx__', any, '"llx"').
pp_predef('__UINT_LEAST64_MAX__', any, '18446744073709551615ULL').
pp_predef('__UINT_LEAST64_TYPE__', any, 'long long unsigned int').
pp_predef('__UINT_LEAST8_FMTX__', any, '"hhX"').
pp_predef('__UINT_LEAST8_FMTo__', any, '"hho"').
pp_predef('__UINT_LEAST8_FMTu__', any, '"hhu"').
pp_predef('__UINT_LEAST8_FMTx__', any, '"hhx"').
pp_predef('__UINT_LEAST8_MAX__', any, '255').
pp_predef('__UINT_LEAST8_TYPE__', any, 'unsigned char').
pp_predef('__USER_LABEL_PREFIX__', any, '_').
pp_predef('__WCHAR_MAX__', any, '2147483647').
pp_predef('__WCHAR_MIN__', any, '(-__WCHAR_MAX__ - 1)').
pp_predef('__WCHAR_TYPE__', any, 'int').
pp_predef('__WCHAR_WIDTH__', any, '32').
pp_predef('__WINT_MAX__', any, '2147483647').
pp_predef('__WINT_MIN__', any, '(-__WINT_MAX__ - 1)').
pp_predef('__WINT_TYPE__', any, 'int').
pp_predef('__WINT_WIDTH__', any, '32').
pp_predef('__block', darwin, '__attribute__((__blocks__(byref)))').
%% the plainest path through the SDK's string and stdio headers: no fortified
%% forms (strcpy stays the function, not __builtin___strcpy_chk), as with the
%% features and attributes answered 0
pp_predef('_FORTIFY_SOURCE', any, '0').
pp_predef('__clang__', any, '1').
pp_predef('__clang_major__', any, '23').
pp_predef('__clang_minor__', any, '1').
pp_predef('__clang_patchlevel__', any, '0').
pp_predef('__llvm__', any, '1').
pp_predef('__nonnull', any, '_Nonnull').
pp_predef('__null_unspecified', any, '_Null_unspecified').
pp_predef('__nullable', any, '_Nullable').
pp_predef('__pic__', any, '2').
pp_predef('__strong', darwin, '').
pp_predef('__unsafe_unretained', darwin, '').
pp_predef('__weak', darwin, '__attribute__((objc_gc(weak)))').
pp_predef('__BIGGEST_ALIGNMENT__', x86_64, '16').
pp_predef('__BITINT_MAXWIDTH__', x86_64, '8388608').
pp_predef('__FXSR__', x86_64, '1').
pp_predef('__GCC_DESTRUCTIVE_SIZE', x86_64, '64').
pp_predef('__LAHF_SAHF__', x86_64, '1').
pp_predef('__LDBL_DECIMAL_DIG__', x86_64, '21').
pp_predef('__LDBL_DENORM_MIN__', x86_64, '3.64519953188247460253e-4951L').
pp_predef('__LDBL_DIG__', x86_64, '18').
pp_predef('__LDBL_EPSILON__', x86_64, '1.08420217248550443401e-19L').
pp_predef('__LDBL_MANT_DIG__', x86_64, '64').
pp_predef('__LDBL_MAX_10_EXP__', x86_64, '4932').
pp_predef('__LDBL_MAX_EXP__', x86_64, '16384').
pp_predef('__LDBL_MAX__', x86_64, '1.18973149535723176502e+4932L').
pp_predef('__LDBL_MIN_10_EXP__', x86_64, '(-4931)').
pp_predef('__LDBL_MIN_EXP__', x86_64, '(-16381)').
pp_predef('__LDBL_MIN__', x86_64, '3.36210314311209350626e-4932L').
pp_predef('__LDBL_NORM_MAX__', x86_64, '1.18973149535723176502e+4932L').
pp_predef('__MMX__', x86_64, '1').
pp_predef('__NO_MATH_INLINES', x86_64, '1').
pp_predef('__OBJC_BOOL_IS_BOOL', x86_64, '0').
pp_predef('__SEG_FS', x86_64, '1').
pp_predef('__SEG_GS', x86_64, '1').
pp_predef('__SIZEOF_LONG_DOUBLE__', x86_64, '16').
pp_predef('__SSE2_MATH__', x86_64, '1').
pp_predef('__SSE2__', x86_64, '1').
pp_predef('__SSE3__', x86_64, '1').
pp_predef('__SSE4_1__', x86_64, '1').
pp_predef('__SSE_MATH__', x86_64, '1').
pp_predef('__SSE__', x86_64, '1').
pp_predef('__SSSE3__', x86_64, '1').
pp_predef('__amd64', x86_64, '1').
pp_predef('__amd64__', x86_64, '1').
pp_predef('__code_model_small__', x86_64, '1').
pp_predef('__core2', x86_64, '1').
pp_predef('__core2__', x86_64, '1').
pp_predef('__seg_fs', x86_64, '__attribute__((address_space(257)))').
pp_predef('__seg_gs', x86_64, '__attribute__((address_space(256)))').
pp_predef('__tune_core2__', x86_64, '1').
pp_predef('__x86_64', x86_64, '1').
pp_predef('__x86_64__', x86_64, '1').
pp_predef('__AARCH64EL__', arm64, '1').
pp_predef('__AARCH64_CMODEL_SMALL__', arm64, '1').
pp_predef('__AARCH64_SIMD__', arm64, '1').
pp_predef('__ARM64_ARCH_8__', arm64, '1').
pp_predef('__ARM_64BIT_STATE', arm64, '1').
pp_predef('__ARM_ACLE', arm64, '202420').
pp_predef('__ARM_ACLE_VERSION(year,quarter,patch)', arm64, '(100 * (year) + 10 * (quarter) + (patch))').
pp_predef('__ARM_ALIGN_MAX_STACK_PWR', arm64, '4').
pp_predef('__ARM_ARCH', arm64, '8').
pp_predef('__ARM_ARCH_ISA_A64', arm64, '1').
pp_predef('__ARM_ARCH_PROFILE', arm64, '\'A\'').
pp_predef('__ARM_FEATURE_AES', arm64, '1').
pp_predef('__ARM_FEATURE_ATOMICS', arm64, '1').
pp_predef('__ARM_FEATURE_CLZ', arm64, '1').
pp_predef('__ARM_FEATURE_COMPLEX', arm64, '1').
pp_predef('__ARM_FEATURE_CRC32', arm64, '1').
pp_predef('__ARM_FEATURE_CRYPTO', arm64, '1').
pp_predef('__ARM_FEATURE_DIRECTED_ROUNDING', arm64, '1').
pp_predef('__ARM_FEATURE_DIV', arm64, '1').
pp_predef('__ARM_FEATURE_DOTPROD', arm64, '1').
pp_predef('__ARM_FEATURE_FMA', arm64, '1').
pp_predef('__ARM_FEATURE_FP16_FML', arm64, '1').
pp_predef('__ARM_FEATURE_FP16_SCALAR_ARITHMETIC', arm64, '1').
pp_predef('__ARM_FEATURE_FP16_VECTOR_ARITHMETIC', arm64, '1').
pp_predef('__ARM_FEATURE_IDIV', arm64, '1').
pp_predef('__ARM_FEATURE_JCVT', arm64, '1').
pp_predef('__ARM_FEATURE_LDREX', arm64, '0xF').
pp_predef('__ARM_FEATURE_NUMERIC_MAXMIN', arm64, '1').
pp_predef('__ARM_FEATURE_PAUTH', arm64, '1').
pp_predef('__ARM_FEATURE_QRDMX', arm64, '1').
pp_predef('__ARM_FEATURE_RCPC', arm64, '1').
pp_predef('__ARM_FEATURE_SHA2', arm64, '1').
pp_predef('__ARM_FEATURE_SHA3', arm64, '1').
pp_predef('__ARM_FEATURE_SHA512', arm64, '1').
pp_predef('__ARM_FEATURE_UNALIGNED', arm64, '1').
pp_predef('__ARM_FP', arm64, '0xE').
pp_predef('__ARM_FP16_ARGS', arm64, '1').
pp_predef('__ARM_FP16_FORMAT_IEEE', arm64, '1').
pp_predef('__ARM_NEON', arm64, '1').
pp_predef('__ARM_NEON_FP', arm64, '0xE').
pp_predef('__ARM_NEON_SVE_BRIDGE', arm64, '1').
pp_predef('__ARM_NEON__', arm64, '1').
pp_predef('__ARM_PCS_AAPCS64', arm64, '1').
pp_predef('__ARM_PREFETCH_RANGE', arm64, '1').
pp_predef('__ARM_SIZEOF_MINIMAL_ENUM', arm64, '4').
pp_predef('__ARM_SIZEOF_WCHAR_T', arm64, '4').
pp_predef('__ARM_STATE_ZA', arm64, '1').
pp_predef('__ARM_STATE_ZT0', arm64, '1').
pp_predef('__BIGGEST_ALIGNMENT__', arm64, '8').
pp_predef('__BITINT_MAXWIDTH__', arm64, '128').
pp_predef('__FP_FAST_FMA', arm64, '1').
pp_predef('__FP_FAST_FMAF', arm64, '1').
pp_predef('__FUNCTION_MULTI_VERSIONING_SUPPORT_LEVEL', arm64, '202430').
pp_predef('__GCC_DESTRUCTIVE_SIZE', arm64, '128').
pp_predef('__HAVE_FUNCTION_MULTI_VERSIONING', arm64, '1').
pp_predef('__LDBL_DECIMAL_DIG__', arm64, '17').
pp_predef('__LDBL_DENORM_MIN__', arm64, '4.9406564584124654e-324L').
pp_predef('__LDBL_DIG__', arm64, '15').
pp_predef('__LDBL_EPSILON__', arm64, '2.2204460492503131e-16L').
pp_predef('__LDBL_MANT_DIG__', arm64, '53').
pp_predef('__LDBL_MAX_10_EXP__', arm64, '308').
pp_predef('__LDBL_MAX_EXP__', arm64, '1024').
pp_predef('__LDBL_MAX__', arm64, '1.7976931348623157e+308L').
pp_predef('__LDBL_MIN_10_EXP__', arm64, '(-307)').
pp_predef('__LDBL_MIN_EXP__', arm64, '(-1021)').
pp_predef('__LDBL_MIN__', arm64, '2.2250738585072014e-308L').
pp_predef('__LDBL_NORM_MAX__', arm64, '1.7976931348623157e+308L').
pp_predef('__OBJC_BOOL_IS_BOOL', arm64, '1').
pp_predef('__SIZEOF_LONG_DOUBLE__', arm64, '8').
pp_predef('__aarch64__', arm64, '1').
pp_predef('__arm64', arm64, '1').
pp_predef('__arm64__', arm64, '1').
%% LINUX ON AARCH64 (0.131), asked before `any' for --target=aarch64-linux-gnu (pp_target_table/1): clang 18's own
%% `-dM -E' where it differs from what the tables answer -- an IEEE quad long double, an unsigned char and wchar_t, the
%% generic armv8's features, none of Apple's names. `$undef' is no macro. Since 0.194 also what Linux has on either
%% machine (below, the x86-64 table): the 64-bit types spelled `long', no `__USER_LABEL_PREFIX__', an unsigned `wint_t'.
pp_predef('__AARCH64_SIMD__', linux_arm64, '$undef').
pp_predef('__ARM64_ARCH_8__', linux_arm64, '$undef').
pp_predef('__ARM_ACLE', linux_arm64, '200').
pp_predef('__ARM_FEATURE_AES', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_ATOMICS', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_COMPLEX', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_CRC32', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_CRYPTO', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_DOTPROD', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_FP16_FML', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_FP16_SCALAR_ARITHMETIC', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_FP16_VECTOR_ARITHMETIC', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_JCVT', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_PAUTH', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_QRDMX', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_RCPC', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_SHA2', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_SHA3', linux_arm64, '$undef').
pp_predef('__ARM_FEATURE_SHA512', linux_arm64, '$undef').
pp_predef('__ARM_NEON_SVE_BRIDGE', linux_arm64, '$undef').
pp_predef('__ARM_NEON__', linux_arm64, '$undef').
pp_predef('__ARM_PREFETCH_RANGE', linux_arm64, '$undef').
pp_predef('__BIGGEST_ALIGNMENT__', linux_arm64, '16').
pp_predef('__CHAR_UNSIGNED__', linux_arm64, '1').
pp_predef('__FUNCTION_MULTI_VERSIONING_SUPPORT_LEVEL', linux_arm64, '$undef').
pp_predef('__HAVE_FUNCTION_MULTI_VERSIONING', linux_arm64, '$undef').
pp_predef('__LDBL_DECIMAL_DIG__', linux_arm64, '36').
pp_predef('__LDBL_DENORM_MIN__', linux_arm64, '6.47517511943802511092443895822764655e-4966L').
pp_predef('__LDBL_DIG__', linux_arm64, '33').
pp_predef('__LDBL_EPSILON__', linux_arm64, '1.92592994438723585305597794258492732e-34L').
pp_predef('__LDBL_MANT_DIG__', linux_arm64, '113').
pp_predef('__LDBL_MAX_10_EXP__', linux_arm64, '4932').
pp_predef('__LDBL_MAX_EXP__', linux_arm64, '16384').
pp_predef('__LDBL_MAX__', linux_arm64, '1.18973149535723176508575932662800702e+4932L').
pp_predef('__LDBL_MIN_10_EXP__', linux_arm64, '(-4931)').
pp_predef('__LDBL_MIN_EXP__', linux_arm64, '(-16381)').
pp_predef('__LDBL_MIN__', linux_arm64, '3.36210314311209350626267781732175260e-4932L').
pp_predef('__LDBL_NORM_MAX__', linux_arm64, '1.18973149535723176508575932662800702e+4932L').
pp_predef('__OBJC_BOOL_IS_BOOL', linux_arm64, '0').
pp_predef('__REGISTER_PREFIX__', linux_arm64, '$undef').
pp_predef('__SIZEOF_LONG_DOUBLE__', linux_arm64, '16').
pp_predef('__WCHAR_MAX__', linux_arm64, '4294967295U').
pp_predef('__WCHAR_TYPE__', linux_arm64, 'unsigned int').
pp_predef('__WCHAR_UNSIGNED__', linux_arm64, '1').
pp_predef('__arm64', linux_arm64, '$undef').
pp_predef('__arm64__', linux_arm64, '$undef').
pp_predef('__INT64_C_SUFFIX__', linux_arm64, 'L').
pp_predef('__INT64_C(c)', linux_arm64, 'c##L').
pp_predef('__UINT64_C(c)', linux_arm64, 'c##UL').
pp_predef('__INT64_FMTd__', linux_arm64, '"ld"').
pp_predef('__INT64_FMTi__', linux_arm64, '"li"').
pp_predef('__INT64_MAX__', linux_arm64, '9223372036854775807L').
pp_predef('__INT64_TYPE__', linux_arm64, 'long int').
pp_predef('__INT_FAST64_FMTd__', linux_arm64, '"ld"').
pp_predef('__INT_FAST64_FMTi__', linux_arm64, '"li"').
pp_predef('__INT_FAST64_MAX__', linux_arm64, '9223372036854775807L').
pp_predef('__INT_FAST64_TYPE__', linux_arm64, 'long int').
pp_predef('__INT_LEAST64_FMTd__', linux_arm64, '"ld"').
pp_predef('__INT_LEAST64_FMTi__', linux_arm64, '"li"').
pp_predef('__INT_LEAST64_MAX__', linux_arm64, '9223372036854775807L').
pp_predef('__INT_LEAST64_TYPE__', linux_arm64, 'long int').
pp_predef('__NO_MATH_ERRNO__', linux_arm64, '$undef').
pp_predef('__SIG_ATOMIC_MIN__', linux_arm64, '$undef').
pp_predef('__SIG_ATOMIC_TYPE__', linux_arm64, '$undef').
pp_predef('__UINT64_C_SUFFIX__', linux_arm64, 'UL').
pp_predef('__UINT64_FMTX__', linux_arm64, '"lX"').
pp_predef('__UINT64_FMTo__', linux_arm64, '"lo"').
pp_predef('__UINT64_FMTu__', linux_arm64, '"lu"').
pp_predef('__UINT64_FMTx__', linux_arm64, '"lx"').
pp_predef('__UINT64_MAX__', linux_arm64, '18446744073709551615UL').
pp_predef('__UINT64_TYPE__', linux_arm64, 'long unsigned int').
pp_predef('__UINT_FAST64_FMTX__', linux_arm64, '"lX"').
pp_predef('__UINT_FAST64_FMTo__', linux_arm64, '"lo"').
pp_predef('__UINT_FAST64_FMTu__', linux_arm64, '"lu"').
pp_predef('__UINT_FAST64_FMTx__', linux_arm64, '"lx"').
pp_predef('__UINT_FAST64_MAX__', linux_arm64, '18446744073709551615UL').
pp_predef('__UINT_FAST64_TYPE__', linux_arm64, 'long unsigned int').
pp_predef('__UINT_LEAST64_FMTX__', linux_arm64, '"lX"').
pp_predef('__UINT_LEAST64_FMTo__', linux_arm64, '"lo"').
pp_predef('__UINT_LEAST64_FMTu__', linux_arm64, '"lu"').
pp_predef('__UINT_LEAST64_FMTx__', linux_arm64, '"lx"').
pp_predef('__UINT_LEAST64_MAX__', linux_arm64, '18446744073709551615UL').
pp_predef('__UINT_LEAST64_TYPE__', linux_arm64, 'long unsigned int').
pp_predef('__USER_LABEL_PREFIX__', linux_arm64, '').
pp_predef('__WCHAR_MIN__', linux_arm64, '$undef').
pp_predef('__WINT_MAX__', linux_arm64, '4294967295U').
pp_predef('__WINT_MIN__', linux_arm64, '$undef').
pp_predef('__WINT_TYPE__', linux_arm64, 'unsigned int').
pp_predef('__WINT_UNSIGNED__', linux_arm64, '1').
pp_predef('__clang_literal_encoding__', linux_arm64, '"UTF-8"').
pp_predef('__clang_wide_literal_encoding__', linux_arm64, '"UTF-32"').
pp_predef('__nonnull', linux_arm64, '$undef').
pp_predef('__null_unspecified', linux_arm64, '$undef').
pp_predef('__nullable', linux_arm64, '$undef').
%% LINUX ON X86-64 (0.194), asked before `any' (pp_target_table/1): clang 22's `-dM -E' on this machine where it differs
%% from what the other tables answer, which were taken from a clang on macOS -- the 64-bit types are `long' (`ld'
%% formats, `L' constants), `__USER_LABEL_PREFIX__' is empty (glibc's asm labels spell it), `wint_t' is unsigned (the
%% shipped library's `char_traits<wchar_t>::int_type', `j' in a symbol: `wistringstream::ignore' did not link), the
%% default CPU is the k8 (no SSE3, SSSE3, SSE4.1, LAHF and 16-byte compare-and-swap), math errno is on, and Apple's
%% nullability spellings `__nonnull' and kin are no macros (glibc defines `__nonnull(params)' itself). Made by a script
%% (o279/gentab.py in HISTORY.md's 0.194): a macro whose value differs between C and C++ is the language tables'.
pp_predef('__GCC_HAVE_SYNC_COMPARE_AND_SWAP_16', linux_x86_64, '$undef').
pp_predef('__INT64_C_SUFFIX__', linux_x86_64, 'L').
pp_predef('__INT64_C(c)', linux_x86_64, 'c##L').
pp_predef('__UINT64_C(c)', linux_x86_64, 'c##UL').
pp_predef('__INT64_FMTd__', linux_x86_64, '"ld"').
pp_predef('__INT64_FMTi__', linux_x86_64, '"li"').
pp_predef('__INT64_MAX__', linux_x86_64, '9223372036854775807L').
pp_predef('__INT64_TYPE__', linux_x86_64, 'long int').
pp_predef('__INT_FAST64_FMTd__', linux_x86_64, '"ld"').
pp_predef('__INT_FAST64_FMTi__', linux_x86_64, '"li"').
pp_predef('__INT_FAST64_MAX__', linux_x86_64, '9223372036854775807L').
pp_predef('__INT_FAST64_TYPE__', linux_x86_64, 'long int').
pp_predef('__INT_LEAST64_FMTd__', linux_x86_64, '"ld"').
pp_predef('__INT_LEAST64_FMTi__', linux_x86_64, '"li"').
pp_predef('__INT_LEAST64_MAX__', linux_x86_64, '9223372036854775807L').
pp_predef('__INT_LEAST64_TYPE__', linux_x86_64, 'long int').
pp_predef('__LAHF_SAHF__', linux_x86_64, '$undef').
pp_predef('__NO_MATH_ERRNO__', linux_x86_64, '$undef').
pp_predef('__SIG_ATOMIC_MIN__', linux_x86_64, '$undef').
pp_predef('__SIG_ATOMIC_TYPE__', linux_x86_64, '$undef').
pp_predef('__SSE3__', linux_x86_64, '$undef').
pp_predef('__SSE4_1__', linux_x86_64, '$undef').
pp_predef('__SSSE3__', linux_x86_64, '$undef').
pp_predef('__UINT64_C_SUFFIX__', linux_x86_64, 'UL').
pp_predef('__UINT64_FMTX__', linux_x86_64, '"lX"').
pp_predef('__UINT64_FMTo__', linux_x86_64, '"lo"').
pp_predef('__UINT64_FMTu__', linux_x86_64, '"lu"').
pp_predef('__UINT64_FMTx__', linux_x86_64, '"lx"').
pp_predef('__UINT64_MAX__', linux_x86_64, '18446744073709551615UL').
pp_predef('__UINT64_TYPE__', linux_x86_64, 'long unsigned int').
pp_predef('__UINT_FAST64_FMTX__', linux_x86_64, '"lX"').
pp_predef('__UINT_FAST64_FMTo__', linux_x86_64, '"lo"').
pp_predef('__UINT_FAST64_FMTu__', linux_x86_64, '"lu"').
pp_predef('__UINT_FAST64_FMTx__', linux_x86_64, '"lx"').
pp_predef('__UINT_FAST64_MAX__', linux_x86_64, '18446744073709551615UL').
pp_predef('__UINT_FAST64_TYPE__', linux_x86_64, 'long unsigned int').
pp_predef('__UINT_LEAST64_FMTX__', linux_x86_64, '"lX"').
pp_predef('__UINT_LEAST64_FMTo__', linux_x86_64, '"lo"').
pp_predef('__UINT_LEAST64_FMTu__', linux_x86_64, '"lu"').
pp_predef('__UINT_LEAST64_FMTx__', linux_x86_64, '"lx"').
pp_predef('__UINT_LEAST64_MAX__', linux_x86_64, '18446744073709551615UL').
pp_predef('__UINT_LEAST64_TYPE__', linux_x86_64, 'long unsigned int').
pp_predef('__USER_LABEL_PREFIX__', linux_x86_64, '').
pp_predef('__WCHAR_MIN__', linux_x86_64, '$undef').
pp_predef('__WINT_MAX__', linux_x86_64, '4294967295U').
pp_predef('__WINT_MIN__', linux_x86_64, '$undef').
pp_predef('__WINT_TYPE__', linux_x86_64, 'unsigned int').
pp_predef('__WINT_UNSIGNED__', linux_x86_64, '1').
pp_predef('__clang_literal_encoding__', linux_x86_64, '"UTF-8"').
pp_predef('__clang_wide_literal_encoding__', linux_x86_64, '"UTF-32"').
pp_predef('__core2', linux_x86_64, '$undef').
pp_predef('__core2__', linux_x86_64, '$undef').
pp_predef('__k8', linux_x86_64, '1').
pp_predef('__k8__', linux_x86_64, '1').
pp_predef('__nonnull', linux_x86_64, '$undef').
pp_predef('__null_unspecified', linux_x86_64, '$undef').
pp_predef('__nullable', linux_x86_64, '$undef').
pp_predef('__tune_core2__', linux_x86_64, '$undef').
pp_predef('__tune_k8__', linux_x86_64, '1').
%% C++ ON LINUX (0.194), asked in C++ after the target's and the platform's tables: clang++ predefines `_GNU_SOURCE'
%% there, as g++ does, so glibc declares its GNU extensions to C++ (libc++'s condition_variable::wait_until calls
%% pthread_cond_clockwait, which glibc declares under __USE_GNU)
pp_predef('_GNU_SOURCE', cpp_linux, '1').
%% AN ISO MODE PREDEFINES __STRICT_ANSI__ (0.214), as clang does under -std=c17, c23, c++17 ... and not under gnu17, gnu23,
%% gnu++17 or no -std: glibc then defines no _DEFAULT_SOURCE in C, and declares ISO C's names alone (`strdup' before C23,
%% `htobe32', `M_PI' are POSIX's and BSD's), where it declared every name in every mode; in C++ the _GNU_SOURCE that clang++
%% predefines on Linux keeps them
pp_predef('__STRICT_ANSI__', iso, '1').
%% ... AND A GNU MODE HAS NAMES OF ITS OWN (0.214), the tables pp_gnu_table/1 names, as clang has them: `linux' and `unix',
%% the spelling outside the implementation's names, which an ISO mode leaves to the program (Linux only), and in C++ g++'s
%% `__GLIBCXX_TYPE_INT_N_0', `__int128' as libstdc++'s extended integer type; every mode predefined them
pp_predef(linux, gnu_linux, '1').
pp_predef(unix, gnu_linux, '1').
pp_predef('__GLIBCXX_BITSIZE_INT_N_0', cpp_gnu, '128').
pp_predef('__GLIBCXX_TYPE_INT_N_0', cpp_gnu, '__int128').
pp_predef('__DEPRECATED', cpp, '1').
%% EXCEPTIONS, AS clang++ HAS THEM (0.193, the owner's decision of 0.190): `#if defined(__cpp_exceptions) &&
%% __cpp_exceptions >= 199711L' decides libc++'s exceptions configuration (_LIBCPP_HAS_NO_EXCEPTIONS in libc++ 18,
%% _LIBCPP_HAS_EXCEPTIONS in 21), and both macros are the table `cpp_eh''s, which pp_predef_macro/3 asks unless the
%% build says -fno-exceptions ('$ccl_exceptions' = no): then libc++ builds its no-exceptions configuration, where a
%% thrower in its headers' code aborts with a message, as this compiler built it from 0.50 to 0.192. A program's own
%% `throw', `try' and `catch' run since 0.108.
pp_predef('__EXCEPTIONS', cpp_eh, '1').
pp_predef('__GNUC_GNU_INLINE__', cpp, '1').
pp_predef('__GNUG__', cpp, '4').
pp_predef('__GXX_EXPERIMENTAL_CXX0X__', cpp, '1').
%% RTTI, AS clang++ HAS IT (0.191, the owner's decision of 0.190): `#if defined(__cpp_rtti) && __cpp_rtti >= 199711L'
%% decides libc++'s _LIBCPP_HAS_RTTI, and both macros are the table `cpp_rtti''s, which pp_predef_macro/3 asks unless
%% the build says -fno-rtti ('$ccl_rtti' = no): then libc++ builds its own no-RTTI configuration, as -fno-rtti gives
%% it. Four headers change (`any', `exception_ptr', `shared_ptr', `function'); the VTABLES do not --
%% `__shared_weak_count::__get_deleter' is declared unconditionally and only the derived override is guarded, so the
%% control blocks lay out as the shipped library's either way. From 0.86 to 0.190 neither macro was predefined, since
%% nothing here made a type_info then; the program's own `typeid' and `dynamic_cast' run since 0.108.
pp_predef('__GXX_RTTI', cpp_rtti, '1').
%% `__OPTIMIZE_SIZE__' IS NOT PREDEFINED (0.162), as clang predefines it only at -Os and -Oz: libc++ 21 vectorizes its
%% `mismatch' (and the `lexicographical_compare' and `operator<' of integers built on it) behind `_LIBCPP_HAS_ALGORITHM_VECTOR_UTILS
%% && !defined(__OPTIMIZE_SIZE__)', over `__attribute__((__ext_vector_type__(N)))' types and the vector builtins, which this
%% compiler reads and lowers since 0.162. From 0.92 to 0.161 it was predefined in C++ to keep that road off, since nothing
%% here read a vector type; libc++ 18 reads the macro nowhere.
pp_predef('__GXX_WEAK__', cpp, '1').
pp_predef('__STDCPP_DEFAULT_NEW_ALIGNMENT__', cpp, '16UL').
pp_predef('__STDCPP_THREADS__', cpp, '1').
pp_predef('__cplusplus', cpp, '201703L').
pp_predef('__cpp_aggregate_bases', cpp, '201603L').
pp_predef('__cpp_aggregate_nsdmi', cpp, '201304L').
pp_predef('__cpp_alias_templates', cpp, '200704L').
pp_predef('__cpp_aligned_new', cpp, '201606L').
pp_predef('__cpp_attributes', cpp, '200809L').
pp_predef('__cpp_binary_literals', cpp, '201304L').
pp_predef('__cpp_capture_star_this', cpp, '201603L').
pp_predef('__cpp_constexpr', cpp, '201603L').
pp_predef('__cpp_constexpr_in_decltype', cpp, '201711L').
pp_predef('__cpp_decltype', cpp, '200707L').
pp_predef('__cpp_decltype_auto', cpp, '201304L').
pp_predef('__cpp_deduction_guides', cpp, '201703L').
pp_predef('__cpp_delegating_constructors', cpp, '200604L').
pp_predef('__cpp_deleted_function', cpp, '202403L').
pp_predef('__cpp_digit_separators', cpp, '201309L').
pp_predef('__cpp_enumerator_attributes', cpp, '201411L').
pp_predef('__cpp_exceptions', cpp_eh, '199711L').   % see EXCEPTIONS above
pp_predef('__cpp_fold_expressions', cpp, '201603L').
pp_predef('__cpp_generic_lambdas', cpp, '201304L').
pp_predef('__cpp_guaranteed_copy_elision', cpp, '201606L').
pp_predef('__cpp_hex_float', cpp, '201603L').
pp_predef('__cpp_if_constexpr', cpp, '201606L').
pp_predef('__cpp_impl_destroying_delete', cpp, '201806L').
pp_predef('__cpp_inheriting_constructors', cpp, '201511L').
pp_predef('__cpp_init_captures', cpp, '201304L').
pp_predef('__cpp_initializer_lists', cpp, '200806L').
pp_predef('__cpp_inline_variables', cpp, '201606L').
pp_predef('__cpp_lambdas', cpp, '200907L').
pp_predef('__cpp_named_character_escapes', cpp, '202207L').   % P2071's value (0.194): 202606L was no value a clang has
pp_predef('__cpp_namespace_attributes', cpp, '201411L').
pp_predef('__cpp_nested_namespace_definitions', cpp, '201411L').
pp_predef('__cpp_noexcept_function_type', cpp, '201510L').
pp_predef('__cpp_nontype_template_args', cpp, '201411L').
pp_predef('__cpp_nontype_template_parameter_auto', cpp, '201606L').
pp_predef('__cpp_nsdmi', cpp, '200809L').
pp_predef('__cpp_pack_indexing', cpp, '202311L').
pp_predef('__cpp_placeholder_variables', cpp, '202306L').
pp_predef('__cpp_range_based_for', cpp, '201603L').
pp_predef('__cpp_raw_strings', cpp, '200710L').
pp_predef('__cpp_ref_qualifiers', cpp, '200710L').
pp_predef('__cpp_return_type_deduction', cpp, '201304L').
pp_predef('__cpp_rtti', cpp_rtti, '199711L').   % see RTTI above
pp_predef('__cpp_rvalue_references', cpp, '200610L').
pp_predef('__cpp_sized_deallocation', cpp, '201309L').
pp_predef('__cpp_static_assert', cpp, '202306L').
pp_predef('__cpp_static_call_operator', cpp, '202207L').
pp_predef('__cpp_structured_bindings', cpp, '202411L').
pp_predef('__cpp_template_auto', cpp, '201606L').
pp_predef('__cpp_template_template_args', cpp, '201611L').
pp_predef('__cpp_threadsafe_static_init', cpp, '200806L').
pp_predef('__cpp_trivial_relocatability', cpp, '202502L').
pp_predef('__cpp_unicode_characters', cpp, '200704L').
pp_predef('__cpp_unicode_literals', cpp, '200710L').
pp_predef('__cpp_user_defined_literals', cpp, '200809L').
pp_predef('__cpp_variable_templates', cpp, '201304L').
pp_predef('__cpp_variadic_friend', cpp, '202403L').
pp_predef('__cpp_variadic_templates', cpp, '200704L').
pp_predef('__cpp_variadic_using', cpp, '201611L').
pp_predef('__private_extern__', cpp, 'extern').
%% the levels above C++17, from the reference compiler's -dM -E at each (2026-09-06): what appears or changes
pp_predef('__cplusplus', cpp20, '202002L').
pp_predef('__CLANG_ATOMIC_CHAR8_T_LOCK_FREE', cpp20, '2').
pp_predef('__GCC_ATOMIC_CHAR8_T_LOCK_FREE', cpp20, '2').
pp_predef('__cpp_aggregate_paren_init', cpp20, '201902L').
pp_predef('__cpp_char8_t', cpp20, '202207L').
pp_predef('__cpp_concepts', cpp20, '202002').
pp_predef('__cpp_conditional_explicit', cpp20, '201806L').
pp_predef('__cpp_consteval', cpp20, '202211L').
pp_predef('__cpp_constexpr', cpp20, '202002L').
pp_predef('__cpp_constexpr_dynamic_alloc', cpp20, '201907L').
pp_predef('__cpp_constinit', cpp20, '201907L').
pp_predef('__cpp_designated_initializers', cpp20, '201707L').
pp_predef('__cpp_generic_lambdas', cpp20, '201707L').
pp_predef('__cpp_impl_coroutine', cpp20, '201902L').
pp_predef('__cpp_impl_three_way_comparison', cpp20, '201907L').
pp_predef('__cpp_init_captures', cpp20, '201803L').
pp_predef('__cpp_modules', cpp20, '1').
pp_predef('__cpp_using_enum', cpp20, '201907L').
pp_predef('__cplusplus', cpp23, '202302L').
pp_predef('__cpp_auto_cast', cpp23, '202110L').
pp_predef('__cpp_constexpr', cpp23, '202211L').
pp_predef('__cpp_explicit_this_parameter', cpp23, '202110L').
pp_predef('__cpp_if_consteval', cpp23, '202106L').
pp_predef('__cpp_implicit_move', cpp23, '202207L').
pp_predef('__cpp_multidimensional_subscript', cpp23, '202211L').
pp_predef('__cpp_range_based_for', cpp23, '202211L').
pp_predef('__cpp_size_t_suffix', cpp23, '202011L').
pp_predef('__cplusplus', cpp26, '202400L').
pp_predef('__cpp_constexpr', cpp26, '202406L').

%% ---- -E: the flattened stream spelled back as text ------------------------------
%% ccl_pp_spell(+Tokens, -Codes): one token after another, a space between, a
%% newline where the line changes (blank lines where lines were skipped, up to
%% three, so the text keeps some of the shape); a string with its escapes,
%% a char as its code, a number as its value with its suffix
ccl_pp_spell(Tokens, Codes) :- ccl_pp_spell_(Tokens, 0, Codes).
ccl_pp_spell_([], _, [10]).
ccl_pp_spell_([tok(K, V, L)|Ts], L0, Codes) :-
    ( L =:= L0 -> Codes = [32|C1] ; L0 =:= 0 -> Codes = C1 ; L - L0 > 3 -> Codes = [10, 10, 10|C1] ; L - L0 =:= 3 -> Codes = [10, 10|C1] ; Codes = [10|C1] ),   % a smaller line: another file begins
    ccl_pp_spell_tok(K, V, C1, C2), ccl_pp_spell_(Ts, L, C2).
ccl_pp_spell_tok(str, Cs, [34|Out], Rest) :- !, pp_escape(Cs, 34, esc, E), append(E, [34|Rest], Out).
ccl_pp_spell_tok(chr, C, [39|Out], Rest) :- !, pp_escape([C], 39, esc, E), append(E, [39|Rest], Out).
ccl_pp_spell_tok(u8str, Cs, [0'u, 0'8, 34|Out], Rest) :- !, pp_escape(Cs, 34, esc, E), append(E, [34|Rest], Out).   % u8"..." and u8'c', kinds of their own (0.196)
ccl_pp_spell_tok(u8chr, C, [0'u, 0'8, 39|Out], Rest) :- !, pp_escape([C], 39, esc, E), append(E, [39|Rest], Out).
ccl_pp_spell_tok(K, Cs, [P, 34|Out], Rest) :- pp_str_prefix(K, [P]), !, pp_escape(Cs, 34, esc, E), append(E, [34|Rest], Out).   % THE PREFIXED LITERALS SPELL WITH THEIR PREFIX (0.93): `L"true"' came out as a code list in the flattened text, which no reader takes -- the census's road, not the gate's, which reads the tokens
ccl_pp_spell_tok(K, C, [P, 39|Out], Rest) :- pp_chr_prefix(K, [P]), !, pp_escape([C], 39, esc, E), append(E, [39|Rest], Out).
ccl_pp_spell_tok(uint, N, Out, Rest) :- !, pp_int_codes(N, Cs), append(Cs, [0'u|Rest], Out).
ccl_pp_spell_tok(long, N, Out, Rest) :- !, pp_int_codes(N, Cs), append(Cs, [0'l|Rest], Out).
ccl_pp_spell_tok(ulong, N, Out, Rest) :- !, pp_int_codes(N, Cs), append(Cs, [0'u, 0'l|Rest], Out).
ccl_pp_spell_tok(llong, N, Out, Rest) :- !, pp_int_codes(N, Cs), append(Cs, [0'l, 0'l|Rest], Out).   % `9ll' and `9ull', kinds of their own (0.179)
ccl_pp_spell_tok(ullong, N, Out, Rest) :- !, pp_int_codes(N, Cs), append(Cs, [0'u, 0'l, 0'l|Rest], Out).
ccl_pp_spell_tok(bitint, N, Out, Rest) :- !, pp_int_codes(N, Cs), append(Cs, [0'w, 0'b|Rest], Out).        % C23's `wb' and `uwb' (0.93): the suffix was lost in the flattened text
ccl_pp_spell_tok(ubitint, N, Out, Rest) :- !, pp_int_codes(N, Cs), append(Cs, [0'u, 0'w, 0'b|Rest], Out).
ccl_pp_spell_tok(pp, A, [35|Out], Rest) :- !, atom_codes(A, Cs), append(Cs, Rest, Out).
ccl_pp_spell_tok(other, C, [C|Rest], Rest) :- !.   % a character that begins no token (0.210)
ccl_pp_spell_tok(cocolog, A, Out, Rest) :- !, atom_codes('#cocolog', H), atom_codes(A, Cs), atom_codes('#end', E), append(H, [10|Cs], O1), append(O1, [10|E], O2), append(O2, Rest, Out).
ccl_pp_spell_tok(imag, F, Out, Rest) :- !, number_codes(F, Cs), append(Cs, [0'i|Rest], Out).                   % the imaginary literal spelled back, `2.0i' (0.101)
ccl_pp_spell_tok(imagf, F, Out, Rest) :- !, number_codes(F, Cs), append(Cs, [0'i, 0'f|Rest], Out).
ccl_pp_spell_tok(imagl, A, Out, Rest) :- !, atom_codes(A, Cs), append(Cs, [0'i, 0'l|Rest], Out).   % a long double's text (0.154)
ccl_pp_spell_tok(K, N, Out, Rest) :- pp_imag_suffix(K, Sfx), !, pp_int_codes(N, Cs), append(Sfx, Rest, Tail), append(Cs, Tail, Out).
ccl_pp_spell_tok(floatf, F, Out, Rest) :- !, pp_float_codes(F, Cs), append(Cs, [0'f|Rest], Out).
ccl_pp_spell_tok(K, A, Out, Rest) :- pp_dec_suffix(K, Sfx), !, atom_codes(A, Cs), append(Sfx, Rest, R1), append(Cs, R1, Out).
ccl_pp_spell_tok(floatl, A, Out, Rest) :- !, atom_codes(A, Cs), append(Cs, [0'L|Rest], Out).   % a long double literal: its text (0.154)
ccl_pp_spell_tok(floatudl, fs(A, S), Out, Rest) :- !, atom_codes(A, C1), atom_codes(S, C2), append(C2, Rest, R1), append(C1, R1, Out).   % `0.1_v', the suffix right after the text (0.160)
ccl_pp_spell_tok(float, F, Out, Rest) :- !, pp_float_codes(F, Cs), append(Cs, Rest, Out).
ccl_pp_spell_tok(_, V, Out, Rest) :- ( atom(V) -> atom_codes(V, Cs) ; number_codes(V, Cs) ), append(Cs, Rest, Out).
pp_int_codes(big(A), Cs) :- !, atom_codes(A, Cs).                                    % a literal past 2^60 spells as its digits (0.94's big(Atom); 0.99: the flattened text had `big(0xff...)ul', which no reader takes -- the census's road only)
pp_int_codes(N, Cs) :- number_codes(N, Cs).
%% A FLOAT'S TEXT (0.143): cocolog writes the fewest digits that read back as the same double since 1.10.28, so a finite
%% value is spelled exactly; an infinity -- a literal past the largest double, which the lexer made infinite -- is
%% `1e999', which a C reader makes infinite again. Every value past 1.0e308 was spelled so before, against the 15 digits
%% cocolog wrote, and `__DBL_MAX__' and `1.5e308' became infinities in the text of `-E'
pp_float_codes(F, Cs) :- F > 1.7976931348623157e308, !, atom_codes('1e999', Cs).
pp_float_codes(F, Cs) :- F < -1.7976931348623157e308, !, atom_codes('-1e999', Cs).
pp_float_codes(F, Cs) :- number_codes(F, Cs).
ccl_pp_hexn(0, [0'0]) :- !.
ccl_pp_hexn(C, Hs) :- ccl_pp_hexn_(C, [], Hs).
ccl_pp_hexn_(0, Acc, Acc) :- !.
ccl_pp_hexn_(C, Acc, Hs) :- D is C mod 16, C1 is C // 16, ccl_pp_hexd(D, H), ccl_pp_hexn_(C1, [H|Acc], Hs).
ccl_pp_hexd(D, H) :- ( D < 10 -> H is 0'0 + D ; H is 0'a + D - 10 ).
