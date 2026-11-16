%% ccllib's <iostream.pl> (phase 1d): std::cout, std::cin and std::cerr over C's stdio. Its header includes the
%% streams' macro files and declares the three objects:
%%
%%   #include <iostream.pl>
%%   cout << "hello";  cout << endl;  cout << 42;
%%   int x;  cin >> x;
%%   cerr << "e";
%%
%% `endl' is the header's macro, `"\n"'. `cerr' is an instance of `cerrstream<>', whose file is stderr; `cout' writes
%% to stdout and `cin' reads stdin until a file is given them. What differs from C++ is CCLLIB.md's section of the
%% iostreams.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/ostream)).
:- ensure_loaded(library(ccllib/istream)).
:- ensure_loaded(library(ccllib/fstream)).
:- ensure_loaded(library(ccllib/stringstream)).
