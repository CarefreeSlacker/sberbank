defmodule SberbankWeb.CustomerTicketsController do
  use SberbankWeb, :controller

  alias Sberbank.{Customers, Staff}
  alias Sberbank.Customers.Ticket
  alias Sberbank.Pipeline.RabbitClient

  def index(conn, %{"customer_id" => customer_id}) do
    %{customer: customer, tickets: tickets, competences: competences} =
      preload_necessary_data(customer_id)

    ticket_changeset = Customers.change_ticket(%Ticket{customer_id: customer.id})

    render(conn, "index.html",
      customer: customer,
      tickets: tickets,
      competences: competences,
      ticket_changeset: ticket_changeset
    )
  end

  def create(conn, %{"customer_id" => customer_id, "ticket" => ticket_params}) do
    case Customers.create_ticket(ticket_params) do
      {:ok, ticket} ->
        RabbitClient.push_ticket(ticket)

        conn
        |> put_flash(:info, "Ticket created successfully")
        |> redirect(to: Routes.customer_customer_tickets_path(conn, :index, customer_id))

      {:error, %Ecto.Changeset{} = ticket_changeset} ->
        %{customer: customer, tickets: tickets, competences: competences} =
          preload_necessary_data(customer_id)

        render(conn, "new.index",
          customer: customer,
          tickets: tickets,
          competences: competences,
          ticket_changeset: ticket_changeset
        )
    end
  end

  def delete(conn, %{"customer_id" => customer_id, "id" => ticket_id}) do
    ticket_id
    |> Customers.get_ticket!()
    |> Customers.delete_ticket()

    conn
    |> put_flash(:info, "Ticket deleted successfully")
    |> redirect(to: Routes.customer_customer_tickets_path(conn, :index, customer_id))
  end

  defp preload_necessary_data(customer_id) do
    customer = Customers.get_customer!(customer_id, tickets: [:competence, :operators])

    %{tickets: tickets} = customer
    competences = Staff.list_competencies()

    %{customer: customer, tickets: tickets, competences: competences}
  end
end
