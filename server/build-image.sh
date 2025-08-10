# Warning: just for development phase, will be move to github action in future.



docker buildx build --platform linux/arm64 --push -t docker.io/junsik/data-plane-server:latest -f Dockerfile.multistage .
