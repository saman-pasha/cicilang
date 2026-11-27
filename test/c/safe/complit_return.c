/* A COMPOUND LITERAL'S ADDRESS RETURNED (1.6.31): the object ends with the block, and clang warns
   `address of stack memory associated with compound literal returned' -- it was built, and the caller read a dead frame */
struct p { int x; };
static struct p *mk(void) { return &(struct p){ 1 }; }
int main(void) { return mk()->x - 1; }
