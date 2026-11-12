/* a function after a typedef of its name (0.298): refused at its line */
typedef int t;
int t(void) { return 1; }
int main(void) { return t(); }
