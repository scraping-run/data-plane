# Warning: just for development phase, will be move to github action in future.



docker buildx build --platform linux/amd64,linux/arm64 --push -t docker.io/junsik/data-plane-web:202508082204 -f Dockerfile .
