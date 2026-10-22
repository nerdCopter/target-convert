#!/bin/bash

# EmuFlight definition converter.
# "Usable" since 2023 July.
# Partially Converts Betaflight config.h files to EmuFlight .mk .c .h files.
# Open to receiving more efficient and elegant code.
# July 2023 and later revision requires Internet connection for automated definitions download.

force=0
args=()
for arg in "$@"; do
    case "${arg}" in
        -f|--force) force=1 ;;
        -*) echo "unknown option '${arg}'. aborting."; exit 1 ;;
        *) args+=("${arg}") ;;
    esac
done
set -- "${args[@]}"

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]  2>/dev/null; then
    echo "EmuFlight partial target converter script."
    echo "Usage: ${0##*/} [-f|--force] <targetName> [targetFolder]"
    echo "   Ex: ${0##*/} TUNERCF405"
    echo "   Ex: ${0##*/} TUNERCF405 ./"
    echo "   Ex: ${0##*/} MAMBAF722_2022B ../EmuFlight/src/main/target/"
    echo ""
    echo "note: config.h downloaded from https://github.com/betaflight/config/"
    echo "      manufacturer directory resolved automatically (repo is grouped configs/<MFR>/<BOARD>/)."
    echo "      TIMER_PIN_MAPPING, named pins and DMA options are copied verbatim from config.h."
    echo "      An existing <targetFolder>/<targetName> aborts the run unless --force is given."
    echo "      Open items are written to <targetName>/resources/open-items.txt."
    exit
fi

if [[ ! $( which grep ) ]] ; then
    echo 'please install: grep'
    exit 1
fi
if [[ ! $( which awk ) ]] ; then
    echo 'please install: awk'
    exit 1
fi
if [[ ! $( which sed ) ]] ; then
    echo 'please install: sed'
    exit 1
fi
if [[ ! $( which wc ) ]] ; then
    echo 'please install: wc'
    exit 1
fi
if [[ ! $( which expr ) ]] ; then
    echo 'please install: expr'
    exit 1
fi
if [[ ! $( which wget ) ]] ; then
    echo 'please install: wget'
    exit 1
fi
if [[ ! $( which git ) ]] ; then
    echo 'please install: git'
    exit 1
fi

license='/*
 * This file is part of EmuFlight. It is derived from Betaflight.
 *
 * This is free software. You can redistribute this software
 * and/or modify this software under the terms of the GNU General
 * Public License as published by the Free Software Foundation,
 * either version 3 of the License, or (at your option) any later
 * version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this software.
 *
 * If not, see <http://www.gnu.org/licenses/>.
 */
'
# examples: https://github.com/betaflight/config/raw/master/configs/TURC/TUNERCF405/config.h
#           https://github.com/betaflight/config/raw/master/configs/DIAT/MAMBAF722_2022B/config.h
# repo layout is configs/<MANUFACTURER_ID>/<BOARD>/config.h; manufacturer directory is
# resolved below via the repo's git tree API since only the board name is known here.

echo ""

generatedMessage="This resource file generated using https://github.com/nerdCopter/target-convert"
generatedSHA="Commit: $(git rev-parse --short HEAD)"
generatedDiff="$(git diff --shortstat)"
if [ -n "$generatedDiff" ]; then
    generatedSHA+=" +$generatedDiff"
fi

echo "${generatedMessage}"
echo "${generatedSHA}"
echo ""

board="${1}"
fc="${board}"
dest="${2:-.}/${board}"
resources="${dest}/resources"

if [[ -e "${dest}" && ${force} -eq 0 ]]; then
    echo "'${dest}' already exists. aborting; use --force to overwrite."
    exit 1
fi

echo "creating ${fc}"
createdDest=0
if [[ ! -e "${dest}" ]]; then
    createdDest=1
fi
mkdir -p "${resources}"

# remove the destination on abort only when this run created it
abort_cleanup() {
    [[ ${createdDest} -eq 1 ]] && rm -rf "${dest}"
}

echo "resolving manufacturer directory..."
configTree=$(wget -qO- "https://api.github.com/repos/betaflight/config/git/trees/master?recursive=1")
if [[ -z "$configTree" ]]; then
    echo "failed to query betaflight/config repo tree. aborting."
    abort_cleanup
    exit 1
fi
manufacturer=$(echo "$configTree" | grep -oE "configs/[A-Za-z0-9]+/${board}/config\.h" | head -1 | cut -d/ -f2)
if [[ -z "$manufacturer" ]]; then
    echo "board '${board}' not found in betaflight/config. aborting."
    abort_cleanup
    exit 1
fi
echo "manufacturer: ${manufacturer}"

echo "downloading..."
# download to a temporary name so a failed run keeps the previous config.h
wget -nv -O "${resources}/config.h.part" "https://github.com/betaflight/config/raw/master/configs/${manufacturer}/${board}/config.h" || { rm -f "${resources}/config.h.part" ; echo "download failed. aborting." ; abort_cleanup ; exit 1 ; }
mv -f "${resources}/config.h.part" "${resources}/config.h"

config="${resources}/config.h"

echo "config.h: ${config}"

# Detect MCU family
mcu=$(grep -m1 'FC_TARGET_MCU' "$config" | awk '{print $3}')
echo "MCU: ${mcu}"
mkFile="${dest}/target.mk"
hFile="${dest}/target.h"
openItems="${resources}/open-items.txt"
: > "${openItems}"

# open items are kept out of the target files; one line per item
notice () {
    echo "$1" >> "${openItems}"
}

function translate () {
    local search="$1"
    local infile="$2"
    local output="$3"
    local outfile="$4"
    if grep -q "${search}" "${infile}"; then
        echo -e "${output}" >> "${outfile}"
    fi
}

# create target.mk file
echo "building ${mkFile}"

# setup STM32 type
# BF:
# STM32F405
# STM32F411
# STM32F411DISCOVERY
# STM32F411SX1280
# STM32F4DISCOVERY
# STM32F745
# STM32F7X2 (aka STM32F722)
# STM32G47X
# STM32H723
# STM32H730
# STM32H743
# STM32H750
# to Emu:
# F3_TARGETS
# F405_TARGETS
# F411_TARGETS
# F446_TARGETS
# F7X2RE_TARGETS
# F7X5XG_TARGETS
# F7X6XG_TARGETS

# strictly notes / from inav
# F4_TARGETS      = $(F405_TARGETS) $(F411_TARGETS) $(F446_TARGETS)
# F7_TARGETS      = $(F7X2RE_TARGETS) $(F7X5XE_TARGETS) $(F7X5XG_TARGETS) $(F7X5XI_TARGETS) $(F7X6XG_TARGETS)

# strictly notes / from brainfpv
# 128K_TARGETS  = $(F1_TARGETS)
# 256K_TARGETS  = $(F3_TARGETS)
# 512K_TARGETS  = $(F411_TARGETS) $(F7X2RE_TARGETS) $(F7X5XE_TARGETS) $(F446_TARGETS)
# 1024K_TARGETS = $(F405_TARGETS) $(F7X5XG_TARGETS) $(F7X6XG_TARGETS)
# 2048K_TARGETS = $(F7X5XI_TARGETS)

