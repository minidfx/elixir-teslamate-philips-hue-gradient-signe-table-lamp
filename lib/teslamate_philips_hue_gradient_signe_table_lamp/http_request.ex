defmodule TeslamatePhilipsHueGradientSigneTableLamp.HttpRequest do
  @type method :: :head | :get | :delete | :trace | :options | :post | :put | :patch

  @enforce_keys [:method, :url]
  defstruct [:method, :url, :body]

  @type t :: %__MODULE__{method: method(), url: bitstring(), body: any()}
end
