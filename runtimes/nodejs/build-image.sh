
# Warning: just for development phase, will be move to github action in future.

# get version from package.json
version=$(node -p "require('./package.json').version")

# build main image
docker buildx build --platform linux/amd64,linux/arm64 --push -t docker.io/junsik/data-plane-runtime-node:$version -t docker.io/junsik/data-plane-runtime-node:latest -f Dockerfile .

# build init image
docker buildx build --platform linux/amd64,linux/arm64 --push -t docker.io/junsik/data-plane-runtime-node-init:$version -t docker.io/junsik/data-plane-runtime-node-init:latest -f Dockerfile.init .