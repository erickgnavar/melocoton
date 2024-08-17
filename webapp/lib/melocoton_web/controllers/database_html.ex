defmodule MelocotonWeb.DatabaseHTML do
  use MelocotonWeb, :html

  embed_templates "database_html/*"

  @doc """
  Renders a database form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def database_form(assigns)
end
