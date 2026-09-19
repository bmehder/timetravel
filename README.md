# timetravel

Development-only time travel and state inspection for Lustre applications.
It records application messages and model snapshots, lets you navigate through
the history, and suppresses effects while you inspect an earlier state.

## Experimental status

This is a very early experiment, created while I am learning Gleam, Lustre, and
the process of publishing packages. It grew out of a debugger I built for a
small Lustre application and is being shared in case it is useful to someone
else.

The API and behavior may change as I learn more. I have tested the core history
behavior and a minified browser build, but this has not yet seen broad use. Bug
reports, corrections, suggestions, and patient feedback are very welcome.

## Demo

Try the debugger in the [Maybe List demo](https://gleam-maybe-list.vercel.app).
Change the list, then open **Time Travel** in the lower-right corner to move
through the recorded states. The demo uses a minified production build.

## Installation

This experiment is not published on Hex yet. Add the tagged Git dependency to
your `gleam.toml`:

```toml
timetravel = {
  git = "https://github.com/bmehder/timetravel.git",
  ref = "v0.1.0",
}
```

## Usage

Keep your production entry point unchanged and add a separate development entry
point:

```gleam
import lustre
import my_app/web
import timetravel

pub fn main() -> Nil {
  let app = timetravel.application(web.init, web.update, web.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
```

Start that entry point with Lustre Dev Tools:

```sh
gleam run -m lustre/dev start my_app_dev
```

The inspector UI uses Tailwind utility classes. Make sure the development
entry point is covered by your Tailwind build (for example, with a matching
`src/my_app_dev.css` file).

The latest 100 transitions are retained. Selecting an earlier transition
restores its recorded model without replaying messages, HTTP requests, or other
effects. New application messages are ignored until you return to the present.

### Minified deployments

JavaScript minification renames Gleam's generated constructor classes. If the
development entry point is deployed with minification enabled, use
`application_with_formatters` so timeline labels and inspected values remain
meaningful:

```gleam
let formatters = timetravel.Formatters(
  message_name: fn(message) {
    case message {
      Increment -> "Increment"
      SetCount(_) -> "SetCount"
    }
  },
  format_message: fn(message) {
    case message {
      Increment -> "Increment"
      SetCount(count) -> "SetCount(" <> int.to_string(count) <> ")"
    }
  },
  format_model: fn(model) { int.to_string(model.count) },
)

let app =
  timetravel.application_with_formatters(
    web.init,
    web.update,
    web.view,
    formatters,
  )
```

The ordinary `application` function remains convenient for unminified local
development builds.

## Acknowledgements

This experiment was informed by and builds on ideas from
[Tardis](https://github.com/ghivert/tardis), an earlier time-travelling
debugger for Lustre by [ghivert](https://github.com/ghivert). Many thanks for
showing what this kind of tooling can look like in the Gleam and Lustre
ecosystem.

## Development

```sh
gleam format --check src test
gleam test
```

## License

MIT
# timetravel
