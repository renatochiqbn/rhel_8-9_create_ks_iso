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
    SRCDIR="${DEFAULT_SRCDIR:-${PWD}}"
    ISOSRCDIR="${DEFAULT_ISOSRCDIR:-"$SRCDIR/ISO"}"
    OEMSRCISO="${DEFAULT_OEMSRCISO:-"rhel-8.10-x86_64-dvd.iso"}"
    KSLOCATION="${DEFAULT_KSLOCATION:-"hd:LABEL=RHEL-8-10-0-BaseOS-x86_64:/ks.cfg"}"
    
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
                printf "SRCDIR=\"%s\"\nISOSRCDIR=\"%s\"\nOEMSRCISO=\"%s\"\nKSLOCATION=\"%s\"\n" "$SRCDIR" "$ISOSRCDIR" "$OEMSRCISO" "$KSLOCATION" >$TEMP_FILE
                clear
                break
                # return 0 # Success
                ;;
            *)
                dialog --title "Error" --msgbox "Invalid choice" 8 40
                continue
                ;;
        esac
    done
    return 0
}

# Select OS type
select_OS() {
    local settings_file=$1
    local choice_os=""
    local choice_os_version=""
    

    # Source existing settings if file exists
    if [[ -f "$settings_file" ]]; then
        source "$settings_file"
        local ${OSTYPE:=$OSTYPE}
        local ${MAJOROSVERSION:=$MAJOROSVERSION}
    else
        local OSTYPE="None"
        local MAJOROSVERSION="Selected"
    fi

    # OS Flavor Selection
    choice_os=$(dialog --clear --title "Select Linux Distribution" \
                        --menu "Current OS selected: [$OSTYPE $MAJOROSVERSION]" 10 50 5 \
                        "RHEL" "Red Hat Enterprise Linux" \
                        "CentOS" "CentOS Linux" \
                        2>&1 1>/dev/tty)
    ret=$?
    if [[ $ret -ne 0 ]]; then  # Handle Cancel
      return 1
    fi

    # Populate Versions based on Flavor (Example)
    case "$choice_os" in
        "RHEL")
            choice_os_version=$(dialog --clear --title "Select RHEL OS version" \
                          --menu "Choose the OS distribution:" 10 50 5 \
                          "8" "Red Hat Enterprise Linux 8" \
                          "9" "Red Hat Enterprise Linux 9" \
                          2>&1 1>/dev/tty)  # RHEL versions
            ;;
        "CentOS")
            choice_os_version=$(dialog --clear --title "Select CentOS version" \
                          --menu "Choose the OS distribution:" 10 50 5 \
                          "8" "CentOS Linux Stream 8" \
                          "9" "CentOS Linux Stream 9" \
                          2>&1 1>/dev/tty)
            ;;
        *)
            echo "Invalid OS flavor selected." >&2 # Error to stderr
            return 1
            ;;
    esac

    # Store choices
    echo "OSTYPE=\"$choice_os\""
    echo "MAJOROSVERSION=\"$choice_os_version\""
    return 0
}

