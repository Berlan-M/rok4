#ifndef _ERROR_
#define _ERROR_

#include "HttpResponse.h"

//TODO  : A REECRIRE ENTIEREMENT

class Error : public StaticHttpResponse {
  public:
  Error(std::string message) : StaticHttpResponse("text/plain", (const uint8_t*) message.c_str(), message.length()) {}

  

};

#endif