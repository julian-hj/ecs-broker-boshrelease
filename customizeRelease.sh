#!/bin/sh

echo "  Does the Service Broker Application require any configurable parameter/variables for its functioning"
echo "     Externalized parameters can be dynamic or user defined like some github access token"
echo "     and needs to be part of the Service Broker App via environment variable"
echo "     Example:  cf set-env ServiceBrokerApp <MyVariable> <TestValue>"
echo ""
printf "  Reply y or n: "
read requireEnvVariables
if [ "${requireEnvVariables:0:1}" == "y" ]; then
  specTmp="spec.tmp"
  propTmp="prop.tmp"
  erbTmp1="erb1.tmp"
  erbTmp2="erb2.tmp"
  tileTmp1="tile1.tmp"
  tileTmp2="tile2.tmp"
  tileTmp3="tile3.tmp"

  for tmp in  $specTmp $propTmp $erbTmp1 $erbTmp2 $tileTmp1 $tileTmp2 $tileTmp3
  do
    rm $tmp 2>/dev/null; touch $tmp
  done

  brokerName=`grep broker.app_name jobs/deploy-service-broker/spec `
  brokerName=`basename ${brokerName} '.app_name:' `
  while true
  do
    printf "    Variable name (without spaces, enter n to stop): "
    read variableName
    if [ "${variableName}" == "n" ]; then
      break
    fi

    printf "    Enter short description of Variable (spaces okay): "
    read variableLabel
    printf "    Enter long description of Variable (spaces okay): "
    read variableDescrp
    printf "    Enter a default value (use quotes if containing spaces): "
    read defaultValue
    printf "    Should this be configurable or exposed to end-user, reply with y or n: "
    read exposable

    mod_variableName=`echo $variableName | sed -e 's/ /_/g;s/-/_/g' `
    variableName_upper=`echo $mod_variableName | awk '{print toupper($0)}' `
    templated_variableName_upper=TEMPLATE_${variableName_upper}
    echo "export ${variableName}=${templated_variableName_upper}"  >> src/templates/setupServiceBrokerEnv.sh
    echo "  ${brokerName}.${variableName}:"  >> $specTmp
    echo "    description: '${variableDescrp}'"  >> $specTmp
    echo "    default: '${defaultValue}'"  >> $specTmp

    echo "export ${variableName_upper}=<%= properties.${brokerName}.${variableName} %>" >> $erbTmp1
    echo "     s#${templated_variableName_upper}#\${${variableName_upper}}#g;  \\ " >> $erbTmp2

    if [ "${exposable:0:1}" == "y" ]; then
      echo "      - reference: .${variableName}"  >> $tileTmp1
      echo "        label: ${variableLabel}  "  >> $tileTmp1
      echo "        description: ${variableDescrp}  "  >> $tileTmp1
    fi

    echo "- name: ${variableName}"  >> $tileTmp2
    echo "  type: string "  >> $tileTmp2
    echo "  configurable: true" >> $tileTmp2
    echo "  default: ${defaultValue}" >> $tileTmp2

    echo "      ${variableName}: (( .properties.${variableName}.value ))"  >> $tileTmp3
    echo "    ${variableName}: ${defaultValue}"  >> $propTmp

    echo ""
  done

  sed -i.bak "/CUSTOM_VARIABLE_BEGIN_MARKER/r./${specTmp}" jobs/deploy-service-broker/spec
  sed -i.bak "/CUSTOM_VARIABLE_BEGIN_MARKER/r./${erbTmp1}" jobs/deploy-service-broker/templates/deploy.sh.erb
  sed -i.bak "/CUSTOM_VARIABLE_SED_BEGIN_MARKER/r./${erbTmp2}" jobs/deploy-service-broker/templates/deploy.sh.erb

  sed -i.bak "/CUSTOM_VARIABLE_LABEL_BEGIN_MARKER/r./${tileTmp1}" *tile.yml 
  sed -i.bak "/CUSTOM_VARIABLE_DEFN_BEGIN_MARKER/r./${tileTmp2}" *tile.yml 
  sed -i.bak "/CUSTOM_VARIABLE_MANIFEST_BEGIN_MARKER/r./${tileTmp3}" *tile.yml
  sed -i.bak "/CUSTOM_VARIABLE_MANIFEST_BEGIN_MARKER/r./${propTmp}" templates/*properties.yml
  rm *.tmp
fi

echo ""
printf "Does the Service Broker need to download any external driver/library? Reply y or n : "
read downloadDriver
if [ "${downloadDriver:0:1}" == "n" ]; then
  sed -i.bak "/DRIVER_DOWNLOAD_BEGIN_MARKER/,/DRIVER_DOWNLOAD_END_MARKER/ { d; }" jobs/deploy-service-broker/spec jobs/deploy-service-broker/templates/deploy.sh.erb templates/*properties.yml  *tile.yml
fi

echo ""
printf "Does the Service Broker need a persistence store? Reply y or n : "
read persistenceStore
if [ "${persistenceStore:0:1}" == "n" ]; then
  sed -i.bak "/PERSISTENCE_STORE_BEGIN_MARKER/,/PERSISTENCE_STORE_END_MARKER/ { d; }" jobs/deploy-service-broker/spec jobs/deploy-service-broker/templates/deploy.sh.erb templates/*properties.yml  *tile.yml
fi


echo ""
printf "Does the Service Broker need to manage a target service? Reply y or n : "
read targetService
if [ "${targetService:0:1}" == "n" ]; then
  sed -i.bak "/TARGET_SERVICE_BEGIN_MARKER/,/TARGET_SERVICE_END_MARKER/ { d; }" jobs/deploy-service-broker/spec jobs/deploy-service-broker/templates/deploy.sh.erb templates/*properties.yml  *tile.yml
fi

echo ""
printf "Does the Service Broker allow customized user defined plans? Reply y or n : "
read userPlans
if [ "${userPlans:0:1}" == "n" ]; then
  sed -i.bak "/ON_DEMAND_PLAN_BEGIN_MARKER/,/ON_DEMAND_PLAN_END_MARKER/ { d; }" jobs/deploy-service-broker/spec jobs/deploy-service-broker/templates/deploy.sh.erb templates/*properties.yml  *tile.yml
fi

echo ""
printf "Does the Service Broker support in-built plan(s)? Reply y or n : "
read internalPlans
if [ "${internalPlans:0:1}" == "y" ]; then
  printf "Provide name of the internal plan (if multiple plans, use comma as separator without spaces): "
  read internalPlanNames
  sed -i.bak "s/INTERNAL_PLAN_NAME/${internalPlanNames}/g" jobs/deploy-service-broker/spec jobs/deploy-service-broker/templates/deploy.sh.erb templates/*properties.yml *tile.yml
else
  sed -i.bak "s/INTERNAL_PLAN_NAME//g" jobs/deploy-service-broker/spec templates/*properties.yml *tile.yml 
fi

find . -name *bak | xargs rm 
echo ""