%% cicilang -- library(ccl_driver): what the `cicilang' command does, once
%% bin/cicilang has read its arguments the way clang reads them.
%%
%%   ccl_drive(+Inputs, +Options)
%%     Inputs   files: .c (read, checked, lowered), .ll (compiled as IR),
%%              .o .a .so .dylib (handed to the linker)
%%     Options  compile_only (-c), assembly (-S), emit_llvm (-emit-llvm),
%%              syntax_only (-fsyntax-only), ast (-ast-dump), out(File) (-o),
%%              opt(Flag) ('-O2' ...), include(Dir) (-I), link(Flag) (-l -L
%%              -shared -framework ...), verbose (-v)
%%
%% Every .c goes through cicilang_ast, cicilang_ir and cicilang_compile; then, unless
%% -c, -S, -emit-llvm or -fsyntax-only, everything links into one output
%% (a.out when -o is not given), as clang does. A diagnostic is printed as
%% clang prints one -- file:line: error: what -- and the run ends `cicilang: N
%% error(s)'; a clean run ends `cicilang: ok'.

:- use_module(library(process)).

ccl_drive(Inputs, Options) :- once(dr_drive(Inputs, Options)).          % one answer: the query loop would re-run a second
dr_drive(Inputs, Options) :-
    dr_setup(Options, Flags), nb_setval('$ccl_children', opts(Options)),   % a cold library header read by a process of its own (0.188)
    dr_inputs(Inputs, Options, Flags, Objects),
    nb_getval('$dr_errors', N),
    (   N > 0 -> true
    ;   ( dr_no_link(Options) ; Objects == [] ) -> true
    ;   ( memberchk(out(Out), Options) -> true ; Out = 'a.out' ),
        findall(F, member(link(F), Options), LinkFlags),
        dr_say(['link ', Out]),
        dr_catch(cicilang_link(Objects, LinkFlags, Out), E, dr_report(Out, E)) ),
    nb_getval('$dr_errors', N1),
    ( N1 =:= 0 -> write('cicilang: ok') ; write('cicilang: '), write(N1), write(' error(s)') ), nl.
%% THE OPTIONS AS A RUN OF THE COMMAND SETS THEM: the language and its level, another machine, the command line's macros
%% and directories, the compile's flags (0.188: a cold header's process sets them as its build does, ccl_drive_header/3)
dr_setup(Options, Flags) :-
    ccl_ensure_globals, nb_setval('$dr_errors', 0),
    ( memberchk(lang(cpp), Options) -> nb_setval('$ccl_lang_forced', cpp), nb_setval('$ccl_lang', cpp) ; nb_setval('$ccl_lang_forced', none) ),   % cicilang++: everything C++
    ( memberchk(std(Std), Options) -> nb_setval('$ccl_std', Std) ; nb_setval('$ccl_std', 17) ),                                       % -std=c++20: the level libc++ keys on
    ( memberchk(cstd(CStd), Options) -> nb_setval('$ccl_c_std', CStd) ; nb_setval('$ccl_c_std', 17) ),                                 % -std=c23: C's own level, the forms and __STDC_VERSION__
    ( memberchk(trigraphs, Options) -> nb_setval('$ccl_trigraphs', yes) ; nb_setval('$ccl_trigraphs', no) ),                          % -std=c99/c11/c17 (ISO, not gnu) or -trigraphs: phase 1's nine sequences, as clang
    ( memberchk(iso, Options) -> nb_setval('$ccl_iso', yes) ; nb_setval('$ccl_iso', no) ),                                                % -std=c17, c23, c++20 ... (ISO, not gnu): __STRICT_ANSI__, as clang (0.214)
    ( memberchk(ftm(FT), Options) -> nb_setval('$pp_ftm', FT) ; nb_setval('$pp_ftm', []) ),                                          % a cold header's process: the program's feature-test macros (0.214, pp_ftm_find/1)
    ( memberchk(no_rtti, Options) -> nb_setval('$ccl_rtti', no) ; nb_setval('$ccl_rtti', yes) ),                                       % -fno-rtti (0.191): libc++'s no-RTTI configuration, the program's typeid refused
    ( memberchk(no_exceptions, Options) -> nb_setval('$ccl_exceptions', no) ; nb_setval('$ccl_exceptions', yes) ),                     % -fno-exceptions (0.193): libc++'s no-exceptions configuration, the program's throw and try refused
    ( memberchk(target(Tg), Options) -> dr_set_target(Tg) ; true ),                % --target=TRIPLE (0.131): another machine's macros, headers, types, ABI, back end and linker
    findall(D, ( member(O, Options), ( O = define(_) ; O = undef(_) ), D = O ), Ds), ccl_pp_cmdline(Ds),                       % -D and -U (0.112): the macros the command line defines and undefines, before every file's own
    forall(member(include(D), Options), assertz(ccl_include_dir(D))),
    ( memberchk(opt(O), Options) -> Flags0 = [O] ; Flags0 = ['-O0'] ),
    ( memberchk(target(Tg1), Options) -> atom_concat('--target=', Tg1, TF), append(Flags0, [TF], Flags) ; Flags = Flags0 ),   % the embedded LLVM's target
    ( memberchk(verbose, Options) -> nb_setval('$dr_verbose', yes) ; nb_setval('$dr_verbose', no) ),
    nb_setval('$ccl_debug', none), nb_setval('$ccl_debug_kind', none).
