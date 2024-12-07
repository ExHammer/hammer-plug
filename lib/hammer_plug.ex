defmodule Hammer.Plug do
  @moduledoc """
  A plug which rate-limits requests, using the Hammer library.

  ## Usage example:

      # Minimal
      plug Hammer.Plug, [
        rate_limit: {"video:upload", 60_000, 10},
        by: {:session, :user_id}
      ] when action == :upload_video_file

      # Using all options
      plug Hammer.Plug, [
        rate_limit: {"chat:message:post", 60_000, 20},
        by: {:session, :user, &Helpers.get_user_id/2},
        when_nil: :raise,
        on_deny: &Helpers.handle_deny/2
      ] when action == :post_chat_message


  ## Options

  ### :rate_limit (`{prefix::string, time_scale::int, limit::int}`)

  Required. A tuple of three elements, a string prefix that identifies
  this particular rate-limiter, an integer time-scale in milliseconds, and
  an integer limit. These are the same as the first three arguments to the
  `check_rate` function in the
  [Hammer](https://hexdocs.pm/hammer/Hammer.html#check_rate/3) module.

  Requests from a single client (as identified by the `:by` parameter) will
  be rate-limited to the specified limit within the specified timeframe.

  By default, requests which are over the limit will be halted, and a
  `429 Too Many Requests` response will be sent.

  #### Examples

      rate_limit: {"chat:message:post", 20_000, 5}

      rate_limit: {"login", 60_000, 10}


  ### :by

  The method by which to choose a "unique" identifier for the request client.
  Optional, defaults to `:ip`.

  Valid options:

  - `:ip` -> Use the IP address of the request
  - `{:session, key}` -> where `key` is an atom, choose this value from the
    session
  - `{:session, key, func}` -> where `key` is an atom and `func` is a
     function of the form `&SomeModule.some_function/1`, choose the value
     from the session, and then apply the supplied function, then use the
     return value as the identifier
  - `{:conn, func}` -> where `func` is a function of the form
     `&SomeModule.some_function/1` which returns a value from the conn to
     be used as the identifier

  #### Examples

      by: :ip

      by: {:session, :user_id}

      by: {:session, :user, &Helpers.get_user_id/1} # where `get_user_id/1` is
      equivalent to `fn (u) -> u.id end`

      by: {:conn, &Helpers.get_email_from_request/1} # where email_from_request/1
      is equivalent to `fn (conn) -> conn.params["email"] end`

  ### :when_nil

  Strategy to use when the request identifier value (as chosen by the `:by`
  parameter), is `nil`.
  Optional, defaults to `:use_nil`

  The most likely scenario is that when using a `:by` strategy like
  `{:session, :user_id}`, the `:user_id` value might actually be `nil`, for
  requests coming from clients that are not logged-in, for example.

  In general, it is recommended that you only use the `:session` strategy
  on routes that you know will only be available to clients which have the
  appropriate session established.

  Valid options:

  - `:use_nil` -> Use the nil value. Not very useful, as this would mean that
    one rate-limiter would apply to all such requests
  - `:pass` -> skip the rate-limit check, and allow the request to proceed
  - `:raise` -> raise a `Hammer.Plug.NilError` exception

  #### Examples

      when_nil: :pass


  ### :on_deny
  A plug function to be invoked when a request is deemed to have exceeded the
  rate-limit.
  Optional, defaults to sending a `429 Too Many Requests` response and halting
  the connection.

  #### Examples

      on_deny: &Helpers.handle_rate_limit_deny/2
      # where `handle_rate_limit_deny/2` is something like:
      #
      #     def handle_rate_limit_deny(conn, _opts) do
      #       ...
      #     end

  """
  @behaviour Plug
  import Plug.Conn
  require Logger

  @impl Plug
  def init(opts) do
    rate_limit_spec = Keyword.get(opts, :rate_limit)

    unless rate_limit_spec do
      raise ArgumentError, "must specify a :rate_limit"
    end

    {id_prefix, scale, limit} = rate_limit_spec

    by = Keyword.get(opts, :by, :ip)

    unless is_valid_method(by) do
      raise ArgumentError, "invalid :by option: #{inspect(by)}"
    end

    when_nil = Keyword.get(opts, :when_nil, :use_nil)

    unless when_nil in [:use_nil, :raise, :pass] do
      raise ArgumentError,
            "expected one of :user_nil, :raise, :pass for :when_nil option, got: #{inspect(when_nil)}"
    end

    on_deny_handler =
      Keyword.get(
        opts,
        :on_deny,
        &Hammer.Plug.default_on_deny_handler/2
      )

    config = %{
      id_prefix: id_prefix,
      scale: scale,
      limit: limit,
      by: by,
      when_nil: when_nil,
      on_deny: on_deny_handler
    }

    plug_name = plug_name(id_prefix)

    Logger.warn("""
    Hummer.Plug is deprecated. Please consider replacing it with a function plug:

        plug :#{plug_name} # when action in ...

        #{render_custom_plug(config) |> String.replace("\n", "\n    ")}
    """)

    config
  end

  @impl true
  def call(conn, config) do
    %{
      id_prefix: id_prefix,
      scale: scale,
      limit: limit,
      by: by,
      when_nil: when_nil,
      on_deny: on_deny_handler
    } = config

    request_identifier = get_request_identifier(conn, by)

    case request_identifier do
      nil ->
        case when_nil do
          # Proceed
          :use_nil ->
            do_rate_limit_check(conn, id_prefix, nil, scale, limit, on_deny_handler)

          :raise ->
            raise Hammer.Plug.NilError

          :pass ->
            # Skip check
            conn
        end

      id ->
        do_rate_limit_check(conn, id_prefix, id, scale, limit, on_deny_handler)
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
        val = get_session(conn, key)

        case val do
          nil ->
            nil

          other ->
            func.(other)
        end

      {:conn, func} ->
        func.(conn)
    end
  end

  defp do_rate_limit_check(conn, id_prefix, request_id, scale, limit, on_deny_handler) do
    full_id = "#{id_prefix}:#{request_id}"

    case Hammer.check_rate(full_id, scale, limit) do
      {:allow, _n} ->
        conn

      {:deny, _n} ->
        on_deny_handler.(conn, [])

      {:error, _reason} ->
        on_deny_handler.(conn, [])
    end
  end

  defp is_valid_method(by) do
    case by do
      :ip -> true
      {:session, key} when is_atom(key) -> true
      {:session, key, func} when is_atom(key) and is_function(func, 1) -> true
      {:conn, func} when is_function(func, 1) -> true
      _ -> false
    end
  end

  defp plug_name(id_prefix) do
    plug_name = "rate_limit_" <> String.replace(id_prefix, ":", "_")
    String.trim_trailing(plug_name, "_")
  end

  defp render_func(func) do
    inspect(func)
    |> String.trim_leading("&")
    |> String.split("/")
    |> List.first()
  end

  @doc false
  def render_custom_plug(config) do
    %{
      id_prefix: id_prefix,
      scale: scale,
      limit: limit,
      by: by,
      when_nil: when_nil,
      on_deny: on_deny_handler
    } = config

    plug_name = plug_name(id_prefix)

    request_id =
      case by do
        :ip ->
          "List.to_string(:inet.ntoa(conn.remote_ip))"

        {:session, key} ->
          "get_session(conn, #{inspect(key)})"

        {:session, key, func} ->
          """
          if value = get_session(conn, #{key}) do
            #{render_func(func)}(value)
          end
          """

        {:conn, func} ->
          "#{render_func(func)}(conn)"
      end

    on_deny_handler = render_func(on_deny_handler)

    on_deny =
      if on_deny_handler == "Hammer.Plug.default_on_deny_handler" do
        "conn |> send_resp(429, \"Too Many Requests\") |> halt()"
      else
        "#{on_deny_handler}(conn)"
      end

    nil_handler =
      case when_nil do
        :use_nil ->
          fn body ->
            """
            # note that request_id might be nil
            #{body}
            """
          end

        :raise ->
          fn body ->
            """
            if request_id do
              #{body}
            else
              raise "Rate limiting request identifier value is nil"
            end
            """
          end

        :pass ->
          fn body ->
            """
            if request_id do
              #{body}
            else
              conn
            end
            """
          end
      end

    """
    defp #{plug_name}(conn, _opts) do
      request_id = #{request_id}

      #{nil_handler.("""
    key = "#{id_prefix}:\#{request_id}"
    scale = #{scale}
    limit = #{limit}

    case Hammer.check_rate(key, scale, limit) do
    {:allow, _count} ->
      conn

    {:deny, _limit} ->
      #{on_deny}

    {:error, _reason} ->
      #{on_deny}
    end
    """)}
    end
    """
    |> Code.format_string!()
    |> IO.iodata_to_binary()
  end
end

defmodule Hammer.Plug.NilError do
  defexception message: "Request identifier value is nil, and :on_nil option set to :raise"
end
