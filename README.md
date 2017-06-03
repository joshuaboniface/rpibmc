# RPiBMC
A BMC (LOM) created with a Raspberry Pi.

Allows one to build a Raspberry Pi-based BMC unit for an IPMI-less server. The
Raspbian system must include the package `screen` and (via `pip`) the Python
libraries `python-daemon` and `raspberry-gpio-python` (installed by default).

There are three main files:

1) `bmcd` - BMC Daemon

   Runs in the background of the system and handles reading and writing GPIO.
   
2) `bmc.sh` - The BMC shell

   Should be set as the default shell of the login user (`bmc`) and provides
   user interface to the BMC.
   
3) `rc.local` - The rc.local file

   The system `rc.local` should be replaced (or symlinked) to this file to start
   the `bmcd` daemon and `screen` console session on boot.
   
