#include <sqlanywhere2.h>

#define ROW_NOT_FOUND_ERROR 100

extern VALUE mSQLAnywhere2, cSQLAnywhere2Error;
static VALUE cSQLAnywhere2Statement, cSQLAnywhere2Result, cSQLAnywhere2Column, cBigDecimal, cTime, cDate;
static VALUE intern_parse, intern_new, intern_BigDecimal, intern_localtime, intern_utc, sym_local;

#define GET_STATEMENT(self) \
  sqlanywhere_stmt_wrapper *stmt_wrapper; \
  Data_Get_Struct(self, sqlanywhere_stmt_wrapper, stmt_wrapper); \
  if (!stmt_wrapper->stmt) { rb_raise(cSQLAnywhere2Error, "Invalid statement handle"); } \
  if (stmt_wrapper->closed) { rb_raise(cSQLAnywhere2Error, "Statement handle already closed"); }


/*
 * used to pass all arguments to sqlany_execute_direct while inside
 * rb_thread_call_without_gvl
 */
struct nogvl_stmt_execute_args {
  a_sqlany_connection *connection;
  a_sqlany_stmt *stmt;
};

/*
 * used to pass all arguments to sqlanywhere_data_to_rb_data
 */
struct sqlanywhere_data_to_rb_data_args {
  int cast;
  rb_encoding *encoding;
  VALUE database_timezone;
  VALUE opt_time_date;
  a_sqlany_data_value *value;
  a_sqlany_column_info *info;
};

/*
 * used to pass all arguments to rb_data_to_sqlanywhere_data
 */
struct rb_data_to_sqlanywhere_data_args {
  rb_encoding *encoding;
  VALUE arg;
  a_sqlany_data_value *value;
};

// Free all allocated bind_params
#define FREE_BINDS                              \
  for (i = 0; i < alloc_count; i++) {           \
    xfree(bind_params[i].value.is_null);        \
    xfree(bind_params[i].value.length);         \
    if (bind_params[i].value.buffer != NULL) {  \
      xfree(bind_params[i].value.buffer);       \
    }                                           \
  }                                             \

static void rb_data_to_sqlanywhere_data(struct rb_data_to_sqlanywhere_data_args data) {
  a_sqlany_data_value *value = data.value;
  VALUE arg = data.arg;
  size_t length;
  rb_encoding *arg_encoding;

  value->is_null = xmalloc(sizeof(int));
  value->length = xmalloc(sizeof(size_t));

  *((int*)value->is_null) = 0;

  switch(TYPE(arg)) {
    case T_STRING:
      arg_encoding = rb_enc_get(arg);
      length = RSTRING_LEN(arg);

      value->buffer = xmalloc(length);
      memcpy(value->buffer, RSTRING_PTR(arg), length);
      *value->length = length;

      value->type = A_STRING;
      // If encoding is ASCII_8BIT then this is a binary string
      if (arg_encoding == rb_ascii8bit_encoding()) {
        value->type = A_BINARY;
      }

      break;
  case T_FIXNUM:
    if (sizeof(void*) == 4) {
      value->buffer = xmalloc(sizeof(int));
      *((int*)value->buffer) = FIX2INT(arg);
      value->type = A_VAL32;
    } else {
      value->buffer = xmalloc(sizeof(long));
      *((long*)value->buffer) = FIX2LONG(arg);
      value->type = A_VAL64;
    }

    break;
  // Since some BIGNUMs don't fit into LONG_LONG always send as STRING type
  case T_BIGNUM:
    arg = rb_big2str(arg, 10);
    length = RSTRING_LEN(arg);

    value->buffer = xmalloc(length);
    memcpy(value->buffer, RSTRING_PTR(arg), length);
    value->type = A_STRING;
    *value->length = length;

    break;
  case T_FLOAT:
    value->buffer = xmalloc(sizeof(double));
    *((double*)value->buffer) = (double) NUM2DBL(arg);
    value->type = A_DOUBLE;
    break;
  case T_NIL:
    value->buffer = NULL;
    value->type = A_VAL32;
    *((int*)value->is_null) = 1;
    break;
  default:
    rb_raise(rb_eTypeError, "Cannot convert type. Must be STRING, FIXNUM, BIGNUM, FLOAT, or NIL");
    break;
  }
}

