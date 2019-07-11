# Copyright © (2011) Institut national de l'information
#                    géographique et forestière 
# 
# Géoportail SAV <geop_services@geoportail.fr>
# 
# This software is a computer program whose purpose is to publish geographic
# data using OGC WMS and WMTS protocol.
# 
# This software is governed by the CeCILL-C license under French law and
# abiding by the rules of distribution of free software.  You can  use, 
# modify and/ or redistribute the software under the terms of the CeCILL-C
# license as circulated by CEA, CNRS and INRIA at the following URL
# "http://www.cecill.info". 
# 
# As a counterpart to the access to the source code and  rights to copy,
# modify and redistribute granted by the license, users are provided only
# with a limited warranty  and the software's author,  the holder of the
# economic rights,  and the successive licensors  have only  limited
# liability. 
# 
# In this respect, the user's attention is drawn to the risks associated
# with loading,  using,  modifying and/or developing or reproducing the
# software by the user in light of its specific status of free software,
# that may mean  that it is complicated to manipulate,  and  that  also
# therefore means  that it is reserved for developers  and  experienced
# professionals having in-depth computer knowledge. Users are therefore
# encouraged to load and test the software's suitability as regards their
# requirements in conditions enabling the security of their systems and/or 
# data to be ensured and,  more generally, to use and operate it in the 
# same conditions as regards security. 
# 
# The fact that you are presently reading this means that you have had
# 
# knowledge of the CeCILL-C license and that you accept its terms.

################################################################################

=begin nd
File: Shell.pm

Class: BE4::Shell

(see ROK4GENERATION/libperlauto/BE4_Shell.png)

Configure and assemble commands used to generate raster pyramid's slabs.

All schemes in this page respect this legend :

(see ROK4GENERATION/tools/formats.png)

Using:
    (start code)
    (end code)
=cut

################################################################################

package BE4::Shell;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use File::Basename;
use File::Path;
use Data::Dumper;

use COMMON::Harvesting;
use COMMON::Node;
use COMMON::ProxyStorage;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{$EXPORT_TAGS{'all'}} );
our @EXPORT      = qw();

################################################################################

use constant TRUE  => 1;
use constant FALSE => 0;

####################################################################################################
#                                     Group: GLOBAL VARIABLES                                      #
####################################################################################################

my $COMMONTEMPDIR;
my $MNTCONFDIR;
my $DNTCONFDIR;
my $USEMASK;

sub setGlobals {
    $COMMONTEMPDIR = shift;
    $USEMASK = shift;

    if (defined $USEMASK && uc($USEMASK) eq "TRUE") {
        $USEMASK = TRUE;
    } else {
        $USEMASK = FALSE;
    }

    $COMMONTEMPDIR = File::Spec->catdir($COMMONTEMPDIR,"COMMON");
    $MNTCONFDIR = File::Spec->catfile($COMMONTEMPDIR,"mergeNtiff");
    $DNTCONFDIR = File::Spec->catfile($COMMONTEMPDIR,"decimateNtiff");
    
    # Common directory
    if (! -d $COMMONTEMPDIR) {
        DEBUG (sprintf "Create the common temporary directory '%s' !", $COMMONTEMPDIR);
        eval { mkpath([$COMMONTEMPDIR]); };
        if ($@) {
            ERROR(sprintf "Can not create the common temporary directory '%s' : %s !", $COMMONTEMPDIR, $@);
            return FALSE;
        }
    }
    
    # MergeNtiff configurations directory
    if (! -d $MNTCONFDIR) {
        DEBUG (sprintf "Create the MergeNtiff configurations directory '%s' !", $MNTCONFDIR);
        eval { mkpath([$MNTCONFDIR]); };
        if ($@) {
            ERROR(sprintf "Can not create the MergeNtiff configurations directory '%s' : %s !", $MNTCONFDIR, $@);
            return FALSE;
        }
    }
    
    # DecimateNtiff configurations directory
    if (! -d $DNTCONFDIR) {
        DEBUG (sprintf "Create the DecimateNtiff configurations directory '%s' !", $DNTCONFDIR);
        eval { mkpath([$DNTCONFDIR]); };
        if ($@) {
            ERROR(sprintf "Can not create the DecimateNtiff configurations directory '%s' : %s !", $DNTCONFDIR, $@);
            return FALSE;
        }
    }

    return TRUE;
}

####################################################################################################
#                                        Group: MERGE N TIFF                                       #
####################################################################################################

# Constant: MERGENTIFF_W
use constant MERGENTIFF_W => 4;

my $MNTFUNCTION = <<'MNTFUNCTION';
MergeNtiff () {
    local config=$1
    local bgI=$2
    local bgM=$3

    
    mergeNtiff -f ${MNT_CONF_DIR}/$config -r ${TMP_DIR}/ ${MERGENTIFF_OPTIONS}
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
    
    rm -f ${MNT_CONF_DIR}/$config

    if [ $bgI ] ; then
        rm -f ${TMP_DIR}/$bgI
    fi
    
    if [ $bgM ] ; then
        rm -f ${TMP_DIR}/$bgM
    fi
}
MNTFUNCTION

