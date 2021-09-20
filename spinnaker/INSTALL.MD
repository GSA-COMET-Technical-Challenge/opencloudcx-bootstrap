
# Table of Contents

---
---

# TL;DR
1. terraform init/terraform apply
1. update environment
    - local hosts file with load balancer ip
    - awd-auth config map with aws role
    -  codebuild with jenkins admin api key
1. run codebuild
1. create application in spinnaker
    - paste json as application definition
    - refresh jenkins links (k8s-jenkins)
1. run pipeline
1. navigate to load balancer url

---
---

# Usage instructions

OpenCloudCX installs in a few separate pieces. This instruction set will outline the steps to get the stack up and running. This tutorial assumes access to a Linux instance. 

---
---
# Phase 0 -- Toolset installation

## Windows System for Liunx

If you don't have access to a Linux instance for installatoin, follow these instructions to install Windows Subsystem for Linux (WSL).

```https://docs.microsoft.com/en-us/windows/wsl/install-win10```

## AWS CLI

Install latest version of the AWS CLI

```https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html```

## Terraform

__This project has been tested against Terraform 0.14.2. Any more recent version may produce anomalous results__

If there are no other versions of terraform installed, follow the clean install instructions. If `terraform -v` reports any other version than `0.14.02`, follow the multiple version instructions

### Download terraform

```bash
curl -o "terraform.zip" https://releases.hashicorp.com/terraform/0.14.2/terraform_0.14.2_linux_amd64.zip
unzip terraform.zip
```

### Clean install

```bash
mv terraform /usr/bin/terraform
rm -f terraform.zip
terraform -version  
```

Output
```
Terraform v0.14.2

Your version of Terraform is out of date! The latest version
is 1.0.7. You can update by downloading from https://www.terraform.io/downloads.html
```

### Multiple version install
``` bash
mv terraform /usr/bin/terraform14
rm -f terraform.zip
terraform14 -version  
```

Output
```
Terraform v0.14.2

Your version of Terraform is out of date! The latest version
is 1.0.7. You can update by downloading from https://www.terraform.io/downloads.html
```
## Kubectl

```https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/```


---


# Phase I -- Base Functionality

The first step is to set up the spinnaker cluster -- installation of all base functionality as follows:
* AWS VPC and security
* AWS EKS cluster
* AWS NodeGroups
* OpenCloudCX services
    * Spinnaker
    * Grafana
    * Anchore 
    * Jenkins
    * Portainer
    * Sonarqube

Below is an example of the `main.tf` file required to build the cluster

```hcl
# Complete example

terraform {
  required_version = "~> 0.14.2"

  backend "s3" {
    key    = "opencloudcx"
    bucket = var.state_bucket_name
    region = "us-east-1"
  }
}

resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  version             = ">= 3.0"
}

provider "aws" {
  alias               = "prod"
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  version             = ">= 3.0"
}

module "opencloudcx" {
  source  = "OpenCloudCX/opencloudcx/aws"
  version = ">= [0.3.11]"

  name               = "riva"
  stack              = "dev"
  detail             = "module-test"
  tags               = { "env" = "dev" }
  region             = "us-east-1"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  cidr               = "10.0.0.0/16"
  dns_zone           = var.dns_zone
  kubernetes_version = "1.21"
  kubernetes_node_groups = {
    default = {
      instance_type = "m5.large"
      min_size      = "1"
      max_size      = "3"
      desired_size  = "2"
    }
  }

  jenkins_secret   = random_password.jenkins_password.result
  sonarqube_secret = random_password.sonarqube_password.result
  github_access_token = var.github_access_token
  aws_account_id = var.aws_account_id
  # portainer_secret = aws_secretsmanager_secret.portainer_secret

  aurora_cluster = {
    node_size = "1"
    node_type = "db.t3.medium"
    version   = "5.7.12"
  }
  helm_chart_version = "2.2.3"
  helm_chart_values  = [file("values.yaml")]
  assume_role_arn    = [module.spinnaker-managed-role.role_arn]

  dockerhub_secret_name = var.dockerhub_secret_name
  dockerhub_username = var.dockerhub_username
  dockerhub_secret = var.dockerhub_secret
}

module "spinnaker-managed-role" {
  source  = "OpenCloudCX/opencloudcx/aws//modules/spinnaker-managed-aws"
  version = "~> 0.3.11"

  providers        = { aws = aws.prod }
  name             = "riva"
  stack            = "dev"
  trusted_role_arn = [module.opencloudcx.role_arn]
}
```

