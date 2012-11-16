# Copyright (c) 2012, Mitchell Cooper
package UIC::Type::Array;

use warnings;
use strict;
use utf8;
use overload
    fallback => 1,
    '@{}'=> sub { shift->{elements} },
    '""' => sub { '('.join ', ', shift->array.')' },
    bool => sub { !!self->array };

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
