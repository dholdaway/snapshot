## REQUIREMENTS:
# This script requires the AWS CLI tools to be installed.
# Read me about AWS CLI at: https://aws.amazon.com/cli/

# Assumptions: these commands are ran as the root user.
#
# Linux install instructions for AWS CLI:
# - Install Python pip (e.g. yum install python-pip)
# - Then run: pip install awscli

# Once the AWS CLI has been installed, you'll need to configure it with the credentials of an IAM user that
# has permission to take and delete snapshots of EBS volumes.
# Configure AWS CLI by running this command:
#               aws configure

# Copy this script to /opt/aws/ebs-snapshot.sh
# And make it exectuable: chmod +x /opt/aws/ebs-snapshot.sh

# Then setup a crontab job for nightly backups:
# (You will have to specify the location of the AWS CLI Config file)
#
# AWS_CONFIG_FILE="/root/.aws/config"
# 00 06 * * *     root    /opt/aws/snapshot.sh >> /var/log/snapshot.log 2>&1
