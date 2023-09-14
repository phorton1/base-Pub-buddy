The windows app is really the main process manager,

but is started by the initial invocation of buddy,

and remains sacrosanct.



which really should be a single instance application.






So, you start the windows app the first time.
It will in turn, open a child window because
we need one to run the threaded SSDP scanner.




Options ...
	start with last open configuration
	minimize this window on startup

The new command allows one to create a new configuration, and
must be used the first time.  A configuration consists of

- the port or ip address to use
