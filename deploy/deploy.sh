#!/bin/bash

#Function to get the full path of scrip regardless of where the script is run from
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
CFN_TEMPLATE="$SCRIPTPATH/cftemplate.yml"

# Change directory to the lambda subdirectory and run 'mvn clean package' to build the Java project.
(cd $SCRIPTPATH/../lambda && mvn clean package)

# Create a new AWS CloudFormation stack for the voice translator application using
# a CloudFormation template. Save the Stack ID returned by the command.
CODE_CF_STACK_ID=$(aws cloudformation create-stack --stack-name vt-code --template-body "file://$SCRIPTPATH/codetemplate.yml" --query "StackId" --output text)

# Wait for the CloudFormation stack creation to complete.
aws cloudformation wait stack-create-complete --stack-name vt-code

# Query the newly created stack to get the output value which is the S3 bucket name where code will be stored.
CODEBUCKET=$(aws cloudformation describe-stacks --stack-name vt-code --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorCodeBucket'].OutputValue" --output text)

# Print the S3 bucket name to the console.
echo "Code Bucket : $CODEBUCKET"

# Upload the compiled jar file from the local machine to the S3 bucket specified.
aws s3 cp $SCRIPTPATH/../lambda/target/translator-app-1.0-SNAPSHOT.jar s3://$CODEBUCKET

# Create another CloudFormation stack for the translator application specifying
# the S3 bucket as a parameter, and enable certain IAM capabilities.
aws cloudformation create-stack --stack-name s2s-translator --template-body file://$CFN_TEMPLATE --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=CodeBucket,ParameterValue=$CODEBUCKET

# Wait for the second CloudFormation stack creation to complete.
aws cloudformation wait stack-create-complete --stack-name s2s-translator

# Get outputs from the second CloudFormation stack, including the UI bucket, Identity Pool ID, and Lambda function.
UIBUCKET=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorBucket'].OutputValue" --output text)
IDENTITYPOOLID=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'IdentityPoolIdOutput'].OutputValue" --output text)
LAMBDAFUNCTION=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorLambda'].OutputValue" --output text)
AWSREGION=$(aws configure get region)

# Save configuration data to a JavaScript file to be used by the UI.
echo "var bucketName = \"$UIBUCKET\";" > $SCRIPTPATH/../ui/js/voice-translator-config.js
echo "var IdentityPoolId = \"$IDENTITYPOOLID\";" >> $SCRIPTPATH/../ui/js/voice-translator-config.js
echo "var lambdaFunction = \"$LAMBDAFUNCTION\";" >> $SCRIPTPATH/../ui/js/voice-translator-config.js
echo "var awsRegion = \"$AWSREGION\";" >> $SCRIPTPATH/../ui/js/voice-translator-config.js

# Upload the UI directory recursively to the specified S3 bucket for the UI.
aws s3 cp $SCRIPTPATH/../ui/ s3://$UIBUCKET --recursive

# Get the application URL from the CloudFormation stack outputs and print it.
APPURL=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorLink'].OutputValue" --output text)
echo "App URL : $APPURL"
