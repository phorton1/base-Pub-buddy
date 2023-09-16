After a difficult few days working on the idea of a putty like
windows UI, and implementing it as BuddyBox.pm and BuddyApp.pm,
with callbacks and process checking to close the app if the window
changes, I have decided to revert back to a simpler command line
approach.

The old code is in /junk/maybeSave/buddyV2withAllThatBuddyAppStuff
inasmuch as there was a lot of learning around Win32::Process::Info.

So, now I am renaming all the files and things back to lowercase
buddy, and removing the app, and using the fileClient window as
an app that can be popped up with ctrl-E.
