#!/bin/bash

#VARIABLES
CLASSNAME="CellphoneDistractionTest"
METHODNAME="testVideo"
# FILENAME="extCap_t_GDWSKYFMAQI7BAAAZ4JIDXRKBA_T1zT0_0014_rPuif.mp4"
LOG_BASE_PATH="/home/tarunsharma/CellphoneDetectionScript/Logs"
# Uploading vidoes to the device
DEVICE_BASE_PATH="/sdcard/device-test-resources/aiTesting/cellphone"
LOCAL_BASE_PATH="/home/tarunsharma/CellphoneDetectionScript/Videos"
FAILEDTESTCASEPATH="/home/tarunsharma/CellphoneDetectionScript/ListOfFailedTestcase.txt"

# clear logs directory 
rm -rf "$LOG_BASE_PATH"/*
rm -rf "$FAILEDTESTCASEPATH"
touch "$FAILEDTESTCASEPATH"
if [ ! -e "$LOG_BASE_PATH" ]; then
    mkdir $LOG_BASE_PATH
fi
if [ ! -e "$LOCAL_BASE_PATH" ]; then
    mkdir $LOCAL_BASE_PATH
fi
# clear before uploading and upload

adb logcat -G 32M
adb shell rm -rf "$DEVICE_BASE_PATH"/*

# Create List of FileNames
for FILE in "$LOCAL_BASE_PATH"/*; do
    FILENAME="$(basename "$FILE")"
    LOGFILENAME="${FILENAME%%.*}.log"
    LOGFILEPATH=$LOG_BASE_PATH/$LOGFILENAME
    echo "$FILENAME"
    adb shell rm -rf "$DEVICE_BASE_PATH"/*
    adb push "${FILE}" "$DEVICE_BASE_PATH/"
    adb root
    adb logcat -b all -c 
    TEST_OUTPUT=$(adb shell am instrument -w -m -e filename "$FILENAME" -e debug false -e class "lightmetrics.lib.$CLASSNAME#$METHODNAME" lightmetrics.lib.test/androidx.test.runner.AndroidJUnitRunner)
    if [[ "$TEST_OUTPUT" == *"FATAL EXCEPTION"* ]]; 
    then 
        echo "$FILENAME" >> $FAILEDTESTCASEPATH
        adb shell rm -rf "$DEVICE_BASE_PATH/$FILE"
        continue
    fi
    adb logcat -d -s 'SnpeWhyDistractionNativ' > "$LOGFILEPATH"
    # sed -i '1,/initNativeObject: Initialized Why-Distraction native wrapper/d' $LOGFILEPATH
done
