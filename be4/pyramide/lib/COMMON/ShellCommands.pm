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
File: Commands.pm

Class: COMMON::ShellCommands

Configure and assemble commands used to generate pyramid's images.

All schemes in this page respect this legend :

(see formats.png)

Using:
    (start code)
    use COMMON::ShellCommands;

    # Commands object creation
    my $objCommands = COMMON::ShellCommands->new(
        $objPyramid, # BE4S3::Pyramid object
        TRUE, # useMasks
    );
    (end code)

Attributes:
    pyramid - <BE4S3::Pyramid> - Allowed to know output format specifications and configure commands.
    mntConfDir - string - Directory, where to write mergeNtiff configuration files.
    dntConfDir - string - Directory, where to write decimateNtiff configuration files.
    useMasks - boolean - If TRUE, all generating tools (mergeNtiff, merge4tiff...) use masks if present and generate a resulting mask. This processing is longer, that's why default behaviour is without mask.
=cut

################################################################################

package COMMON::ShellCommands;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use File::Basename;
use File::Path;
use Data::Dumper;

use COMMON::Harvesting;
use BE4S3::Level;
use COMMON::GraphNode;

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
#                                        Group: Constructors                                       #
####################################################################################################

=begin nd
Constructor: new

Commands constructor. Bless an instance.

Parameters (list):
    pyr - <BE4S3::Pyramid> - Image pyramid to generate
    useMasks - string - Do we want use masks to generate images ?
=cut
sub new {
    my $this = shift;
    my $pyr = shift;
    my $useMasks = shift;
    
    my $class= ref($this) || $this;
    # IMPORTANT : if modification, think to update natural documentation (just above)
    my $this = {
        pyramid => undef,
        mntConfDir => undef,
        dntConfDir => undef,
        useMasks => FALSE,
    };

    bless($this, $class);

    if (! defined $pyr || ref ($pyr) ne "COMMON::Pyramid") {
        ERROR("Can not load Pyramid !");
        return undef;
    }
    $this->{pyramid} = $pyr;

    if ( $this->{pyramid}->ownMasks() || (defined $useMasks && uc($useMasks) eq "TRUE") ) {
        $this->{useMasks} = TRUE;
    }

    return $this;
}

####################################################################################################
#                                        Group: MERGE N TIFF                                       #
####################################################################################################

# Constant: MERGENTIFF_W
use constant MERGENTIFF_W => 4;

my $MNTFUNCTION = <<'MNTFUNCTION';
MergeNtiff () {
    local config=$1
    
    mergeNtiff -f ${MNT_CONF_DIR}/$config -r ${TMP_DIR}/ __mNt__
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
    
    rm -f ${MNT_CONF_DIR}/$config
}
MNTFUNCTION

=begin nd
Function: mergeNtiff

Use the 'MergeNtiff' bash function. Write a configuration file, with sources.

(see mergeNtiff.png)

Parameters (list):
    node - <Node> - Node to generate thanks to a 'mergeNtiff' command.
    
Example:
|    MergeNtiff 19_397_3134.txt

Returns:
    An array (code, weight), ("",-1) if error.
=cut
sub mergeNtiff {
    my $this = shift;
    my $node = shift;
    
    my ($c, $w);
    my ($code, $weight) = ("",MERGENTIFF_W);
    
    if ($this->{useMasks}) {
        $node->addWorkMask();
    }
    
    my $mNtConfFilename = $node->getWorkBaseName.".txt";
    my $mNtConfFile = File::Spec->catfile($this->{mntConfDir}, $mNtConfFilename);
    
    if (! open CFGF, ">", $mNtConfFile ) {
        ERROR(sprintf "Impossible de creer le fichier $mNtConfFile.");
        return ("",-1);
    }
    
    # La premiere ligne correspond à la dalle résultat: La version de travail de la dalle à calculer.
    # Les points d'interrogation permettent de gérer le dossier où écrire les images grâce à une variable
    # Cet export va également ajouter les fonds (si présents) comme premières sources
    printf CFGF $node->exportForMntConf(TRUE, "?");

    #   - Les images sources (QTree)
    my $listGeoImg = $node->getGeoImages;
    foreach my $img (@{$listGeoImg}) {
        printf CFGF "%s", $img->exportForMntConf($this->{useMasks});
    }
    
    close CFGF;
    
    $code .= "MergeNtiff $mNtConfFilename";
    $code .= "\n";

    return ($code,$weight);
}

####################################################################################################
#                                        Group: WORK TO CACHE                                      #
####################################################################################################

