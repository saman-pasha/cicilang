/* the header of xmacro.c (0.310): an X-macro's enum, made of the rows of xmacro_props.def, and the table's declaration
   with its bound */
#ifndef XMACRO_H
#define XMACRO_H
typedef enum {
#define CSS_PROP(id, name, inherited) CSS_##id,
#include "xmacro_props.def"
#undef CSS_PROP
    CSS_NPROPS
} css_prop_id;
typedef struct { const char *name; css_prop_id id; int inherited; } css_prop_def;
extern const css_prop_def css_props[CSS_NPROPS];
#endif
