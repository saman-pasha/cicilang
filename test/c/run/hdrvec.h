/* a header of the program's own whose static inline functions take a vector<pt> member's [] and call its functions by
   name, beside the header's own macros and C17's bool (0.293; hdrvec.c) */
#ifndef HDRVEC_H
#define HDRVEC_H
#include <stdbool.h>
#include <vector.pl>
#define FIRST 0
#define TWICE(x) ((x) * 2)
typedef struct pt { int x, y; } pt;
typedef struct poly { vector<pt> pts; } poly;
static inline int first_x2(const poly *p) { return TWICE(p->pts[FIRST].x); }
static inline bool no_pts(const poly *p) { return size(p->pts) == 0; }
static inline void add_pt(poly *p, int x, int y) { pt a = {x, y}; push_back(p->pts, a); }
#endif
