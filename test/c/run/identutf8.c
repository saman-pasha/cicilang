/* Identifiers past ASCII (C23 6.4.2.1; clang reads them in C17 too): UTF-8 in the source and universal character names,
   `café' the identifier `café'; a global's and a function's symbol their UTF-8 bytes; a struct's tag and members,
   locals, parameters (a struct's pieces among them), a label, an enumerator, a macro, `__func__' (0.196) */
#include <stdio.h>
#include <string.h>
#define DOUBLÉ(x) ((x) * 2)
static int café = 3;
int compteur = 0;
int naïve(int x) { compteur++; return x * café; }
struct Größe { int größe; double π; };
enum Farbe { ROT = 1, GRÜN, BLAU };
const char *nom(void) { return __func__; }
static int doppelt(int größe) { if (größe < 0) goto zurück; return größe * 2; zurück: return 0; }
static double fläche(struct Größe grö, int ñ) { return grö.größe * grö.π + ñ; }
const char *été(void) { return __func__; }
int main(void) {
    struct Größe g = { 7, 3.25 };
    int λ = 5, λ2 = 6, Δx = 10;
    printf("%d %d %.2f %d %d %d\n", naïve(2), g.größe, g.π, λ, λ2 + Δx, DOUBLÉ(GRÜN));
    printf("%s %s %zu %d\n", nom(), été(), strlen(été()), compteur);
    struct Größe *p = &g; p->größe += ROT + BLAU;
    printf("%d %d\n", p->größe, (int) sizeof(struct Größe));
    printf("%d %d %d\n", caf\u00e9, na\u00efve(1), \u03bb + \U000003BB2);
    printf("%d %d %.2f\n", doppelt(4), doppelt(-1), fläche(g, 1));
    return 0;
}
