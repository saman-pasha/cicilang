struct R { int &r; };
int main() { int x = 1, y = 2; R a{x}, b{y}; a = b; return a.r; }
