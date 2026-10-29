#!/bin/sh -e
#
# Install the UF896 modem + Wi-Fi firmware on a running stick over SSH (run on the PC).
# The blobs are Qualcomm proprietary and not part of this repo; bring your own copies:
#
#   install_uf896_firmware.sh <uf896-image-dir> <sp970-fw-dir> <wlan-nv.bin> [user@host]
#
#   <uf896-image-dir>  UF896 modem firmware 'image' dir (modem.mdt/.bNN, mba.mbn,
#                      modem_pr/mcfg/...), e.g. from github.com/kirdesde/qcom-firmware
#   <sp970-fw-dir>     SP970 firmware set (only its wcnss.* is used). The UF896's own
#                      WCNSS firmware (CNSS.PR.1.4.3-00110) crashes 422 s after start.
#   <wlan-nv.bin>      the board's WCNSS_qcom_wlan_nv.bin (Wi-Fi calibration)
#   [user@host]        default root@192.168.100.1
#
# Needs the msm8916-thwc-uf896-wcnssfix.dtb device tree (default in this branch).

UF896=$1
SP970=$2
NV=$3
HOST=${4:-root@192.168.100.1}

[ -f "$UF896/modem.mdt" ] && [ -f "$UF896/mba.mbn" ] || { echo "no modem.mdt/mba.mbn in $UF896"; exit 1; }
[ -f "$SP970/wcnss.mdt" ] || { echo "no wcnss.mdt in $SP970"; exit 1; }
[ -f "$NV" ] || { echo "no $NV"; exit 1; }
MCFG=$UF896/modem_pr/mcfg/configs/mcfg_sw/generic/common/row/gen_3gpp/mcfg_sw.mbn
[ -f "$MCFG" ] || { echo "no $MCFG"; exit 1; }

STAGE=$(mktemp -d)
mkdir -p $STAGE/wlan/prima
cp "$UF896"/modem.* "$UF896/mba.mbn" "$MCFG" $STAGE/
cp "$SP970"/wcnss.* $STAGE/
cp "$NV" $STAGE/wlan/prima/WCNSS_qcom_wlan_nv.bin

tar -C $STAGE -cf $STAGE.tar .
scp -q $STAGE.tar $HOST:/tmp/uf896-fw.tar
ssh $HOST 'tar -C /lib/firmware --no-same-owner -xf /tmp/uf896-fw.tar && rm /tmp/uf896-fw.tar && sync && ls /lib/firmware | wc -l'
rm -rf $STAGE $STAGE.tar
echo "firmware installed on $HOST - reboot the stick to load it"