static VALUE sqlanywhere_data_to_rb_data(struct sqlanywhere_data_to_rb_data_args data) {
  a_sqlany_data_value *value = data.value;
  a_sqlany_column_info *info = data.info;
  VALUE ret_data;

  if (*value->is_null) {
    ret_data = Qnil;
  } else {
    switch(value->type) {
    case A_BINARY:
      ret_data = rb_str_new(value->buffer, *value->length);
      break;
    case A_STRING:
      ret_data = rb_str_new(value->buffer, *value->length);
      rb_enc_associate(ret_data, data.encoding);
      break;
    case A_DOUBLE:
      ret_data = rb_float_new(*(double*) value->buffer);
      break;
    case A_VAL64:
      ret_data = LL2NUM(*(LONG_LONG*)value->buffer);
      break;
    case A_UVAL64:
      ret_data = ULL2NUM(*(unsigned LONG_LONG*)value->buffer);
      break;
    case A_VAL32:
      ret_data = INT2NUM(*(int *)value->buffer);
      break;
    case A_UVAL32:
      ret_data = UINT2NUM(*(unsigned int *)value->buffer);
      break;
    case A_VAL16:
      ret_data = INT2NUM(*(short *)value->buffer);
      break;
    case A_UVAL16:
      ret_data = UINT2NUM(*(unsigned short *)value->buffer);
      break;
    case A_VAL8:
    case A_UVAL8:
      ret_data = CHR2FIX(*(unsigned char *)value->buffer);
      break;
    case A_INVALID_TYPE:
      rb_raise(rb_eTypeError, "Invalid Data Type");
    default:
      ret_data = Qnil;
      break;
    }

    if (data.cast) {
      switch(info->native_type) {
      case DT_DECIMAL:
        ret_data = rb_funcall(rb_cObject, intern_BigDecimal, 1, ret_data);
        break;
      case DT_DATE:
        ret_data = rb_funcall(cDate, intern_parse, 1, ret_data);
        break;
      case DT_TIMESTAMP:
        ret_data = rb_funcall(cTime, intern_parse, 1, ret_data);

        if (data.database_timezone == sym_local) {
          ret_data = rb_funcall(ret_data, intern_localtime, 0);
        } else {
          ret_data = rb_funcall(ret_data, intern_utc, 0);
        }

        break;
      case DT_TIME:
        ret_data = rb_funcall(cTime, intern_parse, 2, ret_data, data.opt_time_date);

        if (data.database_timezone == sym_local) {
          ret_data = rb_funcall(ret_data, intern_localtime, 0);
        } else {
          ret_data = rb_funcall(ret_data, intern_utc, 0);
        }

        break;
      case DT_BIT:
        ret_data = FIX2INT(ret_data) == 1 ? Qtrue : Qfalse;
        break;
      default:
        break;
      }
    }
  }

  return ret_data;
}

static void *nogvl_stmt_execute(void *ptr) {
  struct nogvl_stmt_execute_args *args = ptr;
  sacapi_bool result;

  result = sqlany_execute(args->stmt);

  return (void*)(result != 0 ? Qtrue : Qfalse);
}

static void nogvl_stmt_execute_ubf(void *ptr) {
  struct nogvl_stmt_execute_args *args = ptr;

  sqlany_cancel(args->connection);
}

static void *nogvl_stmt_close(void *ptr) {
  sqlanywhere_stmt_wrapper *stmt_wrapper = ptr;

  if (!stmt_wrapper->closed) {
    stmt_wrapper->closed = 1;
    sqlany_free_stmt(stmt_wrapper->stmt);
  }

  return NULL;
}

static void *nogvl_stmt_fetch_next(void *ptr) {
  sqlanywhere_stmt_wrapper *stmt_wrapper = ptr;
  sacapi_bool result = 0;

  if (!stmt_wrapper->closed) {
    result = sqlany_fetch_next(stmt_wrapper->stmt);
  }

  return (void*)(result != 0 ? Qtrue : Qfalse);
}

