#!/bin/bash

# Build the TypeScript application first
echo "Installing dependencies..."
npm install

echo "Building TypeScript..."
npm run build

# Build Docker image
echo "Building Docker image..."
docker buildx build --platform linux/amd64,linux/arm64 --push -t docker.io/junsik/runtime-exporter:latest -f Dockerfile .

echo "Build complete!"