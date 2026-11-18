kubectl create namespace development

kubectl apply -f ./roles/cluster-pod-reader.yaml
kubectl apply -f ./roles/department-maintainer.yaml
kubectl apply -f ./roles/infrastructure-operator.yaml
kubectl apply -f ./roles/secret-reader.yaml
