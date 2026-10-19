#!/bin/bash
# ============================================================
# BambooTrace — Azure VM Setup Script
# Run once on a fresh Ubuntu 24.04 Azure VM
# Usage: bash scripts/azure_vm_setup.sh
# ============================================================

set -e  # Exit on any error

DEPLOY_USER="${SUDO_USER:-$USER}"

echo "================================================"
echo " BambooTrace Azure VM Setup"
echo "================================================"

# --- 1. System Update ---
echo "[1/5] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# --- 2. Install Docker ---
echo "[2/5] Installing Docker..."
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$DEPLOY_USER"

echo "[2/5] Installing Docker Compose plugin..."
sudo apt-get install -y docker-compose-plugin

# --- 3. Install Nginx ---
echo "[3/5] Installing Nginx..."
sudo apt-get install -y nginx

# --- 4. Install Git ---
echo "[4/5] Installing Git..."
sudo apt-get install -y git

# --- 5. Install useful tools ---
echo "[5/5] Installing utilities..."
sudo apt-get install -y curl wget unzip htop

# --- Enable Nginx and Docker on boot ---
sudo systemctl enable nginx
sudo systemctl enable docker

echo ""
echo "================================================"
echo " Setup complete! Next steps:"
echo "================================================"
echo ""
echo "1. Log out and reconnect (to apply docker group):"
echo "   exit"
echo "   ssh <ADMIN_USER>@<AZURE_VM_PUBLIC_IP>"
echo ""
echo "2. From the repository folder, set up your .env:"
echo "   cp .env.azure.example .env"
echo "   nano .env   # Set managed PostgreSQL, HTTPS URL, and secrets"
echo ""
echo "3. Initialize a new database, if needed:"
echo "   bash scripts/initialize_managed_postgres.sh"
echo ""
echo "4. Deploy:"
echo "   bash scripts/deploy.sh"
echo ""
echo "Ensure the VM can reach the managed PostgreSQL server and that"
echo "DNS/HTTPS are configured before using the app in production."
echo ""
