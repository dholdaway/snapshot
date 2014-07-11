#!/bin/bash
# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail

## START SCRIPT

# Set Variables
instance_id=`wget -q -O- http://169.254.169.254/latest/meta-data/instance-id`
date_7days_ago_in_seconds=`date +%s --date '7 days ago'`
today=`date +"%m-%d-%Y"+"%T"`
logfile="/var/log/aws-snapshot.log"
report="/var/log/snapshotreport.log"
# Start log file: today's date
echo $today >> $logfile

# Grab all volume IDs attached to this instance, and export the IDs to a text file
aws ec2 describe-volumes  --filters Name=attachment.instance-id,Values=$instance_id --query Volumes[].VolumeId --output text | tr '\t' '\n' > /tmp/volume_info.txt 2>&1

# Take a snapshot of all volumes attached to this instance
for volume_id in $(cat /tmp/volume_info.txt)
do
    description="$(hostname)-backup-$(date +%Y-%m-%d)"
        echo "Volume ID is $volume_id" >> $logfile

        # Next, we're going to take a snapshot of the current volume, and capture the resulting snapshot ID
        snapresult=$(aws ec2 create-snapshot --output=text --description $description --volume-id $volume_id --query SnapshotId)

    echo "New snapshot is $snapresult" >> $logfile

    # And then we're going to add a "CreatedBy:AutomatedBackup" tag to the resulting snapshot.
    # Why? Because we only want to purge snapshots taken by the script later, and not delete snapshots manually taken.
    aws ec2 create-tags --resource $snapresult --tags Key=CreatedBy,Value=AutomatedBackup
done

# Get all snapshot IDs associated with each volume attached to this instance
rm /tmp/snapshot_info.txt --force
for vol_id in $(cat /tmp/volume_info.txt)
do
    aws ec2 describe-snapshots --output=text --filters "Name=volume-id,Values=$vol_id" "Name=tag:CreatedBy,Values=AutomatedBackup" --query Snapshots[].SnapshotId | tr '\t' '\n' | sort | uniq >> /tmp/snapshot_info.txt 2>&1
done

# Purge all instance volume snapshots created by this script that are older than 7 days
for snapshot_id in $(cat /tmp/snapshot_info.txt)
do
    echo "Checking $snapshot_id..."
        snapshot_date=$(aws ec2 describe-snapshots --output=text --snapshot-ids $snapshot_id --query Snapshots[].StartTime | awk -F "T" '{printf "%s\n", $1}')
    snapshot_date_in_seconds=`date "--date=$snapshot_date" +%s`

    if (( $snapshot_date_in_seconds <= $date_7days_ago_in_seconds )); then
        echo "Deleting snapshot $snapshot_id ..." >> $logfile
        aws ec2 delete-snapshot --snapshot-id $snapshot_id
    else
        echo "Not deleting snapshot $snapshot_id ..." >> $logfile
    fi
done

# One last carriage-return in the logfile...
echo "" >> $logfile

echo "Results logged to $logfile"

echo "Website Backup successful $today" > $report
echo "" >> $report

echo "last snapshot is $snapresult" >> $report

mail -s "DB Website Backup - $today - successful" EMAIL ADDRESS <$report