static void rb_sqlanywhere_stmt_mark(void * ptr) {
  sqlanywhere_stmt_wrapper *stmt_wrapper = ptr;
  if (!stmt_wrapper) return;

  rb_gc_mark(stmt_wrapper->connection);
}

static void rb_sqlanywhere_stmt_free(void *ptr) {
  sqlanywhere_stmt_wrapper *stmt_wrapper = ptr;

  nogvl_stmt_close(stmt_wrapper);
  decr_sqlanywhere_connection(stmt_wrapper->connection_wrapper);
  xfree(stmt_wrapper);
}

static void rb_raise_sqlanywhere_stmt_error(sqlanywhere_stmt_wrapper *stmt_wrapper) {
  rb_raise_sqlanywhere_error(stmt_wrapper->connection);
}

VALUE rb_sqlanywhere_stmt_new(VALUE connection, a_sqlany_stmt *stmt) {
  GET_CONNECTION(connection);
  sqlanywhere_stmt_wrapper *stmt_wrapper;
  VALUE rb_stmt;

  rb_stmt = Data_Make_Struct(
    cSQLAnywhere2Statement,
    sqlanywhere_stmt_wrapper,
    rb_sqlanywhere_stmt_mark,
    rb_sqlanywhere_stmt_free,
    stmt_wrapper
  );

  stmt_wrapper->connection = connection;
  stmt_wrapper->connection_wrapper = DATA_PTR(connection);
  stmt_wrapper->connection_wrapper->refcount++;
  stmt_wrapper->closed = 0;
  stmt_wrapper->fetched = 0;
  stmt_wrapper->stmt = stmt;

  return rb_stmt;
}