# Constant: WORK2CACHE_W
use constant WORK2CACHE_W => 1;

my $W2CFUNCTION = <<'W2CFUNCTION';
StoreImage () {
    local level=$1
    local workDir=$2
    local workImgName=$3
    local imgName=$4
    local workMskName=$5
    local mskName=$6
    
    
    if [[ ! ${RM_IMGS[$workDir/$workImgName]} ]] ; then
             
        work2cache $workDir/$workImgName __w2cI__ -bucket ${PYR_BUCKET} $imgName
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        echo "$imgName" >> ${TMP_LIST_FILE}
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        if [ "$level" == "$TOP_LEVEL" ] ; then
            rm $workDir/$workImgName
        elif [ "$level" == "$CUT_LEVEL" ] ; then
            mv $workDir/$workImgName ${COMMON_TMP_DIR}/
        fi
        
        if [ $workMskName ] ; then
            
            if [ $mskName ] ; then
                    
                work2cache $workDir/$workMskName __w2cM__ -bucket ${PYR_BUCKET} $mskName
                if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
                echo "$mskName" >> ${TMP_LIST_FILE}
                
            fi
            
            if [ "$level" == "$TOP_LEVEL" ] ; then
                rm $workDir/$workMskName
            elif [ "$level" == "$CUT_LEVEL" ] ; then
                mv $workDir/$workMskName ${COMMON_TMP_DIR}/
            fi
        fi
    fi
}
StoreTiles () {
    local level=$1
    local workDir=$2
    local workImgName=$3
    local imgName=$4

    shift 4

    local imgI=$1
    local imgJ=$2
    local tilesW=$3
    local tilesH=$4

    shift 4

    local workMskName=$1
    local mskName=$2
    
    let imin=$imgI*$tilesW
    let imax=$imgI*$tilesW+$tilesW-1
    let jmin=$imgJ*$tilesH
    let jmax=$imgJ*$tilesH+$tilesH-1
    
    if [[ ! ${RM_IMGS[$workDir/$workImgName]} ]] ; then
             
        work2cache $workDir/$workImgName __w2cI__ -ij $imgI $imgJ -bucket ${PYR_BUCKET} $imgName
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
        
        for i in `seq $imin $imax` ; do 
            for j in `seq $jmin $jmax` ; do 
                echo "${imgName}_${i}_${j}" >> ${TMP_LIST_FILE}
                if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
            done
        done
        
        if [ "$level" == "$TOP_LEVEL" ] ; then
            rm $workDir/$workImgName
        elif [ "$level" == "$CUT_LEVEL" ] ; then
            mv $workDir/$workImgName ${COMMON_TMP_DIR}/
        fi
        
        if [ $workMskName ] ; then
            
            if [ $mskName ] ; then
                    
                work2cache $workDir/$workMskName __w2cM__ -ij $imgI $imgJ -bucket ${PYR_BUCKET} $mskName
                if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
                for i in `seq $imin $imax` ; do 
                    for j in `seq $jmin $jmax` ; do 
                        echo "${mskName}_${i}_${j}" >> ${TMP_LIST_FILE}
                        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
                    done
                done
                
            fi
            
            if [ "$level" == "$TOP_LEVEL" ] ; then
                rm $workDir/$workMskName
            elif [ "$level" == "$CUT_LEVEL" ] ; then
                mv $workDir/$workMskName ${COMMON_TMP_DIR}/
            fi
        fi
    fi
}
W2CFUNCTION


=begin nd
Function: work2cache

Copy image from work directory to cache and transform it (tiled and compressed) thanks to the 'Work2cache' bash function (work2cache).

(see work2cache.png)

Example:
|    Work2cache ${TMP_DIR}/19_395_3137.tif IMAGE/19/02/AF/Z5.tif

Parameter:
    node - <Node> - Node whose image have to be transfered in the cache.
    workDir - string - Work image directory, can be an environment variable.

Returns:
    An array (code, weight), ("",-1) if error.
