/* a function after an extern object of its name (0.298): refused at its line */
extern int t;
int t(void) { return 4; }
int main(void) { return t(); }
