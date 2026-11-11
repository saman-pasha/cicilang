/* A CALL'S COUNT OF ARGUMENTS (0.288): push_back takes the vector and a value; a call with a value too many was made
   with no message */
#include <vector.pl>
int main(void) {
    vector<int> v = [1, 2];
    push_back(v, 7, 8);
    return 0;
}
