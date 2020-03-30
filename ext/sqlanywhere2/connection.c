#include <sqlanywhere2.h>

static VALUE cSQLAnywhere2Connection;
extern VALUE mSQLAnywhere2, cSQLAnywhere2Error;
static ID intern_new;

/*
 * used to pass all arguments to sqlany_connect while inside
 * rb_thread_call_without_gvl
 */
struct nogvl_connect_args {
  a_sqlany_connection *connection;
  const char *opts;
};

/*
 * used to pass all arguments to sqlany_execute_immediate while inside
 * rb_thread_call_without_gvl
 */
struct nogvl_execute_immediate_args {
  a_sqlany_connection *connection;
  const char *sql;
};

/*
 * used to pass all arguments to sqlany_execute_direct while inside
 * rb_thread_call_without_gvl
 */
struct nogvl_execute_direct_args {
  a_sqlany_connection *connection;
  a_sqlany_stmt *stmt;
  const char *sql;
};

static void *nogvl_commit(void *connection) {
  sacapi_bool result;

  result = sqlany_commit(connection);

  return (void *)(result != 0 ? Qtrue : Qfalse);
}

static void *nogvl_rollback(void *connection) {
  sacapi_bool result;

  result = sqlany_rollback(connection);

  return (void *)(result != 0 ? Qtrue : Qfalse);
}

static void *nogvl_connect(void *ptr) {
  struct nogvl_connect_args *args = ptr;
  sacapi_bool result;

  result = sqlany_connect(args->connection, args->opts);

  return (void *)(result != 0 ? Qtrue : Qfalse);
}

static void *nogvl_execute_immediate(void *ptr) {
  struct nogvl_execute_immediate_args *args = ptr;
  sacapi_bool result;

  result = sqlany_execute_immediate(args->connection, args->sql);

  return (void*)(result != 0 ? Qtrue : Qfalse);
}

static void nogvl_execute_immediate_ubf(void *ptr) {
  struct nogvl_execute_immediate_args *args = ptr;

  sqlany_cancel(args->connection);
}

static void *nogvl_execute_direct(void *ptr) {
  struct nogvl_execute_direct_args *args = ptr;

  args->stmt = sqlany_execute_direct(args->connection, args->sql);

  return (void*)(args->stmt != NULL ? Qtrue : Qfalse);
}

static void nogvl_execute_direct_ubf(void *ptr) {
  struct nogvl_execute_direct_args *args = ptr;

  sqlany_cancel(args->connection);
}

static void *nogvl_close(void *ptr) {
  sqlanywhere_connection_wrapper *wrapper = ptr;

  if (!wrapper->closed) {
    sqlany_disconnect(wrapper->connection);
    wrapper->closed = 1;
  }

  return NULL;
}

/* call-seq: connection.close # => nil
 *
 * Explicitly closing this will free up server resources immediately rather
 * than waiting for the garbage collector.
 */
static VALUE rb_sqlanywhere_connection_close(VALUE self) {
  GET_CONNECTION(self);

  if (wrapper->connection) {
    rb_thread_call_without_gvl(nogvl_close, wrapper, RUBY_UBF_IO, 0);
  }

  return Qnil;
}

rb_encoding * rb_sqlanywhere_encoding(VALUE self) {
  VALUE encoding = rb_iv_get(self, "@encoding");
  const char *c_encoding = StringValueCStr(encoding);

  return rb_enc_find(c_encoding);
}

