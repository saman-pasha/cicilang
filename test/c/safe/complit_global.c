/* A COMPOUND LITERAL'S ADDRESS STORED IN A GLOBAL (1.6.31): the global outlives the block's object */
struct p { int x; };
static struct p *g;
static void put(void) { g = &(struct p){ 1 }; }
int main(void) { put(); return g->x - 1; }
