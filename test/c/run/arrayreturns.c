/* arrayreturns.c -- arrays that a return may hand out (1.6.35), built as C and as C++: a static local's array and a
   static local record's array member, which live for the whole run, a parameter declared as an array, which is a
   pointer (C17 6.7.6.3/7), and a global's array; a local's array returned is refused (test/c/safe/local_array_out.c) */
#include <stdio.h>
struct named { char name[8]; int n; };
static char gbuf[8] = "g";
static const char *stat_array(void) { static char buf[8] = "s"; return buf; }
static const char *stat_member(void) { static struct named h = { "m", 1 }; return h.name; }
static const char *param_array(char a[8]) { return a; }
static const char *glob_array(void) { return gbuf; }
int main(void) {
    char x[8] = "p";
    printf("%s %s %s %s\n", stat_array(), stat_member(), param_array(x), glob_array());
    return 0;
}
