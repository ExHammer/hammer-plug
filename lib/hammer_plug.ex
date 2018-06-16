defmodule Hammer.Plug do
  @moduledoc """
  Documentation for Hammer.Plug.
  """
  import Plug.Conn

  @valid_methods [:ip]

  def init(), do: init([])
  def init(opts), do: opts

  def call(conn, opts) do
    id_prefix = Keyword.get(opts, :id)
    if id_prefix == nil do
      raise "Hammer.Plug: no id prefix specified"
    end
    scale = Keyword.get(opts, :scale, 60_000)
    limit = Keyword.get(opts, :limit, 60)
    by = Keyword.get(opts, :by, :ip)
    if !Enum.member?(@valid_methods, by) do
      raise "Hammer.Plug: invalid `by` parameter: #{to_string(by)}"
    end
    full_id = build_identifier(conn, id_prefix, by)
    case Hammer.check_rate(full_id, scale, limit) do
      {:allow, _n} ->
        conn
      {:deny, _n} ->
        conn
        |> send_resp(429, "Too Many Requests")
        |> halt()
    end
  end

  defp build_identifier(conn, prefix, :ip) do
    ip_string = conn.remote_ip
    |> Tuple.to_list
    |> Enum.join(".")
    "#{prefix}:#{ip_string}"
  end
end
