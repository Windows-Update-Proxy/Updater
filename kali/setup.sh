#!/bin/bash

# Setup Script voor C2 Server
# Educational Cybersecurity Project

echo "=========================================="
echo "C2 Server Setup - Docker + Node.js"
echo "=========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "[!] Docker is niet geïnstalleerd!"
    echo "[*] Installeer Docker eerst: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "[!] Docker Compose is niet geïnstalleerd!"
    echo "[*] Installeer Docker Compose eerst"
    exit 1
fi

echo "[+] Docker is geïnstalleerd"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "[*] Maak .env bestand aan..."
    cp .env.example .env 2>/dev/null || cat > .env << 'EOF'
# Environment Configuration
NODE_ENV=production
PORT=3000
ADMIN_TOKEN=your-secret-token-change-this
NGROK_AUTHTOKEN=your_ngrok_authtoken_here
EOF
    echo "[!] BELANGRIJK: Edit .env en configureer je tokens!"
    echo ""
fi

# Vraag voor ngrok authtoken
echo "=========================================="
echo "ngrok Setup"
echo "=========================================="
echo ""
echo "Heb je al een ngrok authtoken?"
echo "Zo niet, maak een gratis account aan op: https://ngrok.com"
echo ""
read -p "Voer je ngrok authtoken in (of druk Enter om over te slaan): " ngrok_token

if [ ! -z "$ngrok_token" ]; then
    # Update .env met ngrok token
    sed -i "s/NGROK_AUTHTOKEN=.*/NGROK_AUTHTOKEN=$ngrok_token/" .env
    echo "[+] ngrok authtoken opgeslagen"
else
    echo "[!] ngrok niet geconfigureerd - server zal alleen lokaal beschikbaar zijn"
fi

echo ""

# Vraag voor admin token
echo "=========================================="
echo "Security Setup"
echo "=========================================="
echo ""
echo "Genereer een veilig admin token voor authenticatie"
read -p "Voer een admin token in (min. 20 karakters): " admin_token

if [ ${#admin_token} -lt 20 ]; then
    echo "[!] Token te kort, genereer automatisch..."
    admin_token=$(openssl rand -hex 32)
    echo "[*] Gegenereerd token: $admin_token"
fi

# Update .env met admin token
sed -i "s/ADMIN_TOKEN=.*/ADMIN_TOKEN=$admin_token/" .env
echo "[+] Admin token opgeslagen"
echo ""

# Maak directories
echo "[*] Maak directories aan..."
mkdir -p data logs
echo "[+] Directories aangemaakt"
echo ""

# Build Docker image
echo "=========================================="
echo "Docker Build"
echo "=========================================="
echo ""
echo "[*] Building Docker image..."
docker-compose build

if [ $? -eq 0 ]; then
    echo "[+] Docker image succesvol gebouwd"
else
    echo "[!] Docker build mislukt"
    exit 1
fi

echo ""
echo "=========================================="
echo "Setup Compleet!"
echo "=========================================="
echo ""
echo "Start de server met: docker-compose up -d"
echo "Stop de server met: docker-compose down"
echo "Bekijk logs met: docker-compose logs -f"
echo ""
echo "Admin Token: $admin_token"
echo ""
echo "BELANGRIJK: Sla dit token veilig op!"
echo "Je hebt het nodig voor de Kali controller"
echo ""
