#!/bin/bash

# EmuFlight definition converter.
# 2023 July - nerdCopter
# Partially Converts betaflight config.h files to EmuFlight .mk .c .h files.
# Open to receiving more efficient and elegant code.
# July 2023 revision requires Internet connection for autmated definitions download.

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

# old
# manufacturer="$(grep MANUFACTURER_ID $config | awk -F' ' '{print $3}')"
# board="$(grep BOARD_NAME $config | awk -F' ' '{print $3}')"
# new
manufacturer=$(echo ${1} | awk -F'-' '{print $1}')
board=$(echo ${1} | awk -F'-' '{print $2}')
fc="${manufacturer}_${board}"
dest="${2}/${fc}"

echo "creating ${fc}"
mkdir ${dest} 2> /dev/null

echo "downloading..."
wget -c -N -nv -P ${dest} "https://github.com/betaflight/config/raw/master/configs/${board}/config.h" || { echo "download failed" ; rm -r ${dest} ; exit 1 ; }
wget -c -N -nv -P ${dest} "https://github.com/betaflight/unified-targets/raw/master/configs/default/${1}.config" || { echo "download failed" ; rm -r ${dest} ; exit 1 ; }

#config="${1}"
config="${dest}/config.h"
unified="${dest}/${1}.config"

echo "config.h: ${config}"
echo "unified: ${unified}"

mkFile="${dest}/target.mk"
cFile="${dest}/target.c"
hFile="${dest}/target.h"

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

if [[ $(grep STM32F405 $config) ]]; then
    echo 'F405_TARGETS   += $(TARGET)' > ${mkFile}
elif [[ $(grep STM32F411 $config) ]]; then
    echo 'F411_TARGETS   += $(TARGET)' > ${mkFile}
elif [[ $(grep STM32F446 $config) ]]; then
    echo 'F446_TARGETS   += $(TARGET)' > ${mkFile}
elif [[ $(grep STM32F7X2 $config) ]]; then
    echo 'F7X5XG_TARGETS += $(TARGET)' > ${mkFile}
elif [[ $(grep STM32F745 $config) ]]; then
    echo 'F7X2RE_TARGETS += $(TARGET)' > ${mkFile}
else
  echo 'not an F4 nor an F7. exiting.'
  exit
fi

# enable flash and drivers
echo 'FEATURES       += VCP ONBOARDFLASH' >> ${mkFile}
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

translate MPU ${config} 'drivers/accgyro/accgyro_mpu.c \' ${mkFile}

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
# drivers/barometer/barometer.h
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

# skipping compass
echo 'skipping any compass; please manually modify target.mk if necessary.'
# emuflight src/main/target
# drivers/compass/compass_ak8963.c \
# drivers/compass/compass_ak8975.c \
# drivers/compass/compass_hmc5883l.c \
# drivers/compass/compass_lis3mdl.c \
# drivers/compass/compass_qmc5883l.c \

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

echo '' >> ${mkFile}
echo '# notice - this file was programmatically generated and may be incomplete.' >> ${mkFile}
echo '#  eg: flash, compass, barometer, vtx6705, ledstrip, pinio, etc.' >> ${mkFile}

# create target.c file

echo "${license}" > ${cFile}

echo '#include <stdint.h>' >> ${cFile}
echo '#include "platform.h"' >> ${cFile}
echo '#include "drivers/io.h"' >> ${cFile}
echo '#include "drivers/dma.h"' >> ${cFile}
echo '#include "drivers/timer.h"' >> ${cFile}
echo '#include "drivers/timer_def.h"' >> ${cFile}
echo ''  >> ${cFile}
echo 'const timerHardware_t timerHardware[USABLE_TIMER_CHANNEL_COUNT] = {' >> ${cFile}
echo '/* notice - incomplete */'  >> ${cFile}
echo '// format : DEF_TIM(TIMxx, CHx, Pxx, TIM_USE_xxxxxxx, 0, x), //comment' >> ${cFile}
echo '};' >> ${cFile}
echo '' >> ${cFile}

echo "not converting timers: target.c needs user translation from unified-targets. please reference associated unified-target."

