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

package BE4::Level;

use strict;
use warnings;

use Log::Log4perl qw(:easy);

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{$EXPORT_TAGS{'all'}} );
our @EXPORT      = qw();

################################################################################
# version
my $VERSION = "0.0.1";

################################################################################
# constantes
use constant TRUE  => 1;
use constant FALSE => 0;

################################################################################
# Preloaded methods go here.
BEGIN {}
INIT {}
END {}


################################################################################
# sample: 
# 
#        <tileMatrix>0</tileMatrix>
#        <baseDir>MNT_MAYOTTE_REDUCT/IMAGE/0</baseDir>
#        <tilesPerWidth>16</tilesPerWidth>
#        <tilesPerHeight>16</tilesPerHeight>
#        <pathDepth>2</pathDepth>
#        <nodata>
#            <filePath>MNT_MAYOTTE_REDUCT/NODATA/0/nd.tif</filePath>
#        </nodata>
#        <TMSLimits>
#            <minTileRow>1</minTileRow>
#            <maxTileRow>1000000</maxTileRow>
#            <minTileCol>1</minTileCol>
#            <maxTileCol>1000000</maxTileCol>
#        </TMSLimits>
# 
################################################################################

#
# Group: variable
#

#
# variable: $self
#
#    *		id                => undef,
#    *		dir_image         => undef,
#    *		compress_image    => undef, # ie "TIFF_RAW_INT8"
#    *		dir_nodata        => undef,
#    *		dir_metadata      => undef,  # NOT IMPLEMENTED !
#    *		compress_metadata => undef,  # NOT IMPLEMENTED !
#    *		type_metadata     => undef,  # NOT IMPLEMENTED !
#    *		bitspersample     => 0,     # ie 8
#    *		samplesperpixel   => 0,     # ie 3
#    *		size              => [],    # number w/h !
#    *		dir_depth         => 0,     # ie 2
#    *		limit             => []     # dim bbox Row/Col !!!
#

#
# Group: constructor
#

################################################################################
# constructor
sub new {
  my $this = shift;

  my $class= ref($this) || $this;
  my $self = {
	id                => undef,
	dir_image         => undef,
	compress_image    => undef, # ie "TIFF_RAW_INT8"
	dir_nodata        => undef,
	dir_metadata      => undef,  # NOT IMPLEMENTED !
	compress_metadata => undef,  # NOT IMPLEMENTED !
	type_metadata     => undef,  # NOT IMPLEMENTED !
	bitspersample     => 0,     # ie 8
	samplesperpixel   => 0,     # ie 3
	size              => [],    # number w/h !
	dir_depth         => 0,     # ie 2
	limit             => []     # dim bbox Row/Col !!!
  };

  bless($self, $class);
  
  TRACE;
  
  # init. class
  if (! $self->_init(@_)) {
    ERROR ("One parameter is missing !");
    return undef;
  }
  
  return $self;
}

################################################################################
# privates init.
sub _init {
    my $self   = shift;
    my $params = shift;

    TRACE;
    
    return FALSE if (! defined $params);
    
    # init. params
    
    # parameters mandatoy !
    if (! exists($params->{id})) {
      ERROR ("key/value required to 'id' !");
      return FALSE;
    }
    if (! exists($params->{dir_image})) {
      ERROR ("key/value required to 'dir_image' !");
      return FALSE;
    }
    if (! exists($params->{compress_image})) {
      ERROR ("key/value required to 'compress_image' !");
      return FALSE;
    }
    if (! exists($params->{dir_nodata})) {
      ERROR ("key/value required to 'dir_nodata' !");
      return FALSE;
    }
    if (! exists($params->{bitspersample})) {
      ERROR ("key/value required to 'bitspersample' !");
      return FALSE;
    }
    if (! exists($params->{samplesperpixel})) {
      ERROR ("key/value required to 'samplesperpixel' !");
      return FALSE;
    }
    if (! exists($params->{size})) {
      ERROR ("key/value required to 'size' !");
      return FALSE;
    }
    if (! exists($params->{dir_depth})) {
      ERROR ("key/value required to 'dir_depth' !");
      return FALSE;
    }
    if (! exists($params->{limit})) {
      ERROR ("key/value required to 'limit' !");
      return FALSE;
    }

    # check type ref
    if (! $params->{bitspersample}){
      ERROR("value not informed to 'bitspersample' !");
      return FALSE;
    }
    if (! $params->{samplesperpixel}){
      ERROR("value not informed to 'samplesperpixel' !");
      return FALSE;
    }
    if (! scalar ($params->{size})){
      ERROR("list empty to 'size' !");
      return FALSE;
    }
    if (! $params->{dir_depth}){
      ERROR("value not informed to 'dir_depth' !");
      return FALSE;
    }
    if (! scalar (@{$params->{limit}})){
      ERROR("list empty to 'limit' !");
      return FALSE;
    }
    
    # parameters optional !
    # TODO : metadata 
    
    $self->{id}             = $params->{id};
    $self->{dir_image}      = $params->{dir_image};
    $self->{compress_image} = $params->{compress_image};
    $self->{dir_nodata}     = $params->{dir_nodata};
    $self->{bitspersample}  = $params->{bitspersample};
    $self->{samplesperpixel}= $params->{samplesperpixel};
    $self->{size}           = $params->{size};
    $self->{dir_depth}      = $params->{dir_depth};
    $self->{limit}          = $params->{limit};
    
    return TRUE;
}

