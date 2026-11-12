/* <string_view.pl>'s header (0.295): <basic_string_view.pl>, the type macro of the view, and the names that C++'s
   <string_view> gives -- `string_view', the instance of char, and `npos', the place that no search finds, which
   <string.pl> gives too. A macro file's NAME.pl.h is included with it, so a program includes <string_view.pl> alone. */
#ifndef _CICILANG_CCLLIB_STRING_VIEW_PL_H
#define _CICILANG_CCLLIB_STRING_VIEW_PL_H
#include <basic_string_view.pl>
typedef basic_string_view<char> string_view;
#ifndef _CICILANG_CCLLIB_NPOS
#define _CICILANG_CCLLIB_NPOS
static const size_t npos = (size_t)-1;
#endif
#endif
