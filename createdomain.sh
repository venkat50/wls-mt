#!/bin/bash

if [ $# -lt 1 ]; then
   echo "Usage: createdomain.sh <Name> <Port>"
   exit 0
fi

NAME="${1}_domain"

DOMAIN_HOME="/u01/wins/wls1221/user_projects/domains"
DOMAIN_DIR="${DOMAIN_HOME}/${NAME}"

cat <<_EOF_ > /tmp/${NAME}.py

# Select the template to use for creating the domain
selectTemplate('Basic WebLogic Server Domain')

_EOF_


#JRFTemplate=

JRFTemplate="Oracle Enterprise Manager-Restricted JRF"

PORT=${2:-9001}

if [ "${PORT}" == "9001" ]; then
   SERVER_NAME=DemoServer
else
   SERVER_NAME=AdminServer
fi

if [ "${PORT}" == "8001" ]; then
  JRFTemplate="Oracle Traffic Director - Restricted JRF"
elif [ "${PORT}" == "7001" ]; then
  JRFTemplate="Oracle Enterprise Manager-Restricted JRF"
fi

if [ "${JRFTemplate}" != "" ]; then
   echo "selectTemplate('${JRFTemplate}')" >> /tmp/${NAME}.py
fi


cat <<_EOF_ >> /tmp/${NAME}.py

loadTemplates()

# Set the listen address and listen port for the Administration Server

cd('Servers/AdminServer')
set('Name','${SERVER_NAME}')
set('ListenAddress','')
set('ListenPort', ${PORT})

# Set the domain password for the Administration Server user
cd('/')
cd('Security/base_domain/User/weblogic')
cmo.setPassword('welcome1')


#=======================================================================================
# Write the domain and close the domain template.
#=======================================================================================

setOption('OverwriteDomain', 'true')
writeDomain('${DOMAIN_DIR}')
closeTemplate()

#exit()

_EOF_


if [ "${NAME}" == "demo_domain" ]; then

cat <<_EOF_ >> /tmp/${NAME}.py

# Enable LifecycleManager

readDomain('${DOMAIN_DIR}')
cd('/')
create('demo_domain','LifecycleManagerConfig')
cd('LifecycleManagerConfig/demo_domain')
set('DeploymentType','admin')
set('OutofBandEnabled',true)
updateDomain()
_EOF_

fi

echo "exit()" >> /tmp/${NAME}.py

#/u01/wins/wls1221/oracle_common/common/bin/wlst.sh /tmp/${NAME}.py
/u01/wins/wls12211/oracle_common/common/bin/wlst.sh /tmp/${NAME}.py


cat <<_EOF_ > ${DOMAIN_DIR}/bin/setUserOverrides.sh

DERBY_FLAG=false
USER_MEM_ARGS="-Xms256m -Xmx512m"
#JAVA_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+ResourceManagement -XX:+UseG1GC \${JAVA_OPTIONS} \${JAVA_PROPERTIES}"
_EOF_

chmod a+x  ${DOMAIN_DIR}/bin/setUserOverrides.sh

ed -s ${DOMAIN_DIR}/nodemanager/nodemanager.properties <<_EOF_
16c
SecureListener=false
.
wq
_EOF_

for k in "otd" "demo" "dev"; do
    grep -q ${k}_domain ${DOMAIN_DIR}/nodemanager/nodemanager.domains
    if [ $? -eq 1 ]; then
    echo "${k}_domain=${DOMAIN_HOME}/${k}_domain" >> ${DOMAIN_DIR}/nodemanager/nodemanager.domains
    fi
done