A companion variables file is required with the following values set. __Recommend using a separate secrets file for best practices__


`variables.auto.tfvars`
```hcl
aws_account_id     = [aws_account_id]
dockerhub_username = [dockerhub_username]
dns_zone           = [dns_zone]
state_bucket_name  = [state_bucket_name]
```

|Variable|type|description|
|---|---|---|
|`aws_account_id`|string|AWS account number for deployment|
|`dockerhub_username`|string|dockerhub username to use for `docker push` commands|
|`dns_zone`|string|DNS zone for cluster (defaults to `spinnaker.internal`)|
|`state_bucket_name`|string|Bucket to use for the terraform state|

---

`secrets.auto.tfvars`
```hcl
dockerhub_secret_name = [dockerhub_secret_name]
github_access_token   = [github_access_token]
```

|Variable|type|description|
|---|---|---|
|`dockerhub_secret_name`|string|Secret name to identify dockerhub secret for Kaniko push|
|`github_access_token`|string|Access toke for github account. Used for repository clones|


<br />
<br />

## Run Terraform

If multiple installation of Terraform are present, ensure Terraform `0.14.2` is the one executing the init and apply.

```
terraform init
terraform apply --auto-approve
```

If there are multiple AWS profiles availble for use, the Terraform commands can be prefixed 
```
AWS_PROFILE=<profile name> terraform init
AWS_PROFILE=<profile name> terraform apply --auto-approve
```

Output
```bash
Apply complete! Resources: 105 added, 0 changed, 0 destroyed.

Outputs:

artifact_write_policy_arn = "arn:aws:iam::725653950044:policy/artifact-dev-module-test-eayq-write"
eks_endpoint = "https://8F31999DFB16EE0842BEB35967271631.sk1.us-east-1.eks.amazonaws.com"
ingress_hostname = "aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com"
kubeconfig = <<EOT
bash -e ../../terraform-aws-opencloudcx/script/update-kubeconfig.sh -r us-east-1 -n riva-dev-module-test-eayq

EOT
spinnaker_managed_role_arn = "arn:aws:iam::725653950044:role/riva-dev-mkpsq-spinnaker-managed"
spinnaker_role_arn = "arn:aws:iam::725653950044:role/riva-dev-module-test-eayq"
```
---

## Validate installation
```bash
aws eks list-clusters --profile PROFILE_NAME --region us-east-1 | jq -r ".clusters[0]"
```

Output
```bash
riva-dev-module-test-eayq
```

Update kubectl configuration with new cluster information
```
aws eks --region us-east-1 update-kubeconfig --name "EKS-CLUSTER-NAME" --profile PROFILE_NAME
kubectl get pods --all-namespaces
```

## Get information about ingress controller
```bash
kubectl get ingress --A
```

Output
```bash
NAMESPACE        NAME                    CLASS    HOSTS                                                                     ADDRESS                                                                   PORTS   AGE
anchore-engine   anchore                 <none>   anchore.riva-cicd-0044.local                                              aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      103m
jenkins          jenkins                 <none>   aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      103m
jenkins          jenkins-reverse-proxy   <none>   jenkins.riva-cicd-0044.local                                              aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      103m
opencloudcx      grafana                 <none>   grafana.riva-cicd-0044.local                                              aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      104m
portainer        portainer               <none>   portainer.riva-cicd-0044.local                                            aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      104m
sonarqube        sonarqube               <none>   sonarqube.riva-cicd-0044.local                                            aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      102m
spinnaker        spinnaker               <none>   spinnaker.riva-cicd-0044.local                                            aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      100m
spinnaker        spinnaker-gate          <none>   spinnaker-gate.riva-cicd-0044.local                                       aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com   80      100m

```

---
---


# Phase II -- Manual Environment Configuration 

