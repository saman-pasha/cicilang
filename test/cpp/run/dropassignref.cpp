// AN ASSIGNMENT OVER AN OBJECT THAT ITS SCOPE DROPS IS A PLACE IN C++ (1.6.13): `track<int> &r = (a = make(...));' drops
// a's old value, stores the new one, and binds r to a -- dropassign.c's assignment, as a place. track<T>'s drop prints
// the name that it frees, so each drop shows where the old value went
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "../../c/run/autodrop.pl"
static track<int> make(const char *tag, int n) { std::printf("make %s\n", tag); track<int> t = tracked<int>(tag, n); return t; }
int main() {
    track<int> a = tracked<int>("a.1", 1);
    track<int> &r = (a = make("a.2", 2));
    std::printf("r %s %d\n", r.tag, r.val);
    r.val = 7;
    std::printf("a %s %d\n", a.tag, a.val);
    return 0;
}
