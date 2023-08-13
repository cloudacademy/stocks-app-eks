## EKS Cluster and Stocks Cloud Native App Deployment
The following instructions are provided to demonstrate how to provision a new EKS cluster and automatically deploy a fully functional Stocks cloud native web application.

An equivalent **ECS** setup is located here:
https://github.com/cloudacademy/stocks-app-ecs

![Stocks App](/docs/stocks.png)

### Kubernetes Architecture
The following architecture diagram documents the EKS cluster resources and Aurora RDS DB (serverless v1) used to setup the Stocks cloud native web application:

![Stocks App](/docs/eks-stocks-v2.png)

### Web Application Architecture
The Stocks cloud native web app consists of the following 3 main components:

#### Stocks Frontend (App)

Implements a web UI using the following languages/frameworks:

- React 16
- Yarn

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-app
- Container Image: [cloudacademydevops/stocks-app](https://hub.docker.com/r/cloudacademydevops/stocks-app)

#### Stocks API

Implements a RESTful based API using the following languages/frameworks:

- Java 17
- Spring Boot
- Maven 3

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-api
- Container Image: [cloudacademydevops/stocks-api](https://hub.docker.com/r/cloudacademydevops/stocks-api)

#### Stocks DB

Provisons and populates a SQL database using the following technology:

- MySQL 5.7

### Prerequisites
Ensure that the following tools are installed and configured appropriately.

- Terraform CLI
- AWS CLI
- Helm CLI
- Kubectl CLI

Note: The terraforming commands below have been tested successfully using the following versions:

- `terraform`: 1.5.3
- `aws`: aws-cli/2.13.2
- `helm`: 3.12.2
- `kubectl`: 1.27.4

### Installation

1. Application Deployment

    1.1. Initialise the Terraform working directory. Execute the following commands:

    ```
    cd terraform
    terraform init
    ```

    1.2. Provision a new EKS cluster and deploy the Stocks cloud native application automatically. Execute the following command:

    ```
    terraform apply -auto-approve
    ```

2. Confirm Access to the EKS Cluster

    2.1. Examine the EKS nodes setup. If this command returns successfully then the EKS cluster and access to it has been established successfully.

    ```
    kubectl get nodes
    ```

    If the previous command errors out due to an authentication issue, consider running the following AWS CLI command to re-establish a KUBECONFIG settings file:

    ```
    export KUBECONFIG=$(pwd)/config
    aws eks --region us-west-2 update-kubeconfig --name cloudacademydevops-eks
    ```

3. Examine EKS Cluster Resources

    3.1. Check Current Namespaces

    ```
    kubectl get namespaces
    ```

    3.2. Check Ingress Controller Setup

    ```
    kubectl get all -n nginx-ingress
    ```

    3.3. Check Cloud Native App Setup

    ```
    kubectl get all,ingress -n cloudacademy
    ```

    3.4. Test Access to the Stocks Frontend Ingress Endpoint

    ```
    curl -I $(kubectl get ing -n cloudacademy frontend -o jsonpath="{.spec.rules[0].host}")
    ```

4. Examine Aurora RDS DB

    4.1. List Database Clusters

    ```
    aws rds describe-db-clusters --region us-west-2
    ```

    4.2. List Database Cluster Endpoints

    ```
    aws rds describe-db-cluster-endpoints --db-cluster-identifier cloudacademy --region us-west-2
    ```

5. Generate and Test Stocks API Endpoint

    Execute the following command to generate Stocks API URL:

    ```
    echo http://$(kubectl get ing -n cloudacademy api -o jsonpath="{.spec.rules[0].host}")
    ```

    Copy the URL from the previous output and browse to it within your own browser. Confirm that the Stocks CSV formatted data is accessible.

6. Generate and Test Stocks APP (frontend) Endpoint

    Execute the following command to generate Stocks API URL:

    ```
    echo http://$(kubectl get ing -n cloudacademy frontend -o jsonpath="{.spec.rules[0].host}")
    ```

    Copy the URL from the previous output and browse to it within your own browser. Confirm that the Stocks App (frontend) loads successfully.