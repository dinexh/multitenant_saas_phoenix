defmodule MultitenantSaas.Accounts.PlatformUserNotifier do
  import Swoosh.Email

  alias MultitenantSaas.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"MultitenantSaas", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(platform_user, url) do
    deliver(platform_user.email, "Confirmation instructions", """

    ==============================

    Hi #{platform_user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a platform_user password.
  """
  def deliver_reset_password_instructions(platform_user, url) do
    deliver(platform_user.email, "Reset password instructions", """

    ==============================

    Hi #{platform_user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a platform_user email.
  """
  def deliver_update_email_instructions(platform_user, url) do
    deliver(platform_user.email, "Update email instructions", """

    ==============================

    Hi #{platform_user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
