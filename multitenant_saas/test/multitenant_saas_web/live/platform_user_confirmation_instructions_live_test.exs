defmodule MultitenantSaasWeb.PlatformUserConfirmationInstructionsLiveTest do
  use MultitenantSaasWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MultitenantSaas.AccountsFixtures

  alias MultitenantSaas.Accounts
  alias MultitenantSaas.Repo

  setup do
    %{platform_user: platform_user_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/platform_users/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, platform_user: platform_user} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", platform_user: %{email: platform_user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.PlatformUserToken, platform_user_id: platform_user.id).context == "confirm"
    end

    test "does not send confirmation token if platform_user is confirmed", %{conn: conn, platform_user: platform_user} do
      Repo.update!(Accounts.PlatformUser.confirm_changeset(platform_user))

      {:ok, lv, _html} = live(conn, ~p"/platform_users/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", platform_user: %{email: platform_user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.PlatformUserToken, platform_user_id: platform_user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", platform_user: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.PlatformUserToken) == []
    end
  end
end
