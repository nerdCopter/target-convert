#!/bin/bash

# EmuFlight definition converter.
# "Usable" since 2023 July.
# Partially Converts Betaflight config.h files to EmuFlight .mk .c .h files.
# Open to receiving more efficient and elegant code.
# July 2023 and later revision requires Internet connection for automated definitions download.

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]  2>/dev/null; then
    echo "EmuFlight partial target converter script."
    echo "Usage: ${0##*/} <targetName> [targetFolder]"
    echo "   Ex: ${0##*/} TUNERCF405"
    echo "   Ex: ${0##*/} TUNERCF405 ./"
    echo "   Ex: ${0##*/} MAMBAF722_2022B ../EmuFlight/src/main/target/"
    echo ""
    echo "note: config.h downloaded from https://github.com/betaflight/config/"
    echo "      Timer/DMA resolved via local lookup tables in lookup/ (no unified-targets)."
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
if [[ ! $( which xargs ) ]] ; then
    echo 'please install: xargs'
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
# examples: https://github.com/betaflight/config/raw/master/configs/TUNERCF405/config.h
#           https://github.com/betaflight/unified-targets/raw/master/configs/default/TURC-TUNERCF405.config
#           https://github.com/betaflight/config/raw/master/configs/MAMBAF722_2022B/config.h
#           https://github.com/betaflight/unified-targets/raw/master/configs/default/DIAT-MAMBAF722_2022B.config

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

echo "creating ${fc}"
mkdir ${dest} 2> /dev/null
mkdir ${resources} 2> /dev/null

echo "downloading..."
wget -c -N -nv -P ${resources} "https://github.com/betaflight/config/raw/master/configs/${board}/config.h" || { echo "download failed. aborting." ; rm -rf ${dest} ; exit 1 ; }

config="${resources}/config.h"

echo "config.h: ${config}"

# Detect MCU family and load timer hardware lookup table
scriptDir="$(cd "$(dirname "$0")" && pwd)"
mcu=$(grep -m1 'FC_TARGET_MCU' "$config" | awk '{print $3}')
echo "MCU: ${mcu}"
case "${mcu}" in
    STM32F4*|STM32F405*|STM32F446*)  timerHwCsv="${scriptDir}/lookup/f4_timer_hw.csv" ;;
    STM32F7*|STM32F7x2*|STM32F745*|STM32F765*) timerHwCsv="${scriptDir}/lookup/f7_timer_hw.csv" ;;
    STM32H7*) timerHwCsv="${scriptDir}/lookup/h7_timer_hw.csv" ;;
    *) timerHwCsv="${scriptDir}/lookup/f7_timer_hw.csv" ; echo 'notice: unknown MCU, defaulting to F7 timer table' ;;
esac
echo "timer table: ${timerHwCsv}"

# Load timer hw lookup table into associative array: key=PIN_occurrence, value=TIMx:CHy
declare -A timerLookup
while IFS=',' read -r pin occ tim ch; do
    [[ "$pin" == '#'* || -z "$pin" ]] && continue
    timerLookup["${pin}_${occ}"]="${tim}:${ch}"
done < "${timerHwCsv}"

# Load motor pin defines from config.h into associative array: key=pin, value=motorN
declare -A motorPins
for n in 1 2 3 4 5 6 7 8; do
    mp=$(grep -m1 "MOTOR${n}_PIN" "$config" | awk '{print $3}')
    [[ -n "$mp" ]] && motorPins["${mp}"]="${n}"
done

# Load servo pin defines from config.h into associative array: key=pin, value=servoN
declare -A servoPins
for n in 1 2 3 4; do
    sp=$(grep -m1 "SERVO${n}_PIN" "$config" | awk '{print $3}')
    [[ -n "$sp" ]] && servoPins["${sp}"]="${n}"
done

# Load peripheral pin defines from config.h
ppmPin=$(grep -m1 'PPM_PIN\b' "$config" | awk '{print $3}')
ledPin=$(grep -m1 'LED_STRIP_PIN\b' "$config" | awk '{print $3}')
camPin=$(grep -m1 'CAMERA_CONTROL_PIN\b' "$config" | awk '{print $3}')

mkFile="${dest}/target.mk"
cFile="${dest}/target.c"
hFile="${dest}/target.h"
tFile="${resources}/timers.txt"

resolvePinMacro() {
    local tok="$1"
    if [[ "$tok" =~ ^P[A-K][0-9]{1,2}$ ]]; then
        echo "$tok"
    else
        local val
        val=$(grep -m1 "^#define ${tok}[[:space:]]" "$config" | awk '{print $3}')
        echo "${val:-$tok}"
    fi
}

