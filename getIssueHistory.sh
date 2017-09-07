#!/bin/bash

source /root/IssueHistory/config
mkdir -p $filepath/History $filepath/IID_samples $filepath/HID_samples


sample_filename=`date -d @$(echo $start_time | sed 's/\(.\{10\}\).*/\1/ ') +"%B-%d-%Y"`_`date -d @$(echo $end_time | sed 's/\(.\{10\}\).*/\1/ ') +"%B-%d-%Y"`
ACTION_TOKEN=`curl -s -k -X POST -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" \
-d \
"grant_type=password&\
username=hiroadmin&\
password=pw4hiroadmin&\
scope=individual,department,company&\
client_id=$CLIENT_KEY&\
client_secret=$CLIENT_SECRET" \
https://$WSO2_IP:9443/oauth2/token \
| python -mjson.tool | grep access_token | cut -f 4 -d '"'`


get_IIDs (){
    curl -s -k -H "_TOKEN:$ACTION_TOKEN" -G 'https://'"$DB_IP":'8443/query/vertices' --data-urlencode "query=ogit\/_created-on:[$start_time TO $end_time] AND ogit\/_type:\"ogit/Automation/AutomationIssue\" AND \/State: $1" --data-urlencode "fields=/IID" --data-urlencode "limit=9999" | python -mjson.tool | jq '.[] | .[] | select(length > 0) | .["/IID"]' > $filepath/IID_samples/"$sample_filename"_$1.json
    
    count=`cat $filepath/IID_samples/"$sample_filename"_$1.json | wc -l`
    echo " $count" "issues got $1"
}

gethistory (){
	counter2=0
	while [ "$counter2" -lt "$2" ]; do
		HID=`cat $filepath/HID_samples/"$1".json | jq '.items'[$counter2]'["ogit/_in-id"]' | tr -d '"'`
	#	echo $HID
		curl -k -s -H "_TOKEN:$ACTION_TOKEN" -X GET https://$DB_IP:8443/$HID | python -mjson.tool >> $filepath/History/$1
		(( counter2 ++ ))
	done
}

get_HIDs (){
    counter1=1
    IID_count=`cat $filepath/IID_samples/"$sample_filename"_$1.json | wc -l`
    for line in `cat $filepath/IID_samples/"$sample_filename"_"$1"".json"`; do
	echo -ne " $1" Issue "$counter1"/"$IID_count"\\r
	IID=`echo $line | tr -d '"'`
	curl -k -s -X GET -H "_TOKEN:$ACTION_TOKEN" -H "Content-Type: application/json" 'https://'$DB_IP':8443/query/gremlin?query=outE("ogit/generates")&fields=ogit/_in-id&root='$IID | python -mjson.tool > $filepath/HID_samples/"$IID".json
	count_HID=`cat $filepath/HID_samples/"$IID".json | jq '.[] | length'`
	gethistory "$IID" "$count_HID"
	(( counter1 ++ ))
#	read -n 1
    done
    echo ""
}

get_IIDs "RESOLVED"
get_IIDs "RESOLVED_EXTERNAL"
get_IIDs "EJECTED"

get_HIDs "RESOLVED"
get_HIDs "RESOLVED_EXTERNAL"
get_HIDs "EJECTED"

