#!/bin/bash

# 设置资源名称和资源组名称
myResourceName="azureopenai-test-mine-uksouth"
myResourceGroupName="openai"

# 获取所有部署的名称列表
deployments=$(az cognitiveservices account deployment list --name $myResourceName --resource-group $myResourceGroupName | jq -r '.[].name')

# 遍历部署名称并删除每个部署
for deployment in $deployments
do
    echo "Deleting deployment $deployment..."
    az cognitiveservices account deployment delete --name $myResourceName --resource-group $myResourceGroupName --deployment-name $deployment
    echo "Deleted deployment $deployment"
done

echo "All deployments have been deleted."
