#!/bin/bash -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
EDL=$DIR/edl/edl

echo "Enter your computer password if prompted"

if [[ ! -f  $EDL ]]; then
  echo "Installing edl..."
  {
    git clone https://github.com/bkerler/edl
    cd $DIR/edl
    git fetch --all
    git checkout 81d30c9039faf953881d38013ced01d1a06429db
    git submodule update --depth=1 --init --recursive
    pip3 install -r requirements.txt

    cd $DIR
  } &> /dev/null
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Installing libusb for macOS..."
  {
    brew install libusb git
    ln -s /opt/homebrew/lib ~/lib
  } &> /dev/null
fi


echo "Getting active slot..."
CURRENT_SLOT="$($EDL getactiveslot 2>&1 | grep "Current active slot:" | cut -d ':' -f2- | sed 's/[[:blank:]]//g')"
BOOT_LUN=""
if [ "$CURRENT_SLOT" == "a" ]; then
  NEW_SLOT="b"
  BOOT_LUN="2"
elif [ "$CURRENT_SLOT" == "b" ]; then
  NEW_SLOT="a"
  BOOT_LUN="1"
else
  echo "Current slot invalid: '$CURRENT_SLOT'"
  exit 1
fi

echo "Current slot: $CURRENT_SLOT"
echo "Flashing slot: $NEW_SLOT"

flash() {
  echo "Writing to $1..."
  $EDL w $1 $2 --memory=ufs
}


$EDL e xbl_$CURRENT_SLOT --memory=ufs &> /dev/null

# flash non-active slot
flash aop_$NEW_SLOT aop.img
flash devcfg_$NEW_SLOT devcfg.img
flash xbl_$NEW_SLOT xbl.img
flash xbl_config_$NEW_SLOT xbl_config.img
flash abl_$NEW_SLOT abl.img
flash boot_$NEW_SLOT boot.img
flash system_$NEW_SLOT system.img


echo "Setting slot $NEW_SLOT active..."
{
  $EDL setactiveslot $NEW_SLOT
  $EDL setbootablestoragedrive $BOOT_LUN
} &> /dev/null


# wipe device
flash userdata reset_userdata.img
echo "Erasing cache..."
$EDL e cache --memory=ufs


echo "Reseting..."
$EDL reset &> /dev/null
