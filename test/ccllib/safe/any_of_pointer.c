/* <any.pl>: an any holds a value with no pointer in it; a pointer is refused where the value is made (1.1.5) */
#include <any.pl>
int main(void) {
    int n = 1;
    int *p = &n;
    any<> a = p;
    return (int)any_cast<int>(a);
}
