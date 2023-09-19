#!/bin/bash

# This will copy all files in./data/ngenresrouces_bucket into the ngenresourcesdev bucket



# Check if the correct number of arguments is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <aws-profile-name>"
    exit 1
fi
aws_profile="$1"

# Check if the bucket exists
bucket_name="ngenforcingresources"
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
bucket_exists=$(aws s3 ls "s3://$bucket_name" --region "us-west-2" 2>&1)

# if [[ $bucket_exists == "NoSuchBucket" ]]; then
#     echo "Bucket $bucket_name does not exist."
#     exit 1
# else
#     echo "Bucket exists, copying ngenresources into cloud..."
# fi

set -e

# Loop through files in the directory
for file in "$script_dir/../data/ngenresources_bucket"/*; do
    if [ -f "$file" ]; then
        # Get the filename from the path
        filename=$(basename "$file")
        
        # Use AWS CLI to upload the file to the S3 bucket
        aws --profile "$aws_profile" s3 cp "$file" "s3://$bucket_name/$filename"
        
        # Check the exit status of the AWS CLI command
        if [ $? -eq 0 ]; then
            echo "Uploaded $filename to $bucket_name"
        else
            echo "Failed to upload $filename"
        fi
    fi
done

exit 1