=begin nd
Function: mergeNtiff

Use the 'MergeNtiff' bash function. Write a configuration file, with sources.

(see ROK4GENERATION/tools/mergeNtiff.png)

Parameters (list):
    node - <Node> - Node to generate thanks to a 'mergeNtiff' command.
    
Example:
|    MergeNtiff 19_397_3134.txt

Returns:
    An array (code, weight), (undef,undef) if error.
=cut
sub mergeNtiff {
    my $node = shift;
    
    my ($c, $w);
    my ($code, $weight) = ("",MERGENTIFF_W);

    # Si elle existe, on copie la dalle de la pyramide de base dans le repertoire de travail 
    # en la convertissant du format cache au format de travail: c'est notre image de fond.
    # Si la dalle de la pyramide de base existe, on a créé un lien, donc il existe un fichier
    # correspondant dans la nouvelle pyramide.
    # On fait de même avec le masque de donnée associé, s'il existe.
    my $imgBg = $node->getSlabPath("IMAGE", TRUE);
    if ($node->getGraph()->getPyramid()->ownAncestor() && COMMON::ProxyStorage::isPresent($node->getStorageType(), $imgBg) ) {
        $node->addBgImage();
        
        my $maskBg = $node->getSlabPath("MASK", TRUE);
        
        if ( $USEMASK && defined $maskBg && COMMON::ProxyStorage::isPresent($node->getStorageType(), $maskBg) ) {
            # On a en plus un masque associé à l'image de fond
            $node->addBgMask();
        }
        
        ($c,$w) = cache2work($node);
        $code .= $c;
        $weight += $w;
    }

    if ($USEMASK) {
        $node->addWorkMask();
    }
    
    my $mNtConfFilename = $node->getWorkBaseName.".txt";
    my $mNtConfFile = File::Spec->catfile($MNTCONFDIR, $mNtConfFilename);
    
    if (! open CFGF, ">", $mNtConfFile ) {
        ERROR(sprintf "Impossible de creer le fichier $mNtConfFile");
        return (undef,undef);
    }
    
    # La premiere ligne correspond à la dalle résultat: La version de travail de la dalle à calculer.
    # Les points d'interrogation permettent de gérer le dossier où écrire les images grâce à une variable
    # Cet export va également ajouter les fonds (si présents) comme premières sources
    printf CFGF $node->exportForMntConf(TRUE, "?");

    my $listGeoImg = $node->getGeoImages;
    foreach my $img (@{$listGeoImg}) {
        printf CFGF "%s", $img->exportForMntConf($USEMASK);
    }
    
    close CFGF;
    
    $code .= "MergeNtiff $mNtConfFilename";
    $code .= sprintf " %s", $node->getBgImageName(TRUE) if (defined $node->getBgImageName()); # pour supprimer l'image de fond si elle existe
    $code .= sprintf " %s", $node->getBgMaskName(TRUE) if (defined $node->getBgMaskName()); # pour supprimer le masque de fond si il existe
    $code .= "\n";

    return ($code,$weight);
}

####################################################################################################
#                                        Group: CACHE TO WORK                                      #
####################################################################################################

# Constant: CACHE2WORK_W
use constant CACHE2WORK_W => 1;

my $FILE_C2WFUNCTION = <<'C2WFUNCTION';
PullSlab () {
    local input=$1
    local output=$2

    cache2work -c zip ${PYR_DIR}/$input ${TMP_DIR}/$output
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
}
C2WFUNCTION

my $S3_C2WFUNCTION = <<'C2WFUNCTION';
PullSlab () {
    local input=$1
    local output=$2

    cache2work -c zip -bucket ${PYR_BUCKET} $input ${TMP_DIR}/$output
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
}
C2WFUNCTION

my $SWIFT_C2WFUNCTION = <<'C2WFUNCTION';
PullSlab () {
    local input=$1
    local output=$2

    cache2work -c zip -container ${PYR_CONTAINER} ${KEYSTONE_OPTION} $input ${TMP_DIR}/$output
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
}
C2WFUNCTION

my $CEPH_C2WFUNCTION = <<'C2WFUNCTION';
PullSlab () {
    local input=$1
    local output=$2

    cache2work -c zip -pool ${PYR_POOL} $input ${TMP_DIR}/$output
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
}
C2WFUNCTION

=begin nd
Function: cache2work

Copy slab from cache to work directory and transform (work format : untiled, zip-compression). Use the 'PullSlab' bash function.

(see ROK4GENERATION/tools/cache2work.png)
    
Examples:
    (start code)
    (end code)
    
Parameters (list):
    node - <Node> - Node whose image have to be transfered in the work directory.

Returns:
    An array (code, weight), (undef,undef) if error.
