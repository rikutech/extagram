defmodule Mix.Tasks.AutoLike do
  use Mix.Task

  def run(usernames) do
    Extagram.AutoLike.launch(usernames)
  end
end
