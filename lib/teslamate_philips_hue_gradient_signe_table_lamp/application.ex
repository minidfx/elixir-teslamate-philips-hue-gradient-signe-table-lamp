defmodule TeslamatePhilipsHueGradientSigneTableLamp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    mqtt_topic =
      "teslamate/cars/#{Application.fetch_env!(:teslamate_philips_hue_gradient_signe_table_lamp, :car_id)}/#"

    children = [
      # Starts a worker by calling: TeslamatePhilipsHueGradientSigneTableLamp.Worker.start_link(arg)
      # {TeslamatePhilipsHueGradientSigneTableLamp.Worker, arg}
      {Finch,
       name: AppFinch,
       pools: %{
         default: [
           conn_opts: [
             transport_opts: [
               verify: :verify_peer,
               # Disable any TLS certificate validation
               verify_fun: {fn _, _, state -> {:valid, state} end, []}
             ]
           ]
         ]
       }},
      TeslamatePhilipsHueGradientSigneTableLamp.Queue,
      TeslamatePhilipsHueGradientSigneTableLamp.HueAnimation,
      {
        TeslamatePhilipsHueGradientSigneTableLamp.States,
        %{log_level: Application.fetch_env!(:logger, :console) |> Keyword.fetch!(:level)}
      },
      {Tortoise311.Connection,
       [
         client_id: :teslamate_philips_hue_gradient_signe_table_lamp,
         server:
           {Tortoise311.Transport.Tcp,
            host: Application.fetch_env!(:teslamate_philips_hue_gradient_signe_table_lamp, :mqtt_host),
            port: Application.fetch_env!(:teslamate_philips_hue_gradient_signe_table_lamp, :mqtt_port)},
         handler: {TeslamatePhilipsHueGradientSigneTableLamp.MqttHandler, []},
         user_name:
           Application.get_env(
             :teslamate_philips_hue_gradient_signe_table_lamp,
             :mqtt_username
           ),
         password:
           Application.get_env(
             :teslamate_philips_hue_gradient_signe_table_lamp,
             :mqtt_password
           ),
         subscriptions: [{mqtt_topic, 2}]
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TeslamatePhilipsHueGradientSigneTableLamp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
