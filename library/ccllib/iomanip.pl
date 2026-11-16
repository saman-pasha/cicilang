%% ccllib's <iomanip.pl> (phase 1d): C++'s manipulators as functions of the stream. C++ writes `cout << setw(6) << x';
%% C has no `<<' that takes a manipulator, so the stream is the first argument:
%%
%%   #include <iomanip.pl>
%%   setw(cout, 6);  setfill(cout, '0');  setprecision(cout, 3);  fixed(cout);
%%   hex(cout);  dec(cout);  oct(cout);  boolalpha(cout);  noboolalpha(cout);
%%
%% Each is a function of the instance, made at its first call, and changes the stream that the others read: the width
%% and the fill of the next value, the base of an integer, the format and the precision of a floating number, and
%% whether a bool is written `true' or `1'.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/iostream)).
