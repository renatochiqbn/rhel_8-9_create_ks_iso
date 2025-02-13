#!/bin/bash

# Define paths to scripts
DIALOG_SCRIPT="./menu_dialog.sh"
SECONDARY_SCRIPT="./create-ks-iso.sh"
VARIABLES_FILE="./variables.sh"

# Function to check if a file exists and is executable
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: $1 not found!"
        exit 1
    elif [ ! -x "$1" ]; then
        echo "Error: $1 is not executable!"
        echo "Run: chmod +x $1"
        exit 1
    fi
}

# Function to read user input
read_user_input() {
    local skip_input
    read -p "Do you want to set initial values? (y/N): " skip_input
    
    if [[ "${skip_input,,}" == "y" ]]; then
        # Read settings file name
        read -p "Enter default name (press Enter to skip): " setting_name
        if [ ! -z "$setting_name" ]; then
            export output_file="$setting_name"
        fi
        
        # Read email
        read -p "Enter default email (press Enter to skip): " user_email
        if [ ! -z "$user_email" ]; then
            export DEFAULT_EMAIL="$user_email"
        fi
        
        # Read notification preference
        read -p "Enable notifications? (y/N): " notif_pref
        if [[ "${notif_pref,,}" == "y" ]]; then
            export DEFAULT_NOTIFICATIONS="ON"
        else
            export DEFAULT_NOTIFICATIONS="OFF"
        fi
        
        # Read dark mode preference
        read -p "Enable dark mode? (y/N): " dark_pref
        if [[ "${dark_pref,,}" == "y" ]]; then
            export DEFAULT_DARK_MODE="ON"
        else
            export DEFAULT_DARK_MODE="OFF"
        fi
        
        echo -e "\nInitial values set. Starting dialog menu..."
    else
        echo "Skipping initial values. Starting dialog menu..."
    fi
}

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "Error: dialog is not installed"
    echo "Install it using:"
    echo "  Debian/Ubuntu: sudo apt-get install dialog"
    echo "  RedHat/CentOS: sudo yum install dialog"
    exit 1
fi

# Check if required scripts exist and are executable
check_file "$DIALOG_SCRIPT"
check_file "$SECONDARY_SCRIPT"

# Load previous values if they exist
if [ -f "$VARIABLES_FILE" ]; then
    source "$VARIABLES_FILE"
    export DEFAULT_NAME="${MENU_NAME:-}"
    export DEFAULT_EMAIL="${MENU_EMAIL:-}"
    export DEFAULT_NOTIFICATIONS="${MENU_NOTIFICATIONS:-OFF}"
    export DEFAULT_DARK_MODE="${MENU_DARK_MODE:-OFF}"
fi

# Offer to read user input
read_user_input

# Run the dialog menu script
echo "Running dialog menu script..."
"$DIALOG_SCRIPT"

# Check if variables file was created
if [ ! -f "$VARIABLES_FILE" ]; then
    echo "Error: Variables file was not created by the dialog script!"
    exit 1
fi

# Make sure variables file is executable
chmod +x "$VARIABLES_FILE"

# Run the secondary script with the exported variables
echo "Running secondary script..."
"$VARIABLES_FILE" "$SECONDARY_SCRIPT"

echo "All scripts completed successfully!"