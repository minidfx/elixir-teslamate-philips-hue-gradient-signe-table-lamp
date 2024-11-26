defmodule TeslamatePhilipsHueGradientSigneTableLamp.States do
  use GenServer
  use TeslamatePhilipsHueGradientSigneTableLamp.Logger

  alias TeslamatePhilipsHueGradientSigneTableLamp.HttpRequest
  alias TeslamatePhilipsHueGradientSigneTableLamp.HueAnimation
  alias TeslamatePhilipsHueGradientSigneTableLamp.HueBridgeClient
  alias TeslamatePhilipsHueGradientSigneTableLamp.Philips
  alias TeslamatePhilipsHueGradientSigneTableLamp.ProcessFacade
  alias TeslamatePhilipsHueGradientSigneTableLamp.Queue

  @type state ::
          :unknown
          | :home
          | :plugged
          | :charging
          | :unplugged
          | :stopped
          | :complete
          | :no_power
  @type server_state :: %{
          state: state(),
          is_plugged: boolean(),
          is_home: boolean(),
          schedule: DateTime.t() | nil,
          battery_level: integer() | nil,
          soc_level: integer() | nil
        }

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

  def start_link(%{test: true}) do
    GenServer.start_link(__MODULE__, Map.put(initial_state(), :test, true), name: __MODULE__)
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
  def charging(), do: GenServer.cast(__MODULE__, :charging)

  @spec unplugged() :: :ok
  def unplugged(), do: GenServer.cast(__MODULE__, :unplugged)

  @spec no_power() :: :ok
  def no_power(), do: GenServer.cast(__MODULE__, :no_power)

  @spec unknown() :: :ok
  def unknown(), do: GenServer.cast(__MODULE__, :unknown)

  @spec scheduled(DateTime.t()) :: :ok
  def scheduled(datetime) when is_struct(datetime, DateTime),
    do: GenServer.cast(__MODULE__, {:scheduled, datetime})

  @spec scheduled(nil) :: :ok
  def scheduled(nil),
    do: GenServer.cast(__MODULE__, :clear_schedule)

  @spec update_battery_level(integer()) :: :ok
  def update_battery_level(level) when level in 0..100,
    do: GenServer.cast(__MODULE__, {:update_battery_level, level})

  @spec update_soc(integer()) :: :ok
  def update_soc(level) when level in 0..100,
    do: GenServer.cast(__MODULE__, {:update_soc, level})

  # Callbacks

  @impl true
  def init(%{test: true} = args) do
    {:ok, args}
  end

  @impl true
  def init(args) do
    Logger.debug("Initializing ...")

    with {:ok, message} <- is_light_supported(),
         request <- Philips.get_unknown_state_request() do
      Logger.info(message)
      Queue.publish_request(request)
      {:ok, args}
    else
      {:error, reason} ->
        Logger.error(reason)
        {:stop, "Cannot contact the HueBridge."}
    end
  end

  # NoPower from the timer

  @impl true

  def handle_info(:no_power, %{is_home: true, timer: _timer} = state) do
    {:noreply,
     state
     |> try_clear_timer()
     |> publish_red_level()
     |> Map.put(:state, :no_power)}
  end

  @impl true
  def handle_info(message, %{state: car_state} = state) do
    Logger.error("Transition not supported: #{inspect(message)}, current state: #{car_state}")

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
    Logger.debug("Scheduling a timeout to make sure that the car is charging after #{@default_timer_duration_ms}")

    Queue.publish_request(Philips.get_pending_status_request())

    {:noreply,
     state
     |> try_schedule_no_power_trigger()
     |> Map.put(:state, :home)
     |> Map.put(:is_home, true)}
  end

  @impl true
  def handle_cast(:home, %{is_home: true} = state) do
    {:noreply, state}
  end

  # NoPower

  @impl true
  def handle_cast(
        :no_power,
        %{
          state: s,
          is_home: true,
          battery_level: b_level,
          soc_level: s_level
        } = state
      )
      when s in [:home, :plugged, :charging, :stopped] and
             not is_nil(b_level) and
             not is_nil(s_level) and
             b_level >= s_level do
    HueAnimation.clear()

    {:noreply, Map.put(state, :state, :no_power)}
  end

  @impl true
  def handle_cast(:no_power, %{state: s, is_home: true} = state)
      when s in [:home, :plugged, :stopped] do
    {:noreply, Map.put(state, :state, :no_power)}
  end

  @impl true
  def handle_cast(:no_power, %{state: s, is_home: true} = state)
      when s in [:charging] do
    HueAnimation.clear()

    {:noreply,
     state
     |> publish_red_level()
     |> Map.put(:state, :no_power)}
  end

  # Plugged

  @impl true
  def handle_cast(:plugged, %{is_home: true, state: :charging} = state) do
    {:noreply, Map.put(state, :is_plugged, true)}
  end

  @impl true
  def handle_cast(
        :plugged,
        %{
          is_plugged: false,
          is_home: true,
          battery_level: b_level,
          soc_level: s_level
        } = state
      )
      when not is_nil(b_level) and
             not is_nil(s_level) and
             b_level >= s_level do
    {:noreply,
     state
     |> try_cancel_timer()
     |> publish_green_level()
     |> Map.put(:state, :plugged)
     |> Map.put(:is_plugged, true)}
  end

  @impl true
  def handle_cast(:plugged, %{is_plugged: false, is_home: true} = state) do
    {:noreply,
     state
     |> Map.put(:state, :plugged)
     |> Map.put(:is_plugged, true)}
  end

  @impl true
  def handle_cast(:plugged, %{is_plugged: true, is_home: true} = state) do
    {:noreply, state}
  end

  # Unplugged

  @impl true
  def handle_cast(:unplugged, %{is_plugged: true} = state) do
    HueAnimation.clear()

    {:noreply,
     state
     |> try_cancel_timer()
     |> publish_red_level()
     |> Map.put(:state, :unplugged)}
  end

  # Charging

  @impl true
  def handle_cast(:charging, %{is_home: true} = state) do
    HueAnimation.charging()

    {:noreply,
     state
     |> try_cancel_timer()
     |> Map.put(:state, :charging)}
  end

  # Stopped

  @impl true
  def handle_cast(:stopped, %{is_plugged: true, is_home: true, schedule: schedule, state: :charging} = state) do
    HueAnimation.clear()
    now = DateTime.utc_now()

    state =
      if(DateTime.before?(now, schedule)) do
        Queue.publish_request(Philips.get_pending_status_request())
        state
      else
        publish_red_level(state)
      end

    {:noreply, Map.put(state, :state, :stopped)}
  end

  @impl true
  def handle_cast(:stopped, %{is_plugged: true, is_home: true, schedule: schedule} = state) do
    now = DateTime.utc_now()

    if(DateTime.before?(now, schedule)) do
      {:noreply, Map.put(state, :state, :stopped)}
    else
      HueAnimation.clear()

      {:noreply,
       state
       |> publish_red_level()
       |> Map.put(:state, :stopped)}
    end
  end

  @impl true
  def handle_cast(:stopped, %{is_plugged: true, is_home: true} = state) do
    HueAnimation.clear()

    {:noreply,
     state
     |> publish_red_level()
     |> Map.put(:state, :stopped)}
  end

  # Complete

  @impl true
  def handle_cast(:complete, %{is_home: true} = state) do
    HueAnimation.clear()

    {:noreply,
     state
     |> try_cancel_timer()
     |> publish_green_level()
     |> Map.put(:state, :complete)}
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
  def handle_cast({:update_battery_level, level}, %{is_home: true, state: :complete} = state) do
    level
    |> Philips.green_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply, Map.put(state, :battery_level, level)}
  end

  @impl true
  def handle_cast({:update_battery_level, level}, %{timer: _} = state) do
    {:noreply, Map.put(state, :battery_level, level)}
  end

  @impl true
  def handle_cast({:update_battery_level, level}, %{is_home: true, state: s} = state)
      when s in [:stopped, :unplugged, :no_power] do
    level
    |> Philips.red_get_battery_state_request()
    |> Queue.publish_request()

    {:noreply, Map.put(state, :battery_level, level)}
  end

  @impl true
  def handle_cast({:update_battery_level, level}, state) do
    {:noreply, Map.put(state, :battery_level, level)}
  end

  # Update SOC

  @impl true
  def handle_cast({:update_soc, level}, state) do
    {:noreply, Map.put(state, :soc_level, level)}
  end

  # Scheduled

  @impl true
  def handle_cast(:clear_schedule, state) do
    Logger.debug("Clearing the charge scheduled ...")

    {:noreply,
     state
     |> try_cancel_timer()
     |> try_clear_schedule()}
  end

  @impl true
  def handle_cast({:scheduled, datetime}, state) do
    Logger.debug("Saving the charge scheduled #{inspect(datetime)} ...")

    {:noreply, Map.put(state, :schedule, datetime)}
  end

  # Fallback

  @impl true
  def handle_cast(message, %{state: :unknown} = state) do
    Logger.info("Any messages from unknown are ignored: #{inspect(message)}")

    {:noreply, state}
  end

  @impl true
  def handle_cast(message, %{state: car_state} = state) do
    Logger.error("Transition not supported: #{inspect(message)}, current state: #{car_state}")

    {:noreply, state}
  end

  # Private

  defp publish_green_level(%{battery_level: level} = state) do
    level
    |> Philips.green_get_battery_state_request()
    |> Queue.publish_request()

    state
  end

  defp publish_green_level(%{} = state) do
    100
    |> Philips.green_get_battery_state_request()
    |> Queue.publish_request()

    state
  end

  defp publish_red_level(%{battery_level: level} = state) do
    level
    |> Philips.red_get_battery_state_request()
    |> Queue.publish_request()

    state
  end

  defp publish_red_level(%{} = state) do
    100
    |> Philips.red_get_battery_state_request()
    |> Queue.publish_request()

    state
  end

  defp try_schedule_no_power_trigger(%{timer: _} = state) do
    state
  end

  defp try_schedule_no_power_trigger(state) do
    try_schedule_no_power_trigger(state, DateTime.utc_now())
  end

  defp try_schedule_no_power_trigger(%{schedule: schedule} = state, %DateTime{} = now) do
    with remaining_time_to_schedule <- DateTime.diff(schedule, now, :second),
         :ok <- if(remaining_time_to_schedule > 0, do: :ok, else: :skip) do
      Logger.debug("Schedule a timer at the schedule time #{schedule} to cast a :no_power message")

      timer =
        ProcessFacade.send_after(
          __MODULE__,
          :no_power,
          (remaining_time_to_schedule + 10) * 1000
        )

      state
      |> try_cancel_timer()
      |> Map.put(:timer, timer)
    else
      _ ->
        Logger.debug("Invalid schedule date, cannot schedule a timer to #{inspect(schedule)} before now #{now}")

        state
        |> try_clear_schedule()
        |> try_schedule_no_power_trigger(now)
    end
  end

  defp try_schedule_no_power_trigger(state, _) do
    Logger.debug(
      "Schedule a timer in #{trunc(@default_timer_duration_ms / 1000 / 60)} minutes to cast :no_power message"
    )

    timer = ProcessFacade.send_after(__MODULE__, :no_power, @default_timer_duration_ms)

    state
    |> try_cancel_timer()
    |> Map.put(:timer, timer)
  end

  defp logger_level_to_genserver_level(:none), do: :trace
  defp logger_level_to_genserver_level(:debug), do: :trace
  defp logger_level_to_genserver_level(:info), do: :log
  defp logger_level_to_genserver_level(:warning), do: :none
  defp logger_level_to_genserver_level(:error), do: :none

  defp initial_state(), do: %{state: :unknown, is_home: false, is_plugged: false}

  defp try_clear_timer(%{timer: _} = state), do: Map.delete(state, :timer)
  defp try_clear_timer(%{} = state), do: state

  defp try_clear_schedule(%{schedule: _} = state), do: Map.delete(state, :schedule)
  defp try_clear_schedule(%{} = state), do: state

  defp try_cancel_timer(%{timer: timer} = state) do
    %{state: s} = state

    if ProcessFacade.cancel_timer(timer) != false,
      do: Logger.debug("Cancelled the timer of the geofence state to determine the charging status from #{s}.")

    try_clear_timer(state)
  end

  defp try_cancel_timer(%{} = state), do: state

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

      error ->
        {:error, "an unknown error occurred: #{inspect(error)}"}
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
          Logger.info(reason)
        end
      end)
      |> Stream.filter(&match?({:ok, _}, &1))
      |> Stream.map(fn {:ok, x} -> x end)
      |> Enum.to_list()

    with [light] <- lights do
      {:ok, light}
    else
      [_] -> {:error, "More than 1 light matches the given environment variable HUE_LIGHT_ID."}
      [] -> {:error, "No light matches the given environment variable HUE_LIGHT_ID"}
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
