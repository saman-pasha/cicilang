/* A BLOCK'S POINTER TO ITS COMPOUND LITERAL, COPIED OUT OF THE BLOCK AND READ AFTER IT (1.6.37): built */
int main(void) { int *p; { int *q = &(int){ 1 }; p = q; } return *p; }