=cut
sub work2cache {
    my $this = shift;
    my $node = shift;
    my $workDir = shift;
    
    my $cmd = "";
    my $weight = 0;
    
    #### Export de l'image

    if ($this->{pyramid}->storeTiles()) {

        my $pyrName = sprintf "%s_IMG_%s", $this->{pyramid}->getNewName(), $node->getLevel();
        
        $cmd .= sprintf "StoreTiles %s %s %s %s %s %s %s %s",
            $node->getLevel, $workDir, $node->getWorkImageName(TRUE), $pyrName,
            $node->getCol, $node->getRow, $this->{pyramid}->getTilesPerWidth, $this->{pyramid}->getTilesPerHeight;

        $weight += WORK2CACHE_W;
        
        #### Export du masque, si présent

        if ($node->getWorkMaskName()) {
            # On a un masque de travail : on le précise pour qu'il soit potentiellement déplacé dans le temporaire commun ou supprimé
            $cmd .= sprintf (" %s", $node->getWorkMaskName(TRUE));
            
            # En plus, on veut exporter les masques dans la pyramide, on en précise donc l'emplacement final
            if ( $this->{pyramid}->ownMasks() ) {
                $pyrName = sprintf "%s_MSK_%s", $this->{pyramid}->getNewName(), $node->getPyramidName();
                
                $cmd .= sprintf (" %s", $pyrName);
                $weight += WORK2CACHE_W;
            }        
        }
        
        $cmd .= "\n";
    } else {
    
        my $pyrName = sprintf "%s_IMG_%s", $this->{pyramid}->getNewName(), $node->getPyramidName();
        
        $cmd .= sprintf ("StoreImage %s %s %s %s", $node->getLevel, $workDir, $node->getWorkImageName(TRUE), $pyrName);
        $weight += WORK2CACHE_W;
        
        #### Export du masque, si présent

        if ($node->getWorkMaskName()) {
            # On a un masque de travail : on le précise pour qu'il soit potentiellement déplacé dans le temporaire commun ou supprimé
            $cmd .= sprintf (" %s", $node->getWorkMaskName(TRUE));
            
            # En plus, on veut exporter les masques dans la pyramide, on en précise donc l'emplacement final
            if ( $this->{pyramid}->ownMasks() ) {
                $pyrName = sprintf "%s_MSK_%s", $this->{pyramid}->getNewName(), $node->getPyramidName();
                
                $cmd .= sprintf (" %s", $pyrName);
                $weight += WORK2CACHE_W;
            }        
        }
        
        $cmd .= "\n";
    }

    return ($cmd,$weight);
}

####################################################################################################
#                                        Group: HARVEST IMAGE                                      #
####################################################################################################

# Constant: WGET_W
use constant WGET_W => 35;

