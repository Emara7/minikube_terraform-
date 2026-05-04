APP_IMAGE ?= cloud-native-demo:dev
HELM_RELEASE ?= cloud-native-demo
NAMESPACE ?= cloud-native-demo

.PHONY: image helm-template helm-install argocd-app dashboard failure-errors failure-cpu

image:
	docker build -t $(APP_IMAGE) app

helm-template:
	helm template $(HELM_RELEASE) helm/cloud-native-demo -f helm/cloud-native-demo/values-dev.yaml

helm-install:
	helm upgrade --install $(HELM_RELEASE) helm/cloud-native-demo -n $(NAMESPACE) --create-namespace -f helm/cloud-native-demo/values-dev.yaml

argocd-app:
	kubectl apply -f argocd/application.yaml

dashboard:
	kubectl apply -f observability/dashboard-configmap.yaml

failure-errors:
	helm upgrade --install $(HELM_RELEASE) helm/cloud-native-demo -n $(NAMESPACE) -f helm/cloud-native-demo/values-dev.yaml -f scenarios/failure/high-error-latency-values.yaml

failure-cpu:
	kubectl apply -f scenarios/failure/cpu-loader.yaml
