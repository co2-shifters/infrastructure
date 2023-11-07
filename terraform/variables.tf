##############################################################
## Variables passed from terraform init
## Do not change
##############################################################
variable "project_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "stage" {
  type = string
  default = ""
}

variable "workspace" {
  type = string
}

##############################################################
## Variables passed from User depending on Use Case
## Change the needed resources
## Details can be found on the repositories of the modules: https://github.axa.com/axach-gcp?q=tf-module&type=all&language=&sort=name
##############################################################


###CREATION OF GCP STORAGE BUCKETS###
variable "bucket_names" {
  description = "Create Buckets"
  type        = any
  default     = {
    # "the-co2-shifter-tfstate" = {} manuell erstellt, da bucket vorhanden sein muss für terraform
    "the-co2-shifter-bz"      = {}
  }
}

###CREATION OF SQL INSTANCES AND DATABASES###
variable "sql_instances" {
  description = "Cloud SQL Instance names"
  type        = any
  default     = {
    // if no instance needed let empty {}
  }
}

variable "sql_db_names" {
  description = "Cloud SQL Databse names"
  type        = any
  default     = {
    // if no database needed let empty {}
  }
}

###CREATION OF A CLOUD RUN SERVICE###
#Documentation: Instances declares a one-hour maintenance window when an Instance can automatically
#restart to apply updates. The maintenance window is specified in UTC time.
#To be able to create and use images you need the foundation feature "basis_ibz"
#Details about the module: https://github.axa.com/axach-gcp/tf-module-cloudrun

variable "cr_names" {
  description = "Creates Cloud Run Services"
  type        = any
  default     = {
    // if no cr needed let empty {}
    "cr-electricity-maps" = {
      image         = "europe-west6-docker.pkg.dev/the-co2-shifter/the-co2-shifter-repo/electricity-maps:latest"
      cpu           = "1" // 1, 2, 4 , CPUs to allocate to service instances.
      memory        = "2048" // one of 128, 256, 512, 1024, 2048, 4096, 8192
      concurrency   = "1" // Maximum number of requests a single service instance can handle at once.
      timeout       = "3600" // Length of time (in seconds) to allow requests to run for.
      max_instances = "2" // Maximum number of service instances to allow to start.
      min_instances = "0" // Minimum number of service instances to keep running.
    }
    "cr-co2-shifter-frontend" = {
      image         = "europe-west6-docker.pkg.dev/the-co2-shifter/the-co2-shifter-repo/co2-shifter-frontend:latest"
      cpu           = "1" // 1, 2, 4 , CPUs to allocate to service instances.
      memory        = "2048" // one of 128, 256, 512, 1024, 2048, 4096, 8192
      // trigger = "pubsub" // remove attribute if cloud run is triggered by http. With pubsub a Topic and subscription will be created to use with Scheduler
      concurrency   = "1" // Maximum number of requests a single service instance can handle at once.
      timeout       = "3600" // Length of time (in seconds) to allow requests to run for.
      // cloudsql_connections = ["postgres-eforms-data"] // Cloud SQL connections to attach to service instances.
      max_instances = "1" // Maximum number of service instances to allow to start.
      min_instances = "0" // Minimum number of service instances to keep running.
    }
  }
}
