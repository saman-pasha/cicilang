/* <any.pl>: an any holds a value with no pointer in it; an array is refused where the value is made (1.1.5) */
#include <any.pl>
int main(void) {
    int a[2] = {1, 2};
    any<> x = a;
    return (int)any_cast<int>(x);
}
