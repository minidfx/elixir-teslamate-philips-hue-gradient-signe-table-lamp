import Config

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:mfa, :initial_call, :registered_name, :line]

config :teslamate_philips_hue_gradient_signe_table_lamp,
  mqtt_host: "<host>",
  mqtt_port: 1883,
  hue_bridge_host: "<host>>",
  hue_bridge_application_key: "<key>",
  hue_signe_gradient_lamp_id: "<id>",
  car_id: 1,
  geofence_home_name: "<name>"
