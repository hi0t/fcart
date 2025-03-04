#include <errno.h>
#include <stm32f4xx_hal.h>
#include <sys/stat.h>
#include <sys/times.h>

char *__env[1] = { 0 };
char **environ = __env;

void initialise_monitor_handles()
{
}

int _getpid(void)
{
    return 1;
}

int _kill(int pid, int sig)
{
    UNUSED(pid);
    UNUSED(sig);
    errno = EINVAL;
    return -1;
}

void _exit(int status)
{
    _kill(status, -1);
    while (1) { }
}

__attribute__((weak)) int _read(int file, char *ptr, int len)
{
    UNUSED(file);
    UNUSED(ptr);
    UNUSED(len);
    return -1;
}

__attribute__((weak)) int _write(int file, char *ptr, int len)
{
    UNUSED(file);
    UNUSED(ptr);
    UNUSED(len);
    return -1;
}

int _close(int file)
{
    UNUSED(file);
    return -1;
}

int _fstat(int file, struct stat *st)
{
    UNUSED(file);
    st->st_mode = S_IFCHR;
    return 0;
}

int _isatty(int file)
{
    UNUSED(file);
    return 1;
}

int _lseek(int file, int ptr, int dir)
{
    UNUSED(file);
    UNUSED(ptr);
    UNUSED(dir);
    return 0;
}

int _open(char *path, int flags, ...)
{
    UNUSED(path);
    UNUSED(flags);
    return -1;
}

int _wait(int *status)
{
    UNUSED(status);
    errno = ECHILD;
    return -1;
}

int _unlink(char *name)
{
    UNUSED(name);
    errno = ENOENT;
    return -1;
}

int _times(struct tms *buf)
{
    UNUSED(buf);
    return -1;
}

int _stat(char *file, struct stat *st)
{
    UNUSED(file);
    st->st_mode = S_IFCHR;
    return 0;
}

int _link(char *old, char *new)
{
    UNUSED(old);
    UNUSED(new);
    errno = EMLINK;
    return -1;
}

int _fork()
{
    errno = EAGAIN;
    return -1;
}

int _execve(char *name, char **argv, char **env)
{
    UNUSED(name);
    UNUSED(argv);
    UNUSED(env);
    errno = ENOMEM;
    return -1;
}
