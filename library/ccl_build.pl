%% cicilang -- library(ccl_build): from IR to an object file, and from
%% object files to a binary or a library.
%%
%%   cicilang_compile(+IR, +File, +Flags)   the IR module text -> the object File;
%%                                        Flags a list of atoms ('-O2', '-g' ...)
%%   cicilang_link(+Objects, +Flags, +Out)  object files -> Out, a binary, or a
%%                                        library when Flags say so (-shared)
%%
%% cicilang_compile goes through the embedded LLVM, library(ccl_llvm): parse,
%% verify, the passes the flags ask for, the object. That module is the whole
%% back end (owner's rule: no clang, no LLVM binary); where it is not built
%% the compile is an error naming module/build-llvm.sh. cicilang_link drives
%% the system linker through cc (c++ for cicilang++), the way Cicili drives cc
%% for its C: llvm-c has no linker to embed.

:- use_module(library(process)).

ccl_compile(IR, File, Flags) :-
    ( ccl_llvm_ready -> ccl_llvm_compile(IR, File, Flags), ccl_note_libatomic(IR) ; throw(error(no_embedded_llvm, cicilang_compile(File))) ).
ccl_llvm_ready :- once(catch(use_module(library(ccl_llvm)), _, fail)), once(catch(ccl_llvm_version(_), _, fail)).
%% AN OBJECT THAT CALLS LIBATOMIC (0.208): libatomic's generic routines, which an atomic object of a size that is no lock-free width
%% and an x86 `long double' take (ccl_ir's ir_atomic_lib/6), and LLVM's own `__atomic_*_16' for a sixteen-byte one; the next link
%% names the library, as it names libm (ccl_link_libs/1). An IR served from the store holds the same calls, so its text is asked
ccl_note_libatomic(IR) :- ( ccl_ir_has(IR, '@__atomic_') ; ( ccl_ir_has(IR, ' i128') ; ccl_ir_has(IR, ' fp128') ), ( ccl_ir_has(IR, ' atomic ') ; ccl_ir_has(IR, 'atomicrmw ') ; ccl_ir_has(IR, 'cmpxchg ') ) ), !,
    nb_setval('$ccl_latomic', yes).
ccl_note_libatomic(_).
%% ... the text split at the string, which is linear: cocolog's sub_atom/5 seeking a substring with its place unbound is
%% quadratic in the atom's length (2.11.6: 5.5 s over 100 KB), and the build of a C++ fixture's IR of megabytes did not end
ccl_ir_has(IR, S) :- ( atom(IR) -> A = IR ; string(IR) -> atom_string(A, IR) ), atomic_list_concat(Ps, S, A), Ps = [_, _|_], !.

ccl_link(Objects, Flags, Out) :-
    ccl_words(Objects, Os), ccl_words(Flags, F),
    ccl_linker(Ld),
    ccl_link_libs(Libs0), ccl_libatomic_lib(Libs0, Libs),
    atomic_list_concat([Ld, ' ', Os, ' ', F, Libs, ' -o \'', Out, '\' 2>&1'], Cmd),
    ccl_sh(Cmd, O, Exit),
    ( Exit =:= 0 -> true ; atom_codes(Msg, O), throw(error(link_failed(Msg), cicilang_link(Out))) ).
%% ... `-latomic' on Linux, this machine's or another's, once for the objects compiled since the last link
ccl_libatomic_lib(Libs0, Libs) :- nb_current('$ccl_latomic', yes), nb_setval('$ccl_latomic', no), ( ccl_cross_target(_, linux) ; \+ ccl_cross_target(_, _), ccl_host_os(linux) ), !, atom_concat(Libs0, ' -latomic', Libs).
ccl_libatomic_lib(Libs, Libs).

%% THE LINKER: cc, or c++ for cicilang++; for another machine (dr_set_target/1) its cross gcc, `aarch64-linux-gnu-gcc' (0.131)
ccl_linker(Ld) :- ccl_cross_target(A, O), ccl_cross_prefix(A, O, P), !, ( ccl_lang(cpp) -> atom_concat(P, '-g++', Ld) ; atom_concat(P, '-gcc', Ld) ).
ccl_linker(Ld) :- ( ccl_lang(cpp) -> Ld = 'c++' ; Ld = cc ).
ccl_cross_target(A, O) :- nb_current('$ccl_target', target(A, O, _)), \+ ( catch(ccl_host_arch(A), _, fail), catch(ccl_host_os(O), _, fail) ).
ccl_cross_prefix(arm64, linux, 'aarch64-linux-gnu').
ccl_cross_prefix(x86_64, linux, 'x86_64-linux-gnu').
%% THE C++ RUNTIME IS NAMED ON LINUX (0.93): a program is compiled against libc++'s headers (the one tree this compiler reads,
%% ccl_toolchain_dirs), and on macOS `c++' is clang, whose C++ library is libc++; on Debian and Ubuntu `c++' is g++, whose is
%% libstdc++, so the link found no `std::__1::__libcpp_verbose_abort' -- libc++'s runtime, `-lc++', is asked for by name there.
ccl_link_libs(Libs) :- ccl_cross_target(_, _), !,   % another machine (0.131): its own C library's libm ...
    (   ccl_lang(cpp), ccl_cxx_dirs([TD]), ccl_cross_sysroot(SR), atom_concat(SR, HD, TD), atom_concat(Root, '/include/c++/v1', HD), atom_concat(Root, '/lib', Run), atom_concat(SR, Run, Lib), exists_directory(Lib)
    ->  atomic_list_concat([' -L\'', Lib, '\' -Wl,-rpath-link,\'', Lib, '\' -Wl,-rpath,\'', Run, '\' -lc++ -lm'], Libs)   % ... and in C++ its libc++ (0.161), the tree read under the sysroot: found there at the link, and at the run where that machine keeps it, Root/lib, which `qemu-aarch64 -L' takes under the sysroot
    ;   Libs = ' -lm' ).
ccl_link_libs(Libs) :- ccl_lang(cpp), ccl_host_os(linux), !,
    (   ccl_cxx_dirs([D]), atom_concat(Root, '/include/c++/v1', D), atom_concat(Root, '/lib', Lib), exists_directory(Lib)   % THE LIBRARY OF THE TREE THE PROGRAM WAS READ FROM (0.122): two libc++ are often installed side by side (/usr/lib/llvm-18 and llvm-21), and the system's `libc++.so' is one of them -- the headers of one and the runtime of the other do not agree (std::print, optional<T &>, __hash_memory)
    ->  ccl_cxxabi_lib(Lib, Abi), atomic_list_concat([' -L\'', Lib, '\' -Wl,-rpath,\'', Lib, '\' -lc++', Abi], Libs)
    ;   Libs = ' -lc++' ).
