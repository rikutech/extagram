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
    Hound.end_session
  end

  defp login do
    fill_field({:name, "username"}, System.get_env("INSTAGRAM_USERNAME"))
    fill_field({:name, "password"}, System.get_env("INSTAGRAM_PASSWORD"))
    submit_element({:xpath, "//button[@type='submit']"})
    click({:xpath, "//button[contains(text(), '後で')]"})
  end

  defp start_like do
    follower_count = 100
    url = "https://www.instagram.com/graphql/query/?"
    |> Kernel.<>("query_hash=56066f031e6239f35a904ac20c9f37d9&")
    |> Kernel.<>("variables=%7B\"id\"%3A\"3184163038\"%2C\"first\"%3A#{follower_count}%7D")
    navigate_to(url)
    %{"data" =>
      %{"user" =>
         %{"edge_followed_by" =>
            %{"edges" => follower_list}
          }
       }
    } = find_element(:tag, "html")
    |> inner_text()
    |> Poison.decode!()

    follower_list
    |> Enum.map(fn %{"node" => %{"username" => un}} -> un end)
    |> Enum.each(&like(&1))
  end

  defp like(username) do
    navigate_to("https://instagram.com/#{username}")

    find_all_elements(:xpath, "//article/div/div/div/div/a")
    |> Enum.take(3)
    |> Enum.each(fn elem ->
      click(elem)
      click({:xpath, "//button[contains(@class, 'coreSpriteHeartOpen')]"})
      click({:xpath, "//div[@role='dialog']/button"})
    end)
  end
end
