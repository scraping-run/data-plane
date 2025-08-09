<<<<<<< HEAD
#!/bin/bash

# Build the web application first
echo "Building web application..."
npm install
npm run build

# Build Docker image
echo "Building Docker image..."
docker buildx build --platform linux/arm64 --push -t docker.io/junsik/data-plane-web:latest -f Dockerfile .

echo "Build complete!"
=======
# Warning: just for development phase, will be move to github action in future.



docker buildx build --platform linux/amd64,linux/arm64 --push -t docker.io/junsik/data-plane-web:202508082204 -f Dockerfile .
>>>>>>> f313b56fc8b5478120a58e6e9ccf5028e77e010e
