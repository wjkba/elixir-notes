defmodule Helpers.Format do
  # @time_now DateTime.utc_now()
  def trim_text(text) do
    String.trim(text)
  end

  def generate_slug(text) do
    text
    |> String.trim()
    |> String.downcase()
    |> String.replace(" ", "-")
    |> dbg()
  end
end
