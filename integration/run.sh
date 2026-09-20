#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for project in counter effects formatted
do
  project_dir="$root/integration/$project"

  echo "==> $project: dependencies"
  (cd "$project_dir" && gleam deps download)

  echo "==> $project: type checking"
  (cd "$project_dir" && gleam check --target javascript)

  echo "==> $project: unminified browser build"
  (cd "$project_dir" && gleam run -m lustre/dev build --outdir=dist)

  echo "==> $project: minified browser build"
  (cd "$project_dir" && gleam run -m lustre/dev build --minify --outdir=dist-minified)

  test -f "$project_dir/dist/index.html"
  test -f "$project_dir/dist/$project.js"
  test -f "$project_dir/dist-minified/index.html"
  test -f "$project_dir/dist-minified/$project.js"
done

echo "All timetravel integration projects built successfully."
