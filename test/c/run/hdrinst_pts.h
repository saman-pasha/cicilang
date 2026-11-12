/* a guarded header whose struct makes the first instance of vector<double>, and a macro of its own over it (0.298;
   hdrinst.c) */
#ifndef HDRINST_PTS_H
#define HDRINST_PTS_H
#define FIRST(p) at((p)->xs, 0)
typedef struct pts { vector<double> xs; } pts;
#endif
