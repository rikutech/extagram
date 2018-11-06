defmodule Extagram.AutoLike do
  @moduledoc """
  Start random autoLike on instagram
  """
  use Hound.Helpers

  def launch(usernames) do
    {:ok, _started} = Application.ensure_all_started(:hound)
    usernames
    |> Enum.map(&(Task.async(fn -> start(&1) end)))
    |> Enum.map(&(Task.await(&1, 360_000)))
  end

  defp start(username) do
    Hound.start_session()
    login()
    start_like(username)
    Hound.end_session()
  end

  defp login do
    navigate_to("http://instagram.com")
    fill_field({:name, "username"}, System.get_env("INSTAGRAM_USERNAME"))
    fill_field({:name, "password"}, System.get_env("INSTAGRAM_PASSWORD"))
    submit_element({:xpath, "//button[@type='submit']"})
    click({:xpath, "//button[contains(text(), '後で')]"})
  end

  defp start_like(username) do
    navigate_to("https://instagram.com/#{username}")
    %{"id" => userid} = Regex.named_captures(~r/"owner":\{"id":"(?<id>[0-9]*)"/, page_source())
    follower_count = 1000
    url = "https://www.instagram.com/graphql/query/?"
    |> Kernel.<>("query_hash=56066f031e6239f35a904ac20c9f37d9&")
    |> Kernel.<>("variables=%7B\"id\"%3A\"#{userid}\"%2C\"first\"%3A#{follower_count}%7D")
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
      with {:ok, btn} <- search_element(:xpath, "//button[contains(@class, 'coreSpriteHeartOpen')]/span[@aria-label='いいね！']", 3)
        do
          click(btn)
        else
          _ -> nil
      end

      click({:xpath, "//div[@role='dialog']/button"})
    end)
  end
end
