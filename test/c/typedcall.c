/* A TYPED CALL BY NAME (0.305): `get<0>(t)' and `get<double>(t)' over an instance are its functions `<instance>_get_0'
   and `<instance>_get_double', dereferenced where the module names them a place; over a pointer to one, the pointer
   as it is; one in another; and a name that the program declares, `lo<0>(x)', is C's own relations. The reader
   gate's k167 reads it */
#include <tuple.pl>
#include <pair.pl>
int lo = 2;
int main(void) {
    tuple<int, double> t = {1, 2.5};
    tuple<int, double> *pt = &t;
    tuple<pair<int, int>, int> n = {{1, 2}, 3};
    int x = 1;
    get<0>(t) = 3;
    get<double>(t) += 1;
    get<1>(pt) = 0.5;
    get<1>(get<0>(n)) = 4;
    return lo<0>(x);
}