=cut
sub cache2work {
    my $node = shift;
    
    #### Rappatriement de l'image de donnée ####    
    my $code = "";
    my $weight = 0;
    
    $code = sprintf "PullSlab %s %s\n",
        $node->getSlabPath("IMAGE", FALSE),
        $node->getBgImageName(TRUE);

    $weight = CACHE2WORK_W;
    
    #### Rappatriement du masque de donnée (si présent) ####
    
    if ( defined $node->getBgMaskName() ) {
        # Un masque est associé à l'image que l'on va utiliser, on doit le mettre également au format de travail
        $code .= sprintf "PullSlab %s %s\n", 
            $node->getSlabPath("MASK", FALSE),
            $node->getBgMaskName(TRUE);

        $weight += CACHE2WORK_W;
    }
    
    return ($code,$weight);
}

####################################################################################################
#                                        Group: WORK TO CACHE                                      #
####################################################################################################

# Constant: WORK2CACHE_W
use constant WORK2CACHE_W => 1;

my $S3_W2CFUNCTION = <<'W2CFUNCTION';
BackupListFile () {
    echo "List file back up to do"
}

PushSlab () {
    local level=$1
    local workImgName=$2
    local imgName=$3
    local workMskName=$4
    local mskName=$5
    
    if [[ ! ${RM_IMGS[${TMP_DIR}/$workImgName]} ]] ; then
             
        work2cache ${TMP_DIR}/$workImgName ${WORK2CACHE_IMAGE_OPTIONS} -bucket ${PYR_BUCKET} $imgName
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        echo "0/$imgName" >> ${TMP_LIST_FILE}
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        if [ "$level" == "${TOP_LEVEL}" ] ; then
            rm ${TMP_DIR}/$workImgName
        elif [ "$level" == "${CUT_LEVEL}" ] ; then
            mv ${TMP_DIR}/$workImgName ${COMMON_TMP_DIR}/
        fi
        
        if [ $workMskName ] ; then
            
            if [ $mskName ] ; then
                    
                work2cache ${TMP_DIR}/$workMskName ${WORK2CACHE_MASK_OPTIONS} -bucket ${PYR_BUCKET} $mskName
                if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
                echo "0/$mskName" >> ${TMP_LIST_FILE}
                
            fi
            
            if [ "$level" == "${TOP_LEVEL}" ] ; then
                rm ${TMP_DIR}/$workMskName
            elif [ "$level" == "${CUT_LEVEL}" ] ; then
                mv ${TMP_DIR}/$workMskName ${COMMON_TMP_DIR}/
            fi
        fi
    fi
}
W2CFUNCTION

my $SWIFT_W2CFUNCTION = <<'W2CFUNCTION';
BackupListFile () {
    echo "List file back up to do"
}

PushSlab () {
    local level=$1
    local workImgName=$2
    local imgName=$3
    local workMskName=$4
    local mskName=$5
    
    if [[ ! ${RM_IMGS[${TMP_DIR}/$workImgName]} ]] ; then
             
        work2cache ${TMP_DIR}/$workImgName ${WORK2CACHE_IMAGE_OPTIONS} -container ${PYR_CONTAINER} ${KEYSTONE_OPTION} $imgName
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        echo "0/$imgName" >> ${TMP_LIST_FILE}
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        if [ "$level" == "${TOP_LEVEL}" ] ; then
            rm ${TMP_DIR}/$workImgName
        elif [ "$level" == "${CUT_LEVEL}" ] ; then
            mv ${TMP_DIR}/$workImgName ${COMMON_TMP_DIR}/
        fi
        
        if [ $workMskName ] ; then
            
            if [ $mskName ] ; then
                    
                work2cache ${TMP_DIR}/$workMskName ${WORK2CACHE_MASK_OPTIONS} -container ${PYR_CONTAINER} ${KEYSTONE_OPTION} $mskName
                if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
                echo "0/$mskName" >> ${TMP_LIST_FILE}
                
            fi
            
            if [ "$level" == "${TOP_LEVEL}" ] ; then
                rm ${TMP_DIR}/$workMskName
            elif [ "$level" == "${CUT_LEVEL}" ] ; then
                mv ${TMP_DIR}/$workMskName ${COMMON_TMP_DIR}/
            fi
        fi
    fi
}
W2CFUNCTION


my $CEPH_W2CFUNCTION = <<'W2CFUNCTION';
BackupListFile () {
    local objectName=`basename ${LIST_FILE}`
    rados -p ${PYR_POOL} put ${objectName} ${LIST_FILE}
}

