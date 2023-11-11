#!/bin/bash

# 检查必要的命令是否存在以及它们的版本

check_command() {
    if ! command -v $1 &> /dev/null
    then
        echo "错误：需要 $1，但它不在你的环境中。"
        exit 1
    fi
}

# 检查 Azure CLI 是否安装
check_command az

# 检查 jq 是否安装
check_command jq

# 检查 curl 是否安装
check_command curl

# 用于和az交互的函数

# 定义一个名为 loginAzure 的函数，用来指导登录
loginAzure() {
    # 使用设备代码登录 Azure
    az login --use-device-code

    # 检查上一个命令的退出状态
    if [ $? -eq 0 ]; then
        echo "登录成功"
    else
        echo "登录失败，请检查你的网络连接或设备代码"
    fi
}

# 用于列出订阅id，并将其保存到 ids.tmp 文件
listSubIds() {
    az account list --query "[].id" -o tsv
}

# 创建Azure资源组，并检查是否创建成功
createResourceGroup() {
    az group create --name openai --location "$1"

    # 检查资源组创建命令的退出状态
    if [ $? -eq 0 ]; then
        echo -e "\n资源组创建成功\n"
    else
        echo "资源组创建失败，请检查你的输入或网络连接"
    fi
}

# 创建 Azure OpenAI 资源
createAzureOpenaiResource() {
    # 使用提供的参数创建 OpenAI 认知服务帐户
    az cognitiveservices account create --name "$1" --resource-group openai --location "$2" --kind OpenAI --sku s0 --subscription "$3"

    # 检查上一个命令的退出状态
    if [ $? -eq 0 ]; then
        echo "OpenAI 资源创建成功"
    else
        echo "OpenAI 资源创建失败，请检查你的输入或网络连接"
    fi
}

# 取得bearer token
getToken(){
    az account get-access-token | jq -r '.accessToken'
}

# 为模型创建部署
createDeployMent() {
    # 发送请求并同时获取响应体和状态码
    response=$(curl --location --silent --show-error --request POST 'https://management.azure.com/batch?api-version=2020-06-01' \
    --header "authorization: Bearer $1" \
    --header 'content-type: application/json' \
    --data '{
        "requests": [
            {
                "content": {
                    "properties": {
                        "model": {
                            "format": "OpenAI",
                            "name": "'"$2"'",
                            "version": "0613"
                        }
                    },
                    "sku": {
                        "name": "Standard",
                        "capacity": '"$3"'
                    }
                },
                "HttpMethod": "PUT",
                "RelativeUrl": "/subscriptions/'"$4"'/resourcegroups/openai/providers/Microsoft.CognitiveServices/accounts/'"$5"'/deployments/'"$2"'?api-version=2023-05-01"
            }
        ]
    }' --write-out "\nHTTPSTATUS:%{http_code}")

    # 提取 HTTP 状态码
    http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # 提取响应体
    response_body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')

    # 解析 JSON 并获取 response 的 httpStatusCode
    code=$(echo "$response_body" | jq -r '.responses[0].httpStatusCode')

    # 检查状态码并输出相应的消息
    if [ "$http_status" -eq 200 ]; then
        if [ "$code" -eq 201 ]; then
            echo -e "\n创建成功"
        else
            echo -e "\n创建异常，状态码是 $code $response_body"
        fi
    else
        echo "创建失败！ $response_body"
    fi
}

getApiKey(){
    az cognitiveservices account keys list --name $1 --resource-group openai | jq -r .key1
}

# 推送到oneapi

