%% cicilang -- library(ccl_include): an #include, found on the inclusion
%% path and read into an AST of its own, as the including file is parsed.
%%
%% When the parser (library(ccl_syntax)) meets `#include <name>' or
%% `#include "name"' at file scope it calls ccl_include/2 here, which finds
%% the file and reads it with the same reader -- recursively, since that
%% file's includes are met the same way -- and the includer's AST holds
%%
%%   include(Line, Spec, Resolved)
%%     Spec      system(Name) for <name>, local(Name) for "name"
%%     Resolved  file(Path, How, Unit) | macros(Path, Preds) | missing | cyclic(Path)
%%     How       raw           the file as written read whole, and that is its AST
%%               preprocessed  raw did not read whole (a system header is
%%                             conditionals and macros the reader does not expand),
%%                             so THAT FILE went through the preprocessor,
%%                             library(ccl_pp) -- cocolog's own -- and the result read
%%               unreadable    neither read: a lexical error
%%     Unit      unit(Items) | partial(unit(Items), line(L), near(F)) | none
%%
%% and the typedef names the included unit declares are known to the rest
%% of the including file. A header is read once per process (a global by
%% path) and never twice on one path (cyclic).
%%
%% THE INCLUSION PATH, in order: the including file's directory (for a
%% quoted name only), then ccl_include_dir/1 facts, then $CICILANG_INCLUDE
%% split on colons, then $COCOLOG_LIBRARY's directories (the macro files
%% this repository ships), then the toolchain's directories from where the
%% conventions put them (ccl_toolchain_dirs/1: the C++ library, this
%% compiler's own library/include, /usr/local/include, the SDK -- no tool
%% is run), cached; ccl_include_path_reset/0 forgets it.
%%
%% THE CACHE: a file read whole -- the one cicilang_ast/2 was given, and every
%% include -- is remembered in the knowledge base keyed by its modification
%% time and the reader's version, one clause per top-level item, so under
%% --embed it is in the store for the next process and is loaded from there
%% instead of re-read while time_file/2 answers the same time (and every
%% header it includes is at its remembered time too). A bare --embed opens
%% ./KB in the working directory: run cocolog with it from the project
%% directory and each system header is parsed once per project.
%%
%% THE SURFACE:
%%   ccl_read_file(+File, -AST, -Rest)      the top of cicilang_ast/3
%%   ccl_kb_forget                          drop every remembered file
%%   ccl_kb_forget_file(+Path)              drop one
%%   ccl_include(+Spec, -Resolved)          one include, from the current file
%%   ccl_include_path(-Dirs)                the inclusion path in force
%%   ccl_include_path_reset                 forget the cached toolchain list
%%   ccl_include_dir(?Dir)                  dynamic: assert a -I directory
%%   ccl_load_macros(+PlPath, -Preds)       load a macro file, register its predicates
%%   ccl_standard_macros                    register format/print/println (every unit does)
%%   ccl_declares(+Unit, +Name, -Item)      the function, declaration or typedef
%%                                          of Name, in the unit or any include
%%   ccl_unit_typedefs(+Unit, -Names)       every typedef name, includes too

:- use_module(library(ccl_syntax)).
:- use_module(library(ccl_infer)).
:- use_module(library(ccl_pp)).
:- use_module(library(process)).
:- use_module(library(os)).
:- dynamic ccl_include_dir/1.

%% ---- what lives only in this process ----------------------------------------
%% A `:- dynamic' here PERSISTS under the store (see RULES.md), so the units
%% read in this process, the files being read (the cycle guard) and the macro
%% files loaded are globals, not clauses: nb_setval/2 is the process's own.
ccl_unit_cached(Path, How, Unit) :- ccl_unit_key(Path, K), ccl_global('$ccl_unit_paths', Ps, []), memberchk(K, Ps), nb_getval(K, How-Unit).
ccl_unit_cache(Path, How, Unit) :- ccl_unit_key(Path, K), nb_setval(K, How-Unit), ccl_global('$ccl_unit_paths', Ps, []), nb_setval('$ccl_unit_paths', [K|Ps]).
%% A UNIT IS READ ONCE PER PROCESS AT EACH LEVEL (0.99): the key carries the language's level, since a header's forms are the
%% level's -- `<stddef.h>' read for a C17 fixture and served to a C23 one in the same process gave it `typeof(id(nullptr))' for
%% `nullptr_t' (the compile gate builds every fixture in one process, and the new `atomic.c' put a C17 read of the header first)
ccl_unit_key(Path, K) :- ccl_read_level(Std), atomic_list_concat(['$ccl_unit:', Path, '@', Std], K).
%% THE READ'S LEVEL, in each key of a read -- the unit cache, the header macros' memo, the store: C++'s level, or C's with
%% `t' where trigraphs are read and `i' in an ISO mode (0.214: __STRICT_ANSI__ changes what glibc declares in C, and
%% -std=c23 and -std=gnu23 read one key). C++'s keys and its summaries' take no mode: neither libc++ nor glibc under the
%% _GNU_SOURCE that clang++ predefines reads otherwise for it
ccl_read_level(Std) :- ( ccl_lang(cpp) -> ccl_std(S1) ; ccl_c_std(S0), ( nb_current('$ccl_trigraphs', yes) -> T = t ; T = '' ), ( nb_current('$ccl_iso', yes) -> I = i ; I = '' ), atomic_list_concat([S0, T, I], S1) ),
    ccl_ftm_tag(F), ( F == '' -> Std = S1 ; atom_concat(S1, F, Std) ).
%% ... AND THE PROGRAM'S FEATURE-TEST MACROS (0.214; '$pp_ftm', pp_ftm_find/1), folded: a header read under the file's
%% `_POSIX_C_SOURCE' is another read, in both languages; nothing where the file defines none
ccl_ftm_tag(T) :- ( nb_current('$pp_ftm', L), L \== [] -> term_to_atom(L, A), atom_codes(A, Cs), ccl_fold(Cs, 7, 131, S1), ccl_fold(Cs, 13, 137, S2), atomic_list_concat(['@f', S1, '-', S2], T) ; T = '' ).
ccl_reading(Path) :- ccl_global('$ccl_reading', L, []), memberchk(Path, L).
ccl_reading_push(Path) :- ccl_global('$ccl_reading', L, []), nb_setval('$ccl_reading', [Path|L]).
ccl_reading_pop(Path) :- ccl_global('$ccl_reading', L, []), ccl_delete_one(L, Path, L1), nb_setval('$ccl_reading', L1).
ccl_delete_one([], _, []).
ccl_delete_one([X|T], X, T) :- !.
ccl_delete_one([Y|T], X, [Y|T1]) :- ccl_delete_one(T, X, T1).
ccl_macro_loaded(Path, Preds) :- ccl_global('$ccl_macro_files', L, []), memberchk(Path-Preds, L).
ccl_macro_note(Path, Preds) :- ccl_global('$ccl_macro_files', L, []), nb_setval('$ccl_macro_files', [Path-Preds|L]).
%% THE FILES THAT A MACRO FILE LOADS BY A DIRECTIVE ARE ITS UNIT'S TOO (0.282): a macro file may load another -- ccllib's
%% <set.pl> has `:- ensure_loaded(library(ccllib/tree)).' -- and what a unit holds comes from that file's clauses as from
%% the macro file's own. ccl_macro_loads(+Path, -Files) gives each file that Path loads so, at any depth: library(Dir/Name)
%% is found on $COCOLOG_LIBRARY, another name beside the file that loads it. A unit kept in the store, its IR there and a
%% C++ file's kept IR name these files with the macro file (ccl_kb_flatten/4, ccl_kb_macro_deps/3, dr_items_deps/2). Until
%% 0.282 they named the macro file alone: tree.pl changed, and a program over <set.pl> was served its old IR. The answer
%% is kept for the process
ccl_macro_loads(Path, Files) :-
    ccl_global('$ccl_macro_loads', L, []),
    (   memberchk(Path-Fs, L) -> Files = Fs
    ;   ccl_macro_loads_([Path], [Path], All), ccl_delete_one(All, Path, Fs0), sort(Fs0, Files),
        nb_setval('$ccl_macro_loads', [Path-Files|L]) ).
ccl_macro_loads_([], Seen, Seen).
ccl_macro_loads_([P|Ps], Seen, All) :-
    ccl_macro_loads_of(P, Fs), ccl_new_files(Fs, Seen, New), append(Seen, New, Seen1), append(Ps, New, Todo),
    ccl_macro_loads_(Todo, Seen1, All).
ccl_new_files([], _, []).
ccl_new_files([F|Fs], Seen, New) :- ( memberchk(F, Seen) -> New = New1 ; New = [F|New1] ), ccl_new_files(Fs, [F|Seen], New1).
%% what one file loads: each `:- ensure_loaded(S).', `:- consult(S).', `:- use_module(S).', `:- include(S).' and
%% `:- [S].' of its text, S one name or a list; a name that is no file here is passed over
ccl_macro_loads_of(P, Fs) :-
    (   catch(read_file_to_codes(P, Codes), _, fail)
    ->  atom_codes(A, Codes), atomic_list_concat(Lines, '\n', A), ccl_pl_directives(Lines, Texts), ccl_pl_loads(Texts, P, Fs)
    ;   Fs = [] ).
%% the directives of a file's text, cheaply: a line that begins with `:-', with the four lines after it, is read as the
%% load reads a clause (ccl_pl_clauses/2), and its first clause is the directive. The file's other lines are not walked
%% character by character: ccllib's tree.pl has 600, and its split into clauses took 13 ms of each build over <set.pl>,
%% where the three files of <set.pl> take 3 ms so
ccl_pl_directives([], []).
ccl_pl_directives([L|Ls], Ts) :-
    (   sub_atom(L, 0, 2, _, ':-'), ccl_pl_window([L|Ls], 5, W), atomic_list_concat(W, '\n', A), atom_codes(A, Cs),
        ccl_pl_clauses(Cs, [T|_])
    ->  Ts = [T|Ts1]
    ;   Ts = Ts1 ),
    ccl_pl_directives(Ls, Ts1).
ccl_pl_window([], _, []) :- !.
ccl_pl_window(_, 0, []) :- !.
ccl_pl_window([L|Ls], N, [L|W]) :- N1 is N - 1, ccl_pl_window(Ls, N1, W).
ccl_pl_loads([], _, []).
ccl_pl_loads([Text|Ts], P, Fs) :-
    (   sub_atom(Text, 0, 2, _, ':-'), catch(term_to_atom(Term, Text), _, fail), nonvar(Term), Term = (:- G), nonvar(G),
        ccl_pl_load_goal(G, Specs)
    ->  ccl_pl_load_files(Specs, P, F1), ccl_pl_loads(Ts, P, F2), append(F1, F2, Fs)
    ;   ccl_pl_loads(Ts, P, Fs) ).
ccl_pl_load_goal(ensure_loaded(S), Ss) :- !, ccl_pl_specs(S, Ss).
ccl_pl_load_goal(consult(S), Ss) :- !, ccl_pl_specs(S, Ss).
ccl_pl_load_goal(use_module(S), Ss) :- !, ccl_pl_specs(S, Ss).
ccl_pl_load_goal(use_module(S, _), Ss) :- !, ccl_pl_specs(S, Ss).
ccl_pl_load_goal(include(S), Ss) :- !, ccl_pl_specs(S, Ss).
ccl_pl_load_goal([S|T], [S|T]).
ccl_pl_specs(S, Ss) :- ( is_list(S) -> Ss = S ; Ss = [S] ).
ccl_pl_load_files([], _, []).
ccl_pl_load_files([S|Ss], P, Fs) :- ( ccl_pl_load_file(S, P, F) -> Fs = [F|Fs1] ; Fs = Fs1 ), ccl_pl_load_files(Ss, P, Fs1).
ccl_pl_load_file(S, _, _) :- var(S), !, fail.
ccl_pl_load_file(library(S), _, F) :- !, ccl_pl_spec_path(S, Rel), ccl_library_dirs(Ds), member(D, Ds), ccl_pl_file_at(D, Rel, F), !.
ccl_pl_load_file(S, P, F) :- ccl_pl_spec_path(S, Rel), file_directory_name(P, D), ( ccl_pl_file_at(D, Rel, F) -> true ; ccl_pl_file_named(Rel, F) ), !.
ccl_pl_spec_path(S, _) :- var(S), !, fail.
ccl_pl_spec_path(A/B, P) :- !, ccl_pl_spec_path(A, PA), ccl_pl_spec_path(B, PB), atomic_list_concat([PA, '/', PB], P).
ccl_pl_spec_path(A, A) :- atom(A).
ccl_pl_file_at(D, Rel, F) :- atomic_list_concat([D, '/', Rel], F0), ccl_pl_file_named(F0, F).
ccl_pl_file_named(F0, F) :- ( exists_file(F0) -> F = F0 ; atom_concat(F0, '.pl', F), exists_file(F) ).

%% ---- the top ----------------------------------------------------------------
%% THE CACHE, as it must be under cocolog (a finding, in RULES.md): a
%% predicate with ONE clause over about 8 KB loses EVERY clause in the store,
%% silently -- so a unit is stored one clause per top-level item, with its
%% count, and an include inside it as a reference to the header's own cached
%% unit; '$ccl_ast'/3 is declared by ccl_kb_ready/0, a file's item predicate
%% by ccl_kb_items/2 (the '$ccl_item'(Path, ...) below reads '$ccl_items:Path'(...)):
%%      '$ccl_ast'(Path, Key, meta(What, Count, Deps))
%%      '$ccl_item'(Path, Key, Index, Item)     Item's include(L, S, file(P, How, U))
%%                                              stored as include(L, S, ref(P, How)), or
%%                                              ref(P, How, Cfg) under its own configuration (0.239)
%%    What is top | included(How) | included_partial(How, Line, Near); Deps is
%%    [DepPath-DepKey ...], each checked against the header's current key on
%%    load; a count that does not match (an item too big to store) is a miss.
ccl_kb_ready :- ccl_ensure_globals, ( nb_getval('$ccl_kb_ready', yes) -> true ; dynamic('$ccl_ast'/3), dynamic('$ccl_hmeta'/3), nb_setval('$ccl_kb_ready', yes) ).
%% The items of a file are a predicate of their own, '$ccl_items:<Path>'(Key,
%% Index, Item): the store grows, once per process that writes a predicate, by
%% about 500 bytes per row THAT predicate holds, whatever the write -- one
%% assertz into a 39k-row '$ccl_item'/4 cost 19.5 MB, and forty writing gate
%% processes made the 870 MB store. A source file's rows are written at every
%% change; in their own small predicate that costs one page.
ccl_kb_items(Path, F) :- atom_concat('$ccl_items:', Path, F), dynamic(F/3).
ccl_kb_items_goal(Path, K, I, It, T) :- ccl_kb_items(Path, F), T =.. [F, K, I, It].
ccl_kb_forget_items(Path) :- ccl_kb_items_goal(Path, _, _, _, T), retractall(T).
ccl_kb_forget_file(Path) :- ccl_kb_ready, retractall('$ccl_ast'(Path, _, _)), ccl_kb_forget_items(Path), retractall('$ccl_hmeta'(Path, _, _)), ccl_kb_hm(Path, F), T =.. [F, _, _, _], retractall(T).

