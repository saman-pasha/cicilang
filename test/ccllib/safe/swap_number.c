/* A CALL'S ARGUMENT OF ANOTHER TYPE (0.288): swap takes two vectors of one type. A number where the second goes was
   made a pointer with no message, and the function read the bytes at that address as a vector's */
#include <vector.pl>
int main(void) {
    vector<int> v = [1, 2];
    swap(v, 5);
    return 0;
}
