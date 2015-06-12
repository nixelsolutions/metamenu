#!/bin/bash
# USER root
# TITLE Change your password
# PARAMETER Enter your new password

USERNAME=`logname`
FORBIDDEN_USERS="root"
NEW_PASSWORD=$1

if [ -z $NEW_PASSWORD ]; then
   echo "ERROR: You didn't enter a password"
   exit 1
fi

for user in $FORBIDDEN_USERS; do
   if [ "$USERNAME" == "$user" ]; then
      echo "ERROR: I cannot change password for user $user"
      exit 1
   fi
done

echo "$USERNAME:$NEW_PASSWORD" | chpasswd && echo "Password changed"
