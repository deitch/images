terraform {
  required_providers {
    apko = { source = "chainguard-dev/apko" }
  }
}

variable "target_repository" {
  description = "The docker repo into which the image and attestations should be published."
}

variable "extra_repositories" {
  type    = list(string)
  default = []
}

variable "extra_keyring" {
  type    = list(string)
  default = []
}

variable "extra_packages" {
  type    = list(string)
  default = []
}

variable "archs" {
  type    = list(string)
  default = []
}

provider "apko" {
  extra_repositories = concat(["https://packages.wolfi.dev/os"], var.extra_repositories)
  extra_keyring      = concat(["https://packages.wolfi.dev/os/wolfi-signing.rsa.pub"], var.extra_keyring)
  extra_packages     = concat(["wolfi-baselayout"], var.extra_packages)
  default_archs      = length(var.archs) == 0 ? ["x86_64", "aarch64"] : var.archs
  default_annotations = {
    "org.opencontainers.image.authors" : "Chainguard Team https://www.chainguard.dev/",
  }
}

provider "apko" {
  alias = "alpine"

  extra_repositories = ["https://dl-cdn.alpinelinux.org/alpine/edge/main"]
  # These packages match chainguard-images/static
  extra_packages = ["alpine-baselayout-data", "alpine-release", "ca-certificates-bundle"]
  default_archs  = var.archs # defaults to all
  default_annotations = {
    "org.opencontainers.image.authors" : "Chainguard Team https://www.chainguard.dev/",
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

locals {
  use_alpine = ["git", "busybox", "static"]
  dirs = distinct([for _, v in fileset(path.module, "images/*/*") : dirname(v)])
  wolfi_dirs = [for d in local.dirs : d if !contains(local.use_alpine, basename(d))]
  alpine_dirs = [for d in local.dirs : d if contains(local.use_alpine, basename(d))]
}



module "wolfi_image" {
  source            = "./tflib/image"
  for_each          = toset(local.wolfi_dirs)
  target_repository = "${var.target_repository}/${each.key}"
  sourcedir         = "./${each.value}"
}

module "alpine_image" {
  source            = "./tflib/image"
  for_each          = toset(local.alpine_dirs)
  target_repository = "${var.target_repository}/${each.key}"
  sourcedir         = "./${each.value}"
  providers = {
    apko = apko.alpine
  }
}

output "wolfi_images" {
  value = toset([
    for image in module.wolfi_image : image.configs
  ])
}

output "alpine_images" {
  value = toset([
    for image in module.alpine_image : image.configs
  ])
}

output "source_directories" {
  value = [
    for f in local.dirs : f
  ]
}