PushSlab () {
    local level=$1
    local workImgName=$2
    local imgName=$3
    local workMskName=$4
    local mskName=$5
    
    
    if [[ ! ${RM_IMGS[${TMP_DIR}/$workImgName]} ]] ; then
             
        work2cache ${TMP_DIR}/$workImgName ${WORK2CACHE_IMAGE_OPTIONS} -pool ${PYR_POOL} $imgName
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        echo "0/$imgName" >> ${TMP_LIST_FILE}
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        if [ "$level" == "${TOP_LEVEL}" ] ; then
            rm ${TMP_DIR}/$workImgName
        elif [ "$level" == "${CUT_LEVEL}" ] ; then
            mv ${TMP_DIR}/$workImgName ${COMMON_TMP_DIR}/
        fi
        
        if [ $workMskName ] ; then
            
            if [ $mskName ] ; then
                    
                work2cache ${TMP_DIR}/$workMskName ${WORK2CACHE_MASK_OPTIONS} -pool ${PYR_POOL} $mskName
                if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
                echo "0/$mskName" >> ${TMP_LIST_FILE}
                
            fi
            
            if [ "$level" == "${TOP_LEVEL}" ] ; then
                rm ${TMP_DIR}/$workMskName
            elif [ "$level" == "${CUT_LEVEL}" ] ; then
                mv ${TMP_DIR}/$workMskName ${COMMON_TMP_DIR}/
            fi
        fi
    fi
}
W2CFUNCTION


my $FILE_W2CFUNCTION = <<'W2CFUNCTION';
BackupListFile () {
    cp ${LIST_FILE} ${PYR_DIR}/
}

PushSlab () {
    local level=$1
    local workImgName=$2
    local imgName=$3
    local workMskName=$4
    local mskName=$5
        
    if [[ ! ${RM_IMGS[${TMP_DIR}/$workImgName]} ]] ; then
        
        local dir=`dirname ${PYR_DIR}/$imgName`
        
        if [ -r ${TMP_DIR}/$workImgName ] ; then rm -f ${PYR_DIR}/$imgName ; fi
        if [ ! -d $dir ] ; then mkdir -p $dir ; fi
            
        work2cache ${TMP_DIR}/$workImgName ${WORK2CACHE_IMAGE_OPTIONS} ${PYR_DIR}/$imgName
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        echo "0/$imgName" >> ${TMP_LIST_FILE}
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        if [ "$level" == "${TOP_LEVEL}" ] ; then
            rm ${TMP_DIR}/$workImgName
        elif [ "$level" == "${CUT_LEVEL}" ] ; then
            mv ${TMP_DIR}/$workImgName ${COMMON_TMP_DIR}/
        fi
        
        if [ $workMskName ] ; then
            
            if [ $mskName ] ; then
                
                dir=`dirname ${PYR_DIR}/$mskName`
                
                if [ -r ${TMP_DIR}/$workMskName ] ; then rm -f ${PYR_DIR}/$mskName ; fi
                if [ ! -d $dir ] ; then mkdir -p $dir ; fi
                    
                work2cache ${TMP_DIR}/$workMskName ${WORK2CACHE_MASK_OPTIONS} ${PYR_DIR}/$mskName
                if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
                echo "0/$mskName" >> ${TMP_LIST_FILE}
                
            fi
            
            if [ "$level" == "${TOP_LEVEL}" ] ; then
                rm ${TMP_DIR}/$workMskName
            elif [ "$level" == "${CUT_LEVEL}" ] ; then
                mv ${TMP_DIR}/$workMskName ${COMMON_TMP_DIR}/
            fi
        fi
    fi
}
W2CFUNCTION

=begin nd
Function: work2cache

Copy image from work directory to cache and transform it (tiled and compressed) thanks to the 'Work2cache' bash function (work2cache).

(see ROK4GENERATION/tools/work2cache.png)

Example:
|    PushSlab 19_395_3137.tif IMAGE/19/02/AF/Z5.tif

Parameter:
    node - <Node> - Node whose image have to be transfered in the cache.

Returns:
    An array (code, weight), (undef,undef) if error.
=cut
sub work2cache {
    my $node = shift;
    
    my $code = "";
    my $weight = 0;
    
    #### Export de l'image

    # Le stockage peut être objet ou fichier
    my $pyrName = $node->getSlabPath("IMAGE", FALSE);
    
    $code .= sprintf ("PushSlab %s %s %s", $node->getLevel, $node->getWorkImageName(TRUE), $pyrName);
    $weight += WORK2CACHE_W;
    
    #### Export du masque, si présent

    if ($node->getWorkMaskName()) {
        # On a un masque de travail : on le précise pour qu'il soit potentiellement déplacé dans le temporaire commun ou supprimé
        $code .= sprintf (" %s", $node->getWorkMaskName(TRUE));
        
        # En plus, on veut exporter les masques dans la pyramide, on en précise donc l'emplacement final
        if ( $node->getGraph()->getPyramid()->ownMasks() ) {
            $pyrName = $node->getSlabPath("MASK", FALSE);
            
            $code .= sprintf (" %s", $pyrName);
            $weight += WORK2CACHE_W;
        }        
    }
    
    $code .= "\n";

    return ($code,$weight);
}

