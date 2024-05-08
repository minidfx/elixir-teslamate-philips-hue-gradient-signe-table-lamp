import Config

config :tesla, adapter: {Tesla.Adapter.Finch, name: AppFinch}

import_config "#{config_env()}.exs"
