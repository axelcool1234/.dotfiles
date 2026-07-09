import gleam/result
import gleam/string
import gleetcode/internal/file
import gleetcode/internal/process
import gleetcode/internal/resolver

pub fn run(
  base_dir: String,
  target: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  use module_name <- result.try(resolver.resolve_module(base_dir, target))

  print("Building tests for: " <> target)
  use _ <- result.try(build_erlang(base_dir))

  use project_name <- result.try(read_project_name(base_dir))
  let test_module = "solutions@" <> module_name <> "@solution_test"

  print("Running tests for: " <> target)
  case run_eunit(base_dir, project_name, test_module, print) {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(msg)
  }
}

fn build_erlang(base_dir: String) -> Result(Nil, String) {
  case process.run("gleam", ["build", "--target", "erlang"], base_dir) {
    Error(err) -> Error("Failed to start build: " <> err)
    Ok(#(0, _)) -> Ok(Nil)
    Ok(#(_, output)) -> Error("Build failed:\n" <> output)
  }
}

fn run_eunit(
  base_dir: String,
  project_name: String,
  test_module: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  let build_dir = base_dir <> "/build/dev/erlang"
  let project_ebin = build_dir <> "/" <> project_name <> "/ebin"
  let stdlib_ebin = build_dir <> "/gleam_stdlib/ebin"
  let gleeunit_ebin = build_dir <> "/gleeunit/ebin"

  let eval =
    "case eunit:test('"
    <> test_module
    <> "', [verbose]) of ok -> halt(0); error -> halt(1) end."

  let args = [
    "-pa",
    project_ebin,
    stdlib_ebin,
    gleeunit_ebin,
    "-noshell",
    "-eval",
    eval,
  ]

  case process.run("erl", args, base_dir) {
    Error(err) -> Error("Failed to start erl: " <> err)
    Ok(#(0, output)) ->
      case string.trim(output) {
        "" -> Ok(Nil)
        text -> {
          print(text)
          Ok(Nil)
        }
      }
    Ok(#(_, output)) -> Error("Tests failed:\n" <> output)
  }
}

fn read_project_name(base_dir: String) -> Result(String, String) {
  let toml_path = base_dir <> "/gleam.toml"
  case file.read(toml_path) {
    Error(_) -> Error("Could not read gleam.toml")
    Ok(content) -> extract_name_from_toml(content)
  }
}

fn extract_name_from_toml(content: String) -> Result(String, String) {
  let lines = string.split(content, "\n")
  find_name_line(lines)
}

fn find_name_line(lines: List(String)) -> Result(String, String) {
  case lines {
    [] -> Error("No 'name' field found in gleam.toml")
    [line, ..rest] ->
      case string.starts_with(string.trim(line), "name") {
        True ->
          case string.split_once(line, "=") {
            Ok(#(_, value)) ->
              value
              |> string.trim
              |> string.replace("\"", "")
              |> Ok
            Error(_) -> find_name_line(rest)
          }
        False -> find_name_line(rest)
      }
  }
}
