defmodule TeslamatePhilipsHueGradientSigneTableLamp.Color do
  alias TeslamatePhilipsHueGradientSigneTableLamp.Color

  @enforce_keys [:color]
  @derive Jason.Encoder
  defstruct [:color]
  @type t :: %__MODULE__{color: %{xy: %{x: float(), y: float()}}}

  @spec create(float(), float()) :: Color.t()
  def create(x, y), do: %Color{color: %{xy: %{x: x, y: y}}}

  @spec create({float(), float()}) :: Color.t()
  def create({x, y}), do: %Color{color: %{xy: %{x: x, y: y}}}
end
