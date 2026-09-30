// a module with one exported function and one it keeps (0.110): modhidden.cpp names the kept one
export module hidem;
int hidden(int x) { return x + 1; }
export int shown(int x) { return hidden(x) * 2; }
