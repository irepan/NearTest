#!/bin/bash

export scriptDir=$(cd `dirname $0` ; pwd)
export REGION=$(aws configure get region)

function test_stack {
    typeset var local STACK_NAME=$1
    aws cloudformation describe-stacks --stack-name $STACK_NAME >/dev/null 2>&1
    exitSts=$?
    if [ $exitSts -eq 0 ] ; then
        echo 0
    else
        echo 1
    fi
}

function stack_exists {
    typeset var local STACK_NAME=$1
    [ $(test_stack "$STACK_NAME") -eq 0 ]
}

function get_stack_output_file {
    typeset var local STACK_NAME=$1
    echo "$scriptDir/../$STACK_NAME.outputs.json"
}

function get_stack_outputs {
    typeset var local STACK_NAME=$1
    typeset var local FILE_NAME=$(get_stack_output_file $STACK_NAME)
    if [ ! -f $FILE_NAME ] ; then
            aws cloudformation describe-stacks --stack-name $STACK_NAME | jq -r '[.Stacks[0].Outputs[] | {key: .OutputKey, value: .OutputValue}] | from_entries' > $FILE_NAME
        fi
    cat $FILE_NAME
}

function create_stack {
    typeset var local STACK_NAME=$1
    typeset var local STACK_BODY=$2
    typeset var local STACK_FILE_NAME=$(get_stack_output_file $STACK_NAME)
    if ! stack_exists $STACK_NAME ; then
        aws cloudformation create-stack \
        --template-body file://${STACK_BODY}  \
        --stack-name ${STACK_NAME}

        aws cloudformation wait stack-create-complete \
        --stack-name ${STACK_NAME}
    fi
    #aws cloudformation describe-stacks --stack-name $STACK_NAME
    if [ ! -f $STACK_FILE_NAME ] ; then
        rm -f $STACK_FILE_NAME
    fi
    get_stack_outputs $STACK_NAME
}

function create_or_update_stack {
    typeset var local STACK_NAME=$1
    typeset var local STACK_BODY=$2
    typeset var local STACK_PARAMETERS=
    typeset var local STACK_FILE_NAME=$(get_stack_output_file $STACK_NAME)
    if [ $# -gt 2 ] ; then
        STACK_PARAMETERS="$3"
    fi
    typeset var local exitSts=0
    if stack_exists $STACK_NAME ; then
        echo "updating stack $STACK_NAME"
        aws cloudformation update-stack \
        --template-body file://${STACK_BODY}  \
        --stack-name ${STACK_NAME} \
        $STACK_PARAMETERS \
         2>/dev/null
        exitSts=$?
        #No update needed
        if [ $exitSts -eq 0 ] ; then
            aws cloudformation wait stack-update-complete \
            --stack-name ${STACK_NAME}
        else
            echo "No updates needed for stack $STACK_NAME"
        fi
    else
        echo "creating stack $STACK_NAME"
        aws cloudformation create-stack \
        --template-body file://${STACK_BODY}  \
        --stack-name ${STACK_NAME} \
        $STACK_PARAMETERS

        aws cloudformation wait stack-create-complete \
        --stack-name ${STACK_NAME}
    fi
    #aws cloudformation describe-stacks --stack-name $STACK_NAME
    if [ ! -f $STACK_FILE_NAME ] ; then
        rm -f $STACK_FILE_NAME
    fi
    get_stack_outputs $STACK_NAME
}

function wait_for_stack_operation {
    typeset var local STACK_NAME=$1
    typeset var local exitSts=0
    typeset var local STACK_OPERATION=$(aws cloudformation describe-stacks --stack-name MysfitsCognitoStack | jq ' .Stacks[0].StackStatus ' | grep -o -e 'CREATE' -e 'UPDATE' -e 'DELETE')
    case $STACK_OPERATION in
        'CREATE')
            aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
            ;;
        'UPDATE')
            aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
            ;;
    esac
}

function getTaskOutputsValue {
    typeset var local STACK_NAME=$1
    typeset var local VALUE=$2
    get_stack_outputs $STACK_NAME | jq ". | .$VALUE" | sed 's/.*"\([^"]*\)".*/\1/'
}

function test_command {
    typeset var local COMMAND=$1
    typeset var local exitSts=0
    which $COMMAND >/dev/null 2>&1
    exitSts=$?
    if [ $exitSts -eq 0 ] ; then
        echo 0
    else
        echo 1
    fi
}

function command_exists {
    typeset var local COMMAND="$1"
    [ $(test_command "$COMMAND") -eq 0 ] 
}
