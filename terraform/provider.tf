provider "google" {
  project     = "axach-lb-admtools-prd"
  region      = "europe-west6"
  request_timeout = "2m"
}

provider "google-beta" {
  project     = "axach-terraform-infra-prod"
  region      = "europe-west6"
  request_timeout = "2m"
}
