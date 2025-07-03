defmodule MultitenantSaasWeb.Router do
  use MultitenantSaasWeb, :router
  use Phoenix.Router

  import MultitenantSaasWeb.PlatformUserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MultitenantSaasWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_platform_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :load_tenant do
    plug MultitenantSaasWeb.Plugs.LoadTenant
  end

  pipeline :dev do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", MultitenantSaasWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", MultitenantSaasWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:multitenant_saas, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser, :load_tenant, :dev]

      live_dashboard "/dashboard", metrics: MultitenantSaasWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MultitenantSaasWeb do
    pipe_through [:browser, :redirect_if_platform_user_is_authenticated]

    live_session :redirect_if_platform_user_is_authenticated,
      on_mount: [{MultitenantSaasWeb.PlatformUserAuth, :redirect_if_platform_user_is_authenticated}] do
      live "/platform_users/register", PlatformUserRegistrationLive, :new
      live "/platform_users/log_in", PlatformUserLoginLive, :new
      live "/platform_users/reset_password", PlatformUserForgotPasswordLive, :new
      live "/platform_users/reset_password/:token", PlatformUserResetPasswordLive, :edit
    end

    post "/platform_users/log_in", PlatformUserSessionController, :create
  end

  scope "/", MultitenantSaasWeb do
    pipe_through [:browser, :require_authenticated_platform_user]

    live_session :require_authenticated_platform_user,
      on_mount: [{MultitenantSaasWeb.PlatformUserAuth, :ensure_authenticated}] do
      live "/platform_users/settings", PlatformUserSettingsLive, :edit
      live "/platform_users/settings/confirm_email/:token", PlatformUserSettingsLive, :confirm_email
    end
  end

  scope "/", MultitenantSaasWeb do
    pipe_through [:browser]

    delete "/platform_users/log_out", PlatformUserSessionController, :delete

    live_session :current_platform_user,
      on_mount: [{MultitenantSaasWeb.PlatformUserAuth, :mount_current_platform_user}] do
      live "/platform_users/confirm/:token", PlatformUserConfirmationLive, :edit
      live "/platform_users/confirm", PlatformUserConfirmationInstructionsLive, :new
    end
  end
end
