defmodule TeslamatePhilipsHueGradientSigneTableLamp.ProcessFacade do
  @moduledoc """
  This module exists only for the tests purpose because the methods of the Process module cannot be mocked because there are inlined by the compiler.
  """

  @doc """
  Sends `msg` to `dest` after `time` milliseconds.

  If `dest` is a PID, it must be the PID of a local process, dead or alive.
  If `dest` is an atom, it must be the name of a registered process
  which is looked up at the time of delivery. No error is produced if the name does
  not refer to a process.

  The message is not sent immediately. Therefore, `dest` can receive other messages
  in-between even when `time` is `0`.

  This function returns a timer reference, which can be read with `read_timer/1`
  or canceled with `cancel_timer/1`.

  The timer will be automatically canceled if the given `dest` is a PID
  which is not alive or when the given PID exits. Note that timers will not be
  automatically canceled when `dest` is an atom (as the atom resolution is done
  on delivery).

  Inlined by the compiler.

  ## Options

    * `:abs` - (boolean) when `false`, `time` is treated as relative to the
    current monotonic time. When `true`, `time` is the absolute value of the
    Erlang monotonic time at which `msg` should be delivered to `dest`.
    To read more about Erlang monotonic time and other time-related concepts,
    look at the documentation for the `System` module. Defaults to `false`.

  ## Examples

      timer_ref = ProcessFacade.send_after(pid, :hi, 1000)

  """
  @spec send_after(pid | atom, term, non_neg_integer, [option]) :: reference
        when option: {:abs, boolean}
  def send_after(dest, msg, time, opts \\ []), do: Process.send_after(dest, msg, time, opts)

  @doc """
  Cancels a timer returned by `send_after/3`.

  When the result is an integer, it represents the time in milliseconds
  left until the timer would have expired.

  When the result is `false`, a timer corresponding to `timer_ref` could not be
  found. This can happen either because the timer expired, because it has
  already been canceled, or because `timer_ref` never corresponded to a timer.

  Even if the timer had expired and the message was sent, this function does not
  tell you if the timeout message has arrived at its destination yet.

  Inlined by the compiler.

  ## Options

    * `:async` - (boolean) when `false`, the request for cancellation is
      synchronous. When `true`, the request for cancellation is asynchronous,
      meaning that the request to cancel the timer is issued and `:ok` is
      returned right away. Defaults to `false`.

    * `:info` - (boolean) whether to return information about the timer being
      cancelled. When the `:async` option is `false` and `:info` is `true`, then
      either an integer or `false` (like described above) is returned. If
      `:async` is `false` and `:info` is `false`, `:ok` is returned. If `:async`
      is `true` and `:info` is `true`, a message in the form `{:cancel_timer,
      timer_ref, result}` (where `result` is an integer or `false` like
      described above) is sent to the caller of this function when the
      cancellation has been performed. If `:async` is `true` and `:info` is
      `false`, no message is sent. Defaults to `true`.

  """
  @spec cancel_timer(reference, options) :: non_neg_integer | false | :ok
        when options: [async: boolean, info: boolean]
  def cancel_timer(timer, options \\ []), do: Process.cancel_timer(timer, options)
end
