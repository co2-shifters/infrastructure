#!/bin/bash

project_id=the-co2-shifter

date && gcloud --project=$project_id builds submit --gcs-source-staging-dir=gs://$project_id-bz/stagingdir

echo "link to artifacts repo: https://console.cloud.google.com/artifacts/docker/$project_id/europe-west6/$project_id-repo" --async

# --impersonate-service-account=si-$projnostage@axach-inetbuildingzone-ibz.iam.gserviceaccount.com \