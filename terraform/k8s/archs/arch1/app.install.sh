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

echo -e "\nSTEP3: create Ingress resource...\n"

cp ./templates/2_ingress.yaml ./manifests/

kubectl apply -f ./manifests/2_ingress.yaml

# ===========================

echo -e "\nSTEP4: patch Ingress resource...\n"

# shortcut to reuse the FQDN assigned to the nginx ingress controller ELB
# not recommended for production environments (proper DNS management should be used - R53 etc)

until kubectl get svc nginx-ingress-controller -n nginx-ingress >/dev/null 2>&1; do echo "waiting for nginx ingress controller service to become available..." && sleep 5; done
INGRESS_LB_FQDN=$(kubectl get svc nginx-ingress-controller -n nginx-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo $INGRESS_LB_FQDN

kubectl patch ingress public --type json -p "[{\"op\": \"replace\", \"path\": \"/spec/rules/0/host\", \"value\": \"$INGRESS_LB_FQDN\"}]"

# ===========================

echo -e "\nSTEP5: create API resources...\n"

sed \
-e "s/RDS_AURORA_ENDPOINT/$1/g" \
./templates/3_api.yaml > ./manifests/3_api.yaml

kubectl apply -f ./manifests/3_api.yaml

# ===========================

echo -e "\nSTEP6: create APP (frontend) compute resources...\n"

sed \
-e "s/INGRESS_FQDN/${INGRESS_LB_FQDN}/g" \
./templates/4_frontend.yaml > ./manifests/4_frontend.yaml

kubectl apply -f ./manifests/4_frontend.yaml

echo -e "\ndeployment finished\n"