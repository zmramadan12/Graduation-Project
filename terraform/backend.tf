terraform {
  backend "s3" {
    bucket = "graduationprojectCICD"
    key    = "ivolve/terraform.tfstate"
    region = "ap-southeast-3"
    encrypt = true
  }
}
 
