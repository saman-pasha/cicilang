/* <functional.pl>: hash refuses a struct by name; a struct hashes by the program's own function (1.1.4) */
#include <functional.pl>
typedef struct point { int x; } point;
int main(void) {
    point p = {1};
    return (int)hash(p);
}
