/* a header that includes the header of the struct, and takes its member's [] and its fields (0.293; hdrvec.c) */
#ifndef HDRVEC2_H
#define HDRVEC2_H
#include "hdrvec.h"
static inline int last_y(const poly *p) { return p->pts[size(p->pts) - 1].y; }
static inline int count_of(const poly *p) { return (int)p->pts.len; }
#endif
