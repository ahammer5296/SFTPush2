#!/bin/bash

FPATH="../mft_macos_build" # Изменено для macOS

mkdir "$FPATH"

header () {
	echo
	echo
	echo "**************************************************************"
	echo "**************************************************************"
	echo "Building $1"
	echo "**************************************************************"
	echo "**************************************************************"
	echo 
	echo 
}

header "macOS"
xcodebuild archive  -scheme "mft" -destination "generic/platform=macOS" \
    -archivePath "${FPATH}/mft_macos"  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES 

if [ $? -ne 0 ]; then
	echo "\n\n******** Error when building for macOS\n\n"
	exit 3
fi

echo "\n\nCheck out ${FPATH}/mft_macos.xcarchive/Products/Library/Frameworks/mft.framework"

header "All Done!"