%% ONE COLD LIBRARY HEADER, READ FOR A BUILD BY A PROCESS OF ITS OWN (0.188; ccl_cold_headers_read/2): the build's options
%% set as the build sets them, then the header read as the build's prescan reads it, its summary written; it starts no
%% process of its own
ccl_drive_header(Spec, From, Options) :- once(dr_header(Spec, From, Options)).
dr_header(Spec, From, Options) :-
    dr_setup(Options, _), nb_setval('$ccl_children', none), ccl_set_lang(From),
    ( catch(ccl_header_macros_ready(Spec, From), _, fail) -> true ; true ).
dr_no_link(O) :- ( memberchk(compile_only, O) ; memberchk(assembly, O) ; memberchk(emit_llvm, O) ; memberchk(syntax_only, O) ; memberchk(ast, O) ; memberchk(preprocess, O) ), !.

%% ANOTHER MACHINE (0.131): clang's `--target=TRIPLE' names the arch and the OS -- `aarch64-linux-gnu', `arm64-apple-darwin',
%% `x86_64-linux-gnu' -- and every question of the machine that asked the host asks it now: the predefined macros
%% ('$pp_arch', '$pp_os', and the target's own table), the headers (ccl_sdk_dirs/1: the cross sysroot), long double
%% ('$ccl_ldbl': an IEEE quad on Linux aarch64), the ABI ('$ir_arch': aapcs), the embedded LLVM's triple (the compile's
%% `--target=' flag) and the linker (ccl_linker/1: the cross gcc). Each is set before anything reads it.
dr_set_target(T) :-
    (   ( sub_atom(T, 0, _, _, aarch64) ; sub_atom(T, 0, _, _, arm64) ) -> A = arm64
    ;   sub_atom(T, 0, _, _, x86_64) -> A = x86_64
    ;   A = unknown ),
    (   sub_atom(T, _, _, _, linux) -> O = linux
    ;   ( sub_atom(T, _, _, _, apple) ; sub_atom(T, _, _, _, darwin) ; sub_atom(T, _, _, _, macos) ) -> O = darwin
    ;   O = unknown ),
    (   A \== unknown, O \== unknown
    ->  nb_setval('$ccl_target', target(A, O, T)), nb_setval('$pp_arch', A), nb_setval('$pp_os', O),
        ( A == arm64 -> nb_setval('$ir_arch', aapcs) ; nb_setval('$ir_arch', sysv) ),
        ( A == arm64, O == linux -> K = quad ; A == arm64 -> K = double ; K = x87 ), nb_setval('$ccl_ldbl', K)
    ;   dr_report(T, error(unknown_target(T), cicilang)) ).
dr_inputs([], _, _, []).
dr_inputs([F|Fs], Options, Flags, Objects) :-
    dr_input(F, Options, Flags, Objects, Objects1),
    dr_inputs(Fs, Options, Flags, Objects1).
