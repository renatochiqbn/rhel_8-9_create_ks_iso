#!/bin/bash
# settings_manager.sh - Script 1: Handles settings file management

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Please install it first."
    exit 1
fi

# Initialize variables
SETTINGS_FILE=""
TEMP_FILE=$(mktemp)
HEIGHT=15
WIDTH=100

# Function for Media Selection
select_media() {
    local settings_file="$1"
    local SRCDIR=""
    local ISOSRCDIR=""
    local OEMSRCISO=""
    local KSLOCATION=""
    
    # Source existing settings if file exists
    if [[ -f "$settings_file" ]]; then
        source "$settings_file"
    fi
    
    # Set defaults if not set from file
    SRCDIR="${SRCDIR:-${PWD}}"
    ISOSRCDIR="${ISOSRCDIR:-"$SRCDIR/ISO"}"
    OEMSRCISO="${OEMSRCISO:-"rhel-8.10-x86_64-dvd.iso"}"
    KSLOCATION="${KSLOCATION:-"hd:LABEL=RHEL-8-10-0-BaseOS-x86_64:/ks.cfg"}"
    
    local ret=0
    while true; do
        # Store menu selection in TEMP_FILE
        exec 3>&1
        choice=$(dialog --clear --title "Configuration Menu" \
                       --menu "Please select an option:" $HEIGHT 200 5 \
                       1 "Enter Working Directory [$SRCDIR]" \
                       2 "Enter ISO Source Directory [...${ISOSRCDIR: -11}]" \
                       3 "Enter OEM Source ISO Filename [$OEMSRCISO]" \
                       4 "Enter Kickstart Location [$KSLOCATION]" \
                       5 "Save and Continue" \
                       2>&1 1>&3)
        ret=$?
        exec 3>&-

        # Check if user pressed Cancel or ESC
        if [[ $ret -ne 0 ]]; then
            clear
            return 1
        fi
        
        case "$choice" in
            1)
                exec 3>&1
                new_dir=$(dialog --clear --title "Source Directory" \
                         --inputbox "Enter Source Directory:" 8 $WIDTH "$SRCDIR" \
                         2>&1 1>&3)
                ret=$?
                exec 3>&-
                if [[ $ret -eq 0 ]]; then
                    SRCDIR="$new_dir"
                fi
                ;;
            2)
                exec 3>&1
                new_iso_dir=$(dialog --clear --title "ISO Source Directory" \
                             --inputbox "Enter ISO Source Directory:" 8 $WIDTH "$ISOSRCDIR" \
                             2>&1 1>&3)
                ret=$?
                exec 3>&-
                if [[ $ret -eq 0 ]]; then
                    ISOSRCDIR="$new_iso_dir"
                fi
                ;;
            3)
                # Get list of ISO files from the ISOSRCDIR
                if [[ -d "$ISOSRCDIR" ]]; then
                    # Create menu items from ISO files
                    local iso_files=()
                    local counter=1
                    while IFS= read -r file; do
                        iso_files+=("$counter" "$file")
                        ((counter++))
                    done < <(find "$ISOSRCDIR" -maxdepth 1 -type f -name "*.iso" -exec basename {} \;)

                    if [[ ${#iso_files[@]} -eq 0 ]]; then
                        dialog --title "Warning" \
                               --msgbox "No ISO files found in $ISOSRCDIR" 8 60
                        continue
                    fi

                    # Show menu with ISO files
                    exec 3>&1
                    new_iso=$(dialog --clear --title "Select OEM Source ISO" \
                             --menu "Choose an ISO file:" 15 $WIDTH 6 \
                             "${iso_files[@]}" \
                             2>&1 1>&3)
                    ret=$?
                    exec 3>&-

                    if [[ $ret -eq 0 ]]; then
                        # Convert selection number back to filename
                        OEMSRCISO="${iso_files[$(( (new_iso - 1) * 2 + 1 ))]}"
                    fi
                else
                    dialog --title "Error" \
                           --msgbox "Directory $ISOSRCDIR does not exist!" 8 60
                fi
                ;;
            4)
                exec 3>&1
                new_ks=$(dialog --clear --title "Kickstart Location" \
                        --inputbox "Enter Kickstart Location:" 8 $WIDTH "$KSLOCATION" \
                        2>&1 1>&3)
                ret=$?
                exec 3>&-
                if [[ $ret -eq 0 ]]; then
                    KSLOCATION="$new_ks"
                fi
                ;;
            5)
                # Save settings and exit
                printf "SRCDIR=\"%s\"\nISOSRCDIR=\"%s\"\nOEMSRCISO=\"%s\"\nKSLOCATION=\"%s\"\n" "$SRCDIR" "$ISOSRCDIR" "$OEMSRCISO" "$KSLOCATION" > $TEMP_FILE
                clear
                return 0
                ;;
            *)
                dialog --title "Error" --msgbox "Invalid choice" 8 40
                continue
                ;;
        esac
    done
}

