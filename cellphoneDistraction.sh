#!/bin/bash

#VARIABLES
CLASSNAME="CellphoneDistractionTest"
METHODNAME="testVideo"
# FILENAME="extCap_t_GDWSKYFMAQI7BAAAZ4JIDXRKBA_T1zT0_0014_rPuif.mp4"
LOG_BASE_PATH="./Logs"
# Uploading vidoes to the device
DEVICE_BASE_PATH="/sdcard/device-test-resources/aiTesting/cellphone"
LOCAL_BASE_PATH="./Videos"
FAILEDTESTCASEPATH="./ListOfFailedTestcase.txt"
DEVICE_LOG_PATH="/data/data/lightmetrics.lib.test/files/lightmetrics"

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

adb logcat -G 512M
adb shell rm -rf "$DEVICE_BASE_PATH"/*
adb root
COUNT=0
RESTART_INTERVAL=10
# Create List of FileNames
for FILE in "$LOCAL_BASE_PATH"/*; do
    COUNT=$((COUNT + 1))
    FILENAME="$(basename "$FILE")"
    LOGFILENAME="${FILENAME%%.*}.log"
    LOGFILEPATH=$LOG_BASE_PATH/$LOGFILENAME
    echo "$FILENAME"
    adb shell 'rm -rf /data/data/lightmetrics.lib.test/files/lightmetrics/*.log.lzma.e2'
    adb shell 'rm -rf /data/data/lightmetrics.lib.test/files/lightmetrics/logs/*.log.e2'
    adb push "${FILE}" "$DEVICE_BASE_PATH/"
    TEST_OUTPUT=$(adb shell am instrument -w -m -e filename "$FILENAME" -e debug false -e class "lightmetrics.lib.$CLASSNAME#$METHODNAME" lightmetrics.lib.test/androidx.test.runner.AndroidJUnitRunner)
    if [[ "$TEST_OUTPUT" == *"Process crashed."* ]]; 
    then 
        echo "$FILENAME" >> $FAILEDTESTCASEPATH
        adb shell rm -rf "$DEVICE_BASE_PATH/$FILENAME"
        continue
    fi
    adb pull $DEVICE_LOG_PATH $LOG_BASE_PATH
    lm-utils log -i $LOG_BASE_PATH/lightmetrics/*.log.lzma.e2 > $LOGFILEPATH
    lm-utils log -i $LOG_BASE_PATH/lightmetrics/logs/*.log.e2 >> $LOGFILEPATH
    sed -i '/SnpeWhyDistractionNativ/!d' $LOGFILEPATH

    rm -rf $LOG_BASE_PATH/lightmetrics

    adb shell rm -rf "$DEVICE_BASE_PATH/$FILENAME"

    adb shell am force-stop "lightmetrics.lib.$CLASSNAME"

    if [ $((COUNT % RESTART_INTERVAL)) -eq 0 ]; then
        echo "Performing maintenance at run $COUNT..."
        adb shell pm clear "lightmetrics.lib.$CLASSNAME"
        adb kill-server
        sleep 2
        adb start-server
        sleep 5
    fi
    
    sleep 1
done