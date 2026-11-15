defmodule Mini.MixProject do
  use Mix.Project

  def project do
    [
      app: :mini_elixir,
      version: "3.1.0",
      elixir: "~> 1.15",
      deps: [{:jason, "~> 1.4"}]
    ]
  end
end
