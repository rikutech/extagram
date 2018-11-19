defmodule Extagram.AutoLike do
  @moduledoc """
  Start random autoLike on instagram
  """
  use Hound.Helpers
  import Extagram.Macros

  def launch(usernames) do
    {:ok, _started} = Application.ensure_all_started(:hound)

    usernames
    |> Enum.each(fn username ->
      start(username)
      IO.puts("#{username}のフォロワーへのいいねが完了しました")
    end)
  end

  defp start(username) do
    get_follower_username_list(username)
    |> Enum.chunk_every(100)
    |> Enum.each(&start_like(&1))

    username
  end

  defp open_browser_and_login do
    if System.get_env("HEADLESS_MODE") == "true" do
      Hound.start_session(
        additional_capabilities: %{
          chromeOptions: %{
            "args" => ["--headless", "--disable-gpu", "--window-size=1920,1080"]
          }
        }
      )
    else
      Hound.start_session()
    end

    login()
  end

  defp close_browser, do: Hound.end_session()

  defp login do
    navigate_to("http://instagram.com")
    fill_field({:name, "username"}, System.get_env("INSTAGRAM_USERNAME"))
    fill_field({:name, "password"}, System.get_env("INSTAGRAM_PASSWORD"))
    submit_element({:xpath, "//button[@type='submit']"})

    with {:ok, btn} <- search_element(:xpath, "//button[contains(text(), '後で')]", 3) do
      click(btn)
    end
  end

  defp start_like(usernames) do
    open_browser_and_login()

    Enum.shuffle(usernames)
    |> Enum.each(&like(&1))

    close_browser()
  end

  defp get_follower_username_list(username) do
    IO.puts("フォロワー情報を取得中です…")
    open_browser_and_login()
    navigate_to("https://instagram.com/#{username}")
    %{"id" => userid} = Regex.named_captures(~r/"owner":\{"id":"(?<id>[0-9]*)"/, page_source())

    usernames =
      _get_follower_list(userid, 0)
      |> Enum.map(fn %{"node" => %{"username" => un}} -> un end)

    close_browser()
    IO.puts("#{length(usernames)}人にいいねを開始します")
    usernames
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
    posts = find_all_elements(:xpath, "//article/div/div/div/div/a")

    if is_list(posts) and length(posts) > 0 do
      _prepare_like(List.first(posts))
    else
      IO.puts("投稿が1件もないのでスキップします")
    end
  end

  defp _prepare_like(post) do
    introduction_txt = find_introduction_txt()
    click(post)
    post_txt = find_post_txt()
    ja_regex = ~r/[\p{Hiragana}\p{Katakana}]/u
    modal_appeared = match?({:ok, _}, search_element(:xpath, "//div[@role='dialog']//article"))

    # ひらがな・カタカナが1文字でも含まれていればいいねする
    if Regex.match?(ja_regex, introduction_txt) || Regex.match?(ja_regex, post_txt) do
      _like(modal_appeared)
    else
      IO.puts("日本人ではない可能性が高いのでスキップします")
    end
  end

  defp _like(_modal_appeared = true) do
    _like_each()
    _go_next_post()
    _like_each()
    _go_next_post()
    _like_each()
  end

  defp _like(_modal_appeared = false) do
    IO.puts("規制に入ったため30秒のインターバルを取ります…")
    Process.sleep(30_000)
    IO.puts("インターバル終了")
  end

  defp find_introduction_txt() do
    with {:ok, txt_box} <-
           search_element(:xpath, "//section/main/div/header/section/div[2]/span", 3) do
      txt_box |> inner_text()
    else
      _ -> ""
    end
  end

  defp find_post_txt() do
    with {:ok, txt_box} <- search_element(:xpath, "//article/*//h2/following-sibling::span[1]", 3) do
      txt_box |> inner_text()
    else
      _ -> ""
    end
  end

  defp _like_each() do
    like_xpath =
      "//button[contains(@class, 'coreSpriteHeartOpen')]/span[@aria-label='Like' or @aria-label='いいね！']"

    with {:ok, btn} <- search_element(:xpath, like_xpath, 1) do
      click(btn)
    else
      _ -> IO.puts("いいね済の投稿です")
    end
  end

  defp _go_next_post do
    btn_xpath = "//a[contains(text(), 'Next') or contains(text(), '次へ')]"

    with {:ok, btn} <- search_element(:xpath, btn_xpath, 3),
         do: click(btn)
  end
end
