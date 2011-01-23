#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Config::Pit;
use Carp ();
use LWP::UserAgent;
use URI::QueryParam;
use XML::RSS;
use Scalar::Util qw(reftype);
use List::MoreUtils qw(any);
use utf8;

# Config
my $DELICIOUS_API_ENDPINT = "http://delicious.com/rss/dann";
my $ENTRY_TAG         = "tokindle";

# Main
my $INSTANT_PAPER_API_ENDPOINT = "https://www.instapaper.com/api/add";
my $CONFIG;

main();
exit;

# Logic
sub main {
    init();
    my $entries = fetch_entriies_from_hatebu();
    post_entries_to_instantpaper($entries);
}

sub init {
    $CONFIG = pit_get(
        "delicious2instant",
        require => {
            "instant_username" => "your username for instantpaper",
            "instant_password" => "your password for instantpaper",
        }
    );
    die 'pit_get failed.' if !%$CONFIG;
}

sub fetch_entriies_from_hatebu {
    say("--> Fetching entries from delicious");
    my $ua                  = LWP::UserAgent->new;
    $ua->agent('Mozilla/8.0');
    my $delicious_api_endpoint = URI->new($DELICIOUS_API_ENDPINT);
    my $res                 = $ua->get($delicious_api_endpoint);

    my $rss     = _parse_rss( $res->content );
    return $rss->{'items'} || [];
}

sub _parse_rss {
    my $rss_text = shift;
    my $rss      = XML::RSS->new;
    eval { $rss->parse($rss_text) }
        or Carp::croak( "Parsing content failed: " . $@ );
    $rss;
}

sub post_entries_to_instantpaper {
    my $entries = shift;
    say("--> Posting delicious entries to InstantPaper ... ");
    foreach my $entry (@$entries) {
        my $tag_text = $entry->{'dc'}->{'subject'};
        my @tags =();
        @tags = split ' ', $tag_text if $tag_text;
        my $contain_tag = any { $_ eq $ENTRY_TAG } @tags;
        post_entry_to_instanpaper($entry) if $contain_tag;
    }
}

sub say {
    my $text = shift;
    print "$text\n";
}

sub post_entry_to_instanpaper {
    my $entry        = shift;
    say("==> Posting '$entry->{title}'");
    my $ua           = LWP::UserAgent->new;
    my $endpoint_uri = URI->new($INSTANT_PAPER_API_ENDPOINT);
    $endpoint_uri->query_form_hash(
        username => $CONFIG->{instant_username},
        password => $CONFIG->{instant_password},
        url      => $entry->{link},
    );
    my $res = $ua->get($endpoint_uri);
    unless ($res->is_success) {
       print STDERR  $res->status_line, "\n";
    }
}
