/* A RAW READ THAT IS WHOLE, WITH A HEADER INSIDE IT THAT WAS NOT READ WHOLE, GOES ON TO THE PREPROCESSED READ (0.290):
   glibc's <getopt.h> is directives alone, and each of the two headers that it includes was read apart, with no macro
   of its includer's, and stopped at its first declaration: `struct option' and getopt_long were unknown, with no
   message. And <limits.h> held <sys/cdefs.h>, whose raw read threw at a static assertion of a branch that no build
   takes: a raw read that throws goes on to the preprocessed read too */
#include <stdio.h>
#include <limits.h>
#include <getopt.h>
int main(void) {
    static struct option opts[] = { { "name", required_argument, 0, 'n' }, { "all", no_argument, 0, 'a' },
                                    { 0, 0, 0, 0 } };
    char a0[] = "prog", a1[] = "--name=abc", a2[] = "-a", a3[] = "rest";
    char *argv[] = { a0, a1, a2, a3, 0 };
    int c, all = 0;
    while ((c = getopt_long(4, argv, "an:", opts, 0)) != -1) {
        if (c == 'n') printf("name=%s\n", optarg);
        if (c == 'a') all = 1;
    }
    printf("all=%d rest=%s %d\n", all, argv[optind], INT_MAX > 0);
    return 0;
}
