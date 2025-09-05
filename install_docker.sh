#!/bin/bash

# This script automates the official Docker installation process for several
# Linux distributions: Ubuntu, Debian, CentOS, and Fedora.
#
# It is designed to be run on a clean system or to handle existing Docker
# installations gracefully by first removing them.
#
# NOTE: This script must be run as root.
# Usage: sudo ./install_docker.sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to display error messages and exit.
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Check if the script is run as root.
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root. Please use 'sudo'."
fi

echo "Starting Docker installation..."

# Step 1: Remove any old versions of Docker.
echo "Checking for and removing old Docker packages..."
for pkg in docker.io docker-doc docker-compose docker-ce docker-ce-cli containerd.io runc; do
    if dpkg -s $pkg &> /dev/null; then
        echo "  - Found old package: $pkg. Removing..."
        apt-get remove -y "$pkg" || true
    elif rpm -q "$pkg" &> /dev/null; then
        echo "  - Found old package: $pkg. Removing..."
        yum remove -y "$pkg" || true
    fi
done

# Step 2: Set up the Docker repository based on the operating system.
echo "Detecting operating system..."
if [[ -f "/etc/os-release" ]]; then
    . /etc/os-release
    OS_NAME=$ID
    VERSION_ID=$VERSION_ID
else
    error_exit "Could not detect operating system from /etc/os-release."
fi

case "$OS_NAME" in
    ubuntu)
        echo "Detected Ubuntu."
        # Update the apt package index and install packages to allow apt to use a repository over HTTPS.
        apt-get update
        apt-get install -y ca-certificates curl gnupg lsb-release

        # Add Docker's official GPG key.
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # Set up the repository.
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Update the apt package index again.
        apt-get update
        ;;

    debian)
        echo "Detected Debian."
        # Update the apt package index and install packages to allow apt to use a repository over HTTPS.
        apt-get update
        apt-get install -y ca-certificates curl gnupg lsb-release

        # Add Docker's official GPG key.
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # Set up the repository.
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Update the apt package index again.
        apt-get update
        ;;

    centos|fedora)
        echo "Detected CentOS or Fedora."
        # For RHEL/CentOS and Fedora, we use yum/dnf.

        if [[ "$OS_NAME" == "centos" ]]; then
            # Install yum-utils and remove old versions
            yum-utils
            yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        else
            # For Fedora, use dnf
            dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
            dnf install -y dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        fi
        ;;

    *)
        error_exit "Unsupported operating system: $OS_NAME. This script supports Ubuntu, Debian, CentOS, and Fedora."
        ;;
esac

# Step 3: Install Docker Engine.
echo "Installing Docker Engine, Docker CLI, and Containerd..."
if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif [[ "$OS_NAME" == "centos" ]]; then
    yum install -y docker-ce docker-ce-cli containerd.io
elif [[ "$OS_NAME" == "fedora" ]]; then
    dnf install -y docker-ce docker-ce-cli containerd.io
fi

# Step 4: Start and enable Docker on system startup.
echo "Enabling and starting the Docker service..."
systemctl start docker
systemctl enable docker

# Step 5: Add the current user to the 'docker' group.
echo "Adding the current user to the 'docker' group to run commands without sudo."
USERNAME=${SUDO_USER:-$(whoami)}
usermod -aG docker "$USERNAME"

echo "Docker installation complete!"
echo "Please log out and log back in, or run 'newgrp docker' to apply the group changes."
echo "You can test your installation by running 'docker run hello-world'."
