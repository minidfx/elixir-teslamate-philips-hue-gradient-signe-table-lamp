import Config

if config_env() == :prod do
  config :teslamate_philips_hue_gradient_signe_table_lamp,
    mqtt_host: System.fetch_env!("MQTT_HOST"),
    mqtt_port: System.fetch_env!("MQTT_PORT")
end
