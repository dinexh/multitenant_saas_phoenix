defmodule MultitenantSaasWeb.PlatformUserSessionController do
  use MultitenantSaasWeb, :controller

  alias MultitenantSaas.Accounts
  alias MultitenantSaasWeb.PlatformUserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:platform_user_return_to, ~p"/platform_users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"platform_user" => platform_user_params}, info) do
    %{"email" => email, "password" => password} = platform_user_params

    if platform_user = Accounts.get_platform_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> PlatformUserAuth.log_in_platform_user(platform_user, platform_user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/platform_users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> PlatformUserAuth.log_out_platform_user()
  end
end