# BF 4.5 generic TARGET_BOARD_IDENTIFIER ##
# AT32F435G #define TARGET_BOARD_IDENTIFIER "A435"
# AT32F435M #define TARGET_BOARD_IDENTIFIER "A435"
# STM32F405 #define TARGET_BOARD_IDENTIFIER "S405"
# STM32F411 #define TARGET_BOARD_IDENTIFIER "S411"
# STM32F446 #define TARGET_BOARD_IDENTIFIER "S446"
# STM32F745 #define TARGET_BOARD_IDENTIFIER "S745"
# STM32F7X2 (aka STM32F722) #define TARGET_BOARD_IDENTIFIER "S7X2"
# STM32G47X #define TARGET_BOARD_IDENTIFIER "SG47"
# STM32H723 #define TARGET_BOARD_IDENTIFIER "SH72"
# STM32H725 #define TARGET_BOARD_IDENTIFIER "SH72"
# STM32H730 #define TARGET_BOARD_IDENTIFIER "S730"
# STM32H743 #define TARGET_BOARD_IDENTIFIER "SH74"
# STM32H750 #define TARGET_BOARD_IDENTIFIER "S750"

if grep -q STM32F405 "$config"; then
    echo 'F405_TARGETS   += $(TARGET)' > "${mkFile}"
    TBID="S405"
elif grep -q STM32F411 "$config"; then
    echo 'F411_TARGETS   += $(TARGET)' > "${mkFile}"
    TBID="S411"
elif grep -q STM32F446 "$config"; then
    echo 'F446_TARGETS   += $(TARGET)' > "${mkFile}"
    TBID="S446"
elif grep -q -E 'STM32F7X2|STM32F722' "$config"; then
    echo 'F7X2RE_TARGETS += $(TARGET)' > "${mkFile}"
    TBID="S7X2"
elif grep -q STM32F745 "$config"; then
    echo 'F7X5XG_TARGETS += $(TARGET)' > "${mkFile}"
    TBID="S745"
elif grep -q -E 'STM32H723|STM32H725' "$config"; then
    echo 'H723_TARGETS   += $(TARGET)' > "${mkFile}"
    TBID="SH72"
elif grep -q STM32H730 "$config"; then
    echo 'H730_TARGETS   += $(TARGET)' > "${mkFile}"
    TBID="S730"
elif grep -q STM32H743 "$config"; then
    echo 'H743_TARGETS   += $(TARGET)' > "${mkFile}"
    TBID="SH74"
elif grep -q STM32H750 "$config"; then
    echo 'H750_TARGETS   += $(TARGET)' > "${mkFile}"
    TBID="S750"
else
    echo ' - not an STM32F4, F7, or H7.'
    echo ' - aborting.'
    abort_cleanup
    exit 1
fi

# --force: drop stale generated files of earlier runs now that the config and MCU are valid
rm -f "${dest}/target.c" "${resources}/timers.txt"

# enable flash and drivers
FEATURES='FEATURES       += VCP '
if grep -q 'USE_SDCARD' "$config"; then
    if grep -q -E 'USE_SDCARD_SPI|SDCARD_SPI_INSTANCE|SDCARD_SPI_CS_PIN' "$config"; then
        FEATURES+='SDCARD'
    else
        FEATURES+='SDIO'
    fi
fi
if grep -q 'USE_FLASH' "$config" || grep -q 'FLASH_CS_PIN' "$config"; then
    if [[ $FEATURES == *'SDCARD'* || $FEATURES == *'SDIO'* ]]; then
        FEATURES+=' ONBOARDFLASH'
    else
        FEATURES+='ONBOARDFLASH'
    fi
fi
if [[ $FEATURES == 'FEATURES       += VCP ' ]]; then
    # No flash or sdcard detected; default to ONBOARDFLASH
    FEATURES+='ONBOARDFLASH'
fi
echo "${FEATURES}" >> "${mkFile}"
echo '' >> "${mkFile}"

echo 'TARGET_SRC = \' >> "${mkFile}"

# gyros

# EmuFlight supported
#define USE_GYRO_SPI_ICM20601
#define USE_GYRO_SPI_ICM20689
#define USE_GYRO_SPI_MPU6000
#define USE_GYRO_SPI_MPU6500 //physical ICM20602
#define USE_GYRO_SPI_MPU9250
# new
#define USE_GYRO_SPI_ICM42688P
#define USE_ACCGYRO_BMI270

# betaflight
#define USE_GYRO_SPI_ICM20602
#define USE_GYRO_SPI_ICM20689
#define USE_GYRO_SPI_ICM42605
#define USE_GYRO_SPI_ICM42688P
#define USE_GYRO_SPI_MPU6000
#define USE_GYRO_SPI_MPU6500
#define USE_GYRO_SPI_MPU9250
#define USE_ACCGYRO_BMI160
#define USE_ACCGYRO_BMI270
#define USE_ACCGYRO_LSM6DSO

# emuflight supported
# drivers/accgyro/accgyro_fake.c \
# drivers/accgyro/accgyro_imuf9001.c \
# drivers/accgyro/accgyro_mpu6050.c \
# drivers/accgyro/accgyro_mpu6500.c \
# drivers/accgyro/accgyro_mpu.c \
# drivers/accgyro/accgyro_spi_bmi160.c \
# drivers/accgyro/accgyro_spi_icm20689.c
# drivers/accgyro/accgyro_spi_icm426xx.c \
# drivers/accgyro/accgyro_spi_mpu6000.c \
# drivers/accgyro/accgyro_spi_mpu6500.c \
# drivers/accgyro/accgyro_spi_mpu9250.c \
# drivers/accgyro_legacy/accgyro_l3gd20.c \
# drivers/accgyro_legacy/accgyro_lsm303dlhc.c \

echo 'adding drivers'
translate USE_GYRO_SPI_MPU6000 "${config}" 'drivers/accgyro/accgyro_spi_mpu6000.c \' "${mkFile}"
translate USE_GYRO_SPI_MPU6500 "${config}" 'drivers/accgyro/accgyro_mpu6500.c \' "${mkFile}"
translate USE_GYRO_SPI_MPU6500 "${config}" 'drivers/accgyro/accgyro_spi_mpu6500.c \' "${mkFile}"
translate USE_GYRO_SPI_MPU9250 "${config}" 'drivers/accgyro/accgyro_spi_mpu9250.c \' "${mkFile}"
translate USE_GYRO_SPI_ICM20689 "${config}" 'drivers/accgyro/accgyro_spi_icm20689.c \' "${mkFile}"
translate USE_GYRO_SPI_ICM20601 "${config}" 'drivers/accgyro/accgyro_spi_mpu6500.c \' "${mkFile}" #ICM20601 is detected via MPU6500 drivers
translate USE_GYRO_SPI_ICM20602 "${config}" 'drivers/accgyro/accgyro_spi_mpu6500.c \' "${mkFile}" #ICM20602 is detected via MPU6500 drivers
translate USE_ACC_SPI_ICM426 "${config}" 'drivers/accgyro/accgyro_spi_icm426xx.c \' "${mkFile}"
translate USE_ACCGYRO_BMI270 "${config}" 'drivers/accgyro/accgyro_spi_bmi270.c \' "${mkFile}"
# skipping legacy, skipping 6050, skipping non-supported


