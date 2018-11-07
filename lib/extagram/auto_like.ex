defmodule Extagram.AutoLike do
  @moduledoc """
  Start random autoLike on instagram
  """
  use Hound.Helpers
  import Extagram.Macros

  def launch(usernames) do
    {:ok, _started} = Application.ensure_all_started(:hound)
    usernames
    |> Enum.map(&(Task.async(fn -> start(&1) end)))
    |> Enum.map(&(Task.await(&1, 3600_000))) #最長1時間動作
    |> Enum.each(&(IO.puts "#{&1}のフォロワーへのいいね完了"))
  end

  defp start(username) do
    Hound.start_session()
    login()
    start_like(username)
    Hound.end_session()
    username
  end

  defp login do
    navigate_to("http://instagram.com")
    fill_field({:name, "username"}, System.get_env("INSTAGRAM_USERNAME"))
    fill_field({:name, "password"}, System.get_env("INSTAGRAM_PASSWORD"))
    submit_element({:xpath, "//button[@type='submit']"})
    with {:ok, btn} <- search_element(:xpath, "//button[contains(text(), '後で')]", 3)
      do click(btn)
    end
  end

  defp start_like(username) do
    navigate_to("https://instagram.com/#{username}")
    %{"id" => userid} = Regex.named_captures(~r/"owner":\{"id":"(?<id>[0-9]*)"/, page_source())
    get_follower_username_list(userid)
    |> Enum.chunk_every(10)
    |> Enum.each(fn username_list ->
      Enum.each(username_list, &like(&1))
      Process.sleep(10000)
    end)
  end

  defp get_follower_username_list(userid) do
    _get_follower_list(userid, 0)
    |> Enum.map(fn %{"node" => %{"username" => un}} -> un end)
  end

  defp _get_follower_list(userid, _initial_count = 0) do
    #ここで1度に取得する件数を指定できるが、いくら大きな値を指定しても最大このあたりしか取れないので50で十分
    variables = %{"id" => userid, "first" => 50}
    %{"edges" => follower_list,
        "page_info" =>
	      %{"has_next_page" => has_next,
          "end_cursor" => after_of},
    } = _fetch_edge_followed_by(variables)
    follower_list ++ _get_follower_list(userid, length(follower_list), has_next, after_of)
  end

  defp _get_follower_list(userid, count, _has_next = true, after_of) when is_less_than_limit(count) do
    variables = %{"id" => userid, "first" => 50, "after" => after_of}
    %{"edges" => follower_list,
        "page_info" =>
        %{"has_next_page" => has_next,
          "end_cursor" => after_of}
    } = _fetch_edge_followed_by(variables)
    follower_list ++ _get_follower_list(userid, count + length(follower_list), has_next, after_of)
  end

  defp _get_follower_list(_, _, _has_next = false, _), do: []
  defp _get_follower_list(_, _, _, _), do: []

  defp _fetch_edge_followed_by(variables) do
    variables_str = variables |> Poison.encode! |> URI.encode()
    url = "https://www.instagram.com/graphql/query/?"
    |> Kernel.<>("query_hash=56066f031e6239f35a904ac20c9f37d9&")
    |> Kernel.<>("variables=#{variables_str}")

    navigate_to(url)
    %{"data" =>
      %{"user" =>
	       %{"edge_followed_by" => edge_followed_by}
       }
    } = find_element(:tag, "html")
    |> inner_text()
    |> Poison.decode!()
    edge_followed_by
  end

  defp like(username) do
    IO.puts "#{username}にいいね中"
    navigate_to("https://instagram.com/#{username}")

    with posts when is_list(posts) <- find_all_elements(:xpath, "//article/div/div/div/div/a") do
      posts
      |> Enum.take(3)
      |> Enum.each(
      fn elem ->
        click(elem)
        like_xpath = "//button[contains(@class, 'coreSpriteHeartOpen')]/span[@aria-label='いいね！']"
        with {:ok, btn} <- search_element(:xpath, like_xpath, 1), do: click(btn)
        with {:ok, btn} <- search_element(:xpath, "//div[@role='dialog']/button", 3), do: click(btn)
      end)
    end
  end
end
