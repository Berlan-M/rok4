#include "ReprojectedImage.h"

#include <string>
#include "Image.h"
#include "Grid.h"
#include "Logger.h"
#include "Kernel.h"
#include <mm_malloc.h>

#include "Utils.h"
#include <cmath>


ReprojectedImage::ReprojectedImage(Image *image,  BoundingBox<double> bbox, Grid* grid,  Kernel::KernelType KT) 
  : Image(grid->width, grid->height, image->channels, bbox), image(image), grid(grid), K(Kernel::getInstance(KT)) {
    
    
    LOGGER_DEBUG("bbox =" << bbox.xmin << " " << bbox.xmax << " " << bbox.ymin << " " << bbox.ymax);
    LOGGER_DEBUG("ibbox =" << image->bbox.xmin << " " << image->bbox.xmax << " " << image->bbox.ymin << " " << image->bbox.ymax);


    double res_x = image->resolution_x();
    double res_y = image->resolution_y();
    grid->bbox.print();
    grid->affine_transform(1./res_x, -image->bbox.xmin/res_x - 0.5, -1./res_y, image->bbox.ymax/res_y - 0.5);
    grid->bbox.print();
    ratio_x = (grid->bbox.xmax - grid->bbox.xmin) / double(width); 
    ratio_y = (grid->bbox.ymax - grid->bbox.ymin) / double(height);

    Kx = ceil(2 * K.size(ratio_x));
    Ky = ceil(2 * K.size(ratio_y));

    LOGGER_DEBUG("KX = " << Kx << " Ky = " << Ky);
 

    int sz1 = 4*((image->width*channels + 3)/4);  // nombre d'éléments d'une ligne de l'image source arrondie au multiple de 4 supérieur.
    int sz2 = 4*((width*channels + 3)/4);         // nombre d'éléments d'une ligne de l'image calculée arrondie au multiple de 4 supérieur.
    int sz3 = 4*((width+3)/4);                    
    int sz4 = 4*((Kx+3)/4);                    
    int sz5 = 4*((Ky+3)/4);                    

    int sz = sz1 * image->height * sizeof(float)             // place pour src_line_buffer;
           + sz2 * 8 * sizeof(float)    // place pour (Ky+4) lignes de resampled_src_line + dst_line_buffer
           + sz3 * 8 * sizeof(float)
           + sz4 * (1028 + 4*channels) * sizeof(float)
           + sz5 * (1028 + 4*channels) * sizeof(float);


    __buffer = (float*) _mm_malloc(sz, 16);  // Allocation allignée sur 16 octets pour SSE
    memset(__buffer, 0, sz);


    float* B = __buffer;

    src_line_buffer = new float*[image->height];
    for(int i = 0; i < image->height; i++) {
      src_line_buffer[i] = B; B += sz1;
    }

    for(int i = 0; i < 4; i++) {
      dst_line_buffer[i] = B; B += sz2;
    }

    mux_dst_line_buffer = B; B += 4*sz2;
    for(int i = 0; i < 4; i++) {
      X[i] = B; B += sz3;
      Y[i] = B; B += sz3;
    }

    dst_line_index = -1;
 
    for(int i = 0; i < 1024; i++) {
      Wx[i] = B; B += sz4;
      Wy[i] = B; B += sz5;
    }
    WWx = B; B += 4*sz4;
    WWy = B; B += 4*sz5;
    TMP1 = B; B += 4*channels*sz4;
    TMP2 = B; B += 4*channels*sz5;

    for(int i = 0; i < 1024; i++) {
      xmin[i] = K.weight(Wx[i], Kx, 1./2048. + double(i)/1024., ratio_x);
      ymin[i] = K.weight(Wy[i], Ky, 1./2048. + double(i)/1024., ratio_y);
    }

    LOGGER_DEBUG("ratio_x =" << ratio_x << " ratio_y= " << ratio_y << " Kx = " << Kx << " Ky = " << Ky);
    

    // TODO : ne pas charger toute l'image source au démarage.
    for(int y = 0; y < image->height; y++) image->getline(src_line_buffer[y], y);
  }


  float* ReprojectedImage::compute_dst_line(int line) {

    if(line/4 == dst_line_index) return dst_line_buffer[line%4];
    dst_line_index = line/4;

    for(int i = 0; i < 4; i++) {
      if(4*dst_line_index+i < height) grid->interpolate_line(4*dst_line_index+i, X[i], Y[i], width);
      else {
        memcpy(X[i], X[0], width*sizeof(float));
        memcpy(Y[i], Y[0], width*sizeof(float));
      }
    }

    int Ix[4], Iy[4];

    for(int x = 0; x < width; x++) {

      for(int i = 0; i < 4; i++) {
        Ix[i] = (X[i][x] - floor(X[i][x])) * 1024;
        Iy[i] = (Y[i][x] - floor(Y[i][x])) * 1024;
//        std::cerr << "Ix " << i << " " << Ix[i] << " " << Iy[i] << " " << xmin[Ix[i]] << " " << ymin[Iy[i]] << std::endl;
      }

      multiplex(WWx, Wx[Ix[0]], Wx[Ix[1]], Wx[Ix[2]], Wx[Ix[3]], Kx);
      multiplex(WWy, Wy[Iy[0]], Wy[Iy[1]], Wy[Iy[2]], Wy[Iy[3]], Ky);

      for(int j = 0; j < Ky; j++) {
        multiplex_unaligned(TMP1,
                  src_line_buffer[(int)(Y[0][x]) + ymin[Iy[0]] + j] + ((int)(X[0][x]) + xmin[Ix[0]])*channels,
                  src_line_buffer[(int)(Y[1][x]) + ymin[Iy[1]] + j] + ((int)(X[1][x]) + xmin[Ix[1]])*channels,
                  src_line_buffer[(int)(Y[2][x]) + ymin[Iy[2]] + j] + ((int)(X[2][x]) + xmin[Ix[2]])*channels,
                  src_line_buffer[(int)(Y[3][x]) + ymin[Iy[3]] + j] + ((int)(X[3][x]) + xmin[Ix[3]])*channels,
                  Kx * channels);
        dot_prod(channels, Kx, TMP2 + 4*j*channels, TMP1, WWx);
      }

      dot_prod(channels, Ky, mux_dst_line_buffer + 4*x*channels, TMP2, WWy);        
    }

    demultiplex(dst_line_buffer[0], dst_line_buffer[1], dst_line_buffer[2], dst_line_buffer[3], mux_dst_line_buffer, width*channels);
    return dst_line_buffer[line%4]; 
  }



  int ReprojectedImage::getline(float* buffer, int line) {    
    const float* dst_line = compute_dst_line(line);
    convert(buffer, dst_line, width*channels);
    return width*channels;
  }

  int ReprojectedImage::getline(uint8_t* buffer, int line) {
    const float* dst_line = compute_dst_line(line);
    convert(buffer, dst_line, width*channels);
    return width*channels;
  }


  ReprojectedImage::~ReprojectedImage() {
    delete image;
    delete grid;

    _mm_free(__buffer);
    delete[] src_line_buffer;

  }



