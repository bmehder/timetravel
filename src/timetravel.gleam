//// Development-only model history and inspection for Lustre applications.

import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import timetravel/internal/inspect

const history_limit = 100

/// Messages handled by the time-travel wrapper.
pub type Message(app_message) {
  App(app_message)
  Back
  Forward
  ReturnToPresent
  GoTo(Int)
  ToggleInspector
}

type Snapshot(model, app_message) {
  Snapshot(model: model, message: app_message)
}

/// The wrapped application model and its recorded history.
pub opaque type Model(model, app_message) {
  Model(
    current: model,
    past: List(Snapshot(model, app_message)),
    future: List(Snapshot(model, app_message)),
    inspector_open: Bool,
  )
}

/// Stable labels and value formatting for production-minified builds.
///
/// JavaScript minifiers rename Gleam constructor classes, so applications that
/// ship the inspector in a minified bundle should provide formatters based on
/// Gleam pattern matching rather than JavaScript constructor names.
pub type Formatters(model, app_message) {
  Formatters(
    message_name: fn(app_message) -> String,
    format_message: fn(app_message) -> String,
    format_model: fn(model) -> String,
  )
}

/// Return the application model at the selected point in history.
pub fn current(model: Model(model, app_message)) -> model {
  model.current
}

/// Return the selected and latest zero-based timeline positions.
pub fn position(model: Model(model, app_message)) -> #(Int, Int) {
  #(
    list.length(model.past),
    list.length(model.past) + list.length(model.future),
  )
}

/// Initialise a time-travel model using an application's init function.
pub fn init(
  arguments arguments: arguments,
  with app_init: fn(arguments) -> #(model, Effect(app_message)),
) -> #(Model(model, app_message), Effect(Message(app_message))) {
  let #(model, app_effect) = app_init(arguments)
  #(
    Model(model, past: [], future: [], inspector_open: False),
    effect.map(app_effect, App),
  )
}

/// Wrap an existing Lustre application with development-only time travel.
pub fn application(app_init, app_update, app_view) {
  application_with_formatters(
    app_init,
    app_update,
    app_view,
    Formatters(inspect.name, inspect.value, inspect.value),
  )
}

/// Wrap an application using minification-safe message labels and formatters.
pub fn application_with_formatters(
  app_init,
  app_update,
  app_view,
  formatters: Formatters(model, app_message),
) {
  lustre.application(
    fn(arguments) { init(arguments: arguments, with: app_init) },
    fn(model, message) {
      update(model: model, message: message, with: app_update)
    },
    fn(model) {
      view_with_formatters(model: model, app: app_view, formatters: formatters)
    },
  )
}

/// Update a time-travel model using an application's update function.
pub fn update(
  model model: Model(model, app_message),
  message message: Message(app_message),
  with app_update: fn(model, app_message) -> #(model, Effect(app_message)),
) -> #(Model(model, app_message), Effect(Message(app_message))) {
  case message {
    App(app_message) -> update_app(model, app_message, app_update)
    Back -> #(back(model), effect.none())
    Forward -> #(forward(model), effect.none())
    ReturnToPresent -> #(return_to_present(model), effect.none())
    GoTo(position) -> #(go_to(model, position), effect.none())
    ToggleInspector -> {
      let opening = !model.inspector_open
      let drag_effect = case opening {
        True -> effect.after_paint(fn(_, root) { attach_dragging(root) })
        False -> effect.none()
      }
      #(Model(..model, inspector_open: opening), drag_effect)
    }
  }
}

fn update_app(
  model: Model(model, app_message),
  message: app_message,
  app_update: fn(model, app_message) -> #(model, Effect(app_message)),
) -> #(Model(model, app_message), Effect(Message(app_message))) {
  case model.future {
    [_, ..] -> #(model, effect.none())
    [] -> {
      let #(updated, app_effect) = app_update(model.current, message)
      let updated_model =
        Model(
          ..model,
          current: updated,
          past: [Snapshot(model.current, message), ..model.past]
            |> list.take(history_limit),
        )
      #(updated_model, effect.map(app_effect, App))
    }
  }
}

fn back(model: Model(model, app_message)) -> Model(model, app_message) {
  case model.past {
    [] -> model
    [Snapshot(previous, message), ..rest] ->
      Model(..model, current: previous, past: rest, future: [
        Snapshot(model.current, message),
        ..model.future
      ])
  }
}

fn forward(model: Model(model, app_message)) -> Model(model, app_message) {
  case model.future {
    [] -> model
    [Snapshot(next, message), ..rest] ->
      Model(
        ..model,
        current: next,
        past: [Snapshot(model.current, message), ..model.past],
        future: rest,
      )
  }
}

