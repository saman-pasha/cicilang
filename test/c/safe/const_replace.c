/* AN OWN FIELD OF A CONST OBJECT IS NO MODIFIABLE LVALUE (0.265; C17 6.5.16/2): a callee whose pointee is const may not
   replace the field -- so the caller keeps its borrows across the call -- and the assignment is refused in clang's words */
#include <stdlib.h>
typedef struct { size_t len; own int *data; } buf;
void bad_set(const buf *b) { free(b->data); b->data = malloc(sizeof(int)); }
int main(void) { buf v = { 1, malloc(sizeof(int)) }; bad_set(&v); free(v.data); return 0; }