echo '// TIM_USE options:' >> ${cFile}
echo '// TIM_USE_ANY' >> ${cFile}
echo '// TIM_USE_BEEPER' >> ${cFile}
echo '// TIM_USE_LED' >> ${cFile}
echo '// TIM_USE_MOTOR' >> ${cFile}
echo '// TIM_USE_NONE' >> ${cFile}
echo '// TIM_USE_PPM' >> ${cFile}
echo '// TIM_USE_PWM' >> ${cFile}
echo '// TIM_USE_SERVO' >> ${cFile}
echo '// TIM_USE_TRANSPONDER' >> ${cFile}
echo '' >> ${cFile}

echo '// config.h timers' >> ${cFile}
grep "MOTOR[[:digit:]]\+_PIN" $config | xargs -d'\n' --replace echo "// {}" >> ${cFile}
grep TIMER_PIN_MAP $config | xargs -d'\n' --replace echo "// {}" >> ${cFile}
echo ''  >> ${cFile}
echo '// unified timers' >> ${cFile}
echo '//# timer' >> ${cFile}
grep -A1 'timer ' $unified | xargs -d'\n' --replace echo "// {}" >> ${cFile}
grep -A1 'dma pin ' $unified | xargs -d'\n' --replace echo "// {}" >> ${cFile}

echo '' >> ${cFile}
echo '// notice - this file was programmatically generated and may be incomplete.' >> ${cFile}
echo '// recommend converting timers from unified-target; however, unified-targets will be sunsetted.' >> ${cFile}

# create target.h file

echo "${license}" > ${hFile}
echo '#pragma once' >> ${hFile}
echo '' >> ${hFile}

translate MANUFACTURER_ID $config "#define TARGET_BOARD_IDENTIFIER \"$(grep MANUFACTURER_ID $config | awk '{print $3}')\"" ${hFile}
translate BOARD_NAME $config "#define USBD_PRODUCT_STRING \"$(grep BOARD_NAME $config | awk '{print $3}')\"" ${hFile}
echo '' >> ${hFile}

# all the USE_ includes acc, gyro, flash, max, etc
grep USE_ $config >> ${hFile}
echo '' >> ${hFile}
echo '#define USE_VCP'  >> ${hFile}
if [[ $(grep USE_FLASH $config) ]] ; then
    echo '#define USE_FLASHFS' >> ${hFile}
    echo '#define USE_FLASH_M25P16  //testing' >> ${hFile}
    echo '#define USE_FLASH_W25M    //testing' >> ${hFile}
    echo '#define USE_FLASH_W25M512 //testing' >> ${hFile}
    echo '#define USE_FLASH_W25Q    //testing' >> ${hFile}
fi
if [[ $(grep USE_MAX7456 $config) ]] ; then
    echo '#define USE_OSD' >> ${hFile}
fi

echo '' >> ${hFile}

# led
if [[ $(grep LED[0-9]_PIN $config) ]] ; then
    echo '#define USE_LED' >> ${hFile}
fi
grep "LED[0-9]_PIN" $config >> ${hFile}

if [[ $(grep LED_STRIP_PIN $config >> ${hFile}) ]] ; then
    echo '#define USE_LED_STRIP' >> ${hFile}
fi

# beeper cam-control
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
if [[ $(grep SPI $config) ]] ; then
    echo '#define USE_SPI' >> ${hFile}
fi

for i in {1..6}
do
    if [[ $(grep "SPI${i}_" $config) ]] ; then
        echo "#define USE_SPI_DEVICE_${i}"  >> ${hFile}
    fi
    grep SPI${i}_SCK_PIN $config >> ${hFile}
    translate SPI${i}_SDI_PIN $config "#define SPI${i}_MISO_PIN        $(grep SPI${i}_SDI_PIN $config | awk '{print $3}')" ${hFile}
    translate SPI${i}_SDO_PIN $config "#define SPI${i}_MOSI_PIN        $(grep SPI${i}_SDO_PIN $config | awk '{print $3}')" ${hFile}
done
echo '' >> ${hFile}

