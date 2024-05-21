defmodule FinstaWeb.HomeLive do
  use FinstaWeb, :live_view

  alias Finsta.Posts
  alias Finsta.Posts.Post

  def render(%{loading: true} = assigns) do
    ~H"""
    Loading...
    """
  end

  def render(%{loading: false} = assigns) do
    ~H"""
    <div class="flex gap-4 justify-between items-center mb-6">
      <h1 class="text-2xl">Finsta</h1>
      
      <.button type="buttom" phx-click={show_modal("new-post-modal")}>New Post</.button>
    </div>

    <div id="feed" phx-update="stream" class="flex flex-col gap-8">
      <article :for={{dom_id, post} <- @streams.posts} id={dom_id}>
        <img src={post.image_path} alt="" class="rounded mb-2" />
        <p class="text-gray-400"><%= post.user.email %></p>
        
        <p><%= post.caption %></p>
      </article>
    </div>

    <.modal id="new-post-modal">
      <.simple_form for={@form} phx-change="validate" phx-submit="publish">
        <.live_file_input upload={@uploads.image} required />
        <.input field={@form[:caption]} type="textarea" label="Caption" required />
        <.button type="submit" phx-disable-with="Saving...">Publish Post</.button>
      </.simple_form>
    </.modal>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Finsta.PubSub, "posts")

      form =
        %Post{}
        |> Post.changeset(%{})
        |> to_form(as: "post")

      socket =
        socket
        |> assign(form: form, loading: false)
        |> allow_upload(:image, accept: ~w(.png .jpg), max_entries: 1)
        |> stream(:posts, Posts.list_posts())

      {:ok, socket}
    else
      {:ok, assign(socket, loading: true)}
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("publish", %{"post" => post_params}, socket) do
    %{current_user: user} = socket.assigns

    post_params
    |> Map.put("user_id", user.id)
    |> Map.put("image_path", List.first(consume_files(socket)))
    |> Posts.save()
    |> case do
      {:ok, post} ->
        socket =
          socket
          |> put_flash(:info, "Post created successfully")
          |> push_navigate(to: ~p"/")

        Phoenix.PubSub.broadcast(Finsta.PubSub, "posts", {:new, Map.put(post, :user, user)})

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_info({:new, post}, socket) do
    socket =
      socket
      |> put_flash(:info, "#{post.user.email} just posted!")
      |> stream_insert(:posts, post, at: 0)

    {:noreply, socket}
  end

  defp consume_files(socket) do
    consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
      dest = Path.join([:code.priv_dir(:finsta), "static", "uploads", Path.basename(path)])
      File.cp!(path, dest)

      {:postpone, ~p"/uploads/#{Path.basename(dest)}"}
    end)
  end
end