################################################################################
# get
sub getID {
  my $self = shift;
  return $self->{id};
}
1;
__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

  BE4::Level -

=head1 SYNOPSIS

  use BE4::Level;
  
  my $params = {
            id                => 1024,
            dir_image         => "./t/data/pyramid/SCAN_RAW_TEST/1024/",
            compress_image    => "TIFF_RAW_INT8",
            dir_nodata        => undef,
            dir_metadata      => undef,
            compress_metadata => undef,
            type_metadata     => undef,
            bitspersample     => 8,
            samplesperpixel   => 3,
            size              => [ 4, 4],
            dir_depth         => 2,
            limit             => [1, 1000000, 1, 1000000] 
    };
    
  my $objLevel = BE4::Level->new($params);

=head1 DESCRIPTION

=head2 EXPORT

None by default.

=head1 SAMPLE

* Sample Pyramid file (.pyr) :

  [MNT_MAYOTTE_REDUCT.pyr]
  
<?xml version="1.0" encoding="US-ASCII"?>
<Pyramid>
    <tileMatrixSet>RGM04UTM38S_10cm</tileMatrixSet>
    <format>TIFF_LZW_FLOAT32</format>
    <channels>1</channels>
    <level>
        <tileMatrix>0</tileMatrix>
        <baseDir>MNT_MAYOTTE_REDUCT/IMAGE/0</baseDir>
        <tilesPerWidth>16</tilesPerWidth>
        <tilesPerHeight>16</tilesPerHeight>
        <pathDepth>2</pathDepth>
        <nodata>
            <filePath>MNT_MAYOTTE_REDUCT/NODATA/0/nd.tif</filePath>
        </nodata>
        <TMSLimits>
            <minTileRow>1</minTileRow>
            <maxTileRow>1000000</maxTileRow>
            <minTileCol>1</minTileCol>
            <maxTileCol>1000000</maxTileCol>
        </TMSLimits>
    </level>
    <level>
        <tileMatrix>1</tileMatrix>
        <baseDir>MNT_MAYOTTE_REDUCT/IMAGE/1</baseDir>
        <tilesPerWidth>16</tilesPerWidth>
        <tilesPerHeight>16</tilesPerHeight>
        <pathDepth>2</pathDepth>
        <nodata>
            <filePath>MNT_MAYOTTE_REDUCT/NODATA/1/nd.tif</filePath>
        </nodata>
        <TMSLimits>
            <minTileRow>1</minTileRow>
            <maxTileRow>1000000</maxTileRow>
            <minTileCol>1</minTileCol>
            <maxTileCol>1000000</maxTileCol>
        </TMSLimits>
    </level>
</Pyramid>

=head1 LIMITATIONS AND BUGS

 No test on the type value !
 Metadata not implemented !

=head1 SEE ALSO

=head1 AUTHORS

Bazonnais Jean Philippe, E<lt>jpbazonnais@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bazonnais Jean Philippe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
