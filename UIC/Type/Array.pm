# Copyright (c) 2012, Mitchell Cooper
# UIC::Type::Array: represents an array in UIC.
#
# in numerical context, returns the scalar value of the array (# of items in array)
# in string context, returns a comma-separated list of elements in the array
# in boolean context, returns true if the array has at least one element; false otherwise
# when dereferenced as an array, returns the array itself
# 
package UIC::Type::Array;

use warnings;
use strict;
use utf8;
use overload
    fallback => 1,
    '@{}'=> sub { shift->{elements} },
    '""' => sub { '('.(join ', ', shift->array).')' },
    bool => sub { !!shift->array },
    '0+' => sub { scalar shift->array };

sub new {
    my ($class, @elements) = @_;
    return bless {
        elements => \@elements
    }, shift;
}

sub array {
    return @{shift->{elements}};
}

sub is_string  { 0 }
sub is_number  { 0 }
sub is_array   { 1 }
sub is_object  { 0 }
sub is_boolean { 0 }

1
