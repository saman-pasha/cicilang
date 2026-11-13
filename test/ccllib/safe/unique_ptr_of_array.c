/* <memory.pl>: a unique_ptr's object is no array: C++'s unique_ptr<T[]> waits, since a type of no bound has no word
   (0.309) */
#include <memory.pl>
int main(void) {
    unique_ptr<int[3]> p;
    return 0;
}
