config {
  force = false
}

plugin "google" {
  enabled = true
  version = "0.39.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Disable rules for pre-existing issues (not related to this PR)
disable = [
  "terraform_required_providers",
  "terraform_unused_declarations",
]