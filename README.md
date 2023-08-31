## EKS Cluster and Stocks Cloud Native App Deployment
The following instructions are provided to demonstrate how to provision a new EKS cluster and automatically deploy a fully functional Stocks cloud native web application.

An equivalent **ECS** setup is located here:
https://github.com/cloudacademy/stocks-app-ecs

![Stocks App](/docs/stocks.png)

### Kubernetes Architecture
Two different Kubernetes architectures are provided for the deployment of the Stocks cloud native web app. The main difference between architectures is the Stock API routing path. To swap between the different architectures, set the `k8s.stocks_app_architecture` local variable to be either `arch1` or `arch2`.

```
locals {
  name        = "cloudacademydevops"
  environment = "prod"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  //returns
  #   tolist([
  #   "us-west-2a",
  #   "us-west-2b"
  # ])

  k8s = {
    stocks_app_architecture = "arch1" #either arch1 or arch2

    cluster_name   = "${local.name}-eks-${local.environment}"
    version        = "1.27"
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 10
    min_size       = 2
    max_size       = 2
    desired_size   = 2
  }

  rds = {
    master_username = "root"
    master_password = "followthewhiterabbit"
    db_name         = "cloudacademy"
    scaling_min     = 2
    scaling_max     = 4
  }
}
```

#### Architecture 1 (arch1):

![Stocks App](/docs/eks-stocks-arch1.png)

#### Architecture 2 (arch2):

![Stocks App](/docs/eks-stocks-arch2.png)

### Web Application Architecture
The Stocks cloud native web app consists of the following 3 main components:

#### Stocks Frontend (App)

Implements a web UI using the following languages/frameworks/tools:

- React 16
- Yarn
- Nginx

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-app
- Container Image: [cloudacademydevops/stocks-app:v2](https://hub.docker.com/r/cloudacademydevops/stocks-app)

#### Stocks API

Implements a RESTful based API using the following languages/frameworks/tools:

- Java 17
- Spring Boot
- Maven 3

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-api
- Container Image: [cloudacademydevops/stocks-api:v2](https://hub.docker.com/r/cloudacademydevops/stocks-api)

#### Stocks DB

Aurora RDS DB (serverless v1) SQL database:

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

    3.1. Check Namespaces

    ```
    kubectl get ns
    ```

    3.2. Check Ingress Controller Setup

    ```
    kubectl get all -n nginx-ingress
    ```

    3.3. Check Cloud Native App Setup

    ```
    kubectl get all,ingress,secret -n cloudacademy
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
    echo http://$(kubectl get ing -n cloudacademy public -o jsonpath="{.spec.rules[0].host}")/api/stocks/csv
    ```

    Copy the URL from the previous output and browse to it within your own browser. Confirm that the Stocks CSV formatted data is accessible.

6. Generate and Test Stocks APP (frontend) Endpoint

    Execute the following command to generate Stocks API URL:

    ```
    echo http://$(kubectl get ing -n cloudacademy public -o jsonpath="{.spec.rules[0].host}")
    ```

    Copy the URL from the previous output and browse to it within your own browser. Confirm that the Stocks App (frontend) loads successfully, complete with stocks data.