defmodule TeslamatePhilipsHueGradientSigneTableLamp.Colors do
  # Public

  @spec rgb_to_xy(:red | :green | :blue | :white | :orange | String.t()) :: {float(), float()}
  def rgb_to_xy(:red),
    do: rgb_to_xy("FF0000")

  def rgb_to_xy(:green),
    do: rgb_to_xy("00FF00")

  def rgb_to_xy(:blue),
    do: rgb_to_xy("0000FF")

  def rgb_to_xy(:white),
    do: rgb_to_xy("FFFFFF")

  def rgb_to_xy(:orange),
    do: rgb_to_xy("FF8000")

  def rgb_to_xy(
        <<red::bitstring-size(16)>> <>
          <<green::bitstring-size(16)>> <>
          <<blue::bitstring-size(16)>>
      ) do
    {x, y, z} =
      rgb_to_xyz(
        String.to_integer(red, 16),
        String.to_integer(green, 16),
        String.to_integer(blue, 16)
      )

    local_x = x / (x + y + z)
    local_y = y / (x + y + z)

    {local_x, local_y}
  end

  @spec hsv_to_xy(integer() | :red | :green | :blue, integer(), integer()) :: {float(), float()}
  def hsv_to_xy(:red, s, v),
    do: hsv_to_xy(0, s, v)

  def hsv_to_xy(:green, s, v),
    do: hsv_to_xy(120, s, v)

  def hsv_to_xy(:blue, s, v),
    do: hsv_to_xy(240, s, v)

  def hsv_to_xy(h, s, v)
      when h in 0..360 and
             s in 0..100 and
             v in 0..100 do
    {r, g, b} = hsv_to_rgb(h, s, v)
    {x, y, z} = rgb_to_xyz(r, g, b)

    local_x = x / (x + y + z)
    local_y = y / (x + y + z)

    {local_x, local_y}
  end

  # Private

  defp hsv_to_rgb(h, s, v)
       when h in 0..360 and
              s in 0..100 and
              v in 0..100 do
    local_s = s / 100
    local_v = v / 100
    c = local_s * local_v
    x = c * (1 - abs(:math.fmod(h / 60, 2) - 1))
    m = local_v - c

    {r, g, b} =
      case h do
        y when y >= 0 and y < 60 -> {c, x, 0}
        y when y >= 60 and y < 120 -> {x, c, 0}
        y when y >= 120 and y < 180 -> {0, c, x}
        y when y >= 180 and y < 240 -> {0, x, c}
        y when y >= 240 and y < 300 -> {x, 0, c}
        _ -> {c, 0, x}
      end

    {r + m, g + m, b + m}
  end

  defp rgb_to_xyz(red, green, blue)
       when red >= 0.0 and red <= 1.0 and
              green >= 0.0 and green <= 1.0 and
              blue >= 0.0 and blue <= 1.0 do
    local_red = apply_gamma_correction(red)
    local_green = apply_gamma_correction(green)
    local_blue = apply_gamma_correction(blue)

    x = local_red * 0.4124 + local_green * 0.3576 + local_blue * 0.1805
    y = local_red * 0.2126 + local_green * 0.7152 + local_blue * 0.0722
    z = local_red * 0.0193 + local_green * 0.1195 + local_blue * 0.9504

    {x, y, z}
  end

  defp rgb_to_xyz(red, green, blue)
       when is_integer(red) and red in 0..255 and
              is_integer(green) and green in 0..255 and
              is_integer(blue) and blue in 0..255 do
    local_red = translate_to_1(red)
    local_green = translate_to_1(green)
    local_blue = translate_to_1(blue)

    rgb_to_xyz(local_red, local_green, local_blue)
  end

  defp translate_to_1(value) when value in 0..255,
    do: value * 1 / 255

  defp apply_gamma_correction(value)
       when value > 0.04045 and value <= 1,
       do: Float.pow((value + 0.55) / 1.055, 2.4)

  defp apply_gamma_correction(value) do
    value / 12.92
  end
end
