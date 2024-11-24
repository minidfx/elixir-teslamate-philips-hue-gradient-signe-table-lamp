import Config

config :logger, :console,
  format: {TeslamatePhilipsHueGradientSigneTableLamp.Logger, :format},
  utc_log: true,
  metadata: [:application, :module, :function, :line, :mfa],
  level: :debug
