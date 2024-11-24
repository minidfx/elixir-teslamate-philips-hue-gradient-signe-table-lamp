defmodule StatesTest do
  use ExUnit.Case, async: false
  use TeslamatePhilipsHueGradientSigneTableLamp.Logger

  import Mock

  alias TeslamatePhilipsHueGradientSigneTableLamp.HueAnimation
  alias TeslamatePhilipsHueGradientSigneTableLamp.Philips
  alias TeslamatePhilipsHueGradientSigneTableLamp.ProcessFacade
  alias TeslamatePhilipsHueGradientSigneTableLamp.Queue
  alias TeslamatePhilipsHueGradientSigneTableLamp.States

  setup do
    _pid = start_link_supervised!({States, %{test: true}})
    :ok
  end

  test "does not send requests or schedule timers when the car is charging" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end}
    ] do
      States.charging()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_not_called(Queue.publish_request(:_))
      assert_not_called(ProcessFacade.send_after(:_, :_, :_))
      assert_not_called(Philips.get_pending_status_request())
    end
  end

  test "sends requests and schedules timers when the car is at home" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end}
    ] do
      States.home_geofence_detected()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
    end
  end

  test "handles scheduled charging when the car is at home, plugged in, and has a saved schedule" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         red_get_battery_state_request: fn _ -> :ok end
       ]},
      {DateTime, [],
       [
         utc_now: fn ->
           Process.get(:utc_calls_count, 0)
           |> then(&Process.put(:utc_calls_count, &1 + 1))
           |> then(
             &Enum.at(
               [~U"2024-01-01T00:00:00Z", ~U"2024-01-01T08:00:00Z"],
               if(&1 == nil, do: 0, else: &1)
             )
           )
           |> tap(&Logger.debug("#{inspect(&1)}"))
         end,
         diff: fn a, b, c -> passthrough([a, b, c]) end,
         before?: fn a, b -> passthrough([a, b]) end
       ]}
    ] do
      States.scheduled(~U"2024-01-01T10:00:00Z")
      States.home_geofence_detected()
      States.plugged()
      States.no_power()
      States.stopped()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 10 * 60 * 60 * 1000 + 10_000), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)

      assert_not_called(Philips.red_get_battery_state_request(:_))
    end
  end

  test "sends green state request when car is at home, plugged in, and battery level exceeds saved SOC level" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         red_get_battery_state_request: fn _ -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end
       ]},
      {DateTime, [],
       [
         utc_now: fn -> ~U"2024-01-01T10:00:00Z" end,
         diff: fn a, b, c -> passthrough([a, b, c]) end,
         before?: fn a, b -> passthrough([a, b]) end
       ]}
    ] do
      States.update_soc(70)
      States.update_battery_level(71)
      States.home_geofence_detected()
      States.plugged()
      States.no_power()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 2)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(Philips.green_get_battery_state_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)

      assert_not_called(Philips.red_get_battery_state_request(:_))
    end
  end

  test "does not send green or red state request when car is at home, plugged in, and battery level is below saved SOC level" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         red_get_battery_state_request: fn _ -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end
       ]},
      {DateTime, [],
       [
         utc_now: fn -> ~U"2024-01-01T10:00:00Z" end,
         diff: fn a, b, c -> passthrough([a, b, c]) end,
         before?: fn a, b -> passthrough([a, b]) end
       ]}
    ] do
      States.update_soc(70)
      States.update_battery_level(69)
      States.home_geofence_detected()
      States.plugged()
      States.no_power()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)

      assert_not_called(Philips.red_get_battery_state_request(:_))
      assert_not_called(Philips.green_get_battery_state_request(:_))
    end
  end

  test "handles scheduled charging and cancels timers when the car is at home, plugged in, and charging" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end},
      {DateTime, [],
       [
         utc_now: fn -> ~U"2024-01-01T10:00:00Z" end,
         diff: fn a, b, c -> passthrough([a, b, c]) end
       ]},
      {HueAnimation, [], charging: fn -> :ok end}
    ] do
      States.scheduled(~U"2024-01-01T12:00:00Z")
      States.home_geofence_detected()
      States.plugged()
      States.no_power()
      States.charging()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 2 * 60 * 60 * 1000 + 10_000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
    end
  end

  test "ignores duplicate home geofence messages from Teslamate" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end}
    ] do
      States.home_geofence_detected()
      States.home_geofence_detected()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
    end
  end

  test "ignores duplicate plugged messages from Teslamate" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end}
    ] do
      States.home_geofence_detected()
      States.plugged()
      States.plugged()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
    end
  end

  test "handles charging state when the car is at home and plugged in" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end},
      {HueAnimation, [], charging: fn -> :ok end}
    ] do
      States.home_geofence_detected()
      States.plugged()
      States.no_power()
      States.charging()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
    end
  end

  test "handles charging state when the car is at home and plugged in but messages arrive out of order" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end},
      {HueAnimation, [], charging: fn -> :ok end}
    ] do
      States.home_geofence_detected()
      States.charging()
      States.plugged()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
    end
  end

  test "handles charging state with duplicate plugged message and out-of-order events" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [], get_pending_status_request: fn -> :ok end},
      {HueAnimation, [], charging: fn -> :ok end}
    ] do
      States.home_geofence_detected()
      States.charging()
      States.plugged()
      States.plugged()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
    end
  end

  test "handles completion when car reaches expected level at home and plugged in" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end
       ]},
      {HueAnimation, [], [charging: fn -> :ok end, clear: fn -> :ok end]}
    ] do
      States.home_geofence_detected()
      States.plugged()
      States.no_power()
      States.charging()
      States.complete()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 2)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
      assert_called_exactly(HueAnimation.clear(), 1)
    end
  end

  test "handles state transition when car leaves home directly from home geofence" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         get_unknown_state_request: fn -> :ok end
       ]}
    ] do
      States.home_geofence_detected()
      States.unknown()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 2)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
    end
  end

  test "handles car state transition from home, plugged in, charging, complete to unknown state after leaving home" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end,
         get_unknown_state_request: fn -> :ok end
       ]},
      {HueAnimation, [], [charging: fn -> :ok end, clear: fn -> :ok end]}
    ] do
      States.home_geofence_detected()
      States.plugged()
      States.no_power()
      States.charging()
      States.complete()
      States.unknown()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 3)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 5 * 60 * 1000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
      assert_called_exactly(HueAnimation.clear(), 1)
    end
  end

  test "handles car state transition from home, plugged in, stopped waiting for schedule, charging at scheduled time, and then complete" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end,
         get_unknown_state_request: fn -> :ok end
       ]},
      {HueAnimation, [], [charging: fn -> :ok end, clear: fn -> :ok end]},
      {DateTime, [],
       [
         utc_now: fn ->
           Process.get(:utc_calls_count, 0)
           |> then(&Process.put(:utc_calls_count, &1 + 1))
           |> then(
             &Enum.at(
               [~U"2024-01-01T00:00:00Z", ~U"2024-01-01T08:00:00Z"],
               if(&1 == nil, do: 0, else: &1)
             )
           )
         end,
         diff: fn a, b, c -> passthrough([a, b, c]) end,
         before?: fn a, b -> passthrough([a, b]) end
       ]}
    ] do
      States.scheduled(~U"2024-01-01T10:00:00Z")
      States.home_geofence_detected()
      States.no_power()
      States.plugged()
      States.stopped()
      States.charging()
      States.complete()
      States.unknown()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 3)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 10 * 60 * 60 * 1000 + 10_000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(Philips.green_get_battery_state_request(:_), 1)
      assert_called_exactly(Philips.get_unknown_state_request(), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
      assert_called_exactly(HueAnimation.clear(), 1)
    end
  end

  test "handles car state transition from home, plugged in, stopped waiting for schedule, charging at scheduled time, and then stopped while charging" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end,
         red_get_battery_state_request: fn _ -> :ok end,
         get_unknown_state_request: fn -> :ok end
       ]},
      {HueAnimation, [], [charging: fn -> :ok end, clear: fn -> :ok end]},
      {DateTime, [],
       [
         utc_now: fn ->
           Process.get(:utc_calls_count, 0)
           |> then(&Process.put(:utc_calls_count, &1 + 1))
           |> then(
             &Enum.at(
               [~U"2024-01-01T00:00:00Z", ~U"2024-01-01T08:00:00Z", ~U"2024-01-01T10:15:00Z"],
               if(&1 == nil, do: 0, else: &1)
             )
           )
         end,
         diff: fn a, b, c -> passthrough([a, b, c]) end,
         before?: fn a, b -> passthrough([a, b]) end
       ]}
    ] do
      States.scheduled(~U"2024-01-01T10:00:00Z")
      States.home_geofence_detected()
      States.plugged()
      States.no_power()
      States.stopped()
      States.charging()
      States.stopped()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 2)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 10 * 60 * 60 * 1000 + 10_000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(Philips.red_get_battery_state_request(:_), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
      assert_called_exactly(HueAnimation.clear(), 1)

      assert_not_called(Philips.green_get_battery_state_request(:_))
    end
  end

  test "handles car state transition from home, plugged in, stopped waiting for schedule, charging at scheduled time, and then no power while charging" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [],
       [
         send_after: fn _, _, _ -> :ok end,
         cancel_timer: fn _ -> :ok end
       ]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end,
         red_get_battery_state_request: fn _ -> :ok end,
         get_unknown_state_request: fn -> :ok end
       ]},
      {HueAnimation, [], [charging: fn -> :ok end, clear: fn -> :ok end]},
      {DateTime, [],
       [
         utc_now: fn ->
           Process.get(:utc_calls_count, 0)
           |> then(&Process.put(:utc_calls_count, &1 + 1))
           |> then(
             &Enum.at(
               [~U"2024-01-01T00:00:00Z", ~U"2024-01-01T08:00:00Z", ~U"2024-01-01T10:15:00Z"],
               if(&1 == nil, do: 0, else: &1)
             )
           )
         end,
         diff: fn a, b, c -> passthrough([a, b, c]) end,
         before?: fn a, b -> passthrough([a, b]) end
       ]}
    ] do
      States.scheduled(~U"2024-01-01T10:00:00Z")
      States.home_geofence_detected()
      States.plugged()
      States.no_power()
      States.stopped()
      States.charging()
      States.no_power()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 2)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :no_power, 10 * 60 * 60 * 1000 + 10_000), 1)
      assert_called_exactly(ProcessFacade.cancel_timer(:_), 1)
      assert_called_exactly(Philips.get_pending_status_request(), 1)
      assert_called_exactly(Philips.red_get_battery_state_request(:_), 1)
      assert_called_exactly(HueAnimation.charging(), 1)
      assert_called_exactly(HueAnimation.clear(), 1)

      assert_not_called(Philips.green_get_battery_state_request(:_))
    end
  end
end
