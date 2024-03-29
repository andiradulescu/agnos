$EDL = "edl/edl"
if (Test-Path -path $EDL) {
    Write-Host 'EDL tool found'
} else {
    Write-Host "Downloading and setting up EDL"
    Invoke-Expression "git clone https://github.com/bkerler/edl.git"
    Invoke-Expression "cd edl"
    Invoke-Expression "git submodule update --depth=1 --init --recursive"
    Invoke-Expression "pip3 install requirements.txt"
    Invoke-Expression "cd .."
}

$CURRENT_SLOT = (& $EDL getactiveslot 2>&1 | Select-String -Pattern "Current active slot:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
$BOOT_LUN = ""

if ($CURRENT_SLOT -eq "a") {
    $NEW_SLOT = "b"
    $BOOT_LUN = "2"
}
elseif ($CURRENT_SLOT -eq "b") {
    $NEW_SLOT = "a"
    $BOOT_LUN = "1"
}
else {
    Write-Host "Current slot invalid: '$CURRENT_SLOT'"
    exit 1
}

Write-Host "Current slot: $CURRENT_SLOT"
Write-Host "Flashing slot: $NEW_SLOT"

function flash {
    param($arg1, $arg2)
    Write-Host "Writing to $arg1..."
    & $EDL w $arg1 $arg2 --memory=ufs | Select-String -Pattern "Progress:"
}

& $EDL e xbl_$CURRENT_SLOT > $null

flash aop_$NEW_SLOT aop.img
flash devcfg_$NEW_SLOT devcfg.img
flash xbl_$NEW_SLOT xbl.img
flash xbl_config_$NEW_SLOT xbl_config.img
flash abl_$NEW_SLOT abl.img
flash boot_$NEW_SLOT boot.img
flash system_$NEWS_SLOT system.img

Write-Host "Setting slot $NEW_SLOT active..."
& $EDL setactiveslot $NEW_SLOT > $null
& $EDL setbootablestoragedrive $BOOT_LUN > $null


# wipe device
flash userdata reset_userdata.img
Write-Host "Erasing cache..."
& $EDL e cache | Select-String -Pattern "Progress:"

Write-Host "Reseting..."
& $EDL reset > $null
