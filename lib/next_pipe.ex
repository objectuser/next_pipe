defmodule NextPipe do
  @moduledoc """
  Use `import NextPipe` to make your pipelines a bit more flexible.

  `NextPipe` allows the chaining of functions with control through the idiomatic
  `{:ok, _}` and `{:error, _}` tuples. In the case of a function returning a
  value matching `{:error, _}`, the pipeline is short-circuited.

  ```elixir
  value
  |> next(fn ...)
  |> next(fn ...)
  |> try_next(fn ..., fn ...)
  |> on_error(fn ...)
  |> always(fn ...)
  ```

  `NextPipe` doesn't use macros or overridden operators. Like `Kernel.then/2`,
  the functions in `NextPipe` work with function arguments and idiomatic tuples,
  `{:ok, _}` and `{:error, _}`.

  Use `next/2` to conditionally execute its function argument based on the value
  of the first argument.

  If the first argument matches `{:ok, _}`, the function passed as the second
  argument will be called with the second element of the tuple passed in the
  first argument. If the first argument matches `{:error, _}`, the function will
  not be called and the same tuple will be returned by `next/2`.

  Otherwise (like at the beginning of a pipeline), the function will be called
  with `value`.

  `try_next/3` works like `next/2` but rescues exceptions. It accepts a third
  optional argument, which is the function to be called in case an exception is
  rescued.

  Use `always/2` to always call the function argument, but with the full
  argument value, _not just_ the second element of the tuple.

  Use `on_error/2` to respond to an error tuple.

  ## As an alternative to `with`

  The `with` special form is often use to conditionally call functions if prior
  functions are successful:

  ```elixir
    with {:ok, value} <- fn1(arg1),
         {:ok, value} <- fn2(value, arg2) do
      fn3(value)
    else
      {:error, error} -> error_fn(error)
    end
  ```

  With `NextPipe`:

  ```elixir
    arg1
    |> next(& fn1/1)
    |> next(& fn2(&1, arg2))
    |> next(& fn3/1)
    |> on_error(& error_fn/1)
  ```

  In the case of `with`, if a function result does not match with the left side
  of the `<-` operator, the subsequent clauses are skipped. If there is an
  `else` in the `with` it is used to handle the mismatch.

  When using `next/2`, if the argument matches `{:error, _}` then the function
  argument is not called and the first argument is returned unchanged. In this
  way, all `next/2` calls are effectively skipped in the pipeline.

  If one of the functions may raise an exception, more boilerplate code is
  eliminated.

  Compare using `with`:

  ```elixir
    try do
      with {:ok, value} <- fn1(arg1),
          {:ok, value} <- fn2(value, arg2) do
        fn3(value)
      end
    rescue
      exception -> {:error, exception}
    end
  ```

  to the equivalent behavior using `NextPipe`:

  ```elixir
    arg1
    |> try_next(& fn1(&1))
    |> try_next(& fn2(&1, arg2))
    |> try_next(& fn3(&1))
  ```

  ## As an alternative to `Ecto.Multi`

  Transaction control with `Ecto.Multi` is quite powerful and flexible. It can,
  however, be a bit cumbersome for simpler situations. And then
  `Repo.transaction/2` with a simple function requires some boilerplate code for
  rescuing any exeptions if passing those up is undesirable. `NextPipe` may
  clean those cases up a bit.

  Compare this use of `Repo.transaction/2`:

  ```elixir
  def something(arg1, arg2) do
    try do
      Repo.transaction(fn repo ->
        arg1
        |> fn1(arg2))
        |> fn2()
      end)
    rescue
      exception -> {:error, exception}
    end
  end
  ```

  And then using `NextPipe`:

  ```elixir
  def something(arg1, arg2) do
    Repo.transaction(fn repo ->
      arg1
      |> try_next(& fn1(&1, arg2))
      |> try_next(& fn2(&1))
      |> on_error(fn error -> repo.rollback(error))
    end)
  end
  ```

  ## Functions with multiple arguments

  The function passed to `next/2` et al accepts a single argument. If multiple
  arguments are required, return a new function with those arguments bound.

  As an example, consider the following traditional Elixir pipeline:

  ```elixir
  def something(arg1, arg2) do
    arg1
    |> fn1(arg2)
    |> fn2()
  end
  ```

  The analogous pipeline using `next/2` might be:

  ```elixir
  def something(arg1, arg2) do
    arg1
    |> next(& fn1(&1, arg2))
    |> next(& fn2(&1))
  end
  ```
  """

  @doc """
  Conditionally call the next function.

  If the first argument matches `{:ok, value}`, `next_fn` is called with
  `value`.

  If the first argument matches `{:error, _}`, the call to `next_fn` will be
  skipped and the function returns the first argument unchanged.

  Otherwise, the function is called with first argument unchanged. This supports
  the use of `next/2` at the beginning of a pipeline.

  `next_fn` is expected to return `{:ok, value}` if it was successful.
  Otherwise, it should return `{:error, value}`.

  `next/2` returns the value returned by `next_fn`.
  """
  @spec next(
          {:ok, any()} | {:error, any()} | any(),
          next_fn :: (any() -> {:ok, any()} | {:error, any()})
        ) :: {:ok, any()} | {:error, any()}
  def next({:ok, value}, next_fn), do: next_fn.(value)

  def next({:error, _value} = input, _next_fn), do: input

  def next(value, next_fn), do: next_fn.(value)

  @doc """
  An alias for `next/2`.
  """
  @spec ok(
          {:ok, any()} | {:error, any()} | any(),
          ok_fn :: (any() -> {:ok, any()} | {:error, any()})
        ) :: {:ok, any()} | {:error, any()}
  defdelegate ok(value, function), to: __MODULE__, as: :next

  @doc """
  Wrap the argument in an `{:ok, _}` tuple, if necessary. This is useful for
  returning an `{:ok, _}` tuple at the end of a pipeline instead of, for
  example, `|> then(&{:ok, &1})`

  - `{:ok, value}` - return unchanged
  - `{:error, value}` - return unchanged
  - `value` - return `{:ok, value}`
  """
  @spec ok({:ok, any()} | {:error, any()} | any()) :: {:ok, any()} | {:error, any()}
  def ok({:ok, _} = ok), do: ok
  def ok({:error, _} = error), do: error
  def ok(value), do: {:ok, value}

  @doc """
  The inverse of `next/2`, if the first argument matches `{:error, value}`, call
  `error_fn` with `value`. Otherwise, return the first argument.
  """
  @spec on_error(
          {:ok, any()} | {:error, any()},
          error_fn :: (any() -> {:ok, any()} | {:error, any()})
        ) :: {:ok, any()} | {:error, any()}
  def on_error({:error, value} = _input, error_fn), do: error_fn.(value)

  def on_error({:ok, _} = input, _error_fn), do: input

  @doc """
  Conditionally call the next function and provide an outlet for handling
  exceptions when `next_fn` is called.

  This function generally behaves the same as `next/2` unless an exception is
  raised in `next_fn`.

  In that case, the exception is rescued and `rescue_fn` is called with two
  arguments: the second element of the `{:ok, value}` tuple and the raised
  exception. The value returned from `try_next/3` is then the value returned
  from `rescue_fn`. `rescue_fn` should return a value matching `{:ok, _}` or
  `{:error, _}`.

  The default implementation of `rescue_fn` simply returns an `{:error,
  exception}` tuple, where `exception` is the exception raised by `next_fn`.
  """
  @spec try_next(
          {:ok, any()} | {:error, any()} | any(),
          next_fn :: (any() -> {:ok, any()} | {:error, any()}),
          rescue_fn :: (any(), any() -> {:ok, any()} | {:error, any()})
        ) :: {:ok, any()} | {:error, any()}
  def try_next(value, next_fn, rescue_fn \\ fn _value, exception -> {:error, exception} end)

  def try_next({:ok, value}, next_fn, rescue_fn) do
    try do
      next_fn.(value)
    rescue
      exception ->
        rescue_fn.(value, exception)
    end
  end

  def try_next({:error, _value} = input, _next_fn, _rescue_fn), do: input

  def try_next(value, next_fn, rescue_fn), do: try_next({:ok, value}, next_fn, rescue_fn)

  @doc """
  Always call `always_fn` with the first argument. Unlike `next`, the
  `always_fn` receives the full tuple passed as the first argument to
  `always/2`, i.e., `{:ok, value}` or `{:error, value}`.

  `always_fn` should return a value matching either `{:ok, _}` or `{:error, _}`.

  This is basically the same as `then/2` with a more strict type spec.
  """
  @spec always(
          {:ok, any()} | {:error, any()},
          always_fn :: (any() -> {:ok, any()} | {:error, any()})
        ) :: {:ok, any()} | {:error, any()}
  defdelegate always(value, always_fn), to: Kernel, as: :then

  @doc """
  Process the enumerable against the function while the function returns `{:ok,
  _}` tuples.

  If all items are successful, the result is an `{:ok, items}` tuple, where
  `items` is the list of values returned as the seccond item in the `{:ok,
  item}` tuple from `function`.

  If any call to function is unsuccessful, the loop is halted and the return
  value is `{:error, {error, items}}`, where `error` is the error returned from
  the unsuccessful function call and `items` is the list of items processed
  successfully.
  """
  @spec next_while(Enumerable.t(), (any() -> {:ok, any()} | {:error, any()})) ::
          {:ok, any()} | {:error, any()}
  def next_while(enumerable, function) do
    Enum.reduce_while(enumerable, {:ok, []}, fn item, {:ok, results} ->
      case function.(item) do
        {:ok, result} -> {:cont, {:ok, [result | results]}}
        {:error, error} -> {:halt, {:error, {error, results}}}
      end
    end)
  end
end