# FrSky SPI
if grep -q RX_SPI_FRSKY "$config" ; then
    echo 'drivers/rx/rx_cc2500.c \' >> "${mkFile}"
    echo 'rx/cc2500_common.c \' >> "${mkFile}"
    echo 'rx/cc2500_frsky_shared.c \' >> "${mkFile}"
    echo 'rx/cc2500_frsky_d.c \' >> "${mkFile}"
    echo 'rx/cc2500_frsky_x.c \' >> "${mkFile}"
    echo 'rx/cc2500_redpine.c \' >> "${mkFile}"
    echo 'rx/cc2500_sfhss.c \' >> "${mkFile}"
fi

# FlySky SPI
if grep -q RX_SPI_A7105_FLYSKY_2A "$config" ; then
    echo 'drivers/rx/rx_a7105.c \' >> "${mkFile}"
    echo 'rx/flysky.c \' >> "${mkFile}"
fi

# barometers

# emuflight supported
# USE_BARO_BMP085
# USE_BARO_BMP280
# USE_BARO_DPS310
# USE_BARO_LPS
# USE_BARO_MS5611
# USE_BARO_QMP6988
# USE_BARO_SPI_BMP280
# USE_BARO_SPI_LPS
# USE_BARO_SPI_MS5611

# betaflight
# USE_BARO_BMP085
# USE_BARO_BMP280
# USE_BARO_BMP388
# USE_BARO_BPM085
# USE_BARO_BPM280
# USE_BARO_DPS310
# USE_BARO_LPS
# USE_BARO_MS5611
# USE_BARO_QMP6988
# USE_BARO_SPI_BMP280
# USE_BARO_SPI_DPS310
# USE_BARO_SPI_LPS

# emuflight supported
# drivers/barometer/barometer_bmp085.c
# drivers/barometer/barometer_bmp280.c
# drivers/barometer/barometer_fake.c
# drivers/barometer/barometer_lps.c
# drivers/barometer/barometer_ms5611.c
# drivers/barometer/barometer_qmp6988.c

translate USE_BARO_BMP085 "${config}" 'drivers/barometer/barometer_bmp085.c \' "${mkFile}"
translate USE_BARO_BMP280 "${config}" 'drivers/barometer/barometer_bmp280.c \' "${mkFile}"
translate USE_BARO_SPI_BMP280 "${config}" 'drivers/barometer/barometer_bmp280.c \' "${mkFile}"
translate USE_BARO_DPS310 "${config}" 'drivers/barometer/barometer_dps310.c \' "${mkFile}"
translate USE_BARO_SPI_DPS310 "${config}" 'drivers/barometer/barometer_dps310.c \' "${mkFile}"
translate USE_BARO_LPS "${config}" 'drivers/barometer/barometer_lps.c \' "${mkFile}"
translate USE_BARO_SPI_LPS "${config}" 'drivers/barometer/barometer_lps.c \' "${mkFile}"
translate USE_BARO_MS5611 "${config}" 'drivers/barometer/barometer_ms5611.c \' "${mkFile}"
translate USE_BARO_SPI_MS5611 "${config}" 'drivers/barometer/barometer_ms5611.c \' "${mkFile}"
translate USE_BARO_QMP6988 "${config}" 'drivers/barometer/barometer_qmp6988.c \' "${mkFile}"
# skipping non-supported

# emuflight src/main/target
# drivers/compass/compass_ak8963.c \
# drivers/compass/compass_ak8975.c \ # not used, afaict.
# drivers/compass/compass_hmc5883l.c \
# drivers/compass/compass_lis3mdl.c \
# drivers/compass/compass_qmc5883l.c \

# commenting out individual MAGs in favor of wildcard
#translate USE_MAG_SPI_AK8963 ${config} 'drivers/compass/compass_ak8963.c \' ${mkFile}
#translate USE_MAG_HMC5883 ${config} 'drivers/compass/compass_hmc5883l.c \' ${mkFile}
#translate USE_MAG_QMC5883 ${config} 'drivers/compass/compass_qmc5883l.c \' ${mkFile}
#translate USE_MAG_LIS3MDL ${config} 'drivers/compass/compass_lis3mdl.c \' ${mkFile}
if grep -q MAG_ "$config" ; then
    echo '$(addprefix drivers/compass/,$(notdir $(wildcard $(SRC_DIR)/drivers/compass/*.c))) \' >> "${mkFile}"
fi

# skipping vtx 6705
echo 'skipping any VTX RTC6705; please manually modify target.mk if necessary.'
# drivers/vtx_rtc6705.c \
# drivers/vtx_rtc6705_soft_spi.c \

# led_strip and pinio sources are in EmuFlight's common source list; nothing to list per board

# OSD is final driver
echo 'drivers/max7456.c \' >> "${mkFile}"

# all the baro/mag drivers in case external baro/mag
# echo 'drivers/barometer/barometer_fake.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_bmp085.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_bmp280.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_lps.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_ms5611.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_qmp6988.c \' >> ${mkFile}
# echo 'drivers/compass/compass_fake.c \' >> ${mkFile}
# echo 'drivers/compass/compass_ak8963.c \' >> ${mkFile}
# echo 'drivers/compass/compass_ak8975.c \' >> ${mkFile}
# echo 'drivers/compass/compass_hmc5883l.c \' >> ${mkFile}
# echo 'drivers/compass/compass_lis3mdl.c \' >> ${mkFile}
# echo 'drivers/compass/compass_qmc5883l.c \' >> ${mkFile}

echo '' >> "${mkFile}"
echo "# ${generatedMessage}" >> "${mkFile}"
echo "# ${generatedSHA}" >> "${mkFile}"

# create target.h file
echo "building ${hFile}"

echo "${license}" > "${hFile}"
echo "// ${generatedMessage}" >> "${hFile}"
echo "// ${generatedSHA}" >> "${hFile}"
echo '' >> "${hFile}"

echo '#pragma once' >> "${hFile}"
echo '' >> "${hFile}"

grep "BOARD_NAME" "$config" >> "${hFile}"
grep "MANUFACTURER_ID" "$config" >> "${hFile}"
echo "#define TARGET_BOARD_IDENTIFIER \"${TBID}\"  // generic ID" >> "${hFile}" #required; this is essentially mcu-type or custom id
grep "define FC_TARGET_MCU" "$config" | sed 's/$/     \/\/ not used in EmuF/' >> "${hFile}" # not used in EmuF
echo '' >> "${hFile}"

