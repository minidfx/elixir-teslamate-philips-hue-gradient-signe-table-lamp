import Config

config :logger, :console,
  format: {TeslamatePhilipsHueGradientSigneTableLamp.Logger, :format},
  utc_log: true,
  metadata: [:application, :module, :function, :line, :mfa],
  level: :warning

config :logger,
  compile_time_purge_matching: [
    [application: :que],
    [module: Tzdata.DataLoader]
  ]
