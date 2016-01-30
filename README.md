# RethinkDB Ecto

Shim library to make it easy to use RethinkDB with Ecto. This is not a full Ecto adapter. It allows using Changesets and validations and callbacks. It basically enables Ecto.Model only.

Still very Proof of Concept. Feedback wanted.

Examples:

instead of:
```elixir
def MyApp.Repo do
  use Ecto.Repo
end
```

do:

```elixir
def MyApp.Repo do
  use RethinkDB.Ecto.Repo
end
```

and then use it like:

```elixir
p = Repo.get(Post, 1)

changeset = Post.changeset(p, %{title: "cool stuff"})

Repo.update(changeset)

Repo.delete(p)

Repo.all(Post)

p = %Post{title: "boring stuff"}

Repo.insert(p)


query = table("posts") |>
	filter(fn (post) ->
	  post[:title] != "boring stuff" || post[:author] == "Greg"
	end)

Repo.query(Post, query)

```
