# Terraform AWS SES Email Forwarder

> This does not create an SES instance for you! You must manually set up SES first.

A very quick and simple Terraform project to deploy an email forwarder ontop of your pre-existing SES instance.

## Prerequisites

- AWS Account
- AWS CLI
- Terraform
- SES

You should have some basic terraform knowledge before using this as you will need to modify the variables.tf file.

## Setup

1. Clone this repository
2. Open the variables.tf file and set the following variables:
  - from_address
    - Set this to the address that is authorised to send emails to your SES instance
  - to_address
    - Set this to the email address that you want to forward emails to
  - forwarding_filters
    - Set this to your domain or specific email addresses you wish to forward emails for
3. run `terraform init`
4. run `terraform apply`
5. Go into your DNS and set up an MX record for your domain to point to the MX record provided in the output of the terraform apply command (it should look like `MX inbound-smtp.us-east-1.amazonaws.com. 10`)

And your good to go!

## License

This project is mainly licensed under the Apache License 2.0. See the LICENSE file for more details.

For the lambda function, the code is licensed under the MIT License as the code *very* loosly is based off of [VeeraChunduri/aws-lambda-ses-forwarder-1](https://github.com/VeeraChunduri/aws-lambda-ses-forwarder-1). (I read it for an idea on how to do this)