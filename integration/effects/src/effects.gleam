import lustre
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import timetravel

type Model {
  Model(status: String, attempts: Int)
}

type Message {
  Load
  Loaded(String)
}

fn init(_arguments) {
  #(Model(status: "Waiting", attempts: 0), effect.none())
}

fn update(model: Model, message: Message) {
  case message {
    Load -> #(
      Model(status: "Loading", attempts: model.attempts + 1),
      effect.from(fn(dispatch) { dispatch(Loaded("Ready")) }),
    )
    Loaded(status) -> #(Model(..model, status: status), effect.none())
  }
}

fn view(model: Model) -> Element(Message) {
  html.main([], [
    html.p([], [html.text(model.status)]),
    html.button([event.on_click(Load)], [html.text("Load")]),
  ])
}

pub fn main() -> Nil {
  let app = timetravel.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
