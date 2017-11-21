/*
 * Copyright © (2011) Institut national de l'information
 *                    géographique et forestière
 *
 * Géoportail SAV <geop_services@geoportail.fr>
 *
 * This software is a computer program whose purpose is to publish geographic
 * data using OGC WMS and WMTS protocol.
 *
 * This software is governed by the CeCILL-C license under French law and
 * abiding by the rules of distribution of free software.  You can  use,
 * modify and/ or redistribute the software under the terms of the CeCILL-C
 * license as circulated by CEA, CNRS and INRIA at the following URL
 * "http://www.cecill.info".
 *
 * As a counterpart to the access to the source code and  rights to copy,
 * modify and redistribute granted by the license, users are provided only
 * with a limited warranty  and the software's author,  the holder of the
 * economic rights,  and the successive licensors  have only  limited
 * liability.
 *
 * In this respect, the user's attention is drawn to the risks associated
 * with loading,  using,  modifying and/or developing or reproducing the
 * software by the user in light of its specific status of free software,
 * that may mean  that it is complicated to manipulate,  and  that  also
 * therefore means  that it is reserved for developers  and  experienced
 * professionals having in-depth computer knowledge. Users are therefore
 * encouraged to load and test the software's suitability as regards their
 * requirements in conditions enabling the security of their systems and/or
 * data to be ensured and,  more generally, to use and operate it in the
 * same conditions as regards security.
 *
 * The fact that you are presently reading this means that you have had
 *
 * knowledge of the CeCILL-C license and that you accept its terms.
 */

/**
 * \file Context.h
 ** \~french
 * \brief Définition de la classe Context
 * \details Classe d'abstraction du contexte de stockage (fichier, ceph s3 ou swift)
 ** \~english
 * \brief Define classe Context
 * \details Storage context abstraction
 */

#ifndef CONTEXT_H
#define CONTEXT_H

#include <stdint.h>// pour uint8_t
#include "Logger.h"
#include "AliasManager.h"
#include <string.h>
#include <sstream>

/**
 * \~french \brief Énumération des types de contextes
 * \~english \brief Available context type
 */
enum eContextType {
    FILECONTEXT,
    CEPHCONTEXT,
    SWIFTCONTEXT,
    S3CONTEXT
};

/**
 * \author Institut national de l'information géographique et forestière
 * \~french
 * \brief Création d'un contexte de stockage abstrait 
 */
class Context {  

protected:

    /**
     * \~french \brief Précise si le contexte est connecté
     * \~english \brief Precise if context is connected
     */
    bool connected;

    /**
     * \~french \brief Gestionnaire d'alias, pour convertir les noms de fichier/objet
     * \~english \brief Alias manager to convert file/object name
     */
    AliasManager* am;

    /**
     * \~french \brief Crée un objet Context
     * \~english \brief Create a Context object
     */
    Context () : connected(false) { am = NULL; }

public:

    /**
     * \~french
     * \brief Précise le gestionnaire d'alias
     * \~english
     * \brief Set the alias manager
     */
    void setAliasManager(AliasManager* a) {
        am = a;
    }

    /**
     * \~french
     * \brief Convertit le nom grâce au gestionnaire d'alias si présent
     */
    std::string convertName(std::string name) {
        if (am != NULL) {
            bool ex;
            std::string realName = am->getAliasedName(name, &ex);
            if (! ex) {
                return name;
            } else {
                return realName;
            }
        } else {
            return name;
        }
    }

    /**
     * \~french \brief Connecte le contexte
     * \~english \brief Connect the context
     */
    virtual bool connection() = 0;

    /**
     * \~french \brief Précise si l'objet demandé existe dans ce contexte
     * \param[in] name Nom de l'objet dont on veut savoir l'existence 
     * \~english \brief Precise if provided object exists in this context
     * \param[in] name Object's name whose existency is asked
     */
    
    bool exists(std::string name) {
        uint8_t test;
        return (read(&test, 0, 1, name) == 1);
    }

    /**
     * \~french \brief Récupère la donnée dans l'objet
     * \param[in,out] data Buffer où stocker la donnée lue. Doit être initialisé et assez grand
     * \param[in] offset À partir d'où on veut lire
     * \param[in] size Nombre d'octet que l'on veut lire
     * \param[in] name Nom de l'objet que l'on veut lire
     * \return Taille effectivement lue, un nombre négatif en cas d'erreur
     * \~english \brief Get the data in the named object
     * \param[in,out] data Buffer where to store read data. Have to be initialized
     * \param[in] offset From where we want to read
     * \param[in] size Number of bytes we want to read
     * \param[in] name Object's name we want to read
     * \return Real size of read data, negative integer if an error occured
     */
    virtual int read(uint8_t* data, int offset, int size, std::string name) = 0;

    /**
     * \~french \brief Écrit de la donnée dans l'objet
     * \param[in] data Buffer contenant la donnée à écrire
     * \param[in] offset À partir d'où on veut écrire
     * \param[in] size Nombre d'octet que l'on veut écrire
     * \param[in] name Nom de l'objet dans lequel on veut écrire
     * \~english \brief Write data in the named object
     * \param[in] data Buffer with data to write
     * \param[in] offset From where we want to write
     * \param[in] size Number of bytes we want to write
     * \param[in] name Object's name we want to write into
     */
    virtual bool write(uint8_t* data, int offset, int size, std::string name) = 0;

    /**
     * \~french \brief Écrit intégralement un objet
     * \param[in] data Buffer contenant la donnée à écrire
     * \param[in] size Nombre d'octet que l'on veut écrire
     * \param[in] name Nom de l'objet à écrire
     * \~english \brief Write an object full
     * \param[in] data Buffer with data to write
     * \param[in] size Number of bytes we want to write
     * \param[in] name Object's name to write
     */
    virtual bool writeFull(uint8_t* data, int size, std::string name) = 0;

    /**
     * \~french \brief Prépare l'objet en écriture
     * \details Cela est utile dans le cas de l'écriture d'un fichier. On ne veut pas ouvrir et fermer le flux à chaque écriture partielle. Pour les autres type de contexte, rien ne sera fait dans cette fonction
     * \param[in] name Nom de l'objet dans lequel on va vouloir écrire
     * \~english \brief Write data in the named object
     * \details It is usefull to write a file. We don't want to open the stream for each partially writting. For other context type, nothing done in this function.
     * \param[in] name Object's name we want to write into
     */
    virtual bool openToWrite(std::string name) = 0;
    /**
     * \~french \brief Termine l'écriture d'un objet
     * \~english \brief Stop the writting
     */
    virtual bool closeToWrite() = 0;

    /**
     * \~french \brief Retourne le type du contexte
     * \~english \brief Return the context's type
     */
    virtual eContextType getType() = 0;
    /**
     * \~french \brief Retourne le type du contexte, sous forme de texte
     * \~english \brief Return the context's type, as string
     */
    virtual std::string getTypeStr() = 0;

    /**
     * \~french \brief Retourne le contenant dans le contexte
     * \~english \brief Return the tray in the context
     */
    virtual std::string getTray() = 0;

    /**
     * \~french \brief Sortie des informations sur le contexte
     * \~english \brief Context description output
     */
    virtual void print() = 0;

    /**
     * \~french \brief Retourne une chaîne de caracère décrivant le contexte
     * \~english \brief Return a string describing the context
     */
    virtual std::string toString() = 0;

    /**
     * \~french \brief Déconnecte le contexte
     * \~english \brief Disconnect the context
     */
    virtual void closeConnection() = 0;

    /**
     * \~french \brief Destructeur
     * \~english \brief Destructor
     */
    virtual ~Context() {}
};

#endif