current_dir = $(shell pwd)
# Wallet Service Measurement a8c17ed1b747c6d978370182b4ab007ff03f5e7c28b6af649acf34329894e58b
SECRET='{"environment": {}, "files": {"/dev/attestation/keys/data":"c1ydwRokay1R4xZ3mPwd1w==","/dev/attestation/keys/logs":"nKz4dRYLWQBhkW9bzs6HQw=="}, "argv": []}'
quick-start:
	make add-helm-repos
	make dependencies ip=$(ip) load_balancer=$(load_balancer)
add-helm-repos:
	helm repo add projectcalico https://docs.tigera.io/calico/charts
	helm repo add metallb https://metallb.github.io/metallb
	helm repo add istio https://istio-release.storage.googleapis.com/charts
	helm repo add jetstack https://charts.jetstack.io
dependencies:
	helm install calico projectcalico/tigera-operator --version v3.25.1 --namespace tigera-operator --create-namespace --wait
	@if [ "$(load_balancer)" = "true" ]; then helm install metallb metallb/metallb  --version v0.13.10 -n metallb-system --create-namespace --wait && sed -i 's/IPPLACEHOLDER/$(ip)/g' ./elonwallet/config/ip_pool.yaml &&  kubectl apply -f ./elonwallet/config/ip_pool.yaml; fi
	helm install istio-base istio/base --version 1.18.0 -n istio-system --create-namespace
	helm install istiod istio/istiod --version 1.18.0  -n istio-system --set meshConfig.ingressService=istio-ingress --set meshConfig.ingressSelector=ingress --wait
	helm install istio-ingress istio/gateway --version 1.18.0  -n istio-system --create-namespace --wait
configure-vault:
	vault plugin register -sha256="f4a2ad37c5177baaaf8559a80a2edca3e158c1b9161e1274e7289e6628d1745e" auth vault-plugin-auth-sgx
	vault auth enable -path=sgx-auth vault-plugin-auth-sgx
	vault secrets enable pki
	vault secrets tune --max-lease-ttl=87600h pki
	vault write -field=certificate pki/root/generate/internal issuing_certificates="https://vault.$(domain)/v1/pki/crl" crl_distribution=_points="https://vault.$(domain)/v1/pki/crl"
	vault secrets enable -path=sgx-pki pki  
	vault secrets tune --max-lease-ttl=87600h sgx-pki
	vault write -format=json sgx-pki/intermediate/generate/internal common_name="$(domain) Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr 
	mkdir -p ./sgx-deployments/certs
	vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > ./sgx-deployments/certs/intermediate.cert.pem 
	vault write sgx-pki/intermediate/set-signed certificate=@./sgx-deployments/certs/intermediate.cert.pem
	vault write sgx-pki/roles/vault-$(domain) allowed_domains="$(domain)" allow_subdomains=true max_ttl="720h" 
	vault secrets enable -path=sgx-app kv-v2 
wallet-service:
	make add-enclave name=wallet-service-sgx domain=$(domain) measurement=d7a56875ce096be3424c2f868c1d084feb13d54b9b4fc89487e15dfce782fcc1
add-enclave:
	bash -c "vault policy write sgx-app/"$(name)" - < <(env -i NAME="$(name)" envsubst < ./elonwallet/config/vault.sgx.policy.template)"
	vault kv put -format=json -mount=sgx-app "$(name)" provision=$(SECRET)
	vault write -format=json auth/sgx-auth/enclave/$(name) mrenclave="$(measurement)"
	vault write -format=json sgx-pki/roles/$(name) allowed_domains="default.$(domain)" allow_subdomains=true allow_localhost=true ttl=8760h key_type="ec" key_bits="256"
build:
	docker build -t $(account)/elonwallet-backend-sgx --build-arg manifestPath=backend --build-arg path=backend/backend ./sgx-deployments
	docker build -t $(account)/elonwallet-frontend-sgx -f ./sgx-deployments/frontend.Dockerfile --build-arg manifestPath=frontend --build-arg path=frontend/frontend/elonwallet.io ./sgx-deployments
	docker build -t $(account)/elonwallet-deployer-sgx --build-arg manifestPath=deployer --build-arg path=deployer/Knative-Client/deployer ./sgx-deployments
	docker build -t $(account)/elonwallet-wallet-service-sgx --build-arg manifestPath=wallet-service --build-arg path=wallet-service/function ./sgx-deployments
	docker push $(account)/elonwallet-backend-sgx
	docker push $(account)/elonwallet-frontend-sgx
	docker push $(account)/elonwallet-deployer-sgx
	docker push $(account)/elonwallet-wallet-service-sgx
	