fn return_to_present(
  model: Model(model, app_message),
) -> Model(model, app_message) {
  case model.future {
    [] -> model
    [_, ..] -> return_to_present(forward(model))
  }
}

fn go_to(
  model: Model(model, app_message),
  target: Int,
) -> Model(model, app_message) {
  let current = list.length(model.past)
  case target < current, target > current, model.future {
    True, _, _ -> go_to(back(model), target)
    _, True, [_, ..] -> go_to(forward(model), target)
    _, _, _ -> model
  }
}

/// Render an application together with the time-travel inspector.
pub fn view(
  model model: Model(model, app_message),
  app app_view: fn(model) -> Element(app_message),
) -> Element(Message(app_message)) {
  view_with_formatters(
    model: model,
    app: app_view,
    formatters: Formatters(inspect.name, inspect.value, inspect.value),
  )
}

/// Render the wrapped application using custom inspection formatters.
pub fn view_with_formatters(
  model model: Model(model, app_message),
  app app_view: fn(model) -> Element(app_message),
  formatters formatters: Formatters(model, app_message),
) -> Element(Message(app_message)) {
  html.div([], [
    html.div(
      [
        attribute.classes([
          #("pointer-events-none opacity-70", model.future != []),
        ]),
      ],
      [element.map(app_view(model.current), App)],
    ),
    inspector(model, formatters),
  ])
}

fn inspector(
  model: Model(model, app_message),
  formatters: Formatters(model, app_message),
) -> Element(Message(app_message)) {
  html.aside(
    [
      attribute.class(
        "fixed bottom-4 right-4 z-50 flex max-h-[calc(100vh-2rem)] flex-col items-end gap-2 font-mono",
      ),
    ],
    [
      case model.inspector_open {
        True -> inspector_panel(model, formatters)
        False -> html.text("")
      },
      html.button(
        [
          attribute.type_("button"),
          event.on_click(ToggleInspector),
          attribute.aria_label("Toggle time travel debugger"),
          attribute.class(
            "flex h-11 items-center gap-2 rounded-full bg-stone-950 px-4 text-xs font-bold text-lime-300 shadow-xl transition hover:bg-stone-800 focus:outline-none focus:ring-2 focus:ring-lime-400",
          ),
        ],
        [
          html.span([attribute.class("text-lg leading-none")], [html.text("⏪")]),
          html.text("TIME TRAVEL"),
        ],
      ),
    ],
  )
}

fn inspector_panel(
  model: Model(model, app_message),
  formatters: Formatters(model, app_message),
) -> Element(Message(app_message)) {
  let travelling = model.future != []
  html.div(
    [
      attribute.data("time-travel-panel", ""),
      attribute.class(
        "fixed bottom-16 right-4 flex h-[44rem] max-h-[calc(100vh-5rem)] min-h-80 w-[48rem] max-w-[calc(100vw-2rem)] min-w-80 resize flex-col overflow-auto rounded-2xl border border-stone-700 bg-stone-950/90 text-stone-100 shadow-2xl backdrop-blur-sm",
      ),
    ],
    [
      html.div(
        [
          attribute.data("time-travel-drag-handle", ""),
          attribute.class(
            "flex cursor-move touch-none select-none items-center justify-between border-b border-stone-800 px-4 py-3",
          ),
        ],
        [
          html.div([], [
            html.p(
              [
                attribute.class(
                  "text-[10px] font-bold uppercase tracking-[0.2em] text-lime-400",
                ),
              ],
              [html.text("Development")],
            ),
            html.p([attribute.class("mt-0.5 text-sm font-bold")], [
              html.text(case travelling {
                True -> "Viewing the past"
                False -> "Present state"
              }),
            ]),
          ]),
          html.div([attribute.class("flex items-center gap-3")], [
            html.p([attribute.class("text-[11px] text-stone-500")], [
              html.text(
                int.to_string(list.length(model.past))
                <> " / "
                <> int.to_string(
                  list.length(model.past) + list.length(model.future),
                ),
              ),
            ]),
            html.button(
              [
                attribute.type_("button"),
                event.on_click(ToggleInspector),
                attribute.aria_label("Close time travel debugger"),
                attribute.class(
                  "flex h-7 w-7 items-center justify-center rounded text-lg text-stone-500 transition hover:bg-stone-800 hover:text-stone-100",
                ),
              ],
              [html.text("×")],
            ),
          ]),
        ],
      ),
      html.div([attribute.class("flex gap-2 border-b border-stone-800 p-3")], [
        control_button("←", "Previous state", Back, model.past == []),
        control_button("→", "Next state", Forward, model.future == []),
        html.button(
          [
            attribute.type_("button"),
            event.on_click(ReturnToPresent),
            attribute.disabled(!travelling),
            attribute.class(
              "ml-auto rounded-lg border border-stone-700 px-3 py-1.5 text-[11px] font-bold text-stone-300 transition hover:border-lime-500 hover:text-lime-300 disabled:cursor-not-allowed disabled:opacity-30",
            ),
          ],
          [html.text("BACK TO THE FUTURE")],
        ),
      ]),
      html.div(
        [
          attribute.class(
            "grid min-h-0 flex-1 grid-cols-[max-content_max-content_minmax(0,1fr)]",
          ),
        ],
        [timeline(model, formatters), ..inspection(model, formatters)],
      ),
    ],
  )
}

