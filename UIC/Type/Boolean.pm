# Copyright (c) 2012, Mitchell Cooper
# UIC::Type::Boolean: represents a boolean value in UIC.
#
# in numerical context, returns 1 for a true value and 0 for a false value
# in string context, returns 'true' or 'false'
# in boolean context, returns the boolean value
# 
package UIC::Type::Boolean;

use warnings;
use strict;
use utf8;
use overload
    fallback => 1,
    '0+' => sub { shift->bool ? 1 : 0 },
    '""' => sub { shift->bool ? 'true' : 'false' },
    bool => \&bool;
    
sub new {
    my ($class, $value) = @_;
    return bless {
        bool  => !!$value,
        value => value
    }, $class;
}

sub bool {
    shift->{bool};
}

sub boolean {
    shift->{bool};
}

sub is_string  { 0 }
sub is_number  { 0 }
sub is_array   { 0 }
sub is_object  { 0 }
sub is_boolean { 1 }

1
