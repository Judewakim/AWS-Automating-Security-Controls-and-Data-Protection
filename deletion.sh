#!/bin/bash

#This bash script terminates the unencrypted RDS DB and EC2 instance

# Variables
DB_INSTANCE_IDENTIFIER="unencrypted-rds-instance" # Same as the creation script
INSTANCE_ID="your-instance-id"  # Change to your EC2 instance ID

# Delete unencrypted RDS DB
aws rds delete-db-instance \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --skip-final-snapshot

# Wait for the DB instance to be deleted
aws rds wait db-instance-deleted --db-instance-identifier $DB_INSTANCE_IDENTIFIER

echo "Unencrypted RDS DB instance deleted."

# Terminate unencrypted EC2 instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Wait for the instance to be terminated
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID

echo "Unencrypted EC2 instance deleted."
