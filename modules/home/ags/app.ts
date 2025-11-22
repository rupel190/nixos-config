import app from "ags/gtk4/app"
import style from "./style.scss"
import Bar from "./widget/Bar"

app.start({
  css: style,
  main() {
    app.get_monitors()
      .filter(m => !m.model.includes("DELL") && !m.model.includes("PG27AQDM"))
      .map(Bar)
  },
})