my $HARVESTFUNCTION = <<'HARVESTFUNCTION';
Wms2work () {
    local dir=$1
    local harvest_ext=$2
    local final_ext=$3
    local nbTiles=$4
    local min_size=$5
    local url=$6
    shift 6

    local size=0

    mkdir $dir

    for i in `seq 1 $#`;
    do
        nameImg=`printf "$dir/img%.5d.$harvest_ext" $i`
        local count=0; local wait_delay=1
        while :
        do
            let count=count+1
            wget --no-verbose -O $nameImg "$url&BBOX=$1"

            if [ $? == 0 ] ; then
                if [ "$harvest_ext" == "png" ] ; then
                    if pngcheck $nameImg 1>/dev/null ; then break ; fi
                else
                    if tiffinfo $nameImg 1>/dev/null ; then break ; fi
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
    
    if [ "$size" -le "$min_size" ] ; then
        RM_IMGS["$dir.$final_ext"]="1"

        rm -rf $dir
        return
    fi

    if [ "$nbTiles" != "1 1" ] ; then
        composeNtiff -g $nbTiles -s $dir/ -c zip $dir.$final_ext
        if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
    else
        mv $dir/img00001.$harvest_ext $dir.$final_ext
    fi

    rm -rf $dir
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
    Wms2work "path/image_several_requests" "png" "tif" "4 4" "250000" "http://localhost/wms-vector?LAYERS=BDD_WLD_WM&SERVICE=WMS&VERSION=1.3.0&REQUEST=getMap&FORMAT=image/png&CRS=EPSG:3857&WIDTH=1024&HEIGHT=1024&STYLES=line&BGCOLOR=0x80BBDA&TRANSPARENT=0X80BBDA" $BBOXES
    (end code)

Parameters (list):
    node - <COMMON::GraphNode> - Node whose image have to be harvested.
    harvesting - <Harvesting> - To use to harvest image.

Returns:
    An array (code, weight), (undef,WGET_W) if error.
=cut
sub wms2work {
    my $this = shift;
    my $node = shift;
    my $harvesting = shift;

    my $pyramid = $node->getGraph->getPyramid;
    
    my @imgSize = $pyramid->getCacheImageSize($node->getLevel); # ie size tile image in pixel !
    my $tms     = $pyramid->getTileMatrixSet;
    
    my $nodeName = $node->getWorkImageName();
    
    my ($xMin, $yMin, $xMax, $yMax) = $node->getBBox();
    
    my ($cmd, $finalExtension) = $harvesting->getCommandWms2work({
        inversion => $tms->getInversion,
        dir => "\${TMP_DIR}/".$nodeName,
        srs => $tms->getSRS,
        bbox => [$xMin, $yMin, $xMax, $yMax],
        width => $imgSize[0],
        height => $imgSize[1]
    });
    
    if (! defined $cmd) {
        return (undef, WGET_W);
    }

    $node->setWorkExtension($finalExtension);
    
    return ($cmd, WGET_W);
}

####################################################################################################
#                                        Group: MERGE 4 TIFF                                       #
####################################################################################################

# Constant: MERGE4TIFF_W
use constant MERGE4TIFF_W => 1;

my $M4TFUNCTION << M4TFUNCTION
Merge4tiff () {
    local imgOut=$1
    local mskOut=$2
    shift 2
    local levelIn=$1
    local imgIn=( 0 $2 $4 $6 $8 )
    local mskIn=( 0 $3 $5 $7 $9 )
    shift 9

    local forRM=''

    # Entrées

    local tempDir="${TMP_DIR}"
    if [ "$levelIn" == "$CUT_LEVEL" ] ; then
        tempDir="${COMMON_TMP_DIR}"
    fi
    
    local inM4T=''
    
    local nbImgs=0
    for i in `seq 1 4`;
    do
        if [ ${imgIn[$i]} != '0' ] ; then
            if [[ -f ${tempDir}/${imgIn[$i]} ]] ; then
                forRM="$forRM ${tempDir}/${imgIn[$i]}"
                inM4T=`printf "$inM4T -i%.1d ${tempDir}/${imgIn[$i]}" $i`
                
                if [ ${mskIn[$i]} != '0' ] ; then
                    inM4T=`printf "$inM4T -m%.1d ${tempDir}/${mskIn[$i]}" $i`
                    forRM="$forRM ${tempDir}/${mskIn[$i]}"
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
        merge4tiff __m4t__ $inM4T $outM4T
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

(see merge4tiff.png)

Parameters (list):
    node - <COMMON::GraphNode> - Node to generate thanks to a 'merge4tiff' command.

Returns:
    An array (code, weight), ("",-1) if error.
=cut
sub merge4tiff {
    my $this = shift;
    my $node = shift;
    
    my ($c, $w);
    my ($code, $weight) = ("",MERGE4TIFF_W);
    
    my @childList = $node->getChildren;
    
    if ($this->{useMasks}) {
        $node->addWorkMask();
    }
    
    # We compose the 'Merge4tiff' call
    #   - the ouput + background
    $code .= sprintf "Merge4tiff %s", $node->exportForM4tConf(TRUE);
    
    #   - the children inputs
    my $inputsLevel = $this->{pyramid}->getTileMatrixSet()->getBelowLevelID($node->getLevel());
    
    $code .= sprintf " %s", $inputsLevel;
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

my $DNTFUNCTION << DNTFUNCTION
DecimateNtiff () {
    local config=$1
    
    decimateNtiff -f ${DNT_CONF_DIR}/$config __dNt__
    if [ $? != 0 ] ; then echo $0 : Erreur a la ligne $(( $LINENO - 1)) >&2 ; exit 1; fi
    
    rm -f ${DNT_CONF_DIR}/$config
}
DNTFUNCTION

=begin nd
Function: decimateNtiff

Use the 'decimateNtiff' bash function. Write a configuration file, with sources.

(see decimateNtiff.png)

Parameters (list):
    node - <Node> - Node to generate thanks to a 'decimateNtiff' command.
    
Example:
|    DecimateNtiff 12_26_17.txt

Returns:
    An array (code, weight), ("",-1) if error.
=cut
sub decimateNtiff {
    my $this = shift;
    my $node = shift;
    
    my ($c, $w);
    my ($code, $weight) = ("",DECIMATENTIFF_W);
    
    if ($this->{useMasks}) {
        $node->addWorkMask();
    }
    
    my $dNtConfFilename = $node->getWorkBaseName.".txt";
    my $dNtConfFile = File::Spec->catfile($this->{dntConfDir}, $dNtConfFilename);
    
    if (! open CFGF, ">", $dNtConfFile ) {
        ERROR(sprintf "Impossible de creer le fichier $dNtConfFile.");
        return ("",-1);
    }
    
    # La premiere ligne correspond à la dalle résultat: La version de travail de la dalle à calculer.
    # Cet export va également ajouter les fonds (si présents) comme premières sources
    printf CFGF $node->exportForDntConf(TRUE, $node->getScript()->getTempDir()."/");
    
    #   - Les noeuds sources (NNGraph)
    foreach my $nodesource ( @{$node->getNodeSources()} ) {
        printf CFGF "%s", $nodesource->exportForDntConf(FALSE, $nodesource->getScript()->getTempDir()."/");
    }
    
    close CFGF;
    
    $code .= "DecimateNtiff $dNtConfFilename";
    $code .= "\n";

    return ($code,$weight);
}

################################################################################

BEGIN {}
INIT {}
END {}



####################################################################################################
#                               Group: Commands methods                                            #
####################################################################################################









=begin nd
Function: configureFunctions

Configure bash functions to write in scripts' header thanks to pyramid's components.
=cut
sub configureFunctions {
    my $this = shift;

    my $pyr = $this->{pyramid};
    my $configuredFunc = $BASHFUNCTIONS;

    ######## mergeNtiff ########
    # work compression : deflate
    my $conf_mNt = "-c zip ";

    my $ip = $pyr->getInterpolation;
    $conf_mNt .= "-i $ip ";
    my $spp = $pyr->getSamplesPerPixel;
    $conf_mNt .= "-s $spp ";
    my $bps = $pyr->getBitsPerSample;
    $conf_mNt .= "-b $bps ";
    my $ph = $pyr->getPhotometric;
    $conf_mNt .= "-p $ph ";
    my $sf = $pyr->getSampleFormat;
    $conf_mNt .= "-a $sf ";

    my $nd = $this->getNodata->getValue;
    $conf_mNt .= "-n $nd ";

    $configuredFunc =~ s/__mNt__/$conf_mNt/;
    
    ######## decimateNtiff ########
    # work compression : deflate
    my $conf_dNt = "-c zip ";

    $conf_dNt .= "-n $nd ";

    $configuredFunc =~ s/__dNt__/$conf_dNt/;
    
    ######## merge4tiff ########
    # work compression : deflate
    my $conf_m4t = "-c zip ";

    my $gamma = $pyr->getGamma;
    $conf_m4t .= "-g $gamma ";
    $conf_m4t .= "-n $nd ";

    $configuredFunc =~ s/__m4t__/$conf_m4t/;
    
    ######## work2cache ########
    my $conf_t2t = "";

    # pour les images
    my $compression = $pyr->getCompression;
    
    $conf_t2t .= "-c $compression ";
    if ($pyr->getCompressionOption eq 'crop') {
        $conf_t2t .= "-crop ";
    }


    $conf_t2t .= sprintf "-t %s %s ", $pyr->getTileMatrixSet->getTileWidth,$pyr->getTileMatrixSet->getTileHeight;

    $configuredFunc =~ s/__w2cI__/$conf_t2t/g;
    
    # pour les masques
    $conf_t2t = sprintf "-c zip -t %s %s", $pyr->getTileMatrixSet->getTileWidth, $pyr->getTileMatrixSet->getTileHeight;
    $configuredFunc =~ s/__w2cM__/$conf_t2t/g;
    
    return $configuredFunc;
}

####################################################################################################
#                                Group: Getters - Setters                                          #
####################################################################################################

# Function: getNodata
sub getNodata {
    my $this = shift;
    return $this->{pyramid}->getNodata();
}

# Function: getPyramid
sub getPyramid {
    my $this = shift;
    return $this->{pyramid};
}

=begin nd
Function: setConfDir

Store the directory for mergeNtiff and decimateNtiff configuration files.

Parameters (list):
    mntConfDir - string - mergeNtiff configurations' directory
    dntConfDir - string - decimateNtiff configurations' directory
=cut
sub setConfDir {
    my $this = shift;
    my $mntConfDir = shift;
    my $dntConfDir = shift;

    $this->{mntConfDir} = $mntConfDir;
    $this->{dntConfDir} = $dntConfDir;
}

####################################################################################################
#                                Group: Export methods                                             #
####################################################################################################

=begin nd
Function: exportForDebug

Returns all commands' informations. Useful for debug.

Example:
    (start code)
    (end code)
=cut
sub exportForDebug {
    my $this = shift ;

    my $export = "";

    $export .= "\nObject COMMON::ShellCommands :\n";
    $export .= "\t Use masks\n" if $this->{useMasks};
    $export .= "\t Doesn't use masks\n" if (! $this->{useMasks});
    $export .= "\t Export masks\n" if $this->{pyramid}->ownMasks();
    $export .= "\t Doesn't export masks\n" if (! $this->{pyramid}->ownMasks());

    return $export;
}
  
1;
__END__