dr_input(F, _, _, Objs, Objs) :- \+ exists_file(F), !, dr_error(F, 0, ['no such file or directory']).   % as clang says it; a missing input compiled to `cicilang: ok' once
dr_input(F, Options, Flags, Objs, Objs1) :-
    (   ( dr_ext(F, c) ; dr_cpp_ext(F) ) -> dr_c(F, Options, Flags, Objs, Objs1)
    ;   dr_ext(F, ll) -> dr_ll(F, Options, Flags, Objs, Objs1)
    ;   ( dr_ext(F, o) ; dr_ext(F, a) ; dr_ext(F, so) ; dr_ext(F, dylib) ) -> Objs = [F|Objs1]
    ;   dr_error(F, 0, ['unknown kind of file']), Objs = Objs1 ).
dr_ext(F, E) :- atom_concat('.', E, Dot), sub_atom(F, _, _, 0, Dot).
dr_abs_path(F, A) :- ( catch(absolute_file_name(F, A0), _, fail) -> A = A0 ; A = F ).
dr_cpp_ext(F) :- member(E, [cpp, cc, cxx, 'C', cppm, ccm, cxxm, ixx, mpp]), dr_ext(F, E), !.

%% a .c: read (headers, macros, := ...), the safe part, the IR, then what the options ask
dr_c(F, Options, _, Objs, Objs) :- memberchk(preprocess, Options), !,                   % -E: the flattened text, cocolog's preprocessor (no clang)
    dr_say(['preprocess ', F]),
    (   dr_catch(dr_preprocess(F, Options), E, (dr_report(F, E), fail)) -> true ; true ).
dr_c(F, Options, Flags, Objs, Objs1) :-
    dr_say(['read ', F]), nb_setval('$dr_expansions', []), dr_macro_trace(F, Options),
    nb_setval('$ccl_scope_ends', []), ( ( memberchk(debug, Options) ; memberchk(debug(lines), Options) ) -> nb_setval('$ccl_scope_ends_for', F) ; nb_setval('$ccl_scope_ends_for', none) ),   % -g: the read records where each scope closes (0.139)
    (   dr_catch(cicilang_ast(F, AST), E1, (dr_pp_warnings, dr_report(F, E1), fail))
    ->  dr_pp_warnings, dr_remember_expansions(AST),
        (   memberchk(ast, Options) -> writeq(AST), nl, Objs = Objs1
        ;   memberchk(syntax_only, Options), ccl_lang(cpp) -> Objs = Objs1      % M5 is the reader; C++'s check and lowering are M6
        ;   (   memberchk(debug, Options) -> dr_abs_path(F, AF), nb_setval('$ccl_debug', file(AF)), nb_setval('$ccl_debug_kind', full)   % -g (0.128): the lowering's line tables name the file
            ;   memberchk(debug(lines), Options) -> dr_abs_path(F, AF), nb_setval('$ccl_debug', file(AF)), nb_setval('$ccl_debug_kind', lines)   % -gline-tables-only, -g1 (0.130): no variable and no type
            ;   nb_setval('$ccl_debug', none), nb_setval('$ccl_debug_kind', none) ),
            (   dr_catch(dr_ir(F, AST, IR), E2, (dr_report(F, E2), fail))
            ->  dr_emit(F, IR, Options, Flags, Objs, Objs1)
            ;   ( nb_getval('$dr_errors', NE), NE =:= 0 -> dr_error(F, 0, ['the check or the lowering failed without saying why']) ; true ), Objs = Objs1 ) )
    ;   Objs = Objs1 ).

%% -g -fdebug-macro (0.134): THE MACROS AS THE FILE AND ITS HEADERS DEFINE THEM, recorded by a standalone run of the
%% preprocessor (ccl_pp_macro_trace/2) BEFORE the read, whose own run starts the preprocessor afresh; the lowering's
%% compile unit describes them (ir_dbg_macros/3). Without the two options, nothing is recorded.
dr_macro_trace(F, Options) :-
    (   memberchk(debug, Options), memberchk(debug_macro, Options)
    ->  ccl_ensure_globals, ccl_set_lang(F), ( catch(ccl_pp_macro_trace(F, Es), _, fail) -> true ; Es = [] ), nb_setval('$ccl_debug_macros', events(Es))
    ;   nb_setval('$ccl_debug_macros', none) ).
%% the file through the preprocessor standalone -- its includes pulled in, every macro
%% expanded -- spelled back as text (ccl_pp_spell/2): to -o FILE, else the answer itself
dr_preprocess(F, Options) :-   % ... its literals, numbers, digraphs and alternative tokens as written (0.228, pp_norm_toks/2)
    ccl_ensure_globals, ccl_set_lang(F), nb_setval('$pp_spelled_out', yes),
    ( catch(ccl_pp_file(F, Tokens, _), E, ( nb_setval('$pp_spelled_out', no), throw(E) )) -> nb_setval('$pp_spelled_out', no) ; nb_setval('$pp_spelled_out', no), fail ),
    ccl_pp_spell(Tokens, Codes),
    (   memberchk(out(O), Options) -> write_file_from_codes(O, Codes)
    ;   atom_codes(A, Codes), write(A) ).
%% ---- the IR beside the units in the store (M4) ----------------------------------------
%% A unit's IR is kept under a predicate of its own, '$ccl_ir:<Path>'(Index,
%% Chunk) -- chunks of 3500 characters, well under the store's clause budget
%% once quoted -- with '$ccl_irmeta'(Path, Signature, Count) as the index. The
%% signature folds into one number everything the IR came from: the unit's key
%% (its time and the reader's version), the key of every unit and macro file
%% its AST reaches, the lowering's version and the host. A file whose signature
%% matches is served: not read again for its check and lowering, the check
%% having passed when the IR was made. A file whose check fails stores nothing.
%% ... AND A C++ FILE'S IR AS A FILE BESIDE THE SUMMARIES (0.221; the owner's decision 4 of 0.190: C++'s reads never use the store),
%% ~/.cicilang/cpp/ir/<name>-<fold>-<fold>.ll, keyed as the store's signature is -- the lowering's version, the host, -g's kind --
%% and by what a C++ read is read under, the summaries' own key (the reader's version, the level, the command line's macros, the
%% target, the RTTI and exceptions configuration, the program's feature-test macros), the file's text, and each file its AST
%% reaches by its time: a local header, a macro file, a library header and its summary, which is written again where one of its
%% deps moved. A file whose check fails keeps nothing, and one that names `__DATE__', `__TIME__' or `__TIMESTAMP__' none, its
%% text being its build's. The file is written under a name of its own and renamed into place (ccl_tmp_name/2), so two builds
%% at once never read half of one. CICILANG_NO_IR_CACHE set builds uncached: the gates set it (test/config.sh), and their
%% builds are their fixtures' own
dr_ir(F, AST, IR) :- ccl_lang(cpp), dr_cxx_ir_on, dr_cxx_ir_file(F, AST, P), !,
    (   catch(dr_cxx_ir_read(P, IR0), _, fail) -> dr_say(['served ', F, ' from the IR cache']), IR = IR0
    ;   dr_say(['check and lower ', F]), cicilang_ir([AST], IR), catch(dr_cxx_ir_write(P, IR), _, true) ).
dr_ir(F, AST, IR) :-
    dr_ir_ready, dr_ir_sig(F, AST, Sig),
    (   dr_ir_cached(F, Sig, IR0) -> dr_say(['served ', F, ' from the store']), IR = IR0
    ;   dr_say(['check and lower ', F]), cicilang_ir([AST], IR), dr_ir_remember(F, Sig, IR) ).
dr_ir_ready :- ccl_kb_ready, dynamic('$ccl_irmeta'/3).                % cheap; an unset global would throw
dr_ir_pred(F, P) :- atom_concat('$ccl_ir:', F, P), dynamic(P/2).
dr_ir_sig(F, AST, Sig) :-
    ccl_lowering_version(LV), ir_arch_init, ir_arch(Arch),
    dr_unit_deps(AST, Ds0), sort(Ds0, Ds),
    findall(P-K, ( member(P, [F|Ds]), ( ccl_kb_key(P, K) -> true ; K = none ) ), Keys),
    ( nb_current('$ccl_debug', Dbg0) -> true ; Dbg0 = none ), ( nb_current('$ccl_debug_kind', DK) -> true ; DK = none ), Dbg = Dbg0-DK,   % -g's IR is another IR (0.128), and the line tables alone a third (0.130)
    ( nb_current('$ccl_debug_macros', events(_)) -> DM = macros ; DM = none ),   % -fdebug-macro's IR is another again (0.134)
    term_to_atom(sig(LV, Arch, Keys, Dbg, DM), A), atom_codes(A, Cs), dr_fold(Cs, 7, 131, S1), dr_fold(Cs, 13, 137, S2), Sig = S1-S2.
%% two folds under 2^31 (cocolog's arithmetic is not exact past 2^52), a pair for 62 bits
dr_fold([], S, _, S).
dr_fold([C|Cs], S0, M, S) :- S1 is (S0 * M + C) mod 2147483647, dr_fold(Cs, S1, M, S).
%% every file an AST reaches: the headers read into it, at any depth, and the macro files
dr_unit_deps(unit(Is), Ds) :- !, dr_items_deps(Is, Ds).
dr_unit_deps(partial(U, _, _), Ds) :- !, dr_unit_deps(U, Ds).
dr_unit_deps(summary(F), [F]) :- !.                                             % a C++ library header's summary
dr_unit_deps(_, []).
dr_items_deps([], []).
dr_items_deps([include(_, _, file(P, _, U))|Is], [P|Ds]) :- !, dr_unit_deps(U, D1), dr_items_deps(Is, D2), append(D1, D2, Ds).
dr_items_deps([include(_, _, macros(P, _))|Is], [P|Ds]) :- !, dr_items_deps(Is, Ds).
dr_items_deps([_|Is], Ds) :- dr_items_deps(Is, Ds).
dr_ir_cached(F, Sig, IR) :-
    '$ccl_irmeta'(F, Sig, N), dr_ir_pred(F, P),
    findall(I-C, ( T =.. [P, I, C], call(T) ), Pairs), length(Pairs, N),
    sort(Pairs, Sorted), dr_ir_join(Sorted, Codes), atom_codes(IR, Codes).
dr_ir_join([], []).
dr_ir_join([_-C|T], Codes) :- atom_codes(C, Cs), dr_ir_join(T, Rest), append(Cs, Rest, Codes).
dr_ir_remember(F, Sig, IR) :-
    dr_ir_forget(F), dr_ir_pred(F, P),
    atom_codes(IR, Codes), dr_chunks(Codes, Chunks),
    (   catch(dr_ir_store(Chunks, P, 0, N), error(resource_error(clause_length), _), fail)
    ->  assertz('$ccl_irmeta'(F, Sig, N))
    ;   dr_ir_forget(F) ).
dr_ir_forget(F) :- retractall('$ccl_irmeta'(F, _, _)), dr_ir_pred(F, P), T =.. [P, _, _], retractall(T).
dr_ir_store([], _, N, N).
dr_ir_store([C|Cs], P, I, N) :- T =.. [P, I, C], assertz(T), I1 is I + 1, dr_ir_store(Cs, P, I1, N).
dr_chunks([], []) :- !.
dr_chunks(Codes, [A|As]) :- dr_take(3500, Codes, Head, Tail), atom_codes(A, Head), dr_chunks(Tail, As).
dr_take(0, T, [], T) :- !.
dr_take(_, [], [], []) :- !.
dr_take(K, [C|Cs], [C|H], T) :- K1 is K - 1, dr_take(K1, Cs, H, T).
dr_cxx_ir_on :- \+ ( catch(os_env('CICILANG_NO_IR_CACHE', V), _, fail), V \== '' ).
dr_cxx_ir_file(F, AST, P) :-
    read_file_to_codes(F, Cs), \+ dr_text_dated(Cs), ccl_fold(Cs, 7, 131, T1), ccl_fold(Cs, 13, 137, T2),
    ccl_lowering_version(LV), ccl_reader_version(RV), ir_arch_init, ir_arch(Arch), ccl_std(Std), ccl_cmdline_key(CK), ccl_target_key(TK),
    ccl_config_key(GK), ccl_ftm_tag(FK),
    ( nb_current('$ccl_debug', Dbg0) -> true ; Dbg0 = none ), ( nb_current('$ccl_debug_kind', DK) -> true ; DK = none ),
    ( nb_current('$ccl_debug_macros', events(_)) -> DM = macros ; DM = none ),
    dr_unit_deps(AST, Ds0), sort(Ds0, Ds), dr_cxx_key_deps(Ds, Keys0), sort(Keys0, Keys),
    term_to_atom(cxxir(LV, RV, Arch, Std, CK, TK, GK, FK, Dbg0-DK, DM, F, T1-T2, Keys), A), atom_codes(A, Ks),
    ccl_fold(Ks, 7, 131, S1), ccl_fold(Ks, 13, 137, S2),
    ccl_sum_dir(SD), atomic_list_concat(Parts, '/', F), last(Parts, Base), atomic_list_concat([SD, '/ir/', Base, '-', S1, '-', S2, '.ll'], P).
%% A KEY THAT A COLD READ AND A WARM ONE GIVE ALIKE (0.221): a library header read cold is its preprocessed unit, whose items
%% name no file, and served it is its summary, the header and the summary's file -- so the key of the first build, over a
%% cold read, was never met again. A library header stands for the files its summary records (`dep(P, T)', the files its
%% preprocessor pulled, with their times), a summary's own file for nothing, any other file for itself with its time
dr_cxx_key_deps([], []).
dr_cxx_key_deps([D|Ds], Ks) :- sub_atom(D, _, _, 0, '.sum'), !, dr_cxx_key_deps(Ds, Ks).
dr_cxx_key_deps([D|Ds], Ks) :- ccl_sum_file(D, F), exists_file(F), catch(ccl_sum_terms(F, Terms), _, fail),
    findall(P-T, member(dep(P, T), Terms), Ps), Ps \== [], !, dr_cxx_key_deps(Ds, K1), append(Ps, K1, Ks).
