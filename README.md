# EmuFlight target conversion script

* This BASH script is a Work-In-Progress.  It downloads and processes target definitions from [Betaflight/config](https://github.com/betaflight/config) and [Betaflight/unified-targets](https://github.com/betaflight/unified-targets) in attempt to convert to EmuFlight targets.  Although functional, it does not account for every combination and still requires human modification to resultant files.

#### Prerequisites:
* `sudo apt install grep gawk sed coreutils findutils wget git`

#### Clone the repo:
* `git clone https://github.com/nerdCopter/target-convert.git`

#### Make the script executable:
* `cd target-convert`
* `chmod +x ./convert.sh`

#### Parameters:
* This BASH script expect two parameters:
  * [unified-target-name] in the format `VEND-TARGETNAME`. (Note the hyphen! Underscore will not work.)
  * [destination-folder] in POSIX path format.

#### Examples:
* `./convert.sh DIAT-MAMBAF405_2022B ./`
* `./convert.sh TURC-TUNERCF405 ./temp`
* `./convert.sh SPBE-SPEEDYBEE_F745_AIO ../EmuFlight/src/main/target/`

#### Outputs:
* Creates a target-folder in the format `VEND_TARGETNAME` containing `target.mk`, `target.c`, `target.h`.
* This folder also contains a sub-folder named `resources` which containing downloads and other output.

#### How to compile:
* Copy or move the new target folder to your EmuFlight's `./src/main/target/` folder.
* Review and modify the `target.*` files as needed in a text-editor.
* Compile and test the new target:
  * `make VEND_TARGETNAME`, where VEND_TARGETNAME is the new target name. (Note the first underscore! Hyphen will not work.)
    * examples: `make TURC_TUNERCF405`, `make SPBE_SPEEDYBEE_F745_AIO`.

#### Pull-Requests to EmuFlight:
* When making Pull-Requests to EmuFlight, do not include the `resources` sub-folder folder nor its contents. PR's should only include `VEND_TARGETNAME/target.*`.
* Remove all unnecessary comments from the target files.
