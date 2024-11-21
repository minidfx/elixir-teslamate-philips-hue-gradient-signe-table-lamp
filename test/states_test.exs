defmodule StatesTest do
  use ExUnit.Case, async: false

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

  test "when the car is at home" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], send_after: fn _, _, _ -> :ok end},
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

  test "when the car is at home, plugged in and has a schedule saved" do
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
       ]}
    ] do
      States.scheduled(~U"2024-01-01T12:00:00Z")
      States.home_geofence_detected()
      States.plugged()

      # HACK: Waiting for the process state
      :sys.get_state(States)

      assert_called_exactly(Queue.publish_request(:_), 1)
      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)

      assert_called_exactly(
        ProcessFacade.send_after(:_, :no_power, 2 * 60 * 60 * 1000 + 10_000),
        1
      )

      assert_not_called(ProcessFacade.cancel_timer(:_))
      assert_called_exactly(Philips.get_pending_status_request(), 1)
    end
  end

  test "when the car is at home, plugged in, with a schedule saved and the charge is running" do
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

  test "when we received a duplicate home geofence message from Teslamate" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], send_after: fn _, _, _ -> :ok end},
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

  test "when we received a duplicate plugged message from Teslamate" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], send_after: fn _, _, _ -> :ok end},
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

  test "when the car is at home, plugged in and it is charging" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], [send_after: fn _, _, _ -> :ok end, cancel_timer: fn _ -> :ok end]},
      {Philips, [], get_pending_status_request: fn -> :ok end},
      {HueAnimation, [], charging: fn -> :ok end}
    ] do
      States.home_geofence_detected()
      States.plugged()
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

  test "when the car is at home, plugged in, it is charging but not in right order" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], [send_after: fn _, _, _ -> :ok end, cancel_timer: fn _ -> :ok end]},
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

  test "when the car is at home, plugged in, it is charging but not in right order and received duplicate plugged message from Teslamate" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], [send_after: fn _, _, _ -> :ok end, cancel_timer: fn _ -> :ok end]},
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

  test "when the car is at home, plugged in, it has reached expected level" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], [send_after: fn _, _, _ -> :ok end, cancel_timer: fn _ -> :ok end]},
      {Philips, [],
       [
         get_pending_status_request: fn -> :ok end,
         green_get_battery_state_request: fn _ -> :ok end
       ]},
      {HueAnimation, [], [charging: fn -> :ok end, clear: fn -> :ok end]}
    ] do
      States.home_geofence_detected()
      States.plugged()
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
end