dr_cxx_key_deps([D|Ds], [D-T|Ks]) :- ( catch(time_file(D, T0), _, fail) -> T = T0 ; T = none ), dr_cxx_key_deps(Ds, Ks).
dr_text_dated(Cs) :- atom_codes(A, Cs), ( sub_atom(A, _, _, _, '__DATE__') ; sub_atom(A, _, _, _, '__TIME__') ; sub_atom(A, _, _, _, '__TIMESTAMP__') ), !.
dr_cxx_ir_read(P, IR) :- exists_file(P), read_file_to_codes(P, Cs), Cs \== [], atom_codes(IR, Cs).
dr_cxx_ir_write(P, IR) :- ccl_sum_dir(SD), atomic_list_concat(['mkdir -p \'', SD, '/ir\''], Mk), once(catch(proc_run(Mk, 10000, _, _), _, true)),
    atom_codes(IR, Cs), ccl_tmp_name(P, T), write_file_from_codes(T, Cs), rename_file(T, P).
dr_ll(F, Options, Flags, Objs, Objs1) :-
    read_file_to_codes(F, Cs), atom_codes(IR, Cs), dr_emit(F, IR, Options, Flags, Objs, Objs1).
dr_emit(F, IR, Options, Flags, Objs, Objs1) :-
    (   memberchk(syntax_only, Options) -> Objs = Objs1
    ;   memberchk(emit_llvm, Options) -> dr_out(F, Options, ll, Out), dr_say(['write ', Out]), atom_codes(IR, Cs), write_file_from_codes(Out, Cs), Objs = Objs1
    ;   memberchk(assembly, Options) -> dr_out(F, Options, s, Out), dr_say(['assemble ', Out]), dr_compile(F, IR, Out, ['-S'|Flags]), Objs = Objs1
    ;   memberchk(compile_only, Options) -> dr_out(F, Options, o, Out), dr_say(['compile ', Out]), dr_compile(F, IR, Out, Flags), Objs = Objs1
    ;   tmp_file(cicilang, T), atom_concat(T, '.o', Out), dr_say(['compile ', F]), ( dr_compile(F, IR, Out, Flags) -> Objs = [Out|Objs1] ; Objs = Objs1 ) ).
