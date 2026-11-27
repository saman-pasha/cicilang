/* A COMPOUND LITERAL OF A LOOP'S PASS, READ AFTER THE LOOP (1.6.37): each pass's literal ends with its pass -- built */
int main(void) { int *p = 0; for (int i = 0; i < 2; i++) { p = &(int){ i }; } return p ? *p : 0; }
