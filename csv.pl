#!/usr/bin/env perl

use warnings;
use strict;
use 5.012;

use IO::All;
use JSON;
use Text::CSV_XS;

my $json < io shift;

my $csv = Text::CSV_XS->new( { binary => 1 } );
$csv->eol( "\n" );

my $entries = decode_json( $json );

open my $obj, '>', 'objects.csv';
open my $cat, '>', 'categories.csv';

$csv->print( $cat, [ qw/name category/ ] );
$csv->print( $obj, [ qw/name type text url title/ ] );

for my $entry ( @$entries ) {
  my $name = $entry->{ name };
  my $categories = $entry->{ categories };
  for my $category ( @$categories ) {
    $csv->print( $cat, [ $name, lc( $category ) ] );
  }
  for my $type ( qw/hardware software who dream/ ) {
    my $objects = $entry->{ $type . "_entities" };
    for my $object ( @$objects ) {
      $csv->print( $obj, [ $name, $type, map { lc( $object->{ $_ } ) } qw/text url title/ ] );
    }
  }
}
