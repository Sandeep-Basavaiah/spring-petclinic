terraform{
    backend "s3" {
        bucket = "ps-tf-remote-backend"
        encrypt = true
        key = "pipeline/infra/terraform.tfstate"
        region = "us-east-1"
    }
}

provider "aws" {
    region = "us-east-1"
}