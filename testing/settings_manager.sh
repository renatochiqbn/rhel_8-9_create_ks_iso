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
WIDTH=50

# Function to create new settings file
create_new_settings() {
    # Get project name
    dialog --title "Project Configuration" \
           --inputbox "Enter project name:" $HEIGHT $WIDTH 2>$TEMP_FILE
    PROJECT_NAME=$(cat $TEMP_FILE)
    
    # Toggle options
    dialog --title "Configuration Options" \
           --checklist "Select options:" $HEIGHT $WIDTH 6 \
           "DEBUG" "Enable debug mode" OFF \
           "LOGGING" "Enable logging" ON \
           "VERBOSE" "Enable verbose output" OFF \
           "BACKUP" "Enable automatic backup" OFF 2>$TEMP_FILE
    
    OPTIONS=$(cat $TEMP_FILE)
    
    # Get output directory
    dialog --title "Output Directory" \
           --inputbox "Enter output directory:" $HEIGHT $WIDTH "/tmp" 2>$TEMP_FILE
    OUTPUT_DIR=$(cat $TEMP_FILE)
    
    # Save settings to file
    SETTINGS_FILE="settings_${PROJECT_NAME}.conf"
    echo "PROJECT_NAME='$PROJECT_NAME'" > $SETTINGS_FILE
    echo "OUTPUT_DIR='$OUTPUT_DIR'" >> $SETTINGS_FILE
    
    # Process options
    for opt in $OPTIONS; do
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
    
    # Prepare current toggle states
    local debug_state=$([ "${DEBUG:-false}" = "true" ] && echo "on" || echo "off")
    local logging_state=$([ "${LOGGING:-false}" = "true" ] && echo "on" || echo "off")
    local verbose_state=$([ "${VERBOSE:-false}" = "true" ] && echo "on" || echo "off")
    local backup_state=$([ "${BACKUP:-false}" = "true" ] && echo "on" || echo "off")
    
    # Edit toggle options
    dialog --title "Edit Configuration Options" \
           --checklist "Update options:" $HEIGHT $WIDTH 6 \
           "DEBUG" "Enable debug mode" $debug_state \
           "LOGGING" "Enable logging" $logging_state \
           "VERBOSE" "Enable verbose output" $verbose_state \
           "BACKUP" "Enable automatic backup" $backup_state 2>$TEMP_FILE
    
    local new_options=$(cat $TEMP_FILE)
    
    # Show confirmation dialog
    dialog --title "Confirm Changes" \
           --yesno "Save changes to $settings_file?" 8 40
    
    if [ $? -eq 0 ]; then
        # Save new settings
        echo "PROJECT_NAME='$new_project_name'" > "$temp_settings"
        echo "OUTPUT_DIR='$new_output_dir'" >> "$temp_settings"
        
        # Reset all options to false first
        echo "DEBUG=false" >> "$temp_settings"
        echo "LOGGING=false" >> "$temp_settings"
        echo "VERBOSE=false" >> "$temp_settings"
        echo "BACKUP=false" >> "$temp_settings"
        
        # Set selected options to true
        for opt in $new_options; do
            opt=$(echo $opt | tr -d '"')
            sed -i "s/${opt}=false/${opt}=true/" "$temp_settings"
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
                echo $SETTINGS_FILE > .selected_settings
                exit 0
            else
                exit 1
            fi
            ;;
    esac
done