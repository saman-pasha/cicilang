/* AN OWN FIELD OF A CONST OBJECT IS NO MODIFIABLE LVALUE (0.265; C17 6.5.16/2): a const local's field assigned */
#include <stdlib.h>
typedef struct { size_t len; own int *data; } buf;
int main(void) { const buf v = { 1, malloc(sizeof(int)) }; free(v.data); v.data = malloc(sizeof(int)); free(v.data); return 0; }
