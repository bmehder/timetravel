import counter
import lustre
import timetravel

pub fn main() -> Nil {
  let app = timetravel.application(counter.init, counter.update, counter.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
