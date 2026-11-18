%% ccllib's <mutex.pl> (phase 2, 1.6.0): C++'s std::mutex, std::lock_guard and std::unique_lock over POSIX's pthread
%% mutex, and std::barrier and std::latch over a mutex with a count.
%%
%%   #include <mutex.pl>
%%   mutex<> m;                          a type macro with no type argument takes an empty `<>', as `any<>' does
%%   lock(m);  try_lock(m);  unlock(m);
%%   lock_guard<mutex<> > g = &m;        born from the mutex's address, unlocked where g's scope ends
%%   unique_lock<mutex<> > u;            lock(u), try_lock(u), unlock(u), owns_lock(u), release(u);
%%   unique_lock<mutex<> > u = &m;         born locked; its scope ends with m unlocked if it held it
%%   barrier<int> b(n);  arrive(b);  arrive_and_wait(b);    `barrier<T>' takes the completion object's type
%%   latch<> l = n;  count_down(&l, k);  wait(&l);  try_wait(&l);  latch_value(&l);
%%
%% A no-argument type macro is written with `<>', never bare: the reader makes an instance only at the
%% `name<...>' form (0.261). A latch's functions take its address, `wait(&l)'.
%%
%% What differs from C++:
%%   the free `lock(m)' and a guard's birth take a POINTER (`lock_guard<mutex<> > g = &m'), since C has no
%%     reference parameter;
%%   a guard keeps its mutex's address as an integer and casts it back, because the safe part follows no
%%     borrow kept in a struct's field;
%%   a guard's own lock of another guard, and unique_lock's `try_lock_for', are not written here;
%%   a barrier or a latch is one process's threads (pthread); `arrive_and_drop' and a barrier's completion
%%     function are not written; a barrier's completion object is a zero, dropped with the barrier;
%%   the timeouts of C++20's mutexes (`try_lock_for') have no form: a pthread's mutex takes none.
:- ensure_loaded(library(ccllib/ccllib)).

