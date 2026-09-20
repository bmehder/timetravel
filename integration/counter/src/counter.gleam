import gleam/int
import lustre
import lustre/effect
import lustre/element/html
import lustre/event
import timetravel

type Message {
  Increment
  Decrement
}

fn init(_arguments) {
  #(0, effect.none())
}

fn update(model, message) {
  case message {
    Increment -> #(model + 1, effect.none())
    Decrement -> #(model - 1, effect.none())
  }
}

fn view(model) {
  html.main([], [
    html.button([event.on_click(Decrement)], [html.text("-")]),
    html.p([], [html.text(int.to_string(model))]),
    html.button([event.on_click(Increment)], [html.text("+")]),
  ])
}

pub fn main() -> Nil {
  let app = timetravel.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
