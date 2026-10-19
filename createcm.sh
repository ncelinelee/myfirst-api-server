#!/bin/bash

USER_NAME=${STUDENT_NUM}

kubectl create configmap ${USER_NAME}-backend-configmap \
  --from-file=application-prod.yaml \
  --namespace=skala-practice