# gyro defines
if [[ $(grep -w GYRO_1_ALIGN $config) ]] ; then
    grep -w GYRO_1_ALIGN $config >> ${hFile}  # -w avoid _ALIGN_YAW
    G1_align=$(grep -w GYRO_1_ALIGN $config | awk -F'GYRO_1_ALIGN' '{print $2}')
else
    echo '#define GYRO_1_ALIGN         CW0_DEG' >> ${hFile}
    G1_align='CW0_DEG'
fi
echo "#define ACC_1_ALIGN          ${G1_align}" >> ${hFile}
grep GYRO_1_CS_PIN $config >> ${hFile}
G1_csPin=$(grep -w GYRO_1_CS_PIN $config | awk -F'GYRO_1_CS_PIN' '{print $2}')
grep GYRO_1_EXTI_PIN $config >> ${hFile} && echo '// notice - GYRO_1_EXTI_PIN and MPU_INT_EXTI may be used interchangeably; there is no other [gyroModel]_EXTI_PIN'  >> ${hFile}
G1_extiPin=$(grep -w GYRO_1_EXTI_PIN $config | awk -F'GYRO_1_EXTI_PIN' '{print $2}')
grep GYRO_1_SPI_INSTANCE $config >> ${hFile}
G1_spi=$(grep -w GYRO_1_SPI_INSTANCE $config | awk -F'GYRO_1_SPI_INSTANCE' '{print $2}')

if [[ $(grep GYRO_1_EXTI_PIN $config) ]] ; then
    echo "#define MPU_INT_EXTI         ${G1_extiPin}" >> $hFile
    # gyro 2 will be gyro_2_, no need for another MPU_INT_EXTI
fi
echo '' >> ${hFile}

# dual gyro
if [[ $(grep -w GYRO_2_ALIGN $config) ]] ; then
    grep -w GYRO_2_ALIGN $config >> ${hFile}  # -w avoid _ALIGN_YAW
elif [[ $(grep "GYRO_2_" $config) ]] ; then
    echo '#define GYRO_2_ALIGN         CW0_DEG' >> ${hFile}
fi
if [[ $(grep "GYRO_2_" $config) ]] ; then
    echo '#define ACC_2_ALIGN      GYRO_2_ALIGN' >> ${hFile}
fi
grep GYRO_2_CS_PIN $config >> ${hFile}
grep GYRO_2_EXTI_PIN $config >> ${hFile}
grep GYRO_2_SPI_INSTANCE $config >> ${hFile}
echo '' >> ${hFile}

# dual gyro
if [[ $(grep "GYRO_2_" $config) ]] ; then
    echo '#define USE_DUAL_GYRO' >> ${hFile}
    echo '' >> ${hFile}
fi

# exti
if [[ $(grep "GYRO_[1-2]_EXTI_PIN" $config) ]] ; then
    echo '#define USE_EXTI' >> $hFile
    echo '//#define USE_GYRO_EXTI' >> $hFile
    echo '// notice - USE_GYRO_EXTI validity unknown at this time' >> $hFile
    echo '' >> ${hFile}
fi

# mpu
if [[ $(grep SPI_MPU $config) ]] ; then
    echo '#define USE_MPU_DATA_READY_SIGNAL' >> ${hFile}
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
        echo "#define MPU6000_SPI_INSTANCE      ${G1_spi}"   >> $hFile
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
        echo "#define MPU6500_SPI_INSTANCE      ${G1_spi}"   >> $hFile
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
        echo "#define ICM20689_SPI_INSTANCE      ${G1_spi}"   >> $hFile
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
        echo "#define ICM42688P_SPI_INSTANCE   ${G1_spi}"   >> $hFile
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
        echo "#define BMI270_SPI_INSTANCE      ${G1_spi}"   >> $hFile
    fi
    echo '' >> ${hFile}
fi

echo '// notice - this file was programmatically generated and may need GYRO_2 manually added.' >> ${hFile}
echo '' >> ${hFile}

# i2c/baro/mag/etc
grep -w MAG_ALIGN $config >> ${hFile}
grep MAG_I2C_INSTANCE $config >> ${hFile}
if [[ $(grep I2C $config) ]] ; then
    echo '#define USE_I2C' >> ${hFile}
fi
if [[ $(grep "USE_I2C[0-4]_PULLUP" $config) ]] ; then
    echo '#define USE_I2C_PULLUP' >> $hFile
