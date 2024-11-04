#!/bin/bash

#This bash script creates the unencrypted RDS DB and EC2 instance

# Variables
DB_INSTANCE_IDENTIFIER="unencrypted-rds-instance"
DB_INSTANCE_TYPE="db.t2.micro" # Change to preferred instance type
DB_NAME="testdb" # Change db name
DB_USERNAME="admin" # Change username
DB_PASSWORD="password" # Change password

EC2_INSTANCE_TYPE="t2.micro" # Change to preferred instance type
AMI_ID="ami-0c55b159cbfafe01e"  # Change to a valid AMI in your region
KEY_NAME="your-key-pair"  # Change to your key pair name

# Create unencrypted RDS DB (change to preferred engine)
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --db-instance-class $DB_INSTANCE_TYPE \
    --engine mysql \
    --allocated-storage 20 \
    --master-username $DB_USERNAME \
    --master-user-password $DB_PASSWORD \
    --no-storage-encrypted

# Wait for the DB instance to be created
aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_IDENTIFIER

echo "Unencrypted RDS DB instance created. Check your email for alarms."

# Create unencrypted EC2 instance with unencrypted EBS
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $EC2_INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --block-device-mappings "[{\"DeviceName\": \"/dev/sda1\", \"Ebs\": {\"VolumeSize\": 20, \"Encrypted\": false}}]" \
    --query "Instances[0].InstanceId" \
    --output text)

# Wait for the instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

echo "Unencrypted EC2 instance created. Check your email for alarms."