%% -- std::mutex: no template argument; the instance `mutex<>' is a struct of the pthread mutex and a flag, born
%% zero: its first lock, try_lock or unlock initializes the pthread mutex (Darwin's PTHREAD_MUTEX_INITIALIZER is no
%% zero), and the scope's drop destroys it. A type's drop stands in its own C text, where the reader that declares an
%% object of the type finds it (a function made at its first call is too late for the scope's defer)
type_mutex([], base([], [typedef(N)]), Items) :- ccl_instance_name(mutex, [], N),
    ccl_c_items("typedef struct @N { pthread_mutex_t m_; int ready; } @N;
void @{N}_ensure(@N *x) { if (!x->ready) { pthread_mutex_init(&x->m_, 0); x->ready = 1; } }
void @{N}_lock(@N *x) { @{N}_ensure(x); pthread_mutex_lock(&x->m_); }
int @{N}_try_lock(@N *x) { @{N}_ensure(x); return pthread_mutex_trylock(&x->m_) == 0; }
void @{N}_unlock(@N *x) { @{N}_ensure(x); pthread_mutex_unlock(&x->m_); }
void @{N}_drop(@N *x) { if (x->ready) { x->ready = 0; pthread_mutex_destroy(&x->m_); } }",
      ['N' = name(N)], Items).

%% -- std::lock_guard<M>: locks a mutex's address at its birth, and unlocks it where the place's scope ends. The mutex's
%% address is kept as an integer and cast back, because the safe part follows no borrow kept in a struct's field
type_lock_guard([M], base([], [typedef(N)]), Items) :-
    ccl_instance_name(lock_guard, [M], N),
    ccllib_mutex_instance('a lock_guard''s mutex', M, W),
    ccl_c_items("typedef struct @N { unsigned long m; } @N;
@N @{N}_of(@{W} *m) { @N g; g.m = (unsigned long)m; @{W}_lock(m); return g; }
void @{N}_drop(@N *g) { @{W}_unlock((@{W} *)g->m); }", ['N' = name(N), 'W' = name(W)], Items).

%% -- std::unique_lock<M>: a guard whose lock it keeps -- lock(u), try_lock(u), unlock(u), owns_lock(u), release(u);
%% its place drops it, and the mutex with it where it holds it
type_unique_lock([M], base([], [typedef(N)]), Items) :-
    ccl_instance_name(unique_lock, [M], N),
    ccllib_mutex_instance('a unique_lock''s mutex', M, W),
    ccl_c_items("typedef struct @N { unsigned long m; int held; } @N;
@N @{N}_of(@{W} *m) { @N u; u.m = (unsigned long)m; u.held = 1; @{W}_lock(m); return u; }
void @{N}_lock(@N *u) { if (!u->held) { @{W}_lock((@{W} *)u->m); u->held = 1; } }
int @{N}_try_lock(@N *u) { if (u->held) return 0; u->held = @{W}_try_lock((@{W} *)u->m); return u->held; }
void @{N}_unlock(@N *u) { if (u->held) { u->held = 0; @{W}_unlock((@{W} *)u->m); } }
int @{N}_owns_lock(const @N *u) { return u->held; }
void @{N}_release(@N *u) { u->held = 0; }
void @{N}_drop(@N *u) { if (u->held) { u->held = 0; @{W}_unlock((@{W} *)u->m); } }", ['N' = name(N), 'W' = name(W)], Items).

%% -- std::barrier<T>: n threads arrive, and the nth lets all of them past; T is the completion object, a zero, dropped
%% with the barrier
type_barrier([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(barrier, [T], N),
    ccllib_plain_element('a barrier''s completion''s value', T),
    ccl_c_items("typedef struct @N { pthread_mutex_t mu; pthread_cond_t cv; int n; int waiting; int gen; @T t; } @N;
@N @{N}_of(int n) { @N b; pthread_mutex_init(&b.mu, 0); pthread_cond_init(&b.cv, 0); b.n = n; b.waiting = 0; b.gen = 0; memset(&b.t, 0, sizeof b.t); return b; }
int @{N}_arrive(@N *b) { pthread_mutex_lock(&b->mu); int last = ++b->waiting >= b->n; if (last) { b->waiting = 0; b->gen++; pthread_cond_broadcast(&b->cv); } pthread_mutex_unlock(&b->mu); return last; }
void @{N}_arrive_and_wait(@N *b) { pthread_mutex_lock(&b->mu); int g = b->gen; if (++b->waiting >= b->n) { b->waiting = 0; b->gen++; pthread_cond_broadcast(&b->cv); } else { while (b->gen == g) pthread_cond_wait(&b->cv, &b->mu); } pthread_mutex_unlock(&b->mu); }
void @{N}_drop(@N *b) { pthread_mutex_destroy(&b->mu); pthread_cond_destroy(&b->cv); }", ['N' = name(N), 'T' = type(T)], Items).

%% -- std::latch: a count that threads bring down, and wait at zero; `latch<>' has no type argument
type_latch([], base([], [typedef(N)]), Items) :- ccl_instance_name(latch, [], N),
    ccl_c_items("typedef struct @N { pthread_mutex_t mu; pthread_cond_t cv; long count; } @N;
@N @{N}_of(long n) { @N l; pthread_mutex_init(&l.mu, 0); pthread_cond_init(&l.cv, 0); l.count = n; return l; }
void @{N}_count_down(@N *l, long n) { pthread_mutex_lock(&l->mu); l->count -= n; if (l->count <= 0) pthread_cond_broadcast(&l->cv); pthread_mutex_unlock(&l->mu); }
void @{N}_wait(@N *l) { pthread_mutex_lock(&l->mu); while (l->count > 0) pthread_cond_wait(&l->cv, &l->mu); pthread_mutex_unlock(&l->mu); }
int @{N}_try_wait(@N *l) { pthread_mutex_lock(&l->mu); int z = l->count <= 0; pthread_mutex_unlock(&l->mu); return z; }
void @{N}_arrive_and_wait(@N *l, long n) { @{N}_count_down(l, n); @{N}_wait(l); }
long @{N}_value(@N *l) { pthread_mutex_lock(&l->mu); long c = l->count; pthread_mutex_unlock(&l->mu); return c; }
void @{N}_drop(@N *l) { pthread_mutex_destroy(&l->mu); pthread_cond_destroy(&l->cv); }", ['N' = name(N)], Items).

%% the mutex a guard or a lock guards: the type `mutex', or an instance of a class that holds one
ccllib_mutex_instance(_What, T, W) :-
    catch(ccl_type_word(T, W), _, fail), memberchk(W, [mutex, ccllib_mutex]), !.
ccllib_mutex_instance(What, T, _) :-
    ccl_arg_words([T], [W]), atomic_list_concat([What, ' is `mutex'', and ', W, ' is none'], M), ccl_macro_error(M).
