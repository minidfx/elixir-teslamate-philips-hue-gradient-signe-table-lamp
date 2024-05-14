defmodule TeslamatePhilipsHueGradientSigneTableLamp.Queue do
  use GenServer

  alias TeslamatePhilipsHueGradientSigneTableLamp.HttpRequest
  alias TeslamatePhilipsHueGradientSigneTableLamp.HueBridgeClient

  require Logger

  # Client

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec publish_request(HttpRequest.t()) :: :ok | {:error, String.t()}
  def publish_request(request) do
    case request do
      %HttpRequest{method: method} when method in [:put, :post] ->
        Logger.debug("[Queue] Publishing a request to the hue bridge ...")
        GenServer.cast(__MODULE__, {:publish_request, request})

      _ ->
        {:error, "The given request is not supported"}
    end
  end

  # Callbacks

  @impl true
  def init(args) do
    Logger.debug("[Queue] Initializing ...")

    {:ok, args}
  end

  @impl true
  def handle_cast({:publish_request, %HttpRequest{method: :put} = request}, state) do
    %HttpRequest{url: u, body: b} = request

    with {:ok, response} <- HueBridgeClient.put(u, b),
         %Tesla.Env{status: 200} <- response do
      Logger.debug("[Queue] Request sent to the hue bridge.")
    else
      %Tesla.Env{status: status} ->
        Logger.error("[Queue] Invalid response received from the hue bridge: #{status}")

      {:error, reason} ->
        Logger.error("[Queue] #{reason}")
    end

    {:noreply, state}
  end
end
