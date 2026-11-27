// a second delete of a plain pointer (1.6.32): its delete leaves it freed, and the second reads it -- it was built, and
// the run aborted in free
int main() { int *p = new int(1); delete p; delete p; return 0; }
