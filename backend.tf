terraform {
  backend "gcs" {
    bucket  = "ott-terraform-state-bucket"
    prefix  = "gke/terraform.tfstate"
  }
}
