defmodule Gearbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :gearbox,
      version: "0.3.4",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Gearbox",
      description: description(),
      package: package(),
      source_url: "https://github.com/edisonywh/gearbox"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.28.0", only: :dev},
      {:earmark, "~> 1.4", only: :dev},
      {:ecto, "~> 3.4", optional: true}
    ]
  end

  def description do
    "Gearbox is a functional state machine with an easy-to-use API, inspired by both Fsm and Machinery"
  end

  def package do
    [
      maintainers: ["Edison Yap"],
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/edisonywh/gearbox"}
    ]
  end
end
