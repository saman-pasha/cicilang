/* refused: what stands after a priority_queue's element type is the NAME of the function that compares two elements,
   where C++ writes the container's type and the comparison's (0.280) */
#include <queue.pl>
int main(void) {
    priority_queue<int, 3> h;
    push(h, 1);
    return 0;
}
