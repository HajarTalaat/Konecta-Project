terraform {
  backend "s3" {
    bucket         = "devops-grad-tf-state"         # Replace with your actual bucket name
    key            = "terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
  }
}
