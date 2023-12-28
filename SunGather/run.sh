#!/usr/bin/with-contenv bashio

if [ ! -d /share/SunGather ]; then
  mkdir -p /share/SunGather
fi

if [ ! -f /share/SunGather/config.yaml ]; then
    cp config-hassio.yaml /share/SunGather/config.yaml
fi

INVERTER_HOST=$(bashio::config 'host')
INTERVAL=$(bashio::config 'scan_interval')
CONNECTION=$(bashio::config 'connection')
SMART_METER=$(bashio::config 'smart_meter')
CUSTOM_MQTT_SERVER=$(bashio::config 'custom_mqtt_server')
LOG_CONSOLE=$(bashio::config 'log_console')

if [ $CUSTOM_MQTT_SERVER = true ]; then
   echo "Skipping auto MQTT set up, please ensure MQTT settings are configured in /share/SunGather/config.yaml"
else
  if ! bashio::services.available "mqtt"; then
    bashio::exit.nok "No internal MQTT Broker found. Please install Mosquitto broker."
  else
      MQTT_HOST=$(bashio::services mqtt "host")
      MQTT_PORT=$(bashio::services mqtt "port")
      MQTT_USER=$(bashio::services mqtt "username")
      MQTT_PASS=$(bashio::services mqtt "password")

      yq -i "
        (.exports[] | select(.name == \"mqtt\") | .enabled) = True |
        (.exports[] | select(.name == \"mqtt\") | .host) = \"$MQTT_HOST\" |
        (.exports[] | select(.name == \"mqtt\") | .port) = $MQTT_PORT |
        (.exports[] | select(.name == \"mqtt\") | .username) = \"$MQTT_USER\" |
        (.exports[] | select(.name == \"mqtt\") | .password) = \"$MQTT_PASS\" |
        (.exports[] | select(.name == \"mqtt\") | .homeassistant) = True
      " /share/SunGather/config.yaml
  fi
fi

yq -i "
  .inverter.host = \"$INVERTER_HOST\" |
  .inverter.scan_interval = $INTERVAL |
  .inverter.connection = \"$CONNECTION\" |
  .inverter.smart_meter = $SMART_METER |
  .inverter.log_console = \"$LOG_CONSOLE\"
" /share/SunGather/config.yaml

yq -i "
  (.exports[] | select(.name == \"hassio\") | .enabled) = True |
  (.exports[] | select(.name == \"hassio\") | .api_url) = \"http://supervisor/core/api\" |
  (.exports[] | select(.name == \"hassio\") | .token) = \"$SUPERVISOR_TOKEN\"
" /share/SunGather/config.yaml

yq -i "
  (.exports[] | select(.name == \"webserver\") | .enabled) = True |
  (.exports[] | select(.name == \"webserver\") | .port) = 8099
" /share/SunGather/config.yaml

exec python3 /sungather.py -c /share/SunGather/config.yaml -l /share/SunGather/