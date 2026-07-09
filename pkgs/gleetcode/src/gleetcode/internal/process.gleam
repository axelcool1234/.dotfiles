pub fn run(
  command: String,
  args: List(String),
  cwd: String,
) -> Result(#(Int, String), String) {
  run_command(command, args, cwd)
}

pub fn sleep(ms: Int) -> Nil {
  sleep_ms(ms)
}

@external(erlang, "gleetcode_process_ffi", "run")
fn run_command(
  command: String,
  args: List(String),
  cwd: String,
) -> Result(#(Int, String), String)

@external(erlang, "gleetcode_process_ffi", "sleep")
fn sleep_ms(ms: Int) -> Nil