void rb_raise_sqlanywhere_error(VALUE self) {
  GET_CONNECTION(self);
  char error_buffer[SACAPI_ERROR_SIZE];
  char state_buffer[SACAPI_ERROR_SIZE];
  sacapi_i32 result;
  VALUE rb_error_msg;
  VALUE rb_sql_state;
  VALUE e;

  result = sqlany_error(wrapper->connection, error_buffer, SACAPI_ERROR_SIZE);

  sqlany_sqlstate(wrapper->connection, state_buffer, SACAPI_ERROR_SIZE);

  // Clear currently stored error
  sqlany_clear_error(wrapper->connection);

  rb_error_msg = rb_str_new2(error_buffer);
  rb_sql_state = rb_str_new2(state_buffer);

  rb_enc_associate(rb_error_msg, rb_sqlanywhere_encoding(self));
  rb_enc_associate(rb_sql_state, rb_sqlanywhere_encoding(self));

  e = rb_funcall(cSQLAnywhere2Error, intern_new, 3, rb_error_msg, INT2NUM(result), rb_sql_state);
  rb_exc_raise(e);
}

static void rb_sqlanywhere_connection_free(void *ptr) {
  sqlanywhere_connection_wrapper *wrapper = ptr;
  decr_sqlanywhere_connection(wrapper);
}

void decr_sqlanywhere_connection(sqlanywhere_connection_wrapper *wrapper) {
  wrapper->refcount--;

  if (wrapper->refcount == 0) {
    nogvl_close(wrapper);
    sqlany_free_connection(wrapper->connection);
    xfree(wrapper);
  }
}

static VALUE allocate(VALUE klass) {
  VALUE obj;
  sqlanywhere_connection_wrapper * wrapper;
  obj = Data_Make_Struct(
    klass,
    sqlanywhere_connection_wrapper,
    NULL,
    rb_sqlanywhere_connection_free,
    wrapper
  );
  wrapper->closed = 1; /* will be set false after calling sqlany_connect */
  wrapper->refcount = 1;

  return obj;
}

static VALUE rb_sqlanywhere_connection_execute_immediate(VALUE self, VALUE sql) {
  struct nogvl_execute_immediate_args args;
  GET_CONNECTION(self);

  Check_Type(sql, T_STRING);

  args.connection = wrapper->connection;
  args.sql = StringValueCStr(sql);

  if ((VALUE) rb_thread_call_without_gvl(nogvl_execute_immediate, &args, nogvl_execute_immediate_ubf, &args) == Qfalse) {
    rb_raise_sqlanywhere_error(self);
  }

  return Qnil;
}

static VALUE rb_initialize_lib(VALUE self) {
  /* Initializing sqlanywhere library
   * Due to specifics in libdbcapi_r each separate process needs to call this to work properly
   * This is especially needed when forking an existing process
   */
  if (sqlany_init("RUBY", _SACAPI_VERSION, NULL) == 0) {
    rb_raise(rb_eRuntimeError, "Could not initialize SQLAnywhere client library");
  }

  return self;
}

static VALUE rb_initialize_connection(VALUE self) {
  GET_CONNECTION(self);

  wrapper->connection = sqlany_new_connection();

  return self;
}

static VALUE rb_sqlanywhere_connect(VALUE self, VALUE opts) {
  struct nogvl_connect_args args;
  VALUE rv;
  GET_CONNECTION(self);

  args.opts = StringValueCStr(opts);
  args.connection = wrapper->connection;

  rv = (VALUE) rb_thread_call_without_gvl(nogvl_connect, &args, RUBY_UBF_IO, 0);

  if (rv == Qfalse) {
    rb_raise_sqlanywhere_error(self);
  }

  wrapper->closed = 0;
  return self;
}

static VALUE rb_sqlanywhere_connection_prepare_statement(VALUE self, VALUE sql) {
  GET_CONNECTION(self);

  Check_Type(sql, T_STRING);

  a_sqlany_stmt *stmt = sqlany_prepare(wrapper->connection, StringValueCStr(sql));

  if (stmt == NULL) {
    rb_raise_sqlanywhere_error(self);
  }

  return rb_sqlanywhere_stmt_new(self, stmt);
}

