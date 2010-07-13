#ifndef LIBTIFF_IMAGE_H
#define LIBTIFF_IMAGE_H

#include "Image.h"
#include "tiffio.h"

class LibtiffImage : public Image {
  private:
  TIFF* tif;
  int planarconfig;

  public:

  /** D */
  int getline(uint8_t* buffer, int line);

  /** D */
  int getline(float* buffer, int line) {return 1;}

  /** D */
  bool isValid();

  /** D */
  LibtiffImage(char* filename);

  /** D */
  ~LibtiffImage();
};

#endif
