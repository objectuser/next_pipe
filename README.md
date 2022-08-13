# NextPipe

Make pipelines a bit more flexible by skipping or always calling functions.

There is no use of macros or operator overloading. Just modules and functions.

## Installation

NextPipe is [available in Hex](https://hex.pm/packages/next_pipe), the package can be installed
by adding `next_pipe` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:next_pipe, "~> 0.1.0"}
  ]
end
```

## Usage

Use `import NextPipe` to make your pipelines a bit more flexible.

`NextPipe` allows the chaining of functions with control through the idiomatic
`{:ok, _}` and `{:error, _}` tuples. In the case of a function returning a value
matching `{:error, _}`, the pipeline is short-circuited.

```elixir
value
|> next(fn ...)
|> next(fn ...)
|> try_next(fn ..., fn ...)
|> always(fn ...)
```

`NextPipe` doesn't use macros or overridden operators. Like `Kernel.then/2`, the
functions in `NextPipe` work with function arguments and idiomatic tuples,
`{:ok, _}` and `{:error, _}`.

Use `next/2` to conditionally execute its function argument based on the first
argument. If the first argument matches `{:ok, _}` the function passed to
`next/2` will be called with the second element of the tuple. If `value` matches
`{:error, _}`, the function will not be called and the same tuple will be
returned.

Otherwise (like at the beginning of a pipeline), the function will be called
with the first argument.

`try_next/3` works like `next/2` but rescues exceptions. It accepts a third
optional argument, which is the function to be called in case an exception is
rescued.

Use `always/2` to always call the function argument, but with the full pipeline
value, _not just_ the second element of the tuple.

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
function returns `{:error, _}`, the subsequent functions passed to `next/2` are
skipped, effectively short-circuting the pipeline.

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
rescuing any exeptions if passing those up is undesirable. `NextPipe` may clean
those cases up a bit.

Compare this use of `Repo.transaction/2`:

```elixir
def something(arg1, arg2) do
  try do
    Repo.transaction(fn repo ->
      arg1
      |> fn1(arg2)
      |> fn2()
    end)
  rescue
    exception ->
      repo.rollback(value)
      {:error, exception}
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
      {:error, value} -> repo.rollback(value)
      value -> value
    end)
  end)
end
```
