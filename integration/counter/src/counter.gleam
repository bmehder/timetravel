import gleam/int
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Message {
  Increment
  Decrement
}

pub fn init(_arguments) {
  #(0, effect.none())
}

pub fn update(model, message) {
  case message {
    Increment -> #(model + 1, effect.none())
    Decrement -> #(model - 1, effect.none())
  }
}

pub fn view(model) -> Element(Message) {
  html.main([], [
    html.button([event.on_click(Decrement)], [html.text("-")]),
    html.p([], [html.text(int.to_string(model))]),
    html.button([event.on_click(Increment)], [html.text("+")]),
  ])
}
