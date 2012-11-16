# Copyright (c) 2012, Mitchell Cooper
package UIC::Type::String;

use warnings;
use strict;
use utf8;
use overload fallback => 1, '""' => \&string;

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
