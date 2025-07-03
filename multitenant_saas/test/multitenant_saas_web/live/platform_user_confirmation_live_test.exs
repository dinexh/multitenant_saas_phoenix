defmodule MultitenantSaasWeb.PlatformUserConfirmationLiveTest do
  use MultitenantSaasWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MultitenantSaas.AccountsFixtures

  alias MultitenantSaas.Accounts
  alias MultitenantSaas.Repo

  setup do
    %{platform_user: platform_user_fixture()}
  end

  describe "Confirm platform_user" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/platform_users/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, platform_user: platform_user} do
      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_confirmation_instructions(platform_user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/platform_users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "PlatformUser confirmed successfully"

      assert Accounts.get_platform_user!(platform_user.id).confirmed_at
      refute get_session(conn, :platform_user_token)
      assert Repo.all(Accounts.PlatformUserToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/platform_users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "PlatformUser confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_platform_user(platform_user)

      {:ok, lv, _html} = live(conn, ~p"/platform_users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, platform_user: platform_user} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "PlatformUser confirmation link is invalid or it has expired"

      refute Accounts.get_platform_user!(platform_user.id).confirmed_at
    end
  end
end