static VALUE rb_sqlanywhere_stmt_rows(VALUE self) {
  GET_STATEMENT(self);
  GET_CONNECTION(stmt_wrapper->connection);
  VALUE rows = rb_ary_new();
  sacapi_i32 num_cols = sqlany_num_cols(stmt_wrapper->stmt);
  struct sqlanywhere_data_to_rb_data_args sqlanywhere_data;
  a_sqlany_data_value col_value;
  int error_code;
  VALUE row;
  int i;

  sqlanywhere_data.encoding = rb_sqlanywhere_encoding(stmt_wrapper->connection);
  sqlanywhere_data.cast = rb_iv_get(stmt_wrapper->connection, "@cast") == Qtrue;
  sqlanywhere_data.database_timezone = rb_iv_get(stmt_wrapper->connection, "@database_timezone");
  sqlanywhere_data.opt_time_date = rb_funcall(cDate, intern_new, 2, INT2NUM(2000), INT2NUM(1));

  if (num_cols < 0) {
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  if (num_cols == 0) {
    return Qnil;
  }

  a_sqlany_column_info column_info[num_cols];
  for (i = 0; i < num_cols; i++) {
    sqlany_get_column_info(stmt_wrapper->stmt, i, &column_info[i]);
  }

  while((VALUE) rb_thread_call_without_gvl(nogvl_stmt_fetch_next, stmt_wrapper, RUBY_UBF_IO, 0) == Qtrue) {
    row = rb_ary_new();

    for (i = 0; i < num_cols; i++) {
      if (!sqlany_get_column(stmt_wrapper->stmt, i, &col_value)) {
        rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
      }

      sqlanywhere_data.value = &col_value;
      sqlanywhere_data.info = &column_info[i];

      rb_ary_push(row, sqlanywhere_data_to_rb_data(sqlanywhere_data));
    }

    rb_ary_push(rows, row);
  }

  /* SQLAnywhere bug
  * When executing a select query with wrong search type
  * it doesn't return an error until we start to fetch results
  * Example
  *
  * CREATE TABLE exp(id INT, name VARCHAR(255));
  * SELECT * FROM exp where name = 123;
  *
  * This will only return an error when we start fetching results
  */
  error_code = sqlany_error(wrapper->connection, NULL, SACAPI_ERROR_SIZE);

  if (error_code != 0 && error_code != ROW_NOT_FOUND_ERROR) {
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  return rows;
}

/* call-seq:
 *    stmt.affected_rows
 *
 * Returns the number of rows changed, deleted, or inserted.
 */
static VALUE rb_sqlanywhere_stmt_affected_rows(VALUE self) {
  sacapi_i32 affected;
  GET_STATEMENT(self);

  affected = sqlany_affected_rows(stmt_wrapper->stmt);

  if (affected == -1) {
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  return ULL2NUM(affected);
}

/* call-seq: stmt.num_params # => Numeric
 *
 * Returns the number of parameters the prepared statement expects.
 */
static VALUE rb_sqlanywhere_stmt_num_params(VALUE self) {
  sacapi_i32 params;
  GET_STATEMENT(self);

  params = sqlany_num_params(stmt_wrapper->stmt);

  if (params == -1) {
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  return ULL2NUM(params);
}

/* call-seq: stmt.num_columns # => Numeric
 *
 * Returns the number of parameters the prepared statement expects.
 */
static VALUE rb_sqlanywhere_stmt_num_columns(VALUE self) {
  sacapi_i32 cols;
  GET_STATEMENT(self);

  cols = sqlany_num_cols(stmt_wrapper->stmt);

  if (cols == -1) {
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  return ULL2NUM(cols);
}

/* call-seq: stmt.columns # => array
 *
 * Returns a list of columns that will be returned by this statement.
 */
static VALUE rb_sqlanywhere_stmt_columns(VALUE self) {
  sacapi_i32 column_count;
  sacapi_i32 i;
  VALUE column_list;
  GET_STATEMENT(self);
  GET_CONNECTION(stmt_wrapper->connection);

  column_count = sqlany_num_cols(stmt_wrapper->stmt);
  column_list = rb_ary_new2((long)column_count);

  for (i = 0; i < column_count; i++) {
    VALUE rb_field;
    a_sqlany_column_info column_info;

    if (sqlany_get_column_info(stmt_wrapper->stmt, i, &column_info) == 0) {
      rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
    }

    rb_field = rb_funcall(
      cSQLAnywhere2Column,
      intern_new,
      7,
      rb_str_new2(column_info.name),
      INT2NUM(column_info.type),
      INT2NUM(column_info.native_type),
      INT2NUM(column_info.precision),
      INT2NUM(column_info.scale),
      INT2NUM(column_info.max_size),
      column_info.nullable == 1 ? Qtrue : Qfalse
    );

    rb_ary_store(column_list, (long)i, rb_field);
  }

  return column_list;
}

/* call-seq: stmt.close # => nil
 *
 * Explicitly closing this will free up server resources immediately rather
 * than waiting for the garbage collector.
 * This is also required to free up any locks in the database.
 * Since statement execution creates a database lock with procedures which contain insert/update
 * irregardless of commit statement
 */
static VALUE rb_sqlanywhere_stmt_close(VALUE self) {
  GET_STATEMENT(self);

  rb_thread_call_without_gvl(nogvl_stmt_close, stmt_wrapper, RUBY_UBF_IO, 0);

  return Qnil;
}

static VALUE rb_sqlanywhere_stmt_create_result(VALUE self) {
  VALUE cols = rb_sqlanywhere_stmt_columns(self);
  VALUE rows = rb_sqlanywhere_stmt_rows(self);

  return rb_funcall(cSQLAnywhere2Result, intern_new, 2, cols, rows);
}

/* call-seq: stmt.last_result # => SQLAnywhere::Result
 *
 * Returns results from previously executed query
 * Returns nil if last query didn't return a result set
 * When used with multiple result query returns an array of SQLAnywhere::Result
 */
VALUE rb_sqlanywhere_stmt_last_result(VALUE self) {
  GET_STATEMENT(self);
  VALUE last_result;

  if (stmt_wrapper->fetched) {
    last_result = rb_iv_get(self, "@last_result");
    return last_result;
  }

  if (sqlany_num_cols(stmt_wrapper->stmt) < 0) {
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  last_result = rb_sqlanywhere_stmt_create_result(self);

  rb_iv_set(self, "@last_result", last_result);

  stmt_wrapper->fetched = 1;

  return last_result;
}

/* call-seq: stmt.execute
 *
 * Executes the current prepared statement, returns +result+.
 */
static VALUE rb_sqlanywhere_stmt_execute(int argc, VALUE *argv, VALUE self) {
  GET_STATEMENT(self);
  GET_CONNECTION(stmt_wrapper->connection);
  sacapi_i32 bind_count;
  sacapi_i32 i;
  a_sqlany_stmt *stmt;
  VALUE result;
  rb_encoding *encoding;
  struct nogvl_stmt_execute_args args;
  struct rb_data_to_sqlanywhere_data_args rb_data;
  int args_count = rb_scan_args(argc, argv, "*", NULL);
  sacapi_i32 alloc_count = 0;

  encoding = rb_sqlanywhere_encoding(stmt_wrapper->connection);
  stmt = stmt_wrapper->stmt;
  bind_count = sqlany_num_params(stmt);

  rb_data.encoding = encoding;

  if (args_count != (sacapi_i32)bind_count) {
    rb_raise(
      cSQLAnywhere2Error,
      "Bind parameter count (%ld) doesn't match number of arguments (%d)",
      (long)bind_count,
      args_count
      );
  }

  // Hold binds to free them up later
  a_sqlany_bind_param bind_params[bind_count];

  if (bind_count > 0) {
    for (i = 0; i < bind_count; i++) {
      if (!sqlany_describe_bind_param(stmt, i, &bind_params[i])) {
        rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
      }

      rb_data.arg = argv[i];
      rb_data.value = &bind_params[i].value;

      rb_data_to_sqlanywhere_data(rb_data);
      alloc_count++;

      if (!sqlany_bind_param(stmt, i, &bind_params[i])) {
        FREE_BINDS;
        rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
      }
    }
  }

  args.stmt = stmt;
  args.connection = wrapper->connection;

  if ((VALUE)rb_thread_call_without_gvl(nogvl_stmt_execute, &args, nogvl_stmt_execute_ubf, &args) == Qfalse) {
    FREE_BINDS;
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  FREE_BINDS;

  stmt_wrapper->fetched = 0;

  result = rb_sqlanywhere_stmt_last_result(self);

  // Reset statement to its prepared state condition
  if (!sqlany_reset(stmt)) {
    rb_raise_sqlanywhere_stmt_error(stmt_wrapper);
  }

  return result;
}

void init_sqlanywhere2_statement() {
  cDate = rb_const_get(rb_cObject, rb_intern("Date"));
  cTime = rb_const_get(rb_cObject, rb_intern("Time"));
  cBigDecimal = rb_const_get(rb_cObject, rb_intern("BigDecimal"));
  cSQLAnywhere2Result = rb_const_get(mSQLAnywhere2, rb_intern("Result"));
  cSQLAnywhere2Column = rb_const_get(mSQLAnywhere2, rb_intern("Column"));

  cSQLAnywhere2Statement = rb_define_class_under(mSQLAnywhere2, "Statement", rb_cObject);
  rb_define_method(cSQLAnywhere2Statement, "execute", rb_sqlanywhere_stmt_execute, -1);
  rb_define_method(cSQLAnywhere2Statement, "close", rb_sqlanywhere_stmt_close, 0);
  rb_define_method(cSQLAnywhere2Statement, "num_columns", rb_sqlanywhere_stmt_num_columns, 0);
  rb_define_method(cSQLAnywhere2Statement, "columns", rb_sqlanywhere_stmt_columns, 0);
  rb_define_method(cSQLAnywhere2Statement, "num_params", rb_sqlanywhere_stmt_num_params, 0);
  rb_define_method(cSQLAnywhere2Statement, "affected_rows", rb_sqlanywhere_stmt_affected_rows, 0);
  rb_define_method(cSQLAnywhere2Statement, "last_result", rb_sqlanywhere_stmt_last_result, 0);

  sym_local = ID2SYM(rb_intern("local"));

  intern_new = rb_intern("new");
  intern_parse = rb_intern("parse");
  intern_BigDecimal = rb_intern("BigDecimal");
  intern_localtime = rb_intern("localtime");
  intern_utc = rb_intern("utc");
}
