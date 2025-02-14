#  Copyright 2025 BradBot_1

#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
variable "service_prefix" {
  description = "The prefix for the service name"
  type        = string
  default     = "email-forwarder"
}

variable "upper_service_prefix" {
  description = "The upper case prefix for the service name"
  type        = string
  default     = "EmailForwarder"
}

variable "service_tag_value" {
  description = "The key for the tag used to identify all related resources"
  type        = string
  default     = "EmailForwarder"
}

# Do not change this
data "aws_caller_identity" "current" {}
# End of Do not change this


variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  validation {
    condition = contains(["us-east-1",
      "us-east-2",
      "us-west-1",
      "us-west-2",
      "af-south-1",
      "ap-east-1",
      "ap-south-2",
      "ap-southeast-3",
      "ap-southeast-5",
      "ap-southeast-4",
      "ap-south-1",
      "ap-northeast-3",
      "ap-northeast-2",
      "ap-southeast-1",
      "ap-southeast-2",
      "ap-southeast-7",
      "ap-northeast-1",
      "ca-central-1",
      "ca-west-1",
      "cn-north-1",
      "cn-northwest-1",
      "eu-central-1",
      "eu-west-1",
      "eu-west-2",
      "eu-south-1",
      "eu-west-3",
      "eu-south-2",
      "eu-north-1",
      "eu-central-2",
      "il-central-1",
      "mx-central-1",
      "me-south-1",
      "me-central-1",
      "sa-east-1"
    ], var.region)
    error_message = "You must specify a valid AWS region."
  }
  default = "us-east-1"
}

variable "from_address" {
  description = "The email address to use as the 'From' address"
  type        = string
}

variable "to_address" {
  description = "The email address to forward to"
  type        = string
}

# These are the email addresses that you will recieve emails for.
# It accepts the following formats:
#      .domain.com : Forwards all emails send to any subdomains of domain.com
#       domain.com : Forwards all emails send to any email addresses ending in domain.com
# example@demo.com : Forwards all emails send to example@demo.com
# Usually you just want ".domain.com" AND "domain.com" (where the domain is your own)
variable "forwarding_filters" {
  description = "A list of email addresses to recieve emails for and forward."
  type        = list(string)
  validation {
    condition     = length(var.forwarding_filters) > 0
    error_message = "You must specify at least one email address to forward for."
  }
}
