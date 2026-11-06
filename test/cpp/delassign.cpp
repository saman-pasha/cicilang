// A DELETED COPY ASSIGNMENT (0.257): a = b assigned as C's struct does
struct S { S &operator=(const S &) = delete; };
int main() { S a, b; a = b; return 0; }
