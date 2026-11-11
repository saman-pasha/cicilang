/* <string.pl>'s header (0.291): <basic_string.pl>, the type macro of the string, and the names that C++'s <string>
   gives -- `string', the instance of char, and `npos', the place that no search finds. A macro file's NAME.pl.h is
   included with it, so a program includes <string.pl> alone. */
#ifndef _CICILANG_CCLLIB_STRING_PL_H
#define _CICILANG_CCLLIB_STRING_PL_H
#include <basic_string.pl>
typedef basic_string<char> string;
static const size_t npos = (size_t)-1;
#endif
