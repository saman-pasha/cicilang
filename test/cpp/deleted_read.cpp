// a read through a plain pointer after its delete (1.6.32) -- it was built, a read of memory given back
int main() { int *p = new int(4); delete p; return *p; }
