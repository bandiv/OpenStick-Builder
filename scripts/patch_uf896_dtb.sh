#!/bin/sh -e
#
# UF896: build msm8916-thwc-uf896-wcnssfix.dtb from the kernel's UF896 device tree,
# with the stock Android memory layout the board's firmware is linked for:
#   - mpss (modem) 78 MB at 0x86800000 instead of 85 MB
#   - wcnss (Wi-Fi) fixed at 0x8b600000 (6 MB) instead of dynamically allocated
# The SP970/UZ801 WCNSS builds that work on this board are linked for 0x8b600000
# and need the full 6 MB. The UF896 modem firmware is 74 MB, so 78 MB still fits.

CHROOT=${CHROOT=$(pwd)/rootfs}
DTBDIR=${CHROOT}/boot/dtbs/qcom
SRC=${DTBDIR}/msm8916-thwc-uf896.dtb
DST=${DTBDIR}/msm8916-thwc-uf896-wcnssfix.dtb
TMPDIR=$(mktemp -d)

dtc -q -I dtb -O dts -o ${TMPDIR}/in.dts ${SRC}

sed 's/reg = <0x00 0x86800000 0x00 0x5500000>;/reg = <0x00 0x86800000 0x00 0x4e00000>;/' ${TMPDIR}/in.dts | awk '
    /^\t\twcnss \{/ { inw = 1 }
    inw && /size = <0x00 0x600000>;/ { sub(/size = <0x00 0x600000>;/, "reg = <0x00 0x8b600000 0x00 0x600000>;"); print; next }
    inw && /alignment|alloc-ranges/ { next }
    inw && /^\t\t\};/ { inw = 0 }
    { print }' > ${TMPDIR}/out.dts

# fail the build if the kernel's device tree changed and the edits didn't apply
grep -q 'reg = <0x00 0x86800000 0x00 0x4e00000>;' ${TMPDIR}/out.dts
grep -q 'reg = <0x00 0x8b600000 0x00 0x600000>;' ${TMPDIR}/out.dts

dtc -q -I dts -O dtb -o ${DST} ${TMPDIR}/out.dts
rm -rf ${TMPDIR}
echo "wrote ${DST}"
