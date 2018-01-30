#! /usr/bin/perl

package geni;
use strict;
use warnings;
use JSON::PP;
use LWP::UserAgent;
use Data::Dumper;
use Readonly;
use HTTP::Cookies::Netscape;
use HTML::HeadParser; 
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep clock_gettime clock_getres clock_nanosleep clock stat );
use XML::Simple;
use Compress::Zlib;
use Carp;
use Term::ProgressBar;
use Getopt::Long;

Readonly my $DEBUG=>1;
Readonly my $GENI_API_LINK => "https://www.geni.com/api";
Readonly my $GENI_SITE_MAP => "http://www.geni.com/sitemap_index.xml";

main();

sub main {
	my $r_arg = user_param();
	
	my $site_map_content = get_sitemap();
	my $r_xml_links = parse_site_map($site_map_content);
	my $r_xml_files = get_xml_links($r_xml_links);
	my $r_people_links = open_xml_files($r_xml_files);
	write_people_links($r_arg, $r_people_links);
	
}

sub get_sitemap {

	my $cookie_jar = HTTP::Cookies::Netscape->new(file => "cookies.txt");
	my $ua = new LWP::UserAgent;
	$ua->cookie_jar( $cookie_jar );
	$ua->timeout(130);


	my $request = new HTTP::Request('GET', $GENI_SITE_MAP);
	my $response = $ua->request($request);

	if (not $response->is_success) {
		confess "Can't get site map - ",$response->status_line;
	}

	my $content = $response->content();
	return $content;
}
sub parse_site_map {
	my ($content_xml) = @_;

	my $r_xml = XMLin($content_xml, Force_Array=>1);
	my @links;

	foreach my $object (@{$r_xml->{sitemap}}) {
		my $tmp = pop @{$object->{loc}};
		push @links, $tmp;
	}
	return \@links;
}

sub get_xml_links {
	my ($r_links) = @_;

	my @files; 

	my $cookie_jar = HTTP::Cookies::Netscape->new(file => "cookies.txt");
	my $ua = new LWP::UserAgent;
	$ua->cookie_jar( $cookie_jar );
	$ua->timeout(120);

    #my $progress = Term::ProgressBar->new({name => 'Getting XML files', count => scalar (@$r_links), ETA => 'linear'});

	LINK:
	foreach my $link (@$r_links) {
		print $link,"\n";

		$link =~ m/\/sm\/(\S+)$/;
		my $file = $1;
		if ($file eq '') {
			warn "I am not fetching link $link\n";
			next LINK;
		}
		my $response = $ua->mirror($link, $file);
		if (not $response->is_success and not $response->code == 304) {
			confess "Can't get $link - ",$response->status_line;
			next LINK;
		}
		#$progress->update;
		push @files, $file;
	}

	return \@files;
}

sub open_xml_files {
	my ($r_files) = @_;
	
	my @links;
	my $progress = Term::ProgressBar->new({name => 'Decomporessing XML files', count => scalar (@$r_files), ETA => 'linear'});

	foreach my $file (@$r_files) {
		#open file
		my $gz = gzopen($file, "rb")
		  or die "Cannot open $file: $gzerrno\n" ; 

		#reading file
		my $content_xml;
		while ($gz->gzreadline($_) > 0) {
			$content_xml .= $_;
		}

		#parsing xml
		my $r_xml = XMLin($content_xml, Force_Array=>1);
		
		OBJECT:
		foreach my $object (@{$r_xml->{url}}) {
			my $tmp = pop @{$object->{loc}};
			next OBJECT if ($tmp !~ m/people/);

			
			push @links, $tmp;
		}

		$progress->update;
	}
	print scalar @links, " were found\n";
	return \@links;
}

sub write_people_links {
	my ($r_arg, $r_people_links) = @_;

	my $file = $r_arg->{file};
	my $FH;
	open $FH, '>', $file or confess "can't open $file\n";
	foreach my $person_link (@$r_people_links) {
		print "$person_link\n";
		$person_link =~ m/\/(\d+)$/;
		my $guid = $1;
		my $new_link = join '/', $GENI_API_LINK, "profile-G$guid";

		print {$FH} "$person_link\t", "$new_link\n";
	}
	close $FH;
}

sub user_param {

	my $r_arg;
	my $file;
	
	GetOptions ("output=s" => \$file);
	if (	(not defined $file)	or 
		(0 == 1) ) {

		die_hard();
	}

	$r_arg->{file} = $file;
	return $r_arg;

}

sub die_hard {
	print "TBD\n";
	exit(1);
}
