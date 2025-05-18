import json
import boto3
import time
import os

region = os.environ["AWS_REGION"]
kms_key_id = os.environ.get("RDS_KMS_KEY", "alias/aws/rds")

ec2 = boto3.client('ec2', region_name=region)
rds = boto3.client('rds', region_name=region)

MINIMUM_EXECUTION_BUFFER_MS = 5000


def lambda_handler(event, context):
    # start_time = time.time()
    
    print("Starting EBS volume remediation...")
    remediate_all_unencrypted_ebs_volumes(context)

    print("\n\nStarting RDS instance remediation...")
    remediate_all_unencrypted_rds_instances(context)

    return {
        'statusCode': 200,
        'body': json.dumps('Remediation completed.')
    }

def remediate_all_unencrypted_ebs_volumes(context):
    try:
        # Collect all volumes ONCE
        all_volumes = []
        next_token = None
        while True:
            if next_token:
                response = ec2.describe_volumes(NextToken=next_token)
            else:
                response = ec2.describe_volumes()
            all_volumes.extend(response['Volumes'])
            next_token = response.get('NextToken')
            if not next_token:
                break

        # Filter unencrypted volumes
        unencrypted_volumes = [v for v in all_volumes if not v['Encrypted']]
        print(f"Found {len(unencrypted_volumes)} unencrypted EBS volumes to remediate.")

    except Exception as e:
        print(f"Failed to list EBS volumes: {str(e)}")
        return

    for volume in unencrypted_volumes:
        if context.get_remaining_time_in_millis() < MINIMUM_EXECUTION_BUFFER_MS:
            print("Stopping EBS loop early to avoid timeout.")
            return

        volume_id = volume['VolumeId']
        try:
            print(f"Remediating unencrypted EBS volume: {volume_id}")
            remediate_ebs_volume(volume, context)
        except Exception as e:
            print(f"Error remediating volume {volume_id}: {str(e)}")


def remediate_all_unencrypted_rds_instances(context):
    try:
        instances = rds.describe_db_instances()
    except Exception as e:
        print(f"Failed to describe RDS instances: {str(e)}")
        return

    for instance in instances['DBInstances']:
        if context.get_remaining_time_in_millis() < MINIMUM_EXECUTION_BUFFER_MS:
            print("Stopping RDS loop early to avoid timeout.")
            return

        if not instance['StorageEncrypted']:
            db_id = instance['DBInstanceIdentifier']
            try:
                print(f"Remediating unencrypted RDS instance: {db_id}")
                remediate_rds_instance(instance, context)
            except Exception as e:
                print(f"Error remediating RDS instance {db_id}: {str(e)}")

# Logic for EBS volume encryption
def remediate_ebs_volume(volume, context):
    volume_id = volume['VolumeId']
    availability_zone = volume['AvailabilityZone']

    if context.get_remaining_time_in_millis() < MINIMUM_EXECUTION_BUFFER_MS:
        print("Aborting remediation to avoid timeout.")
        return

    print(f"Creating snapshot of volume {volume_id}...")
    snapshot = ec2.create_snapshot(VolumeId=volume_id, Description=f"Snapshot of {volume_id} for encryption")
    snapshot_id = snapshot['SnapshotId']

    waiter = ec2.get_waiter('snapshot_completed')
    print(f"Waiting for snapshot {snapshot_id} to complete...")
    waiter.wait(SnapshotIds=[snapshot_id])
    print(f"Snapshot {snapshot_id} completed.")

    print(f"Copying snapshot {snapshot_id} with encryption...")
    copied_snapshot = ec2.copy_snapshot(
        SourceSnapshotId=snapshot_id,
        SourceRegion=ec2.meta.region_name,
        Encrypted=True,
        Description=f"Encrypted copy of {snapshot_id}"
    )
    encrypted_snapshot_id = copied_snapshot['SnapshotId']

    print(f"Waiting for encrypted snapshot {encrypted_snapshot_id} to complete...")
    waiter.wait(SnapshotIds=[encrypted_snapshot_id])
    print(f"Encrypted snapshot {encrypted_snapshot_id} ready.")

    print(f"Creating new encrypted volume in {availability_zone}...")
    new_volume = ec2.create_volume(
        SnapshotId=encrypted_snapshot_id,
        AvailabilityZone=availability_zone,
        Encrypted=True,
        VolumeType=volume['VolumeType'],
        TagSpecifications=[{
            'ResourceType': 'volume',
            'Tags': [{'Key': 'Name', 'Value': f'{volume_id}-encrypted'}]
        }]
    )
    new_volume_id = new_volume['VolumeId']
    print(f"Encrypted volume {new_volume_id} created from snapshot {encrypted_snapshot_id}.")

    print(f"[Info] Volume {volume_id} is now encrypted as {new_volume_id}. You may attach it then delete the unencrypted version manually or wait for automated cutover.")

# Logic for RDS encryption
def remediate_rds_instance(instance, context):
    db_id = instance['DBInstanceIdentifier']
    snapshot_id = f"{db_id}-unencrypted-snapshot"

    if context.get_remaining_time_in_millis() < MINIMUM_EXECUTION_BUFFER_MS:
        print("Aborting remediation to avoid timeout.")
        return

    print(f"Creating snapshot of RDS instance {db_id}...")
    rds.create_db_snapshot(
        DBSnapshotIdentifier=snapshot_id,
        DBInstanceIdentifier=db_id
    )

    waiter = rds.get_waiter('db_snapshot_available')
    print(f"Waiting for RDS snapshot {snapshot_id} to complete...")
    waiter.wait(DBSnapshotIdentifier=snapshot_id)
    print(f"Snapshot {snapshot_id} completed.")

    encrypted_snapshot_id = f"{snapshot_id}-encrypted"
    print(f"Copying RDS snapshot {snapshot_id} with encryption...")
    rds.copy_db_snapshot(
        SourceDBSnapshotIdentifier=snapshot_id,
        TargetDBSnapshotIdentifier=encrypted_snapshot_id,
        KmsKeyId=kms_key_id,
        CopyTags=True,
        Tags=[{'Key': 'Name', 'Value': f'{db_id}-encrypted-copy'}],
        SourceRegion=rds.meta.region_name,
        Encrypted=True
    )

    waiter = rds.get_waiter('db_snapshot_available')
    print(f"Waiting for encrypted RDS snapshot {encrypted_snapshot_id} to complete...")
    waiter.wait(DBSnapshotIdentifier=encrypted_snapshot_id)
    print(f"Encrypted snapshot {encrypted_snapshot_id} ready.")

    new_db_id = f"{db_id}-encrypted"
    print(f"Restoring new RDS instance {new_db_id} from encrypted snapshot...")
    rds.restore_db_instance_from_db_snapshot(
        DBInstanceIdentifier=new_db_id,
        DBSnapshotIdentifier=encrypted_snapshot_id,
        DBInstanceClass=instance['DBInstanceClass'],
        Engine=instance['Engine'],
        AvailabilityZone=instance['AvailabilityZone'],
        PubliclyAccessible=instance['PubliclyAccessible'],
        MultiAZ=instance['MultiAZ'],
        AutoMinorVersionUpgrade=instance['AutoMinorVersionUpgrade'],
        Tags=[{'Key': 'Name', 'Value': f'{new_db_id}'}]
    )

    print(f"Encrypted RDS instance {new_db_id} creation initiated.")
