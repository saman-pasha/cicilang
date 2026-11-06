// A DELETED FUNCTION TEMPLATE OF THE IDIOM THAT REFUSES CONVERSIONS (0.257): it was no candidate, and h(1.5) called h(int)
template <class T> int h(T) = delete;
int h(int) { return 42; }
int main() { return h(1.5); }
