defmodule MultitenantSaas.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias MultitenantSaas.Repo

  alias MultitenantSaas.Accounts.{PlatformUser, PlatformUserToken, PlatformUserNotifier}

  ## Database getters

  @doc """
  Gets a platform_user by email.

  ## Examples

      iex> get_platform_user_by_email("foo@example.com")
      %PlatformUser{}

      iex> get_platform_user_by_email("unknown@example.com")
      nil

  """
  def get_platform_user_by_email(email) when is_binary(email) do
    Repo.get_by(PlatformUser, email: email)
  end

  @doc """
  Gets a platform_user by email and password.

  ## Examples

      iex> get_platform_user_by_email_and_password("foo@example.com", "correct_password")
      %PlatformUser{}

      iex> get_platform_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_platform_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    platform_user = Repo.get_by(PlatformUser, email: email)
    if PlatformUser.valid_password?(platform_user, password), do: platform_user
  end

  @doc """
  Gets a single platform_user.

  Raises `Ecto.NoResultsError` if the PlatformUser does not exist.

  ## Examples

      iex> get_platform_user!(123)
      %PlatformUser{}

      iex> get_platform_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_platform_user!(id), do: Repo.get!(PlatformUser, id)

  ## Platform user registration

  @doc """
  Registers a platform_user.

  ## Examples

      iex> register_platform_user(%{field: value})
      {:ok, %PlatformUser{}}

      iex> register_platform_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_platform_user(attrs) do
    %PlatformUser{}
    |> PlatformUser.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking platform_user changes.

  ## Examples

      iex> change_platform_user_registration(platform_user)
      %Ecto.Changeset{data: %PlatformUser{}}

  """
  def change_platform_user_registration(%PlatformUser{} = platform_user, attrs \\ %{}) do
    PlatformUser.registration_changeset(platform_user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the platform_user email.

  ## Examples

      iex> change_platform_user_email(platform_user)
      %Ecto.Changeset{data: %PlatformUser{}}

  """
  def change_platform_user_email(platform_user, attrs \\ %{}) do
    PlatformUser.email_changeset(platform_user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_platform_user_email(platform_user, "valid password", %{email: ...})
      {:ok, %PlatformUser{}}

      iex> apply_platform_user_email(platform_user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_platform_user_email(platform_user, password, attrs) do
    platform_user
    |> PlatformUser.email_changeset(attrs)
    |> PlatformUser.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the platform_user email using the given token.

  If the token matches, the platform_user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_platform_user_email(platform_user, token) do
    context = "change:#{platform_user.email}"

    with {:ok, query} <- PlatformUserToken.verify_change_email_token_query(token, context),
         %PlatformUserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(platform_user_email_multi(platform_user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp platform_user_email_multi(platform_user, email, context) do
    changeset =
      platform_user
      |> PlatformUser.email_changeset(%{email: email})
      |> PlatformUser.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:platform_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, PlatformUserToken.by_platform_user_and_contexts_query(platform_user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given platform_user.

  ## Examples

      iex> deliver_platform_user_update_email_instructions(platform_user, current_email, &url(~p"/platform_users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_platform_user_update_email_instructions(%PlatformUser{} = platform_user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, platform_user_token} = PlatformUserToken.build_email_token(platform_user, "change:#{current_email}")

    Repo.insert!(platform_user_token)
    PlatformUserNotifier.deliver_update_email_instructions(platform_user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the platform_user password.

  ## Examples

      iex> change_platform_user_password(platform_user)
      %Ecto.Changeset{data: %PlatformUser{}}

  """
  def change_platform_user_password(platform_user, attrs \\ %{}) do
    PlatformUser.password_changeset(platform_user, attrs, hash_password: false)
  end

  @doc """
  Updates the platform_user password.

  ## Examples

      iex> update_platform_user_password(platform_user, "valid password", %{password: ...})
      {:ok, %PlatformUser{}}

      iex> update_platform_user_password(platform_user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_platform_user_password(platform_user, password, attrs) do
    changeset =
      platform_user
      |> PlatformUser.password_changeset(attrs)
      |> PlatformUser.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:platform_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, PlatformUserToken.by_platform_user_and_contexts_query(platform_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{platform_user: platform_user}} -> {:ok, platform_user}
      {:error, :platform_user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_platform_user_session_token(platform_user) do
    {token, platform_user_token} = PlatformUserToken.build_session_token(platform_user)
    Repo.insert!(platform_user_token)
    token
  end

  @doc """
  Gets the platform_user with the given signed token.
  """
  def get_platform_user_by_session_token(token) do
    {:ok, query} = PlatformUserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_platform_user_session_token(token) do
    Repo.delete_all(PlatformUserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given platform_user.

  ## Examples

      iex> deliver_platform_user_confirmation_instructions(platform_user, &url(~p"/platform_users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_platform_user_confirmation_instructions(confirmed_platform_user, &url(~p"/platform_users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_platform_user_confirmation_instructions(%PlatformUser{} = platform_user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if platform_user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, platform_user_token} = PlatformUserToken.build_email_token(platform_user, "confirm")
      Repo.insert!(platform_user_token)
      PlatformUserNotifier.deliver_confirmation_instructions(platform_user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a platform_user by the given token.

  If the token matches, the platform_user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_platform_user(token) do
    with {:ok, query} <- PlatformUserToken.verify_email_token_query(token, "confirm"),
         %PlatformUser{} = platform_user <- Repo.one(query),
         {:ok, %{platform_user: platform_user}} <- Repo.transaction(confirm_platform_user_multi(platform_user)) do
      {:ok, platform_user}
    else
      _ -> :error
    end
  end

  defp confirm_platform_user_multi(platform_user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:platform_user, PlatformUser.confirm_changeset(platform_user))
    |> Ecto.Multi.delete_all(:tokens, PlatformUserToken.by_platform_user_and_contexts_query(platform_user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given platform_user.

  ## Examples

      iex> deliver_platform_user_reset_password_instructions(platform_user, &url(~p"/platform_users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_platform_user_reset_password_instructions(%PlatformUser{} = platform_user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, platform_user_token} = PlatformUserToken.build_email_token(platform_user, "reset_password")
    Repo.insert!(platform_user_token)
    PlatformUserNotifier.deliver_reset_password_instructions(platform_user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the platform_user by reset password token.

  ## Examples

      iex> get_platform_user_by_reset_password_token("validtoken")
      %PlatformUser{}

      iex> get_platform_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_platform_user_by_reset_password_token(token) do
    with {:ok, query} <- PlatformUserToken.verify_email_token_query(token, "reset_password"),
         %PlatformUser{} = platform_user <- Repo.one(query) do
      platform_user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the platform_user password.

  ## Examples

      iex> reset_platform_user_password(platform_user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %PlatformUser{}}

      iex> reset_platform_user_password(platform_user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_platform_user_password(platform_user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:platform_user, PlatformUser.password_changeset(platform_user, attrs))
    |> Ecto.Multi.delete_all(:tokens, PlatformUserToken.by_platform_user_and_contexts_query(platform_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{platform_user: platform_user}} -> {:ok, platform_user}
      {:error, :platform_user, changeset, _} -> {:error, changeset}
    end
  end
end
