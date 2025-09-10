
# Infrastructure-Upgrade

This repository contains Terraform code to provision a scalable, secure, and highly available infrastructure for a microservices-based application on AWS using ECS Fargate.

## Architecture

The infrastructure consists of the following components:

*   **VPC:** A custom VPC with public subnets, an internet gateway, and route tables.
*   **ECS Cluster:** An ECS cluster to manage the application containers.
*   **UI Service:** An ECS service for the UI, with an Application Load Balancer and auto-scaling.
*   **API Service:** An ECS service for the API, with a separate Application Load Balancer and auto-scaling.
*   **IAM Roles:** IAM roles for ECS tasks to interact with other AWS services.
*   **Security Groups:** Security groups to control traffic between the different components.
*   **CloudWatch Logs:** Centralized logging for the ECS services.

## Project Structure

The Terraform code is organized into the following modules:

*   `networking`: Creates the VPC, subnets, and security groups.
*   `ecs_cluster`: Creates the ECS cluster and IAM roles.
*   `app_service`: A reusable module for deploying an application service (for both UI and API).

## Prerequisites

*   [Terraform](https://www.terraform.io/downloads.html) installed.
*   AWS credentials configured.
*   An S3 bucket and a DynamoDB table for the Terraform backend.

## Usage

This project is configured for continuous deployment using GitHub Actions. Any push to the `main` branch will trigger a workflow that automatically plans and applies the Terraform changes.

For manual deployments or testing, you can follow these steps:

1.  **Clone the repository:**

    ```sh
    git clone <repository-url>
    cd Infrastructure-Upgrade
    ```

2.  **Configure the backend:**

    The `backend.tf` file is pre-configured with default S3 bucket (`upgrade-terraform-state-us-east-2`) and DynamoDB table (`upgrade-terraform-state-lock`) names for Terraform state management. You may update these values if you wish to use a different backend.

3.  **Application Secret Management (AWS Secrets Manager):**

    This configuration expects an existing secret in AWS Secrets Manager named `upgrade-app-secrets`. This secret should be a JSON string containing all necessary key-value pairs (e.g., API keys, database passwords) that the application needs at runtime.

    The content of this secret will be injected into both the UI and API service containers as the environment variable `APP_SECRETS`. The `ecs_cluster` module automatically creates the necessary IAM role and policy to allow the ECS tasks to access this secret.

    *Note: These secrets are for the application itself and are different from the [CI/CD Secrets](#cicd-secrets-github-secrets) used for deployment.*

4.  **Initialize Terraform:**

    ```sh
    terraform init
    ```

5.  **Review the plan:**

    ```sh
    terraform plan
    ```

6.  **Apply the changes:**

    ```sh
    terraform apply
    ```

## CI/CD

This repository uses GitHub Actions to automate the deployment of the infrastructure. The workflow is defined in `.github/workflows/deploy.yml` and consists of two main jobs: `plan` and `apply`.

*   **Plan:** This job is triggered on every push to the `main` branch. It performs the following steps:
    *   Checks out the code.
    *   Configures AWS credentials using secrets stored in the repository.
    *   Sets up Terraform.
    *   Runs `terraform init`, `validate`, and `fmt -check`.
    *   Generates a Terraform plan and saves it as an artifact.

*   **Apply:** This job runs after the `plan` job succeeds. It performs the following steps:
    *   Downloads the Terraform plan artifact.
    *   Runs `terraform apply` with auto-approval to apply the changes to the infrastructure.

### CI/CD Secrets (GitHub Secrets)

The GitHub Actions workflow requires the following secrets to be configured in the repository's settings. These secrets are used for authenticating with AWS during the CI/CD process and are distinct from the application secrets stored in AWS Secrets Manager.

*   `AWS_ACCESS_KEY_ID`: The access key ID for an IAM user with permissions to manage the AWS resources.
*   `AWS_SECRET_ACCESS_KEY`: The secret access key for the IAM user.

These secrets are used to configure the AWS credentials in the workflow, allowing Terraform to authenticate with your AWS account.

## Modules

### networking

This module creates the networking resources for the application.

#### Inputs

| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| prefix | The prefix to use for all resources. | `string` | n/a |
| vpc_cidr_block | The CIDR block for the VPC. | `string` | `10.0.0.0/16` |
| public_subnet_cidr_blocks | The CIDR blocks for the public subnets. | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` |
| availability_zones | The availability zones to use for the subnets. | `list(string)` | `["${var.aws_region}a", "${var.aws_region}b"]` |

#### Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC. |
| public_subnet_ids | The IDs of the public subnets. |
| alb_security_group_id | The ID of the ALB security group. |
| fargate_security_group_id | The ID of the Fargate security group. |

### ecs_cluster

This module creates the ECS cluster and the necessary IAM roles for the services. It creates two roles:
*   **ECS Task Execution Role:** Grants permissions for the ECS agent to make AWS API calls on your behalf (e.g., pulling container images from ECR, writing logs to CloudWatch).
*   **ECS Task Role:** Grants permissions to the containers themselves. This role includes a policy that allows tasks to read the `upgrade-app-secrets` secret from AWS Secrets Manager.

#### Inputs

| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| prefix | The prefix to use for all resources. | `string` | n/a |
| aws_region | The AWS region. | `string` | n/a |

#### Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ID of the ECS cluster. |
| cluster_name | The name of the ECS cluster. |
| ecs_task_execution_role_arn | The ARN of the ECS task execution role. |
| ecs_task_role_arn | The ARN of the ECS task role. |

### app_service

This module is a reusable module for deploying an application service.

#### Inputs

| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| prefix | The prefix to use for all resources. | `string` | n/a |
| service_name | The name of the service (e.g., ui, api). | `string` | n/a |
| vpc_id | The ID of the VPC. | `string` | n/a |
| public_subnet_ids | The IDs of the public subnets. | `list(string)` | n/a |
| alb_security_group_id | The ID of the ALB security group. | `string` | n/a |
| fargate_security_group_id | The ID of the Fargate security group. | `string` | n/a |
| cluster_id | The ID of the ECS cluster. | `string` | n/a |
| cluster_name | The name of the ECS cluster. | `string` | n/a |
| ecs_task_execution_role_arn | The ARN of the ECS task execution role. | `string` | n/a |
| task_role_arn | The ARN of the ECS task role. | `string` | `null` |
| container_image | The container image to deploy. | `string` | n/a |
| container_port | The port the container listens on. | `number` | `80` |
| container_cpu | The CPU units to allocate to the container. | `number` | `256` |
| container_memory | The memory to allocate to the container. | `number` | `512` |
| desired_count | The desired number of tasks to run. | `number` | `1` |
| min_capacity | The minimum number of tasks for auto-scaling. | `number` | `1` |
| max_capacity | The maximum number of tasks for auto-scaling. | `number` | `4` |
| scaling_target_value | The target value for the scaling policy. | `number` | `75` |
| health_check_path | The path for the health check. | `string` | `/` |
| certificate_arn | The ARN of the ACM certificate. | `string` | n/a |
| aws_region | The AWS region to deploy resources in. | `string` | n/a |
| secrets_arn | A list of maps, each containing 'name' and 'valueFrom' for secrets. | `list(object({ name = string, valueFrom = string }))` | `[]` |

#### Outputs

| Name | Description |
|------|-------------|
| load_balancer_dns | The DNS name of the Load Balancer. |

## Root Variables and Outputs

### Inputs

| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| aws_region | The AWS region to deploy resources in. | `string` | `us-east-2` |
| ui_container_image | The UI container image to deploy (e.g., from ECR). | `string` | `nginx:1.27.0` |
| api_container_image | The API container image to deploy (e.g., from ECR). | `string` | `nginx:1.27.0` |
| domain_name | The root domain name for your application (e.g., example.com). | `string` | `customdonations.com` |
| ui_subdomain | The subdomain for the UI service (e.g., upgrade-ui). | `string` | `upgrade-ui` |
| api_subdomain | The subdomain for the API service (e.g., upgrade-api). | `string` | `upgrade-api` |

### Outputs

| Name | Description |
|------|-------------|
| ui_load_balancer_dns | The DNS name of the UI Load Balancer. Use this for your CNAME record. |
| api_load_balancer_dns | The DNS name of the API Load Balancer. Use this for your CNAME record. |
