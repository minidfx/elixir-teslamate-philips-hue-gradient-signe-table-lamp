import Config

config :logger, :console,
  format: "$time [$level] $message\n",
  utc_log: true

config :tesla, adapter: {Tesla.Adapter.Finch, name: AppFinch}

import_config "#{config_env()}.exs"
