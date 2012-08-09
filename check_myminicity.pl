#!/usr/bin/env perl

use strict;

use lib "/usr/local/libexec/nagios";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use vars qw($PROGNAME);

use Data::Dumper;
use Date::Calc qw(Decode_Month);
use DateTime;
use Getopt::Long;
use LWP::UserAgent;
use URI;
use Web::Scraper;

$PROGNAME = "check_myminicity.pl";

sub print_help () {
    print_revision($PROGNAME,'');
    print "Copyright (c) 2012 Tomohiro Hosaka <bokutin\@bokut.in>\n";
    print "\n";
    print_usage();
    print "\n";
    support();
}

sub print_usage () {
    print "Usage: \n";
    print " $PROGNAME -U URI -w warning -c critical\n";
    print " $PROGNAME [-h | --help]\n";
    print " $PROGNAME [-V | --version]\n";
}

sub run {
    my ($opt_U, $opt_w, $opt_c, $opt_t) = @_;

    my $uri = URI->new($opt_U);
    my $ua  = LWP::UserAgent->new(
        agent   => 'Mozilla/5.0 (compatible; Yahoo! Slurp/3.0; http://help.yahoo.com/help/us/ysearch/slurp)',
        timeout => $opt_t,
    );
    my $events = scraper {
        process "div.evt", "events[]" => scraper {
            process "strong", text => "TEXT";
        };
    };
    $events->user_agent($ua);
    my $res = $events->scrape($uri);
    #warn Dumper $res;
    #$VAR1 = {
    #          'events' => [
    #                        {
    #                          'text' => '09 August: '
    #                        },

    die unless $res;

    my @deltas = sort { $a <=> $b } map { _evt_str_to_delta_day($_) } map { $_->{text} } @{ $res->{events} };

    my $msg;
    my $state;
    if (@deltas) {
        if ( $deltas[0] > $opt_c ) {
            $msg = "CRITICAL: $deltas[0]";
            $state = $ERRORS{'CRITICAL'};
        } 
        elsif ( $deltas[0] > $opt_w ) {
            $msg = "WARNING: $deltas[0]";
            $state = $ERRORS{'WARNING'};
        }
    }
    $msg   //= "OK: ";
    $state //= $ERRORS{'OK'};

    print "$msg\n";
    exit $state;
}

sub _evt_str_to_delta_day {
    my ($str) = @_;

    #warn $str; 09 August: 

    my ($day, $month) = split(/[ :]+/, $str);
    #warn Dumper [ $day, $month ];

    my $month = Decode_Month($month);

    die unless $month;

    my $today = DateTime->today;
    my $event = do {
        my $dt = DateTime->new( year => $today->year, month => $month, day => $day );
        if ($dt > $today) {
            $dt->add( years => -1 );
        }
        $dt;
    };
    my $dur = $today - $event;
    my $delta_day = $dur->days;
}

main: {
    my ($opt_V, $opt_h, $opt_U, $opt_w, $opt_c, $opt_t);
    check_args: {
        Getopt::Long::Configure('bundling');
        GetOptions(
            "V"   => \$opt_V, "version"    => \$opt_V,
            "h"   => \$opt_h, "help"       => \$opt_h,
            "U=s" => \$opt_U, "uri=s"      => \$opt_U,
            "w=i" => \$opt_w, "warning=i"  => \$opt_w,
            "c=i" => \$opt_c, "critical=i" => \$opt_c,
            "t=i" => \$opt_t, "timeout=i"  => \$opt_t,
        );
    }

    $opt_w = int($opt_w) if defined $opt_w;
    $opt_c = int($opt_c) if defined $opt_c;
    $opt_t ||= 60;

    if ($opt_h or !$opt_U or !defined($opt_w) or !defined($opt_c) or $opt_t!~m/^\d+$/) {
        print_help();
        exit $ERRORS{'OK'};
    }

    if ($opt_V) {
        print_revision($PROGNAME,'');
        exit $ERRORS{'OK'};
    }

    run($opt_U, $opt_w, $opt_c, $opt_t);
}