####################################################################################################
#                                        Group: HARVEST IMAGE                                      #
####################################################################################################

# Constant: WGET_W
use constant WGET_W => 35;

my $HARVESTFUNCTION = <<'HARVESTFUNCTION';
Wms2work () {
    local workName=$1
    local harvestExtension=$2
    local finalExtension=$3
    local minSize=$4
    local url=$5
    local grid=$6
    shift 6

    local size=0

    mkdir ${TMP_DIR}/harvesting/

    for i in `seq 1 $#`;
    do
        nameImg=`printf "${TMP_DIR}/harvesting/img%.5d.$harvestExtension" $i`
        local count=0; local wait_delay=1
        while :
        do
            let count=count+1
            wget --no-verbose -O $nameImg "$url&BBOX=$1"

            if [ $? == 0 ] ; then
                checkWork $nameImg 2>/dev/null
                if [ $? == 0 ] ; then
                    break
                fi
            fi
            
            echo "Failure $count : wait for $wait_delay s"
            sleep $wait_delay
            let wait_delay=wait_delay*2
            if [ 3600 -lt $wait_delay ] ; then 
                let wait_delay=3600
            fi
        done
        let size=`stat -c "%s" $nameImg`+$size

        shift
    done
    
    if [ "$size" -le "$minSize" ] ; then
        RM_IMGS["${TMP_DIR}/${workName}.${finalExtension}"]="1"
        rm -rf ${TMP_DIR}/harvesting/
        return
    fi

    if [ "$grid" != "1 1" ] ; then
        composeNtiff -g $grid -s ${TMP_DIR}/harvesting/ -c zip ${TMP_DIR}/${workName}.${finalExtension}
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
    else
        mv ${TMP_DIR}/harvesting/img00001.${harvestExtension} ${TMP_DIR}/${workName}.${finalExtension}
    fi

    rm -rf ${TMP_DIR}/harvesting/
}
HARVESTFUNCTION

=begin nd
Function: wms2work

Fetch image corresponding to the node thanks to 'wget', in one or more steps at a time. WMS service is described in the current graph's datasource. Use the 'Wms2work' bash function.

Example:
    (start code)
    BBOXES="10018754.17139461632,-626172.13571215872,10644926.30710678016,0.00000000512
    10644926.30710678016,-626172.13571215872,11271098.442818944,0.00000000512
    11271098.442818944,-626172.13571215872,11897270.57853110784,0.00000000512
    11897270.57853110784,-626172.13571215872,12523442.71424327168,0.00000000512
    10018754.17139461632,-1252344.27142432256,10644926.30710678016,-626172.13571215872
    10644926.30710678016,-1252344.27142432256,11271098.442818944,-626172.13571215872
    11271098.442818944,-1252344.27142432256,11897270.57853110784,-626172.13571215872
    11897270.57853110784,-1252344.27142432256,12523442.71424327168,-626172.13571215872
    10018754.17139461632,-1878516.4071364864,10644926.30710678016,-1252344.27142432256
    10644926.30710678016,-1878516.4071364864,11271098.442818944,-1252344.27142432256
    11271098.442818944,-1878516.4071364864,11897270.57853110784,-1252344.27142432256
    11897270.57853110784,-1878516.4071364864,12523442.71424327168,-1252344.27142432256
    10018754.17139461632,-2504688.54284865024,10644926.30710678016,-1878516.4071364864
    10644926.30710678016,-2504688.54284865024,11271098.442818944,-1878516.4071364864
    11271098.442818944,-2504688.54284865024,11897270.57853110784,-1878516.4071364864
    11897270.57853110784,-2504688.54284865024,12523442.71424327168,-1878516.4071364864"
    #
    Wms2work "15_1254_9865_I" "png" "tif" "250000" "http://localhost/wms-vector?LAYERS=BDD_WLD_WM&SERVICE=WMS&VERSION=1.3.0&REQUEST=getMap&FORMAT=image/png&CRS=EPSG:3857&WIDTH=1024&HEIGHT=1024&STYLES=line&BGCOLOR=0x80BBDA&TRANSPARENT=0X80BBDA" $BBOXES
    (end code)

Parameters (list):
    node - <COMMON::GraphNode> - Node whose image have to be harvested.
    harvesting - <COMMON::Harvesting> - To use to harvest image.

Returns:
    An array (code, weight), (undef,undef) if error.
