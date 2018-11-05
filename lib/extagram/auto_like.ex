defmodule Extagram.AutoLike do
  @moduledoc """
  Start random autoLike on instagram
  """
  use Hound.Helpers

  def start do
    Hound.start_session()
    navigate_to("http://instagram.com")
    login()
    start_like()
    #Hound.end_session
  end

  defp login do
    fill_field({:name, "username"}, System.get_env("INSTAGRAM_USERNAME"))
    fill_field({:name, "password"}, System.get_env("INSTAGRAM_PASSWORD"))
    submit_element({:xpath, "//button[@type='submit']"})
    click({:xpath, "//button[contains(text(), '後で')]"})
  end

  defp start_like do
    navigate_to("https://www.instagram.com/everytraveler/")
    click({:xpath, "//a[@href='/everytraveler/followers/']"})
  end
end
