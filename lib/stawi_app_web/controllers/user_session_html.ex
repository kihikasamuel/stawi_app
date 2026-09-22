defmodule StawiAppWeb.UserSessionHTML do
  use StawiAppWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:stawi_app, StawiApp.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