=cut
sub wms2work {
    my $node = shift;
    my $harvesting = shift;

    my ($width, $height) = $node->getSlabSize(); # ie size tile image in pixel !
    my $tms = $node->getGraph()->getPyramid()->getTileMatrixSet();    
    my ($xMin, $yMin, $xMax, $yMax) = $node->getBBox();

    # Calcul de la liste des bbox à moissonner
    my ($grid, @bboxes) = $harvesting->getBboxesList(
        $xMin, $yMin, $xMax, $yMax, 
        $width, $height,
        $tms->getInversion()
    );

    if (scalar @bboxes == 0) {
        ERROR("Impossible de calculer la liste des bboxes à moissonner");
        return (undef, undef);
    }

    my $code = sprintf "BBOXES=\"%s\"\n", join("\n", @bboxes);

    
    # Écriture de la commande

    my $finalExtension = $harvesting->getHarvestExtension();
    if (scalar @bboxes > 1) {
        $finalExtension = "tif";
    }
    $node->setWorkExtension($finalExtension);

    $code .= sprintf "Wms2work \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \$BBOXES\n",
        $node->getWorkImageName(FALSE),
        $harvesting->getHarvestExtension(), $finalExtension,
        $harvesting->getMinSize(), $harvesting->getHarvestUrl($tms->getSRS(), $width, $height), $grid;
    
    return ($code, WGET_W);
}

####################################################################################################
#                                        Group: MERGE 4 TIFF                                       #
####################################################################################################

# Constant: MERGE4TIFF_W
use constant MERGE4TIFF_W => 1;

my $M4TFUNCTION = <<'M4TFUNCTION';
Merge4tiff () {
    local imgOut=$1
    local mskOut=$2
    shift 2
    local imgBg=$1
    local mskBg=$2
    shift 2
    local levelIn=$1
    local imgIn=( 0 $2 $4 $6 $8 )
    local mskIn=( 0 $3 $5 $7 $9 )
    shift 9

    local directoryIn=''

    if [ "$levelIn" == "${CUT_LEVEL}" ] ; then
        directoryIn=${COMMON_TMP_DIR}
    else
        directoryIn=${TMP_DIR}
    fi   

    local forRM=''

    # Entrées   
    local inM4T=''

    if [ $imgBg != '0'  ] ; then
        forRM="$forRM ${TMP_DIR}/$imgBg"
        inM4T="$inM4T -ib ${TMP_DIR}/$imgBg"
        if [ $mskBg != '0'  ] ; then
            forRM="$forRM ${TMP_DIR}/$mskBg"
            inM4T="$inM4T -mb ${TMP_DIR}/$mskBg"
        fi
    fi
    
    local nbImgs=0
    for i in `seq 1 4`;
    do
        if [ ${imgIn[$i]} != '0' ] ; then
            if [[ -f ${directoryIn}/${imgIn[$i]} ]] ; then
                forRM="$forRM ${directoryIn}/${imgIn[$i]}"
                inM4T=`printf "$inM4T -i%.1d ${directoryIn}/${imgIn[$i]}" $i`
                
                if [ ${mskIn[$i]} != '0' ] ; then
                    inM4T=`printf "$inM4T -m%.1d ${directoryIn}/${mskIn[$i]}" $i`
                    forRM="$forRM ${directoryIn}/${mskIn[$i]}"
                fi
                
                let nbImgs=$nbImgs+1
            fi
        fi
    done
    
    # Sorties
    local outM4T=''
    
    if [ ${mskOut} != '0' ] ; then
        outM4T="-mo ${TMP_DIR}/${mskOut}"
    fi
    
    outM4T="$outM4T -io ${TMP_DIR}/${imgOut}"
    
    # Appel à la commande merge4tiff
    if [ "$nbImgs" -gt 0 ] ; then
        merge4tiff ${MERGE4TIFF_OPTIONS} $inM4T $outM4T
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
    else
        RM_IMGS[${TMP_DIR}/${imgOut}]="1"
    fi
    
    # Suppressions
    rm $forRM
}
M4TFUNCTION

=begin nd
Function: merge4tiff

Use the 'Merge4tiff' bash function.

|     i1  i2
|              =  resultImg
|     i3  i4

(see ROK4GENERATION/tools/merge4tiff.png)

Parameters (list):
    node - <COMMON::GraphNode> - Node to generate thanks to a 'merge4tiff' command.

Returns:
    An array (code, weight), (undef,undef) if error.
=cut
sub merge4tiff {
    my $node = shift;
    
    my ($c, $w);
    my ($code, $weight) = ("",MERGE4TIFF_W);
    
    my @childList = $node->getChildren();

    # Si elle existe, on copie la dalle de la pyramide de base dans le repertoire de travail 
    # en la convertissant du format cache au format de travail: c'est notre image de fond.
    # Si la dalle de la pyramide de base existe, on a créé un lien, donc il existe un fichier
    # correspondant dans la nouvelle pyramide.
    # On fait de même avec le masque de donnée associé, s'il existe.

    my $imgBg = $node->getSlabPath("IMAGE", TRUE);
    if ($node->getGraph()->getPyramid()->ownAncestor() && ($USEMASK || scalar @childList != 4) && COMMON::ProxyStorage::isPresent($node->getStorageType(), $imgBg) ) {
        $node->addBgImage();
        
        my $maskBg = $node->getSlabPath("MASK", TRUE);
        
        if ( $USEMASK && defined $maskBg && COMMON::ProxyStorage::isPresent($node->getStorageType(), $maskBg) ) {
            # On a en plus un masque associé à l'image de fond
            $node->addBgMask();
        }
        
        ($c,$w) = cache2work($node);
        $code .= $c;
        $weight += $w;
    }
    
    if ($USEMASK) {
        $node->addWorkMask();
    }
    
    # We compose the 'Merge4tiff' call
    #   - the ouput + background
    $code .= sprintf "Merge4tiff %s", $node->exportForM4tConf(TRUE);
    
    #   - the children inputs
    my $inputsLevel = $node->getGraph()->getPyramid()->getTileMatrixSet()->getBelowLevelID($node->getLevel());
    $code .= " $inputsLevel";

    foreach my $childNode ($node->getPossibleChildren()) {
            
        if (defined $childNode) {
            $code .= $childNode->exportForM4tConf(FALSE);
        } else {
            $code .= " 0 0";
        }
    }
    
    $code .= "\n";

    return ($code,$weight);
}

