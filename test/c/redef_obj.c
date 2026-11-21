/* AN OBJECT WITH TWO INITIALIZERS AT FILE SCOPE (1.6.7; C17 6.9.2/1): refused at the second one's line, where the
   program printed the first one's value */
int x = 1;
int x = 2;
int main(void) { return x; }
