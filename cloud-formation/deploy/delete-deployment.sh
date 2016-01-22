#!/bin/bash

##################################################################

#         This script is use to help deleting elements of a stack
#         That needs to be deleted manuelly

#################################################################


###############################################################

## Function that verify if a list contains a string :
## Parameters:
##        $1 List of string   a list you want to search
##        $2 String           string you are lokking for
listcontains() {
        for word in $1;
        do
           [[ $word == $2 ]] && return 0
        done
       return 1
}


## Function to check if the stack delete succeeded. If after x number of minutes it's not successful, we give up and exit 1
## Parameters:
##     $1 String   Why is the fonction called
##     $2 String   status expected
##     $3 Integer  number of minutes to wait
##     $4 String   command to pass
checkStackStatus()
{
    count=0
    STACK_STATUS="" 
    while [ -z "$STACK_STATUS" ]
     do
        STATUS=`eval $4`

        if [ "$STATUS" != "$2" ]
        then
            if [ $count -lt $3 ]
            then
                echo "Waiting for  $1 to complete, current status : "$STATUS
                sleep 60
                count=$((count+1))
            else
                STACK_STATUS=$STATUS
                echo "Giving up on Stack $1"
                exit 1
            fi
        else
           STACK_STATUS=$STATUS
           echo "Stack $1 status : "$STATUS
        fi
     done
}


#############################################################
##    get list of stacks and choose the one to be deleted
##

TMP_FILE=/tmp/stack.info
aws cloudformation describe-stacks | jq .Stacks[].StackName  | tr -d '\"' > $TMP_FILE
STACKS_LIST=$(cat $TMP_FILE  | awk '{ print $0 }')


echo -e ""
echo -e "Here is the list of existing stacks : "
echo -e ""

while true; do
        for stack in $STACKS_LIST
        do
            echo $stack
        done

        echo -e ""
        read -p "Which stack do you want to delete : " choice

        if listcontains "$STACKS_LIST" "$choice"
           then break;
        else
            echo -e "\n***  Please choose a valid stack  ***\n"
        fi
done

STACK_NAME=$choice

ENV="" # as a protection to don't delete the root of s3 bucket
ENV=`aws cloudformation describe-stacks --stack-name $choice| jq '.Stacks[].Parameters[] | select (.ParameterKey == "Environement") | .ParameterValue' | tr -d '\"'`


if [ -z "$ENV" ]
    then
       ENV=`aws cloudformation describe-stacks --stack-name $choice| jq '.Stacks[].Parameters[] | select (.ParameterKey == "Environment") | .ParameterValue' | tr -d '\"'`
fi


#############  Validating the entry by asking the name of the env. It need to match
echo -e ""
echo "Confirm that you want this stack to be deleted by entering the name of its Environement :"
echo -e ""

while true; do

        echo -e ""
        read -p "What is the environement : " confirmchoice
        echo "Env : $ENV Choice: $confirmchoice"
        if [[ "$ENV" == "$confirmchoice" ]]
           then break;
        else
            echo -e "\n***  You did not enter the correct Environement ***\n"
        fi
done

ENV=`echo $confirmchoice  | tr '[:upper:]' '[:lower:]'`

###############  Confirmation

while true; do
  echo -e ""
  echo -e "*********    Please confirm that you want to delete :  ***********"
  echo -e "*********    Stack : $STACK_NAME"
  echo -e "*********    Env   : $ENV"
  echo -e ""
  read -p "Do you want to continue (Y/N)?" ANSWER
    case $ANSWER in
         [yY] | [yY][Ee][Ss] )
            echo "You Agree to continue"
               break 
               ;;

          [nN] | [n|N][O|o] )
              echo "Not agreed, you can't proceed the stack deletion";
              exit 1
              ;;
           *) echo "Invalid input"
              ;;
    esac
done



################################ List of instances that we will change the termination protection and send the termination signal

#List of ec2 that requires to be deleted manually:
LIST_INSTANCE_PRINT=`aws cloudformation list-stack-resources --stack-name $STACK_NAME | jq '.StackResourceSummaries[] | select (.ResourceType=="AWS::EC2::Instance")'`
LIST_INSTANCES_DELETE=`aws cloudformation list-stack-resources --stack-name $STACK_NAME | jq '.StackResourceSummaries[] | select (.ResourceType=="AWS::EC2::Instance") |  .PhysicalResourceId' | tr -d '\"'`

#echo $LIST_INSTANCE_PRINT

#First deleting all the server manually.  This is to avoid the termination plan protection
for ec2 in $LIST_INSTANCES_DELETE
    do
       echo check if $ec2 is protected
       protection=`aws ec2  describe-instance-attribute --instance-id $ec2 --attribute disableApiTermination | jq .DisableApiTermination | jq .Value`
       running=`aws ec2 describe-instance-status  --instance-id $ec2 | jq .InstanceStatuses[].InstanceState.Name`
       if [[ "$protection" == "true" ]]
         then  echo "Modifying  $ec2 $protection to false and deleting it"
         aws ec2 modify-instance-attribute --instance-id $ec2 --disable-api-termination false
         aws ec2 terminate-instances --instance-id $ec2
       else
         echo "No need to delete $ec2.  It is either not running (running = $running) or not protected (protection = $protection)"
       fi  
    done


#############   Deleting the stack and monitor the status

 aws cloudformation delete-stack  --stack-name $STACK_NAME
 COMMAND="aws cloudformation list-stacks | jq '.StackSummaries[] | select (.StackName==\"$STACK_NAME\") |  .StackStatus'| cut -d \"\\\"\" -f2"
 checkStackStatus "delete stack" "DELETE_COMPLETE" 25 "$COMMAND"

echo "Exiting script"