# Function to manage user settigns
# Function to manage user settings
manage_user_settings() {
    local settings_file=$1
    local usr01="true"
  
    # Source existing settings if file exists
    if [[ -f "$settings_file" ]]; then
        source "$settings_file"
        local username_01="${username_01}"
        local username_01_gecos="${username_01_gecos}"
        local password_username_01="${password_username_01}"
        local username_02="${username_02}"
        local username_02_gecos="${username_02_gecos}"
        local password_username_02="${password_username_02}"
        local username_03="${username_03}"
        local username_03_gecos="${username_03_gecos}"
        local password_username_03="${password_username_03}"
        if [[ -n "$password_username_01" ]]; then isset_pass1="true"; fi
        if [[ -n "$password_username_02" ]]; then isset_pass2="true"; fi
        if [[ -n "$password_username_03" ]]; then isset_pass3="true"; fi
    else
        # Set defaults if not set from file
        local username_01="alt.admin"
        local username_01_gecos="Regular Admin Account"
        local username_02="acas.admin"
        local username_02_gecos="Nessus Admin Account"
        local username_03="ansible.admin"
        local username_03_gecos="Ansible Service Account"
        # Passwords start as null
        local password_username_01=""
        local password_username_02=""
        local password_username_03=""
    fi
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
                clear
                return 1
            fi
            
            case "$choice" in
                1)
                    while true; do
                        sub_choice=$(dialog --clear --title "Edit Admin $username_01" \
                                --menu "Please select an option:" $HEIGHT $WIDTH 5 \
                                1 "Edit Username [$username_01]" \
                                2 "Edit Account Description [$username_01_gecos]" \
                                3 "Edit Password [Password set: ${isset_pass1:-no}]" \
                                4 "Continue" \
                                2>&1 >/dev/tty)
                        ret=$?

                        if [[ $ret -eq 0 ]]; then
                            while true; do
                                case "$sub_choice" in
                                    1)
                                        new_value=$(dialog --clear --inputbox "Enter Username:" 8 $WIDTH "$username_01" 2>&1 >/dev/tty)
                                        [[ $? -eq 0 ]] && username_01="$new_value"
                                        break
                                        ;;
                                    2)
                                        new_value=$(dialog --clear --inputbox "Enter Account Description:" 8 $WIDTH "$username_01_gecos" 2>&1 >/dev/tty)
                                        [[ $? -eq 0 ]] && username_01_gecos="'$new_value'"
                                        break
                                        ;;
                                    3)
                                        new_value=$(dialog --clear --passwordbox "Enter Password:" 8 $WIDTH 2>&1 >/dev/tty)
                                        if [[ $? -eq 0 && -n "$new_value" ]]; then
                                            password_username_01="'$new_value'"
                                            isset_pass1="true"
                                        fi
                                        break
                                        ;;
                                    4)
                                        clear
                                        break
                                        ;;
                                esac
                            done
                        fi
                        break
                    done
                    ;;
                2)
                    while true; do
                        sub_choice=$(dialog --clear --title "Edit Admin $username_02" \
                                --menu "Please select an option:" $HEIGHT $WIDTH 5 \
                                1 "Edit Username [$username_02]" \
                                2 "Edit Account Description [$username_02_gecos]" \
                                3 "Edit Password [Password set: ${isset_pass2:-no}]" \
                                4 "Continue" \
                                2>&1 >/dev/tty)
                        ret=$?

                        if [[ $ret -eq 0 ]]; then
                            while true; do
                                case "$sub_choice" in
                                    1)
                                        new_value=$(dialog --clear --inputbox "Enter Username:" 8 $WIDTH "$username_02" 2>&1 >/dev/tty)
                                        [[ $? -eq 0 ]] && username_02="$new_value"
                                        break
                                        ;;
                                    2)
                                        new_value=$(dialog --clear --inputbox "Enter Account Description:" 8 $WIDTH "$username_02_gecos" 2>&1 >/dev/tty)
                                        [[ $? -eq 0 ]] && username_02_gecos="'$new_value'"
                                        break
                                        ;;
                                    3)
                                        new_value=$(dialog --clear --passwordbox "Enter Password:" 8 $WIDTH 2>&1 >/dev/tty)
                                        if [[ $? -eq 0 && -n "$new_value" ]]; then
                                            password_username_02="$new_value"
                                            isset_pass2="true"
                                        fi
                                        break
                                        ;;
                                    4)
                                        clear
                                        break
                                        ;;
                                esac
                            done
                        fi
                        break
                    done
                    ;;
                3)
                    while true; do
                        sub_choice=$(dialog --clear --title "Edit Admin $username_03" \
                                --menu "Please select an option:" $HEIGHT $WIDTH 5 \
                                1 "Edit Username [$username_03]" \
                                2 "Edit Account Description [$username_03_gecos]" \
                                3 "Edit Password [Password set: ${isset_pass3:-no}]" \
                                4 "Continue" \
                                2>&1 >/dev/tty)
                        ret=$?

                        if [[ $ret -eq 0 ]]; then
                            while true; do
                                case "$sub_choice" in
                                    1)
                                        new_value=$(dialog --clear --inputbox "Enter Username:" 8 $WIDTH "$username_03" 2>&1 >/dev/tty)
                                        [[ $? -eq 0 ]] && username_03="$new_value"
                                        break
                                        ;;
                                    2)
                                        new_value=$(dialog --clear --inputbox "Enter Account Description:" 8 $WIDTH "$username_03_gecos" 2>&1 >/dev/tty)
                                        [[ $? -eq 0 ]] && username_03_gecos="'$new_value'"
                                        break
                                        ;;
                                    3)
                                        new_value=$(dialog --clear --passwordbox "Enter Password:" 8 $WIDTH 2>&1 >/dev/tty)
                                        if [[ $? -eq 0 && -n "$new_value" ]]; then
                                            password_username_03="$new_value"
                                            isset_pass3="true"
                                        fi
                                        break
                                        ;;
                                    4)
                                        clear
                                        break
                                        ;;
                                esac
                            done
                        fi
                        break
                    done
                    ;;
                4)
                    # Store settings
                    echo "username_01=\"$username_01\""
                    echo "username_01_gecos=\"$username_01_gecos\""
                    [[ -n "$password_username_01" ]] && echo "password_username_01=\"$password_username_01\""
                    echo "username_02=\"$username_02\""
                    echo "username_02_gecos=\"$username_02_gecos\""
                    [[ -n "$password_username_02" ]] && echo "password_username_02=\"$password_username_02\""
                    echo "username_03=\"$username_03\""
                    echo "username_03_gecos=\"$username_03_gecos\""
                    [[ -n "$password_username_03" ]] && echo "password_username_03=\"$password_username_03\""
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

