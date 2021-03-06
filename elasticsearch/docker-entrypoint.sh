#!/bin/bash

set -e

# Add elasticsearch as command if needed
if [ "${1:0:1}" = '-' ]; then
	set -- elasticsearch "$@"
fi

cp /elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml

if [ $ELASTICSEARCH_MASTER = "YES" ]
then
  
  cat /readonlyrest.yml >> /usr/share/elasticsearch/config/elasticsearch.yml

  export TESTREADONLYREST=$(/usr/share/elasticsearch/bin/elasticsearch-plugin list | grep readonlyrest)
  if [ -z "$TESTREADONLYREST" ]
  then
    bin/elasticsearch-plugin install file:/usr/share/elasticsearch/readonlyrest.zip
  fi
  export TESTREADONLYREST=''

  rm -rf /tmp/ssl
  mkdir -p /tmp/ssl
  keytool -genkey -keyalg RSA -noprompt -alias $SERVERNAME -dname "CN=$SERVERNAME,OU=IDM,O=EEA,L=IDM1,C=DK" -keystore /tmp/ssl/self.jks -storepass $KIBANA_RW_PASSWORD -keypass $KIBANA_RW_PASSWORD
  keytool -keystore  /tmp/ssl/self.jks -alias $SERVERNAME -export -file  /tmp/ssl/self.cert

  chmod 400 /tmp/ssl/*

  sed "s#CHECKHEALTH#$CHECKHEALTH#g" -i /usr/share/elasticsearch/config/elasticsearch.yml

  echo "node.master: true" >> /usr/share/elasticsearch/config/elasticsearch.yml

  sed "s#KIBANA_RW_USERNAME#$KIBANA_RW_USERNAME#g" -i /usr/share/elasticsearch/config/elasticsearch.yml
  sed "s#KIBANA_RW_PASSWORD#$KIBANA_RW_PASSWORD#g" -i /usr/share/elasticsearch/config/elasticsearch.yml

  sed "s#LOGSTASH_RW_USERNAME#$LOGSTASH_RW_USERNAME#g" -i /usr/share/elasticsearch/config/elasticsearch.yml
  sed "s#LOGSTASH_RW_PASSWORD#$LOGSTASH_RW_PASSWORD#g" -i /usr/share/elasticsearch/config/elasticsearch.yml

  if [ "$KIBANA_RO_USERNAME" ]; then
    sed "s#KIBANA_RO_USERNAME#$KIBANA_RO_USERNAME#g" -i /usr/share/elasticsearch/config/elasticsearch.yml
    sed "s#KIBANA_RO_PASSWORD#$KIBANA_RO_PASSWORD#g" -i /usr/share/elasticsearch/config/elasticsearch.yml
  fi
 
else
  echo "node.master: false" >> /usr/share/elasticsearch/config/elasticsearch.yml
  echo 'discovery.zen.ping.unicast.hosts: ["ELASTICSEARCH_MASTER"]' >> /usr/share/elasticsearch/config/elasticsearch.yml
  sed "s#ELASTICSEARCH_MASTER#$ELASTICSEARCH_MASTER#g" -i /usr/share/elasticsearch/config/elasticsearch.yml
fi

# Drop root privileges if we are running elasticsearch
# allow the container to be started with `--user`
if [ "$1" = 'elasticsearch' -a "$(id -u)" = '0' ]; then
	# Change the ownership of user-mutable directories to elasticsearch
	for path in \
		/usr/share/elasticsearch/data \
		/usr/share/elasticsearch/logs \
	; do
		chown -R elasticsearch:elasticsearch "$path"
	done
	
	set -- gosu elasticsearch "$@"
	#exec gosu elasticsearch "$BASH_SOURCE" "$@"
fi


# As argument is not related to elasticsearch,
# then assume that user wants to run his own process,
# for example a `bash` shell to explore this image
exec "$@"
