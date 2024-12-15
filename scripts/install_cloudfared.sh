#!/bin/bash

# Constants
CLOUDFLARED_DIR="/etc/cloudflared"
ENV_FILE_DOWNLOAD="https://raw.githubusercontent.com/itsvncl/cloudflared-setup/main/cloudfared/.env"
DOCKER_COMPOSE_FILE_DOWNLOAD="https://raw.githubusercontent.com/itsvncl/cloudflared-setup/main/cloudfared/docker-compose.yml"
ENV_FILE="$CLOUDFLARED_DIR/.env"

# Check if the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

install_tools() {
    echo "Installing required tools for automatic setup."
    apt-get update -y
    apt-get install ca-certificates curl sudo systemd -y
}   

# Function to check if Docker is installed, and install it if not
install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y

    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
  else
    echo "Docker is already installed."
  fi
}

# Function to start Docker if not running
start_docker() {
  echo "Checking if Docker is running..."
  
  # Start Docker if it's not running
  sudo systemctl is-active --quiet docker || {
    echo "Starting Docker..."
    sudo systemctl start docker
  }

  sudo systemctl enable docker
}

# Function to check Docker permissions
check_docker_permissions() {
  echo "Checking Docker permissions..."
  
  # Add the current user to the docker group if not already a member
  if ! groups $(whoami) | grep -q -w docker; then
    echo "Adding current user to the docker group..."
    sudo usermod -aG docker $(whoami)
    echo "You must log out and log back in to complete permission setup."
    exit 1
  fi
}

# Function to create the cloudfared folder and download the .env file
create_cloudfared_folder_and_download_env() {
  echo "Creating cloudfared folder at $CLOUDFLARED_DIR..."

  # Create the cloudfared folder
  mkdir -p "$CLOUDFLARED_DIR"

  # Download the .env file from the GitHub repo
  echo "Downloading .env file from GitHub..."
  curl -o "$ENV_FILE" "$ENV_FILE_DOWNLOAD"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to download .env file."
    exit 1
  fi

  echo ".env file downloaded successfully."
}

# Function to prompt for the tunnel token and update the .env file
update_env_file() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file does not exist in $CLOUDFLARED_DIR."
    exit 1
  fi

  # Prompt user for the Cloudflare Tunnel token
  echo "Enter your Cloudflare Tunnel token (you can copy it from your Cloudflare dashboard):"
  read -r TUNNEL_TOKEN

  if [ -z "$TUNNEL_TOKEN" ]; then
    echo "Error: Tunnel token cannot be empty."
    exit 1
  fi

  # Update the .env file with the provided token
  echo "Updating the .env file with the provided token..."
  sed -i "s/^CLOUDFLARE_TOKEN=.*/CLOUDFLARE_TOKEN=\"$TUNNEL_TOKEN\"/" "$ENV_FILE"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to update .env file."
    exit 1
  fi

  echo ".env file updated successfully."
}

# Function to download the docker-compose.yml file
download_compose_file() {
  echo "Downloading docker-compose.yml from GitHub repo..."

  # Download the docker-compose.yml file
  curl -o "$CLOUDFLARED_DIR/docker-compose.yml" "$DOCKER_COMPOSE_FILE_DOWNLOAD"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to download docker-compose.yml from GitHub."
    exit 1
  fi

  echo "docker-compose.yml downloaded successfully."
}

# Function to start the container using docker-compose
start_with_compose() {
  echo "Starting the Cloudflare Tunnel using docker-compose..."

  # Use docker compose with the updated .env file
  sudo docker compose --env-file "$ENV_FILE" -f "$CLOUDFLARED_DIR/docker-compose.yml" up -d

  if [ $? -eq 0 ]; then
    echo "Cloudflare Tunnel setup complete! The container is running."
  else
    echo "Error: Failed to start the Cloudflare Tunnel container."
    exit 1
  fi
}

# Main script execution
install_tools
install_docker
start_docker
#check_docker_permissions
create_cloudfared_folder_and_download_env
update_env_file
download_compose_file
start_with_compose
