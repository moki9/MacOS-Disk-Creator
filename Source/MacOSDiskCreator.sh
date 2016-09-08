#!/bin/bash
# MacOS Disk Creator
# Copyright (c) 2016, Chris1111 <leblond1111@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.



# Remove the image if exist
if [ "/tmp/MacOS.sparseimage" ]; then
	rm -rf "/tmp/MacOS.sparseimage"
fi

if [ "/tmp/MacOS.cdr" ]; then
	rm -rf "/tmp/MacOS.cdr"
fi

if [[ $(mount | awk '$3 == "/Volumes/Mac_OS_Installer" {print $3}') != "" ]]; then
 hdiutil detach "/Volumes/Mac_OS_Installer"
fi


Sleep 2
# script Notifications
osascript -e 'display notification "Installer Image MacOS" with title "Start"  sound name "default"'

Sleep 2
# create sparseimage
hdiutil create -size 8g -type SPARSE -fs HFS+J -volname Mac_OS_Installer -uid 0 -gid 80 -mode 1775 /tmp/MacOS

# Mount the dmg image
hdiutil attach -nobrowse /tmp/MacOS.sparseimage

mkdir ./OS_X_Image/Installer/Installer_OSX

pkgbuild --root ./OS_X_Image/Installer/Installer_OSX --scripts ./OS_X_Image/Installer/scripts --identifier com.Hackintosh.cloverbootloader --version 1 --install-location / Installer.pkg

osascript -e 'tell app "System Events" to display dialog "Installing OS
/tmp/MacOS.sparseimage
Approximate duration is 2 to 3 minutes
Please be patient...." with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:FinderIcon.icns" buttons {"OK"} default button 1 with title "Mac OS Installer"'
echo " "
echo "Installation  /Volumes/Mac_OS_Installer  
Wait, be patient! . . . "

Sleep 2
# run the pkg
osascript -e 'do shell script "installer -allowUntrusted -verboseR -pkg ./Installer.pkg -target /Volumes/Mac_OS_Installer" with administrator privileges'

# script Notifications
osascript -e 'display notification "Finish" with title "Installing OS"  sound name "default"'

pkgbuild --root ./OS_X_Image/Clover_UEFI_Legacy --scripts ./OS_X_Image/scripts --identifier com.Hackintosh.cloverbootloader --version 1 --install-location / CloverEFI.pkg

osascript -e 'tell app "System Events" to display dialog "Installing Clover EFI
Volumes/EFI ⥤ Mac_OS_Installer
Approximate duration is 5 Seconds" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:FinderIcon.icns" buttons {"OK"} default button 1 with title "Clover EFI Installer"'
echo " "
echo "Installation  /Volumes/EFI ⥤ /Mac_OS_Installer "

Sleep 2
# run the pkg
osascript -e 'do shell script "installer -allowUntrusted -verboseR -pkg ./CloverEFI.pkg -target /Volumes/Mac_OS_Installer" with administrator privileges'


# script Notifications
osascript -e 'display notification "Finish" with title "Installing Clover EFI"  sound name "default"'

Sleep 10
# Unmount the dmg image
hdiutil detach -Force /Volumes/Mac_OS_Installer

# Unmount the dmg image
hdiutil detach /Volumes/EFI

echo "  "
echo "********************************************** " 
echo "Convert Sparse image  "
echo "********************************************** " 
echo "  "

# convert the Image
hdiutil convert /tmp/MacOS.sparseimage -format UDTO -o /tmp/MacOS.cdr



Sleep 3
# Remove the sparseimage
rm -R /tmp/MacOS.sparseimage

# Remove the dmg if exist
if [ "/$HOME/Desktop/Mac-OS.dmg" ]; then
	rm -rf "/$HOME/Desktop/Mac-OS.dmg"
fi

Sleep 2
# Move the dmg 
mv /tmp/MacOS.cdr ~/Desktop/Mac-OS.dmg

# Remove the pkg
rm -R ./CloverEFI.pkg
rm -R ./Installer.pkg

echo "  "
echo "********************************************** " 
echo "Move /tmp/MacOS.cdr /Desktop/Mac-OS.dmg  "
echo "********************************************** " 
echo "  "


# Vars
apptitle="MacOS Disk-Creator"
version="1.0"

# Set Icon directory and file 
iconfile="/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns"

