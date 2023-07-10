locals {
  configs = fileset("./", "${var.sourcedir}/configs/*.yaml")
}

module "publisher" {
  source = "../publisher"
  for_each = local.configs

  target_repository = var.target_repository
  config            = file(each.key)
}

module "version-tags" {
  source  = "../version-tags"
  for_each = module.publisher

  package = "apko"
  config  = each.value.config
}