ccl_read_file(File, AST, Rest) :- ccl_ensure_globals, ccl_set_lang(File), ( nb_current('$ccl_reading', []) -> nb_setval('$ccl_src_file', File), nb_setval('$ccl_path_cfgs', []), nb_setval('$pp_inc_cfgs', []), pp_ftm_find(File), dynamic('$ccl_plainfn'/2), retractall('$ccl_plainfn'(_, _)), ccl_inst_reset, ccl_set_clear('$ccl_btds') ; true ), ccl_read_file_(File, AST, Rest).   % the file as the compiler was given it: a source location's, and C's `__PRETTY_FUNCTION__' reads its text (0.166)
%% a unit's type macro instances (0.261): none at its start, each made once in it (ccl_tmacro_instance/5)
ccl_inst_reset :- nb_setval('$ccl_instances', []), nb_setval('$ccl_inst_making', []), nb_setval('$ccl_hoist', []).
%% the language of the file read: C++ by its extension (or forced, cicilang++), C by .c
ccl_set_lang(File) :-
    (   nb_getval('$ccl_lang_forced', F), F \== none -> nb_setval('$ccl_lang', F)
    ;   ccl_lang_of_file(File, L) -> nb_setval('$ccl_lang', L)
    ;   true ).
ccl_lang_of_file(F, cpp) :- member(E, ['.cpp', '.cc', '.cxx', '.C', '.hpp', '.hh', '.hxx', '.cppm', '.ccm', '.cxxm', '.ixx', '.mpp']), sub_atom(F, _, _, 0, E), !.   % a module interface unit's names too (0.108)
ccl_lang_of_file(F, c) :- sub_atom(F, _, _, 0, '.c'), !.
ccl_read_file_(File, AST, Rest) :-
    ccl_kb_cached(File, top, AST0), !, AST = AST0, Rest = [], nb_setval('$ccl_far', 0).
%% A FILE WHOSE OWN RUN CHANGED ITS CONFIGURATION IS NOT KEPT (0.215): its key in the store is made before its read,
%% under the feature-test macros found before its first system #include (pp_ftm_find/1), and a `__STDC_WANT_*' name it
%% defines after that changes them in its run (ccl_pp_top_run/4); kept under the key after the read, it was never served
%% and written again at every build. It is read at every build, its headers served from the store, its IR too (dr_ir/3).
%% NOR IS A READ THAT MADE OR MET A TYPE MACRO'S INSTANCE (0.261): what it holds is the unit's -- an instance stands where the
%% unit first used it, and a later use names it alone (ccl_tmacro_instance/5) -- so it is read again in each unit
ccl_read_file_(File, AST, Rest) :-
    ( nb_current('$pp_ftm', FT0) -> true ; FT0 = [] ), ccl_inst_mark(IM),
    catch(catch(catch(ccl_pp_top(File, Tokens, _), lexical(L), throw(error(syntax_error(cicilang_ast(File, lexical, line(L))), cicilang_ast(File)))), lexical_char(LC, C), throw(error(syntax_error(cicilang_ast(File, char(C), line(LC))), cicilang_ast(File)))),   % the user's file through the preprocessor
          pp_error(PL, PM), throw(error(pp_error(PM), here(File, PL)))),                                                                     % its own #error, an #embed of nothing
    ( nb_current('$ccl_reading', []) -> ccl_inst_reset ; true ),   % THE INSTANCES THAT THE PREPROCESSOR'S READS MADE ARE NOBODY'S (0.261): its run reads each header for its macros, and the parse reads one that met an instance again
    ccl_with_file(File, ( ccl_unit(Tokens, AST, Rest), ccl_farthest(F) )),
    nb_setval('$ccl_far', F),
    ( nb_current('$pp_ftm', FT1) -> true ; FT1 = [] ),
    ( Rest == [], FT1 == FT0, \+ ccl_inst_since(IM) -> ccl_kb_remember(File, top, AST) ; true ).

ccl_kb_key(Path, key(T, V)) :- once(catch(time_file(Path, T), _, fail)), ccl_reader_version(V0), ccl_read_level(L), ( ccl_lang(cpp) -> V = cpp(V0, L) ; L == '17' -> V = V0 ; V = c(V0, L) ).   % a C read at -std=c23 is not the C17 read: <stddef.h> declares nullptr_t and unreachable() at that level only, and the store serves a header's macros and items by this key
ccl_std(S) :- ( nb_current('$ccl_std', S0) -> S = S0 ; S = 17 ).   % a C++ read is not the C read; the time asked every time (0.4 ms): the gate touches a file mid-process and expects the miss
ccl_kb_forget :- ccl_kb_ready, findall(P, '$ccl_ast'(P, _, _), Ps), ccl_kb_forget_each(Ps), retractall('$ccl_ast'(_, _, _)).
ccl_kb_forget_each([]).
ccl_kb_forget_each([P|Ps]) :- ccl_kb_forget_items(P), ccl_kb_forget_each(Ps).

%% remember: What and a unit (or a partial one) -> meta + one clause per item
%% THIS LEVEL's ROWS ONLY (0.225), as a header's macros are kept (0.99): the read of a key's level replaces that level's
%% row and items, and the other levels' stay -- a C23 read of <stdio.h> took the place of its C17 read, and the next C17
%% build read it again (the reader gate's later process, 18 s over Apple's headers)
ccl_kb_remember(Path, What0, Unit) :-
    ccl_kb_ready,
    (   ccl_kb_key(Path, K)
    ->  ccl_kb_what(What0, Unit, What, Items),
        K = key(_, V), retractall('$ccl_ast'(Path, key(_, V), _)), ccl_kb_forget_level(Path, V),
        ccl_kb_items(Path, F), ( What0 == top -> nb_setval('$ccl_kb_top', yes) ; nb_setval('$ccl_kb_top', no) ),
        (   catch(ccl_kb_store_items(Items, F, K, 0, N, [], Deps0), error(resource_error(clause_length), _), fail)
        ->  ( What0 == top -> ccl_kb_macro_deps(Items, Deps0, Deps) ; Deps = Deps0 ),
            assertz('$ccl_ast'(Path, K, meta(What, N, Deps)))
        ;   % an item over the store's clause budget (cocolog 1.2: an error, no
            % longer a silent loss): this file is read again next time, not cached
            ccl_kb_forget_level(Path, V)
        )
    ;   true ).
ccl_kb_forget_level(Path, V) :- ccl_kb_items_goal(Path, key(_, V), _, _, T), retractall(T).
ccl_kb_what(top, unit(Is), top, Is) :- !.
ccl_kb_what(included(How), unit(Is), included(How), Is) :- !.
ccl_kb_what(included(How), partial(unit(Is), line(L), near(F)), included_partial(How, L, F), Is).
ccl_kb_store_items([], _, _, N, N, Deps, Deps).
ccl_kb_store_items([I|Is], F, K, N0, N, D0, Deps) :-
    ccl_kb_flatten(I, I0, D0, D1), ccl_float_freeze(I0, I1),   % a float kept exactly (0.132; ccl_float_freeze/2)
    T =.. [F, K, N0, I1], assertz(T),
    N1 is N0 + 1,
    ccl_kb_store_items(Is, F, K, N1, N, D1, Deps).
ccl_kb_flatten(include(L, S, file(P, How, _)), include(L, S, ref(P, How, Cfg)), D0, D) :- nb_current('$ccl_kb_top', yes), ccl_inc_cfg_at(L, Cfg),
    ( nb_current('$pp_ftm', C0) -> true ; C0 = [] ), Cfg \== C0, !,   % AN INCLUDE OF THE USER'S FILE UNDER A CONFIGURATION OF ITS OWN (0.239): kept, its key made under it
    ( pp_with_cfg(Cfg, ccl_kb_key(P, PK)) -> D = [cfg(P, Cfg)-PK|D0] ; D = D0 ).
ccl_kb_flatten(include(L, S, file(P, How, _)), include(L, S, ref(P, How)), D0, D) :- !,
    ( ccl_kb_key(P, PK) -> D = [P-PK|D0] ; D = D0 ).
ccl_kb_flatten(include(L, S, macros(P, Preds)), include(L, S, macros(P, Preds)), D0, D) :- !,
    ( ccl_kb_key(P, PK) -> D1 = [P-PK|D0] ; D1 = D0 ),
    ccl_macro_loads(P, Fs), ccl_kb_file_deps(Fs, D1, D).   % ... and the files that it loads by a directive (0.282)
ccl_kb_flatten(I, I, D, D).
ccl_kb_file_deps([], D, D).
ccl_kb_file_deps([F|Fs], D0, D) :- ( ccl_kb_key(F, K) -> D1 = [F-K|D0] ; D1 = D0 ), ccl_kb_file_deps(Fs, D1, D).
%% THE USER'S FILE NAMES EACH MACRO FILE THAT ITS INCLUDES REACH (0.282), at any depth, and what each loads: a macro's
%% call in it stands as its expansion, whichever header brought the macro file -- its own includes named that header
%% alone, whose time a change of the macro file leaves as it was. The files are the include nodes' of the units read
%% into it (ccl_unit_macro_files/2), so a file with no such include keeps the deps that it had
ccl_kb_macro_deps(Items, D0, D) :-
    ccl_items_macro_files(Items, Ps0), sort(Ps0, Ps),
    (   Ps == [] -> D = D0
    ;   findall(F, ( member(P, Ps), ( F = P ; ccl_macro_loads(P, Fs), member(F, Fs) ) ), Fs0), sort(Fs0, Files),
        ccl_kb_file_deps(Files, [], D1), append(D0, D1, D2), sort(D2, D) ).
ccl_items_macro_files([], []).
ccl_items_macro_files([include(_, _, macros(P, _))|Is], [P|Ps]) :- !, ccl_items_macro_files(Is, Ps).
ccl_items_macro_files([include(_, _, file(_, _, U))|Is], Ps) :- !,
    ccl_unit_macro_files(U, P1), ccl_items_macro_files(Is, P2), append(P1, P2, Ps).
ccl_items_macro_files([_|Is], Ps) :- ccl_items_macro_files(Is, Ps).
ccl_unit_macro_files(unit(Is), Ps) :- !, ccl_items_macro_files(Is, Ps).
ccl_unit_macro_files(partial(U, _, _), Ps) :- !, ccl_unit_macro_files(U, Ps).
ccl_unit_macro_files(_, []).

%% cached: the meta with the same key, every dep at its remembered key, every
%% item present -> the unit, its includes re-linked through ccl_include_read/2
ccl_kb_cached(Path, What, Unit) :-
    ccl_kb_ready, ccl_kb_key(Path, K),
    '$ccl_ast'(Path, K, meta(What0, N, Deps)), !,
    ccl_kb_deps_fresh(Deps),
    ccl_kb_items_goal(Path, K, I, It, T), findall(I-It, T, Pairs),
    length(Pairs, N),
    sort(Pairs, Sorted), ccl_kb_values(Sorted, Items0),
    ccl_kb_link(Items0, Items),
    ccl_kb_unit(What0, What, Items, Unit).
ccl_kb_deps_fresh([]).
ccl_kb_deps_fresh([cfg(P, Cfg)-PK|Ds]) :- !, pp_with_cfg(Cfg, ccl_kb_key(P, PK)), ccl_kb_deps_fresh(Ds).   % under its include's configuration (0.239)
ccl_kb_deps_fresh([P-PK|Ds]) :- ccl_kb_key(P, PK), ccl_kb_deps_fresh(Ds).
ccl_kb_values([], []).
ccl_kb_values([_-V0|T], [V|Vs]) :- ccl_float_thaw(V0, V), ccl_kb_values(T, Vs).
ccl_kb_link([], []).
ccl_kb_link([include(L, S, ref(P, _))|T], [include(L, S, R)|Ls]) :- !, ( ccl_own_header(P) -> ccl_include_read(P, R) ; pp_sans_user(ccl_include_read(P, R)) ), ccl_kb_link(T, Ls).
ccl_kb_link([include(L, S, ref(P, _, Cfg))|T], [include(L, S, R)|Ls]) :- !, pp_with_cfg(Cfg, ccl_include_read(P, R)), ccl_note_path_cfg(R, Cfg), ccl_kb_link(T, Ls).   % under its own configuration (0.239)
ccl_kb_link([I|T], [I|Ls]) :- ccl_kb_link(T, Ls).
ccl_kb_unit(top, top, Is, unit(Is)).
ccl_kb_unit(included(How), included(How), Is, unit(Is)).
ccl_kb_unit(included_partial(How, L, F), included(How), Is, partial(unit(Is), line(L), near(F))).

%% the file being read is a global, for the directory a quoted include starts
%% from; a nested read saves and restores it with the outer grammar's other
%% globals (its typedef environment, its farthest line)
ccl_with_file(File, Goal) :-
    ccl_save_globals(Saved),
    nb_setval('$ccl_file', File), nb_setval('$ccl_lambda_seq', 0),   % the file's lambdas counted from its own start (0.236, ccl_lambda_at/2)
    ( catch(Goal, E, (ccl_restore_globals(Saved), throw(E)))
    -> ccl_restore_globals(Saved)
    ;  ccl_restore_globals(Saved), fail ).
ccl_save_globals(g(F, E, Far, M, Sc, Gs, Td, Tg, En, Ex, Cn, LS)) :-
    ccl_global('$ccl_file', F, none), ccl_env_names(E), ccl_global('$ccl_far', Far, 0), ccl_global('$ccl_macros', M, []),
    ccl_global('$ccl_scope', Sc, []), ccl_tab_save('$ccl_gscope', Gs), ccl_tab_save('$ccl_typedefs', Td), ccl_tab_save('$ccl_tags', Tg),
    ccl_global('$ccl_enums', En, []), ccl_global('$ccl_expansions', Ex, []), ccl_global('$ccl_consts', Cn, []),   % the program's named constants too (0.195)
    ccl_global('$ccl_lambda_seq', LS, 0).   % and the count of the lambdas read (0.236)
ccl_restore_globals(g(F, E, Far, M, Sc, Gs, Td, Tg, En, Ex, Cn, LS)) :-
    nb_setval('$ccl_file', F), ccl_env_put(E), nb_setval('$ccl_far', Far), nb_setval('$ccl_macros', M),
    nb_setval('$ccl_scope', Sc), ccl_tab_restore('$ccl_gscope', Gs), ccl_tab_restore('$ccl_typedefs', Td), ccl_tab_restore('$ccl_tags', Tg), nb_setval('$ccl_enums', En),
    ccl_tables_changed, nb_setval('$ccl_expansions', Ex), nb_setval('$ccl_consts', Cn), nb_setval('$ccl_lambda_seq', LS).
%% every global is set once per process (ccl_ensure_globals/0), so reads are
%% bare nb_getval/2: a catch/3 costs in proportion to the terms bound inside
%% it, 37 ms with the symbol table -- a finding, in RULES.md
ccl_global(K, V, _) :- ccl_ensure_globals, nb_getval(K, V).
ccl_ensure_globals :-
    ( nb_current('$ccl_inited', yes) -> true
    ; nb_setval('$ccl_file', none), ccl_env_put([]), nb_setval('$ccl_far', 0), nb_setval('$ccl_macros', []),
      nb_setval('$ccl_scope', []), ccl_tabs_reset, nb_setval('$ccl_enums', []), nb_setval('$ccl_consts', []), ccl_tables_changed,
      nb_setval('$ccl_expansions', []), nb_setval('$ccl_incpath', none), nb_setval('$ccl_kb_ready', no), nb_setval('$ccl_reading', []),
      nb_setval('$ccl_macro_files', []), nb_setval('$ccl_macro_loads', []), nb_setval('$ccl_std_macros', none), nb_setval('$ccl_gensym', 0), nb_setval('$ccl_unit_paths', []), nb_setval('$ccl_read_wrote', []), nb_setval('$ccl_lambda_seq', 0),
      nb_setval('$ccl_lang', c), nb_setval('$ccl_lang_forced', none), ccl_fn_templates_put([]), nb_setval('$ccl_class', []), nb_setval('$ccl_inc_kind', local), nb_setval('$ccl_hash', line), nb_setval('$ccl_lib_unit', no),
      nb_setval('$ccl_targ', 0), nb_setval('$ccl_tmpl_depth', 0), nb_setval('$ccl_tt_pending', []), nb_setval('$ccl_tt_frames', []), nb_setval('$ccl_vparams', []), nb_setval('$ccl_vhead', []),
      nb_setval('$ccl_instances', []), nb_setval('$ccl_inst_making', []), nb_setval('$ccl_inst_count', 0), nb_setval('$ccl_hoist', []),
      ( nb_current('$ccl_std', _) -> true ; nb_setval('$ccl_std', 17) ),
      ccl_seed_template_names(Seed), ccl_templates_put(Seed),
      ( catch(ccl_lex_native('', 1, line, c, _, _), _, fail) -> nb_setval('$ccl_lexer', native) ; nb_setval('$ccl_lexer', dcg) ),
      ccl_cache_index('$ccl_sumload:', SI), nb_setval(SI, []),
      nb_setval('$ccl_inited', yes) ).
%% the templates a read starts from: common standard library names and the compiler's template-shaped builtins (a library
%% header's read starts from these alone, ccl_seed_read/2)
ccl_seed_template_names([vector, map, set, unordered_map, unordered_set, list, deque, array, pair, tuple, optional, variant,
                         unique_ptr, shared_ptr, weak_ptr, function, basic_string, initializer_list, allocator, less, greater, hash,
                         numeric_limits, is_same, enable_if, remove_reference, decay, queue, stack, priority_queue, span,
                         '__builtin_common_type', '__type_pack_element', '__make_integer_seq', '__integer_pack']).

