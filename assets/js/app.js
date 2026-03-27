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
import { vim, Vim } from "@replit/codemirror-vim";
import { oneDark } from "@codemirror/theme-one-dark";
import {
  moveCompletionSelection,
  acceptCompletion,
} from "@codemirror/autocomplete";
import { format } from "sql-formatter";

Vim.defineEx("format", "", (cm, _params) => {
  const view = cm.cm6;
  const { state } = view;
  const code = state.doc.toString();

  // TODO: define a way to apply format only to selected text in case
  // there is any

  const formatted = format(code, {
    language: "sql",
    indent: "  ",
    tabWidth: 2,
    keywordCase: "upper",
    linesBetweenQueries: 1,
  });

  view.dispatch({
    changes: {
      from: 0,
      to: state.doc.length,
      insert: formatted,
    },
  });
});

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

        Vim.defineEx("tabnext", "tabn", () => {
          that.pushEvent("next-session", {});
        });

        Vim.defineEx("tabprev", "tabp", () => {
          that.pushEvent("prev-session", {});
        });

        Vim.map("gt", ":tabnext<CR>", "normal");
        Vim.map("gT", ":tabprev<CR>", "normal");

        function keymaps() {
          return keymap.of([
            {
              key: "Tab",
              run: acceptCompletion,
            },
            {
              key: "Ctrl-n",
              run: moveCompletionSelection(true),
            },
            {
              key: "Ctrl-p",
              run: moveCompletionSelection(false),
            },
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
    CommandPalette: {
      mounted() {
        this.setupInput();
      },
      updated() {
        this.setupInput();

        // Scroll selected item into view
        const selected = this.el.querySelector(
          '[style*="background:"][style*="15"]',
        );
        if (selected) selected.scrollIntoView({ block: "nearest" });
      },
      setupInput() {
        const input = this.el.querySelector("#command-palette-input");
        if (!input) return;

        if (document.activeElement !== input) {
          input.focus();
        }

        // Only attach listener once
        if (!input._paletteKeydown) {
          input._paletteKeydown = true;
          input.addEventListener("keydown", (e) => {
            if (
              e.key === "ArrowUp" ||
              e.key === "ArrowDown" ||
              (e.ctrlKey && (e.key === "n" || e.key === "p"))
            ) {
              e.preventDefault();
            }
          });
        }
      },
    },
    AiChatScroll: {
      mounted() {
        this.scrollToBottom();
      },
      updated() {
        this.scrollToBottom();
      },
      scrollToBottom() {
        this.el.scrollTop = this.el.scrollHeight;
      },
    },
    CellEditor: {
      mounted() {
        const input = this.el.querySelector("input[name='value']");
        if (input) {
          input.focus();
          input.select();
          input.addEventListener("keydown", (e) => {
            if (e.key === "Escape") {
              e.preventDefault();
              this.pushEventTo(this.el, "cancel-edit", {});
            } else if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
              // Ctrl+Enter sets NULL
              e.preventDefault();
              this.el.querySelector("input[name='set-null']").value = "true";
              this.el.requestSubmit();
            }
          });
        }
      },
    },
  },
  metadata: {
    keydown: (e, _el) => {
      return {
        key: e.key,
        metaKey: e.metaKey,
        ctrlKey: e.ctrlKey,
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

// Copy to clipboard handler
window.addEventListener("phx:copy", (event) => {
  if (event.detail?.text) {
    navigator.clipboard.writeText(event.detail.text);
  }
});

// Open settings modal from command palette
window.addEventListener("phx:open-settings-modal", () => {
  const modal = document.getElementById("settings-modal");
  if (modal) {
    liveSocket.execJS(modal, modal.getAttribute("data-show-modal"));
  }
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

// Command palette (CMD+K / Ctrl+K)
// Use capture phase so it fires before CodeMirror's Vim mode consumes Ctrl+K
document.addEventListener(
  "keydown",
  (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === "k") {
      e.preventDefault();
      e.stopPropagation();
      // Dispatch a custom event that any LiveView element can pick up
      const trigger = document.getElementById("command-palette-trigger");
      if (trigger) {
        trigger.click();
      }
    }
  },
  true,
);

// Theme management using data-theme attribute
function resolveTheme(preference) {
  if (preference === "system" || !preference) {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }
  return preference;
}

function applyTheme(preference) {
  const resolved = resolveTheme(preference);
  document.documentElement.setAttribute("data-theme", resolved);
  localStorage.setItem("theme", preference);
}

// Apply initial theme
const savedTheme = localStorage.getItem("theme") || "system";
applyTheme(savedTheme);

// Listen for system preference changes
window
  .matchMedia("(prefers-color-scheme: dark)")
  .addEventListener("change", () => {
    const current = localStorage.getItem("theme") || "system";
    if (current === "system") {
      applyTheme("system");
    }
  });

// Toggle theme on button click
const themeToggle = document.getElementById("theme-toggle");
themeToggle.addEventListener("click", () => {
  const current = document.documentElement.getAttribute("data-theme");
  const next = current === "dark" ? "light" : "dark";
  applyTheme(next);
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
