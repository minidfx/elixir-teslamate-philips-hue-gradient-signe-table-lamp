defmodule TeslamatePhilipsHueGradientSigneTableLamp.Logger do
  defmacro __using__(_) do
    quote do
      require Logger
      import TeslamatePhilipsHueGradientSigneTableLamp.Logger
      alias TeslamatePhilipsHueGradientSigneTableLamp.Logger
    end
  end

  @spec format(atom(), String.t(), Logger.Formatter.date_time_ms(), keyword()) :: String.t()
  def format(level, message, timestamp, metadata) do
    {{year, month, day}, {hours, minutes, seconds, ms}} = timestamp

    {full_module, function, arity} = Keyword.get(metadata, :mfa, "unknown")
    module = full_module |> Atom.to_string() |> String.replace("Elixir.", "")

    "#{year}-#{pad_leading_integer(month)}-#{pad_leading_integer(day)}T#{pad_leading_integer(hours)}:#{pad_leading_integer(minutes)}:#{pad_leading_integer(seconds)}.#{pad_leading_integer(ms, 3)}Z [#{level}] [#{module}.#{function}/#{arity}] #{message}\n"
  end

  defp pad_leading_integer(value, count \\ 2) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.pad_leading(count, "0")
  end

  defmacro log(level, message) do
    quote do
      Logger.log(unquote(level), unquote(message),
        module: __MODULE__,
        function: __ENV__.function,
        line: __ENV__.line
      )
    end
  end

  defmacro error(message) do
    quote do
      log(:error, unquote(message))
    end
  end

  defmacro warning(message) do
    quote do
      log(:warning, unquote(message))
    end
  end

  defmacro notice(message) do
    quote do
      log(:notice, unquote(message))
    end
  end

  defmacro info(message) do
    quote do
      log(:info, unquote(message))
    end
  end

  defmacro debug(message) do
    quote do
      log(:debug, unquote(message))
    end
  end
end
