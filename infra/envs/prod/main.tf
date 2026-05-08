module "static_site" {
  source       = "../../modules/static-site"
  project_name = var.project_name
  environment  = var.environment
}

module "visitor_counter" {
  source             = "../../modules/visitor-counter"
  project_name       = var.project_name
  environment        = var.environment
  cors_allow_origins = module.static_site.website_url
}
