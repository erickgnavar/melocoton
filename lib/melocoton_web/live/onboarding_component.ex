defmodule MelocotonWeb.OnboardingComponent do
  use MelocotonWeb, :live_component

  alias Melocoton.Settings

  @total_steps 6

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:step, fn -> 0 end)
    |> assign(:total_steps, @total_steps)
    |> ok()
  end

  @impl true
  def handle_event("next-step", _params, socket) do
    if socket.assigns.step >= @total_steps - 1 do
      complete(socket)
    else
      socket |> assign(:step, socket.assigns.step + 1) |> noreply()
    end
  end

  @impl true
  def handle_event("prev-step", _params, socket) do
    socket |> assign(:step, max(socket.assigns.step - 1, 0)) |> noreply()
  end

  @impl true
  def handle_event("skip-onboarding", _params, socket) do
    complete(socket)
  end

  defp complete(socket) do
    Settings.set("onboarding_completed", "true")
    send(self(), {__MODULE__, :onboarding_completed})
    noreply(socket)
  end
end
