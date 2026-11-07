struct C { const int c; };
int main() { C p{1}, q{2}; p = q; return p.c; }
