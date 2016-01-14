defmodule RethinkDB.Ecto.Repo do
  alias RethinkDB.Record
  alias RethinkDB.Collection
  alias RethinkDB.Query

  defp load_result(model, %Record{data: nil}) do
    nil
  end

  defp load_result(model, %Record{data: data}) do
    load_model(model, data)
  end

  defp load_result(model, %Collection{data: data}) do
    Enum.map data, fn (el) ->
      load_model(model, el)
    end
  end

  def all(module, model) do
    table = model_table(model)
    query(module, model, Query.table(table))
  end

  def query(module, model, query) do
    result = module.run(query)
    load_result(model, result)
  end

  def get(module, model, id) do
    table = model_table(model)
    get_query = Query.table(table)
      |> Query.get(id)
    query(module, model, get_query)
  end

  def insert(module, changeset = %Ecto.Changeset{}) do
    case changeset.errors do
      [] ->
        do_insert(module, changeset)
      _ ->
        {:error, changeset}
    end
  end

  def insert(module, model) do
    changeset = Ecto.Changeset.change(model)
    insert(module, changeset)
  end

  defp do_insert(connection, changeset) do
    model = Ecto.Changeset.apply_changes(changeset)
    module = model.__struct__
    table = model_table(model)
    data = model
      |> Map.from_struct
      |> Map.delete(:__meta__)
      |> Map.delete(:id)
      |> Map.put(:inserted_at, Query.now)
      |> Map.put(:updated_at, Query.now)
      |> Enum.map(&convert_date/1)
      |> Enum.into(%{})
    result = Query.table(table)
      |> Query.insert(data)
      |> connection.run
    case result do
      %Record{data: %{"inserted" => 1, "generated_keys" => [id]}} = x ->
        model = get(connection, module, id)
        changeset = %{changeset | model: model}
        {:ok, model}
      %Record{data: %{"inserted" => 1}} = x ->
        changeset = %{changeset | model: model}
        {:ok, model}
    end
  end

  def update(module, changeset = %Ecto.Changeset{}) do
    case changeset.errors do
      [] ->
        do_update(module, changeset)
      _ ->
        {:error, changeset}
    end
  end

  def update(module, model) do
    changeset = Ecto.Changeset.change(model)
    update(module, changeset)
  end

  defp do_update(connection, changeset) do
    model = Ecto.Changeset.apply_changes(changeset)
    module = model.__struct__
    id = model.id
    table = model_table(model)
    data = model
      |> Map.from_struct
      |> Map.delete(:__meta__)
      |> Map.put(:updated_at, Query.now)
      |> Enum.map(&convert_date/1)
      |> Enum.into(%{})
    result = Query.table(table)
      |> Query.get(id)
      |> Query.update(data)
      |> connection.run
    case result do
      %Record{data: %{"replaced" => 1}} = x ->
        model = get(connection, module, id)
        changeset = %{changeset | model: model}
        {:ok, model}
    end
  end

  defp convert_date({attr, %Ecto.Date{year: year, month: month, day: day}}) do
    {attr, RethinkDB.Query.time(year, month, day, "Z")}
  end

  defp convert_date({attr, %Ecto.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, usec: usec}}) do
    {attr, RethinkDB.Query.time(year, month, day, hour, min, sec, "Z")}
  end

  defp convert_date(x), do: x

  defp convert_date_from_rethinkdb(%RethinkDB.Pseudotypes.Time{epoch_time: epoch_time}) do
    epoch_time
    |> round
    |> +(62167219200) # :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
    |> :calendar.gregorian_seconds_to_datetime
    |> convert_date_from_erl
  end

  defp convert_date_from_rethinkdb(x), do: x

  defp convert_date_from_erl({date, {0, 0, 0}}), do: Ecto.Date.from_erl(date)
  defp convert_date_from_erl({date, time}), do: Ecto.DateTime.from_erl({date, time})


  def delete(connection, changeset = %Ecto.Changeset{}) do
    # validations?
    do_delete(connection, changeset)
  end

  def delete(connection, model) do
    changeset = Ecto.Changeset.change(model)
    delete(connection, changeset)
  end

  defp do_delete(connection, changeset) do
    model = Ecto.Changeset.apply_changes(changeset)
    module = model.__struct__
    id = model.id
    table = model_table(model)
    result = Query.table(table)
      |> Query.get(id)
      |> Query.delete
      |> connection.run
    case result do
      %Record{data: %{"deleted" => 1}} ->
        model = put_in(model.__meta__.state, :deleted)
        changeset = %{changeset | model: model}
        {:ok, model}
    end
  end

  defp model_table(model) do
    struct(model).__meta__.source |> elem(1)
  end

  defp load_model(model, data) do
    Ecto.Schema.__load__(model, nil, nil, [], data, &load/2)
  end

  defp load(x, data) do
    {:ok, convert_date_from_rethinkdb(data)}
  end

  defmacro __using__(opts) do
    otp_app = Dict.fetch!(opts, :otp_app)
    quote do
      use RethinkDB.Connection

      @behaviour Ecto.Repo
      @otp_app unquote(otp_app)

      def __adapter__, do: RethinkDB.Ecto.Adapter
      def __pool__, do: {:error, __MODULE__}
      def __query_cache__, do: {:error, __MODULE__}
      def __repo__, do: true

      def start_link() do
        opts = Dict.take(config, [:database, :hostname, :port, :auth_key])
          |> Enum.map(fn
            {:database, v} -> {:db, v}
            {:hostname, h} -> {:host, h}
            x -> x
          end)
        start_link(opts)
      end

      def stop(_pid), do: stop

      def config, do: Ecto.Repo.Supervisor.config(__MODULE__, @otp_app, [])

      def get(model, id) do
        RethinkDB.Ecto.Repo.get(__MODULE__, model, id)
      end

      def all(model) do
        RethinkDB.Ecto.Repo.all(__MODULE__, model)
      end

      def all(%Ecto.Query{from: {"schema_migrations", model} } = e, opts) do
        q = Query.table("schema_migrations") |> Query.map(fn (el) ->
          Query.bracket(el, "version")
        end)
        %Collection{data: data} = run(q)
        data
      end

      def delete_all(%Ecto.Query{from: {"schema_migrations", model} } = e, opts) do
        [w] = e.wheres
        [{v, _}] = w.params
        q = Query.table("schema_migrations") |> Query.filter(%{version: v}) |> Query.delete
        run(q)
      end

      def insert(changeset) do
        RethinkDB.Ecto.Repo.insert(__MODULE__, changeset)
      end

      def insert!(changeset, opts) do
        RethinkDB.Ecto.Repo.insert(__MODULE__, changeset)
      end

      def update(changeset) do
        RethinkDB.Ecto.Repo.update(__MODULE__, changeset)
      end

      def delete(changeset) do
        RethinkDB.Ecto.Repo.delete(__MODULE__, changeset)
      end

      def query(model, query) do
        RethinkDB.Ecto.Repo.query(__MODULE__, model, query)
      end
    end
  end
end
