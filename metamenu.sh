#!/bin/bash

# Enable this for debugging purposes
#set +x

#set -e

## Needed vars
DEBUG=true
DIRNAME=`dirname $0`
SCRIPT_FILES=`readlink -f $DIRNAME/scripts`
LOG_FILES=`readlink -f $DIRNAME/logs`
RESULT_LOG_FILES=$LOG_FILES/result
PAUSE_SECS=10
DATE=`date +%Y%m%d-%H%M%S`
ME=`logname`
SESSION=$DATE-$$-$ME
LOG=$LOG_FILES/$SESSION.log
BACK_TITLE="`basename $0` - MENU - SESSION $SESSION"
MAIN_MENU_TITLE="MAIN MENU"
PARAMETER_INPUTBOX_TITLE="ENTER REQUIRED PARAMETERS"

## Colors & formatting
NO_COLOR=\\Zn
RED_COLOR=\\Zb\\Z1
BLUE_COLOR=\\Zb\\Z4
declare -r TAB="`echo -e "\t"`"

debug() {
   LOG_DATE=`date +%Y%m%d-%H%M%S`
   msg=`echo -e "$1" | sed "s/^/[$LOG_DATE] - [$$] - [$ME] - /g"`
   echo -e "$msg" >> $LOG
   if $DEBUG; then
      echo -e "$msg"
   fi
}

log_result() {
   LOG_DATE=`date +%Y%m%d-%H%M%S`
   msg=`echo -e "$1" | sed "s/^/[$LOG_DATE] - [$$] - [$ME] - /g"`
   echo -e "$msg" >> $RESULT_LOG
}

show_error_and_exit() {
   dialog_msg="$1"
   for ((i=0; i<$PAUSE_SECS; i++)); do
      dialog --cr-wrap --colors --title "ERROR" --backtitle "${BACK_TITLE}" --infobox "${dialog_msg}\n${RED_COLOR}Exiting in $((PAUSE_SECS-i)) seconds...${NO_COLOR}" 0 0
      sleep 1
   done
   exit 1
}

show_infobox() {
   dialog_title="$1"
   dialog_msg="$2"
   for ((i=0; i<$((PAUSE_SECS/2)); i++)); do
      dialog --cr-wrap --colors --title "${dialog_title}" --backtitle "${BACK_TITLE}" --infobox "${dialog_msg}\n${RED_COLOR}Waiting $((PAUSE_SECS/2-i)) seconds...${NO_COLOR}" 0 0
      sleep 1
   done
}

show_msgbox() {
   dialog_title="$1"
   dialog_msg="$2"
   dialog --cr-wrap --colors --title "${dialog_title}" --backtitle "${BACK_TITLE}" --msgbox "${dialog_msg}\n${RED_COLOR}Press OK to continue...${NO_COLOR}" 0 0
}

cancel_execution() {
   debug "Execution canceled by user. Going back to main menu."
   continue
}

checks() {
   ## Check if log directory exist
   if [ ! -d $LOG_FILES ]; then
      mkdir -p $LOG_FILES 2>&1 >/dev/null
      if [ $? -ne 0 ]; then
         show_error_and_exit "Could not create directory for log files $LOG_FILES\nNothing to do"
      fi
   fi

   if [ ! -d $RESULT_LOG_FILES ]; then
      mkdir -p $RESULT_LOG_FILES 2>&1 >/dev/null
   fi
   
   ## Check if I can write log file
   touch $LOG 2>&1 >/dev/null
   if [ $? -ne 0 ]; then
      show_error_and_exit "Could not write log file $LOG\nNothing to do"
   fi

   ## Check if scripts directory exist
   if [ ! -d $SCRIPT_FILES ]; then
      show_error_and_exit "Could not find directory $SCRIPT_FILES\nNothing to do"
   fi
}

