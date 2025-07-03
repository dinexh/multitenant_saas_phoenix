defmodule MultitenantSaas.AccountsTest do
  use MultitenantSaas.DataCase

  alias MultitenantSaas.Accounts

  import MultitenantSaas.AccountsFixtures
  alias MultitenantSaas.Accounts.{PlatformUser, PlatformUserToken}

  describe "get_platform_user_by_email/1" do
    test "does not return the platform_user if the email does not exist" do
      refute Accounts.get_platform_user_by_email("unknown@example.com")
    end

    test "returns the platform_user if the email exists" do
      %{id: id} = platform_user = platform_user_fixture()
      assert %PlatformUser{id: ^id} = Accounts.get_platform_user_by_email(platform_user.email)
    end
  end

  describe "get_platform_user_by_email_and_password/2" do
    test "does not return the platform_user if the email does not exist" do
      refute Accounts.get_platform_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the platform_user if the password is not valid" do
      platform_user = platform_user_fixture()
      refute Accounts.get_platform_user_by_email_and_password(platform_user.email, "invalid")
    end

    test "returns the platform_user if the email and password are valid" do
      %{id: id} = platform_user = platform_user_fixture()

      assert %PlatformUser{id: ^id} =
               Accounts.get_platform_user_by_email_and_password(platform_user.email, valid_platform_user_password())
    end
  end

  describe "get_platform_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_platform_user!(-1)
      end
    end

    test "returns the platform_user with the given id" do
      %{id: id} = platform_user = platform_user_fixture()
      assert %PlatformUser{id: ^id} = Accounts.get_platform_user!(platform_user.id)
    end
  end

  describe "register_platform_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_platform_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_platform_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_platform_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = platform_user_fixture()
      {:error, changeset} = Accounts.register_platform_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_platform_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers platform_users with a hashed password" do
      email = unique_platform_user_email()
      {:ok, platform_user} = Accounts.register_platform_user(valid_platform_user_attributes(email: email))
      assert platform_user.email == email
      assert is_binary(platform_user.hashed_password)
      assert is_nil(platform_user.confirmed_at)
      assert is_nil(platform_user.password)
    end
  end

  describe "change_platform_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_platform_user_registration(%PlatformUser{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_platform_user_email()
      password = valid_platform_user_password()

      changeset =
        Accounts.change_platform_user_registration(
          %PlatformUser{},
          valid_platform_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_platform_user_email/2" do
    test "returns a platform_user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_platform_user_email(%PlatformUser{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_platform_user_email/3" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "requires email to change", %{platform_user: platform_user} do
      {:error, changeset} = Accounts.apply_platform_user_email(platform_user, valid_platform_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{platform_user: platform_user} do
      {:error, changeset} =
        Accounts.apply_platform_user_email(platform_user, valid_platform_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{platform_user: platform_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_platform_user_email(platform_user, valid_platform_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{platform_user: platform_user} do
      %{email: email} = platform_user_fixture()
      password = valid_platform_user_password()

      {:error, changeset} = Accounts.apply_platform_user_email(platform_user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{platform_user: platform_user} do
      {:error, changeset} =
        Accounts.apply_platform_user_email(platform_user, "invalid", %{email: unique_platform_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{platform_user: platform_user} do
      email = unique_platform_user_email()
      {:ok, platform_user} = Accounts.apply_platform_user_email(platform_user, valid_platform_user_password(), %{email: email})
      assert platform_user.email == email
      assert Accounts.get_platform_user!(platform_user.id).email != email
    end
  end

  describe "deliver_platform_user_update_email_instructions/3" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "sends token through notification", %{platform_user: platform_user} do
      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_update_email_instructions(platform_user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert platform_user_token = Repo.get_by(PlatformUserToken, token: :crypto.hash(:sha256, token))
      assert platform_user_token.platform_user_id == platform_user.id
      assert platform_user_token.sent_to == platform_user.email
      assert platform_user_token.context == "change:current@example.com"
    end
  end

  describe "update_platform_user_email/2" do
    setup do
      platform_user = platform_user_fixture()
      email = unique_platform_user_email()

      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_update_email_instructions(%{platform_user | email: email}, platform_user.email, url)
        end)

      %{platform_user: platform_user, token: token, email: email}
    end

    test "updates the email with a valid token", %{platform_user: platform_user, token: token, email: email} do
      assert Accounts.update_platform_user_email(platform_user, token) == :ok
      changed_platform_user = Repo.get!(PlatformUser, platform_user.id)
      assert changed_platform_user.email != platform_user.email
      assert changed_platform_user.email == email
      assert changed_platform_user.confirmed_at
      assert changed_platform_user.confirmed_at != platform_user.confirmed_at
      refute Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end

    test "does not update email with invalid token", %{platform_user: platform_user} do
      assert Accounts.update_platform_user_email(platform_user, "oops") == :error
      assert Repo.get!(PlatformUser, platform_user.id).email == platform_user.email
      assert Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end

    test "does not update email if platform_user email changed", %{platform_user: platform_user, token: token} do
      assert Accounts.update_platform_user_email(%{platform_user | email: "current@example.com"}, token) == :error
      assert Repo.get!(PlatformUser, platform_user.id).email == platform_user.email
      assert Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end

    test "does not update email if token expired", %{platform_user: platform_user, token: token} do
      {1, nil} = Repo.update_all(PlatformUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_platform_user_email(platform_user, token) == :error
      assert Repo.get!(PlatformUser, platform_user.id).email == platform_user.email
      assert Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end
  end

  describe "change_platform_user_password/2" do
    test "returns a platform_user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_platform_user_password(%PlatformUser{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_platform_user_password(%PlatformUser{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_platform_user_password/3" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "validates password", %{platform_user: platform_user} do
      {:error, changeset} =
        Accounts.update_platform_user_password(platform_user, valid_platform_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{platform_user: platform_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_platform_user_password(platform_user, valid_platform_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{platform_user: platform_user} do
      {:error, changeset} =
        Accounts.update_platform_user_password(platform_user, "invalid", %{password: valid_platform_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{platform_user: platform_user} do
      {:ok, platform_user} =
        Accounts.update_platform_user_password(platform_user, valid_platform_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(platform_user.password)
      assert Accounts.get_platform_user_by_email_and_password(platform_user.email, "new valid password")
    end

    test "deletes all tokens for the given platform_user", %{platform_user: platform_user} do
      _ = Accounts.generate_platform_user_session_token(platform_user)

      {:ok, _} =
        Accounts.update_platform_user_password(platform_user, valid_platform_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end
  end

  describe "generate_platform_user_session_token/1" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "generates a token", %{platform_user: platform_user} do
      token = Accounts.generate_platform_user_session_token(platform_user)
      assert platform_user_token = Repo.get_by(PlatformUserToken, token: token)
      assert platform_user_token.context == "session"

      # Creating the same token for another platform_user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%PlatformUserToken{
          token: platform_user_token.token,
          platform_user_id: platform_user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_platform_user_by_session_token/1" do
    setup do
      platform_user = platform_user_fixture()
      token = Accounts.generate_platform_user_session_token(platform_user)
      %{platform_user: platform_user, token: token}
    end

    test "returns platform_user by token", %{platform_user: platform_user, token: token} do
      assert session_platform_user = Accounts.get_platform_user_by_session_token(token)
      assert session_platform_user.id == platform_user.id
    end

    test "does not return platform_user for invalid token" do
      refute Accounts.get_platform_user_by_session_token("oops")
    end

    test "does not return platform_user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(PlatformUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_platform_user_by_session_token(token)
    end
  end

  describe "delete_platform_user_session_token/1" do
    test "deletes the token" do
      platform_user = platform_user_fixture()
      token = Accounts.generate_platform_user_session_token(platform_user)
      assert Accounts.delete_platform_user_session_token(token) == :ok
      refute Accounts.get_platform_user_by_session_token(token)
    end
  end

  describe "deliver_platform_user_confirmation_instructions/2" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "sends token through notification", %{platform_user: platform_user} do
      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_confirmation_instructions(platform_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert platform_user_token = Repo.get_by(PlatformUserToken, token: :crypto.hash(:sha256, token))
      assert platform_user_token.platform_user_id == platform_user.id
      assert platform_user_token.sent_to == platform_user.email
      assert platform_user_token.context == "confirm"
    end
  end

  describe "confirm_platform_user/1" do
    setup do
      platform_user = platform_user_fixture()

      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_confirmation_instructions(platform_user, url)
        end)

      %{platform_user: platform_user, token: token}
    end

    test "confirms the email with a valid token", %{platform_user: platform_user, token: token} do
      assert {:ok, confirmed_platform_user} = Accounts.confirm_platform_user(token)
      assert confirmed_platform_user.confirmed_at
      assert confirmed_platform_user.confirmed_at != platform_user.confirmed_at
      assert Repo.get!(PlatformUser, platform_user.id).confirmed_at
      refute Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end

    test "does not confirm with invalid token", %{platform_user: platform_user} do
      assert Accounts.confirm_platform_user("oops") == :error
      refute Repo.get!(PlatformUser, platform_user.id).confirmed_at
      assert Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end

    test "does not confirm email if token expired", %{platform_user: platform_user, token: token} do
      {1, nil} = Repo.update_all(PlatformUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_platform_user(token) == :error
      refute Repo.get!(PlatformUser, platform_user.id).confirmed_at
      assert Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end
  end

  describe "deliver_platform_user_reset_password_instructions/2" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "sends token through notification", %{platform_user: platform_user} do
      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_reset_password_instructions(platform_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert platform_user_token = Repo.get_by(PlatformUserToken, token: :crypto.hash(:sha256, token))
      assert platform_user_token.platform_user_id == platform_user.id
      assert platform_user_token.sent_to == platform_user.email
      assert platform_user_token.context == "reset_password"
    end
  end

  describe "get_platform_user_by_reset_password_token/1" do
    setup do
      platform_user = platform_user_fixture()

      token =
        extract_platform_user_token(fn url ->
          Accounts.deliver_platform_user_reset_password_instructions(platform_user, url)
        end)

      %{platform_user: platform_user, token: token}
    end

    test "returns the platform_user with valid token", %{platform_user: %{id: id}, token: token} do
      assert %PlatformUser{id: ^id} = Accounts.get_platform_user_by_reset_password_token(token)
      assert Repo.get_by(PlatformUserToken, platform_user_id: id)
    end

    test "does not return the platform_user with invalid token", %{platform_user: platform_user} do
      refute Accounts.get_platform_user_by_reset_password_token("oops")
      assert Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end

    test "does not return the platform_user if token expired", %{platform_user: platform_user, token: token} do
      {1, nil} = Repo.update_all(PlatformUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_platform_user_by_reset_password_token(token)
      assert Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end
  end

  describe "reset_platform_user_password/2" do
    setup do
      %{platform_user: platform_user_fixture()}
    end

    test "validates password", %{platform_user: platform_user} do
      {:error, changeset} =
        Accounts.reset_platform_user_password(platform_user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{platform_user: platform_user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_platform_user_password(platform_user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{platform_user: platform_user} do
      {:ok, updated_platform_user} = Accounts.reset_platform_user_password(platform_user, %{password: "new valid password"})
      assert is_nil(updated_platform_user.password)
      assert Accounts.get_platform_user_by_email_and_password(platform_user.email, "new valid password")
    end

    test "deletes all tokens for the given platform_user", %{platform_user: platform_user} do
      _ = Accounts.generate_platform_user_session_token(platform_user)
      {:ok, _} = Accounts.reset_platform_user_password(platform_user, %{password: "new valid password"})
      refute Repo.get_by(PlatformUserToken, platform_user_id: platform_user.id)
    end
  end

  describe "inspect/2 for the PlatformUser module" do
    test "does not include password" do
      refute inspect(%PlatformUser{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
