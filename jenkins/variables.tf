variable "kubectl_version" {
  type    = string
  default = "1.22.1"
}

variable "jenkins_username" {
  type    = string
  default = "admin"
}

variable "jenkins_secret" {
  type = string
}

variable "jenkins_url" {
  type = string
}
