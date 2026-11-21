/* a guarded header whose guard redefok.c defines before its #include, so none of its lines is the file's (1.6.7) */
#ifndef REDEFOK_T_H
#define REDEFOK_T_H
static int thrice(int a) { return 3 * a; }
#endif