# Select OS type
select_OS() {
    local settings_file=$1
    local choice_os=""
    local choice_os_version=""
    local output_file=$(mktemp)  # Create a temporary file for output
    
    # Source existing settings if file exists
    if [[ -f "$settings_file" ]]; then
        source "$settings_file"
    fi
    
    # Set defaults if not already set
    local OSTYPE="${OSTYPE:-RHEL}"
    local MAJOROSVERSION="${MAJOROSVERSION:-8}"
    local ISOFFLINEREPO="${ISOFFLINEREPO:-false}"
    local OFFLINEREPO="${OFFLINEREPO:-""}"

    # OS Flavor Selection
    while true; do
        choice_os=$(dialog --clear --title "Select Linux Distribution" \
                            --menu "Current OS selected: [$OSTYPE $MAJOROSVERSION]" 13 50 5 \
                            "RHEL" "Red Hat Enterprise Linux" \
                            "CentOS" "CentOS Linux" \
                            "Offline_Repo" "Current Repo:${OFFLINEREPO:- none} " \
                            "Continue" "Save and Continue" \
                            2>&1 1>/dev/tty)
        ret=$?
        if [[ $ret -ne 0 ]]; then  # Handle Cancel
            rm -f "$output_file"
            return 1
        fi

        # Populate Versions based on Flavor
        case "$choice_os" in
            "RHEL")
                choice_os_version=$(dialog --clear --title "Select RHEL OS version" \
                            --menu "Choose the OS distribution:" 10 50 5 \
                            "8" "Red Hat Enterprise Linux 8" \
                            "9" "Red Hat Enterprise Linux 9" \
                            2>&1 1>/dev/tty)  # RHEL versions
                if [[ $? -eq 0 ]]; then
                    OSTYPE="RHEL"
                    MAJOROSVERSION="$choice_os_version"
                fi
                ;;
            "CentOS")
                choice_os_version=$(dialog --clear --title "Select CentOS version" \
                            --menu "Choose the OS distribution:" 10 50 5 \
                            "8" "CentOS Linux Stream 8" \
                            "9" "CentOS Linux Stream 9" \
                            2>&1 1>/dev/tty) # CentOS versions
                if [[ $? -eq 0 ]]; then
                    OSTYPE="CentOS"
                    MAJOROSVERSION="$choice_os_version"
                fi
                ;;
            "Offline_Repo")
                OFFLINEREPO=$(dialog --clear --inputbox \
                    "Enter offline repo server address. (ex: https://repo.mil/offline):" 8 $WIDTH "$OFFLINEREPO" \
                    2>&1 >/dev/tty)
                if [[ $? -eq 0 && -n "$OFFLINEREPO" ]]; then
                    ISOFFLINEREPO="true"
                fi
                ;;
            "Continue")
                # Save settings and exit
                echo "OSTYPE=\"$OSTYPE\"" > "$output_file"
                echo "MAJOROSVERSION=\"$MAJOROSVERSION\"" >> "$output_file"
                [[ "$ISOFFLINEREPO" == "true" ]] && echo "ISOFFLINEREPO=\"true\"" >> "$output_file"
                [[ -n "$OFFLINEREPO" ]] && echo "OFFLINEREPO=\"$OFFLINEREPO\"" >> "$output_file"
                
                # Copy the output file to TEMP_FILE
                cat "$output_file" > "$TEMP_FILE"
                rm -f "$output_file"
                return 0
                ;;
            *)
                dialog --title "Error" --msgbox "Invalid OS flavor selected." 8 40
                ;;
        esac
    done
}

