/* phase 2: from_chars reads into a value with a place, and refuses an expression that has none */
#include <charconv.pl>
int main(void) {
    int n = 0;
    from_chars("1", "2", n + 1);
    return 0;
}
