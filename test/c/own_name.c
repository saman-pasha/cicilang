/* `own' USED AS A NAME (0.290): the reader check k162 -- `const v *own' is an own pointer with no name, and `own->a'
   is refused where it stands; the first error was `a borrow consumed' at the call in main */
typedef struct v { int a; } v;
static int get(const v *own) {
    return own->a;
}
int main(void) {
    v x = { 3 };
    return get(&x) - 3;
}