%% ---- the directive's text -----------------------------------------------------
ccl_include_spec(Text, Spec) :- atom_codes(Text, Cs), phrase(ccl_inc_spec(Spec), Cs).
ccl_inc_spec(next(Spec)) --> [35], ccl_sp, "include_next", ccl_sp, ccl_inc_name(Spec), ccl_rest_any.   % the path after the including file's directory
ccl_inc_spec(Spec) --> [35], ccl_sp, "include", ccl_sp, ccl_inc_name(Spec), ccl_rest_any.
ccl_inc_name(system(N)) --> "<", ccl_upto(0'>, Cs), { atom_codes(N, Cs) }.
ccl_inc_name(local(N)) --> [34], ccl_upto(34, Cs), { atom_codes(N, Cs) }.
ccl_sp --> [C], { C =:= 32 ; C =:= 9 }, !, ccl_sp.
ccl_sp --> [].
ccl_upto(End, []) --> [End], !.
ccl_upto(End, [C|Cs]) --> [C], ccl_upto(End, Cs).
ccl_rest_any --> [_], !, ccl_rest_any.
ccl_rest_any --> [].

%% ---- one include --------------------------------------------------------------
ccl_include(Spec, R) :-
    ccl_global('$ccl_file', From, none),
    (   ccl_resolve_include(Spec, From, Path)
    ->  ( sub_atom(Path, _, 3, 0, '.pl') -> ccl_load_macros(Path, Preds), R = macros(Path, Preds) ; ccl_inc_kind(Spec, Kind), nb_setval('$ccl_inc_kind', Kind), ( ccl_own_header(Path) -> ccl_include_read(Path, R) ; pp_sans_user(ccl_include_read(Path, R)) ) )
    ;   R = missing ).
%% THE CONFIGURATION AT AN #include OF THE USER'S FILE (0.239; pp_inc_config/2), which its top run noted by line: the
%% reader reads the header under it; a header's own includes are read under the header's
ccl_inc_cfg_at(L, Cfg) :- ccl_global('$ccl_reading', Rd, []), ( Rd == [] -> true ; Rd = [P|_], nb_current('$ccl_cfgs_of', P) ), nb_current('$pp_inc_cfgs', Cs), memberchk(L-Cfg, Cs), !.
%% ... AND AT AN #include OF THE PROGRAM'S OWN HEADER READ AS THE PROGRAM'S FILE IS (0.298; ccl_pp_own_parse/3): its own
%% run noted them, by its lines. `#define K 5' and `#include "d.h"' in a header, `int a[K];' in d.h: d.h was read under
%% the configuration at the file's #include of the header, where no K stood, and the bound was 0. A read that took one is
%% kept in no store (ccl_include_read/2): the store names its headers by reference, and reads them under the configuration
%% at the file's #include
%% ... and kept by the header's path for the file's lowering ('$ccl_path_cfgs', made afresh at each file's read), whose
%% preprocessed read of a raw-read header reads it under the same (ir_hdr_pp_items/2)
ccl_note_path_cfg(file(P, _, _), Cfg) :- atom(P), !, ( nb_current('$ccl_path_cfgs', Ps) -> true ; Ps = [] ), nb_setval('$ccl_path_cfgs', [P-Cfg|Ps]).
ccl_note_path_cfg(_, _).
ccl_path_cfg(P, Cfg) :- nb_current('$ccl_path_cfgs', Ps), memberchk(P-Cfg, Ps), !.
ccl_inc_kind(system(_), system) :- !.
ccl_inc_kind(next(_), system) :- !.
ccl_inc_kind(_, local).

%% ---- a .pl included: its predicates are macros ---------------------------------
%% `#include "m.pl"' loads the Prolog file (ensure_loaded/1: a second load
%% replaces, and under the store the clauses stay in the process) and the
%% node is include(L, Spec, macros(Path, [macro(CName, Pred, Arity|dcg) ...])). From then on a
%% call name(a, b) in the C source, where name/3 is one of them, is run AT
%% PARSE TIME as name(ASTa, ASTb, Result) and Result stands in the AST -- in
%% an expression, as a statement (a statement term is unwrapped), or at file
%% scope; a list result is spliced in. The predicates a file defines are
%% what current_predicate/1 gains by loading it.
%% `#cocolog ... #end' in a C file (owner's rule): the lines between are a
%% macro file written in place -- to a temporary .pl, loaded and registered
%% like `#include "m.pl"', so every predicate they define is a macro from
%% that line on; the block stays in the AST as cocolog(Line, Text), which
%% the check and the lowering pass over (the expansion already happened)
ccl_cocolog_block(L, Text) :-
    tmp_file(cocolog, P0), atomic_list_concat([P0, '-', L, '.pl'], P),
    atom_codes(Text, Cs), write_file_from_codes(P, Cs),
    ccl_load_macros(P, _).
ccl_load_macros(Path, Preds) :- ccl_macro_loaded(Path, Preds), !, ccl_register_macros(Preds).
ccl_load_macros(Path, Preds) :-
    read_file_to_codes(Path, Codes),
    ccl_pl_clauses(Codes, Texts), ccl_pl_heads(Texts, Preds),
    ensure_loaded(Path),
    ccl_macro_note(Path, Preds),
    ccl_register_macros(Preds).

%% the heads a Prolog file defines -- current_predicate/1 names no file (and,
%% before cocolog 1.10.28, listed no consulted clause), so the text is split
%% into clauses (a `.' followed by layout, outside quotes, comments and 0'c)
%% and each is read with term_to_atom/2: name/Arity for a fact or a rule,
%% dcg(name) for `-->'
ccl_pl_clauses(Codes, Texts) :- phrase(ccl_pl_split(Texts), Codes, _).
ccl_pl_split(Ts) --> ccl_pl_layout, ccl_pl_split_(Ts).
ccl_pl_split_([T|Ts]) --> ccl_pl_clause(Cs), { Cs \== [] }, !, { atom_codes(T, Cs) }, ccl_pl_layout, ccl_pl_split_(Ts).
ccl_pl_split_([]) --> [].
ccl_pl_layout --> [C], { ccl_blank(C) ; C =:= 10 }, !, ccl_pl_layout.
ccl_pl_layout --> [0'%], !, ccl_to_eol, ccl_pl_layout.
ccl_pl_layout --> [0'/, 0'*], !, ccl_pl_comment, ccl_pl_layout.
ccl_pl_layout --> [].
ccl_pl_comment --> [0'*, 0'/], !.
ccl_pl_comment --> [_], !, ccl_pl_comment.
ccl_pl_comment --> [].
ccl_pl_clause([0'0, 39, C|T]) --> [0'0, 39, C], !, ccl_pl_clause(T).
ccl_pl_clause([]) --> [0'.], ccl_pl_end, !.
ccl_pl_clause(T) --> [0'%], !, ccl_to_eol, ccl_pl_clause(T).
ccl_pl_clause(T) --> [0'/, 0'*], !, ccl_pl_comment, ccl_pl_clause(T).
ccl_pl_clause([39|T]) --> [39], !, ccl_pl_quoted(39, Q), { append(Q, T1, T) }, ccl_pl_clause(T1).
ccl_pl_clause([34|T]) --> [34], !, ccl_pl_quoted(34, Q), { append(Q, T1, T) }, ccl_pl_clause(T1).
ccl_pl_clause([C|T]) --> [C], ccl_pl_clause(T).
ccl_pl_end(S, S) :- ( S == [] ; S = [C|_], ( ccl_blank(C) ; C =:= 10 ; C =:= 0'% ) ), !.
ccl_pl_quoted(Q, [Q]) --> [Q], !.
ccl_pl_quoted(Q, [92, C|T]) --> [92, C], !, ccl_pl_quoted(Q, T).
ccl_pl_quoted(Q, [C|T]) --> [C], ccl_pl_quoted(Q, T).
%% an entry is macro(CName, Pred, Kind): the name in the C source, the
%% predicate, and its Prolog arity or dcg. A predicate named ccl_macro_X is
%% the macro X -- so a macro may be called what a builtin is called (format)
ccl_pl_heads([], []).
ccl_pl_heads([Text|Ts], Preds) :-
    (   catch(term_to_atom(Term, Text), _, fail), ccl_pl_head(Term, P)
    ->  ccl_pl_heads(Ts, Ps0), ccl_pl_unread(Term, P, Ps0, Ps), ( memberchk(P, Ps) -> Preds = Ps ; Preds = [P|Ps] )
    ;   ccl_pl_heads(Ts, Preds) ).
ccl_pl_head((:- _), _) :- !, fail.
ccl_pl_head((H --> _), macro(C, N, dcg)) :- !, ccl_pl_functor(H, N, _), ccl_macro_cname(N, C).
ccl_pl_head((H :- _), macro(C, N, A)) :- !, ccl_pl_functor(H, N, A), ccl_macro_cname(N, C).
ccl_pl_head(H, macro(C, N, A)) :- ccl_pl_functor(H, N, A), ccl_macro_cname(N, C).
ccl_pl_functor(H, N, A) :- ( H = (M, _), callable(M) -> functor(M, N, A) ; functor(H, N, A) ), atom(N).
ccl_macro_cname(N, C) :- ( atom_concat(ccl_macro_, C0, N) -> C = C0 ; C = N ).
%% AN ARGUMENT TAKEN UNREAD (0.264; CCLLIB.md's phase 0.7): a clause head with unread(_) at a place makes that argument
%% of the macro, at that arity, come unread -- its tokens -- so that the macro reads it after it declares its names
%% (ccl_unread_ahead/6 in library(ccl_syntax)); the entry unread(CName, Arity, Places) stands beside the macro's macro/3,
%% the places of all its clauses joined
ccl_pl_unread(Term, macro(C, _, A), Ps0, Ps) :-
    integer(A), ( Term = (H :- _) -> true ; H = Term ), compound(H), functor(H, _, A),
    findall(I, ( between(1, A, I), arg(I, H, X), nonvar(X), X = unread(_) ), Is), Is \== [], !,
    ( select(unread(C, A, Js), Ps0, Ps1) -> append(Js, Is, K0), sort(K0, Ks), Ps = [unread(C, A, Ks)|Ps1] ; Ps = [unread(C, A, Is)|Ps0] ).
ccl_pl_unread(_, _, Ps, Ps).

ccl_register_macros(Preds) :- ccl_global('$ccl_macros', M0, []), append(Preds, M0, M), nb_setval('$ccl_macros', M).

%% the standard macros -- format, print, println (library/ccl_format.pl) --
%% are global, there in every file without an include, like `:='; the parser
%% registers them at the start of every unit
ccl_standard_macros :-
    (   ccl_global('$ccl_std_macros', P0, none), P0 \== none -> P = P0
    ;   ccl_library_dirs(Ds), ( member(D, Ds), atomic_list_concat([D, '/ccl_format.pl'], P), exists_file(P) -> true ; P = none ),
        nb_setval('$ccl_std_macros', P) ),
    ( P == none -> true ; ccl_load_macros(P, _) ).

%% what an include brings into scope: its declarations, typedef definitions and
%% struct tags (for ccl_type_of/2 and friends, library(ccl_infer)) ...
ccl_include_scope(file(_, _, Unit)) :- !, ccl_unit_note(Unit).
ccl_include_scope(_).
ccl_unit_note(unit(Is)) :- !, ccl_items_note(Is).                     % the bulk noter, library(ccl_syntax)
ccl_unit_note(partial(U, _, _)) :- !, ccl_unit_note(U).
ccl_unit_note(summary(F)) :- !, ccl_sum_note(F).
ccl_unit_note(_).


%% ... and the macros of a .pl
%% it is, or of any .pl a header under it includes (loaded here if need be)
ccl_include_macros(macros(_, _)) :- !.                 % registered by ccl_load_macros
ccl_include_macros(file(_, _, Unit)) :- !, ccl_unit_macros(Unit, Pairs), ccl_load_each(Pairs).
ccl_include_macros(_).
ccl_load_each([]).
ccl_load_each([P-_|T]) :- ccl_load_macros(P, _), ccl_load_each(T).
ccl_unit_macros(summary(_), []) :- !.                   % a summary carries no macro file
ccl_unit_macros(unit(Is), Ms) :- !, ccl_items_macros(Is, Ms).
ccl_unit_macros(partial(U, _, _), Ms) :- !, ccl_unit_macros(U, Ms).
ccl_unit_macros(_, []).
ccl_items_macros([], []).
ccl_items_macros([include(_, _, macros(P, Preds))|T], [P-Preds|Ms]) :- !, ccl_items_macros(T, Ms).
ccl_items_macros([include(_, _, file(_, _, U))|T], Ms) :- !, ccl_unit_macros(U, M1), ccl_items_macros(T, M2), append(M1, M2, Ms).
ccl_items_macros([_|T], Ms) :- ccl_items_macros(T, Ms).

%% in order: read already in this process; in the knowledge base with the same
%% modification time; else read it now and remember it both ways.
%% THE PROGRAM'S OWN HEADER IS READ AGAIN WHERE THE UNIT HAS AN INSTANCE (0.293; ccl_inst_context/1): a read kept in a
%% cache was made where the unit had none, or none of the types around it -- the prescan reads each header alone, with
%% no declaration of the headers before it -- and a function of the header may take an instance's operator or call it
%% by name over a struct that a header before it declares (`p->pts[0]', `pts' a member of type `vector<pt>'): the read
%% kept made no such form, met no instance, and was served to the parse (`not_a_pointer'). Read again in its place, it
%% makes them, meets the instance, and no cache keeps it (ccl_inst_since/1); a header that makes none is kept again
ccl_include_read(Path, cyclic(Path)) :- ccl_reading(Path), !.
ccl_include_read(Path, file(Path, How, Unit)) :- \+ ccl_inst_context(Path), ccl_unit_cached(Path, How, Unit), !.
ccl_include_read(Path, file(Path, How, Unit)) :- \+ ccl_inst_context(Path), ccl_kb_cached(Path, included(How), Unit), !, ccl_unit_cache(Path, How, Unit).
ccl_include_read(Path, file(Path, How, Unit)) :-
    ccl_reading_push(Path), ccl_inst_mark(IM), ( ccl_inst_context(Path) -> Sc = yes, ccl_inscope_push(Path) ; Sc = no ),
    ( nb_current('$ccl_cfg_inner', CI0) -> true ; CI0 = no ), nb_setval('$ccl_cfg_inner', no),
    (   catch(ccl_read_unit(Path, How0, Unit0), E, true)
    ->  ( var(E) -> How = How0, Unit = Unit0 ; How = unreadable, Unit = none, ( E = error(refusal(_, _), _), ccl_own_header(Path) -> RE = E ; true ) )
    ;   How = unreadable, Unit = none ),
    ( nb_getval('$ccl_cfg_inner', yes) -> Inner = yes ; Inner = no ), nb_setval('$ccl_cfg_inner', CI0),
    ( Sc == yes -> ccl_inscope_pop(Path) ; true ),
    ccl_reading_pop(Path),
    ( nonvar(RE) -> throw(RE) ; true ),   % A REFUSAL IN THE PROGRAM'S OWN HEADER IS THE BUILD'S, at the header's line (0.298): it was the header `could not be read', and the build failed at a name that the header declares, `undeclared(t)'
    (   ( ccl_inst_since(IM) ; Sc == yes ) -> true   % A READ THAT MADE OR MET A TYPE MACRO'S INSTANCE (0.261), OR ONE IN ITS INCLUDER'S SCOPE (0.293), is the unit's: kept in neither cache
    ;   ccl_unit_cache(Path, How, Unit),
        ( How == unreadable -> true ; How == summary -> true ; ccl_lang(cpp), How == preprocessed -> true ; Inner == yes -> true ; ccl_kb_remember(Path, included(How), Unit) ) ).   % ... or one that read a header of its own under its own run's configuration (0.298, ccl_inc_cfg_at/2): in the process only
%% the unit has an instance where it includes the program's own header (ccl_own_header/1), and the read is not a
%% library header's: the header is read in its includer's scope (ccl_unit/3), in each read that the include makes of it
ccl_inst_context(Path) :- \+ nb_current('$ccl_lib_unit', yes), ccl_own_header(Path), ( nb_current('$ccl_instances', [_|_]) -> true ; ccl_user_macro_files ).
%% ... OR A MACRO FILE OF ITS OWN, past the global macros of every file (0.298): `vector<int> items;' in a header that
%% includes no <vector.pl>, under a unit that includes it before the header and has made no instance yet -- the header
%% makes the first one. Read alone, the header knew no type macro (ccl_unit_start/1 begins a read with none): both of
%% its reads stopped at its first line, and the unit met `not lowered yet: typedef(bag)' (in C++,
%% `template_without_body(vector)') -- the finding of a program over 0.284
ccl_user_macro_files :- nb_current('$ccl_macros', Ms), Ms \== [],
    ( nb_current('$ccl_std_macros', P), P \== none, ccl_macro_loaded(P, Std) -> true ; Std = [] ), member(M, Ms), \+ memberchk(M, Std), !.
ccl_inscope_push(P) :- ( nb_current('$ccl_inscope', Ps) -> true ; Ps = [] ), nb_setval('$ccl_inscope', [P|Ps]).
ccl_inscope_pop(P) :- ( nb_current('$ccl_inscope', Ps), selectchk(P, Ps, Ps1) -> nb_setval('$ccl_inscope', Ps1) ; true ).
%% a preprocessed C++ header stays in the process: <cstdio> alone is 2700
%% items, and cocolog's store takes a writing process's rows at a cost that
%% follows their count, never reclaiming a dead one -- five minutes and 187 MB
%% for one include chain -- so the C++ system headers are read per run (a
%% bounded 30 s) until a summary cache replaces the AST cache for them

%% raw first; preprocessed only when raw does not read whole -- except a C++
%% library header, <cstdio> and kin: flattened by one run of the preprocessor
%% (library(ccl_pp), cocolog's own), its hundreds of includes resolved there,
%% and read once, as far as it reads; raw, each of those would be attempted,
%% failed and preprocessed in turn, ten minutes for <sstream>
ccl_read_unit(Path, How, Unit) :-
    ccl_lang(cpp), nb_getval('$ccl_inc_kind', system), !,
    nb_setval('$ccl_inc_kind', local),
    ccl_sum_file(Path, F),
    (   ccl_sum_valid(F) -> How = summary, Unit = summary(F)
    ;   ccl_lib_unit(ccl_seed_read(ccl_pp_parse(Path, U1, Info1, Files), U1)), How = preprocessed, ccl_partial(U1, Info1, Unit),
        ccl_sum_dir_ready,   % THE DIRECTORY FIRST (0.106): 0.100 put the AST's write before the summary's, whose mkdir made the directory, so in a fresh or wiped cache the first header's AST met no directory and was lost
        (   catch(ccl_ast_write(F, U1), E, ( ccl_ast_trace(ast_not_written(Path, E)), fail ))   % NO SUMMARY WITHOUT ITS AST (0.106): the recovery
        ->  ( catch(ccl_sum_write(F, Path, Files, U1), _, fail) -> ccl_note_read_wrote(Path, F) ; true )   % used to SUCCEED, so an exception read as a written AST
        ;   ccl_ast_trace(ast_not_written(Path)) ) ).                                              % and a valid summary stood with no template bodies behind it   % THE SUMMARY IS WRITTEN LAST (0.100): it is the validity key, so a run killed while it writes the AST (the slow one) leaves no summary and the next run flattens again -- written first, a killed run left a valid .sum beside no .ast.pl, and every program over that header refused template_without_body
%% THE PROGRAM'S OWN HEADER IN C++ IS READ AS THE PROGRAM'S FILE IS (0.268): its directives run and its macros expanded,
%% each #include passed on to the reader, which reads that header apart (a library's from its summary) -- the mode of
%% ccl_pp_top/3, '$pp_top' yes. Its unit holds the header's own items and an include item for each header that it
%% includes, the shape of a raw read whole, which the desugaring takes for the program's (cpp_register_header/1,
%% cpp_header_fns/1). Read raw, a function of the header kept a macro of the header unexpanded, `TWICE(x)' a call of
%% nothing (`undeclared'); and a header that read only preprocessed was one token stream with each header that it
%% includes in it, which the desugaring took for a library's (cpp_index_header/1) AND for the program's
%% (cpp_include_fns/1), each of its functions defined twice (`invalid redefinition' at LLVM). C keeps its reads: its
%% lowering takes a raw read's definitions from the header read preprocessed (ir_hdr_resolve/2). A read that is not
%% whole goes the old way, raw first
ccl_read_unit(Path, How, Unit) :-
    ccl_lang(cpp), ccl_own_header(Path), ccl_global('$ccl_instances', I0, []),
    (   catch(ccl_pp_own_parse(Path, U, Info), _, fail), Info == whole -> true
    ;   nb_setval('$ccl_instances', I0), fail ), !,
    How = raw, Unit = U.
%% ... AND IN C, ONE WHOSE TEXT A RAW READ IS KNOWN NOT TO BE IS READ SO FIRST (0.298): a header with a conditional past
%% its guard, or whose own lines name a macro of its includer's in the configuration at its #include
%% (`ccl_pre_not_its_text/1'). Its raw read, and the reads of the headers inside it, were made for nothing
%% (`ccl_raw_not_its_text/2', below, took the header so): a file of 40 such headers, each including the next, took 5 s
%% where it takes 2.6 s. A read that is not whole goes the old way
ccl_read_unit(Path, How, Unit) :-
    \+ ccl_lang(cpp), ccl_own_header(Path), ccl_pre_not_its_text(Path), ccl_global('$ccl_instances', I0, []),
    (   catch(ccl_pp_own_parse(Path, U, Info), _, fail), Info == whole -> true
    ;   nb_setval('$ccl_instances', I0), fail ), !,
    How = preprocessed, Unit = U.
%% THE RAW ATTEMPT'S INSTANCES GO WITH IT (0.261): a type macro's instance made by a raw read that did not read whole
%% stands in no AST, so the preprocessed read starts from the unit's instances before the attempt, and the raw partial
%% read that stays keeps its own.
%% THE PROGRAM'S OWN HEADER WHOSE RAW READ MET AN INSTANCE IS READ AGAIN AS THE PROGRAM'S FILE IS (0.293; in C): its
%% directives run and its macros expanded, in its place in the unit, as C++ reads the program's header (0.268, above),
%% and that read is taken where it is whole. The raw read alone made the forms of a macro file -- an operator on an
%% instance, `p->pts[0]' the call of `vector_pt_index', a call by name, `size(p->pts)' the call of `vector_pt_size' --,
%% and kept the header's macros unexpanded; the lowering took each definition from the header read preprocessed ALONE
%% (ir_hdr_resolve/2), where no instance of the unit is and those forms are not made: `p->pts[0]' was `not lowered yet:
%% not_a_pointer', and `size(p->pts)' took the vector by value. A function of such a header has both now, a macro of
%% the header and an instance's operator in one body. Such a read is the unit's (ccl_inst_since/1): no cache keeps it,
%% so it is read where the unit includes it, under the unit's instances
ccl_read_unit(Path, How, Unit) :-
    ccl_global('$ccl_instances', I0, []), ccl_inst_mark(IM),
    ( catch(ccl_parse_file(Path, U0, Info0), _, fail) -> true ; U0 = unit([]), Info0 = stopped(1, near(1)) ),   % A RAW READ THAT THROWS GOES ON TO THE PREPROCESSED READ (0.290; below)
    ccl_global('$ccl_instances', I1, []),
    (   Info0 == whole, \+ ccl_raw_cut_inside(U0)
    ->  (   \+ ccl_lang(cpp), ccl_own_header(Path), ( ccl_inst_since(IM) -> true ; ccl_raw_not_its_text(Path, U0) ), nb_setval('$ccl_instances', I0),
            catch(ccl_pp_own_parse(Path, U2, Info2), _, fail), Info2 == whole
        ->  How = preprocessed, Unit = U2
        ;   nb_setval('$ccl_instances', I1), How = raw, Unit = U0 )
    ;   Info0 == whole                                                    % whole, with a header inside that was not read whole (0.290; below)
    ->  (   nb_setval('$ccl_instances', I0), catch(ccl_pp_parse(Path, U1, Info1, Files), _, fail), Info1 == whole
        ->  How = preprocessed, Unit = U1, ccl_pp_macros(Ms), ccl_kb_remember_macros(Path, Files, Ms)
        ;   nb_setval('$ccl_instances', I1), How = raw, Unit = U0 )
    ;   nb_setval('$ccl_instances', I0), ccl_pp_parse(Path, U1, Info1, Files) -> How = preprocessed, ccl_partial(U1, Info1, Unit), ccl_pp_macros(Ms), ccl_kb_remember_macros(Path, Files, Ms)
    ;   nb_setval('$ccl_instances', I1), How = raw, ccl_partial(U0, Info0, Unit) ).
%% A RAW READ THAT IS NOT ITS HEADER'S TEXT (0.298; in C, the program's own header): the raw read runs no directive, so a
%% macro that the header defines and its own text names stays unexpanded in it, and it reads both arms of a
%% conditional. `#define M 24' and `typedef struct two { int n; size_t a[M]; } two;' were read with the bound `M', which
%% no constant folds, and `sizeof(two)' was 8 where gcc's is 200 (the finding of a program over 0.284). Where the
%% header's lines define a macro whose name an item of the raw read holds (its includes' items aside), or hold a
%% conditional past an include guard (`#ifndef G', `#define G', the last `#endif'), the header is read again as the
%% program's file is, its directives run and its macros expanded; that read is taken where it is whole
ccl_raw_not_its_text(Path, unit(Is)) :- catch(pp_source(Path, Lines), _, fail), ccl_hdr_directives(Lines, Ds),
    (   ccl_hdr_conditional(Ds) -> true
    ;   member(define(N), Ds), \+ ccl_hdr_guard(Ds, N), ccl_items_name(Is, N) -> true
    ;   nb_current('$pp_ftm', F), member(N-user(_, _), F), ccl_items_name(Is, N) ), !.   % ... or a macro of the configuration at its #include: its includer's (0.298, pp_inc_user_macros/4)
%% a header that the raw read is not, known before it runs: a conditional past its guard, or an includer's macro of the
%% configuration (`N-user(Ps, Cs)', pp_inc_user_macros/4) that the header's own words name
ccl_pre_not_its_text(Path) :- catch(pp_source(Path, Lines), _, fail),
    (   ccl_hdr_directives(Lines, Ds), ccl_hdr_conditional(Ds) -> true
    ;   nb_current('$pp_ftm', F), memberchk(_-user(_, _), F), pp_own_header_info(Path, Ws, _, _), member(N-user(_, _), F), memberchk(N, Ws) ), !.
ccl_hdr_directives(Lines, Ds) :-
    findall(D, ( member(line(_, A), Lines), pp_directive_line(A, Body), pp_ws(Body, B1), pp_word(B1, W, Rest), atom_codes(K, W), ccl_hdr_directive(K, Rest, D) ), Ds).
ccl_hdr_directive(define, Rest, define(N)) :- !, pp_ws(Rest, R1), pp_word(R1, Cs, _), Cs \== [], atom_codes(N, Cs).
ccl_hdr_directive(K, Rest, cond(K, N)) :- memberchk(K, [if, ifdef, ifndef, elif, elifdef, elifndef, else, endif]),
    ( pp_ws(Rest, R1), pp_word(R1, Cs, _), Cs \== [] -> atom_codes(N, Cs) ; N = none ).
ccl_hdr_conditional(Ds) :- findall(C, ( member(C, Ds), C = cond(_, _) ), Cs), Cs \== [], \+ ccl_hdr_guard(Ds, _).
ccl_hdr_guard(Ds, G) :- findall(C, ( member(C, Ds), C = cond(_, _) ), [cond(ifndef, G), cond(endif, _)]), memberchk(define(G), Ds).
%% an item of the header's own, no directive, that holds the name, or an item of a header of the program's own that it
%% includes, at any depth: `#define K 5' in a header names `int a[K];' of the header that it includes (0.298)
ccl_items_name(Is, N) :- member(I, Is), ccl_item_name(I, N), !.
ccl_item_name(include(_, _, file(P, _, U)), N) :- !, ccl_own_header(P), ( U = unit(Js) ; U = partial(unit(Js), _, _) ), ccl_items_name(Js, N).
ccl_item_name(include(_, _, _), _) :- !, fail.
ccl_item_name(directive(_, _), _) :- !, fail.
ccl_item_name(I, N) :- ccl_term_atom(I, N).
ccl_term_atom(T, A) :- T == A, !.
ccl_term_atom(T, A) :- compound(T), T =.. [_|As], member(X, As), ccl_term_atom(X, A), !.
%% A RAW READ THAT THROWS (0.290). The raw read is an attempt: it runs no directive, so it reads the lines of each
%% branch of a conditional, and its errors may be those of a branch that no build takes. TWO SUCH ERRORS WERE THE
%% HEADER'S END. The raw lexer ends a directive at its line's end, and C ends it where a comment that began on the line
%% ends (C17 5.1.1.2: a comment is a space before a directive is one): glibc's <netdb.h> has `#  define AI_IDN 0x0040
%% /* IDN encode input (assuming it is encoded' with `in the current locale's character set)' on the next line, whose
%% apostrophe begins a character constant that never ends, and the raw read threw `lexical(Path)'. And glibc's
%% <sys/cdefs.h> has, under an `#if' that no x86 build takes, `_Static_assert (0, "IEEE 128-bits long double requires
%% redirection on this platform");', which the raw read met as a declaration: `static_assert_failed'. Nothing caught
%% either here, and ccl_include_read/2 took the header as `unreadable' with no message: no name of <netdb.h> was
%% declared (`struct addrinfo', `getaddrinfo', `struct hostent'), where the preprocessed read takes each header whole.
%% A raw attempt that throws is an empty partial read now, whatever it throws, and the preprocessed read follows it, as
%% it follows a raw read that stopped: an error that is the header's own is thrown again there.
%% A RAW READ THAT IS WHOLE, WITH A HEADER INSIDE IT THAT WAS NOT READ WHOLE, GOES ON TOO (0.290; in C): glibc's
%% <getopt.h> is directives alone -- <features.h>, a macro, <bits/getopt_core.h>, <bits/getopt_ext.h> --, so its raw
%% read is whole; each of the two headers inside is then read apart, with no macro of its includer's (`__BEGIN_DECLS',
%% `__THROW', which <features.h> brought), and stops at its first declaration: `struct option' and `getopt_long' were
%% unknown, with no message. The preprocessed read of the includer reads them in its text, under its macros; it is
%% taken where it is whole, and the raw read stays where it is not -- a header of the program's whose own items are all
%% read keeps them, where a text that stops inside a header that it includes would lose those after the #include. In
%% C++ a system header is flattened whole, and the program's own header has its own read (0.268): they are as they were
ccl_raw_cut_inside(unit(Is)) :- \+ ccl_lang(cpp), member(include(_, _, file(_, H, U)), Is), ( H == unreadable ; U = partial(_, _, _) ), !.
%% the program's own header: one under no system path and not among the compiler's own (ir_hdr_lib_path/1)
ccl_own_header(P) :- atom(P), \+ ir_hdr_lib_path(P).
%% the header through the preprocessor in the program file's mode: its includes read first and their macros made ready
%% (ccl_pp_prescan/1), then its run and the read of its tokens. A run is a generation of the macros (pp_reset/0), so the
%% header is read in its includer's prescan, before the includer's own run; the includer's configurations at its
%% includes, by its lines, are put back after it ('$pp_inc_cfgs', '$pp_cfg_lib'), however it ends.
%% THE INSTANCES THAT ITS PRESCAN MADE ARE NOBODY'S (0.293), as the program's file's are (0.261, ccl_read_file_/3): the
%% prescan reads each header that it includes for its macros, and the read of its tokens reads one that met an instance
%% again, in its place; the unit's instances as they were before the prescan are put back between the two. A header
%% that includes the header of a struct with a `vector<pt>' member found the instance made by the prescan's read, which
%% stands in no AST, and made no items: `vector_pt' was no type of the unit, and `p->pts' was `no_member(pts)' -- in
%% C++ since 0.268, and in C since this read is C's too (ccl_read_unit/3)
%% ITS #warning LINES ARE THE FILE'S RUN'S (0.298), which ran its directives (pp_own_text/1): the read puts the list back,
%% where a header read so said each twice
ccl_pp_own_parse(Path, unit(Is), Info) :-
    ( nb_current('$pp_warnings', W0) -> true ; W0 = [] ),
    ( nb_current('$pp_inc_cfgs', C0) -> true ; C0 = [] ), ( nb_current('$pp_cfg_lib', L0) -> true ; L0 = none ),
    ccl_global('$ccl_instances', I0, []), ccl_global('$ccl_inst_making', M0, []), ccl_global('$ccl_hoist', H0, []),
    ( nb_current('$pp_own_read', O0) -> true ; O0 = no ), ( nb_current('$ccl_cfgs_of', F0) -> true ; F0 = none ),
    (   catch(( ccl_pp_prescan(Path), nb_setval('$pp_own_read', yes), ccl_pp_top_run(Path, [], Tokens, _), nb_setval('$pp_own_read', O0), \+ memberchk(tok(other, _, _), Tokens),   % ITS RUN UNDER THE CONFIGURATION AT ITS #include (0.298): the macros that its includer defined before it (pp_inc_user_macros/4)
                nb_setval('$ccl_instances', I0), nb_setval('$ccl_inst_making', M0), nb_setval('$ccl_hoist', H0), nb_setval('$ccl_cfgs_of', Path),
                ccl_with_file(Path, ( ccl_unit(Tokens, unit(Is), Rest), ccl_rest_info(Rest, Info) )) ), E, true)
    ->  R = ok ; R = failed ),
    nb_setval('$pp_inc_cfgs', C0), nb_setval('$pp_cfg_lib', L0), nb_setval('$pp_own_read', O0), nb_setval('$ccl_cfgs_of', F0), nb_setval('$pp_warnings', W0),
    ( nonvar(E) -> throw(E) ; R == ok ).

%% A READ THAT WROTE ITS HEADER'S SUMMARY AND AST IS NOTED FOR THE PROCESS (0.218), in a global as the units read here are: the
%% desugaring registers the header's items from that AST, as a served header's are (cpp_read_now_summarized/2)
ccl_note_read_wrote(Path, F) :- ccl_global('$ccl_read_wrote', L, []), ( memberchk(Path-F, L) -> true ; nb_setval('$ccl_read_wrote', [Path-F|L]) ).
%% a LIBRARY header's read is the library's, not the program's: the standard macros (format, print, println, clone)
%% are the program's global names and never fire inside it -- libc++'s <format> calls its own `format(c, ctx)'
%% (0.99); '$ccl_lib_unit' is read by ccl_unit, restored on success, failure and a throw
ccl_lib_unit(G) :-
    ccl_global('$ccl_lib_unit', Old, no), nb_setval('$ccl_lib_unit', yes),
    (   catch(G, E, ( nb_setval('$ccl_lib_unit', Old), throw(E) )) -> nb_setval('$ccl_lib_unit', Old)
    ;   nb_setval('$ccl_lib_unit', Old), fail ).
%% A LIBRARY HEADER IS READ FROM THE SEED (0.186): the templates and the function templates that the process noted before
%% -- the program's, another header's -- are set aside while the header is flattened and read, and put back after it with
%% the header's own as its summary notes them (ccl_items_templates/2), on success, failure and a throw. A header's read
%% depended on what the process had read before it: after <ranges> had noted `__move_impl', a static member function
%% template there, a later <string> read `__move_impl<_AlgPolicy>', move.h's class template, as an expression, and the
%% summary and the AST written by a cold build over several headers were not the library read's (0.185's nets against
%% 0.184's chain: 4 of 47 summaries over libc++ 18, 5 of 47 over 21). The includer of a header flattened in the process
%% now has what an includer served from its summary has.
%% THE NAMES OF ITS FREE FUNCTIONS DECLARED NOEXCEPT ARE THE HEADER'S OWN TOO (0.193): the read notes each in the set
%% `'$ccl_nxs'' (ccl_note_nx), which the program's own declarations fill; set aside like the templates, the set holds the
%% header's names after its read, which go to the LIBRARY's set `'$ccl_lnxs'' (ccl_lib_nothrow/1) and into the summary
%% (`nothrow(N)' lines, ccl_sum_write/4) through `'$ccl_hdr_nxs'', and the program's set is put back as it was: a
%% program's own `swap' is not noexcept because a header declares one so, and a header flattened in the process gives
%% what one served from its summary gives
ccl_seed_read(G, U) :-
    ccl_ensure_globals, ccl_set_list('$ccl_tmpls', Ts0), ccl_set_list('$ccl_ftmpls', Fs0), ccl_set_list('$ccl_nxs', Nx0),
    ccl_seed_template_names(Seed), ccl_templates_put(Seed), ccl_fn_templates_put([]), ccl_set_clear('$ccl_nxs'), nb_setval('$ccl_hdr_nxs', []),
    (   catch(G, E, ( ccl_templates_put(Ts0), ccl_fn_templates_put(Fs0), ccl_set_rebuild('$ccl_nxs', Nx0), throw(E) ))
    ->  ccl_templates_put(Ts0), ccl_fn_templates_put(Fs0), ccl_unit_templates_note(U),
        ccl_set_list('$ccl_nxs', NxH), ccl_set_rebuild('$ccl_nxs', Nx0), ccl_set_adds('$ccl_lnxs', NxH), nb_setval('$ccl_hdr_nxs', NxH)
    ;   ccl_templates_put(Ts0), ccl_fn_templates_put(Fs0), ccl_set_rebuild('$ccl_nxs', Nx0), fail ).
ccl_unit_templates_note(unit(Is)) :- !, ccl_items_templates(Is, Ns), ccl_note_templates(Ns).
ccl_unit_templates_note(_).

%% ---- the summary cache: a C++ library header, once ----------------------------
%% What a header contributes downstream is its declarations -- the names and
%% types the noter collects: functions and globals, typedefs, tags with their
%% members (method bodies dropped), enumerators, template names, type names --
%% not its text. So a flattened library header is summarized to ONE FILE,
%% ~/.cicilang/cpp/<name>-<fold>.sum, a term per line, keyed by the reader's
%% version and the time of every file the preprocessor pulled (a dep per
%% line, since a line past some tens of KB does not read back); the next run
%% loads the summary instead of preprocessing and reading forty thousand
%% lines. The include node is then
%% include(L, Spec, summary(File)), and every consumer of a unit -- the
%% parser's Env, the symbol table, the bulk noter, the driver's deps -- reads
%% the summary where it would have walked the unit. cocolog's store is not
%% involved: it cannot hold units this size (RULES.md's findings).
ccl_sum_dir(D) :- ( catch(os_env('HOME', H), _, fail) -> true ; H = '/tmp' ), atom_concat(H, '/.cicilang/cpp', D).
ccl_sum_file(Path, F) :-
    ccl_sum_dir(D), ccl_std(Std), ccl_cmdline_key(CK), ccl_target_key(TK), ccl_config_key(GK), ccl_ftm_tag(FK), atomic_list_concat([Path, '@', Std, CK, TK, GK, FK], Keyed), atom_codes(Keyed, Cs), ccl_fold(Cs, 7, 131, S1), ccl_fold(Cs, 13, 137, S2),   % one summary per level, and per set of command-line macros (0.112): a header read under `-DNDEBUG' is another header
    ( sub_atom(Path, B, _, 0, Base), sub_atom(Path, B1, 1, _, '/'), B1 < B, \+ sub_atom(Base, _, _, _, '/') -> true ; Base = Path ),
    atomic_list_concat([D, '/', Base, '-', S1, '-', S2, '.sum'], F).
ccl_cmdline_key(K) :- ( nb_current('$pp_cmdline', L), L \== [] -> msort(L, L1), term_to_atom(L1, A), atom_concat('@', A, K) ; K = '' ).
%% ... AND PER MACHINE (0.161): a header read for another machine (`--target=') is read under its macros -- `__aarch64__',
%% `__CHAR_UNSIGNED__', the quad's `__LDBL_*' -- and this compiler's own `<limits.h>' and `<float.h>' have one path for every
%% machine, so a host's summary of one was VALID for a target's read (its deps unchanged) and served it the host's limits
ccl_target_key(K) :- ( nb_current('$ccl_target', target(A, O, T)), \+ ( catch(ccl_host_arch(A), _, fail), catch(ccl_host_os(O), _, fail) ) -> atom_concat('@', T, K) ; K = '' ).
%% ... AND PER CONFIGURATION OF libc++ (0.191): a header read under -fno-rtti is read under other macros (`__cpp_rtti'
%% undefined), and its deps are the same files; the default configuration adds nothing, so its summaries keep their names
ccl_config_key(K) :- ( nb_current('$ccl_rtti', no) -> K1 = '@no-rtti' ; K1 = '' ), ( nb_current('$ccl_exceptions', no) -> K2 = '@no-exceptions' ; K2 = '' ), atom_concat(K1, K2, K).   % ... and -fno-exceptions (0.193)
ccl_fold([], S, _, S).
ccl_fold([C|Cs], S0, M, S) :- S1 is (S0 * M + C) mod 2147483647, ccl_fold(Cs, S1, M, S).
ccl_sum_valid(F) :-
    exists_file(F), ccl_ast_file(F, A), exists_file(A),   % A SUMMARY IS VALID ONLY WITH ITS AST BESIDE IT (0.106): a hollow one, left by the lost-AST defect, refused every program over the header's templates until the cache was wiped by hand; now it is simply read again
    ccl_sum_terms(F, [sum(_, key(V, cpp(S)))|Terms]), ccl_reader_version(V), ccl_std(S), \+ memberchk(big(_), Terms),   % a long term whose clause file is gone: read the header again
    findall(P-T, member(dep(P, T), Terms), Deps), Deps \== [], ccl_deps_hold(Deps).
ccl_deps_hold([]).
ccl_deps_hold([P-T|Ds]) :- once(catch(time_file(P, T1), _, fail)), T1 =:= T, ccl_deps_hold(Ds).
ccl_sum_dir_ready :- ccl_sum_dir(D), atomic_list_concat(['mkdir -p \'', D, '\''], Mk), once(catch(proc_run(Mk, 10000, _, _), _, true)).
ccl_sum_write(F, Path, Files, unit(Is)) :-
    ccl_sum_dir_ready,
    ( memberchk(Path, Files) -> Fs = Files ; Fs = [Path|Files] ), ccl_dep_times(Fs, Deps), ccl_reader_version(V),
    ccl_collect_items(Is, Ds, [], Ts, [], Gs, [], Es, []),
    ccl_items_typedefs(Is, Names0), ccl_tag_names(Gs, TagNames), append(Names0, TagNames, Names),
    ccl_items_templates(Is, Tmpls),
    ccl_std(S), ccl_sum_deps(Deps, T1), ccl_sum_decls(Ds, T2), ccl_sum_typedefs(Ts, T3), ccl_sum_tags(Gs, T4),   % a term per dep, per declaration ...: a line stays short
    ccl_sum_enums(Es, T5), ccl_sum_names(Names, T6), ccl_sum_tmpls(Tmpls, T7),
    ( nb_current('$ccl_hdr_nxs', Nxs) -> true ; Nxs = [] ), ccl_sum_nothrow(Nxs, T8),   % the header's free functions declared noexcept (0.193, ccl_seed_read/2)
    ccl_concat_codes([[sum(Path, key(V, cpp(S)))], T1, T2, T3, T4, T5, T6, T7, T8], Terms),
    ccl_pp_macros(Ms), ccl_sum_mnames(Ms, Out8), append(Out8, Ms, MTerms),   % the macros the run defined, for the user's file, beside it
    ccl_mac_file(F, M), ccl_tmp_name(M, MT), write_file_from_codes(MT, []), ccl_sum_chunks(MTerms, 100, MT), rename_file(MT, M),
    nb_setval('$ccl_sum_bigs', big(F, 0, [])),
    ccl_tmp_name(F, FT), write_file_from_codes(FT, []), ccl_sum_chunks(Terms, 100, FT),
    nb_getval('$ccl_sum_bigs', big(_, NB, Bigs)), nb_setval('$ccl_sum_bigs', none),
    ( NB > 0 -> ccl_big_file(F, BF), reverse(Bigs, Bigs1), ccl_write_whole(BF, Bigs1) ; true ),
    rename_file(FT, F), ccl_sum_forget(F).   % the .sum last, and whole (a rename): a truncated one must never read as valid
%% a file written through a temporary name and renamed into place, so a run killed mid-write leaves the old file or none;
%% its text the atoms Parts
ccl_write_whole(F, Parts) :- ccl_tmp_name(F, T), write_file_from_codes(T, []), ccl_append_parts(T, Parts), rename_file(T, F).
%% THE TEMPORARY NAME IS THE WRITER'S OWN (0.188): `F.tmp' and the process's id, so two processes that write one header's
%% summary at once -- two builds, or a build's processes for its cold headers (ccl_cold_headers_read/2) -- each write a
%% file of their own and rename it whole; under one name their appends were interleaved, and the rename took the mix
ccl_tmp_name(F, T) :- ( catch(os_pid(P), _, fail) -> true ; P = 0 ), atomic_list_concat([F, '.tmp', P], T).
%% THE PARTS OF A TEXT, ATOMS, APPENDED TO THE FILE F (0.188): consecutive parts joined up to 16,000 characters, a longer
%% part as its codes. append_file_from_codes/2 copies an atom through a buffer of 64 KB and raises a type error past it
%% (cocolog's lib/files.cicili, `char txt [65536]'), and a character takes at most four bytes; a code list has no bound.
ccl_append_parts(_, []) :- !.
ccl_append_parts(F, Ps) :- ccl_parts_batch(Ps, 0, B, Rest),
    ( B == [] -> Rest = [P|Rest1], atom_codes(P, Cs), append_file_from_codes(F, Cs) ; atomic_list_concat(B, A), append_file_from_codes(F, A), Rest1 = Rest ),
    ccl_append_parts(F, Rest1).
ccl_parts_batch([P|Ps], N0, [P|B], Rest) :- atom_length(P, K), N is N0 + K, N =< 16000, !, ccl_parts_batch(Ps, N, B, Rest).
ccl_parts_batch(Ps, _, [], Ps).
%% THE AST BESIDE THE SUMMARY: the flattened header's named items, one clause each -- '$cpp_hdr_ast'(Name, Item) in
%% <name>-<fold>.ast.pl -- consulted by the desugaring when the include is served from the summary, so a program that
%% instantiates a library template needs no second flatten (two minutes for <vector>): what the summary keeps for the
%% parser and the tables, this keeps for the templates. A clause file, not a term a line: ensure_loaded/1 takes a
%% two-megabyte clause in a fraction of a second under --local, where term_to_atom/2 fails past tens of KB a line
%% (cicilang++ never runs over a store, where such a clause would be refused). The names are the desugaring's index
%% names (cpp_index_name/2); an item with none is never asked for by name and is left out.
ccl_ast_file(F, A) :- atom_length(F, N), N1 is N - 4, sub_atom(F, 0, N1, 4, B), atom_concat(B, '.ast.pl', A).
ccl_ast_write(F, unit(Is)) :- ccl_ast_file(F, A), ccl_flat_items([], Is, Flat), cpp_ns_quals(Flat, Qs),
    ccl_tmp_name(A, T), write_file_from_codes(T, []), ccl_ast_chunks(Flat, Qs, 100, T), rename_file(T, A).
%% THE TEXT IS BUILT A HUNDRED ITEMS AT A TIME, each chunk inside \+ \+: cocolog reclaims the heap on backtracking only,
%% and term_to_atom over three thousand items in one deterministic run held a gigabyte of intermediates beside the two
%% megabytes of text it was making (the cold read of <iostream>: 2598 MB). A CHUNK'S TEXT IS THE ATOMS term_to_atom/2
%% MAKES, APPENDED TO THE FILE (0.188; ccl_append_parts/2), where each was turned into codes and the codes appended over
%% and over on their way to the file -- 26 million steps of append/3 in a cold read of <thread>, most of them the text
%% of its AST and its summary. The temporary name is renamed into place at the end.
ccl_ast_chunks([], _, _, _) :- !.
ccl_ast_chunks(Is, Qs, K, T) :-
    ccl_ast_take(K, Is, Some, Rest),
    \+ \+ ( ccl_ast_lines(Some, Qs, Parts), ccl_append_parts(T, Parts) ),
    ccl_ast_chunks(Rest, Qs, K, T).
ccl_ast_take(0, Is, [], Is) :- !.
ccl_ast_take(_, [], [], []) :- !.
ccl_ast_take(K, [I|Is], [I|Some], Rest) :- K1 is K - 1, ccl_ast_take(K1, Is, Some, Rest).
%% the write is allowed to fail -- the header is read again next run -- but never SILENTLY: <iostream>'s AST was
%% the stale one of an older read for as long as ccl_flat_items failed on it, and nothing said so
ccl_ast_trace(T) :- once(catch(cpp_trace(T), _, true)).
%% each item with the NAMESPACE PATH it stood in, since a name the header only declares is called by its
%% mangled symbol and a summary-served run must know the same path the index knew (cpp_mangled_name/3)
ccl_flat_items(Path, Is, Flat) :- ccl_flat_items_(Path, Is, F0), ccl_flat_quals(F0, Flat).
ccl_flat_items_(_, [], []).
ccl_flat_items_(Path, [namespace(_, N, Js)|Is], Flat) :- !, ( atom(N), N \== anon, Path \== c -> append(Path, [N], P1) ; N = inline(_), Path \== c -> append(Path, [N], P1) ; P1 = Path ),   % an inline namespace's segment is `inline(N)' (0.100): in the mangler's path, out of the collision key
    ccl_flat_items_(P1, Js, F1), ccl_flat_items_(Path, Is, F2), append(F1, F2, Flat).
ccl_flat_items_(Path, [extern_c(_, Js)|Is], Flat) :- !, ccl_flat_items_(c, Js, F1), ccl_flat_items_(Path, Is, F2), append(F1, F2, Flat).
ccl_flat_items_(Path, [I|Is], [in(Path, I)|Flat]) :- ccl_flat_items_(Path, Is, Flat).
%% AN ITEM DECLARED BY A NAME QUALIFIED WITH A NAMESPACE BELONGS TO THAT NAMESPACE ([namespace.memdef]/2): libc++
%% defines `template <class _CharT> inline constexpr bool __format::__enable_insertable<basic_string<_CharT>> = true;'
%% in namespace std, and taken for std's own `__enable_insertable' it collided with __format's -- the primary was
%% keyed `__format.__enable_insertable', the specialization belonged to nothing, no string was insertable and
%% std::format wrote into a `__writer_container<void>' (test/cpp/run/qualspec.cpp). Only a qualifier whose every
%% segment is a namespace of the same items counts: `ios_base::flags' defined out of its class stays where it is.
ccl_flat_quals(F0, F) :- findall(S, ( member(in(P, _), F0), P \== c, member(S, P), atom(S) ), Ns0), sort(Ns0, Ns),
    ( Ns == [] -> F = F0 ; ccl_flat_quals_(F0, Ns, F) ).
ccl_flat_quals_([], _, []).
ccl_flat_quals_([in(P, I)|Fs], Ns, [in(P1, I)|Gs]) :- ccl_item_ns_path(P, I, Ns, P1), ccl_flat_quals_(Fs, Ns, Gs).
ccl_item_ns_path(P, I, Ns, P1) :- P \== c, ccl_item_ns_qual(I, Q), Q = [_|_], forall(member(S, Q), ( atom(S), memberchk(S, Ns) )), !, append(P, Q, P1).
ccl_item_ns_path(P, _, _, P).
ccl_item_ns_qual(template(_, _, I), Q) :- !, ccl_item_ns_qual(I, Q).
ccl_item_ns_qual(declare(_, base(_, [class(_, scoped(Q, _), _, _)])), Q).
ccl_item_ns_qual(declare(_, base(_, [struct(scoped(Q, _), _)])), Q).
ccl_item_ns_qual(declaration(_, _, _, [var(scoped(Q, _), _, _)]), Q).
ccl_item_ns_qual(function(_, _, _, scoped(Q, _), _, _, _), Q).
ccl_ast_lines([], _, []).
ccl_ast_lines([in(Path, I)|Is], Qs, Out) :-
    (   catch(cpp_index_name(I, N), _, fail)
    ->  cpp_index_key(Qs, Path, N, Key0),                                   % the same qualified key the index gives a deeper namespace's item (cpp_ns_quals)
        ( Key0 == N -> Key = N, I0 = I ; cpp_qualify_item(N, Key0, I, Iq) -> Key = Key0, I0 = Iq ; Key = N, I0 = I ),
        cpp_qualify_body(Qs, Path, I0, I1),                                     % the deeper namespace's bare uses of a colliding name go to its key (0.100)
        ccl_float_freeze(I1, I2), ccl_ast_clause('$cpp_hdr_ast'(Key, I2), Out, O1), ccl_ast_clause('$cpp_hdr_ast_ns'(Key, Path), O1, O2)   % a float kept exactly (0.132)
    ;   catch(cpp_enum_ns_name(I, EN), _, fail) -> ccl_ast_clause('$cpp_hdr_ast_ns'(EN, Path), Out, O2)   % a header's enum, its namespace path alone (0.112)
    ;   catch(cpp_keyed_typedef_item(Qs, Path, I, Key, I1), _, fail) -> ccl_float_freeze(I1, I2), ccl_ast_clause('$cpp_hdr_ast'(Key, I2), Out, O1), ccl_ast_clause('$cpp_hdr_ast_ns'(Key, Path), O1, O2)   % a keyed namespace-scope typedef, as the index has it (0.201)
    ;   catch(cpp_fwd_class_item(I, FN), _, fail) -> ccl_ast_clause('$cpp_hdr_ast_ns'(FN, Path), Out, O2)   % a class declared and never defined, its namespace path alone (0.201)
    ;   Out = O2 ),
    ccl_ast_lines(Is, Qs, O2).
ccl_ast_clause(T, [A, '.\n'|O], O) :- term_to_atom(T, A).
ccl_sum_mnames([], []) :- !.
ccl_sum_mnames(Ms, [mnames(Ns)|Out]) :- ccl_sum_mnames_(Ms, 100, Ns, Rest), ccl_sum_mnames(Rest, Out).
ccl_sum_mnames_([], _, [], []) :- !.
ccl_sum_mnames_(Ms, 0, [], Ms) :- !.
ccl_sum_mnames_([macro(N, _, _)|Ms], K, [N|Ns], Rest) :- K1 is K - 1, ccl_sum_mnames_(Ms, K1, Ns, Rest).
%% EACH SECTION IS A LIST OF TERMS, and the text is made of them all at the end, a hundred at a time (below):
%% the codes were built term by term and appended, and cocolog reclaims nothing a deterministic run makes
ccl_sum_deps([], []).
ccl_sum_deps([P-T|Ds], [dep(P, T)|Out]) :- ccl_sum_deps(Ds, Out).
ccl_sum_decls([], []).
ccl_sum_decls([N-T|Ds], [decl(N, T)|Out]) :- ccl_sum_decls(Ds, Out).
ccl_sum_typedefs([], []).
ccl_sum_typedefs([N-T|Ds], [typedef(N, T)|Out]) :- ccl_sum_typedefs(Ds, Out).
ccl_sum_tags([], []).
ccl_sum_tags([Tag-Ms|Gs], [tag(Tag, Ms1)|Out]) :- ccl_sum_slim(Ms, Ms1), ccl_sum_tags(Gs, Out).
ccl_sum_enums([], []).
ccl_sum_enums([N-V|Es], [enum(N, V)|Out]) :- ccl_sum_enums(Es, Out).
ccl_sum_names([], []).
ccl_sum_names([N|Ns], [tname(N)|Out]) :- ccl_sum_names(Ns, Out).
ccl_sum_tmpls([], []).
ccl_sum_tmpls([fn(N)|Ns], [ftemplate(N)|Out]) :- !, ccl_sum_tmpls(Ns, Out).
ccl_sum_tmpls([N|Ns], [template(N)|Out]) :- ccl_sum_tmpls(Ns, Out).
ccl_sum_nothrow([], []).
ccl_sum_nothrow([N|Ns], [nothrow(N)|Out]) :- ccl_sum_nothrow(Ns, Out).
%% the terms' text, a hundred terms at a time inside \+ \+, each chunk's atoms appended to the file F (ccl_append_parts/2),
%% as the AST beside it is written (ccl_ast_chunks)
ccl_sum_chunks([], _, _) :- !.
ccl_sum_chunks(Ts, K, F) :-
    ccl_ast_take(K, Ts, Some, Rest),
    \+ \+ ( ccl_sum_terms_out(Some, Parts), ccl_append_parts(F, Parts) ),
    ccl_sum_chunks(Rest, K, F).
%% a class's members without their bodies: what a type needs of them
ccl_sum_slim(none, none) :- !.
ccl_sum_slim([], []).
ccl_sum_slim([method(L, Q, R, N, Ps, V, _)|Ms], [method(L, Q, R, N, Ps, V, none)|Ms1]) :- !, ccl_sum_slim(Ms, Ms1).
ccl_sum_slim([ctor(L, Q, Ps, _, _)|Ms], [ctor(L, Q, Ps, [], none)|Ms1]) :- !, ccl_sum_slim(Ms, Ms1).
ccl_sum_slim([dtor(L, Q, _)|Ms], [dtor(L, Q, none)|Ms1]) :- !, ccl_sum_slim(Ms, Ms1).
ccl_sum_slim([template(L, Ps, M)|Ms], [template(L, Ps, M1)|Ms1]) :- !, ccl_sum_slim([M], [M1]), ccl_sum_slim(Ms, Ms1).
ccl_sum_slim([M|Ms], [M|Ms1]) :- ccl_sum_slim(Ms, Ms1).
ccl_sum_terms_out([], []).
ccl_sum_terms_out([T0|Ts], [L, '.\n'|Out]) :- ccl_float_freeze(T0, T), term_to_atom(T, A), ccl_sum_line(T, A, L), ccl_sum_terms_out(Ts, Out).   % a float kept exactly (0.132)
%% A TERM TOO LONG FOR A LINE goes to the clause file beside the summary, <name>-<fold>.big.pl, as
%% '$ccl_sum_big'(F, I, T), and its line is `big(I)' (0.112): term_to_atom/2 READS through an 8 KB buffer in cocolog
%% (`char buf [8192]' in coco_b_term_to_atom, the neighbour's), so the `tag(...)' lines of libc++'s large classes --
%% basic_string 56 KB, tuple, vector, pair: twelve lines of <vector>'s summary -- were written whole and dropped
%% SILENTLY at the read, and a summary-served run's tag table lacked them. ensure_loaded/1 has no such limit (the AST
%% beside the summary is read so). Only while a .sum is written (`'$ccl_sum_bigs''); the .mac's lines stay as they were.
%% The clauses of the big terms are kept as atoms, the newest first, and joined when the summary is done. The 8 KB read
%% has been gone since cocolog 1.10.6 (`term_to_atom/2 take text of any length'); the clause file stays, as the store's
%% form, and since 0.259 it is read as text, a clause at a time (ccl_big_terms/2), never loaded.
ccl_sum_line(T, A, L) :- atom_length(A, N), N > 8000, nb_current('$ccl_sum_bigs', big(F, I, Bs)), !,
    term_to_atom('$ccl_sum_big'(F, I, T), C), I1 is I + 1, nb_setval('$ccl_sum_bigs', big(F, I1, ['.\n', C|Bs])), term_to_atom(big(I), L).
ccl_sum_line(_, A, A).
ccl_big_file(F, B) :- atom_length(F, N), N1 is N - 4, sub_atom(F, 0, N1, 4, Base), atom_concat(Base, '.big.pl', B).
ccl_concat_codes([], []).
ccl_concat_codes([C|Cs], Out) :- ccl_concat_codes(Cs, O2), append(C, O2, Out).
ccl_tag_names([], []).
ccl_tag_names([Tag-_|Gs], Ns) :- ccl_tag_names(Gs, Ns1), ( atom(Tag), Tag \== anon -> Ns = [Tag|Ns1] ; Ns = Ns1 ).
ccl_items_templates([], []).
ccl_items_templates([template(_, _, I)|Is], Ns) :- !, ccl_items_templates(Is, Ns1),
    (   ccl_template_name(I, N), N \== none -> ( ( I = function(_, _, _, _, _, _, _) ; I = declaration(_, _, _, _) ) -> Ns = [fn(N)|Ns1] ; Ns = [N|Ns1] )   % fn(N): a function or variable template, no type
    ;   Ns = Ns1 ).
ccl_items_templates([namespace(_, _, Js)|Is], Ns) :- !, ccl_items_templates(Js, N1), ccl_items_templates(Is, N2), append(N1, N2, Ns).
ccl_items_templates([extern_c(_, Js)|Is], Ns) :- !, ccl_items_templates(Js, N1), ccl_items_templates(Is, N2), append(N1, N2, Ns).
ccl_items_templates([_|Is], Ns) :- ccl_items_templates(Is, Ns).
%% the files the preprocessor pulled, each with its time
ccl_dep_times([], []).
ccl_dep_times([F|Fs], Ds) :- ccl_dep_times(Fs, Ds1), ( once(catch(time_file(F, T), _, fail)) -> Ds = [F-T|Ds1] ; Ds = Ds1 ).
%% reading a summary: its terms, one per line; the four tables' lists. Parsed
%% ONCE per process (`'$ccl_sum:<F>'`): every consumer of an include --
%% the validity check, the Env, the symbol table, the bulk rebuild, the
%% driver's deps -- asks for the same terms, and a 600-line summary costs
%% 0.15 s to parse (the lines split by atomic_list_concat/3: ccl_split/3 on
%% the codes took 0.26 s by itself)
ccl_sum_terms(F, Terms) :-
    atom_concat('$ccl_sum:', F, K),
    (   nb_current(K, T0), T0 \== none -> Terms = T0
    ;   read_file_to_codes(F, Codes), atom_codes(A, Codes), atomic_list_concat(Lines, '\n', A), ccl_sum_lines(Lines, Terms0),
        ccl_sum_bigs_in(F, Terms0, Terms1), ccl_float_thaw_list(Terms1, Terms), nb_setval(K, Terms) ).
%% the long terms back from the clause file beside the summary, READ AS TEXT, a clause at a time, none of them put in the
%% database (0.259): ensure_loaded/1 put them there, keyed by the summary's full path, and cocolog never reads again a
%% file it has loaded -- so a ~/.cicilang moved to another path matched none of them (absbase.cpp's four headers with a
%% long term read by processes of their own, `0 summaries written', then each read again in the build's process: 94 s,
%% 22 s over a fresh store), and a summary written again in the process (its header's child, ccl_cold_headers_read/2)
%% was served with the long terms of the summary the process had read before it. A `big(I)' with no clause behind it
%% stays, and makes the summary invalid (ccl_sum_valid), so the header is read again rather than served short
ccl_sum_bigs_in(F, Ts0, Ts) :- memberchk(big(_), Ts0), !, ccl_big_file(F, B), ( exists_file(B) -> ccl_big_terms(B, Bigs) ; Bigs = [] ), ccl_sum_bigs_(Ts0, Bigs, Ts).
ccl_sum_bigs_in(_, Ts, Ts).
ccl_sum_bigs_([], _, []).
ccl_sum_bigs_([big(I)|Ts0], Bigs, [T|Ts]) :- memberchk(I-T0, Bigs), !, T = T0, ccl_sum_bigs_(Ts0, Bigs, Ts).
ccl_sum_bigs_([T|Ts0], Bigs, [T|Ts]) :- ccl_sum_bigs_(Ts0, Bigs, Ts).
%% a clause file's long terms, I-T for each '$ccl_sum_big'(_, I, T) in it: the clauses split at their full stops (a line
%% end in a quoted atom is written `\n', so none is inside a clause), each read by term_to_atom/2 into a fresh term (it
%% compares a bound one), which takes a text of any length since cocolog 1.10.6; a clause that does not read is none
ccl_big_terms(B, Bigs) :- read_file_to_codes(B, Cs), atom_codes(A, Cs), atomic_list_concat(Cls, '.\n', A), ccl_big_terms_(Cls, Bigs).
ccl_big_terms_([], []).
ccl_big_terms_([C|Cs], Bigs) :- ( C \== '', catch(term_to_atom(X, C), _, fail), X = '$ccl_sum_big'(_, I, T) -> Bigs = [I-T|Bigs1] ; Bigs = Bigs1 ), ccl_big_terms_(Cs, Bigs1).
ccl_sum_forget(F) :- atom_concat('$ccl_sum:', F, K), nb_setval(K, none), ccl_cache_index('$ccl_sumload:', IK), nb_setval(IK, []).
ccl_sum_lines([], []).
ccl_sum_lines([L|Ls], Ts) :-                                                  % every position bound: a free one enumerates, 0.7 ms a line
    (   L == '' -> Ts = Ts1
    ;   atom_length(L, N), N1 is N - 1, sub_atom(L, N1, 1, 0, '.'), sub_atom(L, 0, N1, 1, A), catch(term_to_atom(T, A), _, fail) -> Ts = [T|Ts1]
    ;   Ts = Ts1 ),
    ccl_sum_lines(Ls, Ts1).
%% the macros beside the summary, <name>-<fold>.mac: the names by the hundred
%% (mnames lines, parsed), then a line per macro AS WRITTEN, parsed on its
%% first use -- 1200 come with <stdio.h>, 30 us each to parse, a file uses a
%% dozen. Read: the lines split, the mnames taken off the front, the rest raw.
ccl_mac_file(F, M) :- atom_length(F, N), N1 is N - 4, sub_atom(F, 0, N1, 4, B), atom_concat(B, '.mac', M).
ccl_mac_lines(M, Names, Raws) :-
    read_file_to_codes(M, Codes), atom_codes(A, Codes), atomic_list_concat(Lines, '\n', A),
    ccl_mac_names(Lines, Names, Raws0), ( append(Raws, [''], Raws0) -> true ; Raws = Raws0 ).
ccl_mac_names([L|Ls], Names, Raws) :-
    atom_length(L, N), N1 is N - 1, sub_atom(L, 0, 7, _, 'mnames('), sub_atom(L, 0, N1, 1, A), catch(term_to_atom(T, A), _, fail), T = mnames(Ns), !,   % a fresh T: term_to_atom compares a bound one
    ccl_mac_names(Ls, Names1, Raws), append(Ns, Names1, Names).
ccl_mac_names(Ls, [], Ls).
%% a summary's four tables, its templates and its names, split once per process
ccl_sum_load(F, D, T, G, E, Tmpls, Names) :-
    ccl_cached_named('$ccl_sumload:', F, sum(D, T, G, E, Tmpls, Names), ccl_sum_load_nocache(F, D, T, G, E, Tmpls, Names)).
ccl_sum_load_nocache(F, D, T, G, E, Tmpls, Names) :-
    ccl_sum_terms(F, Terms),
    findall(N-Ty, member(decl(N, Ty), Terms), D), findall(N-Ty, member(typedef(N, Ty), Terms), T),
    findall(Tag-Ms, member(tag(Tag, Ms), Terms), G), findall(N-V, member(enum(N, V), Terms), E),
    findall(N, member(template(N), Terms), Tmpls0), findall(fn(N), member(ftemplate(N), Terms), Tmpls1), findall(nx(N), member(nothrow(N), Terms), Tmpls2),
    append(Tmpls1, Tmpls2, Tmpls12), append(Tmpls0, Tmpls12, Tmpls),   % the names noted with the templates: nx(N) a free function declared noexcept (0.193)
    findall(N, member(tname(N), Terms), Names).
%% a summary in the symbol table, as ccl_items_note puts a unit there
ccl_sum_note(F) :-
    ccl_sum_load(F, D, T, G, E, Tmpls, Names),
    ccl_scope_add(D),
    ccl_tab_add('$ccl_typedefs', T),
    ccl_tab_add('$ccl_tags', G), ccl_tables_changed,
    nb_getval('$ccl_enums', E0), append(E, E0, E1), nb_setval('$ccl_enums', E1),
    ccl_note_templates(Tmpls), ccl_add_envs(Names).
%% a summary's names into the sets of templates and of the Env, the new ones logged (ccl_env_log/1; until 0.187 a list
%% beside each set took them in ONE read and one write: one at a time, every addition had copied the whole list,
%% 190 names against 500 -- 15 ms of every rebuild of the symbol table)
ccl_note_templates(Ns0) :- ccl_split_fn_templates(Ns0, Ns, Fns, Nxs),
    ccl_set_adds('$ccl_tmpls', Ns), ccl_set_adds('$ccl_ftmpls', Fns), ccl_set_adds('$ccl_lnxs', Nxs).
ccl_split_fn_templates([], [], [], []).
ccl_split_fn_templates([fn(N)|Ns], [N|Ps], [N|Fs], Xs) :- !, ccl_split_fn_templates(Ns, Ps, Fs, Xs).
ccl_split_fn_templates([nx(N)|Ns], Ps, Fs, [N|Xs]) :- !, ccl_split_fn_templates(Ns, Ps, Fs, Xs).   % a free function the header declares noexcept (0.193)
ccl_split_fn_templates([N|Ns], [N|Ps], Fs, Xs) :- ccl_split_fn_templates(Ns, Ps, Fs, Xs).
ccl_add_envs(Ns) :- ccl_set_new(Ns, '$ccl_envs', New), ccl_env_log(New).
%% the names not in the set yet, added to it as they are found (a duplicate among them counted once)
ccl_set_new([], _, []).
ccl_set_new([N|Ns], Set, New) :- ( ccl_set_add_new(Set, N) -> New = [N|New1] ; New = New1 ), ccl_set_new(Ns, Set, New1).
%% a template head's parameters that it added to the env: those among the names logged since its mark (ccl_env_since/2)
ccl_new_names([], _, []).
ccl_new_names([N|Ns], Added, New) :- ( atom(N), memberchk(N, Added) -> New = [N|New1] ; New = New1 ), ccl_new_names(Ns, Added, New1).
ccl_partial(U, whole, U) :- !.
ccl_partial(U, stopped(L, near(F)), partial(U, line(L), near(F))).
ccl_parse_file(Path, unit(Is), Info) :-
    read_file_to_codes(Path, Codes),
    ccl_tokens(Codes, Tokens, RestCodes),
    ( RestCodes == [] -> true ; throw(lexical(Path)) ),
    ccl_with_file(Path, ( ccl_unit(Tokens, unit(Is), Rest), ccl_rest_info(Rest, Info) )).
ccl_rest_info([], whole) :- !.
ccl_rest_info([tok(_, _, L)|_], stopped(L, near(F))) :- ccl_farthest(F).

%% the file through the preprocessor (library(ccl_pp)): its directives run,
%% its includes pulled in, its macros expanded -- one token stream, read by
%% the same grammar; Files are every file it pulled, the includer first
ccl_pp_parse(Path, unit(Is), Info, Files) :-
    catch(ccl_pp_file(Path, Tokens, Files), pp_error(PL, PM), throw(error(pp_error(PM), here(Path, PL)))),   % a header's #embed of nothing
    ccl_with_file(Path, ( ccl_unit(Tokens, unit(Is), Rest), ccl_rest_info(Rest, Info) )).

%% ---- a header's macros, for the user's file -----------------------------------
%% Made ready before the file's run (ccl_pp_prescan): the header read through
%% the reader's door -- its unit cached, its summary written -- then its macro
%% table from the summary (C++), the store ('$ccl_hmacros:<Path>' rows beside
%% the items, keyed like them), or one standalone run of the preprocessor
%% (a raw-read header, once per store); kept per process in '$ccl_hm:<Path>'.
ccl_header_macros_ready(Spec, From) :-
    (   ccl_resolve_include(Spec, From, Path), \+ sub_atom(Path, _, 3, 0, '.pl')
    ->  ccl_inc_kind(Spec, Kind), nb_setval('$ccl_inc_kind', Kind),
        ( ccl_include_read(Path, _) -> true ; true ),
        ( ccl_header_macros(Path, _) -> true ; true )
    ;   true ).

%% ---- the cold headers of a build, each read by a process of its own (0.188) ----
%% THE OWNER'S DESIGN: before its file's run, a C++ build that the command runs (ccl_drive/2 sets '$ccl_children') finds
%% the library headers its includes name that no valid summary serves, and where two or more are cold it starts one
%% cocolog for each, J at a time (ccl_jobs/1: $CICILANG_JOBS, else the machine's processors), each reading its header as
%% the build's prescan reads it (ccl_drive_header/3) and writing its summary; the build waits for them, and its prescan
%% then serves each header from its summary. Since 0.186 a header's read does not depend on what the process read before
%% it, so a header read by a process of its own gives the summary the build would write. A child that has not ended
%% after 1800 s is killed, its session by signal 9, and one that ends without a summary leaves its header to the build,
%% which reads it as before. A child runs in a session of its own (proc_spawn/2), so a build killed from outside does not
%% take it along: `ulimit -t' holds its own CPU time to 1800 s. One cold header is read in the build's own process.
ccl_cold_headers_read(Specs, From) :-
    (   ccl_lang(cpp), nb_current('$ccl_children', opts(Opts0)), ( nb_current('$pp_ftm', FT0), pp_cfg_sans_user(FT0, FT), FT \== [] -> Opts = [ftm(FT)|Opts0] ; Opts = Opts0 ),   % the program's feature-test macros too (0.214), no includer's macro (0.298)
        ccl_cold_headers(Specs, From, [], Cold), Cold = [_, _|_], ccl_jobs(J), J >= 2
    ->  get_time(T0), catch(ccl_kids_run(Cold, From, Opts, J), _, true), get_time(T1),
        findall(F, ( member(_-Path, Cold), ccl_sum_file(Path, F), ccl_sum_forget(F), ccl_sum_valid(F) ), Fs),   % forgotten: the check parsed it before its child wrote it
        length(Cold, N), length(Fs, M), S is T1 - T0, format(atom(SA), '~1f', [S]),
        dr_say(['the ', N, ' cold headers given to processes of their own, ', J, ' at a time: ', M, ' summaries written in ', SA, ' s'])
    ;   true ).
ccl_cold_headers([], _, _, []).
ccl_cold_headers([Spec|Specs], From, Seen, Cold) :-
    (   ccl_cold_header(Spec, From, Path), \+ memberchk(Path, Seen) -> Cold = [Spec-Path|Cold1], Seen1 = [Path|Seen]
    ;   Cold = Cold1, Seen1 = Seen ),
    ccl_cold_headers(Specs, From, Seen1, Cold1).
%% a library header (`<name>' or `#include_next'), no `.pl' macro file, not read in this process, no valid summary
ccl_cold_header(Spec, From, Path) :-
    ccl_inc_kind(Spec, system), once(ccl_resolve_include(Spec, From, Path)), \+ sub_atom(Path, _, 3, 0, '.pl'),
    \+ ccl_unit_cached(Path, _, _), ccl_sum_file(Path, F), \+ ccl_sum_valid(F).
%% the children at once: $CICILANG_JOBS where it is a number (1 reads every header in the build's own process), else the
%% machine's processors (library(os)'s os_cpus/1)
ccl_jobs(J) :-
    (   catch(os_env('CICILANG_JOBS', A), _, fail), catch(atom_number(A, J0), _, fail), integer(J0) -> J = J0
    ;   catch(os_cpus(J0), _, fail), integer(J0) -> J = J0
    ;   J = 1 ).
ccl_kids_run(Cold, From, Opts, J) :- current_prolog_flag(executable, Exe), ccl_kids(Cold, [], J, ctx(Exe, From, Opts)).
%% a child started while one of the J places is free; else the ended ones reaped, a tenth of a second between looks
ccl_kids([], [], _, _) :- !.
ccl_kids([H|Hs], Run, J, Ctx) :- length(Run, R), R < J, !,
    ( ccl_kid_start(H, Ctx, Kid) -> Run1 = [Kid|Run] ; Run1 = Run ),
    ccl_kids(Hs, Run1, J, Ctx).
ccl_kids(Hs, Run, J, Ctx) :- ccl_kids_reap(Run, Run1), ( Run1 == Run -> proc_sleep(100) ; true ), ccl_kids(Hs, Run1, J, Ctx).
%% one child: /bin/sh, in a session of its own, runs cocolog over the build's options and the header's spec, its output
%% to nowhere and its input none (a query reads its input)
ccl_kid_start(Spec-_, ctx(Exe, From, Opts), kid(Pid, T0)) :-
    term_to_atom(ccl_drive_header(Spec, From, Opts), G0), atom_concat('use_module(library(cicilang)), ', G0, G),
    ccl_sh_quote(Exe, QE), ccl_sh_quote(G, QG),
    atomic_list_concat(['ulimit -t 1800 2>/dev/null; exec ', QE, ' --local query ', QG, ' > /dev/null 2>&1 < /dev/null'], Cmd),
    catch(proc_spawn(Cmd, Pid), _, fail), get_time(T0),
    ccl_spec_text(Spec, Name), dr_say(['read ', Name, ' in a process of its own']).
%% the children still running: an ended one reaped (or gone), one past its 1800 s killed
ccl_kids_reap([], []).
ccl_kids_reap([kid(Pid, T0)|Ks], Run) :-
    (   catch(proc_wait(Pid, 0, _), _, fail) -> Run = Run1
    ;   \+ catch(proc_running(Pid), _, fail) -> Run = Run1
    ;   get_time(T), T - T0 > 1800 -> G is -Pid, ( catch(proc_kill(G, 9), _, fail) -> true ; true ), ( catch(proc_wait(Pid, 5000, _), _, fail) -> true ; true ), Run = Run1
    ;   Run = [kid(Pid, T0)|Run1] ),
    ccl_kids_reap(Ks, Run1).
%% an atom in single quotes for /bin/sh: each quote in it closed, escaped and opened again
ccl_sh_quote(A, Q) :- atomic_list_concat(Ps, '\'', A), atomic_list_concat(Ps, '\'\\\'\'', B), atomic_list_concat(['\'', B, '\''], Q).
ccl_spec_text(system(N), T) :- !, atomic_list_concat(['<', N, '>'], T).
ccl_spec_text(local(N), T) :- !, atomic_list_concat(['"', N, '"'], T).
ccl_spec_text(next(S), T) :- !, ccl_spec_text(S, T).
ccl_spec_text(S, T) :- term_to_atom(S, T).

%% the table's kind: indexed(TK) (every name in '$ccl_hml'(Name, TK, Def), TK the memo's key) or
%% store(Key) (answered by name from the rows); nothing of a header in neither
ccl_header_macros(Path, Kind) :-
    ccl_hm_key(Path, K),
    (   nb_current(K, K0), K0 \== none -> Kind = K0
    ;   ccl_header_macros_(Path, Kind), nb_setval(K, Kind) ).
ccl_header_macros_known(Path, Kind) :- ccl_hm_key(Path, K), nb_current(K, Kind), Kind \== none.
%% THE MEMO IS PER LEVEL, as the unit cache is (ccl_unit_key): a header's macros at -std=c23 are not its C17 ones (0.99;
%% keyed by the path alone, a C17 fixture after a C23 one in one process was served the C23 rows' key, whose rows a later
%% read had retracted -- `undeclared(EOF)' in the compile gate, never alone)
ccl_hm_key(Path, K) :- ccl_read_level(Std), atomic_list_concat(['$ccl_hm:', Path, '@', Std], K).
%% indexed(TK): a summary's, as facts '$ccl_hml'(Name, TK, raw(Line)), TK the memo's key (0.239: the path, which two
%% configurations of one header shared) -- an
%% assert is 2 us and the lookup by name 3 us, where a global per name cost
%% 25 us each for 1200 names; a fact is a store row under --embed, which the
%% C++ mode never runs over (cicilang++ is --no-kb). store(Key): the rows.
%% list: a header the store would not take, its macros in a global, searched.
ccl_header_macros_(Path, indexed(TK)) :- ccl_lang(cpp), ccl_sum_file(Path, F), ccl_sum_valid(F), ccl_mac_file(F, M), exists_file(M), !, ccl_hm_key(Path, TK), ccl_mac_lines(M, Names, Raws), dynamic('$ccl_hml'/3), ccl_hml_assert(Names, Raws, TK).
ccl_header_macros_(Path, store(K)) :- ccl_kb_macros_cached(Path, K), !.
ccl_header_macros_(Path, Kind) :-
    ccl_pp_file(Path, _, Files), ccl_pp_macros(Ms), ccl_kb_remember_macros(Path, Files, Ms),
    (   ccl_kb_macros_cached(Path, K) -> Kind = store(K)
    ;   ccl_hm_key(Path, TK), atom_concat('$ccl_hmlist:', TK, KL), nb_setval(KL, Ms), Kind = list(KL) ).
ccl_hml_assert([], _, _) :- !.
ccl_hml_assert(_, [], _) :- !.
ccl_hml_assert([N|Ns], [R|Rs], Path) :- assertz('$ccl_hml'(N, Path, raw(R))), ccl_hml_assert(Ns, Rs, Path).
ccl_hml_list(KL, N, Ps, A) :- nb_getval(KL, Ms), memberchk(macro(N, Ps, text(A)), Ms).
%% the store's rows for a header's macros: one predicate per header, as the
%% items, a row per macro under its NAME (the lookup is by name) and a dep row
%% per file of the closure under '$dep' (no identifier)
ccl_kb_hm_name(Path, F) :- atom_concat('$ccl_hmacros:', Path, F).
ccl_kb_hm(Path, F) :- ccl_kb_hm_name(Path, F), dynamic(F/3).
ccl_kb_macro(Path, K, N, Ps, A) :- ccl_kb_hm_name(Path, F), T =.. [F, N, K, macro(N, Ps, text(A))], once(T).
%% the deps -- every file of the header's closure, 38 for <stdio.h> -- are rows
%% too, dep(I), since one clause naming them all is over the store's budget
ccl_kb_remember_macros(Path, Files, Ms) :-
    ccl_kb_ready,
    (   ccl_kb_key(Path, K)
    ->  findall(P-PK, ( member(P, Files), ccl_kb_key(P, PK) ), Deps),
        K = key(_, KV), retractall('$ccl_hmeta'(Path, key(_, KV), _)), ccl_kb_hm(Path, F), T0 =.. [F, _, key(_, KV), _], retractall(T0),   % THIS LEVEL's rows only (0.99): the C17 rows and the C23 rows of one header live side by side
        (   catch(( ccl_kb_store_macros(Ms, F, K, 0, N), ccl_kb_store_deps(Deps, F, K, 0, ND), assertz('$ccl_hmeta'(Path, K, meta(N, ND))) ),
                  error(resource_error(clause_length), _), fail)
        ->  true
        ;   T1 =.. [F, _, _, _], retractall(T1), retractall('$ccl_hmeta'(Path, _, _)) )
    ;   true ).
ccl_kb_store_macros([], _, _, N, N).
ccl_kb_store_macros([macro(N, Ps, B)|Ms], F, K, C0, C) :- T =.. [F, N, K, macro(N, Ps, B)], assertz(T), C1 is C0 + 1, ccl_kb_store_macros(Ms, F, K, C1, C).
ccl_kb_store_deps([], _, _, N, N).
ccl_kb_store_deps([D|Ds], F, K, N0, N) :- T =.. [F, '$dep', K, D], assertz(T), N1 is N0 + 1, ccl_kb_store_deps(Ds, F, K, N1, N).   % one key for the dep rows: the store indexes an atom, not dep(I)
%% valid when the meta row is there under the header's key and every dep is at
%% its remembered time; the macro rows are not counted (a partial write was
%% retracted where it failed)
ccl_kb_macros_cached(Path, K) :-
    ccl_kb_ready, ccl_kb_key(Path, K), '$ccl_hmeta'(Path, K, meta(_, ND)), !,
    ccl_kb_hm(Path, F), TD =.. [F, '$dep', K, D], findall(D, TD, Deps), length(Deps, ND), ccl_kb_deps_fresh(Deps).

%% ---- the path ----------------------------------------------------------------
ccl_resolve_include(path(P), _, P) :- !, exists_file(P).                       % a module's interface unit, found by ccl_module_path (0.108)
ccl_resolve_include(Spec, _, N) :- ( Spec = local(N) ; Spec = system(N) ), sub_atom(N, 0, 1, _, '/'), !, exists_file(N).   % AN ABSOLUTE PATH, as it is written (0.260), as clang and gcc take it (the place is the implementation's, C17 6.10.2/2-3): it was joined to the includer's directory and never found
ccl_resolve_include(local(N), From, Path) :-
    From \== none, file_directory_name(From, Dir), atomic_list_concat([Dir, '/', N], P0), exists_file(P0), !, Path = P0.
ccl_resolve_include(Spec, _, Path) :-
    ( Spec = local(N) ; Spec = system(N) ),
    ccl_include_path(Dirs), member(D, Dirs), atomic_list_concat([D, '/', N], P), exists_file(P), !, Path = P.
ccl_resolve_include(next(Spec), From, Path) :-
    ( Spec = local(N) ; Spec = system(N) ),
    ccl_include_path(Dirs), ( ccl_dirs_after(Dirs, From, Rest) -> true ; Rest = Dirs ),
    member(D, Rest), atomic_list_concat([D, '/', N], P), exists_file(P), !, Path = P.
%% an imported module's interface: read earlier in this run, else NAME.cppm (and kin) beside the importer, then on the path
ccl_module_path(N, Path) :- nb_current('$ccl_modules', M), memberchk(N-Path, M), !.
ccl_module_path(N, Path) :- atomic_list_concat(Parts, ':', N), atomic_list_concat(Parts, '-', Base), ccl_global('$ccl_file', From, none),
    ( From == none -> Dirs0 = [] ; file_directory_name(From, D0), Dirs0 = [D0] ), ccl_include_path(Ds), append(Dirs0, Ds, Dirs),
    member(D, Dirs), member(E, ['.cppm', '.ccm', '.cxxm', '.ixx', '.mpp']), atomic_list_concat([D, '/', Base, E], Path), exists_file(Path), !.
ccl_dirs_after([D|Ds], From, Ds) :- atom_concat(D, '/', DP), atom_concat(DP, Base, From), \+ sub_atom(Base, _, _, _, '/'), !.
ccl_dirs_after([_|Ds], From, Rest) :- ccl_dirs_after(Ds, From, Rest).

ccl_include_path(Dirs) :-
    (   ccl_global('$ccl_incpath', D0, none), D0 \== none -> Dirs = D0
    ;   ccl_user_dirs(U), ccl_library_dirs(Ls), ccl_ccllib_dirs(Ls, Cs), ccl_toolchain_dirs(T), append([U, Ls, Cs, T], Dirs), nb_setval('$ccl_incpath', Dirs) ).
%% the cocolog library directories, so `#include <ccl_format.pl>' finds the
%% macro files this repository ships beside its grammars; and CCLLIB'S (0.274; CCLLIB.md): each one's ccllib/, so
%% `#include <vector.pl>' finds library/ccllib/vector.pl -- behind the user's directories and before the toolchain's
ccl_ccllib_dirs(Ls, Cs) :- findall(D, ( member(L, Ls), atom_concat(L, '/ccllib', D), exists_directory(D) ), Cs).
ccl_library_dirs(Ds) :-
    ( once(catch(os_env('COCOLOG_LIBRARY', V), _, fail)), V \== '' -> atom_codes(V, Cs), ccl_split(Cs, 0':, Parts), ccl_atoms(Parts, Ds) ; Ds = [] ).
ccl_include_path_reset :- nb_setval('$ccl_incpath', none).
ccl_user_dirs(Ds) :-
    findall(D, ccl_include_dir(D), Ds0),
    ( catch(os_env('CICILANG_INCLUDE', V), _, fail), V \== '' -> atom_codes(V, Cs), ccl_split(Cs, 0':, Parts), ccl_atoms(Parts, Es), append(Ds0, Es, Ds) ; Ds = Ds0 ).
%% the toolchain's directories, in the order a compiler searches them, from
%% where the conventions put them -- no tool is run (owner's rule: the
%% embedded LLVM is the whole toolchain): the C++ library's headers first in
%% C++ ($LLVM, Homebrew's LLVM, else the SDK's own copy), then this compiler's
%% freestanding headers (library/include beside the grammars: stddef.h,
%% stdarg.h, stdbool.h, float.h ...), the local prefix, then the SDK
%% ($SDKROOT, the Command Line Tools' SDK, Xcode's) or /usr/include
ccl_toolchain_dirs(Ds) :-
    ( ccl_lang(cpp) -> ccl_cxx_dirs(Cxx) ; Cxx = [] ),
    ccl_own_include_dirs(Own), ccl_sdk_dirs(Sdk),
    append(Cxx, Own, D1), append(D1, ['/usr/local/include', '/opt/homebrew/include'], D2), append(D2, Sdk, D3),
    ccl_existing_dirs(D3, Ds).

%% ONE C++ library, the first found: two libc++ trees on the path mix their
%% wrappers (the SDK's ctype.h under LLVM's cctype defines _LIBCPP_CTYPE_H
%% and trips an #error)
ccl_cxx_dirs(Ds) :-
    ccl_llvm_roots(Rs), findall(D, ( member(R, Rs), atom_concat(R, '/include/c++/v1', D) ), D0), ccl_sdk_dirs(S), findall(D, ( member(Sd, S), atom_concat(Sd, '/c++/v1', D) ), D1), append(D0, D1, All),
    ( member(D, All), exists_directory(D) -> Ds0 = [D] ; Ds0 = [] ),
    ( Ds0 = [HD], ccl_cross_sysroot(SR), atom_concat(SR, HD, TD), exists_directory(TD) -> Ds = [TD] ; Ds = Ds0 ).   % ANOTHER MACHINE'S libc++ (0.161): the tree the host would read, under the cross sysroot -- Debian's and Ubuntu's arm64 packages (libc++-18-dev, libc++1-18, libc++abi1-18, libunwind-18) extracted into /usr/aarch64-linux-gnu put it at /usr/aarch64-linux-gnu/usr/lib/llvm-18; without it the host's headers, which compile and do not link
ccl_llvm_roots(Rs) :- ( catch(os_env('LLVM', L), _, fail), L \== '' -> Rs0 = [L, '/usr/local/opt/llvm', '/opt/homebrew/opt/llvm'] ; Rs0 = ['/usr/local/opt/llvm', '/opt/homebrew/opt/llvm'] ),
    ccl_debian_llvm_roots(Ds), append(Rs0, Ds, Rs).
%% Debian and Ubuntu keep each LLVM under /usr/lib/llvm-NN, libc++ at /usr/lib/llvm-NN/include/c++/v1 (the libc++-NN-dev
%% package); the newest first, since two are often installed
ccl_debian_llvm_roots(Ds) :-
    (   exists_directory('/usr/lib'), once(catch(directory_files('/usr/lib', Fs), _, fail))
    ->  findall(N-D, ( member(F, Fs), atom_concat('llvm-', NA, F), atom_number(NA, N), integer(N), atomic_list_concat(['/usr/lib/', F], D) ), Ps),
        msort(Ps, Ss), reverse(Ss, Rs), findall(D, member(_-D, Rs), Ds)
    ;   Ds = [] ).
ccl_own_include_dirs(Ds) :- ccl_library_dirs(Ls), findall(D, ( member(L, Ls), atom_concat(L, '/include', D) ), Ds).
ccl_sdk_dirs(Ds) :- ccl_cross_sysroot(R), !, atom_concat(R, '/include', D), Ds = [D, '/usr/include'].   % ANOTHER MACHINE'S C LIBRARY (0.131): the cross sysroot's headers, as clang --target searches them, and never this host's multiarch directory
ccl_sdk_dirs(Ds) :-
    ( catch(os_env('SDKROOT', S), _, fail), S \== '' -> atom_concat(S, '/usr/include', D0), Ds = [D0|Ds1] ; Ds = Ds1 ),
    ccl_multiarch_dirs(M),
    append(['/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include',
            '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include'], M, D2),
    append(D2, ['/usr/include'], Ds1).
%% a target of another machine (dr_set_target/1) on Debian and Ubuntu: the cross toolchain's sysroot, /usr/<triplet>
ccl_cross_sysroot(R) :- nb_current('$ccl_target', target(A, linux, _)), \+ catch(ccl_host_arch(A), _, fail),
    ( A == arm64 -> R = '/usr/aarch64-linux-gnu' ; A == x86_64 -> R = '/usr/x86_64-linux-gnu' ), atom_concat(R, '/include', D), exists_directory(D).
%% DEBIAN AND UBUNTU SPLIT THE C LIBRARY'S HEADERS, and the split half comes FIRST: <bits/...>
%% and <sys/cdefs.h> live in /usr/include/<triplet>, which clang searches before /usr/include
%% (`clang -E -v' lists it there). Without it the closure of <stdio.h> stops at 146 lines against
%% clang's 828 over 35 files, `__BEGIN_DECLS', `__THROW', `__wur' and `_Nonnull((1))' -- all of
%% them sys/cdefs.h's -- reach the reader unexpanded, and every declaration wearing one is lost:
%% `undeclared(printf)' for a two-line program. Both triplets are offered and ccl_existing_dirs
%% keeps whichever is there, so macOS, where neither exists, is untouched.
ccl_multiarch_dirs(['/usr/include/x86_64-linux-gnu', '/usr/include/aarch64-linux-gnu']).
ccl_existing_dirs([], []).
ccl_existing_dirs([D|Ds], Es) :- ccl_existing_dirs(Ds, Es1), ( exists_directory(D), \+ memberchk(D, Es1) -> Es = [D|Es1] ; Es = Es1 ).
ccl_split([], _, [[]]).
ccl_split([C|Cs], Sep, Parts) :- ccl_split(Cs, Sep, [P|Ps]), ( C =:= Sep -> Parts = [[], P|Ps] ; Parts = [[C|P]|Ps] ).
ccl_atoms([], []).
ccl_atoms([[]|T], As) :- !, ccl_atoms(T, As).
ccl_atoms([Cs|T], [A|As]) :- atom_codes(A, Cs), ccl_atoms(T, As).

%% ---- what an included unit declares ----------------------------------------------
ccl_include_typedefs(file(_, _, Unit), Env0, Env) :- !, ccl_unit_typedefs(Unit, Names), append(Names, Env0, Env).
ccl_include_typedefs(_, Env, Env).
ccl_unit_typedefs(unit(Is), Ns) :- !, ccl_items_typedefs(Is, Ns).
ccl_unit_typedefs(partial(U, _, _), Ns) :- !, ccl_unit_typedefs(U, Ns).
ccl_unit_typedefs(summary(F), Ns) :- !, ccl_sum_load(F, _, _, _, _, _, Ns).           % a C++ library header's summary: its type names
ccl_unit_typedefs(_, []).
ccl_items_typedefs([], []).
ccl_items_typedefs([typedef(_, Ds)|T], Ns) :- !, ccl_declared_names(Ds, N1), ccl_items_typedefs(T, N2), append(N1, N2, Ns).
ccl_items_typedefs([include(_, _, R)|T], Ns) :- !, ccl_include_typedefs(R, [], N1), ccl_items_typedefs(T, N2), append(N1, N2, Ns).
ccl_items_typedefs([declare(_, base(_, [S]))|T], [N|Ns]) :- ccl_lang(cpp), ccl_cpp_type_name(S, N), !, ccl_items_typedefs(T, Ns).   % C++: a class's, a struct's, an enum class's name is a type name
ccl_items_typedefs([template(_, _, declare(_, base(_, [S])))|T], [N|Ns]) :- ccl_lang(cpp), ccl_cpp_type_name(S, N), !, ccl_items_typedefs(T, Ns).
ccl_items_typedefs([namespace(_, _, Js)|T], Ns) :- ccl_lang(cpp), !, ccl_items_typedefs(Js, N1), ccl_items_typedefs(T, N2), append(N1, N2, Ns).
ccl_items_typedefs([_|T], Ns) :- ccl_items_typedefs(T, Ns).
ccl_cpp_type_name(class(_, N, _, _), N) :- atom(N), N \== anon.
ccl_cpp_type_name(struct(N, _), N) :- atom(N), N \== anon.
ccl_cpp_type_name(enum_class(N, _), N) :- atom(N).

%% ccl_declares(+Unit, +Name, -Item): the item declaring Name, here or in an
%% include, depth first in file order
ccl_declares(unit(Is), Name, Item) :- !, ccl_items_declare(Is, Name, Item).
ccl_declares(partial(U, _, _), Name, Item) :- ccl_declares(U, Name, Item).
ccl_items_declare([I|_], Name, I) :- ccl_item_declares(I, Name), !.
ccl_items_declare([include(_, _, file(_, _, U))|_], Name, Item) :- ccl_declares(U, Name, Item), !.
ccl_items_declare([_|T], Name, Item) :- ccl_items_declare(T, Name, Item).
ccl_item_declares(function(_, _, _, Name, _, _, _), Name).
ccl_item_declares(declaration(_, _, _, Ds), Name) :- memberchk(var(Name, _, _), Ds).
ccl_item_declares(typedef(_, Ds), Name) :- memberchk(var(Name, _, _), Ds).
