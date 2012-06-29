#!/usr/bin/env perl

use warnings;
use strict;
use 5.012;

use JSON;
use IO::All;

my $json < io shift;
my $entries = decode_json( $json );

my $mapping = {
    artist => 'artist', blogger => 'web', actor => 'artist', entrepreneur => 'manager', manager => 'manager', film => 'artist', fashion => 'artist', journalist => 'writer', hacker => 'dev', crafter => 'artist', chef => 'artist', game => 'dev', musician => 'artist', photographer => 'artist', podcaster => 'web', modder => 'dev', politics => 'manager', poet => 'writer', producer => 'manager', professor => 'scientist', reporter => 'writer', researcher => 'scientist', scientist => 'scientist', security => 'dev', designer => 'artist', developer => 'dev', editor => 'manager', sysadmin => 'dev', systems => 'dev', teacher => 'scientist', technologist => 'web', usability => 'web', web => 'web', writer => 'writer'
};

my $objects = {};

for my $entry ( @$entries ) {
  my $name = $entry->{ name };
  my $raw_categories = $entry->{ categories };
  my $categories = [];
  for my $cat (@$raw_categories) {
    my $trans = $mapping->{$cat};
    push @$categories, $trans if $trans;
  }
  for my $type ( qw/hardware software who dream/ ) {
    my $objs = $entry->{ $type . "_entities" };
    for my $object ( @$objs ) {
      my $url = $object->{url};
      $objects->{ $url }->{ names }->{ $object->{text} }++;
      $objects->{ $url }->{ types }->{ $type }++;
      $objects->{ $url }->{ categories }->{ $_ }++ foreach @$categories;
      for my $o (@$objs) {
        my $u = $o->{url};
        if ( $u ne $url ) {
          $objects->{ $url }->{edges}->{$u}++;
        }
      }
    }
  }
}

use YAML;

my $deleted = {};

foreach my $url ( keys %$objects ) {
  my $occ = 0;
  $occ += $_ foreach values %{ $objects->{$url}->{names} };
  $deleted->{ $url } = 1 if $occ < 2;
}

my @nodes;
my %edges;

foreach my $url ( keys %$objects ) {
  next if $deleted->{$url};
  my $obj = $objects->{$url};
  my ( $name ) = sort { $obj->{names}->{ $b } <=> $obj->{names}->{ $a } } keys %{ $obj->{names} };
  my ( $category ) = sort { $obj->{categories}->{ $b } <=> $obj->{categories}->{ $a } } keys %{ $obj->{categories} };
  my ( $type ) = sort { $obj->{types}->{ $b } <=> $obj->{types}->{ $a } } keys %{ $obj->{types} };
  my @links = grep { !$deleted->{ $_ } } keys %{ $obj->{edges} };
  my $weighted_links = {};
  $weighted_links->{ $_ } = $obj->{edges}->{ $_ } foreach @links;
  push @nodes, { name => $name, id => $url, category => $category, type => $type };
  map { $edges{ join( " - ", sort ($url, $_) ) } += $weighted_links->{ $_ } } keys %$weighted_links;
}

say 'nodedef> name,label VARCHAR(256),category VARCHAR(32),type VARCHAR(32)';

map { say "'" . join( "','", $_->{id}, $_->{name}, $_->{category}, $_->{type} ) . "'" } @nodes;

say 'edgedef> node1,node2,weight INT';

for my $ids ( keys %edges ) {
    my ($id1, $id2) = split / - /, $ids;
    my $w = $edges{ $ids };
    say join( ",", "'" . $id1 . "'" , "'" . $id2 . "'", $w );
}
