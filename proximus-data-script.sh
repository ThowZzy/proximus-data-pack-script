#!/bin/bash

prompt_cookie() {
    read -s -p "Enter the cookie 'iiamsid' value : " cookie_value
    echo
}

prompt_executions() {
    read -p "How many packs ? : " num_executions
    if ! [[ "$num_executions" =~ ^[1-9]$|^10$ ]]; then
        echo "Invalid input! Please enter a number between 1 and 10."
        prompt_executions
    fi
}

use_previous_cookie() {
    read -p "Do you want to use the previous cookie? [Y/n]: " choice
    case $choice in
        yes|Yes|YES|y|Y)
            if [ -f "cookie" ]; then
                cookie_value=$(<cookie)
            else
                echo "No previous cookie found. Enter a new one."
                prompt_cookie
            fi
            ;;
        no|No|NO|n|N)
            prompt_cookie
            ;;
        *)
            echo "Invalid choice. Please enter 'yes' or 'no'."
            use_previous_cookie
            ;;
    esac
}

use_previous_cookie
prompt_executions

# Store the cookie value in the "cookie" file
echo "$cookie_value" > cookie

# Retrieve ServiceID from account
serviceID=$(curl -s 'https://www.proximus.be/rest/products-aggregator/user-product-overview' \
              -X GET -H "Cookie: iiamsid=$cookie_value" \
              | jq -r '.FLS.inPackProducts[0].products[] | select(.technicalName == "internet") | .accessNumber')

pids=()

#Curl command in async + logging
execute_async() {
  local i=$1
  curl -s "https://www.proximus.be/rest/shopping-basket/product/FI?serviceId=$serviceID" -X POST -H 'Content-Type: application/json' \
    --data-raw '{"actions":[{"name":"MyProximusConfirmAction","parameters":{"MPC_UUID":"KIIGH"},"type":"serverSide","dependsOnSubStepId":false,"dependsOnOtherFieldsWithSameId":false}],"configuration":{},"cpvComponent":{"mpcUuid":"KIIGH","chargeEvent":"PR","chargeCode":"KETKR","action":"PROVIDE"}}' \
    -H "Cookie: iiamsid=$cookie_value"  | (
      result="$(cat)"
      if [[ -z "$result" ]]; then
        echo "Result ($i/$num_executions) : Failed.. (Wrong cookie?)"
      else
        # Process non-empty output with jq
        echo "Result ($i/$num_executions) : $(echo "$result" | jq -r '.validationResult.status // "Failed.. (Create an issue on github for this one)"')"
      fi
    ) &
  pids[$i]="$!"
}

#Request a pack X times
for ((i = 1; i <= num_executions; i++)); do
  echo "Requesting 300GB... ($i/$num_executions)"
  execute_async $i
done

wait "${pids[@]}"  # Wait for all PIDs in the pids array (wait for all curl commands to finish)