# Function to create or adjust security settings.
manage_security_settings() {
    local settings_file=$1

    # Source existing settings
    source "$settings_file"

    # Prepare current toggle states
    local fips_state=$([ "${ENABLEFIPS:-false}" = "true" ] && echo "on" || echo "off")
    local luks_state=$([ "${ENABLELUKS:-false}" = "true" ] && echo "on" || echo "off")
    local stig_state=$([ "${APPLYOPENSCAPSTIG:-false}" = "true" ] && echo "on" || echo "off")

    # Edit toggle options
    dialog --title "Edit Security Options" \
           --checklist "Update options:" $HEIGHT $WIDTH 6 \
           "ENABLEFIPS" "Enable FIPS 140-2 mode" $fips_state \
           "ENABLELUKS" "Enable LUKS drive encryption" $luks_state \
           "APPLYOPENSCAPSTIG" "Enable DoD STIG hardening - No GUI" $stig_state 2>$TEMP_FILE
}

# Function to create or adjust virtualization settings.
manage_virtual_settings() {
    local settings_file=$1

    # Source existing settings
    source "$settings_file"

    # Prepare current toggle states
    local isvirtual_state=$([ "${ISVIRTUALPLATFORM:-false}" = "true" ] && echo "on" || echo "off")
    local PCIPT_state=$([ "${PCIPASSTHROUGH:-false}" = "true" ] && echo "on" || echo "off")
    local isintel_state=$([ "${INTELCPU:-false}" = "true" ] && echo "on" || echo "off")

    # Edit toggle options
    dialog --title "Edit Virtualization Options" \
           --checklist "Update options:" $HEIGHT $WIDTH 6 \
           "ISVIRTUALPLATFORM" "Enables virtualization packages" $isvirtual_state \
           "PCIPASSTHROUGH" "Enable PCI passthrough" $PCIPT_state \
           "INTELCPU" "Is Intel CPU?" $isintel_state 2>$TEMP_FILE
}

