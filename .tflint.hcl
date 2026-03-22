config {
  module = true
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "hetznercloud" {
  enabled = true
  version = "0.7.1"
  source  = "github.com/terraform-linters/tflint-ruleset-hcloud"
}