function translate () {
    local search="$1"
    local infile="$2"
    local output="$3"
    local outfile="$4"
    if [[ $(grep "${search}" "${infile}") ]]; then
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
# STM32F7X2
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
# STM32F7X2 #define TARGET_BOARD_IDENTIFIER "S7X2"
# STM32G47X #define TARGET_BOARD_IDENTIFIER "SG47"
# STM32H723 #define TARGET_BOARD_IDENTIFIER "SH72"
# STM32H725 #define TARGET_BOARD_IDENTIFIER "SH72"
# STM32H730 #define TARGET_BOARD_IDENTIFIER "S730"
# STM32H743 #define TARGET_BOARD_IDENTIFIER "SH74"
# STM32H750 #define TARGET_BOARD_IDENTIFIER "S750"

if [[ $(grep STM32F405 $config) ]]; then
    echo 'F405_TARGETS   += $(TARGET)' > ${mkFile}
    TBID="S405"
elif [[ $(grep STM32F411 $config) ]]; then
    echo 'F411_TARGETS   += $(TARGET)' > ${mkFile}
    TBID="S411"
elif [[ $(grep STM32F446 $config) ]]; then
    echo 'F446_TARGETS   += $(TARGET)' > ${mkFile}
    TBID="S446"
elif [[ $(grep STM32F7X2 $config) ]]; then
    echo 'F7X2RE_TARGETS += $(TARGET)' > ${mkFile}
    TBID="S7X2"
elif [[ $(grep STM32F745 $config) ]]; then
    echo 'F7X5XG_TARGETS += $(TARGET)' > ${mkFile}
    TBID="S745"
elif [[ $(grep -E 'STM32H723|STM32H725' $config) ]]; then
    echo 'H723_TARGETS   += $(TARGET)' > ${mkFile}
    TBID="SH72"
elif [[ $(grep STM32H730 $config) ]]; then
    echo 'H730_TARGETS   += $(TARGET)' > ${mkFile}
    TBID="S730"
elif [[ $(grep STM32H743 $config) ]]; then
    echo 'H743_TARGETS   += $(TARGET)' > ${mkFile}
    TBID="SH74"
elif [[ $(grep STM32H750 $config) ]]; then
    echo 'H750_TARGETS   += $(TARGET)' > ${mkFile}
    TBID="S750"
else
    echo ' - not an STM32F4, F7, or H7.'
    echo ' - aborting.'
    rm -r ${dest}
    exit
fi

# enable flash and drivers
FEATURES='FEATURES       += VCP '
if [[ $(grep SDCARD $config) ]]; then
    FEATURES+='SDCARD'
else
    FEATURES+='ONBOARDFLASH'
fi
echo "${FEATURES}" >> ${mkFile}
echo '' >> ${mkFile}

echo 'TARGET_SRC = \' >> ${mkFile}

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
translate USE_GYRO_SPI_MPU6000 ${config} 'drivers/accgyro/accgyro_spi_mpu6000.c \' ${mkFile}
translate USE_GYRO_SPI_MPU6500 ${config} 'drivers/accgyro/accgyro_mpu6500.c \' ${mkFile}
translate USE_GYRO_SPI_MPU6500 ${config} 'drivers/accgyro/accgyro_spi_mpu6500.c \' ${mkFile}
translate USE_GYRO_SPI_MPU9250 ${config} 'drivers/accgyro/accgyro_spi_mpu9250.c \' ${mkFile}
translate USE_GYRO_SPI_ICM20689 ${config} 'drivers/accgyro/accgyro_spi_icm20689.c \' ${mkFile}
translate USE_GYRO_SPI_ICM20601 ${config} 'drivers/accgyro/accgyro_spi_mpu6500.c \' ${mkFile} #ICM20601 is detected via MPU6500 drivers
translate USE_GYRO_SPI_ICM20602 ${config} 'drivers/accgyro/accgyro_spi_mpu6500.c \' ${mkFile} #ICM20602 is detected via MPU6500 drivers
translate USE_ACC_SPI_ICM426 ${config} 'drivers/accgyro/accgyro_spi_icm426xx.c \' ${mkFile}
translate USE_ACCGYRO_BMI270 ${config} 'drivers/accgyro/accgyro_spi_bmi270.c \' ${mkFile}
# skipping legacy, skipping 6050, skipping non-supported


# FrSky SPI
if [[ $(grep RX_SPI_FRSKY $config) ]] ; then
    echo 'drivers/rx/rx_cc2500.c \' >> ${mkFile}
    echo 'rx/cc2500_common.c \' >> ${mkFile}
    echo 'rx/cc2500_frsky_shared.c \' >> ${mkFile}
    echo 'rx/cc2500_frsky_d.c \' >> ${mkFile}
    echo 'rx/cc2500_frsky_x.c \' >> ${mkFile}
    echo 'rx/cc2500_redpine.c \' >> ${mkFile}
    echo 'rx/cc2500_sfhss.c \' >> ${mkFile}
fi

# FlySky SPI
if [[ $(grep RX_SPI_A7105_FLYSKY_2A $config) ]] ; then
    echo 'drivers/rx/rx_a7105.c \' >> ${mkFile}
    echo 'rx/flysky.c \' >> ${mkFile}
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

translate USE_BARO_BMP085 ${config} 'drivers/barometer/barometer_bmp085.c \' ${mkFile}
translate USE_BARO_BMP280 ${config} 'drivers/barometer/barometer_bmp280.c \' ${mkFile}
translate USE_BARO_SPI_BMP280 ${config} 'drivers/barometer/barometer_bmp280.c \' ${mkFile}
translate USE_BARO_LPS ${config} 'drivers/barometer/barometer_lps.c \' ${mkFile}
translate USE_BARO_MS5611 ${config} 'drivers/barometer/barometer_ms5611.c \' ${mkFile}
translate USE_BARO_QMP6988 ${config} 'drivers/barometer/barometer_qmp6988.c \' ${mkFile}
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
if [[ $(grep MAG_ $config) ]] ; then
    echo '$(addprefix drivers/compass/,$(notdir $(wildcard $(SRC_DIR)/drivers/compass/*.c))) \' >> ${mkFile}
fi

# skipping vtx 6705
echo 'skipping any VTX RTC6705; please manually modify target.mk if necessary.'
# drivers/vtx_rtc6705.c \
# drivers/vtx_rtc6705_soft_spi.c \

# led_strip
translate LED_STRIP ${config} 'drivers/light_led.h \' ${mkFile}
translate LED_STRIP ${config} 'drivers/light_ws2811strip.c \' ${mkFile}
# no good ? -- translate LED_STRIP ${config} 'drivers/light_ws2811strip_hal.c \' ${mkFile}

# pinio
translate PINIO ${config} 'drivers/pinio.c \' ${mkFile}

# OSD is final driver
echo 'drivers/max7456.c \' >> ${mkFile}

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

echo '' >> ${mkFile}
echo '# notice - this file was programmatically generated and may be incomplete.' >> ${mkFile}
echo '' >> ${mkFile}
echo "# ${generatedMessage}" >> ${mkFile}
echo "# ${generatedSHA}" >> ${mkFile}

# create target.c file
echo "building ${cFile}"

echo "${license}" > ${cFile}
echo "// ${generatedMessage}" >> ${cFile}
echo "// ${generatedSHA}" >> ${cFile}
echo '' >> ${cFile}

echo '#include <stdint.h>' >> ${cFile}
echo '#include "platform.h"' >> ${cFile}
echo '#include "drivers/io.h"' >> ${cFile}
echo '#include "drivers/dma.h"' >> ${cFile}
echo '#include "drivers/timer.h"' >> ${cFile}
echo '#include "drivers/timer_def.h"' >> ${cFile}
echo '' >> ${cFile}

# DEF_TIM (from TIMER_PIN_MAP in config.h + lookup tables)
echo 'building DEF_TIM'

# Parse TIMER_PIN_MAP entries: TIMER_PIN_MAP(idx, PIN, occurrence, dmaopt)
# Store as parallel arrays: tpmPin[], tpmOcc[], tpmDma[]
tpmPin=()
tpmOcc=()
tpmDma=()
# Extract continuation lines of TIMER_PIN_MAPPING into one stream, then parse each TIMER_PIN_MAP()
while IFS= read -r mapline; do
    rawPin=$(echo "$mapline" | sed 's/.*TIMER_PIN_MAP([^,]*, *\([A-Z][A-Z0-9_]*\).*/\1/')
    pin=$(resolvePinMacro "$rawPin")
    occ=$(echo  "$mapline" | sed 's/.*TIMER_PIN_MAP([^,]*, *[^,]*, *\([0-9]*\).*/\1/')
    dopt=$(echo "$mapline" | sed 's/.*TIMER_PIN_MAP([^,]*, *[^,]*, *[^,]*, *\(-\?[0-9]*\).*/\1/')
    tpmPin+=("$pin")
    tpmOcc+=("$occ")
    tpmDma+=("$dopt")
done < <(grep 'TIMER_PIN_MAP(' "$config" | grep -v '^\s*//')

tpmCount=${#tpmPin[@]}
echo "timerCount: $tpmCount"

# Derive motor count from config.h motor pin defines
motorsCount=0
for n in 1 2 3 4 5 6 7 8; do
    [[ -n "$(grep -m1 "MOTOR${n}_PIN" "$config")" ]] && motorsCount=$n
done
echo "motorsCount: $motorsCount"

# EmuF TIM_USE_ options:
# TIM_USE_ANY
# TIM_USE_BEEPER
# TIM_USE_LED
# TIM_USE_MOTOR
# TIM_USE_NONE
# TIM_USE_PPM
# TIM_USE_PWM
# TIM_USE_SERVO
# TIM_USE_TRANSPONDER

# Emit DEF_TIM entries from TIMER_PIN_MAP + lookup tables
echo 'const timerHardware_t timerHardware[USABLE_TIMER_CHANNEL_COUNT] = {' >> ${cFile}
for (( i = 0; i < tpmCount; i++ )); do
    pin="${tpmPin[$i]}"
    occ="${tpmOcc[$i]}"
    dopt="${tpmDma[$i]}"

    # Look up TIM + CH via lookup table
    timch="${timerLookup[${pin}_${occ}]}"
    if [[ -z "$timch" ]]; then
        echo " - notice: no timer lookup for ${pin} occurrence ${occ}; using TIM_USE_ANY"
        timchOut="UNKNOWN_TIM, UNKNOWN_CH"
    else
        timchOut="${timch//:/, }"
    fi

    # Determine TIM_USE from pin role defines in config.h
    comment=""
    timUse="TIM_USE_ANY"
    if [[ -n "${motorPins[$pin]+_}" ]]; then
        motorN="${motorPins[$pin]}"
        timUse="TIM_USE_MOTOR"
        comment="motor ${motorN}"
        echo "building DEF_TIM for motor ${motorN} : ${pin}"
    elif [[ -n "${servoPins[$pin]+_}" ]]; then
        servoN="${servoPins[$pin]}"
        timUse="TIM_USE_SERVO"
        comment="servo ${servoN}"
        echo "building DEF_TIM for servo ${servoN} : ${pin}"
    elif [[ -n "$ppmPin" && "$pin" == "$ppmPin" ]]; then
        timUse="TIM_USE_PPM"
        comment="ppm"
        echo "building DEF_TIM for ppm : ${pin}"
    elif [[ -n "$ledPin" && "$pin" == "$ledPin" ]]; then
        timUse="TIM_USE_LED"
        comment="led strip"
        echo "building DEF_TIM for led : ${pin}"
    elif [[ -n "$camPin" && "$pin" == "$camPin" ]]; then
        timUse="TIM_USE_ANY"
        comment="cam ctrl"
        echo "building DEF_TIM for cam : ${pin}"
    else
        comment="could not determine TIM_USE_xxxxx - please check"
        echo "building DEF_TIM for pin : ${pin} (role unknown)"
    fi

    # dmaopt -1 means no DMA (e.g. input capture only)
    if [[ "$dopt" == "-1" ]]; then
        dopt="0"
        comment+="; dma -1 in config (input only)"
    fi

    echo "    DEF_TIM(${timchOut}, ${pin}, ${timUse}, 0, ${dopt}), // ${comment}" >> ${cFile}
done
echo '};' >> ${cFile}

echo '' >> ${cFile}
echo '// notice - this file was programmatically generated and may be incomplete.' >> ${cFile}

# timers.txt file for quick reference
echo '// timers for target.c' > ${tFile}
echo '// format : DEF_TIM(TIMxx, CHx, Pxx, TIM_USE_xxxxxxx, 0, x), //comment' >> ${tFile}
echo '' >> ${tFile}
echo 'TIM_USE options:' >> ${tFile}
echo 'TIM_USE_ANY' >> ${tFile}
echo 'TIM_USE_BEEPER' >> ${tFile}
echo 'TIM_USE_LED' >> ${tFile}
echo 'TIM_USE_MOTOR' >> ${tFile}
echo 'TIM_USE_NONE' >> ${tFile}
echo 'TIM_USE_PPM' >> ${tFile}
echo 'TIM_USE_PWM' >> ${tFile}
echo 'TIM_USE_SERVO' >> ${tFile}
echo 'TIM_USE_TRANSPONDER' >> ${tFile}
echo '' >> ${tFile}
echo '// config.h timers' >> ${tFile}
grep "MOTOR[[:digit:]]\+_PIN" $config | xargs -d'\n' --replace echo "{}" >> ${tFile}
echo '' >> ${tFile}
grep TIMER_PIN_MAP $config | xargs -d'\n' --replace echo "{}" >> ${tFile}
echo '' >> ${tFile}
echo '// TIMER_PIN_MAP from config.h' >> ${tFile}
echo '// format: TIMER_PIN_MAP(index, pin, occurrence, dmaopt)' >> ${tFile}
echo '// occurrence selects which timer from the MCU timer table (see lookup/*.csv)' >> ${tFile}
grep 'TIMER_PIN_MAP(' "$config" | grep -v '^\s*//' | sed 's/^/    /' >> ${tFile}

# create target.h file
echo "building ${hFile}"

echo "${license}" > ${hFile}
echo "// ${generatedMessage}" >> ${hFile}
echo "// ${generatedSHA}" >> ${hFile}
echo '' >> ${hFile}

echo '#pragma once' >> ${hFile}
echo '' >> ${hFile}

#translate MANUFACTURER_ID $config "#define TARGET_MANUFACTURER_IDENTIFIER \"$(grep MANUFACTURER_ID $config | awk '{print $3}')\"" ${hFile} #this should be proper but fails to be used
grep "BOARD_NAME" $config >> ${hFile}
grep "MANUFACTURER_ID" $config >> ${hFile}
#translate BOARD_NAME $config "#define USBD_PRODUCT_STRING \"$(grep BOARD_NAME $config | awk '{print $3}')\"" ${hFile} # not needed; this is only the string for the Computer's OS.
echo "#define TARGET_BOARD_IDENTIFIER \"${TBID}\"  // generic ID" >> ${hFile} #required; this is essentially mcu-type or custom id
grep "define FC_TARGET_MCU" $config | sed 's/$/     \/\/ not used in EmuF/' >> ${hFile} # not used in EmuF
echo '' >> ${hFile}

# all the USE_ definitions - includes acc, gyro, flash, max, etc
echo "building USE_"
echo " - reference ./info/USE_.txt"
grep "define USE_" $config >> ${hFile}
if [[ $(grep USE_BARO $config) ]] ; then
    echo '#define USE_BARO' >> ${hFile}
fi
echo '' >> ${hFile}

echo '#define USE_VCP' >> ${hFile}
if [[ $(grep USE_FLASH $config) ]] ; then
    echo '#define USE_FLASHFS' >> ${hFile}
    echo '#define USE_FLASH_M25P16    // 16MB Micron M25P16 driver; drives all unless QSPI' >> ${hFile}
fi
if [[ $(grep USE_MAX7456 $config) ]] ; then
    echo '#define USE_OSD' >> ${hFile}
fi
echo '' >> ${hFile}

# led
echo "building LED"
if [[ $(grep LED[0-9]_PIN $config) ]] ; then
    echo '#define USE_LED' >> ${hFile}
fi
grep "LED[0-9]_PIN" $config >> ${hFile}

if [[ $(grep 'define[[:space:]\+]LED_STRIP_PIN' $config >> ${hFile}) ]] ; then
    echo '#define USE_LED_STRIP' >> ${hFile}
fi

# beeper, cam-control, usb
echo "building beeper, cam, usb"
if [[ $(grep BEEPER_ $config) ]] ; then
    echo '#define USE_BEEPER' >> ${hFile}
fi
grep 'define[[:space:]\+]BEEPER_PIN' $config >> ${hFile}
grep BEEPER_INVERTED $config >> ${hFile}
grep CAMERA_CONTROL_PIN $config >> ${hFile}
if [[ $(grep USB_DETECT_PIN $config) ]] ; then
    echo '#define USE_USB_DETECT' >> ${hFile}
    grep 'USB_DETECT_PIN' $config >> ${hFile}
fi
echo '' >> ${hFile}

# spi
echo "building SPI"
if [[ $(grep SPI $config) ]] ; then
    echo '#define USE_SPI' >> ${hFile}
fi

for i in {1..6}
do
    if [[ $(grep "SPI${i}_" $config) ]] ; then
        echo "#define USE_SPI_DEVICE_${i}" >> ${hFile}
    fi
    grep SPI${i}_SCK_PIN $config >> ${hFile}
    translate SPI${i}_SDI_PIN $config "#define SPI${i}_MISO_PIN        $(grep SPI${i}_SDI_PIN $config | awk '{print $3}')" ${hFile}
    translate SPI${i}_SDO_PIN $config "#define SPI${i}_MOSI_PIN        $(grep SPI${i}_SDO_PIN $config | awk '{print $3}')" ${hFile}
done
echo '' >> ${hFile}

# gyro defines
echo "building GYRO"
if [[ $(grep GYRO_SPI $config) ]] ; then
    echo '#define USE_SPI_GYRO' >> $hFile
    echo ' - defined USE_SPI_GYRO'
fi;

# exti
if [[ $(grep "GYRO_[1-2]_EXTI_PIN" $config) ]] ; then
    echo '#define USE_EXTI' >> $hFile
    echo '#define USE_GYRO_EXTI' >> $hFile
    echo ' - defined USE_EXTI and USE_GYRO_EXTI'
    echo '' >> ${hFile}
fi

# mpu
if [[ $(grep SPI_MPU $config) ]] ; then
    echo '#define USE_MPU_DATA_READY_SIGNAL' >> ${hFile}
    grep ENSURE_MPU_DATA_READY_IS_LOW $config >> ${hFile}
    echo ' - defined MPU ready'
    echo '' >> ${hFile}
fi

G1_csPin=$(grep -w GYRO_1_CS_PIN $config | awk -F' ' '{print $3}')
G1_extiPin=$(grep -w GYRO_1_EXTI_PIN $config | awk -F' ' '{print $3}')
G1_spi=$(grep -w GYRO_1_SPI_INSTANCE $config | awk -F' ' '{print $3}' | sed 's/^SPI\([1-4]\)$/SPIDEV_\1/')

if [[ ! $(grep "GYRO_2_" $config) ]] ; then
    if [[ $(grep GYRO_1_EXTI_PIN $config) ]] ; then
        echo "#define MPU_INT_EXTI         ${G1_extiPin}" >> $hFile
        echo ' - defined MPU_INT_EXTI'
        # gyro 2 will be gyro_2_, no need for another MPU_INT_EXTI
        # echo '// notice - GYRO_1_EXTI_PIN and MPU_INT_EXTI may be used interchangeably; there is no other [gyroModel]_EXTI_PIN at this time. (ref: https://github.com/emuflight/EmuFlight/blob/master/src/main/sensors/gyro.c)' >> ${hFile}
        echo '' >> ${hFile}
    fi
fi

if [[ $(grep -w GYRO_1_ALIGN $config) ]] ; then
    G1_align=$(grep -w GYRO_1_ALIGN $config | awk -F' ' '{print $3}')
else
    G1_align='CW0_DEG' # default
fi
if [[ $(grep "GYRO_2_" $config) ]] ; then # only define GYRO_1 when GYRO_2 exists; will otherwise define actual GYRO
    echo "#define ACC_1_ALIGN          ${G1_align}" >> ${hFile}
    echo "#define GYRO_1_ALIGN         ${G1_align}" >> ${hFile}
    grep GYRO_1_CS_PIN $config >> ${hFile}
    grep GYRO_1_EXTI_PIN $config >> ${hFile}
    grep GYRO_1_SPI_INSTANCE $config | sed 's/_SPI_INSTANCE/_SPI_BUS/; s/\bSPI\([1-4]\)\b/SPIDEV_\1/g' >> ${hFile}
    echo ' - defined GYRO_1'
    echo '' >> ${hFile}
fi

# dual gyro
if [[ $(grep "GYRO_2_" $config) ]] ; then
    echo '#define USE_DUAL_GYRO' >> ${hFile}
    echo '' >> ${hFile}
fi
if [[ $(grep "GYRO_2_" $config) ]] ; then
    translate "DEFAULT_GYRO_TO_USE"  $config "#define GYRO_CONFIG_USE_GYRO_DEFAULT $(grep "DEFAULT_GYRO_TO_USE" $config | awk '{print $3}')" ${hFile}
fi
if [[ $(grep -w GYRO_2_ALIGN $config) ]] ; then
    G2_align=$(grep -w GYRO_2_ALIGN $config | awk -F' ' '{print $3}')
elif [[ $(grep  GYRO_2 $config) ]] ; then
    G2_align='CW0_DEG' # default
fi
if [[ $(grep "GYRO_2_" $config) ]] ; then
    echo "#define ACC_2_ALIGN          ${G2_align}" >> ${hFile}
    echo "#define GYRO_2_ALIGN         ${G2_align}" >> ${hFile}
    grep GYRO_2_CS_PIN $config >> ${hFile}
    grep GYRO_2_EXTI_PIN $config >> ${hFile}
    grep GYRO_2_SPI_INSTANCE $config | sed 's/_SPI_INSTANCE/_SPI_BUS/; s/\bSPI\([1-4]\)\b/SPIDEV_\1/g' >> ${hFile}
    echo ' - defined GYRO_2'
    echo '' >> ${hFile}
else #individual gyro/all defines
    #MPU9250
    #define USE_GYRO_SPI_MPU9250
    #define USE_ACC_SPI_MPU9250
    if [[ $(grep SPI_MPU9250 $config) ]] ; then
        # convert gyro1 > mpu -- this may need changing later
        if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
            echo "#define ACC_MPU9250_ALIGN        ${G1_align}" >> $hFile
            echo "#define GYRO_MPU9250_ALIGN       ${G1_align}" >> $hFile
            echo "#define MPU9250_CS_PIN           ${G1_csPin}" >> $hFile
            echo "#define MPU9250_SPI_BUS          ${G1_spi}"  >> $hFile
            echo ' - defined MPU9250'
        fi
        echo '' >> ${hFile}
    fi

    # MPU6000
    #define USE_ACC_SPI_MPU6000
    #define USE_GYRO_SPI_MPU6000
    if [[ $(grep SPI_MPU6000 $config) ]] ; then
        # convert gyro1 > mpu -- this may need changing later
        if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
            echo "#define ACC_MPU6000_ALIGN        ${G1_align}" >> $hFile
            echo "#define GYRO_MPU6000_ALIGN       ${G1_align}" >> $hFile
            echo "#define MPU6000_CS_PIN           ${G1_csPin}" >> $hFile
            echo "#define MPU6000_SPI_BUS          ${G1_spi}"  >> $hFile
            echo ' - defined MPU6000'
        fi
        echo '' >> ${hFile}
    fi

    # MPU6500 / ICM2060x
    #define USE_ACC_SPI_MPU6500
    #define USE_GYRO_SPI_MPU6500
    #define USE_ACC_SPI_ICM20601
    #define USE_GYRO_SPI_ICM20601
    #define USE_ACC_SPI_ICM20602
    #define USE_GYRO_SPI_ICM20602
    if [[ $(grep SPI_MPU6500 $config) ]] || [[ $(grep SPI_ICM2060[1-2] $config) ]] ; then
        if [[ $(grep SPI_ICM2060[1-2] $config) ]] ; then
            echo "// ICM2060x detected by MPU6500 driver" >> $hFile
        fi;
        # convert gyro1 > mpu -- this may need changing later
        if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
            echo "#define ACC_MPU6500_ALIGN        ${G1_align}" >> $hFile
            echo "#define GYRO_MPU6500_ALIGN       ${G1_align}" >> $hFile
            echo "#define MPU6500_CS_PIN           ${G1_csPin}" >> $hFile
            echo "#define MPU6500_SPI_BUS          ${G1_spi}"  >> $hFile
            echo ' - defined MPU6500 (maybe ICM2060x)'
        fi
        echo '' >> ${hFile}
    fi

    # ICM20689
    #define USE_ACC_SPI_ICM20689
    #define USE_GYRO_SPI_ICM20689
    if [[ $(grep SPI_ICM20689 $config) ]] ; then
        # convert gyro1 > icm -- this may need changing later
        if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
            echo "#define ACC_ICM20689_ALIGN       ${G1_align}" >> $hFile
            echo "#define GYRO_ICM20689_ALIGN      ${G1_align}" >> $hFile
            echo "#define ICM20689_CS_PIN          ${G1_csPin}" >> $hFile
            echo "#define ICM20689_SPI_BUS         ${G1_spi}"  >> $hFile
            echo ' - defined ICM20689'
        fi
        echo '' >> ${hFile}
    fi

    # ICM42688P
    #define USE_GYRO_SPI_ICM42688P
    #define USE_ACC_SPI_ICM42688P
    if [[ $(grep SPI_ICM42688P $config) ]] ; then
        # convert gyro1 > icm -- this may need changing later
        if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
            echo "#define ACC_ICM42688P_ALIGN      ${G1_align}" >> $hFile
            echo "#define GYRO_ICM42688P_ALIGN     ${G1_align}" >> $hFile
            echo "#define ICM42688P_CS_PIN         ${G1_csPin}" >> $hFile
            echo "#define ICM42688P_SPI_BUS        ${G1_spi}"  >> $hFile
            echo ' - defined ICM42688P'
        fi
        echo '' >> ${hFile}
    fi

    # BMI270
    #define USE_ACCGYRO_BMI270
    #define USE_SPI_GYRO
    if [[ $(grep ACCGYRO_BMI270 $config) ]] ; then
        # convert gyro1 > icm -- this may need changing later
        echo '#define USE_SPI_GYRO' >> $hFile
        if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
            echo "#define ACC_BMI270_ALIGN         ${G1_align}" >> $hFile
            echo "#define GYRO_BMI270_ALIGN        ${G1_align}" >> $hFile
            echo "#define BMI270_CS_PIN            ${G1_csPin}" >> $hFile
            echo "#define BMI270_SPI_BUS           ${G1_spi}"  >> $hFile
            echo ' - defined BMI270'
        fi
        echo '' >> ${hFile}
    fi
fi

## vcp, uarts, softserial
echo "building UART(RX/TX), VCP, and serial-count"
vcpserial=1

hardserial=0
for ((i=1; i<=10; i++)) #only seen 8 in EmuF, saw 10 in BF
do
    if [[ $(grep "UART${i}_[TR]X_PIN" $config) ]] ; then
        echo "#define USE_UART${i}" >> ${hFile}
        grep "define[[:space:]\+]UART${i}_[TR]X_PIN" $config >> ${hFile}
        ((hardserial++))
    fi
done

softserial=0
for ((i=1; i<=2; i++)) # only seen 2 in both EmuF and BF
do
    if [[ $(grep "SOFTSERIAL${i}_[TR]X_PIN" $config) ]] ; then
        echo "#define USE_SOFTSERIAL${i}" >> ${hFile}
        grep "SOFTSERIAL${i}_[TR]X_PIN" $config >> ${hFile}
        ((softserial++))
    fi
done
# RX_PPM_PIN not used in EmuF; (ref: https://github.com/emuflight/EmuFlight/blob/master/src/main/pg/rx_pwm.c)
#grep 'RX_PPM_PIN' $config | sed 's/^/\/\//' | sed 's/$/     \/\/ not used in EmuF/'

grep "INVERTER_PIN_UART" $config >> ${hFile}
grep "USART" $config >> ${hFile}
totalserial=$(expr $hardserial + $softserial)
echo "#define SERIAL_PORT_COUNT $(expr $vcpserial + $totalserial)" >> ${hFile}
echo '' >> ${hFile}

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
if [[ $(grep 'RX_SPI_' $config) ]] ; then
    featureRX='FEATURE_RX_SPI'

    if  [[ $(grep 'RX_SPI_FRSKY_X' $config) ]] ; then
        echo '#define RX_SPI_DEFAULT_PROTOCOL RX_SPI_FRSKY_X' >> ${hFile}
    fi

    if  [[ $(grep 'RX_SPI_FRSKY_D' $config) ]] ; then
        echo '#define RX_SPI_DEFAULT_PROTOCOL RX_SPI_FRSKY_D' >> ${hFile}
    fi

    grep 'RX_SPI_'  $config >> ${hFile}
    grep 'RX_CC2500_SPI_'  $config >> ${hFile}
    sed -i 's/RX_SPI_CC2500_/RX_CC2500_SPI_/g' ${hFile} #translate the transposed defines

    translate 'RX_SPI_BIND_PIN' $config "#define BINDPLUG_PIN $(grep 'RX_SPI_BIND_PIN' $config | awk -F' ' '{print $3}' )" ${hFile}

    grep 'USE_RX_FRSKY_SPI_TELEMETRY' $config >> ${hFile}
    grep 'USE_TELEMETRY_FRSKY_HUB' $config >> ${hFile}
    grep 'RX_FRSKY_SPI_LED_PIN_INVERTED' $config >> ${hFile}

    if  [[ $(grep 'RX_SPI_A7105_FLYSKY_2A' $config) ]] ; then
        echo '#define USE_RX_FLYSKY' >> ${hFile}
        echo '#define RX_SPI_DEFAULT_PROTOCOL RX_SPI_A7105_FLYSKY_2A' >> ${hFile}
    fi

    echo 'skipping some SPI based RX. please define all RX_SPI_ manually; too complex for automation; ELRS not supported by EmuFlight.'
    echo '' >> ${hFile}
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
grep BARO_CS_PIN $config >> ${hFile}
grep BARO_SPI_INSTANCE $config >> ${hFile}
if [[ $(grep USE_BARO_.*BMP280 $config) ]] && [[ $(grep BARO_CS_PIN $config) ]] ; then
    BARO_CS=$(grep -w BARO_CS_PIN $config | awk -F' ' '{print $3}')
    BARO_SPI=$(grep -w BARO_SPI_INSTANCE $config | awk -F' ' '{print $3}')
    echo "#define BMP280_CS_PIN       ${BARO_CS}" >> ${hFile}
    echo "#define BMP280_SPI_INSTANCE ${BARO_SPI}" >> ${hFile}
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

if [[ $(grep -w MAG_ALIGN $config) ]] ; then
    MAG_align=$(grep -w MAG_ALIGN $config | awk -F' ' '{print $3}')
elif [[ $(grep USE_MAG $config) ]] ; then
    MAG_align='CW0_DEG' # default
fi
#if [[ $(grep USE_MAG $config) ]] ; then
#    echo "#define MAG_ALIGN          ${MAG_align} //technically this will go unused" >> ${hFile}
#fi
if [[ $(grep USE_MAG_SPI_AK8963 $config) ]] ; then
    echo '#define USE_SPI_MAG' >> ${hFile}
    translate "MAG_CS_PIN" $config "#define AK8963_CS_PIN $(grep -w MAG_CS_PIN $config | awk -F' ' '{print $3}')" ${hFile}
    translate "MAG_SPI_INSTANCE" $config "#define AK8963_SPI_INSTANCE $(grep -w MAG_SPI_INSTANCE $config | awk -F' ' '{print $3}')" ${hFile}
    echo "#define MAG_AK8963_ALIGN   ${MAG_align}" >> ${hFile}
fi
if [[ $(grep USE_MAG_HMC5883 $config) ]] ; then
    grep USE_MAG_HMC5883 $config >> ${hFile}
    echo "#define MAG_HMC5883_ALIGN  ${MAG_align}" >> ${hFile}
fi
if [[ $(grep USE_MAG_QMC5883 $config) ]] ; then
    grep USE_MAG_QMC5883 $config >> ${hFile}
    echo "#define MAG_QMC5883L_ALIGN ${MAG_align}" >> ${hFile}
fi

#I2C
#grep MAG_I2C_INSTANCE $config >> ${hFile} # purge as it will be duplicated by grep I2CDEV_${i}
if [[ $(grep I2C $config) ]] ; then
    echo '#define USE_I2C' >> ${hFile}
fi
if [[ $(grep "USE_I2C[0-4]_PULLUP" $config) ]] ; then
    echo '#define USE_I2C_PULLUP' >> $hFile
fi
for i in {1..4}
do
    if [[ $(grep "I2C${i}_" $config) ]] ; then
        echo "#define USE_I2C_DEVICE_${i}" >> ${hFile}
        echo "#define I2C_DEVICE_${i}      (I2CDEV_${i})" >> ${hFile}
    fi
    grep I2CDEV_${i} $config >> ${hFile} # duplicates MAG_I2C_INSTANCE
    if [[ $(grep "USE_I2C${i}_PULLUP ON" $config) ]] ; then
        echo "#define I2C${i}_PULLUP true" >> $hFile
    fi
    translate "I2C${i}_OVERCLOCK ON" $config "#define I2C${i}_OVERCLOCK true" ${hFile}
    translate "I2C${i}_SCL_PIN" $config "#define I2C${i}_SCL $(grep "I2C${i}_SCL_PIN" $config | awk '{print          $3}')" ${hFile}
    translate "I2C${i}_SDA_PIN" $config "#define I2C${i}_SDA $(grep "I2C${i}_SDA_PIN" $config | awk '{print          $3}')" ${hFile}
done
echo '' >> ${hFile}

## flash
echo "building FLASH"
if [[ $(grep 'USE_FLASH' $config) ]] ; then
    grep FLASH_CS_PIN $config >> ${hFile}
    grep FLASH_SPI_INSTANCE $config >> ${hFile}
    translate "BLACKBOX_DEVICE_FLASH" $config '#define ENABLE_BLACKBOX_LOGGING_ON_SPIFLASH_BY_DEFAULT' ${hFile}
    echo '' >> ${hFile}
fi

## sdcard
if [[ $(grep USE_SDCARD $config) ]] ; then
    echo "#define USE_SDCARD_SDIO" >> ${hFile}
    grep SDCARD_SPI_CS_PIN $config >> ${hFile}
    grep SDCARD_SPI_INSTANCE $config >> ${hFile}
    echo "//notice - NEED: #define SDCARD_DMA_CHANNEL          X            // please verify" >> ${hFile}
    echo "//notice - NEED: #define SDCARD_DMA_CHANNEL_TX       DMAx_StreamX // please verify" >> ${hFile}
    echo "//notice - other sdcard defines maybe needed (rare?): SDCARD_DMA_STREAM_TX_FULL, SDCARD_DMA_STREAM_TX, SDCARD_DMA_CLK, SDCARD_DMA_CHANNEL_TX_COMPLETE_FLAG" >> ${hFile}
    translate "BLACKBOX_DEVICE_SDCARD" $config "#define ENABLE_BLACKBOX_LOGGING_ON_SDCARD_BY_DEFAULT" ${hFile}
    echo "#define SDCARD_SPI_FULL_SPEED_CLOCK_DIVIDER     4    //notice - needs validation. these are hardware dependent. known options: 2, 4, 8." >> ${hFile}
    echo "#define SDCARD_SPI_INITIALIZATION_CLOCK_DIVIDER 256  //notice - needs validation. these are hardware dependent. known options: 128, 256" >> ${hFile}
    grep SDCARD_DETECT_INVERTED $config >> ${hFile}
    echo '' >> ${hFile}
fi

## gps -- skipping
echo "skipping GPS"

## max7456
echo "building MAX7456"
if [[ $(grep 'USE_MAX7456' $config) ]] ; then
    grep MAX7456_SPI_CS_PIN $config >> ${hFile}
    grep MAX7456_SPI_INSTANCE $config >> ${hFile}
    echo '' >> ${hFile}
fi

## adc, default voltage/current, scale
echo "building ADC"
if [[ $(grep ADC $config) ]] ; then
    echo '#define USE_ADC' >> ${hFile}
fi
translate "ADC_VBAT_PIN" $config "#define VBAT_ADC_PIN $(grep "ADC_VBAT_PIN" $config | awk '{print          $3}')" ${hFile}
translate "ADC_CURR_PIN" $config "#define CURRENT_METER_ADC_PIN $(grep "ADC_CURR_PIN" $config | awk '{print          $3}')" ${hFile}
translate "ADC_RSSI_PIN" $config "#define RSSI_ADC_PIN $(grep "ADC_RSSI_PIN" $config | awk '{print          $3}')" ${hFile}
grep "ADC[[:digit:]]_DMA_OPT" $config >> ${hFile}
# Resolve ADCn_DMA_OPT -> DMA stream using lookup table
for i in {1..5}
do
    dmaOpt=$(grep -m1 "ADC${i}_DMA_OPT" "$config" | awk '{print $3}')
    if [[ -n "$dmaOpt" ]]; then
        adcLookup=$(grep -m1 "^${i},${dmaOpt}," "${scriptDir}/lookup/f4f7_dma_adc.csv" 2>/dev/null)
        if [[ -n "$adcLookup" ]]; then
            ctrl=$(echo "$adcLookup" | awk -F',' '{print $3}')
            stream=$(echo "$adcLookup" | awk -F',' '{print $4}')
            echo "#define ADC${i}_DMA_STREAM DMA${ctrl}_Stream${stream} // ADC${i} opt${dmaOpt}" >> ${hFile}
        else
            echo "#define ADC${i}_DMA_STREAM DMA2_Stream0 // notice - ADC${i} opt${dmaOpt} not resolved; please verify" >> ${hFile}
        fi
    fi
done
echo ' - please verify ADC DMA Streams.'
grep "DEFAULT_VOLTAGE_METER_SOURCE" $config >> ${hFile}
scale=$(grep "DEFAULT_VOLTAGE_METER_SCALE" $config | awk '{print $3}')
[[ -n "$scale" ]] && echo "#define DEFAULT_VOLTAGE_METER_SCALE $scale" >> ${hFile}
grep "DEFAULT_CURRENT_METER_SOURCE" $config >> ${hFile}
curscale=$(grep "DEFAULT_CURRENT_METER_SCALE" $config | awk '{print $3}')
[[ -n "$curscale" ]] && echo "#define DEFAULT_CURRENT_METER_SCALE $curscale" >> ${hFile}
grep ADC_INSTANCE $config >> ${hFile}
echo '' >> ${hFile}

## dshot
echo "building DMAR"
if [[ $(grep DSHOT_DMAR $config) ]] ; then
    translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_ON" $config "#define ENABLE_DSHOT_DMAR true" ${hFile}
    translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_OFF" $config "#define ENABLE_DSHOT_DMAR false" ${hFile}
    #translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_AUTO" $config "#define ENABLE_DSHOT_DMAR true" ${hFile}
    echo '' >> ${hFile}
fi

## esc serial timer
echo "building ESC"
if [[ $(grep ESCSERIAL $config) ]] ; then
    echo '#define USE_ESCSERIAL' >> ${hFile}
    translate "ESCSERIAL_PIN" $config "#define ESCSERIAL_TIMER_TX_PIN $(grep "ESCSERIAL_PIN" $config | awk '{print          $3}')" ${hFile}
    echo '' >> ${hFile}
fi

# pinio
echo "building PINIO"
if [[ $(grep 'PINIO[0-9]_' $config >> ${hFile}) ]] ; then
    echo '#define USE_PINIOBOX' >> $hFile
    echo '' >> $hFile
fi

# button
echo "building button"
if [[ $(grep BUTTON_[AB] $config) ]] ; then
    grep 'USB_MSC_BUTTON_PIN' >> ${hFile}
    grep "BUTTON_[AB]" $config >> ${hFile}
    echo '' >> ${hFile}
fi

echo '' >> ${hFile}

# port masks
echo "building port masks"

# Compute per-port bitmasks by scanning every P[A-K][0-9]{1,2} token in config.h.
# Each bit N in TARGET_IO_PORTx represents pin N (0-15): (1 << N).
# H7 uses ports up to K; F4/F7 typically use up to H. Unused ports are skipped.
declare -A portMask
while IFS= read -r pinToken; do
    port="${pinToken:1:1}"
    num="${pinToken:2}"
    portMask[$port]=$(( ${portMask[$port]:-0} | (1 << num) ))
done < <(grep -oE '\bP[A-K][0-9]{1,2}\b' "$config" | sort -u)

for port in A B C D E F G H I J K; do
    mask="${portMask[$port]}"
    if [[ -n "$mask" && "$mask" -ne 0 ]]; then
        # Single-pin port (mask is a power of 2): emit exact BIT(n).
        # Multi-pin port: emit 0xffff so future pin additions never require mask edits.
        if (( (mask & (mask - 1)) == 0 )); then
            pin_num=0; while (( (1 << pin_num) != mask )); do (( pin_num++ )); done
            printf '#define TARGET_IO_PORT%s (BIT(%d))\n' "$port" "$pin_num" >> "${hFile}"
        else
            printf '#define TARGET_IO_PORT%s 0xffff\n' "$port" >> "${hFile}"
        fi
    fi
done
echo '// notice - port masks derived from config.h; single-pin ports use exact mask, multi-pin ports use 0xffff' >> ${hFile}
echo '' >> ${hFile}

echo "building static default FEATURES"
echo " - please modify as fit."
echo "#define DEFAULT_FEATURES       (FEATURE_OSD | FEATURE_TELEMETRY | FEATURE_AIRMODE | ${featureRX})" >> ${hFile}
echo "#define DEFAULT_RX_FEATURE     ${featureRX}" >> ${hFile}
echo '' >> ${hFile}

# used timers: derive from TIMER_PIN_MAP lookup results
echo "building USED_TIMERS"
declare -A usedTimNums
for (( i = 0; i < tpmCount; i++ )); do
    pin="${tpmPin[$i]}"; occ="${tpmOcc[$i]}"
    timch="${timerLookup[${pin}_${occ}]}"
    [[ -n "$timch" ]] && usedTimNums["${timch%%:*}"]=1
done
usedTimers=''
for t in $(echo "${!usedTimNums[@]}" | tr ' ' '\n' | sort -V); do
    num="${t#TIM}"
    [[ $usedTimers != '' ]] && usedTimers+="|"
    usedTimers+=" TIM_N(${num}) "
done
echo "#define USABLE_TIMER_CHANNEL_COUNT $(grep 'TIMER_PIN_MAP(' "${config}" | grep -cv '^\s*//')" >> ${hFile}
# to do: logic
echo "#define USED_TIMERS (${usedTimers})" >> ${hFile}
echo '' >> ${hFile}

echo '// notice - this file was programmatically generated and may be incomplete.' >> ${hFile}

echo 'cleaning files'
sed '/"TODO"/d' -i ${hFile}
awk -i inplace '!(NF && seen[$0]++)' ${hFile} # deduplicate, but skip empty lines
awk -i inplace '!(NF && seen[$0]++)' ${mkFile} # deduplicate, but skip empty lines

echo ''
echo 'Task finished. No guarantees; Definitions are likely incomplete.'
echo 'Please search the resultant files for the keyword "notice" to rectify any needs.'
echo 'Please cleanup target files before Pull-Requesting.'
echo ''
echo "Folder: ${dest}"
ls -lh "${dest}"
