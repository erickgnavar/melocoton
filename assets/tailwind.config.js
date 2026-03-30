// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

module.exports = {
  darkMode: ["selector", '[data-theme="dark"]'],
  content: [
    "./js/**/*.js",
    "../lib/melocoton_web.ex",
    "../lib/melocoton_web/**/*.*ex",
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        transaction: {
          active: {
            DEFAULT: "#f97316",
            light: "rgba(249, 115, 22, 0.1)",
            medium: "rgba(249, 115, 22, 0.2)",
            dark: "rgba(249, 115, 22, 0.8)",
          },
        },
        env: {
          local: "#22c55e",
          dev: "#0ea5e9",
          prod: "#7c3aed",
          staging: "#f59e0b",
        },
        app: {
          sidebar: {
            light: "#f5f5f4",
            dark: "#242422",
          },
          content: {
            light: "#ffffff",
            dark: "#1c1c1a",
          },
          border: {
            light: "#d1d1d1",
            dark: "#3a3a3a",
          },
          accent: {
            light: "#0078d7",
            dark: "#0078d7",
          },
          menubar: {
            light: "#f0f0f0",
            dark: "#333333",
          },
          input: {
            light: "#ffffff",
            dark: "#2d2d2d",
          },
          editor: {
            light: "#ffffff",
            dark: "#1c1c1a",
          },
        },
      },
      fontFamily: {
        system: [
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "Roboto",
          "Helvetica",
          "Arial",
          "sans-serif",
          "Apple Color Emoji",
          "Segoe UI Emoji",
          "Segoe UI Symbol",
        ],
        mono: [
          "SFMono-Regular",
          "Menlo",
          "Monaco",
          "Consolas",
          "Liberation Mono",
          "Courier New",
          "monospace",
        ],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant("phx-click-loading", [
        ".phx-click-loading&",
        ".phx-click-loading &",
      ]),
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-submit-loading", [
        ".phx-submit-loading&",
        ".phx-submit-loading &",
      ]),
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-change-loading", [
        ".phx-change-loading&",
        ".phx-change-loading &",
      ]),
    ),

    // Embeds Lucide icons (https://lucide.dev) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/lucide/icons");
      let values = {};
      fs.readdirSync(iconsDir).forEach((file) => {
        if (path.extname(file) !== ".svg") return;
        let name = path.basename(file, ".svg");
        values[name] = { name, fullPath: path.join(iconsDir, file) };
      });
      matchComponents(
        {
          lucide: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, "")
              .replace(/\s+/g, " ")
              .replace(/"/g, "'")
              .replace(/#/g, "%23");
            let url = `url("data:image/svg+xml,${content}")`;
            return {
              "mask-image": url,
              "mask-repeat": "no-repeat",
              "mask-size": "100% 100%",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: theme("spacing.6"),
              height: theme("spacing.6"),
            };
          },
        },
        { values },
      );
    }),
  ],
};
