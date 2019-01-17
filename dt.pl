#!/usr/bin/perl
######
#
# dt = dependency tree
#
# This script will print a dependency tree for a perl file
# The script will find and recursevly construct a tree of dependencies
#
# cannot handle Autouse classes at the moment
#
# flags:
# -l list files instead of making a tree
#
#####
use IO::File;
use warnings;
use strict;

#for printing special characters
use utf8;
binmode STDOUT, ":utf8";

use constant MAX_DEPTH => 10;
use constant {SUCCESS_DEPENDENCIES => 0, MAX_DEPTH_REACHED => 1, NO_FILE => 2, CIRCULAR_DEPENDENCY => 3, SUCCESS_NO_DEPENDENCIES => 4};

#handle flags
my @flags;
foreach my $a (@ARGV)
{
	if( $a =~ /-./ )
	{
		$a =~ s/-//;
		push @flags, $a;
	}
}

my $file_name = $ARGV[0];

#	root directory for dependencies
#	eg 
#	~/dir_a/inputfile.pm
#	~/dir_b/dependencies.pm
#	set $root_dep to dir_b/
my $root_dep = 'lib/';

my @dependencies;
my @warnings;
my $file = new IO::File;

#main
@dependencies = find_dependencies(file_name => $file_name, depth => 0, parent => 'NULL', grand_parent => 'GRAND_NULL');

# file_name => $, depth => $, grand_parent => $, parent => $
sub find_dependencies
{
	my %arg = @_;
	my $file_name = $arg{file_name};
	my $depth = $arg{depth};
	my $grand_parent = $arg{grand_parent};
	my $parent = $arg{parent};

	if($depth > MAX_DEPTH)
	{
		print "Max depth ", MAX_DEPTH, " reached!\n";
		return MAX_DEPTH_REACHED; 
	}
	#return if no file was given
	if(not $file_name)
	{
		print "No file with the name $file_name was found!\n";
		return NO_FILE;
	}

	# check if circular dependency
	# not perfect cannot catch larger circles of dependencies
	#print "gp $grand_parent and p $parent\n";
	if($file_name eq $grand_parent)
	{
		#print "current $file_name, parent $parent, grand parent $grand_parent\n";
		#print "WARNING: Circular dependency found! $file_name -> $parent -> $grand_parent. Removing $file_name from dependency tree...";
		return CIRCULAR_DEPENDENCY;
	}

	#create the correct number of tabs (used to be tabs, box drawing characters now)
	#my $tabs = tabs($depth);
	
	#find dependencies
	my @deps;
	my @test;
	if ($file->open("< $file_name"))
	{
		while(<$file>)
		{
			next if $_ =~ /\#/;
			#say STDOUT "input line $_";
			#'normal' use cases
			if(/^use( base)?\s(.+)\(?/g and not (/qw/ or /utf8/ or /strict/ or /warnings/ or /vars/))
			{
				#print "1 $1\n";
				#print "2 $2\n";
				push @deps, $2;
			}
			elsif(/([a-z]+::)+[a-z]+/gi and not (/\{/ or /my/ or /Autouse/ or /package/ or /ver/ or /\./))
			{
				my $t = $_;
				$t =~ s/\s*//;
				#next if not $_;
				#print "\nKnown limitation: cannot follow Autouse dependencies, $_\n";
				#print "----------->Autouse, $file_name: $t\n";
				#push @test, $t;
				push @deps, $t;
			}
			#print "test array\n";
			#say STDOUT @test;
			
			#elsif(/\s*((.+::)+.+)$/g and not (/<|>|->|=|#|package/)) #assuming the rest are autouse classes where classes are written och separate lines
			#{
			#	push @deps, $1 if($1 ne /$file_name)
			#}
			#elsif(/^use base
		}
	}
	else
	{
		#print "Cannot find file $file_name\n";
	}
	$file->close;
	#no dependencies found!
	return SUCCESS_NO_DEPENDENCIES if(not @deps);

	if($depth == 0)
	{
		print "$file_name depends on\n"; 
	}
	#else
	#{
	#	$tabs = tabs($depth);
	#	print "${tabs}\n"; 
	#}

	#foreach (@deps)
	for (my $i = 0; $i < scalar @deps; $i++)
	{
		my $dep = $deps[$i];
		$dep =~ s/::/\//g; #ABC::Example () -> ABC/Example
		$dep =~ s/\(.*\)//g; #ABC/Example ('stuff') -> ABC/Example
		$dep =~ s/;//g; #ABC/Example; -> ABC/Example 
		$dep =~ s/\s+//g; #remove spaces
		$dep =~ s/'//g; #ABC/'Example' -> ABC/Example
		$dep = $root_dep.$dep.'.pm';
		$deps[$i] = $dep;
		print tree(depth => $depth, dep => $deps[$i], nr_deps => scalar @deps, i => $i);
		#print "$tabs$dep\n";
		#print "before recursion to $_, deps @deps\n";
		my $result = find_dependencies(file_name => $dep, depth => $depth + 1, parent => $file_name, grand_parent => $parent);
		die if($result == MAX_DEPTH_REACHED);
			
	}


	return SUCCESS_DEPENDENCIES;
}

# depth => $
#	dep => $
#	nr_deps => $
#	i => $i
sub tree
{
	my $tree = '';
	my %args = @_;
	my $depth = $args{depth};
	my $dep = $args{dep};
	my $nr_deps = $args{nr_deps};

	#\N{...}
	#BOX DRAWINGS LIGHT HORIZONTAL
	#BOX DRAWINGS LIGHT VERTICAL AND RIGHT

	if( grep { $_ eq 'l' } @flags )
	{
		return "$dep\n";
	}

	# Special case for the root file and its direct dependencies
	if($depth % 2 == 0 and $depth < 2)
	{
		$tree .= "\N{BOX DRAWINGS LIGHT VERTICAL AND RIGHT}\N{BOX DRAWINGS LIGHT HORIZONTAL}"; #T-
		for(my $i = 0; $i < $depth; $i++)
		{
			$tree .= "\N{BOX DRAWINGS LIGHT VERTICAL} "; #|
		}
	}
	else
	{


		for(my $i = 0; $i < $depth; $i++)
		{
			#if($args{i} > 0  and $nr_deps == $args{i})
			#{
				$tree .= "\N{BOX DRAWINGS LIGHT VERTICAL} "; #|
				#}
				#else
				#{
				#	$tree .= ' ';
				#}
		}
		if($depth == $args{nr_deps})
		{
			$tree .= "\N{BOX DRAWINGS LIGHT VERTICAL AND RIGHT}"; #T
		}
		else
		{
			$tree .= "\N{BOX DRAWINGS LIGHT UP AND RIGHT}"; #L
		}
		$tree .= "\N{BOX DRAWINGS LIGHT HORIZONTAL}"; #-
	}

	return "$tree$dep\n";
}
