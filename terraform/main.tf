#Backend Storage
terraform {
  backend "gcs" {
  }
}

# create secret
resource "google_secret_manager_secret" "secret_electricity_maps_token" {
  secret_id = "electricity_maps_token"
  project   = var.project_id
  replication {
    user_managed {
      replicas {
        location = "europe-west6"
      }
    }
  }
}


# create standard buckets
locals {
  standard_buckets = { for key, value in var.bucket_names : key => value if try(value.create, true) }
}

resource "google_storage_bucket" "buckets" {
  for_each 		= local.standard_buckets
  project       = var.project_id

  name     		= each.key
  location 		= try(each.value.location, "europe-west6")
  storage_class = try(each.value.storage_class, "STANDARD")
  uniform_bucket_level_access = true

  force_destroy = try(each.value.force_destroy, false)

  versioning {
    enabled = try(each.value.versioning, false)
  }
}

# create artifact repository
locals {
  # variable to define where the base resources (like sa, repo) has to be created. Only once per "projectid_without_stage"
  docker_repo = ["europe-west6"]
  python_repo = []

  # variable to define in which regions has to be created buckets
  regions_repo = setunion(local.docker_repo, local.python_repo)
  # variable to define all format-region repos
  repos = merge(
    { for region in local.docker_repo : "docker-${region}" => { format : "DOCKER", location : region, suffix : "repo" } },
    {
      for region in local.python_repo : "python-${region}" => {
        format : "PYTHON", location : region, suffix : "pyrepo"
      }
    }
  )
}

resource "google_artifact_registry_repository" "artifact_repo" {
  for_each      = local.repos
  project       = var.project_id
  location      = each.value.location
  repository_id = "${var.project_id}-repo"
  description   = "${var.project_id}-repo"
  format        = each.value.format // all other formats are alpha yet
}
