/* a header with no #include, whose function takes the member's [] over the struct that the headers before it declare,
   as C reads an #include: its text in the includer's place (0.293; hdrvec.c) */
static inline int sum_x(const poly *p) { int s = 0; for (size_t i = 0; i < size(p->pts); i++) s += p->pts[i].x; return s; }
