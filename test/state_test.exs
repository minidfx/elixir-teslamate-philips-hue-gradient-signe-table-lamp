defmodule StatesTest do
  use ExUnit.Case

  import Mock

  alias TeslamatePhilipsHueGradientSigneTableLamp.HttpRequest
  alias TeslamatePhilipsHueGradientSigneTableLamp.Philips
  alias TeslamatePhilipsHueGradientSigneTableLamp.ProcessFacade
  alias TeslamatePhilipsHueGradientSigneTableLamp.Queue
  alias TeslamatePhilipsHueGradientSigneTableLamp.States

  test "when the car is scheduled from an unknown state" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {ProcessFacade, [], send_after: fn _, _, _ -> :ok end}
    ] do
      scheduled_datetime = DateTime.new!(~D"2024-01-01", ~T"22:00:00")
      _actual = States.handle_cast({:scheduled, scheduled_datetime}, %{state: :unknown})

      assert_not_called(ProcessFacade.send_after(:_, :_, :_))
      assert_not_called(Queue.publish_request())
    end
  end

  test "when the car is scheduled at home and plugged in" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {Philips, [], get_pending_status_request: fn -> %HttpRequest{method: :get, url: ""} end},
      {ProcessFacade, [], send_after: fn _, _, _ -> :ok end},
      {DateTime, [],
       [
         utc_now: fn -> ~U[2024-01-01 18:00:00Z] end,
         add: fn a, b, c -> passthrough([a, b, c]) end,
         diff: fn a, b, c -> passthrough([a, b, c]) end,
         before?: fn a, b -> passthrough([a, b]) end
       ]}
    ] do
      scheduled_datetime = ~U[2024-01-01 22:00:00Z]

      _actual =
        States.handle_cast({:scheduled, scheduled_datetime}, %{is_plugged: true, is_home: true})

      assert_called_exactly(ProcessFacade.send_after(:_, :_, :_), 1)

      assert_called_exactly(
        ProcessFacade.send_after(
          :_,
          :_,
          4 * 60 * 60 * 1000 + 1 * 60 * 1000
        ),
        1
      )

      assert_called_exactly(Queue.publish_request(:_), 1)
    end
  end
end
