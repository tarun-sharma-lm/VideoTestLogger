#!/bin/bash


# FILENAME="extCap_t_GDWSKYFMAQI7BAAAZ4JIDXRKBA_T1zT0_0014_rPuif.mp4"
LOG_BASE_PATH="/home/tarunsharma/CellphoneDetectionScript/Logs"
# Uploading vidoes to the device
DEVICE_BASE_PATH="/sdcard/device-test-resources/aiTesting/cellphone"
LOCAL_BASE_PATH="/home/tarunsharma/CellphoneDetectionScript/Videos"
FAILEDTESTCASEPATH="/home/tarunsharma/CellphoneDetectionScript/ListOfFailedTestcase.txt"
isFirst=true

# clear logs directory 
rm -rf "$LOG_BASE_PATH"/*
rm -rf "$FAILEDTESTCASEPATH"
touch "$FAILEDTESTCASEPATH"

# clear before uploading and upload
adb shell rm -rf "$DEVICE_BASE_PATH"/*
adb push "${LOCAL_BASE_PATH}/." "$DEVICE_BASE_PATH/"

# Create List of FileNames
for FILE in "$LOCAL_BASE_PATH"/*; do
    FILENAME="$(basename "$FILE")"
    LOGFILENAME="${FILENAME%%.*}.log"
    LOGFILEPATH=$LOG_BASE_PATH/$LOGFILENAME
    echo "$FILENAME"
    adb root
    adb logcat -b all -c 
    TEST_OUTPUT=$(adb shell am instrument -w -m -e filename "$FILENAME" -e debug false -e class 'lightmetrics.lib.CellphoneDistractionTest#testVideo' lightmetrics.lib.test/androidx.test.runner.AndroidJUnitRunner)
    if [[ "$TEST_OUTPUT" == *"FATAL EXCEPTION"* ]]; 
    then 
        echo "$FILENAME" >> $FAILEDTESTCASEPATH
        continue
    fi
    adb logcat -d -s 'SnpeWhyDistractionNativ' > "$LOGFILEPATH"
    if $isFirst; then
        isFirst=false
    else
        sed -i '2,26d' $LOGFILEPATH
    fi
done
