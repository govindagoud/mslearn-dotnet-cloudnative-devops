!#/bin/bash


export LOCATION=eastus
export RESOURCE_GROUP=rg-eshop
export CLUSTER_NAME=aks-eshop
export ACR_NAME=acseshop$SRANDOM 

# create RG and ACR then login to ACR
az group create --name $RESOURCE_GROUP --location $LOCATION
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic
az acr login --name $ACR_NAME

#To tag your images and push them to the ACR you just created, run these commands:
docker tag storeimage $ACR_NAME.azurecr.io/storeimage:v1
docker tag productservice $ACR_NAME.azurecr.io/productservice:v1

docker push $ACR_NAME.azurecr.io/storeimage:v1
docker push $ACR_NAME.azurecr.io/productservice:v1

#list repos in acr
az acr repository list --name $ACR_NAME --output table

#Create your AKS and connect it to the ACR with these commands:
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 1 --generate-ssh-keys --node-vm-size Standard_B2s --network-plugin azure --attach-acr $ACR_NAME
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP

#Check that the new AKS can pull images from the ACR with this command:
az aks check-acr --acr $ACR_NAME.azurecr.io --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP

#deploy an NGINX ingress controller with this command:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.3/deploy/static/provider/cloud/deploy.yaml

# replace your acr name and deploy apps
kubectl apply -f deployment.yml

#View the deployed eShop with this comman
echo "http://$(kubectl get services --namespace ingress-nginx ingress-nginx-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}')"


#Create a service principal to deploy from GitHub

export SUBS=$(az account show --query 'id' --output tsv)

#create an Azure AD service principal to allow access from GitHub:
az ad sp create-for-rbac --name "eShop" --role contributor --scopes /subscriptions/$SUBS/resourceGroups/$RESOURCE_GROUP --json-auth


#rollback deployment
kubectl rollout undo deployment/productservice