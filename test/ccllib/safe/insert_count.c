/* A CALL'S COUNT OF ARGUMENTS (0.288): insert takes the vector, a place and a value. With the place left out the call
   was made with the two arguments that it had, with no message, and the function read its value from what a register
   held */
#include <vector.pl>
int main(void) {
    vector<int> v = [1, 2];
    insert(v, 7);
    return 0;
}
