defmodule NextPipe.MixProject do
  use Mix.Project

  def project do
    [
      app: :next_pipe,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
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
    Make pipelines a bit more flexible by skipping or always calling functions.
    """
  end

  defp docs do
    [
      main: "NextPipe",
      maintainers: ["objectuser"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/objectuser/next_pipe"
      },
      source_url: "https://github.com/objectuser/next_pipe"
    ]
  end
end
