# RPiBMC, simplified

A (simpler) external baseboard management controller (BMC), created with a
Raspberry Pi, for lights-out management (LOM).

Allows one to build a Raspberry Pi-based BMC unit for an IPMI-less server. The
Raspbian system must include the package `screen`.

Information about the original RPiBMC project can be found here:
https://www.boniface.me/post/a-raspberry-pi-bmc/

This simplified version differs from that project in a couple of ways:

 - does not depend on a constantly running bmcd daemon
 - missing the locate feature

Otherwise, the same hardware and GPIOs (BCM numbering mode) are used.

The BMC shell is entirely contained in `bmc.sh`, and provides a text-based
interface to the BMC.

It can be set as the default shell of the login user, or directly invoked.  The
user must be made part of the `gpio` group and should be able to use `sudo`.
