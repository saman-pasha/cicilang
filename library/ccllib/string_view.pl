%% ccllib's <string_view.pl> (0.295; CCLLIB.md's phase 1a): std::string_view for cicilang's C, and for cicilang++ beside
%% libc++'s. Its header, string_view.pl.h, includes <basic_string_view.pl>, names the instance of char `string_view'
%% and gives `npos', as <string.pl> does for a string: a macro file's own header takes no instance of a type macro that
%% the same file defines, and the type macro stands in a file of its own
:- ensure_loaded(library(ccllib/ccllib)).