# timers: EmuFlight resolves timer and channel at run time from TIMER_PIN_MAPPING; copy it verbatim
echo "building TIMER_PIN_MAPPING"
timerMap=$(awk '/^[[:space:]]*#[[:space:]]*define[[:space:]]+TIMER_PIN_MAPPING([[:space:]]|$)/ { on = 1 }
     on { print; if ($0 !~ /\\[[:space:]]*$/) on = 0 }' "$config")
if [[ -z "${timerMap}" ]]; then
    notice 'TIMER_PIN_MAPPING not found in config.h; add the timer map to target.h manually.'
else
    echo "${timerMap}" >> "${hFile}"
fi
grep -E '^[[:space:]]*#[[:space:]]*define[[:space:]]+(MOTOR[0-9]+_PIN|SERVO[0-9]+_PIN|RX_PWM[0-9]+_PIN|RX_PPM_PIN|LED_STRIP_PIN|TRANSPONDER_PIN|CAMERA_CONTROL_PIN|GYRO_[0-9]+_CLKIN_PIN|TIMUP[0-9]+_DMA_OPT)[[:space:]]' "$config" >> "${hFile}"
echo '' >> "${hFile}"

# all the USE_ definitions - includes acc, gyro, flash, max, etc
echo "building USE_"
echo " - reference ./info/USE_.txt"
# Emit USE_ defines; comment out those with no EmuFlight driver (H7 / BF-4.5 additions)
grep "define USE_" "$config" | while IFS= read -r line; do
    if echo "$line" | grep -qE 'USE_(ACCGYRO_(LSM6DSV16X|LSM6DSK320X|LSM6DSO|ICM40609D|ICM42686P|ICM45605|ICM45686|IIM42652|IIM42653)|GYRO_CLKIN)'; then
        echo "// ${line} // not supported in EmuFlight"
    elif echo "$line" | grep -qE 'USE_ESCSERIAL([[:space:]]|$)'; then
        :  # fleet-wide default in EmuFlight
    else
        echo "${line}"
    fi
done >> "${hFile}"
translate 'USE_BARO' "$config" '#define USE_BARO' "${hFile}"
echo '' >> "${hFile}"

echo '#define USE_VCP' >> "${hFile}"
if grep -q 'USE_FLASH' "$config" || grep -q 'FLASH_CS_PIN' "$config" ; then
    echo '#define USE_FLASHFS' >> "${hFile}"
    # Detect NOR vs NAND flash chip types from BF config
    has_nor=$(grep -E 'USE_FLASH_(W25Q128FV|M25P16|W25M512|PY25Q128HA)' "$config" 2>/dev/null)
    has_nand=$(grep -E 'USE_FLASH_(W25N01G|W25N02K|W25M02G)' "$config" 2>/dev/null)
    if [[ $has_nor || ! $has_nand ]] ; then
        # NOR or unknown chip (including FLASH_CS_PIN-only configs): emit NOR driver
        translate 'USE_FLASH_W25Q128FV' "$config" '#define USE_FLASH_W25Q128FV' "${hFile}"
        translate 'USE_FLASH_W25M512'   "$config" '#define USE_FLASH_W25M512'   "${hFile}"
        echo '#define USE_FLASH_M25P16    // 16MB Micron M25P16 driver; drives all unless QSPI' >> "${hFile}"
    fi
    # NAND chips
    translate 'USE_FLASH_W25M02G' "$config" '#define USE_FLASH_W25M02G' "${hFile}"
    translate 'USE_FLASH_W25N01G' "$config" '#define USE_FLASH_W25N01G' "${hFile}"
    translate 'USE_FLASH_W25N02K' "$config" '#define USE_FLASH_W25N02K' "${hFile}"
fi
translate 'USE_MAX7456' "$config" '#define USE_OSD' "${hFile}"
echo '' >> "${hFile}"

# led
echo "building LED"
translate 'LED[0-9]_PIN' "$config" '#define USE_LED' "${hFile}"
grep "LED[0-9]_PIN" "$config" >> "${hFile}"

translate 'define[[:space:]]\+LED_STRIP_PIN' "$config" '#define USE_LED_STRIP' "${hFile}"

# beeper, cam-control, usb
echo "building beeper, cam, usb"
translate 'BEEPER_' "$config" '#define USE_BEEPER' "${hFile}"
grep -E '^[[:space:]]*#[[:space:]]*define[[:space:]]+BEEPER_PIN[[:space:]]' "$config" >> "${hFile}"
grep BEEPER_INVERTED "$config" >> "${hFile}"
if grep -q USB_DETECT_PIN "$config" ; then
    echo '#define USE_USB_DETECT' >> "${hFile}"
    grep 'USB_DETECT_PIN' "$config" >> "${hFile}"
fi
echo '' >> "${hFile}"

# spi
echo "building SPI"
translate 'SPI' "$config" '#define USE_SPI' "${hFile}"

for i in {1..6}
do
    translate "SPI${i}_" "$config" "#define USE_SPI_DEVICE_${i}" "${hFile}"
    grep SPI${i}_SCK_PIN "$config" >> "${hFile}"
    grep -E "^[[:space:]]*#[[:space:]]*define[[:space:]]+SPI${i}_(TX|RX)_DMA_OPT[[:space:]]" "$config" >> "${hFile}"
    translate SPI${i}_SDI_PIN "$config" "#define SPI${i}_MISO_PIN        $(grep SPI${i}_SDI_PIN "$config" | awk '{print $3}')" "${hFile}"
    translate SPI${i}_SDO_PIN "$config" "#define SPI${i}_MOSI_PIN        $(grep SPI${i}_SDO_PIN "$config" | awk '{print $3}')" "${hFile}"
done
echo '' >> "${hFile}"

# gyro defines
echo "building GYRO"
if grep -q GYRO_SPI "$config" ; then
    echo '#define USE_SPI_GYRO' >> "$hFile"
    echo ' - defined USE_SPI_GYRO'
fi;

# exti
if grep -q "GYRO_[1-2]_EXTI_PIN" "$config" ; then
    echo '#define USE_EXTI' >> "$hFile"
    echo '#define USE_GYRO_EXTI' >> "$hFile"
    echo ' - defined USE_EXTI and USE_GYRO_EXTI'
    echo '' >> "${hFile}"
fi

# mpu
if grep -q SPI_MPU "$config" ; then
    echo '#define USE_MPU_DATA_READY_SIGNAL' >> "${hFile}"
    grep ENSURE_MPU_DATA_READY_IS_LOW "$config" >> "${hFile}"
    echo ' - defined MPU ready'
    echo '' >> "${hFile}"
fi

G1_csPin=$(grep -w GYRO_1_CS_PIN "$config" | awk -F' ' '{print $3}')
G1_extiPin=$(grep -w GYRO_1_EXTI_PIN "$config" | awk -F' ' '{print $3}')
G1_spi=$(grep -w GYRO_1_SPI_INSTANCE "$config" | awk -F' ' '{print $3}' | sed 's/^SPI\([1-6]\)$/SPIDEV_\1/')

if ! grep -q "GYRO_2_" "$config" ; then
    if grep -q GYRO_1_EXTI_PIN "$config" ; then
        echo "#define MPU_INT_EXTI         ${G1_extiPin}" >> "$hFile"
        echo ' - defined MPU_INT_EXTI'
        # gyro 2 will be gyro_2_, no need for another MPU_INT_EXTI
        # echo '// notice - GYRO_1_EXTI_PIN and MPU_INT_EXTI may be used interchangeably; there is no other [gyroModel]_EXTI_PIN at this time. (ref: https://github.com/emuflight/EmuFlight/blob/master/src/main/sensors/gyro.c)' >> ${hFile}
        echo '' >> "${hFile}"
    fi
fi

if grep -q -w GYRO_1_ALIGN "$config" ; then
    G1_align=$(grep -w GYRO_1_ALIGN "$config" | awk -F' ' '{print $3}')
else
    G1_align='CW0_DEG' # default
fi
if grep -q "GYRO_2_" "$config" ; then # only define GYRO_1 when GYRO_2 exists; will otherwise define actual GYRO
    echo "#define ACC_1_ALIGN          ${G1_align}" >> "${hFile}"
    echo "#define GYRO_1_ALIGN         ${G1_align}" >> "${hFile}"
    grep GYRO_1_CS_PIN "$config" >> "${hFile}"
    grep GYRO_1_EXTI_PIN "$config" >> "${hFile}"
    grep GYRO_1_SPI_INSTANCE "$config" | sed 's/_SPI_INSTANCE/_SPI_BUS/; s/\bSPI\([1-6]\)\b/SPIDEV_\1/g' >> "${hFile}"
    echo ' - defined GYRO_1'
    echo '' >> "${hFile}"
fi

# dual gyro
if grep -q "GYRO_2_" "$config" ; then
    echo '#define USE_DUAL_GYRO' >> "${hFile}"
    echo '' >> "${hFile}"
fi
if grep -q "GYRO_2_" "$config" ; then
    translate "DEFAULT_GYRO_TO_USE"  "$config" "#define GYRO_CONFIG_USE_GYRO_DEFAULT $(grep "DEFAULT_GYRO_TO_USE" "$config" | awk '{print $3}')" "${hFile}"
fi
if grep -q -w GYRO_2_ALIGN "$config" ; then
    G2_align=$(grep -w GYRO_2_ALIGN "$config" | awk -F' ' '{print $3}')
elif grep -q GYRO_2 "$config" ; then
    G2_align='CW0_DEG' # default
fi
if grep -q "GYRO_2_" "$config" ; then
    echo "#define ACC_2_ALIGN          ${G2_align}" >> "${hFile}"
    echo "#define GYRO_2_ALIGN         ${G2_align}" >> "${hFile}"
    grep GYRO_2_CS_PIN "$config" >> "${hFile}"
    grep GYRO_2_EXTI_PIN "$config" >> "${hFile}"
    grep GYRO_2_SPI_INSTANCE "$config" | sed 's/_SPI_INSTANCE/_SPI_BUS/; s/\bSPI\([1-6]\)\b/SPIDEV_\1/g' >> "${hFile}"
    echo ' - defined GYRO_2'
    echo '' >> "${hFile}"
else #individual gyro/all defines
    #MPU9250
    #define USE_GYRO_SPI_MPU9250
    #define USE_ACC_SPI_MPU9250
    if grep -q SPI_MPU9250 "$config" ; then
        # convert gyro1 > mpu -- this may need changing later
        if grep -q GYRO_1_SPI_INSTANCE "$config" ; then
            echo "#define ACC_MPU9250_ALIGN        ${G1_align}" >> "$hFile"
            echo "#define GYRO_MPU9250_ALIGN       ${G1_align}" >> "$hFile"
            echo "#define MPU9250_CS_PIN           ${G1_csPin}" >> "$hFile"
            echo "#define MPU9250_SPI_BUS          ${G1_spi}"  >> "$hFile"
            echo ' - defined MPU9250'
        fi
        echo '' >> "${hFile}"
    fi

    # MPU6000
    #define USE_ACC_SPI_MPU6000
    #define USE_GYRO_SPI_MPU6000
    if grep -q SPI_MPU6000 "$config" ; then
        # convert gyro1 > mpu -- this may need changing later
        if grep -q GYRO_1_SPI_INSTANCE "$config" ; then
            echo "#define ACC_MPU6000_ALIGN        ${G1_align}" >> "$hFile"
            echo "#define GYRO_MPU6000_ALIGN       ${G1_align}" >> "$hFile"
            echo "#define MPU6000_CS_PIN           ${G1_csPin}" >> "$hFile"
            echo "#define MPU6000_SPI_BUS          ${G1_spi}"  >> "$hFile"
            echo ' - defined MPU6000'
        fi
        echo '' >> "${hFile}"
    fi

    # MPU6500 / ICM2060x
    #define USE_ACC_SPI_MPU6500
    #define USE_GYRO_SPI_MPU6500
    #define USE_ACC_SPI_ICM20601
    #define USE_GYRO_SPI_ICM20601
    #define USE_ACC_SPI_ICM20602
    #define USE_GYRO_SPI_ICM20602
    if grep -q SPI_MPU6500 "$config" || grep -q SPI_ICM2060[1-2] "$config" ; then
        if grep -q SPI_ICM2060[1-2] "$config" ; then
            echo "// ICM2060x detected by MPU6500 driver" >> "$hFile"
        fi;
        # convert gyro1 > mpu -- this may need changing later
        if grep -q GYRO_1_SPI_INSTANCE "$config" ; then
            echo "#define ACC_MPU6500_ALIGN        ${G1_align}" >> "$hFile"
            echo "#define GYRO_MPU6500_ALIGN       ${G1_align}" >> "$hFile"
            echo "#define MPU6500_CS_PIN           ${G1_csPin}" >> "$hFile"
            echo "#define MPU6500_SPI_BUS          ${G1_spi}"  >> "$hFile"
            echo ' - defined MPU6500 (maybe ICM2060x)'
        fi
        echo '' >> "${hFile}"
    fi

    # ICM20689
    #define USE_ACC_SPI_ICM20689
    #define USE_GYRO_SPI_ICM20689
    if grep -q SPI_ICM20689 "$config" ; then
        # convert gyro1 > icm -- this may need changing later
        if grep -q GYRO_1_SPI_INSTANCE "$config" ; then
            echo "#define ACC_ICM20689_ALIGN       ${G1_align}" >> "$hFile"
            echo "#define GYRO_ICM20689_ALIGN      ${G1_align}" >> "$hFile"
            echo "#define ICM20689_CS_PIN          ${G1_csPin}" >> "$hFile"
            echo "#define ICM20689_SPI_BUS         ${G1_spi}"  >> "$hFile"
            echo ' - defined ICM20689'
        fi
        echo '' >> "${hFile}"
    fi

    # ICM42688P
    #define USE_GYRO_SPI_ICM42688P
    #define USE_ACC_SPI_ICM42688P
    if grep -q SPI_ICM42688P "$config" ; then
        # convert gyro1 > icm -- this may need changing later
        if grep -q GYRO_1_SPI_INSTANCE "$config" ; then
            echo "#define ACC_ICM42688P_ALIGN      ${G1_align}" >> "$hFile"
            echo "#define GYRO_ICM42688P_ALIGN     ${G1_align}" >> "$hFile"
            echo "#define ICM42688P_CS_PIN         ${G1_csPin}" >> "$hFile"
            echo "#define ICM42688P_SPI_BUS        ${G1_spi}"  >> "$hFile"
            echo ' - defined ICM42688P'
        fi
        echo '' >> "${hFile}"
    fi

    # BMI270
    #define USE_ACCGYRO_BMI270
    #define USE_SPI_GYRO
    if grep -q ACCGYRO_BMI270 "$config" ; then
        # convert gyro1 > icm -- this may need changing later
        echo '#define USE_SPI_GYRO' >> "$hFile"
        if grep -q GYRO_1_SPI_INSTANCE "$config" ; then
            echo "#define ACC_BMI270_ALIGN         ${G1_align}" >> "$hFile"
            echo "#define GYRO_BMI270_ALIGN        ${G1_align}" >> "$hFile"
            echo "#define BMI270_CS_PIN            ${G1_csPin}" >> "$hFile"
            echo "#define BMI270_SPI_BUS           ${G1_spi}"  >> "$hFile"
            echo ' - defined BMI270'
        fi
        echo '' >> "${hFile}"
    fi
fi

# the gyro defines below cover only these drivers; report a config that enables none of them
if ! grep -qE '^[[:space:]]*#[[:space:]]*define[[:space:]]+USE_(GYRO_SPI_(MPU6000|MPU6500|MPU9250|ICM20689|ICM20601|ICM20602|ICM42688P)|ACCGYRO_BMI270)([[:space:]]|$)' "$config" ; then
    notice 'no recognized gyro-enable define found in config.h (checked models: MPU6000, MPU6500, MPU9250, ICM20689, ICM20601, ICM20602, ICM42688P, BMI270); check the gyro defines and add missing ones by hand.'
fi

## vcp, uarts, softserial
echo "building UART(RX/TX), VCP, and serial-count"
vcpserial=1

hardserial=0
for ((i=1; i<=10; i++)) #only seen 8 in EmuF, saw 10 in BF
do
    if grep -q "UART${i}_[TR]X_PIN" "$config" ; then
        echo "#define USE_UART${i}" >> "${hFile}"
        grep -E "^[[:space:]]*#[[:space:]]*define[[:space:]]+UART${i}_[TR]X_PIN[[:space:]]" "$config" >> "${hFile}"
        ((hardserial++))
    fi
done

softserial=0
for ((i=1; i<=2; i++)) # only seen 2 in both EmuF and BF
do
    if grep -q "SOFTSERIAL${i}_[TR]X_PIN" "$config" ; then
        echo "#define USE_SOFTSERIAL${i}" >> "${hFile}"
        grep "SOFTSERIAL${i}_[TR]X_PIN" "$config" >> "${hFile}"
        ((softserial++))
    fi
done
# RX_PPM_PIN not used in EmuF; (ref: https://github.com/emuflight/EmuFlight/blob/master/src/main/pg/rx_pwm.c)
#grep 'RX_PPM_PIN' $config | sed 's/^/\/\//' | sed 's/$/     \/\/ not used in EmuF/'

grep "INVERTER_PIN_UART" "$config" >> "${hFile}"
grep "USART" "$config" >> "${hFile}"
totalserial=$(expr $hardserial + $softserial)
echo "#define SERIAL_PORT_COUNT $(expr $vcpserial + $totalserial)" >> "${hFile}"
echo '' >> "${hFile}"

# BF config.h:
# USE_RX_SPI
# RX_SPI_BIND
# RX_SPI_BIND_PIN
# RX_SPI_CC2500_ANT_SEL_PIN
# RX_SPI_CC2500_LNA_EN_PIN
# RX_SPI_CC2500_TX_EN_PIN
# RX_SPI_CS
# RX_SPI_CS_PIN
# RX_SPI_DEFAULT_PROTOCOL
# RX_SPI_EXPRESSLRS_BUSY_PIN
# RX_SPI_EXPRESSLRS_RESET_PIN
# RX_SPI_EXTI
# RX_SPI_EXTI_PIN
# RX_SPI_INSTANCE
# RX_SPI_LED
# RX_SPI_LED_INVERTED
# RX_SPI_LED_PIN
# RX_SPI_PROTOCOL
#
# to EmuF:
# USE_RX_SPI
# USE_RX_FLYSKY
# USE_RX_FLYSKY_SPI_LED
# USE_RX_FRSKY_SPI
# USE_RX_FRSKY_SPI_D
# USE_RX_FRSKY_SPI_TELEMETRY
# USE_RX_FRSKY_SPI_X
# BINDPLUG_PIN
# DMA_SPI_RX_DMA_CHANNEL
# DMA_SPI_RX_DMA_FLAG_ALL
# DMA_SPI_RX_DMA_FLAG_GL
# DMA_SPI_RX_DMA_FLAG_TC
# DMA_SPI_RX_DMA_HANDLER
# DMA_SPI_RX_DMA_IRQn
# DMA_SPI_RX_DMA_STREAM
# RX_CC2500_SPI_ANT_SEL_PIN
# RX_CC2500_SPI_GDO_0_PIN
# RX_CC2500_SPI_LED_PIN
# RX_CC2500_SPI_LNA_EN_PIN
# RX_CC2500_SPI_TX_EN_PIN
# RX_FLYSKY_SPI_LED_PIN
# RX_FRSKY_SPI_LED_PIN_INVERTED
# RX_NSS_PIN
# RX_SPI_DEFAULT_PROTOCOL
# RX_SPI_INSTANCE
# RX_SPI_LED_PIN
# SPI1_NSS_PIN
# SPI2_NSS_PIN
# SPI3_NSS_PIN
# SPI4_NSS_PIN
# SPI5_NSS_PIN
# SPI_RX_CS_PIN

# RX SPI vs SERIAL
if grep -q 'RX_SPI_' "$config" ; then
    featureRX='FEATURE_RX_SPI'

    if  grep -q 'RX_SPI_FRSKY_X' "$config" ; then
        echo '#define RX_SPI_DEFAULT_PROTOCOL RX_SPI_FRSKY_X' >> "${hFile}"
    fi

    if  grep -q 'RX_SPI_FRSKY_D' "$config" ; then
        echo '#define RX_SPI_DEFAULT_PROTOCOL RX_SPI_FRSKY_D' >> "${hFile}"
    fi

    grep 'RX_SPI_'  "$config" >> "${hFile}"
    grep 'RX_CC2500_SPI_'  "$config" >> "${hFile}"
    sed -i 's/RX_SPI_CC2500_/RX_CC2500_SPI_/g' "${hFile}" #translate the transposed defines

    translate 'RX_SPI_BIND_PIN' "$config" "#define BINDPLUG_PIN $(grep 'RX_SPI_BIND_PIN' "$config" | awk -F' ' '{print $3}' )" "${hFile}"

    grep 'USE_RX_FRSKY_SPI_TELEMETRY' "$config" >> "${hFile}"
    grep 'USE_TELEMETRY_FRSKY_HUB' "$config" >> "${hFile}"
    grep 'RX_FRSKY_SPI_LED_PIN_INVERTED' "$config" >> "${hFile}"

    if  grep -q 'RX_SPI_A7105_FLYSKY_2A' "$config" ; then
        echo '#define USE_RX_FLYSKY' >> "${hFile}"
        echo '#define RX_SPI_DEFAULT_PROTOCOL RX_SPI_A7105_FLYSKY_2A' >> "${hFile}"
    fi

    echo 'skipping some SPI based RX. please define all RX_SPI_ manually; too complex for automation; ELRS not supported by EmuFlight.'
    echo '' >> "${hFile}"
else
    featureRX='FEATURE_RX_SERIAL'
fi

# i2c/baro/mag/etc
echo 'building I2C (BARO, MAG, etc)'
echo ' - not all baro are supported by EmuFlight'
echo ' - BARO/MAG likely incomplete - please inspect and rectify.'

# BARO

# EmuF
#define DEFAULT_BARO_BMP280
#define DEFAULT_BARO_QMP6988
#define DEFAULT_BARO_SPI_BMP280
#define DEFAULT_BARO_SPI_LPS

# BF
#define DEFAULT_BARO_DEVICE BARO_BMP280
#define DEFAULT_BARO_DEVICE BARO_NONE

#in BF config.h
#define DEFAULT_BARO_DEVICE _____
#define DEFAULT_BARO_I2C_ADDRESS xxx

#BARO_CS_PIN
#BARO_I2C_INSTANCE #would be duplicated by grep I2CDEV_${i}
grep BARO_CS_PIN "$config" >> "${hFile}"
grep BARO_SPI_INSTANCE "$config" >> "${hFile}"
if grep -q USE_BARO_.*BMP280 "$config" && grep -q BARO_CS_PIN "$config" ; then
    BARO_CS=$(grep -w BARO_CS_PIN "$config" | awk -F' ' '{print $3}')
    BARO_SPI=$(grep -w BARO_SPI_INSTANCE "$config" | awk -F' ' '{print $3}')
    echo "#define BMP280_CS_PIN       ${BARO_CS}" >> "${hFile}"
    echo "#define BMP280_SPI_INSTANCE ${BARO_SPI}" >> "${hFile}"
fi

# MAG

#USE_MAG_SPI_AK8963
#USE_MAG_AK8975
#USE_MAG_HMC5883
#USE_MAG_QMC5883
#USE_MAG_LIS3MDL

#MAG_HMC5883_ALIGN
#MAG_QMC5883L_ALIGN
#MAG_AK8975_ALIGN
#MAG_AK8963_ALIGN

#HMC5883_SPI_INSTANCE
#HMC5883_CS_PIN
#AK8963_SPI_INSTANCE
#AK8963_CS_PIN

if grep -q -w MAG_ALIGN "$config" ; then
    MAG_align=$(grep -w MAG_ALIGN "$config" | awk -F' ' '{print $3}')
elif grep -q USE_MAG "$config" ; then
    MAG_align='CW0_DEG' # default
fi
#if [[ $(grep USE_MAG $config) ]] ; then
#    echo "#define MAG_ALIGN          ${MAG_align} //technically this will go unused" >> ${hFile}
#fi
if grep -q USE_MAG_SPI_AK8963 "$config" ; then
    echo '#define USE_SPI_MAG' >> "${hFile}"
    translate "MAG_CS_PIN" "$config" "#define AK8963_CS_PIN $(grep -w MAG_CS_PIN "$config" | awk -F' ' '{print $3}')" "${hFile}"
    translate "MAG_SPI_INSTANCE" "$config" "#define AK8963_SPI_INSTANCE $(grep -w MAG_SPI_INSTANCE "$config" | awk -F' ' '{print $3}')" "${hFile}"
    echo "#define MAG_AK8963_ALIGN   ${MAG_align}" >> "${hFile}"
fi
if grep -q USE_MAG_HMC5883 "$config" ; then
    grep USE_MAG_HMC5883 "$config" >> "${hFile}"
    echo "#define MAG_HMC5883_ALIGN  ${MAG_align}" >> "${hFile}"
fi
if grep -q USE_MAG_QMC5883 "$config" ; then
    grep USE_MAG_QMC5883 "$config" >> "${hFile}"
    echo "#define MAG_QMC5883L_ALIGN ${MAG_align}" >> "${hFile}"
fi

#I2C
#grep MAG_I2C_INSTANCE $config >> ${hFile} # purge as it will be duplicated by grep I2CDEV_${i}
translate 'I2C' "$config" '#define USE_I2C' "${hFile}"
translate 'USE_I2C[0-4]_PULLUP' "$config" '#define USE_I2C_PULLUP' "${hFile}"
for i in {1..4}
do
    if grep -q "I2C${i}_" "$config" ; then
        echo "#define USE_I2C_DEVICE_${i}" >> "${hFile}"
        echo "#define I2C_DEVICE_${i}      (I2CDEV_${i})" >> "${hFile}"
    fi
    grep I2CDEV_${i} "$config" >> "${hFile}" # duplicates MAG_I2C_INSTANCE
    translate "USE_I2C${i}_PULLUP ON" "$config" "#define I2C${i}_PULLUP true" "${hFile}"
    translate "I2C${i}_OVERCLOCK ON" "$config" "#define I2C${i}_OVERCLOCK true" "${hFile}"
    translate "I2C${i}_SCL_PIN" "$config" "#define I2C${i}_SCL $(grep "I2C${i}_SCL_PIN" "$config" | awk '{print          $3}')" "${hFile}"
    translate "I2C${i}_SDA_PIN" "$config" "#define I2C${i}_SDA $(grep "I2C${i}_SDA_PIN" "$config" | awk '{print          $3}')" "${hFile}"
done
echo '' >> "${hFile}"

## flash
echo "building FLASH"
if grep -q 'USE_FLASH' "$config" || grep -q 'FLASH_CS_PIN' "$config" ; then
    grep FLASH_CS_PIN "$config" >> "${hFile}"
    grep FLASH_SPI_INSTANCE "$config" >> "${hFile}"
    translate "BLACKBOX_DEVICE_FLASH" "$config" '#define ENABLE_BLACKBOX_LOGGING_ON_SPIFLASH_BY_DEFAULT' "${hFile}"
    echo '' >> "${hFile}"
fi

## sdcard
if grep -q USE_SDCARD "$config" ; then
    if grep -q -E 'USE_SDCARD_SPI|SDCARD_SPI_INSTANCE|SDCARD_SPI_CS_PIN' "$config"; then
        echo "#define USE_SDCARD_SPI" >> "${hFile}"
        grep SDCARD_SPI_CS_PIN "$config" >> "${hFile}"
        grep SDCARD_SPI_INSTANCE "$config" >> "${hFile}"
        echo "#define SDCARD_SPI_FULL_SPEED_CLOCK_DIVIDER     4" >> "${hFile}"
        echo "#define SDCARD_SPI_INITIALIZATION_CLOCK_DIVIDER 256" >> "${hFile}"
        notice 'SDCARD_SPI_*_CLOCK_DIVIDER values are defaults; validate on hardware (full speed: 2, 4, 8; initialization: 128, 256).'
    else
        echo "#define USE_SDCARD_SDIO" >> "${hFile}"
        if [[ "$mcu" != STM32H7* ]]; then
            notice 'SDIO: define SDIO_DMA DMAx_StreamX in target.h and verify it.'
        fi
    fi
    notice 'SD card: SDCARD_DMA_STREAM_TX_FULL, SDCARD_DMA_STREAM_TX, SDCARD_DMA_CLK and SDCARD_DMA_CHANNEL_TX_COMPLETE_FLAG may be needed (rare).'
    translate "BLACKBOX_DEVICE_SDCARD" "$config" "#define ENABLE_BLACKBOX_LOGGING_ON_SDCARD_BY_DEFAULT" "${hFile}"
    grep SDCARD_DETECT_INVERTED "$config" >> "${hFile}"
    echo '' >> "${hFile}"
fi

## gps -- skipping
echo "skipping GPS"

## max7456
echo "building MAX7456"
if grep -q 'USE_MAX7456' "$config" ; then
    grep MAX7456_SPI_CS_PIN "$config" >> "${hFile}"
    grep MAX7456_SPI_INSTANCE "$config" >> "${hFile}"
    echo '' >> "${hFile}"
fi

## adc, default voltage/current, scale
echo "building ADC"
translate 'ADC' "$config" '#define USE_ADC' "${hFile}"
translate "ADC_VBAT_PIN" "$config" "#define VBAT_ADC_PIN $(grep "ADC_VBAT_PIN" "$config" | awk '{print          $3}')" "${hFile}"
translate "ADC_CURR_PIN" "$config" "#define CURRENT_METER_ADC_PIN $(grep "ADC_CURR_PIN" "$config" | awk '{print          $3}')" "${hFile}"
translate "ADC_RSSI_PIN" "$config" "#define RSSI_ADC_PIN $(grep "ADC_RSSI_PIN" "$config" | awk '{print          $3}')" "${hFile}"
grep "ADC[[:digit:]]_DMA_OPT" "$config" >> "${hFile}"
grep "DEFAULT_VOLTAGE_METER_SOURCE" "$config" >> "${hFile}"
scale=$(grep "DEFAULT_VOLTAGE_METER_SCALE" "$config" | awk '{print $3}')
[[ -n "$scale" ]] && echo "#define DEFAULT_VOLTAGE_METER_SCALE $scale" >> "${hFile}"
grep "DEFAULT_CURRENT_METER_SOURCE" "$config" >> "${hFile}"
curscale=$(grep "DEFAULT_CURRENT_METER_SCALE" "$config" | awk '{print $3}')
[[ -n "$curscale" ]] && echo "#define DEFAULT_CURRENT_METER_SCALE $curscale" >> "${hFile}"
grep ADC_INSTANCE "$config" >> "${hFile}"
echo '' >> "${hFile}"

## dshot
echo "building DMAR"
if grep -q DSHOT_DMAR "$config" ; then
    translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_ON" "$config" "#define ENABLE_DSHOT_DMAR true" "${hFile}"
    translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_OFF" "$config" "#define ENABLE_DSHOT_DMAR false" "${hFile}"
    #translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_AUTO" $config "#define ENABLE_DSHOT_DMAR true" ${hFile}
    echo '' >> "${hFile}"
fi

## esc serial timer
echo "building ESC"
if grep -q ESCSERIAL "$config" ; then
    translate "ESCSERIAL_PIN" "$config" "#define ESCSERIAL_TIMER_TX_PIN $(grep "ESCSERIAL_PIN" "$config" | awk '{print          $3}')" "${hFile}"
    echo '' >> "${hFile}"
fi

# pinio
echo "building PINIO"
if grep -q 'PINIO[0-9]_' "$config" ; then
    grep 'PINIO[0-9]_' "$config" >> "${hFile}"
    echo '#define USE_PINIOBOX' >> "$hFile"
    echo '' >> "$hFile"
fi

# button
echo "building button"
if grep -q BUTTON_[AB] "$config" ; then
    grep 'USB_MSC_BUTTON_PIN' "$config" >> "${hFile}"
    grep "BUTTON_[AB]" "$config" >> "${hFile}"
    echo '' >> "${hFile}"
fi

echo '' >> "${hFile}"


echo "building static default FEATURES"
# EmuFlight ORs FEATURE_OSD, FEATURE_TELEMETRY and FEATURE_AIRMODE into every reset; copy only the reference config's own list
awk '/^[[:space:]]*#[[:space:]]*define[[:space:]]+DEFAULT_FEATURES[[:space:]]/ { on = 1 }
     on { print; if ($0 !~ /\\[[:space:]]*$/) on = 0 }' "$config" >> "${hFile}"
echo "#define DEFAULT_RX_FEATURE     ${featureRX}" >> "${hFile}"
echo '' >> "${hFile}"


echo 'cleaning files'
sed '/"TODO"/d' -i "${hFile}"
# deduplicate, but skip empty lines and the verbatim TIMER_PIN_MAPPING block
awk -i inplace '/^[[:space:]]*#[[:space:]]*define[[:space:]]+TIMER_PIN_MAPPING([[:space:]]|$)/ { m = 1 }
    m { print; if ($0 !~ /\\[[:space:]]*$/) m = 0; next }
    !(NF && seen[$0]++)' "${hFile}"
awk -i inplace '!(NF && seen[$0]++)' "${mkFile}" # deduplicate, but skip empty lines

# a TIMER_PIN_MAP row naming an undefined macro breaks the build; check the final file
for tok in $(echo "${timerMap}" | grep -oE 'TIMER_PIN_MAP[[:space:]]*\([^,]*,[^,]*,' | awk -F, '{gsub(/[[:space:]]/, "", $2); print $2}' | grep -vE '^P[A-K][0-9]+$' | sort -u); do
    grep -qE "^[[:space:]]*#[[:space:]]*define[[:space:]]+${tok}[[:space:]]" "${hFile}" || notice "TIMER_PIN_MAPPING names ${tok}, which target.h does not define."
done

echo ''
echo 'Task finished. No guarantees; Definitions are likely incomplete.'
if [[ -s "${openItems}" ]]; then
    echo "Open items: ${openItems}"
    cat "${openItems}"
else
    rm -f "${openItems}"
fi
echo 'Please cleanup target files before Pull-Requesting.'
echo ''
echo "Folder: ${dest}"
ls -lh "${dest}"
