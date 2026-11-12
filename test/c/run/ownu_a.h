/* the file's CAP and BIG undefined by the program's own header; BIG a function from here (ownundef.c) */
#ifndef OWNU_A_H
#define OWNU_A_H
#undef CAP
#undef BIG
static int BIG(int a, int b) { return a > b ? a * 10 : b * 10; }
#endif