# Select Restore
response=$(osascript -e 'tell app "System Events" to display dialog "Select Restore to copy Mac-OS.dmg image to a USB key or Disk.\n\nSelect Cancel to Quit" buttons {"Cancel","Restore"} default button 2 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'"  ')

action=$(echo $response | cut -d ':' -f2)

# Exit if Canceled
if [ ! "$action" ] ; then
  osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "User cancelled"'
  exit 0
fi

### RESTORE : Select image file and usbdisk location
if [ "$action" == "Restore" ] ; then

  # Get image file location
  imagepath=`/usr/bin/osascript << EOT
    tell application "Finder"
        activate
        set imagefilepath to choose file default location "/$HOME/Desktop" with prompt "Select Mac-OS.dmg image file to restore to USB key or Disk."
    end tell 
    return (posix path of imagefilepath) 
  EOT`

  # Cancel is user selects Cancel
  if [ ! "$imagepath" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "User cancelled"'
    exit 0
  fi

  # Get input folder of usbdisk disk 
  usbdiskpath=`/usr/bin/osascript << EOT
    tell application "Finder"
        activate
        set folderpath to choose folder default location "/Volumes" with prompt "Select your USB key / Disk  location"
    end tell 
    return (posix path of folderpath) 
  EOT`

  # Cancel is user selects Cancel
  if [ ! "$usbdiskpath" ] ; then
    osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "User cancelled"'
    exit 0
  fi

  # Parse vars for dd
  inputfile=$imagepath

  # Check if Compressed from extension
  extension="${inputfile##*.}"
  if [ "$extension" == "gz" ] || [ "$extension" == "zip" ] || [ "$extension" == "xz" ]; then
    compression="Yes"
  else
    compression="No"
  fi

fi

# Parse usbdisk disk volume
usbdisk=$( echo $usbdiskpath | awk -F '\/Volumes\/' '{print $2}' | cut -d '/' -f1 )
disknum=$( diskutil list | grep "$usbdisk" | awk -F 'disk' '{print $2}' | cut -d 's' -f1 )
devdisk="/dev/disk$disknum"
# use rdisk for faster copy
devdiskr="/dev/rdisk$disknum"
# Get Drive size
drivesize=$( diskutil list | grep "disk$disknum" | grep "0\:" | cut -d "*" -f2 | awk '{print $1 " " $2}' )

# Set output option
if [ "$action" == "Backup" ] ; then
  inputfile=$devdiskr
  source="$drivesize $usbdisk (disk$disknum)"
  dest=$outputfile
  check=$dest
fi
if [ "$action" == "Restore" ] ; then
  source=$inputfile
  dest="$drivesize $usbdisk (disk$disknum)"
  outputfile=$devdiskr
  check=$source
fi

# Confirmation Dialog
response=$(osascript -e 'tell app "System Events" to display dialog "Please confirm your choice and click OK\n\nSource: \n'"$source"' \n\nDestination: \n'"$dest"' \n\n\nNOTE: Any data you have on the volume will be lost when it is created!" buttons {"Cancel", "OK"} default button 2 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'" ')
answer=$(echo $response | grep "OK")

# Cancel is user does not select OK
if [ ! "$answer" ] ; then
  osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "User cancelled"'
  exit 0
fi

# Unmount Volume
response=$(diskutil unmountDisk $devdisk)
answer=$(echo $response | grep "successful")

# Cancel if unable to unmount
if [ ! "$answer" ] ; then
  osascript -e 'display notification "Program closing" with title "'"$apptitle"'" subtitle "Cannot Unmount '"$usbdisk"'"'
  exit 0
fi

# Start dd copy
## Todo - delete image file if it exists already


# script Notifications
osascript -e 'display notification "Please be patient...." with title "Restoring Disk Started"  sound name "default"'

if [ "$compression" == "No" ] ; then
  osascript -e 'do shell script "dd if=\"'"$inputfile"'\" of=\"'"$outputfile"'\" bs=1m" with administrator privileges'
fi

# Copy Complete
# Check filesize the OSX way 1Kb = 1000 bytes
filesize=$(stat -f%z "$check")

if [ "$filesize" -gt 1000000000000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000000000000" | bc ) TB" 
elif [ "$filesize" -gt 1000000000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000000000" | bc ) GB" 
elif [ "$filesize" -gt 1000000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000000" | bc ) MB" 
elif [ "$filesize" -gt 1000 ] ; then
  fsize="$( echo "scale=2; $filesize/1000" | bc ) KB" 
fi

# Get Filename for display
fname=$(basename "$check")

# script Notifications
osascript -e 'display notification "'"$drivesize"' Drive '$action' Complete " with title "'"$apptitle"'" subtitle " '"$fname"' "'

response=$(osascript -e 'tell app "System Events" to display dialog "'"$drivesize"' Restore Disk '$action' Complete\n\nFile '"$fname"'\n\nSize '"$fsize"' " buttons {"Done"} default button 1 with title "'"$apptitle"' '"$version"'" with icon POSIX file "'"$iconfile"'" ')


# Rename USB Installer
/usr/sbin/diskutil rename "Mac_OS_Installer" "Mac-OS-USB"

echo "  "
echo "********************************************** " 
echo "
Restore Completed
Done! "
echo "********************************************** " 







