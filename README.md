# CitrixDG-Drain-And-Reboot

This script will tag a server in a delivery group that is not in maintenance mode with the word DRAIN and place in maintenance mode. Upon next run, it checks for a tagged server 
and if it is in maintenance mode and has no sessions, the tag will be removed, server taken out of maintenance mode,and rebooted.  It will tag a new server if none has already 
been tagged. Only one server will be tagged and placed in maintenance mode by this script at a time.

This script can be easily modified to loop through a number of DDCs.
