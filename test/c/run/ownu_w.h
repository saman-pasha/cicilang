/* the file's WIDE defined again where the file defined it, and its NARROW undefined; #pragma once (ownundef.c) */
#pragma once
#ifdef WIDE
#undef WIDE
#define WIDE 2
#endif
#include "ownu_in.h"
