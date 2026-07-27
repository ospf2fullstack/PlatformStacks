# LiteLLM Terraform Module (AWS)
# Deploys LiteLLM on ECS Fargate with Aurora PostgreSQL and ElastiCache Redis
#
# Usage:
#   module "litellm" {
#     source = "./terraform"
#     ...
#   }

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "tenant" {
  description = "Tenant name for resource naming"
  type        = string
}

variable "env" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "litellm_version" {
  description = "LiteLLM container image tag"
  type        = string
  default     = "main-v1.93.0"
}

variable "openai_api_key_arn" {
  description = "ARN of the OpenAI API key in Secrets Manager"
  type        = string
}

variable "anthropic_api_key_arn" {
  description = "ARN of the Anthropic API key in Secrets Manager"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for TLS"
  type        = string
}

# Alternatively, use the official Terraform module:
#
# module "litellm" {
#   source  = "BerriAI/litellm/aws"
#   version = "~> 1.93"
#
#   region = var.region
#   azs    = var.azs
#   tenant = var.tenant
#   env    = var.env
#
#   acm_certificate_arn = var.acm_certificate_arn
#
#   proxy_config = {
#     model_list = [
#       {
#         model_name = "gpt-4o"
#         litellm_params = {
#           model   = "openai/gpt-4o"
#           api_key = "os.environ/OPENAI_API_KEY"
#         }
#       }
#     ]
#   }
#
#   gateway_extra_secrets = {
#     OPENAI_API_KEY    = var.openai_api_key_arn
#     ANTHROPIC_API_KEY = var.anthropic_api_key_arn
#   }
# }

output "note" {
  value = "Use the official BerriAI/litellm/aws Terraform module for production. This file documents the required variables and patterns."
}
