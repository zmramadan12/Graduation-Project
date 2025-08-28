terraform {
  backend "s3" {
    bucket = "graduation-project-cicd"
    key    = "ivolve/terraform.tfstate"
    region = "ap-southeast-3"
    encrypt = true
  }
}
 
