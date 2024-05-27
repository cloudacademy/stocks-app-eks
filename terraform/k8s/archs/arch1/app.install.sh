#!/usr/bin/env bash
echo -e "\nRDS ENDPOINT: $1\n"

echo -e "\nSTEP1: updating kubeconfig...\n"
sudo curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.12/2024-04-19/bin/linux/amd64/kubectl
sudo chmod +x ./kubectl
sudo mkdir -p $HOME/bin && sudo cp ./kubectl $HOME/bin/kubectl && sudo export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc

kubectl create namespace cloudacademy --dry-run=client -o yaml | kubectl apply -f - # create namespace if not exists
kubectl config set-context --current --namespace=cloudacademy

# ===========================

echo -e "\nSTEP2: create Ingress resource...\n"

cp ./templates/1_ingress.yaml ./manifests/

kubectl apply -f ./manifests/1_ingress.yaml

# ===========================

echo -e "\nSTEP3: patch Ingress resource...\n"

# shortcut to reuse the FQDN assigned to the nginx ingress controller ELB
# not recommended for production environments (proper DNS management should be used - R53 etc)

until kubectl get svc nginx-ingress-controller -n nginx-ingress >/dev/null 2>&1; do echo "waiting for nginx ingress controller service to become available..." && sleep 5; done
INGRESS_LB_FQDN=$(kubectl get svc nginx-ingress-controller -n nginx-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo $INGRESS_LB_FQDN

kubectl patch ingress public --type json -p "[{\"op\": \"replace\", \"path\": \"/spec/rules/0/host\", \"value\": \"$INGRESS_LB_FQDN\"}]"

# ===========================

echo -e "\nSTEP4: create API resources...\n"

sed \
-e "s/RDS_AURORA_ENDPOINT/$1/g" \
./templates/2_api.yaml > ./manifests/2_api.yaml

kubectl apply -f ./manifests/2_api.yaml

# ===========================

echo -e "\nSTEP5: create APP (frontend) compute resources...\n"

sed \
-e "s/INGRESS_FQDN/${INGRESS_LB_FQDN}/g" \
./templates/3_frontend.yaml > ./manifests/3_frontend.yaml

kubectl apply -f ./manifests/3_frontend.yaml

echo -e "\ndeployment finished\n"
