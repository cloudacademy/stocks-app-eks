### Architecture 2 (arch2):
This architecture consists of a single Ingress resource that has a signle path for all traffic configured. The Ingress resource sends all traffic to the downstream frontend service and respective pods. Routing logic is implemented within the frontend pods.

![Stocks App](/docs/eks-stocks-arch2.png)

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
    - host: fake.cloudacademy.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 8080
```

**Note**: The `host` field is overwritten dynamically at deployment time with the FQDN of the Ingress Controller's ELB (created when the Ingress Controller is installed). The `app.install.sh` is responsible for scripting this update.

### Frontend Pod Nginx Config

```
upstream api-backend {
    server ${NGINX_APP_APIHOSTPORT};
    keepalive 20;
}

server {
  listen 8080;
  add_header Cache-Control no-cache;

  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
    try_files $uri $uri/ /index.html;
    expires -1;
  }

  location /api/stocks/csv {
    proxy_pass http://api-backend;
  }

  error_page   500 502 503 504  /50x.html;
  location = /50x.html {
    root   /usr/share/nginx/html;
  }
}
```

**Note**: The `NGINX_APP_APIHOSTPORT` environment variable is substituted in dynamically during container launch time. The `NGINX_APP_APIHOSTPORT` environment variable is set to the API's cluster internal service FQDN and port number, `api.cloudacademy.svc.cluster.local:8080`. This configuration can be viewed in the `4_frontend.yaml` manifest:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: cloudacademy
  labels:
    role: frontend
    env: demo
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      role: frontend
  template:
    metadata:
      labels:
        role: frontend
    spec:
      containers:
      - name: frontend
        image: cloudacademydevops/stocks-app:v2
        imagePullPolicy: Always
        env:
          - name: REACT_APP_APIHOSTPORT
            value: INGRESS_FQDN
          - name: NGINX_APP_APIHOSTPORT
            value: api.cloudacademy.svc.cluster.local:8080
        ports:
        - containerPort: 8080
```

### Terraform Provisioning
This architecture is deployed automatically during provisioning time by setting the `k8s.stocks_app_architecture` local variable to `arch2` in the `main.tf` template.

```
locals {
  name        = "cloudacademydevops"
  environment = "prod"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  
  k8s = {
    stocks_app_architecture = "arch2" # <===== either arch1 or arch2

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
