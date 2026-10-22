# JavaScript interop

## Choose the lightest tool

1. **For UI-only changes, use `Phoenix.LiveView.JS` commands** (show/hide, toggling classes, focus, transitions). They run on the client without a round trip, and they survive DOM patches.

   ```heex
   <button phx-click={JS.toggle(to: "#menu") |> JS.toggle_class("rotate-180", to: "#chevron")}>Menu</button>
   <button phx-click={JS.push("delete", value: %{id: @post.id}) |> JS.hide(to: "#post-#{@post.id}")}>Delete</button>
   ```

   Use `JS.ignore_attributes(["open"])` in `phx-mounted` (1.1+) on `<dialog>` and `<details>` elements whose attributes the browser controls.

2. **For behaviour tied to one element, use a colocated hook:**

   ```heex
   <input id="phone" name="user[phone]" phx-hook=".PhoneMask" />
   <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneMask">
     export default {
       mounted() { this.el.addEventListener("input", () => { /* ... */ }) }
     }
   </script>
   ```

   The hook name must start with `.`, and the element needs a unique `id`. `phx.new` 1.8 apps already import colocated hooks into `app.js`; older apps must add `import {hooks as colocatedHooks} from "phoenix-colocated/my_app"`.

3. **For shared or reusable code, use an external hook.** Define it in `assets/js/`, register it with `new LiveSocket("/live", Socket, {hooks: {MyHook}})`, and attach it with `phx-hook="MyHook"`.

## Rules

- If a hook or a third-party library manages an element's children (a chart, an editor, a map), set `phx-update="ignore"` on that element.
- Never put raw `<script>` tags in HEEx, and never link external script URLs in layouts. Import libraries into `app.js` instead.

## Server ↔ client messages

```elixir
# server → client. Always return or rebind the socket.
{:noreply, push_event(socket, "chart:update", %{points: points})}
```

```javascript
// in a hook
mounted() {
  this.handleEvent("chart:update", ({points}) => this.chart.setData(points))
  this.pushEvent("chart:ready", {}, (reply) => console.log(reply))   // client → server with a reply
}
```

```elixir
def handle_event("chart:ready", _params, socket), do: {:reply, %{ok: true}, socket}
```

- In LiveView 1.2+, `%JS{}` commands can be sent in `push_event` payloads (`%{toggle: JS.toggle_class(...)}`) and run in a hook with `this.js().execJS(this.el, toggle)`.
- `push_event` events go to every hook listening for that name. Namespace event names (`"chart:update"`).
