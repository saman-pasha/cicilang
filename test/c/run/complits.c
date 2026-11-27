/* compound literals and the slots of global objects that the safe part keeps (1.6.31): a compound literal's address and
   an array's value used in their block, handed to a call, one a pass of a loop; a pointer read out of a global table, a
   global pointer and a global struct's member, read, returned and measured -- each a borrow that nothing frees --, a
   local of a global's name that frees its own memory, and a C library's extern object closed */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct p { int x, y; };
static const char *names[] = { "ab", "cde", "f" };
static const char *gp = "glob";
static struct { const char *name; int n; } cfg = { "cfg", 4 };
static int sum(const struct p *a) { return a->x + a->y; }
static int first(const int *a) { return a[0]; }
static const char *pick(int i) { return names[i % 3]; }
static const char *pickp(int i) { const char *s = names[i]; return s; }
static int shadow(void) { char *gp = malloc(4); if (!gp) return -1; gp[0] = 'x'; int k = gp[0]; free(gp); return k; }
static size_t lens(void) { size_t n = 0; for (int i = 0; i < 3; i++) { const char *s = names[i]; n += strlen(s); } return n; }
int main(void) {
    struct p *q = &(struct p){ 3, 4 };
    q->x += 10;
    int *a = (int[]){ 1, 2, 3 };
    a[1] = 20;
    char *c = &(char){ 'z' };
    const struct p *r = &(const struct p){ 5, 6 };
    int n = 0;
    for (int i = 0; i < 3; i++) { int *e = &(int){ i }; n += *e; }
    printf("%d %d %d %c %d %d %d %d\n", q->x, q->y, a[1], *c, r->y, n, sum(&(struct p){ 1, 2 }), first((int[]){ 9, 8 }));
    const char *g = gp;
    const char *m = cfg.name;
    printf("%s %s %s %s %zu %s %s %d %d\n", pick(4), pickp(2), g, m, lens(), names[0], gp, cfg.n, shadow());
    fflush(stdout);
    fclose(stdin);
    return 0;
}
