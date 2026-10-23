// A static assertion of the program is checked where its condition folds (0.198): one that holds passes, and a false one is
// an error, as clang++ says it (`static assertion failed due to requirement 'sizeof(int) == 8': wrong size')
template <class T> struct Box { T v; };
static_assert(sizeof(Box<int>) == 4, "box size");
static_assert(sizeof(int) == 8, "wrong size");
int main() { return 0; }
