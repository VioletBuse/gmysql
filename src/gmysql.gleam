import gleam/dynamic.{type Dynamic}

pub type Connection

pub type ConnectionMode {
  Synchronous
  Asynchronous
  Lazy
}

pub type ConnectionOption {
  Host(String)
  Port(Int)
  User(String)
  Password(String)
  Database(String)
  ConnectMode(ConnectionMode)
  ConnectTimeout(Int)
  KeepAlive(Int)
}

pub type Error {
  ServerError(Int, BitArray)
  UnknownError(Dynamic)
  DecodeError(dynamic.DecodeErrors)
}

pub type Param

@external(erlang, "gmysql_ffi", "connect")
pub fn connect(options: List(ConnectionOption)) -> Result(Connection, Dynamic)

@external(erlang, "gmysql_ffi", "with_connection")
pub fn with_connection(
  options: List(ConnectionOption),
  with function: fn(Connection) -> a,
) -> Result(a, Dynamic)

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
