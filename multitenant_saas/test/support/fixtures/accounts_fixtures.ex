defmodule MultitenantSaas.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MultitenantSaas.Accounts` context.
  """

  def unique_platform_user_email, do: "platform_user#{System.unique_integer()}@example.com"
  def valid_platform_user_password, do: "hello world!"

  def valid_platform_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_platform_user_email(),
      password: valid_platform_user_password()
    })
  end

  def platform_user_fixture(attrs \\ %{}) do
    {:ok, platform_user} =
      attrs
      |> valid_platform_user_attributes()
      |> MultitenantSaas.Accounts.register_platform_user()

    platform_user
  end

  def extract_platform_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
