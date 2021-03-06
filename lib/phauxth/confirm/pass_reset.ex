defmodule Phauxth.Confirm.PassReset do
  @moduledoc """
  Confirm a user in order to reset the password.

  ## Options

  There is one option:

    * key_validity - the length, in minutes, that the token is valid for
      * the default is 20 minutes

  ## Examples

  Add the following lines to the `web/router.ex` file (for a html app):

      resources "/password_resets", PasswordResetController, only: [:new, :create]
      get "/password_resets/edit", PasswordResetController, :edit
      put "/password_resets/update", PasswordResetController, :update

  and for an api, add:

      post "/password_resets/create", PasswordResetController, :create
      put "/password_resets/update", PasswordResetController, :update

  Then add the following to the `password_reset_controller.ex` update function
  (this example is for a html app):

      def update(conn, %{"password_reset" => params}) do
        case Phauxth.Confirm.PassReset.verify(params, MyApp.Accounts, key_validity: 20) do
          {:ok, user} ->
            Accounts.update_user(user, params)
            Message.reset_success(user.email)
            message = "Your password has been reset"
            configure_session(conn, drop: true)
            |> handle_success(message, session_path(conn, :new))
          {:error, message} ->
            conn
            |> put_flash(:error, message)
            |> render("edit.html", email: params["email"], key: params["key"])
        end
      end

  In this example, the `Accounts.update_user` function updates the
  database, setting the `password_hash` value to the hash for the
  new password and the `reset_token` and `reset_sent_at` values to nil.
  """

  use Phauxth.Confirm.Base, ok_log: "password reset"

  def check_key(nil, _, _), do: {:error, "invalid credentials"}
  def check_key(user, key, valid_secs) do
    check_time(user.reset_sent_at, valid_secs) and
    secure_compare(user.reset_token, key) and {:ok, user}
  end
end
