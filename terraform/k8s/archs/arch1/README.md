### Architecture 1 (arch1):
This architecture consists of a single Ingress resource that has multiple paths configured, one for the frontend (html, js, css), and one for the API (csv data). The Ingress resource maps each path to its respective service

![Stocks App](/docs/eks-stocks-arch1.png)

### Terraform Provisioning
This architecture is deployed automatically during provisioning time by setting the `k8s.stocks_app_architecture` Local Value to `arch1` in the `main.tf` template.

```
locals {
  name        = "cloudacademydevops"
  environment = "prod"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  
  k8s = {
    stocks_app_architecture = "arch1" # <===== either arch1 or arch2

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

### Ingress Setup

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: public
  namespace: cloudacademy
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: elb.host.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 8080
          - path: /api/stocks/csv
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 8080
```

**Note**: The `host` field is overwritten dynamically at deployment time with the FQDN of the Ingress Controller's ELB (created when the Ingress Controller is installed). The `app.install.sh` is responsible for scripting this update.