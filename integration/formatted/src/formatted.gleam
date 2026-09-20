import gleam/int
import lustre
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import timetravel

type Model {
  Model(count: Int, label: String)
}

type Message {
  Increment
  Rename(String)
}

fn init(_arguments) {
  #(Model(count: 0, label: "Counter"), effect.none())
}

fn update(model: Model, message: Message) {
  case message {
    Increment -> #(Model(..model, count: model.count + 1), effect.none())
    Rename(label) -> #(Model(..model, label: label), effect.none())
  }
}

fn view(model: Model) -> Element(Message) {
  html.main([], [
    html.h1([], [html.text(model.label)]),
    html.p([], [html.text(int.to_string(model.count))]),
    html.button([event.on_click(Increment)], [html.text("Increment")]),
  ])
}

fn message_name(message: Message) -> String {
  case message {
    Increment -> "Increment"
    Rename(_) -> "Rename"
  }
}

fn format_message(message: Message) -> String {
  case message {
    Increment -> "Increment"
    Rename(label) -> "Rename(\"" <> label <> "\")"
  }
}

fn format_model(model: Model) -> String {
  "Model(count: "
  <> int.to_string(model.count)
  <> ", label: \""
  <> model.label
  <> "\")"
}

pub fn main() -> Nil {
  let formatters =
    timetravel.Formatters(
      message_name: message_name,
      format_message: format_message,
      format_model: format_model,
    )
  let app =
    timetravel.application_with_formatters(init, update, view, formatters)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
