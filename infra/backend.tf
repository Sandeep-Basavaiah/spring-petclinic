terraform {
    backend "s3" {
        key = "terraform/tfstate.tfstate"
        bucket = "ps-tf-remote-backend"
        region = "us-east-1"
    }
}