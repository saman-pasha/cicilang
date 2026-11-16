%% ccllib's <fstream.pl> (phase 1d): std::fstream over C's stdio. One instance reads and writes: open(f, path, mode)
%% takes C's modes, "r", "w", "a", "r+", as fopen does.
%%
%%   #include <fstream.pl>
%%   fstream<char> f;
%%   open(f, "data.txt", "w");  f << "x";  f << endl;  close(f);
%%   open(f, "data.txt", "r");  f >> n;  getline(f, buf, 64);  close(f);
%%
%% A local fstream is dropped where its scope ends, and its drop closes the file. `ofstream' and `ifstream' are names
%% of the same type by the header's macros, so a program may write either; there is no separate mode of the stream.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/iostream_impl)).
type_fstream([T], base([], [typedef(N)]), Items) :-
    ( ccl_arg_words([T], [char]) -> true ; ccl_macro_error('a fstream''s element is char: the other character types wait') ),
    ccl_instance_name(fstream, [T], N), ccllib_stream_type(N, Items).
fn_fstream(Name, [T], Items) :- ccl_instance_name(fstream, [T], N), D = expr(call(id(ccllib_stdout), [])),
    (   ccllib_stream_common_fn(Name, D, Text)
    ;   ccllib_stream_out_fn(Name, D, Text)
    ;   ccllib_stream_in_fn(Name, D, Text)
    ;   ccllib_stream_file_fn(Name, Text) ),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T), 'D' = D], Items).
