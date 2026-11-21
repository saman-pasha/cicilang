/* AN `extern' OBJECT WITH AN INITIALIZER IS ITS DEFINITION (1.6.7; C17 6.9.2/1), so a second initializer is a second
   definition: refused at its line */
extern int w = 4;
int w = 5;
int main(void) { return w; }
