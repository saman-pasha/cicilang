%% cicilang -- the reader's gate, as a cocolog program: one process, every
%% header parsed once, every check a Prolog goal over the AST. Run by
%% test/reader.sh, which sets CCL_TEST_ROOT and CICILI and adds, in the
%% shell, the checks that need a second process (the knowledge base as the
%% cache). Each check prints `ok   Name' or `FAIL Name'; the last line is
%% GREEN or RED.
%%
%%   CCL_TEST_ROOT=<this repo> cocolog --embed <the store> query "ensure_loaded('test/reader.pl'), reader_main"
%% (never `run test/reader.pl main': under a store, `run' consults the program into it)

:- use_module(library(cicilang)).
:- use_module(library(os)).
:- use_module(library(process)).

reader_main :-
    setup,
    t_checks, t_real,
    nb_getval('$t_fails', N),
    ( N =:= 0 -> write('GREEN: reader (one process)') ; write('RED: '), write(N), write(' failure(s)') ), nl.

%% setup/0 alone, then one check by name, runs it on its own:
%%   cocolog --local query "ensure_loaded('test/reader.pl'), setup, k72"
setup :-
    nb_setval('$t_fails', 0), nb_setval('$t_err', none),
    os_env('CCL_TEST_ROOT', Root), atom_concat(Root, '/test/c/', C), nb_setval('$t_cdir', C),
    ( once(catch(os_env('CCL_TEST_TMP', T), _, fail)), T \== '' -> true ; T = '/tmp/cicilang-reader-scratch', sh(mkdir, ['-p', T]) ),
    nb_setval('$t_tmp', T).

%% ---- the harness ------------------------------------------------------------
section(S) :- write('-- '), write(S), nl.
check(Name, Goal) :-
    nb_setval('$t_err', none),
    (   \+ \+ catch(Goal, E, (nb_setval('$t_err', E), fail))   % \+ \+: cocolog reclaims the heap on backtracking only, so a check's garbage goes here, not into the next check's peak
    ->  write('ok   '), write(Name), nl
    ;   nb_getval('$t_fails', N), N1 is N + 1, nb_setval('$t_fails', N1),
        write('FAIL '), write(Name), nl,
        ( nb_getval('$t_err', E), E \== none -> write('     error '), write(E), nl ; true ) ).
c(Name, Path) :- nb_getval('$t_cdir', C), atom_concat(C, Name, Path).
tmp(D) :- nb_getval('$t_tmp', D).                       % the wrapper's scratch directory, writable
%% a copy of a fixture, and a touch 50 ms later: time_file/2 answers a file's time to the nanosecond since cocolog
%% 2.12.2 (whole seconds before, and the wait was 1.1 s), and Linux stamps a file from its coarse clock, a tick a few ms
copy(From, To) :- sh(cp, [From, To]).
touch(F) :- proc_sleep(50), sh(touch, [F]).
sh(Cmd, Args) :- sh_line([Cmd|Args], Line), once(catch(proc_run(Line, 20000, _, 0), _, fail)).
sh_line([], '').
sh_line([A|As], L) :- sh_line(As, L0), atomic_list_concat(['\'', A, '\' ', L0], L).
%% a sample's unit, read once per process
%% a fixture read at C's own level (-std=c23), the read kept apart from the C17 one
unit_c(Name, Std, U) :-
    c(Name, P), atomic_list_concat(['$t_unit_c', Std, ':', P], K),
    (   once(nb_current(K, U0)) -> U = U0
    ;   nb_setval('$ccl_c_std', Std), cicilang_ast(P, U0), nb_setval('$ccl_c_std', 17), nb_setval(K, U0), U = U0 ).
unit(Name, U) :-
    c(Name, P), atom_concat('$t_unit:', P, K),
    (   once(nb_current(K, U0)) -> U = U0
    ;   cicilang_ast(P, U0), nb_setval(K, U0), U = U0 ).
fn_body(Name, F, B) :- unit(Name, unit(Is)), member(function(_, _, _, F, _, _, block(B)), Is).
codes_atom(S, A) :- atom_codes(A, S).

%% ---- the checks --------------------------------------------------------------
%% EACH CHECK IS ITS OWN CLAUSE, so its variables are its own: two checks in
%% one clause would share a variable of the same name, and the second would
%% have to unify one file's AST with the first's. (Clauses, not facts driven
%% by findall/3: consulting 71 goal-carrying facts into an embedded store
%% segfaults cocolog.)

k1 :- check('cicilang_ast/2 reads the file and answers a unit of 3 items',
    ( unit('hello.c', unit(Is)), length(Is, 3) )).

k2 :- check('a directive that is not an include is kept whole',
    ( unit('rich.c', unit(Is)), member(directive(5, '#define LIMIT 10'), Is) )).

k3 :- check('main is a function at its line, returning int, taking void',
    ( unit('hello.c', unit(Is)), member(function(5, none, base([], [int]), main, [], false, _), Is) )).

k4 :- check('its body: a call with a string (10 codes, ending in newline), then return 0',
    ( fn_body('hello.c', main, [expr(6, call(id(printf), [str(S), _])), return(7, int(0))]), length(S, 10), last(S, 10) )).

k5 :- check('cicilang_ast/3 leaves nothing when the whole file parses',
    ( c('hello.c', P), cicilang_ast(P, _, []) )).

k6 :- check('<stdio.h> resolves to a file on the toolchain\'s path and is read',
    ( unit('hello.c', unit([include(2, system('stdio.h'), file(P, How, unit(_)))|_])), sub_atom(P, _, _, 0, '/stdio.h'), memberchk(How, [raw, preprocessed]) )).

k7 :- check('and printf is declared somewhere under it',
    ( unit('hello.c', U), ccl_declares(U, printf, I), functor(I, declaration, _) )).

k8 :- check('and malloc under <stdlib.h>, as a function returning a pointer',
    ( unit('hello.c', U), ccl_declares(U, malloc, declaration(_, _, _, [var(malloc, fn(ptr(_, _), _, _), _)])) )).

k9 :- check('a quoted include is found beside the file and read raw',
    ( c('local.h', LH), unit('uses.c', unit([include(1, local('local.h'), file(LH, raw, unit([typedef(1, _)])))|_])) )).

k10 :- check('and its typedef makes \'Parcel * p = 0;\' a declaration in the includer',
    ( fn_body('uses.c', f, [I|_]), functor(I, declaration, _) )).

k11 :- check('a header that is nowhere is missing, and the file still reads',
    unit('missing.c', unit([include(1, local('nope.h'), missing), declaration(2, _, _, _)]))).

k12 :- check('a cycle of headers is cut, not followed',
    ( c('a.h', AH), unit('cyc.c', unit([include(1, _, file(_, raw, unit([include(1, _, file(_, raw, unit([include(1, _, cyclic(AH))|_])))|_])))])) )).

k13 :- check('the toolchain\'s inclusion path comes from the SDK\'s and LLVM\'s conventional places, no tool run',
    ( ccl_include_path(Ds), length(Ds, N), N > 1 )).

k14 :- check('after hello.c, its headers are in the store, one clause per item',
    ( unit('hello.c', _), ccl_kb_ready, '$ccl_ast'(P, _, meta(included(_), N, _)), sub_atom(P, _, _, 0, '/stdio.h'), N > 0 )).

k15 :- check('and hello.c itself, read whole, keyed by its time and the reader\'s version',
    ( c('hello.c', P), '$ccl_ast'(P, key(T, V), meta(top, 3, [_, _])), number(T), ccl_reader_version(V) )).

k16 :- check('a cached read is the same AST as a fresh one',
    ( c('rich.c', P), cicilang_ast(P, A), ccl_kb_forget_file(P), cicilang_ast(P, B), A == B )).

k17 :- check('a touched file is read again, not served stale',
    ( tmp(D), c('uses.c', U), c('local.h', H), atomic_list_concat([D, '/uses.c'], U2), copy(U, U2), copy(H, D),
            cicilang_ast(U2, _), '$ccl_ast'(U2, key(T0, _), _), touch(U2), cicilang_ast(U2, _), '$ccl_ast'(U2, key(T1, _), _), T1 > T0 )).

k18 :- check('a changed macro file makes its includer\'s cached read a miss',
    ( tmp(D), c('macros.pl', M), c('uses_macros.c', UM), atomic_list_concat([D, '/uses_macros.c'], UM2), copy(M, D), copy(UM, UM2),
            cicilang_ast(UM2, _), ccl_kb_cached(UM2, top, _), atomic_list_concat([D, '/macros.pl'], M2), touch(M2), \+ ccl_kb_cached(UM2, top, _) )).

k19 :- check('the include node names the macro file and its predicates, DCG ones too',
    ( c('macros.pl', MP), unit('uses_macros.c', unit([include(1, local('macros.pl'), macros(MP, Ps))|_])),
            memberchk(macro(square, square, 2), Ps), memberchk(macro(swap, swap, 3), Ps), memberchk(macro(sum, sum, dcg), Ps) )).

k20 :- check('a macro at file scope: counter(hits); is a static int declaration',
    ( unit('uses_macros.c', unit(Is)), member(declaration(_, static, _, [var(hits, _, int(0))]), Is) )).

k21 :- check('a list result is spliced: pair(lo, hi); is two declarations',
    ( unit('uses_macros.c', unit(Is)), append(_, [declaration(_, _, _, [var(lo, _, int(1))]), declaration(_, _, _, [var(hi, _, int(2))])|_], Is) )).

k22 :- check('in an expression: square(a) is a * a',
    ( fn_body('uses_macros.c', f, B), member(return(_, bin('+', bin('*', id(a), id(a)), _)), B) )).

k23 :- check('a DCG macro parses its arguments: sum(a, 2, 3) folds to (a + 2) + 3',
    ( fn_body('uses_macros.c', f, B), member(return(_, bin('+', _, bin('+', bin('+', id(a), int(2)), int(3)))), B) )).

k24 :- check('as a statement: swap(a, b); is a block with a fresh temporary',
    ( fn_body('uses_macros.c', f, B), member(block([declaration(_, _, _, [var(T, _, id(a))]), expr(_, assign('=', id(a), id(b))), expr(_, assign('=', id(b), id(T)))]), B), sub_atom(T, 0, 4, _, tmp_) )).

k25 :- check('type inference: a parameter, the usual conversions, a member through a pointer and a typedef',
    ( fn_body('uses_macros.c', f, B),
            member(declaration(_, _, _, [var(t1, _, str(S1))]), B), codes_atom(S1, 'base([],[int])'),
            member(declaration(_, _, _, [var(t2, _, str(S2))]), B), codes_atom(S2, 'base([],[double])'),
            member(declaration(_, _, _, [var(t4, _, str(S4))]), B), codes_atom(S4, 'base([],[int])') )).

k26 :- check('and a call\'s return type combined with a long',
    ( fn_body('uses_macros.c', f, B), member(declaration(_, _, _, [var(t6, _, str(S))]), B), codes_atom(S, 'base([],[long])') )).

k27 :- check('the size of a struct, LP64: int + double = 16',
    ( fn_body('uses_macros.c', f, B), member(declaration(_, _, _, [var(sz, _, int(16))]), B) )).

k28 :- check('a macro that fails stops the read with its name and arguments',
    ( c('bad_macro.c', P), catch(cicilang_ast(P, _), error(E, _), true), E == macro_failed(boom, [int(1)]) )).

k29 :- check('a macro that throws reports the macro, its arguments and the ball',
    ( c('throwing_macro.c', P), catch(cicilang_ast(P, _), error(E, _), true), E == macro_error(bang, [int(1)], oops) )).

k79 :- check('a unit that expanded macros ends with what expanded where: swap(a, b) at line 12',
    ( unit('uses_macros.c', unit(Is)), append(_, ['$expansions'(Es)], Is), memberchk(expansion(12, swap, [id(a), id(b)]), Es) )).

k80 :- check('an error inside a macro names the call site and the macro: file, line 2, bang in throws.pl',
    ( c('throwing_macro.c', P), c('throws.pl', M), catch(cicilang_ast(P, _), error(macro_error(bang, [int(1)], oops), here(P, 2, in_macro(bang, M))), true) )).

k30 :- check('n := 42; is an int declaration with that initializer',
    ( fn_body('walrus.c', f, B), member(declaration(4, none, base([], [int]), [var(n, base([], [int]), int(42))]), B) )).

k31 :- check('d := n + 1.5; is a double, by the usual conversions',
    ( fn_body('walrus.c', f, B), member(declaration(_, _, _, [var(d, base([], [double]), _)]), B) )).

k32 :- check('q := &p; is a pointer to the typedef, and y := q->y; a double through it',
    ( fn_body('walrus.c', f, B), member(declaration(_, _, _, [var(q, ptr([], base([], [typedef(point_t)])), _)]), B), member(declaration(_, _, _, [var(y, base([], [double]), _)]), B) )).

k33 :- check('t := s; keeps the pointer type; c := k; drops the const: the new variable is its own',
    ( fn_body('walrus.c', f, B), member(declaration(_, _, _, [var(t, ptr([], base([], [char])), _)]), B), member(declaration(_, _, _, [var(c, base([], [int]), _)]), B) )).

k34 :- check('for (i := 0; ...) declares i in the for',
    ( fn_body('walrus.c', f, B), member(for(_, decl(base([], [int]), [var(i, base([], [int]), int(0))]), _, postinc(id(i)), _), B) )).

k35 :- check('g := 7; at file scope is a global int',
    ( unit('walrus.c', unit(Is)), member(declaration(2, none, base([], [int]), [var(g, _, int(7))]), Is) )).

k36 :- check('a right-hand side whose type is unknown is an error naming the variable, the file and the line',
    ( c('no_infer.c', P), catch(cicilang_ast(P, _), error(E, here(F, L)), true), E == cannot_infer(z, id(nothing)), F == P, L =:= 2 )).

k37 :- check('{ a, b } := p; binds the members by position, each a declaration by inference',
    ( fn_body('pattern.c', f, B), member(declaration(5, none, _, [var(a, base([], [int]), member(id(p), x))]), B), member(declaration(5, none, _, [var(b, base([], [double]), member(id(p), y))]), B) )).

k38 :- check('_ skips, field: name binds by name, a nested { } destructures a member, all through a pointer',
    ( fn_body('pattern.c', f, B), member(declaration(_, _, _, [var(x, base([], [int]), member(arrow(id(n), at), x))]), B),
            member(declaration(_, _, _, [var(nm, ptr([], base([const], [char])), arrow(id(n), name))]), B), \+ member(declaration(_, _, _, [var(next, _, _)]), B) )).

k39 :- check('a right-hand side that is not a variable is evaluated once, into a temporary',
    ( fn_body('pattern.c', f, B), append(_, [declaration(_, _, _, [var(T, base([], [typedef(point_t)]), call(id(make), []))]), declaration(_, _, _, [var(u, _, member(id(T), x))]), declaration(_, _, _, [var(v, _, member(id(T), y))])|_], B), sub_atom(T, 0, 4, _, tmp_) )).

k40 :- check('a pattern longer than the struct is an error naming the position',
    ( c('pattern_bad.c', P), catch(cicilang_ast(P, _), error(E, here(_, L)), true), E == no_member(position(3), base([], [typedef(point_t)])), L =:= 2 )).

k41 :- check('a field the struct has not is an error naming it',
    ( c('pattern_bad2.c', P), catch(cicilang_ast(P, _), error(E, _), true), E == no_member(zz, base([], [typedef(point_t)])) )).

k42 :- check('println: {} next, {name} by name, {0} by index, {p} a struct by its members, % kept, newline added',
    ( fn_body('fmt.c', main, B), member(expr(_, call(id(printf), [str(S), id(n), id(name), id(n), member(id(p), x), member(id(p), y)])), B),
            codes_atom(S, 'n = %d name = %s again %d p = point_t { x: %d, y: %g } 100%%\n') )).

k43 :- check('format is an expression of type char *: asprintf into a fresh buffer, in a statement expression',
    ( fn_body('fmt.c', main, B), member(declaration(_, _, _, [var(s, ptr([], base([], [char])), stmt_expr(block([declaration(_, _, _, [var(Buf, _, none)]), expr(_, call(id(asprintf), [addr(id(Buf)), str(S), int(1), int(2), int(3)])), expr(_, id(Buf))])))]), B),
            codes_atom(S, '%d + %d = %d') )).

k44 :- check('a struct inside a struct nests; unsigned long is %lu; {{ }} are braces',
    ( fn_body('fmt.c', main, B), member(expr(_, call(id(printf), [str(S), member(member(id(nd), at), x), member(member(id(nd), at), y), member(id(nd), name), member(id(nd), id)])), B),
            codes_atom(S, 'node { at: point_t { x: %d, y: %g }, name: %s, id: %lu } {braces}\n') )).

k45 :- check('a hole with no argument is an error with its place',
    ( c('fmt_bad.c', P), catch(cicilang_ast(P, _), error(macro_error(M, here(_, L)), _), true), M == no_argument(1), L =:= 1 )).

k46 :- check('a name not in scope cannot be formatted',
    ( c('fmt_bad2.c', P), catch(cicilang_ast(P, _), error(macro_error(M, here(F, _)), _), true), M == cannot_format(id(nope)), F == P )).

k47 :- check('point { int x; double y; } is the typedef of a struct with that tag and those members',
    unit('shorthand.c', unit([typedef(1, [var(point, base([], [struct(point, [member(base([], [int]), x, none), member(base([], [double]), y, none)])]), none)])|_]))).

k48 :- check('the name is a type inside its own members (node *next) and afterwards (point at); a trailing ; is fine',
    unit('shorthand.c', unit([_, typedef(2, [var(node, base([], [struct(node, [member(ptr([], base([], [typedef(node)])), next, none), member(base([], [typedef(point)]), at, none)])]), none)])|_]))).

k49 :- check('and the types serve a block: a declaration, and a pattern through them',
    ( fn_body('shorthand.c', f, B), member(declaration(_, _, base([], [typedef(point)]), [var(p, _, init(_))]), B), member(declaration(_, _, _, [var(a, base([], [int]), member(id(p), x))]), B) )).

k72 :- check('defer(f) { fclose(f); } is a statement over its named variables, with its block, where it stands',
    ( fn_body('defer.c', count_lines, B), member(defer(8, [id(f)], block([expr(8, call(id(fclose), [id(f)]))])), B),
            member(defer(12, [id(buf)], block([expr(12, call(id(free), [id(buf)]))])), B) )).

k73 :- check('and a call named defer without a block is still a call',
    ( fn_body('defer.c', g, [return(_, call(id(defer), [int(1), int(2)]))]) )).

k74 :- check('buf := malloc(max); is a void * -- malloc\'s prototype came from <stdlib.h>',
    ( fn_body('defer.c', count_lines, B), member(declaration(10, none, _, [var(buf, ptr([], base([], [void])), call(id(malloc), _))]), B) )).

k75 :- check('own char *b = move(a); -- own is a qualifier, move a node, in the reader',
    ( fn_body('run/owners.c', main, B), member(declaration(_, _, base([own], [char]), [var(b, ptr([], base([own], [char])), move(id(a)))]), B) )).

k76 :- check('an own parameter and an own return type',
    ( unit('run/owners.c', unit(Is)), member(function(_, static, _, take, [param(ptr([], base([own], [char])), s)], _, _), Is),
            member(function(_, static, ptr([], base([own], [char])), make, _, _, _), Is) )).

k77 :- check('every statement carries its line: the if, the while, the return in rich.c',
    ( fn_body('rich.c', main, B), member(while(32, _, _), B), member(if(Li, _, goto(Lg, done), none), B), Li =:= Lg, Li > 40, member(label(45, done, return(46, _)), B) )).

k78 :- check('a macro written in the short form gets the line of the call: swap(a, b); at line 12',
    ( fn_body('uses_macros.c', f, B), member(block([declaration(12, _, _, _), expr(12, assign('=', id(a), id(b))), _]), B) )).

k50 :- check('a typedef of a basic type',
    ( unit('rich.c', unit(Is)), member(typedef(_, [var(ulong, base([], [unsigned, long]), none)]), Is) )).

k51 :- check('a typedef of a struct with members',
    ( unit('rich.c', unit(Is)), member(typedef(_, [var(point_t, base([], [struct(point, Ms)]), none)]), Is), length(Ms, 2), Ms = [member(_, x, _)|_] )).

k52 :- check('an enum with a value',
    ( unit('rich.c', unit(Is)), member(declare(_, base([], [enum(color, Es)])), Is), member(enumerator('GREEN', int(5)), Es) )).

k53 :- check('a bitfield member and a self-pointer',
    ( unit('rich.c', unit(Is)), member(declare(_, base([], [struct(node, Ms)])), Is), member(member(ptr([], base([], [struct(node, none)])), next, none), Ms), member(member(_, flags, int(3)), Ms) )).

k54 :- check('a static function',
    ( unit('rich.c', unit(Is)), member(function(_, static, base([], [int]), square, [param(base([], [int]), n)], false, _), Is) )).

k55 :- check('a function-pointer parameter, inside out',
    ( unit('rich.c', unit(Is)), member(function(_, _, _, apply, [param(ptr([], fn(base([], [int]), [param(base([], [int]), anon)], false)), f), _], _, _), Is) )).

k56 :- check('a prototype is a declaration of a function type',
    ( unit('rich.c', unit(Is)), member(declaration(_, none, _, [var(apply, fn(_, _, _), none)]), Is) )).

k57 :- check('an array of pointers with a designated initializer',
    ( unit('rich.c', unit(Is)), member(declaration(_, none, base([const], [char]), [var(names, arr(int(4), ptr([], _)), init(L))]), Is), length(L, 3), last(L, item([at(int(3))], _)) )).   % the bound is one past the designator's index, taken at the read

k58 :- check('designators by field',
    ( unit('rich.c', unit(Is)), member(declaration(_, _, _, [var(origin, _, init([item([field(x)], int(0))|_]))]), Is) )).

k59 :- check('a float with an exponent, a hex integer, a char escape',
    ( unit('rich.c', unit(Is)), member(declaration(_, _, _, [var(ratio, _, float(1500.0))]), Is), member(declaration(_, _, _, [var(big, _, ulong(255))]), Is), member(declaration(_, _, _, [var(sep, _, chr(10))]), Is) )).

k60 :- check('the typedef name is a type from then on',
    ( fn_body('rich.c', main, B), member(declaration(_, none, base([], [typedef(point_t)]), _), B) )).

k61 :- check('for, if/else-if, continue, break, compound assignment',
    ( fn_body('rich.c', main, B), member(for(_, assign('=', id(i), int(0)), bin('<', id(i), int(10)), postinc(id(i)), block([if(_, _, continue(_), if(_, _, break(_), none)), expr(_, assign('+=', id(total), call(id(square), [id(i)])))])), B) )).   % LIMIT expanded

k62 :- check('while, do-while',
    ( fn_body('rich.c', main, B), member(while(_, bin('>', id(total), int(100)), expr(_, _)), B), member(do(_, block([expr(_, postinc(id(total)))]), bin('<', id(total), int(5))), B) )).

k63 :- check('switch with cases, a fallthrough and a default',
    ( fn_body('rich.c', main, B), member(switch(_, id(argc), block([case(_, int(1), expr(_, _)), break(_), case(_, int(2), default(_, expr(_, assign('=', id(total), neg(id(total))))))])), B) )).

k64 :- check('the conditional, casts, sizeof of a type and of an expression',
    ( fn_body('rich.c', main, B), member(expr(_, assign('=', id(total), cond(bin('>', id(argc), int(1)), cast(base([], [int]), id(ratio)), bin('+', cast(_, sizeof_type(base([], [typedef(point_t)]))), sizeof(member(id(p), x)))))), B) )).

k65 :- check('the operator levels: shift, or, and, unary not, xor',
    ( fn_body('rich.c', main, B), member(expr(_, assign('=', id(mask), bin('^', bin('&', bin('|', bin('<<', id(mask), int(2)), int(3)), bitnot(bin('<<', uint(1), int(4)))), int(15)))), B) )).

k66 :- check('member, address-of, arrow',
    ( fn_body('rich.c', main, B), member(expr(_, assign('=', arrow(member(id(n), next), flags), int(5))), B), member(expr(_, assign('=', member(id(n), next), addr(id(n)))), B) )).

k67 :- check('the comma operator, logical operators, goto and a label',
    ( fn_body('rich.c', main, B), member(expr(_, assign('=', id(i), comma(id(total), comma(id(mask), int(3))))), B), member(if(_, not(bin('||', bin('&&', id(i), id(total)), not(id(mask)))), goto(_, done), none), B), member(label(_, done, return(_, _)), B) )).

k68 :- check('adjacent string literals are one string',
    ( fn_body('rich.c', main, B), member(expr(_, call(id(printf), [_, _, str(S)])), B), codes_atom(S, ab) )).

k69 :- check('cicilang_ast/3 answers the tokens from the first thing it could not read',
    ( c('bad.c', P), cicilang_ast(P, unit(Is), [tok(_, _, 3)|_]), length(Is, 2) )).

k70 :- check('cicilang_ast/2 makes that a syntax error naming the line, and where it gave up',
    ( c('bad.c', P), catch(cicilang_ast(P, _), error(E, _), true), E == syntax_error(cicilang_ast(P, line(3), near(3))) )).

k71 :- check('a lexical error names its line too',
    ( c('lex.c', P), catch(cicilang_ast(P, _), error(syntax_error(cicilang_ast(_, lexical, line(L))), _), true), L =:= 2 )).

k81 :- check('the tie, x tie y: on a member, a result, a parameter, a local, and after :=',
    ( unit('tie.c', unit(Is)),
      member(declare(_, base(_, [struct(list, Ms)])), Is), member(member(ptr([tie(head)|_], _), cur, none), Ms),
      member(declaration(_, _, _, [var(find, fn(ptr([tie(head)|_], _), _, _), none)]), Is),
      member(function(_, _, _, f, [param(_, head), param(ptr([tie(head)|_], _), cur)], _, block(B)), Is),
      member(declaration(_, _, _, [var(b, base([tie(a)|_], [double]), float(_))]), B),
      member(declaration(_, _, _, [var(c, base([tie(b)|_], [int]), id(a))]), B) )).

k82 :- check('#cocolog ... #end defines macros in place: a clause, a rule, a DCG rule, and the block stays an item',
    ( unit('cocolog.c', unit(Is)), member(cocolog(2, _), Is),
      fn_body('cocolog.c', f, B), member(return(_, bin('+', bin('*', id(a), int(2)), bin('*', id(a), id(a)))), B),
      fn_body('cocolog.c', g, B2), member(expr(_, call(id(puts), [str(S)])), B2), atom_codes(A, S), A == 'hi bob' )).

%% C TEXT (0.260; CCLLIB.md's phase 0.1): test/c/run/ctext.c over its ctext.pl, and test/c/uses_ctext.c, ctext_bad.c and
%% ctext_nohole.c over test/c/ctext.pl
k96 :- check('C text at file scope: vec_of(0); is the text\'s typedef and two functions, each at the call\'s line 4, @{N}_push a pasted name, own @T *data an own int pointer',
    ( unit('run/ctext.c', unit(Is)),
      append(_, [typedef(4, [var(vec_int, base([], [struct(vec_int, Ms)]), none)]),
                 function(4, static, base([], [void]), vec_int_push, [param(ptr([], base([], [typedef(vec_int)])), v), param(base([], [int]), x)], false, _),
                 function(4, static, base([], [int]), vec_int_at, [param(ptr([], base([const], [typedef(vec_int)])), v), param(base([], [typedef(size_t)]), i)], false, _)|_], Is),
      memberchk(member(ptr([], base([own], [int])), data, none), Ms) )).

k97 :- check('a type hole in sizeof(@T) is the type, and @T in the text\'s comment is no hole',
    ( unit('run/ctext.c', unit(Is)), member(function(_, _, _, vec_int_push, _, _, block(B)), Is), member(if(4, _, block(Then), none), B),
      member(expr(4, assign('=', arrow(id(v), data), call(id(realloc), [arrow(id(v), data), bin('*', arrow(id(v), cap), sizeof_type(base([], [int])))]))), Then) )).

k98 :- check('C text as an expression: twice(a + 1) is (a + 1) * 2, the hole\'s AST in its place; quad(b), a text that calls twice twice, is b * 2 * 2',
    ( fn_body('run/ctext.c', main, B), member(expr(12, call(id(printf), As)), B),
      memberchk(bin('*', bin('+', id(a), int(1)), int(2)), As), memberchk(bin('*', bin('*', id(b), int(2)), int(2)), As) )).

k99 :- check('C text as statements: swap_any(a, b); is a block whose temporary is a fresh name (a name hole); repeat2(n++); is the statement hole twice',
    ( fn_body('run/ctext.c', main, B),
      member(block([declaration(9, none, base([], [int]), [var(T, base([], [int]), id(a))]), expr(9, assign('=', id(a), id(b))), expr(9, assign('=', id(b), id(T)))]), B), sub_atom(T, 0, 2, _, t_),
      member(block([expr(11, postinc(id(n))), expr(11, postinc(id(n)))]), B) )).

k100 :- check('the expansions that a text made name the program\'s arguments -- twice on b, and on b * 2 -- and no stand-in of a hole is left in the unit',
    ( unit('run/ctext.c', unit(Is)), append(_, ['$expansions'(Es)], Is),
      memberchk(expansion(12, twice, [id(b)]), Es), memberchk(expansion(12, twice, [bin('*', id(b), int(2))]), Es),
      findall(I, ( member(I, Is), I \= include(_, _, _) ), Own), term_to_atom(Own, A), \+ sub_atom(A, _, _, _, ccl_hole_) )).

k101 :- check('C text as a type name: const @T * over int * is a pointer to a const pointer to int, the qualifier joining the hole\'s type as a typedef\'s does (C17 6.7.8/3)',
    ( fn_body('uses_ctext.c', g, B), member(declaration(_, _, _, [var(t, _, str(S))]), B), codes_atom(S, 'ptr([],ptr([const],base([],[int])))') )).

k102 :- check('a hole in a literal is none ("@x and @{y}" with no hole bound), and the program\'s #define N 99 does not reach a text: @x + N is 1 + N',
    ( fn_body('uses_ctext.c', g, B), member(declaration(_, _, _, [var(s, _, str(S))]), B), codes_atom(S, '@x and @{y}'),
      member(return(_, bin('+', int(1), id('N'))), B) )).

k103 :- check('a text that does not read stops the read at the call, with the macro, its file and the text\'s own line: bad_items at line 2, the text\'s line 3',
    ( c('ctext_bad.c', P), c('ctext.pl', M), catch(cicilang_ast(P, _), error(macro_error(bad_items, [int(0)], error(ctext_error(T), _)), here(P, 2, in_macro(bad_items, M))), true),
      T == 'C text: the text does not read as file-scope items (its line 3)' )).

k104 :- check('a hole that Holes does not bind is refused by its name: C text: no hole @y',
    ( c('ctext_nohole.c', P), catch(cicilang_ast(P, _), error(macro_error(no_hole, [id(k)], error(ctext_error(T), _)), here(P, 2, _)), true), T == 'C text: no hole @y' )).

%% TYPE MACROS (0.261; CCLLIB.md's phases 0.2 to 0.4): test/c/run/tvector.c over its tvector.pl and tvhdr.h, and
%% tmacro_fail.c, tmacro_same.c and tmacro_typed.c over test/c/tmacro.pl
sub_t(X, X).
sub_t(X, T) :- compound(T), T =.. [_|As], member(A, As), sub_t(X, A).
top_items(Is, Ts) :- findall(T, ( member(I, Is), ( I = function(L, S, _, F, _, _, _) -> T = fn(L, S, F) ; I = typedef(L, [var(N, _, _)]) -> T = td(L, N) ) ), Ts).

k105 :- check('vector<T> in C: each instance -- its typedef and its functions -- stands at file scope before the first item that used it, once in the unit: vector<double> before sum, which main uses again; vector<point_t> and inplace<double, 8> before main',
    ( unit('run/tvector.c', unit(Is)), top_items(Is, Ts),
      Ts == [td(6, point_t), td(7, vector_double), fn(7, linkonce, vector_double_push), fn(7, linkonce, vector_double_at), fn(7, linkonce, vector_double_len),
             fn(7, linkonce, vector_double_drop), fn(7, linkonce, vector_double_from), fn(7, static, sum),
             td(18, vector_point_t), fn(18, linkonce, vector_point_t_push), fn(18, linkonce, vector_point_t_at), fn(18, linkonce, vector_point_t_len), fn(18, linkonce, vector_point_t_drop), fn(18, linkonce, vector_point_t_from),
             td(22, inplace_double_8), fn(12, none, main)] )).

k106 :- check('an instance that a header made stands in the header\'s unit, its functions linkonce, and the unit that includes it names it alone: vector<int> in tvhdr.h',
    ( unit('run/tvector.c', unit(Is)), member(include(_, local('tvhdr.h'), file(_, _, unit(Hs))), Is), top_items(Hs, Ts),
      Ts == [td(3, vector_int), fn(3, linkonce, vector_int_push), fn(3, linkonce, vector_int_at), fn(3, linkonce, vector_int_len), fn(3, linkonce, vector_int_drop), fn(3, linkonce, vector_int_from), fn(3, static, ivec_sum)],
      \+ member(typedef(_, [var(vector_int, _, _)]), Is) )).

k107 :- check('a value argument, inplace<double, 8>, is an array\'s bound; sizeof(vector<int>) and the cast (vector<int> *)0 name the instance made',
    ( unit('run/tvector.c', unit(Is)), member(typedef(_, [var(inplace_double_8, base([], [struct(inplace_double_8, Ms)]), none)]), Is),
      memberchk(member(arr(int(8), base([], [double])), a, none), Ms), fn_body('run/tvector.c', main, B),
      sub_t(sizeof_type(base([], [typedef(vector_int)])), B), sub_t(cast(ptr([], base([], [typedef(vector_int)])), int(0)), B) )).

k108 :- check('explicit types for a function macro: max<double>(3, 2.5) is the macro called with types([double]) first; max(4, 7) its other clause',
    ( fn_body('run/tvector.c', main, B), D = base([], [double]),
      sub_t(cond(bin('>', cast(D, int(3)), cast(D, float(2.5))), cast(D, int(3)), cast(D, float(2.5))), B), sub_t(cond(bin('>', int(4), int(7)), int(4), int(7)), B) )).

k109 :- check('a read that made or met an instance is kept in neither cache, the header\'s nor the file\'s, where a header that met none is',
    ( c('run/tvector.c', P), c('run/tvhdr.h', H), unit('run/tvector.c', _), ccl_kb_ready,
      \+ '$ccl_ast'(P, _, _), \+ '$ccl_ast'(H, _, _), \+ ccl_unit_cached(H, _, _), '$ccl_ast'(S, _, meta(included(_), _, _)), sub_atom(S, _, _, 0, '/stdlib.h') )).

k111 :- check('a header that the raw read does not take whole is read preprocessed, and its unit holds the instance that the raw attempt made and dropped: vector<long> in tvhdr2.h, once in the program',
    ( unit('run/tvector.c', unit(Is)), member(include(_, local('tvhdr2.h'), file(_, preprocessed, U)), Is), ( U = unit(Hs) ; U = partial(unit(Hs), _, _) ), !,
      member(typedef(_, [var(vector_long, _, _)]), Hs), findall(x, ( sub_t(T, Is), nonvar(T), T = typedef(_, [var(vector_long, _, _)]) ), Xs), length(Xs, 1) )).

%% AUTODROP (0.262; CCLLIB.md's phase 0.5): test/c/run/autodrop.c over its autodrop.pl, and test/c/run/tvector.c
k112 :- check('an instance\'s drop, <name>_drop(<name> *) among its items, has its parameter\'s pointee marked dying, as a C++ destructor\'s this',
    ( unit('run/tvector.c', unit(Is)), member(function(_, linkonce, base([], [void]), vector_double_drop, [param(ptr([], base([dying], [typedef(vector_double)])), v)], false, _), Is),
      member(function(_, linkonce, _, vector_point_t_drop, [param(ptr([], base([dying], [typedef(vector_point_t)])), v)], false, _), Is) )).

k113 :- check('a block\'s object of a type that has a drop is given zero where it has no initializer, and a defer of its drop follows its declaration, the object its mark',
    ( fn_body('run/tvector.c', main, B), V = base([], [typedef(vector_int)]),
      append(_, [declaration(13, none, V, [var(v, V, init([item([], int(0))]))]), defer(13, ['$autodrop'(v)], block([expr(13, call(id(vector_int_drop), [addr(id(v))]))]))|_], B),
      \+ ( member(D, B), D = defer(_, ['$autodrop'(b)], _) ) )).

k114 :- check('a parameter by value of a type that has a drop is the callee\'s: a defer of its drop at the body\'s head',
    ( fn_body('run/autodrop.c', take, [defer(_, ['$autodrop'(t)], block([expr(_, call(id(track_int_drop), [addr(id(t))]))]))|_]) )).

k115 :- check('an object named whole by value moves: an initializer, a call\'s argument and a return\'s value are move(...); a member read off it is not',
    ( fn_body('run/autodrop.c', main, B), fn_body('run/autodrop.c', pass, P),
      sub_t(var(n, _, move(id(m))), B), sub_t(call(id(take), [move(id(k))]), B), sub_t(return(_, move(id(t))), P),
      \+ sub_t(move(id(x)), B), sub_t(member(id(x), val), B) )).

k116 :- check('a for\'s object of a type that has a drop is a block\'s declaration around the loop, dropped where the loop ends',
    ( fn_body('run/autodrop.c', main, B), member(block([declaration(_, none, _, [var(f, _, _)]), defer(_, ['$autodrop'(f)], _), for(_, none, _, _, _)]), B) )).

k117 :- check('a later declaration of the name hides an autodropped object from the walk of the moves: an int named like it is not moved',
    ( unit('adshadow.c', unit(Is)), member(function(_, _, _, main, _, _, block(B)), Is),
      member(block(In), B), sub_t(call(id(use), [id(a)]), In), sub_t(call(id(take), [move(id(a))]), B) )).

%% LIST AND MAP LITERALS (0.263; CCLLIB.md's phase 0.6): test/c/run/literal.c over its literal.pl, and test/c/lit_*.c
k118 :- check('a literal at := with its types named is vector<T>: a call of vector_int_from over the compound literal of its elements and their count',
    ( fn_body('run/literal.c', main, B), I = base([], [int]),
      sub_t(call(id(vector_int_from), [compound_lit(arr(int(3), I), init([item([], int(5)), item([], int(3)), item([], int(9))])), int(3)]), B) )).

k119 :- check('a literal takes a declaration\'s declared type, its elements converted to the element type: [1, 2.5] of a vector<double>',
    ( fn_body('run/literal.c', main, B), D = base([], [double]),
      sub_t(call(id(vector_double_from), [compound_lit(arr(int(2), D), init([item([], int(1)), item([], float(2.5))])), int(2)]), B) )).

k120 :- check('a key: value literal at := with its types K:V named is map<K, V>: a call of map_int_double_from over its keys and its values',
    ( fn_body('run/literal.c', main, B), I = base([], [int]), D = base([], [double]),
      sub_t(call(id(map_int_double_from), [compound_lit(arr(int(2), I), init([item([], int(5)), item([], int(3))])), compound_lit(arr(int(2), D), init([item([], float(1.25)), item([], float(2.5))])), int(2)]), B) )).

k121 :- check('an empty literal is the empty object of the type its place gives: [] and [int;] of a vector<int>',
    ( fn_body('run/literal.c', main, B), V = base([], [typedef(vector_int)]), E = compound_lit(V, init([item([], int(0))])),
      sub_t(var(e, _, E), B), sub_t(var(e2, _, E), B) )).

k122 :- check('a literal takes the type of a call\'s parameter, of the left side of =, and of a return\'s function',
    ( fn_body('run/literal.c', main, B), fn_body('run/literal.c', halves, H),
      sub_t(call(id(count), [call(id(vector_int_from), _)]), B), sub_t(assign('=', id(x), call(id(vector_long_from), _)), B),
      sub_t(return(_, call(id(vector_double_from), _)), H) )).

k123 :- check('a key given twice, one of the two no constant, is taken -- the map keeps the first at run time, as std::map does -- and so is a trailing comma',
    ( fn_body('run/literal.c', main, B), sub_t(call(id(map_int_int_from), [compound_lit(arr(int(3), _), init([item([], id(k)), item([], int(1)), item([], int(2))])), _, int(3)]), B) )).

lit_refused(F, L, M) :- c(F, P), catch(cicilang_ast(P, _), error(list_literal(M0), here(P, L0)), true), L0 == L, M0 == M.
k124 :- check('a literal is refused at its line in clang\'s manner: narrowing, two equal constant keys, no types to name, map types with a comma, mixed items, a type that is no instance, no common type, a variadic argument, other types than the declared one, no type macro',
    ( lit_refused('lit_narrow.c', 6, 'narrowing conversion of an element of the literal from double to int'),
      lit_refused('lit_narrow2.c', 6, 'narrowing conversion of an element of the literal from long to int'),
      lit_refused('lit_char.c', 6, 'narrowing conversion of an element of the literal from int to char'),
      lit_refused('lit_keys.c', 6, 'two equal keys in a map literal: 1'),
      lit_refused('lit_empty.c', 6, 'an empty literal names its types: [int;] or [int:double;]'),
      lit_refused('lit_comma.c', 6, 'a map literal\'s types are written with a colon: [K:V; k: v]'),
      lit_refused('lit_mixed.c', 6, 'a literal\'s items are all elements or all key: value pairs'),
      lit_refused('lit_target.c', 6, 'a list literal makes a type macro\'s instance, not int'),
      lit_refused('lit_common.c', 6, 'the elements of a literal with no types have no common type: name its types'),
      lit_refused('lit_vararg.c', 7, 'a list literal as an argument takes its parameter\'s type, and this argument has no parameter'),
      lit_refused('lit_types.c', 6, 'the literal\'s types are not those of the type it makes'),
      lit_refused('lit_nomacro.c', 4, 'a list literal needs the type macro vector (its macro file included)') )).

%% ARGUMENTS READ AFTER THE MACRO (0.264; CCLLIB.md's phase 0.7): test/c/run/unread.c over its unread.pl, unread_*.c over
%% unread_bad.pl, forscope.c
k125 :- check('a clause head\'s unread(_) marks its place: the macro file\'s entries hold unread(Name, Arity, Places) beside its macro/3',
    ( unit('run/unread.c', unit(Is)), member(include(_, local('unread.pl'), macros(_, Ps)), Is),
      memberchk(unread(loop, 4, [3]), Ps), memberchk(unread(each, 4, [3]), Ps), memberchk(unread(sum_by, 4, [3]), Ps),
      memberchk(unread(sort_by, 5, [4]), Ps), memberchk(macro(loop, loop, 4), Ps), \+ memberchk(unread(ur_elem, _, _), Ps) )).

k126 :- check('an argument taken unread is read where the macro\'s C text puts it, after the text declares its names: println in loop\'s body formats the loop\'s int m',
    ( fn_body('run/unread.c', main, B), atom_codes('m = %d\n', S1),
      sub_t(for(_, decl(base([], [int]), [var(m, base([], [int]), int(0))]), bin(<, id(m), int(3)), postinc(id(m)), block([expr(_, call(id(printf), [str(S1), id(m)]))])), B) )).

k127 :- check('the loop\'s m hides the block\'s double m in the body alone: inner m by %d, outer m by %g after the loop, and a plain for\'s k too',
    ( fn_body('run/unread.c', main, B), atom_codes('inner m = %d\n', S1), atom_codes('outer m = %g\n', S2), atom_codes('k = %g\n', S3),
      sub_t(call(id(printf), [str(S1), id(m)]), B), sub_t(call(id(printf), [str(S2), id(m)]), B), sub_t(call(id(printf), [str(S3), id(k)]), B) )).

k128 :- check('an unread argument holds a macro that takes its own unread -- a loop in a loop\'s body -- and a block with := in it',
    ( fn_body('run/unread.c', main, B), atom_codes('%d %d\n', S1), atom_codes('y = %g\n', S2),
      sub_t(call(id(printf), [str(S1), id(i), id(j)]), B), sub_t(var(y, base([], [double]), _), B), sub_t(call(id(printf), [str(S2), id(y)]), B) )).

k129 :- check('the record of an expansion names an unread argument by its text',
    ( unit('run/unread.c', unit(Is)), append(_, ['$expansions'(Es)], Is), memberchk(expansion(_, loop, [id(m), int(3), unread('println("m = {}", m)')]), Es) )).

k130 :- check('a type that the reader\'s tables hold through a C text\'s type hole is its type in the AST: := of an instance\'s at, each\'s element, no ccl_hole_ name left',
    ( unit('run/unread.c', unit(Is)), fn_body('run/unread.c', main, B), sub_t(var(w, base([], [int]), _), B), sub_t(var(x, base([], [int]), _), B),
      \+ ( member(I, Is), I \= include(_, _, _), sub_t(typedef(H), I), atom(H), atom_concat(ccl_hole_, _, H) ) )).

k131 :- check('a for is a block: the name its init declares ends with it, and := after the loop takes the outer double',
    ( fn_body('forscope.c', main, B), sub_t(var(x, base([], [double]), id(m)), B) )).

k132 :- check('a macro that gives back an argument it took unread, and an unread argument that does not read where the text puts it, are refused at the call',
    ( c('unread_back.c', P1), catch(cicilang_ast(P1, _), error(macro_error(M1, here(P1, 3)), _), true),
      M1 == 'the macro keep gives back an argument that it took unread: a C text reads it, `@x\' with x = the argument',
      c('unread_place.c', P2), c('unread_bad.pl', MF),
      catch(cicilang_ast(P2, _), error(macro_error(plus_one, [unread('int z')], error(ctext_error(M2), _)), here(P2, 3, in_macro(plus_one, MF))), true),
      M2 == 'C text: an argument taken unread does not read where the text puts it, in an expression' )).

k133 :- check('cicilang++ refuses by name a macro that takes an argument unread: cicilang reads it in C (CCLLIB.md\'s phase 0.10)',
    ( c('../cpp/unread_cpp.cpp', P), nb_getval('$ccl_lang', L0), nb_setval('$ccl_lang', cpp),
      catch(cicilang_ast(P, _), E, true), nb_setval('$ccl_lang', L0),
      nonvar(E), E = error(macro_error(M, here(P, 4)), _),
      M == 'the macro loop takes an argument unread, which cicilang reads in C and cicilang++ does not yet (CCLLIB.md\'s phase 0.10)' )).

k110 :- check('a type macro that fails, two instances that one name names, and a typed call of a macro with no typed form are refused at the use',
    ( c('tmacro_fail.c', P1), c('tmacro.pl', M), catch(cicilang_ast(P1, _), error(E1, here(P1, 3, in_macro(type_none, M))), true), E1 == macro_failed(none, [base([], [int])]),
      c('tmacro_same.c', P2), catch(cicilang_ast(P2, _), error(macro_error(pair, _, error(ctext_error(T2), _)), here(P2, 7, _)), true),
      T2 == 'the instance\'s type is the type of pair<a_b, c>\'s instance',
      c('tmacro_typed.c', P3), catch(cicilang_ast(P3, _), error(macro_error(T3, here(P3, 3)), _), true), T3 == 'the macro twice takes no types before its 1 argument(s)' )).

k83 :- check('pp_defs.h is preprocessed (its false group is not C): #if/#elif/#else, defined, __has_include, ##, #, __VA_ARGS__, a continuation, __LINE__',
    ( unit('pp.c', unit([include(1, local('pp_defs.h'), file(_, preprocessed, unit(Is)))|_])),
      member(typedef(_, [var(mytype, base([], [int]), none)]), Is),
      member(declaration(_, static, _, [var(pp_text, _, str(S))]), Is), atom_codes(A, S), A == 'hello world',
      member(declare(_, base(_, [enum(_, Es)])), Is),
      member(enumerator('PP_AREA', int(12)), Es), member(enumerator('PP_CAT', int(42)), Es),   % C folds an enumerator at the read (0.195)
      member(enumerator('PP_TAKEN', int(1)), Es), member(enumerator('PP_HAS', int(1)), Es), member(enumerator('PP_BITS', int(64)), Es),
      member(enumerator('PP_ZERO', int(7)), Es), member(enumerator('PP_LINE', int(40)), Es) )).

%% the native lexer (module/cicilang.cicili) against the DCG (ccl_lex//2), on
%% the corners fixture in every mode and both languages, the real fixtures,
%% and the SDK's headers: the same tokens, the same rest; the preprocessor's
%% marked mode (0.209, ccl_lex_marked//2) its marks of white space too -- the
%% DCG's mark of a name's spelling aside, '$ucn' (0.228): a line that writes
%% one is the DCG's alone (ccl_lex_atom_marked/4)
k84 :- check('the native lexer gives the DCG\'s tokens and rest on lexer.c (line/punct/punctsp, c/cpp), rich.c, cocolog.c, btree_del.c, classes.cpp, cdefs.h, math.h',
    ( c('lexer.c', Lex), c('rich.c', Rich), c('cocolog.c', Coc), c('run/btree_del.c', Bt), c('../cpp/classes.cpp', Cls),
      lex_same(Lex, line, c), lex_same(Lex, punct, c), lex_same(Lex, line, cpp), lex_same(Lex, punct, cpp),
      lex_same(Lex, punctsp, c), lex_same(Lex, punctsp, cpp), lex_same(Cls, punctsp, cpp),
      lex_same(Rich, line, c), lex_same(Coc, line, c), lex_same(Bt, line, c), lex_same(Cls, line, cpp),
      lex_sdk('sys/cdefs.h', line, c), lex_sdk('sys/cdefs.h', punct, c), lex_sdk('math.h', punct, c), lex_sdk('math.h', punctsp, c) )).
k85 :- check('and the native lexer is the one the reader runs',
    ( nb_getval('$ccl_lexer', native) )).
k94 :- check('an identifier\'s characters past ASCII by the language and its level, and the white space past ASCII (0.221): the native lexer gives the DCG\'s tokens -- a, the euro sign and b one name in C17 and C11, a name, tok(other, 8364) and a name in C23 and C++; a middle dot first a name in C17 and tok(other, 183) in C++; a combining acute after x one name in C11 and the name x and tok(other, 769) in C99; a no-break space two names',
    ( lex_both([105,110,116,32,97,8364,98,59], c, 17, T1), T1 = [tok(kw, int, 1), tok(id, A1, 1), tok(p, ';', 1)], atom_codes(A1, [97,8364,98]),
      lex_both([105,110,116,32,97,8364,98,59], c, 11, T1),
      lex_both([105,110,116,32,97,8364,98,59], c, 23, T2), T2 = [tok(kw, int, 1), tok(id, a, 1), tok(other, 8364, 1), tok(id, b, 1), tok(p, ';', 1)],
      lex_both([105,110,116,32,97,8364,98,59], cpp, 17, T2),
      lex_both([105,110,116,32,183,120,59], c, 17, T3), T3 = [tok(kw, int, 1), tok(id, A3, 1), tok(p, ';', 1)], atom_codes(A3, [183,120]),
      lex_both([105,110,116,32,183,120,59], cpp, 23, T4), T4 = [tok(kw, int, 1), tok(other, 183, 1), tok(id, x, 1), tok(p, ';', 1)],
      lex_both([105,110,116,32,120,769,59], c, 11, T5), T5 = [tok(kw, int, 1), tok(id, A5, 1), tok(p, ';', 1)], atom_codes(A5, [120,769]),
      lex_both([105,110,116,32,120,769,59], c, 99, T6), T6 = [tok(kw, int, 1), tok(id, x, 1), tok(other, 769, 1), tok(p, ';', 1)],
      lex_both([105,110,116,32,97,160,98,59], c, 23, T7), T7 = [tok(kw, int, 1), tok(id, a, 1), tok(id, b, 1), tok(p, ';', 1)],
      lex_both([105,110,116,32,97,12288,98,59], cpp, 17, T7) )).
%% the codes lexed by both lexers in the preprocessor's mode, in the language at the C level: the same tokens, all of the text
lex_both(Cs, Lang, Std, T) :-
    ccl_ensure_globals, nb_getval('$ccl_hash', M0), nb_getval('$ccl_lang', L0), ( nb_current('$ccl_c_std', S0) -> true ; S0 = 17 ),
    nb_setval('$ccl_hash', punct), nb_setval('$ccl_lang', Lang), nb_setval('$ccl_c_std', Std),
    ( phrase(ccl_lex(1, T1), Cs, R1), atom_codes(A, Cs), ccl_lex_lang(Lg), ccl_lex_native(A, 1, punct, Lg, T2, R2) -> Ok = true ; Ok = false ),
    nb_setval('$ccl_hash', M0), nb_setval('$ccl_lang', L0), nb_setval('$ccl_c_std', S0),
    Ok == true, T1 == T2, R1 == [], R2 == [], T = T1.
lex_sdk(Name, Mode, Lang) :- ( ccl_include_path(Ds), member(D, Ds), atomic_list_concat([D, '/', Name], F), exists_file(F) -> lex_same(F, Mode, Lang) ; true ).
lex_same(File, Mode, Lang) :-
    nb_getval('$ccl_hash', M0), nb_getval('$ccl_lang', L0),
    ( Mode == punctsp -> H = punct, G = ccl_lex_marked(1, T1) ; H = Mode, G = ccl_lex(1, T1) ),
    nb_setval('$ccl_hash', H), nb_setval('$ccl_lang', Lang),
    read_file_to_codes(File, Cs), phrase(G, Cs, R1), atom_codes(A, Cs), ccl_lex_native(A, 1, Mode, Lang, T2, R2),
    nb_setval('$ccl_hash', M0), nb_setval('$ccl_lang', L0),
    lex_no_ucn(T1, T1a), T1a == T2, R1 == R2, T1 = [_|_], ( Mode == punctsp -> memberchk(h(_, ['$sp']), T1), memberchk(tok(_, _, _), T1) ; true ).
lex_no_ucn([], []).
lex_no_ucn([h(T, Ms)|Xs], [Y|Ys]) :- !, findall(M, ( member(M, Ms), M \= '$ucn'(_) ), Ms1), ( Ms1 == [] -> Y = T ; Y = h(T, Ms1) ), lex_no_ucn(Xs, Ys).
lex_no_ucn([X|Xs], [X|Ys]) :- lex_no_ucn(Xs, Ys).
%% A NAME WRITTEN WITH A UNIVERSAL CHARACTER NAME in the marked mode (0.228): the token the name's, marked with its
%% spelling for `#x', `S(caf\u00e9) x' over codes, and the line the DCG's
k95 :- check('a name written with a universal character name is marked with its spelling in the preprocessor\'s marked mode, h(tok(id, N, L), [\'$ucn\'(Spelling)]), which #x spells (0.228); such a line is the DCG\'s',
    ( Cs = [83,40,99,97,102,92,117,48,48,101,57,41,32,120], atom_codes(A, Cs), ccl_ucn_text(A),
      ccl_ensure_globals, nb_getval('$ccl_hash', M0), nb_getval('$ccl_lang', L0), ( nb_current('$ccl_c_std', S0) -> true ; S0 = 17 ),
      nb_setval('$ccl_hash', punct), nb_setval('$ccl_lang', c), nb_setval('$ccl_c_std', 17),
      ( ccl_lex_atom_marked(A, 1, T, R) -> true ; T = none ), nb_setval('$ccl_hash', M0), nb_setval('$ccl_lang', L0), nb_setval('$ccl_c_std', S0),
      R == [], T = [h(tok(id, 'S', 1), ['$sp']), tok(p, '(', 1), h(tok(id, N, 1), ['$ucn'(Sp)]), tok(p, ')', 1), h(tok(id, x, 1), ['$sp'])],
      atom_codes(N, [99,97,102,233]), atom_codes(Sp, [99,97,102,92,117,48,48,101,57]) )).

k87 :- check('C23 (-std=c23): constexpr a constant that folds, enum : unsigned char, [[maybe_unused]], typeof, static_assert with and without a message, _Static_assert',
    ( unit_c('run/c23.c', 23, unit(Is)),
      member(declaration(_, none, base(Q, [int]), [var('K', _, int(7))]), Is), memberchk(const, Q),
      member(declare(_, base(_, [enum('Small', [enum_base(base([], [unsigned, char])), enumerator('A', int(1)), enumerator('B', none)])])), Is),
      member(static_assert(_, bin('==', id('K'), int(7)), str(_)), Is),
      member(static_assert(_, bin('>', id('K'), int(0)), none), Is),
      member(static_assert(_, bin('==', sizeof_type(_), int(4)), str(_)), Is),
      member(typedef(_, [var(kint, base([], [typeof(id('K'))]), none)]), Is) )).
k89 :- check('C23: __VA_OPT__ keeps or drops its group, #embed puts the resource\'s bytes where it stood (limit, prefix, suffix, if_empty), __has_embed and __has_c_attribute answer',
    ( unit_c('run/c23pp.c', 23, unit(Is)),
      member(declaration(_, static, _, [var(data, _, init([item(_, int(104)), item(_, int(101)), item(_, int(108)), item(_, int(108)), item(_, int(111))]))]), Is),
      member(declaration(_, static, _, [var(part, _, init([item(_, int(1)), item(_, int(104)), item(_, int(101)), item(_, int(108)), item(_, int(99))]))]), Is),
      member(declaration(_, static, _, [var(none, _, init([item(_, int(7)), item(_, int(8))]))]), Is),
      member(directive(_, '#define E1 1'), Is), member(directive(_, '#define E2 1'), Is), member(directive(_, '#define E3 1'), Is), member(directive(_, '#define A1 1'), Is),
      member(function(_, _, _, main, _, _, block(B)), Is),
      member(expr(_, call(id(printf), [str(_)])), B),
      member(expr(_, call(id(printf), [str(_), int(1), int(2)])), B) )).
k91 :- check('C11 and C17: L"wide" is wstr, u"..." u16str, U"..." u32str, u8"..." a plain str, the chars alike; _Thread_local is the qualifier thread_local; int v[n] keeps its bound',
    ( unit('run/c17rest.c', unit(Is)),
      member(declaration(_, none, base(Q, [int]), [var(counter, _, int(5))]), Is), memberchk(thread_local, Q),
      member(declaration(_, static, base(Q2, [int]), [var(hidden, _, none)]), Is), memberchk(thread_local, Q2),
      member(function(_, _, _, main, _, _, block(B)), Is),
      member(declaration(_, none, _, [var(v, arr(id(n), base([], [int])), none)]), B),
      member(declaration(_, none, _, [var(w, _, wstr([119, 105, 100, 101]))]), B),
      member(declaration(_, none, _, [var(u, _, str([117, 116, 102, 56]))]), B),
      member(declaration(_, none, _, [var(s16, _, u16str([97, 98]))]), B),
      member(declaration(_, none, _, [var(s32, _, u32str([120, 121, 122, 195, 169]))]), B),
      member(expr(_, call(id(printf), [_, cast(_, sizeof(wchr(120)))|_])), B) )).
k92 :- check('GNU\'s __int128 is a type word: typedef __int128 i128 and typedef unsigned __int128 u128 read, struct W holds one, and a cast to it reads',
    ( unit('run/int128.c', unit(Is)),
      member(typedef(_, [var(i128, base(_, S1), none)]), Is), memberchk('__int128', S1), \+ memberchk(unsigned, S1),
      member(typedef(_, [var(u128, base(_, S2), none)]), Is), memberchk('__int128', S2), memberchk(unsigned, S2),
      member(declare(_, base(_, [struct('W', Ms)])), Is), member(member(base(_, S3), v, none), Ms), memberchk('__int128', S3),
      member(function(_, _, _, mul, _, _, _), Is) )).
k93 :- check('a float in a stored read comes back exactly, 17 digits and the largest double: cocolog writes a float with 15 (0.132)',
    ( c('floats.c', P), ccl_kb_forget_file(P), cicilang_ast(P, A), ccl_kb_cached(P, top, B), A == B,
      A = unit(Is), member(declaration(_, _, _, [var(b, _, float(F))]), Is), F =:= 1.7976931348623157e308,
      member(declaration(_, _, _, [var(a, _, float(G))]), Is), G =\= 0.3 )).
k90 :- check('C23: _BitInt(N) a specifier, _Generic chosen at the read, _Alignof and alignof, _Alignas kept as the qualifier aligned(E), nullptr_t and unreachable() from <stddef.h>',
    ( unit_c('run/c23b.c', 23, unit(Is)),
      member(declaration(_, none, base(_, [bitint(int(7))]), [var(small, _, int(60))]), Is),
      member(declaration(_, none, base(_, S12), [var(twelve, _, int(4000))]), Is), memberchk(bitint(int(12)), S12), memberchk(unsigned, S12),
      member(function(_, _, _, main, _, _, block(B)), Is),
      member(declaration(_, none, _, [var(np, base([], [typedef(nullptr_t)]), nullptr)]), B),
      member(declaration(_, none, base(QA, [int]), [var(aligned, _, int(5))]), B), memberchk(aligned(int(16)), QA),
      member(expr(_, call(id('__builtin_unreachable'), [])), B),
      member(expr(_, call(id(printf), [_, int(1), int(2), int(3), int(4), int(9), cast(_, alignof_type(_)), id(mut)])), B) )).
k88 :- check('C23: bool/true/false and nullptr are the language\'s, auto deduces, an array bound folds from a constexpr, 0b101010 and 1\'000\'000 are numbers',
    ( unit_c('run/c23.c', 23, unit(Is)), member(function(_, _, _, main, _, _, block(B)), Is),
      member(declaration(_, none, base([], [bool]), [var(t, _, bool(true))]), B),
      member(declaration(_, none, base([], [bool]), [var(f, _, bool(false))]), B),
      member(declaration(_, none, _, [var(p, ptr([], base([], [int])), nullptr)]), B),
      member(declaration(_, none, base([], [int]), [var(n, _, bin('+', id('K'), int(1)))]), B),
      member(declaration(_, none, _, [var(arr, arr(int(7), _), none)]), B),   % C folds a bound over a named constant at the read (0.195)
      member(expr(_, assign('=', index(id(arr), int(0)), int(42))), B),
      member(declaration(_, none, _, [var(big, _, int(1000000))]), B),
      member(declaration(_, none, _, [var(d, _, float(15.25))]), B) )).
k86 :- check('macros.c: SQ(a[i]) expanded, CAT(tw, o) a name, NULL the cast, the #if group gone, #define kept as a directive item',
    ( unit('macros.c', unit(Is)), member(directive(6, '#define SQ(x) ((x) * (x))'), Is), \+ member(directive(_, '#  define BITS 32'), Is),
      member(declaration(21, none, _, [var(two, _, int(2))]), Is),
      fn_body('macros.c', main, B), member(declaration(_, none, _, [var(a, arr(int(4), _), _)]), B),
      member(declaration(_, none, _, [var(p, _, cast(ptr([], base([], [void])), int(0)))]), B),
      member(for(_, _, _, _, expr(_, assign('+=', id(sum), bin('*', index(id(a), id(i)), index(id(a), id(i)))))), B) )).

t_checks :-
    section('hello.c, whole'),
    k1,
    k2,
    k3,
    k4,
    k5,
    section('includes: found on the inclusion path, read, and their typedefs known'),
    k6,
    k7,
    k8,
    k9,
    k10,
    k11,
    k12,
    k13,
    section('the knowledge base remembers what was read, by modification time'),
    k14,
    k15,
    k16,
    k17,
    k18,
    section('macros: a .pl included is a set of macro functions over ASTs'),
    k19,
    k20,
    k21,
    k22,
    k23,
    k24,
    k25,
    k26,
    k27,
    k28,
    k29,
    k79,
    k80,
    section(':= declares by inference'),
    k30,
    k31,
    k32,
    k33,
    k34,
    k35,
    k36,
    section('the left of := may be a pattern over a struct'),
    k37,
    k38,
    k39,
    k40,
    k41,
    section('format, print, println: global macros, Rust\'s holes, the symbol table\'s types'),
    k42,
    k43,
    k44,
    k45,
    k46,
    section('name { ... } at file scope is typedef struct name { ... } name;'),
    k47,
    k48,
    k49,
    section('defer(a, b) { ... }: scope-bound, like cleanup'),
    k72,
    k73,
    k74,
    section('the safe part, as read: own and move'),
    k75,
    k76,
    section('statement lines'),
    k77,
    k78,
    section('rich.c: the grammar, one construct at a time'),
    k50,
    k51,
    k52,
    k53,
    k54,
    k55,
    k56,
    k57,
    k58,
    k59,
    k60,
    k61,
    k62,
    k63,
    k64,
    k65,
    k66,
    k67,
    k68,
    section('the tie'),
    k81,
    section('a #cocolog block'),
    k82,
    section('C text: a macro writes C with holes, which the reader reads (0.260)'),
    k96,
    k97,
    k98,
    k99,
    k100,
    k101,
    k102,
    k103,
    k104,
    section('type macros: vector<int> in C, its instance made once in the unit, linkonce (0.261)'),
    k105,
    k106,
    k107,
    k108,
    k109,
    k110,
    k111,
    section('autodrop: an object of a type that has a drop, dropped where its scope ends (0.262)'),
    k112,
    k113,
    k114,
    k115,
    k116,
    k117,
    section('list and map literals: [int; 5, 3, 9], [int:double; 5: 1.25] (0.263)'),
    k118,
    k119,
    k120,
    k121,
    k122,
    k123,
    k124,
    section('arguments read after the outer macro: loop(m, 3, println("{}", m)) (0.264)'),
    k125,
    k126,
    k127,
    k128,
    k129,
    k130,
    k131,
    k132,
    k133,
    section('the preprocessor, in cocolog: a header raw cannot take'),
    k83,
    section('the lexer, native: ccl_lex_native/6 token for token with the DCG'),
    k84,
    k85,
    k94,
    k95,
    section('the user\'s file through the preprocessor: its macros, and the headers\' macros'),
    k86,
    k87,
    k88,
    k89,
    k90,
    k91,
    k92,
    k93,
    section('where it stops'),
    k69,
    k70,
    k71.

%% ---- real C from the neighbours ----------------------------------------------
%% not chk/3 facts: each file is checked only if the neighbour checkout has it
t_real :-
    section('real C from the neighbours, read entirely'),
    os_env('CICILI', Cicili),
    real_file(Cicili, 'test/c/main.c'), real_file(Cicili, 'test/c/shared.c'), real_file(Cicili, 'test/c/macro.c'),
    real_file(Cicili, 'example/cimath.c'), real_file(Cicili, 'example/numpy_example.c').
real_file(Cicili, Rel) :-
    atomic_list_concat([Cicili, '/', Rel], P),
    (   exists_file(P)
    ->  check(Rel, ( cicilang_ast(P, unit(_), Rest), ( Rest == [] -> true ; Rest = [tok(_, _, L)|_], ccl_farthest(F), write('     stopped at '), write(L), write(' near '), write(F), nl, fail ) ))
    ;   write('SKIP '), write(Rel), write(' (not here)'), nl ).
