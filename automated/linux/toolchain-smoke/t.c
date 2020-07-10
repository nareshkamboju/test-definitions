#define _GNU_SOURCE
#include <unistd.h>

static char one_kb[1024] = {
	[0 ... 1022] = 'a',
	0
};

/*
 * Each string is 1kB, so we would need 2048 strings to fill a 2MB stack.
 *
 * But we have the string pointers themselves: 4 bytes per string, so
 * that would be an additional 8kB on top of the 2MB of strings. Plus
 * we have the two NULL terminators (8 bytes) for argv/envp.
 *
 * And then we have the ELF AUX fields, which is a few hundred bytes too.
 *
 * And then we need the call stack frame etc, and only need to come within
 * 4kB of the 2MB stack target.
 *
 * So instead of using 2048 strings to fill up 2MB exactly, we want to fill up
 * basically 2MB-12kB, and let the AUX info etc go into the last page.
 *
 * So 2036 1kB strings, plus noise.
 */

static char *argv[] = {
	[0] = "/bin/echo",
	[1 ... 2036] = one_kb,
	NULL
};

static char *envp[] = {
	NULL
};

int main(int argc, char **envp)
{
	/*
	 * Don't do this recursively, and sleep so people can look at /proc/<pid>/maps
	 */
	if (argc > 1000) {
		sleep(100);
		return 0;
	}
	return execvpe("./a.out", argv, envp);
}
