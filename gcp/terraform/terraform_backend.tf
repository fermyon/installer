terraform {
  backend "gcs" {
    bucket  = "tf-state-nicks-blog-2"
    prefix  = "terraform/state"
  }
}