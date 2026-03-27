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
TAG="SnpeWhyDistractionNativ"
MAX_FILE_SIZE=150000000  # 150MB in bytes
SEGMENT_DURATION=120     # split into 2-minute chunks

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
    FILE_SIZE=$(stat -c%s "$FILE")
    if [ "$FILE_SIZE" -gt "$MAX_FILE_SIZE" ]; then
        echo "$FILENAME is $(( FILE_SIZE / 1000000 ))MB — splitting into ${SEGMENT_DURATION}s segments..."
        SPLIT_DIR=$(mktemp -d "./split_XXXXXX")
        BASENAME="${FILENAME%.*}"
        ffmpeg -i "$FILE" -c copy -segment_time "$SEGMENT_DURATION" -f segment -reset_timestamps 1 "${SPLIT_DIR}/${BASENAME}_%03d.mp4"
        SEGMENT_INDEX=0
        > "$LOGFILEPATH"
        for SEGMENT in "$SPLIT_DIR"/*.mp4; do
            SEGMENT_NAME="$(basename "$SEGMENT")"
            echo "  Processing segment: $SEGMENT_NAME"
            adb push "$SEGMENT" "$DEVICE_BASE_PATH/"
            TEST_OUTPUT=$(adb shell am instrument -w -m -e filename "$SEGMENT_NAME" -e debug false -e class "lightmetrics.lib.$CLASSNAME#$METHODNAME" lightmetrics.lib.test/androidx.test.runner.AndroidJUnitRunner)
            if [[ "$TEST_OUTPUT" == *"Process crashed."* ]]; then
                echo "$FILENAME (segment $SEGMENT_NAME)" >> $FAILEDTESTCASEPATH
            fi
            adb shell rm -rf "$DEVICE_BASE_PATH/$SEGMENT_NAME"

            adb pull $DEVICE_LOG_PATH $LOG_BASE_PATH
            lm-utils log -i $LOG_BASE_PATH/lightmetrics/*.log.lzma.e2 >> "$LOGFILEPATH"
            lm-utils log -i $LOG_BASE_PATH/lightmetrics/logs/*.log.e2 >> "$LOGFILEPATH"
            rm -rf $LOG_BASE_PATH/lightmetrics
            adb shell 'rm -rf /data/data/lightmetrics.lib.test/files/lightmetrics/*.log.lzma.e2'
            adb shell 'rm -rf /data/data/lightmetrics.lib.test/files/lightmetrics/logs/*.log.e2'
            SEGMENT_INDEX=$((SEGMENT_INDEX + 1))
        done
        rm -rf "$SPLIT_DIR"
        # filter by TAG and fix frame numbers across segments
        sed -i "/$TAG/!d" "$LOGFILEPATH"
        awk -F'Frame number: ' '
            /Frame number:/ {
                split($2, a, ",")
                frame = a[1] + 0
                if (frame < prev_frame) offset += prev_frame
                prev_frame = frame
                sub(/Frame number: [0-9]+/, "Frame number: " (frame + offset))
            }
            { print }
        ' "$LOGFILEPATH" > "${LOGFILEPATH}.tmp" && mv "${LOGFILEPATH}.tmp" "$LOGFILEPATH"
    else
        adb push "${FILE}" "$DEVICE_BASE_PATH/"
        TEST_OUTPUT=$(adb shell am instrument -w -m -e filename "$FILENAME" -e debug false -e class "lightmetrics.lib.$CLASSNAME#$METHODNAME" lightmetrics.lib.test/androidx.test.runner.AndroidJUnitRunner)
        if [[ "$TEST_OUTPUT" == *"Process crashed."* ]]; then
            echo "$FILENAME" >> $FAILEDTESTCASEPATH
            adb shell rm -rf "$DEVICE_BASE_PATH/$FILENAME"
            continue
        fi
        adb pull $DEVICE_LOG_PATH $LOG_BASE_PATH
        lm-utils log -i $LOG_BASE_PATH/lightmetrics/*.log.lzma.e2 > $LOGFILEPATH
        lm-utils log -i $LOG_BASE_PATH/lightmetrics/logs/*.log.e2 >> $LOGFILEPATH
        sed -i "/$TAG/!d" $LOGFILEPATH

        rm -rf $LOG_BASE_PATH/lightmetrics

        adb shell rm -rf "$DEVICE_BASE_PATH/$FILENAME"
    fi

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