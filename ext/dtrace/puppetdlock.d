#! /usr/bin/env dtrace -s
/*
 * This script uses dtrace (tested on Mac OS X) to record concurrent access to
 * the configuration run lock file.  This script is an effort to diagnose #2888
 * Dtrace provides the capability of tracking filesystem calls across multiple
 * processes, which we're going to use to find the deadlock.
 * The path to the puppetdlock file (in 2.7.x) is the only argument.  This can
 * be obtained with puppet agent --configprint puppetlockfile
 */

#pragma D option quiet

dtrace:::BEGIN
{
 printf("# Now watching access to %s (CTRL-C to quit)\n", $1)
}

/* The intent is to efficiently detect when we've opened the configuration run lockfile. */
syscall::open*:entry
/execname == "ruby"/
{
  self->path_ptr = arg0;
  self->open_ok = 1;
}

/* Save the file descriptor */
syscall::open*:return
/self->open_ok && arg0 != -1/
{
  /* open_fd[<pid>,<file_desciptor>] */
  fd_is_open[pid,arg1] = 1;
  self->path = copyinstr(self->path_ptr);
}

syscall::open*:return
/self->open_ok/
{
  /* cleanup */
  self->open_ok = 0;
  self->path_ptr = 0;
  self->path = 0;
}

syscall::close*:entry
/fd_is_open[pid,arg0]/
{
  printf("{ \"walltimestamp\":\"%d\", \"pid\":\"%d\", \"probefunc\":\"%s\", \"event\":\"entry\", \"file_descriptor\":\"%d\"}\n", walltimestamp, pid, probefunc, arg0);
  fd_is_open[pid,arg0] = 0;
}

syscall::write*:entry
/fd_is_open[pid,arg0]/
{
  printf("{ \"walltimestamp\":\"%d\", \"pid\":\"%d\", \"probefunc\":\"%s\", \"event\":\"entry\", \"file_descriptor\":\"%d\", \"bytes\":\"%d\"}\n", walltimestamp, pid, probefunc, arg0, arg2);
}

syscall::write*:return
/fd_is_open[pid,arg0]/
{
  printf("{ \"walltimestamp\":\"%d\", \"pid\":\"%d\", \"probefunc\":\"%s\", \"event\":\"return\", \"file_descriptor\":\"%d\", \"bytes\":\"%d\"}\n", walltimestamp, pid, probefunc, arg0, arg2)
}

syscall::write*:return
/self->write_ok/
{
  /* cleanup */
  self->write_ok = 0;
}
/* vim:filetype=dtrace */