ccl_link_libs(' -lm') :- ccl_host_os(linux), !.   % THE MATH LIBRARY IS NAMED AT THE LINK ON LINUX (0.100): glibc keeps `sqrt', `creal' and `cabs' in libm, apart from libc (macOS has them in libSystem), and a C program that uses them is otherwise `undefined reference' -- the fixtures' clang builds pass `-lm' by hand
ccl_link_libs('').
%% LIBC++ABI IS NAMED WHERE THE TREE HAS ONE (0.181): libc++ 18's `libc++.so' is a linker script, `INPUT(libc++.so.1
%% -lc++abi -lunwind)', which names it, and libc++ 21's and 22's is the library itself: the link through g++ found the
%% program's `__cxa_throw', `__cxa_begin_catch', personality and type information in libstdc++, g++'s own runtime, while
%% libc++'s own code used libc++abi -- two runtimes in one process. Named after `-lc++', each is libc++abi's, as
%% clang++'s link has it, and over libc++ 18 the libraries and their bindings are the same as without.
ccl_cxxabi_lib(Lib, ' -lc++abi') :- atom_concat(Lib, '/libc++abi.so', A), exists_file(A), !.
ccl_cxxabi_lib(_, '').
ccl_sh(Cmd, Out, Exit) :- ( once(catch(proc_run(Cmd, 300000, Out, Exit), _, fail)) -> true ; Out = "could not run", Exit = 1 ).
ccl_words([], '').
ccl_words([W|Ws], A) :- ccl_words(Ws, A1), atomic_list_concat(['\'', W, '\' ', A1], A).
