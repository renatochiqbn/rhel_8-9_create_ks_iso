#!/bin/bash

# Store dialog outputs
temp_file=$(mktemp)
: "${output_file:="settings.conf"}"


# Initialize values from environment variables or set defaults
name="${DEFAULT_NAME:-}"
email="${DEFAULT_EMAIL:-}"
notifications="${DEFAULT_NOTIFICATIONS:-OFF}"
dark_mode="${DEFAULT_DARK_MODE:-OFF}"

# Rest of the menu script remains the same...
show_main_menu() {
    dialog --clear --title "Configuration Menu" \
           --menu "Please select an option:" 15 50 5 \
           1 "Enter Name [$name]" \
           2 "Enter Email [$email]" \
           3 "Toggle Notifications [$notifications]" \
           4 "Toggle Dark Mode [$dark_mode]" \
           5 "Save and Exit" \
           2> "$temp_file"

    return $?
}

# Function to handle user input
handle_input() {
    local choice=$(cat "$temp_file")
    case $choice in
        1)
            dialog --title "Enter Name" \
                   --inputbox "Please enter your name:" 8 40 "$name" \
                   2> "$temp_file"
            if [ $? -eq 0 ]; then
                name=$(cat "$temp_file")
            fi
            ;;
        2)
            dialog --title "Enter Email" \
                   --inputbox "Please enter your email:" 8 40 "$email" \
                   2> "$temp_file"
            if [ $? -eq 0 ]; then
                email=$(cat "$temp_file")
            fi
            ;;
        3)
            if [ "$notifications" = "OFF" ]; then
                notifications="ON"
            else
                notifications="OFF"
            fi
            dialog --title "Notifications" \
                   --msgbox "Notifications are now $notifications" 6 40
            ;;
        4)
            if [ "$dark_mode" = "OFF" ]; then
                dark_mode="ON"
            else
                dark_mode="OFF"
            fi
            dialog --title "Dark Mode" \
                   --msgbox "Dark Mode is now $dark_mode" 6 40
            ;;
        5)
            # Save settings to file
            {
                echo "name=$name"
                echo "email=$email"
                echo "notifications=$notifications"
                echo "dark_mode=$dark_mode"
            } > "$output_file"
            
            dialog --title "Save and Exit" \
                   --msgbox "Settings have been saved to $output_file" 6 40
            return 1
            ;;
    esac
    return 0
}

# Main loop
while true; do
    show_main_menu
    if [ $? -ne 0 ]; then
        break
    fi
    
    handle_input
    if [ $? -eq 1 ]; then
        break
    fi
done

# Clean up
clear
rm -f "$temp_file"