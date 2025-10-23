#!/bin/bash

# Variables
USER_PREFIX="apnic_isif"
PASSWORD="apnic_isif@2025"

# Loop to create users from apnic_isif001 to apnic_isif030
for i in $(seq -w 1 50); do
    USERNAME="${USER_PREFIX}${i}"

    # Check if the user already exists
    if id "$USERNAME" &>/dev/null; then
        echo "User $USERNAME already exists. Skipping..."
        continue
    fi

    # Create the user
    useradd -m -s /bin/bash "$USERNAME"
    if [ $? -eq 0 ]; then
        echo "User $USERNAME created successfully."
    else
        echo "Failed to create user $USERNAME."
        continue
    fi

    # Set the password
    echo "$USERNAME:$PASSWORD" | chpasswd
    if [ $? -eq 0 ]; then
        echo "Password for $USERNAME set successfully."
    else
        echo "Failed to set password for $USERNAME."
        continue
    fi
done

useradd -m -s /bin/bash "admin"
echo "admin:P@ssw0rd" | chpasswd

echo "User creation process completed."
