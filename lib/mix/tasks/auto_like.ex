defmodule Mix.Tasks.AutoLike do
  use Mix.Task

  def run(username) do
    Extagram.AutoLike.start(username)
  end
end
