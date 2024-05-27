#!/bin/bash

#Function to get the full path of scrip regardless of where the script is run from
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
CFN_TEMPLATE="$SCRIPTPATH/cftemplate.yml"

(cd $SCRIPTPATH/../lambda && mvn clean package)

CODE_CF_STACK_ID=$(aws cloudformation create-stack --stack-name vt-code --template-body "file://$SCRIPTPATH/codetemplate.yml" --query "StackId" --output text)

aws cloudformation wait stack-create-complete --stack-name vt-code

CODEBUCKET=$(aws cloudformation describe-stacks --stack-name vt-code --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorCodeBucket'].OutputValue" --output text)

echo "Code Bucket : $CODEBUCKET"

#Upload code to code bucket
aws s3 cp $SCRIPTPATH/../lambda/target/translator-app-1.0-SNAPSHOT.jar s3://$CODEBUCKET

aws cloudformation create-stack --stack-name s2s-translator --template-body file://$CFN_TEMPLATE --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=CodeBucket,ParameterValue=$CODEBUCKET

aws cloudformation wait stack-create-complete --stack-name s2s-translator

UIBUCKET=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorBucket'].OutputValue" --output text)
IDENTITYPOOLID=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'IdentityPoolIdOutput'].OutputValue" --output text)
LAMBDAFUNCTION=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorLambda'].OutputValue" --output text)
AWSREGION=$(aws configure get region)
echo "var bucketName = \"$UIBUCKET\";" > $SCRIPTPATH/../ui/js/voice-translator-config.js
echo "var IdentityPoolId = \"$IDENTITYPOOLID\";" >> $SCRIPTPATH/../ui/js/voice-translator-config.js
echo "var lambdaFunction = \"$LAMBDAFUNCTION\";" >> $SCRIPTPATH/../ui/js/voice-translator-config.js
echo "var awsRegion = \"$AWSREGION\";" >> $SCRIPTPATH/../ui/js/voice-translator-config.js

aws s3 cp $SCRIPTPATH/../ui/ s3://$UIBUCKET --recursive

APPURL=$(aws cloudformation describe-stacks --stack-name s2s-translator --query "Stacks[0].Outputs[?OutputKey == 'VoiceTranslatorLink'].OutputValue" --output text)

echo "App URL : $APPURL"
