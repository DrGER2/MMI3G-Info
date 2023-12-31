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
INFO_GEMMI=N
INFO_MEDIA=N
INFO_SSS=N
INFO_HW=Y
INFO_NETWORK=N
INFO_SYSLOG=Y

### Common functions ###
xlister(){
  echo
  if [ -e "$1" ]
  then
    echo "[INFO] List $1 ($(date)):"
    ls -ovR $1
  else
    echo "[INFO] Cannot find $1 ($(date))."
  fi
}

### Script startup ###
xversion="v231230"
case "$MUVER" in
MMI3GB) DRES=l;;
MMI3GH | MMI3GP) DRES=h;;
esac # MUVER-DRES
showScreen ${SDLIB}/mmi3ginfo-0-${DRES}.png
touch ${SDPATH}/.started
xlogfile=${SDPATH}/mmi3ginfo-$(getTime).log
exec > ${xlogfile} 2>&1
umask 022
echo "[INFO] Start: $(date); Timestamp: $(getTime)"

### 20210325 drger; MMI3G Summary ###
echo "[INFO] MMI3G Info Dump: mmi3ginfo3-$xversion"

### Get Train and MainUnit software version ###
case "$MUVER" in
MMI3GB | MMI3GH)
  SWTRAIN="$(sloginfo -m 10000 -s 5 |
    sed -n 's/^.* +++ Train //p' | sed -n 1p)" ;;
esac # MUVER-SWTRAIN
echo; echo "[INFO] MU train name: $SWTRAIN"
MUSWVER="$(sed -n 's/^version = //p' /etc/version/MainUnit-version.txt)"
echo "[INFO] MU software version: $MUSWVER"

### MainUnit Variant ###
case "$MUVER" in
MMI3GB) MUVAR="9304" ;;
MMI3GH) MUVAR="9308" ;;
MMI3GP)
  MUVAR="$(sed -n 's,^<VariantName>,,;s,</VariantName>$,,p' \
         /etc/mmi3g-srv-starter.cfg)" ;;
esac # MUVER-MUVAR
echo "[INFO] MU variant: $MUVAR"

### Get hwSample version ###
MUHWSAMPLE="n/a"
[ -f /etc/hwSample ] && MUHWSAMPLE="$(cat /etc/hwSample)"
echo "[INFO] MU hwSample: $MUHWSAMPLE"

### Get installed HDD info from syslog and fdisk ###
HDDINFO="$(sloginfo -m 19 -s 2 | grep 'eide_display_devices.*tid 1' |
  sed 's/^.*mdl //;s/ tid 1.*$//')"
echo
if [ -z "$HDDINFO" ]
then
  echo "[INFO] No HDD reported by eide_display_devices."
else
  if [ -e /dev/hd0 ]
  then
    echo "[INFO] Installed HDD: $HDDINFO"
    HDDC="$(fdisk /dev/hd0 query -T)"
    echo "[INFO] HDD reported cylinders: $HDDC"
    HDDH="$(fdisk /dev/hd0 info | sed -n 's,^    Heads            : ,,p')"
    HDDS="$(fdisk /dev/hd0 info | sed -n 's,^    Sectors/Track    : ,,p')"
    echo "[INFO] HDD capacity (512 byte sectors): $(($HDDC * $HDDH * $HDDS))"
    echo "[INFO] HDD partition table:"
    fdisk /dev/hd0 show
  else
    echo "[INFO] Cannot find device /dev/hd0."
  fi
fi # HDDINFO

### Get navdb info ###
case "$MUVER" in
MMI3GB)
  # We are MMI3GB, now to find the navdb ...
  if [ -e /fs/sd0/pkgdb ]
  then
    NAVDBP=/fs/sd0
  elif [ -e /fs/sd1/pkgdb ]
  then
    NAVDBP=/fs/sd1
  else
    NAVDBP=/fs/cd0
  fi ;;
MMI3GH | MMI3GP)
  # We are MMI3GH or MMI3GP
  NAVDBP=/mnt/nav/db ;;
