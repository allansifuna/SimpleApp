# State bucket
terraform {
  backend "s3" {
    bucket       = "rewards-tfstate"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