# 定义一个函数，用于执行 cURL 命令并处理响应
push35ToOne() {
    # 执行 cURL 命令并保存响应
    response=$(curl --location 'https://zh.quzhi.life/api/channel/' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer '"'$1'"'' \
    --data '{
        "name": "test",
        "type": 1,
        "key": "'"'$2'"'",
        "openai_organization": "",
        "base_url": "http://az-raw.ns-jsfr8fru.svc.cluster.local:8787/'"'$3'"'",
        "order": 0,
        "sort": 9,
        "weight": 0,
        "retryInterval": 10,
        "testRequestBody": "",
        "overFrequencyAutoDisable": true,
        "other": "",
        "model_mapping": "",
        "excluded_fields": "",
        "models": "gpt-3.5-turbo,gpt-3.5-turbo-0301,gpt-3.5-turbo-0613,gpt-3.5-turbo-16k,gpt-3.5-turbo-16k-0613,gpt-3.5-turbo-1106",
        "groups": [
            "A3.5"
        ],
        "group": "A3.5"
    }' --silent --write-out "HTTPSTATUS:%{http_code}")

    # 分离 HTTP 状态码和响应体
    http_status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')

    # 检查 HTTP 状态码
    if [ "$http_status" -eq 200 ]; then
        # 解析 JSON 并检查 'success'
        success=$(echo $body | jq '.success')
        message=$(echo $body | jq '.message')

        if [ "$success" == "true" ]; then
            echo "成功添加到 oneapi"
        else
            echo "添加异常: $message"
        fi
    else
        echo "添加失败，请检查密钥！"
    fi
}

push4ToOne() {
    # 执行 cURL 命令并保存响应
    response=$(curl --location 'https://zh.quzhi.life/api/channel/' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer '"'$1'"'' \
    --data '{
        "name": "'"'$3'"'",
        "type": 1,
        "key": "'"'$2'"'",
        "openai_organization": "",
        "base_url": "http://az-raw.ns-jsfr8fru.svc.cluster.local:8787/'"'$3'"'",
        "order": 0,
        "sort": 9,
        "weight": 0,
        "retryInterval": 10,
        "testRequestBody": "",
        "overFrequencyAutoDisable": true,
        "other": "",
        "model_mapping": "",
        "excluded_fields": "",
        "models": "gpt-4,gpt-4-0314,gpt-4-0613,gpt-4-32k,gpt-4-32k-0314,gpt-4-32k-0613",
        "groups": [
            "A4.0"
        ],
        "group": "A4.0"
    }' --silent --write-out "HTTPSTATUS:%{http_code}")

    # 分离 HTTP 状态码和响应体
    http_status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')

    # 检查 HTTP 状态码
    if [ "$http_status" -eq 200 ]; then
        # 解析 JSON 并检查 'success'
        success=$(echo $body | jq '.success')
        message=$(echo $body | jq '.message')

        if [ "$success" == "true" ]; then
            echo "成功添加到 oneapi"
        else
            echo "添加异常: $message"
        fi
    else
        echo "添加失败，请检查密钥！"
    fi
}

# 主体

# 登录az账号
# loginAzure

# 获取订阅id并打印
subscription_id=$(listSubIds)
token=$(getToken)
echo "获取到订阅id：$subscription_id，如果不是单订阅，请退出脚本"

# 获取用户输入的tag
echo "输入你希望的tag，务必独一无二: "
read tag

echo "输入oneapi的鉴权密钥："
read oneKey

# JSON 数据
read -r -d '' known_regions_json << EOM
[
    {
        "id":"1",
        "display":"UK South",
        "name":"uksouth"
    },
    {
        "id":"2",
        "display":"East US",
        "name":"eastus"
    },
    {
        "id":"3",
        "display":"North Central US",
        "name":"northcentralus"
    },
    {
        "id":"4",
        "display":"France Central",
        "name":"francecentral"
    },
    {
        "id":"5",
        "display":"Canada East",
        "name":"canadaeast"
    },
    {
        "id":"6",
        "display":"Sweden Central",
        "name":"swedencentral"
    }
]
EOM

# 使用这个 JSON 数据
echo "$known_regions_json" | jq -c '.[]' | while read -r region; do
    # 使用 jq 来解析每个 JSON 对象的属性
    region_id=$(echo "$region" | jq -r '.id')
    display=$(echo "$region" | jq -r '.display')
    name=$(echo "$region" | jq -r '.name')

    # 定义初始的capacity
    cap48=40
    cap432=80
    cap3=300

    # 如果region_id表示是前三个
    if [ "$region_id" == "1" ] || [ "$region_id" == "2" ] || [ "$region_id" == "3" ]; then
        #初始化配额
        if [ "$name" == "eastus" ] || [ "$name" == "uksouth" ]; then
            cap3=240
        fi
        # 创建资源
        echo -e "\n尝试创建 $display 的资源"
        createAzureOpenaiResource "$tag-$name" "$name" "$subscription_id"

        echo -e "\n开始部署模型35-turbo"
        createDeployMent "$token" "gpt-35-turbo" $cap3 "$subscription_id" "$tag-$name"

        echo -e "\n开始部署模型35-turbo-16k"
        createDeployMent "$token" "gpt-35-turbo-16k" $cap3 "$subscription_id" "$tag-$name"

        echo -e "\n正在推送到oneapi"
        key=$(getApiKey "$tag-$name")
        push35ToOne "$oneKey" "$key" "$tag-$name" 
    fi

    if [ "$region_id" == "4" ] || [ "$region_id" == "5" ] || [ "$region_id" == "6" ]; then
    #初始化配额
        if [ "$name" == "francecentral" ]; then
            cap3=240
            cap48=20
            cap432=60
        fi
        # 创建资源
        echo -e "\n尝试创建 $display 的资源"
        createAzureOpenaiResource "$tag-$name" "$name" "$subscription_id"

        echo -e "\n开始部署模型35-turbo"
        createDeployMent "$token" "gpt-35-turbo" $cap3 "$subscription_id" "$tag-$name"
        
        echo -e "\n开始部署模型35-turbo-16k"
        createDeployMent "$token" "gpt-35-turbo-16k" $cap3 "$subscription_id" "$tag-$name"

        echo -e "\n开始部署模型gpt-4"
        createDeployMent "$token" "gpt-4" $cap48 "$subscription_id" "$tag-$name"

        echo -e "\n开始部署模型gpt-4-32k"
        createDeployMent "$token" "gpt-4-32k" $cap432 "$subscription_id" "$tag-$name"

        echo -e "\n正在推送到oneapi"
        key=$(getApiKey "$tag-$name")
        push4ToOne "$oneKey" "$key" "$tag-$name" 
    fi
done

echo -e "\n执行完毕"