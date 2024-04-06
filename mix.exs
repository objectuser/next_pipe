defmodule NextPipe.MixProject do
  use Mix.Project

  def project do
    [
      app: :next_pipe,
      version: "0.4.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package(),
      name: "NextPipe"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.28", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    Make pipelines a bit more flexible using idiomatic `{:ok, _}` and `{:error, _}` tuples.
    """
  end

  defp docs do
    [
      main: "NextPipe",
      extra_section: "Notebooks",
      extras: [
        "notebooks/next_pipe.livemd"
      ]
    ]
  end

  defp package do
    [
      name: "next_pipe",
      maintainers: ["objectuser"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/objectuser/next_pipe"
      },
      source_url: "https://github.com/objectuser/next_pipe"
    ]
  end
end
