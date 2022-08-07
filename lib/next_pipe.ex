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
  |> always(fn ...)
  ```

  `NextPipe` doesn't use macros or overridden operators. Like `Kernel.then/2`,
  the functions in `NextPipe` work with function arguments and idiomatic tuples,
  `{:ok, _}` and `{:error, _}`.

  Use `next/2` to conditionally execute its function argument based on `value`.
  If `value` matches `{:ok, _}` the function passed to `next/2` will be called
  with the second element of the tuple. If `value` matches `{:error, _}`, the
  function will not be called and the same tuple will be returned.

  Otherwise (like at the beginning of a pipeline), the function will be called
  with `value`.

  `try_next/3` works like `next/2` but rescues exceptions. It accepts a third
  optional argument, which is the function to be called in case an exception is
  rescued.

  Use `always/2` to always call the function argument, but with the full
  pipeline value, _not just_ the second element of the tuple.

  ## As an alternative to `with`

  The `with` special form is often use to conditionally call functions if prior
  functions are successful:

  ```elixir
    with {:ok, value} <- fn1(arg1),
         {:ok, value} <- fn2(value, arg2) do
      fn3(value)
    end
  ```

  With `NextPipe`:

  ```elixir
    arg1
    |> next(& fn1(&1))
    |> next(& fn2(&1, arg2))
    |> next(& fn3(&1))
  ```

  Just like when using `with`, when creating a pipeline using `next/2`, if a
  function returns `{:error, _}`, the subsequent functions passed to `next/2`
  are skipped, effectively short-circuting the pipeline.

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

  To using `NextPipe`:

  ```elixir
    arg1
    |> try_next(& fn1(&1))
    |> try_next(& fn2(&1, arg2))
    |> try_next(& fn3(&1))
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
      |> always(fn
        fn {:error, value} -> repo.rollback(value)
        fn value -> value
      end)
    end)
  end
  ```
  """

  @doc """
  Conditionally call the next function with the pipeline value.

  If the pipeline value matches `{:ok, value}`, the `next_fn` is called with
  `value`.

  If the pipeline value matches `{:error, value}`, the call to `next_fn` will be
  skipped and the pipeline value is returned unchanged.

  Otherwise, the function is called with the `value`, which supports the use of
  `next/2` at the beginning of a pipeline.

  `next_fn` must return `{:ok, value}` if it was successful. Otherwise, it must
  return `{:error, value}`.

  `next/2` returns the value returned by `next_fn`.
  """
  @spec next(
          {:ok, any()} | {:error, any()} | any(),
          (any() -> {:ok, any()} | {:error, any()})
        ) ::
          {:ok, any()} | {:error, any()}
  def next({:ok, value}, next_fn) do
    next_fn.(value)
  end

  def next({:error, _value} = input, _next_fn) do
    input
  end

  def next(value, next_fn) do
    next_fn.(value)
  end

  @doc """
  Conditionally call the next function with the pipeline value and provide an
  outlet for handling exceptions when `next_fn` is called.

  This function generally behaves the same as `next/2` unless an exception is
  raised in `next_fn`.

  In that case, the exception is rescued and `rescue_fn` is called with two
  arguments: the second element of the `{:ok, value}` tuple and the raised
  exception. The value returned from `try_next/3` is then the value returned
  from `rescue_fn`. `rescue_fn` must return a value matching `{:ok, _}` or
  `{:error, _}`.

  The default implementation of `rescue_fn` simply returns an `{:error,
  exception}` tuple, where `exception` is the exception raised by `next_fn`.
  """
  @spec try_next(
          {:ok, any()} | {:error, any()} | any(),
          (any() -> {:ok, any()} | {:error, any()}),
          (any(), any() -> {:ok, any()} | {:error, any()})
        ) ::
          {:ok, any()} | {:error, any()}

  def try_next(value, next_fn, rescue_fn \\ fn _value, exception -> {:error, exception} end)

  def try_next({:ok, value}, next_fn, rescue_fn) do
    try do
      next_fn.(value)
    rescue
      exception ->
        rescue_fn.(value, exception)
    end
  end

  def try_next({:error, _value} = input, _next_fn, _rescue_fn) do
    input
  end

  def try_next(value, next_fn, rescue_fn), do: try_next({:ok, value}, next_fn, rescue_fn)

  @doc """
  Always call `always_fn` with the pipeline value. Unlike `next`, the
  `always_fn` receives the full tuple passed as the first argument to
  `NextPipe.always/2`, i.e., `{:ok, value}` or `{:error, value}`.

  `always_fn` should return a value matching either `{:ok, _}` or `{:error, _}`.
  """
  @spec always(
          {:ok, any()} | {:error, any()},
          (any() -> {:ok, any()} | {:error, any()})
        ) ::
          {:ok, any()} | {:error, any()}
  def always(value, always_fn) do
    always_fn.(value)
  end
end
