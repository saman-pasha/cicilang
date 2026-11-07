template <class T> int p(T) { return 1; }
template <> int p<int>(int) = delete;
int main() { return p(1); }
