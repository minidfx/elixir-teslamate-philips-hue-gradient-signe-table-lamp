defmodule TeslamatePhilipsHueGradientSigneTableLamp.States do
  use GenServer

  alias TeslamatePhilipsHueGradientSigneTableLamp.HttpRequest
  alias TeslamatePhilipsHueGradientSigneTableLamp.HueAnimation
  alias TeslamatePhilipsHueGradientSigneTableLamp.HueBridgeClient
  alias TeslamatePhilipsHueGradientSigneTableLamp.Philips
  alias TeslamatePhilipsHueGradientSigneTableLamp.ProcessFacade
  alias TeslamatePhilipsHueGradientSigneTableLamp.Queue

  require Logger

  @type state ::
          :unknown
          | :home
          | :plugged
          | :charging
          | :unplugged
          | :stopped
          | :complete
          | :no_power
          | :scheduled
  @type server_state :: %{state: state(), is_plugged: boolean(), is_home: boolean()}

  @default_timer_duration_ms 5 * 60 * 1000

  # Client

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(%{log_level: :none}) do
    GenServer.start_link(
      __MODULE__,
      initial_state(),
      name: __MODULE__
    )
  end

  def start_link(%{log_level: level})
      when level in [:debug, :info, :warning, :error, :none] do
    GenServer.start_link(
      __MODULE__,
      initial_state(),
      name: __MODULE__,
      debug: [logger_level_to_genserver_level(level)]
    )
  end

  @spec current_state() :: state()
  def current_state(), do: GenServer.call(__MODULE__, :state)

  @spec home_geofence_detected() :: :ok
  def home_geofence_detected(), do: GenServer.cast(__MODULE__, :home)

  @spec plugged() :: :ok
  def plugged(), do: GenServer.cast(__MODULE__, :plugged)

  @spec stopped() :: :ok
  def stopped(), do: GenServer.cast(__MODULE__, :stopped)

  @spec complete() :: :ok
  def complete(), do: GenServer.cast(__MODULE__, :complete)

  @spec charging() :: :ok
  def charging() do
    GenServer.cast(__MODULE__, :charging)
  end

  @spec unplugged() :: :ok
  def unplugged(), do: GenServer.cast(__MODULE__, :unplugged)

  @spec no_power() :: :ok
  def no_power(), do: GenServer.cast(__MODULE__, :no_power)

  @spec unknown() :: :ok
  def unknown(), do: GenServer.cast(__MODULE__, :unknown)

  @spec scheduled(DateTime.t()) :: :ok
  def scheduled(datetime) when is_struct(datetime, DateTime),
    do: GenServer.cast(__MODULE__, {:scheduled, datetime})

  @spec update_battery_level(integer()) :: :ok
  def update_battery_level(level) when level in 0..100,
    do: GenServer.cast(__MODULE__, {:update_battery_level, level})

  # Callbacks

  @impl true
  def init(args) do
    Logger.debug("[State] Initializing ...")

    with {:ok, message} <- is_light_supported(),
         request <- Philips.get_unknown_state_request() do
      Logger.info("[State] #{message}")
      Queue.publish_request(request)
      {:ok, args}
    else
      {:error, reason} ->
        Logger.error("[State] #{reason}")
        {:stop, "Cannot contact the HueBridge."}
    end
  end

  # NoPower from the timer

  @impl true

  def handle_info(:no_power, %{is_home: true, timer: _timer} = state) do
    Queue.publish_request(Philips.get_no_power_request())

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :no_power)}
  end

  @impl true
  def handle_info(message, %{state: car_state} = state) do
    Logger.error(
      "[State] Transition not supported: #{inspect(message)}, current state: #{car_state}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_call(:state, _, state), do: {:reply, state, state}

  # Geofence detected

  @impl true
  def handle_cast(:home, %{is_home: false, timer: _} = state) do
    {:noreply,
     state
     |> Map.put(:state, :home)
     |> Map.put(:is_home, true)}
  end

  @impl true
  def handle_cast(:home, %{is_home: false} = state) do
    Queue.publish_request(Philips.get_pending_status_request())

    timer = ProcessFacade.send_after(__MODULE__, :no_power, @default_timer_duration_ms)

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :home)
     |> Map.put(:timer, timer)
     |> Map.put(:is_home, true)}
  end

  # NoPower

  @impl true
  def handle_cast(:no_power, %{state: s, timer: _, is_home: true} = state)
      when s in [:home, :plugged, :charging, :stopped] do
    {:noreply, Map.put(state, :state, :no_power)}
  end

  @impl true
  def handle_cast(:no_power, %{state: s, is_home: true} = state)
      when s in [:home, :plugged, :charging, :stopped] do
    Queue.publish_request(Philips.get_no_power_request())

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :no_power)}
  end

  # Plugged

  @impl true
  def handle_cast(:plugged, %{is_plugged: false, is_home: true, timer: _} = state) do
    {:noreply,
     state
     |> Map.put(:state, :plugged)
     |> Map.put(:is_plugged, true)}
  end

  @impl true
  def handle_cast(:plugged, %{is_plugged: false, is_home: true} = state) do
    Queue.publish_request(Philips.get_pending_status_request())

    timer = ProcessFacade.send_after(__MODULE__, :no_power, @default_timer_duration_ms)

    {:noreply,
     state
     |> Map.put(:state, :plugged)
     |> Map.put(:is_plugged, true)
     |> Map.put(:timer, timer)}
  end

  @impl true
  def handle_cast(:plugged, %{is_plugged: false} = state) do
    {:noreply,
     state
     |> Map.put(:state, :plugged)
     |> Map.put(:is_plugged, true)}
  end

  # Unplugged

  @impl true
  def handle_cast(:unplugged, %{is_plugged: true, battery_level: level} = state) do
    HueAnimation.clear()

    level
    |> Philips.red_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :unplugged)}
  end

  @impl true
  def handle_cast(:unplugged, %{is_plugged: true} = state) do
    HueAnimation.clear()

    Queue.publish_request(Philips.get_no_power_request())

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :unplugged)}
  end

  # Charging

  @impl true
  def handle_cast(:charging, %{is_plugged: true, is_home: true} = state) do
    HueAnimation.charging()

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :charging)}
  end

  # Stopped

  @impl true
  def handle_cast(:stopped, %{is_plugged: true, is_home: true, battery_level: level} = state) do
    HueAnimation.clear()

    level
    |> Philips.red_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply, Map.put(state, :state, :stopped)}
  end

  @impl true
  def handle_cast(:stopped, %{is_plugged: true, is_home: true} = state) do
    HueAnimation.clear()

    Queue.publish_request(Philips.get_no_power_request())

    {:noreply, Map.put(state, :state, :stopped)}
  end

  # Complete

  @impl true
  def handle_cast(:complete, %{is_plugged: true, is_home: true, battery_level: level} = state) do
    HueAnimation.clear()

    level
    |> Philips.green_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply, Map.put(state, :state, :complete)}
  end

  @impl true
  def handle_cast(:complete, %{is_plugged: true, is_home: true} = state) do
    HueAnimation.clear()

    # 100 percent because we didn't received the battery level yet.
    100
    |> Philips.green_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply, Map.put(state, :state, :complete)}
  end

  # Unknown

  @impl true
  def handle_cast(:unknown, state) do
    Queue.publish_request(Philips.get_unknown_state_request())

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :unknown)
     |> Map.put(:is_home, false)
     |> Map.put(:is_plugged, false)}
  end

  # Update battery level

  @impl true
  def handle_cast({:update_battery_level, level}, %{state: :complete} = state) do
    level
    |> Philips.green_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply, Map.put(state, :battery_level, level)}
  end

  @impl true
  def handle_cast({:update_battery_level, level}, %{state: s} = state)
      when s in [:stopped, :unplugged] do
    level
    |> Philips.red_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply, Map.put(state, :battery_level, level)}
  end

  @impl true
  def handle_cast({:update_battery_level, level}, state) do
    {:noreply, Map.put(state, :battery_level, level)}
  end

  # Scheduled

  @impl true
  def handle_cast({:scheduled, datetime}, %{is_plugged: true, is_home: true} = state) do
    diff_before_scheduled =
      DateTime.diff(datetime, DateTime.utc_now(), :millisecond)

    scheduling =
      if diff_before_scheduled > 0 do
        Logger.debug("[State] Schedule a message to test whether the car is charging.")

        Queue.publish_request(Philips.get_pending_status_request())

        timer =
          ProcessFacade.send_after(
            __MODULE__,
            :no_power,
            diff_before_scheduled + 1 * 60 * 1000
          )

        {:ok, timer}
      else
        :skip
      end

    case scheduling do
      {:ok, timer} ->
        {:noreply,
         state
         |> try_cancel_timer()
         |> Map.put(:state, :scheduled)
         |> Map.put(:timer, timer)}

      :skip ->
        {:noreply,
         state
         |> try_cancel_timer()
         |> Map.put(:state, :scheduled)}
    end
  end

  # Fallback

  @impl true
  def handle_cast(message, %{state: :unknown} = state) do
    Logger.info("[State] Any messages from unknown are ignored: #{inspect(message)}")

    {:noreply, state}
  end

  @impl true
  def handle_cast(message, %{state: car_state} = state) do
    Logger.error(
      "[State] Transition not supported: #{inspect(message)}, current state: #{car_state}"
    )

    {:noreply, state}
  end

  # Private

  defp logger_level_to_genserver_level(:none), do: :trace
  defp logger_level_to_genserver_level(:debug), do: :trace
  defp logger_level_to_genserver_level(:info), do: :log
  defp logger_level_to_genserver_level(:warning), do: :none
  defp logger_level_to_genserver_level(:error), do: :none

  defp initial_state(), do: %{state: :unknown, is_home: false, is_plugged: false}

  defp try_cancel_timer(%{timer: timer} = state) do
    %{state: s} = state

    if ProcessFacade.cancel_timer(timer) != false,
      do:
        Logger.debug(
          "[State] Cancelled the timer of the geofence state to determine the charging status from #{s}."
        )

    Map.delete(state, :timer)
  end

  defp try_cancel_timer(state) when is_map(state), do: state

  defp is_light_supported() do
    with request <- Philips.get_devices_information_request(),
         %HttpRequest{url: u, method: m} <- request,
         {:ok, response} <- HueBridgeClient.request(method: m, url: u),
         %Tesla.Env{status: 200, body: content} <- response,
         {:ok, devices} <- try_get_devices(content),
         {:ok, light} <- try_find_light(devices),
         {:ok, id} <- try_get_model_id(light) do
      {:ok, "The light #{id} is valid and will be used."}
    else
      %Tesla.Env{status: status} ->
        {:error, "An invalid HTTP status was received from the hue bridge: #{status}"}
    end
  end

  defp try_get_devices(%{"data" => devices}) when is_list(devices), do: {:ok, devices}

  defp try_get_devices(_payload),
    do: {:error, "The devices was not found from the payload returned."}

  defp try_get_model_id(%{"product_data" => %{"model_id" => id}}),
    do: {:ok, id}

  defp try_get_model_id(_device),
    do: {:errr, "Cannot found the model id from the device payload."}

  defp try_find_light(devices) when is_list(devices) do
    lights =
      devices
      |> Stream.map(&is_my_light/1)
      |> Stream.each(fn result ->
        if match?({:error, _}, result) do
          {:error, reason} = result
          Logger.info("[State] #{reason}")
        end

        result
      end)
      |> Stream.filter(&match?({:ok, _}, &1))
      |> Stream.map(fn {:ok, x} -> x end)
      |> Enum.to_list()

    with [light] <- lights do
      {:ok, light}
    else
      [_] -> {:error, "More than 1 light matches the given environment variable HUE_LIGHT_ID."}
      [] -> {:error, "No light matches the given environment variable HUE_LIGHT_ID"}
      :error -> {:error, "Make sure the environment variable HUE_LIGHT_ID was correctly set."}
    end
  end

  defp is_my_light(
         %{"product_data" => %{"product_archetype" => "hue_signe"}, "services" => services} =
           light
       ) do
    with {:ok, light_id} <-
           Application.fetch_env(
             :teslamate_philips_hue_gradient_signe_table_lamp,
             :hue_signe_gradient_lamp_id
           ),
         true <-
           services
           |> Stream.filter(fn %{"rtype" => x} -> String.equivalent?(x, "light") end)
           |> Stream.filter(fn %{"rid" => x} -> String.equivalent?(x, light_id) end)
           |> Enum.any?() do
      {:ok, light}
    else
      false -> {:error, "The light was not found."}
      :error -> {:error, "Make sure the environment variable HUE_LIGHT_ID was correctly set."}
    end
  end

  defp is_my_light(%{"product_data" => %{"product_archetype" => type, "model_id" => id}}),
    do: {:error, "The device #{id} is invalid because the type #{type} is not supported."}
end
