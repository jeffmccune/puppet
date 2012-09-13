#!/usr/sbin/dtrace -s
/*
** opensnoop.d - snoop file opens as they occur.
**		 Written in DTrace (Solaris 10 build 51).
**
** NOTE: This version is deprecated. See "opensnoop",
** 	http://www.brendangregg.com/dtrace.html
**
** 23-May-2004, ver 0.70
**
**
** USAGE:	./opensnoop.d
**
**	Different styles of output can be selected by changing
**	the "PFORMAT" variable below.
** 	
** FIELDS:
**		UID	user ID
**		PID	process ID
**		PPID	parent process ID
**		CMD	command 
**		ARGS	command with full arguments
**		TIME	timestamp, us
**		FH	file handle (-1 for error)
**		FILE	pathname for file open
**
** SEE ALSO: truss, BSM auditing
**
** Standard Disclaimer: This is freeware, use at your own risk.
**
** 09-May-2004	Brendan Gregg	Created this.
**
*/

inline int PFORMAT = 1;
/*			1 - Default output
 *			2 - Full command argument output
 *			3 - Timestamp output (includes TIME)
 *			4 - Everything, space delimited (for spreadsheets)
 */

signed int fh;

#pragma D option quiet


/*
**  Print header
*/
dtrace:::BEGIN /PFORMAT == 1/ { 
	printf("%5s %5s %-12s %3s %s\n",
	 "UID","PID","CMD","FH","FILE");
}
dtrace:::BEGIN /PFORMAT == 2/ { 
	printf("%5s %5s %-38s %2s %s\n",
	 "UID","PID","FILE","FH","ARGS");
}
dtrace:::BEGIN /PFORMAT == 3/ { 
	printf("%-14s %5s %5s %-12s %3s %s\n",
	 "TIME","UID","PID","CMD","FH","FILE");
}
dtrace:::BEGIN /PFORMAT == 4/ { 
	printf("%s %s %s %s %s %s %s %s\n",
	 "TIME","UID","PID","PPID","CMD","FH","FILE","ARGS");
}


/*
**  Main
*/
syscall::open*:entry
{
	/*
	**  Store values
	*/
	self->uid = curpsinfo->pr_euid;
	self->pid = pid;
	self->ppid = curpsinfo->pr_ppid;
	self->file = copyinstr(arg0);
	self->comm = (char *)curpsinfo->pr_fname;
	self->args = (char *)curpsinfo->pr_psargs;
}


/*
**  Print output
*/
syscall::open*:return
/PFORMAT == 1/
{
	printf("%5d %5d %-12s %3d %s\n",
	 self->uid,self->pid,stringof(self->comm),
	 fh = arg0,self->file);
}
syscall::open*:return
/PFORMAT == 2/
{
	printf("%5d %5d %-38s %2d %s\n",
	 self->uid,self->pid,self->file,
	 fh = arg0,stringof(self->args));
}
syscall::open*:return
/PFORMAT == 3/
{
	printf("%-14d %5d %5d %-12s %3d %s\n",
	 timestamp/1000,self->uid,self->pid,stringof(self->comm),
	 fh = arg0,self->file);
}
syscall::open*:return
/PFORMAT == 4/
{
	printf("%d %d %d %d %s %d %s %s\n",
	 timestamp/1000,self->uid,self->pid,self->ppid,stringof(self->comm),
	 fh = arg0,self->file,stringof(self->args));
}


/*
**  Cleanup
*/
syscall::open*:return
{
	self->uid = 0;
	self->pid = 0;
	self->ppid = 0;
	self->file = NULL;
	self->comm = NULL;
	self->args = NULL;
}
