/* AN ENUM DEFINED AGAIN AT C23 WITH OTHER VALUES (1.6.7; C23 6.7.2.3/1): refused at the second one's line */
enum e { A = 1 };
enum e { A = 2 };
int main(void) { return A; }
