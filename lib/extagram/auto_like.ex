defmodule Extagram.AutoLike do
  @moduledoc """
  Start random autoLike on instagram
  """
  use Hound.Helpers

  def start do
    hound_session()
    navigate_to("http://instagram.com")
    fill_field({:name, "username"}, System.get_env("INSTAGRAM_USERNAME"))
    fill_field({:name, "password"}, System.get_env("INSTAGRAM_PASSWORD"))
    submit_element({:type, "submit"})
  end
end
