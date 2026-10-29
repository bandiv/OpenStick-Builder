#!/bin/sh
# UF896: the modem drops LTE ~7 min after it starts and sits in 'factory-test' mode.
# Recovery: stop the modem (rmtfs -s owns the remoteproc), reload qcom_bam_dmux (it doesn't
# recover from a modem restart by itself: wwan0 then refuses to come up), start the modem,
# park wwan1-7 like rc.local does at boot, SIM power-cycle, reconnect.
# Triggers: 'factory-test' mode, or 1.1.1.1 and 8.8.8.8 unreachable for 3 min.
Q="qmicli -p -d /dev/wwan0qmi0"
log() { logger -t modem-watchdog "$*"; }
online() { ping -c1 -W5 1.1.1.1 >/dev/null 2>&1 || ping -c1 -W5 8.8.8.8 >/dev/null 2>&1; }

recover() {
  systemctl stop ModemManager
  systemctl stop rmtfs; sleep 3
  modprobe -r qcom_bam_dmux; modprobe qcom_bam_dmux
  systemctl start rmtfs
  i=0; while [ $i -lt 40 ]; do [ -e /dev/wwan0qmi0 ] && ip link show wwan0 >/dev/null 2>&1 && break; i=$((i+1)); sleep 2; done
  sleep 3
  for n in 1 2 3 4 5 6 7; do ip link set wwan$n netns null 2>/dev/null; done
  /usr/local/sbin/modem-online.sh >/dev/null 2>&1
  systemctl start ModemManager
  i=0; while [ $i -lt 18 ]; do sleep 10; online && break; nmcli con up lte >/dev/null 2>&1; i=$((i+1)); done
}

fail=0
sleep 120
while true; do
  mode=$($Q --dms-get-operating-mode 2>/dev/null | sed -n "s/.*Mode: '\(.*\)'/\1/p")
  if online; then fail=0; else fail=$((fail + 20)); fi
  if [ "$mode" = "factory-test" ] || [ $fail -ge 180 ]; then
    t0=$(date +%s)
    log "recovering modem (mode=$mode, offline ${fail}s)"
    recover
    if online; then log "back online after $(( $(date +%s) - t0 ))s"; else log "still offline after recovery"; fi
    fail=0; sleep 60
  fi
  sleep 20
done
