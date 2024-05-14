defmodule TeslamatePhilipsHueGradientSigneTableLamp.HueAnimation do
  use GenServer

  alias TeslamatePhilipsHueGradientSigneTableLamp.Philips
  alias TeslamatePhilipsHueGradientSigneTableLamp.Queue

  require Logger

  @default_latence 1000

  # Client

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec charging() :: :ok
  def charging() do
    Logger.debug("[HueAnimation] Running charging animation ...")
    GenServer.cast(__MODULE__, :clear)
    GenServer.cast(__MODULE__, :looping_charging)
  end

  @spec clear() :: :ok
  def clear() do
    Logger.debug("[HueAnimation] Clearing any animation ...")
    GenServer.cast(__MODULE__, :clear)
  end

  # Callbacks

  @impl true
  def init(args) do
    Logger.debug("[HueAnimation] Initializing ...")
    {:ok, args}
  end

  @impl true
  def handle_info(:looping_charging, %{charging_pixel_index: pixel_index} = state)
      when pixel_index < 4 do
    Queue.publish_request(Philips.get_charging_state_request(pixel_index + 1))

    Logger.debug("[HueAnimation] Lopping charging animation, pixel #{pixel_index} ...")
    Process.send_after(__MODULE__, :looping_charging, @default_latence)

    {:noreply, %{state | charging_pixel_index: pixel_index + 1}}
  end

  @impl true
  def handle_info(:looping_charging, %{charging_pixel_index: pixel_index} = state) do
    Queue.publish_request(Philips.get_charging_state_request(1))

    Logger.debug("[HueAnimation] Lopping charging animation, pixel #{pixel_index} ...")
    Process.send_after(__MODULE__, :looping_charging, @default_latence)

    {:noreply, %{state | charging_pixel_index: 1}}
  end

  @impl true
  def handle_info(:looping_charging, state) do
    Logger.debug("[HueAnimation] Charging animation stopped.")
    {:noreply, state}
  end

  @impl true
  def handle_cast(:looping_charging, %{charging_pixel_index: _} = state) do
    Logger.debug("[HueAnimation] Charging animation already started.")
    {:noreply, state}
  end

  @impl true
  def handle_cast(:looping_charging, state) do
    Queue.publish_request(Philips.get_charging_state_request(1))

    Logger.debug("[HueAnimation] Lopping charging animation, pixel 1 ...")
    Process.send_after(__MODULE__, :looping_charging, @default_latence)

    {:noreply, Map.put(state, :charging_pixel_index, 1)}
  end

  @impl true
  def handle_cast(:clear, state) do
    Logger.debug("[HueAnimation] Animation cleared.")
    {:noreply, Map.delete(state, :charging_pixel_index)}
  end
end