esac # MUVER-NAVDBP
DBINFO=${NAVDBP}/DBInfo.txt
if [ -f "$DBINFO" ]
then
  DBPKG="$(ls ${NAVDBP}/pkgdb/*.pkg | sed -n 1p)"
  DBDESC="$(sed -n 's/^description="//p' $DBPKG | sed 's/".*$//')"
  DBREL="$(sed -n 's/^SystemName=[^ ]* //p' $DBINFO | sed 's/".*$//')"
  echo; echo "[INFO] Installed navigation database info: $DBDESC $DBREL"
  NAVREG="$(sed -n 's/^userflags=.*region@//p' $DBPKG | sed 's/;model.*$//')"
  echo "[INFO] Nav database region code: ${NAVREG}"
  FSCSPEC="$(sed -n 's/^userflags=fsc@//p' $DBPKG | sed 's/;region.*$//')"
  echo "[INFO] Nav database release activation file: 000${FSCSPEC}.fsc"
  if [ -f /HBpersistence/FSC/000${FSCSPEC}.fsc ]
  then
    echo "[INFO] Found nav database release FSC file."
  else
    echo "[INFO] Nav database release FSC file not found !"
  fi # FSCSPEC

  if [ -n "$(pidin -f an | grep vdev-logvolmgr)" ]
  then
    echo "[INFO] H-B navdb activation: enabled !"
  else
    echo "[INFO] H-B navdb activation: disabled."
  fi
  if [ -n "$(grep 'acios_db.ini' /usr/bin/manage_cd.sh)" ]
  then
    echo "[INFO] Found LVM patch in /usr/bin/manage_cd.sh."
  elif [ -n "$(grep 'mme-becker.sh' /etc/mmelauncher.cfg)" ]
  then
    echo "[INFO] Found LVM patch in /etc/mmelauncher.cfg."
  else
    echo "[INFO] LVM patch not found !"
  fi
else
  echo; echo "[INFO] No navigation database found on HDD !"
fi # navdb info

### Get Gracenote info ###
GNDBF=/mnt/gracenode/db/gracenote.txt
if [ -f "$GNDBF" ]
then
  GNPN="$(sed -n 's/^PartNumber=//p' $GNDBF | sed 's/$//')"
  echo; echo "[INFO] Gracenote CD-Database part number: $GNPN"
  GNSVN="$(sed -n 's/^SoftwareVersionNumber=//p' $GNDBF | sed 's/$//')"
  echo "[INFO] Gracenote CD-Database version: $GNSVN"
else
  echo; echo "[INFO] No Gracenote database found on HDD !"
fi # gracenote info

### 3GP HMI Info ###
if [ "$MUVER" = MMI3GP ]
then
  echo; echo "[INFO] HMI type: $(cat /etc/hmi_type.txt | sed 's/"//g')"
  echo "[INFO] HMI region: $(cat /etc/hmi_country.txt | sed 's/"//g')"
fi

### Get QNX system info ###
echo; echo "[INFO] uname -a"
uname -a
echo; echo "[INFO] pidin info:"
pidin info

if [ "${INFO_PROCESS}" = Y ]
then
  echo; echo "[INFO] Running processes: pidin -f aenA ($(date)):"
  pidin -f aenA
else
  echo; echo "[INFO] INFO_PROCESS = N"
fi # INFO_PROCESS

if [ "${INFO_MOUNT}" = Y ]
then
  echo; echo "[INFO] Mounted filesystems: mount ($(date)):"
  mount

  echo; echo "[INFO] Free space: df -k -P ($(date)):"
  df -k -P

  echo; echo "[INFO] ls / ($(date)):"
  ls -o /

  echo; echo "[INFO] ls /mnt ($(date)):"
  ls -o /mnt/
else
  echo; echo "[INFO] INFO_MOUNT = N"
fi # INFO_MOUNT

if [ "$INFO_FLASH" = Y ]
then
  xlister /mnt/ifs-root
  xlister /mnt/efs-system
  xlister /bin/
  xlister /etc/
  xlister /lib/
  xlister /sbin/
  xlister /usr/
else
  echo; echo "[INFO] INFO_FLASH = N"
fi # INFO_FLASH

if [ "$INFO_FLASH2" = Y ]
then
  xlister /mnt/efs-persist
  xlister /mnt/efs-extended
  xlister /mnt/hmisql
  xlister /mnt/mmebackup1
  xlister /mnt/persistence
  xlister /mnt/phonedb
  xlister /dev/
