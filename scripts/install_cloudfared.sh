#!/bin/bash

# Constants
CLOUDFLARED_DIR="/etc/cloudflared"
ENV_FILE_DOWNLOAD="https://raw.githubusercontent.com/itsvncl/cloudfared-setup/main/cloudfared/.env"
DOCKER_COMPOSE_FILE_DOWNLOAD="https://raw.githubusercontent.com/itsvncl/cloudfared-setup/main/cloudfared/docker-compose.yml"
ENV_FILE="$CLOUDFLARED_DIR/.env"

# Check if the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

# Function to check if Docker is installed, and install it if not
install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    apt update
    apt install -y docker.io docker-compose-plugin
    systemctl start docker
    systemctl enable docker
    echo "Docker installed successfully."
  else
    echo "Docker is already installed."
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
  sed -i "s/^CLOUDFARE_TOKEN=.*/CLOUDFARE_TOKEN=\"$TUNNEL_TOKEN\"/" "$ENV_FILE"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to update .env file."
    exit 1
  fi

  echo ".env file updated successfully."
}

# Function to download the docker-compose.yml file and replace the token placeholder
download_compose_file() {
  echo "Downloading docker-compose.yml from GitHub repo..."

  # Download the docker-compose.yml file
  curl -o "$CLOUDFLARED_DIR/docker-compose.yml" "https://raw.githubusercontent.com/itsvncl/cloudfared-setup/main/cloudfared/docker-compose.yml"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to download docker-compose.yml from GitHub."
    exit 1
  fi

  echo "docker-compose.yml downloaded successfully."
}

# Function to start the container using docker-compose
start_with_compose() {
  echo "Starting the Cloudflare Tunnel using docker-compose..."

  # Use docker-compose to start the container with the updated .env file
  docker-compose --env-file "$ENV_FILE" -f "$CLOUDFLARED_DIR/docker-compose.yml" up -d

  if [ $? -eq 0 ]; then
    echo "Cloudflare Tunnel setup complete! The container is running."
  else
    echo "Error: Failed to start the Cloudflare Tunnel container."
    exit 1
  fi
}

# Main script execution
install_docker
create_cloudfared_folder_and_download_env
update_env_file
download_compose_file
start_with_compose
