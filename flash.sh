#!/bin/bash -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
EDL=$DIR/edl_repo/edl

{
  if [[ ! -f  $EDL ]]; then
    git clone https://github.com/bkerler/edl $DIR/edl_repo
    cd $DIR/edl_repo
    git fetch --all
    # TODO: git checkout
    git submodule update --depth=1 --init --recursive
    pip3 install -r requirements.txt

    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install libusb git
      lb -s /opt/homebrew/lib ~/lib
    fi

    cd $DIR
  fi
} > /dev/null

echo "Enter your computer password if prompted"

CURRENT_SLOT="$($EDL getactiveslot 2>&1 | grep "Current active slot:" | cut -d ':' -f2- | sed 's/[[:blank:]]//g')"
echo $CURRENT_SLOT
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
  $EDL w $1 $2 --memory=ufs | grep "Progress:"
}


$EDL e xbl_$CURRENT_SLOT > /dev/null

# flash non-active slot
flash aop_$NEW_SLOT aop.img
flash devcfg_$NEW_SLOT devcfg.img
flash xbl_$NEW_SLOT xbl.img
flash xbl_config_$NEW_SLOT xbl_config.img
flash abl_$NEW_SLOT abl.img
flash boot_$NEW_SLOT boot.img
#flash system_$NEWS_SLOT system.img

echo "Setting slot $NEW_SLOT active..."
{
  $EDL setactiveslot $NEW_SLOT
  $EDL setbootablestoragedrive $BOOT_LUN
} > /dev/null

# wipe device
flash userdata reset_userdata.img
echo "Erasing cache..."
$EDL e cache | egrep "Progress:"

echo "Reseting..."
$EDL reset > /dev/null
