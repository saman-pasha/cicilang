/* A CALL'S ARGUMENT OF ANOTHER TYPE (0.288): swap takes two vectors of one type, and a vector of another element is
   refused by name at the call */
#include <vector.pl>
int main(void) {
    vector<int> v = [1, 2];
    vector<double> w = [1.5];
    swap(v, w);
    return 0;
}
