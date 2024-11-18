import Config

config :logger, :console,
  format: {TeslamatePhilipsHueGradientSigneTableLamp.Logger, :format},
  utc_log: true,
  metadata: [:application, :module, :function, :line, :mfa],
  level: :debug

config :logger,
  compile_time_purge_matching: [
    [application: :que],
    [module: TeslamatePhilipsHueGradientSigneTableLamp.Handler],
    [module: Tzdata.DataLoader]
  ]

config :teslamate_philips_hue_gradient_signe_table_lamp,
  mqtt_host: "<host>",
  mqtt_port: 1883,
  mqtt_username: "<username>",
  mqtt_password: "<password>",
  hue_bridge_host: "<host>",
  hue_bridge_application_key: "<key>",
  hue_signe_gradient_lamp_id: "<id>",
  car_id: 1,
  geofence_home_name: "<name>"
