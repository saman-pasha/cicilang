%% readhdr.pl -- read ONE library header whole, at a level, report its item count.
%% Run per header in its own process (for the parallel pool) with HOME set to the
%% shared warm cache, the summary pre-deleted so the read is cold and writes a
%% fresh summary as a side effect. Args by environment: CCL_HDR, CCL_STD, CCL_MIN.
:- use_module(library(cicilang)).
readhdr_main :-
    os_env('CCL_HDR', H), os_env('CCL_STD', StdA), os_env('CCL_MIN', MinA),
    atom_number(StdA, Std), atom_number(MinA, Min),
    nb_setval('$ccl_std', Std),
    os_env('CCL_TEST_TMP', D), atomic_list_concat([D, '/inc_', H, '_', Std, '.cpp'], F),
    atomic_list_concat(['#include <', H, '>\n'], Text), atom_codes(Text, Cs), write_file_from_codes(F, Cs),
    (   catch(cicilang_ast(F, unit(Is)), E, (print_message(error, E), fail)),
        member(include(_, system(H), file(_, preprocessed, U)), Is)
    ->  (   U = unit(Items) -> length(Items, K),
            ( Min =:= 0 -> format("warm <~w> C++~w: ~w items~n", [H, Std, K])
            ; K >= Min -> format("ok   <~w> at C++~w flattened and read whole: ~w items~n", [H, Std, K])
            ; format("FAIL <~w> at C++~w read whole but only ~w items~n", [H, Std, K]) )
        ;   U = partial(unit(Items), line(L), near(Far)) -> length(Items, K), format("FAIL <~w> at C++~w read PARTIAL: ~w items, stopped at line ~w, farthest ~w~n", [H, Std, K, L, Far])
        ;   format("FAIL <~w> at C++~w: ~w~n", [H, Std, U]) )
    ;   format("FAIL <~w> at C++~w could not be read~n", [H, Std]) ).
