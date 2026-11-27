/* AN ARRAY COMPOUND LITERAL GIVEN TO AN OWNER (1.6.31): its value, the first element's address, is a borrow of the
   block's object, which no owner takes -- it was built, and the run aborted in free */
#include <stdlib.h>
int main(void) { own int *o = (int[]){ 1, 2 }; free(o); return 0; }
