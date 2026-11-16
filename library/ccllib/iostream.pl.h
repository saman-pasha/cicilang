/* C++'s <iostream> (phase 1d): the three streams and the manipulator `endl', over the macro files of the streams */
#ifndef _CICILANG_CCLLIB_IOSTREAM_PL_H
#define _CICILANG_CCLLIB_IOSTREAM_PL_H
#include <ostream.pl>
#include <istream.pl>
#include <fstream.pl>
#include <stringstream.pl>
static ostream<char> cout;
static istream<char> cin;
static cerrstream<> cerr;
static const char *endl = "\n";
static const char *ends = "";
#endif
