template <class T> void h(T *) = delete;
void h(int *) {}
int main() { double d = 1; h(&d); }
