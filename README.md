# This is the Script that runs the cellPhoneDistraction testcase on videos data and create logs

## Create Videos directory and put videos in it.

## Need to do some changes in Android Studios
val filename = InstrumentationRegistry.getArguments().getString("filename")
val s3FileUrl = "${rootDirectory}/${filename}"

## This also creates a text file that lists the name of the vidoes that failed the testcase