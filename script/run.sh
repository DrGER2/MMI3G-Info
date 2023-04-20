#!/bin/ksh

# 20230111 drger; MMI3G Information dump v3
# 20211129 drger; MMI3G Information dump v2
# 20210928 drger; MMI3GP Information dump v1

### REPORT CONFIGURATION ###
INFO_PROCESS=Y
INFO_MOUNT=Y
INFO_FLASH=Y
INFO_FLASH2=Y
INFO_NAV=Y
INFO_GEMMI=Y
INFO_MEDIA=Y
INFO_SSS=Y
INFO_NETWORK=Y
INFO_SYSLOG=Y

# Common functions
xlister(){
  echo; echo "[INFO] List $1 :"
  ls -ovR $1
}

# Script startup:
xversion="v230419"
showScreen ${SDLIB}/mmi3ginfo-0.png
touch ${SDPATH}/.started
xlogfile=${SDPATH}/mmi3ginfo-$(getTime).log
exec > ${xlogfile} 2>&1
umask 022
echo "[INFO] Start: $(date); Timestamp: $(getTime)"

# 20210325 grafe; QNX commands here:
echo; echo "[INFO] MMI Info Dump: mmi3ginfo3-$xversion"

# Get Train and MainUnit software version:
[ "$MUVER" = "MMI3G" ] && SWTRAIN="$(sloginfo -m 10000 -s 5 |
  sed -n 's/^.* +++ Train //p' | sed -n '1p')"
echo; echo "[INFO] MU train name: $SWTRAIN"
MUSWVER="$(sed -n 's/^version = //p' /etc/version/MainUnit-version.txt)"
echo; echo "[INFO] MU software version: $MUSWVER"

# Get installed HDD info from syslog:
HDDINFO="$(sloginfo -m 19 -s 2 | grep 'eide_display_devices.*tid 1' |
  sed 's/^.*mdl //;s/ tid 1.*$//')"
[ -z "$HDDINFO" ] && HDDINFO="n/a"
echo; echo "[INFO] Installed HDD: $HDDINFO"

# Get QNX system info:
echo; echo "[INFO] uname -a"
uname -a

if [ "${INFO_PROCESS}" = Y ]; then
  # List running processes
  echo; echo "[INFO] Running processes (pidin -f aenA)"
  pidin -f aenA
fi # INFO_PROCESS

if [ "${INFO_MOUNT}" = Y ]; then
  # List mounted filesystems
  echo; echo "[INFO] Mounted filesystems (mount):"
  mount

  # List free filesystem space
  echo; echo "[INFO] Free space (df -k -P):"
  df -k -P

  echo; echo "[INFO] ls /"
  ls -o /

  echo; echo "[INFO] ls /mnt"
  ls -o /mnt/
fi # INFO_MOUNT

if [ "$INFO_FLASH" = Y ]; then
  xlister /mnt/ifs-root
  xlister /mnt/efs-system
  xlister /bin/
  xlister /etc/
  xlister /lib/
  xlister /sbin/
  xlister /usr/
fi # INFO_FLASH

if [ "$INFO_FLASH2" = Y ]; then
  xlister /mnt/efs-persist
  xlister /mnt/efs-extended
  xlister /mnt/hmisql
  xlister /mnt/mmebackup1
  xlister /mnt/persistence
  xlister /mnt/phonedb
  xlister /dev/
  xlister /tmp/
  xlister /HBpersistence/
  xlister /proc/
fi # INFO_FLASH2

if [ "$INFO_NAV" = Y ]; then
  xlister /mnt/nav
  cp -v /mnt/efs-persist/FSC/*.fsc ${SDVAR}/
  if [ -f /mnt/efs-persist/navi/db/acios_db.ini ]; then
    echo; echo "[INFO] acios_db.ini:"
    cat /mnt/efs-persist/navi/db/acios_db.ini
    cp -v /mnt/efs-persist/navi/db/acios_db.ini ${SDVAR}/
  else
    echo; echo "[INFO] Cannot find file acios_db.ini"
  fi
fi # INFO_NAV

if [ "$MUVER" = "MMI3GP" ]; then
if [ "$INFO_GEMMI" = Y ]; then
  xlister /mnt/img-cache
  if [ -f /mnt/img-cache/gemmi/.config/Google/GoogleEarthPlus.conf ]; then
    echo; echo "[INFO] GoogleEarthPlus.conf:"
    cat /mnt/img-cache/gemmi/.config/Google/GoogleEarthPlus.conf ${SDVAR}/
    cp -v /mnt/img-cache/gemmi/.config/Google/GoogleEarthPlus.conf ${SDVAR}/
  else
    echo; echo "[INFO] Cannot find file GoogleEarthPlus.conf"
  fi
fi # INFO_GEMMI
fi # MMI3GP

if [ "$INFO_MEDIA" = Y ]; then
  xlister /mnt/gracenode
  if [ -f /mnt/gracenode/db/gracenote.txt ]; then
    echo; echo "[INFO] Gracenote version info:"
    cat /mnt/gracenode/db/gracenote.txt
  fi
  xlister /mnt/mediadisk
  if [ "$MUVER" = "MMI3GP" ]; then
    xlister /mnt/pv-cache
  fi # MMI3GP
fi # INFO_MEDIA

if [ "$INFO_SSS" = Y ]; then
  xlister /mnt/sss
fi # INFO_SSS

if [ "$INFO_NETWORK" = Y ]; then
  echo; echo "[INFO] ifconfig -a"
  ifconfig -a

  echo; echo "[INFO] netstat -n -r"
  netstat -v -n -r

  if [ "$MUVER" = "MMI3GP" ]; then
    echo; echo "[INFO] sysctl net.inet.ip.forwarding"
    sysctl net.inet.ip.forwarding

    echo; echo "[INFO] pfctl -s Interfaces"
    pfctl -vv -s Interfaces

    echo; echo "[INFO] pfctl -s all"
    pfctl -v -s all
  fi # MMI3GP
fi # INFO_NETWORK

if [ "$INFO_SYSLOG" = Y ]; then
  echo; echo "[INFO] sloginfo:"
  sloginfo
fi # INFO_SYSLOG

# Script cleanup:
echo; echo "[INFO] End: $(date); Timestamp: $(getTime)"
showScreen ${SDLIB}/mmi3ginfo-1.png
rm -f ${SDPATH}/.started
exit 0
