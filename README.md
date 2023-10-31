# The CO2 Shifter - infrastructure

## github

https://github.com/co2-shifters/infrastructure

Use git cli to work with github

````bash
git clone https://github.com/co2-shifters/infrastructure
````

## Google Cloud 

### Project
https://console.cloud.google.com/home/dashboard?project=the-co2-shifter

### Permissions for users

* roles/viewer
* roles/run.admin
* roles/storage.admin
* roles/secretmanager.admin
* roles/artifactregistry.admin
* roles/cloudbuild.builds.builder

## CICD
Use Terraform to deploy google cloud resources

### Plan
````bash
./scripts/tf_local.sh -c -a plan
````

### Apply
````bash
./scripts/tf_local.sh -a apply
````

