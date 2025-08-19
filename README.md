# Melocoton

A simple database client focused

## Features

- keyboard driven
- simple UI
- supports `sqlite` and `postgres`
- multi platform

## Requirements

- [mise](https://mise.jdx.dev/getting-started.html) to install all the required dependencies.
- we also need to install `rust` we can do it with [rustup](https://rustup.rs/)

## Local development

1. Install all the dependencies with `mise install`
2. Install `elixir` dependencies with `mix deps.get`
3. Install `nodejs` dependencies with `npm install --prefix assets`
4. Run migrations, `mix ecto.migrate`
5. Run development server, `iex -S mix phx.server`

Enjoy! ❤️
