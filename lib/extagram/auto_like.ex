defmodule Extagram.AutoLike do
  @moduledoc """
  Start random autoLike on instagram
  """
  use Hound.Helpers
  import Extagram.Macros

  def launch(usernames) do
    {:ok, _started} = Application.ensure_all_started(:hound)

    usernames
    |> Enum.map(&Task.async(fn -> start(&1) end))
    # 最長1時間動作
    |> Enum.map(&Task.await(&1, 3600_000))
    |> Enum.each(&IO.puts("#{&1}のフォロワーへのいいね完了"))
  end

  defp start(username) do
    Hound.start_session(
      additional_capabilities: %{
        chromeOptions: %{
          "args" => ["--headless", "--disable-gpu", "--window-size=1920,1080"]
        }
      }
    )

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

    with {:ok, btn} <- search_element(:xpath, "//button[contains(text(), '後で')]", 3) do
      click(btn)
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
    # ここで1度に取得する件数を指定できるが、いくら大きな値を指定しても最大このあたりしか取れないので50で十分
    variables = %{"id" => userid, "first" => 50}

    %{
      "edges" => follower_list,
      "page_info" => %{"has_next_page" => has_next, "end_cursor" => after_of}
    } = _fetch_edge_followed_by(variables)

    public_follower_list =
      follower_list
      |> Enum.filter(fn
        %{"node" => %{"is_private" => false}} -> true
        _ -> false
      end)

    public_follower_list ++
      _get_follower_list(userid, length(public_follower_list), has_next, after_of)
  end

  defp _get_follower_list(userid, count, _has_next = true, after_of)
       when is_less_than_limit(count) do
    variables = %{"id" => userid, "first" => 50, "after" => after_of}

    %{
      "edges" => follower_list,
      "page_info" => %{"has_next_page" => has_next, "end_cursor" => after_of}
    } = _fetch_edge_followed_by(variables)

    public_follower_list =
      follower_list
      |> Enum.filter(fn
        %{"node" => %{"is_private" => false}} -> true
        _ -> false
      end)

    public_follower_list ++
      _get_follower_list(userid, count + length(public_follower_list), has_next, after_of)
  end

  defp _get_follower_list(_, _, _has_next = false, _), do: []
  defp _get_follower_list(_, _, _, _), do: []

  defp _fetch_edge_followed_by(variables) do
    variables_str = variables |> Poison.encode!() |> URI.encode()

    url =
      "https://www.instagram.com/graphql/query/?"
      |> Kernel.<>("query_hash=56066f031e6239f35a904ac20c9f37d9&")
      |> Kernel.<>("variables=#{variables_str}")

    navigate_to(url)

    %{"data" => %{"user" => %{"edge_followed_by" => edge_followed_by}}} =
      find_element(:tag, "html")
      |> inner_text()
      |> Poison.decode!()

    edge_followed_by
  end

  defp like(username) do
    IO.puts("#{username}にいいね中")
    navigate_to("https://instagram.com/#{username}")
    elems = find_all_elements(:xpath, "//article/div/div/div/div/a")
    with posts when is_list(posts) and length(posts) > 0 <- elems, do: _like(posts)
  end

  defp _like(posts) do
    ja_regex = ~r/[\p{Hiragana}\p{Katakana}]/u

    introduction_txt =
      with {:ok, txt_box} <-
             search_element(:xpath, "//section/main/div/header/section/div[2]/span", 3) do
        txt_box |> inner_text()
      else
        _ -> ""
      end

    post = List.first(posts)
    click(post)

    post_txt =
      with {:ok, txt_box} <-
             search_element(:xpath, "//article/*//h2/following-sibling::span[1]", 3) do
        txt_box |> inner_text()
      else
        _ -> ""
      end

    # ひらがな・カタカナが1文字でも含まれていればいいねする
    if Regex.match?(ja_regex, introduction_txt) || Regex.match?(ja_regex, post_txt) do
      _close_modal()

      posts
      |> Enum.take(3)
      |> Enum.each(&_like_each(&1))
    else
      IO.puts("日本人ではない可能性が高いのでいいねしません")
    end
  end

  defp _like_each(post) do
    click(post)
    like_xpath = "//button[contains(@class, 'coreSpriteHeartOpen')]/span[@aria-label='Like']"

    with {:ok, btn} <- search_element(:xpath, like_xpath, 1) do
      click(btn)
    else
      _ -> IO.puts("いいね済の投稿です")
    end

    _close_modal()
  end

  defp _close_modal do
    with {:ok, btn} <- search_element(:xpath, "//button[contains(text(), 'Close')]", 3),
         do: click(btn)
  end
end