# Function to create or adjust additional settings.
manage_additional_settings() {
    local settings_file=$1

    # Source existing settings
    source "$settings_file"

    # Prepare current toggle states
    local bootiso_state=$([ "${CREATEBOOTISO:-false}" = "true" ] && echo "on" || echo "off")
    local KSINBOOTISO_state=$([ "${KSINBOOTISO:-false}" = "true" ] && echo "on" || echo "off")
    local WRITEPASSWDS_state=$([ "${WRITEPASSWDS:-false}" = "true" ] && echo "on" || echo "off")
    local WRITESSHKEYS_state=$([ "${WRITESSHKEYS:-false}" = "true" ] && echo "on" || echo "off")
    local SERIALDISPLAY_state=$([ "${SERIALDISPLAY:-false}" = "true" ] && echo "on" || echo "off")
    local DEBUG_state=$([ "${DEBUG:-false}" = "true" ] && echo "on" || echo "off")

    # Edit toggle options
    dialog --title "Edit Additional Options" \
           --checklist "Update options:" $HEIGHT $WIDTH 6 \
           "CREATEBOOTISO" "Creates boot ISO" $bootiso_state \
           "KSINBOOTISO" "Insert ks.cfg in boot ISO" $KSINBOOTISO_state \
           "WRITEPASSWDS" "Write plaintext passwords to files" $WRITEPASSWDS_state \
           "WRITESSHKEYS" "Write SSH Keys to files" $WRITESSHKEYS_state \
           "SERIALDISPLAY" "Enable serial console display" $SERIALDISPLAY_state \
           "DEBUG" "Enable for debug. Not required for use." $DEBUG_state 2>$TEMP_FILE
}

# Function to create new settings file
create_new_settings() {
    # Get project name
    dialog --title "Project Configuration" \
           --inputbox "Enter project name:" $HEIGHT $WIDTH 2>$TEMP_FILE
    PROJECT_NAME=$(cat $TEMP_FILE)
    
    ## Toggle options
    # dialog --title "Configuration Options" \
    #        --checklist "Select options:" $HEIGHT $WIDTH 6 \
    #        "DEBUG" "Enable debug mode" OFF \
    #        "LOGGING" "Enable logging" ON \
    #        "VERBOSE" "Enable verbose output" OFF \
    #        "BACKUP" "Enable automatic backup" OFF 2>$TEMP_FILE
    
    # OPTIONS=$(cat $TEMP_FILE)
    
    # Media Source Configuration Options
    select_media
    local media_options=$(cat $TEMP_FILE)

    # OS Selection Options
    local os_selection=$(select_OS)

    # Create Security options
    manage_security_settings
    local security_options=$(cat $TEMP_FILE)

    # Create Virtualization Settings
    manage_virtual_settings
    local virtual_options=$(cat $TEMP_FILE)
    
    #Create User Settings
    local user_selection=$(manage_user_settings)

    # Create Additional Settings
    manage_additional_settings
    local additional_options=$(cat $TEMP_FILE)
    
    # Get output directory
    dialog --title "Output Directory" \
           --inputbox "Enter output directory:" $HEIGHT $WIDTH "./" 2>$TEMP_FILE
    OUTPUT_DIR=$(cat $TEMP_FILE)
    
    # Save settings to file
    SETTINGS_FILE="settings_${PROJECT_NAME}.conf"
    echo "PROJECT_NAME='$PROJECT_NAME'" > $SETTINGS_FILE
    echo "OUTPUT_DIR='$OUTPUT_DIR'" >> $SETTINGS_FILE
    
    # Process Media Select options
    for opt in $media_options; do
        echo "${opt}" >> $SETTINGS_FILE  #not sure what output will be
    done

    # Process OS Selection
    for opt in $os_selection; do 
        echo "${opt}" >> $SETTINGS_FILE 
    done

    # Process User Selection
    for opt in $user_selection; do 
        echo "${opt}" >> $SETTINGS_FILE 
    done

    # Process options
    for opt in $OPTIONS; do
        opt=$(echo $opt | tr -d '"')
        echo "${opt}=true" >> $SETTINGS_FILE
    done

    for opt in $security_options; do
        opt=$(echo $opt | tr -d '"')
        echo "${opt}=true" >> $SETTINGS_FILE
    done

    for opt in $virtual_options; do
        opt=$(echo $opt | tr -d '"')
        echo "${opt}=true" >> $SETTINGS_FILE
    done

    for opt in $additional_options; do
        opt=$(echo $opt | tr -d '"')
        echo "${opt}=true" >> $SETTINGS_FILE
    done
    
    dialog --title "Success" \
           --msgbox "Settings saved to $SETTINGS_FILE" 8 40
}

