defmodule TeslamatePhilipsHueGradientSigneTableLamp.Philips do
  alias TeslamatePhilipsHueGradientSigneTableLamp.Color
  alias TeslamatePhilipsHueGradientSigneTableLamp.Colors
  alias TeslamatePhilipsHueGradientSigneTableLamp.HttpRequest

  @count_pixels 4
  @default_background_color "E0E479"

  @spec get_pending_status_request() :: HttpRequest.t()
  def get_pending_status_request() do
    light_id =
      Application.fetch_env!(
        :teslamate_philips_hue_gradient_signe_table_lamp,
        :hue_signe_gradient_lamp_id
      )

    %HttpRequest{
      method: :put,
      url: "/resource/light/#{light_id}",
      body: %{
        on: %{on: true},
        gradient: %{
          points: Enum.map(1..@count_pixels, fn _ -> blue() end)
        }
      }
    }
  end

  @spec get_unknown_state_request() :: HttpRequest.t()
  def get_unknown_state_request() do
    light_id =
      Application.fetch_env!(
        :teslamate_philips_hue_gradient_signe_table_lamp,
        :hue_signe_gradient_lamp_id
      )

    %HttpRequest{
      method: :put,
      url: "/resource/light/#{light_id}",
      body: %{
        on: %{on: false}
      }
    }
  end

  @spec get_charging_state_request(1 | 2 | 3 | 4) :: HttpRequest.t()
  def get_charging_state_request(pixel) when pixel in 1..@count_pixels do
    light_id =
      Application.fetch_env!(
        :teslamate_philips_hue_gradient_signe_table_lamp,
        :hue_signe_gradient_lamp_id
      )

    %HttpRequest{
      method: :put,
      url: "/resource/light/#{light_id}",
      body: %{
        gradient: %{
          points: Enum.map(1..@count_pixels, &if(pixel == &1, do: green(90), else: green()))
        }
      }
    }
  end

  @spec get_devices_information_request() :: HttpRequest.t()
  def get_devices_information_request() do
    %HttpRequest{
      method: :get,
      url: "/resource/device"
    }
  end

  @spec red_get_battery_state_request(integer()) :: HttpRequest.t()
  def red_get_battery_state_request(level) when level in 0..100,
    do: internal_get_battery_state_request(:red, level)

  @spec green_get_battery_state_request(integer()) :: HttpRequest.t()
  def green_get_battery_state_request(level) when level in 0..100,
    do: internal_get_battery_state_request(:green, level)

  @spec red() :: Color.t()
  def red(),
    do:
      Colors.rgb_to_xy(:red)
      |> Color.create()

  @spec green() :: Color.t()
  def green(),
    do:
      Colors.rgb_to_xy(:green)
      |> Color.create()

  @spec green(integer()) :: Color.t()
  def green(saturation),
    do:
      Colors.hsv_to_xy(:green, compute_partial_pixel_saturation(saturation), 100)
      |> Color.create()

  @spec blue() :: Color.t()
  def blue(),
    do:
      Colors.rgb_to_xy(:blue)
      |> Color.create()

  @spec white() :: Color.t()
  def white(),
    do:
      Colors.rgb_to_xy(:white)
      |> Color.create()

  @spec orange() :: Color.t()
  def orange(),
    do:
      Colors.rgb_to_xy(:orange)
      |> Color.create()

  # Private

  defp internal_get_battery_state_request(color, 100) do
    Enum.map(
      [
        Colors.rgb_to_xy(color),
        Colors.rgb_to_xy(color),
        Colors.rgb_to_xy(color),
        Colors.rgb_to_xy(color)
      ],
      &Color.create/1
    )
    |> internal_get_battery_state_request()
  end

  defp internal_get_battery_state_request(color, level) when level >= 75 do
    Enum.map(
      [
        Colors.rgb_to_xy(color),
        Colors.rgb_to_xy(color),
        Colors.rgb_to_xy(color),
        Colors.hsv_to_xy(color, compute_partial_pixel_saturation(level), 100)
      ],
      &Color.create/1
    )
    |> internal_get_battery_state_request()
  end

  defp internal_get_battery_state_request(color, level) when level >= 50 do
    Enum.map(
      [
        Colors.rgb_to_xy(color),
        Colors.rgb_to_xy(color),
        Colors.hsv_to_xy(color, compute_partial_pixel_saturation(level), 100),
        Colors.rgb_to_xy(@default_background_color)
      ],
      &Color.create/1
    )
    |> internal_get_battery_state_request()
  end

  defp internal_get_battery_state_request(color, level) when level >= 25 do
    Enum.map(
      [
        Colors.rgb_to_xy(color),
        Colors.hsv_to_xy(color, compute_partial_pixel_saturation(level), 100),
        Colors.rgb_to_xy(@default_background_color),
        Colors.rgb_to_xy(@default_background_color)
      ],
      &Color.create/1
    )
    |> internal_get_battery_state_request()
  end

  defp internal_get_battery_state_request(color, level) when is_integer(level) do
    Enum.map(
      [
        Colors.hsv_to_xy(color, compute_partial_pixel_saturation(level), 100),
        Colors.rgb_to_xy(@default_background_color),
        Colors.rgb_to_xy(@default_background_color),
        Colors.rgb_to_xy(@default_background_color)
      ],
      &Color.create/1
    )
    |> internal_get_battery_state_request()
  end

  defp internal_get_battery_state_request(points) when is_list(points) do
    light_id =
      Application.fetch_env!(
        :teslamate_philips_hue_gradient_signe_table_lamp,
        :hue_signe_gradient_lamp_id
      )

    %HttpRequest{
      method: :put,
      url: "/resource/light/#{light_id}",
      body: %{
        gradient: %{
          points: points
        }
      }
    }
  end

  defp compute_partial_pixel_saturation(percentage)
       when is_integer(percentage) and percentage in 0..100 do
    remaining_value = rem(percentage, 25)
    trunc(remaining_value * 100 / 25)
  end
end
