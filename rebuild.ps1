Write-Host "Stopping containers..."
docker compose down
Write-Host "Building image..."
docker compose build
Write-Host "Starting containers..."
docker compose up -d
Write-Host "Done! n8n available at http://localhost:5678"