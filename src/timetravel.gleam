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

const stylesheet = "
.tt-app--past { pointer-events: none; opacity: 0.7; }
.tt-root, .tt-root *, .tt-root *::before, .tt-root *::after { box-sizing: border-box; }
.tt-root { position: fixed; right: 1rem; bottom: 1rem; z-index: 2147483647; display: flex; max-height: calc(100vh - 2rem); flex-direction: column; align-items: flex-end; gap: 0.5rem; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, \"Liberation Mono\", \"Courier New\", monospace; }
.tt-root button { margin: 0; font: inherit; }
.tt-toggle { display: flex; height: 2.75rem; align-items: center; gap: 0.5rem; border: 0; border-radius: 9999px; background: #0c0a09; padding: 0 1rem; color: #bef264; box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.25), 0 8px 10px -6px rgb(0 0 0 / 0.25); cursor: pointer; font-size: 0.75rem; font-weight: 700; transition: background-color 150ms, box-shadow 150ms; }
.tt-toggle:hover { background: #292524; }
.tt-toggle:focus-visible { outline: 2px solid #a3e635; outline-offset: 2px; }
.tt-toggle-icon { font-size: 1.125rem; line-height: 1; }
.tt-panel { position: fixed; right: 1rem; bottom: 4rem; display: flex; width: 48rem; min-width: 20rem; max-width: calc(100vw - 2rem); height: 44rem; min-height: 20rem; max-height: calc(100vh - 5rem); resize: both; flex-direction: column; overflow: auto; border: 1px solid #44403c; border-radius: 1rem; background: rgb(12 10 9 / 0.9); color: #f5f5f4; box-shadow: 0 25px 50px -12px rgb(0 0 0 / 0.5); backdrop-filter: blur(4px); }
.tt-header { display: flex; cursor: move; touch-action: none; user-select: none; align-items: center; justify-content: space-between; border-bottom: 1px solid #292524; padding: 0.75rem 1rem; }
.tt-eyebrow { margin: 0; color: #a3e635; font-size: 0.625rem; font-weight: 700; letter-spacing: 0.2em; text-transform: uppercase; }
.tt-title { margin: 0.125rem 0 0; font-size: 0.875rem; font-weight: 700; }
.tt-status { display: flex; align-items: center; gap: 0.75rem; }
.tt-position { margin: 0; color: #78716c; font-size: 0.6875rem; }
.tt-close { display: flex; width: 1.75rem; height: 1.75rem; align-items: center; justify-content: center; border: 0; border-radius: 0.25rem; background: transparent; color: #78716c; cursor: pointer; font-size: 1.125rem; transition: background-color 150ms, color 150ms; }
.tt-close:hover { background: #292524; color: #f5f5f4; }
.tt-controls { display: flex; gap: 0.5rem; border-bottom: 1px solid #292524; padding: 0.75rem; }
.tt-control { display: flex; width: 2.25rem; height: 2rem; align-items: center; justify-content: center; border: 0; border-radius: 0.5rem; background: #292524; color: inherit; cursor: pointer; font-size: 0.875rem; transition: background-color 150ms, opacity 150ms; }
.tt-control:hover:not(:disabled) { background: #44403c; }
.tt-control:disabled, .tt-return:disabled { cursor: not-allowed; opacity: 0.3; }
.tt-return { margin-left: auto; border: 1px solid #44403c; border-radius: 0.5rem; background: transparent; padding: 0.375rem 0.75rem; color: #d6d3d1; cursor: pointer; font-size: 0.6875rem; font-weight: 700; transition: border-color 150ms, color 150ms, opacity 150ms; }
.tt-return:hover:not(:disabled) { border-color: #84cc16; color: #bef264; }
.tt-grid { display: grid; min-height: 0; flex: 1; grid-template-columns: minmax(12rem, max-content) minmax(20rem, max-content) minmax(28rem, 1fr); }
.tt-timeline { min-width: 10rem; overflow: auto; border-right: 1px solid #292524; padding: 0.75rem; }
.tt-column-label { margin: 0 0 0.5rem; color: #57534e; font-size: 0.625rem; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; }
.tt-timeline-list { margin: 0; padding: 0; list-style: none; font-size: 0.625rem; }
.tt-timeline-list > li + li { margin-top: 0.25rem; }
.tt-timeline-entry { display: flex; width: 100%; align-items: center; gap: 0.5rem; border: 0; border-radius: 0.25rem; background: transparent; padding: 0.25rem 0.375rem; color: #78716c; cursor: pointer; text-align: left; transition: background-color 150ms, color 150ms; }
.tt-timeline-entry:hover { background: #292524; color: #e7e5e4; }
.tt-timeline-entry--selected { background: #292524; color: #a3e635; font-weight: 700; }
.tt-timeline-position { width: 1.25rem; flex-shrink: 0; color: #57534e; text-align: right; }
.tt-inspection { overflow: auto; border-left: 1px solid #292524; }
.tt-inspection--message { min-width: 18rem; }
.tt-inspection--model { min-width: 24rem; }
.tt-inspection-heading { position: sticky; top: 0; margin: 0; border-bottom: 1px solid #292524; background: rgb(12 10 9 / 0.9); padding: 0.5rem 1rem; color: #a3e635; font-size: 0.625rem; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; backdrop-filter: blur(4px); }
.tt-inspection-value { min-height: 12rem; margin: 0; padding: 1rem; color: #d6d3d1; font: 0.75rem/1.25rem ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, \"Liberation Mono\", \"Courier New\", monospace; }
.tt-inspection-value--message { white-space: pre; }
.tt-inspection-value--model { overflow-wrap: break-word; white-space: pre-wrap; }
"

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
  // The model immediately before `message` was handled. Keeping the message
  // beside that model lets Back and Forward move without replaying updates.
  Snapshot(model: model, message: app_message)
}

/// The wrapped application model and its recorded history.
///
/// `past` is stored newest-first so recording and stepping backward are cheap.
/// `future` is stored with the next state first. Together they form the full
/// timeline around `current`.
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
    // While inspecting history, ignore application messages so the displayed
    // snapshot cannot diverge from the timeline. Inspector controls still work.
    [_, ..] -> #(model, effect.none())
    [] -> {
      let #(updated, app_effect) = app_update(model.current, message)
      let updated_model =
        Model(
          ..model,
          current: updated,
          // Prepending makes the newest transition cheap to record. `take`
            // consequently discards the oldest transition when the limit is hit.
            past: [Snapshot(model.current, message), ..model.past]
            |> list.take(history_limit),
        )
      // Effects run only when a new present-day transition is recorded. Moving
      // through history never replays HTTP requests, storage writes, or timers.
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
    html.style([], stylesheet),
    html.div(
      [
        attribute.class("tt-app"),
        attribute.classes([
          #("tt-app--past", model.future != []),
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
      attribute.class("tt-root"),
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
          attribute.class("tt-toggle"),
        ],
        [
          html.span([attribute.class("tt-toggle-icon")], [html.text("⏪")]),
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
      attribute.class("tt-panel"),
    ],
    [
      html.div(
        [
          attribute.data("time-travel-drag-handle", ""),
          attribute.class("tt-header"),
        ],
        [
          html.div([], [
            html.p(
              [
                attribute.class("tt-eyebrow"),
              ],
              [html.text("Development")],
            ),
            html.p([attribute.class("tt-title")], [
              html.text(case travelling {
                True -> "Viewing the past"
                False -> "Present state"
              }),
            ]),
          ]),
          html.div([attribute.class("tt-status")], [
            html.p([attribute.class("tt-position")], [
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
                attribute.class("tt-close"),
              ],
              [html.text("×")],
            ),
          ]),
        ],
      ),
      html.div([attribute.class("tt-controls")], [
        control_button("←", "Previous state", Back, model.past == []),
        control_button("→", "Next state", Forward, model.future == []),
        html.button(
          [
            attribute.type_("button"),
            event.on_click(ReturnToPresent),
            attribute.disabled(!travelling),
            attribute.class("tt-return"),
          ],
          [html.text("BACK TO THE FUTURE")],
        ),
      ]),
      html.div(
        [
          attribute.class("tt-grid"),
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
      attribute.class("tt-control"),
    ],
    [html.text(icon)],
  )
}

fn timeline(
  model: Model(model, app_message),
  formatters: Formatters(model, app_message),
) -> Element(Message(app_message)) {
  let current = list.length(model.past)
  // The UI needs chronological order, unlike the newest-first representation
  // used by `past` for efficient updates.
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

  html.div([attribute.class("tt-timeline")], [
    html.p(
      [
        attribute.class("tt-column-label"),
      ],
      [html.text("Timeline")],
    ),
    html.ol([attribute.class("tt-timeline-list")], entries),
  ])
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
        attribute.class("tt-timeline-entry"),
        attribute.classes([
          #("tt-timeline-entry--selected", selected),
        ]),
      ],
      [
        html.span([attribute.class("tt-timeline-position")], [
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
        True -> "tt-inspection tt-inspection--message"
        False -> "tt-inspection tt-inspection--model"
      }),
    ],
    [
      html.h3(
        [
          attribute.class("tt-inspection-heading"),
        ],
        [html.text(label)],
      ),
      html.pre(
        [
          attribute.class(case fit_content {
            True -> "tt-inspection-value tt-inspection-value--message"
            False -> "tt-inspection-value tt-inspection-value--model"
          }),
        ],
        [html.text(value)],
      ),
    ],
  )
}

@external(javascript, "./time_travel_ffi.mjs", "attachDragging")
fn attach_dragging(root: Dynamic) -> Nil
