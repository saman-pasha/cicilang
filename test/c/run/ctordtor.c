/* GCC's `constructor' AND `destructor' ATTRIBUTES (1.6.8): a constructor runs before main, a destructor after main's
   return and after the atexit handlers, the constructors by their priorities from the lowest, the destructors from
   the highest, a priority's absence the highest of all (65535); the attribute on a prototype is its definition's, in
   both spellings, on a function that is not static, and both on one function */
#include <stdio.h>
#include <stdlib.h>
static int counter;
__attribute__((constructor(103))) static void c103(void) { printf("c103 %d\n", counter++); }
__attribute__((constructor(101))) static void c101(void) { printf("c101 %d\n", counter++); }
__attribute__((constructor)) static void cnone(void) { printf("c-none %d\n", counter++); }
__attribute__((__constructor__(102))) static void c102(void) { printf("c102 %d\n", counter++); }
__attribute__((destructor(101))) static void d101(void) { printf("d101 %d\n", counter); }
__attribute__((destructor(102))) static void d102(void) { printf("d102 %d\n", counter); }
__attribute__((__destructor__)) static void dnone(void) { printf("d-none %d\n", counter); }
static void proto_ctor(void) __attribute__((constructor));
void proto_dtor(void) __attribute__((destructor));
static void proto_ctor(void) { printf("proto ctor\n"); }
void proto_dtor(void) { printf("proto dtor\n"); }
__attribute__((constructor, destructor)) static void both(void) { printf("both %d\n", counter); }
static void at(void) { printf("atexit\n"); }
int main(void) { atexit(at); printf("main %d\n", counter); return 0; }
