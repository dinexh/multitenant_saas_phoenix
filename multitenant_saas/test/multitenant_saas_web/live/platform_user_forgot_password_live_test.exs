defmodule MultitenantSaasWeb.PlatformUserForgotPasswordLiveTest do
  use MultitenantSaasWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MultitenantSaas.AccountsFixtures

  alias MultitenantSaas.Accounts
  alias MultitenantSaas.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/platform_users/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/platform_users/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/platform_users/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_platform_user(platform_user_fixture())
        |> live(~p"/platform_users/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, platform_user: platform_user} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", platform_user: %{"email" => platform_user.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Accounts.PlatformUserToken, platform_user_id: platform_user.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", platform_user: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.PlatformUserToken) == []
    end
  end
end
