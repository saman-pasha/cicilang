/* a destructor runs at exit() too, after the atexit handlers (1.6.8) */
#include <stdio.h>
#include <stdlib.h>
__attribute__((destructor)) static void fini(void) { printf("fini\n"); }
static void at(void) { printf("atexit\n"); }
int main(void) { atexit(at); printf("main\n"); exit(3); }
