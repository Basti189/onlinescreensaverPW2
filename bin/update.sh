#!/bin/sh
#
##############################################################################
#
# Fetch screensaver from a configurable URL.
cd "$(dirname "$0")"
# load configuration
if [ -e "config.sh" ]; then
    source ./config.sh
else
    TMPFILE=/tmp/tmp.onlinescreensaver.png
fi
# load utils
if [ -e "utils.sh" ]; then
    source ./utils.sh
else
    echo "Could not find utils.sh in `pwd`"
    exit
fi

# do nothing if no URL is set
if [ -z $IMAGE_URI ]; then
    logger "No image URL has been set. Please edit config.sh."
    return
fi

# Check WiFi connection status
WIFI_CONNECTION=`lipc-get-prop com.lab126.wifid cmState`
logger "WiFi connection state: $WIFI_CONNECTION"

# Get battery status and build URL with parameters
POWERD_OUTPUT=`/usr/bin/powerd_test -s`
batteryLevel=`echo "$POWERD_OUTPUT" | awk -F: '/Battery Level/ {print substr($2, 1, length($2)-1) + 0}'`
isCharging=`echo "$POWERD_OUTPUT" | awk -F: '/Charging/ {print substr($2,2,length($2))}'`
IMAGE_URI_WITH_PARAMS="$IMAGE_URI?batteryLevel=$batteryLevel&isCharging=$isCharging"

# Capture wget output and exit code for detailed logging
WGET_OUTPUT=$(wget --no-check-certificate -q $IMAGE_URI_WITH_PARAMS -O $TMPFILE 2>&1)
WGET_EXIT_CODE=$?

if [ $WGET_EXIT_CODE -eq 0 ]; then
    mv $TMPFILE $SCREENSAVERFILE
    logger "Screen saver image updated successfully from $IMAGE_URI"
    # refresh screen
    if [ `lipc-get-prop com.lab126.powerd status | grep "Ready" | wc -l` -gt 0 ] || [ `lipc-get-prop com.lab126.powerd status | grep "Screen Saver" | wc -l` -gt 0 ]
    then
        logger "Updating image on screen"
        eips -f -g $SCREENSAVERFILE

        if [ "${OSS_DEBUG:-0}" -eq 1 ]; then
            TS="$(date '+%H:%M:%S' 2>/dev/null)"
            [ -z "$TS" ] && TS="$(date 2>/dev/null)"

            BOX_X=2
            BOX_Y=2
            BOX_W=50   # inkl. Rahmen
            BOX_H=5

            # Leerzeilen innen (BOX_W-2)
            INNER_W=$((BOX_W-2))
            INNER_SPACES="$(printf '%*s' "$INNER_W" '')"

            # Top border
            eips "$BOX_X" "$BOX_Y" "+$(printf '%*s' "$INNER_W" '' | tr ' ' '-')+"

            # Middle
            i=1
            while [ $i -le $((BOX_H-2)) ]; do
            eips "$BOX_X" "$((BOX_Y+i))" "|$INNER_SPACES|"
            i=$((i+1))
            done

            # Bottom border
            eips "$BOX_X" "$((BOX_Y+BOX_H-1))" "+$(printf '%*s' "$INNER_W" '' | tr ' ' '-')+"

            # Text
            eips "$((BOX_X+2))" "$((BOX_Y+2))" "UPDATED: $TS"
        fi

    fi
else
    # Log detailed wget failure information
    logger "wget failed with exit code $WGET_EXIT_CODE when downloading $IMAGE_URI"
    echo "$(date): wget failed with exit code $WGET_EXIT_CODE when downloading $IMAGE_URI" >> $LOGFILE
    
    # Log wget error output if available
    if [ -n "$WGET_OUTPUT" ]; then
        echo "$(date): wget error output: $WGET_OUTPUT" >> $LOGFILE
        logger "wget error: $WGET_OUTPUT"
    fi
    
    # Log common wget exit code meanings
    case $WGET_EXIT_CODE in
        1) echo "$(date): wget error: Generic error code" >> $LOGFILE ;;
        2) echo "$(date): wget error: Parse error (command line options)" >> $LOGFILE ;;
        3) echo "$(date): wget error: File I/O error" >> $LOGFILE ;;
        4) echo "$(date): wget error: Network failure" >> $LOGFILE ;;
        5) echo "$(date): wget error: SSL verification failure" >> $LOGFILE ;;
        6) echo "$(date): wget error: Username/password authentication failure" >> $LOGFILE ;;
        7) echo "$(date): wget error: Protocol errors" >> $LOGFILE ;;
        8) echo "$(date): wget error: Server issued an error response" >> $LOGFILE ;;
        *) echo "$(date): wget error: Unknown exit code $WGET_EXIT_CODE" >> $LOGFILE ;;
    esac
    
    # Clean up temp file if it exists but is incomplete
    if [ -f $TMPFILE ]; then
        rm -f $TMPFILE
        logger "Removed incomplete temporary file $TMPFILE"
    fi
    
fi
