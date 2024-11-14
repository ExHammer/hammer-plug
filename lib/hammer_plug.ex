defmodule Hammer.Plug do
  @moduledoc """
  A plug which rate-limits requests, using the Hammer library.

  ## Usage example:

      # define the rate limiter
      defmodule MyApp.RateLimit do
        use Hammer, backend: :ets
      end

      # register the plug
      plug Hammer.Plug, [
        rate_limit: MyApp.RateLimit,
        key: &MyApp.RateLimit.key_from_conn/1,
        key_path: [:remote_ip],
        scale: :timer.seconds(60),
        limit: 10
      ] when action == :upload_video_file

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

  @impl true
  def init(opts) do
    rate_limiter =
      Keyword.get(opts, :rate_limiter) ||
        raise ArgumentError, """
        Hammer.Plug requires a `:rate_limiter` option that specifies the rate limiter to use.

        Example:

            defmodule MyApp.RateLimit do
              use Hammer, backend: :ets
            end

            plug Hammer.Plug, [
              rate_limiter: MyApp.RateLimit,
              ...
            ]

        """

    by = Keyword.get(opts, :by, :ip)

    valid_by? =
      case by do
        :ip -> true
        {:session, key} when is_atom(key) -> true
        {:session, key, func} when is_atom(key) and is_function(func, 1) -> true
        {:conn, func} when is_function(func, 1) -> true
        _ -> false
      end

    unless valid_by? do
      raise ArgumentError, """
      Hammer.Plug: invalid `by` parameter: #{inspect(by)}
      """
    end

    %{rate_limiter: rate_limiter, by: by}
  end

  @impl true
  def call(conn, config) do
    %{
      rate_limiter: rate_limiter,
      key_prefix: key_prefix,
      by: by,
      on_deny_handler: on_deny_handler,
      when_nil: when_nil
    } = config

    request_id =
      case by do
        :ip ->
          List.to_string(:inet.ntoa(conn.remote_ip))

        {:session, key} ->
          get_session(conn, key)

        {:session, key, func} ->
          if value = get_session(conn, key) do
            func.(value)
          end

        {:conn, func} ->
          func.(conn)
      end

    key = "#{key_prefix}:#{request_id}"

    case rate_limiter.check_rate(key, scale, limit) do
      {:allow, _count} -> conn
      {:deny, wait} -> on_deny_handler.(conn, wait)
    end

    case request_id do
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

      request_id ->
        do_rate_limit_check(conn, id_prefix, id, scale, limit, on_deny_handler)
    end
  end

  def default_on_deny_handler(conn, _opts) do
    conn
    |> send_resp(429, "Too Many Requests")
    |> halt()
  end
end
