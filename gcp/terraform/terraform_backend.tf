terraform {
  backend "gcs" {
    bucket  = "tf-state-nicks-blog"
    prefix  = "terraform/state"
  }
}