# Function to manage time settings
manage_time_settings() {
    local settings_file=$1
    local output_file=$(mktemp)
    
    # Source existing settings if file exists
    if [[ -f "$settings_file" ]]; then
        source "$settings_file"
    fi
    
    # Set defaults if not already set
    local TIMEZONE="${TIMEZONE:-Etc/UTC}"
    local NTP_SERVERS="${NTP_SERVERS:-}"

    while true; do
        sub_choice=$(dialog --clear --title "Edit Time Settings" \
                --menu "Please select an option:" $HEIGHT $WIDTH 5 \
                1 "Edit Timezone [$TIMEZONE]" \
                2 "Edit NTP Servers [Current: ${NTP_SERVERS:-none}]" \
                3 "Continue" \
                2>&1 >/dev/tty)
        ret=$?

        # Check if user pressed Cancel or ESC
        if [[ $ret -ne 0 ]]; then
            rm -f "$output_file"
            return 1
        fi
            
        case "$sub_choice" in
            1)
                new_value=$(dialog --clear --inputbox "Enter Timezone:" 8 $WIDTH "$TIMEZONE" 2>&1 >/dev/tty)
                [[ $? -eq 0 ]] && TIMEZONE="$new_value"
                ;;
            2)
                new_value=$(dialog --clear --inputbox "Enter NTP SERVERS. Comma delimited:" 8 $WIDTH "$NTP_SERVERS" 2>&1 >/dev/tty)
                [[ $? -eq 0 ]] && NTP_SERVERS="$new_value"
                ;;
            3)
                # Save settings and exit
                echo "TIMEZONE=\"$TIMEZONE\"" > "$output_file"
                [[ -n "$NTP_SERVERS" ]] && echo "NTP_SERVERS=\"$NTP_SERVERS\"" >> "$output_file"
                
                # Copy the output file to TEMP_FILE
                cat "$output_file" > "$TEMP_FILE"
                rm -f "$output_file"
                return 0
                ;;
        esac
    done
}

# Function to manage user settings
manage_user_settings() {
    local settings_file=$1
    local output_file=$(mktemp)
    
    # Source existing settings if file exists
    if [[ -f "$settings_file" ]]; then
        source "$settings_file"
    fi
    
    # Set defaults if not already set
    local username_01="${username_01:-alt.admin}"
    local username_01_gecos="${username_01_gecos:-Regular Admin Account}"
    local password_username_01="${password_username_01:-}"
    local username_02="${username_02:-acas.admin}"
    local username_02_gecos="${username_02_gecos:-Nessus Admin Account}"
    local password_username_02="${password_username_02:-}"
    local username_03="${username_03:-ansible.admin}"
    local username_03_gecos="${username_03_gecos:-Ansible Service Account}"
    local password_username_03="${password_username_03:-}"
    
    # Set password indicators
    local isset_pass1=$([ -n "$password_username_01" ] && echo "true" || echo "false")
    local isset_pass2=$([ -n "$password_username_02" ] && echo "true" || echo "false")
    local isset_pass3=$([ -n "$password_username_03" ] && echo "true" || echo "false")

    while true; do
        choice=$(dialog --clear --title "Configuration Menu" \
                    --menu "Please select an option:" $HEIGHT $WIDTH 5 \
                    1 "Edit Admin User 1 [$username_01 - $username_01_gecos]" \
                    2 "Edit Admin User 2 [$username_02 - $username_02_gecos]" \
                    3 "Edit Admin User 3 [$username_03 - $username_03_gecos]" \
                    4 "Save and Continue" \
                    2>&1 >/dev/tty)
        ret=$?

        # Check if user pressed Cancel or ESC
        if [[ $ret -ne 0 ]]; then
            rm -f "$output_file"
            return 1
        fi
        
        case "$choice" in
            1)
                sub_choice=$(dialog --clear --title "Edit Admin $username_01" \
                        --menu "Please select an option:" $HEIGHT $WIDTH 5 \
                        1 "Edit Username [$username_01]" \
                        2 "Edit Account Description [$username_01_gecos]" \
                        3 "Edit Password [Password set: ${isset_pass1:-no}]" \
                        4 "Continue" \
                        2>&1 >/dev/tty)
                ret=$?

                if [[ $ret -eq 0 ]]; then
                    case "$sub_choice" in
                        1)
                            new_value=$(dialog --clear --inputbox "Enter Username:" 8 $WIDTH "$username_01" 2>&1 >/dev/tty)
                            [[ $? -eq 0 ]] && username_01="$new_value"
                            ;;
                        2)
                            new_value=$(dialog --clear --inputbox "Enter Account Description:" 8 $WIDTH "$username_01_gecos" 2>&1 >/dev/tty)
                            [[ $? -eq 0 ]] && username_01_gecos="$new_value"
                            ;;
                        3)
                            new_value=$(dialog --clear --passwordbox "Enter Password:" 8 $WIDTH 2>&1 >/dev/tty)
                            if [[ $? -eq 0 && -n "$new_value" ]]; then
                                password_username_01="$new_value"
                                isset_pass1="true"
                            fi