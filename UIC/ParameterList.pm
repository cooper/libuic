# Copyright (c) 2012, Mitchell Cooper
# ParameterList: represents a hash of parameters.
# provides methods for testing parameter types, etc.
package UIC::ParameterList;

use warnings;
use strict;
use utf8;

my $inner = '$uic_list$';

# UIC::ParameterList->new(
#     someParam => ['string', 'hi']
# ); etc... [type, value]
sub new {
    my ($class, %params) = @_;
    my $list = bless {}, $class;
    
    # process the parameters.
    foreach my $param (CORE::keys %params) {
        my ($type, $value) = @{$params{$param}};
        $list->{$inner}{type}{$param}  = $type;
        $list->{$inner}{value}{$param} = $value;
        $list->{$param} = $value;
    }
    
    return $list;
}

# returns the keys of the parameters.
sub keys {
    my $list = shift;
    return CORE::keys %{$list->{$inner}{value}};
}

# adds a parameter $param of type $type.
sub add {
    my ($list, $param, $type, $value) = @_;
    $list->{$inner}{type}{$param}     = $type;
    $list->{$inner}{value}{$param}    = $value;
    $list->{$param} = $value;
    return 1;
}

# returns the string type of a parameter. ex: "string"
sub type_of {
    my ($list, $param) = @_;
    return $list->{$inner}{type}{$param};
}

# returns true if a parameter is present and defined.
sub has {
    my ($list, @params) = @_;
    return unless defined $list->{$inner}{value}{$_} foreach @params;
    return 1;
}

# returns the number of parameters in the list.
sub count {
    my $list = shift;
    return scalar CORE::keys %{$list->{$inner}{value}};
}

1
