/* A COMPOUND LITERAL OF A BLOCK, READ AFTER THE BLOCK (1.6.37; C17 6.5.2.5/5: its storage is the block's): the pointer
   dangles at the block's end -- it was built, and the read is of a dead object */
int main(void) { int *p; { p = &(int){ 1 }; } return *p; }
