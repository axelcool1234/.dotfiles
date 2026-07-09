import gleam/list
import gleeunit
import gleetcode.{Auth, Fetch, GlobalOpts, Init, List, Submit, Test}
import gleetcode/internal/spec_parser

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parse_global_with_directory_test() {
  let assert #(GlobalOpts(directory: "/tmp/proj"), ["init"]) =
    gleetcode.parse_global(["-C", "/tmp/proj", "init"])
}

pub fn parse_global_default_test() {
  let assert #(GlobalOpts(directory: "."), ["fetch", "two-sum"]) =
    gleetcode.parse_global(["fetch", "two-sum"])
}

pub fn route_init_test() {
  let assert Ok(Init) = gleetcode.route(["init"])
}

pub fn route_auth_test() {
  let assert Ok(Auth) = gleetcode.route(["auth"])
}

pub fn route_list_test() {
  let assert Ok(List([])) = gleetcode.route(["list"])
}

pub fn route_fetch_test() {
  let assert Ok(Fetch("two-sum")) = gleetcode.route(["fetch", "two-sum"])
}

pub fn route_submit_test() {
  let assert Ok(Submit("two-sum")) = gleetcode.route(["submit", "two-sum"])
}

pub fn route_test_test() {
  let assert Ok(Test("two-sum")) = gleetcode.route(["test", "two-sum"])
}

pub fn route_missing_arg_test() {
  let assert Error("Missing argument: <slug-or-number>") =
    gleetcode.route(["fetch"])
}

pub fn parse_erlang_spec_test() {
  let snippet =
    "-spec twoSum(Nums :: [integer()], Target :: integer()) -> [integer()]."
  let assert Ok(spec) = spec_parser.parse_erlang_spec(snippet)

  assert spec.name == "twoSum"
  assert spec.return_type == "List(Int)"
  assert list.map(spec.params, fn(p) { #(p.name, p.type_str) }) == [
    #("nums", "List(Int)"),
    #("target", "Int"),
  ]
}

pub fn parse_tree_node_spec_test() {
  let snippet =
    "-spec invertTree(Root :: 'null' | #tree_node{}) -> 'null' | #tree_node{}."
  let assert Ok(spec) = spec_parser.parse_erlang_spec(snippet)

  assert spec.params == [spec_parser.Param("root", "Option(TreeNode)")]
  assert spec.return_type == "Option(TreeNode)"
}
