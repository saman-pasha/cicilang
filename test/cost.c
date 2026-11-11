/* test/cost.c -- what a command costs (0.273): `cost FILE CMD ARG...' runs the command, its input and output the
   caller's, and writes one line to FILE: the seconds of the wall clock that it took, and the kilobytes of the largest
   resident size among its processes -- wait4's ru_maxrss, the command's own and that of each child it waited for.
   Its exit status is the command's; 128 and the signal's number for one that a signal ended. The ccllib gate builds
   it with cc and measures the three runs with it: a measure must not be made by what it measures. */
#include <stdio.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
int main(int argc, char **argv) {
    struct timespec t0, t1;
    struct rusage ru;
    int st = 0;
    if (argc < 3) { fprintf(stderr, "usage: cost FILE CMD ARG...\n"); return 2; }
    clock_gettime(CLOCK_MONOTONIC, &t0);
    pid_t p = fork();
    if (p < 0) { perror("cost: fork"); return 2; }
    if (p == 0) { execvp(argv[2], argv + 2); perror(argv[2]); _exit(127); }
    if (wait4(p, &st, 0, &ru) < 0) { perror("cost: wait4"); return 2; }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    long kb = ru.ru_maxrss;
#ifdef __APPLE__
    kb /= 1024;                                         /* bytes there, kilobytes on Linux */
#endif
    FILE *f = fopen(argv[1], "w");
    if (!f) { perror(argv[1]); return 2; }
    fprintf(f, "%.3f %ld\n", (double)(t1.tv_sec - t0.tv_sec) + (double)(t1.tv_nsec - t0.tv_nsec) / 1e9, kb);
    fclose(f);
    return WIFEXITED(st) ? WEXITSTATUS(st) : 128 + WTERMSIG(st);
}