# Function to edit existing settings
edit_settings() {
    local settings_file=$1
    local temp_settings=$(mktemp)
    
    # Source existing settings
    source "$settings_file"
    
    # Edit project name
    dialog --title "Edit Project Name" \
           --inputbox "Current project name:" $HEIGHT $WIDTH "$PROJECT_NAME" 2>$TEMP_FILE
    local new_project_name=$(cat $TEMP_FILE)
    
    # Edit output directory
    dialog --title "Edit Output Directory" \
           --inputbox "Current output directory:" $HEIGHT $WIDTH "$OUTPUT_DIR" 2>$TEMP_FILE
    local new_output_dir=$(cat $TEMP_FILE)

    # Media Source Configuration Options
    select_media "$settings_file"
    local media_options=$(cat $TEMP_FILE)

    # OS Selection Options
    local os_selection=$(select_OS "$settings_file")

    # Edit Security Settings - pass both the settings file and temp file
    manage_security_settings "$settings_file"
    local security_options=$(cat $TEMP_FILE)

    # Edit Security Settings - pass both the settings file and temp file
    manage_virtual_settings "$settings_file"
    local virtual_options=$(cat $TEMP_FILE)
    
    #Edit User Settings
    local user_selection=$(manage_user_settings "$settings_file")

    # Edit Security Settings - pass both the settings file and temp file
    manage_additional_settings "$settings_file"
    local additional_options=$(cat $TEMP_FILE)

    # Show confirmation dialog
    dialog --title "Confirm Changes" \
           --yesno "Save changes to $settings_file?" 8 40
    
    if [ $? -eq 0 ]; then
        # Save new settings
        echo "PROJECT_NAME='$new_project_name'" > "$temp_settings"
        echo "OUTPUT_DIR='$new_output_dir'" >> "$temp_settings"

        # Reset security options to false in temp settings
        echo "ENABLEFIPS=false" >> "$temp_settings"
        echo "ENABLELUKS=false" >> "$temp_settings"
        echo "APPLYOPENSCAPSTIG=false" >> "$temp_settings"

        # Reset virtualization options to false in temp settings
        echo "ISVIRTUALPLATFORM=false" >> "$temp_settings"
        echo "PCIPASSTHROUGH=false" >> "$temp_settings"
        echo "INTELCPU=false" >> "$temp_settings"

        # Reset additional options to false in temp settings
        echo "CREATEBOOTISO=false" >> "$temp_settings"
        echo "KSINBOOTISO=false" >> "$temp_settings"
        echo "WRITEPASSWDS=false" >> "$temp_settings"
        echo "WRITESSHKEYS=false" >> "$temp_settings"
        echo "SERIALDISPLAY=false" >> "$temp_settings"
        echo "DEBUG=false" >> "$temp_settings"
        
        # Select media processing
        for opt in $media_options; do
            echo "${opt}" >> $temp_settings
        done
        
        # Process OS Selection
        for opt in $os_selection; do  #Test this!!!!!!!
            echo "${opt}" >> $temp_settings  #not sure what output will be
        done

        # Set selected options to true
        for opt in $security_options; do
            opt=$(echo $opt | tr -d '"')
            sed -i "s/${opt}=false/${opt}=true/" "$temp_settings"
        done

        for opt in $virtual_options; do
            opt=$(echo $opt | tr -d '"')
            sed -i "s/${opt}=false/${opt}=true/" "$temp_settings"
        done

        for opt in $additional_options; do
            opt=$(echo $opt | tr -d '"')
            sed -i "s/${opt}=false/${opt}=true/" "$temp_settings"
        done
    
        # Process User Selection
        for opt in $user_selection; do 
            echo "${opt}" >> $temp_settings 
        done

        # Replace original file with new settings
        mv "$temp_settings" "$settings_file"
        
        dialog --title "Success" \
               --msgbox "Changes saved to $settings_file" 8 40
    else
        rm -f "$temp_settings"
        dialog --title "Cancelled" \
               --msgbox "No changes were saved" 8 40
    fi
}