dr_compile(F, IR, Out, Flags) :- dr_catch(cicilang_compile(IR, Out, Flags), E, (dr_report(F, E), fail)).
%% the output name: -o, else the input's basename with the new extension, in the working directory
dr_out(_, Options, _, Out) :- memberchk(out(Out), Options), !.
dr_out(F, _, Ext, Out) :-
    ( sub_atom(F, B, _, 0, Base0), sub_atom(F, B1, 1, _, '/'), B1 < B, \+ sub_atom(Base0, _, _, _, '/') -> true ; Base0 = F ),
    dr_basename(F, Base), ( sub_atom(Base, S, _, 0, '.c') -> sub_atom(Base, 0, S, _, Stem) ; sub_atom(Base, S, _, 0, '.ll') -> sub_atom(Base, 0, S, _, Stem) ; Stem = Base ),
    atomic_list_concat([Stem, '.', Ext], Out).
dr_basename(F, B) :- atom_codes(F, Cs), dr_after_slash(Cs, Bs), atom_codes(B, Bs).
dr_after_slash(Cs, Bs) :- ( append(_, [0'/|R], Cs), \+ memberchk(0'/, R) -> Bs = R ; Bs = Cs ).

%% the unit's expansions, for the note under a diagnostic on an expanded line
dr_remember_expansions(unit(Is)) :- !, ( append(_, ['$expansions'(Es)], Is) -> nb_setval('$dr_expansions', Es) ; nb_setval('$dr_expansions', []) ).
dr_remember_expansions(_).
dr_note_expansion(F, L) :-
    ( nb_getval('$dr_expansions', Es), member(expansion(L, N, As), Es)
    -> write(F), write(':'), write(L), write(': note: expanded from macro \''), write(N), write('\' on '), dr_args(As), nl
    ; true ).
dr_args([]).
dr_args([A]) :- !, writeq(A).
dr_args([A|As]) :- writeq(A), write(', '), dr_args(As).

%% ---- diagnostics, clang's shape ---------------------------------------------------------
%% once: the callers' recovery fails after reporting, and must not report twice
dr_report(F, error(E, W)) :- !, once(dr_diag(F, E, W)).
dr_report(F, E) :- once(dr_error(F, 0, [E])).
dr_diag(_, syntax_error(cicilang_ast(File, line(L), near(N))), _) :- !, dr_error(File, L, ['syntax error: could not read this item (gave up near line ', N, ')']).
dr_diag(_, syntax_error(cicilang_ast(File, lexical, line(L))), _) :- !, dr_error(File, L, ['lexical error']).
%% A CHARACTER PAST ASCII THAT BEGINS NO TOKEN (0.221), named as clang names it: one that may follow in an identifier at the
%% level and not begin one, `not allowed at the start of an identifier', any other `not allowed in an identifier'
dr_diag(_, syntax_error(cicilang_ast(File, char(C), line(L))), _) :- !, dr_hex4(C, H),
    ( catch(ccl_id_cp(more, C), _, fail) -> W = ' not allowed at the start of an identifier' ; W = ' not allowed in an identifier' ),
    dr_error(File, L, ['character <U+', H, '>', W]).
dr_diag(F, cannot_infer(N, E), here(_, L)) :- !, dr_error(F, L, ['cannot infer the type of ', N, ' from ', E]).
dr_diag(F, pp_error(M), here(_, L)) :- !, dr_error(F, L, [M]).                      % the file's own #error, its text; an #embed of nothing
dr_diag(F, static_assert_failed(T), here(_, L)) :- !, ( T == '' -> dr_error(F, L, ['static assertion failed']) ; dr_error(F, L, ['static assertion failed: ', T]) ).
dr_diag(F, no_member(What, T), here(_, L)) :- !, dr_error(F, L, ['no member ', What, ' in ', T]).
dr_diag(F, macro_error(M, here(_, L)), _) :- !, dr_error(F, L, ['macro: ', M]).
%% an error inside a macro: the call site, then where it went wrong in the macro
dr_diag(F, macro_error(N, As, E), here(_, L, in_macro(P, MF))) :- !,
    dr_prolog_error(E, Text), dr_error(F, L, ['in the expansion of macro \'', N, '\': ', Text]), dr_note_macro(F, L, P, MF, As).
dr_diag(F, macro_failed(N, As), here(_, L, in_macro(P, MF))) :- !,
    dr_error(F, L, ['macro \'', N, '\' failed: no result for these arguments']), dr_note_macro(F, L, P, MF, As).
dr_diag(F, macro_error(N, As, E), _) :- !, dr_prolog_error(E, Text), dr_error(F, 0, ['in the expansion of macro \'', N, '\' on ', As, ': ', Text]).
dr_diag(F, macro_failed(N, As), _) :- !, dr_error(F, 0, ['macro \'', N, '\' failed on ', As]).
dr_diag(F, ownership(Kind, N, Form), where(Fn, line(L))) :- !, dr_kind(Kind, Text), dr_error(F, L, [Text, ' ''', N, ''' in ', Form, ' (function ', Fn, ')']).
dr_diag(F, not_lowered(What), where(Fn, line(L))) :- !, dr_error(F, L, ['not lowered yet: ', What, ' (function ', Fn, ')']).
dr_diag(F, compile_failed(Msg), _) :- !, dr_error(F, 0, ['LLVM: ', Msg]).
dr_diag(F, unknown_target(T), _) :- !, dr_error(F, 0, ['unknown target triple \'', T, '\'']).
dr_diag(F, no_embedded_llvm, _) :- !, dr_error(F, 0, ['the embedded LLVM is not built: LLVM=... sh module/build-llvm.sh']).
dr_diag(F, cocolog_error(Msg), _) :- !, dr_error(F, 0, ['LLVM: ', Msg]).            % the embedded LLVM's refusal
dr_diag(F, link_failed(Msg), _) :- !, dr_error(F, 0, ['link: ', Msg]).
dr_diag(F, E, W) :- dr_error(F, 0, [E, ' ', W]).
%% a code point as clang writes it after `U+': upper-case hex digits, four at the least
dr_hex4(C, H) :- dr_hex_digits(C, Ds0), dr_pad4(Ds0, Ds), atom_codes(H, Ds).
dr_hex_digits(C, [D]) :- C < 16, !, dr_hex_digit(C, D).
dr_hex_digits(C, Ds) :- Q is C // 16, R is C mod 16, dr_hex_digits(Q, Ds0), dr_hex_digit(R, D), append(Ds0, [D], Ds).
dr_hex_digit(V, D) :- ( V < 10 -> D is 0'0 + V ; D is 0'A + V - 10 ).
dr_pad4(Ds0, Ds) :- length(Ds0, N), ( N < 4 -> dr_pad4([0'0|Ds0], Ds) ; Ds = Ds0 ).
dr_kind(use_after_move, 'use after move of') :- !.
dr_kind(owner_unset, 'owner used before it was given anything:') :- !.
dr_kind(borrow_after_move, 'use of a borrow after its owner was consumed:') :- !.
dr_kind(borrow_escapes, 'a borrow leaves the function:') :- !.
dr_kind(borrow_stored, 'a borrow stored where it cannot be followed:') :- !.
dr_kind(borrow_consumed, 'a borrow consumed:') :- !.
dr_kind(borrow_incomplete, 'a borrowed struct''s own field not whole at the return:') :- !.
dr_kind(owner_stored, 'an owner''s pointer stored into a plain slot:') :- !.
dr_kind(tie_unknown, 'the tie names nothing declared before it:') :- !.
dr_kind(tie_outlived, 'owner outlives what it is tied to:') :- !.
dr_kind(tie_escapes, 'tied owner moved beyond its tie:') :- !.
dr_kind(tie_mismatch, 'value not within its tie:') :- !.
dr_kind(untied, 'no owner behind:') :- !.
dr_kind(own_unbounded, 'an own pointer with no owner to name (behind a plain pointer, in an array with no constant bound, an array parameter):') :- !.
dr_kind(own_array_by_value, 'a struct with an own array held by value (it lives behind an own pointer):') :- !.
dr_kind(own_array_untagged, 'an own array in a struct without a tag (the drain is named by it):') :- !.
dr_kind(array_unset, 'an own array not zeroed at birth (calloc, or an initializer):') :- !.
dr_kind(unconsumed, 'plain pointer not consumed:') :- !.
dr_kind(owner_leaked, 'owner leaked:') :- !.
dr_kind(move_in_loop, 'owner consumed inside a loop:') :- !.
dr_kind(move_of_non_owner, 'move of a non-owner:') :- !.
dr_kind(owner_overwritten, 'owner overwritten while live:') :- !.
dr_kind(goto_with_owners, 'goto over the declaration of fresh memory or of an own array:') :- !.
dr_kind(goto_over_defer, 'goto over a defer (or a local with a destructor) to label') :- !.
dr_kind(K, K).
%% the user's file's `#warning' lines, printed after its read in clang's shape (they count as no error)
dr_pp_warnings :-
    (   nb_current('$pp_warnings', Ws) -> nb_setval('$pp_warnings', []), reverse(Ws, Ws1), dr_pp_warnings_(Ws1) ; true ).
dr_pp_warnings_([]).
dr_pp_warnings_([warning(F, L, M)|Ws]) :- write(F), write(':'), write(L), write(': warning: '), write(M), nl, dr_pp_warnings_(Ws).
dr_error(F, L, Parts) :-
    nb_getval('$dr_errors', N), N1 is N + 1, nb_setval('$dr_errors', N1),
    write(F), ( L > 0 -> write(':'), write(L) ; true ), write(': error: '), dr_write(Parts), nl,
    ( L > 0 -> dr_note_expansion(F, L) ; true ),
    dr_why_stop(F, L, Parts).
%% THE RUN ENDS AT ITS FIRST ERROR under test/why.sh (0.144), which sets '$ccl_why': library(flow/debug) records the
%% last inferences before a run's end, so the end must be where the compiler gave up. An error the compiler RAISES
%% passes the driver's report sites untaken (dr_catch/3, 0.146), and the run ends with the compiler's own exception,
%% whose path and the failure it answered the debugger reads back (flow_why_raised/3); caught and reported, it ended
%% with the driver's own throw below, whose path is the report's. cocolog 1.11.7's caught(K) explains a catch's
%% recovery only where the window recorded the catch's call, and a report site's is made when the build starts, long
%% before the window: over plain catch/3 here, no case found the compiler's error (0.148). An error the driver says
%% after a FAILURE (`the check or the lowering failed without saying why') throws past every recovery here. Nothing
%% else sets the global, and a build reads it once per report site and once per error it reports.
dr_why_stop(F, L, Parts) :- ( nb_current('$ccl_why', yes) -> throw(ccl_why(F, L, Parts)) ; true ).
dr_catch(G, E, R) :- ( nb_current('$ccl_why', yes) -> call(G) ; catch(G, E, R) ).
dr_note_macro(F, L, P, MF, As) :-
    write(F), write(':'), write(L), write(': note: the macro is '), write(P), write(' in '), write(MF), write(', called on '), dr_args(As), nl.
%% a Prolog error, said plainly
dr_prolog_error(error(existence_error(procedure, PI), _), T) :- !, dr_join(['the macro calls ', PI, ', which does not exist'], T).
dr_prolog_error(error(type_error(Ty, C), _), T) :- !, dr_join(['expected a ', Ty, ', got ', C], T).
dr_prolog_error(error(instantiation_error, _), T) :- !, T = 'an argument was left unbound'.
dr_prolog_error(error(macro_error(M, _), _), T) :- !, dr_join(['the macro said: ', M], T).
dr_prolog_error(error(E, _), T) :- !, dr_join(['it threw ', E], T).
dr_prolog_error(E, T) :- dr_join(['it threw ', E], T).
dr_join(Parts, A) :- dr_join_codes(Parts, Cs), atom_codes(A, Cs).
dr_join_codes([], []).
dr_join_codes([P|Ps], Cs) :- ( atom(P) -> atom_codes(P, C) ; term_to_atom(P, A), atom_codes(A, C) ), dr_join_codes(Ps, Cs1), append(C, Cs1, Cs).
dr_write([]).
dr_write([P|Ps]) :- ( atomic(P) -> write(P) ; writeq(P) ), dr_write(Ps).
dr_say(Parts) :- ( nb_getval('$dr_verbose', yes) -> write('cicilang: '), dr_write(Parts), nl ; true ).