main_menu() {
   ## find all menu scripts
   MENU_ITEM=1
   MENU=""               # This variable contains all menu items in dialog format
   MENU[0]=1             # First item is exit option
   MENU[1]="EXIT"
   MENU_TITLES=""        # This variable contains all scripts titles
   MENU_SCRIPTS=""       # This variable contains all scripts paths
   MENU_PARAMETERS=""    # This variable contains all scripts parameters
   MENU_SUDOS=""              # This variable contains all scripts sudos
   
   for script in `find ${SCRIPT_FILES} -type l -o -type f -perm /u+x | sort`; do
      menu_title=`grep -E "#.*TITLE " ${script} | sed "s/#.*TITLE //g" | sed "s/\"//g" | tail -1`
      menu_parameters=`grep -E "#.*PARAMETER " ${script} | sed "s/#.*PARAMETER //g" | sed "s/\"//g"`
      menu_sudos=`grep -E "#.*USER " ${script} | sed "s/#.*USER //g" | sed "s/\"//g" | tail -1`

      # Build the menu
      MENU[$((2*MENU_ITEM))]=$((MENU_ITEM+1))
      MENU[$((2*MENU_ITEM+1))]="`basename ${script}`${TAB}=> ${menu_title}"
      MENU_TITLES[$MENU_ITEM]=${menu_title}
      MENU_SCRIPTS[$MENU_ITEM]=${script}
      MENU_PARAMETERS[$MENU_ITEM]=${menu_parameters}
      MENU_SUDOS[$MENU_ITEM]=${menu_sudos}
   
      MENU_ITEM=$((MENU_ITEM+1))
   done

   debug "Dialog menu listing\n***\n`echo ${MENU[@]}`\n***"
   debug "Menu scripts titles listing\n***\n`echo ${MENU_TITLES[@]}`\n***"
   debug "Menu scripts paths listing\n***\n`echo ${MENU_SCRIPTS[@]}`\n***"
   debug "Menu scripts parameters listing\n***\n`echo ${MENU_PARAMETERS[@]}`\n***"
   debug "Menu scripts sudos listing\n***\n`echo ${MENU_SUDOS[@]}`\n***"
   
   ## Just in case we didn't find any script...
   if [ ${#MENU_SCRIPTS[@]} -le 1 ]; then
      debug "I did not find any executable script so I'm exiting..."
      show_error_and_exit "Could not find any script on directory $SCRIPT_FILES\nNothing to do"
   fi

   ## OK, now show the menu
   cmd=(dialog --cr-wrap --title "${MAIN_MENU_TITLE}" --backtitle "${BACK_TITLE}" --menu "Choose the script you want to execute:" 0 0 0)
   result=$("${cmd[@]}" "${MENU[@]}" 2>&1 >/dev/tty)
   if [ $? -ne 0 ]; then
      debug "Exiting upon user demand. Goodbye ;)"
      exit 1
   fi

   debug "User chose option number: $result"
  
   if [ $result -eq 1 ]; then
      debug "User requested to exit. Goodbye ;)"
      clear
      exit 0
   fi

   ## This is our script
   script=${MENU_SCRIPTS[$((result-1))]}
   script_title=${MENU_TITLES[$((result-1))]}
   script_parameters=${MENU_PARAMETERS[$((result-1))]}
   script_sudo=${MENU_SUDOS[$((result-1))]}
   if [ ! -z ${script_sudo} ]; then
      script_sudo="sudo -nu ${script_sudo} "
   fi
   debug "User chose script path = ${script}"
   debug "User chose script title = ${script_title}"
   debug "User chose script parameters = ${script_parameters}"
   debug "User chose script sudo = ${script_sudo}"
}

ask_for_parameters() {
   ## Ask for required parameters
   INPUT_ITEMS=0
   INPUT_PARAMETERS=""
   IFS=$'\n'
   for parameter in $script_parameters; do
      parameter_title=`echo $parameter | awk -F"[" '{print $1}'`
      parameter_default=`echo $parameter | awk -F"[" '{print $2}' | sed "s/]//g"`
      cmd=(dialog --cr-wrap --title "`basename ${script}` requires parameters" --backtitle "${BACK_TITLE}" --inputbox "${parameter_title}" 0 $((`echo ${parameter_title} | wc -m`+`basename ${script} | wc -m`)) ${parameter_default})
      result=$("${cmd[@]}" 2>&1 >/dev/tty)
      if [ $? -ne 0 ]; then
         return 1
      fi
      debug "Parameter ${INPUT_ITEMS} is: \"${result}\""
      INPUT_PARAMETERS[${INPUT_ITEMS}]="${result}"
      INPUT_ITEMS=$((INPUT_ITEMS+1))
   done
   INPUT_PARAMETERS=`for parameter in ${INPUT_PARAMETERS[@]}; do echo -n "\\"$parameter\\" "; done`
   script_basename=`basename ${script}`
   script="${script} ${INPUT_PARAMETERS}"
}

execute_script() {
   RESULT_LOG=$RESULT_LOG_FILES/$SESSION-${script_basename}.log
   ## Execute the script
   dialog_msg="\nYou are about to execute the following script:\n\n${script_sudo}${script_basename} ${INPUT_PARAMETERS}\n\nDo you want to continue?\n\n"
   dialog --cr-wrap --title "${script_basename} confirmation" --backtitle "${BACK_TITLE}" --yesno "${dialog_msg}" 0 0 || return 1

   ## We reach to this point only if user answered yes
   debug "Executing this command: ${script}"
   result_msg=`eval ${script_sudo}${script} 2>&1`
   result=$?
   log_result "Execution: ${script_sudo}${script}"

   if [ $result -eq 0 ]; then
      debug "Exec result is [OK]:\n${result_msg}"
      log_result "Result [OK]:\n${result_msg}"
      dialog_msg="\n${BLUE_COLOR}Script successfully executed${NO_COLOR}. Executed command was:\n\n${script_sudo}${script_basename}\n\nExecution output was:\n\n************************\n\n${result_msg}\n\n************************\n"
      #show_infobox "EXECUTION_SUCCESS" "${dialog_msg}"
      show_msgbox "EXECUTION SUCCESS" "${dialog_msg}"
   else
      debug "Exec result is [FAILED]:\n${result_msg}"
      log_result "Result [FAILED]:\n${result_msg}"
      dialog_msg="\n${RED_COLOR}EXECUTION FAILED${NO_COLOR}. Executed command was:\n\n${script_sudo}${script_basename}\n\nExecution output was:\n\n************************\n\n${result_msg}\n\n************************\n"
      #show_infobox "EXECUTION FAILED" "${dialog_msg}"
      show_msgbox "EXECUTION FAILED" "${dialog_msg}"
   fi
}

while [ true ]; do
   checks
   debug "New session $SESSION"
   main_menu
   ask_for_parameters || cancel_execution
   execute_script || cancel_execution
   clear
done
