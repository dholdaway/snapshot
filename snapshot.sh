#!/bin/bash
# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail

# AWS_CONFIG_FILE="/root/.aws/config"
# 00 06 * * *     root    /opt/aws/snapshot.sh >> /var/log/snapshot.log 2>&1


## START SCRIPT

# Set Variables
instance_id=`wget -q -O- http://169.254.169.254/latest/meta-data/instance-id`
date_7days_ago_in_seconds=`date +%s --date '7 days ago'`
today=`date +"%m-%d-%Y"+"%T"`
logfile="/var/log/ebs-snapshot.log"

echo $today >> $logfile

aws ec2 describe-volumes --output=text --filter Name=attachment.instance-id,Values=$instance_id | grep VOLUME | cut -f7 > /tmp/volume_info.txt 2>&1

for volume_id in $(cat /tmp/volume_info.txt)
do
    description="$(hostname)-backup-$(date +%Y-%m-%d)"
	echo "Volume ID is $volume_id" >> $logfile
    
	snapresult=$(aws ec2 create-snapshot --output=text --description $description --volume-id $volume_id | cut -f4)
	
    echo "New snapshot is $snapresult" >> $logfile
         
    aws ec2 create-tags --resource $snapresult --tags Key=CreatedBy,Value=AutomatedBackup
done

rm /tmp/snapshot_info.txt --force
for vol_id in $(cat /tmp/volume_info.txt)
do
    aws ec2 describe-snapshots --output=text --filters "Name=volume-id,Values=$vol_id" "Name=tag:CreatedBy,Values=AutomatedBackup"| grep SNAPSHOT | cut -f5 | sort | uniq >> /tmp/snapshot_info.txt 2>&1
done

for snapshot_id in $(cat /tmp/snapshot_info.txt)
do
    echo "Checking $snapshot_id..."
	snapshot_date=$(aws ec2 describe-snapshots --output=text --snapshot-ids $snapshot_id | grep SNAPSHOT | awk '{print $6}' | awk -F "T" '{printf "%s\n", $1}')
    snapshot_date_in_seconds=`date "--date=$snapshot_date" +%s`

    if (( $snapshot_date_in_seconds <= $date_7days_ago_in_seconds )); then
        echo "Deleting snapshot $snapshot_id ..." >> $logfile
        aws ec2 delete-snapshot --snapshot-id $snapshot_id
    else
        echo "Not deleting snapshot $snapshot_id ..." >> $logfile
    fi
done

echo "" >> $logfile

echo "Results logged to $logfile"
