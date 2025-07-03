defmodule MultitenantSaasWeb.PlatformUserSessionControllerTest do
  use MultitenantSaasWeb.ConnCase, async: true

  import MultitenantSaas.AccountsFixtures

  setup do
    %{platform_user: platform_user_fixture()}
  end

  describe "POST /platform_users/log_in" do
    test "logs the platform_user in", %{conn: conn, platform_user: platform_user} do
      conn =
        post(conn, ~p"/platform_users/log_in", %{
          "platform_user" => %{"email" => platform_user.email, "password" => valid_platform_user_password()}
        })

      assert get_session(conn, :platform_user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ platform_user.email
      assert response =~ ~p"/platform_users/settings"
      assert response =~ ~p"/platform_users/log_out"
    end

    test "logs the platform_user in with remember me", %{conn: conn, platform_user: platform_user} do
      conn =
        post(conn, ~p"/platform_users/log_in", %{
          "platform_user" => %{
            "email" => platform_user.email,
            "password" => valid_platform_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_multitenant_saas_web_platform_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the platform_user in with return to", %{conn: conn, platform_user: platform_user} do
      conn =
        conn
        |> init_test_session(platform_user_return_to: "/foo/bar")
        |> post(~p"/platform_users/log_in", %{
          "platform_user" => %{
            "email" => platform_user.email,
            "password" => valid_platform_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, platform_user: platform_user} do
      conn =
        conn
        |> post(~p"/platform_users/log_in", %{
          "_action" => "registered",
          "platform_user" => %{
            "email" => platform_user.email,
            "password" => valid_platform_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, platform_user: platform_user} do
      conn =
        conn
        |> post(~p"/platform_users/log_in", %{
          "_action" => "password_updated",
          "platform_user" => %{
            "email" => platform_user.email,
            "password" => valid_platform_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/platform_users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/platform_users/log_in", %{
          "platform_user" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/platform_users/log_in"
    end
  end

  describe "DELETE /platform_users/log_out" do
    test "logs the platform_user out", %{conn: conn, platform_user: platform_user} do
      conn = conn |> log_in_platform_user(platform_user) |> delete(~p"/platform_users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :platform_user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the platform_user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/platform_users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :platform_user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
