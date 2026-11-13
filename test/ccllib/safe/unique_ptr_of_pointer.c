/* <memory.pl>: a unique_ptr's object is a value with no pointer in it, as a container's element is (decision 2)
   (0.309) */
#include <memory.pl>
int main(void) {
    unique_ptr<char *> p;
    return 0;
}
