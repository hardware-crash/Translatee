#!/bin/bash

#Function to get the full path of scrip regardless of where the script is run from
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
CFN_TEMPLATE="$SCRIPTPATH/cftemplate-final.yml"
echo "Script folder : $SCRIPTPATH"

CODEBUCKET=$(aws cloudformation describe-stacks --stack-name vt-code --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorCodeBucket'].OutputValue" --output text)
CODEBUCKET2=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorBucket'].OutputValue" --output text)

# Remove all contents from the bucket recursively
echo "Removing all contents from the bucket: $CODEBUCKET"
aws s3 rm "s3://$CODEBUCKET" --recursive

# Optional: Wait and verify that the bucket is empty
echo "Verifying that the bucket is empty..."
aws s3 ls "s3://$CODEBUCKET" --recursive

# Remove all contents from the bucket recursively
echo "Removing all contents from the bucket: $CODEBUCKET2"
aws s3 rm "s3://$CODEBUCKET2" --recursive

# Optional: Wait and verify that the bucket is empty
echo "Verifying that the bucket is empty..."
aws s3 ls "s3://$CODEBUCKET2" --recursive

# Delete CloudFormation stacks
echo "Deleting CloudFormation stack: vt-code"
aws cloudformation delete-stack --stack-name vt-code

echo "Deleting CloudFormation stack: s2s-translator"
aws cloudformation delete-stack --stack-name s2s-translator

# Optional: Wait for stack deletion to complete
echo "Waiting for stack vt-code to be deleted..."
aws cloudformation wait stack-delete-complete --stack-name vt-code

echo "Waiting for stack s2s-translator to be deleted..."
aws cloudformation wait stack-delete-complete --stack-name s2s-translator

echo "Stacks deleted successfully."
