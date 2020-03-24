#ifndef SQLANYWHERE_STATEMENT_H
#define SQLANYWHERE_STATEMENT_H

typedef struct {
  VALUE connection;
  sqlanywhere_connection_wrapper *connection_wrapper;
  a_sqlany_stmt *stmt;
  int closed;
  int fetched;
} sqlanywhere_stmt_wrapper;

void init_sqlanywhere_statement(void);

VALUE rb_sqlanywhere_stmt_new(VALUE connection, a_sqlany_stmt *stmt);
VALUE rb_sqlanywhere_stmt_last_result(VALUE self);

#endif