####################################################################################################
#                                        Group: DECIMATE N TIFF                                    #
####################################################################################################

use constant DECIMATENTIFF_W => 3;

my $DNTFUNCTION = <<'DNTFUNCTION';
DecimateNtiff () {
    local config=$1
    local bgI=$2
    local bgM=$3
    
    decimateNtiff -f ${DNT_CONF_DIR}/$config ${DECIMATENTIFF_OPTIONS}
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
    
    rm -f ${DNT_CONF_DIR}/$config
    
    if [ $bgI ] ; then
        rm -f ${TMP_DIR}/$bgI
    fi
    
    if [ $bgM ] ; then
        rm -f ${TMP_DIR}/$bgM
    fi
}
DNTFUNCTION

=begin nd
Function: decimateNtiff

Use the 'decimateNtiff' bash function. Write a configuration file, with sources.

(see ROK4GENERATION/toolsdecimateNtiff.png)

Parameters (list):
    node - <Node> - Node to generate thanks to a 'decimateNtiff' command.
    
Example:
|    DecimateNtiff 12_26_17.txt

Returns:
    An array (code, weight), (undef,undef) if error.
=cut
sub decimateNtiff {
    my $node = shift;
    
    my ($c, $w);
    my ($code, $weight) = ("",DECIMATENTIFF_W);

    # Si elle existe, on copie la dalle de la pyramide de base dans le repertoire de travail 
    # en la convertissant du format cache au format de travail: c'est notre image de fond.
    # Si la dalle de la pyramide de base existe, on a créé un lien, donc il existe un fichier
    # correspondant dans la nouvelle pyramide.
    # On fait de même avec le masque de donnée associé, s'il existe.
    my $imgBg = $node->getSlabPath("IMAGE", TRUE);
    if ($node->getGraph()->getPyramid()->ownAncestor() && COMMON::ProxyStorage::isPresent($node->getStorageType(), $imgBg) ) {
        $node->addBgImage();
        
        my $maskBg = $node->getSlabPath("MASK", TRUE);
        
        if ( $USEMASK && defined $maskBg && COMMON::ProxyStorage::isPresent($node->getStorageType(), $maskBg) ) {
            # On a en plus un masque associé à l'image de fond
            $node->addBgMask();
        }
        
        ($c,$w) = cache2work($node);
        $code .= $c;
        $weight += $w;
    }
    
    if ($USEMASK) {
        $node->addWorkMask();
    }
    
    my $dntConf = $node->getWorkBaseName().".txt";
    my $dntConfFile = File::Spec->catfile($DNTCONFDIR, $dntConf);
    
    if (! open CFGF, ">", $dntConfFile ) {
        ERROR(sprintf "Impossible de creer le fichier $dntConfFile.");
        return (undef,undef);
    }
    
    # La premiere ligne correspond à la dalle résultat: La version de travail de la dalle à calculer.
    # Cet export va également ajouter les fonds (si présents) comme premières sources
    printf CFGF $node->exportForDntConf(TRUE, $node->getScript()->getTempDir()."/");
    
    #   - Les noeuds sources (NNGraph)
    foreach my $sourceNode ( @{$node->getSourceNodes()} ) {
        printf CFGF "%s", $sourceNode->exportForDntConf(FALSE, $sourceNode->getScript()->getTempDir()."/");
    }
    
    close CFGF;
    
    $code .= "DecimateNtiff $dntConf";
    $code .= sprintf " %s", $node->getBgImageName(TRUE) if (defined $node->getBgImageName()); # pour supprimer l'image de fond si elle existe
    $code .= sprintf " %s", $node->getBgMaskName(TRUE) if (defined $node->getBgMaskName()); # pour supprimer le masque de fond si il existe
    $code .= "\n";

    return ($code,$weight);
}

####################################################################################################
#                                   Group: Export function                                         #
####################################################################################################

=begin nd
Function: getScriptInitialization