fi
for i in {1..4}
do
    if [[ $(grep "I2C${i}_" $config) ]] ; then
        echo "#define USE_I2C_DEVICE_${i}"  >> ${hFile}
        echo "#define I2C_DEVICE        (I2CDEV_${i})"  >> ${hFile}
    fi
    grep I2CDEV_${i} $config >> ${hFile}
    if [[ $(grep "USE_I2C${i}_PULLUP ON" $config) ]] ; then
        echo "#define I2C${i}_PULLUP true" >> $hFile
    fi
    translate "I2C${i}_OVERCLOCK ON" $config "#define I2C${i}_OVERCLOCK true" ${hFile}
    translate "I2C${i}_SCL_PIN" $config "#define I2C${i}_SCL $(grep "I2C${i}_SCL_PIN" $config | awk '{print          $3}')" ${hFile}
    translate "I2C${i}_SDA_PIN" $config "#define I2C${i}_SDA $(grep "I2C${i}_SDA_PIN" $config | awk '{print          $3}')" ${hFile}
done
echo '// notice - this file was programmatically generated and likely needs MAG/BARO manually added and/or verified.' >> ${hFile}
echo '' >> ${hFile}

## flash
grep FLASH_CS_PIN $config >> ${hFile}
grep FLASH_SPI_INSTANCE $config >> ${hFile}
translate "BLACKBOX_DEVICE_FLASH" $config '#define ENABLE_BLACKBOX_LOGGING_ON_SPIFLASH_BY_DEFAULT' ${hFile}
echo '' >> ${hFile}

## gps -- skipping

## max7456
grep MAX7456_SPI_CS_PIN $config >> ${hFile}
grep MAX7456_SPI_INSTANCE $config >> ${hFile}
echo '' >> ${hFile}

## vcp, uarts, softserial
vcpserial=1
hardserial=$(grep "UART[[:digit:]]\+_TX_PIN" $config | wc -l)
softserial=$(grep "SOFTSERIAL[[:digit:]]_TX_PIN" $config | wc -l )
totalserial=$(expr $hardserial + $softserial)
for ((i=1; i<=${totalserial}; i++))
do
    echo "#define USE_UART${i}" >> ${hFile}
done
grep "UART[[:digit:]]\+_TX_PIN" $config >> ${hFile}
grep "UART[[:digit:]]\+_RX_PIN" $config >> ${hFile}
grep "SOFTSERIAL[[:digit:]]_TX_PIN" $config >> ${hFile}
grep "SOFTSERIAL[[:digit:]]_RX_PIN" $config >> ${hFile}
for ((i=1; i<=${softserial}; i++))
do
    echo "#define USE_SOFTSERIAL{$i}" >> ${hFile}
done
grep 'RX_PPM_PIN' $config >> ${hFile}
grep "INVERTER_PIN_UART" $config >> ${hFile}
grep "USART" $config >> ${hFile}
echo "#define SERIAL_PORT_COUNT $(expr $vcpserial + $totalserial)"  >> ${hFile}
echo '// notice - UART/USART were programmatically generated - should verify UART/USART.' >> ${hFile}
echo '// notice - may need "#define SERIALRX_UART SERIAL_PORT_USART_"' >> ${hFile}
echo '// notice - may need "#define DEFAULT_RX_FEATURE, SERIALRX_PROVIDER' >> ${hFile}
echo '// notice - should verify serial count.' >> ${hFile}
echo '' >> ${hFile}

# RX SPI & inverted RX SPI LED
grep "RX_SPI_EXTI_PIN" $config >> ${hFile}
if [[ $(grep RX_SPI_LED_INVERTED $config) ]] ; then
    echo '#define RX_CC2500_SPI_LED_PIN_INVERTED' >> $hFile
    echo '#define RX_FRSKY_SPI_LED_PIN_INVERTED' >> $hFile
    echo '// notice - this needs to be verified' >> $hFile
    echo '' >> $hFile
fi

