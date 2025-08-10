DOMAIN=${DOMAIN:-prod.scraping.run}
echo "DOMAIN: $DOMAIN"

# check $DOMAIN is available
if ! host $DOMAIN; then
    echo "Domain $DOMAIN is not available"
    exit 1
fi

# *************** Environment Variables ************** #

## envs - global
EXTERNAL_HTTP_SCHEMA=${EXTERNAL_HTTP_SCHEMA:-https}

NAMESPACE=${NAMESPACE:-data-plane-system}
PASSWD_OR_SECRET=$(tr -cd 'a-z0-9' </dev/urandom | head -c32)

ENABLE_MONITOR=${ENABLE_MONITOR:-true}

# *************** Deployments **************** #

## 0. create namespace
kubectl create namespace ${NAMESPACE} || true

## 1. install mongodb with KubeBlocks
set -e
set -x

# Check which MongoDB deployment method to use
USE_KUBEBLOCKS=${USE_KUBEBLOCKS:-true}
USE_REPLICA_SET=${USE_REPLICA_SET:-true}

if [ "$USE_KUBEBLOCKS" = "true" ]; then
    echo "Installing MongoDB 5.0 with KubeBlocks..."
    # Set replica count based on USE_REPLICA_SET
    if [ "$USE_REPLICA_SET" = "true" ]; then
        REPLICAS=3
    else
        REPLICAS=1
    fi
    
    # Apply KubeBlocks MongoDB cluster with dynamic replica count
    sed -e "s/\$CAPACITY/${DB_PV_SIZE:-30Gi}/g" \
        -e "s/replicas: [0-9]*/replicas: ${REPLICAS}/g" \
        mongodb-kubeblocks.yaml | kubectl apply -n ${NAMESPACE} -f -
    
    # Wait for KubeBlocks cluster to be ready
    echo "Waiting for KubeBlocks MongoDB cluster to be ready..."
    sleep 30  # Initial wait for cluster creation
    
    # Get connection info from KubeBlocks cluster
    # KubeBlocks creates services like: mongodb-mongodb, mongodb-mongodb-0, etc.
    if [ "$REPLICAS" = "3" ]; then
        DB_ENDPOINT="mongodb-mongodb-0.${NAMESPACE}.svc.cluster.local:27017,mongodb-mongodb-1.${NAMESPACE}.svc.cluster.local:27017,mongodb-mongodb-2.${NAMESPACE}.svc.cluster.local:27017"
        REPLICA_SET_PARAM="?replicaSet=mongodb&authSource=admin"
    else
        DB_ENDPOINT="mongodb-mongodb.${NAMESPACE}.svc.cluster.local:27017"
        REPLICA_SET_PARAM="?authSource=admin"
    fi
    
    # Get credentials from KubeBlocks secret (usually mongodb-conn-credential)
    echo "Retrieving MongoDB credentials from KubeBlocks..."
    # Try to get credentials from KubeBlocks generated secret
    if kubectl get secret mongodb-conn-credential -n ${NAMESPACE} >/dev/null 2>&1; then
        DB_USERNAME=$(kubectl get secret mongodb-conn-credential -n ${NAMESPACE} -o jsonpath='{.data.username}' | base64 -d)
        DB_PASSWORD=$(kubectl get secret mongodb-conn-credential -n ${NAMESPACE} -o jsonpath='{.data.password}' | base64 -d)
    else
        # Fallback to our custom secret
        DB_USERNAME=$(kubectl get secret mongodb-secret -n ${NAMESPACE} -o jsonpath='{.data.mongodb-root-username}' | base64 -d)
        DB_PASSWORD=$(kubectl get secret mongodb-secret -n ${NAMESPACE} -o jsonpath='{.data.mongodb-root-password}' | base64 -d)
    fi
    DB_DATABASE="data-plane"
    
elif [ "$USE_REPLICA_SET" = "true" ]; then
    echo "Installing MongoDB Replica Set (manual)..."
    sed "s/\$CAPACITY/${DB_PV_SIZE:-30Gi}/g" mongodb-replicaset.yaml | kubectl apply -n ${NAMESPACE} -f -
    
    # Wait for StatefulSet to be ready
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=3 statefulset/mongodb -n ${NAMESPACE} --timeout=300s
    
    # Wait for init job to complete
    kubectl wait --for=condition=complete job/mongodb-init-replica -n ${NAMESPACE} --timeout=120s || true
    
    # MongoDB replica set connection string
    DB_ENDPOINT="mongodb-0.mongodb.${NAMESPACE}.svc.cluster.local:27017,mongodb-1.mongodb.${NAMESPACE}.svc.cluster.local:27017,mongodb-2.mongodb.${NAMESPACE}.svc.cluster.local:27017"
    REPLICA_SET_PARAM="?replicaSet=rs0&authSource=admin"
    
    # Get credentials from secret
    DB_USERNAME=$(kubectl get secret -n ${NAMESPACE} mongodb-secret -ojsonpath='{.data.mongodb-root-username}' | base64 -d)
    DB_PASSWORD=$(kubectl get secret -n ${NAMESPACE} mongodb-secret -ojsonpath='{.data.mongodb-root-password}' | base64 -d)
    DB_DATABASE=$(kubectl get secret -n ${NAMESPACE} mongodb-secret -ojsonpath='{.data.mongodb-database}' | base64 -d)
    
