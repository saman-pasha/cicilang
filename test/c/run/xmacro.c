/* AN #include INSIDE AN ITEM IS ITS FILE'S TEXT IN PLACE (0.310; C17 6.10.2/3): the finding of a program over a CSS table,
   whose enum of properties was made of an X-macro's rows (xmacro.h over xmacro_props.def) and lost them, so that its
   table of CSS_NPROPS rows was longer than CSS_NPROPS. The rows of an enum, of an initializer under a #define inside it,
   of a struct's fields and of a function's body come from an #include; a table of no bound takes the bound of the
   header's declaration; and a table whose rows have no braces of their own has the elements that clang gives it, at
   file scope and in a block. Built as C and as C++; the lines are clang's */
#include <stdio.h>
#include "xmacro.h"
const css_prop_def css_props[] = {
#define CSS_PROP(id, name, inherited) { name, CSS_##id, inherited },
#include "xmacro_props.def"
#undef CSS_PROP
};
struct point {
#include "xmacro_fields.inc"
};
typedef struct { const char *name; int id; } row;
static const row elided[] = { "color", 0, "margin", 1 };
static const int pairs[][2] = { 1, 2, 3, 4, 5, 6 };
static int total(void) {
    struct point p = { 3, 4 };
    int sum = 0;
#include "xmacro_body.inc"
    return sum;
}
int main(void) {
    int i, inherited = 0;
    row local[2] = { "font-size", 3, "padding", 2 };
    for (i = 0; i < CSS_NPROPS; i++) inherited += css_props[i].inherited;
    printf("%d properties, %d inherited, the last %s\n", (int)CSS_NPROPS, inherited, css_props[CSS_font_size].name);
    printf("%d rows in the table\n", (int)(sizeof css_props / sizeof css_props[0]));
    printf("a point of %d bytes, %d\n", (int)sizeof(struct point), total());
    printf("%d elided rows, the second %s; %d pairs, the last %d\n", (int)(sizeof elided / sizeof elided[0]), elided[1].name,
           (int)(sizeof pairs / sizeof pairs[0]), pairs[2][1]);
    printf("a local table: %s %d, %s %d\n", local[0].name, local[0].id, local[1].name, local[1].id);
    return 0;
}
