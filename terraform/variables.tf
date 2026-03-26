variable "aws_region" {
  description = "AWS region for the Book Review deployment."
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public web-tier subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks for the two private app-tier subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for the two private database-tier subnets."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "web_instance_type" {
  description = "EC2 instance type for the frontend web tier."
  type        = string
  default     = "t3.small"
}

variable "app_instance_type" {
  description = "EC2 instance type for the backend app tier."
  type        = string
  default     = "t3.micro"
}

variable "web_desired_capacity" {
  description = "Desired number of frontend instances."
  type        = number
  default     = 2
}

variable "app_desired_capacity" {
  description = "Desired number of backend instances."
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "Instance class for the RDS MySQL primary and replica."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name for the Book Review app."
  type        = string
  default     = "book_review_db"
}

variable "db_username" {
  description = "Master username for the RDS MySQL instance."
  type        = string
  default     = "bookreviewadmin"
}

variable "db_password" {
  description = "Master password for the RDS MySQL instance."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret for the backend app."
  type        = string
  sensitive   = true
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the public web-tier instances for administration."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "repo_url" {
  description = "Git repository URL for the Book Review application."
  type        = string
  default     = "https://github.com/pravinmishraaws/book-review-app.git"
}

variable "generated_key_name" {
  description = "Name for the Terraform-generated EC2 key pair."
  type        = string
  default     = "bookreview-web-key"
}

variable "private_key_filename" {
  description = "Local filename for the generated PEM key."
  type        = string
  default     = "bookreview-web-key.pem"
}