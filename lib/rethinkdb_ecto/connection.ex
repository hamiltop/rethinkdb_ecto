defmodule RethinkDB.Ecto.Connection do
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
    Ecto.Model.Callbacks.__apply__(module, :before_insert, changeset)
    table = model_table(model)
    data = model
      |> Map.from_struct
      |> Map.delete(:__meta__)
      |> Map.delete(:id)
      |> Map.put(:inserted_at, Query.now)
      |> Map.put(:updated_at, Query.now)
    result = Query.table(table)
      |> Query.insert(data)
      |> connection.run
    case result do
      %Record{data: %{"inserted" => 1, "generated_keys" => [id]}} = x ->
        model = get(connection, module, id)
        changeset = %{changeset | model: model}
        Ecto.Model.Callbacks.__apply__(module, :after_insert, changeset)
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
    Ecto.Model.Callbacks.__apply__(module, :before_update, changeset)
    table = model_table(model)
    data = model
      |> Map.from_struct
      |> Map.delete(:__meta__)
      |> Map.put(:updated_at, Query.now)
    result = Query.table(table)
      |> Query.get(id)
      |> Query.update(data)
      |> connection.run
    case result do
      %Record{data: %{"replaced" => 1}} = x ->
        model = get(connection, module, id)
        changeset = %{changeset | model: model}
        Ecto.Model.Callbacks.__apply__(module, :after_update, changeset)
        {:ok, model}
    end
  end

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
    Ecto.Model.Callbacks.__apply__(module, :before_delete, changeset)
    table = model_table(model)
    result = Query.table(table)
      |> Query.get(id)
      |> Query.delete
      |> connection.run
    case result do
      %Record{data: %{"deleted" => 1}} ->
        model = put_in(model.__meta__.state, :deleted)
        changeset = %{changeset | model: model}
        Ecto.Model.Callbacks.__apply__(module, :after_delete, changeset)
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
    {:ok, data}
  end

  defmacro __using__(_) do
    quote do
      use RethinkDB.Connection

      def get(model, id) do
        RethinkDB.Ecto.Connection.get(__MODULE__, model, id)
      end

      def all(model) do
        RethinkDB.Ecto.Connection.all(__MODULE__, model)
      end

      def insert(changeset) do
        RethinkDB.Ecto.Connection.insert(__MODULE__, changeset)
      end

      def update(changeset) do
        RethinkDB.Ecto.Connection.update(__MODULE__, changeset)
      end

      def delete(changeset) do
        RethinkDB.Ecto.Connection.delete(__MODULE__, changeset)
      end

      def query(model, query) do
        RethinkDB.Ecto.Connection.query(__MODULE__, model, query)
      end
    end
  end
end
