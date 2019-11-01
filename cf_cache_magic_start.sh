#!/bin/bash
startDate=$(date +"%D %T")
echo "Start: ${startDate}"
script_name="cf_cache_magic.sh"
pkill -f ${script_name}
/path/to/${script_name}
finishDate=$(date +"%D %T")
echo "Finish: ${finishDate}"
