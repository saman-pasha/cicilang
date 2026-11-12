/* an #error of the program's own header under a condition (0.298; pperr_own.c, pperr_own_ok.c) */
#ifndef PPERR_OWN_H
#define PPERR_OWN_H
#ifndef CFG
#error "CFG is needed"
#endif
int pperr_own(void);
#endif
