#!/usr/bin/env bash
echo -e "\nRDS ENDPOINT: $1\n"
echo -e "\nSTEP1: updating kubeconfig...\n"

kubectl create namespace cloudacademy --dry-run=client -o yaml | kubectl apply -f - # create namespace if not exists
kubectl config set-context --current --namespace=cloudacademy

# ===========================

echo -e "\nSTEP2: create secret resource...\n"

cp ./templates/1_secret.yaml ./manifests/

kubectl apply -f ./manifests/1_secret.yaml

# ===========================

echo -e "\nSTEP3: create API resources...\n"

sed \
-e "s/RDS_AURORA_ENDPOINT/$1/g" \
./templates/2_api.yaml > ./manifests/2_api.yaml

kubectl apply -f ./manifests/2_api.yaml

# ===========================

echo -e "\nSTEP4: create APP (frontend) networking resources...\n"

cp ./templates/3_frontend_networking.yaml ./manifests/

kubectl apply -f ./manifests/3_frontend_networking.yaml

# ===========================

echo -e "\nSTEP5: patch APP (frontend) ingress resource...\n"

until kubectl get svc nginx-ingress-controller -n nginx-ingress >/dev/null 2>&1; do echo "waiting for nginx ingress controller service to become available..." && sleep 5; done
INGRESS_LB_FQDN=$(kubectl get svc nginx-ingress-controller -n nginx-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo $INGRESS_LB_FQDN

kubectl patch ingress frontend -p "{\"spec\": {\"rules\": [{\"host\": \"$INGRESS_LB_FQDN\",\"http\": {\"paths\": [{\"path\": \"/\",\"pathType\": \"Prefix\",\"backend\": {\"service\": {\"name\": \"frontend\",\"port\": {\"number\": 8080}}}}]}}]}}"

# ===========================

echo -e "\nSTEP4: create APP (frontend) compute resources...\n"

sed \
-e "s/INGRESS_FQDN/${INGRESS_LB_FQDN}/g" \
./templates/4_frontend_compute.yaml > ./manifests/4_frontend_compute.yaml

kubectl apply -f ./manifests/4_frontend_compute.yaml

echo -e "\ndeployment finished\n"