defmodule MultitenantSaasWeb.Plugs.LoadTenant do
  alias Triplex

  def init(default), do: default

  def call(conn, _otp) do
    case extract_subdomain(conn.host) do
      nil -> conn
      tenant -> Triplex.put_tenant!(conn, tenant)
    end
  end

  def extract_subdomain(host) do
    case String.split(host, ".") do
      [sub, _domain, _tld] -> sub
      [sub, _domain] -> sub
      _ -> nil
    end
  end
end
