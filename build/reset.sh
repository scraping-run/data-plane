#!/bin/bash

# Reset script for data-plane installation
# This script removes all data-plane components from the Kubernetes cluster

set -e

# *************** Configuration ************** #
NAMESPACE=${NAMESPACE:-data-plane-system}

echo "================================================"
echo "Data Plane Reset Script"
echo "================================================"
echo "This will remove all data-plane components from namespace: $NAMESPACE"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Reset cancelled."
    exit 0
fi

echo ""
echo "Starting reset process..."

# *************** Remove Helm Releases ************** #
echo ""
echo "1. Removing Helm releases..."

# Remove web
if helm list -n ${NAMESPACE} | grep -q "^web\s"; then
    echo "   - Uninstalling data-plane-web..."
    helm uninstall web -n ${NAMESPACE} || true
else
    echo "   - data-plane-web not found"
fi

# Remove server
if helm list -n ${NAMESPACE} | grep -q "^server\s"; then
    echo "   - Uninstalling data-plane-server..."
    helm uninstall server -n ${NAMESPACE} || true
else
    echo "   - data-plane-server not found"
fi

# Remove minio
if helm list -n ${NAMESPACE} | grep -q "^minio\s"; then
    echo "   - Uninstalling minio..."
    helm uninstall minio -n ${NAMESPACE} || true
else
    echo "   - minio not found"
fi

# Remove prometheus
if helm list -n ${NAMESPACE} | grep -q "^prometheus\s"; then
    echo "   - Uninstalling prometheus..."
    helm uninstall prometheus -n ${NAMESPACE} || true
else
    echo "   - prometheus not found"
fi

# *************** Remove MongoDB ************** #
echo ""
echo "2. Removing MongoDB..."

# Check if KubeBlocks MongoDB cluster exists
if kubectl get cluster mongodb -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "   - Removing KubeBlocks MongoDB cluster..."
    kubectl delete cluster mongodb -n ${NAMESPACE} --ignore-not-found=true
    # Wait for cluster to be deleted
    sleep 10
fi

# Remove manual MongoDB installations (both single instance and replica set)
kubectl delete deployment mongodb -n ${NAMESPACE} --ignore-not-found=true
kubectl delete statefulset mongodb -n ${NAMESPACE} --ignore-not-found=true
kubectl delete service mongodb mongodb-0 mongodb-1 mongodb-2 -n ${NAMESPACE} --ignore-not-found=true
kubectl delete service mongodb-mongodb mongodb-mongodb-0 mongodb-mongodb-1 mongodb-mongodb-2 -n ${NAMESPACE} --ignore-not-found=true
kubectl delete job mongodb-init-replica -n ${NAMESPACE} --ignore-not-found=true
kubectl delete secret mongodb-secret mongodb-conn-credential -n ${NAMESPACE} --ignore-not-found=true
kubectl delete pvc mongodb-data -n ${NAMESPACE} --ignore-not-found=true
kubectl delete pvc data-mongodb-0 data-mongodb-1 data-mongodb-2 -n ${NAMESPACE} --ignore-not-found=true
kubectl delete pvc data-mongodb-mongodb-0 data-mongodb-mongodb-1 data-mongodb-mongodb-2 -n ${NAMESPACE} --ignore-not-found=true
kubectl delete pv mongodb-data-pv --ignore-not-found=true

# *************** Remove Additional Resources ************** #
echo ""
echo "3. Removing additional resources..."

# Remove any remaining PVCs
echo "   - Removing PersistentVolumeClaims..."
kubectl delete pvc --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining secrets
echo "   - Removing non-essential secrets..."
kubectl get secrets -n ${NAMESPACE} -o name | grep -v "default-token\|kubernetes.io/service-account-token" | xargs -r kubectl delete -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining configmaps
echo "   - Removing ConfigMaps..."
kubectl delete configmap --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining services
echo "   - Removing Services..."
kubectl delete service --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining ingresses
echo "   - Removing Ingresses..."
kubectl delete ingress --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining deployments
echo "   - Removing Deployments..."
kubectl delete deployment --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining statefulsets
echo "   - Removing StatefulSets..."
kubectl delete statefulset --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining daemonsets
echo "   - Removing DaemonSets..."
kubectl delete daemonset --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining jobs
echo "   - Removing Jobs..."
kubectl delete job --all -n ${NAMESPACE} --ignore-not-found=true

# Remove any remaining cronjobs
echo "   - Removing CronJobs..."
kubectl delete cronjob --all -n ${NAMESPACE} --ignore-not-found=true

# *************** Optional: Remove Namespace ************** #
echo ""
read -p "Do you want to delete the namespace '$NAMESPACE'? (yes/no): " delete_ns

if [ "$delete_ns" = "yes" ]; then
    echo "4. Deleting namespace..."
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
    echo "   Namespace deleted. Waiting for termination..."
    
    # Wait for namespace to be deleted
    timeout=60
    while kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; do
        if [ $timeout -le 0 ]; then
            echo "   Warning: Namespace deletion timed out. It may still be terminating."
            break
        fi
        echo -n "."
        sleep 2
        timeout=$((timeout - 2))
    done
    echo ""
else
    echo "4. Namespace retained."
fi

# *************** Cleanup PVs ************** #
echo ""
echo "5. Checking for orphaned PersistentVolumes..."
orphaned_pvs=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace == "'${NAMESPACE}'") | .metadata.name')

if [ -n "$orphaned_pvs" ]; then
    echo "   Found orphaned PVs:"
    echo "$orphaned_pvs" | while read pv; do
        echo "   - $pv"
    done
    
    read -p "Do you want to delete these orphaned PVs? (yes/no): " delete_pvs
    if [ "$delete_pvs" = "yes" ]; then
        echo "$orphaned_pvs" | while read pv; do
            kubectl delete pv $pv --ignore-not-found=true
        done
        echo "   Orphaned PVs deleted."
    fi
else
    echo "   No orphaned PVs found."
fi

echo ""
echo "================================================"
echo "Reset complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. To reinstall, run: ./start.sh"
echo "2. To check remaining resources: kubectl get all -n ${NAMESPACE}"
echo ""