#ifndef EXTENTED_COMPOUND_IMAGE_H
#define EXTENTED_COMPOUND_IMAGE_H

#include "Image.h"
#include <vector>
#include <cstring>
#include "Logger.h"
#include "math.h"

#ifndef __max
#define __max(a, b)   ( ((a) > (b)) ? (a) : (b) )
#endif
#ifndef __min
#define __min(a, b)   ( ((a) < (b)) ? (a) : (b) )
#endif

class ExtendedCompoundImage : public Image {

	friend class extendedCompoundImageFactory;

private:

	std::vector<Image*> images;

	/**
	Remplissage iteratif d'une ligne
	Copie de la portion recouvrante de chaque ligne d'une image dans l'image finale
	retourne le nombre d'octets de la ligne
	*/

	template<typename T>
	int _getline(T* buffer, int line) {

		double y=l2y(line);
		for (uint i=0;i<images.size();i++){
                        /* On écarte les images qui ne se trouvent pas sur la ligne*/
                        if (images[i]->getymin()>=y||images[i]->getymax()<y)
                                continue;
                        if (images[i]->getxmin()>=getxmax()||images[i]->getxmax()<=getxmin())
                                continue;

                        /* c0 : indice de la 1ere colonne dans l'ExtendedCompoundImage de son intersection avec l'image courante */
                        int c0=__max(0,x2c(images[i]->getxmin()));
                        /* c1-1 : indice de la derniere colonne dans l'ExtendedCompoundImage de son intersection avec l'image courante */
                        int c1=__min(width,x2c(images[i]->getxmax()));

                        T* buffer_t = new T[images[i]->width*images[i]->channels];
                        images[i]->getline(buffer_t,images[i]->y2l(y));
                        memcpy(&buffer[c0*channels],
                                   &buffer_t[-(__min(0,x2c(images[i]->getxmin())))*channels],
                                   (c1-c0)*channels*sizeof(T));
                        delete [] buffer_t;

		}
		return width*channels*sizeof(T);
	}

protected:

	/** Constructeur
  Appelé via une fabrique de type extendedCompoundImageFactory
  Les Image sont detruites ensuite en meme temps que l'objet
  Il faut donc les creer au moyen de l operateur new et ne pas s'occuper de leur suppression
	 */
	ExtendedCompoundImage(int width, int height, int channels, BoundingBox<double> bbox, std::vector<Image*>& images) :
		Image(width, height, channels,bbox),
		images(images) {}

public:
	/** D */
	int getline(uint8_t* buffer, int line) { return _getline(buffer, line); }

	/** D */
	int getline(float* buffer, int line) { return _getline(buffer, line); }

	/** Destructeur
      Suppression des images */
	virtual ~ExtendedCompoundImage() {
		for(uint i = 0; i < images.size(); i++)
			delete images[i];
	}

};

class extendedCompoundImageFactory {
public:
	ExtendedCompoundImage* createExtendedCompoundImage(int width, int height, int channels, BoundingBox<double> bbox, std::vector<Image*>& images)
	{
		uint i;
		double intpart;
		for (i=0;i<images.size()-1;i++)
		{
			if (images[i]->getresx()!=images[i+1]->getresx() || images[i]->getresy()!=images[i+1]->getresy() )
			{
				LOGGER_DEBUG("Les images ne sont pas toutes a la meme resolution");
				return NULL;				
			}
			if (modf(images[i]->getxmin()/images[i]->getresx(),&intpart)!=modf(images[i+1]->getxmin()/images[i+1]->getresx(),&intpart)
					|| modf(images[i]->getymax()/images[i]->getresy(),&intpart)!=modf(images[i+1]->getymax()/images[i+1]->getresy(),&intpart))
			{
				LOGGER_DEBUG("Les images ne sont pas toutes en phase");
				return NULL;
			}	
		}
		return new ExtendedCompoundImage(width,height,channels,bbox,images);
	}
};

#endif
