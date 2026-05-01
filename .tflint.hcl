config {
  force = false
}

plugin "google" {
  enabled = true
  version = "0.39.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Disable rules that produce warnings but don't affect the module
disable = [
  "terraform_required_providers",
  "terraform_unused_declarations",
]