fn control_button(
  icon: String,
  label: String,
  message: Message(app_message),
  disabled: Bool,
) -> Element(Message(app_message)) {
  html.button(
    [
      attribute.type_("button"),
      event.on_click(message),
      attribute.disabled(disabled),
      attribute.aria_label(label),
      attribute.class(
        "flex h-8 w-9 items-center justify-center rounded-lg bg-stone-800 text-sm transition hover:bg-stone-700 disabled:cursor-not-allowed disabled:opacity-30",
      ),
    ],
    [html.text(icon)],
  )
}

fn timeline(
  model: Model(model, app_message),
  formatters: Formatters(model, app_message),
) -> Element(Message(app_message)) {
  let current = list.length(model.past)
  let steps = list.append(list.reverse(model.past), model.future)
  let entries =
    steps
    |> list.index_map(fn(snapshot, index) {
      let Snapshot(_, message) = snapshot
      timeline_entry(
        index + 1,
        formatters.message_name(message),
        current == index + 1,
      )
    })
    |> list.prepend(timeline_entry(0, "Init", current == 0))

  html.div(
    [attribute.class("min-w-40 overflow-auto border-r border-stone-800 p-3")],
    [
      html.p(
        [
          attribute.class(
            "mb-2 text-[10px] font-bold uppercase tracking-wider text-stone-600",
          ),
        ],
        [html.text("Timeline")],
      ),
      html.ol([attribute.class("space-y-1 text-[10px]")], entries),
    ],
  )
}

fn timeline_entry(
  position: Int,
  label: String,
  selected: Bool,
) -> Element(Message(app_message)) {
  html.li([], [
    html.button(
      [
        attribute.type_("button"),
        event.on_click(GoTo(position)),
        attribute.class(
          "flex w-full items-center gap-2 rounded px-1.5 py-1 text-left transition hover:bg-stone-800 hover:text-stone-200",
        ),
        attribute.classes([
          #("bg-stone-800 font-bold text-lime-400", selected),
          #("text-stone-500", !selected),
        ]),
      ],
      [
        html.span([attribute.class("w-5 shrink-0 text-right text-stone-600")], [
          html.text(int.to_string(position)),
        ]),
        html.span([], [html.text(label)]),
      ],
    ),
  ])
}

fn inspection(
  model: Model(model, app_message),
  formatters: Formatters(model, app_message),
) -> List(Element(Message(app_message))) {
  let message = case model.past {
    [Snapshot(_, message), ..] -> formatters.format_message(message)
    [] -> "Init"
  }

  [
    inspected_value("Message", message, fit_content: True),
    inspected_value(
      "Model",
      formatters.format_model(model.current),
      fit_content: False,
    ),
  ]
}

fn inspected_value(
  label: String,
  value: String,
  fit_content fit_content: Bool,
) -> Element(Message(app_message)) {
  html.section(
    [
      attribute.class(case fit_content {
        True -> "min-w-72 overflow-auto border-l border-stone-800"
        False -> "min-w-96 overflow-auto border-l border-stone-800"
      }),
    ],
    [
      html.h3(
        [
          attribute.class(
            "sticky top-0 border-b border-stone-800 bg-stone-950/90 px-4 py-2 text-[10px] font-bold uppercase tracking-wider text-lime-400 backdrop-blur-sm",
          ),
        ],
        [html.text(label)],
      ),
      html.pre(
        [
          attribute.class(case fit_content {
            True ->
              "min-h-48 whitespace-pre p-4 text-xs leading-5 text-stone-300"
            False ->
              "min-h-48 whitespace-pre-wrap break-words p-4 text-xs leading-5 text-stone-300"
          }),
        ],
        [html.text(value)],
      ),
    ],
  )
}

@external(javascript, "./time_travel_ffi.mjs", "attachDragging")
fn attach_dragging(root: Dynamic) -> Nil
