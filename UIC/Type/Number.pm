# Copyright (c) 2012, Mitchell Cooper
# UIC::Type::Number: represents a numerical value in UIC.
#
# in numerical context, returns the numerical value
# in string context, returns the numerical value
# in boolean context, returns a false value for 0; true for anything else
# 
package UIC::Type::Number;

use warnings;
use strict;
use utf8;
use overload
    fallback => 1,
    '0+' => \&number,
    '""' => \&number,
    bool => sub { !!shift->{number} };

sub new {
    my ($class, $number) = @_;
    return bless {
        number => $number
    }, $class;
}

sub number {
    shift->{number};
}

sub is_string  { 0 }
sub is_number  { 1 }
sub is_array   { 0 }
sub is_object  { 0 }
sub is_boolean { 0 }

1
