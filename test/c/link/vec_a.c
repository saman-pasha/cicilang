/* two units over <vector.pl> (0.274): each makes the functions of vector<int> that it calls -- this one push_back, at
   and size, vec_b.c push_back, back and insert -- and the link keeps one of what both made (linkonce_odr) */
#include <stdio.h>
#include <vector.pl>
int more(vector<int> *v, int n);
int main(void) {
    vector<int> v;
    push_back(v, 7);
    int s = more(&v, 4);
    printf("%zu %d %d %d\n", size(v), at(v, 0), at(v, 1), s);
    return 0;
}
