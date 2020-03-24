#include <sqlanywhere2.h>

VALUE mSQLAnywhere2, cSQLAnywhere2Error;

void Init_sqlanywhere2() {
  mSQLAnywhere2 = rb_define_module("SQLAnywhere2");
  cSQLAnywhere2Error = rb_const_get(mSQLAnywhere2, rb_intern("Error"));

  init_sqlanywhere2_connection();
  init_sqlanywhere2_statement();
}
