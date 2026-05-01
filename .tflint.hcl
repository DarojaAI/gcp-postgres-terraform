config {
  force = false
}

plugin "google" {
  enabled = true
  version = "0.39.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

rule "google_required_attribute" {
  enabled = true
}

rule "google_invalid_argument" {
  enabled = true
}

rule "google_undefined_argument" {
  enabled = true
}

rule "google_unexpected_large_diff" {
  enabled = true
}