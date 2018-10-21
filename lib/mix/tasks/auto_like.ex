defmodule Mix.Tasks.AutoLike do
  def run(_) do
    Extagram.AutoLike.start
  end
end
