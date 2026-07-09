import gleam/erlang/atom.{type Atom}

pub type FileError =
  Atom

pub fn read(path: String) -> Result(String, FileError) {
  read_file(path)
}

pub fn write(path: String, contents: String) -> Result(Nil, FileError) {
  write_file(path, contents)
}

pub fn write_private(path: String, contents: String) -> Result(Nil, FileError) {
  write_private_file(path, contents)
}

pub fn mkdir(path: String) -> Result(Nil, FileError) {
  ensure_dir(path <> "/.")
}

pub fn exists(path: String) -> Bool {
  is_regular(path)
}

pub fn dir_exists(path: String) -> Bool {
  is_dir(path)
}

pub fn list_directory(path: String) -> Result(List(String), FileError) {
  list_dir(path)
}

pub fn describe_error(error: FileError) -> String {
  atom.to_string(error)
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, FileError)

@external(erlang, "gleetcode_file_ffi", "write_file")
fn write_file(path: String, contents: String) -> Result(Nil, FileError)

@external(erlang, "gleetcode_file_ffi", "write_private_file")
fn write_private_file(path: String, contents: String) -> Result(Nil, FileError)

@external(erlang, "gleetcode_file_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Result(Nil, FileError)

@external(erlang, "filelib", "is_regular")
fn is_regular(path: String) -> Bool

@external(erlang, "filelib", "is_dir")
fn is_dir(path: String) -> Bool

@external(erlang, "gleetcode_file_ffi", "list_dir")
fn list_dir(path: String) -> Result(List(String), FileError)

