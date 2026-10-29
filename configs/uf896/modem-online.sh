#!/bin/sh
# UF896: with the UF896 firmware the modem boots in 'shutting-down' and reports
# sim-missing until the SIM is power-cycled and the modem is set online.
Q="qmicli -p -d /dev/wwan0qmi0"
i=0
while [ ! -e /dev/wwan0qmi0 ] && [ $i -lt 60 ]; do i=$((i+1)); sleep 1; done
sleep 5
$Q --uim-sim-power-off=1
sleep 3
$Q --uim-sim-power-on=1
sleep 5
$Q --dms-set-operating-mode=online
$Q --dms-get-operating-mode
