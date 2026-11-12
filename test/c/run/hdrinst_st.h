/* a struct over a type macro's instance and the prototypes of functions that its includer defines (0.298; hdrinst.c) */
typedef struct st { vector<int> v; int n; } st;
int count(const st *s);
int twice(int x);
