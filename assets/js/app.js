// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

import { EditorView, basicSetup } from "codemirror";
import { Compartment } from "@codemirror/state";
import { keymap } from "@codemirror/view";
import { sql, PostgreSQL, SQLite, StandardSQL } from "@codemirror/lang-sql";
import { vim } from "@replit/codemirror-vim";
import { oneDark } from "@codemirror/theme-one-dark";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: {
    SQLEditor: {
      mounted() {
        const that = this;
        const sqlExtensionCompartment = new Compartment();
        // HACK: allow to load schema after receiving its value from
        // server once the database was inspected
        window.sqlExtensionCompartment = sqlExtensionCompartment;

        function keymaps() {
          return keymap.of([
            {
              key: "Mod-Enter",
              run() {
                // run query with current selection when pressing
                // CMD + enter
                const selection = view.state.selection.ranges.at(0);
                const selectedText = view.state.doc
                  .toString()
                  .substring(selection.from, selection.to);

                that.pushEvent("run-query", {
                  query: selectedText,
                });

                return true;
              },
            },
          ]);
        }

        const view = new EditorView({
          // because this element is a textarea we pass its content
          // when initializing the editor
          doc: this.el.value,
          parent: document.getElementById("editor"),
          extensions: [
            vim(),
            keymaps(),
            basicSetup,
            sqlExtensionCompartment.of(sql({})),
            EditorView.updateListener.of((updateView) => {
              // update text area
              that.el.value = updateView.state.doc.toString();
              // we trigger this event to be able to update the session
              // query value, this simulate a manual edit inside the
              // textarea element
              that.pushEvent("validate", {
                _target: ["session", "query"],
                session: { query: updateView.state.doc.toString() },
              });
            }),
            oneDark,
          ],
        });

        // HACK: expose view so we can use it on load-new-query event
        // to reset editor content
        window.view = view;

        view.focus();
      },
    },
  },
  metadata: {
    keydown: (e, _el) => {
      return {
        key: e.key,
        metaKey: e.metaKey,
      };
    },
  },
});

window.addEventListener("phx:load-query", ({ detail }) => {
  // this will be triggered when a new session is loaded in server, so
  // we need to reset SQL editor with new session's query
  const newState = view.state.update({
    changes: { from: 0, to: view.state.doc.length, insert: detail.query },
  });
  view.dispatch(newState);
});

window.addEventListener("phx:load-schema", ({ detail: { schema, type } }) => {
  let dialect = StandardSQL;
  if (type === "postgres") dialect = PostgreSQL;
  if (type === "sqlite") dialect = SQLite;

  view.dispatch({
    effects: sqlExtensionCompartment.reconfigure(
      sql({ schema: schema, dialect: dialect }),
    ),
  });
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

const themeToggle = document.getElementById("theme-toggle");

// Check for saved theme preference or use system preference
if (
  localStorage.theme === "dark" ||
  (!("theme" in localStorage) &&
    window.matchMedia("(prefers-color-scheme: dark)").matches)
) {
  document.documentElement.classList.add("dark");
} else {
  document.documentElement.classList.remove("dark");
}

// Toggle theme
themeToggle.addEventListener("click", () => {
  document.documentElement.classList.toggle("dark");

  // Save preference
  if (document.documentElement.classList.contains("dark")) {
    localStorage.theme = "dark";
  } else {
    localStorage.theme = "light";
  }
});

// this only work when running through Tauri web view
if (window.__TAURI__) {
  const { invoke } = window.__TAURI__.core;

  document.addEventListener("keydown", async (event) => {
    if (event.metaKey && event.key === "n") {
      event.preventDefault();

      await invoke("open_new_window");
    }
  });
}
