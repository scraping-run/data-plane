#!/bin/bash

# Build the web application first
echo "Building web application..."
npm install
npm run build

# Build Docker image
echo "Building Docker image..."
docker buildx build --platform linux/arm64 --push -t docker.io/junsik/data-plane-web:latest -f Dockerfile .

echo "Build complete!"