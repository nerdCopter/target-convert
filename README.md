# EmuFlight target conversion script

* This BASH script is a Work-In-Progress.  It processes target definitions from [Betaflight/config](https://github.com/betaflight/config) and [Betaflight/unified-targets](https://github.com/betaflight/unified-targets) in attempt to convert to EmuFlight targets.  Although functional, it does not account for every combination and still requires human modification to resultant files.

#### Clone the repo 
* git clone https://github.com/nerdCopter/target-convert.git

#### Make the script executable 
* `cd target-convert`
* `chmod +x ./convert.sh`

#### Example Usage:
* parameters are [unified-target-name] in format `VEND-TARGETNAME` and [destination-folder] in POSIX path format.
* `./convert.sh DIAT-MAMBAF405_2022B ./temp`
* `./convert.sh TURC-TUNERCF405 ./`
* `./convert.sh SPBE-SPEEDYBEE_F745_AIO ../EmuFlight/src/main/target/`

#### Output
* Target-folder containing `target.mk`, `target.c`, `target.h`.
* A sub-folder containing downloaded resources.
* When building targets or making pull-request, do not include the resultant `resources` sub-folder folder.
