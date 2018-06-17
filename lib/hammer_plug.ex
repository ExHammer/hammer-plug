defmodule Hammer.Plug do
  @moduledoc """
  Documentation for Hammer.Plug.
  """
  import Plug.Conn

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
    when_nil = Keyword.get(opts, :when_nil, :use_nil)

    on_deny_handler =
      Keyword.get(
        opts,
        :on_deny,
        &Hammer.Plug.default_on_deny_handler/2
      )

    if !is_valid_method(by) do
      raise "Hammer.Plug: invalid `by` parameter"
    end

    request_identifier = get_request_identifier(conn, by)

    case request_identifier do
      nil ->
        case when_nil do
          # Proceed
          :use_nil ->
            do_check(conn, id_prefix, nil, scale, limit, on_deny_handler)

          :raise ->
            by_string = by_to_string(by)
            raise "Hammer.Plug: request-id value is nil, by: #{by_string}"

          :pass ->
            # Skip check
            conn
        end

      id ->
        do_check(conn, id_prefix, id, scale, limit, on_deny_handler)
    end
  end

  def default_on_deny_handler(conn, _opts) do
    conn
    |> send_resp(429, "Too Many Requests")
    |> halt()
  end

  ## Private helpers

  defp get_request_identifier(conn, by) do
    case by do
      :ip ->
        conn.remote_ip
        |> Tuple.to_list()
        |> Enum.join(".")

      {:session, key} ->
        get_session(conn, key)

      {:session, key, func} ->
        get_session(conn, key) |> func.()
    end
  end

  defp do_check(conn, id_prefix, request_id, scale, limit, on_deny_handler) do
    full_id = "#{id_prefix}:#{request_id}"

    case Hammer.check_rate(full_id, scale, limit) do
      {:allow, _n} ->
        conn

      {:deny, _n} ->
        on_deny_handler.(conn, [])
    end
  end

  defp by_to_string(by) do
    case by do
      a when is_atom(a) -> to_string(a)
      {:session, key} -> "{:session, #{key}}"
      {:session, key, _func} -> "{:session, #{key}, &fn}"
    end
  end

  defp is_valid_method(by) do
    case by do
      :ip -> true
      {:session, key} when is_atom(key) -> true
      {:session, key, func} when is_atom(key) and is_function(func) -> true
      _ -> false
    end
  end
end
