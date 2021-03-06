defmodule Phauxth.Authenticate.Base do
  @moduledoc """
  Base module for authentication.

  This is used by Phauxth.Authenticate and Phauxth.Remember.
  It can also be used to produce a custom authentication module,
  as outlined below.

  ## Custom authentication modules

  One example of a custom authentication module is provided by the
  Phauxth.Remember module, which uses this base module to provide the
  'remember me' functionality.

  ### Graphql authentication

  The following module is another example of how this Base module can
  be extended, this time to provide authentication for absinthe-elixir:

      defmodule AbsintheAuthenticate do

        use Phauxth.Authenticate.Base
        import Plug.Conn

        def set_user(user, conn) do
          put_private(conn, :absinthe, %{token: %{current_user: user}})
        end
      end

  And in the `router.ex` file, call this plug in the pipeline you
  want to authenticate (setting the method to :token).

      pipeline :api do
        plug :accepts, ["json"]
        plug AbsintheAuthenticate, method: :token
      end

  """

  @doc false
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      @behaviour Plug

      import Plug.Conn
      alias Phauxth.Token

      @doc false
      def init(opts) do
        {Keyword.get(opts, :method, :session),
        Keyword.get(opts, :max_age, 24 * 60 * 60),
        Keyword.get(opts, :user_context, default_user_context())}
      end

      @doc false
      def call(conn, opts) do
        get_user(conn, opts) |> log_user |> set_user(conn)
      end

      @doc """
      Get the user based on the session id or token id.

      This function also calls the database to get user information.
      """
      def get_user(conn, {:session, _, user_context}) do
        with user_id when not is_nil(user_id) <- get_session(conn, :user_id),
          do: user_context.get(user_id)
      end
      def get_user(%Plug.Conn{req_headers: headers} = conn,
          {:token, max_age, user_context}) do
        with {_, token} <- List.keyfind(headers, "authorization", 0),
             {:ok, user_id} <- check_token(token, {conn, max_age}),
          do: user_context.get(user_id)
      end

      @doc """
      Verify the token.

      This function can be overridden if you want to use a different
      token implementation.
      """
      def check_token(token, {conn, max_age}) do
        Token.verify(conn, token, max_age: max_age)
      end

      @doc """
      Set the `current_user` variable.
      """
      def set_user(user, conn) do
        Plug.Conn.assign(conn, :current_user, user)
      end

      defp default_user_context do
        Mix.Project.config
        |> Keyword.fetch!(:app)
        |> to_string
        |> Macro.camelize
        |> Module.concat(Accounts)
      end

      defoverridable [init: 1, call: 2, get_user: 2, check_token: 2, set_user: 2]
    end
  end

  alias Phauxth.{Config, Log}

  @doc """
  Log the result of the authentication and return the user struct or nil.
  """
  def log_user(nil) do
    Log.info(%Log{}) && nil
  end
  def log_user({:error, msg}) do
    Log.info(%Log{message: "#{msg} token"}) && nil
  end
  def log_user(user) do
    Log.info(%Log{user: user.id, message: "User authenticated"})
    Map.drop(user, Config.drop_user_keys)
  end
end
