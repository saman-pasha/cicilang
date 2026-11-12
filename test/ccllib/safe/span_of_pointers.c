/* <span.pl>: a span's element is a value with no pointer in it, as a vector's is (0.295) */
#include <span.pl>
int main(int argc, char **argv) {
    span<char *> s = {argv, (size_t)argc};
    return (int)size(s);
}
