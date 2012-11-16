# Copyright (c) 2012, Mitchell Cooper
# UIC::Type::Object: represents an object in UIC.
#
# in numerical context, returns 1
# in string context, returns a string representing the unique object {type id}
# in boolean context, returns a true
# 
package UIC::Type::Object;

use warnings;
use strict;
use utf8;
use overload
    fallback => 1,
    '""' => sub { '{'.$_[0]->type.' '.$_[0]->id.'}' },
    bool => sub { 1 },
    '0+' => sub { 1 };

sub new {
    my ($class, $type, $identifier) = @_;
    return bless {
        type => $type,
        id   => $identifier
    }, shift;
}

sub type {
    shift->{type};
}

sub id {
    shift->{id};
}

sub is_string  { 0 }
sub is_number  { 0 }
sub is_array   { 0 }
sub is_object  { 1 }
sub is_boolean { 0 }

1