## adc, default voltage/current, scale
translate "ADC_VBAT_PIN" $config "#define VBAT_ADC_PIN $(grep "ADC_VBAT_PIN" $config | awk '{print          $3}')" ${hFile}
translate "ADC_CURR_PIN" $config "#define CURRENT_METER_ADC_PIN $(grep "ADC_CURR_PIN" $config | awk '{print          $3}')" ${hFile}
translate "ADC_RSSI_PIN" $config "#define RSSI_ADC_PIN $(grep "ADC_RSSI_PIN" $config | awk '{print          $3}')" ${hFile}
for i in {1..4}
do
    translate "ADC${i}_DMA_OPT" $config "#define ADC${i}_DMA_STREAM DMA2_Stream0 // notice - DMA2_Stream0 likely wrong - found in unified-target." ${hFile}
    translate "ADC ${i}: DMA" $unified "// $(grep "ADC ${i}: DMA" $unified) // notice - use this for above define." ${hFile}
done
grep "DEFAULT_VOLTAGE_METER_SOURCE" $config >> ${hFile}
grep "DEFAULT_CURRENT_METER_SOURCE" $config >> ${hFile}
grep DEFAULT_CURRENT_METER_SCALE $config >> ${hFile}
grep ADC_INSTANCE $config >> ${hFile}
echo '// notice - DMA conversions incomplete - needs human modifications. e.g. ADC_INSTANCE, ADC3_DMA_OPT, etc.'  >> ${hFile}
echo '' >> ${hFile}

## dshot
translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_ON" $config "#define ENABLE_DSHOT_DMAR true" ${hFile}
#translate "DEFAULT_DSHOT_BURST DSHOT_DMAR_AUTO" $config "#define ENABLE_DSHOT_DMAR true" ${hFile}

## esc serial timer
if [[ $(grep ESCSERIAL $config) ]] ; then
    echo '#define USE_ESCSERIAL' >> ${hFile}
    translate "ESCSERIAL_PIN" $config "#define ESCSERIAL_TIMER_TX_PIN $(grep "ESCSERIAL_PIN" $config | awk '{print          $3}')" ${hFile}
fi
echo ''  >> ${hFile}

# pinio
if [[ $(grep 'PINIO[0-9]_' $config >> ${hFile}) ]] ; then
    echo '' >> $hFile
fi

# inverted sdcard
grep SDCARD_DETECT_INVERTED $config >> ${hFile}

# inverted button
grep "BUTTON_[AB]_PIN_INVERTED" $config >> ${hFile}

echo '// notice - this file was programmatically generated and may not have accounted for any config instance of "#define TLM_INVERTED ON", etc.' >> ${hFile}
echo ''  >> ${hFile}

# port masks
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
echo '// notice - masks were programmatically generated - must verify last port group for 0xffff or (BIT(2))'  >> ${hFile}
echo '' >> ${hFile}

echo '#define DEFAULT_FEATURES       (FEATURE_OSD | FEATURE_TELEMETRY | FEATURE_AIRMODE | FEATURE_RX_SERIAL)' >> ${hFile}
echo '#define DEFAULT_RX_FEATURE     FEATURE_RX_SERIAL' >> ${hFile}
echo '// notice - incomplete; may need additional DEFAULT_FEATURES; e.g. FEATURE_SOFTSERIAL | FEATURE_RX_SPI' >> ${hFile}
echo '' >> ${hFile}

echo "#define USABLE_TIMER_CHANNEL_COUNT $(grep -c 'TIMER_PIN_MAP(' ${config} )" >> ${hFile}
# to do: logic
echo '#define USED_TIMERS ( TIM_N(x) | TIM_N(x) | TIM_N(x) | TIM_N(x) | TIM_N(x) )' >> ${hFile}
echo '// notice - incomplete. add/remove/replace x' >> ${hFile}
echo '' >> ${hFile}
echo 'Please modify USED_TIMERS in .h file'

echo '// notice - this file was programmatically generated and may be incomplete.' >> ${hFile}

echo 'cleaning files'
sed '/"TODO"/d' -i ${hFile}

echo 'Task finished. No guarantees; Definitions are likely incomplete.'
echo 'Please search the resultant files for the keyword "notice" to rectify any needs.'
echo "Folder: ${dest}"
ls -lh "${dest}"