# xlister /tmp/
# xlister /HBpersistence/
  xlister /proc/
else
  echo; echo "[INFO] INFO_FLASH2 = N"
fi # INFO_FLASH2

if [ "$INFO_NAV" = Y ]
then
  if [ -e /mnt/nav ]
  then
    # High or Plus
    xlister /mnt/nav
  else
    # Basic
    if [ -e /fs/cd0/pkgdb ]
    then
      xlister /fs/cd0
    elif [ -e /fs/sd0/pkgdb ]
    then
      xlister /fs/sd0
    elif [ -e /fs/sd1/pkgdb ]
    then
      xlister /fs/sd1
    else
      echo; echo "[INFO] Cannot find installed nav database."
    fi
  fi
  cp -v /mnt/efs-persist/FSC/*.fsc ${SDVAR}/
  if [ -f /mnt/efs-persist/navi/db/acios_db.ini ]
  then
    echo; echo "[INFO] acios_db.ini:"
    cat /mnt/efs-persist/navi/db/acios_db.ini
    cp -v /mnt/efs-persist/navi/db/acios_db.ini ${SDVAR}/
  else
    echo; echo "[INFO] Cannot find file acios_db.ini"
  fi
else
  echo; echo "[INFO] INFO_NAV = N"
fi # INFO_NAV

if [ "$MUVER" = MMI3GP ]
then
if [ "$INFO_GEMMI" = Y ]
then
  xlister /mnt/img-cache
  if [ -f /mnt/img-cache/gemmi/.config/Google/GoogleEarthPlus.conf ]
   then
    echo; echo "[INFO] GoogleEarthPlus.conf:"
    cat /mnt/img-cache/gemmi/.config/Google/GoogleEarthPlus.conf
    cp -v /mnt/img-cache/gemmi/.config/Google/GoogleEarthPlus.conf ${SDVAR}/
  else
    echo; echo "[INFO] Cannot find file GoogleEarthPlus.conf"
  fi
else
  echo; echo "[INFO] INFO_GEMMI = N"
fi # INFO_GEMMI
fi # MMI3GP

if [ "$INFO_MEDIA" = Y ]
then
  xlister /mnt/mediadisk
  xlister /mnt/gracenode
  [ "$MUVER" = MMI3GP ] && xlister /mnt/pv-cache
else
  echo; echo "[INFO] INFO_MEDIA = N"
fi # INFO_MEDIA

if [ "$INFO_SSS" = Y ]
then
  xlister /mnt/sss
else
  echo; echo "[INFO] INFO_SSS = N"
fi # INFO_SSS

if [ "$INFO_HW" = Y ]
then
  echo; echo "[INFO] PCI configuration space ($(date)):"
  pci -v

  echo
  if [ -f /dev/shmem/bdaddr.txt ]
  then
    echo "[INFO] Bluetooth h/w address: $(cat /dev/shmem/bdaddr.txt)"
    echo
  else
    echo "[INFO] Cannot find Bluetooth h/w address !"
  fi
else
  echo; echo "[INFO] INFO_HW = N"
fi # INFO_HW

if [ "$INFO_NETWORK" = Y ]
then
  echo; echo "[INFO] ifconfig -a ($(date)):"
  ifconfig -a

  echo; echo "[INFO] netstat -n -r ($(date)):"
  netstat -v -n -r

  if [ "$MUVER" = MMI3GP ]
  then
    echo; echo "[INFO] sysctl net.inet.ip.forwarding"
    sysctl net.inet.ip.forwarding

    echo; echo "[INFO] pfctl -s Interfaces"
    pfctl -vv -s Interfaces

    echo; echo "[INFO] pfctl -s all"
    pfctl -v -s all
  fi # MMI3GP
else
  echo; echo "[INFO] INFO_NETWORK = N"
fi # INFO_NETWORK

if [ "$INFO_SYSLOG" = Y ]
then
  echo; echo "[INFO] sloginfo ($(date)):"
  sloginfo
else
  echo; echo "[INFO] INFO_SYSLOG = N"
fi # INFO_SYSLOG

### Script cleanup ###
echo; echo "[INFO] End: $(date); Timestamp: $(getTime)"
showScreen ${SDLIB}/mmi3ginfo-1-${DRES}.png
rm -f ${SDPATH}/.started
exit 0
