/* a private constructor chosen for a local outside the class and its friends is refused by name (0.117) */
class Single { Single() {} public: static Single &get() { static Single s; return s; } };
int main() { Single s; return 0; }