Parameters (list):
    pyramid - <COMMON::PyramidVector> - Pyramid to generate
    temp - string - Temporary directory

Returns:
    Global variables and functions to print into script
=cut
sub getScriptInitialization {
    my $pyramid = shift;

    # Variables

    my $string = sprintf "MERGENTIFF_OPTIONS=\"-c zip -i %s -s %s -b %s -a %s -n %s\"\n",
        $pyramid->getImageSpec()->getInterpolation(),
        $pyramid->getImageSpec()->getPixel()->getSamplesPerPixel(),
        $pyramid->getImageSpec()->getPixel()->getBitsPerSample(),
        $pyramid->getImageSpec()->getPixel()->getSampleFormat(),
        $pyramid->getNodata()->getValue();
    $string .= "MNT_CONF_DIR=$MNTCONFDIR\n";

    $string .= sprintf "WORK2CACHE_MASK_OPTIONS=\"-c zip -t %s %s\"\n", $pyramid->getTileMatrixSet()->getTileWidth(), $pyramid->getTileMatrixSet()->getTileHeight();

    $string .= sprintf "WORK2CACHE_IMAGE_OPTIONS=\"-c %s -t %s %s -s %s -b %s -a %s",
        $pyramid->getImageSpec()->getCompression(),
        $pyramid->getTileMatrixSet()->getTileWidth(), $pyramid->getTileMatrixSet()->getTileHeight(),
        $pyramid->getImageSpec()->getPixel()->getSamplesPerPixel(),
        $pyramid->getImageSpec()->getPixel()->getBitsPerSample(),
        $pyramid->getImageSpec()->getPixel()->getSampleFormat();

    if ($pyramid->getImageSpec()->getCompressionOption() eq 'crop') {
        $string .= " -crop\"\n";
    } else {
        $string .= "\"\n";
    }

    if ($pyramid->getTileMatrixSet()->isQTree()) {
        $string .= sprintf "MERGE4TIFF_OPTIONS=\"-c zip -g %s -n %s -s %s -b %s -a %s\"\n",
            $pyramid->getImageSpec()->getGamma(),
            $pyramid->getNodata()->getValue(),
            $pyramid->getImageSpec()->getPixel()->getSamplesPerPixel(),
            $pyramid->getImageSpec()->getPixel()->getBitsPerSample(),
            $pyramid->getImageSpec()->getPixel()->getSampleFormat();
    } else {
        $string .= sprintf "DECIMATENTIFF_OPTIONS=\"-c zip -n %s\"\n", $pyramid->getNodata()->getValue();
        $string .= "DNT_CONF_DIR=$DNTCONFDIR\n";
    }

    if ($pyramid->getStorageType() eq "FILE") {
        $string .= sprintf "PYR_DIR=%s\n", $pyramid->getDataDir();
    }
    elsif ($pyramid->getStorageType() eq "CEPH") {
        $string .= sprintf "PYR_POOL=%s\n", $pyramid->getDataPool();
    }
    elsif ($pyramid->getStorageType() eq "S3") {
        $string .= sprintf "PYR_BUCKET=%s\n", $pyramid->getDataBucket();
    }
    elsif ($pyramid->getStorageType() eq "SWIFT") {
        $string .= sprintf "PYR_CONTAINER=%s\n", $pyramid->getDataContainer();
        if ($pyramid->keystoneConnection()) {
            $string .= "KEYSTONE_OPTION=\"-ks\"\n";
        } else {
            $string .= "KEYSTONE_OPTION=\"\"\n";
        }
    }

    $string .= sprintf "LIST_FILE=\"%s\"\n", $pyramid->getListFile();
    $string .= "COMMON_TMP_DIR=\"$COMMONTEMPDIR\"\n";

    # Fonctions

    $string .= "\n# Pour mémoriser les dalles supprimées\n";
    $string .= "declare -A RM_IMGS\n";
    if ($pyramid->getStorageType() eq "FILE") {
        $string .= $FILE_C2WFUNCTION;
        $string .= $FILE_W2CFUNCTION;
    }
    elsif ($pyramid->getStorageType() eq "CEPH") {
        $string .= $CEPH_C2WFUNCTION;
        $string .= $CEPH_W2CFUNCTION;
    }
    elsif ($pyramid->getStorageType() eq "S3") {
        $string .= $S3_C2WFUNCTION;
        $string .= $S3_W2CFUNCTION;
    }
    elsif ($pyramid->getStorageType() eq "SWIFT") {
        $string .= $SWIFT_C2WFUNCTION;
        $string .= $SWIFT_W2CFUNCTION;
    }

    $string .= $MNTFUNCTION;
    $string .= $HARVESTFUNCTION;

    if ($pyramid->getTileMatrixSet()->isQTree()) {
        $string .= $M4TFUNCTION;
    } else {
        $string .= $DNTFUNCTION;
    }

    $string .= "\n";

    return $string;
}

  
1;
__END__