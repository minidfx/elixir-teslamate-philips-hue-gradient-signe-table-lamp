import Config

if config_env() == :prod do
  config :teslamate_philips_hue_gradient_signe_table_lamp,
    mqtt_host: System.fetch_env!("MQTT_HOST"),
    mqtt_port: System.fetch_env!("MQTT_PORT") |> String.to_integer(),
    mqtt_username: System.get_env("MQTT_USERNAME"),
    mqtt_password: System.get_env("MQTT_PASSWORD"),
    hue_bridge_host: System.fetch_env!("HUE_BRIDGE_HOST"),
    hue_bridge_application_key: System.fetch_env!("HUE_BRIDGE_APPLICATION_KEY"),
    hue_signe_gradient_lamp_id: System.fetch_env!("HUE_LIGHT_ID"),
    car_id: System.fetch_env!("CAR_ID") |> String.to_integer(),
    geofence_home_name: System.fetch_env!("GEOFENCE_HOME_NAME")
end
