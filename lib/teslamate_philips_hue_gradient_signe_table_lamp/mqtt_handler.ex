defmodule TeslamatePhilipsHueGradientSigneTableLamp.MqttHandler do
  use Tortoise311.Handler

  alias TeslamatePhilipsHueGradientSigneTableLamp.States

  require Logger

  # Callbacks

  @impl true
  def init(_args) do
    {:ok, %{}}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "geofence"] = topic_levels,
        nil,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} <nil>")
    States.unknown()

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "geofence"] = topic_levels,
        payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")

    with {:ok, _} <- is_home_geofence(payload) do
      States.home_geofence_detected()
    else
      {:skip, geofence} ->
        Logger.debug("Received a geofence for the place: #{geofence}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("[MQTT] #{reason}")
    end

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "plugged_in"] = topic_levels,
        "true" = payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")
    States.plugged()

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "plugged_in"] = topic_levels,
        "false" = payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")
    States.unplugged()

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "charging_state"] = topic_levels,
        "Charging" = payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")
    States.charging()

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "charging_state"] = topic_levels,
        "Stopped" = payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")
    States.stopped()

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "charging_state"] = topic_levels,
        "Complete" = payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")
    States.complete()

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "charging_state"] = topic_levels,
        "NoPower" = payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")
    States.no_power()

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "scheduled_charging_start_time"] = topic_levels,
        payload,
        state
      )
      when not is_nil(payload) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")

    with {:ok, scheduled_datetime, _} <- DateTime.from_iso8601(payload) do
      States.scheduled(scheduled_datetime)
    else
      {:error, reason} -> Logger.error("[State] #{reason}")
    end

    {:ok, state}
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "usable_battery_level"] = topic_levels,
        payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")

    with {level, _} <- Integer.parse(payload) do
      States.update_battery_level(level)
      {:ok, state}
    else
      :error -> {:ok, state}
    end
  end

  @impl true
  def handle_message(
        ["teslamate", "cars", _, "battery_level"] = topic_levels,
        payload,
        state
      ) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")

    with {level, _} <- Integer.parse(payload) do
      States.update_battery_level(level)
      {:ok, state}
    else
      :error -> {:ok, state}
    end
  end

  @impl true
  def handle_message(topic_levels, payload, state) do
    Logger.debug("[MQTT] #{Enum.join(topic_levels, "/")} #{payload}")
    {:ok, state}
  end

  @impl true
  def subscription(status, topic_filter, state) do
    Logger.debug("[MQTT] #{inspect(status)}: #{topic_filter}")
    {:ok, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.debug("[MQTT] Terminated because #{inspect(reason)}.")
  end

  # Private

  defp is_home_geofence(geofence_name) do
    with {:ok, geofence} <-
           Application.fetch_env(
             :teslamate_philips_hue_gradient_signe_table_lamp,
             :geofence_home_name
           ),
         true <- geofence == geofence_name do
      {:ok, geofence}
    else
      false -> {:skip, geofence_name}
      _ -> {:error, "The geofence home name was not configured."}
    end
  end
end
