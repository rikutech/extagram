defmodule Extagram.Macros do
  defmacro is_less_than_limit(count) do
    limit_env = System.get_env("LIKE_TARGET_LIMIT")
    limit = if limit_env, do: String.to_integer(limit_env), else: 100
    quote do: unquote(count) < unquote(limit)
  end
end
