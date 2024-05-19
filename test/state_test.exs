defmodule StatesTest do
  use ExUnit.Case

  import Mock

  alias TeslamatePhilipsHueGradientSigneTableLamp.HttpRequest
  alias TeslamatePhilipsHueGradientSigneTableLamp.States
  alias TeslamatePhilipsHueGradientSigneTableLamp.Queue
  alias TeslamatePhilipsHueGradientSigneTableLamp.Philips

  test "when the car is getting to Home" do
    with_mocks [
      {Queue, [], [publish_request: fn _ -> :ok end]},
      {Philips, [], get_geofence_detected_request: fn -> %HttpRequest{method: :get, url: ""} end},
      {Process, [], send_after: fn _, _, _ -> :ok end}
    ] do
      actual = States.handle_cast(:geofence_detected, %{state: :unknown})

      assert match?({:noreply, _}, actual)

      {:noreply, new_state} = actual

      assert new_state.state == :geofence_detected
    end
  end
end
