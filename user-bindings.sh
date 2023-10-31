#!/bin/bash
users=("maurice.philip94@gmail.com" "christoph.schlumpf@proton.me" "jc873@gmx.de" "johnjos1@students.zhaw.ch" "ryfnoe01@students.zhaw.ch" "stammnoa@students.zhaw.ch" "nageljay@students.zhaw.ch" "sommesi1@students.zhaw.ch" "chensve1@students.zhaw.ch")

for user in "${users[@]}"
do
  gcloud projects add-iam-policy-binding the-co2-shifter --member=user:$user --role=roles/viewer
  gcloud projects add-iam-policy-binding the-co2-shifter --member=user:$user --role=roles/run.admin
  gcloud projects add-iam-policy-binding the-co2-shifter --member=user:$user --role=roles/storage.admin
  gcloud projects add-iam-policy-binding the-co2-shifter --member=user:$user --role=roles/secretmanager.admin
  gcloud projects add-iam-policy-binding the-co2-shifter --member=user:$user --role=roles/artifactregistry.admin
  gcloud projects add-iam-policy-binding the-co2-shifter --member=user:$user --role=roles/cloudbuild.builds.builder
done