static VALUE rb_sqlanywhere_connection_execute_direct(VALUE self, VALUE sql) {
  struct nogvl_execute_direct_args args;
  GET_CONNECTION(self);

  Check_Type(sql, T_STRING);

  args.connection = wrapper->connection;
  args.sql = StringValueCStr(sql);

  if ((VALUE) rb_thread_call_without_gvl(nogvl_execute_direct, &args, nogvl_execute_direct_ubf, &args) == Qfalse) {
    rb_raise_sqlanywhere_error(self);
  }

  VALUE statement = rb_sqlanywhere_stmt_new(self, args.stmt);
  VALUE result = rb_ary_new();

  rb_ary_push(result, statement);
  rb_ary_push(result, rb_sqlanywhere_stmt_last_result(statement));

  return result;
}

/* call-seq:
 *    connection.commit
 *
 * Returns true if succeeded, false if not
 */
static VALUE rb_sqlanywhere_commit(VALUE self) {
  GET_CONNECTION(self);

  return (VALUE) rb_thread_call_without_gvl(nogvl_commit, wrapper->connection, RUBY_UBF_IO, 0);
}

/* call-seq:
 *    connection.commit!
 *
 * Returns true if succeeded, raises an error if not
 */
static VALUE rb_sqlanywhere_commit_bang(VALUE self) {
  GET_CONNECTION(self);

  if ((VALUE) rb_thread_call_without_gvl(nogvl_commit, wrapper->connection, RUBY_UBF_IO, 0) == Qfalse) {
    rb_raise_sqlanywhere_error(self);
  }

  return Qtrue;
}

/* call-seq:
 *    connection.rollback
 *
 * Returns true if succeeded, false if not
 */
static VALUE rb_sqlanywhere_rollback(VALUE self) {
  GET_CONNECTION(self);

  return (VALUE) rb_thread_call_without_gvl(nogvl_rollback, wrapper->connection, RUBY_UBF_IO, 0);
}

/* call-seq:
 *    connection.rollback!
 *
 * Returns true if succeeded, raises an error if not
 */
static VALUE rb_sqlanywhere_rollback_bang(VALUE self) {
  GET_CONNECTION(self);

  if ((VALUE) rb_thread_call_without_gvl(nogvl_rollback, wrapper->connection, RUBY_UBF_IO, 0) == Qfalse) {
    rb_raise_sqlanywhere_error(self);
  }

  return Qtrue;
}

void init_sqlanywhere2_connection() {
  cSQLAnywhere2Connection = rb_define_class_under(mSQLAnywhere2, "Connection", rb_cObject);

  rb_define_alloc_func(cSQLAnywhere2Connection, allocate);
  rb_define_method(cSQLAnywhere2Connection, "close", rb_sqlanywhere_connection_close, 0);
  rb_define_method(cSQLAnywhere2Connection, "commit", rb_sqlanywhere_commit, 0);
  rb_define_method(cSQLAnywhere2Connection, "commit!", rb_sqlanywhere_commit_bang, 0);
  rb_define_method(cSQLAnywhere2Connection, "rollback", rb_sqlanywhere_rollback, 0);
  rb_define_method(cSQLAnywhere2Connection, "rollback!", rb_sqlanywhere_rollback_bang, 0);
  rb_define_private_method(cSQLAnywhere2Connection, "_prepare", rb_sqlanywhere_connection_prepare_statement, 1);
  rb_define_private_method(cSQLAnywhere2Connection, "_execute_immediate", rb_sqlanywhere_connection_execute_immediate, 1);
  rb_define_private_method(cSQLAnywhere2Connection, "_execute_direct", rb_sqlanywhere_connection_execute_direct, 1);
  rb_define_private_method(cSQLAnywhere2Connection, "connect", rb_sqlanywhere_connect, 1);
  rb_define_private_method(cSQLAnywhere2Connection, "initialize_connection", rb_initialize_connection, 0);
  rb_define_private_method(cSQLAnywhere2Connection, "initialize_lib", rb_initialize_lib, 0);

  intern_new = rb_intern("new");
}
