#!/usr/bin/env perl

use warnings;
use strict;
use 5.012;

use URI;
use Web::Scraper;
use WWW::Mechanize;
use YAML;
use JSON;

my $mech = WWW::Mechanize->new();

my $links_scraper = scraper {
  process 'h2.person>a', 'urls[]' => '@href';
};

my $link_format = { 'url' => '@href', 'title' => '@title', 'text' => 'TEXT' };

my $who_id = "who-are-you-and-what-do-you-do";
my $hardware_id = "what-hardware-do-you-use";
my $software_id = "and-what-software";
my $dream_id = "what-would-be-your-dream-setup";

my $scraper = scraper {
  process "h2.person", name => 'TEXT';
  process "p.summary", summary => 'TEXT';
  process 'a[rel="category"]', 'categories[]' => 'TEXT';

  #  process '//h3[@id="who-are-you-and-what-do-you-do"]/following::p[following::h3[@id="what-hardware-do-you-use"]] | //h3[@id="who-are-you-and-what-do-you-do"]/following::li[following::h3[@id="what-hardware-do-you-use"]]', 'who_text[]' => 'TEXT';
  process between($who_id, $hardware_id, "p", "li"), 'who_text[]' => 'TEXT';
  #  process '//h3[@id="who-are-you-and-what-do-you-do"]/following::a[following::h3[@id="what-hardware-do-you-use"]]', 'who_entities[]' => $link_format;
  process between($who_id, $hardware_id, "a"), 'who_entities[]' => $link_format;

  process between($hardware_id, $software_id, "p", "li"), 'hardware_text[]' => 'TEXT';
  process between($hardware_id, $software_id, "a"), 'hardware_entities[]' => $link_format;

  process between($software_id, $dream_id, "p", "li"), 'software_text[]' => 'TEXT';
  process between($software_id, $dream_id, "a"), 'software_entities[]' => $link_format;

  #  HACK because HTML::TreeBuilder deletes <article> and <section> tags
  process '//h3[@id="what-would-be-your-dream-setup"]/following::p[not(contains(.,"snafu"))]', 'dream_text[]' => 'TEXT';
  process '//h3[@id="what-would-be-your-dream-setup"]/following::a[not(contains(.,"waferbaby") or contains(.,"Alike"))]', 'dream_entities[]' => $link_format;
};

my @interviews;

for my $year (2009..2012) {

  warn "====> processing year $year\n";
  my $start = 'http://usesthis.com/interviews/in/' . $year;
  $mech->get( $start );
  my $links = $links_scraper->scrape( $mech->content );

  for my $link ( @{ $links->{ urls } } ) {
    warn "working on $link\n";
    $mech->get( $link );
    my $html = $mech->content;
    my $res = $scraper->scrape( $html );
    my $target = {};
    for my $k ( keys %$res ) {
      if ( $k =~ /text$/ ) {
        $target->{ $k } = join "\n\n", @{ $res->{ $k } };
      }  elsif ( $k eq 'name' ) {
        $target->{ $k } = substr( $res->{ $k }, 1, length($res->{ $k }) - 2);
      } else {
        $target->{ $k } = $res->{ $k };
      }
    }
    push @interviews, $target;
    sleep 2;
  }
}

print encode_json( \@interviews );

sub between {
  my ($start, $end, @tags) = @_;
  my @parts = map {sprintf '//h3[@id="%s"]/following::%s[following::h3[@id="%s"]]', $start, $_, $end} @tags;
  join " | ", @parts;
}
