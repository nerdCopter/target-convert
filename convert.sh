#!/bin/bash

# EmuFlight definition converter.
# "Usable" since 2023 July.
# Partially Converts Betaflight config.h files to EmuFlight .mk .c .h files.
# Open to receiving more efficient and elegant code.
# July 2023 and later revision requires Internet connection for automated definitions download.

if ! [ $# -eq 2 ]  2>/dev/null; then
    echo "EmuFlight partial target converter script."
    echo "Usage: ${0##*/} <unifiedTargetName> <targetFolder>"
    echo "   Ex: ${0##*/} TURC-TUNERCF405 ./"
    echo "   Ex: ${0##*/} DIAT-MAMBAF722_2022B ../EmuFlight/src/main/target/"
    echo ""
    echo "note: Target definitions will be downloaded from"
    echo "      https://github.com/betaflight/config/"
    echo "      and https://github.com/betaflight/unified-targets/"
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

manufacturer=$(echo ${1} | awk -F'-' '{print $1}')
board=$(echo ${1} | awk -F'-' '{print $2}')
fc="${manufacturer}_${board}"
dest="${2}/${board}"
resources="${dest}/resources"

echo "creating ${fc}"
mkdir ${dest} 2> /dev/null
mkdir ${resources} 2> /dev/null

echo "downloading..."
wget -c -N -nv -P ${resources} "https://github.com/betaflight/config/raw/master/configs/${board}/config.h" || { echo "download failed. aborting." ; rm -rf ${dest} ; exit 1 ; }
wget -c -N -nv -P ${resources} "https://github.com/betaflight/unified-targets/raw/master/configs/default/${1}.config" || { echo "download failed. aborting." ; rm -r ${dest} ; exit 1 ; }

config="${resources}/config.h"
unified="${resources}/${1}.config"

echo "config.h: ${config}"
echo "unified: ${unified}"

mkFile="${dest}/target.mk"
cFile="${dest}/target.c"
hFile="${dest}/target.h"
tFile="${resources}/timers.txt"

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
else
    echo ' - not an F4 nor an F7.'
    rm -r ${dest}
    echo ' - aborting.'
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
echo 'drivers/accgyro/accgyro_mpu.c \' >> ${mkFile} # needed irregardless (???)
translate USE_GYRO_SPI_MPU6000 ${config} 'drivers/accgyro/accgyro_spi_mpu6000.c \' ${mkFile}
translate USE_GYRO_SPI_MPU6500 ${config} 'drivers/accgyro/accgyro_mpu6500.c \' ${mkFile}
translate USE_GYRO_SPI_MPU6500 ${config} 'drivers/accgyro/accgyro_spi_mpu6500.c \' ${mkFile}
translate USE_GYRO_SPI_MPU9250 ${config} 'drivers/accgyro/accgyro_spi_mpu9250.c \' ${mkFile}
translate USE_GYRO_SPI_ICM20689 ${config} 'drivers/accgyro/accgyro_spi_icm20689.c \' ${mkFile}
translate USE_GYRO_SPI_ICM20601 ${config} 'drivers/accgyro/accgyro_spi_icm20601.c \' ${mkFile}
translate USE_GYRO_SPI_ICM20602 ${config} 'drivers/accgyro/accgyro_spi_icm20602.c \' ${mkFile}
translate USE_ACC_SPI_ICM426 ${config} 'drivers/accgyro/accgyro_spi_icm426xx.c \' ${mkFile}
translate USE_ACCGYRO_BMI270 ${config} 'drivers/accgyro/accgyro_spi_bmi270.c \' ${mkFile}
# skipping legacy, skipping 6050, skipping non-supported

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
translate USE_MAG_SPI_AK8963 ${config} 'drivers/compass/compass_ak8963.c \' ${mkFile}
translate USE_MAG_HMC5883 ${config} 'drivers/compass/compass_hmc5883l.c \' ${mkFile}
translate USE_MAG_QMC5883 ${config} 'drivers/compass/compass_qmc5883l.c \' ${mkFile}
translate USE_MAG_LIS3MDL ${config} 'drivers/compass/compass_lis3mdl.c \' ${mkFile}

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
# echo 'drivers/barometer/barometer_bmp085.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_bmp280.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_lps.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_ms5611.c \' >> ${mkFile}
# echo 'drivers/barometer/barometer_qmp6988.c \' >> ${mkFile}
# echo 'drivers/compass/compass_ak8963.c \' >> ${mkFile}
# echo 'drivers/compass/compass_ak8975.c \' >> ${mkFile}
# echo 'drivers/compass/compass_hmc5883l.c \' >> ${mkFile}
# echo 'drivers/compass/compass_lis3mdl.c \' >> ${mkFile}
# echo 'drivers/compass/compass_qmc5883l.c \' >> ${mkFile}

echo '' >> ${mkFile}
echo '# notice - this file was programmatically generated and may be incomplete.' >> ${mkFile}
echo '# eg: flash, compass, barometer, vtx6705, ledstrip, pinio, etc.   especially mag/baro' >> ${mkFile}
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

# DEF_TIM
echo 'building DEF_TIM'
pinArray=($(grep "TIM[0-9]* CH" $unified | awk -F' ' '{print $3}' | sed s/://)) #col 3 contains colon to be stripped
timerArray=($(grep "TIM[0-9]* CH" $unified | awk -F' ' '{print $4}'))
channelArray=($(grep "TIM[0-9]* CH" $unified | awk -F' ' '{print $5}'))
pinCount=${#pinArray[@]}
timerCount=${#timerArray[@]}
channelCount=${#channelArray[@]}
# debug to screen
#echo "pinCount: $pinCount"
echo "timerCount: $timerCount"
#echo "channelCount: $channelCount"

#tranlate pin syntax
for (( i = 0; i <= $pinCount-1; i++ ))
do
    # specialized 0-trim
    convertedPinArray[$i]="P$(echo ${pinArray[$i]} | sed -E 's/^([A-Z])0?([0-9]+)/\1\2/')"
    # debug to screen
    #echo "pin: ${pinArray[$i]} (${convertedPinArray[$i]}) timer: ${timerArray[$i]} channel: ${channelArray[$i]}"
done
convertedPinArray=("${convertedPinArray[@]}")
convertedPinCount=${#channelArray[@]}
# debug to screen
#echo "convertedPinCountCount: $convertedPinCount"

# debug to screen
# grep 'dma pin ' $unified

motorsArray=($(grep "resource MOTOR " $unified | awk -F' ' '{print $3}'))
motorsPINArray=($(grep "resource MOTOR " $unified | awk -F' ' '{print $4}'))
motorsCount=${#motorsArray[@]}
motorsPINCount=${#motorsPINArray[@]}
# debug to screen
echo "motorsCount: $motorsCount"
#echo "motorsPINCount: $motorsPINCount"

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

# above was data reading, so now perform output
echo 'const timerHardware_t timerHardware[USABLE_TIMER_CHANNEL_COUNT] = {' >> ${cFile}
for (( i = 1; i <= $motorsCount; i++ ))
do
    echo "building DEF_TIM for motor $i : ${motorsPINArray[$i-1]}"
    timer=""
    channel=""
    dma=""
    for (( j = 0; j <= $pinCount-1; j++ )) ; do
        # match motor pin/timer/chan/dma
        # debug to screen
        #echo "motor $i ${motorsPINArray[$i-1]} (${convertedPinArray[$j]})" #motors[0] is motorNumber1
        #echo "${motorsPINArray[$i-1]} == ${pinArray[$j]} ?? >> ${timerArray[$j]} & ${channelArray[$j]}"
        if [[ "${motorsPINArray[$i-1]}" == "${pinArray[$j]}" ]] ; then
            # debug to screen
            #echo "found ^"
            timer="${timerArray[$j]}"
            channel="${channelArray[$j]}"
            dma=$(grep "dma pin ${motorsPINArray[$i-1]}" $unified | awk -F' ' '{print $4}')
            if [ -z "$dma" ] ; then
                echo ' - error: no associated dma value found. assuming 0. please repair if necessary.'
                comment+='; dma 0 assumed, please verify'
                dma="0"
            fi
            break # stop at motor ${j}
        fi
    done;
    echo "    DEF_TIM(${timer}, ${channel}, ${convertedPinArray[$j]}, TIM_USE_MOTOR, 0, ${dma}), // motor ${i}" >> ${cFile}
    # debug to screen
    #echo "    DEF_TIM(${timer}, ${channel}, ${convertedPinArray[$j]}, TIM_USE_MOTOR, 0, ${dma}), // motor ${i}"

    # remove pin $j (motor $i) we dont need it anymore (syntax: unset 'array[x]')
    unset 'pinArray[j]' 
    unset 'timerArray[j]'
    unset 'channelArray[j]'
    unset 'convertedPinArray[j]'
done

#compact arrays after unsets / very important
pinArray=("${pinArray[@]}")
timerArray=("${timerArray[@]}")
channelArray=("${channelArray[@]}")
convertedPinArray=("${convertedPinArray[@]}")
#new array sizes
pinCount=${#pinArray[@]}
timerCount=${#timerArray[@]}
channelCount=${#channelArray[@]}
convertedPinCount=${#channelArray[@]}
# debug to screen
#echo "remaining pinCount: $pinCount"
echo "remaining timerCount: $timerCount"
#echo "remaining channelCount: $channelCount"
#echo "remaining convertedPinCountCount: $convertedPinCount"

# build remaining non-motor timers
for (( i = 0; i <= $pinCount-1; i++ ))
do
    echo "building DEF_TIM for pin ${pinArray[$i]} (${convertedPinArray[$i]})"
    timer="${timerArray[$i]}"
    channel="${channelArray[$i]}"
    dma=$(grep "dma pin ${pinArray[$i]}" $unified | awk -F' ' '{print $4}')
    ppm=$(grep "${pinArray[$i]}" $unified | grep PPM)
    led=$(grep "${pinArray[$i]}" $unified | grep LED)
    cam=$(grep "${pinArray[$i]}" $unified | grep CAMERA)
    baro=$(grep "${pinArray[$i]}" $unified | grep BARO)
    if [[ $ppm ]] ; then
        timUse="TIM_USE_PPM"
        comment="ppm"
    elif [[ $led ]] ; then
        timUse="TIM_USE_LED"
        comment="led"
    elif [[ $cam ]] ; then
        timUse="TIM_USE_ANY"
        comment="cam ctrl"
    elif [[ $baro ]] ; then
        timUse="TIM_USE_ANY"
        comment="baro"
    else
        timUse="TIM_USE_ANY"
        comment="could not determine TIM_USE_xxxxx - please check"
    fi
    if [ -z "$dma" ] ; then
        echo ' - error: no associated dma value found. assuming 0. please repair if necessary.'
        comment+='; dma 0 assumed, please verify'
        dma="0"
    fi
    echo "    DEF_TIM(${timer}, ${channel}, ${convertedPinArray[$i]}, ${timUse}, 0, ${dma}), // ${comment}" >> ${cFile}
    # debug to screen
    #echo "    DEF_TIM(${timer}, ${channel}, ${convertedPinArray[$i]}, ${timUse}, 0, ${dma}), // ${comment}"
done
echo '};' >> ${cFile}
echo '' >> ${cFile}

echo '// notice - DEF_TIM was programmatically generated and may be wrong or incomplete.' >> ${cFile}
echo '//          please reference associated unified-target.' >> ${cFile}
echo '//          some timers may associate with multiple pins. e.g baro/flash' >> ${cFile}

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
echo '// unified timers' >> ${tFile}
echo '# timer' >> ${tFile}
grep -A1 'timer ' $unified | xargs -d'\n' --replace echo "{}" >> ${tFile}
echo '' >> ${tFile}
grep -A1 'dma ADC ' $unified | xargs -d'\n' --replace echo "{}" >> ${tFile}
grep -A1 'dma pin ' $unified | xargs -d'\n' --replace echo "{}" >> ${tFile}

# create target.h file
echo "building ${hFile}"

echo "${license}" > ${hFile}
echo "// ${generatedMessage}" >> ${hFile}
echo "// ${generatedSHA}" >> ${hFile}
echo '' >> ${hFile}

echo '#pragma once' >> ${hFile}
echo '' >> ${hFile}


translate MANUFACTURER_ID $config "#define TARGET_MANUFACTURER_IDENTIFIER \"$(grep MANUFACTURER_ID $config | awk '{print $3}')\"" ${hFile} #this is technically proper
translate BOARD_NAME $config "#define USBD_PRODUCT_STRING \"$(grep BOARD_NAME $config | awk '{print $3}')\"" ${hFile}
echo '' >> ${hFile}
grep "define FC_TARGET_MCU" $config | sed 's/$/     \/\/ not used in EmuF/' >> ${hFile} # not used in EmuF
translate MANUFACTURER_ID $config "#define TARGET_BOARD_IDENTIFIER \"${TBID}\"  // generic ID" ${hFile} #seemingly deprecated in BF 4.5, resorting to unified equivalent
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
    echo '#define USE_FLASH_M25P16    // 16MB Micron M25P16 and others (ref: https://github.com/betaflight/betaflight/blob/master/src/main/drivers/flash_m25p16.c)' >> ${hFile}
    echo '//#define USE_FLASH_W25M    // 1Gb NAND flash support' >> ${hFile}
    echo '//#define USE_FLASH_W25M512 // 16, 32, 64 or 128MB Winbond stacked die support' >> ${hFile}
    echo '//#define USE_FLASH_W25Q    // 512Kb (256Kb x 2 stacked) NOR flash support' >> ${hFile}
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

if [[ $(grep LED_STRIP_PIN $config >> ${hFile}) ]] ; then
    echo '#define USE_LED_STRIP' >> ${hFile}
fi

# beeper, cam-control, usb
echo "building beeper, cam, usb"
if [[ $(grep BEEPER_ $config) ]] ; then
    echo '#define USE_BEEPER' >> ${hFile}
fi
grep BEEPER_PIN $config >> ${hFile}
grep BEEPER_INVERTED $config >> ${hFile}
grep CAMERA_CONTROL_PIN $config >> ${hFile}
if [[ $(grep USB_DETECT_PIN $config) ]] ; then
    echo '#define USE_USB_DETECT' >> ${hFile}
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
fi;

# exti
if [[ $(grep "GYRO_[1-2]_EXTI_PIN" $config) ]] ; then
    echo '#define USE_EXTI // notice - REQUIRED when USE_GYRO_EXTI' >> $hFile
    echo '#define USE_GYRO_EXTI' >> $hFile
    echo '' >> ${hFile}
fi
# mpu
if [[ $(grep SPI_MPU $config) ]] ; then
    echo '#define USE_MPU_DATA_READY_SIGNAL' >> ${hFile}
    grep ENSURE_MPU_DATA_READY_IS_LOW $config >> ${hFile}
    echo '' >> ${hFile}
fi

if [[ $(grep -w GYRO_1_ALIGN $config) ]] ; then
    grep -w GYRO_1_ALIGN $config >> ${hFile}  # -w avoid _ALIGN_YAW
    G1_align=$(grep -w GYRO_1_ALIGN $config | awk -F' ' '{print $3}')
else
    G1_align='CW0_DEG' # default
    echo "#define GYRO_1_ALIGN         ${G1_align}" >> ${hFile}
fi
echo "#define ACC_1_ALIGN          ${G1_align}" >> ${hFile}
grep GYRO_1_CS_PIN $config >> ${hFile}
G1_csPin=$(grep -w GYRO_1_CS_PIN $config | awk -F' ' '{print $3}')
grep GYRO_1_EXTI_PIN $config >> ${hFile}
G1_extiPin=$(grep -w GYRO_1_EXTI_PIN $config | awk -F' ' '{print $3}')
grep GYRO_1_SPI_INSTANCE $config >> ${hFile}
G1_spi=$(grep -w GYRO_1_SPI_INSTANCE $config | awk -F' ' '{print $3}')

if [[ $(grep GYRO_1_EXTI_PIN $config) ]] ; then
    echo "#define MPU_INT_EXTI         ${G1_extiPin}" >> $hFile
    # gyro 2 will be gyro_2_, no need for another MPU_INT_EXTI
fi
echo '// notice - GYRO_1_EXTI_PIN and MPU_INT_EXTI may be used interchangeably; there is no other [gyroModel]_EXTI_PIN at this time. (ref: https://github.com/emuflight/EmuFlight/blob/master/src/main/sensors/gyro.c)' >> ${hFile}
echo '' >> ${hFile}

# dual gyro
if [[ $(grep "GYRO_2_" $config) ]] ; then
    echo '#define USE_DUAL_GYRO' >> ${hFile}
    echo '' >> ${hFile}
fi
if [[ $(grep "GYRO_2_" $config) ]] ; then
    translate "DEFAULT_GYRO_TO_USE"  $config "#define GYRO_CONFIG_USE_GYRO_DEFAULT $(grep "DEFAULT_GYRO_TO_USE" $config | awk '{print $3}')" ${hFile}
fi
if [[ $(grep -w GYRO_2_ALIGN $config) ]] ; then
    grep -w GYRO_2_ALIGN $config >> ${hFile}  # -w avoid _ALIGN_YAW
    G2_align=$(grep -w GYRO_2_ALIGN $config | awk -F' ' '{print $3}')
elif [[ $(grep  GYRO_2 $config) ]] ; then
    G2_align='CW0_DEG' # default
    echo "#define GYRO_2_ALIGN         ${G2_align}" >> ${hFile}
fi
if [[ $(grep "GYRO_2_" $config) ]] ; then
    echo "#define ACC_2_ALIGN          ${G2_align}" >> ${hFile}
    grep GYRO_2_CS_PIN $config >> ${hFile}
    grep GYRO_2_EXTI_PIN $config >> ${hFile}
    grep GYRO_2_SPI_INSTANCE $config >> ${hFile}
    echo '' >> ${hFile}
fi

#MPU9250
#define USE_GYRO_SPI_MPU9250
#define USE_ACC_SPI_MPU9250
if [[ $(grep SPI_MPU9250 $config) ]] ; then
    # convert gyro1 > mpu -- this may need changing later
    if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
        echo "#define ACC_MPU9250_ALIGN         ${G1_align}" >> $hFile
        echo "#define GYRO_MPU9250_ALIGN        ${G1_align}" >> $hFile
        echo "#define MPU9250_CS_PIN            ${G1_csPin}" >> $hFile
        echo "#define MPU9250_SPI_INSTANCE      ${G1_spi}"  >> $hFile
    fi
    echo '' >> ${hFile}
fi

# MPU6000
#define USE_ACC_SPI_MPU6000
#define USE_GYRO_SPI_MPU6000
if [[ $(grep SPI_MPU6000 $config) ]] ; then
    # convert gyro1 > mpu -- this may need changing later
    if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
        echo "#define ACC_MPU6000_ALIGN         ${G1_align}" >> $hFile
        echo "#define GYRO_MPU6000_ALIGN        ${G1_align}" >> $hFile
        echo "#define MPU6000_CS_PIN            ${G1_csPin}" >> $hFile
        echo "#define MPU6000_SPI_INSTANCE      ${G1_spi}"  >> $hFile
    fi
    echo '' >> ${hFile}
fi

# MPU6500
#define USE_ACC_SPI_MPU6500
#define USE_GYRO_SPI_MPU6500
if [[ $(grep SPI_MPU6500 $config) ]] ; then
    # convert gyro1 > mpu -- this may need changing later
    if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
        echo "#define ACC_MPU6500_ALIGN         ${G1_align}" >> $hFile
        echo "#define GYRO_MPU6500_ALIGN        ${G1_align}" >> $hFile
        echo "#define MPU6500_CS_PIN            ${G1_csPin}" >> $hFile
        echo "#define MPU6500_SPI_INSTANCE      ${G1_spi}"  >> $hFile
    fi
    echo '' >> ${hFile}
fi

# ICM20689
#define USE_ACC_SPI_ICM20689
#define USE_GYRO_SPI_ICM20689
if [[ $(grep SPI_ICM20689 $config) ]] ; then
    # convert gyro1 > icm -- this may need changing later
    if [[ $(grep GYRO_1_SPI_INSTANCE $config) ]] ; then
        echo "#define ACC_ICM20689_ALIGN         ${G1_align}" >> $hFile
        echo "#define GYRO_ICM20689_ALIGN        ${G1_align}" >> $hFile
        echo "#define ICM20689_CS_PIN            ${G1_csPin}" >> $hFile
        echo "#define ICM20689_SPI_INSTANCE      ${G1_spi}"  >> $hFile
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
        echo "#define ICM42688P_SPI_INSTANCE   ${G1_spi}"  >> $hFile
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
        echo "#define BMI270_SPI_INSTANCE      ${G1_spi}"  >> $hFile
    fi
    echo '' >> ${hFile}
fi

echo '// notice - this file was programmatically generated and may need GYRO_2 manually added.' >> ${hFile}
echo '' >> ${hFile}

## vcp, uarts, softserial
echo "building UART(RX/TX), VCP, and serial-count"
vcpserial=1

hardserial=0
for ((i=1; i<=10; i++)) #only seen 8 in EmuF, saw 10 in BF
do
    if [[ $(grep "UART${i}_[TR]X_PIN" $config) ]] ; then
        echo "#define USE_UART${i}" >> ${hFile}
        grep "UART${i}_[TR]X_PIN" $config >> ${hFile}
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
echo '// notice - UART/USART were programmatically generated - please verify UART/USART.' >> ${hFile}
echo '// notice - may need "#define SERIALRX_UART SERIAL_PORT_USART_"' >> ${hFile}
echo '// notice - for any iterim non-defined TX/RX _PIN, may need to define as NONE and also include any USE_UARTx involved.' >> ${hFile}
echo '// notice - please verify serial count. UARTs defined as NONE may need to be included.' >> ${hFile}
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
    echo 'skipping SPI based RX. please define all RX_SPI_ manually; too complex for automation; ELRS not supported by EmuFlight.'
    echo '// notice - please manually add all SPI based receiver definitions. complexity for these is currently beyond scope of automation.' >> ${hFile}
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
        echo "#define I2C_DEVICE        (I2CDEV_${i})" >> ${hFile}
    fi
    grep I2CDEV_${i} $config >> ${hFile} # duplicates MAG_I2C_INSTANCE
    if [[ $(grep "USE_I2C${i}_PULLUP ON" $config) ]] ; then
        echo "#define I2C${i}_PULLUP true" >> $hFile
    fi
    translate "I2C${i}_OVERCLOCK ON" $config "#define I2C${i}_OVERCLOCK true" ${hFile}
    translate "I2C${i}_SCL_PIN" $config "#define I2C${i}_SCL $(grep "I2C${i}_SCL_PIN" $config | awk '{print          $3}')" ${hFile}
    translate "I2C${i}_SDA_PIN" $config "#define I2C${i}_SDA $(grep "I2C${i}_SDA_PIN" $config | awk '{print          $3}')" ${hFile}
done
echo '// notice - this file was programmatically generated and likely needs MAG/BARO manually added, finished, or verified.' >> ${hFile}
echo '//           e.g. USE_BARO_xxxxxx, USE_BARO_SPI_xxxxxx, DEFAULT_BARO_SPI_xxxxxx, xxxxxx_CS_PIN, xxxxxx_SPI_INSTANCE' >> ${hFile}
echo '//           e.g. BMP280_CS_PIN and BMP280_SPI_INSTANCE instead of BARO_CS_PIN and BARO_SPI_INSTANCE' >> ${hFile}
echo '' >> ${hFile}

## flash
echo "building FLASH"
grep FLASH_CS_PIN $config >> ${hFile}
grep FLASH_SPI_INSTANCE $config >> ${hFile}
translate "BLACKBOX_DEVICE_FLASH" $config '#define ENABLE_BLACKBOX_LOGGING_ON_SPIFLASH_BY_DEFAULT' ${hFile}
echo '' >> ${hFile}

## sdcard
if [[ $(grep USE_SDCARD $config) ]] ; then
    echo "#define USE_SDCARD_SDIO" >> ${hFile}
    grep SDCARD_SPI_CS_PIN $config >> ${hFile}
    grep SDCARD_SPI_INSTANCE $config >> ${hFile}
    spiMosi=$(grep '# SPI_MOSI' ${unified})
    echo "//notice - NEED: #define SDCARD_DMA_CHANNEL          X            //${spiMosi}" >> ${hFile}
    echo "//notice - NEED: #define SDCARD_DMA_CHANNEL_TX       DMAx_StreamX //${spiMosi}" >> ${hFile}
    echo "//notice - other sdcard defines maybe needed (rare?): SDCARD_DMA_STREAM_TX_FULL, SDCARD_DMA_STREAM_TX, SDCARD_DMA_CLK, SDCARD_DMA_CHANNEL_TX_COMPLETE_FLAG" >> ${hFile}
    translate "BLACKBOX_DEVICE_SDCARD" $config "#define ENABLE_BLACKBOX_LOGGING_ON_SDCARD_BY_DEFAULT" ${hFile}
    echo "#define SDCARD_SPI_FULL_SPEED_CLOCK_DIVIDER     4    //notice - needs validation. these are hardware dependent. known options: 2, 4, 8." >> ${hFile}
    echo "#define SDCARD_SPI_INITIALIZATION_CLOCK_DIVIDER 256  //notice - needs validation. these are hardware dependent. known options: 128, 256" >> ${hFile}
    echo '' >> ${hFile}
fi

## gps -- skipping
echo "skipping GPS"

## max7456
echo "building MAX7456"
grep MAX7456_SPI_CS_PIN $config >> ${hFile}
grep MAX7456_SPI_INSTANCE $config >> ${hFile}
echo '' >> ${hFile}

## adc, default voltage/current, scale
echo "building ADC"
if [[ $(grep ADC $config) ]] ; then
    echo '#define USE_ADC' >> ${hFile}
fi
translate "ADC_VBAT_PIN" $config "#define VBAT_ADC_PIN $(grep "ADC_VBAT_PIN" $config | awk '{print          $3}')" ${hFile}
translate "ADC_CURR_PIN" $config "#define CURRENT_METER_ADC_PIN $(grep "ADC_CURR_PIN" $config | awk '{print          $3}')" ${hFile}
translate "ADC_RSSI_PIN" $config "#define RSSI_ADC_PIN $(grep "ADC_RSSI_PIN" $config | awk '{print          $3}')" ${hFile}
grep "ADC[[:digit:]]_DMA_OPT" $config >> ${hFile}
for i in {1..5}
do
    #old commented out
    #translate "ADC${i}_DMA_OPT" $config "#define ADC${i}_DMA_STREAM DMA2_Stream0 // notice - DMA2_Stream0 likely wrong - found in unified-target." ${hFile}
    #translate "ADC ${i}: DMA" $unified "// $(grep "ADC ${i}: DMA" $unified) // notice - use this for above define." ${hFile}
    # format: # ADC 1: DMA2 Stream 0 Channel 0
    adcDmaString=$(grep "ADC ${i}: DMA" $unified)
    if [ ! -z "$adcDmaString" ] ; then
        dma=$(echo "$adcDmaString" | awk -F'DMA' '{print $2}' | awk -F' ' '{print $1}')
        stream=$(echo "$adcDmaString" | awk -F'Stream' '{print $2}' | awk -F' ' '{print $1}')
        echo "#define ADC${i}_DMA_STREAM DMA${dma}_Stream${stream} //${adcDmaString}" >> ${hFile}
        # debug to screen
        #echo "$adcDmaString"
        #echo "#define ADC${i}_DMA_STREAM DMA${dma}_Stream${stream} //${adcDmaString}"
    fi

done
echo ' - please verify ADC DMA Streams.'
grep "DEFAULT_VOLTAGE_METER_SOURCE" $config >> ${hFile}
grep "DEFAULT_CURRENT_METER_SOURCE" $config >> ${hFile}
grep DEFAULT_CURRENT_METER_SCALE $config >> ${hFile}
grep ADC_INSTANCE $config >> ${hFile}
echo '// notice - DMA conversion were programmatically generated and may be incomplete.' >> ${hFile}
echo '' >> ${hFile}

## dshot
echo "building DMAR"
translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_ON" $config "#define ENABLE_DSHOT_DMAR true" ${hFile}
#translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_AUTO" $config "#define ENABLE_DSHOT_DMAR true" ${hFile}

## esc serial timer
echo "building ESC"
if [[ $(grep ESCSERIAL $config) ]] ; then
    echo '#define USE_ESCSERIAL' >> ${hFile}
    translate "ESCSERIAL_PIN" $config "#define ESCSERIAL_TIMER_TX_PIN $(grep "ESCSERIAL_PIN" $config | awk '{print          $3}')" ${hFile}
fi
echo '' >> ${hFile}

# pinio
echo "building PINIO"
if [[ $(grep 'PINIO[0-9]_' $config >> ${hFile}) ]] ; then
    echo '#define USE_PINIOBOX' >> $hFile
    echo '' >> $hFile
fi

echo "building misc/inverted"

# inverted sdcard
grep SDCARD_DETECT_INVERTED $config >> ${hFile}

# inverted button
grep "BUTTON_[AB]_PIN_INVERTED" $config >> ${hFile}

echo '// notice - this file was programmatically generated and may not have accounted for any config instance of "#define TLM_INVERTED ON", etc.' >> ${hFile}
echo '' >> ${hFile}

# port masks
echo "building port masks"
if [[ $(grep ' PA[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTA 0xffff' >> ${hFile}
fi
if [[ $(grep ' PB[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTB 0xffff' >> ${hFile}
fi
if [[ $(grep ' PB[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTC 0xffff' >> ${hFile}
fi
if [[ $(grep ' PD[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTD 0xffff' >> ${hFile}
fi
if [[ $(grep ' PE[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTE 0xffff' >> ${hFile}
fi
if [[ $(grep ' PF[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTF 0xffff' >> ${hFile}
fi
if [[ $(grep ' PG[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTG 0xffff' >> ${hFile}
fi
if [[ $(grep ' PH[0-9]' $config) ]]; then
    echo '#define TARGET_IO_PORTH 0xffff' >> ${hFile}
fi
echo '// notice - masks were programmatically generated - please verify last port group for 0xffff or (BIT(2))' >> ${hFile}
echo '' >> ${hFile}

echo "building static default FEATURES"
echo " - please modify as fit."
echo "#define DEFAULT_FEATURES       (FEATURE_OSD | FEATURE_TELEMETRY | FEATURE_AIRMODE | ${featureRX})" >> ${hFile}
echo "#define DEFAULT_RX_FEATURE     ${featureRX}" >> ${hFile}
echo '// notice - potentially incomplete; may need additional DEFAULT_FEATURES; e.g. FEATURE_SOFTSERIAL | FEATURE_RX_SPI' >> ${hFile}
echo '// notice - may need "#define DEFAULT_RX_FEATURE, SERIALRX_PROVIDER' >> ${hFile}
echo '' >> ${hFile}

# used timers
echo "building USED_TIMERS"
usedTimers=''
for i in {1..20}
do
    if [[ $(grep "TIM${i} CH" $unified) ]] ; then
        if ! [[ $usedTimers == '' ]] ; then
            usedTimers+="|"
        fi
        usedTimers+=" TIM_N(${i}) "
    fi
done
echo "#define USABLE_TIMER_CHANNEL_COUNT $(grep -c 'TIMER_PIN_MAP(' ${config} )" >> ${hFile}
# to do: logic
echo "#define USED_TIMERS (${usedTimers})" >> ${hFile}
echo '// notice - USED_TIMERS were programmatically generated from unified-target and may be incomplete.' >> ${hFile}
echo '' >> ${hFile}

echo '// notice - this file was programmatically generated and may be incomplete.' >> ${hFile}

echo 'cleaning files'
sed '/"TODO"/d' -i ${hFile}
awk -i inplace '!(NF && seen[$0]++)' ${hFile} # deduplicate, but skip empty lines

echo ''
echo 'Task finished. No guarantees; Definitions are likely incomplete.'
echo 'Please search the resultant files for the keyword "notice" to rectify any needs.'
echo 'Please cleanup target files before Pull-Requesting.'
echo ''
echo "Folder: ${dest}"
ls -lh "${dest}"
