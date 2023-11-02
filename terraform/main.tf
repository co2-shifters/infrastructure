#Backend Storage
terraform {
  backend "gcs" {
  }
}

# enable services
resource "google_project_service" "project" {
  for_each = toset([
    "artifactregistry",
    "cloudresourcemanager", # manuell aktiviert
    "storage",
    "cloudbuild",
    "secretmanager",
    "run"
  ])
  project = var.project_id
  service = "${each.key}.googleapis.com"

  disable_dependent_services = true
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
  depends_on = [
    google_project_service.project
  ]
}

resource "google_project_iam_member" "cr_secret_access" {
  project = var.project_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:981307717818-compute@developer.gserviceaccount.com"

  depends_on = [
    google_project_service.project
  ]
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
  depends_on = [
    google_project_service.project
  ]
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

  depends_on = [
    google_project_service.project
  ]
}

# cloud run services
locals {
  # all cloud runs
  cr_names    = {for key, value in var.cr_names : key => value}
}

data "external" "artifact_registry_image" {
  for_each = local.cr_names
  program  = [
    "bash", "-c", <<-EOT
location=`echo ${replace(element(split("/", each.value.image), 0), "-docker.pkg.dev", "")}`;
repo=`echo ${element(split("/", each.value.image), 2)}`;
get_tag=`echo ${try(element(split(":", each.value.image), length(split(":", each.value.image))-1), "")}`;
package=`echo ${element(split(":", join("/", slice(split("/", each.value.image), 3, length(split("/", each.value.image))))), 0)} | sed 's/\//\%2F/g'`;
call=`echo "https://artifactregistry.googleapis.com/v1beta2/projects/${var.project_id}/locations/$location/repositories/$repo/packages/$package/tags/$get_tag"`;
curl --max-time 30 -s -X GET -H "Authorization: Bearer $TF_VAR_sa_secret_id" -H "Content-Type:application/json" "$call";
EOT
  ]
  depends_on = [
    google_project_service.project
  ]
}

#resource "terraform_data" "images" {
#  for_each = local.cr_names
#  triggers_replace = [
#    data.external.artifact_registry_image[each.key]["result"]
#  ]
#}

resource "google_cloud_run_service" "default" {
  for_each = local.cr_names
  project  = var.project_id
  name     = try(each.value.name, each.key)
  location = try(each.value.region, "europe-west6")
  metadata {
    annotations = {
      "run.googleapis.com/launch-stage" : try(each.value.launch_stage, null)
    }
    labels = try(each.value.labels, {})
  }
  template {
    spec {
      container_concurrency = try(each.value.concurrency, "1")
      timeout_seconds       = try(each.value.timeout, "60")
      dynamic "volumes" {
        for_each = try(each.value.secret_mounts, {})
        content {
          name = volumes.key
          secret {
            secret_name = volumes.key
            items {
              key  = "latest"
              path = volumes.value.file_name
              mode = 256  # 0400 (=readable by the owner)
            }
          }
        }
      }
      containers {
        image = replace("${element(split(":", try(each.value.image[var.stage], each.value.image)), 0)}@${element(split("/versions/", data.external.artifact_registry_image[each.key]["result"]["version"]), length(split("/versions/", data.external.artifact_registry_image[each.key]["result"]["version"]))-1)}", element(split("/", try(each.value.image[var.stage], each.value.image)), 2), try(each.value.repo_staged, false) ? "${element(split("/", try(each.value.image[var.stage], each.value.image)), 2)}-${var.stage}" : element(split("/", try(each.value.image[var.stage], each.value.image)), 2))
        ports {
          container_port = try(each.value.port, 8080)
        }
        dynamic "volume_mounts" {
          for_each = try(each.value.secret_mounts, {})
          content {
            name       = volume_mounts.key
            mount_path = volume_mounts.value.mount_path
          }
        }
        dynamic "env" {
          for_each = try(each.value.envs, {})
          content {
            name  = env.key
            value = env.value
          }
        }
        dynamic "env" {
          for_each = try(each.value.secrets, {})
          content {
            name = env.key
            value_from {
              secret_key_ref {
                name = env.value
                key  = "latest"
              }
            }
          }
        }
        resources {
          limits = {
            cpu    = "${try(each.value.cpu[var.stage] * 1000, each.value.cpu * 1000)}m"
            memory = "${try(each.value.memory[var.stage], each.value.memory)}Mi"
          }
        }
      }
      #service_account_name = try("${each.value.service_account_name}@${var.project_id}.iam.gserviceaccount.com", "service-account-no-admin@${var.project_id}.iam.gserviceaccount.com")
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"                   = try(each.value.max_instances[var.stage], try(each.value.max_instances, "1"))
        "autoscaling.knative.dev/minScale"                   = try(each.value.min_instances[var.stage], try(each.value.min_instances, "0"))
        "run.googleapis.com/execution-environment"           = try(each.value.exec_env, null)
      }
    }
  }
  autogenerate_revision_name = true
  traffic {
    percent         = try(each.value.traffic["percent"], 100)
    latest_revision = try(each.value.traffic["latest_revision"], true)
  }
  lifecycle {
    ignore_changes = [
      # https://github.com/GoogleCloudPlatform/magic-modules/pull/7938
      metadata[0].annotations["run.googleapis.com/operation-id"],
      template[0].metadata[0].labels["run.googleapis.com/startupProbeType"],
    ]
  }
}
data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}
resource "google_cloud_run_service_iam_policy" "noauth" {
  for_each    = local.cr_names
  location    = google_cloud_run_service.default[each.key].location
  project     = google_cloud_run_service.default[each.key].project
  service     = google_cloud_run_service.default[each.key].name
  policy_data = data.google_iam_policy.noauth.policy_data
  depends_on  = [google_cloud_run_service.default]
}

