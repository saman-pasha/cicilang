/* a coroutine whose promise has no get_return_object: refused by that name (0.108), as clang refuses it -- the coroutines themselves run (test/cpp/run/co*.cpp) */
struct Task { struct promise_type { }; };
Task count() { co_return; }
int main() { return 0; }
