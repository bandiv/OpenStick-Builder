# OpenStick Image Builder
Image builder for MSM8916 based 4G modem dongles

This builder uses the precompiled [kernel](https://pkgs.postmarketos.org/package/master/postmarketos/aarch64/linux-postmarketos-qcom-msm8916) provided by [postmarketOS](https://postmarketos.org/) for Qualcomm MSM8916 devices.

> [!NOTE]
> Branch overview:
> - `debian`  : Debian (stable) based image (default branch).
> - `ubuntu-24.04` : Ubuntu 24.04 LTS (Noble) based image (identical build steps).
> - Alpine (upstream) : Refer to the [original repository's](https://github.com/kinsamanka/OpenStick-Builder/tree/alpine) alpine branch (not maintained here).
> - `uf896` : Debian image for the **UF896_V1.1** (Wingtech) stick, see [UF896](#uf896) below.

## UF896
This branch targets the UF896_V1.1 board (MSM8916, 384 MB RAM, 4 GB eMMC; the case carries the LTE antenna). Differences from `debian`:

- Boots `msm8916-thwc-uf896-wcnssfix.dtb`, generated at build time from the kernel's UF896 device tree by [`scripts/patch_uf896_dtb.sh`](scripts/patch_uf896_dtb.sh): stock memory layout (modem 78 MB at `0x86800000`, Wi-Fi fixed at `0x8b600000`), which the working Wi-Fi firmware is linked for.
- `modem-online.service`: power-cycles the SIM and sets the modem online at boot (otherwise it reports no SIM).
- `modem-watchdog.service`: the UF896 modem drops LTE about 7 minutes after every start and stays in `factory-test` mode. The watchdog restarts it in software (including reloading `qcom_bam_dmux`). Expect a 1–6 minute outage each time; see `journalctl -t modem-watchdog`. The underlying cause is not known yet.
- No `tor`, `ruby` or `build-essential`.

### Firmware
The image has no firmware; the stick has no `modem`/`persist` partitions to load it from. Install it once over SSH after flashing, from your own copies:

```shell
scripts/install_uf896_firmware.sh <uf896-image-dir> <sp970-fw-dir> <WCNSS_qcom_wlan_nv.bin> [root@192.168.100.1]
```

- **Modem:** the UF896's own set (`MPSS.DPM.2.0.2.c1-00155`) plus `mcfg_sw.mbn` from `common/row/gen_3gpp`. The UFI001C/UZ801/SP970 modem firmware crashes this board's modem.
- **Wi-Fi:** WCNSS from the SP970 set (`CNSS.PR.1.4.2.C4.1-00040`) with the UF896 calibration file. The UF896/UFI001C WCNSS (`CNSS.PR.1.4.3-00110`) crashes 422 s after starting and takes LTE down with it.

### Notes
- Default login `user` / `1`, hotspot `4G-UFI-XX` / `1234567890` at `192.168.100.1`. Change both, and add an SSH key before using it anywhere.
- Serial console (1.8 V, 115200 8N1): of the 8 round pads on the bottom edge (USB plug on the right, counted from the left), pad 1 is the stick's TX and pad 6 its RX; GND on the USB plug's tabs.
- No LTE signal at all (-128 dBm, `NoNetworkFound`) with the board out of its case means no antenna.

## Build Instructions
### Build locally
This has been tested to work on **Ubuntu 22.04, 24.04 and 25.04**
- clone
  ```shell
  git clone --recurse-submodules https://github.com/Mio-sha512/OpenStick-Builder.git
  cd OpenStick-Builder/
  ```
#### Quick (Debian branch)
```shell
git checkout debian
sudo ./build.sh
```
#### Quick (Ubuntu 24.04 branch)
```shell
git checkout ubuntu-24.04
sudo ./build.sh
```
#### Detailed (same for any branch)
- install dependencies
  ```shell
  sudo scripts/install_deps.sh
  ```
- build hyp and lk2nd

  These custom bootloaders allow basic support for an `extlinux.conf` file, similar to U-Boot and Depthcharge.
  ```shell
  sudo scripts/build_hyp_aboot.sh
  ```
- extract Qualcomm firmware

  Extracts the bootloader and creates a new partition table that utilizes the full eMMC space
  ```shell
  sudo scripts/extract_fw.sh
  ```
- create rootfs using debootstrap
  ```shell
  sudo scripts/debootstrap.sh
  ```

- build gadget-tools
  ```shell
  sudo scripts/build_gt.sh
  ```
- create images
  ```shell
  sudo scripts/build_images.sh
  ```

The generated firmware files will be stored under the `files` directory

### On the cloud using Github Actions
1. Fork this repo
2. Run the [Build workflow](../../actions/workflows/build.yml)
   - click and run ***Run workflow***
   - once the workflow is done, click on the workflow summary and then download the resulting artifact

## Customizations
Edit [`scripts/setup.sh`](scripts/setup.sh) to add/remove packages. Note that this script is running inside the `chroot` environment.

## Firmware Installation
> [!WARNING]  
> The following commands can potentially brick your device, making it unbootable. Proceed with caution and at your own risk!

> [!IMPORTANT]  
> Make sure to perform a backup of the original firmware using the command `edl rf orig_fw.bin`

### Prerequisites
- [EDL](https://github.com/bkerler/edl)
- Android fastboot tool
  ```
  sudo apt install fastboot
  ```

### Steps
- Ensure that your device is running the stock firmware
- Enter Qualcomm EDL mode using this [guide](https://wiki.postmarketos.org/wiki/Zhihe_series_LTE_dongles_(generic-zhihe)#How_to_enter_flash_mode)
- Backup required partitions

  The following files are required from the original firmware:

     - `fsc.bin`
     - `fsg.bin`
     - `modem.bin`
     - `modemst1.bin`
     - `modemst2.bin`
     - `persist.bin`
     - `sec.bin`

  Skip this step if these files are already present
  ```shell
  for n in fsc fsg modem modemst1 modemst2 persist sec; do
      edl r ${n} ${n}.bin
  done
  ```
- Install `aboot`
  ```shell
  edl w aboot aboot.mbn
  ```
- Reboot to fastboot
  ```shell
  edl e boot
  edl reset
  ```
- Flash firmware
  ```shell
  fastboot flash partition gpt_both0.bin
  fastboot flash aboot aboot.mbn
  fastboot flash hyp hyp.mbn
  fastboot flash rpm rpm.mbn
  fastboot flash sbl1 sbl1.mbn
  fastboot flash tz tz.mbn
  fastboot flash boot boot.bin
  fastboot flash rootfs rootfs.bin
  ```
- Restore original partitions
  ```shell
  for n in fsc fsg modem modemst1 modemst2 persist sec; do
      fastboot flash ${n} ${n}.bin
  done
  ```
- Reboot
  ```shell
  fastboot reboot
  ```

## Post-Install
- Network configuration
  
  |  | |
  | ----- | ---- |
  | ssid | 4G-UFI-XX |
  | password | 1234567890 |
  | ip addr | 192.168.100.1 |

- Default user
  
  | | |
  | ----- | ---- |
  | username | user |
  | password | 1 |
 
- If your device is not based on **UZ801**, modify `/boot/extlinux/extlinux.conf` to use the correct devicetree
  ```shell
  sed -i 's/yiming-uz801v3/<BOARD>/' /boot/extlinux/extlinux.conf
  ```

  where `<BOARD>` is
     - `thwc-uf896` for **UF896** boards
     - `thwc-ufi001c` for **UFIxxx** boards
     - `jz01-45-v33` for **JZxxx** boards
     - `fy-mf800` for **MF800** boards


- To update the kernel of the `debian` image
- Get the kernel link from: http://mirror.postmarketos.org/postmarketos/master/aarch64/

  ```shell
  wget -O - http://mirror.postmarketos.org/postmarketos/master/aarch64/linux-postmarketos-qcom-msm8916-6.12.1-r2.apk \
          | tar xkzf - -C / --exclude=.PKGINFO --exclude=.SIGN* 2>/dev/null
  ```
