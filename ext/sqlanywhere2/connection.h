#ifndef SQLANYWHERE_CONNECTION_H
#define SQLANYWHERE_CONNECTION_H

typedef struct {
  long server_version;
  int refcount;
  int closed;
  a_sqlany_connection *connection;
} sqlanywhere_connection_wrapper;


#define GET_CONNECTION(self) \
  sqlanywhere_connection_wrapper *wrapper; \
  Data_Get_Struct(self, sqlanywhere_connection_wrapper, wrapper);

void init_sqlanywhere_connection(void);
void decr_sqlanywhere_connection(sqlanywhere_connection_wrapper *wrapper);
void rb_raise_sqlanywhere_error(VALUE self);
rb_encoding * rb_sqlanywhere_encoding(VALUE self);

#endif
