
# Infrastructure-Upgrade

This repository contains Terraform code to provision a two-tier application on AWS using ECS Fargate. The infrastructure is designed to be scalable, secure, and highly available.

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

1.  **Clone the repository:**

    ```sh
    git clone <repository-url>
    cd Infrastructure-Upgrade
    ```

2.  **Configure the backend:**

    Update the `backend.tf` file with the names of your S3 bucket and DynamoDB table.

3.  **Initialize Terraform:**

    ```sh
    terraform init
    ```

4.  **Review the plan:**

    ```sh
    terraform plan
    ```

5.  **Apply the changes:**

    ```sh
    terraform apply
    ```

## Modules

### networking

This module creates the networking resources for the application.

#### Inputs

| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| prefix | The prefix to use for all resources. | `string` | n/a |
| vpc_cidr_block | The CIDR block for the VPC. | `string` | `10.0.0.0/16` |
| public_subnet_cidr_blocks | The CIDR blocks for the public subnets. | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` |
| availability_zones | The availability zones to use for the subnets. | `list(string)` | `["us-east-1a", "us-east-1b"]` |
| container_port | The port the container listens on. | `number` | `80` |

#### Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC. |
| public_subnet_ids | The IDs of the public subnets. |
| alb_security_group_id | The ID of the ALB security group. |
| fargate_security_group_id | The ID of the Fargate security group. |

### ecs_cluster

This module creates the ECS cluster and IAM roles.

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

## Root Variables and Outputs

### Inputs

| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| aws_region | The AWS region to deploy resources in. | `string` | `us-east-1` |
| ui_container_image | The UI container image to deploy (e.g., from ECR). | `string` | `nginx:1.27.0` |
| api_container_image | The API container image to deploy (e.g., from ECR). | `string` | `123456789012.dkr.ecr.us-east-1.amazonaws.com/my-api:latest` |
| domain_name | The root domain name for your application (e.g., example.com). | `string` | `customdonations.com` |
| ui_subdomain | The subdomain for the UI service (e.g., upgrade-ui). | `string` | `upgrade-ui` |
| api_subdomain | The subdomain for the API service (e.g., upgrade-api). | `string` | `upgrade-api` |

### Outputs

| Name | Description |
|------|-------------|
| ui_load_balancer_dns | The DNS name of the UI Load Balancer. Use this for your CNAME record. |
| api_load_balancer_dns | The DNS name of the API Load Balancer. Use this for your CNAME record. |
