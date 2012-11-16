# Copyright (c) 2012, Mitchell Cooper
# UIC::Type::String: represents a string value in UIC.
#
# in numerical context, returns 0
# in string context, returns the string value
# in boolean context, returns a false value for '' and '0'; true for anything else
# 
package UIC::Type::String;

use warnings;
use strict;
use utf8;
use overload fallback => 1,
    '""' => \&string,
    '0+' => sub { 0 },
    bool => sub { !!shift->string };

sub new {
    my ($class, $string) = @_;
    return bless {
        string => $string
    }, $class;
}

sub string {
    shift->{string};
}

sub is_string  { 1 }
sub is_number  { 0 }
sub is_array   { 0 }
sub is_object  { 0 }
sub is_boolean { 0 }

1
