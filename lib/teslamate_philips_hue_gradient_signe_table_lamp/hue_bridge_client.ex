defmodule TeslamatePhilipsHueGradientSigneTableLamp.HueBridgeClient do
  use Tesla

  plug(
    Tesla.Middleware.BaseUrl,
    "https://#{Application.fetch_env!(:teslamate_philips_hue_gradient_signe_table_lamp, :hue_bridge_host)}/clip/v2"
  )

  plug(Tesla.Middleware.Headers, [
    {"hue-application-key",
     Application.fetch_env!(
       :teslamate_philips_hue_gradient_signe_table_lamp,
       :hue_bridge_application_key
     )},
    {"Content-Type", "application/json"}
  ])

  plug(Tesla.Middleware.JSON)
end
