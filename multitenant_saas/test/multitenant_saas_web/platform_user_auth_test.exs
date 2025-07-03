defmodule MultitenantSaasWeb.PlatformUserAuthTest do
  use MultitenantSaasWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias MultitenantSaas.Accounts
  alias MultitenantSaasWeb.PlatformUserAuth
  import MultitenantSaas.AccountsFixtures

  @remember_me_cookie "_multitenant_saas_web_platform_user_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, MultitenantSaasWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{platform_user: platform_user_fixture(), conn: conn}
  end

  describe "log_in_platform_user/3" do
    test "stores the platform_user token in the session", %{conn: conn, platform_user: platform_user} do
      conn = PlatformUserAuth.log_in_platform_user(conn, platform_user)
      assert token = get_session(conn, :platform_user_token)
      assert get_session(conn, :live_socket_id) == "platform_users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_platform_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, platform_user: platform_user} do
      conn = conn |> put_session(:to_be_removed, "value") |> PlatformUserAuth.log_in_platform_user(platform_user)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, platform_user: platform_user} do
      conn = conn |> put_session(:platform_user_return_to, "/hello") |> PlatformUserAuth.log_in_platform_user(platform_user)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, platform_user: platform_user} do
      conn = conn |> fetch_cookies() |> PlatformUserAuth.log_in_platform_user(platform_user, %{"remember_me" => "true"})
      assert get_session(conn, :platform_user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :platform_user_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_platform_user/1" do
    test "erases session and cookies", %{conn: conn, platform_user: platform_user} do
      platform_user_token = Accounts.generate_platform_user_session_token(platform_user)

      conn =
        conn
        |> put_session(:platform_user_token, platform_user_token)
        |> put_req_cookie(@remember_me_cookie, platform_user_token)
        |> fetch_cookies()
        |> PlatformUserAuth.log_out_platform_user()

      refute get_session(conn, :platform_user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_platform_user_by_session_token(platform_user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "platform_users_sessions:abcdef-token"
      MultitenantSaasWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> PlatformUserAuth.log_out_platform_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if platform_user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> PlatformUserAuth.log_out_platform_user()
      refute get_session(conn, :platform_user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_platform_user/2" do
    test "authenticates platform_user from session", %{conn: conn, platform_user: platform_user} do
      platform_user_token = Accounts.generate_platform_user_session_token(platform_user)
      conn = conn |> put_session(:platform_user_token, platform_user_token) |> PlatformUserAuth.fetch_current_platform_user([])
      assert conn.assigns.current_platform_user.id == platform_user.id
    end

    test "authenticates platform_user from cookies", %{conn: conn, platform_user: platform_user} do
      logged_in_conn =
        conn |> fetch_cookies() |> PlatformUserAuth.log_in_platform_user(platform_user, %{"remember_me" => "true"})

      platform_user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> PlatformUserAuth.fetch_current_platform_user([])

      assert conn.assigns.current_platform_user.id == platform_user.id
      assert get_session(conn, :platform_user_token) == platform_user_token

      assert get_session(conn, :live_socket_id) ==
               "platform_users_sessions:#{Base.url_encode64(platform_user_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, platform_user: platform_user} do
      _ = Accounts.generate_platform_user_session_token(platform_user)
      conn = PlatformUserAuth.fetch_current_platform_user(conn, [])
      refute get_session(conn, :platform_user_token)
      refute conn.assigns.current_platform_user
    end
  end

  describe "on_mount :mount_current_platform_user" do
    test "assigns current_platform_user based on a valid platform_user_token", %{conn: conn, platform_user: platform_user} do
      platform_user_token = Accounts.generate_platform_user_session_token(platform_user)
      session = conn |> put_session(:platform_user_token, platform_user_token) |> get_session()

      {:cont, updated_socket} =
        PlatformUserAuth.on_mount(:mount_current_platform_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_platform_user.id == platform_user.id
    end

    test "assigns nil to current_platform_user assign if there isn't a valid platform_user_token", %{conn: conn} do
      platform_user_token = "invalid_token"
      session = conn |> put_session(:platform_user_token, platform_user_token) |> get_session()

      {:cont, updated_socket} =
        PlatformUserAuth.on_mount(:mount_current_platform_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_platform_user == nil
    end

    test "assigns nil to current_platform_user assign if there isn't a platform_user_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        PlatformUserAuth.on_mount(:mount_current_platform_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_platform_user == nil
    end
  end

  describe "on_mount :ensure_authenticated" do
    test "authenticates current_platform_user based on a valid platform_user_token", %{conn: conn, platform_user: platform_user} do
      platform_user_token = Accounts.generate_platform_user_session_token(platform_user)
      session = conn |> put_session(:platform_user_token, platform_user_token) |> get_session()

      {:cont, updated_socket} =
        PlatformUserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_platform_user.id == platform_user.id
    end

    test "redirects to login page if there isn't a valid platform_user_token", %{conn: conn} do
      platform_user_token = "invalid_token"
      session = conn |> put_session(:platform_user_token, platform_user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: MultitenantSaasWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = PlatformUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_platform_user == nil
    end

    test "redirects to login page if there isn't a platform_user_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: MultitenantSaasWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = PlatformUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_platform_user == nil
    end
  end

  describe "on_mount :redirect_if_platform_user_is_authenticated" do
    test "redirects if there is an authenticated  platform_user ", %{conn: conn, platform_user: platform_user} do
      platform_user_token = Accounts.generate_platform_user_session_token(platform_user)
      session = conn |> put_session(:platform_user_token, platform_user_token) |> get_session()

      assert {:halt, _updated_socket} =
               PlatformUserAuth.on_mount(
                 :redirect_if_platform_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated platform_user", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               PlatformUserAuth.on_mount(
                 :redirect_if_platform_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_platform_user_is_authenticated/2" do
    test "redirects if platform_user is authenticated", %{conn: conn, platform_user: platform_user} do
      conn = conn |> assign(:current_platform_user, platform_user) |> PlatformUserAuth.redirect_if_platform_user_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if platform_user is not authenticated", %{conn: conn} do
      conn = PlatformUserAuth.redirect_if_platform_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_platform_user/2" do
    test "redirects if platform_user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> PlatformUserAuth.require_authenticated_platform_user([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/platform_users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> PlatformUserAuth.require_authenticated_platform_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :platform_user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> PlatformUserAuth.require_authenticated_platform_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :platform_user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> PlatformUserAuth.require_authenticated_platform_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :platform_user_return_to)
    end

    test "does not redirect if platform_user is authenticated", %{conn: conn, platform_user: platform_user} do
      conn = conn |> assign(:current_platform_user, platform_user) |> PlatformUserAuth.require_authenticated_platform_user([])
      refute conn.halted
      refute conn.status
    end
  end
end
