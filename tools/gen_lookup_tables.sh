#!/bin/bash
# gen_lookup_tables.sh - Generate lookup TSV files from Betaflight codebase.
# Run from target-convert/ root:
#   tools/gen_lookup_tables.sh <path-to-betaflight-repo>
# Example:
#   tools/gen_lookup_tables.sh ~/SYNC/nerdCopter-GIT/betaflight
#
# Outputs (written to lookup/):
#   f4_timer_hw.tsv       pin + occurrence -> TIM + CH  (STM32F405/F446)
#   f7_timer_hw.tsv       pin + occurrence -> TIM + CH  (STM32F7x2/F745/F765)
#   h7_timer_hw.tsv       pin + occurrence -> TIM + CH  (STM32H7xx)
#   f4f7_dma_timer.tsv    TIM + CH + opt   -> DMA ctrl/stream/channel
#   f4f7_dma_adc.tsv      ADC dev + opt    -> DMA ctrl/stream/channel
#   f4f7_dma_spi.tsv      SPI dev + dir + opt -> DMA ctrl/stream/channel

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path-to-betaflight-repo>"
    exit 1
fi

BF="$1"
DRIVERS="$BF/src/main/drivers/stm32"
OUT="$(dirname "$0")/../lookup"

if [[ ! -d "$DRIVERS" ]]; then
    echo "Error: $DRIVERS not found. Is $BF a Betaflight repo?"
    exit 1
fi

mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# Helper: parse timer_stm32<mcu>xx.c fullTimerHardware table into TSV
# Format: pin  occurrence  TIM  CH
# ---------------------------------------------------------------------------
parse_timer_hw () {
    local infile="$1"
    local outfile="$2"
    echo "# Generated from $(basename $infile)" > "$outfile"
    echo "# pin	occurrence	TIM	CH" >> "$outfile"

    # Track occurrence count per pin
    declare -A occ
    grep 'DEF_TIM(' "$infile" | grep -v '^\s*//' | \
    sed 's/.*DEF_TIM(\s*//' | \
    while IFS= read -r line; do
        # Extract: TIMx, CHy, Pnn
        tim=$(echo "$line"  | awk -F',' '{gsub(/[ \t]/,""); print $1}')
        ch=$(echo "$line"   | awk -F',' '{gsub(/[ \t]/,""); print $2}')
        pin=$(echo "$line"  | awk -F',' '{gsub(/[ \t]/,""); print $3}')
        key="${pin}"
        occ[$key]=$(( ${occ[$key]:-0} + 1 ))
        printf "%s\t%d\t%s\t%s\n" "$pin" "${occ[$key]}" "$tim" "$ch"
    done >> "$outfile"
    echo "  -> $outfile"
}

echo "Parsing timer hardware tables..."
parse_timer_hw "$DRIVERS/timer_stm32f4xx.c" "$OUT/f4_timer_hw.tsv"
parse_timer_hw "$DRIVERS/timer_stm32f7xx.c" "$OUT/f7_timer_hw.tsv"
parse_timer_hw "$DRIVERS/timer_stm32h7xx.c" "$OUT/h7_timer_hw.tsv"

# ---------------------------------------------------------------------------
# parse_dma_section: extract a { PERIPH, dev, { DMA(c,s,ch)... } } table
# between two line markers in dma_reqmap_mcu.c, filter by a grep pattern.
# Usage: parse_dma_section <infile> <start_pat> <end_pat> <grep_pat> <awk_fmt>
# awk_fmt fields referenced as $1=matched groups from the outer sed
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Parse dma_reqmap_mcu.c F4/F7 dmaTimerMapping block
# Lines: from "static const dmaTimerMapping_t dmaTimerMapping" (after F4 marker)
#        to   "#undef TC"
# Format: TIM  CH  opt  ctrl  stream  channel
# ---------------------------------------------------------------------------
echo "Parsing F4/F7 DMA timer mapping..."
{
    echo "# Generated from dma_reqmap_mcu.c (STM32F4/F7 block)"
    printf "# TIM\tCH\topt\tctrl\tstream\tchannel\n"
    # Extract the F4/F7 dmaTimerMapping block by line numbers
    start=$(grep -n "static const dmaTimerMapping_t dmaTimerMapping" "$DRIVERS/dma_reqmap_mcu.c" | tail -1 | cut -d: -f1)
    end=$(awk -v s="$start" 'NR>s && /^#undef TC/{print NR; exit}' "$DRIVERS/dma_reqmap_mcu.c")
    sed -n "${start},${end}p" "$DRIVERS/dma_reqmap_mcu.c" | \
    grep '{ TIM[0-9]' | \
    sed 's/.*{ TIM\([0-9]*\), TC(CH\([0-9]*\)), { \(.*\) } }.*/\1 \2 \3/' | \
    while read -r tim ch dmas; do
        opt=0
        # split on ), DMA(
        echo "$dmas" | tr ',' '\n' | grep -o '[0-9]*' | paste - - - | \
        while read -r ctrl stream channel; do
            printf "TIM%s\tCH%s\t%d\t%s\t%s\t%s\n" "$tim" "$ch" "$opt" "$ctrl" "$stream" "$channel"
            opt=$(( opt + 1 ))
        done
    done
} > "$OUT/f4f7_dma_timer.tsv"
echo "  -> $OUT/f4f7_dma_timer.tsv"

