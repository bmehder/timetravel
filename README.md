# timetravel

Development-only time travel and state inspection for Lustre applications.
It records application messages and model snapshots, lets you navigate through
the history, and suppresses effects while you inspect an earlier state.

## Pre-1.0 status

This package grew out of a debugger built for a small Lustre application. Its
core history behavior is covered by unit tests, and independent example
applications verify both minified and unminified browser builds.

The API may still change before 1.0 as it sees broader use. Bug reports,
corrections, and suggestions are welcome.

## Demo

Try the debugger in the [Maybe List demo](https://gleam-maybe-list.vercel.app).
Change the list, then open **Time Travel** in the lower-right corner to move
through the recorded states. The public showcase is intentionally unminified
so the automatic value inspector can retain Gleam constructor names.

## Installation

Add the package to a Lustre project as a development dependency:

```sh
gleam add --dev timetravel
```

## Usage

Keep your production entry point unchanged and add a separate development entry
point at `dev/my_app_dev.gleam`. Modules in Gleam's `dev` directory can import
development dependencies without including them in production builds:

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

The inspector is self-contained and injects its own prefixed CSS. It does not
require Tailwind or any stylesheet configuration in the host application.

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
./integration/run.sh
```

The integration command builds three small, independent Lustre applications
against the local package. Together they exercise the zero-configuration API,
managed effects, custom minification-safe formatters, and both unminified and
minified browser bundles. Generated dependencies and build output remain inside
the integration projects and are ignored by Git. The integration projects use
the system installation of Bun.

## License

MIT
# timetravel
