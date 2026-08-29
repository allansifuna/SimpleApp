variable "instances" {
  description = "App servers, keyed by a short identifier — add/override entries to scale"
  type = map(object({
    instance_type = optional(string, "t3.micro")
    volume_size   = optional(number, 12)
  }))
  default = {
    "1" = {}
  }
}

variable "github_repo" {
  type = string
}

variable "ssh_public_key" {
  description = "Public half of a keypair you generate by hand: ssh-keygen -t ed25519 -f rewards_server_deploy_key -N \"\""
  type        = string
}
