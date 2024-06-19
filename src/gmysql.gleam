import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option, None, Some}

pub type Connection

pub type ConnectionMode {
  Synchronous
  Asynchronous
  Lazy
}

type ConnectionOption {
  Host(String)
  Port(Int)
  User(String)
  Password(String)
  Database(String)
  ConnectMode(ConnectionMode)
  ConnectTimeout(Int)
  KeepAlive(Int)
}

pub type Config {
  Config(
    host: String,
    port: Int,
    user: Option(String),
    password: Option(String),
    database: String,
    connection_mode: ConnectionMode,
    connection_timeout: Int,
    keep_alive: Int,
  )
}

pub fn default_config() -> Config {
  Config(
    host: "localhost",
    port: 3306,
    user: None,
    password: None,
    database: "mysql",
    connection_mode: Asynchronous,
    connection_timeout: 1000,
    keep_alive: 1000,
  )
}

fn config_to_connection_options(config: Config) -> List(ConnectionOption) {
  [
    Some(Host(config.host)),
    Some(Port(config.port)),
    option.map(config.user, User),
    option.map(config.password, Password),
    Some(Database(config.database)),
    Some(ConnectMode(config.connection_mode)),
    Some(ConnectTimeout(config.connection_timeout)),
    Some(KeepAlive(config.keep_alive)),
  ]
  |> option.values
}

pub type Error {
  ServerError(Int, BitArray)
  UnknownError(Dynamic)
  DecodeError(dynamic.DecodeErrors)
}

pub type Param

@external(erlang, "gmysql_ffi", "connect")
fn connect_ffi(options: List(ConnectionOption)) -> Result(Connection, Dynamic)

pub fn connect(config: Config) {
  config_to_connection_options(config)
  |> connect_ffi
}

@external(erlang, "gmysql_ffi", "with_connection")
fn with_connection_ffi(
  options: List(ConnectionOption),
  with function: fn(Connection) -> a,
) -> Result(a, Dynamic)

pub fn with_connection(
  config: Config,
  with function: fn(Connection) -> a,
) -> Result(a, Dynamic) {
  config_to_connection_options(config)
  |> with_connection_ffi(function)
}

@external(erlang, "gmysql_ffi", "exec")
pub fn exec(
  connection: Connection,
  query: String,
  timeout: Int,
) -> Result(Nil, Error)

@external(erlang, "gmysql_ffi", "to_param")
pub fn to_param(param: a) -> Param

@external(erlang, "gmysql_ffi", "query")
fn query_internal(
  connection: Connection,
  query: String,
  params: List(Param),
  timeout: Int,
) -> Result(Dynamic, Error)

pub fn query(
  connection: Connection,
  query: String,
  params: List(Param),
  timeout: Int,
  decoder: fn(Dynamic) -> Result(a, dynamic.DecodeErrors),
) -> Result(a, Error) {
  case query_internal(connection, query, params, timeout) {
    Error(int) -> Error(int)
    Ok(dyn) ->
      case decoder(dyn) {
        Ok(decoded) -> Ok(decoded)
        Error(decode_errors) -> Error(DecodeError(decode_errors))
      }
  }
}

pub type TransactionError(a) {
  FunctionError(a)
  OtherError(Dynamic)
}

/// Execute a function within a transaction.
/// If the function throws or returns an error, it will rollback.
/// You can nest this function, which will create a savepoint.
@external(erlang, "gmysql_ffi", "with_transaction")
pub fn with_transaction(
  connection: Connection,
  retry retries: Int,
  with function: fn(Connection) -> Result(a, b),
) -> Result(a, TransactionError(b))

@external(erlang, "gmysql_ffi", "close")
pub fn close(connection: Connection) -> Nil