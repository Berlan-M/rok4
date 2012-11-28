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

package BE4::Node;

use strict;
use warnings;

use Log::Log4perl qw(:easy);

use File::Spec ;
use Data::Dumper ;
use BE4::Base36 ;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{$EXPORT_TAGS{'all'}} );
our @EXPORT      = qw();

################################################################################
# Constantes
use constant TRUE  => 1;
use constant FALSE => 0;

################################################################################

BEGIN {}
INIT {}
END {}

################################################################################
=begin nd
Group: variable

variable: $self
    * i : integer - column
    * j : integer - row
    * pyramidName : string - relative path of this node in the pyramid (generated from i,j). Example : level16/00/12/L5.tif
    * tm : BE4::TileMatrix - to which node belong
    * graph : BE4::Graph or BE4::QTree - which contain the node
    * w - own node's weight  
    * W - accumulated weight (childs' weights sum)
    * code - commands to execute to generate this node (to write in a script)
    * script : BE4::Script - in which the node is calculated
    * nodeSources : array of BE4::Node - from which this node is calculated
    * geoImages : array of BE4::GeoImage - from which this node is calculated
=cut

####################################################################################################
#                                       CONSTRUCTOR METHODS                                        #
####################################################################################################

# Group: constructor

sub new {
    my $this = shift;
    
    my $class= ref($this) || $this;
    # IMPORTANT : if modification, think to update natural documentation (just above) and pod documentation (bottom)
    my $self = {
        i => undef,
        j => undef,
        pyramidName => undef,
        tm => undef,
        graph => undef,
        w => 0,
        W => 0,
        code => '',
        script => undef,
        nodeSources => [],
        geoImages => [],
    };
    
    bless($self, $class);
    
    TRACE;
    
    # init. class
    return undef if (! $self->_init(@_));
    
    return $self;
}

#
=begin nd
method: _init

Load node's parameters

Parameters:
    params - a hash of parameters
=cut
sub _init {
    my $self = shift;
    my $params = shift ; # Hash
    
    TRACE;
    
    # mandatory parameters !
    if (! defined $params->{i}) {
        ERROR("Node Coord i is undef !");
        return FALSE;
    }
    if (! defined $params->{j}) {
        ERROR("Node Coord j is undef !");
        return FALSE;
    }
    if (! defined $params->{tm}) {
        ERROR("Node tmid is undef !");
        return FALSE;
    }
    if (! defined $params->{graph}) {
        ERROR("Tree Node is undef !");
        return FALSE;
    }
    
    # init. params    
    $self->{i} = $params->{i};
    $self->{j} = $params->{j};
    $self->{tm} = $params->{tm};
    $self->{graph} = $params->{graph};
    $self->{w} = 0;
    $self->{W} = 0;
    $self->{code} = '';
    
    my $base36path = BE4::Base36->indicesToB36Path($params->{i},$params->{j},
                                                   $self->getGraph->getPyramid->getDirDepth()+1);
    
    $self->{pyramidName} = File::Spec->catfile($self->getLevel, $base36path.".tif");;
    
    return TRUE;
}

####################################################################################################
#                                       GEOGRAPHIC TOOLS                                           #
####################################################################################################

# Group: geographic tools

=begin nd
method: isPointInNodeBbox

Return a boolean indicating if the point in parameter is inside the bbox of the node
  
Parameters:
    x - the x coordinate of the point you want to know if it is in
    x - the y coordinate of the point you want to know if it is in
=cut
sub isPointInNodeBbox {
    my $self = shift;
    my $x = shift;
    my $y = shift;
    
    my ($xMinNode,$yMinNode,$xMaxNode,$yMaxNode) = $self->getBBox();
    
    if ( $xMinNode <= $x && $x <= $xMaxNode && $yMinNode <= $y && $y <= $yMaxNode ) {
        return TRUE;
    } else {
        return FALSE;
    }
}

=begin nd
method: isBboxIntersectingNodeBbox

Test if the Bbox  in parameter intersect the bbox of the node
      
Parameters:
    Bbox - (xmin,ymin,xmax,ymax) : coordinates of the bbox
=cut
sub isBboxIntersectingNodeBbox {
    my $self = shift;
    my ($xMin,$yMin,$xMax,$yMax) = @_;
    my ($xMinNode,$yMinNode,$xMaxNode,$yMaxNode) = $self->getBBox();
    
    if ($xMax > $xMinNode && $xMin < $xMaxNode && $yMax > $yMinNode && $yMin < $yMaxNode) {
        return TRUE;
    } else {
        return FALSE;
    }
    
}

####################################################################################################
#                                       GETTERS / SETTERS                                          #
####################################################################################################

# Group: getters - setters

sub getScript {
    my $self = shift;
    return $self->{script}
}

sub writeInScript {
    my $self = shift;
    $self->{script}->print($self->{code});
}

sub setScript {
    my $self = shift;
    my $script = shift;
    
    if (! defined $script || ref ($script) ne "BE4::Script") {
        ERROR("We expect to a BE4::Script object.");
    }
    
    $self->{script} = $script; 
}

sub getCol {
    my $self = shift;
    return $self->{i};
}

sub getRow {
    my $self = shift;
    return $self->{j};
}

sub getPyramidName {
    my $self = shift;
    return $self->{pyramidName};
}

sub getWorkBaseName {
    my $self = shift;
    my $suffix = shift;
    
    # si un prefixe est préciser
    return (sprintf "%s_%s_%s_%s", $self->getLevel, $self->{i}, $self->{j}, $suffix) if (defined $suffix);
    # si pas de prefixe
    return (sprintf "%s_%s_%s", $self->getLevel, $self->{i}, $self->{j});
}

sub getWorkName {
    my $self = shift;
    my $suffix = shift;
    
    # si un prefixe est préciser
    return (sprintf "%s_%s_%s_%s.tif", $self->getLevel, $self->{i}, $self->{j}, $suffix) if (defined $suffix);
    # si pas de prefixe
    return (sprintf "%s_%s_%s.tif", $self->getLevel, $self->{i}, $self->{j});
}

sub getLevel {
    my $self = shift;
    return $self->{tm}->getID;
}

sub getTM {
    my $self = shift;
    return $self->{tm};
}

sub getGraph {
    my $self = shift;
    return $self->{graph};
}

sub getNodeSources {
    my $self = shift;
    return $self->{nodeSources};
}

sub getGeoImages {
    my $self = shift;
    return $self->{geoImages};
}

sub addNodeSources {
    my $self = shift;
    my @nodes = shift;
    
    push(@{$self->getNodeSources()},@nodes);
    
    return TRUE;
}

sub addGeoImages {
    my $self = shift;
    my @images = shift;
    
    push(@{$self->getGeoImages()},@images);
    
    return TRUE;
}

sub setCode {
    my $self = shift;
    my $code = shift;
    $self->{code} = $code;
}

sub getBBox {
    my $self = shift;
    
    my @Bbox = $self->{tm}->indicesToBBox(
        $self->{i},
        $self->{j},
        $self->{graph}->getPyramid->getTilesPerWidth,
        $self->{graph}->getPyramid->getTilesPerHeight
    );
    
    return @Bbox;
}

sub getCode {
    my $self = shift;
    return $self->{code};
}

sub getOwnWeight {
    my $self = shift;
    return $self->{w};
}

sub getAccumulatedWeight {
    my $self = shift;
    return $self->{W};
}

sub setOwnWeight {
    my $self = shift;
    my $weight = shift;
    $self->{w} = $weight;
}

sub getScriptID {
    my $self = shift;
    return $self->{script}->getID;
}

#
=begin nd
method: setAccumulatedWeight

AccumulatedWeight = children's weights sum + own weight = provided weight + already store own weight.
=cut
sub setAccumulatedWeight {
    my $self = shift;
    my $childrenWeight = shift;
    $self->{W} = $childrenWeight + $self->getOwnWeight;
}

#
=begin nd
method: getPossibleChildren

Parameters:
    node - BE4::Node whose we want to know children.

Returns:
    An array of the real children from a node (length is always 4, with undefined value for children which don't exist), an empty array if the node is a leaf.
=cut
sub getPossibleChildren {
    my $self = shift;
    return $self->{graph}->getPossibleChildren($self);
}

#
=begin nd
method: getChildren

Parameters:
    node - BE4::Node whose we want to know children.

Returns:
    An array of the real children from a node (max length = 4), an empty array if the node is a leaf.
=cut
sub getChildren {
    my $self = shift;
    return $self->{graph}->getChildren($self);
}

####################################################################################################
#                                          EXPORT METHODS                                          #
####################################################################################################

# Group: export methods

=begin nd
method: exportForMntConf

Export attributs of the Node for mergNtiff configuration file.

=cut
sub exportForMntConf {
    my $self = shift;
    my $imagePath = shift;
    my $maskPath = shift;
    
    TRACE;
    
    my @Bbox = $self->getBBox;
    
    my $output = sprintf "IMG %s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $imagePath,
        $Bbox[0], $Bbox[3], $Bbox[2], $Bbox[1],
        $self->getTM()->getResolution(), $self->getTM()->getResolution();
    
    if (defined $maskPath) {
        $output .= sprintf "MSK %s\n", $maskPath;
    }
    
    return $output;
}

#
=begin nd
method: exportForDebug

Export in a string the content of the node object
=cut
sub exportForDebug {
    my $self = shift ;
    
    my $output = "";
    
    $output .= sprintf "Object BE4::Node :\n";
    $output .= sprintf "\tLevel : %s\n",$self->getLevel();
    $output .= sprintf "\tTM Resolution : %s\n",$self->getTM()->getResolution();
    $output .= sprintf "\tColonne : %s\n",$self->getCol();
    $output .= sprintf "\tLigne : %s\n",$self->getRow();
    if (defined $self->getScript()) {
        $output .= sprintf "\tScript ID : %\n",$self->getScriptID();
    } else {
        $output .= sprintf "\tScript undefined.\n";
    }
    $output .= sprintf "\t Noeud Source :\n";
    foreach my $node_sup ( @{$self->getNodeSources()} ) {
        $output .= sprintf "\t\tResolution : %s, Colonne ; %s, Ligne : %s\n",$node_sup->getTM()->getResolution(),$node_sup->getCol(),$node_sup->getRow();
    }
    $output .= sprintf "\t Geoimage Source :\n";
    
    foreach my $img ( @{$self->getGeoImages()} ) {
        $output .= sprintf "\t\tNom : %s\n",$img->getName();
    }
    
    return $output;
}

1;
__END__