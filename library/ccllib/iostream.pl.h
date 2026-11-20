/* C++'s <iostream> (phase 1d): the three streams, over the macro files of the streams, whose headers give endl and
   ends (1.6.3) */
#ifndef _CICILANG_CCLLIB_IOSTREAM_PL_H
#define _CICILANG_CCLLIB_IOSTREAM_PL_H
#include <ostream.pl>
#include <istream.pl>
#include <fstream.pl>
#include <stringstream.pl>
static ostream<char> cout;
static istream<char> cin;
static cerrstream<> cerr;
#endif