else
    echo "Installing single MongoDB instance..."
    sed "s/\$CAPACITY/${DB_PV_SIZE:-30Gi}/g" mongodb-4.4.yaml | kubectl apply -n ${NAMESPACE} -f -
    kubectl wait --for=condition=available --timeout=120s deployment/mongodb -n ${NAMESPACE}
    
    # Single instance connection
    DB_ENDPOINT="mongodb.${NAMESPACE}.svc.cluster.local:27017"
    REPLICA_SET_PARAM="?authSource=admin"
    
    # Get credentials from secret
    DB_USERNAME=$(kubectl get secret -n ${NAMESPACE} mongodb-secret -ojsonpath='{.data.mongodb-root-username}' | base64 -d)
    DB_PASSWORD=$(kubectl get secret -n ${NAMESPACE} mongodb-secret -ojsonpath='{.data.mongodb-root-password}' | base64 -d)
    DB_DATABASE=$(kubectl get secret -n ${NAMESPACE} mongodb-secret -ojsonpath='{.data.mongodb-database}' | base64 -d)
fi

# URL encode the password to handle special characters
urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o
    
    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * ) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Encode password for safe URL usage
DB_PASSWORD_ENCODED=$(urlencode "${DB_PASSWORD}")
DATABASE_URL="mongodb://${DB_USERNAME}:${DB_PASSWORD_ENCODED}@${DB_ENDPOINT}/${DB_DATABASE}${REPLICA_SET_PARAM}"

echo "MongoDB connection configured with URL-encoded password"
if [ "$USE_REPLICA_SET" = "true" ]; then
    echo "Using MongoDB Replica Set with connection: ${DB_ENDPOINT}"
else
    echo "Using single MongoDB instance"
fi

## 2. install prometheus
PROMETHEUS_URL=http://prometheus-operated.${NAMESPACE}.svc.cluster.local:9090
if [ "$ENABLE_MONITOR" = "true" ]; then
    sed -e "s/\$NAMESPACE/$NAMESPACE/g" \
        -e "s/\$PROMETHEUS_PV_SIZE/${PROMETHEUS_PV_SIZE:-20Gi}/g" \
        -e "s/\$DOMAIN/${DOMAIN}/g" \
        prometheus-helm.yaml >prometheus-helm-with-values.yaml

    helm install prometheus --version 48.3.3 -n ${NAMESPACE} \
        -f ./prometheus-helm-with-values.yaml \
        ./charts/kube-prometheus-stack
fi

## 3. install minio
MINIO_ROOT_ACCESS_KEY=minio-root-user
MINIO_ROOT_SECRET_KEY=$PASSWD_OR_SECRET
MINIO_DOMAIN=oss.${DOMAIN}
MINIO_EXTERNAL_ENDPOINT="${EXTERNAL_HTTP_SCHEMA}://${MINIO_DOMAIN}"
MINIO_INTERNAL_ENDPOINT="http://minio.${NAMESPACE}.svc.cluster.local:9000"

helm install minio -n ${NAMESPACE} \
    --set rootUser=${MINIO_ROOT_ACCESS_KEY} \
    --set rootPassword=${MINIO_ROOT_SECRET_KEY} \
    --set persistence.size=${OSS_PV_SIZE:-3Gi} \
    --set domain=${MINIO_DOMAIN} \
    --set consoleHost=minio.${DOMAIN} \
    --set metrics.serviceMonitor.enabled=${ENABLE_MONITOR} \
    --set metrics.serviceMonitor.additionalLabels.release=prometheus \
    --set metrics.serviceMonitor.additionalLabels.namespace=${NAMESPACE} \
    ./charts/minio

## 4. install data-plane-server
SERVER_JWT_SECRET=$PASSWD_OR_SECRET
RUNTIME_EXPORTER_SECRET=$PASSWD_OR_SECRET
helm install server -n ${NAMESPACE} \
    --set databaseUrl=${DATABASE_URL} \
    --set jwt.secret=${SERVER_JWT_SECRET} \
    --set apiServerHost=api.${DOMAIN} \
    --set apiServerUrl=${EXTERNAL_HTTP_SCHEMA}://api.${DOMAIN} \
    --set siteName=${DOMAIN} \
    --set default_region.fixed_namespace=${NAMESPACE} \
    --set default_region.database_url=${DATABASE_URL} \
    --set default_region.minio_domain=${MINIO_DOMAIN} \
    --set default_region.minio_external_endpoint=${MINIO_EXTERNAL_ENDPOINT} \
    --set default_region.minio_internal_endpoint=${MINIO_INTERNAL_ENDPOINT} \
    --set default_region.minio_root_access_key=${MINIO_ROOT_ACCESS_KEY} \
    --set default_region.minio_root_secret_key=${MINIO_ROOT_SECRET_KEY} \
    --set default_region.runtime_domain=${DOMAIN} \
    --set default_region.website_domain=${DOMAIN} \
    --set default_region.tls.enabled=true \
    $([ "$ENABLE_MONITOR" = "true" ] && echo "--set default_region.runtime_exporter_secret=${RUNTIME_EXPORTER_SECRET}") \
    $([ "$ENABLE_MONITOR" = "true" ] && echo "--set default_region.prometheus_url=${PROMETHEUS_URL}") \
    ./charts/data-plane-server

## 5. install data-plane-web
helm install web -n ${NAMESPACE} \
    --set domain=${DOMAIN} \
    ./charts/data-plane-web
