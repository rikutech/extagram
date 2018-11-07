defmodule Extagram.Macros do
  defmacro is_less_than_limit(count) do
    quote do: unquote(count) < unquote(System.get_env("LIKE_TARGET_LIMIT") || 100)
  end
end

