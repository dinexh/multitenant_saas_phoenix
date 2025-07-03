defmodule MultitenantSaasWeb.PlatformUserSettingsLiveTest do
  use MultitenantSaasWeb.ConnCase, async: true

  alias MultitenantSaas.Accounts
  import Phoenix.LiveViewTest
  import MultitenantSaas.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_platform_user(platform_user_fixture())
        |> live(~p"/platform_users/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if platform_user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/platform_users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/platform_users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_platform_user_password()
      platform_user = platform_user_fixture(%{password: password})
      %{conn: log_in_platform_user(conn, platform_user), platform_user: platform_user, password: password}
    end

    test "updates the platform_user email", %{conn: conn, password: password, platform_user: platform_user} do
      new_email = unique_platform_user_email()

      {:ok, lv, _html} = live(conn, ~p"/platform_users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "platform_user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_platform_user_by_email(platform_user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "platform_user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, platform_user: platform_user} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "platform_user" => %{"email" => platform_user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_platform_user_password()
      platform_user = platform_user_fixture(%{password: password})
      %{conn: log_in_platform_user(conn, platform_user), platform_user: platform_user, password: password}
    end

    test "updates the platform_user password", %{conn: conn, platform_user: platform_user, password: password} do
      new_password = valid_platform_user_password()

      {:ok, lv, _html} = live(conn, ~p"/platform_users/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "platform_user" => %{
            "email" => platform_user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/platform_users/settings"

      assert get_session(new_password_conn, :platform_user_token) != get_session(conn, :platform_user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_platform_user_by_email_and_password(platform_user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "platform_user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/platform_users/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "platform_user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      platform_user = platform_user_fixture()
      email = unique_platform_user_email()

      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_update_email_instructions(%{platform_user | email: email}, platform_user.email, url)
        end)

      %{conn: log_in_platform_user(conn, platform_user), token: token, email: email, platform_user: platform_user}
    end

    test "updates the platform_user email once", %{conn: conn, platform_user: platform_user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/platform_users/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/platform_users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_platform_user_by_email(platform_user.email)
      assert Accounts.get_platform_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/platform_users/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/platform_users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, platform_user: platform_user} do
      {:error, redirect} = live(conn, ~p"/platform_users/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/platform_users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_platform_user_by_email(platform_user.email)
    end

    test "redirects if platform_user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/platform_users/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/platform_users/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