## Get IP Address of ingress controller
```bash
nslookup aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com
```

Output 
```bash
Non-authoritative answer:
Name:	aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com
Address: 34.196.156.6
Name:	aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com
Address: 184.73.159.142
```
## Update local `/etc/hosts` file
```bash
sudo vi /etc/hosts
```
Add the following entries using the IP address from the `nslookup` command

```bash
34.196.156.6	riva-cicd-0044.local
34.196.156.6	jenkins.riva-cicd-0044.local
34.196.156.6	sonarqube.riva-cicd-0044.local
34.196.156.6	spinnaker.riva-cicd-0044.local
34.196.156.6	anchore.riva-cicd-0044.local
34.196.156.6	grafana.riva-cicd-0044.local
34.196.156.6	portainer.riva-cicd-0044.local
34.196.156.6	spinnaker-gate.riva-cicd-0044.local
```

Test `http://portainer.riva-cicd-0044.local` to ensure everything has worked

## Get Jenkins admin token and add it to AWS CodeBuild environment configuration

1.  Retrieve Jenkins password
```bash
kubectl get secret --namespace jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode;echo
```
2. Log into Jenkins at the load balancer address from above with username: admin and the password from the previous step
1. Navigate to User Credentials by selecting `Manage Jenkins` --> `Manage Users` --> `admin` --> `configure` --> `Add New Token`
1. Copy the token after generation
1. Log into the AWS Console with account access to AWS CodeBuild
1. Select CodeBuild from the Services drop down
1. Select the build project labled `ocxbootstrap-eayq`
1. Click on the `Edit` menu and select `Environment`
1. Expand `Additional configuration`
1. Scroll down to `Environment Variables`
1. Click on `Add environment variable`
1. Enter `JENKINS_API_TOKEN` in the Name field
1. Enter the API token generated in previous steps
1. Click on `Update environment`

## Update EKS to allow AWS CodeBuild role to execute
```bash
kubectl edit -n kube-system configmap/aws-auth
```
Add the following information
```
    - rolearn: arn:aws:iam::725653950044:role/eayq-ocxbootstrap-codebuild-kubectl-role
      username: build
      groups:
        - system:masters
```

Final file should look like

```bash
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  mapRoles: |
    - rolearn: arn:aws:iam::725653950044:role/eayq-ocxbootstrap-codebuild-kubectl-role
      username: build
      groups:
        - system:masters
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::725653950044:role/riva-dev-module-test-eayq
      username: system:node:{{EC2PrivateDNSName}}
kind: ConfigMap
metadata:
  creationTimestamp: "TIMESTAMP"
  name: aws-auth
  namespace: kube-system
  resourceVersion: "VERSION"
  uid: [UUID]]

```
---
---
# Phase III -- Jenkins and OpenCloudCX Configuration

1.  From the AWS console, execute the CodeBuild project by selecting `Start Build` in the upper right hand corner
1. Check Jenkins to see if the build jobs are defined in the dashboard
1. Check OpenCloudCX to see if the jenkins configuration is present
```bash
kubectl exec -it -n spinnaker spinnaker-spinnaker-halyard-0 -- bash -c "hal config ci jenkins"
```

Output
```bash
+ Get current deployment
  Success
+ Get jenkins ci
  Success
Validation in default:
- WARNING Version "1.19.12" was patched by "1.19.14". Please
  upgrade when possible.
? https://www.spinnaker.io/community/releases/versions/

Validation in halconfig:
- WARNING There is a newer version of Halyard available (1.44.1),
  please update when possible
? Run 'sudo apt-get update && sudo apt-get install
  spinnaker-halyard -y' to upgrade

+ Configured jenkins ci: 
{"enabled":true,"masters":[{"name":"k8s-jenkins","permissions":{},"address":"http://aacf594b7347c40239c4d14810a1c70c-1569543887.us-east-1.elb.amazonaws.com","username":"admin","password":"[JENKINS_ADMIN_TOKEN]"}]}
```
---
---
# Phase IV -- OpenCloudCX Pipeline Creation

## Create pipeline in OpenCloudCX

"Screenshots"

---
---
# Phase V -- Victory

## Navigate to URL for application display