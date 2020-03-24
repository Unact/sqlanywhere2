void Init_sqlanywhere(void);

#if defined(SQLANY_API_VERSION_4)
  #define _SACAPI_VERSION SQLANY_API_VERSION_4
#else
  #define _SACAPI_VERSION SQLANY_API_VERSION_2
#endif

#include <ruby.h>
#include <ruby/encoding.h>
#include <ruby/thread.h>

#include <sacapi.h>
#include <connection.h>
#include <statement.h>