# ---------------------------------------------------------------------------
# Parse F4/F7 dmaPeripheralMapping - ADC entries
# Format: ADCdev  opt  ctrl  stream  channel
# ---------------------------------------------------------------------------
echo "Parsing F4/F7 DMA ADC mapping..."
{
    echo "# Generated from dma_reqmap_mcu.c (STM32F4/F7 block)"
    printf "# ADCdev\topt\tctrl\tstream\tchannel\n"
    start=$(grep -n "static const dmaPeripheralMapping_t dmaPeripheralMapping" "$DRIVERS/dma_reqmap_mcu.c" | tail -1 | cut -d: -f1)
    end=$(awk -v s="$start" 'NR>s && /^\};/{print NR; exit}' "$DRIVERS/dma_reqmap_mcu.c")
    sed -n "${start},${end}p" "$DRIVERS/dma_reqmap_mcu.c" | \
    grep 'DMA_PERIPH_ADC.*ADCDEV_' | \
    sed 's/.*ADCDEV_\([0-9]*\),\s*{ \(.*\) }.*/\1 \2/' | \
    while read -r dev dmas; do
        opt=0
        echo "$dmas" | tr ',' '\n' | grep -o '[0-9]*' | paste - - - | \
        while read -r ctrl stream channel; do
            printf "%s\t%d\t%s\t%s\t%s\n" "$dev" "$opt" "$ctrl" "$stream" "$channel"
            opt=$(( opt + 1 ))
        done
    done
} > "$OUT/f4f7_dma_adc.tsv"
echo "  -> $OUT/f4f7_dma_adc.tsv"

# ---------------------------------------------------------------------------
# Parse F4/F7 dmaPeripheralMapping - SPI entries
# Format: SPIdev  dir  opt  ctrl  stream  channel
# (Use the common, non-F7x5-specific lines only: SPI1-3 are F405/F7x2 safe)
# ---------------------------------------------------------------------------
echo "Parsing F4/F7 DMA SPI mapping..."
{
    echo "# Generated from dma_reqmap_mcu.c (STM32F4/F7 block)"
    printf "# SPIdev\tdir\topt\tctrl\tstream\tchannel\n"
    start=$(grep -n "static const dmaPeripheralMapping_t dmaPeripheralMapping" "$DRIVERS/dma_reqmap_mcu.c" | tail -1 | cut -d: -f1)
    end=$(awk -v s="$start" 'NR>s && /^\};/{print NR; exit}' "$DRIVERS/dma_reqmap_mcu.c")
    sed -n "${start},${end}p" "$DRIVERS/dma_reqmap_mcu.c" | \
    grep 'DMA_PERIPH_SPI_SD[OI].*SPIDEV_' | grep -v 'if defined\|F411\|F745\|F746\|F765\|F722\|EXTENDED' | \
    sed 's/.*SPI_SD\([OI]\),\s*SPIDEV_\([0-9]*\),\s*{ \(.*\) }.*/\1 \2 \3/' | \
    while read -r dir dev dmas; do
        opt=0
        echo "$dmas" | tr ',' '\n' | grep -o '[0-9]*' | paste - - - | \
        while read -r ctrl stream channel; do
            printf "%s\t%s\t%d\t%s\t%s\t%s\n" "$dev" "$dir" "$opt" "$ctrl" "$stream" "$channel"
            opt=$(( opt + 1 ))
        done
    done
} > "$OUT/f4f7_dma_spi.tsv"
echo "  -> $OUT/f4f7_dma_spi.tsv"

echo ""
echo "Done. Tables written to $OUT/"
ls -lh "$OUT/"