# Function to review settings
review_settings() {
    local settings_file=$1
    local review_text=""
    
    # Source the settings file
    source "$settings_file"
    
    # Prepare review text
    review_text="Current Settings in $settings_file:\n\n"
    review_text+="Project Name: $PROJECT_NAME\n"
    review_text+="Output Directory: $OUTPUT_DIR\n\n"
    review_text+="Options:\n"
    review_text+="Debug Mode: ${DEBUG:-false}\n"
    review_text+="Logging: ${LOGGING:-false}\n"
    review_text+="Verbose Output: ${VERBOSE:-false}\n"
    review_text+="Automatic Backup: ${BACKUP:-false}\n"
    
    # Show review dialog
    dialog --title "Settings Review" \
           --msgbox "$review_text" 20 60
}

# Main menu
while true; do
    dialog --title "Settings Manager" \
           --menu "Choose an option:" $HEIGHT $WIDTH 4 \
           1 "Load existing settings file" \
           2 "Create new settings file" \
           3 "Review current settings" \
           4 "Edit current settings" \
           5 "Exit" 2>$TEMP_FILE
    
    choice=$(cat $TEMP_FILE)
    
    case $choice in
        1)
            # List all .conf files in current directory
            files=$(ls *.conf 2>/dev/null)
            if [ -z "$files" ]; then
                dialog --title "Error" \
                       --msgbox "No settings files found!" 8 40
                continue
            fi
            
            # Create menu items for each file
            menu_items=""
            for file in $files; do
                menu_items="$menu_items $file '$file'"
            done
            
            # Show file selection menu
            dialog --title "Select Settings File" \
                   --menu "Choose a file:" $HEIGHT $WIDTH 4 $menu_items 2>$TEMP_FILE
            
            SETTINGS_FILE=$(cat $TEMP_FILE)
            if [ -n "$SETTINGS_FILE" ]; then
                dialog --title "Success" \
                       --msgbox "Loaded $SETTINGS_FILE" 8 40
            fi
            ;;
        2)
            create_new_settings
            ;;
        3)
            if [ -z "$SETTINGS_FILE" ]; then
                dialog --title "Error" \
                       --msgbox "No settings file currently loaded!" 8 40
                continue
            fi
            review_settings "$SETTINGS_FILE"
            ;;
        4)
            if [ -z "$SETTINGS_FILE" ]; then
                dialog --title "Error" \
                       --msgbox "No settings file currently loaded!" 8 40
                continue
            fi
            edit_settings "$SETTINGS_FILE"
            ;;
        5)
            rm -f $TEMP_FILE
            if [ -n "$SETTINGS_FILE" ]; then
                clear
                echo $SETTINGS_FILE > .selected_settings
                exit 0
            else
                clear
                exit 1
            fi
            ;;
    esac
done

# Add trap to clean up temp files
trap 'rm -f "$TEMP_FILE"' EXIT